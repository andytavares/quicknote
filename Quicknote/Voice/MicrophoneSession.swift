import QuicknoteKit

/// Everything hold to talk needs from the audio side, so tests can stand in for the microphone and the speech model.
protocol SpeechSession: AnyObject {
    var updates: AsyncStream<TranscriptUpdate> { get }
    /// Loudness from 0 to 1 for the HUD level meter.
    var levels: AsyncStream<Float> { get }
    func start() async throws
    func finish() async throws -> [SpokenLine]
    func cancel() async
}

/// The microphone feeding a `LiveTranscriber` as `Speaker.me`.
final class MicrophoneSession: SpeechSession {
    private let transcriber = LiveTranscriber(speaker: .me)
    private let microphone = MicrophoneCapture()
    let levels: AsyncStream<Float>
    private let levelContinuation: AsyncStream<Float>.Continuation

    init() {
        (levels, levelContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    var updates: AsyncStream<TranscriptUpdate> { transcriber.updates }

    func start() async throws {
        try await transcriber.start()
        let (transcriber, levels) = (transcriber, levelContinuation)
        try microphone.start { buffer in
            transcriber.append(buffer)
            levels.yield(MicrophoneCapture.level(of: buffer))
        }
    }

    func finish() async throws -> [SpokenLine] {
        microphone.stop()
        levelContinuation.finish()
        return try await transcriber.finish()
    }

    func cancel() async {
        microphone.stop()
        levelContinuation.finish()
        await transcriber.cancel()
    }
}
