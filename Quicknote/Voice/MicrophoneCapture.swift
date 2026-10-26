import AVFoundation

/// The default microphone as a stream of buffers, delivered on an audio thread.
nonisolated final class MicrophoneCapture: @unchecked Sendable {
    private let engine = AVAudioEngine()

    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 4096, format: input.outputFormat(forBus: 0)) { buffer, _ in
            if let copy = buffer.ownedCopy() { onBuffer(copy) }
        }
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Root-mean-square loudness of the first channel, 0 to 1, for a level meter.
    static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let squares = (0..<Int(buffer.frameLength)).reduce(Float(0)) { $0 + samples[$1] * samples[$1] }
        return min(1, (squares / Float(buffer.frameLength)).squareRoot() * 4)
    }
}
