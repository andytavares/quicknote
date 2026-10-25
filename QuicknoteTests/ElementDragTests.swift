import CoreGraphics
import QuicknoteKit
import Testing

@testable import Quicknote

struct ElementDragTests {
    private let box = CanvasElement(kind: .box, frame: CGRect(x: 100, y: 100, width: 200, height: 100))

    private var document: CanvasDocument {
        var document = CanvasDocument(background: .card(style: .sticky, size: .square))
        document.add(box)
        return document
    }

    private func press(_ point: CGPoint) -> CanvasPointerEvent {
        CanvasPointerEvent(phase: .began, point: point, zoom: 1)
    }

    @Test func pressingAnElementSelectsItAndStartsMovingIt() {
        let start = ElementDrag.begin(at: press(CGPoint(x: 150, y: 150)), in: document, selected: nil)
        #expect(start.selectedID == box.id)
        #expect(start.drag == .moving(box.id, last: CGPoint(x: 150, y: 150)))
    }

    @Test func pressingEmptyCanvasClearsTheSelection() {
        let start = ElementDrag.begin(at: press(CGPoint(x: 900, y: 900)), in: document, selected: box)
        #expect(start.selectedID == nil)
        #expect(start.drag == nil)
    }

    @Test func pressingAHandleOfTheSelectionResizesIt() {
        let corner = CGPoint(x: 300, y: 200)
        let start = ElementDrag.begin(at: press(corner), in: document, selected: box)
        #expect(start.drag == .resizing(box.id, .bottomRight))
    }

    @Test func movingFollowsThePointerFromTheLastPoint() {
        var moved = document
        let next = ElementDrag.moving(box.id, last: CGPoint(x: 150, y: 150))
            .follow(CGPoint(x: 160, y: 140), in: &moved)
        #expect(moved.elements[0].frame.origin == CGPoint(x: 110, y: 90))
        #expect(next == .moving(box.id, last: CGPoint(x: 160, y: 140)))
    }

    @Test func rotatingPointsTheTopOfTheElementAtThePointer() {
        var rotated = document
        _ = ElementDrag.rotating(box.id).follow(CGPoint(x: 400, y: 150), in: &rotated)
        #expect(abs(rotated.elements[0].rotation - .pi / 2) < 0.0001)
    }
}
