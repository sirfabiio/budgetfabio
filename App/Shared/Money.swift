import Foundation

/// Valores monetários são sempre inteiros em cêntimos.
typealias Cents = Int

enum PT {
    static let locale = Locale(identifier: "pt_PT")

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = locale
        cal.firstWeekday = 2
        cal.timeZone = .current
        return cal
    }
}

enum MoneyFormat {
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = PT.locale
        f.currencyCode = "EUR"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    private static let plain: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = PT.locale
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// "1234,50 €" no formato pt-PT.
    static func string(_ cents: Cents) -> String {
        let value = NSDecimalNumber(decimal: Decimal(cents) / 100)
        return formatter.string(from: value) ?? "\(cents / 100),\(String(format: "%02d", abs(cents % 100))) €"
    }

    /// "1234,50" sem símbolo (para campos de edição e CSV).
    static func plainString(_ cents: Cents) -> String {
        let sign = cents < 0 ? "-" : ""
        let a = abs(cents)
        return "\(sign)\(a / 100),\(String(format: "%02d", a % 100))"
    }

    /// Valor em euros apenas para gráficos (nunca para armazenamento).
    static func chartValue(_ cents: Cents) -> Double {
        Double(cents) / 100
    }
}

enum DateFormat {
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(PT.locale))
    }

    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(PT.locale))
    }

    static func month(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(PT.locale)).capitalized(with: PT.locale)
    }

    static func shortMonth(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).locale(PT.locale))
    }
}
