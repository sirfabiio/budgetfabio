import SwiftUI
import SwiftData

/// Secção de objetivos usada no ecrã do Cofre e no ecrã dedicado.
struct GoalsSection: View {
    let goals: [Goal]
    let vault: Cents
    @State private var editing: Goal?
    @State private var creating = false
    @State private var allocating: Goal?

    var body: some View {
        Section {
            if goals.isEmpty {
                Text("Cria objetivos (ex.: peças para a KTM, viagem) e afeta-lhes parte do cofre.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(goals) { g in
                GoalRow(goal: g)
                    .contentShape(Rectangle())
                    .onTapGesture { allocating = g }
                    .swipeActions {
                        Button { editing = g } label: { Label("Editar", systemImage: "pencil") }
                    }
                    .accessibilityAction(named: "Editar") { editing = g }
                    .accessibilityAddTraits(.isButton)
            }
            // As folhas ficam numa única linha para não serem replicadas por cada linha da secção.
            Button { creating = true } label: { Label("Novo objetivo", systemImage: "plus") }
                .sheet(item: $editing) { GoalEditorView(goal: $0) }
                .sheet(isPresented: $creating) { GoalEditorView(goal: nil) }
                .sheet(item: $allocating) { g in
                    GoalAllocationView(goal: g, vault: vault, allocations: goals.map(\.allocatedCents))
                }
        } header: {
            Text("Objetivos")
        }
    }
}

struct GoalsView: View {
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0

    var body: some View {
        let vault = BalanceCalculator.balances(transactions.map(\.snapshot), opening: openingBalance).vault
        List {
            Section {
                LabeledContent("Saldo do cofre", value: MoneyFormat.string(vault))
                LabeledContent("Livre", value: MoneyFormat.string(VaultCalculator.free(vault: vault, allocations: goals.map(\.allocatedCents))))
            }
            GoalsSection(goals: goals, vault: vault)
        }
        .navigationTitle("Objetivos")
    }
}

struct GoalRow: View {
    let goal: Goal

    var body: some View {
        let fraction = goal.targetCents > 0 ? min(1, Double(goal.allocatedCents) / Double(goal.targetCents)) : 0
        let percent = goal.targetCents > 0 ? goal.allocatedCents * 100 / goal.targetCents : 0
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                CategoryIcon(iconName: goal.iconName, colorHex: goal.colorHex, size: 28)
                Text(goal.name).font(.headline)
                Spacer()
                Text("\(percent)%").monospacedDigit().foregroundStyle(.secondary)
            }
            ProgressView(value: fraction).tint(Color(hex: goal.colorHex))
            HStack {
                Text("\(MoneyFormat.string(goal.allocatedCents)) de \(MoneyFormat.string(goal.targetCents))")
                Spacer()
                if let d = goal.deadline { Text("até \(DateFormat.short(d))") }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Objetivo \(goal.name): \(MoneyFormat.string(goal.allocatedCents)) de \(MoneyFormat.string(goal.targetCents)), \(percent) por cento.")
    }
}

private struct GoalAllocationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    let vault: Cents
    let allocations: [Cents]
    @State private var adding = true
    @State private var amount: Cents? = nil

    private var error: VaultError? {
        guard let amount else { return nil }
        return VaultCalculator.validateAllocation(delta: adding ? amount : -amount, goalAllocated: goal.allocatedCents,
                                                  vault: vault, allocations: allocations)
    }

    var body: some View {
        NavigationStack {
            Form {
                GoalRow(goal: goal)
                Picker("Operação", selection: $adding) {
                    Text("Afetar").tag(true)
                    Text("Libertar").tag(false)
                }
                .pickerStyle(.segmented)
                AmountField(title: "Valor", cents: $amount)
                LabeledContent("Livre no cofre", value: MoneyFormat.string(VaultCalculator.free(vault: vault, allocations: allocations)))
                if let error {
                    Label(error.message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
            .navigationTitle(goal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmar") {
                        guard let amount else { return }
                        goal.allocatedCents += adding ? amount : -amount
                        try? context.save()
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0 || error != nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct GoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let goal: Goal?
    @State private var name = ""
    @State private var target: Cents? = nil
    @State private var hasDeadline = false
    @State private var deadline = Date.now
    @State private var colorHex = Palette.colors[7]
    @State private var iconName = "star.fill"
    @State private var confirmDelete = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        CategoryIcon(iconName: iconName, colorHex: colorHex, size: 36)
                        TextField("Nome do objetivo", text: $name)
                    }
                    AmountField(title: "Valor alvo", cents: $target)
                    Toggle("Data limite", isOn: $hasDeadline)
                    if hasDeadline { DatePicker("Até", selection: $deadline, displayedComponents: .date) }
                }
                Section("Aspeto") {
                    Picker("Cor", selection: $colorHex) {
                        ForEach(Palette.colors, id: \.self) { hex in
                            Label(hex, systemImage: "circle.fill").tint(Color(hex: hex)).foregroundStyle(Color(hex: hex)).tag(hex)
                        }
                    }
                    Picker("Ícone", selection: $iconName) {
                        ForEach(Palette.icons, id: \.self) { Label($0, systemImage: $0).tag($0) }
                    }
                }
                if goal != nil {
                    Section {
                        Button("Eliminar objetivo", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("O valor afeto volta a ficar livre no cofre.")
                    }
                }
            }
            .navigationTitle(goal == nil ? "Novo objetivo" : "Editar objetivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (target ?? 0) <= 0)
                }
            }
            .confirmationDialog("Eliminar este objetivo?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    if let goal { context.delete(goal) }
                    try? context.save()
                    dismiss()
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let g = goal {
                    name = g.name; target = g.targetCents; hasDeadline = g.deadline != nil
                    deadline = g.deadline ?? .now; colorHex = g.colorHex; iconName = g.iconName
                }
            }
        }
    }

    private func save() {
        guard let target else { return }
        let g = goal ?? Goal(name: name, targetCents: target)
        if goal == nil { context.insert(g) }
        g.name = name.trimmingCharacters(in: .whitespaces)
        g.targetCents = target
        g.deadline = hasDeadline ? deadline : nil
        g.colorHex = colorHex
        g.iconName = iconName
        try? context.save()
        dismiss()
    }
}
