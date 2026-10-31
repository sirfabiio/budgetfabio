import Foundation

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekly, monthly, yearly
    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "Diária"
        case .weekly: return "Semanal"
        case .monthly: return "Mensal"
        case .yearly: return "Anual"
        }
    }

    func unitLabel(_ n: Int) -> String {
        switch self {
        case .daily: return n == 1 ? "dia" : "dias"
        case .weekly: return n == 1 ? "semana" : "semanas"
        case .monthly: return n == 1 ? "mês" : "meses"
        case .yearly: return n == 1 ? "ano" : "anos"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        case .yearly: return .year
        }
    }
}

struct RecurrenceSchedule: Equatable {
    var frequency: RecurrenceFrequency
    var interval: Int
    var start: Date
    var end: Date?
}

enum RecurrenceEngine {
    /// Limite de segurança para não gerar listas infinitas.
    static let maxOccurrences = 5000

    /// n-ésima ocorrência, calculada sempre a partir da data inicial para evitar deriva
    /// (ex.: dia 31 → 28/29 fev → 31 mar).
    static func occurrence(_ n: Int, of s: RecurrenceSchedule, calendar: Calendar = PT.calendar) -> Date? {
        calendar.date(byAdding: s.frequency.component, value: n * max(1, s.interval), to: s.start)
    }

    /// Ocorrências em atraso: estritamente depois de `lastGenerated` (se existir) e até `now` (inclusive).
    static func dueOccurrences(_ s: RecurrenceSchedule, lastGenerated: Date?, now: Date, calendar: Calendar = PT.calendar) -> [Date] {
        var result: [Date] = []
        var n = 0
        while n < maxOccurrences, let date = occurrence(n, of: s, calendar: calendar) {
            if date > now { break }
            if let end = s.end, date > end { break }
            if lastGenerated == nil || date > lastGenerated! {
                result.append(date)
            }
            n += 1
        }
        return result
    }

    /// Próxima ocorrência estritamente depois de `date`.
    static func nextOccurrence(_ s: RecurrenceSchedule, after date: Date, calendar: Calendar = PT.calendar) -> Date? {
        var n = 0
        while n < maxOccurrences, let d = occurrence(n, of: s, calendar: calendar) {
            if let end = s.end, d > end { return nil }
            if d > date { return d }
            n += 1
        }
        return nil
    }
}
