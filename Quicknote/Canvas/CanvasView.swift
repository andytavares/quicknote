import QuicknoteKit
import SwiftUI

enum CanvasPointerPhase { case began, changed, ended }

/// A pointer event in canvas coordinates. `zoom` is view points per canvas unit.
struct CanvasPointerEvent {
    let phase: CanvasPointerPhase
    let point: CGPoint
    let zoom: CGFloat
}

/// Shows a `CanvasDocument` fitted into the space it is given, with the selected element's handles on top.
/// It draws and reports pointer events; what a drag means is up to the owner (Snap editor, Cards editor).
struct CanvasView<Accessory: View>: View {
    let document: CanvasDocument
    let resources: CanvasResources
    var selectedID: UUID?
    var onPointer: (CanvasPointerEvent) -> Void = { _ in }
    /// Drawn on top in view coordinates (canvas point times `zoom`), such as an inline text field.
    @ViewBuilder var accessory: (CGFloat) -> Accessory

    @Environment(\.displayScale) private var displayScale
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let size = CanvasRenderer.pixelSize(of: document)
            let zoom = min(proxy.size.width / size.width, proxy.size.height / size.height)
            canvas(zoom: zoom, size: size)
                .frame(width: size.width * zoom, height: size.height * zoom)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
    }

    private func canvas(zoom: CGFloat, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            if let image = CanvasRenderer.render(document, scale: zoom * displayScale, resources: resources) {
                Image(decorative: image, scale: displayScale)
            }
            if let selected = document.elements.first(where: { $0.id == selectedID }) {
                ElementHandlesView(element: selected, zoom: zoom)
            }
            accessory(zoom)
        }
        .contentShape(Rectangle())
        .gesture(dragGesture(zoom: zoom))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Canvas")
        .accessibilityValue("\(document.elements.count) elements")
        .accessibilityAddTraits(.isImage)
    }

    private func dragGesture(zoom: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onPointer(
                    CanvasPointerEvent(
                        phase: isDragging ? .changed : .began, point: canvasPoint(value.location, zoom), zoom: zoom))
                isDragging = true
            }
            .onEnded { value in
                isDragging = false
                onPointer(CanvasPointerEvent(phase: .ended, point: canvasPoint(value.location, zoom), zoom: zoom))
            }
    }

    private func canvasPoint(_ location: CGPoint, _ zoom: CGFloat) -> CGPoint {
        CGPoint(x: location.x / zoom, y: location.y / zoom)
    }
}

extension CanvasView where Accessory == EmptyView {
    init(
        document: CanvasDocument, resources: CanvasResources, selectedID: UUID? = nil,
        onPointer: @escaping (CanvasPointerEvent) -> Void = { _ in }
    ) {
        self.init(
            document: document, resources: resources, selectedID: selectedID, onPointer: onPointer,
            accessory: { _ in EmptyView() })
    }
}
