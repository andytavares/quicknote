import KeyboardShortcuts
import Testing

@testable import Quicknote

struct ShortcutsTests {
    @Test func defaultShortcutsMatchTheDocumentedKeys() {
        let defaults = Shortcuts.all.map { $0.name.defaultShortcut?.description }
        #expect(defaults == ["⌃⌥N", "⌃⌥K", "⌃⌥4", "⌃⌥C", "⌃⌥F", "⌃⌥S", "⌃⌥B"])
    }

    @Test func labelShowsTheCurrentKeysAndNothingWhenCleared() {
        defer { KeyboardShortcuts.reset(.search) }
        KeyboardShortcuts.reset(.search)
        #expect(Shortcuts.label(for: .search) == "⌃⌥F")
        KeyboardShortcuts.setShortcut(.init(.g, modifiers: [.command, .shift]), for: .search)
        #expect(Shortcuts.label(for: .search) == "⇧⌘G")
        KeyboardShortcuts.setShortcut(nil, for: .search)
        #expect(Shortcuts.label(for: .search).isEmpty)
    }
}
