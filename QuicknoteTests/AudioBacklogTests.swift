import AVFoundation
import Testing

@testable import Quicknote

struct AudioBacklogTests {
    private func buffer(frames: AVAudioFrameCount) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        return buffer
    }

    @Test func keepsEarlyAudioInOrder() {
        var backlog = AudioBacklog()
        backlog.add(HeldAudioBuffer(buffer: buffer(frames: 1)))
        backlog.add(HeldAudioBuffer(buffer: buffer(frames: 2)))
        #expect(backlog.drain().map(\.frameLength) == [1, 2])
        #expect(backlog.drain().isEmpty)
    }

    @Test func dropsTheOldestAudioPastTheLimit() {
        var backlog = AudioBacklog(limit: 2)
        for frames in 1...3 { backlog.add(HeldAudioBuffer(buffer: buffer(frames: AVAudioFrameCount(frames)))) }
        #expect(backlog.drain().map(\.frameLength) == [2, 3])
    }
}
