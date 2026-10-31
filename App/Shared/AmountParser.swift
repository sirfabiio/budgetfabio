import Foundation

/// Converte texto livre ("12,50 €", "€12.50", "EUR 1.234,56", "-3,2") em cêntimos.
/// Não usa Double: os dígitos são lidos diretamente para inteiros.
enum AmountParser {
    static func parseCents(_ raw: String) -> Cents? {
        var negative = false
        var chars: [Character] = []
        for ch in raw {
            if ch.isASCII, ch.isNumber {
                chars.append(ch)
            } else if ch == "," || ch == "." {
                chars.append(ch)
            } else if ch == "-" || ch == "−" {
                if chars.isEmpty { negative = true }
            }
            // Ignora símbolos de moeda, letras e espaços (incluindo espaços não separáveis).
        }
        // Remove separadores nas pontas ("12.50." ou ".")
        while let last = chars.last, last == "," || last == "." { chars.removeLast() }
        while let first = chars.first, first == "," || first == "." {
            // ",50" é válido como 0,50
            if chars.count > 1, chars[1].isNumber { chars.insert("0", at: 0); break }
            chars.removeFirst()
        }
        guard chars.contains(where: { $0.isNumber }) else { return nil }

        let separators = chars.enumerated().filter { $0.element == "," || $0.element == "." }
        var decimalIndex: Int? = nil

        if let lastSep = separators.last {
            let distinct = Set(separators.map { $0.element })
            let digitsAfter = chars.count - lastSep.offset - 1
            if distinct.count == 2 {
                // Ambos presentes: o último é o separador decimal.
                decimalIndex = lastSep.offset
            } else {
                let count = separators.count
                if count == 1 {
                    // Um único separador: decimal se tiver 1 ou 2 casas, milhares se tiver 3.
                    decimalIndex = digitsAfter == 3 ? nil : lastSep.offset
                } else {
                    // Vários do mesmo tipo: são separadores de milhares.
                    decimalIndex = nil
                }
            }
        }

        var integerDigits = ""
        var fractionDigits = ""
        for (i, ch) in chars.enumerated() {
            guard ch.isNumber else { continue }
            if let d = decimalIndex, i > d {
                fractionDigits.append(ch)
            } else {
                integerDigits.append(ch)
            }
        }
        if fractionDigits.count > 2 {
            // Arredondamento a meio para cima no terceiro dígito.
            let third = fractionDigits[fractionDigits.index(fractionDigits.startIndex, offsetBy: 2)]
            fractionDigits = String(fractionDigits.prefix(2))
            if let d = third.wholeNumberValue, d >= 5 {
                return finish(integer: integerDigits, fraction: fractionDigits, negative: negative, roundUp: true)
            }
        }
        return finish(integer: integerDigits, fraction: fractionDigits, negative: negative, roundUp: false)
    }

    private static func finish(integer: String, fraction: String, negative: Bool, roundUp: Bool) -> Cents? {
        let intPart = integer.isEmpty ? "0" : integer
        guard intPart.count <= 13, let euros = Int(intPart) else { return nil }
        let frac = fraction.padding(toLength: 2, withPad: "0", startingAt: 0)
        guard let cents = Int(frac) else { return nil }
        var total = euros * 100 + cents + (roundUp ? 1 : 0)
        if negative { total = -total }
        return total
    }
}
