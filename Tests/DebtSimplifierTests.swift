import XCTest
@testable import Orcamento

final class DebtSimplifierTests: XCTestCase {
    /// Aplica as transferências e confirma que todos ficam a zero.
    private func assertSettles(_ balances: [String: Cents], _ transfers: [Settlement], file: StaticString = #filePath, line: UInt = #line) {
        var b = balances
        for t in transfers {
            XCTAssertGreaterThan(t.amountCents, 0, file: file, line: line)
            b[t.from, default: 0] += t.amountCents
            b[t.to, default: 0] -= t.amountCents
        }
        XCTAssertTrue(b.values.allSatisfy { $0 == 0 }, "Saldos finais: \(b)", file: file, line: line)
    }

    func testEqualSharesDistributeRemainder() {
        let s = SplitCalculator.equalShares(total: 1000, participants: ["Eu", "Ana", "Rui"])
        XCTAssertEqual(s, ["Eu": 334, "Ana": 333, "Rui": 333])
        XCTAssertEqual(s.values.reduce(0, +), 1000)
    }

    func testNetBalances() {
        let records = [
            SplitRecord(payer: "Eu", amountCents: 9000, shares: SplitCalculator.equalShares(total: 9000, participants: ["Eu", "Ana", "Rui"])),
            SplitRecord(payer: "Ana", amountCents: 3000, shares: ["Ana": 1000, "Rui": 2000]),
        ]
        let net = SplitCalculator.netBalances(records, participants: ["Eu", "Ana", "Rui"])
        XCTAssertEqual(net, ["Eu": 6000, "Ana": -1000, "Rui": -5000])
    }

    func testSettlementRecordZeroesDebt() {
        var records = [SplitRecord(payer: "Eu", amountCents: 2000, shares: ["Eu": 1000, "Ana": 1000])]
        records.append(SplitRecord(payer: "Ana", amountCents: 1000, shares: ["Eu": 1000]))
        let net = SplitCalculator.netBalances(records, participants: ["Eu", "Ana"])
        XCTAssertEqual(net, ["Eu": 0, "Ana": 0])
        XCTAssertTrue(DebtSimplifier.simplify(net).isEmpty)
    }

    func testSimpleChainCollapses() {
        // A deve 10 a B, B deve 10 a C → basta A pagar 10 a C.
        let balances = ["A": -1000, "B": 0, "C": 1000]
        let t = DebtSimplifier.simplify(balances)
        XCTAssertEqual(t, [Settlement(from: "A", to: "C", amountCents: 1000)])
    }

    func testMinimumUsesZeroSumSubgroups() {
        // Dois pares independentes: o ótimo são 2 transferências (não 3).
        let balances = ["A": -500, "B": 500, "C": -700, "D": 700]
        let t = DebtSimplifier.simplify(balances)
        XCTAssertEqual(t.count, 2)
        assertSettles(balances, t)
        let tricky = ["A": -400, "B": -300, "C": -300, "D": 700, "E": 300]
        let tt = DebtSimplifier.simplify(tricky)
        XCTAssertEqual(tt.count, 3)
        assertSettles(tricky, tt)
    }

    func testMinimumBeatsGreedyCase() {
        // Subgrupos {A, C} e {B, D, E}. O guloso mistura-os (4 transferências); o ótimo usa 3.
        let balances = ["A": 400, "B": 500, "C": -400, "D": -300, "E": -200]
        let greedy = DebtSimplifier.greedy(balances.sorted { $0.key < $1.key })
        let optimal = DebtSimplifier.simplify(balances)
        XCTAssertEqual(greedy.count, 4)
        XCTAssertEqual(optimal.count, 3)
        assertSettles(balances, optimal)
        assertSettles(balances, greedy)
    }

    func testEmpty() {
        XCTAssertTrue(DebtSimplifier.simplify([:]).isEmpty)
        XCTAssertTrue(DebtSimplifier.simplify(["A": 0, "B": 0]).isEmpty)
    }
}
