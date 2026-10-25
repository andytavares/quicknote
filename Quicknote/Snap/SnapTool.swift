import QuicknoteKit
import SwiftUI

/// The markup tools in the order of the editor palette (S20).
enum SnapTool: String, CaseIterable, Identifiable {
    case select, arrow, line, box, diamond, circle, triangle, text, step, highlight, blur

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .select: "↖"
        case .arrow: "→"
        case .line: "╱"
        case .box: "▭"
        case .diamond: "◇"
        case .circle: "○"
        case .triangle: "△"
        case .text: "T"
        case .step: "①"
        case .highlight: "▬"
        case .blur: "▒"
        }
    }

    /// Single-key shortcut, active while the canvas has keyboard focus.
    var shortcut: Character {
        switch self {
        case .select: "v"
        case .arrow: "a"
        case .line: "l"
        case .box: "b"
        case .diamond: "d"
        case .circle: "c"
        case .triangle: "g"
        case .text: "t"
        case .step: "s"
        case .highlight: "h"
        case .blur: "u"
        }
    }

    static let highlightColorHex = "#F2C14E"
    static let stepSide: CGFloat = 44
    static let textSize = CGSize(width: 160, height: 48)

    /// What a drag from `start` to `end` makes with this tool, or nil for Select.
    func newElement(from start: CGPoint, to end: CGPoint, style: ElementStyle) -> CanvasElement? {
        var style = style
        let frame = CGRect(
            x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
        switch self {
        case .select: return nil
        case .step:
            let frame = Self.frame(centredOn: start, size: CGSize(width: Self.stepSide, height: Self.stepSide))
            return CanvasElement(kind: .step(number: 0), frame: frame, style: style)
        case .text:
            return CanvasElement(
                kind: .text("Text"), frame: Self.frame(centredOn: start, size: Self.textSize), style: style)
        case .highlight:
            style.colorHex = Self.highlightColorHex
            return CanvasElement(kind: .highlight, frame: frame, style: style)
        default:
            var element = CanvasElement(kind: kind, frame: frame, style: style)
            element.flippedX = end.x < start.x
            element.flippedY = end.y < start.y
            return element
        }
    }

    private var kind: ElementKind {
        switch self {
        case .arrow: .arrow
        case .line: .line
        case .box: .box
        case .diamond: .diamond
        case .circle: .circle
        case .triangle: .triangle
        case .blur: .blur
        default: .highlight
        }
    }

    private static func frame(centredOn point: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height)
    }
}
