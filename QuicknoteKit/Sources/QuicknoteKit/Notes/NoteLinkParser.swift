import Foundation

/// Finds `[[Title]]` links in a note body.
public enum NoteLinkParser {
    /// Titles in order of first appearance, trimmed and without duplicates.
    public static func linkedTitles(in body: String) -> [String] {
        var seen = Set<String>()
        return body.matches(of: /\[\[([^\[\]\n]*)\]\]/).compactMap { match in
            let title = match.1.trimmingCharacters(in: .whitespaces)
            return title.isEmpty || !seen.insert(title).inserted ? nil : title
        }
    }
}
