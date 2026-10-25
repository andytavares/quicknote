import CoreGraphics
import QuicknoteKit
import Testing

@testable import Quicknote

@MainActor
struct CanvasRendererTests {
    private let paper = CanvasBackground.card(style: .minimal, size: .wallpaper(width: 200, height: 100))
    private let resources = CanvasResources(image: { _ in nil })

    private func box() -> CanvasElement {
        CanvasElement(
            kind: .box, frame: CGRect(x: 20, y: 20, width: 100, height: 50),
            style: ElementStyle(colorHex: "#FF0000", strokeWidth: 6))
    }

    @Test func outputSizeIsTheDocumentsPixelSize() throws {
        let document = CanvasDocument(background: paper)
        let image = try #require(CanvasRenderer.render(document, resources: resources))
        #expect((image.width, image.height) == (200, 100))
        let doubled = try #require(CanvasRenderer.render(document, scale: 2, resources: resources))
        #expect((doubled.width, doubled.height) == (400, 200))
    }

    @Test func aBoxPaintsItsOutlineAndLeavesTheRestOfThePaper() throws {
        let document = CanvasDocument(background: paper, elements: [box()])
        let image = try #require(CanvasRenderer.render(document, resources: resources))
        #expect(SnapTestSupport.pixel(image, x: 22, y: 45) == (255, 0, 0))
        #expect(SnapTestSupport.pixel(image, x: 70, y: 45) == (255, 255, 255))
        #expect(SnapTestSupport.pixel(image, x: 5, y: 5) == (255, 255, 255))
    }

    @Test func aSnapBackgroundDrawsItsImageUnderTheElements() throws {
        let snap = SnapTestSupport.image(width: 100, height: 100, leftHalfBlack: true)
        let document = CanvasDocument(background: .image(attachmentId: 1, size: CGSize(width: 100, height: 100)))
        let image = try #require(CanvasRenderer.render(document, resources: CanvasResources(image: { _ in snap })))
        #expect(SnapTestSupport.pixel(image, x: 10, y: 50) == (0, 0, 0))
        #expect(SnapTestSupport.pixel(image, x: 90, y: 50) == (255, 255, 255))
    }

    @Test func blurSoftensTheEdgeUnderItAndNothingOutside() throws {
        let snap = SnapTestSupport.image(width: 100, height: 100, leftHalfBlack: true)
        let blur = CanvasElement(kind: .blur, frame: CGRect(x: 30, y: 30, width: 40, height: 40))
        let document = CanvasDocument(
            background: .image(attachmentId: 1, size: CGSize(width: 100, height: 100)), elements: [blur])
        let image = try #require(CanvasRenderer.render(document, resources: CanvasResources(image: { _ in snap })))
        #expect(SnapTestSupport.pixel(image, x: 46, y: 50).red > 20)
        #expect(SnapTestSupport.pixel(image, x: 46, y: 10) == (0, 0, 0))
    }

    @Test func theBackgroundHookReplacesThePlainRectangle() throws {
        var custom = resources
        custom.paintBackground = { _, _, context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }
        let image = try #require(CanvasRenderer.render(CanvasDocument(background: paper), resources: custom))
        #expect(SnapTestSupport.pixel(image, x: 50, y: 50) == (0, 0, 255))
    }
}
