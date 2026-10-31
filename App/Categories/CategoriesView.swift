import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Query(sort: \FinCategory.sortOrder) private var categories: [FinCategory]
    @State private var editing: FinCategory?
    @State private var creating = false
    @State private var showArchived = false

    var body: some View {
        List {
            ForEach(CategoryKind.allCases) { kind in
                let items = categories.filter { $0.kind == kind && !$0.isArchived }
                Section(kind == .expense ? "Despesas" : "Receitas") {
                    ForEach(items) { c in row(c) }
                }
            }
            let archived = categories.filter(\.isArchived)
            if !archived.isEmpty {
                Section {
                    DisclosureGroup("Arquivadas (\(archived.count))", isExpanded: $showArchived) {
                        ForEach(archived) { c in row(c) }
                    }
                }
            }
        }
        .navigationTitle("Categorias")
        .toolbar {
            Button { creating = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Nova categoria")
        }
        .sheet(item: $editing) { c in CategoryEditorView(category: c) }
        .sheet(isPresented: $creating) { CategoryEditorView(category: nil) }
    }

    private func row(_ c: FinCategory) -> some View {
        Button { editing = c } label: {
            HStack {
                CategoryIcon(iconName: c.iconName, colorHex: c.colorHex)
                Text(c.name).foregroundStyle(c.isArchived ? .secondary : .primary)
                Spacer()
                if c.isArchived { Image(systemName: "archivebox").foregroundStyle(.secondary) }
            }
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button {
                c.isArchived.toggle()
            } label: {
                Label(c.isArchived ? "Reativar" : "Arquivar", systemImage: c.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            .tint(.orange)
        }
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
    @State private var loaded = false

    private let columns = [GridItem(.adaptive(minimum: 40))]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        CategoryIcon(iconName: iconName, colorHex: colorHex, size: 40)
                        TextField("Nome", text: $name)
                    }
                    Picker("Tipo", selection: $kind) {
                        ForEach(CategoryKind.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("Cor") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Palette.colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay { if hex == colorHex { Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.bold()) } }
                                .onTapGesture { colorHex = hex }
                                .accessibilityLabel("Cor \(hex)")
                                .accessibilityAddTraits(hex == colorHex ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Ícone") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Palette.icons, id: \.self) { icon in
                            Image(systemName: icon)
                                .frame(width: 36, height: 36)
                                .background(icon == iconName ? Color(hex: colorHex).opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 8))
                                .onTapGesture { iconName = icon }
                                .accessibilityLabel(icon)
                                .accessibilityAddTraits(icon == iconName ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if category != nil {
                    Section {
                        Toggle("Arquivada", isOn: $isArchived)
                    } footer: {
                        Text("As categorias arquivadas deixam de aparecer nas escolhas, mas as transações antigas mantêm-nas.")
                    }
                }
            }
            .navigationTitle(category == nil ? "Nova categoria" : "Editar categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let c = category {
                    name = c.name; kind = c.kind; colorHex = c.colorHex; iconName = c.iconName; isArchived = c.isArchived
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let c = category {
            c.name = trimmed; c.kind = kind; c.colorHex = colorHex; c.iconName = iconName; c.isArchived = isArchived
        } else {
            let order = (all.map(\.sortOrder).max() ?? 0) + 1
            context.insert(FinCategory(name: trimmed, kind: kind, colorHex: colorHex, iconName: iconName, sortOrder: order))
        }
        try? context.save()
        dismiss()
    }
}
