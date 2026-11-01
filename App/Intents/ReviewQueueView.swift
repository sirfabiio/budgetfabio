import SwiftUI
import SwiftData

/// Transações capturadas automaticamente que ainda não foram confirmadas.
struct ReviewQueueView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<FinTransaction> { $0.needsReview == true }, sort: \FinTransaction.date, order: .reverse)
    private var pending: [FinTransaction]
    @State private var editing: FinTransaction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Apple Pay", title: "Por rever")
                if pending.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal").font(.largeTitle).foregroundStyle(Theme.positive)
                        Text("Nada por rever").font(.headline)
                        Text("As despesas capturadas pelo Apple Pay aparecem aqui.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .card()
                } else {
                    Text("Toca para rever e escolher a categoria, ou confirma diretamente se a sugestão estiver certa.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    RowsCard {
                        ForEach(pending) { t in
                            HStack(spacing: 0) {
                                Button { editing = t } label: { TransactionRow(transaction: t) }
                                    .buttonStyle(.plain)
                                Button { confirm(t) } label: {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Theme.positive, in: Circle())
                                }
                                .padding(.trailing, 16)
                                .accessibilityLabel("Confirmar \(t.title)")
                            }
                            if t.id != pending.last?.id { RowDivider() }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { t in TransactionEditorView(transaction: t) }
    }

    private func confirm(_ t: FinTransaction) {
        t.needsReview = false
        if let c = t.category, !t.merchant.isEmpty {
            MerchantRuleStore.learn(merchant: t.merchant, category: c, context: context)
        }
        try? context.save()
    }
}
