import Foundation
import SwiftData

@MainActor
enum MerchantRuleStore {
    /// Memoriza (ou atualiza) a categoria escolhida para um comerciante.
    static func learn(merchant: String, category: FinCategory, context: ModelContext) {
        let key = MerchantMatcher.key(merchant)
        guard !key.isEmpty else { return }
        let rules = (try? context.fetch(FetchDescriptor<MerchantRule>())) ?? []
        if let existing = rules.first(where: { $0.merchantKey == key }) {
            existing.category = category
            existing.updatedAt = .now
        } else {
            context.insert(MerchantRule(merchantKey: key, category: category))
        }
    }

    /// Categoria sugerida para um comerciante, com base nas regras aprendidas.
    static func suggestion(for merchant: String, context: ModelContext) -> FinCategory? {
        let rules = (try? context.fetch(FetchDescriptor<MerchantRule>())) ?? []
        guard let key = MerchantMatcher.bestMatch(for: merchant, keys: rules.map(\.merchantKey)) else { return nil }
        return rules.first { $0.merchantKey == key }?.category
    }
}
