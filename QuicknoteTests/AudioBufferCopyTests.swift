import AVFoundation
import Testing

@testable import Quicknote

struct AudioBufferCopyTests {
    private func stereoBuffer(samples: [Float]) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for channel in 0..<2 {
            for (index, sample) in samples.enumerated() {
                buffer.floatChannelData![channel][index] = sample + Float(channel)
            }
        }
        return buffer
    }

    private func channel(_ channel: Int, of buffer: AVAudioPCMBuffer) -> [Float] {
        Array(UnsafeBufferPointer(start: buffer.floatChannelData![channel], count: Int(buffer.frameLength)))
    }

    @Test func copyKeepsEverySampleOfEveryChannel() throws {
        let copy = try #require(stereoBuffer(samples: [0.1, 0.2, 0.3]).ownedCopy())
        #expect(copy.frameLength == 3)
        #expect(channel(0, of: copy) == [0.1, 0.2, 0.3])
        #expect(channel(1, of: copy) == [1.1, 1.2, 1.3])
    }

    @Test func copyOutlivesChangesToTheBorrowedBuffer() throws {
        let borrowed = stereoBuffer(samples: [0.5, 0.5])
        let copy = try #require(borrowed.ownedCopy())
        borrowed.floatChannelData![0][0] = 0
        #expect(channel(0, of: copy) == [0.5, 0.5])
    }
}
