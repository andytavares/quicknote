import AppKit

extension CGImage {
    /// PNG bytes for files and the pasteboard; nil only if encoding fails.
    var pngData: Data? {
        NSBitmapImageRep(cgImage: self).representation(using: .png, properties: [:])
    }
}
