import AVFoundation

nonisolated extension AVAudioPCMBuffer {
    /// A copy that owns its samples, for audio callbacks whose buffers are reused once they return.
    /// Written by hand because `AVAudioPCMBuffer(copying:)` needs macOS 27.
    func ownedCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else { return nil }
        copy.frameLength = frameLength
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: audioBufferList))
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (from, to) in zip(source, destination) {
            guard let fromData = from.mData, let toData = to.mData else { continue }
            toData.copyMemory(from: fromData, byteCount: Int(min(from.mDataByteSize, to.mDataByteSize)))
        }
        return copy
    }
}
