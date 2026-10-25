import Foundation
import Testing

@testable import QuicknoteKit

struct EdgeFilterTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let xcode = ContextKey(appBundleId: "com.apple.dt.Xcode", siteHost: nil)

    private func note(
        _ body: String, due: TimeInterval? = nil, age: TimeInterval = 0,
        _ configure: (inout Note) -> Void = { _ in }
    ) -> Note {
        var note = Note(body: body, now: now.addingTimeInterval(-age))
        note.dueAt = due.map { now.addingTimeInterval($0) }
        configure(&note)
        return note
    }

    private func titles(_ notes: [Note]) -> [String] { notes.map(\.title) }

    @Test func hidesOffEdgeCompletedAndSnoozedNotes() {
        let notes = [
            note("shown"),
            note("off") { $0.onEdge = false },
            note("done") { $0.completedAt = now },
            note("snoozed") { $0.snoozedUntil = now.addingTimeInterval(60) },
            note("woke") { $0.snoozedUntil = now.addingTimeInterval(-60) },
        ]
        #expect(Set(titles(EdgeFilter.visibleNotes(notes, context: nil, now: now))) == ["shown", "woke"])
    }

    @Test func pinnedNotesNeedMatchingContext() {
        let pinned = note("xcode only") {
            $0.pinnedToContext = true
            $0.appBundleId = "com.apple.dt.Xcode"
        }
        #expect(EdgeFilter.visibleNotes([pinned], context: nil, now: now).isEmpty)
        let other = ContextKey(appBundleId: "com.apple.Safari", siteHost: nil)
        #expect(EdgeFilter.visibleNotes([pinned], context: other, now: now).isEmpty)
        #expect(titles(EdgeFilter.visibleNotes([pinned], context: xcode, now: now)) == ["xcode only"])
    }

    @Test func siteHostMatchIgnoresLeadingWww() {
        let pinned = note("site") {
            $0.pinnedToContext = true
            $0.siteHost = "www.example.com"
        }
        let bare = ContextKey(appBundleId: nil, siteHost: "example.com")
        let prefixed = ContextKey(appBundleId: nil, siteHost: "WWW.Example.com")
        let different = ContextKey(appBundleId: nil, siteHost: "wwwexample.com")
        #expect(EdgeFilter.visibleNotes([pinned], context: bare, now: now).count == 1)
        #expect(EdgeFilter.visibleNotes([pinned], context: prefixed, now: now).count == 1)
        #expect(EdgeFilter.visibleNotes([pinned], context: different, now: now).isEmpty)
    }

    @Test func pinnedNoteWithNoAppOrSiteNeverMatches() {
        let pinned = note("orphan") { $0.pinnedToContext = true }
        #expect(EdgeFilter.visibleNotes([pinned], context: ContextKey(), now: now).isEmpty)
    }

    @Test func ordersContextThenDueThenNewest() {
        let contextual = note("context", age: 500) {
            $0.pinnedToContext = true
            $0.appBundleId = "com.apple.dt.Xcode"
        }
        let notes = [
            note("newest", age: 1),
            note("old", age: 100),
            note("due later", due: 200),
            note("due soon", due: 100),
            contextual,
        ]
        let visible = EdgeFilter.visibleNotes(notes, context: xcode, now: now)
        #expect(titles(visible) == ["context", "due soon", "due later", "newest", "old"])
    }

    @Test func contextNotesAreOnlyTheMatchingPinnedOnes() {
        let match = note("match") {
            $0.pinnedToContext = true
            $0.appBundleId = "com.apple.dt.Xcode"
        }
        let unpinned = note("unpinned") { $0.appBundleId = "com.apple.dt.Xcode" }
        let snoozed = note("snoozed") {
            $0.pinnedToContext = true
            $0.appBundleId = "com.apple.dt.Xcode"
            $0.snoozedUntil = now.addingTimeInterval(60)
        }
        let result = EdgeFilter.contextNotes([match, unpinned, snoozed], context: xcode, now: now)
        #expect(titles(result) == ["match"])
        #expect(EdgeFilter.contextNotes([match], context: nil, now: now).isEmpty)
    }
}
