import CoreGraphics

/// Export size of a card. Wallpaper carries the pixel size of the display it was made on.
public enum CardSize: Codable, Equatable, Sendable {
    case square
    case story
    case wallpaper(width: Int, height: Int)

    public var pixelSize: CGSize {
        switch self {
        case .square: CGSize(width: 1080, height: 1080)
        case .story: CGSize(width: 1080, height: 1920)
        case .wallpaper(let width, let height): CGSize(width: width, height: height)
        }
    }

    public var title: String {
        switch self {
        case .square: "Square"
        case .story: "Story"
        case .wallpaper: "Wallpaper"
        }
    }
}
