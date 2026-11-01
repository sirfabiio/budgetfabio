import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.openingBalance) private var openingBalance: Int = 0
    @AppStorage(SettingsKeys.faceIDEnabled) private var faceIDEnabled = false
    @State private var openingInput: Cents? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Preferências", title: "Definições")

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Saldo inicial à ordem")
                    StyledField(systemImage: "eurosign") {
                        AmountField(title: "", cents: $openingInput)
                    }
                    Text("Saldo da conta à ordem antes da primeira transação registada na app.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow("Segurança")
                    StyledField(systemImage: "faceid") {
                        Toggle("Bloquear com \(AppLock.biometryName)", isOn: Binding(get: { faceIDEnabled }, set: { on in
                            Task {
                                // Confirma a identidade antes de mudar a definição.
                                if await AppLock.authenticate(reason: on ? "Ativar o bloqueio da app" : "Desativar o bloqueio da app") {
                                    faceIDEnabled = on
                                }
                            }
                        }))
                    }
                    Text("Pede autenticação sempre que a app volta do segundo plano.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }

                Label("Todos os dados ficam apenas neste iPhone. Sem contas, sem rede, sem analytics.", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(Theme.textSecondary)
                    .card(padding: 16, background: Theme.cardMuted)
            }
            .padding(.horizontal, Theme.margin)
            .padding(.bottom, 24)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { openingInput = openingBalance }
        .onChange(of: openingInput) { _, v in openingBalance = v ?? 0 }
    }
}
