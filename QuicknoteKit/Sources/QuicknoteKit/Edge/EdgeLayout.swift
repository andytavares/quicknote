import CoreGraphics

/// Where the edge panel and its tabs sit on one display. Frames are in screen coordinates (origin bottom-left).
public struct EdgeLayout: Equatable, Sendable {
    public static let tabWidth: CGFloat = 16
    public static let tabHeight: CGFloat = 44
    public static let tabSpacing: CGFloat = 6
    public static let topInset: CGFloat = 60
    public static let bottomInset: CGFloat = 24
    public static let cardWidth: CGFloat = 260
    public static let cardHeight: CGFloat = 280
    public static let cardGap: CGFloat = 8

    /// One frame per tab; when notes do not fit the last frame is the "+N" overflow tab.
    public let tabFrames: [CGRect]
    /// How many notes have no tab of their own.
    public let overflowCount: Int
    public let panelFrame: CGRect

    public var isEmpty: Bool { panelFrame.isEmpty }

    public init(tabCount: Int, visibleFrame: CGRect, showsCard: Bool) {
        let available = visibleFrame.height - Self.topInset - Self.bottomInset
        let slotLimit = max(1, Int((available + Self.tabSpacing) / (Self.tabHeight + Self.tabSpacing)))
        let slots = min(tabCount, slotLimit)
        overflowCount = tabCount > slotLimit ? tabCount - (slotLimit - 1) : 0
        let top = visibleFrame.maxY - Self.topInset
        tabFrames = (0..<slots).map { index in
            CGRect(
                x: visibleFrame.maxX - Self.tabWidth,
                y: top - Self.tabHeight - CGFloat(index) * (Self.tabHeight + Self.tabSpacing),
                width: Self.tabWidth, height: Self.tabHeight)
        }
        let tabsHeight = slots == 0 ? 0 : CGFloat(slots) * (Self.tabHeight + Self.tabSpacing) - Self.tabSpacing
        let height = showsCard ? min(max(tabsHeight, Self.cardHeight), available) : tabsHeight
        let width = showsCard ? Self.tabWidth + Self.cardGap + Self.cardWidth : (slots == 0 ? 0 : Self.tabWidth)
        panelFrame = CGRect(x: visibleFrame.maxX - width, y: top - height, width: width, height: height)
    }
}
