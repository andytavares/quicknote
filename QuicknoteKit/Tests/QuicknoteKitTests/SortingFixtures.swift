import Foundation

@testable import QuicknoteKit

/// Gregorian calendar in New York, where the 1 Nov 2026 DST change falls.
let newYorkCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    return calendar
}()

func newYorkDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    newYorkCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
