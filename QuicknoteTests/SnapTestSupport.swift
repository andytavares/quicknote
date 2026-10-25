import CoreGraphics

/// Small bitmaps for Snap and canvas tests.
enum SnapTestSupport {
    /// `leftHalfBlack` makes a hard vertical edge in the middle; otherwise the image is white.
    static func image(width: Int, height: Int, leftHalfBlack: Bool = false) -> CGImage {
        let context = bitmapContext(width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        if leftHalfBlack {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        }
        return context.makeImage()!
    }

    /// RGB of the pixel at (x, y) counted from the top-left.
    static func pixel(_ image: CGImage, x: Int, y: Int) -> (red: Int, green: Int, blue: Int) {
        let context = bitmapContext(width: image.width, height: image.height)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        let offset = y * context.bytesPerRow + x * 4
        return (Int(bytes[offset]), Int(bytes[offset + 1]), Int(bytes[offset + 2]))
    }

    private static func bitmapContext(width: Int, height: Int) -> CGContext {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
}
