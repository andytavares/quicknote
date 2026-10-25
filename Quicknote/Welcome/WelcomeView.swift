import KeyboardShortcuts
import SwiftUI

/// S02. No permission prompts here; each is asked when a feature first needs it.
struct WelcomeView: View {
    let close: () -> Void
    @State private var opensAtLogin = AppSettings.opensAtLogin

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading) {
                Text("Welcome to Quicknote").font(.title2.bold())
                Text("Catch a thought in a second. See it again when it matters.").foregroundStyle(.secondary)
            }
            shortcutGrid
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes, voice and screenshots stay on this Mac. No account.")
                Text("Each permission is asked the first time a feature needs it.")
                Text("You can change every shortcut in Settings.")
            }
            .font(.callout).foregroundStyle(.secondary)
            HStack {
                Toggle("Open at login", isOn: $opensAtLogin)
                    .onChange(of: opensAtLogin) {
                        AppSettings.opensAtLogin = opensAtLogin
                        opensAtLogin = AppSettings.opensAtLogin
                    }
                Spacer()
                Button("Change shortcuts") {
                    SettingsTab.show(.shortcuts)
                    close()
                }
                Button("Start") { close() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 560)
    }

    private var shortcutGrid: some View {
        let items = Shortcuts.all.map { (shortcut: $0.name.shortcut?.description ?? "–", title: $0.title) }
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2), spacing: 8) {
            ForEach(items, id: \.title) { item in
                HStack {
                    Text(item.shortcut).font(.body.monospaced()).padding(.horizontal, 6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                    Text(item.title)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
