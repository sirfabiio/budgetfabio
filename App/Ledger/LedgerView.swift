import SwiftUI
import SwiftData

struct LedgerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @State private var filter = LedgerFilter()
    @State private var showingFilters = false
    @State private var editing: FinTransaction?
    @State private var creating = false

    var body: some View {
        let filtered = transactions.filter { filter.matches($0.snapshot) }
        let groups = LedgerFilter.groupByDay(filtered) { $0.date }
        let total = LedgerFilter.signedTotal(filtered.map(\.snapshot))

        List {
            Section {
                HStack {
                    Text("\(filtered.count) transaç\(filtered.count == 1 ? "ão" : "ões")")
                    Spacer()
                    Text("Total: \(total >= 0 ? "+" : "−")\(MoneyFormat.string(abs(total)))")
                        .monospacedDigit()
                        .foregroundStyle(total >= 0 ? .green : .red)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
            }
            if groups.isEmpty {
                ContentUnavailableView(transactions.isEmpty ? "Ainda sem transações" : "Sem resultados",
                                       systemImage: "tray",
                                       description: Text(transactions.isEmpty ? "Toca em + para registar a primeira." : "Ajusta a pesquisa ou os filtros."))
            }
            ForEach(groups) { group in
                Section {
                    ForEach(group.items) { t in
                        Button { editing = t } label: { TransactionRow(transaction: t) }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    context.delete(t)
                                    try? context.save()
                                    VaultIntegrity.enforce(context)
                                } label: { Label("Eliminar", systemImage: "trash") }
                            }
                    }
                } header: {
                    HStack {
                        Text(DateFormat.day(group.day))
                        Spacer()
                        let dayTotal = LedgerFilter.signedTotal(group.items.map(\.snapshot))
                        Text("\(dayTotal >= 0 ? "+" : "−")\(MoneyFormat.string(abs(dayTotal)))").monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle("Histórico")
        .searchable(text: $filter.searchText, prompt: "Pesquisar descrição, comerciante…")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showingFilters = true } label: {
                    Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel(filter.isActive ? "Filtros (ativos)" : "Filtros")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { creating = true } label: { Image(systemName: "plus.circle.fill") }
                    .accessibilityLabel("Nova transação")
            }
        }
        .sheet(item: $editing) { t in TransactionEditorView(transaction: t) }
        .sheet(isPresented: $creating) { TransactionEditorView(transaction: nil) }
        .sheet(isPresented: $showingFilters) {
            LedgerFilterView(filter: $filter, categories: categories)
        }
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
