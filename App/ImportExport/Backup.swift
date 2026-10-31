import Foundation
import SwiftData

/// Cópia de segurança completa em JSON. Valores sempre em cêntimos (inteiros).
struct BackupDocument: Codable, Equatable {
    struct Settings: Codable, Equatable {
        var openingBalanceCents: Int
        var globalMonthlyBudgetCents: Int
    }
    struct Category: Codable, Equatable {
        var id: UUID; var name: String; var kind: String; var colorHex: String; var iconName: String
        var isArchived: Bool; var sortOrder: Int; var monthlyBudgetCents: Int?
    }
    struct Transaction: Codable, Equatable {
        var id: UUID; var amountCents: Int; var kind: String; var date: Date; var categoryID: UUID?
        var method: String; var note: String; var merchant: String; var card: String; var needsReview: Bool
        var createdAt: Date; var recurringRuleID: UUID?; var splitExpenseID: UUID?
    }
    struct MerchantRuleDTO: Codable, Equatable {
        var merchantKey: String; var categoryID: UUID?
    }
    struct GoalDTO: Codable, Equatable {
        var id: UUID; var name: String; var targetCents: Int; var allocatedCents: Int; var deadline: Date?
        var iconName: String; var colorHex: String; var createdAt: Date
    }
    struct RecurringDTO: Codable, Equatable {
        var id: UUID; var name: String; var amountCents: Int; var kind: String; var categoryID: UUID?; var method: String
        var frequency: String; var interval: Int; var startDate: Date; var endDate: Date?; var lastGeneratedDate: Date?
        var isActive: Bool; var notify: Bool
    }
    struct SplitGroupDTO: Codable, Equatable {
        var id: UUID; var name: String; var participants: [String]; var createdAt: Date
    }
    struct SplitExpenseDTO: Codable, Equatable {
        var id: UUID; var groupID: UUID; var title: String; var amountCents: Int; var payer: String; var date: Date
        var isEqualSplit: Bool; var shares: [String: Int]; var isSettlement: Bool
    }

    var format: String = "orcamento-backup"
    var version: Int = 1
    var exportedAt: Date
    var settings: Settings
    var categories: [Category]
    var transactions: [Transaction]
    var merchantRules: [MerchantRuleDTO]
    var goals: [GoalDTO]
    var recurringRules: [RecurringDTO]
    var splitGroups: [SplitGroupDTO]
    var splitExpenses: [SplitExpenseDTO]

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func encoded() throws -> Data { try BackupDocument.encoder().encode(self) }

    static func decode(_ data: Data) throws -> BackupDocument {
        let doc = try decoder().decode(BackupDocument.self, from: data)
        guard doc.format == "orcamento-backup" else { throw BackupError.wrongFormat }
        guard doc.version <= 1 else { throw BackupError.newerVersion }
        return doc
    }
}

enum BackupError: LocalizedError {
    case wrongFormat, newerVersion
    var errorDescription: String? {
        switch self {
        case .wrongFormat: return "Este ficheiro não é uma cópia de segurança desta app."
        case .newerVersion: return "A cópia de segurança foi criada por uma versão mais recente da app."
        }
    }
}

@MainActor
enum BackupService {
    static func makeDocument(_ context: ModelContext) -> BackupDocument {
        let d = UserDefaults.standard
        let categories: [BackupDocument.Category] = fetchAll(FinCategory.self, context).map { c in
            BackupDocument.Category(id: c.id, name: c.name, kind: c.kindRaw, colorHex: c.colorHex, iconName: c.iconName,
                                    isArchived: c.isArchived, sortOrder: c.sortOrder, monthlyBudgetCents: c.monthlyBudgetCents)
        }
        let transactions: [BackupDocument.Transaction] = fetchAll(FinTransaction.self, context).map { t in
            BackupDocument.Transaction(id: t.id, amountCents: t.amountCents, kind: t.kindRaw, date: t.date, categoryID: t.category?.id,
                                       method: t.methodRaw, note: t.note, merchant: t.merchant, card: t.card, needsReview: t.needsReview,
                                       createdAt: t.createdAt, recurringRuleID: t.recurringRuleID, splitExpenseID: t.splitExpenseID)
        }
        let rules: [BackupDocument.MerchantRuleDTO] = fetchAll(MerchantRule.self, context).map { r in
            BackupDocument.MerchantRuleDTO(merchantKey: r.merchantKey, categoryID: r.category?.id)
        }
        let goals: [BackupDocument.GoalDTO] = fetchAll(Goal.self, context).map { g in
            BackupDocument.GoalDTO(id: g.id, name: g.name, targetCents: g.targetCents, allocatedCents: g.allocatedCents,
                                   deadline: g.deadline, iconName: g.iconName, colorHex: g.colorHex, createdAt: g.createdAt)
        }
        let recurring: [BackupDocument.RecurringDTO] = fetchAll(RecurringRule.self, context).map { r in
            BackupDocument.RecurringDTO(id: r.id, name: r.name, amountCents: r.amountCents, kind: r.kindRaw, categoryID: r.category?.id,
                                        method: r.methodRaw, frequency: r.frequencyRaw, interval: r.interval, startDate: r.startDate,
                                        endDate: r.endDate, lastGeneratedDate: r.lastGeneratedDate, isActive: r.isActive, notify: r.notify)
        }
        let groups: [BackupDocument.SplitGroupDTO] = fetchAll(SplitGroup.self, context).map { g in
            BackupDocument.SplitGroupDTO(id: g.id, name: g.name, participants: g.participants, createdAt: g.createdAt)
        }
        let splits: [BackupDocument.SplitExpenseDTO] = fetchAll(SplitExpense.self, context).map { e in
            BackupDocument.SplitExpenseDTO(id: e.id, groupID: e.groupID, title: e.title, amountCents: e.amountCents, payer: e.payer,
                                           date: e.date, isEqualSplit: e.isEqualSplit, shares: e.shares, isSettlement: e.isSettlement)
        }
        let settings = BackupDocument.Settings(openingBalanceCents: d.integer(forKey: SettingsKeys.openingBalance),
                                               globalMonthlyBudgetCents: d.integer(forKey: SettingsKeys.globalBudget))
        return BackupDocument(exportedAt: .now, settings: settings, categories: categories, transactions: transactions,
                              merchantRules: rules, goals: goals, recurringRules: recurring, splitGroups: groups, splitExpenses: splits)
    }

    private static func fetchAll<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    /// Substitui TODOS os dados pelos da cópia de segurança.
    static func restore(_ doc: BackupDocument, into context: ModelContext) throws {
        try context.delete(model: FinTransaction.self)
        try context.delete(model: MerchantRule.self)
        try context.delete(model: RecurringRule.self)
        try context.delete(model: Goal.self)
        try context.delete(model: SplitExpense.self)
        try context.delete(model: SplitGroup.self)
        try context.delete(model: FinCategory.self)
        try context.save()

        var cats: [UUID: FinCategory] = [:]
        for c in doc.categories {
            let m = FinCategory(id: c.id, name: c.name, kind: CategoryKind(rawValue: c.kind) ?? .expense, colorHex: c.colorHex,
                                iconName: c.iconName, isArchived: c.isArchived, sortOrder: c.sortOrder, monthlyBudgetCents: c.monthlyBudgetCents)
            context.insert(m)
            cats[c.id] = m
        }
        for t in doc.transactions {
            let m = FinTransaction(id: t.id, amountCents: t.amountCents, kind: TransactionKind(rawValue: t.kind) ?? .expense, date: t.date,
                                   category: t.categoryID.flatMap { cats[$0] }, method: PaymentMethod(rawValue: t.method) ?? .other,
                                   note: t.note, merchant: t.merchant, card: t.card, needsReview: t.needsReview,
                                   recurringRuleID: t.recurringRuleID, splitExpenseID: t.splitExpenseID)
            m.createdAt = t.createdAt
            context.insert(m)
        }
        for r in doc.merchantRules {
            context.insert(MerchantRule(merchantKey: r.merchantKey, category: r.categoryID.flatMap { cats[$0] }))
        }
        for g in doc.goals {
            let m = Goal(id: g.id, name: g.name, targetCents: g.targetCents, allocatedCents: g.allocatedCents, deadline: g.deadline,
                         iconName: g.iconName, colorHex: g.colorHex)
            m.createdAt = g.createdAt
            context.insert(m)
        }
        for r in doc.recurringRules {
            let m = RecurringRule(id: r.id, name: r.name, amountCents: r.amountCents, kind: TransactionKind(rawValue: r.kind) ?? .expense,
                                  category: r.categoryID.flatMap { cats[$0] }, method: PaymentMethod(rawValue: r.method) ?? .other,
                                  frequency: RecurrenceFrequency(rawValue: r.frequency) ?? .monthly, interval: r.interval,
                                  startDate: r.startDate, endDate: r.endDate, isActive: r.isActive, notify: r.notify)
            m.lastGeneratedDate = r.lastGeneratedDate
            context.insert(m)
        }
        for g in doc.splitGroups {
            let m = SplitGroup(id: g.id, name: g.name, participants: g.participants)
            m.createdAt = g.createdAt
            context.insert(m)
        }
        for e in doc.splitExpenses {
            context.insert(SplitExpense(id: e.id, groupID: e.groupID, title: e.title, amountCents: e.amountCents, payer: e.payer,
                                        date: e.date, isEqualSplit: e.isEqualSplit, shares: e.shares, isSettlement: e.isSettlement))
        }
        let d = UserDefaults.standard
        d.set(doc.settings.openingBalanceCents, forKey: SettingsKeys.openingBalance)
        d.set(doc.settings.globalMonthlyBudgetCents, forKey: SettingsKeys.globalBudget)
        try context.save()
        VaultIntegrity.enforce(context)
    }
}
