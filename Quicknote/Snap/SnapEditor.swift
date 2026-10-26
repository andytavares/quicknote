import AppKit
import OSLog
import QuicknoteKit
import SwiftUI

/// The Snap editor window (S20). Each window owns one `SnapEditorModel`.
enum SnapEditorWindow {
    private static var open: [NSWindow] = []
    private static let logger = Logger(subsystem: "app.quicknote.Quicknote", category: "Snap")

    static func show(original: CGImage, document: CanvasDocument, noteId: Int64?) {
        let model = SnapEditorModel(original: original, document: document, noteId: noteId)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 900, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered,
            defer: false)
        let delegate = SnapEditorWindowDelegate(model: model) { open.removeAll { $0 === window } }
        window.delegate = delegate
        objc_setAssociatedObject(window, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        window.title = "Snap · \(Date().formatted(date: .omitted, time: .shortened))"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(
            rootView: SnapEditorView(model: model, saver: .live, close: { [weak window] in window?.close() }))
        window.center()
        open.append(window)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Reopens a saved Snap from its canvas JSON and original attachment.
    static func reopen(noteId: Int64) {
        let saver = SnapSaver.live
        guard let note = try? saver.repository.note(id: noteId), let document = note.canvas,
            case .image(let attachmentId, _) = document.background,
            let attachment = try? saver.attachments.attachments(of: noteId).first(where: { $0.id == attachmentId }),
            let source = CGImageSourceCreateWithURL(saver.attachments.fileURL(for: attachment) as CFURL, nil),
            let original = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return logger.error("Snap \(noteId) cannot be reopened") }
        show(original: original, document: document, noteId: noteId)
    }
}

/// Routes spoken captions here while the editor is the key window, and releases them afterwards.
private final class SnapEditorWindowDelegate: NSObject, NSWindowDelegate {
    let model: SnapEditorModel
    let didClose: () -> Void

    init(model: SnapEditorModel, didClose: @escaping () -> Void) {
        self.model = model
        self.didClose = didClose
    }

    func windowDidBecomeKey(_ notification: Notification) {
        VoiceFeature.captionTarget = { [model] text in
            model.caption = model.caption.isEmpty ? text : "\(model.caption) \(text)"
        }
    }

    func windowDidResignKey(_ notification: Notification) { VoiceFeature.captionTarget = nil }

    func windowWillClose(_ notification: Notification) {
        VoiceFeature.captionTarget = nil
        didClose()
    }
}

struct SnapEditorView: View {
    @Bindable var model: SnapEditorModel
    let saver: SnapSaver
    let close: () -> Void
    @FocusState private var isCanvasFocused: Bool
    @FocusState private var isTextFieldFocused: Bool
    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 0) {
            toolRow
            Divider()
            canvas
            Divider()
            captionRow
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar { toolbarContent }
        .alert("Couldn't save the Snap", isPresented: Binding(get: { saveError != nil }, set: { _ in saveError = nil }))
        {
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: Layout

    private var toolRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(SnapTool.allCases) { tool in toolButton(tool) }
                Divider().frame(height: 18)
                ForEach(SnapEditorModel.palette, id: \.self) { colorButton($0) }
                strokeMenu
                Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Redo", systemImage: "arrow.uturn.forward") { model.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            .labelStyle(.iconOnly)
            .padding(8)
        }
    }

    private func toolButton(_ tool: SnapTool) -> some View {
        Button {
            model.tool = tool
        } label: {
            Text("\(tool.symbol) \(tool.title)")
        }
        .buttonStyle(.bordered)
        .tint(model.tool == tool ? .accentColor : nil)
        .accessibilityLabel("\(tool.title) tool")
        .accessibilityAddTraits(model.tool == tool ? .isSelected : [])
        .help("\(tool.title) (\(String(tool.shortcut).uppercased()))")
    }

    private func colorButton(_ hex: String) -> some View {
        Button {
            model.setColor(hex)
        } label: {
            Circle().fill(Color(hex: hex)).frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.primary, lineWidth: model.style.colorHex == hex ? 2 : 0).padding(-3))
        }
        .buttonStyle(.plain)
        .padding(4)
        .accessibilityLabel("Colour \(hex)")
        .accessibilityAddTraits(model.style.colorHex == hex ? .isSelected : [])
    }

    private var strokeMenu: some View {
        Picker("Stroke width", selection: Binding(get: { model.style.strokeWidth }, set: { model.setStrokeWidth($0) }))
        {
            ForEach(SnapEditorModel.strokeWidths, id: \.self) { Text("\(Int($0)) px").tag($0) }
        }
        .frame(width: 80)
        .accessibilityLabel("Stroke width")
    }

    private var canvas: some View {
        CanvasView(
            document: model.document, resources: model.resources, selectedID: model.selectedID,
            onPointer: { model.handle($0) },
            accessory: { zoom in textEditor(zoom: zoom) }
        )
        .padding(22)
        .background(Color(nsColor: .underPageBackgroundColor))
        .focusable()
        .focused($isCanvasFocused)
        .onKeyPress(phases: [.down, .repeat], action: handleKey)
        .onAppear { isCanvasFocused = true }
    }

    @ViewBuilder
    private func textEditor(zoom: CGFloat) -> some View {
        if let id = model.editingTextID, let element = model.document.elements.first(where: { $0.id == id }) {
            TextField("Text", text: $model.editingText)
                .textFieldStyle(.plain)
                .font(.system(size: element.frame.height * 0.7 * zoom, weight: .medium))
                .foregroundStyle(Color(hex: element.style.colorHex))
                .frame(
                    width: max(element.frame.width, 120) * zoom, height: element.frame.height * zoom,
                    alignment: .leading
                )
                .focused($isTextFieldFocused)
                .onSubmit { model.commitTextEditing() }
                .onAppear { isTextFieldFocused = true }
                .offset(x: element.frame.minX * zoom, y: element.frame.minY * zoom)
                .accessibilityLabel("Text for the annotation")
        }
    }

    private var captionRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic").foregroundStyle(.secondary).accessibilityHidden(true)
            Text("Hold \(Shortcuts.label(for: .holdToTalk)) to add a caption by voice").font(.callout).foregroundStyle(
                .secondary)
            TextField("Caption", text: $model.caption)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Caption")
            Button("Save to edge") { Task { await saveToEdge() } }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Save the Snap to the edge")
        }
        .padding(10)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            dragHandle
            Button("Copy") { Task { await payload().map { ShareActions.copyImage(of: $0) } } }
                .accessibilityLabel("Copy the image")
            Button("Save PNG") { Task { await payload().map { try? ShareActions.savePNG($0) } } }
                .accessibilityLabel("Save the image as a PNG file")
            ShareMenu(payload: { await payload() })
        }
    }

    private var dragHandle: some View {
        Label("Drag PNG", systemImage: "square.and.arrow.up.on.square")
            .onDrag { NSItemProvider(contentsOf: dragFileURL()) ?? NSItemProvider() }
            .help("Drag the image into Slack, Mail or a folder as a PNG file")
            .accessibilityLabel("Drag the image out as a PNG file")
    }

    // MARK: Actions

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if let tool = SnapTool.allCases.first(where: { String($0.shortcut) == press.characters }),
            press.modifiers.isEmpty
        {
            model.tool = tool
            return .handled
        }
        let step: CGFloat = press.modifiers.contains(.shift) ? 10 : 1
        switch press.key {
        case .delete, .deleteForward: model.deleteSelection()
        case .return: model.selectedID.map { model.beginEditingText(of: $0) }
        case .leftArrow: model.nudgeSelection(by: CGSize(width: -step, height: 0))
        case .rightArrow: model.nudgeSelection(by: CGSize(width: step, height: 0))
        case .upArrow: model.nudgeSelection(by: CGSize(width: 0, height: -step))
        case .downArrow: model.nudgeSelection(by: CGSize(width: 0, height: step))
        default: return .ignored
        }
        return .handled
    }

    private func renderedImage() -> CGImage? {
        model.commitTextEditing()
        return CanvasRenderer.render(model.document, resources: model.resources)
    }

    private func dragFileURL() -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "Snap.png")
        try? renderedImage()?.pngData?.write(to: url)
        return url
    }

    /// Saves the note (creating it the first time) and returns what to share.
    private func payload() async -> SharePayload? {
        guard let image = renderedImage(), let noteId = await persist() else { return nil }
        return SharePayload(image: image, caption: model.caption, noteId: noteId)
    }

    private func persist() async -> Int64? {
        model.saveCaption()
        do {
            let id = try await saver.save(
                SnapContent(original: model.original, document: model.document), noteId: model.noteId, now: Date())
            model.noteId = id
            return id
        } catch {
            saveError = error.localizedDescription
            return nil
        }
    }

    private func saveToEdge() async {
        model.commitTextEditing()
        if await persist() != nil { close() }
    }
}
