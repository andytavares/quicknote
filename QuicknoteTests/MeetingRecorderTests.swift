import AVFoundation
import QuicknoteKit
import Testing

@testable import Quicknote

struct RecorderTimelineTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func walksIdleRecordingPausedRecordingFinishingIdle() {
        var timeline = RecorderTimeline()
        var phases = [timeline.phase]
        _ = timeline.start(at: start)
        phases.append(timeline.phase)
        _ = timeline.pause(at: start + 10)
        phases.append(timeline.phase)
        _ = timeline.resume(at: start + 20)
        phases.append(timeline.phase)
        _ = timeline.stop(at: start + 30)
        phases.append(timeline.phase)
        timeline.finished()
        phases.append(timeline.phase)
        #expect(phases == [.idle, .recording, .paused, .recording, .finishing, .idle])
    }

    @Test func refusesTransitionsThatDoNotApply() {
        var timeline = RecorderTimeline()
        let results = [
            timeline.pause(at: start), timeline.resume(at: start), timeline.stop(at: start),
            timeline.start(at: start), timeline.start(at: start), timeline.resume(at: start),
        ]
        #expect(results == [false, false, false, true, false, false])
    }

    @Test func bookmarksOnlyWhileRecording() {
        var timeline = RecorderTimeline()
        var canBookmark = [timeline.canBookmark]
        _ = timeline.start(at: start)
        canBookmark.append(timeline.canBookmark)
        _ = timeline.pause(at: start + 5)
        canBookmark.append(timeline.canBookmark)
        _ = timeline.resume(at: start + 6)
        _ = timeline.stop(at: start + 7)
        canBookmark.append(timeline.canBookmark)
        #expect(canBookmark == [false, true, false, false])
    }

    @Test func elapsedTimeLeavesOutPausedTime() {
        var timeline = RecorderTimeline()
        _ = timeline.start(at: start)
        let running = timeline.elapsedMs(at: start + 4)
        _ = timeline.pause(at: start + 10)
        let whilePaused = timeline.elapsedMs(at: start + 500)
        _ = timeline.resume(at: start + 70)
        let afterResume = timeline.elapsedMs(at: start + 75)
        _ = timeline.stop(at: start + 80)
        let afterStop = timeline.elapsedMs(at: start + 999)
        let measured: [Int] = [running, whilePaused, afterResume, afterStop]
        #expect(measured == [4_000, 10_000, 15_000, 20_000])
    }
}

struct SilenceDetectorTests {
    private func buffer(amplitude: Float, seconds: Double) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 1_000, channels: 2)!
        let frames = AVAudioFrameCount(seconds * 1_000)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channel in 0..<2 { for frame in 0..<Int(frames) { buffer.floatChannelData![channel][frame] = amplitude } }
        return buffer
    }

    private func verdicts(window: Double, _ buffers: [(Float, Double)]) -> [SilenceDetector.Verdict?] {
        var detector = SilenceDetector(window: window)
        return buffers.map { detector.feed(buffer(amplitude: $0.0, seconds: $0.1)) }
    }

    @Test func reportsSilenceOnceAfterTheWindow() {
        let expected: [SilenceDetector.Verdict?] = [nil, .silent, nil]
        #expect(verdicts(window: 3, [(0, 2), (0, 1), (0, 1)]) == expected)
    }

    @Test func reportsAudioAsSoonAsItIsHeard() {
        let expected: [SilenceDetector.Verdict?] = [nil, .heardAudio, nil]
        #expect(verdicts(window: 3, [(0, 1), (0.2, 0.1), (0, 5)]) == expected)
    }

    @Test func audioAfterTheSilentVerdictClearsIt() {
        let expected: [SilenceDetector.Verdict?] = [.silent, .heardAudio]
        #expect(verdicts(window: 1, [(0, 1), (0.3, 0.1)]) == expected)
    }

    @Test func treatsHissBelowTheThresholdAsSilence() {
        let expected: [SilenceDetector.Verdict?] = [.silent]
        #expect(verdicts(window: 1, [(0.00001, 1)]) == expected)
    }
}

struct SummaryChunkerTests {
    @Test func keepsEveryChunkUnderTheBudgetInOrderWithoutSplittingLines() {
        let lines = (1...20).map { "[00:\($0)] Me: line number \($0)" }
        let chunks = SummaryChunker.chunks(of: lines, maxCharacters: 100)
        #expect(chunks.allSatisfy { $0.count <= 100 })
        #expect(chunks.count > 1)
        #expect(chunks.joined(separator: "\n").split(separator: "\n").map(String.init) == lines)
    }

    @Test func aSingleLongLineStaysWholeInItsOwnChunk() {
        let long = String(repeating: "x", count: 50)
        #expect(SummaryChunker.chunks(of: ["a", long, "b"], maxCharacters: 10) == ["a", long, "b"])
    }

    @Test func emptyTranscriptHasNoChunks() {
        #expect(SummaryChunker.chunks(of: [], maxCharacters: 100).isEmpty)
    }
}

struct TranscriptNavigatorTests {
    private func segment(_ startMs: Int, _ endMs: Int) -> TranscriptSegment {
        TranscriptSegment(meetingId: 1, line: SpokenLine(span: startMs..<endMs, speaker: .me, text: "t"))
    }

    @Test func rowMapsToItsStart() {
        let segments = [segment(0, 900), segment(1_000, 2_000)]
        #expect(TranscriptNavigator.startMs(ofRow: 1, in: segments) == 1_000)
        #expect(TranscriptNavigator.startMs(ofRow: 5, in: segments) == nil)
    }

    @Test func playheadMapsToTheLatestStartedRow() {
        let segments = [segment(1_000, 2_000), segment(3_000, 4_000), segment(5_000, 6_000)]
        #expect(TranscriptNavigator.currentRow(atMs: 500, in: segments) == nil)
        #expect(TranscriptNavigator.currentRow(atMs: 1_000, in: segments) == 0)
        #expect(TranscriptNavigator.currentRow(atMs: 4_500, in: segments) == 1)
        #expect(TranscriptNavigator.currentRow(atMs: 99_000, in: segments) == 2)
        #expect(TranscriptNavigator.currentRow(atMs: 0, in: []) == nil)
    }

    @Test func bookmarkMarkSitsAtItsShareOfTheDuration() {
        #expect(TranscriptNavigator.fraction(ofMs: 500, durationMs: 2_000) == 0.25)
        #expect(TranscriptNavigator.fraction(ofMs: 5_000, durationMs: 2_000) == 1)
        #expect(TranscriptNavigator.fraction(ofMs: 5, durationMs: 0) == 0)
    }
}

struct MeetingExportTests {
    private let date = Date(timeIntervalSince1970: 1_792_000_000)

    @Test func namesFilesFromTitleDateAndKind() {
        let day = date.formatted(.iso8601.year().month().day())
        #expect(
            MeetingExport.summary.fileName(title: "Weekly sync", startedAt: date) == "Weekly sync \(day) summary.md")
        #expect(
            MeetingExport.transcript.fileName(title: "Weekly sync", startedAt: date)
                == "Weekly sync \(day) transcript.txt")
        #expect(
            MeetingExport.notesAndTasks.fileName(title: "Weekly sync", startedAt: date) == "Weekly sync \(day) notes.md"
        )
        #expect(MeetingExport.audio.fileName(title: "Weekly sync", startedAt: date) == "Weekly sync \(day).m4a")
    }

    @Test func replacesCharactersThatBreakFileNames() {
        let name = MeetingExport.audio.fileName(title: "Q3/Q4: plan", startedAt: date)
        #expect(!name.contains("/") && !name.contains(":"))
    }

    @Test func blankTitleFallsBackToMeeting() {
        #expect(MeetingExport.audio.fileName(title: "  ", startedAt: date).hasPrefix("Meeting "))
    }
}

struct RecordingSourceFileTests {
    private func tone(frames: AVAudioFrameCount) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for index in 0..<Int(frames) { buffer.floatChannelData![0][index] = 0.25 }
        return buffer
    }

    @Test func audioArrivingAfterTheFileClosesNeverErasesTheRecording() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).caf")
        defer { try? FileManager.default.removeItem(at: url) }
        let source = RecordingSource(speaker: .me, fileURL: url)
        source.stopTranscribing()
        source.receive(tone(frames: 1_600))
        source.receive(tone(frames: 1_600))
        source.closeFile()
        source.receive(tone(frames: 160))
        source.closeFile()
        #expect(try AVAudioFile(forReading: url).length == 3_200)
    }
}
