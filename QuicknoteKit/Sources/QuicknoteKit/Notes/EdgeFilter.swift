import Foundation

/// What is in front of the user: an app, a site in a browser, or both.
public struct ContextKey: Equatable, Sendable {
    public var appBundleId: String?
    public var siteHost: String?

    public init(appBundleId: String? = nil, siteHost: String? = nil) {
        self.appBundleId = appBundleId
        self.siteHost = siteHost
    }
}

/// Decides which notes wait as tabs on the screen edge right now.
public enum EdgeFilter {
    public static func visibleNotes(_ notes: [Note], context: ContextKey?, now: Date) -> [Note] {
        let candidates = notes.filter { isOnEdge($0, now: now) && (!$0.pinnedToContext || matches($0, context)) }
        return candidates.sorted { first, second in
            let firstMatches = pinnedMatch(first, context), secondMatches = pinnedMatch(second, context)
            if firstMatches != secondMatches { return firstMatches }
            return NoteOrder.isBefore(first, second)
        }
    }

    /// The pinned notes that match `context`; the edge pops these out.
    public static func contextNotes(_ notes: [Note], context: ContextKey?, now: Date) -> [Note] {
        visibleNotes(notes, context: context, now: now).filter { pinnedMatch($0, context) }
    }

    private static func isOnEdge(_ note: Note, now: Date) -> Bool {
        note.onEdge && note.completedAt == nil && (note.snoozedUntil.map { $0 <= now } ?? true)
    }

    private static func pinnedMatch(_ note: Note, _ context: ContextKey?) -> Bool {
        note.pinnedToContext && matches(note, context)
    }

    private static func matches(_ note: Note, _ context: ContextKey?) -> Bool {
        guard let context else { return false }
        let sameApp = note.appBundleId != nil && note.appBundleId == context.appBundleId
        let sameSite = note.siteHost != nil && normalized(note.siteHost) == normalized(context.siteHost)
        return sameApp || sameSite
    }

    private static func normalized(_ host: String?) -> String? {
        host?.lowercased().replacing(/^www\./, with: "")
    }
}

/// Due date first (no date last), then newest.
enum NoteOrder {
    static func isBefore(_ first: Note, _ second: Note) -> Bool {
        switch (first.dueAt, second.dueAt) {
        case let (firstDue?, secondDue?) where firstDue != secondDue: return firstDue < secondDue
        case (.some, nil): return true
        case (nil, .some): return false
        default: return first.updatedAt > second.updatedAt
        }
    }
}
