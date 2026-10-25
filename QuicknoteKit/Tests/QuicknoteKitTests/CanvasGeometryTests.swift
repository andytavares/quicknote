import CoreGraphics
import Foundation
import Testing

@testable import QuicknoteKit

struct CanvasGeometryTests {
    private func document(with elements: CanvasElement...) -> CanvasDocument {
        var document = CanvasDocument(background: .card(style: .minimal, size: .square))
        elements.forEach { document.add($0) }
        return document
    }

    private func box(frame: CGRect, rotation: CGFloat = 0, kind: ElementKind = .box) -> CanvasElement {
        CanvasElement(kind: kind, frame: frame, rotation: rotation)
    }

    @Test func hitTestFindsTopmostElement() {
        let bottom = box(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let top = box(frame: CGRect(x: 50, y: 50, width: 100, height: 100))
        let canvas = document(with: bottom, top)
        #expect(canvas.elementID(at: CGPoint(x: 60, y: 60)) == top.id)
        #expect(canvas.elementID(at: CGPoint(x: 10, y: 10)) == bottom.id)
        #expect(canvas.elementID(at: CGPoint(x: 500, y: 500)) == nil)
    }

    @Test func hitTestRespectsRotation() {
        // A 100x20 bar turned 90 degrees about (50, 10) covers x 40...60, y -40...60.
        let bar = box(frame: CGRect(x: 0, y: 0, width: 100, height: 20), rotation: .pi / 2)
        let canvas = document(with: bar)
        #expect(canvas.elementID(at: CGPoint(x: 50, y: 50)) == bar.id)
        #expect(canvas.elementID(at: CGPoint(x: 5, y: 10)) == nil)
    }

    @Test func hitTestUsesShapeNotBoundingBox() {
        let circle = box(frame: CGRect(x: 0, y: 0, width: 100, height: 100), kind: .circle)
        let diamond = box(frame: CGRect(x: 200, y: 0, width: 100, height: 100), kind: .diamond)
        let triangle = box(frame: CGRect(x: 400, y: 0, width: 100, height: 100), kind: .triangle)
        let canvas = document(with: circle, diamond, triangle)
        #expect(canvas.elementID(at: CGPoint(x: 3, y: 3)) == nil)
        #expect(canvas.elementID(at: CGPoint(x: 50, y: 50)) == circle.id)
        #expect(canvas.elementID(at: CGPoint(x: 203, y: 3)) == nil)
        #expect(canvas.elementID(at: CGPoint(x: 250, y: 50)) == diamond.id)
        #expect(canvas.elementID(at: CGPoint(x: 403, y: 5)) == nil)
        #expect(canvas.elementID(at: CGPoint(x: 450, y: 90)) == triangle.id)
    }

    @Test func lineHitsWithinSixPointsOfTheSegment() {
        let line = box(frame: CGRect(x: 0, y: 0, width: 100, height: 100), kind: .line)
        let canvas = document(with: line)
        #expect(canvas.elementID(at: CGPoint(x: 50, y: 50)) == line.id)
        // Distance from (60, 40) to the diagonal is 14.1; from (53, 47) it is 4.2.
        #expect(canvas.elementID(at: CGPoint(x: 60, y: 40)) == nil)
        #expect(canvas.elementID(at: CGPoint(x: 53, y: 47)) == line.id)
    }

    @Test func flippedArrowRunsFromTopRightToBottomLeft() {
        var arrow = box(frame: CGRect(x: 0, y: 0, width: 100, height: 100), kind: .arrow)
        arrow.flippedX = true
        let canvas = document(with: arrow)
        #expect(canvas.elementID(at: CGPoint(x: 80, y: 20)) == arrow.id)
        #expect(canvas.elementID(at: CGPoint(x: 20, y: 20)) == nil)
    }

    @Test func resizeBottomRightGrowsFromTopLeft() {
        var canvas = document(with: box(frame: CGRect(x: 10, y: 10, width: 100, height: 50)))
        let id = canvas.elements[0].id
        canvas.resizeElement(id: id, handle: .bottomRight, to: CGPoint(x: 210, y: 110))
        #expect(canvas.elements[0].frame == CGRect(x: 10, y: 10, width: 200, height: 100))
    }

    @Test func edgeHandleChangesOneAxis() {
        var canvas = document(with: box(frame: CGRect(x: 0, y: 0, width: 100, height: 50)))
        let id = canvas.elements[0].id
        canvas.resizeElement(id: id, handle: .right, to: CGPoint(x: 150, y: 999))
        #expect(canvas.elements[0].frame == CGRect(x: 0, y: 0, width: 150, height: 50))
    }

    @Test func resizeNeverGoesBelowEightByEight() {
        var canvas = document(with: box(frame: CGRect(x: 0, y: 0, width: 100, height: 50)))
        let id = canvas.elements[0].id
        canvas.resizeElement(id: id, handle: .bottomRight, to: CGPoint(x: -40, y: -40))
        #expect(canvas.elements[0].frame == CGRect(x: 0, y: 0, width: 8, height: 8))
        canvas.resizeElement(id: id, handle: .topLeft, to: CGPoint(x: 90, y: 90))
        #expect(canvas.elements[0].frame == CGRect(x: 0, y: 0, width: 8, height: 8))
    }

    @Test func rotatedResizeKeepsTheOppositeCornerFixedOnScreen() {
        // 100x50 box turned 90 degrees about its centre (50, 25).
        // Its local top-left corner (0, 0) lands at (75, -25); bottom-right (100, 50) lands at (25, 75).
        var canvas = document(with: box(frame: CGRect(x: 0, y: 0, width: 100, height: 50), rotation: .pi / 2))
        let id = canvas.elements[0].id
        // Drag the bottom-right handle 50 further along the element's local x axis.
        // Local x axis points down the canvas after a quarter turn, so canvas (25, 125) is local (150, 50).
        canvas.resizeElement(id: id, handle: .bottomRight, to: CGPoint(x: 25, y: 125))
        let resized = canvas.elements[0]
        #expect(abs(resized.frame.width - 150) < 0.001)
        #expect(abs(resized.frame.height - 50) < 0.001)
        let topLeftOnScreen = resized.canvasPoint(fromLocal: resized.frame.origin)
        #expect(abs(topLeftOnScreen.x - 75) < 0.001)
        #expect(abs(topLeftOnScreen.y - -25) < 0.001)
    }

    @Test func resizingInkScalesItsPoints() {
        let ink = box(
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            kind: .ink(points: [CGPoint(x: 50, y: 20)])
        )
        var canvas = document(with: ink)
        canvas.resizeElement(id: ink.id, handle: .bottomRight, to: CGPoint(x: 200, y: 100))
        #expect(canvas.elements[0].kind == .ink(points: [CGPoint(x: 100, y: 20)]))
    }
}
