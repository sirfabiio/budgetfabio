import Foundation

struct LedgerFilter: Equatable {
    var searchText: String = ""
    var startDate: Date? = nil
    var endDate: Date? = nil
    var categoryID: UUID? = nil
    var method: PaymentMethod? = nil
    var kind: TransactionKind? = nil
    var minCents: Cents? = nil
    var maxCents: Cents? = nil

    var isActive: Bool {
        startDate != nil || endDate != nil || categoryID != nil || method != nil || kind != nil || minCents != nil || maxCents != nil
    }

    func matches(_ t: TxSnapshot, calendar: Calendar = PT.calendar) -> Bool {
        if let startDate, t.date < calendar.startOfDay(for: startDate) { return false }
        if let endDate, let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)), t.date >= end { return false }
        if let categoryID, t.categoryID != categoryID { return false }
        if let method, t.method != method { return false }
        if let kind, t.kind != kind { return false }
        if let minCents, t.amountCents < minCents { return false }
        if let maxCents, t.amountCents > maxCents { return false }
        let q = TextNormalizer.key(searchText)
        if !q.isEmpty, !TextNormalizer.key(t.text).contains(q) { return false }
        return true
    }

    /// Total com sinal: receitas e levantamentos do cofre somam, despesas e depósitos subtraem.
    static func signedTotal(_ txs: [TxSnapshot]) -> Cents {
        txs.reduce(0) { acc, t in
            switch t.kind {
            case .income, .vaultWithdrawal: return acc + t.amountCents
            case .expense, .vaultDeposit: return acc - t.amountCents
            }
        }
    }

    /// Agrupa por dia (início do dia), dias mais recentes primeiro.
    static func groupByDay<T>(_ items: [T], date: (T) -> Date, calendar: Calendar = PT.calendar) -> [DayGroup<T>] {
        let groups = Dictionary(grouping: items) { calendar.startOfDay(for: date($0)) }
        return groups.keys.sorted(by: >).map { day in
            DayGroup(day: day, items: groups[day]!.sorted { date($0) > date($1) })
        }
    }
}

struct DayGroup<T>: Identifiable {
    var day: Date
    var items: [T]
    var id: Date { day }
}
