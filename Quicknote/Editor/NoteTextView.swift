import AppKit
import SwiftUI

/// SwiftUI wrapper for `EditorTextView`. The model owns the text; this keeps the two in step.
struct NoteTextView: NSViewRepresentable {
    let model: NoteEditorModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        // TextKit 1: the checkbox and chip drawing needs the layout manager.
        let textView = EditorTextView(usingTextLayoutManager: false)
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.autoresizingMask = .width
        textView.setAccessibilityLabel("Note text")
        textView.registerForDraggedTypes([.fileURL])
        textView.onToggleCheckbox = { model.toggleCheckbox(line: $0) }
        textView.onOpenLink = { model.openLink(title: $0) }
        textView.onDropFiles = { model.importFiles($0) }
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorTextView, let note = model.note else { return }
        if textView.string != note.body { textView.string = note.body }
        textView.restyle(fontId: note.font)
        guard let completion = model.completionRequest else { return }
        Task {
            textView.insertText(completion.text, replacementRange: completion.range)
            model.completionRequest = nil
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let model: NoteEditorModel

        init(model: NoteEditorModel) { self.model = model }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? EditorTextView else { return }
            model.edit(body: textView.string)
            textView.restyle(fontId: model.note?.font ?? "system")
            model.updateLinkTrigger(text: textView.string, cursor: textView.selectedRange().location)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? EditorTextView else { return }
            model.updateLinkTrigger(text: textView.string, cursor: textView.selectedRange().location)
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard model.suggestionRowCount > 0 else { return false }
            switch selector {
            case #selector(NSResponder.moveUp(_:)): model.moveSuggestion(by: -1)
            case #selector(NSResponder.moveDown(_:)): model.moveSuggestion(by: 1)
            case #selector(NSResponder.insertNewline(_:)): model.chooseSuggestion(at: model.selectedSuggestion)
            case #selector(NSResponder.cancelOperation(_:)): model.dismissSuggestions()
            default: return false
            }
            return true
        }
    }
}
