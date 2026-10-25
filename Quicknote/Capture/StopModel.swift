import Foundation
import Observation
import QuicknoteKit

/// State behind Save where you stopped.
@Observable
final class StopModel {
    var stop = StopNote()
    var lastStop: Note?
    var onClose: () -> Void = {}

    func prepare(context: CapturedContext?) {
        stop = StopNote(context: context)
        lastStop = previousStop(for: context?.appBundleId)
    }

    func save() {
        guard !stop.isEmpty else { return }
        var note = stop.makeNote(now: Date())
        try? NoteRepository(database: AppEnvironment.current.database).save(&note, now: Date())
        onClose()
    }

    /// The newest saved stop for the same app, if any.
    private func previousStop(for bundleId: String?) -> Note? {
        guard let bundleId else { return nil }
        let notes = try? NoteRepository(database: AppEnvironment.current.database).notes(matching: .kind(.context))
        return notes?.first { $0.appBundleId == bundleId }
    }
}
