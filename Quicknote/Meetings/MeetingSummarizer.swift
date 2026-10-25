import FoundationModels
import QuicknoteKit

/// Writes a short summary on this Mac with the system language model.
enum MeetingSummarizer {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    private static let instructions = "You summarise meeting transcripts. Reply with plain text only."

    /// Summarises each chunk that fits the context window, then combines the parts. Nil when no text results.
    static func summary(of segments: [TranscriptSegment]) async throws -> String? {
        let lines = segments.map { "\($0.speaker == .me ? "Me" : "Others"): \($0.text)" }
        guard !lines.isEmpty else { return nil }
        let chunks = SummaryChunker.chunks(of: lines, maxCharacters: chunkCharacterBudget)
        var parts: [String] = []
        for chunk in chunks {
            parts.append(
                try await respond(
                    "Summarise this part of a meeting in a short paragraph and bullet points.\n\n\(chunk)"))
        }
        guard parts.count > 1 else { return parts.first }
        let combined = parts.joined(separator: "\n\n")
        return try await respond(
            "Combine these partial summaries of one meeting into one short summary.\n\n\(combined)")
    }

    /// Half the window in tokens at about three characters each; the rest is left for instructions and the reply.
    private static var chunkCharacterBudget: Int { SystemLanguageModel.default.contextSize / 2 * 3 }

    private static func respond(_ prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        return try await session.respond(to: prompt).content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
