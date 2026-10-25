/// Snap selection and editor (S19, S20). Owned by the Snap unit.
enum SnapFeature {
    static func start() {}
    /// Reopens a saved Snap in the editor.
    static func edit(noteId: Int64) {}
}
