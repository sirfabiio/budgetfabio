import SwiftUI
import SwiftData

enum SplitConstants {
    /// O utilizador da app; só a sua parte conta como despesa pessoal.
    static let me = "Eu"
}

struct SplitGroupsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SplitGroup.createdAt, order: .reverse) private var groups: [SplitGroup]
    @State private var creating = false

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView("Sem grupos", systemImage: "person.3",
                                       description: Text("Cria um grupo para um jantar, uma viagem ou a casa partilhada."))
            }
            ForEach(groups) { g in
                NavigationLink { SplitGroupDetailView(group: g) } label: {
                    VStack(alignment: .leading) {
                        Text(g.name)
                        Text(g.participants.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .onDelete { idx in
                for i in idx { delete(groups[i]) }
            }
        }
        .navigationTitle("Divisão de despesas")
        .toolbar {
            Button { creating = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Novo grupo")
        }
        .sheet(isPresented: $creating) { SplitGroupEditorView(group: nil) }
    }

    private func delete(_ g: SplitGroup) {
        let gid = g.id
        let expenses = (try? context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupID == gid }))) ?? []
        for e in expenses { context.delete(e) }
        // As despesas pessoais já registadas mantêm-se no histórico.
        context.delete(g)
        try? context.save()
    }
}

struct SplitGroupEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let group: SplitGroup?
    @State private var name = ""
    @State private var others: [String] = [""]
    @State private var loaded = false

    private var cleanedOthers: [String] {
        var seen: Set<String> = [SplitConstants.me]
        var result: [String] = []
        for o in others {
            let t = o.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty, !seen.contains(t) { seen.insert(t); result.append(t) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nome do grupo (ex.: Viagem Porto)", text: $name)
                Section("Participantes") {
                    Text(SplitConstants.me).foregroundStyle(.secondary)
                    ForEach(others.indices, id: \.self) { i in
                        TextField("Nome", text: $others[i])
                    }
                    Button { others.append("") } label: { Label("Adicionar pessoa", systemImage: "person.badge.plus") }
                }
            }
            .navigationTitle(group == nil ? "Novo grupo" : "Editar grupo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let participants = [SplitConstants.me] + cleanedOthers
                        if let group {
                            group.name = name
                            // Nunca remove participantes com movimentos; só acrescenta.
                            var merged = group.participants
                            for p in participants where !merged.contains(p) { merged.append(p) }
                            group.participants = merged
                        } else {
                            context.insert(SplitGroup(name: name, participants: participants))
                        }
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || cleanedOthers.isEmpty)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let group {
                    name = group.name
                    others = group.participants.filter { $0 != SplitConstants.me }
                }
            }
        }
    }
}

struct SplitGroupDetailView: View {
    @Environment(\.modelContext) private var context
    let group: SplitGroup
    @Query private var expenses: [SplitExpense]
    @State private var adding = false
    @State private var editingGroup = false
    @State private var settling: Settlement?

    init(group: SplitGroup) {
        self.group = group
        let gid = group.id
        _expenses = Query(filter: #Predicate<SplitExpense> { $0.groupID == gid }, sort: \SplitExpense.date, order: .reverse)
    }

    var body: some View {
        let net = SplitCalculator.netBalances(expenses.map(\.record), participants: group.participants)
        let transfers = DebtSimplifier.simplify(net)
        let total = expenses.filter { !$0.isSettlement }.reduce(0) { $0 + $1.amountCents }

        List {
            Section {
                LabeledContent("Total do grupo", value: MoneyFormat.string(total))
                LabeledContent("A minha parte", value: MoneyFormat.string(expenses.filter { !$0.isSettlement }.reduce(0) { $0 + ($1.shares[SplitConstants.me] ?? 0) }))
            }
            Section("Saldo por pessoa") {
                ForEach(group.participants, id: \.self) { p in
                    let v = net[p] ?? 0
                    HStack {
                        Text(p)
                        Spacer()
                        Text(v == 0 ? "Saldado" : (v > 0 ? "Recebe \(MoneyFormat.string(v))" : "Deve \(MoneyFormat.string(-v))"))
                            .foregroundStyle(v == 0 ? Color.secondary : (v > 0 ? Color.green : Color.red))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Section {
                if transfers.isEmpty {
                    Label("Está tudo saldado.", systemImage: "checkmark.circle").foregroundStyle(.green)
                }
                ForEach(transfers, id: \.self) { t in
                    Button { settling = t } label: {
                        HStack {
                            Text("\(t.from) → \(t.to)")
                            Spacer()
                            Text(MoneyFormat.string(t.amountCents)).monospacedDigit()
                        }
                    }
                    .accessibilityHint("Registar este pagamento")
                }
            } header: {
                Text("Transferências para saldar")
            } footer: {
                Text("Número mínimo de transferências. Toca numa para a registar como paga.")
            }
            Section("Despesas") {
                ForEach(expenses) { e in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(e.isSettlement ? "Pagamento: \(e.payer) → \(e.shares.keys.sorted().joined(separator: ", "))" : e.title)
                            Text("\(e.isSettlement ? "" : "Pago por \(e.payer) · ")\(DateFormat.short(e.date))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(MoneyFormat.string(e.amountCents)).monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
                .onDelete { idx in
                    for i in idx { deleteExpense(expenses[i]) }
                }
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nova despesa partilhada")
            }
            ToolbarItem(placement: .secondaryAction) {
                Button("Editar grupo") { editingGroup = true }
            }
        }
        .sheet(isPresented: $adding) { SplitExpenseEditorView(group: group) }
        .sheet(isPresented: $editingGroup) { SplitGroupEditorView(group: group) }
        .confirmationDialog("Registar pagamento?", isPresented: Binding(get: { settling != nil }, set: { if !$0 { settling = nil } }),
                            titleVisibility: .visible, presenting: settling) { t in
            Button("\(t.from) pagou \(MoneyFormat.string(t.amountCents)) a \(t.to)") {
                context.insert(SplitExpense(groupID: group.id, title: "Pagamento", amountCents: t.amountCents, payer: t.from,
                                            isEqualSplit: false, shares: [t.to: t.amountCents], isSettlement: true))
                try? context.save()
            }
        }
    }

    private func deleteExpense(_ e: SplitExpense) {
        let eid: UUID? = e.id
        let linked = (try? context.fetch(FetchDescriptor<FinTransaction>(predicate: #Predicate { $0.splitExpenseID == eid }))) ?? []
        for t in linked { context.delete(t) }
        context.delete(e)
        try? context.save()
    }
}

struct SplitExpenseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    let group: SplitGroup
    @State private var title = ""
    @State private var amount: Cents? = nil
    @State private var payer = SplitConstants.me
    @State private var date = Date.now
    @State private var equal = true
    @State private var custom: [String: Cents?] = [:]
    @State private var categoryID: UUID? = nil
    @State private var method: PaymentMethod = .applePay

    private var shares: [String: Cents] {
        if equal { return SplitCalculator.equalShares(total: amount ?? 0, participants: group.participants) }
        var r: [String: Cents] = [:]
        for p in group.participants { r[p] = (custom[p] ?? nil) ?? 0 }
        return r
    }

    private var customSum: Cents { shares.values.reduce(0, +) }
    private var valid: Bool {
        guard let amount, amount > 0, !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return customSum == amount
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Descrição (ex.: Jantar)", text: $title)
                    AmountField(title: "Valor total", cents: $amount)
                    Picker("Pago por", selection: $payer) {
                        ForEach(group.participants, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("Data", selection: $date, displayedComponents: .date)
                }
                Section {
                    Toggle("Dividir em partes iguais", isOn: $equal)
                    if equal {
                        ForEach(group.participants, id: \.self) { p in
                            LabeledContent(p, value: MoneyFormat.string(shares[p] ?? 0))
                        }
                    } else {
                        ForEach(group.participants, id: \.self) { p in
                            AmountField(title: p, cents: Binding(get: { custom[p] ?? nil }, set: { custom[p] = $0 }))
                        }
                        if let amount, customSum != amount {
                            Label("A soma das partes (\(MoneyFormat.string(customSum))) tem de ser igual ao total (\(MoneyFormat.string(amount))).",
                                  systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red).font(.footnote)
                        }
                    }
                } header: {
                    Text("Divisão")
                }
                Section {
                    Picker("Categoria", selection: $categoryID) {
                        Text("Sem categoria").tag(UUID?.none)
                        ForEach(categories.filter { $0.kind == .expense && !$0.isArchived }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    if payer == SplitConstants.me {
                        Picker("Método", selection: $method) {
                            ForEach(PaymentMethod.allCases) { Text($0.label).tag($0) }
                        }
                    }
                } header: {
                    Text("A minha parte")
                } footer: {
                    Text("Só a tua parte (\(MoneyFormat.string(shares[SplitConstants.me] ?? 0))) é registada como despesa pessoal.")
                }
            }
            .navigationTitle("Despesa partilhada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar", action: save).disabled(!valid) }
            }
        }
    }

    private func save() {
        guard valid, let amount else { return }
        let s = shares
        let expense = SplitExpense(groupID: group.id, title: title.trimmingCharacters(in: .whitespaces), amountCents: amount,
                                   payer: payer, date: date, isEqualSplit: equal, shares: s)
        context.insert(expense)
        if let mine = s[SplitConstants.me], mine > 0 {
            context.insert(FinTransaction(amountCents: mine, kind: .expense, date: date,
                                          category: categories.first { $0.id == categoryID },
                                          method: payer == SplitConstants.me ? method : .other,
                                          note: "\(group.name): \(expense.title)", splitExpenseID: expense.id))
        }
        try? context.save()
        dismiss()
    }
}
