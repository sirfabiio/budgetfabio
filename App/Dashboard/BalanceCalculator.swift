import Foundation

struct Balances: Equatable {
    var checking: Cents
    var vault: Cents
    var netWorth: Cents { checking + vault }
}

struct CashFlow: Equatable {
    var income: Cents
    var expense: Cents
    var net: Cents { income - expense }
}

struct CategoryTotal: Equatable, Identifiable {
    var categoryID: UUID?
    var total: Cents
    var id: String { categoryID?.uuidString ?? "sem-categoria" }
}

enum BalanceCalculator {
    /// Saldo à ordem e saldo do cofre, opcionalmente até uma data (inclusive).
    static func balances(_ txs: [TxSnapshot], opening: Cents, upTo date: Date? = nil) -> Balances {
        var checking = opening
        var vault: Cents = 0
        for t in txs {
            if let date, t.date > date { continue }
            switch t.kind {
            case .income: checking += t.amountCents
            case .expense: checking -= t.amountCents
            case .vaultDeposit:
                checking -= t.amountCents
                vault += t.amountCents
            case .vaultWithdrawal:
                checking += t.amountCents
                vault -= t.amountCents
            }
        }
        return Balances(checking: checking, vault: vault)
    }

    /// Receitas vs despesas num intervalo [start, end). Transferências do cofre não contam.
    static func cashFlow(_ txs: [TxSnapshot], from start: Date, to end: Date) -> CashFlow {
        var flow = CashFlow(income: 0, expense: 0)
        for t in txs where t.date >= start && t.date < end {
            switch t.kind {
            case .income: flow.income += t.amountCents
            case .expense: flow.expense += t.amountCents
            default: break
            }
        }
        return flow
    }

    /// Despesas agrupadas por categoria, por ordem decrescente.
    static func expensesByCategory(_ txs: [TxSnapshot], from start: Date, to end: Date) -> [CategoryTotal] {
        var totals: [UUID?: Cents] = [:]
        for t in txs where t.kind == .expense && t.date >= start && t.date < end {
            totals[t.categoryID, default: 0] += t.amountCents
        }
        return totals.map { CategoryTotal(categoryID: $0.key, total: $0.value) }
            .sorted { $0.total == $1.total ? $0.id < $1.id : $0.total > $1.total }
    }

    static func monthInterval(containing date: Date, calendar: Calendar = PT.calendar) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 0)
    }
}
