import Foundation

enum VaultError: Error, Equatable {
    case nonPositiveAmount
    case exceedsFreeVault(available: Cents)
    case exceedsAllocation(available: Cents)
    case exceedsChecking(available: Cents)

    var message: String {
        switch self {
        case .nonPositiveAmount: return "O valor tem de ser superior a zero."
        case .exceedsFreeVault(let a): return "Só há \(MoneyFormat.string(a)) livres no cofre (o resto está afeto a objetivos)."
        case .exceedsAllocation(let a): return "Este objetivo só tem \(MoneyFormat.string(a)) afetos."
        case .exceedsChecking(let a): return "O saldo à ordem é de apenas \(MoneyFormat.string(a))."
        }
    }
}

enum VaultCalculator {
    /// Saldo do cofre ainda não afeto a objetivos.
    static func free(vault: Cents, allocations: [Cents]) -> Cents {
        vault - allocations.reduce(0, +)
    }

    /// Valida uma afetação (delta > 0) ou desafetação (delta < 0) a um objetivo.
    /// A soma dos objetivos nunca pode exceder o saldo do cofre.
    static func validateAllocation(delta: Cents, goalAllocated: Cents, vault: Cents, allocations: [Cents]) -> VaultError? {
        if delta == 0 { return .nonPositiveAmount }
        if delta > 0 {
            let available = free(vault: vault, allocations: allocations)
            return delta > available ? .exceedsFreeVault(available: max(0, available)) : nil
        }
        return -delta > goalAllocated ? .exceedsAllocation(available: goalAllocated) : nil
    }

    /// Levantar do cofre só pode usar a parte livre (não afeta a objetivos).
    static func validateWithdrawal(amount: Cents, vault: Cents, allocations: [Cents]) -> VaultError? {
        if amount <= 0 { return .nonPositiveAmount }
        let available = free(vault: vault, allocations: allocations)
        return amount > available ? .exceedsFreeVault(available: max(0, available)) : nil
    }

    static func validateDeposit(amount: Cents, checking: Cents) -> VaultError? {
        if amount <= 0 { return .nonPositiveAmount }
        return amount > checking ? .exceedsChecking(available: max(0, checking)) : nil
    }
}
