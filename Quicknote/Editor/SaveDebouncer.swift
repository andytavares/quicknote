import Foundation

/// Runs `action` once after edits stop coming. `flush()` runs a pending one now.
final class SaveDebouncer {
    private let delay: Duration
    private let action: () -> Void
    private var pending: Task<Void, Never>?

    init(delay: Duration = .milliseconds(500), action: @escaping () -> Void) {
        self.delay = delay
        self.action = action
    }

    var hasPendingSave: Bool { pending != nil }

    func schedule() {
        pending?.cancel()
        pending = Task { [delay] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            flush()
        }
    }

    func flush() {
        guard pending != nil else { return }
        pending?.cancel()
        pending = nil
        action()
    }
}
