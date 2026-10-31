import Foundation
import SwiftData

@Model
final class FinCategory {
    var id: UUID
    var name: String
    var kindRaw: String
    var colorHex: String
    var iconName: String
    var isArchived: Bool
    var sortOrder: Int
    /// Limite mensal opcional em cêntimos (orçamento por categoria).
    var monthlyBudgetCents: Int?

    init(id: UUID = UUID(), name: String, kind: CategoryKind = .expense, colorHex: String, iconName: String,
         isArchived: Bool = false, sortOrder: Int = 0, monthlyBudgetCents: Int? = nil) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.colorHex = colorHex
        self.iconName = iconName
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.monthlyBudgetCents = monthlyBudgetCents
    }

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }
}

@Model
final class FinTransaction {
    var id: UUID
    /// Sempre positivo; o sentido é dado por `kind`.
    var amountCents: Int
    var kindRaw: String
    var date: Date
    var category: FinCategory?
    var methodRaw: String
    var note: String
    var merchant: String
    var card: String
    /// Capturada automaticamente (Apple Pay) e ainda por confirmar.
    var needsReview: Bool
    var createdAt: Date
    var recurringRuleID: UUID?
    var splitExpenseID: UUID?

    init(id: UUID = UUID(), amountCents: Int, kind: TransactionKind, date: Date = .now, category: FinCategory? = nil,
         method: PaymentMethod = .debitCard, note: String = "", merchant: String = "", card: String = "",
         needsReview: Bool = false, recurringRuleID: UUID? = nil, splitExpenseID: UUID? = nil) {
        self.id = id
        self.amountCents = amountCents
        self.kindRaw = kind.rawValue
        self.date = date
        self.category = category
        self.methodRaw = method.rawValue
        self.note = note
        self.merchant = merchant
        self.card = card
        self.needsReview = needsReview
        self.createdAt = .now
        self.recurringRuleID = recurringRuleID
        self.splitExpenseID = splitExpenseID
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .other }
        set { methodRaw = newValue.rawValue }
    }

    var title: String {
        if !note.isEmpty { return note }
        if !merchant.isEmpty { return merchant }
        if let category { return category.name }
        return kind.label
    }

    var snapshot: TxSnapshot {
        TxSnapshot(id: id, amountCents: amountCents, kind: kind, date: date, categoryID: category?.id,
                   method: method, text: [note, merchant, card, category?.name ?? ""].joined(separator: " "))
    }
}

/// Regra aprendida comerciante → categoria.
@Model
final class MerchantRule {
    var merchantKey: String
    var category: FinCategory?
    var updatedAt: Date

    init(merchantKey: String, category: FinCategory?) {
        self.merchantKey = merchantKey
        self.category = category
        self.updatedAt = .now
    }
}

@Model
final class Goal {
    var id: UUID
    var name: String
    var targetCents: Int
    /// Parte do saldo do cofre afetada a este objetivo.
    var allocatedCents: Int
    var deadline: Date?
    var iconName: String
    var colorHex: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, targetCents: Int, allocatedCents: Int = 0, deadline: Date? = nil,
         iconName: String = "star.fill", colorHex: String = "#5E5CE6") {
        self.id = id
        self.name = name
        self.targetCents = targetCents
        self.allocatedCents = allocatedCents
        self.deadline = deadline
        self.iconName = iconName
        self.colorHex = colorHex
        self.createdAt = .now
    }
}

@Model
final class RecurringRule {
    var id: UUID
    var name: String
    var amountCents: Int
    var kindRaw: String
    var category: FinCategory?
    var methodRaw: String
    var frequencyRaw: String
    var interval: Int
    var startDate: Date
    var endDate: Date?
    var lastGeneratedDate: Date?
    var isActive: Bool
    var notify: Bool

    init(id: UUID = UUID(), name: String, amountCents: Int, kind: TransactionKind = .expense, category: FinCategory? = nil,
         method: PaymentMethod = .directDebit, frequency: RecurrenceFrequency = .monthly, interval: Int = 1,
         startDate: Date, endDate: Date? = nil, isActive: Bool = true, notify: Bool = true) {
        self.id = id
        self.name = name
        self.amountCents = amountCents
        self.kindRaw = kind.rawValue
        self.category = category
        self.methodRaw = method.rawValue
        self.frequencyRaw = frequency.rawValue
        self.interval = interval
        self.startDate = startDate
        self.endDate = endDate
        self.lastGeneratedDate = nil
        self.isActive = isActive
        self.notify = notify
    }

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var method: PaymentMethod {
        get { PaymentMethod(rawValue: methodRaw) ?? .other }
        set { methodRaw = newValue.rawValue }
    }

    var frequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var schedule: RecurrenceSchedule {
        RecurrenceSchedule(frequency: frequency, interval: interval, start: startDate, end: endDate)
    }
}

@Model
final class SplitGroup {
    var id: UUID
    var name: String
    var participants: [String]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, participants: [String]) {
        self.id = id
        self.name = name
        self.participants = participants
        self.createdAt = .now
    }
}

@Model
final class SplitExpense {
    var id: UUID
    var groupID: UUID
    var title: String
    var amountCents: Int
    var payer: String
    var date: Date
    var isEqualSplit: Bool
    /// Partes por pessoa (cêntimos), codificadas em JSON para evitar dicionários no esquema.
    var sharesData: Data
    /// Pagamento entre participantes para saldar dívidas (não é despesa).
    var isSettlement: Bool

    init(id: UUID = UUID(), groupID: UUID, title: String, amountCents: Int, payer: String, date: Date = .now,
         isEqualSplit: Bool, shares: [String: Int], isSettlement: Bool = false) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.amountCents = amountCents
        self.payer = payer
        self.date = date
        self.isEqualSplit = isEqualSplit
        self.sharesData = (try? JSONEncoder().encode(shares)) ?? Data()
        self.isSettlement = isSettlement
    }

    var shares: [String: Int] {
        get { (try? JSONDecoder().decode([String: Int].self, from: sharesData)) ?? [:] }
        set { sharesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var record: SplitRecord {
        SplitRecord(payer: payer, amountCents: amountCents, shares: shares)
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        FinCategory.self, FinTransaction.self, MerchantRule.self, Goal.self,
        RecurringRule.self, SplitGroup.self, SplitExpense.self,
    ]
}
