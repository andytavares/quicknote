import CoreGraphics
import QuicknoteKit

/// Paints the paper of a Card (S22) in canvas coordinates, top-left origin. Plug it into `CanvasResources.paintBackground`.
struct CardBackgroundPainter {
    let style: CardStyle
    let bounds: CGRect
    let context: CGContext

    static let fibreSeed: UInt64 = 0x51_4B_4E_4F

    static func paint(_ background: CanvasBackground, _ resources: CanvasResources, _ context: CGContext) {
        guard case .card(let style, let size) = background else {
            return CanvasRenderer.paintPlainBackground(background, resources, context)
        }
        CardBackgroundPainter(style: style, bounds: CGRect(origin: .zero, size: size.pixelSize), context: context)
            .paint()
    }

    func paint() {
        fill(bounds, hex: style.paperColorHex)
        switch style {
        case .sticky: paintShadowBand()
        case .postcard: paintPostcardMarks()
        case .polaroid: paintPolaroidWindow()
        case .lined: paintRules()
        case .minimal: break
        case .kraft: paintFibres()
        }
    }

    private var ink: CGColor { CanvasRenderer.cgColor(style.inkColorHex, alpha: 0.55) }
    private var lineWidth: CGFloat { max(bounds.height / 540, 2) }

    private func fill(_ rect: CGRect, hex: String, alpha: CGFloat = 1) {
        context.setFillColor(CanvasRenderer.cgColor(hex, alpha: alpha))
        context.fill(rect)
    }

    private func stroke(from start: CGPoint, to end: CGPoint, color: CGColor) {
        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }

    private func paintShadowBand() {
        fill(CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 0.06), hex: "#000000", alpha: 0.08)
    }

    private func paintPostcardMarks() {
        let width = bounds.width
        let height = bounds.height
        stroke(from: CGPoint(x: width / 2, y: height * 0.08), to: CGPoint(x: width / 2, y: height * 0.92), color: ink)
        context.setStrokeColor(ink)
        context.setLineWidth(lineWidth)
        context.stroke(CGRect(x: width * 0.74, y: height * 0.08, width: width * 0.18, height: height * 0.2))
        for fraction in [0.5, 0.62, 0.74] {
            let y = height * fraction
            stroke(from: CGPoint(x: width * 0.55, y: y), to: CGPoint(x: width * 0.92, y: y), color: ink)
        }
    }

    /// Thin frame on the top and sides, a thick one at the bottom, around a pale picture window.
    private func paintPolaroidWindow() {
        let side = bounds.width * 0.06
        let window = CGRect(
            x: side, y: side, width: bounds.width - side * 2, height: bounds.height - side - bounds.height * 0.22)
        fill(window, hex: "#E4E0D6")
    }

    private func paintRules() {
        let spacing = bounds.height / 24
        var y = spacing * 3
        while y < bounds.height {
            stroke(from: CGPoint(x: 0, y: y), to: CGPoint(x: bounds.width, y: y), color: Self.ruleColor)
            y += spacing
        }
        let margin = bounds.width * 0.12
        stroke(from: CGPoint(x: margin, y: 0), to: CGPoint(x: margin, y: bounds.height), color: Self.marginColor)
    }

    private static let ruleColor = CGColor(red: 0.45, green: 0.62, blue: 0.85, alpha: 0.6)
    private static let marginColor = CGColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.7)

    /// Short random strokes. The seed is fixed so a card renders the same every time.
    private func paintFibres() {
        var random = SeededGenerator(seed: Self.fibreSeed)
        context.setLineWidth(max(bounds.height / 1080, 1))
        for index in 0..<Int(bounds.width * bounds.height / 1500) {
            let start = CGPoint(
                x: .random(in: 0...bounds.width, using: &random), y: .random(in: 0...bounds.height, using: &random))
            let angle = CGFloat.random(in: 0...(2 * .pi), using: &random)
            let length = CGFloat.random(in: 6...22, using: &random) * bounds.height / 1080
            context.setStrokeColor(CGColor(gray: index.isMultiple(of: 2) ? 0.2 : 1, alpha: 0.07))
            context.move(to: start)
            context.addLine(to: CGPoint(x: start.x + length * cos(angle), y: start.y + length * sin(angle)))
            context.strokePath()
        }
    }
}

/// SplitMix64: small, and the same sequence on every run.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
