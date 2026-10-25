import CoreGraphics
import Foundation

extension CanvasDocument {
    /// Appends on top. A step gets the next step number.
    public mutating func add(_ element: CanvasElement) {
        var element = element
        if case .step = element.kind {
            let stepCount = elements.filter { if case .step = $0.kind { true } else { false } }.count
            element.kind = .step(number: stepCount + 1)
        }
        elements.append(element)
    }

    public mutating func moveElement(id: UUID, by offset: CGSize) {
        update(id) { $0.frame = $0.frame.offsetBy(dx: offset.width, dy: offset.height) }
    }

    public mutating func rotateElement(id: UUID, to radians: CGFloat) {
        update(id) { $0.rotation = radians }
    }

    public mutating func bringToFront(id: UUID) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
        elements.append(elements.remove(at: index))
    }

    public mutating func remove(id: UUID) {
        elements.removeAll { $0.id == id }
        renumberSteps()
    }

    /// Numbers steps 1...n in z-order, closing the gap a removed step left.
    public mutating func renumberSteps() {
        var next = 1
        for index in elements.indices {
            guard case .step = elements[index].kind else { continue }
            elements[index].kind = .step(number: next)
            next += 1
        }
    }

    public mutating func resizeElement(id: UUID, handle: ResizeHandle, to canvasPoint: CGPoint) {
        update(id) { $0 = $0.resized(handle: handle, to: canvasPoint) }
    }

    private mutating func update(_ id: UUID, _ change: (inout CanvasElement) -> Void) {
        guard let index = elements.firstIndex(where: { $0.id == id }) else { return }
        change(&elements[index])
    }
}
