import Foundation

/// A `[[` the cursor sits after, with the partial title typed so far.
struct LinkTrigger: Equatable {
    /// UTF-16 range of the partial title, after the `[[`.
    var range: NSRange
    var query: String

    /// Nil unless the cursor is right after `[[` plus a partial title on one line, outside a closed link.
    static func detect(in text: String, cursor: Int) -> LinkTrigger? {
        let nsText = text as NSString
        guard cursor <= nsText.length else { return nil }
        let lineStart = nsText.lineRange(for: NSRange(location: cursor, length: 0)).location
        let before = nsText.substring(with: NSRange(location: lineStart, length: cursor - lineStart))
        guard let open = before.range(of: "[[", options: .backwards) else { return nil }
        let query = String(before[open.upperBound...])
        guard !query.contains("]"), !query.contains("[") else { return nil }
        let lineEnd = NSMaxRange(nsText.lineRange(for: NSRange(location: cursor, length: 0)))
        let after = nsText.substring(with: NSRange(location: cursor, length: lineEnd - cursor))
        guard !closesBeforeNextOpening(after) else { return nil }
        let start = lineStart + before.utf16.distance(from: before.startIndex, to: open.upperBound)
        return LinkTrigger(range: NSRange(location: start, length: cursor - start), query: query)
    }

    private static func closesBeforeNextOpening(_ rest: String) -> Bool {
        guard let close = rest.range(of: "]]") else { return false }
        guard let open = rest.range(of: "[[") else { return true }
        return close.lowerBound < open.lowerBound
    }
}
