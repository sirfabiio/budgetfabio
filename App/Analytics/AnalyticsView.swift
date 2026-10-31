import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query(sort: \FinTransaction.date) private var transactions: [FinTransaction]
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0
    @State private var months = 6

    var body: some View {
        let snaps = transactions.map(\.snapshot)
        let series = AnalyticsCalculator.monthlySeries(snaps, opening: openingBalance, months: months, now: .now)
        let mom = AnalyticsCalculator.monthOverMonth(snaps, now: .now)

        List {
            Picker("Período", selection: $months) {
                Text("6 meses").tag(6)
                Text("12 meses").tag(12)
                Text("24 meses").tag(24)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            netWorthSection(series)
            savingsSection(series)
            momSection(mom)
        }
        .navigationTitle("Análise")
    }

    @ViewBuilder
    private func netWorthSection(_ series: [MonthPoint]) -> some View {
    Section("Evolução do património") {
        Chart(series) { p in
            AreaMark(x: .value("Mês", p.month, unit: .month), y: .value("Património", MoneyFormat.chartValue(p.netWorth)))
                .foregroundStyle(Color.blue.opacity(0.15))
            LineMark(x: .value("Mês", p.month, unit: .month), y: .value("Património", MoneyFormat.chartValue(p.netWorth)))
                .foregroundStyle(.blue)
                .symbol(.circle)
        }
        .chartXAxis { AxisMarks(values: .stride(by: .month, count: months > 12 ? 3 : 1)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
        .frame(height: 200)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Evolução do património")
        .accessibilityValue(series.map { "\(DateFormat.month($0.month)): \(MoneyFormat.string($0.netWorth))" }.joined(separator: ", "))
        if let last = series.last {
            LabeledContent("Património atual", value: MoneyFormat.string(last.netWorth))
            LabeledContent("Saldo à ordem", value: MoneyFormat.string(last.checking))
            LabeledContent("Cofre", value: MoneyFormat.string(last.vault))
        }
    }
    }

    @ViewBuilder
    private func savingsSection(_ series: [MonthPoint]) -> some View {
    Section {
        Chart(series) { p in
            BarMark(x: .value("Mês", p.month, unit: .month), y: .value("Taxa", Double(p.savingsRateBasisPoints ?? 0) / 100))
                .foregroundStyle((p.savingsRateBasisPoints ?? 0) >= 0 ? Color.green : Color.red)
        }
        .chartYAxis {
            AxisMarks { v in
                AxisGridLine()
                AxisValueLabel {
                    if let d = v.as(Double.self) { Text("\(Int(d))%") }
                }
            }
        }
        .chartXAxis { AxisMarks(values: .stride(by: .month, count: months > 12 ? 3 : 1)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Taxa de poupança mensal")
        .accessibilityValue(series.map { "\(DateFormat.month($0.month)): \(rateText($0.savingsRateBasisPoints))" }.joined(separator: ", "))
        ForEach(series.suffix(3).reversed()) { p in
            LabeledContent(DateFormat.month(p.month), value: "\(rateText(p.savingsRateBasisPoints)) · poupado \(MoneyFormat.string(p.saved))")
        }
    } header: {
        Text("Taxa de poupança")
    } footer: {
        Text("(Receitas − despesas) ÷ receitas. Transferências para o cofre não contam como despesa.")
    }
    }

    @ViewBuilder
    private func momSection(_ mom: [CategoryComparison]) -> some View {
    Section("Este mês vs mês anterior") {
        if mom.isEmpty {
            Text("Sem despesas nos últimos dois meses.").foregroundStyle(.secondary)
        } else {
            Chart {
                ForEach(mom) { c in
                    BarMark(x: .value("Valor", MoneyFormat.chartValue(c.previous)), y: .value("Categoria", name(c.categoryID)))
                        .foregroundStyle(by: .value("Mês", "Mês anterior"))
                        .position(by: .value("Mês", "Mês anterior"))
                    BarMark(x: .value("Valor", MoneyFormat.chartValue(c.current)), y: .value("Categoria", name(c.categoryID)))
                        .foregroundStyle(by: .value("Mês", "Este mês"))
                        .position(by: .value("Mês", "Este mês"))
                }
            }
            .chartForegroundStyleScale(["Mês anterior": Color.gray, "Este mês": Color.accentColor])
            .frame(height: CGFloat(max(160, mom.count * 44)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Comparação de despesas por categoria entre este mês e o anterior")
            .accessibilityValue(mom.map { "\(name($0.categoryID)): \(MoneyFormat.string($0.current)) contra \(MoneyFormat.string($0.previous))" }.joined(separator: ", "))
            ForEach(mom) { c in
                HStack {
                    Text(name(c.categoryID))
                    Spacer()
                    Text("\(c.delta > 0 ? "+" : c.delta < 0 ? "−" : "")\(MoneyFormat.string(abs(c.delta)))")
                        .monospacedDigit()
                        .foregroundStyle(c.delta > 0 ? .red : .green)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
    }

    private func name(_ id: UUID?) -> String {
        categories.first { $0.id == id }?.name ?? "Sem categoria"
    }

    private func rateText(_ bp: Int?) -> String {
        guard let bp else { return "—" }
        let sign = bp < 0 ? "−" : ""
        let a = abs(bp)
        return "\(sign)\(a / 100),\(String(format: "%02d", a % 100)) %"
    }
}
