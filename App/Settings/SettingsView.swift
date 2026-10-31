import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0
    @AppStorage(SettingsKeys.faceIDEnabled) private var faceIDEnabled = false
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
            Section {
                Toggle("Bloquear com \(AppLock.biometryName)", isOn: Binding(get: { faceIDEnabled }, set: { on in
                    Task {
                        // Confirma a identidade antes de mudar a definição.
                        if await AppLock.authenticate(reason: on ? "Ativar o bloqueio da app" : "Desativar o bloqueio da app") {
                            faceIDEnabled = on
                        }
                    }
                }))
            } header: {
                Text("Segurança")
            } footer: {
                Text("Pede autenticação sempre que a app volta do segundo plano.")
            }
            Section("Privacidade") {
                Label("Todos os dados ficam apenas neste iPhone. Sem contas, sem rede, sem analytics.", systemImage: "lock.shield")
                    .font(.footnote)
            }
        }
        .navigationTitle("Definições")
    }
}
