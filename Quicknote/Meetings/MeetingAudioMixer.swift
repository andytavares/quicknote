import AVFoundation

enum MeetingAudioMixerError: LocalizedError {
    case noAudio

    var errorDescription: String? { "The meeting has no recorded audio." }
}

/// Lays the per-source recordings over each other (both start at zero) and exports one .m4a.
enum MeetingAudioMixer {
    static func mix(_ sources: [URL], into output: URL) async throws {
        let composition = AVMutableComposition()
        for url in sources where FileManager.default.fileExists(atPath: url.path) {
            let asset = AVURLAsset(url: url)
            guard let track = try await asset.loadTracks(withMediaType: .audio).first,
                let target = composition.addMutableTrack(
                    withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            else { continue }
            let duration = try await asset.load(.duration)
            try target.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
        }
        guard !composition.tracks.isEmpty,
            let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
        else { throw MeetingAudioMixerError.noAudio }
        try? FileManager.default.removeItem(at: output)
        try await session.export(to: output, as: .m4a)
    }
}
