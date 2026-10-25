import CoreGraphics
import Foundation
import Testing

@testable import QuicknoteKit

struct CanvasDocumentTests {
    private func emptyDocument() -> CanvasDocument {
        CanvasDocument(background: .card(style: .sticky, size: .square))
    }

    private func element(_ kind: ElementKind, frame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 50))
        -> CanvasElement
    {
        CanvasElement(kind: kind, frame: frame)
    }

    @Test func addedStepsGetConsecutiveNumbers() {
        var document = emptyDocument()
        document.add(element(.step(number: 0)))
        document.add(element(.box))
        document.add(element(.step(number: 0)))
        let numbers = document.elements.compactMap { element -> Int? in
            if case .step(let number) = element.kind { return number }
            return nil
        }
        #expect(numbers == [1, 2])
    }

    @Test func removingAStepRenumbersTheRest() {
        var document = emptyDocument()
        let steps = (0..<3).map { _ in element(.step(number: 0)) }
        steps.forEach { document.add($0) }
        document.remove(id: steps[0].id)
        let numbers = document.elements.map(\.kind)
        #expect(numbers == [.step(number: 1), .step(number: 2)])
    }

    @Test func moveShiftsTheFrameOnly() {
        var document = emptyDocument()
        let box = element(.box)
        document.add(box)
        document.moveElement(id: box.id, by: CGSize(width: 10, height: -5))
        #expect(document.elements[0].frame == CGRect(x: 10, y: -5, width: 100, height: 50))
    }

    @Test func movingAnUnknownIdChangesNothing() {
        var document = emptyDocument()
        document.add(element(.box))
        let before = document
        document.moveElement(id: UUID(), by: CGSize(width: 10, height: 10))
        #expect(document == before)
    }

    @Test func rotateSetsRotation() {
        var document = emptyDocument()
        let box = element(.box)
        document.add(box)
        document.rotateElement(id: box.id, to: .pi / 2)
        #expect(document.elements[0].rotation == .pi / 2)
    }

    @Test func bringToFrontMovesElementLast() {
        var document = emptyDocument()
        let first = element(.box)
        let second = element(.circle)
        document.add(first)
        document.add(second)
        document.bringToFront(id: first.id)
        #expect(document.elements.map(\.id) == [second.id, first.id])
    }

    @Test func documentSurvivesJSONRoundTrip() throws {
        var document = CanvasDocument(
            background: .image(attachmentId: 7, size: CGSize(width: 800, height: 600)),
            caption: "Pricing page"
        )
        document.add(element(.ink(points: [CGPoint(x: 1, y: 2), CGPoint(x: 3, y: 4)])))
        document.add(element(.extraNote(text: "Hi", colorHex: "#FBE38E")))
        document.add(element(.text("Hello")))
        let decoded = try JSONDecoder().decode(CanvasDocument.self, from: JSONEncoder().encode(document))
        #expect(decoded == document)
        #expect(decoded.showsMadeWithMark == false)
    }

    @Test func noteCanvasRoundTripsThroughCanvasJSON() {
        var note = Note(body: "Card")
        #expect(note.canvas == nil)
        note.canvas = emptyDocument()
        #expect(note.canvasJSON != nil)
        #expect(note.canvas == emptyDocument())
        note.canvas = nil
        #expect(note.canvasJSON == nil)
    }

    @Test func corruptCanvasJSONReadsAsNil() {
        var note = Note(body: "Card")
        note.canvasJSON = "{not json"
        #expect(note.canvas == nil)
    }

    @Test func keepingElementsInsideMovesThemOnToTheCanvasAndShrinksOversizedOnes() {
        var document = CanvasDocument(background: .card(style: .sticky, size: .square))
        document.add(CanvasElement(kind: .box, frame: CGRect(x: 100, y: 1_500, width: 200, height: 100)))
        document.add(CanvasElement(kind: .box, frame: CGRect(x: -50, y: 10, width: 1_500, height: 80)))
        document.add(CanvasElement(kind: .box, frame: CGRect(x: 10, y: 10, width: 50, height: 50)))
        document.keepElementsInside(CGSize(width: 1_080, height: 1_080))
        #expect(
            document.elements.map(\.frame) == [
                CGRect(x: 100, y: 980, width: 200, height: 100),
                CGRect(x: 0, y: 10, width: 1_080, height: 80),
                CGRect(x: 10, y: 10, width: 50, height: 50),
            ])
    }
}
