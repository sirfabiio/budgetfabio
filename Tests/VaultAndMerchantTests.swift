import XCTest
@testable import Orcamento

final class VaultAndMerchantTests: XCTestCase {
    func testGoalsCannotExceedVault() {
        // Cofre 1000 €, objetivos já com 600 + 300 → livre 100 €.
        let allocations = [60000, 30000]
        XCTAssertEqual(VaultCalculator.free(vault: 100000, allocations: allocations), 10000)
        XCTAssertNil(VaultCalculator.validateAllocation(delta: 10000, goalAllocated: 30000, vault: 100000, allocations: allocations))
        XCTAssertEqual(VaultCalculator.validateAllocation(delta: 10001, goalAllocated: 30000, vault: 100000, allocations: allocations),
                       .exceedsFreeVault(available: 10000))
        XCTAssertNil(VaultCalculator.validateAllocation(delta: -30000, goalAllocated: 30000, vault: 100000, allocations: allocations))
        XCTAssertEqual(VaultCalculator.validateAllocation(delta: -30001, goalAllocated: 30000, vault: 100000, allocations: allocations),
                       .exceedsAllocation(available: 30000))
    }

    func testWithdrawalOnlyFromFreePart() {
        XCTAssertNil(VaultCalculator.validateWithdrawal(amount: 10000, vault: 100000, allocations: [90000]))
        XCTAssertEqual(VaultCalculator.validateWithdrawal(amount: 10001, vault: 100000, allocations: [90000]), .exceedsFreeVault(available: 10000))
        XCTAssertEqual(VaultCalculator.validateWithdrawal(amount: 0, vault: 100000, allocations: []), .nonPositiveAmount)
    }

    func testDepositLimitedByChecking() {
        XCTAssertNil(VaultCalculator.validateDeposit(amount: 5000, checking: 5000))
        XCTAssertEqual(VaultCalculator.validateDeposit(amount: 5001, checking: 5000), .exceedsChecking(available: 5000))
    }

    func testMerchantKeyAndMatching() {
        XCTAssertEqual(MerchantMatcher.key("CONTINENTE Modelo 1234"), "continente modelo")
        XCTAssertEqual(MerchantMatcher.key("Pingo Doce"), "pingo doce")
        XCTAssertEqual(MerchantMatcher.key("Café Nicola"), "cafe nicola")
        let keys = ["continente", "pingo doce", "galp"]
        XCTAssertEqual(MerchantMatcher.bestMatch(for: "Continente Bom Dia Lisboa", keys: keys), "continente")
        XCTAssertEqual(MerchantMatcher.bestMatch(for: "PINGO DOCE", keys: keys), "pingo doce")
        XCTAssertNil(MerchantMatcher.bestMatch(for: "Lidl", keys: keys))
        XCTAssertNil(MerchantMatcher.bestMatch(for: "Galpão", keys: keys))
    }

    func testAnalyticsSeriesAndSavingsRate() {
        let txs = [
            TxSnapshot(amountCents: 100000, kind: .income, date: makeDate(2026, 2, 1)),
            TxSnapshot(amountCents: 60000, kind: .expense, date: makeDate(2026, 2, 10)),
            TxSnapshot(amountCents: 20000, kind: .vaultDeposit, date: makeDate(2026, 2, 11)),
            TxSnapshot(amountCents: 100000, kind: .income, date: makeDate(2026, 3, 1)),
            TxSnapshot(amountCents: 120000, kind: .expense, date: makeDate(2026, 3, 10)),
        ]
        let series = AnalyticsCalculator.monthlySeries(txs, opening: 0, months: 2, now: makeDate(2026, 3, 15))
        XCTAssertEqual(series.count, 2)
        XCTAssertEqual(series[0].checking, 20000)
        XCTAssertEqual(series[0].vault, 20000)
        XCTAssertEqual(series[0].netWorth, 40000)
        XCTAssertEqual(series[0].savingsRateBasisPoints, 4000)
        XCTAssertEqual(series[1].netWorth, 20000)
        XCTAssertEqual(series[1].savingsRateBasisPoints, -2000)
    }

    func testForecast() {
        // Dia 10 de abril (30 dias), 300 € gastos → 30 €/dia × 20 dias = 600 €.
        let f = AnalyticsCalculator.endOfMonthForecast(checking: 100000, monthExpenses: 30000, upcomingRecurringNet: -5000, now: makeDate(2026, 4, 10))
        XCTAssertEqual(f, 100000 - 60000 - 5000)
    }
}

final class VaultTrimTests: XCTestCase {
    func testTrimAllocationsFromNewest() {
        XCTAssertEqual(VaultCalculator.trimAllocations([5000, 3000, 2000], vault: 10000), [5000, 3000, 2000])
        XCTAssertEqual(VaultCalculator.trimAllocations([5000, 3000, 2000], vault: 7000), [5000, 2000, 0])
        XCTAssertEqual(VaultCalculator.trimAllocations([5000, 3000], vault: -100), [0, 0])
    }
}
