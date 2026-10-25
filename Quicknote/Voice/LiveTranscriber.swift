import AVFoundation
import CoreMedia
import QuicknoteKit
import Speech
import Synchronization

/// What a `LiveTranscriber` reports while audio is flowing.
enum TranscriptUpdate: Equatable, Sendable {
    /// Text still being revised; replaces the previous partial.
    case partial(String)
    /// Text that will not change again.
    case line(SpokenLine)
}

enum LiveTranscriberError: LocalizedError {
    case languageUnavailable
    case languageDownloadFailed(String)
    case noCompatibleAudioFormat

    var errorDescription: String? {
        switch self {
        case .languageUnavailable:
            "English speech recognition is not available on this Mac."
        case .languageDownloadFailed(let reason):
            "Quicknote could not download the English speech model (\(reason)). Check your connection and try again."
        case .noCompatibleAudioFormat:
            "Speech recognition could not accept this audio."
        }
    }
}

/// On-device English speech to text for one audio source. `append` may be called from any thread,
/// such as an audio tap; buffers that arrive before `start()` returns are dropped.
nonisolated final class LiveTranscriber: Sendable {
    let updates: AsyncStream<TranscriptUpdate>
    private let updateContinuation: AsyncStream<TranscriptUpdate>.Continuation
    private let inputs: AsyncStream<AnalyzerInput>
    private let inputContinuation: AsyncStream<AnalyzerInput>.Continuation
    private let speaker: Speaker
    private let session = Mutex(Session())

    private struct Session {
        var analyzer: SpeechAnalyzer?
        var converter: AudioBufferConverter?
        var resultsTask: Task<Void, any Error>?
        var lines: [SpokenLine] = []
    }

    init(speaker: Speaker) {
        self.speaker = speaker
        (updates, updateContinuation) = AsyncStream.makeStream()
        (inputs, inputContinuation) = AsyncStream.makeStream()
    }

    /// Installs the English model when it is missing, then begins listening. Throws a `LiveTranscriberError`.
    func start() async throws {
        let transcriber = SpeechTranscriber(locale: Self.locale, preset: .timeIndexedProgressiveTranscription)
        try await Self.installLanguageIfNeeded(for: transcriber)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw LiveTranscriberError.noCompatibleAudioFormat
        }
        let resultsTask = Task { for try await result in transcriber.results { self.receive(result) } }
        session.withLock {
            $0.analyzer = analyzer
            $0.converter = AudioBufferConverter(outputFormat: format)
            $0.resultsTask = resultsTask
        }
        try await analyzer.start(inputSequence: inputs)
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        let converted = session.withLock { $0.converter }?.convert(buffer)
        if let converted { inputContinuation.yield(AnalyzerInput(buffer: converted)) }
    }

    /// Ends the input, waits for the last words and returns every finished line.
    func finish() async throws -> [SpokenLine] {
        inputContinuation.finish()
        let (analyzer, resultsTask) = session.withLock { ($0.analyzer, $0.resultsTask) }
        defer { updateContinuation.finish() }
        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        try await resultsTask?.value
        return session.withLock { $0.lines }
    }

    /// Stops without waiting for results.
    func cancel() async {
        inputContinuation.finish()
        updateContinuation.finish()
        let (analyzer, resultsTask) = session.withLock { ($0.analyzer, $0.resultsTask) }
        resultsTask?.cancel()
        await analyzer?.cancelAndFinishNow()
    }

    // MARK: Results

    /// Milliseconds from the start of the audio, rounded down.
    static func span(of range: CMTimeRange) -> Range<Int> {
        let start = milliseconds(range.start)
        return start..<max(start, milliseconds(range.end))
    }

    private static func milliseconds(_ time: CMTime) -> Int {
        time.isNumeric ? max(0, Int((time.seconds * 1000).rounded(.down))) : 0
    }

    private func receive(_ result: SpeechTranscriber.Result) {
        let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard result.isFinal else {
            updateContinuation.yield(.partial(text))
            return
        }
        let line = SpokenLine(span: Self.span(of: result.range), speaker: speaker, text: text)
        session.withLock { $0.lines.append(line) }
        updateContinuation.yield(.line(line))
    }

    private static let locale = Locale(identifier: "en-US")

    private static func installLanguageIfNeeded(for transcriber: SpeechTranscriber) async throws {
        let status = await AssetInventory.status(forModules: [transcriber])
        if status == .unsupported { throw LiveTranscriberError.languageUnavailable }
        guard status != .installed else { return }
        do {
            try await AssetInventory.assetInstallationRequest(supporting: [transcriber])?.downloadAndInstall()
        } catch {
            throw LiveTranscriberError.languageDownloadFailed(error.localizedDescription)
        }
    }
}

/// Converts microphone or system audio to the format the analyzer asked for. Used from one audio thread.
nonisolated final class AudioBufferConverter: @unchecked Sendable {
    private let outputFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?

    init(outputFormat: AVAudioFormat) { self.outputFormat = outputFormat }

    func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if buffer.format == outputFormat { return buffer }
        if inputFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: outputFormat)
            inputFormat = buffer.format
        }
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let converter, let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity)
        else { return nil }
        var supplied = false
        var failure: NSError?
        let status = converter.convert(to: output, error: &failure) { _, inputStatus in
            if supplied {
                inputStatus.pointee = .noDataNow
                return nil
            }
            supplied = true
            inputStatus.pointee = .haveData
            return buffer
        }
        return status == .error || output.frameLength == 0 ? nil : output
    }
}
