import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @Query(sort: \FinTransaction.date, order: .reverse) private var transactions: [FinTransaction]
    @AppStorage(SettingsKeys.globalBudget) private var globalBudget: Int = 0
    @State private var editing: FinCategory?
    @State private var creating = false
    @State private var showArchived = false

    var body: some View {
        let active = categories.filter { !$0.isArchived }
        let archived = categories.filter(\.isArchived)
        let limits = active.compactMap(\.monthlyBudgetCents).reduce(0, +)
        let month = BalanceCalculator.monthInterval(containing: .now)
        let snaps = transactions.map(\.snapshot)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Organização", title: "Categorias") {
                    Button { creating = true } label: { Label("Nova", systemImage: "plus") }
                        .buttonStyle(PillButtonStyle())
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Eyebrow("Orçamento mensal por categoria")
                        Spacer()
                        Text("\(active.count) categorias").font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    HeroAmount(cents: limits)
                    if globalBudget > 0 {
                        HStack(spacing: 12) {
                            ThinProgress(fraction: Double(limits) / Double(globalBudget), color: Theme.primary, height: 8)
                            Text("\(limits * 100 / globalBudget)% alocado").font(.subheadline).foregroundStyle(Theme.textSecondary)
                                .fixedSize()
                        }
                    } else {
                        Text("Soma dos limites definidos nas categorias de despesa.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                }
                .card(padding: 24)
                .accessibilityElement(children: .combine)

                ForEach(CategoryKind.allCases) { kind in
                    let items = active.filter { $0.kind == kind }
                    if !items.isEmpty {
                        Eyebrow(kind == .expense ? "Despesas" : "Receitas").padding(.leading, 4).padding(.top, 4)
                        RowsCard {
                            ForEach(items) { c in
                                row(c, spent: monthTotal(c, snaps: snaps, month: month))
                                if c.id != items.last?.id { RowDivider() }
                            }
                        }
                    }
                }

                if !archived.isEmpty {
                    DisclosureGroup(isExpanded: $showArchived) {
                        RowsCard {
                            ForEach(archived) { c in
                                row(c, spent: nil)
                                if c.id != archived.last?.id { RowDivider() }
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Eyebrow("Arquivadas (\(archived.count))")
                    }
                    .tint(Theme.textSecondary)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { c in CategoryEditorView(category: c) }
        .sheet(isPresented: $creating) { CategoryEditorView(category: nil) }
    }

    private func monthTotal(_ c: FinCategory, snaps: [TxSnapshot], month: DateInterval) -> Cents {
        snaps.filter { $0.categoryID == c.id && $0.date >= month.start && $0.date < month.end && !$0.kind.isTransfer }
            .reduce(0) { $0 + $1.amountCents }
    }

    private func row(_ c: FinCategory, spent: Cents?) -> some View {
        Button { editing = c } label: {
            HStack(spacing: 14) {
                IconTile(systemName: c.iconName, colorHex: c.colorHex, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.name).font(.body.weight(.semibold))
                        .foregroundStyle(c.isArchived ? Theme.textSecondary : Theme.textPrimary)
                    if let limit = c.monthlyBudgetCents {
                        Text("Limite: \(MoneyFormat.string(limit))").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                if let spent {
                    HStack(spacing: 8) {
                        Circle().fill(Color(hex: c.colorHex)).frame(width: 8, height: 8)
                        Text("\(c.kind == .expense ? "−" : "+") \(MoneyFormat.string(spent))")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                } else {
                    Image(systemName: "archivebox").foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                c.isArchived.toggle()
            } label: {
                Label(c.isArchived ? "Reativar" : "Arquivar", systemImage: c.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: c.isArchived ? "Reativar" : "Arquivar") { c.isArchived.toggle() }
    }
}

struct CategoryEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var all: [FinCategory]
    let category: FinCategory?

    @State private var name = ""
    @State private var kind: CategoryKind = .expense
    @State private var colorHex = Palette.colors[6]
    @State private var iconName = Palette.icons[0]
    @State private var isArchived = false
    @State private var limit: Cents? = nil
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SheetHeader(eyebrow: "Parâmetros", title: category == nil ? "Nova Categoria" : "Editar Categoria") { dismiss() }

                Picker("Tipo", selection: $kind) {
                    ForEach(CategoryKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                IconColorPicker(iconName: $iconName, colorHex: $colorHex)

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Nome da categoria")
                    StyledField(systemImage: "tag") { TextField("Ex.: Alimentação", text: $name) }
                }

                if kind == .expense {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Eyebrow("Limite mensal opcional")
                            Spacer()
                            Text("pt-PT").font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        StyledField(systemImage: "eurosign") { AmountField(title: "", cents: $limit) }
                    }
                }

                if category != nil {
                    StyledField(systemImage: "archivebox") {
                        Toggle("Arquivada", isOn: $isArchived)
                    }
                    Text("As categorias arquivadas deixam de aparecer nas escolhas, mas as transações antigas mantêm-nas.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }

                Button(category == nil ? "Criar Categoria" : "Guardar Alterações", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(Theme.margin)
            .padding(.top, 8)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            if let c = category {
                name = c.name; kind = c.kind; colorHex = c.colorHex; iconName = c.iconName
                isArchived = c.isArchived; limit = c.monthlyBudgetCents
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let budget = kind == .expense ? limit.flatMap { $0 > 0 ? $0 : nil } : nil
        if let c = category {
            c.name = trimmed; c.kind = kind; c.colorHex = colorHex; c.iconName = iconName
            c.isArchived = isArchived; c.monthlyBudgetCents = budget
        } else {
            let order = (all.map(\.sortOrder).max() ?? 0) + 1
            context.insert(FinCategory(name: trimmed, kind: kind, colorHex: colorHex, iconName: iconName,
                                       sortOrder: order, monthlyBudgetCents: budget))
        }
        try? context.save()
        dismiss()
    }
}
