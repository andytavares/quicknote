import Foundation

/// One styled stretch of text. `range` is in UTF-16 units so an NSTextView can apply it directly.
public struct StyleSpan: Equatable, Sendable {
    public enum Style: Equatable, Sendable {
        case bold, italic, listItem, strikethrough, code
        case heading(level: Int)
        case checkbox(checked: Bool)
        case link(title: String)
        /// A syntax character the editor dims: `*`, `_`, `~~`, `` ` ``, `# `, `[[`, `]]`, `[]`, `[x]`.
        case marker
    }

    public var range: NSRange
    public var style: Style

    public init(range: NSRange, style: Style) {
        self.range = range
        self.style = style
    }
}

/// What Enter does on a list line: start the next item with this prefix, or end the list.
public enum ListContinuation: Equatable, Sendable {
    case next(String)
    case end
}

/// Slack-style formatting (`*bold*`, `_italic_`, `[] ` checkboxes, `[[links]]`) plus the common Markdown
/// additions: `# ` headings, `**bold**`, `~~strike~~`, `` `code` ``, and `-`, `*`, `+` or `1.` lists.
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

    /// The prefix Enter repeats on the next line; nil when the line is not a list item or checkbox.
    public static func continuation(after line: String) -> ListContinuation? {
        guard let match = line.prefixMatch(of: itemPrefixPattern), match.2 != nil || match.4 != nil else { return nil }
        if line[match.range.upperBound...].allSatisfy(\.isWhitespace) { return .end }
        var bullet = match.2.map(String.init) ?? ""
        if let number = match.3.flatMap({ Int($0) }) { bullet = "\(number + 1). " }
        return .next(String(match.1) + bullet + (match.4 == nil ? "" : "[ ] "))
    }

    private static var itemPrefixPattern: Regex<(Substring, Substring, Substring?, Substring?, Substring?)> {
        /^(\s*)((?:[-*+]|(\d+)\.) )?(\[[ x]?\] )?/
    }
    private static var checkboxPattern: Regex<(Substring, Substring?, Substring, Substring?)> {
        /^([-*+] )?(\[( |x)?\])(?= )/
    }
    private static var listPattern: Regex<Substring> { #/^(?:[-*+]|\d+\.) /# }
    private static var headingPattern: Regex<(Substring, Substring)> { #/^(#{1,3}) /# }
    private static var linkPattern: Regex<(Substring, Substring)> { /\[\[([^\[\]]*)\]\]/ }

    /// An inline style wrapped in `width` mark characters on each side.
    private struct Mark {
        let pattern: Regex<(Substring, Substring)>
        let style: StyleSpan.Style
        let width: Int
    }

    private static var code: Mark { Mark(pattern: /`([^`]+)`/, style: .code, width: 1) }
    private static var doubleBold: Mark { Mark(pattern: /\*\*(\S|\S[^*]*\S)\*\*/, style: .bold, width: 2) }
    private static var strikethrough: Mark { Mark(pattern: /~~(\S|\S[^~]*\S)~~/, style: .strikethrough, width: 2) }
    private static var bold: Mark { Mark(pattern: /\*(\S|\S[^*]*\S)\*/, style: .bold, width: 1) }
    private static var italic: Mark { Mark(pattern: /_(\S|\S[^_]*\S)_/, style: .italic, width: 1) }

    private static func lineSpans(_ line: String, offset: Int) -> [StyleSpan] {
        let codeSpans = markSpans(line, code, offset: offset)
        let linkSpans = without(linkSpans(line, offset: offset), overlapping: codeSpans)
        let literal = codeSpans + linkSpans
        let doubleBoldSpans = without(markSpans(line, doubleBold, offset: offset), overlapping: literal)
        let inline =
            doubleBoldSpans
            + without(markSpans(line, bold, offset: offset), overlapping: literal + doubleBoldSpans)
            + without(markSpans(line, italic, offset: offset), overlapping: literal)
            + without(markSpans(line, strikethrough, offset: offset), overlapping: literal)
        return blockSpans(line, offset: offset) + literal + inline
    }

    /// Drops each styled run, with its markers, that touches a run in `others`.
    private static func without(_ spans: [StyleSpan], overlapping others: [StyleSpan]) -> [StyleSpan] {
        let taken = others.filter { $0.style != .marker }.map(\.range)
        let dropped = spans.filter { span in
            span.style != .marker && taken.contains { NSIntersectionRange($0, span.range).length > 0 }
        }
        return spans.filter { span in !dropped.contains { NSIntersectionRange($0.range, span.range).length > 0 } }
    }

    private static func blockSpans(_ line: String, offset: Int) -> [StyleSpan] {
        if let box = line.prefixMatch(of: checkboxPattern) {
            let boxRange = NSRange(box.2.startIndex..<box.2.endIndex, in: line)
            let checked = box.3 == "x"
            var spans = [StyleSpan(range: shifted(boxRange, offset), style: .checkbox(checked: checked))]
            if box.1 != nil { spans.append(StyleSpan(range: NSRange(location: offset, length: 2), style: .listItem)) }
            return spans + [StyleSpan(range: shifted(boxRange, offset), style: .marker)]
        }
        if let heading = line.prefixMatch(of: headingPattern) {
            let level = heading.1.count
            return [
                StyleSpan(range: NSRange(location: offset, length: line.utf16.count), style: .heading(level: level)),
                StyleSpan(range: NSRange(location: offset, length: level + 1), style: .marker),
            ]
        }
        guard let item = line.prefixMatch(of: listPattern) else { return [] }
        return [StyleSpan(range: shifted(NSRange(item.range, in: line), offset), style: .listItem)]
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

    /// The runs of one inline mark in one line, each with its opening and closing markers.
    private static func markSpans(_ line: String, _ mark: Mark, offset: Int) -> [StyleSpan] {
        line.matches(of: mark.pattern).filter { standsAlone($0.range, in: line) }.flatMap { match -> [StyleSpan] in
            let range = shifted(NSRange(match.range, in: line), offset)
            return [
                StyleSpan(range: range, style: mark.style),
                StyleSpan(range: NSRange(location: range.location, length: mark.width), style: .marker),
                StyleSpan(range: NSRange(location: range.upperBound - mark.width, length: mark.width), style: .marker),
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
