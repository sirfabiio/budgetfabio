import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0
    @AppStorage(SettingsKeys.globalBudget) private var globalBudget: Int = 0
    @State private var showingNew = false

    private var snapshots: [TxSnapshot] { transactions.map(\.snapshot) }
    private var month: DateInterval { BalanceCalculator.monthInterval(containing: .now) }

    var body: some View {
        let snaps = snapshots
        let balances = BalanceCalculator.balances(snaps, opening: openingBalance)
        let flow = BalanceCalculator.cashFlow(snaps, from: month.start, to: month.end)
        let byCategory = BalanceCalculator.expensesByCategory(snaps, from: month.start, to: month.end)
        let pendingReview = transactions.filter(\.needsReview).count

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Saldo à ordem").font(.subheadline).foregroundStyle(.secondary)
                    Text(MoneyFormat.string(balances.checking))
                        .font(.largeTitle.bold().monospacedDigit())
                        .foregroundStyle(balances.checking < 0 ? .red : .primary)
                        .minimumScaleFactor(0.6)
                    if balances.vault != 0 {
                        Label("Cofre: \(MoneyFormat.string(balances.vault))", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                }
                .accessibilityElement(children: .combine)
                .padding(.vertical, 4)
            }

            if pendingReview > 0 {
                Section {
                    NavigationLink {
                        ReviewQueueView()
                    } label: {
                        Label("\(pendingReview) transaç\(pendingReview == 1 ? "ão" : "ões") por rever", systemImage: "exclamationmark.bubble.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section(DateFormat.month(.now)) {
                CashFlowRow(title: "Receitas", cents: flow.income, color: .green)
                CashFlowRow(title: "Despesas", cents: flow.expense, color: .red)
                CashFlowRow(title: "Saldo do mês", cents: flow.net, color: flow.net >= 0 ? .green : .red)
                if globalBudget > 0 {
                    BudgetBar(status: BudgetCalculator.status(spent: flow.expense, limit: globalBudget))
                }
                CashFlowChart(flow: flow)
            }

            Section("Despesas por categoria") {
                if byCategory.isEmpty {
                    ContentUnavailableView("Sem despesas este mês", systemImage: "chart.pie",
                                           description: Text("As despesas registadas aparecem aqui."))
                } else {
                    CategoryPieChart(totals: byCategory, categories: categories)
                    ForEach(byCategory) { item in
                        let cat = categories.first { $0.id == item.categoryID }
                        HStack {
                            CategoryIcon(iconName: cat?.iconName ?? "questionmark", colorHex: cat?.colorHex ?? "#8E8E93", size: 26)
                            Text(cat?.name ?? "Sem categoria")
                            Spacer()
                            Text(MoneyFormat.string(item.total)).monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            ExtraDashboardSections(snapshots: snaps, checking: balances.checking, monthExpense: flow.expense)
        }
        .navigationTitle("Painel")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNew = true } label: { Image(systemName: "plus.circle.fill") }
                    .accessibilityLabel("Nova transação")
            }
        }
        .sheet(isPresented: $showingNew) {
            TransactionEditorView(transaction: nil)
        }
    }
}

/// Ponto de extensão para secções extra do painel (ver Fase 4).
struct ExtraDashboardSections: View {
    var snapshots: [TxSnapshot]
    var checking: Cents
    var monthExpense: Cents
    var body: some View { EmptyView() }
}

private struct CashFlowRow: View {
    var title: String
    var cents: Cents
    var color: Color

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(MoneyFormat.string(cents)).monospacedDigit().foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CashFlowChart: View {
    var flow: CashFlow

    var body: some View {
        Chart {
            BarMark(x: .value("Valor", MoneyFormat.chartValue(flow.income)), y: .value("Tipo", "Receitas"))
                .foregroundStyle(.green)
            BarMark(x: .value("Valor", MoneyFormat.chartValue(flow.expense)), y: .value("Tipo", "Despesas"))
                .foregroundStyle(.red)
        }
        .chartXAxis(.hidden)
        .frame(height: 80)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fluxo de caixa do mês: receitas \(MoneyFormat.string(flow.income)), despesas \(MoneyFormat.string(flow.expense)).")
    }
}

struct CategoryPieChart: View {
    var totals: [CategoryTotal]
    var categories: [FinCategory]

    private func category(_ id: UUID?) -> FinCategory? { categories.first { $0.id == id } }

    var body: some View {
        Chart(totals) { item in
            SectorMark(angle: .value("Valor", MoneyFormat.chartValue(item.total)), innerRadius: .ratio(0.55), angularInset: 1.5)
                .foregroundStyle(Color(hex: category(item.categoryID)?.colorHex ?? "#8E8E93"))
                .cornerRadius(4)
        }
        .frame(height: 200)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gráfico de despesas por categoria")
        .accessibilityValue(totals.map { "\(category($0.categoryID)?.name ?? "Sem categoria"): \(MoneyFormat.string($0.total))" }.joined(separator: ", "))
    }
}
