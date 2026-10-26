import AppKit
import QuicknoteKit

/// The NSTextView behind the editor: styles itself from `SlackMarkdown` spans, draws checkboxes,
/// and turns clicks on checkboxes and `[[link]]` chips into callbacks.
final class EditorTextView: NSTextView {
    static let textColor = NSColor.textColor
    private static let markerColor = NSColor.tertiaryLabelColor

    private var spans: [StyleSpan] = []
    var onToggleCheckbox: (Int) -> Void = { _ in }
    var onOpenLink: (String) -> Void = { _ in }
    var onDropFiles: ([URL]) -> Void = { _ in }

    func restyle(fontId: String) {
        guard let storage = textStorage, !hasMarkedText() else { return }
        let base = EditorFont.resolve(id: fontId, size: 15)
        spans = SlackMarkdown.spans(in: string)
        storage.beginEditing()
        storage.setAttributes(
            [.font: base, .foregroundColor: Self.textColor], range: NSRange(location: 0, length: storage.length))
        for span in spans.sorted(by: { rank($0) < rank($1) }) { apply(span, to: storage) }
        storage.endEditing()
        typingAttributes = [.font: base, .foregroundColor: Self.textColor]
        needsDisplay = true
    }

    /// Heading size first, then other content, then dimmed markers, then the clear text under a drawn checkbox.
    private func rank(_ span: StyleSpan) -> Int {
        switch span.style {
        case .heading: 0
        case .marker: 2
        case .checkbox: 3
        default: 1
        }
    }

    private func apply(_ span: StyleSpan, to storage: NSTextStorage) {
        switch span.style {
        case .bold: addTrait(.boldFontMask, to: span.range, in: storage)
        case .italic: addTrait(.italicFontMask, to: span.range, in: storage)
        case .heading(let level): setHeading(level: level, on: span.range, in: storage)
        case .strikethrough:
            storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: span.range)
        case .code:
            convertFonts(in: span.range, of: storage) {
                .monospacedSystemFont(ofSize: $0.pointSize * 0.92, weight: .regular)
            }
            storage.addAttribute(.backgroundColor, value: Self.markerColor.withAlphaComponent(0.08), range: span.range)
        case .marker: storage.addAttribute(.foregroundColor, value: Self.markerColor, range: span.range)
        case .checkbox: storage.addAttribute(.foregroundColor, value: NSColor.clear, range: span.range)
        case .link:
            storage.addAttributes(
                [
                    .foregroundColor: NSColor.controlAccentColor,
                    .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.15),
                ],
                range: span.range)
        case .listItem:
            let style = NSMutableParagraphStyle()
            style.headIndent = 14
            storage.addAttribute(
                .paragraphStyle, value: style, range: (string as NSString).paragraphRange(for: span.range))
        }
    }

    private func addTrait(_ trait: NSFontTraitMask, to range: NSRange, in storage: NSTextStorage) {
        convertFonts(in: range, of: storage) { NSFontManager.shared.convert($0, toHaveTrait: trait) }
    }

    private static let headingScales: [Int: CGFloat] = [1: 1.5, 2: 1.3, 3: 1.15]

    private func setHeading(level: Int, on range: NSRange, in storage: NSTextStorage) {
        let scale = Self.headingScales[level] ?? 1
        convertFonts(in: range, of: storage) { font in
            NSFontManager.shared.convert(
                NSFontManager.shared.convert(font, toSize: font.pointSize * scale), toHaveTrait: .boldFontMask)
        }
    }

    private func convertFonts(in range: NSRange, of storage: NSTextStorage, _ convert: (NSFont) -> NSFont) {
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            guard let font = value as? NSFont else { return }
            storage.addAttribute(.font, value: convert(font), range: subrange)
        }
    }

    // MARK: Checkboxes and chips

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for span in spans {
            guard case .checkbox(let checked) = span.style else { continue }
            drawCheckbox(in: rect(for: span.range), checked: checked)
        }
    }

    private func drawCheckbox(in rect: NSRect, checked: Bool) {
        let side = min(rect.height - 4, 14)
        let box = NSRect(x: rect.minX + 1, y: rect.midY - side / 2, width: side, height: side)
        let path = NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3)
        (checked ? NSColor.controlAccentColor : NSColor.clear).setFill()
        path.fill()
        Self.markerColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        guard checked else { return }
        let tick = NSBezierPath()
        tick.move(to: NSPoint(x: box.minX + side * 0.25, y: box.midY))
        tick.line(to: NSPoint(x: box.minX + side * 0.45, y: box.minY + side * 0.28))
        tick.line(to: NSPoint(x: box.minX + side * 0.78, y: box.maxY - side * 0.25))
        NSColor.white.setStroke()
        tick.lineWidth = 1.6
        tick.stroke()
    }

    private func rect(for characterRange: NSRange) -> NSRect {
        guard let layoutManager, let textContainer else { return .zero }
        let glyphs = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        for span in spans where rect(for: span.range).contains(point) {
            switch span.style {
            case .checkbox: return onToggleCheckbox(lineIndex(of: span.range.location))
            case .link(let title): return onOpenLink(title)
            default: continue
            }
        }
        super.mouseDown(with: event)
    }

    private func lineIndex(of location: Int) -> Int {
        (string as NSString).substring(to: location).filter { $0 == "\n" }.count
    }

    // MARK: Dropped files

    private func droppedFiles(_ sender: any NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        droppedFiles(sender).isEmpty ? super.draggingEntered(sender) : .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let files = droppedFiles(sender)
        guard !files.isEmpty else { return super.performDragOperation(sender) }
        onDropFiles(files)
        return true
    }
}
