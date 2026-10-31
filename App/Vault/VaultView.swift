import SwiftUI
import SwiftData

struct VaultView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0
    @State private var transfer: TransactionKind?
    @State private var editingTransfer: FinTransaction?

    var body: some View {
        let balances = BalanceCalculator.balances(transactions.map(\.snapshot), opening: openingBalance)
        let allocated = goals.map(\.allocatedCents)
        let free = VaultCalculator.free(vault: balances.vault, allocations: allocated)
        let movements = transactions.filter { $0.kind.isTransfer }

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Saldo do cofre").font(.subheadline).foregroundStyle(.secondary)
                    Text(MoneyFormat.string(balances.vault)).font(.largeTitle.bold().monospacedDigit())
                    HStack {
                        Label("Afeto a objetivos: \(MoneyFormat.string(allocated.reduce(0, +)))", systemImage: "target")
                        Spacer()
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    Label("Livre: \(MoneyFormat.string(free))", systemImage: "lock.open")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                HStack {
                    Button { transfer = .vaultDeposit } label: {
                        Label("Guardar", systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Button { transfer = .vaultWithdrawal } label: {
                        Label("Levantar", systemImage: "arrow.up.to.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .listRowBackground(Color.clear)
            } footer: {
                Text("As transferências entre o saldo à ordem (\(MoneyFormat.string(balances.checking))) e o cofre não contam como despesa nem receita.")
            }

            GoalsSection(goals: goals, vault: balances.vault)

            Section("Movimentos do cofre") {
                if movements.isEmpty {
                    Text("Ainda sem movimentos.").foregroundStyle(.secondary)
                }
                ForEach(movements.prefix(50)) { t in
                    Button { editingTransfer = t } label: {
                        HStack {
                            Image(systemName: t.kind == .vaultDeposit ? "arrow.down.to.line" : "arrow.up.to.line")
                                .foregroundStyle(.blue)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading) {
                                Text(t.kind == .vaultDeposit ? "Guardado no cofre" : "Levantado do cofre")
                                Text(DateFormat.short(t.date)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(MoneyFormat.string(t.amountCents)).monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Cofre")
        .sheet(item: $transfer) { kind in
            VaultTransferView(kind: kind, checking: balances.checking, vault: balances.vault, allocations: allocated)
        }
        .sheet(item: $editingTransfer) { TransactionEditorView(transaction: $0) }
    }
}

private struct VaultTransferView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let kind: TransactionKind
    let checking: Cents
    let vault: Cents
    let allocations: [Cents]
    @State private var amount: Cents? = nil
    @State private var date = Date.now
    @State private var note = ""

    private var error: VaultError? {
        guard let amount else { return nil }
        return kind == .vaultDeposit
            ? VaultCalculator.validateDeposit(amount: amount, checking: checking)
            : VaultCalculator.validateWithdrawal(amount: amount, vault: vault, allocations: allocations)
    }

    var body: some View {
        NavigationStack {
            Form {
                AmountField(title: "Valor", cents: $amount)
                DatePicker("Data", selection: $date)
                TextField("Nota (opcional)", text: $note)
                if let error {
                    Label(error.message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
            .navigationTitle(kind == .vaultDeposit ? "Guardar no cofre" : "Levantar do cofre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        guard let amount else { return }
                        context.insert(FinTransaction(amountCents: amount, kind: kind, date: date, method: .bankTransfer, note: note))
                        try? context.save()
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0 || error != nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
