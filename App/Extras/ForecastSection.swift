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
        // Despesas variáveis do mês (exclui as geradas por regras recorrentes).
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
        HStack(spacing: 14) {
            IconTile(systemName: "sparkles", colorHex: "#3B3BF5", size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow("Previsão a \(DateFormat.short(month.end.addingTimeInterval(-1)))")
                Text(MoneyFormat.string(forecast))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(forecast < 0 ? Theme.danger : Theme.textPrimary)
                Text("Ritmo de gasto atual + recorrentes por ocorrer")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .card(padding: 16)
        .accessibilityElement(children: .combine)
    }
}
