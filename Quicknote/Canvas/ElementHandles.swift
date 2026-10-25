import QuicknoteKit
import SwiftUI

enum HandleTarget: Equatable {
    case resize(ResizeHandle)
    case rotate
}

/// Where an element's 8 resize handles and its rotation handle sit, in canvas coordinates.
enum ElementHandles {
    static let rotationOffset: CGFloat = 28
    static let hitRadius: CGFloat = 10

    /// `zoom` is view points per canvas unit, so handles keep a constant size on screen.
    static func positions(of element: CanvasElement, zoom: CGFloat) -> [(HandleTarget, CGPoint)] {
        let frame = element.frame
        let resizeHandles = ResizeHandle.allCases.map { handle in
            (HandleTarget.resize(handle), element.canvasPoint(fromLocal: local(handle, in: frame)))
        }
        let rotation = CGPoint(x: frame.midX, y: frame.minY - rotationOffset / zoom)
        return resizeHandles + [(.rotate, element.canvasPoint(fromLocal: rotation))]
    }

    static func target(at point: CGPoint, of element: CanvasElement, zoom: CGFloat) -> HandleTarget? {
        positions(of: element, zoom: zoom).first { hypot($0.1.x - point.x, $0.1.y - point.y) <= hitRadius / zoom }?.0
    }

    private static func local(_ handle: ResizeHandle, in frame: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: frame.minX, y: frame.minY)
        case .top: CGPoint(x: frame.midX, y: frame.minY)
        case .topRight: CGPoint(x: frame.maxX, y: frame.minY)
        case .right: CGPoint(x: frame.maxX, y: frame.midY)
        case .bottomRight: CGPoint(x: frame.maxX, y: frame.maxY)
        case .bottom: CGPoint(x: frame.midX, y: frame.maxY)
        case .bottomLeft: CGPoint(x: frame.minX, y: frame.maxY)
        case .left: CGPoint(x: frame.minX, y: frame.midY)
        }
    }
}

/// The dashed outline, handles and rotation stem of the selected element, drawn in view coordinates.
struct ElementHandlesView: View {
    let element: CanvasElement
    let zoom: CGFloat

    var body: some View {
        Canvas { context, _ in
            let positions = ElementHandles.positions(of: element, zoom: zoom)
            let corners = [ResizeHandle.topLeft, .topRight, .bottomRight, .bottomLeft].compactMap { corner in
                positions.first { $0.0 == .resize(corner) }?.1
            }
            var outline = Path()
            outline.addLines(corners.map { scaled($0) })
            outline.closeSubpath()
            context.stroke(outline, with: .color(.accentColor), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            for (target, point) in positions { drawHandle(target, at: scaled(point), in: &context) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func scaled(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x * zoom, y: point.y * zoom) }

    private func drawHandle(_ target: HandleTarget, at point: CGPoint, in context: inout GraphicsContext) {
        let box = CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)
        let shape = target == .rotate ? Path(ellipseIn: box) : Path(roundedRect: box, cornerRadius: 2)
        context.fill(shape, with: .color(.accentColor))
        context.stroke(shape, with: .color(.white), lineWidth: 1)
    }
}
