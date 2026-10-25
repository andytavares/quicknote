import Foundation
import Testing

@testable import QuicknoteKit

struct MarkdownExporterTests {
    private let moment = Date(timeIntervalSince1970: 1_700_000_000)

    @Test func roundTripKeepsBodyLinksAndAttachmentFiles() throws {
        let temporary = try TemporaryPaths()
        defer { temporary.remove() }
        let database = try AppDatabase.inMemory()
        var note = Note(body: "Lisbon trip\nSee [[Flights]] for times", kind: .task, now: moment)
        note.appName = "Safari"
        try database.writer.write { db in try note.insert(db) }
        let store = AttachmentStore(paths: temporary.paths, database: database)
        let image = try store.attach(
            fileAt: try temporary.makeFile(named: "map.png", contents: "PNG"), to: note.id!, kind: .image)
        let file = try store.attach(
            fileAt: try temporary.makeFile(named: "pass.pdf", contents: "PDF"), to: note.id!, kind: .file)
        let folder = temporary.scratch.appending(path: "out")

        let url = try MarkdownExporter(paths: temporary.paths).export(note, attachments: [image, file], to: folder)

        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(url.lastPathComponent == "lisbon-trip.md")
        #expect(text.hasPrefix("---\nkind: task\n"))
        #expect(text.contains("app: \"Safari\"\n"))
        #expect(text.contains("Lisbon trip\nSee [[Flights]] for times"))
        #expect(text.contains("![map.png](lisbon-trip/map.png)"))
        #expect(text.contains("[pass.pdf](lisbon-trip/pass.pdf)"))
        #expect(!text.contains("![pass.pdf]"))
        let copied = try FileManager.default.contentsOfDirectory(atPath: folder.appending(path: "lisbon-trip").path)
        #expect(copied.sorted() == ["map.png", "pass.pdf"])
    }

    @Test func frontMatterOmitsEmptyFieldsAndKeepsRecurrenceJSON() throws {
        let temporary = try TemporaryPaths()
        defer { temporary.remove() }
        var note = Note(body: "Water plants", kind: .reminder, now: moment)
        note.recurrenceJSON = #"{"every":"week"}"#
        note.dueAt = moment
        note.projectId = 7

        let url = try MarkdownExporter(paths: temporary.paths).export(note, attachments: [], to: temporary.scratch)

        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("created: 2023-11-14T22:13:20Z\n"))
        #expect(text.contains("due: 2023-11-14T22:13:20Z\n"))
        #expect(text.contains(#"recurrenceJSON: "{\"every\":\"week\"}""#))
        #expect(text.contains("project: 7\n"))
        #expect(!text.contains("site:"))
        #expect(!text.contains("url:"))
        #expect(!text.contains("app:"))
    }

    @Test func slugsAreFilesystemSafeAndUniqueInTheFolder() throws {
        let temporary = try TemporaryPaths()
        defer { temporary.remove() }
        let exporter = MarkdownExporter(paths: temporary.paths)

        let first = try exporter.export(Note(body: "A/B: c?"), attachments: [], to: temporary.scratch)
        let second = try exporter.export(Note(body: "A/B: c?"), attachments: [], to: temporary.scratch)
        let untitled = try exporter.export(Note(body: "???"), attachments: [], to: temporary.scratch)

        #expect(first.lastPathComponent == "a-b-c.md")
        #expect(second.lastPathComponent == "a-b-c-2.md")
        #expect(untitled.lastPathComponent == "note.md")
    }

    @Test func exportAllWritesEveryNoteWithItsAttachments() throws {
        let temporary = try TemporaryPaths()
        defer { temporary.remove() }
        let database = try AppDatabase.inMemory()
        let ids = try database.writer.write { db -> [Int64] in
            try ["One", "Two", "Three"].map { body in
                var note = Note(body: body)
                try note.insert(db)
                return note.id!
            }
        }
        _ = try AttachmentStore(paths: temporary.paths, database: database)
            .attach(fileAt: try temporary.makeFile(named: "a.txt"), to: ids[1], kind: .file)
        let folder = temporary.scratch.appending(path: "all")

        let count = try MarkdownExporter(paths: temporary.paths).exportAll(database: database, to: folder)

        #expect(count == 3)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(names == ["one.md", "three.md", "two", "two.md"])
    }
}
