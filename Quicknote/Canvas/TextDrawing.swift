import AppKit

/// A run of text drawn into a canvas context. AppKit text needs the current graphics context, flipped to match.
struct TextDrawing {
    let string: String
    let rect: CGRect
    let font: NSFont
    let color: NSColor
    var centred = false

    func draw(in context: CGContext) {
        let style = NSMutableParagraphStyle()
        style.alignment = centred ? .center : .left
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        let height = (string as NSString).boundingRect(
            with: rect.size, options: .usesLineFragmentOrigin, attributes: attributes
        ).height
        let target = centred ? rect.insetBy(dx: 0, dy: max((rect.height - height) / 2, 0)) : rect
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        (string as NSString).draw(with: target, options: .usesLineFragmentOrigin, attributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }
}
