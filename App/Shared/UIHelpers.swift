import SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0x8E8E93
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: 1)
    }
}

enum Palette {
    static let colors = ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#30B0C7",
                         "#007AFF", "#5856D6", "#AF52DE", "#FF2D55", "#A2845E", "#8E8E93"]
    static let icons = ["cart.fill", "fork.knife", "car.fill", "fuelpump.fill", "house.fill", "bolt.fill",
                        "cross.case.fill", "gamecontroller.fill", "bag.fill", "book.fill", "airplane", "gift.fill",
                        "repeat", "wrench.and.screwdriver.fill", "pawprint.fill", "tshirt.fill", "phone.fill", "wifi",
                        "banknote.fill", "briefcase.fill", "arrow.uturn.backward", "plus.circle.fill", "heart.fill",
                        "graduationcap.fill", "dumbbell.fill", "film.fill", "music.note", "tram.fill", "star.fill",
                        "ellipsis.circle.fill"]
}

struct CategoryIcon: View {
    var iconName: String
    var colorHex: String
    var size: CGFloat = 32

    var body: some View {
        IconTile(systemName: iconName, colorHex: colorHex, size: size)
    }
}

/// Campo de valor monetário que aceita "12,50", "12.50", "12,50 €".
struct AmountField: View {
    var title: String
    @Binding var cents: Cents?
    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0,00", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .onChange(of: text) { _, new in
                    cents = AmountParser.parseCents(new).map { abs($0) }
                }
            Text("€").foregroundStyle(.secondary)
        }
        .onAppear {
            if let cents { text = MoneyFormat.plainString(cents) }
        }
        .onChange(of: cents) { _, new in
            if AmountParser.parseCents(text) != new {
                text = new.map { MoneyFormat.plainString($0) } ?? ""
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

struct MoneyText: View {
    var cents: Cents
    var kind: TransactionKind? = nil

    var body: some View {
        Text(display)
            .font(.body.weight(.semibold).monospacedDigit())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var display: String {
        switch kind {
        case .income?, .vaultWithdrawal?: return "+ " + MoneyFormat.string(cents)
        case .expense?, .vaultDeposit?: return "− " + MoneyFormat.string(cents)
        default: return MoneyFormat.string(cents)
        }
    }

    private var color: Color {
        switch kind {
        case .income?: return Theme.positive
        default: return Theme.textPrimary
        }
    }
}

extension BudgetState {
    var color: Color {
        switch self {
        case .normal: return Theme.primary
        case .nearLimit: return Theme.warning
        case .exceeded: return Theme.danger
        }
    }
}

struct BudgetBar: View {
    var status: BudgetStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThinProgress(fraction: status.fraction, color: status.state.color)
            HStack {
                Text("\(MoneyFormat.string(status.spent)) de \(MoneyFormat.string(status.limit))")
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(status.remaining >= 0 ? "Resta \(MoneyFormat.string(status.remaining))" : "Excedido em \(MoneyFormat.string(-status.remaining))")
                    .foregroundStyle(status.state == .exceeded ? Theme.danger : Theme.textPrimary)
            }
            .font(.caption.monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Gasto \(MoneyFormat.string(status.spent)) de \(MoneyFormat.string(status.limit)). \(status.state.label).")
    }
}

enum SettingsKeys {
    static let openingBalance = "openingBalanceCents"
    static let globalBudget = "globalMonthlyBudgetCents"
    static let faceIDEnabled = "faceIDEnabled"
    static let notificationsEnabled = "notificationsEnabled"
    static let seeded = "didSeedCategories"
    static let appearance = "appearanceMode"
}
