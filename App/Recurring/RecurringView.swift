import SwiftUI
import SwiftData

struct RecurringView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecurringRule.name) private var rules: [RecurringRule]
    @AppStorage(SettingsKeys.notificationsEnabled) private var notificationsEnabled = true
    @State private var editing: RecurringRule?
    @State private var creating = false

    var body: some View {
        List {
            Section {
                Toggle("Notificações de lembrete", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, on in
                        Task {
                            if on { _ = await RecurringService.requestAuthorization() }
                            RecurringService.rescheduleNotifications(context, enabled: on)
                        }
                    }
            } footer: {
                Text("O iOS não garante execução em segundo plano: as ocorrências em atraso são criadas sempre que abres a app.")
            }
            if rules.isEmpty {
                ContentUnavailableView("Sem recorrentes", systemImage: "repeat",
                                       description: Text("Cria regras para renda, subscrições, salário…"))
            }
            ForEach(rules) { rule in
                Button { editing = rule } label: { row(rule) }
                    .buttonStyle(.plain)
            }
            .onDelete { idx in
                for i in idx { context.delete(rules[i]) }
                try? context.save()
                RecurringService.rescheduleNotifications(context, enabled: notificationsEnabled)
            }
        }
        .navigationTitle("Recorrentes")
        .toolbar {
            Button { creating = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Nova regra recorrente")
        }
        .sheet(item: $editing) { RecurringEditorView(rule: $0) }
        .sheet(isPresented: $creating) { RecurringEditorView(rule: nil) }
    }

    private func row(_ rule: RecurringRule) -> some View {
        HStack {
            CategoryIcon(iconName: rule.category?.iconName ?? "repeat", colorHex: rule.category?.colorHex ?? "#30B0C7")
            VStack(alignment: .leading) {
                Text(rule.name).foregroundStyle(rule.isActive ? .primary : .secondary)
                Group {
                    if let next = RecurrenceEngine.nextOccurrence(rule.schedule, after: max(.now, rule.lastGeneratedDate ?? .distantPast)), rule.isActive {
                        Text("\(everyText(rule)) · próxima: \(DateFormat.short(next))")
                    } else {
                        Text(rule.isActive ? "\(everyText(rule)) · terminada" : "Pausada")
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            MoneyText(cents: rule.amountCents, kind: rule.kind)
        }
        .accessibilityElement(children: .combine)
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
        }
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
