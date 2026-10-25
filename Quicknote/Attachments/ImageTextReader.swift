import Foundation
import Vision

/// Reads the text in an image on this Mac (Vision), for search. Owned by the Capture unit.
enum ImageTextReader {
    /// The recognised lines joined by newlines, or nil when the file is unreadable or has no text.
    static func text(inImageAt url: URL) async -> String? {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [Locale.Language(identifier: "en-US")]
        guard let observations = try? await request.perform(on: url) else { return nil }
        let lines = observations.compactMap { $0.topCandidates(1).first?.string }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}
