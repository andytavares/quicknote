/// Splits a transcript into pieces that fit the language model's context window.
enum SummaryChunker {
    /// Joins whole lines, in order, until the next one would pass `maxCharacters`.
    /// A line longer than the budget gets a chunk of its own rather than being cut.
    static func chunks(of lines: [String], maxCharacters: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for line in lines {
            let joined = current.isEmpty ? line : current + "\n" + line
            if joined.count > maxCharacters, !current.isEmpty {
                chunks.append(current)
                current = line
            } else {
                current = joined
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
