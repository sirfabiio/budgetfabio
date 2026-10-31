import SwiftUI
import SwiftData

/// Extra: previsão do saldo à ordem no fim do mês.
struct ForecastSection: View {
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query private var rules: [RecurringRule]
    var checking: Cents

    var body: some View {
        let now = Date.now
        let cal = PT.calendar
        let month = BalanceCalculator.monthInterval(containing: now)
        // Despesas variáveis do mês (exclui recorrentes e partes de despesas partilhadas já conhecidas).
        let variable = transactions
            .filter { $0.kind == .expense && $0.recurringRuleID == nil && $0.date >= month.start && $0.date < month.end }
            .reduce(0) { $0 + $1.amountCents }
        let upcoming = rules.filter(\.isActive).reduce(0) { acc, rule -> Cents in
            let from = max(now, rule.lastGeneratedDate ?? .distantPast)
            let dates = RecurrenceEngine.dueOccurrences(rule.schedule, lastGenerated: from, now: month.end.addingTimeInterval(-1), calendar: cal)
            let sign = rule.kind == .income ? 1 : -1
            return acc + sign * rule.amountCents * dates.count
        }
        let forecast = AnalyticsCalculator.endOfMonthForecast(checking: checking, monthExpenses: variable,
                                                              upcomingRecurringNet: upcoming, now: now, calendar: cal)
        Section {
            HStack {
                VStack(alignment: .leading) {
                    Text("Saldo previsto a \(DateFormat.short(month.end.addingTimeInterval(-1)))")
                    Text("Ritmo de gasto atual + recorrentes por ocorrer").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(MoneyFormat.string(forecast))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(forecast < 0 ? .red : .primary)
            }
            .accessibilityElement(children: .combine)
        } header: {
            Text("Previsão de fim de mês")
        }
    }
}
