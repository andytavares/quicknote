import AppKit
import QuicknoteKit
import SwiftUI

struct CaptureView: View {
    @Bindable var model: CaptureModel
    @FocusState private var isTyping: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            TextEditor(text: $model.draft.text)
                .font(.system(size: 16))
                .scrollContentBackground(.hidden)
                .frame(height: 90)
                .focused($isTyping)
                .onKeyPress(.return, phases: .down) { press in
                    guard !press.modifiers.contains(.shift) else { return .ignored }
                    model.save()
                    return .handled
                }
                .onKeyPress(.tab) {
                    model.cycleKind()
                    return .handled
                }
                .accessibilityLabel("Note text")
                .accessibilityHint("Return saves, Shift Return adds a line, Tab changes the type")
            attachmentList
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .dropDestination(for: URL.self) { urls, _ in
            model.attach(urls.filter(\.isFileURL))
            return true
        }
        .onAppear { isTyping = true }
    }

    private var header: some View {
        HStack {
            if let context = model.draft.context { ContextChip(context: context) }
            Spacer()
            Text("⌃⌥N").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var attachmentList: some View {
        ForEach(model.draft.attachments, id: \.self) { url in
            Label(url.lastPathComponent, systemImage: "paperclip").font(.caption)
                .accessibilityLabel("Attached \(url.lastPathComponent)")
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text(model.detectedChip).font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(.tint.opacity(0.2), in: Capsule())
                .accessibilityLabel("Type: \(model.detectedChip)")
            colorMenu
            projectMenu
            pinToggle
            Spacer()
            Button("Attach", action: chooseFiles).accessibilityLabel("Attach files")
            Button("Save") { model.save() }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Save note")
                .accessibilityHint("Shortcut Return")
        }
    }

    private var colorMenu: some View {
        Menu {
            ForEach(AppSettings.noteColorChoices, id: \.hex) { choice in
                Button(choice.name) { model.draft.colorHex = choice.hex }
            }
        } label: {
            Circle().fill(Color(hex: model.draft.colorHex)).frame(width: 14, height: 14)
        }
        .menuStyle(.borderlessButton).fixedSize()
        .accessibilityLabel("Note colour")
    }

    private var projectMenu: some View {
        let name = model.projects.first { $0.id == model.draft.projectId }?.name
        return Menu(name.map { "Project: \($0)" } ?? "No project") {
            Button("No project") { model.draft.projectId = nil }
            ForEach(model.projects) { project in
                Button(project.name) { model.draft.projectId = project.id }
            }
        }
        .menuStyle(.borderlessButton).fixedSize()
        .accessibilityLabel("Project")
        .accessibilityValue(name ?? "None")
    }

    @ViewBuilder private var pinToggle: some View {
        if let context = model.draft.context, let name = context.siteHost ?? context.appName {
            Toggle("Pin to \(name)", isOn: $model.draft.pinsToContext)
                .toggleStyle(.checkbox).font(.caption)
                .accessibilityLabel("Pin to \(name)")
        }
    }

    private func chooseFiles() {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = true
        if openPanel.runModal() == .OK { model.attach(openPanel.urls) }
    }
}
