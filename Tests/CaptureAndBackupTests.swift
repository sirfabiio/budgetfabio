import XCTest
import SwiftData
@testable import Orcamento

@MainActor
final class CaptureAndBackupTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(AppSchema.models)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        // Mantém o contentor vivo durante o teste.
        retained.append(container)
        return context
    }
    private var retained: [ModelContainer] = []

    func testCaptureParsesAmountAndMarksForReview() throws {
        let ctx = try makeContext()
        let t = try ExpenseCapture.register(amountText: "€12.50", merchant: "Pingo Doce 123", card: "Visa", categoryName: nil, context: ctx)
        XCTAssertEqual(t.amountCents, 1250)
        XCTAssertEqual(t.kind, .expense)
        XCTAssertEqual(t.method, .applePay)
        XCTAssertTrue(t.needsReview)
        XCTAssertNil(t.category)
    }

    func testLearnedMerchantRuleSuggestsCategory() throws {
        let ctx = try makeContext()
        let food = FinCategory(name: "Supermercado", colorHex: "#34C759", iconName: "cart.fill")
        ctx.insert(food)
        MerchantRuleStore.learn(merchant: "PINGO DOCE", category: food, context: ctx)
        try ctx.save()
        let t = try ExpenseCapture.register(amountText: "12,50 €", merchant: "Pingo Doce Benfica", card: nil, categoryName: nil, context: ctx)
        XCTAssertEqual(t.category?.id, food.id)
        XCTAssertTrue(t.needsReview)
    }

    func testExplicitCategoryWins() throws {
        let ctx = try makeContext()
        let food = FinCategory(name: "Supermercado", colorHex: "#34C759", iconName: "cart.fill")
        let fun = FinCategory(name: "Lazer", colorHex: "#AF52DE", iconName: "gamecontroller.fill")
        ctx.insert(food); ctx.insert(fun)
        MerchantRuleStore.learn(merchant: "Continente", category: food, context: ctx)
        let t = try ExpenseCapture.register(amountText: "5", merchant: "Continente", card: nil, categoryName: "lazer", context: ctx)
        XCTAssertEqual(t.category?.id, fun.id)
    }

    func testInvalidAmountThrows() throws {
        let ctx = try makeContext()
        XCTAssertThrowsError(try ExpenseCapture.register(amountText: "abc", merchant: nil, card: nil, categoryName: nil, context: ctx))
    }

    func testRecurringCatchUpCreatesTransactionsOnce() throws {
        let ctx = try makeContext()
        let rule = RecurringRule(name: "Renda", amountCents: 65000, startDate: dayStart(2026, 1, 1))
        ctx.insert(rule)
        try ctx.save()
        XCTAssertEqual(RecurringService.catchUp(ctx, now: makeDate(2026, 3, 15)), 3)
        XCTAssertEqual(RecurringService.catchUp(ctx, now: makeDate(2026, 3, 20)), 0)
        XCTAssertEqual(RecurringService.catchUp(ctx, now: makeDate(2026, 4, 1)), 1)
        let txs = try ctx.fetch(FetchDescriptor<FinTransaction>())
        XCTAssertEqual(txs.count, 4)
        XCTAssertTrue(txs.allSatisfy { $0.recurringRuleID == rule.id && $0.amountCents == 65000 })
    }

    func testBackupRoundTrip() throws {
        let ctx = try makeContext()
        let cat = FinCategory(name: "Viagens", colorHex: "#007AFF", iconName: "airplane", monthlyBudgetCents: 20000)
        ctx.insert(cat)
        ctx.insert(FinTransaction(amountCents: 4999, kind: .expense, date: makeDate(2026, 2, 3), category: cat, method: .creditCard, note: "Comboio"))
        ctx.insert(FinTransaction(amountCents: 10000, kind: .vaultDeposit, date: makeDate(2026, 2, 4)))
        ctx.insert(Goal(name: "KTM", targetCents: 80000, allocatedCents: 5000))
        let group = SplitGroup(name: "Porto", participants: ["Eu", "Ana"])
        ctx.insert(group)
        ctx.insert(SplitExpense(groupID: group.id, title: "Jantar", amountCents: 3000, payer: "Ana", isEqualSplit: true, shares: ["Eu": 1500, "Ana": 1500]))
        try ctx.save()

        let doc = BackupService.makeDocument(ctx)
        let data = try doc.encoded()
        let decoded = try BackupDocument.decode(data)
        XCTAssertEqual(decoded.transactions.count, 2)
        XCTAssertEqual(decoded.splitExpenses.first?.shares, ["Eu": 1500, "Ana": 1500])

        let ctx2 = try makeContext()
        try BackupService.restore(decoded, into: ctx2)
        let again = BackupService.makeDocument(ctx2)
        XCTAssertEqual(again.categories, decoded.categories)
        XCTAssertEqual(again.transactions.sorted { $0.id.uuidString < $1.id.uuidString },
                       decoded.transactions.sorted { $0.id.uuidString < $1.id.uuidString })
        XCTAssertEqual(again.goals.first?.allocatedCents, 5000)
    }

    func testBackupRejectsForeignJSON() {
        XCTAssertThrowsError(try BackupDocument.decode(Data("{\"a\":1}".utf8)))
    }
}
