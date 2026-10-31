import SwiftUI
import SwiftData

/// Transações capturadas automaticamente que ainda não foram confirmadas.
struct ReviewQueueView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<FinTransaction> { $0.needsReview == true }, sort: \FinTransaction.date, order: .reverse)
    private var pending: [FinTransaction]
    @State private var editing: FinTransaction?

    var body: some View {
        List {
            if pending.isEmpty {
                ContentUnavailableView("Nada por rever", systemImage: "checkmark.seal",
                                       description: Text("As despesas capturadas pelo Apple Pay aparecem aqui."))
            }
            ForEach(pending) { t in
                Button { editing = t } label: { TransactionRow(transaction: t) }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            confirm(t)
                        } label: { Label("Confirmar", systemImage: "checkmark") }
                            .tint(.green)
                    }
            }
        }
        .navigationTitle("Por rever")
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
