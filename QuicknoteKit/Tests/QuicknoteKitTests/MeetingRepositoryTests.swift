import Foundation
import GRDB
import Testing

@testable import QuicknoteKit

struct MeetingRepositoryTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func makeRepository() throws -> (MeetingRepository, AppDatabase) {
        let database = try AppDatabase.inMemory()
        return (MeetingRepository(database: database), database)
    }

    @Test func startCreatesAnOffEdgeNoteAndTheMeeting() throws {
        let (repository, database) = try makeRepository()
        let meeting = try repository.start(title: "Design sync", at: now)
        let note = try database.writer.read { try Note.fetchOne($0, key: meeting.noteId) }
        #expect(note?.body == "Design sync")
        #expect(note?.kind == .note)
        #expect(note?.onEdge == false)
        #expect(try repository.meeting(id: meeting.id!)?.startedAt == now)
    }

    @Test func appendStoresSegmentsInOrder() throws {
        let (repository, _) = try makeRepository()
        let id = try repository.start(title: "Sync", at: now).id!
        try repository.append(
            [
                SpokenLine(span: 0..<2_000, speaker: .me, text: "Hello"),
                SpokenLine(span: 2_000..<4_000, speaker: .others, text: "Hi"),
            ], to: id)
        let segments = try repository.segments(of: id)
        #expect(segments.map(\.text) == ["Hello", "Hi"])
        #expect(segments.map(\.speaker) == [.me, .others])
    }

    @Test func bookmarksCanBeLabelled() throws {
        let (repository, _) = try makeRepository()
        let id = try repository.start(title: "Sync", at: now).id!
        let later = try repository.addBookmark(at: 90_000, to: id)
        _ = try repository.addBookmark(at: 10_000, to: id)
        try repository.label(bookmarkId: later.id!, as: "Budget")
        let bookmarks = try repository.bookmarks(of: id)
        #expect(bookmarks.map(\.atMs) == [10_000, 90_000])
        #expect(bookmarks.map(\.label) == [nil, "Budget"])
    }

    @Test func finishStoresRecordingAndCreatesLinkedTasks() throws {
        let (repository, _) = try makeRepository()
        let id = try repository.start(title: "Sync", at: now).id!
        try repository.append(
            [
                SpokenLine(span: 0..<2_000, speaker: .others, text: "We talked about the weather."),
                SpokenLine(
                    span: 1_112_000..<1_118_000, speaker: .others,
                    text: "Action item: Dana will send the estimate by Friday."),
            ], to: id)
        let recording = FinishedRecording(durationMs: 1_200_000, audioPath: "meetings/1.m4a")
        let tasks = try repository.finish(meetingId: id, recording: recording)

        #expect(tasks.count == 1)
        #expect(tasks[0].kind == .task)
        #expect(tasks[0].body == "Dana will send the estimate by Friday.")
        #expect(tasks[0].sourceMeetingId == id)
        #expect(tasks[0].sourceMs == 1_112_000)
        #expect(tasks[0].dueAt != nil)
        #expect(tasks[0].onEdge)
        let meeting = try #require(try repository.meeting(id: id))
        #expect(meeting.durationMs == 1_200_000)
        #expect(meeting.audioPath == "meetings/1.m4a")
        #expect(try repository.actionItemTasks(of: id).map(\.id) == tasks.map(\.id))
    }

    @Test func finishingTwiceDoesNotDuplicateTasks() throws {
        let (repository, database) = try makeRepository()
        let id = try repository.start(title: "Sync", at: now).id!
        try repository.append([SpokenLine(span: 0..<1_000, speaker: .me, text: "I'll book the room.")], to: id)
        let recording = FinishedRecording(durationMs: 5_000, audioPath: "a.m4a")
        let first = try repository.finish(meetingId: id, recording: recording)
        let second = try repository.finish(meetingId: id, recording: recording)
        #expect(second.map(\.id) == first.map(\.id))
        let taskCount = try database.writer.read { try Note.filter(Column("kind") == NoteKind.task).fetchCount($0) }
        #expect(taskCount == 1)
    }

    @Test func summaryIsStored() throws {
        let (repository, _) = try makeRepository()
        let id = try repository.start(title: "Sync", at: now).id!
        try repository.setSummary("Short recap", for: id)
        #expect(try repository.meeting(id: id)?.summary == "Short recap")
    }

    @Test func allListsNewestFirst() throws {
        let (repository, _) = try makeRepository()
        _ = try repository.start(title: "Old", at: now)
        _ = try repository.start(title: "New", at: now.addingTimeInterval(3_600))
        #expect(try repository.all().map(\.title) == ["New", "Old"])
    }
}
