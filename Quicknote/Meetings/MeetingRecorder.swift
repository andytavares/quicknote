import Foundation
import Observation
import QuicknoteKit

/// What the pill shows once a recording is saved.
struct RecordingOutcome: Equatable {
    var meetingId: Int64
    var summaryNote: String?
}

/// Records a meeting: one source per input, each with its own transcriber and audio file (S17).
@Observable
final class MeetingRecorder {
    private(set) var timeline = RecorderTimeline()
    private(set) var title = ""
    private(set) var hasMicrophone = false
    private(set) var hasMacAudio = false
    private(set) var macAudioIsSilent = false
    private(set) var bookmarkedAtMs: Int?
    private(set) var progress: String?
    private(set) var problem: String?
    private(set) var outcome: RecordingOutcome?

    @ObservationIgnored private(set) var meetingId: Int64?
    @ObservationIgnored private var sources: [RecordingSource] = []
    @ObservationIgnored private var consumers: [Task<Void, Never>] = []
    @ObservationIgnored private let microphone = MicrophoneCapture()
    @ObservationIgnored private let macAudio = SystemAudioTap()
    @ObservationIgnored private let pill = RecorderPill()
    @ObservationIgnored private var repository: MeetingRepository {
        MeetingRepository(database: AppEnvironment.current.database)
    }

    var isRecording: Bool { timeline.phase == .recording || timeline.phase == .paused }

    func level(of speaker: Speaker) -> Float { sources.first { $0.speaker == speaker }?.level ?? 0 }

    func elapsedMs(at date: Date = Date()) -> Int { timeline.elapsedMs(at: date) }

    // MARK: Start

    func start(title: String, microphone wantsMicrophone: Bool, macAudio wantsMacAudio: Bool) async {
        guard timeline.phase == .idle else { return }
        outcome = nil
        problem = nil
        let readiness = await grantedSources(microphone: wantsMicrophone, macAudio: wantsMacAudio)
        guard readiness.microphone || readiness.macAudio else {
            return show(problem: "Nothing to record: allow the Microphone or turn on Mac audio.")
        }
        do {
            try begin(title: title, microphone: readiness.microphone, macAudio: readiness.macAudio)
        } catch {
            await cancelStart()
            show(problem: error.localizedDescription)
        }
    }

    private func grantedSources(microphone: Bool, macAudio: Bool) async -> (microphone: Bool, macAudio: Bool) {
        _ = await Permissions.ensure(.speechRecognition)
        let granted = microphone ? await Permissions.ensure(.microphone) : false
        return (granted, macAudio)
    }

    private func begin(title: String, microphone wantsMicrophone: Bool, macAudio wantsMacAudio: Bool) throws {
        let meeting = try repository.start(title: title, at: Date())
        let folder = AppEnvironment.current.paths.attachments.appending(path: "meetings/\(meeting.id!)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        meetingId = meeting.id
        self.title = title
        hasMicrophone = wantsMicrophone
        hasMacAudio = wantsMacAudio
        _ = timeline.start(at: Date())
        pill.show(for: self)
        if wantsMicrophone { try startMicrophone(in: folder) }
        if wantsMacAudio { startMacAudio(in: folder) }
        pill.announce("Recording \(title)")
    }

    private func startMicrophone(in folder: URL) throws {
        let source = RecordingSource(speaker: .me, fileURL: folder.appending(path: "me.caf"))
        try microphone.start { source.receive($0) }
        track(source)
    }

    private func startMacAudio(in folder: URL) {
        let source = RecordingSource(speaker: .others, fileURL: folder.appending(path: "others.caf")) { verdict in
            Task { @MainActor in self.hear(verdict) }
        }
        do {
            try macAudio.start { source.receive($0) }
            track(source)
        } catch {
            hasMacAudio = false
            problem = error.localizedDescription
        }
    }

    private func track(_ source: RecordingSource) {
        sources.append(source)
        guard let meetingId else { return }
        consumers.append(
            Task {
                do { try await source.transcriber.start() } catch {
                    source.stopTranscribing()
                    problem =
                        "No transcript for \(source.speaker == .me ? "your microphone" : "Mac audio"): \(error.localizedDescription)"
                    return
                }
                for await update in source.transcriber.updates {
                    if case .line(let line) = update { try? repository.append([line], to: meetingId) }
                }
            })
    }

    private func hear(_ verdict: SilenceDetector.Verdict) {
        macAudioIsSilent = verdict == .silent
        Permissions.recordSystemAudioResult(allowed: verdict == .heardAudio)
        if verdict == .silent { pill.announce("No Mac audio is coming through") }
    }

    // MARK: While recording

    func togglePause() {
        let now = Date()
        let changed = timeline.phase == .paused ? timeline.resume(at: now) : timeline.pause(at: now)
        guard changed else { return }
        sources.forEach { $0.setPaused(timeline.phase == .paused) }
        pill.announce(timeline.phase == .paused ? "Paused" : "Recording")
    }

    func bookmark() {
        guard timeline.canBookmark, let meetingId else { return }
        let atMs = elapsedMs()
        guard (try? repository.addBookmark(at: atMs, to: meetingId)) != nil else { return }
        bookmarkedAtMs = atMs
        pill.announce("Bookmarked at \(MeetingTime.format(ms: atMs))")
        Task {
            try? await Task.sleep(for: .seconds(4))
            if bookmarkedAtMs == atMs { bookmarkedAtMs = nil }
        }
    }

    // MARK: Stop

    func stop() async {
        guard timeline.stop(at: Date()), let meetingId else { return }
        pill.announce("Saving the meeting")
        microphone.stop()
        macAudio.stop()
        progress = "Finishing transcript…"
        await finishTranscription()
        progress = "Saving audio…"
        let audioPath = await mixAudio(meetingId: meetingId)
        let recording = FinishedRecording(durationMs: elapsedMs(), audioPath: audioPath)
        _ = try? repository.finish(meetingId: meetingId, recording: recording)
        let summaryNote = await summarise(meetingId: meetingId)
        reset(outcome: RecordingOutcome(meetingId: meetingId, summaryNote: summaryNote))
    }

    private func finishTranscription() async {
        for source in sources where (try? await source.transcriber.finish()) == nil {
            await source.transcriber.cancel()
        }
        for consumer in consumers { await consumer.value }
        sources.forEach { $0.closeFile() }
    }

    /// Relative to the attachments folder; empty when no audio could be saved.
    private func mixAudio(meetingId: Int64) async -> String {
        let relative = "meetings/\(meetingId)"
        let folder = AppEnvironment.current.paths.attachments.appending(path: relative)
        let inputs = ["me.caf", "others.caf"].map { folder.appending(path: $0) }
        do {
            try await MeetingAudioMixer.mix(inputs, into: folder.appending(path: "meeting.m4a"))
            inputs.forEach { try? FileManager.default.removeItem(at: $0) }
            return "\(relative)/meeting.m4a"
        } catch {
            problem = error.localizedDescription
            return ""
        }
    }

    /// A note for the pill when there is no summary, nil when one was stored.
    private func summarise(meetingId: Int64) async -> String? {
        guard MeetingSummarizer.isAvailable else {
            return "No summary: on-device summaries are not available on this Mac."
        }
        progress = "Summarising on this Mac…"
        do {
            let segments = try repository.segments(of: meetingId)
            guard let summary = try await MeetingSummarizer.summary(of: segments) else {
                return "No summary: nothing was said."
            }
            try repository.setSummary(summary, for: meetingId)
            return nil
        } catch {
            return "No summary: \(error.localizedDescription)"
        }
    }

    private func reset(outcome: RecordingOutcome) {
        timeline.finished()
        sources = []
        consumers = []
        progress = nil
        macAudioIsSilent = false
        self.outcome = outcome
        pill.announce("Meeting saved")
    }

    private func cancelStart() async {
        microphone.stop()
        macAudio.stop()
        for source in sources { await source.transcriber.cancel() }
        consumers.forEach { $0.cancel() }
        sources = []
        consumers = []
        timeline.finished()
        pill.hide()
        if let meetingId, let meeting = try? repository.meeting(id: meetingId) {
            try? NoteRepository(database: AppEnvironment.current.database).delete(noteId: meeting.noteId)
        }
        meetingId = nil
    }

    private func show(problem message: String) {
        problem = message
        pill.show(for: self)
        pill.announce(message)
    }

    func dismissOutcome() {
        outcome = nil
        problem = nil
        if timeline.phase == .idle { pill.hide() }
    }
}
