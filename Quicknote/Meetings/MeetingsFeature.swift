/// Meeting recorder and detail (S17, S18). Owned by the Meetings unit.
enum MeetingsFeature {
    static var isRecording: Bool { false }
    static func toggleRecording() {}
    static func bookmark() {}
    /// Opens a meeting at a moment, used by tasks that came from an action item.
    static func open(meetingId: Int64, atMs: Int) {}
}
