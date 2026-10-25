import QuicknoteKit
import SwiftUI

/// Recorded meetings, newest first.
struct MeetingListView: View {
    let meetings: [Meeting]

    var body: some View {
        List(meetings) { meeting in
            Button {
                if let meetingId = meeting.id { MeetingsFeature.open(meetingId: meetingId, atMs: 0) }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meeting.title.isEmpty ? "Untitled meeting" : meeting.title)
                        Text(meeting.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(MeetingTime.format(ms: meeting.durationMs)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open meeting \(meeting.title)")
        }
        .overlay { if meetings.isEmpty { ContentUnavailableView("No meetings yet", systemImage: "waveform") } }
        .navigationTitle("Meetings")
    }
}
