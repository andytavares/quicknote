import AppKit

/// The 50 colours in the Style popover: the six default note colours, then a generated pastel grid.
enum EditorPalette {
    static let columnCount = 10
    static let swatches: [String] = (AppSettings.noteColorChoices.map(\.hex) + generatedHexColors).prefix(50).map { $0 }

    private static var generatedHexColors: [String] {
        let saturations: [CGFloat] = [0.18, 0.3, 0.45, 0.6, 0.75]
        return saturations.flatMap { saturation in
            (0..<columnCount).map { hue in
                hex(
                    hue: CGFloat(hue) / CGFloat(columnCount), saturation: saturation,
                    brightness: 0.55 + saturation * 0.4)
            }
        }
    }

    private static func hex(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> String {
        hex(of: NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1))
    }

    /// `#RRGGBB` in sRGB, the form notes store.
    static func hex(of color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let (red, green, blue) = (rgb.redComponent, rgb.greenComponent, rgb.blueComponent)
        return String(format: "#%02X%02X%02X", Int(red * 255 + 0.5), Int(green * 255 + 0.5), Int(blue * 255 + 0.5))
    }
}
