import XCTest
@testable import Orcamento

final class RecurrenceEngineTests: XCTestCase {
    func testMonthlyCatchUpFromNeverGenerated() {
        let s = RecurrenceSchedule(frequency: .monthly, interval: 1, start: dayStart(2026, 1, 15), end: nil)
        let due = RecurrenceEngine.dueOccurrences(s, lastGenerated: nil, now: makeDate(2026, 4, 20))
        XCTAssertEqual(due, [dayStart(2026, 1, 15), dayStart(2026, 2, 15), dayStart(2026, 3, 15), dayStart(2026, 4, 15)])
    }

    func testCatchUpOnlyAfterLastGenerated() {
        let s = RecurrenceSchedule(frequency: .monthly, interval: 1, start: dayStart(2026, 1, 15), end: nil)
        let due = RecurrenceEngine.dueOccurrences(s, lastGenerated: dayStart(2026, 2, 15), now: makeDate(2026, 4, 20))
        XCTAssertEqual(due, [dayStart(2026, 3, 15), dayStart(2026, 4, 15)])
        // Abrir a app de novo no mesmo dia não gera duplicados.
        let again = RecurrenceEngine.dueOccurrences(s, lastGenerated: due.last, now: makeDate(2026, 4, 20))
        XCTAssertTrue(again.isEmpty)
    }

    func testMonthEndDoesNotDrift() {
        let s = RecurrenceSchedule(frequency: .monthly, interval: 1, start: dayStart(2026, 1, 31), end: nil)
        let due = RecurrenceEngine.dueOccurrences(s, lastGenerated: nil, now: makeDate(2026, 4, 30, 23))
        XCTAssertEqual(due, [dayStart(2026, 1, 31), dayStart(2026, 2, 28), dayStart(2026, 3, 31), dayStart(2026, 4, 30)])
    }

    func testDailyWeeklyYearlyAndInterval() {
        let daily = RecurrenceSchedule(frequency: .daily, interval: 1, start: dayStart(2026, 5, 1), end: nil)
        XCTAssertEqual(RecurrenceEngine.dueOccurrences(daily, lastGenerated: nil, now: makeDate(2026, 5, 7)).count, 7)

        let biweekly = RecurrenceSchedule(frequency: .weekly, interval: 2, start: dayStart(2026, 5, 1), end: nil)
        XCTAssertEqual(RecurrenceEngine.dueOccurrences(biweekly, lastGenerated: nil, now: makeDate(2026, 5, 31)),
                       [dayStart(2026, 5, 1), dayStart(2026, 5, 15), dayStart(2026, 5, 29)])

        let yearly = RecurrenceSchedule(frequency: .yearly, interval: 1, start: dayStart(2024, 2, 29), end: nil)
        XCTAssertEqual(RecurrenceEngine.dueOccurrences(yearly, lastGenerated: nil, now: makeDate(2026, 3, 1)).count, 3)
    }

    func testEndDateStopsGeneration() {
        let s = RecurrenceSchedule(frequency: .monthly, interval: 1, start: dayStart(2026, 1, 1), end: dayStart(2026, 2, 10))
        XCTAssertEqual(RecurrenceEngine.dueOccurrences(s, lastGenerated: nil, now: makeDate(2026, 6, 1)),
                       [dayStart(2026, 1, 1), dayStart(2026, 2, 1)])
        XCTAssertNil(RecurrenceEngine.nextOccurrence(s, after: dayStart(2026, 2, 1)))
    }

    func testFutureStartGeneratesNothingAndNextOccurrence() {
        let s = RecurrenceSchedule(frequency: .weekly, interval: 1, start: dayStart(2026, 7, 1), end: nil)
        XCTAssertTrue(RecurrenceEngine.dueOccurrences(s, lastGenerated: nil, now: makeDate(2026, 6, 1)).isEmpty)
        XCTAssertEqual(RecurrenceEngine.nextOccurrence(s, after: makeDate(2026, 6, 1)), dayStart(2026, 7, 1))
        XCTAssertEqual(RecurrenceEngine.nextOccurrence(s, after: dayStart(2026, 7, 1)), dayStart(2026, 7, 8))
    }
}

final class MonthlyEquivalentTests: XCTestCase {
    func testMonthlyEquivalent() {
        XCTAssertEqual(RecurrenceEngine.monthlyEquivalent(amount: 65000, frequency: .monthly, interval: 1), 65000)
        XCTAssertEqual(RecurrenceEngine.monthlyEquivalent(amount: 24000, frequency: .yearly, interval: 1), 2000)
        XCTAssertEqual(RecurrenceEngine.monthlyEquivalent(amount: 1200, frequency: .weekly, interval: 1), 5200)
        XCTAssertEqual(RecurrenceEngine.monthlyEquivalent(amount: 100, frequency: .daily, interval: 1), 3042)
        XCTAssertEqual(RecurrenceEngine.monthlyEquivalent(amount: 3000, frequency: .monthly, interval: 3), 1000)
    }
}

final class AmountKeypadTests: XCTestCase {
    func testTypingAmount() {
        var t = ""
        for k in ["4", "2", ",", "5", "0", "9"] { t = AmountKeypad.press(k, on: t) }
        XCTAssertEqual(t, "42,50")
        XCTAssertEqual(AmountParser.parseCents(t), 4250)
        t = AmountKeypad.press("⌫", on: t)
        XCTAssertEqual(t, "42,5")
        XCTAssertEqual(AmountKeypad.press(",", on: ""), "0,")
        XCTAssertEqual(AmountKeypad.press(",", on: "3,"), "3,")
        XCTAssertEqual(AmountKeypad.press("7", on: "0"), "7")
        XCTAssertEqual(AmountKeypad.press("1", on: "123456789"), "123456789")
    }
}
