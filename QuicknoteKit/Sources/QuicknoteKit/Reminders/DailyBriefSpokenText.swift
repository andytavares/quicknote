import Foundation

extension DailyBrief {
    /// Read-aloud script: short sentences, empty sections skipped.
    public func spokenText(calendar: Calendar) -> String {
        let speech = Speech(calendar: calendar)
        let intro = "\(speech.greeting(at: date)). Today is \(speech.format(date, "EEEE, d MMMM"))."
        let sections = [
            eventSentence(speech), dueSentence(speech), overdueSentence(), comingBackSentence(speech),
        ].compactMap { $0 }
        return ([intro] + (sections.isEmpty ? ["Nothing planned today."] : sections)).joined(separator: " ")
    }

    private func eventSentence(_ speech: Speech) -> String? {
        let spoken = events.map { $0.isAllDay ? "\($0.title), all day" : "\($0.title) at \(speech.time($0.start))" }
        return sentence("You have \(spoken.count) \(spoken.count == 1 ? "event" : "events")", spoken)
    }

    private func dueSentence(_ speech: Speech) -> String? {
        let open = dueToday.filter { !$0.isCompleted }.map { item in
            item.time.map { "\(item.title) at \(speech.time($0))" } ?? item.title
        }
        let verb = open.count == 1 ? "task is" : "tasks are"
        return sentence("\(open.count) \(verb) due today", open)
    }

    private func overdueSentence() -> String? {
        sentence("\(overdue.count) overdue", overdue.map(\.title))
    }

    private func comingBackSentence(_ speech: Speech) -> String? {
        let spoken = comingBack.map { "\($0.title) at \(speech.time($0.time!))" }
        let verb = spoken.count == 1 ? "note is" : "notes are"
        return sentence("\(spoken.count) \(verb) coming back", spoken)
    }

    /// "You have 2 events: a, b." Nil when there is nothing to read.
    private func sentence(_ head: String, _ spoken: [String]) -> String? {
        spoken.isEmpty ? nil : "\(head): \(spoken.joined(separator: ", "))."
    }
}

private struct Speech {
    let calendar: Calendar

    func greeting(at date: Date) -> String {
        switch calendar.component(.hour, from: date) {
        case ..<12: "Good morning"
        case ..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    /// "10 AM" on the hour, "4:30 PM" otherwise.
    func time(_ date: Date) -> String {
        format(date, calendar.component(.minute, from: date) == 0 ? "h a" : "h:mm a")
    }

    func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
