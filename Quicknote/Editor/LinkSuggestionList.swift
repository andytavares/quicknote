import SwiftUI

/// The `[[` picker: matching titles, then "Create “…”". Arrow keys and Return are handled by the text view.
struct LinkSuggestionList: View {
    let model: NoteEditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Link to note").font(.caption).foregroundStyle(.secondary).padding(8)
            ForEach(model.suggestions.indices, id: \.self) { index in
                row(model.suggestions[index].title, at: index)
            }
            if model.showsCreateRow {
                row("Create “\(model.linkTrigger?.query ?? "")”", at: model.suggestions.count)
            }
        }
        .frame(width: 280)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Link to note")
    }

    private func row(_ title: String, at index: Int) -> some View {
        Button {
            model.chooseSuggestion(at: index)
        } label: {
            Text(title).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8).padding(
                .vertical, 5
            )
            .background(index == model.selectedSuggestion ? Color.accentColor.opacity(0.25) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
