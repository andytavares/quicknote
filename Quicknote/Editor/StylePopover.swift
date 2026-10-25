import AppKit
import SwiftUI

/// Colour (50 presets plus custom) and font (six) for the note (S12).
struct StylePopover: View {
    let model: NoteEditorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Colour").font(.headline)
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(20), spacing: 6), count: EditorPalette.columnCount),
                spacing: 6
            ) {
                ForEach(EditorPalette.swatches, id: \.self) { hex in
                    Button {
                        setColor(hex)
                    } label: {
                        swatch(hex)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Colour \(hex)")
                }
            }
            ColorPicker("Custom colour…", selection: customColor)
                .accessibilityLabel("Custom colour")
            Divider()
            Text("Font").font(.headline)
            ForEach(EditorFont.choices, id: \.id) { choice in
                Button {
                    model.update { $0.font = choice.id }
                } label: {
                    HStack {
                        Text(choice.name).font(Font(choice.nsFont(size: 14)))
                        Spacer()
                        if model.note?.font == choice.id { Image(systemName: "checkmark") }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Font \(choice.name)")
            }
        }
        .padding(14)
        .frame(width: 290)
    }

    private func swatch(_ hex: String) -> some View {
        Circle().fill(Color(hex: hex)).frame(width: 20, height: 20)
            .overlay(Circle().stroke(Color.primary, lineWidth: model.note?.color == hex ? 2 : 0))
            .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 0.5))
    }

    private func setColor(_ hex: String) { model.update { $0.color = hex } }

    private var customColor: Binding<Color> {
        Binding(
            get: { Color(hex: model.note?.color ?? "#FBE38E") },
            set: { setColor(EditorPalette.hex(of: NSColor($0))) })
    }
}
