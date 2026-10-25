import Foundation
import QuicknoteKit

/// The three fields of Save where you stopped, and the note they become.
struct StopNote {
    var done = ""
    var blocked = ""
    var next = ""
    var context: CapturedContext?

    var isEmpty: Bool { [done, blocked, next].allSatisfy { $0.allSatisfy(\.isWhitespace) } }

    var title: String {
        context?.appName.map { "Where I stopped — \($0)" } ?? "Where I stopped"
    }

    var body: String {
        let lines = [("Done", done), ("Blocked", blocked), ("Next", next)].map { label, value in
            "\(label): \(value.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return ([title] + lines).joined(separator: "\n")
    }

    func makeNote(now: Date) -> Note {
        var note = Note(body: body, kind: .context, now: now)
        note.remember(context)
        return note
    }
}
