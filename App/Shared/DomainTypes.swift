import Foundation

enum TransactionKind: String, Codable, CaseIterable, Identifiable {
    case income
    case expense
    /// Saldo à ordem → cofre. Não conta como despesa.
    case vaultDeposit
    /// Cofre → saldo à ordem. Não conta como receita.
    case vaultWithdrawal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .income: return "Receita"
        case .expense: return "Despesa"
        case .vaultDeposit: return "Transferência para o cofre"
        case .vaultWithdrawal: return "Transferência do cofre"
        }
    }

    var isTransfer: Bool { self == .vaultDeposit || self == .vaultWithdrawal }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case applePay
    case debitCard
    case creditCard
    case cash
    case mbway
    case bankTransfer
    case directDebit
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .debitCard: return "Cartão de débito"
        case .creditCard: return "Cartão de crédito"
        case .cash: return "Dinheiro"
        case .mbway: return "MB WAY"
        case .bankTransfer: return "Transferência bancária"
        case .directDebit: return "Débito direto"
        case .other: return "Outro"
        }
    }

    static func fromLabel(_ text: String) -> PaymentMethod? {
        let key = TextNormalizer.key(text)
        return allCases.first { TextNormalizer.key($0.label) == key || $0.rawValue.lowercased() == key.replacingOccurrences(of: " ", with: "") }
    }
}

enum CategoryKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income
    var id: String { rawValue }
    var label: String { self == .expense ? "Despesa" : "Receita" }
}

/// Representação imutável de uma transação, usada pela lógica de domínio pura.
struct TxSnapshot: Equatable {
    var id: UUID
    var amountCents: Cents
    var kind: TransactionKind
    var date: Date
    var categoryID: UUID?
    var method: PaymentMethod
    var text: String

    init(id: UUID = UUID(), amountCents: Cents, kind: TransactionKind, date: Date,
         categoryID: UUID? = nil, method: PaymentMethod = .other, text: String = "") {
        self.id = id
        self.amountCents = amountCents
        self.kind = kind
        self.date = date
        self.categoryID = categoryID
        self.method = method
        self.text = text
    }
}

enum TextNormalizer {
    /// Minúsculas, sem acentos, só letras/dígitos/espaços simples.
    static func key(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: PT.locale).lowercased()
        let mapped = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }
}
