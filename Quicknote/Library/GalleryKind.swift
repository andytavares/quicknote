import QuicknoteKit

/// Snaps and Cards are both canvas notes; the canvas background tells them apart.
enum GalleryKind: String, CaseIterable, Identifiable {
    case snap = "Snaps"
    case card = "Cards"

    var id: String { rawValue }

    static func classify(_ note: Note) -> GalleryKind? {
        switch note.canvas?.background {
        case .image: .snap
        case .card: .card
        case nil: nil
        }
    }
}
