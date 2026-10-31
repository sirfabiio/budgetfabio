import SwiftUI

struct ApplePayHelpView: View {
    private struct Step: Identifiable {
        let id: Int
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(id: 1, title: "Abre a app Atalhos", detail: "Vem instalada no iPhone. Se a apagaste, reinstala-a a partir da App Store."),
        Step(id: 2, title: "Separador “Automação”", detail: "Toca em “Automação” na parte de baixo e depois em “+” (ou “Nova automação”)."),
        Step(id: 3, title: "Escolhe “Transação”", detail: "Na lista de automações pessoais, escolhe “Transação” (Carteira/Apple Pay)."),
        Step(id: 4, title: "Seleciona os cartões", detail: "Marca os cartões da Carteira que queres registar. Deixa a categoria de comerciante como “Qualquer”."),
        Step(id: 5, title: "“Executar imediatamente”", detail: "Escolhe “Executar imediatamente” (e desativa “Notificar ao executar”, se quiseres) para que corra sem pedir confirmação."),
        Step(id: 6, title: "Nova ação em branco", detail: "Toca em “Nova automação em branco” (ou “Criar novo atalho”) e depois em “Adicionar ação”."),
        Step(id: 7, title: "Adiciona “Registar despesa”", detail: "Pesquisa “Orçamento” e escolhe a ação “Registar despesa”."),
        Step(id: 8, title: "Liga as variáveis", detail: "Toca em “Valor” e escolhe a variável “Atalho: Entrada” → “Quantia”. Faz o mesmo para “Comerciante” (→ Comerciante) e “Cartão” (→ Nome do cartão ou Cartão). A categoria é opcional."),
        Step(id: 9, title: "Guarda", detail: "Toca em “OK”. A partir de agora, cada pagamento com Apple Pay é registado em segundo plano e fica marcado “por rever”."),
    ]

    var body: some View {
        List {
            Section {
                Label("A app aceita valores como “12,50 €”, “€12.50” ou “EUR 1.234,56”.", systemImage: "eurosign.circle")
                Label("Quando confirmares a categoria de um comerciante, a app memoriza-a e sugere-a nas próximas compras.", systemImage: "brain")
            }
            Section("Passo a passo") {
                ForEach(steps) { s in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(s.id)")
                            .font(.headline.monospacedDigit())
                            .frame(width: 28, height: 28)
                            .background(Color.accentColor.opacity(0.15), in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.title).font(.headline)
                            Text(s.detail).font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Passo \(s.id). \(s.title). \(s.detail)")
                }
            }
            Section {
                Text("Os nomes exatos dos menus podem variar ligeiramente com a versão do iOS. A automação corre no iPhone e os dados nunca saem do dispositivo.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink { ReviewQueueView() } label: { Label("Ver transações por rever", systemImage: "exclamationmark.bubble") }
            }
        }
        .navigationTitle("Captura Apple Pay")
    }
}
