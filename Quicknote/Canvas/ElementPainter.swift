import AppKit
import QuicknoteKit

/// Paints one element inside its own rotated space: `local` is the frame centred on the origin.
struct ElementPainter {
    let element: CanvasElement
    let local: CGRect
    let context: CGContext
    let resources: CanvasResources

    private var color: CGColor { CanvasRenderer.cgColor(element.style.colorHex) }
    private var strokeWidth: CGFloat { element.style.strokeWidth }

    func paint() {
        switch element.kind {
        case .arrow, .line: paintSegment(withHead: element.kind == .arrow)
        case .box, .diamond, .circle, .triangle: stroke(outline)
        case .text(let string): paintText(string)
        case .step(let number): paintStep(number)
        case .highlight: fill(CGPath(rect: local, transform: nil), alpha: 0.5)
        case .sticker(let symbol): paintSticker(symbol)
        case .photo(let attachmentId): paintPhoto(attachmentId)
        case .washi(let pattern): paintWashi(pattern)
        case .ink(let points): paintInk(points)
        case .extraNote(let text, let colorHex): paintExtraNote(text, colorHex: colorHex)
        case .blur: break  // drawn by the renderer from the pixels below
        }
    }

    private var outline: CGPath {
        let inset = local.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2)
        let path = CGMutablePath()
        switch element.kind {
        case .circle: path.addEllipse(in: inset)
        case .diamond:
            path.addLines(between: [
                CGPoint(x: inset.midX, y: inset.minY), CGPoint(x: inset.maxX, y: inset.midY),
                CGPoint(x: inset.midX, y: inset.maxY), CGPoint(x: inset.minX, y: inset.midY),
            ])
            path.closeSubpath()
        case .triangle:
            path.addLines(between: [
                CGPoint(x: inset.midX, y: inset.minY), CGPoint(x: inset.maxX, y: inset.maxY),
                CGPoint(x: inset.minX, y: inset.maxY),
            ])
            path.closeSubpath()
        default: path.addRect(inset)
        }
        return path
    }

    private func stroke(_ path: CGPath) {
        context.setStrokeColor(color)
        context.setLineWidth(strokeWidth)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.addPath(path)
        context.strokePath()
    }

    private func fill(_ path: CGPath, alpha: CGFloat = 1) {
        context.setFillColor(CanvasRenderer.cgColor(element.style.colorHex, alpha: alpha))
        context.addPath(path)
        context.fillPath()
    }

    private func paintSegment(withHead: Bool) {
        let start = CGPoint(
            x: element.flippedX ? local.maxX : local.minX, y: element.flippedY ? local.maxY : local.minY)
        let end = CGPoint(x: element.flippedX ? local.minX : local.maxX, y: element.flippedY ? local.minY : local.maxY)
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        if withHead {
            let angle = atan2(end.y - start.y, end.x - start.x)
            let length = max(strokeWidth * 4, 14)
            for spread in [CGFloat.pi / 7, -CGFloat.pi / 7] {
                path.move(to: end)
                path.addLine(
                    to: CGPoint(x: end.x - length * cos(angle + spread), y: end.y - length * sin(angle + spread)))
            }
        }
        stroke(path)
    }

    private func paintText(_ string: String) {
        let font = CanvasRenderer.font(named: element.style.fontName, size: local.height * 0.7)
        TextDrawing(string: string, rect: local, font: font, color: NSColor(cgColor: color) ?? .red).draw(in: context)
    }

    private func paintStep(_ number: Int) {
        fill(CGPath(ellipseIn: local, transform: nil))
        let font = NSFont.systemFont(ofSize: local.height * 0.55, weight: .bold)
        TextDrawing(string: String(number), rect: local, font: font, color: .white, centred: true).draw(in: context)
    }

    private func paintSticker(_ symbol: String) {
        let font = NSFont.systemFont(ofSize: min(local.width, local.height) * 0.8)
        TextDrawing(string: symbol, rect: local, font: font, color: .black, centred: true).draw(in: context)
    }

    private func paintPhoto(_ attachmentId: Int64) {
        guard let image = resources.image(attachmentId) else { return }
        context.saveGState()
        context.clip(to: local)
        let ratio = max(local.width / CGFloat(image.width), local.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * ratio, height: CGFloat(image.height) * ratio)
        let rect = CGRect(
            x: local.midX - size.width / 2, y: local.midY - size.height / 2, width: size.width, height: size.height)
        CanvasRenderer.drawImage(image, in: rect, context: context)
        context.restoreGState()
    }

    private func paintWashi(_ pattern: String) {
        fill(CGPath(rect: local, transform: nil), alpha: 0.75)
        guard pattern != "plain" else { return }
        context.saveGState()
        context.clip(to: local)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.5))
        context.setLineWidth(local.height / 6)
        var x = local.minX - local.height
        while x < local.maxX {
            context.move(to: CGPoint(x: x, y: local.maxY))
            context.addLine(to: CGPoint(x: x + local.height, y: local.minY))
            x += local.height / 1.5
        }
        context.strokePath()
        context.restoreGState()
    }

    private func paintInk(_ points: [CGPoint]) {
        guard let first = points.first else { return }
        let origin = local.origin
        let path = CGMutablePath()
        path.move(to: CGPoint(x: origin.x + first.x, y: origin.y + first.y))
        for point in points.dropFirst() { path.addLine(to: CGPoint(x: origin.x + point.x, y: origin.y + point.y)) }
        stroke(path)
    }

    private func paintExtraNote(_ text: String, colorHex: String) {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 3), blur: 6, color: CGColor(gray: 0, alpha: 0.25))
        context.setFillColor(CanvasRenderer.cgColor(colorHex))
        context.fill(local)
        context.restoreGState()
        let font = NSFont.systemFont(ofSize: local.height * 0.16)
        TextDrawing(string: text, rect: local.insetBy(dx: 8, dy: 8), font: font, color: NSColor(white: 0.17, alpha: 1))
            .draw(in: context)
    }
}
