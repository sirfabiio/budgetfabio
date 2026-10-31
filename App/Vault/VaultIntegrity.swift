import Foundation
import SwiftData

@MainActor
enum VaultIntegrity {
    /// Garante que a soma dos objetivos nunca excede o saldo do cofre.
    static func enforce(_ context: ModelContext) {
        let txs = (try? context.fetch(FetchDescriptor<FinTransaction>())) ?? []
        let goals = (try? context.fetch(FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let vault = BalanceCalculator.balances(txs.map(\.snapshot), opening: 0).vault
        let trimmed = VaultCalculator.trimAllocations(goals.map(\.allocatedCents), vault: vault)
        var changed = false
        for (g, v) in zip(goals, trimmed) where g.allocatedCents != v {
            g.allocatedCents = v
            changed = true
        }
        if changed { try? context.save() }
    }
}
