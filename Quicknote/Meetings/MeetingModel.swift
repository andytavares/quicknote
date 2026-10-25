import AVFoundation
import AppKit
import Observation
import QuicknoteKit
import UniformTypeIdentifiers

/// State of one meeting detail window (S18): the stored meeting plus the player.
@Observable
final class MeetingModel {
    enum Tab: Hashable { case transcript, summary, bookmarks }

    private(set) var meeting: Meeting
    private(set) var segments: [TranscriptSegment] = []
    private(set) var bookmarks: [MeetingBookmark] = []
    private(set) var tasks: [Note] = []
    private(set) var currentMs = 0
    private(set) var isPlaying = false
    var tab = Tab.transcript
    var problem: String?

    @ObservationIgnored private let player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private let meetings: MeetingRepository
    @ObservationIgnored private let notes: NoteRepository

    init(meeting: Meeting, atMs: Int, environment: AppEnvironment = .current) {
        self.meeting = meeting
        meetings = MeetingRepository(database: environment.database)
        notes = NoteRepository(database: environment.database)
        let audioPath = meeting.audioPath ?? ""
        player = audioPath.isEmpty ? nil : AVPlayer(url: environment.paths.attachments.appending(path: audioPath))
        reload()
        observePlayback()
        seek(toMs: atMs)
    }

    var hasAudio: Bool { player != nil }
    var durationMs: Int { meeting.durationMs }
    var currentRow: Int? { TranscriptNavigator.currentRow(atMs: currentMs, in: segments) }

    func close() {
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
    }

    // MARK: Playback

    func seek(toMs ms: Int) {
        currentMs = max(0, ms)
        player?.seek(
            to: CMTime(value: CMTimeValue(currentMs), timescale: 1_000), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func seek(toRow row: Int) {
        if let ms = TranscriptNavigator.startMs(ofRow: row, in: segments) { seek(toMs: ms) }
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    private func observePlayback() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 4), queue: .main) {
            [weak self] time in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying, time.isNumeric else { return }
                self.currentMs = Int(time.seconds * 1_000)
                if self.player?.rate == 0 { self.isPlaying = false }
            }
        }
    }

    // MARK: Editing

    func reload() {
        let id = meeting.id!
        meeting = (try? meetings.meeting(id: id)) ?? meeting
        segments = (try? meetings.segments(of: id)) ?? []
        bookmarks = (try? meetings.bookmarks(of: id)) ?? []
        tasks = (try? meetings.actionItemTasks(of: id)) ?? []
    }

    func toggle(task: Note) {
        var changed = task
        changed.completedAt = task.completedAt == nil ? Date() : nil
        save(&changed)
    }

    /// A task linked to the current playhead.
    func addActionItem(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var task = Note(body: trimmed, kind: .task)
        task.sourceMeetingId = meeting.id
        task.sourceMs = currentMs
        save(&task)
    }

    func label(of bookmark: MeetingBookmark) -> String { bookmark.label ?? "" }

    func setLabel(_ label: String, of bookmark: MeetingBookmark) {
        guard let id = bookmark.id else { return }
        try? meetings.label(bookmarkId: id, as: label)
        reload()
    }

    private func save(_ task: inout Note) {
        do { try notes.save(&task, now: Date()) } catch { problem = error.localizedDescription }
        reload()
    }

    // MARK: Export

    func export(_ kind: MeetingExport) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = kind.fileName(title: meeting.title, startedAt: meeting.startedAt)
        panel.allowedContentTypes = UTType(filenameExtension: kind.fileExtension).map { [$0] } ?? []
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do { try write(kind, to: destination) } catch { problem = error.localizedDescription }
    }

    private func write(_ kind: MeetingExport, to destination: URL) throws {
        let transcript = MeetingTranscript(
            segments: segments, bookmarks: bookmarks,
            actionItems: tasks.map { ActionItem(text: $0.body, atMs: $0.sourceMs ?? 0, due: $0.dueAt) })
        if let text = kind.text(meeting: meeting, transcript: transcript) {
            try text.write(to: destination, atomically: true, encoding: .utf8)
        } else if let audioPath = meeting.audioPath, !audioPath.isEmpty {
            let source = AppEnvironment.current.paths.attachments.appending(path: audioPath)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
        } else {
            throw MeetingAudioMixerError.noAudio
        }
    }
}
