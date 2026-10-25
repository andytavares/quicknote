/// Undo and redo for a canvas. Record the starting document first, then the result of every edit.
public struct CanvasHistory: Sendable {
    public static let capacity = 100

    private var states: [CanvasDocument] = []
    private var current = -1

    public init() {}

    public mutating func record(_ document: CanvasDocument) {
        states.removeSubrange((current + 1)...)
        states.append(document)
        if states.count > Self.capacity { states.removeFirst() }
        current = states.count - 1
    }

    /// Updates the newest state instead of adding one, so a run of keystrokes is a single undo step.
    public mutating func replaceLatest(with document: CanvasDocument) {
        guard states.indices.contains(current) else { return record(document) }
        states.removeSubrange((current + 1)...)
        states[current] = document
    }

    public mutating func undo() -> CanvasDocument? {
        guard current > 0 else { return nil }
        current -= 1
        return states[current]
    }

    public mutating func redo() -> CanvasDocument? {
        guard current + 1 < states.count else { return nil }
        current += 1
        return states[current]
    }
}
