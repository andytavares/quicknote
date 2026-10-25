import AppKit

/// The six note fonts. All ship with macOS; a missing one falls back to the system font.
struct EditorFont: Equatable {
    let id: String
    let name: String
    /// PostScript name of a font that ships with macOS.
    var postScriptName: String?
    var design: NSFontDescriptor.SystemDesign?

    static let choices = [
        EditorFont(id: "handwritten", name: "Handwritten", postScriptName: "BradleyHandITCTT-Bold"),
        EditorFont(id: "system", name: "System"),
        EditorFont(id: "rounded", name: "Rounded", design: .rounded),
        EditorFont(id: "serif", name: "Serif", design: .serif),
        EditorFont(id: "marker", name: "Marker", postScriptName: "MarkerFelt-Thin"),
        EditorFont(id: "mono", name: "Mono", design: .monospaced),
    ]

    /// The font for a stored `Note.font`; unknown ids read as System.
    static func resolve(id: String, size: CGFloat) -> NSFont {
        (choices.first { $0.id == id } ?? choices[1]).nsFont(size: size)
    }

    func nsFont(size: CGFloat) -> NSFont {
        let system = NSFont.systemFont(ofSize: size)
        if let postScriptName { return NSFont(name: postScriptName, size: size) ?? system }
        guard let design, let descriptor = system.fontDescriptor.withDesign(design) else { return system }
        return NSFont(descriptor: descriptor, size: size) ?? system
    }
}
