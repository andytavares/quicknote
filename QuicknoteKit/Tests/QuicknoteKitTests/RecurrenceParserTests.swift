import Foundation
import Testing

@testable import QuicknoteKit

struct RecurrenceParserTests {
    static let phrases: [(String, RecurrenceRule)] = [
        ("every day", RecurrenceRule(frequency: .daily)),
        ("daily", RecurrenceRule(frequency: .daily)),
        ("every weekday", RecurrenceRule(frequency: .weekly, weekdays: [2, 3, 4, 5, 6])),
        ("every week", RecurrenceRule(frequency: .weekly)),
        ("weekly", RecurrenceRule(frequency: .weekly)),
        ("every 2 weeks", RecurrenceRule(frequency: .weekly, interval: 2)),
        ("every other week", RecurrenceRule(frequency: .weekly, interval: 2)),
        ("every 3 days", RecurrenceRule(frequency: .daily, interval: 3)),
        ("every month", RecurrenceRule(frequency: .monthly)),
        ("monthly", RecurrenceRule(frequency: .monthly)),
        ("every year", RecurrenceRule(frequency: .yearly)),
        ("yearly", RecurrenceRule(frequency: .yearly)),
        ("every tue and thu", RecurrenceRule(frequency: .weekly, weekdays: [3, 5])),
        ("Every Monday, Wednesday and Friday", RecurrenceRule(frequency: .weekly, weekdays: [2, 4, 6])),
        ("EVERY SUNDAY", RecurrenceRule(frequency: .weekly, weekdays: [1])),
    ]

    @Test(arguments: phrases) func parsesPhrase(phrase: String, expected: RecurrenceRule) {
        #expect(RecurrenceParser.parse(phrase) == expected)
    }

    @Test func findsThePhraseInsideASentenceAndReportsItsRange() throws {
        let text = "water plants every tue and thu"
        let match = try #require(RecurrenceParser.find(in: text))
        #expect(text[match.range] == "every tue and thu")
        #expect(match.rule == RecurrenceRule(frequency: .weekly, weekdays: [3, 5]))
    }

    @Test(arguments: ["Everything is fine", "Buy milk", "every dayglow", ""])
    func ignoresTextWithoutARepeat(text: String) {
        #expect(RecurrenceParser.parse(text) == nil)
    }

    @Test func describesRules() {
        let cases: [(RecurrenceRule, String)] = [
            (RecurrenceRule(frequency: .weekly, weekdays: [3, 5]), "Weekly on Tuesday and Thursday"),
            (RecurrenceRule(frequency: .weekly, weekdays: [2, 4, 6]), "Weekly on Monday, Wednesday and Friday"),
            (RecurrenceRule(frequency: .weekly, weekdays: [2, 3, 4, 5, 6]), "Every weekday"),
            (RecurrenceRule(frequency: .weekly, interval: 2), "Every 2 weeks"),
            (RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [3]), "Every 2 weeks on Tuesday"),
            (RecurrenceRule(frequency: .daily), "Every day"),
            (RecurrenceRule(frequency: .daily, interval: 3), "Every 3 days"),
            (RecurrenceRule(frequency: .monthly), "Every month"),
            (RecurrenceRule(frequency: .yearly), "Every year"),
        ]
        for (rule, expected) in cases {
            #expect(RecurrenceParser.describe(rule) == expected)
        }
    }
}
