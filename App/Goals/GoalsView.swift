import SwiftUI
import SwiftData

/// Lista de objetivos (usada no Cofre e no ecrã dedicado).
struct GoalsList: View {
    let goals: [Goal]
    let vault: Cents
    @State private var editing: Goal?
    @State private var creating = false
    @State private var allocating: Goal?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Objetivos de Poupança").font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                if !goals.isEmpty { Badge("\(goals.count)") }
                Spacer()
                Button { creating = true } label: { Label("Novo objetivo", systemImage: "plus") }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
            .padding(.top, 8)

            if goals.isEmpty {
                Text("Cria objetivos (ex.: peças para a KTM, viagem de verão) e afeta-lhes parte do cofre.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .card()
            }
            ForEach(goals) { g in
                Button { allocating = g } label: { GoalCard(goal: g) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { allocating = g } label: { Label("Afetar ou libertar", systemImage: "arrow.left.arrow.right") }
                        Button { editing = g } label: { Label("Editar", systemImage: "pencil") }
                    }
                    .accessibilityAction(named: "Editar") { editing = g }
                    .accessibilityHint("Afetar ou libertar dinheiro do cofre")
            }
        }
        .sheet(item: $editing) { GoalEditorView(goal: $0) }
        .sheet(isPresented: $creating) { GoalEditorView(goal: nil) }
        .sheet(item: $allocating) { g in
            GoalAllocationView(goal: g, vault: vault, allocations: goals.map(\.allocatedCents))
        }
    }
}

struct GoalsView: View {
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @Query(sort: \Goal.createdAt) private var goals: [Goal]
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0

    var body: some View {
        let vault = BalanceCalculator.balances(transactions.map(\.snapshot), opening: openingBalance).vault
        let free = VaultCalculator.free(vault: vault, allocations: goals.map(\.allocatedCents))
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Cofre", title: "Objetivos")
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("Saldo do cofre")
                        Text(MoneyFormat.string(vault)).font(.title3.weight(.bold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(Theme.outline).frame(width: 1, height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("Por alocar")
                        Text(MoneyFormat.string(free)).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(Theme.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                }
                .card()
                .accessibilityElement(children: .combine)
                GoalsList(goals: goals, vault: vault)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GoalCard: View {
    let goal: Goal

    var body: some View {
        let fraction = goal.targetCents > 0 ? min(1, Double(goal.allocatedCents) / Double(goal.targetCents)) : 0
        let percent = goal.targetCents > 0 ? goal.allocatedCents * 100 / goal.targetCents : 0
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                IconTile(systemName: goal.iconName, colorHex: goal.colorHex, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name).font(.headline).foregroundStyle(Theme.textPrimary)
                    if let d = goal.deadline {
                        Label("Até \(DateFormat.month(d))", systemImage: "calendar")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    } else {
                        Text("Sem prazo").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Badge("\(percent)%", style: percent >= 100 ? .positive : .primary)
            }
            ThinProgress(fraction: fraction, color: percent >= 100 ? Theme.positive : Theme.primary, height: 8)
            HStack {
                Text(MoneyFormat.string(goal.allocatedCents)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("de \(MoneyFormat.string(goal.targetCents))").foregroundStyle(Theme.textSecondary)
            }
            .font(.subheadline.monospacedDigit())
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Objetivo \(goal.name): \(MoneyFormat.string(goal.allocatedCents)) de \(MoneyFormat.string(goal.targetCents)), \(percent) por cento.")
    }
}

struct GoalAllocationView: View {
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SheetHeader(eyebrow: "Objetivo", title: goal.name) { dismiss() }
                GoalCard(goal: goal)
                Picker("Operação", selection: $adding) {
                    Text("Afetar").tag(true)
                    Text("Libertar").tag(false)
                }
                .pickerStyle(.segmented)
                StyledField(systemImage: "eurosign") { AmountField(title: "Valor", cents: $amount) }
                HStack {
                    Text("Livre no cofre").foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(MoneyFormat.string(VaultCalculator.free(vault: vault, allocations: allocations))).monospacedDigit()
                }
                .font(.subheadline)
                if let error {
                    Label(error.message, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.danger)
                }
                Button("Confirmar") {
                    guard let amount else { return }
                    goal.allocatedCents += adding ? amount : -amount
                    try? context.save()
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled((amount ?? 0) <= 0 || error != nil)
            }
            .padding(Theme.margin)
            .padding(.top, 8)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(eyebrow: "Objetivo", title: goal == nil ? "Novo objetivo" : "Editar objetivo") { dismiss() }
                IconColorPicker(iconName: $iconName, colorHex: $colorHex)
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Nome do objetivo")
                    StyledField(systemImage: "target") { TextField("Ex.: Peças para a KTM", text: $name) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Valor alvo")
                    StyledField(systemImage: "eurosign") { AmountField(title: "", cents: $target) }
                }
                StyledField(systemImage: "calendar") {
                    Toggle("Data limite", isOn: $hasDeadline)
                }
                if hasDeadline {
                    DatePicker("Até", selection: $deadline, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .card(padding: 8)
                }
                Button("Guardar", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (target ?? 0) <= 0)
                if goal != nil {
                    Button("Eliminar objetivo", role: .destructive) { confirmDelete = true }
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity)
                    Text("O valor afeto volta a ficar livre no cofre.").font(.caption).foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.margin)
            .padding(.top, 8)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
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

/// Escolha de ícone e cor (partilhada por categorias e objetivos).
struct IconColorPicker: View {
    @Binding var iconName: String
    @Binding var colorHex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                IconTile(systemName: iconName, colorHex: colorHex, size: 64)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.primary, lineWidth: 2))
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cor").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Palette.colors, id: \.self) { hex in
                                Button { colorHex = hex } label: {
                                    Circle().fill(Color(hex: hex))
                                        .frame(width: 30, height: 30)
                                        .overlay {
                                            if hex == colorHex {
                                                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                            }
                                        }
                                }
                                .accessibilityLabel("Cor \(hex)")
                                .accessibilityAddTraits(hex == colorHex ? .isSelected : [])
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            Text("Escolher ícone").font(.subheadline).foregroundStyle(Theme.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                ForEach(Palette.icons, id: \.self) { icon in
                    Button { iconName = icon } label: {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundStyle(icon == iconName ? Color(hex: colorHex) : Theme.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(icon == iconName ? Color(hex: colorHex).opacity(0.15) : Theme.card, in: Circle())
                            .overlay(Circle().stroke(icon == iconName ? Color(hex: colorHex) : Theme.outline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(icon)
                    .accessibilityAddTraits(icon == iconName ? .isSelected : [])
                }
            }
        }
        .card(padding: 16, background: Theme.cardMuted)
    }
}
