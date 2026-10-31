import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @AppStorage(SettingsKeys.globalBudget) private var globalBudget: Int = 0
    @State private var monthAnchor: Date = .now
    @State private var editingCategory: FinCategory?
    @State private var editingGlobal = false

    var body: some View {
        let interval = BalanceCalculator.monthInterval(containing: monthAnchor)
        let snaps = transactions.map(\.snapshot)
        let totalSpent = BudgetCalculator.spent(snaps, categoryID: nil, in: interval)
        let expenseCategories = categories.filter { $0.kind == .expense && (!$0.isArchived || $0.monthlyBudgetCents != nil) }

        List {
            Section {
                HStack {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Mês anterior")
                    Spacer()
                    Text(DateFormat.month(monthAnchor)).font(.headline)
                    Spacer()
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Mês seguinte")
                }
                .buttonStyle(.borderless)
            }

            Section("Limite global mensal") {
                Button { editingGlobal = true } label: {
                    if globalBudget > 0 {
                        BudgetBar(status: BudgetCalculator.status(spent: totalSpent, limit: globalBudget))
                    } else {
                        HStack {
                            Text("Definir limite global")
                            Spacer()
                            Text("Gasto: \(MoneyFormat.string(totalSpent))").foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Por categoria") {
                ForEach(expenseCategories) { c in
                    Button { editingCategory = c } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                CategoryIcon(iconName: c.iconName, colorHex: c.colorHex, size: 26)
                                Text(c.name)
                                Spacer()
                                if c.monthlyBudgetCents == nil {
                                    Text(MoneyFormat.string(BudgetCalculator.spent(snaps, categoryID: c.id, in: interval)))
                                        .foregroundStyle(.secondary).monospacedDigit()
                                }
                            }
                            if let limit = c.monthlyBudgetCents {
                                BudgetBar(status: BudgetCalculator.status(spent: BudgetCalculator.spent(snaps, categoryID: c.id, in: interval), limit: limit))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Orçamentos")
        .sheet(item: $editingCategory) { c in
            BudgetLimitEditor(title: c.name, initial: c.monthlyBudgetCents) { c.monthlyBudgetCents = $0 }
        }
        .sheet(isPresented: $editingGlobal) {
            BudgetLimitEditor(title: "Limite global", initial: globalBudget > 0 ? globalBudget : nil) { globalBudget = $0 ?? 0 }
        }
    }

    private func shiftMonth(_ delta: Int) {
        monthAnchor = PT.calendar.date(byAdding: .month, value: delta, to: monthAnchor) ?? monthAnchor
    }
}

private struct BudgetLimitEditor: View {
    @Environment(\.dismiss) private var dismiss
    var title: String
    var initial: Cents?
    var onSave: (Cents?) -> Void
    @State private var value: Cents? = nil

    var body: some View {
        NavigationStack {
            Form {
                AmountField(title: "Limite mensal", cents: $value)
                if initial != nil {
                    Button("Remover limite", role: .destructive) { onSave(nil); dismiss() }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { onSave(value); dismiss() }.disabled((value ?? 0) <= 0)
                }
            }
            .onAppear { value = initial }
        }
        .presentationDetents([.medium])
    }
}
