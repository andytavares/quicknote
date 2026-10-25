import CoreGraphics
import Foundation

public enum ResizeHandle: CaseIterable, Sendable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
}

extension CanvasElement {
    public static let minimumSide: CGFloat = 8
    public static let lineHitDistance: CGFloat = 6

    /// Converts a point in the unrotated frame's space to canvas coordinates.
    public func canvasPoint(fromLocal local: CGPoint) -> CGPoint {
        rotate(local, by: rotation)
    }

    /// Converts a canvas point into the unrotated frame's space.
    public func localPoint(fromCanvas canvas: CGPoint) -> CGPoint {
        rotate(canvas, by: -rotation)
    }

    /// True when the point is inside the rotated shape (lines and arrows: within 6pt of the segment).
    public func contains(canvasPoint: CGPoint) -> Bool {
        let local = localPoint(fromCanvas: canvasPoint)
        switch kind {
        case .arrow, .line:
            let (start, end) = segmentEnds()
            return distance(from: local, toSegmentFrom: start, to: end) <= Self.lineHitDistance
        case .circle, .diamond, .triangle:
            return shapeContains(local)
        default:
            return frame.contains(local)
        }
    }

    func resized(handle: ResizeHandle, to dragged: CGPoint) -> CanvasElement {
        let local = localPoint(fromCanvas: dragged)
        var edges = (minX: frame.minX, maxX: frame.maxX, minY: frame.minY, maxY: frame.maxY)
        switch handle {
        case .topLeft, .left, .bottomLeft: edges.minX = min(local.x, edges.maxX - Self.minimumSide)
        case .topRight, .right, .bottomRight: edges.maxX = max(local.x, edges.minX + Self.minimumSide)
        default: break
        }
        switch handle {
        case .topLeft, .top, .topRight: edges.minY = min(local.y, edges.maxY - Self.minimumSide)
        case .bottomLeft, .bottom, .bottomRight: edges.maxY = max(local.y, edges.minY + Self.minimumSide)
        default: break
        }
        let newLocal = CGRect(
            x: edges.minX, y: edges.minY, width: edges.maxX - edges.minX, height: edges.maxY - edges.minY)
        // Centre the new frame on the new local centre mapped through the old rotation, so the
        // side that was not dragged stays where it was on screen.
        let centre = canvasPoint(fromLocal: CGPoint(x: newLocal.midX, y: newLocal.midY))
        var copy = self
        copy.frame = CGRect(
            x: centre.x - newLocal.width / 2,
            y: centre.y - newLocal.height / 2,
            width: newLocal.width,
            height: newLocal.height
        )
        copy.scaleInk(from: frame.size)
        return copy
    }

    private mutating func scaleInk(from oldSize: CGSize) {
        guard case .ink(let points) = kind else { return }
        let scaleX = frame.width / oldSize.width
        let scaleY = frame.height / oldSize.height
        kind = .ink(points: points.map { CGPoint(x: $0.x * scaleX, y: $0.y * scaleY) })
    }

    private func segmentEnds() -> (CGPoint, CGPoint) {
        let start = CGPoint(x: flippedX ? frame.maxX : frame.minX, y: flippedY ? frame.maxY : frame.minY)
        let end = CGPoint(x: flippedX ? frame.minX : frame.maxX, y: flippedY ? frame.minY : frame.maxY)
        return (start, end)
    }

    private func shapeContains(_ local: CGPoint) -> Bool {
        guard frame.contains(local) else { return false }
        let dx = abs(local.x - frame.midX) / (frame.width / 2)
        let dy = abs(local.y - frame.midY) / (frame.height / 2)
        switch kind {
        case .circle: return dx * dx + dy * dy <= 1
        case .diamond: return dx + dy <= 1
        default: return dx <= (local.y - frame.minY) / frame.height  // triangle: apex at top centre
        }
    }

    /// Rotates `point` by `angle` about the frame centre.
    private func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        let offsetX = point.x - frame.midX
        let offsetY = point.y - frame.midY
        return CGPoint(
            x: frame.midX + offsetX * cos(angle) - offsetY * sin(angle),
            y: frame.midY + offsetX * sin(angle) + offsetY * cos(angle)
        )
    }

    private func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        let along = lengthSquared == 0 ? 0 : ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared
        let t = min(max(along, 0), 1)
        return hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy))
    }
}

extension CanvasDocument {
    /// The topmost element whose rotated shape contains the point.
    public func elementID(at point: CGPoint) -> UUID? {
        elements.last { $0.contains(canvasPoint: point) }?.id
    }
}
