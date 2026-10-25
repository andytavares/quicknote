/// "Add to Calendar?" sheet (S06). Owned by the Calendar and Brief unit.
enum CalendarConfirmation {
    /// Asks before writing the note's event to Calendar. Does nothing for notes without a due time.
    static func present(forNoteId noteId: Int64) {}
}
