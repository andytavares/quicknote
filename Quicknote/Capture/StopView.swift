import SwiftUI

/// Save where you stopped (S09): Done, Blocked, Next, and the last stop for this app.
struct StopView: View {
    @Bindable var model: StopModel
    @FocusState private var focused: Field?

    private enum Field { case done, blocked, next }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Save where you stopped").font(.headline)
                if let context = model.stop.context { ContextChip(context: context) }
            }
            field("Done", text: $model.stop.done, field: .done)
            field("Blocked", text: $model.stop.blocked, field: .blocked)
            field("Next", text: $model.stop.next, field: .next)
            lastStop
            Divider()
            HStack {
                Text("\(Shortcuts.label(for: .saveContext))  Esc").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Save") { model.save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Save where you stopped")
            }
        }
        .padding(14)
        .frame(width: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .onAppear { focused = .done }
    }

    private func field(_ label: String, text: Binding<String>, field: Field) -> some View {
        HStack {
            Text(label).font(.callout.bold()).frame(width: 60, alignment: .leading)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
                .focused($focused, equals: field)
                .onSubmit { model.save() }
                .accessibilityLabel(label)
        }
    }

    @ViewBuilder private var lastStop: some View {
        if let note = model.lastStop {
            DisclosureGroup("Last stop here · \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))") {
                Text(note.body).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("Last saved stop for this app")
        }
    }
}
