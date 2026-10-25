import SwiftUI

/// S17's start sheet: a title and which sources to record.
struct StartMeetingView: View {
    @State var title: String
    @State private var recordsMicrophone = true
    @State private var recordsMacAudio = true
    let cancel: () -> Void
    let record: (String, Bool, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start meeting recording").bold()
            TextField("Title", text: $title).textFieldStyle(.roundedBorder).onSubmit(submit)
                .accessibilityLabel("Meeting title")
            Toggle("Record my microphone", isOn: $recordsMicrophone)
            Toggle("Record Mac audio (other people on the call)", isOn: $recordsMacAudio)
            Text("Transcribed on this Mac. Nothing is uploaded.").font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button("Record", action: submit).keyboardShortcut(.defaultAction)
                    .disabled(!recordsMicrophone && !recordsMacAudio)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func submit() {
        guard recordsMicrophone || recordsMacAudio else { return }
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        record(trimmed.isEmpty ? "Meeting" : trimmed, recordsMicrophone, recordsMacAudio)
    }
}
