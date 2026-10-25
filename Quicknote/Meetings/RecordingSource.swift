import AVFoundation
import QuicknoteKit
import Synchronization

/// One audio source of a meeting: its transcriber, its audio file, its level and its silence check.
/// `receive` runs on an audio thread; `isPaused` drops buffers so neither the file nor the transcript advances.
nonisolated final class RecordingSource: Sendable {
    let speaker: Speaker
    let transcriber: LiveTranscriber
    private let fileURL: URL
    private let onVerdict: (@Sendable (SilenceDetector.Verdict) -> Void)?
    private let state = Mutex(State())

    private struct State {
        var file: AVAudioFile?
        /// Set once the file was opened; it is never opened again, so a reopen cannot truncate saved audio.
        var fileWasOpened = false
        var isPaused = false
        var level: Float = 0
        var transcribes = true
        var silence = SilenceDetector()
    }

    init(speaker: Speaker, fileURL: URL, onVerdict: (@Sendable (SilenceDetector.Verdict) -> Void)? = nil) {
        self.speaker = speaker
        self.fileURL = fileURL
        self.onVerdict = onVerdict
        self.transcriber = LiveTranscriber(speaker: speaker)
    }

    var level: Float { state.withLock { $0.level } }

    func setPaused(_ paused: Bool) {
        state.withLock {
            $0.isPaused = paused
            if paused { $0.level = 0 }
        }
    }

    func receive(_ buffer: AVAudioPCMBuffer) {
        let heard = state.withLock { state -> SilenceDetector.Verdict?? in
            guard !state.isPaused else { return .none }
            state.level = MicrophoneCapture.level(of: buffer)
            write(buffer, to: &state)
            return .some(state.silence.feed(buffer))
        }
        guard let heard else { return }
        if state.withLock({ $0.transcribes }) { transcriber.append(buffer) }
        if let verdict = heard { onVerdict?(verdict) }
    }

    /// Keeps recording audio when speech recognition could not start, so the held audio is not kept in memory.
    func stopTranscribing() { state.withLock { $0.transcribes = false } }

    /// Closes the audio file so it can be read.
    func closeFile() { state.withLock { $0.file = nil } }

    private func write(_ buffer: AVAudioPCMBuffer, to state: inout State) {
        do {
            if !state.fileWasOpened {
                state.fileWasOpened = true
                state.file = try AVAudioFile(forWriting: fileURL, settings: buffer.format.settings)
            }
            try state.file?.write(from: buffer)
        } catch {
            // Keep what was written; later audio is dropped from the file but still transcribed.
            state.file = nil
        }
    }
}
