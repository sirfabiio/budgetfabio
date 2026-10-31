import Foundation

struct MonthPoint: Equatable, Identifiable {
    var month: Date
    var income: Cents
    var expense: Cents
    var checking: Cents
    var vault: Cents
    var netWorth: Cents { checking + vault }
    var saved: Cents { income - expense }
    /// Taxa de poupança em pontos base (1/100 de %), para evitar Double. nil se não houve receitas.
    var savingsRateBasisPoints: Int? {
        guard income > 0 else { return nil }
        return saved * 10_000 / income
    }
    var id: Date { month }
}

struct CategoryComparison: Equatable, Identifiable {
    var categoryID: UUID?
    var current: Cents
    var previous: Cents
    var delta: Cents { current - previous }
    var id: String { categoryID?.uuidString ?? "sem-categoria" }
}

enum AnalyticsCalculator {
    /// Série mensal (do mais antigo para o mais recente) dos últimos `months` meses até `now`.
    static func monthlySeries(_ txs: [TxSnapshot], opening: Cents, months: Int, now: Date, calendar: Calendar = PT.calendar) -> [MonthPoint] {
        guard months > 0 else { return [] }
        let currentMonth = calendar.dateInterval(of: .month, for: now)!.start
        var points: [MonthPoint] = []
        for offset in stride(from: months - 1, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .month, value: -offset, to: currentMonth),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { continue }
            let flow = BalanceCalculator.cashFlow(txs, from: start, to: end)
            let endInclusive = end.addingTimeInterval(-1)
            let b = BalanceCalculator.balances(txs, opening: opening, upTo: endInclusive)
            points.append(MonthPoint(month: start, income: flow.income, expense: flow.expense, checking: b.checking, vault: b.vault))
        }
        return points
    }

    /// Despesas por categoria no mês de `now` vs mês anterior.
    static func monthOverMonth(_ txs: [TxSnapshot], now: Date, calendar: Calendar = PT.calendar) -> [CategoryComparison] {
        let current = calendar.dateInterval(of: .month, for: now)!
        let prevStart = calendar.date(byAdding: .month, value: -1, to: current.start)!
        let cur = BalanceCalculator.expensesByCategory(txs, from: current.start, to: current.end)
        let prev = BalanceCalculator.expensesByCategory(txs, from: prevStart, to: current.start)
        var map: [UUID?: CategoryComparison] = [:]
        for c in cur { map[c.categoryID] = CategoryComparison(categoryID: c.categoryID, current: c.total, previous: 0) }
        for p in prev {
            map[p.categoryID, default: CategoryComparison(categoryID: p.categoryID, current: 0, previous: 0)].previous = p.total
        }
        return map.values.sorted { max($0.current, $0.previous) > max($1.current, $1.previous) }
    }

    /// Previsão simples de saldo no fim do mês: média diária de despesas variáveis já feitas,
    /// projetada para os dias que faltam, mais recorrentes conhecidos ainda por ocorrer.
    static func endOfMonthForecast(checking: Cents, monthExpenses: Cents, upcomingRecurringNet: Cents, now: Date, calendar: Calendar = PT.calendar) -> Cents {
        let interval = calendar.dateInterval(of: .month, for: now)!
        let dayOfMonth = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
        let remainingDays = max(0, daysInMonth - dayOfMonth)
        let dailyAverage = dayOfMonth > 0 ? monthExpenses / dayOfMonth : 0
        return checking - dailyAverage * remainingDays + upcomingRecurringNet
    }
}
