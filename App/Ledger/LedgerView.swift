import SwiftUI
import SwiftData

struct LedgerView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.modelContext) private var context
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @State private var filter = LedgerFilter()
    @State private var showingFilters = false
    @State private var editing: FinTransaction?
    @State private var monthChip: Date? = nil

    var body: some View {
        let filtered = transactions.filter { filter.matches($0.snapshot) }
        let groups = LedgerFilter.groupByDay(filtered) { $0.date }
        let total = LedgerFilter.signedTotal(filtered.map(\.snapshot))

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14, pinnedViews: []) {
                ScreenHeader(eyebrow: "Visão geral", title: "Histórico") {
                    HStack(spacing: 10) {
                        CircleIconButton(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "slider.horizontal.3",
                                         label: filter.isActive ? "Filtros (ativos)" : "Filtros") { showingFilters = true }
                        CircleIconButton(systemName: "plus", label: "Nova transação") { router.showNewTransaction = true }
                    }
                }

                searchField
                chips

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("Total no filtro")
                        Text("\(total >= 0 ? "+" : "−")\(MoneyFormat.string(abs(total)))")
                            .font(.title2.weight(.bold).monospacedDigit())
                            .foregroundStyle(total >= 0 ? Theme.positive : Theme.textPrimary)
                    }
                    Spacer()
                    Badge("\(filtered.count) transaç\(filtered.count == 1 ? "ão" : "ões")")
                }
                .card()
                .accessibilityElement(children: .combine)

                if groups.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray").font(.largeTitle).foregroundStyle(Theme.textSecondary)
                        Text(transactions.isEmpty ? "Ainda sem transações" : "Sem resultados").font(.headline)
                        Text(transactions.isEmpty ? "Toca em + para registar a primeira." : "Ajusta a pesquisa ou os filtros.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }

                ForEach(groups) { group in
                    let dayTotal = LedgerFilter.signedTotal(group.items.map(\.snapshot))
                    HStack {
                        Eyebrow(DateFormat.dayHeader(group.day))
                        Spacer()
                        Text("\(dayTotal >= 0 ? "+" : "−")\(MoneyFormat.string(abs(dayTotal)))")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .padding(.top, 10)
                    .padding(.horizontal, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)

                    RowsCard {
                        ForEach(group.items) { t in
                            Button { editing = t } label: { TransactionRow(transaction: t, showsDate: false) }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { editing = t } label: { Label("Editar", systemImage: "pencil") }
                                    Button(role: .destructive) { delete(t) } label: { Label("Eliminar", systemImage: "trash") }
                                }
                                .accessibilityAction(named: "Eliminar") { delete(t) }
                            if t.id != group.items.last?.id { RowDivider() }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editing) { TransactionEditorView(transaction: $0) }
        .sheet(isPresented: $showingFilters) {
            LedgerFilterView(filter: $filter, categories: categories)
        }
        .onChange(of: filter) { _, f in
            // O chip de mês só fica ativo se as datas coincidirem com um mês inteiro.
            if let m = monthChip, f.startDate != m { monthChip = nil }
        }
    }

    private func delete(_ t: FinTransaction) {
        context.delete(t)
        try? context.save()
        VaultIntegrity.enforce(context)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary).accessibilityHidden(true)
            TextField("Pesquisar comerciantes, categorias…", text: $filter.searchText)
                .submitLabel(.search)
            if !filter.searchText.isEmpty {
                Button { filter.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Limpar pesquisa")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .background(Theme.tile, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var chips: some View {
        let cal = PT.calendar
        let current = BalanceCalculator.monthInterval(containing: .now).start
        let categoryName = categories.first { $0.id == filter.categoryID }?.name
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    Button("Todos os meses") { setMonth(nil) }
                    ForEach(0..<24, id: \.self) { i in
                        let m = cal.date(byAdding: .month, value: -i, to: current) ?? current
                        Button(DateFormat.month(m)) { setMonth(m) }
                    }
                } label: {
                    ChipLabel(title: monthChip.map { DateFormat.month($0) } ?? "Todos os meses", selected: monthChip != nil, showsChevron: true)
                }
                Menu {
                    Button("Todas as categorias") { filter.categoryID = nil }
                    ForEach(categories) { c in Button(c.name) { filter.categoryID = c.id } }
                } label: {
                    ChipLabel(title: categoryName ?? "Todas as categorias", selected: filter.categoryID != nil, showsChevron: true)
                }
                Menu {
                    Button("Todos") { filter.method = nil }
                    ForEach(PaymentMethod.allCases) { m in Button(m.label) { filter.method = m } }
                } label: {
                    ChipLabel(title: "Método: \(filter.method?.label ?? "Todos")", selected: filter.method != nil, showsChevron: true)
                }
                Menu {
                    Button("Todos") { filter.kind = nil }
                    ForEach(TransactionKind.allCases) { k in Button(k.label) { filter.kind = k } }
                } label: {
                    ChipLabel(title: "Tipo: \(filter.kind?.label ?? "Todos")", selected: filter.kind != nil, showsChevron: true)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func setMonth(_ m: Date?) {
        monthChip = m
        guard let m else {
            filter.startDate = nil
            filter.endDate = nil
            return
        }
        let interval = BalanceCalculator.monthInterval(containing: m)
        filter.startDate = interval.start
        filter.endDate = PT.calendar.date(byAdding: .day, value: -1, to: interval.end)
    }
}

private struct LedgerFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: LedgerFilter
    var categories: [FinCategory]

    @State private var useStart = false
    @State private var useEnd = false
    @State private var start = Date.now
    @State private var end = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Datas") {
                    Toggle("Desde", isOn: $useStart)
                    if useStart { DatePicker("Início", selection: $start, displayedComponents: .date) }
                    Toggle("Até", isOn: $useEnd)
                    if useEnd { DatePicker("Fim", selection: $end, displayedComponents: .date) }
                }
                Section("Tipo e categoria") {
                    Picker("Tipo", selection: $filter.kind) {
                        Text("Todos").tag(TransactionKind?.none)
                        ForEach(TransactionKind.allCases) { Text($0.label).tag(Optional($0)) }
                    }
                    Picker("Categoria", selection: $filter.categoryID) {
                        Text("Todas").tag(UUID?.none)
                        ForEach(categories) { c in Text(c.name).tag(Optional(c.id)) }
                    }
                    Picker("Método", selection: $filter.method) {
                        Text("Todos").tag(PaymentMethod?.none)
                        ForEach(PaymentMethod.allCases) { Text($0.label).tag(Optional($0)) }
                    }
                }
                Section("Intervalo de valor") {
                    AmountField(title: "Mínimo", cents: $filter.minCents)
                    AmountField(title: "Máximo", cents: $filter.maxCents)
                }
                Section {
                    Button("Limpar filtros", role: .destructive) {
                        let text = filter.searchText
                        filter = LedgerFilter(searchText: text)
                        useStart = false
                        useEnd = false
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") {
                        filter.startDate = useStart ? start : nil
                        filter.endDate = useEnd ? end : nil
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let s = filter.startDate { useStart = true; start = s }
                if let e = filter.endDate { useEnd = true; end = e }
            }
        }
    }
}
