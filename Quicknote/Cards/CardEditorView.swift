import AppKit
import QuicknoteKit
import SwiftUI
import UniformTypeIdentifiers

struct CardEditorView: View {
    @Bindable var model: CardEditorModel
    @FocusState private var isCanvasFocused: Bool
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: 0) {
            CardStylesColumn(model: model)
            Divider()
            VStack(spacing: 0) {
                canvas
                Divider()
                footer
            }
            Divider()
            CardDecoratePanel(model: model, chooseAndAddPhoto: chooseAndAddPhoto)
        }
        .frame(minWidth: 900, minHeight: 560)
        .toolbar { toolbarContent }
        .onDisappear { if model.isEdited { _ = try? model.save() } }
        .alert(
            "Couldn't save the card",
            isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })
        ) {
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var canvas: some View {
        CanvasView(document: model.document, resources: model.resources, selectedID: model.selectedID) {
            model.handle($0)
        }
        .padding(22)
        .background(Color(nsColor: .underPageBackgroundColor))
        .focusable()
        .focused($isCanvasFocused)
        .onKeyPress(phases: [.down, .repeat]) { press in
            guard press.key == .delete || press.key == .deleteForward else { return .ignored }
            model.deleteSelection()
            return .handled
        }
        .onAppear { isCanvasFocused = true }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(model.selectionSummary).font(.callout).foregroundStyle(.secondary)
            if let text = model.selectedText {
                TextField("Text", text: Binding(get: { text }, set: { model.setText($0) }))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Text of the selected item")
            }
            Spacer()
            Button("Delete", systemImage: "trash") { model.deleteSelection() }
                .disabled(model.selectedID == nil)
                .accessibilityLabel("Delete the selected item")
            Toggle(
                "Add “made with Quicknote”",
                isOn: Binding(get: { model.document.showsMadeWithMark }, set: { model.setShowsMadeWithMark($0) })
            )
            .accessibilityLabel("Add made with Quicknote")
        }
        .padding(10)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup {
            Picker(
                "Size",
                selection: Binding(get: { model.sizeChoice }, set: { model.chooseSize($0) })
            ) {
                ForEach(CardSizeChoice.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Card size")
            Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityLabel("Undo")
            Button("Redo", systemImage: "arrow.uturn.forward") { model.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .accessibilityLabel("Redo")
            Button("Save PNG") { Task { await payload().map { try? ShareActions.savePNG($0, fileName: "Card.png") } } }
                .accessibilityLabel("Save the card as a PNG file")
            ShareMenu(payload: { await payload() })
        }
    }

    /// Saves the note and renders the card at its export size.
    private func payload() async -> SharePayload? {
        do {
            let noteId = try model.save()
            guard let image = model.renderedImage() else { return nil }
            return SharePayload(image: image, caption: "", noteId: noteId)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func chooseAndAddPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try model.addPhoto(fileAt: url) } catch { errorMessage = error.localizedDescription }
    }
}

/// The six styles as thumbnails.
struct CardStylesColumn: View {
    let model: CardEditorModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(CardStyle.allCases, id: \.self) { style in
                    Button {
                        model.setStyle(style)
                    } label: {
                        VStack(spacing: 4) {
                            thumbnail(of: style)
                            Text(style.title).font(.caption)
                        }
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor, lineWidth: model.cardStyle == style ? 2 : 0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(style.title) style")
                    .accessibilityAddTraits(model.cardStyle == style ? .isSelected : [])
                }
            }
            .padding(10)
        }
        .frame(width: 110)
    }

    @ViewBuilder private func thumbnail(of style: CardStyle) -> some View {
        let document = CanvasDocument(background: .card(style: style, size: .square))
        if let image = CanvasRenderer.render(document, scale: 0.08, resources: model.resources) {
            Image(decorative: image, scale: 1).resizable().scaledToFit().frame(width: 80, height: 80)
        }
    }
}
