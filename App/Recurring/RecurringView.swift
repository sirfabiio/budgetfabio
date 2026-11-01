import SwiftUI
import SwiftData

struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringRule.name) private var rules: [RecurringRule]
    @AppStorage(SettingsKeys.notificationsEnabled) private var notificationsEnabled = true
    @State private var editing: RecurringRule?
    @State private var creating = false
    @State private var categoryFilter: UUID? = nil

    var body: some View {
        let active = rules.filter { $0.isActive && $0.kind == .expense }
        let monthly = active.reduce(0) { $0 + RecurrenceEngine.monthlyEquivalent(amount: $1.amountCents, frequency: $1.frequency, interval: $1.interval) }
        let nexts = active.compactMap { nextDate($0) }.sorted()
        let filterCategories = uniqueCategories()
        let shown = rules.filter { categoryFilter == nil || $0.category?.id == categoryFilter }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Gestão periódica", title: "Recorrentes") {
                    Button { creating = true } label: { Label("Nova", systemImage: "plus") }
                        .buttonStyle(PillButtonStyle(filled: true))
                }

                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow("Total mensal previsto")
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                HeroAmount(cents: monthly)
                                Text("/ mês").font(.subheadline).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        IconTile(systemName: "calendar", colorHex: "#3B3BF5", size: 48)
                    }
                    Rectangle().fill(Theme.outline).frame(height: 1)
                    HStack {
                        Circle().fill(Theme.primary).frame(width: 8, height: 8)
                        Text("\(active.count) despes\(active.count == 1 ? "a ativa" : "as ativas")").font(.subheadline)
                        Spacer()
                        if let first = nexts.first {
                            Text("Próxima: ").font(.subheadline).foregroundColor(Theme.textSecondary)
                                + Text(DateFormat.rowDate(first)).font(.subheadline.weight(.semibold))
                        }
                    }
                }
                .card(padding: 24)
                .accessibilityElement(children: .combine)

                if !filterCategories.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button { categoryFilter = nil } label: {
                                ChipLabel(title: "Todas (\(rules.count))", selected: categoryFilter == nil)
                            }
                            ForEach(filterCategories) { c in
                                Button { categoryFilter = c.id } label: {
                                    ChipLabel(title: c.name, selected: categoryFilter == c.id)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if rules.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "repeat").font(.largeTitle).foregroundStyle(Theme.textSecondary)
                        Text("Sem recorrentes").font(.headline)
                        Text("Cria regras para renda, subscrições, ginásio, salário…")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .card()
                } else {
                    RowsCard {
                        ForEach(shown) { rule in
                            row(rule)
                            if rule.id != shown.last?.id { RowDivider() }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles").foregroundStyle(Theme.primary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $notificationsEnabled) {
                            Text("Lembretes no dia do pagamento").font(.subheadline.weight(.semibold))
                        }
                        Text("Notificação local às 9:00 no dia de cada ocorrência. O iOS não garante execução em segundo plano: as ocorrências em atraso são criadas sempre que abres a app.")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .card(padding: 16)
                .onChange(of: notificationsEnabled) { _, on in
                    Task {
                        if on { _ = await RecurringService.requestAuthorization() }
                        RecurringService.rescheduleNotifications(context, enabled: on)
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { RecurringEditorView(rule: $0) }
        .sheet(isPresented: $creating) { RecurringEditorView(rule: nil) }
    }

    private func nextDate(_ rule: RecurringRule) -> Date? {
        RecurrenceEngine.nextOccurrence(rule.schedule, after: max(.now, rule.lastGeneratedDate ?? .distantPast))
    }

    private func uniqueCategories() -> [FinCategory] {
        var seen = Set<UUID>()
        var result: [FinCategory] = []
        for r in rules {
            if let c = r.category, !seen.contains(c.id) { seen.insert(c.id); result.append(c) }
        }
        return result
    }

    private func row(_ rule: RecurringRule) -> some View {
        HStack(spacing: 12) {
            Button { editing = rule } label: {
                HStack(spacing: 12) {
                    IconTile(systemName: rule.category?.iconName ?? "repeat", colorHex: rule.category?.colorHex, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(rule.name).font(.body.weight(.semibold)).lineLimit(1)
                            Badge(everyText(rule).uppercased(with: PT.locale))
                        }
                        Group {
                            if rule.isActive, let next = nextDate(rule) {
                                Text("Próximo: ") + Text(DateFormat.rowDate(next)).foregroundColor(Theme.textPrimary)
                            } else {
                                Text(rule.isActive ? "Terminada" : "Pausada")
                            }
                        }
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 4)
                    MoneyText(cents: rule.amountCents, kind: rule.kind)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Toggle("Ativa", isOn: Binding(get: { rule.isActive }, set: { on in
                rule.isActive = on
                if on, rule.lastGeneratedDate == nil || rule.lastGeneratedDate! < PT.calendar.startOfDay(for: .now) {
                    // Ao reativar, não gera retroativamente o período em pausa.
                    rule.lastGeneratedDate = PT.calendar.startOfDay(for: .now).addingTimeInterval(-1)
                }
                try? context.save()
                RecurringService.rescheduleNotifications(context, enabled: notificationsEnabled)
            }))
            .labelsHidden()
            .tint(Theme.primary)
            .accessibilityLabel("\(rule.name) ativa")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            Button(role: .destructive) {
                context.delete(rule)
                try? context.save()
                RecurringService.rescheduleNotifications(context, enabled: notificationsEnabled)
            } label: { Label("Eliminar", systemImage: "trash") }
        }
    }

    private func everyText(_ rule: RecurringRule) -> String {
        rule.interval == 1 ? rule.frequency.label : "A cada \(rule.interval) \(rule.frequency.unitLabel(rule.interval))"
    }
}

struct RecurringEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @AppStorage(SettingsKeys.notificationsEnabled) private var notificationsEnabled = true
    let rule: RecurringRule?

    @State private var name = ""
    @State private var amount: Cents? = nil
    @State private var kind: TransactionKind = .expense
    @State private var categoryID: UUID? = nil
    @State private var method: PaymentMethod = .directDebit
    @State private var frequency: RecurrenceFrequency = .monthly
    @State private var interval = 1
    @State private var start = Date.now
    @State private var hasEnd = false
    @State private var end = Date.now
    @State private var isActive = true
    @State private var notify = true
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome (ex.: Renda)", text: $name)
                    Picker("Tipo", selection: $kind) {
                        Text("Despesa").tag(TransactionKind.expense)
                        Text("Receita").tag(TransactionKind.income)
                    }
                    .pickerStyle(.segmented)
                    AmountField(title: "Valor", cents: $amount)
                    Picker("Categoria", selection: $categoryID) {
                        Text("Sem categoria").tag(UUID?.none)
                        ForEach(categories.filter { $0.kind == (kind == .income ? .income : .expense) && (!$0.isArchived || $0.id == categoryID) }) {
                            Text($0.name).tag(Optional($0.id))
                        }
                    }
                    Picker("Método", selection: $method) {
                        ForEach(PaymentMethod.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("Repetição") {
                    Picker("Frequência", selection: $frequency) {
                        ForEach(RecurrenceFrequency.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("A cada \(interval) \(frequency.unitLabel(interval))", value: $interval, in: 1...365)
                    DatePicker("Início", selection: $start, displayedComponents: .date)
                    Toggle("Data de fim", isOn: $hasEnd)
                    if hasEnd { DatePicker("Fim", selection: $end, in: start..., displayedComponents: .date) }
                }
                Section {
                    Toggle("Ativa", isOn: $isActive)
                    Toggle("Notificar no dia", isOn: $notify)
                }
                if let rule {
                    Section {
                        Button("Eliminar regra", role: .destructive) {
                            context.delete(rule)
                            try? context.save()
                            RecurringService.rescheduleNotifications(context, enabled: notificationsEnabled)
                            dismiss()
                        }
                    } footer: {
                        Text("As transações já criadas por esta regra mantêm-se no histórico.")
                    }
                }
            }
            .navigationTitle(rule == nil ? "Nova recorrente" : "Editar recorrente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (amount ?? 0) <= 0)
                }
            }
            .onAppear(perform: load)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
        }
        .tint(Theme.primary)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let r = rule else { return }
        name = r.name; amount = r.amountCents; kind = r.kind; categoryID = r.category?.id; method = r.method
        frequency = r.frequency; interval = r.interval; start = r.startDate
        hasEnd = r.endDate != nil; end = r.endDate ?? .now; isActive = r.isActive; notify = r.notify
    }

    private func save() {
        guard let amount, amount > 0 else { return }
        let cal = PT.calendar
        let startDay = cal.startOfDay(for: start)
        let category = categories.first { $0.id == categoryID }
        let target: RecurringRule
        if let rule {
            target = rule
            // Se o calendário mudar, recomeça a contagem a partir de hoje para não duplicar o passado.
            if rule.startDate != startDay || rule.frequency != frequency || rule.interval != interval {
                target.lastGeneratedDate = startDay < cal.startOfDay(for: .now) ? rule.lastGeneratedDate ?? nil : nil
            }
        } else {
            target = RecurringRule(name: name, amountCents: amount, startDate: startDay)
            context.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.amountCents = amount
        target.kind = kind
        target.category = category
        target.method = method
        target.frequency = frequency
        target.interval = interval
        target.startDate = startDay
        target.endDate = hasEnd ? cal.startOfDay(for: end) : nil
        target.isActive = isActive
        target.notify = notify
        try? context.save()
        RecurringService.catchUp(context)
        RecurringService.rescheduleNotifications(context, enabled: notificationsEnabled)
        dismiss()
    }
}
