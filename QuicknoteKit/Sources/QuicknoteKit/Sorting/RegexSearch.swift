import Foundation

/// First case-insensitive match of `pattern` in `text`: where it is and what each capture group caught ("" if unused).
func firstCaseInsensitiveMatch(_ pattern: String, in text: String) -> (range: Range<String.Index>, captures: [String])?
{
    guard let regex = try? Regex(pattern).ignoresCase(), let match = text.firstMatch(of: regex) else { return nil }
    return (match.range, match.output.dropFirst().map { $0.substring.map(String.init) ?? "" })
}
