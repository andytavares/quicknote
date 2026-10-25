import Foundation
import Vision

/// Reads the text in an image on this Mac (Vision), for search. Owned by the Capture unit.
enum ImageTextReader {
    /// The recognised lines joined by newlines, or nil when the file is unreadable or has no text.
    static func text(inImageAt url: URL) async -> String? {
        let lines = await lines { level in
            var request = RecognizeTextRequest()
            request.recognitionLevel = level
            request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
            return try await request.perform(on: url).compactMap { $0.topCandidates(1).first?.string }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// Accurate recognition throws on virtual Macs (no Neural Engine), so fast is tried next.
    static func lines(
        recognize: (RecognizeTextRequest.RecognitionLevel) async throws -> [String]
    ) async -> [String] {
        for level in [RecognizeTextRequest.RecognitionLevel.accurate, .fast] {
            if let lines = try? await recognize(level) { return lines }
        }
        return []
    }
}
