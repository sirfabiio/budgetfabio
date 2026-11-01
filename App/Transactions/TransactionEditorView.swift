import SwiftUI
import SwiftData

/// Lógica pura do teclado numérico do montante ("42,50").
enum AmountKeypad {
    static let maxIntegerDigits = 9

    static func press(_ key: String, on text: String) -> String {
        switch key {
        case "⌫":
            return String(text.dropLast())
        case ",":
            if text.contains(",") { return text }
            return text.isEmpty ? "0," : text + ","
        default:
            guard key.count == 1, key.first!.isNumber else { return text }
            if let comma = text.firstIndex(of: ",") {
                if text.distance(from: comma, to: text.endIndex) > 2 { return text }
                return text + key
            }
            if text == "0" { return key }
            if text.count >= maxIntegerDigits { return text }
            return text + key
        }
    }
}

struct TransactionEditorView: View {
    private enum Mode: Hashable { case expense, income, transfer }
    private enum Field: Hashable { case note, merchant, card }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @Query private var allTransactions: [FinTransaction]
    @Query private var goals: [Goal]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0

    let transaction: FinTransaction?

    @State private var mode: Mode = .expense
    @State private var transferKind: TransactionKind = .vaultDeposit
    @State private var amountText = ""
    @State private var date: Date = .now
    @State private var categoryID: UUID? = nil
    @State private var method: PaymentMethod = .applePay
    @State private var note = ""
    @State private var merchant = ""
    @State private var card = ""
    @State private var showAllCategories = false
    @State private var loaded = false
    @State private var confirmDelete = false
    @FocusState private var focus: Field?

    private var kind: TransactionKind {
        switch mode {
        case .expense: return .expense
        case .income: return .income
        case .transfer: return transferKind
        }
    }

    private var amount: Cents? { AmountParser.parseCents(amountText).map { abs($0) } }

    private var availableCategories: [FinCategory] {
        let wanted: CategoryKind = mode == .income ? .income : .expense
        return categories.filter { ($0.kind == wanted && !$0.isArchived) || $0.id == categoryID }
    }

    /// Valida transferências do cofre contra os saldos (sem contar esta transação, se for edição).
    private var vaultError: VaultError? {
        guard mode == .transfer, let amount, amount > 0 else { return nil }
        let others = allTransactions.filter { $0.id != transaction?.id }.map(\.snapshot)
        let b = BalanceCalculator.balances(others, opening: openingBalance)
        return transferKind == .vaultDeposit
            ? VaultCalculator.validateDeposit(amount: amount, checking: b.checking)
            : VaultCalculator.validateWithdrawal(amount: amount, vault: b.vault, allocations: goals.map(\.allocatedCents))
    }

    private var canSave: Bool { (amount ?? 0) > 0 && vaultError == nil }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(eyebrow: nil, title: transaction == nil ? "Nova Transação" : "Editar Transação") { dismiss() }
                .padding(.horizontal, Theme.margin)
                .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    modePicker
                    amountDisplay
                    if mode == .transfer { transferSection } else { categorySection; methodSection }
                    detailsSection
                    if transaction != nil {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Eliminar transação", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .foregroundStyle(Theme.danger)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 12) {
                if focus == nil { keypad }
                Button(transaction == nil ? "Guardar Transação" : "Guardar Alterações", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Theme.cardMuted.ignoresSafeArea())
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .confirmationDialog("Eliminar esta transação?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { delete() }
        }
        .onAppear(perform: load)
        .onChange(of: mode) { _, _ in
            if let id = categoryID, !availableCategories.contains(where: { $0.id == id }) { categoryID = nil }
        }
    }

    // MARK: Secções

    private var modePicker: some View {
        Picker("Tipo", selection: $mode) {
            Text("Despesa").tag(Mode.expense)
            Text("Receita").tag(Mode.income)
            Text("Transferência").tag(Mode.transfer)
        }
        .pickerStyle(.segmented)
    }

    private var amountDisplay: some View {
        let sign: String = (kind == .income || kind == .vaultWithdrawal) ? "+ " : "− "
        return VStack(spacing: 6) {
            Eyebrow("Montante")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(sign + (amountText.isEmpty ? "0" : amountText))
                    .font(.system(size: 56, weight: .medium, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(amountText.isEmpty ? Theme.textSecondary : Theme.textPrimary)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text("€").font(.system(size: 36)).foregroundStyle(Theme.textSecondary)
            }
            if let vaultError {
                Label(vaultError.message, systemImage: "exclamationmark.triangle")
                    .font(.footnote).foregroundStyle(Theme.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Montante: \(amount.map { MoneyFormat.string($0) } ?? "vazio")")
    }

    private var categorySection: some View {
        let list = availableCategories
        let shown = showAllCategories ? list : Array(list.prefix(6))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Categoria").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textSecondary)
                Spacer()
                if list.count > 6 {
                    Button(showAllCategories ? "Ver menos" : "Ver todas") { showAllCategories.toggle() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.primary)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(shown) { c in
                    Button {
                        categoryID = categoryID == c.id ? nil : c.id
                    } label: {
                        SelectChip(title: c.name, systemImage: c.iconName, colorHex: c.colorHex, selected: categoryID == c.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Método de pagamento").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PaymentMethod.allCases) { m in
                        Button { method = m } label: {
                            SelectChip(title: m.label, systemImage: Self.icon(for: m), selected: method == m)
                                .fixedSize()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var transferSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sentido").font(.subheadline.weight(.medium)).foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                Button { transferKind = .vaultDeposit } label: {
                    SelectChip(title: "Para o cofre", systemImage: "arrow.down.to.line", selected: transferKind == .vaultDeposit)
                }
                .buttonStyle(.plain)
                Button { transferKind = .vaultWithdrawal } label: {
                    SelectChip(title: "Do cofre", systemImage: "arrow.up.to.line", selected: transferKind == .vaultWithdrawal)
                }
                .buttonStyle(.plain)
            }
            Text("As transferências entre o saldo à ordem e o cofre não contam como despesa nem receita.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    private var detailsSection: some View {
        VStack(spacing: 10) {
            StyledField(systemImage: "calendar") {
                Text("Data").foregroundStyle(Theme.textSecondary)
                Spacer()
                DatePicker("Data", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .environment(\.locale, PT.locale)
            }
            StyledField(systemImage: "text.alignleft") {
                TextField("Descrição", text: $note).focused($focus, equals: .note)
            }
            if mode != .transfer {
                StyledField(systemImage: "storefront") {
                    TextField("Comerciante", text: $merchant).focused($focus, equals: .merchant)
                }
                if method == .applePay || !card.isEmpty {
                    StyledField(systemImage: "creditcard") {
                        TextField("Cartão", text: $card).focused($focus, equals: .card)
                    }
                }
            }
            if transaction?.needsReview == true {
                Label("Capturada automaticamente. Ao guardar fica revista e a categoria é memorizada para este comerciante.",
                      systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ",", "0", "⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { key in
                Button {
                    amountText = AmountKeypad.press(key, on: amountText)
                } label: {
                    Group {
                        if key == "⌫" {
                            Image(systemName: "delete.left")
                        } else {
                            Text(key)
                        }
                    }
                    .font(.title2.weight(.regular))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.outline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key == "⌫" ? "Apagar" : (key == "," ? "Vírgula" : key))
            }
        }
    }

    static func icon(for method: PaymentMethod) -> String {
        switch method {
        case .applePay: return "wave.3.right"
        case .debitCard, .creditCard: return "creditcard"
        case .cash: return "banknote"
        case .mbway: return "iphone"
        case .bankTransfer: return "arrow.left.arrow.right"
        case .directDebit: return "building.columns"
        case .other: return "ellipsis.circle"
        }
    }

    // MARK: Ações

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let t = transaction else { return }
        switch t.kind {
        case .expense: mode = .expense
        case .income: mode = .income
        case .vaultDeposit, .vaultWithdrawal:
            mode = .transfer
            transferKind = t.kind
        }
        amountText = MoneyFormat.plainString(t.amountCents)
        date = t.date
        categoryID = t.category?.id
        method = t.method
        note = t.note
        merchant = t.merchant
        card = t.card
    }

    private func save() {
        guard let amount, amount > 0, vaultError == nil else { return }
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
        target.method = kind.isTransfer ? .bankTransfer : method
        target.note = note.trimmingCharacters(in: .whitespaces)
        target.merchant = kind.isTransfer ? "" : merchant.trimmingCharacters(in: .whitespaces)
        target.card = kind.isTransfer ? "" : card.trimmingCharacters(in: .whitespaces)
        target.needsReview = false
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
    var showsDate = true

    private var icon: (String, String?) {
        switch transaction.kind {
        case .vaultDeposit: return ("arrow.down.to.line", "#3B3BF5")
        case .vaultWithdrawal: return ("arrow.up.to.line", "#3B3BF5")
        default:
            return (transaction.category?.iconName ?? "questionmark", transaction.category?.colorHex)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if showsDate { parts.append(DateFormat.rowDate(transaction.date)) }
        if transaction.kind.isTransfer {
            parts.append(transaction.kind.label)
        } else {
            if !transaction.note.isEmpty, !transaction.merchant.isEmpty { parts.append(transaction.merchant) }
            if let c = transaction.category, c.name != transaction.title { parts.append(c.name) }
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: icon.0, colorHex: icon.1, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.kind == .vaultDeposit && transaction.note.isEmpty ? "Para o cofre"
                         : transaction.kind == .vaultWithdrawal && transaction.note.isEmpty ? "Do cofre"
                         : transaction.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if transaction.method == .applePay && !transaction.kind.isTransfer { Badge("Apple Pay") }
                    if transaction.needsReview { Badge("Por rever", style: .warning) }
                }
                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundStyle(Theme.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            MoneyText(cents: transaction.amountCents, kind: transaction.kind)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
