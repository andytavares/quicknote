import QuicknoteKit
import SwiftUI

/// The meeting detail window's content (S18).
struct MeetingView: View {
    @Bindable var model: MeetingModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            MeetingPlayerBar(model: model)
            Divider()
            HStack(spacing: 0) {
                tabs.frame(maxWidth: .infinity)
                Divider()
                MeetingSidePanel(model: model).frame(width: 290)
            }
        }
        .frame(minWidth: 760, minHeight: 480)
        .alert("Something went wrong", isPresented: .constant(model.problem != nil)) {
            Button("OK") { model.problem = nil }
        } message: {
            Text(model.problem ?? "")
        }
    }

    private var header: some View {
        HStack {
            Text(model.meeting.title).font(.headline)
            Text(
                "\(model.meeting.startedAt.formatted(.dateTime.weekday().day().month().hour().minute())) · \(MeetingTime.format(ms: model.durationMs))"
            )
            .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Menu("Export") {
                ForEach(MeetingExport.allCases, id: \.self) { kind in
                    Button(kind.menuTitle) { model.export(kind) }
                }
            }
            .fixedSize()
            .accessibilityLabel("Export")
        }
        .padding(12)
    }

    private var tabs: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("View", selection: $model.tab) {
                Text("Transcript").tag(MeetingModel.Tab.transcript)
                Text("Summary").tag(MeetingModel.Tab.summary)
                Text("Bookmarks (\(model.bookmarks.count))").tag(MeetingModel.Tab.bookmarks)
            }
            .pickerStyle(.segmented).labelsHidden().accessibilityLabel("Meeting view")
            switch model.tab {
            case .transcript: TranscriptList(model: model)
            case .summary: summary
            case .bookmarks: BookmarkList(model: model)
            }
        }
        .padding(12)
    }

    private var summary: some View {
        let text = model.meeting.summary ?? ""
        return ScrollView {
            Text(text.isEmpty ? emptySummaryMessage : text)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
        }
    }

    private var emptySummaryMessage: String {
        MeetingSummarizer.isAvailable
            ? "No summary for this meeting."
            : "No summary. On-device summaries are not available on this Mac."
    }
}

private struct MeetingPlayerBar: View {
    let model: MeetingModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.togglePlayback()
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
            }
            .disabled(!model.hasAudio)
            .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
            Text(MeetingTime.format(ms: model.currentMs)).monospacedDigit()
            scrubber
            Text(MeetingTime.format(ms: model.durationMs)).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var scrubber: some View {
        let seconds = Binding(
            get: { Double(model.currentMs) / 1_000 }, set: { model.seek(toMs: Int($0 * 1_000)) })
        return Slider(value: seconds, in: 0...max(1, Double(model.durationMs) / 1_000))
            .disabled(!model.hasAudio)
            .accessibilityLabel("Playback position")
            .overlay { bookmarkMarks }
    }

    private var bookmarkMarks: some View {
        GeometryReader { proxy in
            ForEach(model.bookmarks) { bookmark in
                let fraction = TranscriptNavigator.fraction(ofMs: bookmark.atMs, durationMs: model.durationMs)
                RoundedRectangle(cornerRadius: 1.5).fill(.yellow).frame(width: 3, height: 14)
                    .position(x: 8 + (proxy.size.width - 16) * fraction, y: proxy.size.height / 2)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct TranscriptList: View {
    let model: MeetingModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(model.segments.enumerated()), id: \.element.id) { row, segment in
                        TranscriptRow(segment: segment, isCurrent: row == model.currentRow) { model.seek(toRow: row) }
                            .id(row)
                    }
                }
            }
            .onChange(of: model.currentRow) { _, row in
                if let row { withAnimation { proxy.scrollTo(row, anchor: .center) } }
            }
            .onAppear { if let row = model.currentRow { proxy.scrollTo(row, anchor: .center) } }
            .overlay { if model.segments.isEmpty { Text("No transcript.").foregroundStyle(.secondary) } }
        }
    }
}

private struct TranscriptRow: View {
    let segment: TranscriptSegment
    let isCurrent: Bool
    let seek: () -> Void

    var body: some View {
        Button(action: seek) {
            HStack(alignment: .top, spacing: 10) {
                Text(MeetingTime.format(ms: segment.startMs)).font(.caption.monospacedDigit()).foregroundStyle(
                    .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(segment.speaker == .me ? "Me" : "Others").font(.caption.bold())
                    Text(segment.text).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(6)
            .background(isCurrent ? Color.accentColor.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(segment.speaker == .me ? "Me" : "Others") at \(MeetingTime.format(ms: segment.startMs)): \(segment.text)"
        )
        .accessibilityHint("Plays from here")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

private struct BookmarkList: View {
    let model: MeetingModel

    var body: some View {
        List(model.bookmarks) { bookmark in
            HStack {
                Button(MeetingTime.format(ms: bookmark.atMs)) { model.seek(toMs: bookmark.atMs) }
                    .buttonStyle(.link).accessibilityLabel("Go to \(MeetingTime.format(ms: bookmark.atMs))")
                TextField("Label", text: label(of: bookmark)).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Bookmark label at \(MeetingTime.format(ms: bookmark.atMs))")
            }
        }
        .overlay {
            if model.bookmarks.isEmpty {
                Text("No bookmarks. Press \(Shortcuts.label(for: .bookmarkMeeting)) while recording.").foregroundStyle(
                    .secondary)
            }
        }
    }

    private func label(of bookmark: MeetingBookmark) -> Binding<String> {
        Binding(get: { model.label(of: bookmark) }, set: { model.setLabel($0, of: bookmark) })
    }
}

private struct MeetingSidePanel: View {
    let model: MeetingModel
    @State private var newItem = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Action items").bold()
            Text("Saved as tasks").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.tasks) { task in taskRow(task) }
                }
            }
            HStack {
                TextField("+ Add action item", text: $newItem).onSubmit(add)
                    .accessibilityLabel("Add action item at the current time")
            }
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.quaternary.opacity(0.4))
    }

    private func taskRow(_ task: Note) -> some View {
        HStack(alignment: .top) {
            Toggle("", isOn: Binding(get: { task.completedAt != nil }, set: { _ in model.toggle(task: task) }))
                .labelsHidden().accessibilityLabel("Done: \(task.body)")
            VStack(alignment: .leading, spacing: 2) {
                Text(task.body).strikethrough(task.completedAt != nil)
                if let ms = task.sourceMs {
                    Button(MeetingTime.format(ms: ms)) { model.seek(toMs: ms) }
                        .buttonStyle(.link).font(.caption.monospacedDigit())
                        .accessibilityLabel("Go to \(MeetingTime.format(ms: ms))")
                }
            }
        }
    }

    private func add() {
        model.addActionItem(newItem)
        newItem = ""
    }
}
