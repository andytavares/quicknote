import CoreGraphics
import Testing

@testable import QuicknoteKit

struct EdgeLayoutTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 800)

    @Test func tabsStackUpFromTheBottomOfTheRightEdge() {
        let layout = EdgeLayout(tabCount: 3, visibleFrame: screen, showsCard: false)
        let bottom = screen.minY + EdgeLayout.bottomInset
        #expect(layout.tabFrames.count == 3)
        #expect(
            layout.tabFrames[0]
                == CGRect(
                    x: 1440 - EdgeLayout.tabWidth, y: bottom, width: EdgeLayout.tabWidth,
                    height: EdgeLayout.tabHeight))
        let step = EdgeLayout.tabHeight + EdgeLayout.tabSpacing
        #expect(layout.tabFrames[2].minY == layout.tabFrames[0].minY + 2 * step)
        #expect(layout.panelFrame.minY == bottom)
        #expect(layout.overflowCount == 0)
    }

    @Test func tabsNeverReachPastTheMiddleOfTheScreen() {
        let layout = EdgeLayout(tabCount: 20, visibleFrame: screen, showsCard: false)
        #expect(layout.overflowCount > 0)
        #expect(layout.tabFrames.allSatisfy { $0.maxY <= screen.midY })
        #expect(layout.panelFrame.maxY <= screen.midY)
        #expect(EdgeLayout(tabCount: 20, visibleFrame: screen, showsCard: true).panelFrame.maxY <= screen.midY)
    }

    @Test func thePanelHugsTheTabsSoTheRestOfTheScreenStaysClickThrough() {
        let layout = EdgeLayout(tabCount: 3, visibleFrame: screen, showsCard: false)
        #expect(layout.panelFrame.width == EdgeLayout.tabWidth)
        #expect(layout.panelFrame.maxX == screen.maxX)
        #expect(layout.panelFrame.height == 3 * EdgeLayout.tabHeight + 2 * EdgeLayout.tabSpacing)
    }

    @Test func noTabsAndNoCardMeansNoPanel() {
        #expect(EdgeLayout(tabCount: 0, visibleFrame: screen, showsCard: false).isEmpty)
        #expect(!EdgeLayout(tabCount: 0, visibleFrame: screen, showsCard: true).isEmpty)
    }

    @Test func aCardWidensAndHeightensThePanelToHoldIt() {
        let layout = EdgeLayout(tabCount: 1, visibleFrame: screen, showsCard: true)
        #expect(layout.panelFrame.width == EdgeLayout.tabWidth + EdgeLayout.cardGap + EdgeLayout.cardWidth)
        #expect(layout.panelFrame.height == EdgeLayout.cardHeight)
        #expect(layout.panelFrame.minY == screen.minY + EdgeLayout.bottomInset)
    }

    @Test func tooManyTabsEndInAnOverflowTabCountingTheHiddenOnes() {
        let short = CGRect(x: 0, y: 0, width: 1440, height: 400)
        let layout = EdgeLayout(tabCount: 20, visibleFrame: short, showsCard: false)
        let available = short.height / 2 - EdgeLayout.bottomInset
        #expect(layout.panelFrame.height <= available)
        #expect(layout.overflowCount > 0)
        // The last frame belongs to the overflow tab itself.
        #expect(layout.tabFrames.count - 1 + layout.overflowCount == 20)
    }

    @Test func aSecondDisplayWithAnOffsetOriginStillDocksToItsOwnRightEdge() {
        let second = CGRect(x: 1440, y: -200, width: 1920, height: 1080)
        let layout = EdgeLayout(tabCount: 1, visibleFrame: second, showsCard: false)
        #expect(layout.panelFrame.maxX == second.maxX)
        #expect(layout.panelFrame.minY == second.minY + EdgeLayout.bottomInset)
    }
}
