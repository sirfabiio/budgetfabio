import SwiftUI
import SwiftData

struct TransactionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]

    let transaction: FinTransaction?

    @State private var kind: TransactionKind = .expense
    @State private var amount: Cents? = nil
    @State private var date: Date = .now
    @State private var categoryID: UUID? = nil
    @State private var method: PaymentMethod = .debitCard
    @State private var note: String = ""
    @State private var merchant: String = ""
    @State private var card: String = ""
    @State private var loaded = false
    @State private var confirmDelete = false

    private var availableCategories: [FinCategory] {
        let wanted: CategoryKind = kind == .income ? .income : .expense
        return categories.filter { ($0.kind == wanted && !$0.isArchived) || $0.id == categoryID }
    }

    private var canSave: Bool { (amount ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                if kind.isTransfer {
                    Section { Label(kind.label, systemImage: "arrow.left.arrow.right") }
                } else {
                    Picker("Tipo", selection: $kind) {
                        Text("Despesa").tag(TransactionKind.expense)
                        Text("Receita").tag(TransactionKind.income)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section {
                    AmountField(title: "Valor", cents: $amount)
                    DatePicker("Data", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }

                if !kind.isTransfer {
                    Section {
                        Picker("Categoria", selection: $categoryID) {
                            Text("Sem categoria").tag(UUID?.none)
                            ForEach(availableCategories) { c in
                                Label(c.name, systemImage: c.iconName).tag(Optional(c.id))
                            }
                        }
                        Picker("Método de pagamento", selection: $method) {
                            ForEach(PaymentMethod.allCases) { m in Text(m.label).tag(m) }
                        }
                    }
                }

                Section {
                    TextField("Descrição", text: $note)
                    if !kind.isTransfer {
                        TextField("Comerciante", text: $merchant)
                        if method == .applePay || !card.isEmpty {
                            TextField("Cartão", text: $card)
                        }
                    }
                }

                if transaction?.needsReview == true {
                    Section {
                        Label("Capturada automaticamente. Ao guardar fica revista e a categoria é memorizada para este comerciante.", systemImage: "info.circle")
                            .font(.footnote)
                    }
                }

                if transaction != nil {
                    Section {
                        Button("Eliminar transação", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(transaction == nil ? "Nova transação" : "Editar transação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }.disabled(!canSave)
                }
            }
            .confirmationDialog("Eliminar esta transação?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { delete() }
            }
            .onAppear(perform: load)
            .onChange(of: kind) { _, _ in
                if let id = categoryID, !availableCategories.contains(where: { $0.id == id }) { categoryID = nil }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let t = transaction else { return }
        kind = t.kind
        amount = t.amountCents
        date = t.date
        categoryID = t.category?.id
        method = t.method
        note = t.note
        merchant = t.merchant
        card = t.card
    }

    private func save() {
        guard let amount, amount > 0 else { return }
        let category = categories.first { $0.id == categoryID }
        let target: FinTransaction
        if let transaction {
            target = transaction
        } else {
            target = FinTransaction(amountCents: amount, kind: kind)
            context.insert(target)
        }
        target.amountCents = amount
        target.kind = kind
        target.date = date
        target.category = kind.isTransfer ? nil : category
        target.method = method
        target.note = note.trimmingCharacters(in: .whitespaces)
        target.merchant = merchant.trimmingCharacters(in: .whitespaces)
        target.card = card.trimmingCharacters(in: .whitespaces)
        if target.needsReview {
            target.needsReview = false
        }
        if !target.merchant.isEmpty, let category, kind == .expense {
            MerchantRuleStore.learn(merchant: target.merchant, category: category, context: context)
        }
        try? context.save()
        VaultIntegrity.enforce(context)
        dismiss()
    }

    private func delete() {
        if let transaction { context.delete(transaction) }
        try? context.save()
        VaultIntegrity.enforce(context)
        dismiss()
    }
}

struct TransactionRow: View {
    let transaction: FinTransaction

    var body: some View {
        HStack(spacing: 12) {
            if transaction.kind.isTransfer {
                CategoryIcon(iconName: "lock.fill", colorHex: "#007AFF")
            } else {
                CategoryIcon(iconName: transaction.category?.iconName ?? "questionmark",
                             colorHex: transaction.category?.colorHex ?? "#8E8E93")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.title).lineLimit(1)
                HStack(spacing: 4) {
                    Text(transaction.category?.name ?? transaction.kind.label)
                    Text("·")
                    Text(transaction.method.label)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                MoneyText(cents: transaction.amountCents, kind: transaction.kind)
                if transaction.needsReview {
                    Text("Por rever").font(.caption2.bold()).foregroundStyle(.orange)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
