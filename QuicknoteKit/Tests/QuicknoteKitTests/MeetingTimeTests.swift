import Testing

@testable import QuicknoteKit

struct MeetingTimeTests {
    @Test func formatsUnderAnHourAsMinutesAndSeconds() {
        #expect(MeetingTime.format(ms: 1_112_000) == "18:32")
        #expect(MeetingTime.format(ms: 5_999) == "00:05")
    }

    @Test func formatsAnHourOrMoreWithHours() {
        #expect(MeetingTime.format(ms: 3_600_000) == "1:00:00")
        #expect(MeetingTime.format(ms: 3_725_000) == "1:02:05")
    }

    @Test func negativeValuesClampToZero() {
        #expect(MeetingTime.format(ms: -50) == "00:00")
    }
}
