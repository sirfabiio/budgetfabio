import Foundation

/// Despesa partilhada, em forma pura: quem pagou, quanto, e quanto cabe a cada pessoa.
struct SplitRecord: Equatable {
    var payer: String
    var amountCents: Cents
    var shares: [String: Cents]
}

struct Settlement: Equatable, Hashable {
    var from: String
    var to: String
    var amountCents: Cents
}

enum SplitCalculator {
    /// Divide em partes iguais; os cêntimos que sobram vão para os primeiros participantes.
    static func equalShares(total: Cents, participants: [String]) -> [String: Cents] {
        guard !participants.isEmpty else { return [:] }
        let base = total / participants.count
        let remainder = total % participants.count
        var shares: [String: Cents] = [:]
        for (i, p) in participants.enumerated() {
            shares[p, default: 0] += base + (i < remainder ? 1 : 0)
        }
        return shares
    }

    /// Saldo líquido por pessoa: positivo = tem a receber, negativo = deve.
    static func netBalances(_ records: [SplitRecord], participants: [String]) -> [String: Cents] {
        var net: [String: Cents] = [:]
        for p in participants { net[p] = 0 }
        for r in records {
            net[r.payer, default: 0] += r.amountCents
            for (person, share) in r.shares {
                net[person, default: 0] -= share
            }
        }
        return net
    }
}

enum DebtSimplifier {
    /// Até este número de pessoas com saldo não nulo, usa-se a solução ótima (programação dinâmica).
    static let exactLimit = 16

    /// Conjunto mínimo de transferências que salda todos os saldos (a soma tem de ser zero).
    static func simplify(_ balances: [String: Cents]) -> [Settlement] {
        let people = balances.filter { $0.value != 0 }.sorted { $0.key < $1.key }
        guard people.reduce(0, { $0 + $1.value }) == 0 else { return greedy(people) }
        guard !people.isEmpty else { return [] }
        if people.count > exactLimit { return greedy(people) }

        // dp[mask] = número máximo de subgrupos de soma zero em que `mask` pode ser partido.
        // Transferências mínimas = n - máximo de subgrupos.
        let n = people.count
        let full = (1 << n) - 1
        var sum = [Cents](repeating: 0, count: 1 << n)
        for mask in 1...full {
            let low = mask.trailingZeroBitCount
            sum[mask] = sum[mask & (mask - 1)] + people[low].value
        }
        var dp = [Int](repeating: 0, count: 1 << n)
        var choice = [Int](repeating: -1, count: 1 << n)
        for mask in 1...full {
            var best = -1
            var bestBit = -1
            var bits = mask
            while bits != 0 {
                let i = bits.trailingZeroBitCount
                bits &= bits - 1
                let v = dp[mask ^ (1 << i)]
                if v > best { best = v; bestBit = i }
            }
            dp[mask] = best + (sum[mask] == 0 ? 1 : 0)
            choice[mask] = bestBit
        }
        // Reconstrói a ordem de inserção; cada prefixo de soma zero fecha um subgrupo.
        var order: [Int] = []
        var mask = full
        while mask != 0 {
            let i = choice[mask]
            order.append(i)
            mask ^= 1 << i
        }
        order.reverse()
        var result: [Settlement] = []
        var group: [(key: String, value: Cents)] = []
        var running: Cents = 0
        for i in order {
            group.append(people[i])
            running += people[i].value
            if running == 0 {
                result += greedy(group)
                group.removeAll()
            }
        }
        return result
    }

    /// Emparelha sempre o maior credor com o maior devedor.
    static func greedy(_ people: [(key: String, value: Cents)]) -> [Settlement] {
        var creditors = people.filter { $0.value > 0 }.map { ($0.key, $0.value) }
        var debtors = people.filter { $0.value < 0 }.map { ($0.key, -$0.value) }
        var result: [Settlement] = []
        while !creditors.isEmpty, !debtors.isEmpty {
            creditors.sort { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
            debtors.sort { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
            let amount = min(creditors[0].1, debtors[0].1)
            result.append(Settlement(from: debtors[0].0, to: creditors[0].0, amountCents: amount))
            creditors[0].1 -= amount
            debtors[0].1 -= amount
            if creditors[0].1 == 0 { creditors.removeFirst() }
            if debtors[0].1 == 0 { debtors.removeFirst() }
        }
        return result
    }
}
