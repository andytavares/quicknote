import Foundation
import QuicknoteKit
import Testing

@testable import Quicknote

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2
    return calendar
}()

/// Wednesday 2026-10-28 14:00 UTC; the week runs Monday 26th to Sunday 1 Nov.
private let now = Date(timeIntervalSince1970: 1_793_196_000)

private func task(_ body: String, dueInDays days: Double? = nil, hasTime: Bool = false, hours: Double = 0) -> Note {
    var note = Note(body: body, kind: .task, now: now)
    let midnight = calendar.startOfDay(for: now)
    note.dueAt = days.map { midnight.addingTimeInterval($0 * 86_400 + hours * 3_600) }
    note.dueHasTime = hasTime
    return note
}

private let grouper = TaskGrouper(
    now: now, calendar: calendar,
    projects: [Project(name: "Home"), Project(name: "Lisbon trip")].enumerated().map { index, project in
        var project = project
        project.id = Int64(index + 1)
        return project
    })

struct LibraryTests {
    @Test func dueDateGroupsFollowFixedOrder() {
        let notes = [
            task("later", dueInDays: 10),
            task("none"),
            task("friday", dueInDays: 2, hours: 9),
            task("today", dueInDays: 0, hours: 18),
            task("yesterday", dueInDays: -1, hours: 9),
        ]
        let groups = grouper.groups(notes, by: .dueDate)
        #expect(groups.map(\.title) == ["Overdue", "Today", "This week", "Later", "No date"])
        #expect(groups.map { $0.notes.map(\.body) } == [["yesterday"], ["today"], ["friday"], ["later"], ["none"]])
    }

    @Test func timedTaskEarlierTodayIsOverdueButUntimedIsToday() {
        let timed = task("timed", dueInDays: 0, hasTime: true, hours: 9)
        let untimed = task("untimed", dueInDays: 0, hours: 9)
        let groups = grouper.groups([timed, untimed], by: .dueDate)
        #expect(groups.map(\.title) == ["Overdue", "Today"])
        #expect(grouper.isOverdue(timed))
        #expect(!grouper.isOverdue(untimed))
    }

    @Test func sundayIsThisWeekAndMondayIsLater() {
        let groups = grouper.groups([task("sunday", dueInDays: 4), task("monday", dueInDays: 5)], by: .dueDate)
        #expect(groups.map(\.title) == ["This week", "Later"])
    }

    @Test func projectGroupsFollowProjectOrderThenNoProject() {
        var lisbon = task("passport")
        lisbon.projectId = 2
        var home = task("plants")
        home.projectId = 1
        let groups = grouper.groups([lisbon, task("loose"), home], by: .project)
        #expect(groups.map(\.title) == ["Home", "Lisbon trip", "No project"])
    }

    @Test func priorityGroupsRunHighToNone() {
        var high = task("high")
        high.priority = 3
        var low = task("low")
        low.priority = 1
        let groups = grouper.groups([task("none"), low, high], by: .priority)
        #expect(groups.map(\.title) == ["High", "Low", "No priority"])
    }

    @Test func sidebarSectionsMapToRepositoryQueries() {
        #expect(LibrarySection.inbox.filter == .inbox)
        #expect(LibrarySection.tasks.filter == .kind(.task))
        #expect(LibrarySection.reminders.filter == .kind(.reminder))
        #expect(LibrarySection.events.filter == .kind(.event))
        #expect(LibrarySection.ideas.filter == .kind(.idea))
        #expect(LibrarySection.bookmarks.filter == .kind(.bookmark))
        #expect(LibrarySection.bugs.filter == .kind(.bug))
        #expect(LibrarySection.project(7).filter == .project(7))
        #expect(LibrarySection.completed.filter == .completed)
        let notNoteLists: [LibrarySection] = [.brief, .meetings, .snaps, .cards, .sites]
        #expect(notNoteLists.allSatisfy { $0.filter == nil })
        #expect(LibrarySection.snaps.galleryKind == .snap && LibrarySection.cards.galleryKind == .card)
    }

    @Test func openingANoteSelectsTheSectionOfItsType() {
        let expected: [NoteKind: LibrarySection] = [
            .note: .inbox, .todoList: .inbox, .context: .inbox, .task: .tasks, .reminder: .reminders,
            .event: .events, .idea: .ideas, .bookmark: .bookmarks, .bug: .bugs,
        ]
        for kind in NoteKind.allCases {
            #expect(LibrarySection.containing(Note(body: "x", kind: kind)) == expected[kind])
        }
    }

    @Test func openingACompletedNoteSelectsCompleted() {
        var done = Note(body: "done", kind: .task)
        done.completedAt = now
        #expect(LibrarySection.containing(done) == .completed)
    }

    @Test func galleryClassifiesSnapsCardsAndPlainNotes() {
        var snap = Note(body: "snap")
        snap.canvas = CanvasDocument(background: .image(attachmentId: 1, size: CGSize(width: 10, height: 10)))
        var card = Note(body: "card")
        card.canvas = CanvasDocument(background: .card(style: .sticky, size: .square))
        var broken = Note(body: "broken")
        broken.canvasJSON = "{not json"
        #expect(GalleryKind.classify(snap) == .snap)
        #expect(GalleryKind.classify(card) == .card)
        #expect(GalleryKind.classify(Note(body: "plain")) == nil)
        #expect(GalleryKind.classify(broken) == nil)
    }

    @Test func detailLineShowsKindDueAndOverdueDays() {
        #expect(grouper.detail(for: task("a", dueInDays: -2, hours: 9)) == "Task · overdue 2 days")
        #expect(grouper.detail(for: task("b")) == "Task")
        var slack = task("c")
        slack.appName = "Slack"
        #expect(grouper.detail(for: slack) == "Task · Slack")
    }
}
