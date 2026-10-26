import AVFoundation
import CoreAudio

enum SystemAudioTapError: LocalizedError {
    case failed(step: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .failed(let step, let status): "Mac audio could not start (\(step), error \(status))."
        }
    }
}

/// Everything the Mac plays, except Quicknote itself, as buffers on an audio thread.
/// A Core Audio process tap inside a private aggregate device; macOS asks for permission when it starts.
nonisolated final class SystemAudioTap: @unchecked Sendable {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "quicknote.system-audio-tap", qos: .userInitiated)

    func start(onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        do {
            let description = CATapDescription(stereoGlobalTapButExcludeProcesses: Self.ownProcessObjects())
            description.uuid = UUID()
            description.isPrivate = true
            description.muteBehavior = .unmuted
            try check(AudioHardwareCreateProcessTap(description, &tapID), "create tap")
            let format = try tapFormat()
            try makeAggregateDevice(tapUUID: description.uuid)
            try startIO(format: format, onBuffer: onBuffer)
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, procID)
            if let procID { AudioDeviceDestroyIOProcID(aggregateID, procID) }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        (tapID, aggregateID, procID) = (AudioObjectID(kAudioObjectUnknown), AudioObjectID(kAudioObjectUnknown), nil)
    }

    private func makeAggregateDevice(tapUUID: UUID) throws {
        let outputDevice = try Self.defaultOutputDevice()
        let outputUID = try Self.read(outputDevice, selector: kAudioDevicePropertyDeviceUID) as CFString as String
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Quicknote Mac audio",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: tapUUID.uuidString]
            ],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "create device")
    }

    private func startIO(format: AVAudioFormat, onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
        try check(
            AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, queue) { _, input, _, _, _ in
                guard let borrowed = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil),
                    let copy = borrowed.ownedCopy()
                else { return }
                onBuffer(copy)
            }, "create IO proc")
        try check(AudioDeviceStart(aggregateID, procID), "start device")
    }

    private func tapFormat() throws -> AVAudioFormat {
        var description: AudioStreamBasicDescription = try Self.read(tapID, selector: kAudioTapPropertyFormat)
        guard let format = AVAudioFormat(streamDescription: &description) else {
            throw SystemAudioTapError.failed(step: "read format", status: kAudioHardwareUnspecifiedError)
        }
        return format
    }

    /// Quicknote's own audio object, so its playback is not recorded. Empty until the process has used audio.
    private static func ownProcessObjects() -> [AudioObjectID] {
        var pid = getpid()
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject, mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
        return status == noErr && object != kAudioObjectUnknown ? [object] : []
    }

    private static func defaultOutputDevice() throws -> AudioObjectID {
        try Self.read(
            AudioObjectID(kAudioObjectSystemObject), selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
    }

    private static func read<Value>(_ object: AudioObjectID, selector: AudioObjectPropertySelector) throws -> Value {
        var address = AudioObjectPropertyAddress(
            mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<Value>.size)
        let pointer = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        guard status == noErr else { throw SystemAudioTapError.failed(step: "read property", status: status) }
        return pointer.move()
    }

    private func check(_ status: OSStatus, _ step: String) throws {
        guard status == noErr else { throw SystemAudioTapError.failed(step: step, status: status) }
    }
}
