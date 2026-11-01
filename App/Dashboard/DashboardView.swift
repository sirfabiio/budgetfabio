import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @EnvironmentObject private var router: AppRouter
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @Query private var rules: [RecurringRule]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0
    @AppStorage(SettingsKeys.globalBudget) private var globalBudget: Int = 0
    @State private var month: Date = BalanceCalculator.monthInterval(containing: .now).start
    @State private var editing: FinTransaction?

    var body: some View {
        let snaps = transactions.map(\.snapshot)
        let interval = BalanceCalculator.monthInterval(containing: month)
        let isCurrent = interval.contains(.now)
        let balances = BalanceCalculator.balances(snaps, opening: openingBalance,
                                                  upTo: isCurrent ? nil : interval.end.addingTimeInterval(-1))
        let flow = BalanceCalculator.cashFlow(snaps, from: interval.start, to: interval.end)
        let byCategory = BalanceCalculator.expensesByCategory(snaps, from: interval.start, to: interval.end)
        let series = AnalyticsCalculator.monthlySeries(snaps, opening: openingBalance, months: 6, now: month)
        let pendingReview = transactions.filter(\.needsReview).count

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    MonthMenu(month: $month)
                    Spacer()
                    NavigationLink { AnalyticsView() } label: {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(Theme.card, in: Circle())
                            .overlay(Circle().stroke(Theme.outline, lineWidth: 1))
                    }
                    .accessibilityLabel("Análise")
                }
                .padding(.top, 8)

                BudgetRingCard(flow: flow, budget: globalBudget)

                HStack(spacing: 12) {
                    BalanceTile(title: "Saldo à ordem", icon: "wallet.pass", cents: balances.checking, muted: false)
                    Button { router.tab = .vault } label: {
                        BalanceTile(title: "Cofre", icon: "lock", cents: balances.vault, muted: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Abre o cofre")
                }

                if pendingReview > 0 {
                    NavigationLink { ReviewQueueView() } label: {
                        HStack(spacing: 12) {
                            IconTile(systemName: "exclamationmark.bubble.fill", colorHex: "#C26A00", size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(pendingReview) transaç\(pendingReview == 1 ? "ão" : "ões") por rever").font(.headline)
                                Text("Capturadas pelo Apple Pay").font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                        }
                        .card(padding: 16)
                    }
                    .buttonStyle(.plain)
                }

                SectionTitle("Resumo") {
                    Text(DateFormat.month(month)).font(.subheadline).foregroundStyle(Theme.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    FlowTile(flow: flow)
                    TopCategoryTile(byCategory: byCategory, categories: categories)
                    TrendTile(series: series)
                    SavingsTile(flow: flow)
                }

                Group {
                    UpcomingTile(rules: rules)
                    if isCurrent {
                        ForecastSection(checking: balances.checking)
                    }
                }

                if !byCategory.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow("Distribuição por categoria")
                        CategoryPieChart(totals: byCategory, categories: categories)
                        ForEach(byCategory.prefix(6)) { item in
                            let cat = categories.first { $0.id == item.categoryID }
                            HStack(spacing: 10) {
                                Circle().fill(Color(hex: cat?.colorHex ?? "#8E8E93")).frame(width: 10, height: 10)
                                Text(cat?.name ?? "Sem categoria").font(.subheadline)
                                Spacer()
                                Text(MoneyFormat.string(item.total)).font(.subheadline.monospacedDigit())
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .card()
                }

                Group {
                SectionTitle("Transações recentes") {
                    Button { router.tab = .ledger } label: {
                        HStack(spacing: 4) { Text("Ver tudo"); Image(systemName: "chevron.right") }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.primary)
                    }
                }

                if transactions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray").font(.largeTitle).foregroundStyle(Theme.textSecondary)
                        Text("Ainda sem transações").font(.headline)
                        Text("Toca em + para registar a primeira.").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .card()
                } else {
                    RowsCard {
                        let recent = Array(transactions.prefix(5))
                        ForEach(recent) { t in
                            Button { editing = t } label: { TransactionRow(transaction: t) }
                                .buttonStyle(.plain)
                            if t.id != recent.last?.id { RowDivider() }
                        }
                    }
                }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 96)
        }
        .screenBackground()
        .overlay(alignment: .bottomTrailing) { NewTransactionFAB() }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editing) { TransactionEditorView(transaction: $0) }
    }
}

// MARK: - Cartões do painel

private struct BudgetRingCard: View {
    @EnvironmentObject private var router: AppRouter
    var flow: CashFlow
    var budget: Cents

    var body: some View {
        let hasBudget = budget > 0
        let status = BudgetCalculator.status(spent: flow.expense, limit: budget)
        let available = budget - flow.expense
        let fraction: Double = hasBudget ? status.fraction
            : (flow.income > 0 ? Double(flow.expense) / Double(flow.income) : 0)
        let ringColor = hasBudget ? (status.state == .normal ? Theme.primary : status.state.color) : Theme.primary

        VStack(spacing: 20) {
            ZStack {
                ProgressRing(fraction: fraction, color: ringColor, lineWidth: 14)
                    .frame(width: 200, height: 200)
                VStack(spacing: 4) {
                    HeroAmount(cents: hasBudget ? available : flow.net,
                               color: (hasBudget ? available : flow.net) < 0 ? Theme.danger : Theme.textPrimary)
                        .frame(maxWidth: 160)
                    Text(hasBudget ? "disponível para gastar\neste mês" : "saldo do mês")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(hasBudget
                ? "Disponível para gastar este mês: \(MoneyFormat.string(available)). \(status.state.label)."
                : "Saldo do mês: \(MoneyFormat.string(flow.net)).")

            Rectangle().fill(Theme.outline).frame(height: 1)

            HStack(spacing: 0) {
                if hasBudget {
                    RingStat(title: "Orçamento", cents: budget)
                    divider
                    RingStat(title: "Gasto", cents: flow.expense)
                    divider
                    RingStat(title: "Disponível", cents: available, color: available < 0 ? Theme.danger : Theme.primary)
                } else {
                    RingStat(title: "Receitas", cents: flow.income, color: Theme.positive)
                    divider
                    RingStat(title: "Despesas", cents: flow.expense)
                    divider
                    Button { router.tab = .budgets } label: {
                        VStack(spacing: 4) {
                            Eyebrow("Orçamento")
                            Text("Definir").font(.headline).foregroundStyle(Theme.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card(padding: 24)
    }

    private var divider: some View {
        Rectangle().fill(Theme.outline).frame(width: 1, height: 40)
    }
}

private struct RingStat: View {
    var title: String
    var cents: Cents
    var color: Color = Theme.textPrimary

    var body: some View {
        VStack(spacing: 4) {
            Eyebrow(title)
            Text(MoneyFormat.string(cents))
                .font(.headline.monospacedDigit())
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct BalanceTile: View {
    var title: String
    var icon: String
    var cents: Cents
    var muted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Eyebrow(title)
                Spacer()
                Image(systemName: icon).foregroundStyle(Theme.textSecondary).accessibilityHidden(true)
            }
            HeroAmount(cents: cents, font: .title2.weight(.bold), color: cents < 0 ? Theme.danger : Theme.textPrimary)
        }
        .card(background: muted ? Theme.cardMuted : Theme.card)
        .accessibilityElement(children: .combine)
    }
}

private struct SummaryTile<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(title)
            content
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .card(padding: 16)
    }
}

private struct FlowTile: View {
    var flow: CashFlow

    var body: some View {
        let pct = flow.income > 0 ? flow.expense * 100 / flow.income : 0
        SummaryTile(title: "Fluxo do mês") {
            Text(flow.income > 0 ? "\(pct)% gasto" : "Sem receitas").font(.headline)
            Spacer(minLength: 4)
            ThinProgress(fraction: flow.income > 0 ? Double(flow.expense) / Double(flow.income) : 0,
                         color: pct > 100 ? Theme.danger : Theme.primary, height: 8)
            HStack {
                Text(MoneyFormat.string(flow.income)).foregroundStyle(Theme.positive)
                Spacer()
                Text(MoneyFormat.string(flow.expense))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fluxo do mês: receitas \(MoneyFormat.string(flow.income)), despesas \(MoneyFormat.string(flow.expense)).")
    }
}

private struct TopCategoryTile: View {
    var byCategory: [CategoryTotal]
    var categories: [FinCategory]

    var body: some View {
        let total = byCategory.reduce(0) { $0 + $1.total }
        let top = byCategory.first
        let cat = categories.first { $0.id == top?.categoryID }
        let pct = (top != nil && total > 0) ? top!.total * 100 / total : 0
        SummaryTile(title: "Categorias") {
            HStack(alignment: .top) {
                Text(top == nil ? "Sem despesas" : (cat?.name ?? "Sem categoria"))
                    .font(.headline).lineLimit(2)
                Spacer(minLength: 4)
                ProgressRing(fraction: Double(pct) / 100, color: Color(hex: cat?.colorHex ?? "#3B3BF5"), lineWidth: 5)
                    .frame(width: 30, height: 30)
            }
            Spacer(minLength: 4)
            if top != nil {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: cat?.colorHex ?? "#3B3BF5")).frame(width: 8, height: 8)
                    Text("\(pct)% do total").font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(top == nil ? "Sem despesas este mês" : "Categoria com mais gastos: \(cat?.name ?? "Sem categoria"), \(pct) por cento do total.")
    }
}

private struct TrendTile: View {
    var series: [MonthPoint]

    var body: some View {
        let cur = series.last?.expense ?? 0
        let prev = series.count >= 2 ? series[series.count - 2].expense : 0
        let change: Int? = prev > 0 ? (cur - prev) * 1000 / prev : nil
        SummaryTile(title: "Tendência") {
            Text(change.map { "\($0 >= 0 ? "+" : "−")\(abs($0) / 10),\(abs($0) % 10)% vs mês ant." } ?? "Sem comparação")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Chart(series) { p in
                LineMark(x: .value("Mês", p.month), y: .value("Despesas", MoneyFormat.chartValue(p.expense)))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.primary)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 40)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tendência das despesas nos últimos seis meses")
        .accessibilityValue(series.map { "\(DateFormat.month($0.month)): \(MoneyFormat.string($0.expense))" }.joined(separator: ", "))
    }
}

private struct SavingsTile: View {
    var flow: CashFlow

    var body: some View {
        let rate = flow.income > 0 ? flow.net * 100 / flow.income : nil
        let label: String = {
            guard let rate else { return "Sem receitas" }
            if rate >= 20 { return "Forte (\(rate)%)" }
            if rate >= 10 { return "Moderada (\(rate)%)" }
            return "Baixa (\(rate)%)"
        }()
        SummaryTile(title: "Poupança") {
            Text(label).font(.subheadline.weight(.semibold))
            Spacer(minLength: 4)
            ZStack {
                Circle().trim(from: 0, to: 0.5)
                    .stroke(Theme.track, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                Circle().trim(from: 0, to: 0.5 * max(0, min(1, Double(rate ?? 0) / 50)))
                    .stroke(Theme.primary, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }
            .rotationEffect(.degrees(180))
            .frame(width: 70, height: 70)
            .frame(height: 36, alignment: .top)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Taxa de poupança: \(label)")
    }
}

private struct UpcomingTile: View {
    var rules: [RecurringRule]

    var body: some View {
        let now = Date.now
        let horizon = PT.calendar.date(byAdding: .day, value: 30, to: now) ?? now
        let dates: [Date] = rules.filter { $0.isActive && $0.kind == .expense }.flatMap { rule in
            RecurrenceEngine.dueOccurrences(rule.schedule, lastGenerated: max(now, rule.lastGeneratedDate ?? .distantPast), now: horizon)
        }.sorted()
        NavigationLink { RecurringView() } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Eyebrow("Próximos pagamentos")
                    Text(dates.isEmpty ? "Nada agendado" : "\(dates.count) despes\(dates.count == 1 ? "a agendada" : "as agendadas")")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                }
                Spacer()
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(dates.prefix(4).enumerated()), id: \.offset) { i, d in
                        VStack(spacing: 4) {
                            Capsule().fill(i == 0 ? Theme.primary : Theme.track)
                                .frame(width: 10, height: i == 0 ? 30 : 22)
                            Text("\(PT.calendar.component(.day, from: d))")
                                .font(.caption2.weight(i == 0 ? .bold : .regular))
                                .foregroundStyle(i == 0 ? Theme.primary : Theme.textSecondary)
                        }
                    }
                }
            }
            .card(padding: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(dates.isEmpty ? "Sem pagamentos agendados nos próximos 30 dias"
            : "\(dates.count) pagamentos agendados nos próximos 30 dias. Próximo a \(DateFormat.short(dates[0])).")
    }
}

struct CategoryPieChart: View {
    var totals: [CategoryTotal]
    var categories: [FinCategory]

    private func category(_ id: UUID?) -> FinCategory? { categories.first { $0.id == id } }

    var body: some View {
        Chart(totals) { item in
            SectorMark(angle: .value("Valor", MoneyFormat.chartValue(item.total)), innerRadius: .ratio(0.6), angularInset: 2)
                .foregroundStyle(Color(hex: category(item.categoryID)?.colorHex ?? "#8E8E93"))
                .cornerRadius(4)
        }
        .frame(height: 180)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gráfico de despesas por categoria")
        .accessibilityValue(totals.map { "\(category($0.categoryID)?.name ?? "Sem categoria"): \(MoneyFormat.string($0.total))" }.joined(separator: ", "))
    }
}
