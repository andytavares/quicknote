import QuicknoteKit
import SwiftUI

/// The tabs on the edge, with the card that peeks, expands or slides out beside them.
struct EdgeTabsView: View {
    let model: EdgeModel
    let actions: EdgeActions
    let visibleFrame: CGRect
    let onCardVisibilityChange: (Bool) -> Void

    @State private var hidePeekTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: EdgeLayout {
        EdgeLayout(tabCount: model.tabCount, visibleFrame: visibleFrame, showsCard: false)
    }

    private var card: EdgeCard? { model.card }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Only the card animates: the panel widens at once, so animating the tabs too made them fly in.
            cardView
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: card?.id)
            VStack(spacing: EdgeLayout.tabSpacing) {
                ForEach(model.slots(for: layout)) { slot in tab(for: slot) }
            }
            .frame(width: EdgeLayout.tabWidth)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .onChange(of: card?.id) { onCardVisibilityChange(card != nil) }
        .onExitCommand { model.expandedNoteId = nil }
    }

    @ViewBuilder private var cardView: some View {
        if let card {
            EdgeCardView(card: card, model: model, actions: actions, onHover: setPeek)
                .padding(.trailing, EdgeLayout.cardGap)
                .contentShape(Rectangle())
                .onHover { setPeek(card.noteId, hovering: $0) }
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
        }
    }

    @ViewBuilder private func tab(for slot: EdgeModel.Slot) -> some View {
        switch slot {
        case .context:
            EdgeTab(
                color: .accentColor, badge: "\(model.contextNotes.count)",
                label: "Notes pinned to \(model.contextLabel)", isCurrent: card?.shows(slot) == true
            ) {
                model.isContextCardShown.toggle()
            }
        case .note(let note):
            noteTab(note, isCurrent: card?.shows(slot) == true)
        case .overflow(let count):
            EdgeTab(
                color: .gray, badge: "+\(count)", label: "\(count) more notes, open the Library", isCurrent: false
            ) {
                LibraryFeature.show()
            }
        }
    }

    private func noteTab(_ note: Note, isCurrent: Bool) -> some View {
        EdgeTab(color: note.edgeColor, badge: nil, label: "Note: \(note.title)", isCurrent: isCurrent) {
            model.toggleCard(noteId: note.id ?? 0)
        }
        .onHover { setPeek(note.id, hovering: $0) }
        .onDragAwayFromEdge { actions.removeFromEdge(note) }
        .accessibilityAction(named: "Remove from edge") { actions.removeFromEdge(note) }
    }

    /// The pointer crosses a gap between a tab and its card, so hiding waits a moment.
    private func setPeek(_ noteId: Int64?, hovering: Bool) {
        hidePeekTask?.cancel()
        if hovering { model.peekedNoteId = noteId; return }
        hidePeekTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            if !Task.isCancelled { model.peekedNoteId = nil }
        }
    }
}

private struct EdgeTab: View {
    let color: Color
    let badge: String?
    let label: String
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .frame(width: EdgeLayout.tabWidth, height: EdgeLayout.tabHeight)
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.7), lineWidth: 2)
                    }
                    if let badge {
                        Text(badge).font(.caption2.bold()).foregroundStyle(.white).minimumScaleFactor(0.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityHint("Click to open. Drag away from the edge to remove it from the edge.")
    }
}

extension View {
    /// Dragging a tab this far away from the right edge removes it from the edge.
    fileprivate func onDragAwayFromEdge(perform remove: @escaping () -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 12).onEnded { drag in
                if drag.translation.width < -80 { remove() }
            })
    }
}
