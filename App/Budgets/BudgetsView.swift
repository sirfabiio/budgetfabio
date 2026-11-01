import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @AppStorage(SettingsKeys.globalBudget) private var globalBudget: Int = 0
    @State private var month: Date = BalanceCalculator.monthInterval(containing: .now).start
    @State private var editingCategory: FinCategory?
    @State private var editingGlobal = false

    var body: some View {
        let interval = BalanceCalculator.monthInterval(containing: month)
        let snaps = transactions.map(\.snapshot)
        let totalSpent = BudgetCalculator.spent(snaps, categoryID: nil, in: interval)
        let expenseCategories = categories.filter { $0.kind == .expense && (!$0.isArchived || $0.monthlyBudgetCents != nil) }
        let withLimit = expenseCategories.filter { $0.monthlyBudgetCents != nil }
        let withoutLimit = expenseCategories.filter { $0.monthlyBudgetCents == nil }
        let categoryLimits = withLimit.reduce(0) { $0 + ($1.monthlyBudgetCents ?? 0) }
        let total = globalBudget > 0 ? globalBudget : categoryLimits
        let status = BudgetCalculator.status(spent: totalSpent, limit: total)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    MonthMenu(month: $month)
                    ScreenHeader(title: "Orçamentos") {
                        CircleIconButton(systemName: "slider.horizontal.3", label: "Definir limite global") { editingGlobal = true }
                    }
                }
                .padding(.top, 8)

                Button { editingGlobal = true } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Eyebrow(globalBudget > 0 ? "Total orçamentado" : "Soma dos limites por categoria")
                            Spacer()
                            if total > 0 {
                                Text("\(totalSpent * 100 / total)% gasto").font(.subheadline).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        if total > 0 {
                            HeroAmount(cents: total)
                            ThinProgress(fraction: status.fraction, color: status.state.color, height: 6)
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(MoneyFormat.string(totalSpent)) de \(MoneyFormat.string(total))")
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(status.remaining >= 0 ? "Disponível: " : "Excedido: ").font(.subheadline)
                                Text(MoneyFormat.string(abs(status.remaining)))
                                    .font(.title3.weight(.bold).monospacedDigit())
                                    .foregroundStyle(status.remaining >= 0 ? Theme.textPrimary : Theme.danger)
                            }
                        } else {
                            Text("Ainda sem orçamento").font(.title2.weight(.bold))
                            Text("Gasto este mês: \(MoneyFormat.string(totalSpent)). Toca para definir um limite mensal global, ou define limites por categoria abaixo.")
                                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .card(padding: 24)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Editar o limite global")

                SectionTitle("Categorias") {
                    Text("\(withLimit.count) orçamento\(withLimit.count == 1 ? "" : "s")")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }

                ForEach(withLimit) { c in
                    Button { editingCategory = c } label: {
                        CategoryBudgetCard(category: c,
                                           status: BudgetCalculator.status(spent: BudgetCalculator.spent(snaps, categoryID: c.id, in: interval),
                                                                           limit: c.monthlyBudgetCents ?? 0))
                    }
                    .buttonStyle(.plain)
                }

                if !withoutLimit.isEmpty {
                    Eyebrow("Sem limite definido").padding(.top, 8).padding(.leading, 4)
                    RowsCard {
                        ForEach(withoutLimit) { c in
                            Button { editingCategory = c } label: {
                                HStack(spacing: 14) {
                                    IconTile(systemName: c.iconName, colorHex: c.colorHex, size: 40)
                                    Text(c.name).font(.body.weight(.medium))
                                    Spacer()
                                    Text(MoneyFormat.string(BudgetCalculator.spent(snaps, categoryID: c.id, in: interval)))
                                        .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                                    Image(systemName: "plus.circle").foregroundStyle(Theme.primary)
                                        .accessibilityLabel("Definir limite")
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if c.id != withoutLimit.last?.id { RowDivider(inset: 70) }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editingCategory) { c in
            BudgetLimitEditor(title: c.name, initial: c.monthlyBudgetCents) { c.monthlyBudgetCents = $0 }
        }
        .sheet(isPresented: $editingGlobal) {
            BudgetLimitEditor(title: "Limite global mensal", initial: globalBudget > 0 ? globalBudget : nil) { globalBudget = $0 ?? 0 }
        }
    }
}

private struct CategoryBudgetCard: View {
    var category: FinCategory
    var status: BudgetStatus

    var body: some View {
        let pct = status.limit > 0 ? status.spent * 100 / status.limit : 0
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                IconTile(systemName: category.iconName, colorHex: category.colorHex, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name).font(.headline).lineLimit(1)
                    Text("\(MoneyFormat.string(status.spent)) de \(MoneyFormat.string(status.limit))")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    switch status.state {
                    case .exceeded:
                        Badge("Ultrapassado", style: .danger)
                        Text("Excedido em +\(MoneyFormat.string(-status.remaining))")
                            .font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    case .nearLimit:
                        Badge("Perto do limite", style: .warning)
                        Text("Resta \(MoneyFormat.string(status.remaining)) (\(pct)%)")
                            .font(.caption.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                    case .normal:
                        Text("Resta \(MoneyFormat.string(status.remaining))").font(.headline.monospacedDigit())
                        Text("\(pct)%").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            ThinProgress(fraction: status.fraction, color: status.state.color, height: 5)
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.name): gasto \(MoneyFormat.string(status.spent)) de \(MoneyFormat.string(status.limit)), \(status.state.label).")
    }
}

struct BudgetLimitEditor: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var initial: Cents?
    var onSave: (Cents?) -> Void
    @State private var value: Cents? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SheetHeader(eyebrow: "Orçamento", title: title) { dismiss() }
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow("Limite mensal")
                StyledField(systemImage: "eurosign") {
                    AmountField(title: "", cents: $value)
                }
            }
            if initial != nil {
                Button("Remover limite", role: .destructive) { onSave(nil); dismiss() }
                    .foregroundStyle(Theme.danger)
            }
            Spacer()
            Button("Guardar") { onSave(value); dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled((value ?? 0) <= 0)
        }
        .padding(Theme.margin)
        .padding(.top, 8)
        .background(Theme.background.ignoresSafeArea())
        .onAppear { value = initial }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
