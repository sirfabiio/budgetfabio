import SwiftUI
import LocalAuthentication

/// Extra: bloqueio da app com Face ID / código do iPhone (sem capabilities pagas).
@MainActor
final class AppLock: ObservableObject {
    @Published var isLocked: Bool

    init() {
        isLocked = UserDefaults.standard.bool(forKey: SettingsKeys.faceIDEnabled)
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKeys.faceIDEnabled) }

    func lockIfEnabled() {
        if isEnabled { isLocked = true }
    }

    func unlock() {
        Task {
            if await Self.authenticate(reason: "Desbloquear as tuas finanças") { isLocked = false }
        }
    }

    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return false }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }

    static var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "código do iPhone"
        }
    }
}

struct LockScreen: View {
    @ObservedObject var lock: AppLock

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Image("AppLogo")
                    .resizable()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityHidden(true)
                Text("Budget do Fábio bloqueado").font(.title2.bold())
                Button {
                    lock.unlock()
                } label: {
                    Label("Desbloquear com \(AppLock.biometryName)", systemImage: "faceid")
                        .padding(.horizontal)
                }
                .buttonStyle(PillButtonStyle(filled: true))
            }
        }
        .onAppear { lock.unlock() }
    }
}
