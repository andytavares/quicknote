import Foundation
import Observation
import QuicknoteKit

/// Query text, results and the highlighted row. Searches run off the main thread after a pause in typing.
@Observable
final class SearchModel {
    typealias Search = @Sendable (String) -> [SearchRow]

    static let debounce: Duration = .milliseconds(120)

    var query = "" {
        didSet { if query != oldValue { scheduleSearch() } }
    }
    private(set) var rows: [SearchRow] = []
    private(set) var selectedIndex = 0
    private(set) var hasSearched = false
    /// Bumped each time the panel is asked to open, so the view refocuses and selects the field text.
    private(set) var focusRequest = 0

    private let search: Search
    private let debounce: Duration
    private var pending: Task<Void, Never>?

    init(debounce: Duration = SearchModel.debounce, search: @escaping Search) {
        self.debounce = debounce
        self.search = search
    }

    var selectedRow: SearchRow? { rows.indices.contains(selectedIndex) ? rows[selectedIndex] : nil }

    /// Clamps at both ends so holding the arrow key does not jump past the list.
    func moveSelection(by step: Int) {
        guard !rows.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + step, 0), rows.count - 1)
    }

    func requestFocus() { focusRequest += 1 }

    func select(_ row: SearchRow) {
        if let index = rows.firstIndex(of: row) { selectedIndex = index }
    }

    /// Resolves when the search for the current query has finished or was cancelled.
    func settle() async { await pending?.value }

    private func scheduleSearch() {
        pending?.cancel()
        let text = query
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            show([], searched: false)
            return
        }
        pending = Task { [search, debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            let found = await Task.detached { search(text) }.value
            guard !Task.isCancelled else { return }
            show(found, searched: true)
        }
    }

    private func show(_ found: [SearchRow], searched: Bool) {
        rows = found
        selectedIndex = 0
        hasSearched = searched
    }
}
