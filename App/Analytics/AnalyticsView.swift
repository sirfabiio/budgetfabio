import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query(sort: \FinTransaction.date) private var transactions: [FinTransaction]
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0
    @State private var months = 6
    @State private var share: ShareFile?

    var body: some View {
        let snaps = transactions.map(\.snapshot)
        let series = AnalyticsCalculator.monthlySeries(snaps, opening: openingBalance, months: months, now: .now)
        let mom = AnalyticsCalculator.monthOverMonth(snaps, now: .now)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Finanças pessoais", title: "Análise") {
                    Text("Atualizado hoje").font(.subheadline).foregroundStyle(Theme.textSecondary)
                }

                Picker("Período", selection: $months) {
                    Text("3M").tag(3)
                    Text("6M").tag(6)
                    Text("12M").tag(12)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Período em meses")

                NetWorthCard(series: series)
                SavingsCard(series: series)
                MonthComparisonCard(series: series, mom: mom, categories: categories)
                TopCategoriesCard(snaps: snaps, months: months, categories: categories)

                Button { exportPDF() } label: {
                    Label("Exportar relatório mensal (PDF)", systemImage: "arrow.down.doc")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $share) { ActivityView(items: [$0.url]) }
    }

    private func exportPDF() {
        if let url = MonthlyReportBuilder.makePDF(transactions: transactions, categories: categories,
                                                  opening: openingBalance, month: .now) {
            share = ShareFile(url: url)
        }
    }
}

/// Variação percentual em décimas (ex.: 184 → "+18,4%").
private func percentText(_ tenths: Int) -> String {
    "\(tenths >= 0 ? "+" : "−")\(abs(tenths) / 10),\(abs(tenths) % 10)%"
}

private struct NetWorthCard: View {
    var series: [MonthPoint]

    var body: some View {
        let first = series.first?.netWorth ?? 0
        let last = series.last?.netWorth ?? 0
        let delta = last - first
        let change: Int? = first != 0 ? delta * 1000 / abs(first) : nil
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Evolução do património líquido")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HeroAmount(cents: last)
                if let change { Badge(percentText(change), style: change >= 0 ? .primary : .danger) }
            }
            Text("Últimos \(series.count) meses (\(delta >= 0 ? "+" : "−") \(MoneyFormat.string(abs(delta))))")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
            Chart(series) { p in
                AreaMark(x: .value("Mês", p.month, unit: .month), y: .value("Património", MoneyFormat.chartValue(p.netWorth)))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Theme.primary.opacity(0.18), Theme.primary.opacity(0.0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Mês", p.month, unit: .month), y: .value("Património", MoneyFormat.chartValue(p.netWorth)))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.primary)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .symbol { Circle().stroke(Theme.primary, lineWidth: 2).background(Circle().fill(Theme.card)).frame(width: 8, height: 8) }
            }
            .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])) } }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .frame(height: 180)
            .padding(.top, 8)
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Evolução do património líquido: \(MoneyFormat.string(last)).")
        .accessibilityValue(series.map { "\(DateFormat.month($0.month)): \(MoneyFormat.string($0.netWorth))" }.joined(separator: ", "))
    }
}

private struct SavingsCard: View {
    var series: [MonthPoint]

    var body: some View {
        let rates = series.compactMap(\.savingsRateBasisPoints)
        let avg = rates.isEmpty ? nil : rates.reduce(0, +) / rates.count
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("Taxa de poupança")
                Spacer()
                Badge("Meta: 20%")
            }
            Text(avg.map { "\($0 / 100)% de média" } ?? "Sem receitas no período").font(.title3.weight(.semibold))
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(series.enumerated()), id: \.offset) { i, p in
                    let rate = p.savingsRateBasisPoints
                    let isLast = i == series.count - 1
                    let h = CGFloat(max(0, min(60, (rate ?? 0) / 100))) / 60 * 90
                    VStack(spacing: 6) {
                        Text(rate.map { "\($0 / 100)%" } ?? "—")
                            .font(.caption2.weight(isLast ? .bold : .regular))
                            .foregroundStyle(isLast ? Theme.primary : ((rate ?? 0) < 0 ? Theme.danger : Theme.textSecondary))
                            .lineLimit(1).minimumScaleFactor(0.6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isLast ? Theme.primary : Theme.track)
                            .frame(height: max(4, h))
                        Text(DateFormat.monthAbbrev(p.month))
                            .font(.caption2.weight(isLast ? .bold : .regular))
                            .foregroundStyle(isLast ? Theme.textPrimary : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140, alignment: .bottom)
            Rectangle().fill(Theme.outline).frame(height: 1)
            if let last = series.last {
                Text("No mês corrente, poupaste \(MoneyFormat.string(max(0, last.saved))) (\(last.savingsRateBasisPoints.map { "\($0 / 100)%" } ?? "—") das receitas). Transferências para o cofre não contam como despesa.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Taxa de poupança mensal")
        .accessibilityValue(series.map { "\(DateFormat.month($0.month)): \($0.savingsRateBasisPoints.map { "\($0 / 100) por cento" } ?? "sem receitas")" }.joined(separator: ", "))
    }
}

private struct MonthComparisonCard: View {
    var series: [MonthPoint]
    var mom: [CategoryComparison]
    var categories: [FinCategory]

    var body: some View {
        let cur = series.last
        let prev = series.count >= 2 ? series[series.count - 2] : nil
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Comparação mês a mês")
                Spacer()
                if let cur, let prev {
                    Text("\(DateFormat.monthAbbrev(cur.month)) vs \(DateFormat.monthAbbrev(prev.month))")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            }
            HStack(spacing: 10) {
                CompareTile(title: "Receitas", value: cur?.income ?? 0, previous: prev?.income ?? 0, sign: "+ ")
                CompareTile(title: "Despesas", value: cur?.expense ?? 0, previous: prev?.expense ?? 0, sign: "− ")
            }
            Rectangle().fill(Theme.outline).frame(height: 1)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saldo do mês").font(.headline)
                    Text("Receitas − despesas").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                let net = cur?.saved ?? 0
                Text("\(net >= 0 ? "+" : "−") \(MoneyFormat.string(abs(net)))")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(net >= 0 ? Theme.textPrimary : Theme.danger)
            }
            if !mom.isEmpty {
                Rectangle().fill(Theme.outline).frame(height: 1)
                Text("Por categoria").font(.subheadline.weight(.semibold))
                ForEach(mom.prefix(6)) { c in
                    HStack {
                        Text(categories.first { $0.id == c.categoryID }?.name ?? "Sem categoria").font(.subheadline)
                        Spacer()
                        Text("\(c.delta > 0 ? "+" : c.delta < 0 ? "−" : "")\(MoneyFormat.string(abs(c.delta)))")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(c.delta > 0 ? Theme.danger : Theme.positive)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .card()
    }
}

private struct CompareTile: View {
    var title: String
    var value: Cents
    var previous: Cents
    var sign: String

    var body: some View {
        let change: Int? = previous > 0 ? (value - previous) * 1000 / previous : nil
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(Theme.textSecondary)
            Text(sign + MoneyFormat.string(value)).font(.headline.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6)
            Text(change.map { "\(percentText($0)) vs \(MoneyFormat.string(previous))" } ?? "Sem mês anterior")
                .font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct TopCategoriesCard: View {
    var snaps: [TxSnapshot]
    var months: Int
    var categories: [FinCategory]

    var body: some View {
        let cal = PT.calendar
        let end = BalanceCalculator.monthInterval(containing: .now).end
        let start = cal.date(byAdding: .month, value: -months, to: end) ?? end
        let totals = BalanceCalculator.expensesByCategory(snaps, from: start, to: end)
        let sum = max(1, totals.reduce(0) { $0 + $1.total })
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Eyebrow("Top categorias")
                Spacer()
                Text("Total: \(MoneyFormat.string(totals.reduce(0) { $0 + $1.total }))").font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            if totals.isEmpty {
                Text("Sem despesas no período.").font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            ForEach(Array(totals.prefix(5).enumerated()), id: \.offset) { i, item in
                let cat = categories.first { $0.id == item.categoryID }
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(i + 1). \(cat?.name ?? "Sem categoria")").font(.body)
                        Spacer()
                        Text(MoneyFormat.string(item.total)).font(.body.monospacedDigit())
                        Text("\(item.total * 100 / sum)%").font(.caption).foregroundStyle(Theme.textSecondary).frame(width: 40, alignment: .trailing)
                    }
                    ThinProgress(fraction: Double(item.total) / Double(sum),
                                 color: i == 0 ? Theme.primary : Color(hex: cat?.colorHex ?? "#8E8E93").opacity(0.8), height: 6)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }
}
