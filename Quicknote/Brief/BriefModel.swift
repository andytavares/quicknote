import AVFoundation
import Foundation
import QuicknoteKit

/// The Brief's data and read-aloud state. `refresh()` rebuilds it from notes and today's events.
@MainActor @Observable
final class BriefModel: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var brief: DailyBrief
    private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()
    private var repository: NoteRepository { NoteRepository(database: AppEnvironment.current.database) }

    override init() {
        brief = DailyBriefBuilder.build(notes: [], events: [], day: BriefDay(now: Date(), calendar: .current))
        super.init()
        synthesizer.delegate = self
        refresh()
    }

    func refresh() {
        let notes =
            ((try? repository.notes(matching: .inbox)) ?? []) + ((try? repository.notes(matching: .completed)) ?? [])
        let day = BriefDay(now: Date(), calendar: .current)
        brief = DailyBriefBuilder.build(notes: notes, events: CalendarBridge.shared.eventsToday(), day: day)
    }

    /// Checks an open item off (a repeating one moves to its next date) or reopens a completed one.
    func toggle(_ item: BriefItem) {
        guard let noteId = item.noteId, var note = try? repository.note(id: noteId) else { return }
        if item.isCompleted {
            note.completedAt = nil
        } else {
            note = note.completing(now: Date(), calendar: .current)
        }
        try? repository.save(&note, now: Date())
        refresh()
    }

    func toggleReadAloud() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        } else {
            synthesizer.speak(AVSpeechUtterance(string: brief.spokenText(calendar: .current)))
        }
        isSpeaking = synthesizer.isSpeaking
    }

    func stopReadAloud() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in isSpeaking = false }
    }
}
