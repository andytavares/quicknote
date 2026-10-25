import Foundation

/// The six card looks from design screen S22.
public enum CardStyle: String, CaseIterable, Codable, Sendable {
    case sticky, postcard, polaroid, lined, minimal, kraft

    public var title: String { rawValue.capitalized }

    public var paperColorHex: String {
        switch self {
        case .sticky: "#FBE38E"
        case .postcard, .polaroid: "#FFFDF8"
        case .lined, .minimal: "#FFFFFF"
        case .kraft: "#C9A57A"
        }
    }

    public var inkColorHex: String { "#2B2618" }
}
