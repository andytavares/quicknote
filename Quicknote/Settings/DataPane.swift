import AppKit
import QuicknoteKit
import SwiftUI
import UserNotifications

/// Settings › Data (S26): what is stored, export, and Delete everything.
struct DataPane: View {
    @State private var summary: DataSummary?
    @State private var isConfirmingDelete = false
    @State private var typedWord = ""
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Stored on this Mac")
                    Text(summary?.text ?? "Counting…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Show in Finder") { NSWorkspace.shared.open(AppEnvironment.current.paths.root) }
                    .accessibilityLabel("Show Quicknote's folder in Finder")
            }
            HStack {
                VStack(alignment: .leading) {
                    Text("Export everything")
                    Text("Markdown files plus attachments").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Export…") { exportEverything() }.accessibilityLabel("Export everything as Markdown")
            }
            Divider()
            deleteSection
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }
        .task { reload() }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Delete everything").bold().foregroundStyle(.red)
            Text(
                "Removes all notes, recordings, Snaps, cards and attachments from this Mac. Events already in Calendar stay. This can't be undone."
            )
            .font(.caption).fixedSize(horizontal: false, vertical: true)
            if isConfirmingDelete {
                TextField("Type DELETE to confirm", text: $typedWord).accessibilityLabel("Type DELETE to confirm")
                HStack {
                    Spacer()
                    Button("Cancel") { stopConfirming() }.keyboardShortcut(.cancelAction)
                    Button("Delete everything", role: .destructive) { deleteEverything() }
                        .disabled(!DeleteConfirmation.isConfirmed(typedWord))
                }
            } else {
                Button("Delete everything…", role: .destructive) { isConfirmingDelete = true }
            }
        }
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.red))
    }

    private func reload() {
        summary = try? DataSummary.load(from: AppEnvironment.current)
    }

    private func stopConfirming() {
        isConfirmingDelete = false
        typedWord = ""
    }

    private func exportEverything() {
        let chooser = NSOpenPanel()
        chooser.canChooseDirectories = true
        chooser.canChooseFiles = false
        chooser.canCreateDirectories = true
        chooser.prompt = "Export here"
        guard chooser.runModal() == .OK, let folder = chooser.url else { return }
        let environment = AppEnvironment.current
        do {
            let count = try MarkdownExporter(paths: environment.paths).exportAll(
                database: environment.database, to: folder)
            message = "Exported \(count) \(count == 1 ? "note" : "notes") to \(folder.lastPathComponent)."
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }

    private func deleteEverything() {
        let environment = AppEnvironment.current
        do {
            try DataEraser(paths: environment.paths, database: environment.database).eraseEverything()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            EdgeFeature.refresh()
            message = "Everything was deleted."
        } catch {
            message = "Delete failed: \(error.localizedDescription)"
        }
        stopConfirming()
        reload()
    }
}
