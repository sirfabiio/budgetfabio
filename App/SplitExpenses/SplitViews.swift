import SwiftUI
import SwiftData

enum SplitConstants {
    /// O utilizador da app; só a sua parte conta como despesa pessoal.
    static let me = "Eu"
}

struct SplitGroupsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SplitGroup.createdAt, order: .reverse) private var groups: [SplitGroup]
    @Query private var expenses: [SplitExpense]
    @State private var creating = false
    @State private var deleting: SplitGroup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Divisão de despesas", title: "Grupos") {
                    Button { creating = true } label: { Label("Novo", systemImage: "plus") }
                        .buttonStyle(PillButtonStyle(filled: true))
                }
                if groups.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.3").font(.largeTitle).foregroundStyle(Theme.textSecondary)
                        Text("Sem grupos").font(.headline)
                        Text("Cria um grupo para um jantar, uma viagem ou a casa partilhada.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .card()
                }
                ForEach(groups) { g in
                    let records = expenses.filter { $0.groupID == g.id }.map(\.record)
                    let net = SplitCalculator.netBalances(records, participants: g.participants)
                    let mine = net[SplitConstants.me] ?? 0
                    NavigationLink { SplitGroupDetailView(group: g) } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(g.name).font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
                            }
                            HStack {
                                AvatarStack(names: g.participants)
                                Spacer()
                                Text(mine == 0 ? "Saldado" : (mine > 0 ? "Recebes \(MoneyFormat.string(mine))" : "Deves \(MoneyFormat.string(-mine))"))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(mine == 0 ? Theme.textSecondary : (mine > 0 ? Theme.primary : Theme.danger))
                            }
                        }
                        .card()
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) { deleting = g } label: { Label("Eliminar grupo", systemImage: "trash") }
                    }
                    .accessibilityAction(named: "Eliminar grupo") { deleting = g }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $creating) { SplitGroupEditorView(group: nil) }
        .confirmationDialog("Eliminar este grupo?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { g in
            Button("Eliminar \(g.name)", role: .destructive) { delete(g) }
        } message: { _ in
            Text("As despesas pessoais já registadas mantêm-se no histórico.")
        }
    }

    private func delete(_ g: SplitGroup) {
        let gid = g.id
        let expenses = (try? context.fetch(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupID == gid }))) ?? []
        for e in expenses { context.delete(e) }
        context.delete(g)
        try? context.save()
    }
}

struct AvatarStack: View {
    var names: [String]
    var size: CGFloat = 36

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(names.prefix(5).enumerated()), id: \.offset) { _, n in
                InitialsAvatar(name: n, highlighted: n == SplitConstants.me, size: size)
            }
            if names.count > 5 {
                Text("+\(names.count - 5)").font(.caption.weight(.semibold))
                    .frame(width: size, height: size).background(Theme.tile, in: Circle())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Participantes: \(names.joined(separator: ", "))")
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
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
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
        let owedToMe = transfers.filter { $0.to == SplitConstants.me }
        let iOwe = transfers.filter { $0.from == SplitConstants.me }
        let mine = net[SplitConstants.me] ?? 0
        let maxAbs = max(1, net.values.map { abs($0) }.max() ?? 1)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name).font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)
                        Text("\(group.participants.count) participantes · Criado a \(DateFormat.rowDate(group.createdAt))")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Badge(transfers.isEmpty ? "Saldado" : "Ativo", style: transfers.isEmpty ? .positive : .neutral)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        AvatarStack(names: group.participants)
                        Spacer()
                        Text("\(group.participants.count) pessoas no cálculo").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    Rectangle().fill(Theme.outline).frame(height: 1)
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("Devem-te")
                            Text("+ \(MoneyFormat.string(owedToMe.reduce(0) { $0 + $1.amountCents }))")
                                .font(.title2.weight(.bold).monospacedDigit())
                            Label("\(owedToMe.count) pessoa\(owedToMe.count == 1 ? "" : "s")", systemImage: "circle.fill")
                                .font(.caption).foregroundStyle(Theme.textSecondary).labelStyle(DotLabelStyle(color: Theme.primary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Rectangle().fill(Theme.outline).frame(width: 1, height: 70)
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("Deves")
                            Text("− \(MoneyFormat.string(iOwe.reduce(0) { $0 + $1.amountCents }))")
                                .font(.title2.weight(.bold).monospacedDigit())
                            Label("\(iOwe.count) transferência\(iOwe.count == 1 ? "" : "s")", systemImage: "circle.fill")
                                .font(.caption).foregroundStyle(Theme.textSecondary).labelStyle(DotLabelStyle(color: Theme.textSecondary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                    }
                    Rectangle().fill(Theme.outline).frame(height: 1)
                    HStack {
                        Text("Teu balanço líquido:").foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(mine >= 0 ? "+" : "−") \(MoneyFormat.string(abs(mine)))")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(mine >= 0 ? Theme.primary : Theme.danger)
                    }
                }
                .card(padding: 24)
                .accessibilityElement(children: .combine)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Balanço do Grupo").font(.headline)
                        Spacer()
                        Text("TOTAL: \(MoneyFormat.string(total))").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    }
                    ForEach(group.participants, id: \.self) { p in
                        let v = net[p] ?? 0
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                InitialsAvatar(name: p, highlighted: p == SplitConstants.me, size: 32)
                                Text(p == SplitConstants.me ? "Eu (tu)" : p)
                                Spacer()
                                Text("\(v > 0 ? "+ " : v < 0 ? "− " : "")\(MoneyFormat.string(abs(v)))")
                                    .font(.body.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(v < 0 ? Theme.textSecondary : Theme.textPrimary)
                            }
                            ThinProgress(fraction: Double(abs(v)) / Double(maxAbs), color: v > 0 ? Theme.primary : Theme.textSecondary.opacity(0.5), height: 8)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(p): \(v == 0 ? "saldado" : (v > 0 ? "recebe \(MoneyFormat.string(v))" : "deve \(MoneyFormat.string(-v))"))")
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Transferências para saldar").font(.headline)
                    Text("Número mínimo de transferências. Toca em “Marcar pago” quando o pagamento for feito.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                    if transfers.isEmpty {
                        Label("Está tudo saldado.", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.positive)
                    }
                    ForEach(transfers, id: \.self) { t in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(t.from) → \(t.to)").font(.subheadline.weight(.semibold))
                                Text(MoneyFormat.string(t.amountCents)).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Button { settling = t } label: { Label("Marcar pago", systemImage: "checkmark") }
                                .buttonStyle(PillButtonStyle())
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .card()

                SectionTitle("Despesas")
                if expenses.isEmpty {
                    Text("Ainda sem despesas neste grupo.").font(.subheadline).foregroundStyle(Theme.textSecondary).card()
                } else {
                    RowsCard {
                        ForEach(expenses) { e in
                            HStack(spacing: 12) {
                                IconTile(systemName: e.isSettlement ? "checkmark.circle" : "receipt", size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.isSettlement ? "Pagamento: \(e.payer) → \(e.shares.keys.sorted().joined(separator: ", "))" : e.title)
                                        .font(.body.weight(.semibold)).lineLimit(1)
                                    Text("\(e.isSettlement ? "" : "Pago por \(e.payer) · ")\(DateFormat.rowDate(e.date))")
                                        .font(.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Text(MoneyFormat.string(e.amountCents)).font(.body.weight(.semibold).monospacedDigit())
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12)
                            .contextMenu {
                                Button(role: .destructive) { deleteExpense(e) } label: { Label("Eliminar", systemImage: "trash") }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityAction(named: "Eliminar") { deleteExpense(e) }
                            if e.id != expenses.last?.id { RowDivider(inset: 68) }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 100)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            Button { adding = true } label: { Label("Nova despesa de grupo", systemImage: "plus") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editingGroup = true } label: { Image(systemName: "person.badge.plus") }
                    .accessibilityLabel("Editar grupo e participantes")
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

/// Rótulo com um ponto colorido em vez de ícone.
struct DotLabelStyle: LabelStyle {
    var color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            configuration.title
        }
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
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
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
