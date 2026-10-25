import Observation
import QuicknoteKit
import SwiftUI

/// Editing state of the Snap editor (S20): the document, undo history, tool, selection and the drag in progress.
@Observable
final class SnapEditorModel {
    static let palette = ["#E5484D", "#F2C14E", "#2F6FED"]
    static let strokeWidths: [CGFloat] = [3, 6, 10]

    private enum Drag {
        case creating(UUID, start: CGPoint)
        case moving(UUID, last: CGPoint)
        case resizing(UUID, ResizeHandle)
        case rotating(UUID)
    }

    private(set) var document: CanvasDocument
    private(set) var selectedID: UUID?
    var tool = SnapTool.arrow
    var style = ElementStyle(colorHex: palette[0], strokeWidth: strokeWidths[0])
    var caption: String
    /// The text element being typed into, with its current text.
    var editingTextID: UUID?
    var editingText = ""
    var noteId: Int64?

    let original: CGImage
    private var history = CanvasHistory()
    private var drag: Drag?
    private var recorded: CanvasDocument

    init(original: CGImage, document: CanvasDocument, noteId: Int64? = nil) {
        self.original = original
        self.document = document
        self.noteId = noteId
        self.caption = document.caption ?? ""
        self.recorded = document
        history.record(document)
    }

    var selectedElement: CanvasElement? { document.elements.first { $0.id == selectedID } }
    var resources: CanvasResources { CanvasResources(image: { [original] _ in original }) }

    // MARK: Pointer

    func handle(_ event: CanvasPointerEvent) {
        switch event.phase {
        case .began: pointerBegan(at: event.point, zoom: event.zoom)
        case .changed: pointerMoved(to: event.point)
        case .ended: pointerEnded(at: event.point)
        }
    }

    private func pointerBegan(at point: CGPoint, zoom: CGFloat) {
        commitTextEditing()
        if tool == .select {
            beginSelectDrag(at: point, zoom: zoom)
        } else if let element = tool.newElement(from: point, to: point, style: style) {
            document.add(element)
            let id = document.elements.last!.id
            selectedID = id
            drag = .creating(id, start: point)
        }
    }

    private func beginSelectDrag(at point: CGPoint, zoom: CGFloat) {
        if let selected = selectedElement, let target = ElementHandles.target(at: point, of: selected, zoom: zoom) {
            drag =
                switch target {
                case .resize(let handle): .resizing(selected.id, handle)
                case .rotate: .rotating(selected.id)
                }
            return
        }
        selectedID = document.elementID(at: point)
        drag = selectedID.map { .moving($0, last: point) }
    }

    private func pointerMoved(to point: CGPoint) {
        switch drag {
        case .creating(let id, let start): reshapeCreated(id, from: start, to: point)
        case .moving(let id, let last):
            document.moveElement(id: id, by: CGSize(width: point.x - last.x, height: point.y - last.y))
            drag = .moving(id, last: point)
        case .resizing(let id, let handle): document.resizeElement(id: id, handle: handle, to: point)
        case .rotating(let id): rotate(id, toward: point)
        case nil: break
        }
    }

    private func pointerEnded(at point: CGPoint) {
        pointerMoved(to: point)
        defer { drag = nil }
        guard let drag else { return }
        if case .creating(let id, _) = drag { finishCreating(id) }
        recordIfChanged()
    }

    private func reshapeCreated(_ id: UUID, from start: CGPoint, to end: CGPoint) {
        guard let index = document.elements.firstIndex(where: { $0.id == id }),
            var element = tool.newElement(from: start, to: end, style: style)
        else { return }
        element.id = id
        element.kind = document.elements[index].kind
        document.elements[index] = element
    }

    private func finishCreating(_ id: UUID) {
        guard let element = document.elements.first(where: { $0.id == id }) else { return }
        switch element.kind {
        case .text:
            beginEditingText(of: id)
            editingText = ""
        case .step: break
        default:
            if max(element.frame.width, element.frame.height) < CanvasElement.minimumSide {
                document.remove(id: id)
                selectedID = nil
            }
        }
    }

    private func rotate(_ id: UUID, toward point: CGPoint) {
        guard let element = document.elements.first(where: { $0.id == id }) else { return }
        let angle = atan2(point.y - element.frame.midY, point.x - element.frame.midX) + .pi / 2
        document.rotateElement(id: id, to: angle)
    }

    // MARK: Text

    func beginEditingText(of id: UUID) {
        guard let element = document.elements.first(where: { $0.id == id }), case .text(let string) = element.kind
        else { return }
        selectedID = id
        editingTextID = id
        editingText = string
    }

    /// Writes the typed text into the element; an empty text removes it.
    func commitTextEditing() {
        guard let id = editingTextID, let index = document.elements.firstIndex(where: { $0.id == id }) else { return }
        editingTextID = nil
        if editingText.isEmpty {
            document.remove(id: id)
            selectedID = nil
        } else {
            var element = document.elements[index]
            element.kind = .text(editingText)
            element.frame.size.width = max(CanvasRenderer.textSize(editingText, height: element.frame.height).width, 24)
            document.elements[index] = element
        }
        recordIfChanged()
    }

    // MARK: Edits

    func setColor(_ hex: String) {
        style.colorHex = hex
        edit { $0.style.colorHex = hex }
    }

    func setStrokeWidth(_ width: CGFloat) {
        style.strokeWidth = width
        edit { $0.style.strokeWidth = width }
    }

    func deleteSelection() {
        guard let id = selectedID else { return }
        document.remove(id: id)
        selectedID = nil
        recordIfChanged()
    }

    func nudgeSelection(by offset: CGSize) {
        guard let id = selectedID else { return }
        document.moveElement(id: id, by: offset)
        recordIfChanged()
    }

    func undo() { history.undo().map(restore) }
    func redo() { history.redo().map(restore) }

    func saveCaption() { document.caption = caption.isEmpty ? nil : caption }

    private func edit(_ change: (inout CanvasElement) -> Void) {
        guard let index = document.elements.firstIndex(where: { $0.id == selectedID }) else { return }
        change(&document.elements[index])
        recordIfChanged()
    }

    private func restore(_ restored: CanvasDocument) {
        document = restored
        recorded = restored
        if selectedElement == nil { selectedID = nil }
    }

    private func recordIfChanged() {
        guard document != recorded else { return }
        history.record(document)
        recorded = document
    }
}
