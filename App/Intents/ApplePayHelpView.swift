import SwiftUI
import SwiftData

struct ApplePayHelpView: View {
    @Environment(\.openURL) private var openURL
    @Query(sort: \FinTransaction.createdAt, order: .reverse) private var transactions: [FinTransaction]

    private struct Step: Identifiable {
        let id: Int
        let text: AttributedString
    }

    private static func md(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s)) ?? AttributedString(s)
    }

    private static let steps: [Step] = [
        Step(id: 1, text: md("Abre a app **Atalhos** da Apple e toca no separador **Automação**.")),
        Step(id: 2, text: md("Toca em **+** (Nova automação pessoal) e escolhe o evento **Transação** (Carteira / Apple Pay).")),
        Step(id: 3, text: md("Seleciona os cartões a registar e escolhe **Executar imediatamente** (desativa “Notificar ao executar”, se quiseres).")),
        Step(id: 4, text: md("Cria uma automação em branco, toca em **Adicionar ação**, pesquisa **Budget do Fábio** e escolhe **Registar despesa**.")),
        Step(id: 5, text: md("Em **Valor** escolhe a variável *Entrada do atalho → Quantia*; em **Comerciante** → *Comerciante*; em **Cartão** → *Cartão*. A categoria é opcional.")),
        Step(id: 6, text: md("Pronto! Cada pagamento com Apple Pay é registado em segundo plano e fica **por rever** na app.")),
    ]

    var body: some View {
        let captured = transactions.filter { $0.method == .applePay && !$0.merchant.isEmpty }
        let last = captured.first
        let pending = transactions.filter(\.needsReview).count

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Captura Apple Pay").font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)
                    Text("Registo automático após cada pagamento com o iPhone ou o Apple Watch.")
                        .font(.body).foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Badge(last == nil ? "Ainda sem capturas" : "Ativo", style: last == nil ? .neutral : .positive, systemImage: "circle.fill")
                        Spacer()
                        NavigationLink { ReviewQueueView() } label: {
                            Label("Por rever (\(pending))", systemImage: "exclamationmark.bubble")
                        }
                        .buttonStyle(PillButtonStyle())
                    }
                    HStack(spacing: 14) {
                        IconTile(systemName: "creditcard", size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            if let last {
                                Eyebrow("Última captura: \(last.createdAt.formatted(.relative(presentation: .named).locale(PT.locale)))")
                                HStack {
                                    Text(last.merchant).font(.headline).lineLimit(1)
                                    Spacer()
                                    Text("− \(MoneyFormat.string(last.amountCents))").font(.headline.monospacedDigit())
                                }
                            } else {
                                Eyebrow("Última captura")
                                Text("Configura a automação abaixo.").font(.headline)
                            }
                        }
                    }
                }
                .card(padding: 20)
                .accessibilityElement(children: .contain)

                HStack {
                    Eyebrow("Configuração passo a passo")
                    Spacer()
                    Text("\(Self.steps.count) passos").font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 4)

                ForEach(Self.steps) { s in
                    HStack(alignment: .center, spacing: 16) {
                        Text("\(s.id)")
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.primary)
                            .frame(width: 44, height: 44)
                            .background(Theme.primarySoft, in: Circle())
                            .overlay(Circle().stroke(Theme.primary.opacity(0.3), lineWidth: 1))
                            .accessibilityHidden(true)
                        Text(s.text).font(.body).foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .card(padding: 16)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Passo \(s.id). ") + Text(s.text))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Aceita valores como “12,50 €”, “€12.50” ou “EUR 1.234,56”.", systemImage: "eurosign.circle")
                    Label("Quando confirmas a categoria de um comerciante, a app memoriza-a e sugere-a nas próximas compras.", systemImage: "brain")
                    Label("Os nomes dos menus podem variar ligeiramente com a versão do iOS. Os dados nunca saem do iPhone.", systemImage: "lock.shield")
                }
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .card(padding: 16, background: Theme.cardMuted)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 100)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            Button {
                if let url = URL(string: "shortcuts://") { openURL(url) }
            } label: {
                Label("Abrir a app Atalhos", systemImage: "wand.and.stars")
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
