import KeyboardShortcuts
import Testing

@testable import Quicknote

struct ShortcutsTests {
    @Test func defaultShortcutsMatchTheDocumentedKeys() {
        let defaults = Shortcuts.all.map { $0.name.defaultShortcut?.description }
        #expect(defaults == ["⌃⌥N", "⌃⌥K", "⌃⌥4", "⌃⌥C", "⌃⌥F", "⌃⌥S", "⌃⌥B"])
    }
}
