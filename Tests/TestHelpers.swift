import Foundation
@testable import Orcamento

func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    PT.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}

func dayStart(_ y: Int, _ m: Int, _ d: Int) -> Date {
    PT.calendar.date(from: DateComponents(year: y, month: m, day: d))!
}
