import AppKit
import ScreenCaptureKit

/// One display as the capture needs it: AppKit frame (bottom-left origin, global points) and backing scale.
struct SnapDisplay: Equatable {
    var displayID: CGDirectDisplayID
    var frame: CGRect
    var scale: CGFloat
}

/// What to ask ScreenCaptureKit for: a rect of one display in points (top-left origin, display-local)
/// and the output size in that display's pixels.
struct SnapCaptureRequest: Equatable {
    var displayID: CGDirectDisplayID
    var sourceRect: CGRect
    var pixelSize: CGSize

    /// `selection` is in global AppKit screen coordinates, so a display left of or above the main one works.
    static func make(selection: CGRect, on display: SnapDisplay) -> SnapCaptureRequest {
        let local = CGRect(
            x: selection.minX - display.frame.minX, y: display.frame.maxY - selection.maxY,
            width: selection.width, height: selection.height)
        let pixels = CGSize(
            width: (selection.width * display.scale).rounded(), height: (selection.height * display.scale).rounded())
        return SnapCaptureRequest(displayID: display.displayID, sourceRect: local, pixelSize: pixels)
    }
}

extension SnapDisplay {
    init?(_ screen: NSScreen) {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        self.init(displayID: number.uint32Value, frame: screen.frame, scale: screen.backingScaleFactor)
    }
}

enum SnapCaptureError: Error { case displayNotFound, noImage }

enum SnapCapture {
    /// Captures the request without the windows in `excludedWindowIDs` (the dim overlay).
    static func capture(_ request: SnapCaptureRequest, excludingWindowIDs excludedWindowIDs: [CGWindowID]) async throws
        -> CGImage
    {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == request.displayID }) else {
            throw SnapCaptureError.displayNotFound
        }
        let excluded = content.windows.filter { excludedWindowIDs.contains($0.windowID) }
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = request.sourceRect
        configuration.width = Int(request.pixelSize.width)
        configuration.height = Int(request.pixelSize.height)
        configuration.showsCursor = false
        let filter = SCContentFilter(display: display, excludingWindows: excluded)
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
}
