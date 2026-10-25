import QuicknoteKit
import SwiftUI

/// The Decorate column of the Card editor: emoji, stickers, photo, text, extra note, signing and washi tape.
struct CardDecoratePanel: View {
    let model: CardEditorModel
    let chooseAndAddPhoto: () -> Void
    @State private var showsEmoji = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Decorate").font(.headline)
                buttons
                Text("Stickers").font(.subheadline).foregroundStyle(.secondary)
                symbolGrid(CardEditorModel.stickers, label: "Sticker")
                Text("Washi tape").font(.subheadline).foregroundStyle(.secondary)
                washiRow
            }
            .padding(12)
        }
        .frame(width: 230)
    }

    private var buttons: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], alignment: .leading, spacing: 6) {
            Button("Emoji") { showsEmoji = true }
                .popover(isPresented: $showsEmoji) { symbolGrid(CardEditorModel.emoji, label: "Emoji").padding(12) }
                .accessibilityLabel("Add an emoji")
            Button("Photo…") { chooseAndAddPhoto() }.accessibilityLabel("Add a photo")
            Button("Text") { model.addText() }.accessibilityLabel("Add text")
            Button("Extra note") { model.addExtraNote() }.accessibilityLabel("Add an extra note")
            Button("Sign") { model.isSigning.toggle() }
                .tint(model.isSigning ? .accentColor : nil)
                .accessibilityLabel("Sign the card by drawing on it")
                .accessibilityAddTraits(model.isSigning ? .isSelected : [])
        }
        .buttonStyle(.bordered)
    }

    private func symbolGrid(_ symbols: [String], label: String) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 4), spacing: 6) {
            ForEach(symbols, id: \.self) { symbol in
                Button(symbol) {
                    model.addSticker(symbol)
                    showsEmoji = false
                }
                .font(.title2)
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) \(symbol)")
            }
        }
    }

    private var washiRow: some View {
        HStack {
            ForEach(CardEditorModel.washiPresets) { preset in
                Button {
                    model.addWashi(preset)
                } label: {
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: preset.colorHex)).frame(width: 36, height: 18)
                        .overlay {
                            if preset.pattern == "stripes" { Text("///").font(.caption2).foregroundStyle(.white) }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Washi tape \(preset.name)")
            }
        }
    }
}
