import AVFoundation

/// An audio buffer handed from the tap thread to the transcriber. The tap copies each buffer and never
/// touches it again, which is what makes passing it between threads safe.
nonisolated struct HeldAudioBuffer: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
}

/// Audio that arrives while the speech model is still starting, kept so the first words are not lost.
nonisolated struct AudioBacklog {
    /// About a minute of microphone buffers; older audio is dropped first.
    static let defaultLimit = 600

    private let limit: Int
    private var buffers: [HeldAudioBuffer] = []

    init(limit: Int = AudioBacklog.defaultLimit) {
        self.limit = limit
    }

    mutating func add(_ held: HeldAudioBuffer) {
        buffers.append(held)
        if buffers.count > limit { buffers.removeFirst(buffers.count - limit) }
    }

    /// Returns the held audio oldest first and empties the backlog.
    mutating func drain() -> [AVAudioPCMBuffer] {
        defer { buffers = [] }
        return buffers.map(\.buffer)
    }
}
