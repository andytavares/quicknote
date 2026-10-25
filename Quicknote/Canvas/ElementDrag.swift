import CoreGraphics
import Foundation
import QuicknoteKit

/// Moving, resizing or rotating an element with the pointer. Shared by the Snap and Card editors, which add their
/// own drags (drawing a new shape, signing) around it.
enum ElementDrag: Equatable {
    case moving(UUID, last: CGPoint)
    case resizing(UUID, ResizeHandle)
    case rotating(UUID)

    struct Start: Equatable {
        let selectedID: UUID?
        let drag: ElementDrag?
    }

    /// A press on a handle of the selected element resizes or rotates it; elsewhere it selects and moves
    /// the element under the pointer, or clears the selection on empty canvas.
    static func begin(at press: CanvasPointerEvent, in document: CanvasDocument, selected: CanvasElement?) -> Start {
        if let selected, let target = ElementHandles.target(at: press.point, of: selected, zoom: press.zoom) {
            switch target {
            case .resize(let handle): return Start(selectedID: selected.id, drag: .resizing(selected.id, handle))
            case .rotate: return Start(selectedID: selected.id, drag: .rotating(selected.id))
            }
        }
        let hit = document.elementID(at: press.point)
        return Start(selectedID: hit, drag: hit.map { .moving($0, last: press.point) })
    }

    /// Applies the pointer's new position and returns the drag to continue with.
    func follow(_ point: CGPoint, in document: inout CanvasDocument) -> ElementDrag {
        switch self {
        case .moving(let id, let last):
            document.moveElement(id: id, by: CGSize(width: point.x - last.x, height: point.y - last.y))
            return .moving(id, last: point)
        case .resizing(let id, let handle):
            document.resizeElement(id: id, handle: handle, to: point)
        case .rotating(let id):
            guard let element = document.elements.first(where: { $0.id == id }) else { break }
            let angle = atan2(point.y - element.frame.midY, point.x - element.frame.midX) + .pi / 2
            document.rotateElement(id: id, to: angle)
        }
        return self
    }
}
