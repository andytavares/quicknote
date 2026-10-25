import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let newNote = Self("newNote", initial: .init(.n, modifiers: [.control, .option]))
    static let holdToTalk = Self("holdToTalk", initial: .init(.k, modifiers: [.control, .option]))
    static let snap = Self("snap", initial: .init(.four, modifiers: [.control, .option]))
    static let newCard = Self("newCard", initial: .init(.c, modifiers: [.control, .option]))
    static let search = Self("search", initial: .init(.f, modifiers: [.control, .option]))
    static let saveContext = Self("saveContext", initial: .init(.s, modifiers: [.control, .option]))
    static let bookmarkMeeting = Self("bookmarkMeeting", initial: .init(.b, modifiers: [.control, .option]))
}

/// Global shortcuts and what each one does. Every shortcut can be changed in Settings › Shortcuts.
enum Shortcuts {
    static let all: [(name: KeyboardShortcuts.Name, title: String)] = [
        (.newNote, "New note"),
        (.holdToTalk, "Hold to talk"),
        (.snap, "Snap"),
        (.newCard, "New card"),
        (.search, "Search"),
        (.saveContext, "Save where I stopped"),
        (.bookmarkMeeting, "Bookmark meeting moment"),
    ]

    static func register() {
        KeyboardShortcuts.onKeyUp(for: .newNote) { CaptureFeature.showPanel() }
        KeyboardShortcuts.onKeyDown(for: .holdToTalk) { VoiceFeature.startHoldToTalk() }
        KeyboardShortcuts.onKeyUp(for: .holdToTalk) { VoiceFeature.stopHoldToTalk() }
        KeyboardShortcuts.onKeyUp(for: .snap) { SnapFeature.start() }
        KeyboardShortcuts.onKeyUp(for: .newCard) { CardsFeature.newCard(fromNoteId: nil) }
        KeyboardShortcuts.onKeyUp(for: .search) { SearchFeature.showPanel() }
        KeyboardShortcuts.onKeyUp(for: .saveContext) { CaptureFeature.showSaveContext() }
        KeyboardShortcuts.onKeyUp(for: .bookmarkMeeting) { MeetingsFeature.bookmark() }
    }
}
