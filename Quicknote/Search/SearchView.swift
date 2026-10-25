import AppKit
import QuicknoteKit
import SwiftUI

struct SearchView: View {
    @Bindable var model: SearchModel
    let open: (SearchRow) -> Void
    let showLibrary: () -> Void
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            field
            Divider()
            results
            Divider()
            footer
        }
        .frame(width: 620)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onChange(of: model.focusRequest, initial: true) { fieldFocused = true }
        .onChange(of: model.rows.count) { announceCount() }
    }

    private var field: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
            TextField("Search", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($fieldFocused)
                .onKeyPress(.downArrow) {
                    model.moveSelection(by: 1); return .handled
                }
                .onKeyPress(.upArrow) {
                    model.moveSelection(by: -1); return .handled
                }
                .onKeyPress(.return, phases: .down) { press in handleReturn(press) }
                .accessibilityLabel("Search notes, meetings and files")
            Text(Shortcuts.label(for: .search)).font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
        }
        .padding(14)
        .onChange(of: model.focusRequest) { selectAllText() }
    }

    @ViewBuilder private var results: some View {
        if model.rows.isEmpty {
            Text(model.hasSearched ? "No matches" : "Type to search notes, meetings and files")
                .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(24)
        } else {
            ScrollViewReader { proxy in
                ScrollView { rowList }
                    .frame(maxHeight: 420)
                    .onChange(of: model.selectedIndex) {
                        if let row = model.selectedRow { proxy.scrollTo(row.id) }
                    }
            }
        }
    }

    private var rowList: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(SearchGroup.allCases, id: \.self) { group in
                let groupRows = model.rows.filter { $0.group == group }
                if !groupRows.isEmpty {
                    Text(group.rawValue).font(.caption.bold()).foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.top, 4)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(groupRows) { row in resultRow(row) }
                }
            }
        }
        .padding(6)
    }

    private func resultRow(_ row: SearchRow) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if let timestamp = row.timestamp {
                Text(timestamp).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading) {
                Text(SearchSnippet.attributed(row.snippet)).lineLimit(2)
                Text(row.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(row == model.selectedRow ? Color.accentColor.opacity(0.18) : .clear, in: .rect(cornerRadius: 7))
        .contentShape(.rect)
        .onTapGesture {
            model.select(row); open(row)
        }
        .id(row.id)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("↵ open")
            Text("⌘↵ show in Library")
            Spacer()
            Text("Works offline")
        }
        .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.vertical, 8)
    }

    private func handleReturn(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) {
            showLibrary()
        } else if let row = model.selectedRow {
            open(row)
        }
        return .handled
    }

    private func selectAllText() {
        DispatchQueue.main.async {
            NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSText.selectAll(_:)), with: nil)
        }
    }

    private func announceCount() {
        guard model.hasSearched else { return }
        let count = model.rows.count
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: count == 0 ? "No results" : "\(count) results"])
    }
}
