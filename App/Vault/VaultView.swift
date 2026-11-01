import SwiftUI
import SwiftData

struct VaultView: View {
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0
    @State private var transfer: TransactionKind?
    @State private var editingTransfer: FinTransaction?
    @State private var choosingGoal = false
    @State private var allocating: Goal?

    var body: some View {
        let balances = BalanceCalculator.balances(transactions.map(\.snapshot), opening: openingBalance)
        let allocated = goals.map(\.allocatedCents)
        let free = VaultCalculator.free(vault: balances.vault, allocations: allocated)
        let movements = Array(transactions.filter { $0.kind.isTransfer }.prefix(30))

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(title: "Cofre") {
                    Badge("Separado do saldo", style: .neutral, systemImage: "lock.fill")
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Eyebrow("Total acumulado em poupança")
                        Spacer()
                        Badge("Protegido", style: .primary, systemImage: "shield")
                    }
                    HeroAmount(cents: balances.vault)
                    Label("Saldo à ordem: \(MoneyFormat.string(balances.checking))", systemImage: "wallet.pass")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    Rectangle().fill(Theme.outline).frame(height: 1)
                    HStack(spacing: 12) {
                        Button { transfer = .vaultDeposit } label: {
                            Label("Depositar", systemImage: "arrow.down")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button { transfer = .vaultWithdrawal } label: {
                            Label("Levantar", systemImage: "arrow.up")
                        }
                        .buttonStyle(OutlineButtonStyle())
                    }
                }
                .card(padding: 24)

                HStack(spacing: 14) {
                    IconTile(systemName: "wallet.pass", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disponível no cofre").font(.subheadline).foregroundStyle(Theme.textSecondary)
                        Text("Por alocar: \(MoneyFormat.string(free))").font(.headline.monospacedDigit())
                    }
                    Spacer()
                    Button("Alocar") { choosingGoal = true }
                        .buttonStyle(PillButtonStyle())
                        .disabled(free <= 0)
                }
                .card(padding: 16)
                .accessibilityElement(children: .contain)

                GoalsList(goals: goals, vault: balances.vault)

                SectionTitle("Movimentos do cofre")
                if movements.isEmpty {
                    Text("Ainda sem movimentos. As transferências não contam como despesa nem receita.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        .card()
                } else {
                    RowsCard {
                        ForEach(movements) { t in
                            Button { editingTransfer = t } label: { TransactionRow(transaction: t) }
                                .buttonStyle(.plain)
                            if t.id != movements.last?.id { RowDivider() }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $transfer) { kind in
            VaultTransferView(kind: kind, checking: balances.checking, vault: balances.vault, allocations: allocated)
        }
        .sheet(item: $editingTransfer) { TransactionEditorView(transaction: $0) }
        .sheet(item: $allocating) { g in
            GoalAllocationView(goal: g, vault: balances.vault, allocations: allocated)
        }
        .confirmationDialog("Alocar a que objetivo?", isPresented: $choosingGoal, titleVisibility: .visible) {
            ForEach(goals) { g in Button(g.name) { allocating = g } }
        } message: {
            Text(goals.isEmpty ? "Cria primeiro um objetivo." : "Livre no cofre: \(MoneyFormat.string(free))")
        }
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
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(eyebrow: "Cofre", title: kind == .vaultDeposit ? "Depositar no cofre" : "Levantar do cofre") { dismiss() }
            StyledField(systemImage: "eurosign") { AmountField(title: "Valor", cents: $amount) }
            StyledField(systemImage: "calendar") {
                Text("Data").foregroundStyle(Theme.textSecondary)
                Spacer()
                DatePicker("Data", selection: $date).labelsHidden()
            }
            StyledField(systemImage: "text.alignleft") { TextField("Nota (opcional)", text: $note) }
            if let error {
                Label(error.message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.danger)
            } else {
                Text(kind == .vaultDeposit
                     ? "Sai do saldo à ordem (\(MoneyFormat.string(checking))) e não conta como despesa."
                     : "Volta para o saldo à ordem e não conta como receita.")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Button("Confirmar") {
                guard let amount else { return }
                context.insert(FinTransaction(amountCents: amount, kind: kind, date: date, method: .bankTransfer, note: note))
                try? context.save()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled((amount ?? 0) <= 0 || error != nil)
        }
        .padding(Theme.margin)
        .padding(.top, 8)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
