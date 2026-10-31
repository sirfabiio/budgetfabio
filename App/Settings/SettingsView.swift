import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0
    @State private var openingInput: Cents? = nil

    var body: some View {
        Form {
            Section {
                AmountField(title: "Saldo inicial à ordem", cents: $openingInput)
                    .onAppear { openingInput = openingBalance }
                    .onChange(of: openingInput) { _, v in openingBalance = v ?? 0 }
            } footer: {
                Text("Saldo da conta à ordem antes da primeira transação registada na app.")
            }
            Section("Privacidade") {
                Label("Todos os dados ficam apenas neste iPhone. Sem contas, sem rede, sem analytics.", systemImage: "lock.shield")
                    .font(.footnote)
            }
        }
        .navigationTitle("Definições")
    }
}
