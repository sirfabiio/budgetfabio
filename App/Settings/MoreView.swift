import SwiftUI
import SwiftData

struct MoreView: View {
    @Query private var groups: [SplitGroup]
    @Query(filter: #Predicate<FinTransaction> { $0.needsReview == true }) private var pending: [FinTransaction]
    @Query(filter: #Predicate<RecurringRule> { $0.isActive == true }) private var activeRules: [RecurringRule]
    @AppStorage(SettingsKeys.faceIDEnabled) private var faceIDEnabled = false
    @AppStorage(SettingsKeys.appearance) private var appearance = AppearanceMode.automatic.rawValue

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: "Preferências", title: "Mais")

                profileCard

                Eyebrow("Gestão financeira").padding(.leading, 4)
                RowsCard {
                    MoreRow(icon: "square.grid.2x2", title: "Categorias") { CategoriesView() }
                    RowDivider()
                    MoreRow(icon: "repeat", title: "Despesas recorrentes",
                            detail: activeRules.isEmpty ? nil : "\(activeRules.count) ativas") { RecurringView() }
                    RowDivider()
                    MoreRow(icon: "target", title: "Objetivos") { GoalsView() }
                    RowDivider()
                    MoreRow(icon: "person.2", title: "Despesas partilhadas e grupos",
                            badge: groups.isEmpty ? nil : "\(groups.count)") { SplitGroupsView() }
                    RowDivider()
                    MoreRow(icon: "chart.xyaxis.line", title: "Análise") { AnalyticsView() }
                }

                Eyebrow("Automação").padding(.leading, 4)
                RowsCard {
                    MoreRow(icon: "creditcard", title: "Captura automática Apple Pay") { ApplePayHelpView() }
                    RowDivider()
                    MoreRow(icon: "exclamationmark.bubble", title: "Por rever",
                            badge: pending.isEmpty ? nil : "\(pending.count)") { ReviewQueueView() }
                }

                Eyebrow("Dados e privacidade").padding(.leading, 4)
                RowsCard {
                    HStack(spacing: 14) {
                        IconTile(systemName: "lock", size: 40)
                        Toggle("Bloqueio com \(AppLock.biometryName)", isOn: Binding(get: { faceIDEnabled }, set: { on in
                            Task {
                                if await AppLock.authenticate(reason: on ? "Ativar o bloqueio da app" : "Desativar o bloqueio da app") {
                                    faceIDEnabled = on
                                }
                            }
                        }))
                        .font(.body.weight(.medium))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    RowDivider()
                    MoreRow(icon: "square.and.arrow.up", title: "Exportar e importar", detail: "CSV, PDF, JSON") { ImportExportView() }
                    RowDivider()
                    MoreRow(icon: "eurosign", title: "Saldo inicial e definições") { SettingsView() }
                }

                Eyebrow("Preferências da aplicação").padding(.leading, 4)
                RowsCard {
                    InfoRow(icon: "eurosign.circle", title: "Moeda principal", value: "Euro (€)")
                    RowDivider()
                    InfoRow(icon: "calendar", title: "Formato de data", value: "DD/MM/AAAA")
                    RowDivider()
                    HStack(spacing: 14) {
                        IconTile(systemName: "paintpalette", size: 40)
                        Text("Aparência").font(.body.weight(.medium))
                        Spacer()
                        Picker("Aparência", selection: $appearance) {
                            ForEach(AppearanceMode.allCases) { Text($0.label).tag($0.rawValue) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                }

                VStack(spacing: 4) {
                    Text("Budget do Fábio v\(version)")
                    Text("Dados guardados apenas neste iPhone · sem rede")
                }
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var profileCard: some View {
        HStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("Budget do Fábio").font(.title3.weight(.semibold))
                Text("Finanças pessoais, 100% offline").font(.subheadline).foregroundStyle(Theme.textSecondary)
                Badge("Plano pessoal • Local", style: .neutral, systemImage: "circle.fill")
            }
            Spacer()
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}

private struct MoreRow<Destination: View>: View {
    var icon: String
    var title: String
    var detail: String? = nil
    var badge: String? = nil
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                IconTile(systemName: icon, size: 40)
                Text(title).font(.body.weight(.medium)).foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if let detail { Text(detail).font(.subheadline).foregroundStyle(Theme.textSecondary) }
                if let badge { Badge(badge, style: .primary) }
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct InfoRow: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: 14) {
            IconTile(systemName: icon, size: 40)
            Text(title).font(.body.weight(.medium))
            Spacer()
            Text(value).font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
