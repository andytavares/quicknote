/// Card editor (S21, S22). Owned by the Cards unit.
enum CardsFeature {
    /// Opens the card editor for a note, or a blank card when `fromNoteId` is nil.
    static func newCard(fromNoteId: Int64?) {}
}
