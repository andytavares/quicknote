import QuicknoteKit
import SwiftUI

/// Notes grouped by the app or site they were made in (S16).
struct SitesAndAppsView: View {
    let model: LibraryModel

    var body: some View {
        List {
            ForEach(model.contextGroups, id: \.displayName) { group in
                Section {
                    ForEach(group.notes) { note in
                        Button(note.title.isEmpty ? "Untitled" : note.title) { model.open(note) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open \(note.title)")
                    }
                } header: {
                    header(for: group)
                }
            }
        }
        .overlay {
            if model.contextGroups.isEmpty {
                ContentUnavailableView("No app or site notes yet", systemImage: "macwindow")
            }
        }
        .navigationTitle("Sites and apps")
    }

    private func header(for group: ContextGroup) -> some View {
        HStack(spacing: 8) {
            Text(group.displayName.prefix(1).uppercased())
                .font(.headline).frame(width: 28, height: 28)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .accessibilityHidden(true)
            Text(group.displayName).font(.headline)
            let count = group.notes.count
            Text("\(count) note\(count == 1 ? "" : "s") · \(group.siteHost == nil ? "app" : "site")")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
