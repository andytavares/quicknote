import AVFoundation

/// Watches one audio source for sound. `.silent` is reported once the first `window` seconds were quiet,
/// and `.heardAudio` the first time sound arrives (also after `.silent`).
nonisolated struct SilenceDetector {
    enum Verdict: Equatable { case silent, heardAudio }

    /// Peak amplitude (0 to 1) below which a buffer counts as silence.
    static let threshold: Float = 0.0005

    private let window: Double
    private var secondsHeard = 0.0
    private var hasHeardAudio = false
    private var hasReportedSilence = false

    init(window: Double = 3) { self.window = window }

    mutating func feed(_ buffer: AVAudioPCMBuffer) -> Verdict? {
        if !hasHeardAudio, Self.peak(of: buffer) > Self.threshold {
            hasHeardAudio = true
            return .heardAudio
        }
        guard !hasHeardAudio, !hasReportedSilence else { return nil }
        secondsHeard += Double(buffer.frameLength) / buffer.format.sampleRate
        guard secondsHeard >= window else { return nil }
        hasReportedSilence = true
        return .silent
    }

    static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else { return 0 }
        var peak: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<Int(buffer.frameLength) { peak = max(peak, abs(channels[channel][frame])) }
        }
        return peak
    }
}
