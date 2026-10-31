import Foundation
import SwiftData

@MainActor
enum Persistence {
    /// Contentor único partilhado pela app e pelos App Intents (mesmo processo).
    static let shared: ModelContainer = {
        let schema = Schema(AppSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Não foi possível abrir a base de dados: \(error)")
        }
    }()

    /// Cria as categorias iniciais em português, apenas uma vez.
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<FinCategory>())) ?? 0
        guard count == 0 else { return }
        let expense: [(String, String, String)] = [
            ("Supermercado", "cart.fill", "#34C759"),
            ("Restaurantes", "fork.knife", "#FF9500"),
            ("Transportes", "tram.fill", "#007AFF"),
            ("Combustível", "fuelpump.fill", "#FF3B30"),
            ("Casa", "house.fill", "#A2845E"),
            ("Contas e serviços", "bolt.fill", "#FFCC00"),
            ("Saúde", "cross.case.fill", "#FF2D55"),
            ("Lazer", "gamecontroller.fill", "#AF52DE"),
            ("Compras", "bag.fill", "#5856D6"),
            ("Subscrições", "repeat", "#30B0C7"),
            ("Educação", "graduationcap.fill", "#00C7BE"),
            ("Viagens", "airplane", "#007AFF"),
            ("Oficina e peças", "wrench.and.screwdriver.fill", "#FF9500"),
            ("Presentes", "gift.fill", "#FF2D55"),
            ("Outros", "ellipsis.circle.fill", "#8E8E93"),
        ]
        let income: [(String, String, String)] = [
            ("Salário", "banknote.fill", "#34C759"),
            ("Trabalhos extra", "briefcase.fill", "#00C7BE"),
            ("Reembolsos", "arrow.uturn.backward", "#5856D6"),
            ("Outras receitas", "plus.circle.fill", "#8E8E93"),
        ]
        for (i, c) in expense.enumerated() {
            context.insert(FinCategory(name: c.0, kind: .expense, colorHex: c.2, iconName: c.1, sortOrder: i))
        }
        for (i, c) in income.enumerated() {
            context.insert(FinCategory(name: c.0, kind: .income, colorHex: c.2, iconName: c.1, sortOrder: 100 + i))
        }
        try? context.save()
    }
}
