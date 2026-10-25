import Foundation

/// One styled stretch of text. `range` is in UTF-16 units so an NSTextView can apply it directly.
public struct StyleSpan: Equatable, Sendable {
    public enum Style: Equatable, Sendable {
        case bold, italic, listItem
        case checkbox(checked: Bool)
        case link(title: String)
        /// A syntax character the editor dims: `*`, `_`, `[[`, `]]`, `[]`, `[x]`.
        case marker
    }

    public var range: NSRange
    public var style: Style

    public init(range: NSRange, style: Style) {
        self.range = range
        self.style = style
    }
}

/// Slack-style formatting: `*bold*`, `_italic_`, `- ` lists, `[] ` checkboxes and `[[links]]`.
public enum SlackMarkdown {
    public static func spans(in text: String) -> [StyleSpan] {
        let nsText = text as NSString
        var spans: [StyleSpan] = []
        nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: .byLines) {
            line, lineRange, _, _ in
            spans += lineSpans(line ?? "", offset: lineRange.location)
        }
        return spans
    }

    /// Flips the checkbox on a zero-based line. Lines without one are left alone.
    public static func togglingCheckbox(in text: String, line: Int) -> String {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(line) else { return text }
        let nsLine = lines[line] as NSString
        for span in spans(in: lines[line]) {
            guard case .checkbox(let checked) = span.style else { continue }
            lines[line] = nsLine.replacingCharacters(in: span.range, with: checked ? "[ ]" : "[x]")
            break
        }
        return lines.joined(separator: "\n")
    }

    private static var checkboxPattern: Regex<(Substring, Substring?, Substring, Substring?)> {
        /^(- )?(\[( |x)?\])(?= )/
    }
    private static var linkPattern: Regex<(Substring, Substring)> { /\[\[([^\[\]]*)\]\]/ }
    private static var boldPattern: Regex<(Substring, Substring)> { /\*(\S|\S[^*]*\S)\*/ }
    private static var italicPattern: Regex<(Substring, Substring)> { /_(\S|\S[^_]*\S)_/ }

    private static func lineSpans(_ line: String, offset: Int) -> [StyleSpan] {
        let blockSpans = blockSpans(line, offset: offset)
        let linkSpans = linkSpans(line, offset: offset)
        let linkRanges = linkSpans.filter { $0.style != .marker }.map(\.range)
        let inline =
            markSpans(line, .bold, boldPattern, offset: offset)
            + markSpans(line, .italic, italicPattern, offset: offset)
        let outsideLinks = inline.filter { span in
            !linkRanges.contains { NSIntersectionRange($0, span.range).length > 0 }
        }
        return blockSpans + linkSpans + outsideLinks
    }

    private static func blockSpans(_ line: String, offset: Int) -> [StyleSpan] {
        if let box = line.prefixMatch(of: checkboxPattern) {
            let boxRange = NSRange(box.2.startIndex..<box.2.endIndex, in: line)
            let checked = box.3 == "x"
            var spans = [StyleSpan(range: shifted(boxRange, offset), style: .checkbox(checked: checked))]
            if box.1 != nil { spans.append(StyleSpan(range: NSRange(location: offset, length: 2), style: .listItem)) }
            return spans + [StyleSpan(range: shifted(boxRange, offset), style: .marker)]
        }
        return line.hasPrefix("- ") ? [StyleSpan(range: NSRange(location: offset, length: 2), style: .listItem)] : []
    }

    private static func linkSpans(_ line: String, offset: Int) -> [StyleSpan] {
        line.matches(of: linkPattern).flatMap { match -> [StyleSpan] in
            let title = match.1.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return [] }
            let range = shifted(NSRange(match.range, in: line), offset)
            let close = NSRange(location: range.upperBound - 2, length: 2)
            return [
                StyleSpan(range: range, style: .link(title: title)),
                StyleSpan(range: NSRange(location: range.location, length: 2), style: .marker),
                StyleSpan(range: close, style: .marker),
            ]
        }
    }

    private static func markSpans(
        _ line: String, _ style: StyleSpan.Style, _ pattern: some RegexComponent<(Substring, Substring)>,
        offset: Int
    ) -> [StyleSpan] {
        line.matches(of: pattern).filter { standsAlone($0.range, in: line) }.flatMap { match -> [StyleSpan] in
            let range = shifted(NSRange(match.range, in: line), offset)
            return [
                StyleSpan(range: range, style: style),
                StyleSpan(range: NSRange(location: range.location, length: 1), style: .marker),
                StyleSpan(range: NSRange(location: range.upperBound - 1, length: 1), style: .marker),
            ]
        }
    }

    /// Like Slack, marks touching a letter or digit outside them (`snake_case`, `2*3*4`) are plain text.
    private static func standsAlone(_ range: Range<String.Index>, in line: String) -> Bool {
        let before = range.lowerBound > line.startIndex ? line[line.index(before: range.lowerBound)] : nil
        let after = range.upperBound < line.endIndex ? line[range.upperBound] : nil
        return !(before?.isLetter ?? false) && !(before?.isNumber ?? false)
            && !(after?.isLetter ?? false) && !(after?.isNumber ?? false)
    }

    private static func shifted(_ range: NSRange, _ offset: Int) -> NSRange {
        NSRange(location: range.location + offset, length: range.length)
    }
}
