import QuicknoteKit
import SwiftUI

enum EdgeCard {
    case peek(Note), expanded(Note), context

    var id: String {
        switch self {
        case .peek(let note): "peek-\(note.id ?? 0)"
        case .expanded(let note): "expanded-\(note.id ?? 0)"
        case .context: "context"
        }
    }

    var noteId: Int64? {
        switch self {
        case .peek(let note), .expanded(let note): note.id
        case .context: nil
        }
    }

    /// Whether `slot` is the tab this card belongs to, so that tab is highlighted.
    func shows(_ slot: EdgeModel.Slot) -> Bool {
        switch (self, slot) {
        case (.context, .context): true
        case (.peek, .note(let note)), (.expanded, .note(let note)): note.id == noteId
        default: false
        }
    }
}

extension Note {
    var edgeColor: Color { Color(hex: color) }
}

struct EdgeCardView: View {
    let card: EdgeCard
    let model: EdgeModel
    let actions: EdgeActions
    let onHover: (Int64?, Bool) -> Void

    var body: some View {
        // Note colours are light; in dark mode the buttons would draw white text on them.
        cardContent.environment(\.colorScheme, .light)
    }

    @ViewBuilder private var cardContent: some View {
        switch card {
        case .peek(let note):
            NoteCard(note: note, actions: nil)
                .onTapGesture { model.reveal(noteId: note.id ?? 0) }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Click to show its options.")
        case .expanded(let note):
            NoteCard(note: note, actions: actions)
                .onTapGesture(count: 2) { actions.openInLibrary(note) }
        case .context: ContextCard(model: model, actions: actions)
        }
    }
}

private let cardInk = Color.black.opacity(0.85)

private struct NoteCard: View {
    let note: Note
    let actions: EdgeActions?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.kind == .reminder && note.dueAt != nil ? "Reminder" : "Note")
                .font(.system(size: 10.5, weight: .bold)).textCase(.uppercase).opacity(0.7)
            Text(note.body).font(.system(size: 14)).lineLimit(actions == nil ? 5 : 8)
            if let actions { NoteCardButtons(note: note, actions: actions) }
        }
        .foregroundStyle(cardInk)
        .padding(12)
        .frame(width: EdgeLayout.cardWidth, alignment: .leading)
        .background(note.edgeColor, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 6, y: 2)
        .accessibilityElement(children: actions == nil ? .combine : .contain)
    }
}

private struct NoteCardButtons: View {
    let note: Note
    let actions: EdgeActions

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Done") { actions.done(note) }.accessibilityLabel("Mark done")
                SnoozeMenu { actions.snooze(note, until: $0) }
            }
            HStack {
                Button("Open in Library") { actions.openInLibrary(note) }
                Button("Remove from edge") { actions.removeFromEdge(note) }
            }
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

private struct SnoozeMenu: View {
    let snooze: (Date) -> Void

    var body: some View {
        Menu("Snooze") {
            ForEach(SnoozeOption.options(now: Date(), calendar: .current), id: \.title) { option in
                Button("\(option.title)  \(hint(for: option.until))") { snooze(option.until) }
            }
        }
        .accessibilityLabel("Snooze")
    }

    private func hint(for date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened) : date.formatted(.dateTime.weekday(.abbreviated))
    }
}

private struct ContextCard: View {
    let model: EdgeModel
    let actions: EdgeActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("For \(model.contextLabel)").font(.system(size: 10.5, weight: .bold)).textCase(.uppercase)
                Spacer()
                Text("pinned").font(.system(size: 10.5)).opacity(0.6)
            }
            ForEach(model.contextNotes) { note in
                Button {
                    actions.done(note)
                } label: {
                    Label(note.title, systemImage: "circle").labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark done: \(note.title)")
            }
            Text("Shows only in \(model.contextLabel) · \(model.contextNotes.count) open").font(.caption).opacity(0.65)
        }
        .foregroundStyle(cardInk)
        .padding(12)
        .frame(width: EdgeLayout.cardWidth, alignment: .leading)
        .background(model.contextNotes.first?.edgeColor ?? .yellow, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 6, y: 2)
    }
}
