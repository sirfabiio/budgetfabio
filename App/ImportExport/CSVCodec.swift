import Foundation

/// Linha de CSV independente do SwiftData.
struct CSVRow: Equatable {
    var date: Date
    var kind: TransactionKind
    var amountCents: Cents
    var category: String
    var method: PaymentMethod
    var note: String
    var merchant: String
    var needsReview: Bool
}

struct CSVImportError: Equatable, Identifiable {
    var line: Int
    var message: String
    var id: Int { line }
}

struct CSVImportResult: Equatable {
    var rows: [CSVRow]
    var errors: [CSVImportError]
}

/// CSV com `;` como separador (compatível com o Excel em pt-PT), valores "1234,50" e datas AAAA-MM-DD.
enum CSVCodec {
    static let delimiter: Character = ";"
    static let header = ["data", "tipo", "valor", "categoria", "metodo", "descricao", "comerciante", "por_rever"]

    private static func dateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    static func kindCode(_ kind: TransactionKind) -> String {
        switch kind {
        case .income: return "receita"
        case .expense: return "despesa"
        case .vaultDeposit: return "para_cofre"
        case .vaultWithdrawal: return "do_cofre"
        }
    }

    static func kind(from code: String) -> TransactionKind? {
        switch TextNormalizer.key(code).replacingOccurrences(of: " ", with: "_") {
        case "receita", "income": return .income
        case "despesa", "expense": return .expense
        case "para_cofre", "vaultdeposit": return .vaultDeposit
        case "do_cofre", "vaultwithdrawal": return .vaultWithdrawal
        default: return nil
        }
    }

    // MARK: Exportar

    static func encode(_ rows: [CSVRow]) -> String {
        let df = dateFormatter()
        var lines = [header.joined(separator: String(delimiter))]
        for r in rows {
            let fields = [
                df.string(from: r.date),
                kindCode(r.kind),
                MoneyFormat.plainString(r.amountCents),
                r.category,
                r.method.label,
                r.note,
                r.merchant,
                r.needsReview ? "sim" : "nao",
            ]
            lines.append(fields.map(escape).joined(separator: String(delimiter)))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func escape(_ field: String) -> String {
        if field.contains(delimiter) || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    // MARK: Importar

    /// Divide o texto em registos e campos (RFC 4180, com aspas e quebras de linha dentro de aspas).
    /// Devolve cada registo com o número da linha onde começa.
    static func parseRecords(_ text: String, delimiter: Character = CSVCodec.delimiter) -> [(line: Int, fields: [String])] {
        var records: [(line: Int, fields: [String])] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var line = 1
        var recordLine = 1
        var chars = Array(text)
        if chars.first == "\u{FEFF}" { chars.removeFirst() }
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\""); i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    if c == "\n" || c == "\r\n" { line += 1 }
                    field.append(c)
                }
            } else if c == "\"" && field.isEmpty {
                inQuotes = true
            } else if c == delimiter {
                fields.append(field); field = ""
            } else if c == "\n" || c == "\r" || c == "\r\n" {
                fields.append(field); field = ""
                records.append((recordLine, fields)); fields = []
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                line += 1
                recordLine = line
            } else {
                field.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !fields.isEmpty {
            fields.append(field)
            records.append((recordLine, fields))
        }
        return records.filter { !($0.1.count == 1 && $0.1[0].trimmingCharacters(in: .whitespaces).isEmpty) }
    }

    static func decode(_ text: String) -> CSVImportResult {
        let records = parseRecords(text)
        guard let first = records.first else {
            return CSVImportResult(rows: [], errors: [CSVImportError(line: 1, message: "Ficheiro vazio.")])
        }
        let headerKeys = first.fields.map { TextNormalizer.key($0).replacingOccurrences(of: " ", with: "_") }
        var index: [String: Int] = [:]
        for (i, k) in headerKeys.enumerated() { index[k] = i }
        let required = ["data", "tipo", "valor"]
        let missing = required.filter { index[$0] == nil }
        if !missing.isEmpty {
            return CSVImportResult(rows: [], errors: [CSVImportError(line: first.line, message: "Cabeçalho inválido: faltam as colunas \(missing.joined(separator: ", ")).")])
        }

        let df = dateFormatter()
        let altDF = dateFormatter()
        altDF.dateFormat = "dd/MM/yyyy"
        var rows: [CSVRow] = []
        var errors: [CSVImportError] = []

        for record in records.dropFirst() {
            func value(_ key: String) -> String {
                guard let i = index[key], i < record.fields.count else { return "" }
                return record.fields[i].trimmingCharacters(in: .whitespaces)
            }
            var problems: [String] = []
            let dateText = value("data")
            let date = df.date(from: dateText) ?? altDF.date(from: dateText)
            if date == nil { problems.append("data inválida \"\(dateText)\" (use AAAA-MM-DD)") }
            let parsedKind = CSVCodec.kind(from: value("tipo"))
            if parsedKind == nil { problems.append("tipo inválido \"\(value("tipo"))\" (receita, despesa, para_cofre, do_cofre)") }
            let amount = AmountParser.parseCents(value("valor"))
            if amount == nil { problems.append("valor inválido \"\(value("valor"))\"") }
            else if amount! <= 0 { problems.append("o valor tem de ser positivo") }
            let methodText = value("metodo")
            let method: PaymentMethod? = methodText.isEmpty ? .other : PaymentMethod.fromLabel(methodText)
            if method == nil { problems.append("método de pagamento desconhecido \"\(methodText)\"") }
            let reviewText = TextNormalizer.key(value("por_rever"))

            if problems.isEmpty, let date, let parsedKind, let amount, let method {
                rows.append(CSVRow(date: date, kind: parsedKind, amountCents: amount, category: value("categoria"), method: method,
                                   note: value("descricao"), merchant: value("comerciante"),
                                   needsReview: ["sim", "s", "true", "1", "yes"].contains(reviewText)))
            } else {
                errors.append(CSVImportError(line: record.line, message: problems.joined(separator: "; ")))
            }
        }
        return CSVImportResult(rows: rows, errors: errors)
    }
}
