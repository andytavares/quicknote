import AppKit
import Observation
import QuicknoteKit

enum CardSizeChoice: String, CaseIterable, Identifiable {
    case square, story, wallpaper

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// A washi tape look: the pattern name the painter knows and its colour.
struct WashiPreset: Identifiable {
    let name: String
    let pattern: String
    let colorHex: String
    var id: String { name }
}

/// Editing state of the Card editor (S21): the document, undo history, selection, signing and the drag in progress.
@Observable
final class CardEditorModel {
    static let stickers = ["🎂", "✨", "🌻", "★", "♥", "✈️"]
    static let emoji = ["😀", "😍", "🥳", "😎", "🤗", "😴", "🎉", "🎁", "🎈", "🌈", "🌸", "🍀", "🍋", "🍰", "☕️", "🏖️"]
    static let noteColors = ["#FFD966", "#A8D8B9", "#F4A6B8"]
    static let washiPresets = [
        WashiPreset(name: "Pink", pattern: "plain", colorHex: "#F4A6B8"),
        WashiPreset(name: "Mint stripes", pattern: "stripes", colorHex: "#7CC4A4"),
        WashiPreset(name: "Blue", pattern: "plain", colorHex: "#8FB8E8"),
        WashiPreset(name: "Gold stripes", pattern: "stripes", colorHex: "#E8B94A"),
    ]
    static let signStrokeWidth: CGFloat = 6

    private enum Drag {
        case drawing(UUID, points: [CGPoint])
        case moving(UUID, last: CGPoint)
        case resizing(UUID, ResizeHandle)
        case rotating(UUID)
    }

    private(set) var document: CanvasDocument
    private(set) var selectedID: UUID?
    private(set) var photos: [Int64: CGImage] = [:]
    var isSigning = false
    var noteId: Int64?
    var screenPixelSize = CardEditorModel.mainScreenPixelSize

    private let saver: CardSaver
    private var history = CanvasHistory()
    private var drag: Drag?
    private var recorded: CanvasDocument
    private let initial: CanvasDocument

    init(document: CanvasDocument, noteId: Int64?, saver: CardSaver) {
        self.document = document
        self.noteId = noteId
        self.saver = saver
        self.recorded = document
        self.initial = document
        history.record(document)
        loadPhotos()
    }

    static var mainScreenPixelSize: CGSize {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let scale = screen?.backingScaleFactor ?? 2
        let size = screen?.frame.size ?? CGSize(width: 1440, height: 900)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    /// A sticky card carrying the note's text, or a blank one.
    static func startingDocument(text: String?) -> CanvasDocument {
        var document = CanvasDocument(background: .card(style: .sticky, size: .square))
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return document }
        let frame = CGRect(x: 90, y: 120, width: 900, height: 72)
        document.add(
            CanvasElement(
                kind: .text(String(text.prefix(240))), frame: frame,
                style: ElementStyle(colorHex: CardStyle.sticky.inkColorHex)))
        return document
    }

    var cardStyle: CardStyle {
        if case .card(let style, _) = document.background { style } else { .sticky }
    }

    var sizeChoice: CardSizeChoice {
        guard case .card(_, let size) = document.background else { return .square }
        return switch size {
        case .square: .square
        case .story: .story
        case .wallpaper: .wallpaper
        }
    }

    var isEdited: Bool { document != initial }

    var selectedElement: CanvasElement? { document.elements.first { $0.id == selectedID } }

    var resources: CanvasResources {
        CanvasResources(image: { [photos] in photos[$0] }, paintBackground: CardBackgroundPainter.paint)
    }

    var selectedText: String? {
        switch selectedElement?.kind {
        case .text(let text), .extraNote(let text, _): text
        default: nil
        }
    }

    var selectionSummary: String {
        guard let element = selectedElement else { return "Nothing selected" }
        return "Selected: \(Self.name(of: element.kind)) · rotate \(Int((element.rotation * 180 / .pi).rounded()))°"
    }

    private static func name(of kind: ElementKind) -> String {
        switch kind {
        case .text: "text"
        case .sticker: "sticker"
        case .photo: "photo"
        case .washi: "washi tape"
        case .ink: "signature"
        case .extraNote: "extra note"
        default: "shape"
        }
    }

    // MARK: Card settings

    func setStyle(_ style: CardStyle) {
        guard case .card(_, let size) = document.background else { return }
        document.background = .card(style: style, size: size)
        recordIfChanged()
    }

    func chooseSize(_ choice: CardSizeChoice) {
        let size: CardSize =
            switch choice {
            case .square: .square
            case .story: .story
            case .wallpaper:
                .wallpaper(width: Int(screenPixelSize.width), height: Int(screenPixelSize.height))
            }
        document.background = .card(style: cardStyle, size: size)
        recordIfChanged()
    }

    func setShowsMadeWithMark(_ shows: Bool) {
        document.showsMadeWithMark = shows
        recordIfChanged()
    }

    // MARK: Decorate

    func addSticker(_ symbol: String) {
        add(CanvasElement(kind: .sticker(symbol), frame: centred(CGSize(width: 160, height: 160))))
    }

    func addText() {
        let style = ElementStyle(colorHex: cardStyle.inkColorHex)
        add(CanvasElement(kind: .text("Your text"), frame: centred(CGSize(width: 360, height: 72)), style: style))
    }

    func addExtraNote() {
        let count = document.elements.filter { if case .extraNote = $0.kind { true } else { false } }.count
        let color = Self.noteColors[count % Self.noteColors.count]
        add(
            CanvasElement(
                kind: .extraNote(text: "Note", colorHex: color), frame: centred(CGSize(width: 300, height: 220)),
                rotation: 0.07))
    }

    func addWashi(_ preset: WashiPreset) {
        add(
            CanvasElement(
                kind: .washi(pattern: preset.pattern), frame: centred(CGSize(width: 360, height: 64)), rotation: -0.1,
                style: ElementStyle(colorHex: preset.colorHex)))
    }

    /// Copies the picture into the note as an `.image` attachment and puts it on the card.
    func addPhoto(fileAt url: URL) throws {
        let id = try saver.ensureNote(noteId, now: Date())
        noteId = id
        let attachment = try saver.attachPhoto(at: url, noteId: id)
        guard let image = saver.image(attachmentId: attachment.id!, noteId: id) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        photos[attachment.id!] = image
        let ratio = CGFloat(image.height) / CGFloat(image.width)
        let width = min(520, 520 / max(ratio, 1))
        add(
            CanvasElement(
                kind: .photo(attachmentId: attachment.id!), frame: centred(CGSize(width: width, height: width * ratio)))
        )
    }

    func setText(_ text: String) {
        edit { element in
            switch element.kind {
            case .text:
                element.kind = .text(text)
                element.frame.size.width = max(CanvasRenderer.textSize(text, height: element.frame.height).width, 24)
            case .extraNote(_, let colorHex): element.kind = .extraNote(text: text, colorHex: colorHex)
            default: break
            }
        }
    }

    func deleteSelection() {
        guard let id = selectedID else { return }
        document.remove(id: id)
        selectedID = nil
        recordIfChanged()
    }

    func undo() { history.undo().map(restore) }
    func redo() { history.redo().map(restore) }

    // MARK: Save

    func save() throws -> Int64 {
        let id = try saver.save(document, noteId: noteId, now: Date())
        noteId = id
        return id
    }

    func renderedImage() -> CGImage? {
        CanvasRenderer.render(document, resources: resources)
    }

    // MARK: Pointer

    func handle(_ event: CanvasPointerEvent) {
        switch event.phase {
        case .began: pointerBegan(at: event.point, zoom: event.zoom)
        case .changed: pointerMoved(to: event.point)
        case .ended: pointerEnded(at: event.point)
        }
    }

    /// Ink points relative to the frame origin, as `ElementKind.ink` stores them.
    static func inkElement(through points: [CGPoint], style: ElementStyle) -> CanvasElement {
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        let origin = CGPoint(x: xs.min() ?? 0, y: ys.min() ?? 0)
        let frame = CGRect(
            x: origin.x, y: origin.y, width: max((xs.max() ?? 0) - origin.x, CanvasElement.minimumSide),
            height: max((ys.max() ?? 0) - origin.y, CanvasElement.minimumSide))
        let relative = points.map { CGPoint(x: $0.x - origin.x, y: $0.y - origin.y) }
        return CanvasElement(kind: .ink(points: relative), frame: frame, style: style)
    }

    private var signStyle: ElementStyle {
        ElementStyle(colorHex: cardStyle.inkColorHex, strokeWidth: Self.signStrokeWidth)
    }

    private func pointerBegan(at point: CGPoint, zoom: CGFloat) {
        if isSigning {
            let element = Self.inkElement(through: [point], style: signStyle)
            document.add(element)
            selectedID = element.id
            drag = .drawing(element.id, points: [point])
        } else {
            beginSelectDrag(at: point, zoom: zoom)
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
        case .drawing(let id, let points): extendStroke(id, points: points + [point])
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
        if case .drawing(let id, let points) = drag, points.count < 3 {
            document.remove(id: id)  // a click without a stroke
            selectedID = nil
        }
        recordIfChanged()
    }

    private func extendStroke(_ id: UUID, points: [CGPoint]) {
        guard let index = document.elements.firstIndex(where: { $0.id == id }) else { return }
        var element = Self.inkElement(through: points, style: signStyle)
        element.id = id
        document.elements[index] = element
        drag = .drawing(id, points: points)
    }

    private func rotate(_ id: UUID, toward point: CGPoint) {
        guard let element = document.elements.first(where: { $0.id == id }) else { return }
        document.rotateElement(id: id, to: atan2(point.y - element.frame.midY, point.x - element.frame.midX) + .pi / 2)
    }

    // MARK: Helpers

    private func add(_ element: CanvasElement) {
        isSigning = false
        document.add(element)
        selectedID = element.id
        recordIfChanged()
    }

    private func centred(_ size: CGSize) -> CGRect {
        let canvas = CanvasRenderer.pixelSize(of: document)
        return CGRect(
            x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2, width: size.width,
            height: size.height)
    }

    private func edit(_ change: (inout CanvasElement) -> Void) {
        guard let index = document.elements.firstIndex(where: { $0.id == selectedID }) else { return }
        change(&document.elements[index])
        recordIfChanged()
    }

    private func loadPhotos() {
        guard let noteId else { return }
        for case .photo(let attachmentId) in document.elements.map(\.kind) {
            photos[attachmentId] = saver.image(attachmentId: attachmentId, noteId: noteId)
        }
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
