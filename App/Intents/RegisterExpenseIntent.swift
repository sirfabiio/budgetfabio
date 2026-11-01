import AppIntents
import SwiftData
import Foundation

enum IntentFailure: Error, CustomLocalizedStringResourceConvertible {
    case invalidAmount(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidAmount(let raw): return "Não percebi o valor \"\(raw)\". Usa, por exemplo, 12,50 €."
        }
    }
}

/// Lógica da captura, separada do AppIntent para poder ser testada.
@MainActor
enum ExpenseCapture {
    @discardableResult
    static func register(amountText: String, merchant: String?, card: String?, categoryName: String?,
                         date: Date = .now, context: ModelContext) throws -> FinTransaction {
        guard let cents = AmountParser.parseCents(amountText), cents != 0 else {
            throw IntentFailure.invalidAmount(amountText)
        }
        let merchantName = (merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let categories = (try? context.fetch(FetchDescriptor<FinCategory>())) ?? []

        // 1) categoria indicada explicitamente; 2) regra aprendida comerciante→categoria.
        var category: FinCategory? = nil
        if let name = categoryName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            let key = TextNormalizer.key(name)
            category = categories.first { TextNormalizer.key($0.name) == key && $0.kind == .expense && !$0.isArchived }
        }
        if category == nil, !merchantName.isEmpty {
            category = MerchantRuleStore.suggestion(for: merchantName, context: context)
        }

        // Valores negativos (ex.: reembolsos no Apple Pay) entram como receita.
        let t = FinTransaction(amountCents: abs(cents), kind: cents < 0 ? .income : .expense, date: date, category: category,
                               method: .applePay, note: "", merchant: merchantName,
                               card: (card ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                               needsReview: true)
        context.insert(t)
        try context.save()
        return t
    }
}

struct RegisterExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Registar despesa"
    static var description = IntentDescription("Regista uma despesa no Budget do Fábio sem abrir a app. Pensado para a automação de Transação do Apple Pay nos Atalhos.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Valor", description: "Ex.: 12,50 € ou €12.50")
    var valor: String

    @Parameter(title: "Comerciante")
    var comerciante: String?

    @Parameter(title: "Cartão")
    var cartao: String?

    @Parameter(title: "Categoria", description: "Opcional. Se vazio, usa a categoria aprendida para o comerciante.")
    var categoria: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Registar despesa de \(\.$valor) em \(\.$comerciante)") {
            \.$cartao
            \.$categoria
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = Persistence.shared.mainContext
        Persistence.seedIfNeeded(context)
        let t = try ExpenseCapture.register(amountText: valor, merchant: comerciante, card: cartao, categoryName: categoria, context: context)
        let where_ = t.merchant.isEmpty ? "" : " em \(t.merchant)"
        let cat = t.category.map { " (\($0.name))" } ?? ""
        return .result(dialog: "Registado: \(MoneyFormat.string(t.amountCents))\(where_)\(cat). Fica por rever na app.")
    }
}

struct OrcamentoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegisterExpenseIntent(),
            phrases: [
                "Registar despesa no \(.applicationName)",
                "Nova despesa no \(.applicationName)",
            ],
            shortTitle: "Registar despesa",
            systemImageName: "creditcard"
        )
    }
}
