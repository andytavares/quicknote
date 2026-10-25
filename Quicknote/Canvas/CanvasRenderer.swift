import AppKit
import CoreImage
import QuicknoteKit
import SwiftUI

/// Where a canvas gets its pictures and how its background is painted.
struct CanvasResources {
    /// Paints the background first, in canvas coordinates (top-left origin, `CanvasRenderer.pixelSize(of:)` big). The Cards unit replaces this
    /// to draw paper textures; the default fills `.card` with a plain rectangle and draws a Snap's image.
    typealias BackgroundPainter = @MainActor (CanvasBackground, CanvasResources, CGContext) -> Void

    /// The picture stored as an attachment: a Snap's original or a Card's photo.
    var image: (Int64) -> CGImage?
    var paintBackground: BackgroundPainter = CanvasRenderer.paintPlainBackground
}

/// Draws a `CanvasDocument` into a bitmap at any scale. One scale unit is one canvas pixel.
enum CanvasRenderer {
    private static let ciContext = CIContext()
    private static let blurRadius: CGFloat = 12

    static func pixelSize(of document: CanvasDocument) -> CGSize { pixelSize(of: document.background) }

    static func pixelSize(of background: CanvasBackground) -> CGSize {
        switch background {
        case .image(_, let size): size
        case .card(_, let size): size.pixelSize
        }
    }

    /// Full resolution at `scale` 1. Blur reads the pixels painted below it, so it needs a bitmap context.
    static func render(_ document: CanvasDocument, scale: CGFloat = 1, resources: CanvasResources) -> CGImage? {
        let size = pixelSize(of: document)
        guard let context = makeContext(size: size, scale: scale) else { return nil }
        let bounds = CGRect(origin: .zero, size: size)
        resources.paintBackground(document.background, resources, context)
        for element in document.elements { draw(element, in: context, resources: resources) }
        if document.showsMadeWithMark { drawMadeWithMark(in: context, bounds: bounds) }
        return context.makeImage()
    }

    static func paintPlainBackground(
        _ background: CanvasBackground, _ resources: CanvasResources, _ context: CGContext
    ) {
        let bounds = CGRect(origin: .zero, size: pixelSize(of: background))
        switch background {
        case .image(let attachmentId, _):
            if let image = resources.image(attachmentId) { drawImage(image, in: bounds, context: context) }
        case .card(let style, _):
            context.setFillColor(cgColor(style.paperColorHex))
            context.fill(bounds)
        }
    }

    static func textSize(_ text: String, height: CGFloat) -> CGSize {
        (text as NSString).size(withAttributes: [.font: font(named: nil, size: height * 0.7)])
    }

    static func cgColor(_ hex: String, alpha: CGFloat = 1) -> CGColor {
        NSColor(Color(hex: hex)).withAlphaComponent(alpha).cgColor
    }

    static func font(named name: String?, size: CGFloat) -> NSFont {
        name.flatMap { NSFont(name: $0, size: size) } ?? NSFont.systemFont(ofSize: size, weight: .medium)
    }

    /// Top-left origin, canvas units: flips the bitmap's native bottom-left origin.
    private static func makeContext(size: CGSize, scale: CGFloat) -> CGContext? {
        let width = max(Int((size.width * scale).rounded()), 1)
        let height = max(Int((size.height * scale).rounded()), 1)
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.translateBy(x: 0, y: CGFloat(height))
        context?.scaleBy(x: scale, y: -scale)
        return context
    }

    static func drawImage(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }

    private static func draw(_ element: CanvasElement, in context: CGContext, resources: CanvasResources) {
        if case .blur = element.kind {
            drawBlur(element, in: context)
            return
        }
        context.saveGState()
        context.translateBy(x: element.frame.midX, y: element.frame.midY)
        context.rotate(by: element.rotation)
        let local = CGRect(
            x: -element.frame.width / 2, y: -element.frame.height / 2, width: element.frame.width,
            height: element.frame.height)
        ElementPainter(element: element, local: local, context: context, resources: resources).paint()
        context.restoreGState()
    }

    private static func drawBlur(_ element: CanvasElement, in context: CGContext) {
        let scale = CGFloat(context.width) / context.boundingBoxOfClipPath.width
        var transform = CGAffineTransform(translationX: element.frame.midX, y: element.frame.midY)
            .rotated(by: element.rotation).translatedBy(x: -element.frame.midX, y: -element.frame.midY)
        let outline = CGPath(rect: element.frame, transform: &transform)
        let region = outline.boundingBoxOfPath.integral
        guard let below = context.makeImage(),
            let piece = below.cropping(to: region.applying(CGAffineTransform(scaleX: scale, y: scale)))
        else { return }
        let source = CIImage(cgImage: piece)
        let blurred = source.clampedToExtent().applyingGaussianBlur(sigma: blurRadius * scale).cropped(
            to: source.extent)
        guard let result = ciContext.createCGImage(blurred, from: source.extent) else { return }
        context.saveGState()
        context.addPath(outline)
        context.clip()
        drawImage(result, in: region, context: context)
        context.restoreGState()
    }

    private static func drawMadeWithMark(in context: CGContext, bounds: CGRect) {
        let height = max(bounds.height * 0.025, 12)
        let mark = "Made with Quicknote"
        let width = textSize(mark, height: height / 0.7).width
        let rect = CGRect(x: bounds.maxX - width - height, y: bounds.maxY - height * 2, width: width, height: height)
        TextDrawing(string: mark, rect: rect, font: font(named: nil, size: height), color: .gray).draw(in: context)
    }
}
