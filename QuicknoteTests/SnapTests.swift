import CoreGraphics
import Foundation
import QuicknoteKit
import Testing

@testable import Quicknote

struct SnapCaptureRequestTests {
    @Test func mainDisplayAtRetinaScaleFlipsYAndDoublesPixels() {
        let display = SnapDisplay(displayID: 1, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), scale: 2)
        let request = SnapCaptureRequest.make(selection: CGRect(x: 100, y: 500, width: 350, height: 210), on: display)
        #expect(request.sourceRect == CGRect(x: 100, y: 190, width: 350, height: 210))
        #expect(request.pixelSize == CGSize(width: 700, height: 420))
    }

    @Test func displayToTheRightWithBelowOriginUsesDisplayLocalPoints() {
        let display = SnapDisplay(displayID: 2, frame: CGRect(x: 1440, y: -180, width: 1920, height: 1080), scale: 1)
        let request = SnapCaptureRequest.make(selection: CGRect(x: 1500, y: 100, width: 300, height: 200), on: display)
        #expect(request.sourceRect == CGRect(x: 60, y: 600, width: 300, height: 200))
        #expect(request.pixelSize == CGSize(width: 300, height: 200))
    }

    @Test func displayToTheLeftHasNegativeGlobalOrigin() {
        let display = SnapDisplay(displayID: 3, frame: CGRect(x: -1920, y: 200, width: 1920, height: 1080), scale: 1)
        let request = SnapCaptureRequest.make(selection: CGRect(x: -1000, y: 400, width: 100, height: 50), on: display)
        #expect(request.sourceRect == CGRect(x: 920, y: 830, width: 100, height: 50))
    }

    @Test func fractionalScaleRoundsPixelsToWholeNumbers() {
        let display = SnapDisplay(displayID: 4, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), scale: 1.5)
        let request = SnapCaptureRequest.make(selection: CGRect(x: 0, y: 0, width: 101, height: 33), on: display)
        #expect(request.pixelSize == CGSize(width: 152, height: 50))
    }
}

struct SnapToolTests {
    private let style = ElementStyle(colorHex: "#2F6FED", strokeWidth: 6)

    @Test func stepsAreNumberedInOrderAndCentredOnTheClick() throws {
        var document = CanvasDocument(background: .image(attachmentId: 0, size: CGSize(width: 500, height: 500)))
        for point in [CGPoint(x: 100, y: 100), CGPoint(x: 200, y: 100)] {
            document.add(try #require(SnapTool.step.newElement(from: point, to: point, style: style)))
        }
        #expect(document.elements.map(\.kind) == [.step(number: 1), .step(number: 2)])
        #expect(document.elements[0].frame == CGRect(x: 78, y: 78, width: 44, height: 44))
    }

    @Test func highlightIsYellowWhateverColourIsPicked() throws {
        let element = try #require(SnapTool.highlight.newElement(from: .zero, to: CGPoint(x: 80, y: 20), style: style))
        #expect(element.style.colorHex == "#F2C14E")
        #expect(element.style.strokeWidth == 6)
    }

    @Test func shapesTakeThePickedStyleAndAnArrowDraggedBackwardsIsFlipped() throws {
        let arrow = try #require(
            SnapTool.arrow.newElement(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 40, y: 70), style: style))
        #expect(arrow.frame == CGRect(x: 40, y: 70, width: 60, height: 30))
        #expect(arrow.style == style)
        #expect(arrow.flippedX && arrow.flippedY)
    }

    @Test func selectMakesNothing() {
        #expect(SnapTool.select.newElement(from: .zero, to: CGPoint(x: 9, y: 9), style: style) == nil)
    }

    @Test func everyToolHasItsOwnShortcut() {
        #expect(Set(SnapTool.allCases.map(\.shortcut)).count == SnapTool.allCases.count)
    }
}

@MainActor
struct SnapEditorModelTests {
    private func model() -> SnapEditorModel {
        let size = CGSize(width: 400, height: 300)
        return SnapEditorModel(
            original: SnapTestSupport.image(width: 400, height: 300),
            document: CanvasDocument(background: .image(attachmentId: 0, size: size)))
    }

    private func drag(_ model: SnapEditorModel, from start: CGPoint, to end: CGPoint) {
        model.handle(CanvasPointerEvent(phase: .began, point: start, zoom: 1))
        model.handle(CanvasPointerEvent(phase: .changed, point: end, zoom: 1))
        model.handle(CanvasPointerEvent(phase: .ended, point: end, zoom: 1))
    }

    @Test func draggingWithABoxToolAddsABoxAndUndoRemovesIt() {
        let model = model()
        model.tool = .box
        drag(model, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60))
        #expect(model.document.elements.map(\.kind) == [.box])
        #expect(model.document.elements[0].frame == CGRect(x: 10, y: 10, width: 100, height: 50))
        model.undo()
        #expect(model.document.elements.isEmpty)
        model.redo()
        #expect(model.document.elements.count == 1)
    }

    @Test func aClickWithAShapeToolLeavesNothingBehind() {
        let model = model()
        model.tool = .circle
        drag(model, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 51, y: 51))
        #expect(model.document.elements.isEmpty)
    }

    @Test func selectDragMovesTheElementAndDeleteRemovesIt() {
        let model = model()
        model.tool = .box
        drag(model, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60))
        model.tool = .select
        drag(model, from: CGPoint(x: 60, y: 35), to: CGPoint(x: 90, y: 55))
        #expect(model.document.elements[0].frame.origin == CGPoint(x: 40, y: 30))
        model.deleteSelection()
        #expect(model.document.elements.isEmpty)
    }

    @Test func draggingTheRotationHandleRotatesTheSelection() {
        let model = model()
        model.tool = .box
        drag(model, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 200, y: 160))
        model.tool = .select
        let top = CGPoint(x: 150, y: 100 - 28)
        drag(model, from: top, to: CGPoint(x: 250, y: 130))
        #expect(abs(model.document.elements[0].rotation - .pi / 2) < 0.01)
    }

    @Test func pickingAColourRecolorsTheSelectionAndLaterShapes() {
        let model = model()
        model.tool = .box
        drag(model, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 110, y: 60))
        model.setColor("#2F6FED")
        #expect(model.document.elements[0].style.colorHex == "#2F6FED")
        drag(model, from: CGPoint(x: 150, y: 10), to: CGPoint(x: 250, y: 60))
        #expect(model.document.elements[1].style.colorHex == "#2F6FED")
    }

    @Test func aTextClickOpensTheEditorAndEmptyTextIsDiscarded() {
        let model = model()
        model.tool = .text
        drag(model, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 100, y: 100))
        #expect(model.editingTextID != nil)
        model.commitTextEditing()
        #expect(model.document.elements.isEmpty)
        drag(model, from: CGPoint(x: 100, y: 100), to: CGPoint(x: 100, y: 100))
        model.editingText = "too cramped!"
        model.commitTextEditing()
        #expect(model.document.elements.map(\.kind) == [.text("too cramped!")])
    }
}
