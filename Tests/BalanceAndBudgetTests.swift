import XCTest
@testable import Orcamento

final class BalanceAndBudgetTests: XCTestCase {
    let food = UUID()
    let fuel = UUID()

    lazy var txs: [TxSnapshot] = [
        TxSnapshot(amountCents: 150000, kind: .income, date: makeDate(2026, 3, 1)),
        TxSnapshot(amountCents: 4520, kind: .expense, date: makeDate(2026, 3, 2), categoryID: food),
        TxSnapshot(amountCents: 6000, kind: .expense, date: makeDate(2026, 3, 5), categoryID: fuel),
        TxSnapshot(amountCents: 1490, kind: .expense, date: makeDate(2026, 3, 9), categoryID: food),
        TxSnapshot(amountCents: 20000, kind: .vaultDeposit, date: makeDate(2026, 3, 10)),
        TxSnapshot(amountCents: 5000, kind: .vaultWithdrawal, date: makeDate(2026, 3, 20)),
        TxSnapshot(amountCents: 999, kind: .expense, date: makeDate(2026, 4, 1), categoryID: food),
    ]

    func testBalancesTreatVaultTransfersAsMovesNotExpenses() {
        let b = BalanceCalculator.balances(txs, opening: 10000)
        // 10000 + 150000 - 4520 - 6000 - 1490 - 20000 + 5000 - 999
        XCTAssertEqual(b.checking, 131991)
        XCTAssertEqual(b.vault, 15000)
        XCTAssertEqual(b.netWorth, 146991)
    }

    func testBalancesUpToDate() {
        let b = BalanceCalculator.balances(txs, opening: 0, upTo: makeDate(2026, 3, 10, 23))
        XCTAssertEqual(b.checking, 150000 - 4520 - 6000 - 1490 - 20000)
        XCTAssertEqual(b.vault, 20000)
    }

    func testMonthlyCashFlowExcludesTransfersAndOtherMonths() {
        let m = BalanceCalculator.monthInterval(containing: makeDate(2026, 3, 15))
        let flow = BalanceCalculator.cashFlow(txs, from: m.start, to: m.end)
        XCTAssertEqual(flow.income, 150000)
        XCTAssertEqual(flow.expense, 12010)
        XCTAssertEqual(flow.net, 137990)
    }

    func testExpensesByCategorySorted() {
        let m = BalanceCalculator.monthInterval(containing: makeDate(2026, 3, 15))
        let byCat = BalanceCalculator.expensesByCategory(txs, from: m.start, to: m.end)
        XCTAssertEqual(byCat.map(\.categoryID), [food, fuel])
        XCTAssertEqual(byCat.map(\.total), [6010, 6000])
    }

    func testBudgetStates() {
        XCTAssertEqual(BudgetCalculator.status(spent: 7999, limit: 10000).state, .normal)
        XCTAssertEqual(BudgetCalculator.status(spent: 8000, limit: 10000).state, .nearLimit)
        XCTAssertEqual(BudgetCalculator.status(spent: 10000, limit: 10000).state, .nearLimit)
        XCTAssertEqual(BudgetCalculator.status(spent: 10001, limit: 10000).state, .exceeded)
        XCTAssertEqual(BudgetCalculator.status(spent: 0, limit: 0).state, .normal)
        XCTAssertEqual(BudgetCalculator.status(spent: 1, limit: 0).state, .exceeded)
        XCTAssertEqual(BudgetCalculator.status(spent: 2500, limit: 10000).remaining, 7500)
    }

    func testBudgetSpentPerCategory() {
        let m = BalanceCalculator.monthInterval(containing: makeDate(2026, 3, 15))
        XCTAssertEqual(BudgetCalculator.spent(txs, categoryID: food, in: m), 6010)
        XCTAssertEqual(BudgetCalculator.spent(txs, categoryID: nil, in: m), 12010)
    }

    func testLedgerFilters() {
        var f = LedgerFilter()
        f.categoryID = food
        XCTAssertEqual(txs.filter { f.matches($0) }.count, 3)
        f.startDate = makeDate(2026, 3, 3)
        f.endDate = makeDate(2026, 3, 31)
        XCTAssertEqual(txs.filter { f.matches($0) }.count, 1)

        var g = LedgerFilter()
        g.minCents = 5000
        g.maxCents = 20000
        g.kind = .expense
        XCTAssertEqual(txs.filter { g.matches($0) }.map(\.amountCents), [6000])

        var h = LedgerFilter()
        h.searchText = "cafe"
        XCTAssertTrue(h.matches(TxSnapshot(amountCents: 1, kind: .expense, date: .now, text: "Café Central")))
        XCTAssertFalse(h.matches(TxSnapshot(amountCents: 1, kind: .expense, date: .now, text: "Pingo Doce")))
    }

    func testLedgerSignedTotalAndGrouping() {
        XCTAssertEqual(LedgerFilter.signedTotal(txs), 150000 - 4520 - 6000 - 1490 - 20000 + 5000 - 999)
        let groups = LedgerFilter.groupByDay(txs) { $0.date }
        XCTAssertEqual(groups.count, 7)
        XCTAssertEqual(groups.first?.day, dayStart(2026, 4, 1))
    }
}
