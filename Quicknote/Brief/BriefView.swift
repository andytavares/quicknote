import EventKit
import QuicknoteKit
import SwiftUI

struct BriefView: View {
    var model: BriefModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if !model.brief.events.isEmpty { eventsSection }
                itemSection("Due today", model.brief.dueToday, checkable: true)
                itemSection("Overdue", model.brief.overdue, checkable: true, isWarning: true)
                itemSection("Coming back today", model.brief.comingBack, checkable: false)
            }
            .padding(.horizontal, 22).padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 480, minHeight: 360)
        .toolbar {
            Button(model.isSpeaking ? "Stop" : "Read aloud", systemImage: model.isSpeaking ? "stop.fill" : "play.fill")
            {
                model.toggleReadAloud()
            }
            .accessibilityLabel(model.isSpeaking ? "Stop reading" : "Read the Daily Brief aloud")
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                model.refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in model.refresh() }
        .onDisappear { model.stopReadAloud() }
    }

    private var header: some View {
        VStack(alignment: .leading) {
            Text(model.brief.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.title2.bold())
            Text(model.brief.headline).foregroundStyle(.secondary)
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Events")
            ForEach(Array(model.brief.events.enumerated()), id: \.offset) { _, event in
                HStack {
                    Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                        .monospacedDigit().foregroundStyle(.secondary)
                    Circle().fill(Color(hex: event.colorHex)).frame(width: 8, height: 8)
                    Text(event.title)
                    Spacer()
                    Text(event.calendarTitle).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private func itemSection(_ title: String, _ items: [BriefItem], checkable: Bool, isWarning: Bool = false)
        -> some View
    {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle(title, isWarning: isWarning)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    BriefItemRow(item: item, checkable: checkable, model: model)
                }
            }
        }
    }

    private func sectionTitle(_ title: String, isWarning: Bool = false) -> some View {
        Text(title).font(.caption.bold()).foregroundStyle(isWarning ? Color.red : Color.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct BriefItemRow: View {
    let item: BriefItem
    let checkable: Bool
    var model: BriefModel

    var body: some View {
        HStack {
            if checkable {
                Button {
                    model.toggle(item)
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isCompleted ? "Reopen \(item.title)" : "Complete \(item.title)")
            }
            Button {
                if let noteId = item.noteId { LibraryFeature.open(noteId: noteId) }
            } label: {
                HStack {
                    Text(item.title).strikethrough(item.isCompleted)
                    Spacer()
                    if let time = item.time {
                        Text(time.formatted(date: .omitted, time: .shortened))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(item.title) in the Library")
        }
    }
}

extension Color {
    fileprivate init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0x888888
        self.init(
            red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}
