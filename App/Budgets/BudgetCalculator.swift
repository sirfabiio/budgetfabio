import Foundation

enum BudgetState: Equatable {
    case normal
    case nearLimit
    case exceeded

    var label: String {
        switch self {
        case .normal: return "Dentro do orçamento"
        case .nearLimit: return "Perto do limite"
        case .exceeded: return "Ultrapassado"
        }
    }
}

struct BudgetStatus: Equatable {
    var spent: Cents
    var limit: Cents
    var state: BudgetState
    /// Fração consumida (0...∞) apenas para a barra de progresso.
    var fraction: Double { limit > 0 ? Double(spent) / Double(limit) : 0 }
    var remaining: Cents { limit - spent }
}

enum BudgetCalculator {
    /// A partir desta percentagem (inclusive) considera-se "perto do limite".
    static let nearLimitPercent = 80

    static func status(spent: Cents, limit: Cents) -> BudgetStatus {
        let state: BudgetState
        if limit <= 0 {
            state = spent > 0 ? .exceeded : .normal
        } else if spent > limit {
            state = .exceeded
        } else if spent * 100 >= limit * nearLimitPercent {
            state = .nearLimit
        } else {
            state = .normal
        }
        return BudgetStatus(spent: spent, limit: limit, state: state)
    }

    static func spent(_ txs: [TxSnapshot], categoryID: UUID?, in interval: DateInterval) -> Cents {
        txs.filter { $0.kind == .expense && $0.date >= interval.start && $0.date < interval.end && (categoryID == nil || $0.categoryID == categoryID) }
            .reduce(0) { $0 + $1.amountCents }
    }
}
