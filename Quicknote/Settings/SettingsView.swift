import AppKit
import KeyboardShortcuts
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case permissions = "Permissions"
    case data = "Data"

    static let storageKey = "settingsTab"

    /// Opens the Settings window on one tab.
    static func show(_ tab: SettingsTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: storageKey)
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

/// Settings window (S25, S26). Owned by the Settings and Permissions unit.
struct SettingsView: View {
    @AppStorage(SettingsTab.storageKey) private var tab = SettingsTab.general

    var body: some View {
        VStack(spacing: 0) {
            Picker("Settings section", selection: $tab) {
                ForEach(SettingsTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()
            Group {
                switch tab {
                case .general: GeneralPane()
                case .shortcuts: ShortcutsPane()
                case .permissions: PermissionsPane()
                case .data: DataPane()
                }
            }
            .padding([.horizontal, .bottom])
            Spacer(minLength: 0)
        }
        .frame(width: 440, height: 380)
    }
}

private struct GeneralPane: View {
    @State private var opensAtLogin = AppSettings.opensAtLogin
    @State private var showsEdgeOnAllDisplays = AppSettings.showsEdgeOnAllDisplays
    @State private var popsUpContextNotes = AppSettings.popsUpContextNotes
    @State private var noteColor = AppSettings.defaultNoteColor
    @State private var font = AppSettings.defaultFont
    @State private var checksForUpdates = AppSettings.checksForUpdatesAutomatically

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Open at login", isOn: $opensAtLogin)
                .onChange(of: opensAtLogin) {
                    AppSettings.opensAtLogin = opensAtLogin
                    opensAtLogin = AppSettings.opensAtLogin
                }
            Toggle("Show edge tabs on all displays", isOn: $showsEdgeOnAllDisplays)
                .onChange(of: showsEdgeOnAllDisplays) {
                    AppSettings.showsEdgeOnAllDisplays = showsEdgeOnAllDisplays
                    EdgeFeature.refresh()
                }
            Toggle("Pop up app and site notes", isOn: $popsUpContextNotes)
                .onChange(of: popsUpContextNotes) { AppSettings.popsUpContextNotes = popsUpContextNotes }
            LabeledContent("Default note colour") { colorChoices }
            Picker("Default font", selection: $font) {
                ForEach(AppSettings.fontChoices, id: \.id) { Text($0.name).tag($0.id) }
            }
            .onChange(of: font) { AppSettings.defaultFont = font }
            LabeledContent("Voice") { Text("English (on this Mac)").foregroundStyle(.secondary) }
            LabeledContent("Updates") {
                Toggle("Check automatically", isOn: $checksForUpdates)
                    .onChange(of: checksForUpdates) { AppSettings.checksForUpdatesAutomatically = checksForUpdates }
            }
        }
    }

    private var colorChoices: some View {
        HStack(spacing: 8) {
            ForEach(AppSettings.noteColorChoices, id: \.hex) { choice in
                Button {
                    noteColor = choice.hex
                    AppSettings.defaultNoteColor = choice.hex
                } label: {
                    Circle().fill(Color(hex: choice.hex)).frame(width: 16, height: 16)
                        .overlay(
                            Circle().stroke(noteColor == choice.hex ? Color.accentColor : .secondary, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(choice.name) note colour")
                .accessibilityAddTraits(noteColor == choice.hex ? .isSelected : [])
            }
        }
    }
}

private struct ShortcutsPane: View {
    @State private var resetCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Shortcuts.all, id: \.title) { shortcut in
                LabeledContent(shortcut.title) { KeyboardShortcuts.Recorder(for: shortcut.name) }
            }
            HStack {
                Spacer()
                Button("Restore defaults") {
                    KeyboardShortcuts.reset(Shortcuts.all.map(\.name))
                    resetCount += 1
                }
                .accessibilityLabel("Restore default shortcuts")
            }
        }
        .id(resetCount)
    }
}

extension Color {
    /// `#RRGGBB`; anything else is grey.
    init(hex: String) {
        let digits = UInt32(hex.dropFirst(), radix: 16) ?? 0x808080
        self.init(
            red: Double((digits >> 16) & 0xFF) / 255, green: Double((digits >> 8) & 0xFF) / 255,
            blue: Double(digits & 0xFF) / 255)
    }
}
