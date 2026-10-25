import CoreGraphics
import Foundation

public enum CanvasBackground: Codable, Equatable, Sendable {
    /// A Snap: the captured image stored as an attachment, with its pixel size.
    case image(attachmentId: Int64, size: CGSize)
    /// A Card: paper style and export size.
    case card(style: CardStyle, size: CardSize)
}

public enum ElementKind: Codable, Equatable, Sendable {
    case arrow, line, box, diamond, circle, triangle
    case text(String)
    case step(number: Int)
    case highlight, blur
    /// An emoji or the name of a bundled sticker.
    case sticker(String)
    case photo(attachmentId: Int64)
    case washi(pattern: String)
    /// Freehand stroke; points are relative to the frame origin.
    case ink(points: [CGPoint])
    case extraNote(text: String, colorHex: String)
}

public struct ElementStyle: Codable, Equatable, Sendable {
    public var colorHex: String
    public var strokeWidth: CGFloat
    public var fontName: String?

    public init(colorHex: String = "#D93D42", strokeWidth: CGFloat = 4, fontName: String? = nil) {
        self.colorHex = colorHex
        self.strokeWidth = strokeWidth
        self.fontName = fontName
    }
}

public struct CanvasElement: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: ElementKind
    /// Unrotated frame in canvas coordinates.
    public var frame: CGRect
    /// Radians, clockwise on screen, about the frame centre.
    public var rotation: CGFloat
    public var style: ElementStyle
    /// Arrows and lines run from (minX, minY) to (maxX, maxY); a flip mirrors that diagonal on one axis.
    public var flippedX: Bool
    public var flippedY: Bool

    public init(
        id: UUID = UUID(),
        kind: ElementKind,
        frame: CGRect,
        rotation: CGFloat = 0,
        style: ElementStyle = ElementStyle()
    ) {
        self.id = id
        self.kind = kind
        self.frame = frame
        self.rotation = rotation
        self.style = style
        self.flippedX = false
        self.flippedY = false
    }
}

/// One canvas model for Snaps and Cards. `elements` is in z-order: the last element is on top.
public struct CanvasDocument: Codable, Equatable, Sendable {
    public var background: CanvasBackground
    public var elements: [CanvasElement]
    public var caption: String?
    public var showsMadeWithMark: Bool

    public init(
        background: CanvasBackground,
        elements: [CanvasElement] = [],
        caption: String? = nil,
        showsMadeWithMark: Bool = false
    ) {
        self.background = background
        self.elements = elements
        self.caption = caption
        self.showsMadeWithMark = showsMadeWithMark
    }
}
