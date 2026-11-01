import SwiftUI

// MARK: - Contentores

struct CardModifier: ViewModifier {
    var padding: CGFloat = 20
    var background: Color = Theme.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.outline, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 20, background: Color = Theme.card) -> some View {
        modifier(CardModifier(padding: padding, background: background))
    }

    /// Fundo do ecrã em todas as vistas principais.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

/// Cartão com linhas separadas por divisórias (equivalente a uma secção agrupada).
struct RowsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous).stroke(Theme.outline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}

struct RowDivider: View {
    var inset: CGFloat = 72
    var body: some View {
        Rectangle().fill(Theme.outline).frame(height: 1).padding(.leading, inset)
    }
}

// MARK: - Texto

/// Rótulo em maiúsculas com espaçamento ("TOTAL ORÇAMENTADO").
struct Eyebrow: View {
    var text: String
    var color: Color = Theme.textSecondary

    init(_ text: String, color: Color = Theme.textSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased(with: PT.locale))
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

/// Valor monetário de destaque.
struct HeroAmount: View {
    var cents: Cents
    var font: Font = .system(.largeTitle, design: .default).weight(.bold)
    var color: Color = Theme.textPrimary
    var prefix: String = ""

    var body: some View {
        Text(prefix + MoneyFormat.string(cents))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

/// Cabeçalho de ecrã: rótulo superior opcional, título grande e ação à direita.
struct ScreenHeader<Trailing: View>: View {
    var eyebrow: String?
    var title: String
    @ViewBuilder var trailing: Trailing

    init(eyebrow: String? = nil, title: String, @ViewBuilder trailing: () -> Trailing) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if let eyebrow { Eyebrow(eyebrow) }
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.top, 8)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(eyebrow: String? = nil, title: String) {
        self.init(eyebrow: eyebrow, title: title) { EmptyView() }
    }
}

struct SectionTitle<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
        .padding(.top, 8)
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(_ title: String) { self.init(title) { EmptyView() } }
}

// MARK: - Ícones, badges, progresso

/// Ícone de categoria num quadrado arredondado.
struct IconTile: View {
    var systemName: String
    var colorHex: String? = nil
    var size: CGFloat = 44

    var body: some View {
        let tint = colorHex.map { Color(hex: $0) } ?? Theme.textPrimary
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(colorHex.map { Color(hex: $0).opacity(0.14) } ?? Theme.tile,
                        in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .accessibilityHidden(true)
    }
}

enum BadgeStyle {
    case neutral, primary, positive, warning, danger

    var foreground: Color {
        switch self {
        case .neutral: return Theme.textSecondary
        case .primary: return Theme.primary
        case .positive: return Theme.positive
        case .warning: return Theme.warning
        case .danger: return Theme.danger
        }
    }

    var background: Color {
        switch self {
        case .neutral: return Theme.tile
        case .primary: return Theme.primarySoft
        case .positive: return Theme.positiveSoft
        case .warning: return Theme.warningSoft
        case .danger: return Theme.dangerSoft
        }
    }
}

struct Badge: View {
    var text: String
    var style: BadgeStyle = .neutral
    var systemImage: String? = nil

    init(_ text: String, style: BadgeStyle = .neutral, systemImage: String? = nil) {
        self.text = text
        self.style = style
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).imageScale(.small) }
            Text(text)
        }
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(style.foreground)
        .background(style.background, in: Capsule())
    }
}

struct ThinProgress: View {
    var fraction: Double
    var color: Color = Theme.primary
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(color)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Anel de progresso (usado no painel e nos mini-cartões).
struct ProgressRing: View {
    var fraction: Double
    var color: Color = Theme.primary
    var lineWidth: CGFloat = 14

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, fraction)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityHidden(true)
    }
}

/// Avatar com iniciais.
struct InitialsAvatar: View {
    var name: String
    var highlighted = false
    var size: CGFloat = 36

    var body: some View {
        Text(Self.initials(name))
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(highlighted ? Theme.onInk : Theme.textPrimary)
            .frame(width: size, height: size)
            .background(highlighted ? Theme.ink : Theme.tile, in: Circle())
            .overlay(Circle().stroke(Theme.card, lineWidth: 2))
            .accessibilityHidden(true)
    }

    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased(with: PT.locale)
    }
}

// MARK: - Botões

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.primary.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4),
                        in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous))
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.card.opacity(configuration.isPressed ? 0.6 : 1),
                        in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous).stroke(Theme.outline, lineWidth: 1))
    }
}

/// Botão compacto em cápsula ("+ Nova", "Alocar").
struct PillButtonStyle: ButtonStyle {
    var filled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(filled ? Color.white : Theme.primary)
            .background(filled ? Theme.primary : Theme.card, in: Capsule())
            .overlay(Capsule().stroke(filled ? Color.clear : Theme.outline, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Botão redondo só com ícone (sempre com rótulo de acessibilidade).
struct CircleIconButton: View {
    var systemName: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Theme.card, in: Circle())
                .overlay(Circle().stroke(Theme.outline, lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}

/// Chip de filtro/seleção.
struct ChipLabel: View {
    var title: String
    var systemImage: String? = nil
    var selected = false
    var showsChevron = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title).lineLimit(1)
            if showsChevron { Image(systemName: "chevron.down").imageScale(.small) }
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .foregroundStyle(selected ? Theme.onInk : Theme.textPrimary)
        .background(selected ? Theme.ink : Theme.card, in: Capsule())
        .overlay(Capsule().stroke(selected ? Color.clear : Theme.outline, lineWidth: 1))
    }
}

/// Chip de escolha no editor (borda azul quando selecionado).
struct SelectChip: View {
    var title: String
    var systemImage: String?
    var colorHex: String? = nil
    var selected: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(colorHex.map { Color(hex: $0) } ?? (selected ? Theme.primary : Theme.textSecondary))
            }
            Text(title).lineLimit(1)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(selected ? Theme.primary : Theme.textPrimary)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(selected ? Theme.primarySoft : Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selected ? Theme.primary : Theme.outline, lineWidth: selected ? 1.5 : 1))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Seletor de mês em cápsula ("Outubro 2026 ⌄").
struct MonthMenu: View {
    @Binding var month: Date
    var months = 24
    var filled = false

    var body: some View {
        let cal = PT.calendar
        let current = BalanceCalculator.monthInterval(containing: .now).start
        Menu {
            ForEach(0..<months, id: \.self) { i in
                let m = cal.date(byAdding: .month, value: -i, to: current) ?? current
                Button(DateFormat.month(m)) { month = m }
            }
        } label: {
            ChipLabel(title: DateFormat.month(month), selected: filled, showsChevron: true)
        }
        .accessibilityLabel("Mês: \(DateFormat.month(month))")
    }
}

/// Campo de texto com o estilo dos ecrãs (fundo suave, cantos arredondados).
struct StyledField<Content: View>: View {
    var systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage).foregroundStyle(Theme.textSecondary).accessibilityHidden(true)
            content
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(Theme.cardMuted, in: RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.fieldRadius, style: .continuous).stroke(Theme.outline, lineWidth: 1))
    }
}

/// Cabeçalho de folha (sheet): rótulo, título e botão fechar.
struct SheetHeader: View {
    var eyebrow: String?
    var title: String
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow { Eyebrow(eyebrow) }
                Text(title).font(.title2.weight(.bold)).foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Theme.tile, in: Circle())
            }
            .accessibilityLabel("Fechar")
        }
    }
}

// MARK: - Datas relativas

extension DateFormat {
    /// "set" → "Set"
    static func monthAbbrev(_ date: Date) -> String {
        let s = date.formatted(.dateTime.month(.abbreviated).locale(PT.locale)).replacingOccurrences(of: ".", with: "")
        return s.prefix(1).uppercased(with: PT.locale) + s.dropFirst()
    }

    /// "Hoje, 13:45", "Ontem, 09:15" ou "30 Set".
    static func rowDate(_ date: Date) -> String {
        let cal = PT.calendar
        let time = date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(PT.locale))
        if cal.isDateInToday(date) { return "Hoje, \(time)" }
        if cal.isDateInYesterday(date) { return "Ontem, \(time)" }
        let day = cal.component(.day, from: date)
        if cal.component(.year, from: date) == cal.component(.year, from: .now) {
            return "\(day) \(monthAbbrev(date))"
        }
        return "\(day) \(monthAbbrev(date)) \(cal.component(.year, from: date))"
    }

    /// "HOJE, 24 OUTUBRO", "ONTEM, 23 OUTUBRO", "30 SETEMBRO 2026"
    static func dayHeader(_ date: Date) -> String {
        let cal = PT.calendar
        let dm = date.formatted(.dateTime.day().month(.wide).locale(PT.locale))
        let text: String
        if cal.isDateInToday(date) { text = "Hoje, \(dm)" }
        else if cal.isDateInYesterday(date) { text = "Ontem, \(dm)" }
        else { text = date.formatted(.dateTime.day().month(.wide).year().locale(PT.locale)) }
        return text.replacingOccurrences(of: " de ", with: " ").uppercased(with: PT.locale)
    }

    /// "Dezembro 2026"
    static func monthYear(_ date: Date) -> String { month(date) }
}
