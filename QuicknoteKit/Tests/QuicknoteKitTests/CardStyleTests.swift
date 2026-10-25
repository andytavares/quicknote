import CoreGraphics
import Foundation
import Testing

@testable import QuicknoteKit

struct CardStyleTests {
    @Test func thereAreSixStylesEachWithPaperAndInk() {
        #expect(CardStyle.allCases.map(\.title) == ["Sticky", "Postcard", "Polaroid", "Lined", "Minimal", "Kraft"])
        for style in CardStyle.allCases {
            #expect(style.paperColorHex.hasPrefix("#") && style.paperColorHex.count == 7)
            #expect(style.inkColorHex.hasPrefix("#") && style.inkColorHex.count == 7)
            #expect(style.paperColorHex != style.inkColorHex)
        }
    }

    @Test func kraftPaperMatchesTheDesign() {
        #expect(CardStyle.kraft.paperColorHex == "#C9A57A")
    }

    @Test func sizesHaveTheDesignPixelDimensions() {
        #expect(CardSize.square.pixelSize == CGSize(width: 1080, height: 1080))
        #expect(CardSize.story.pixelSize == CGSize(width: 1080, height: 1920))
        #expect(CardSize.wallpaper(width: 3024, height: 1964).pixelSize == CGSize(width: 3024, height: 1964))
        #expect(
            [CardSize.square, .story, .wallpaper(width: 1, height: 1)].map(\.title) == ["Square", "Story", "Wallpaper"])
    }

    @Test func cardSizeRoundTripsThroughJSON() throws {
        let size = CardSize.wallpaper(width: 2560, height: 1440)
        let decoded = try JSONDecoder().decode(CardSize.self, from: JSONEncoder().encode(size))
        #expect(decoded == size)
    }
}
