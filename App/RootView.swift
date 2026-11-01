import SwiftUI

enum AppTab: Hashable {
    case home, ledger, budgets, vault, more
}

/// Estado de navegação partilhado (ex.: "Ver tudo" no painel abre o Histórico).
@MainActor
final class AppRouter: ObservableObject {
    @Published var tab: AppTab = .home
    @Published var showNewTransaction = false
}

struct RootView: View {
    @StateObject private var lock = AppLock()
    @StateObject private var router = AppRouter()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.appearance) private var appearance = AppearanceMode.automatic.rawValue

    var body: some View {
        tabs
            .environmentObject(router)
            .tint(Theme.primary)
            .preferredColorScheme((AppearanceMode(rawValue: appearance) ?? .automatic).colorScheme)
            .sheet(isPresented: $router.showNewTransaction) {
                TransactionEditorView(transaction: nil)
            }
            .overlay {
                if lock.isLocked { LockScreen(lock: lock) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { lock.lockIfEnabled() }
            }
    }

    private var tabs: some View {
        TabView(selection: $router.tab) {
            NavigationStack { DashboardView() }
                .tabItem { Label("Início", systemImage: "house") }
                .tag(AppTab.home)
            NavigationStack { LedgerView() }
                .tabItem { Label("Histórico", systemImage: "list.bullet.rectangle.portrait") }
                .tag(AppTab.ledger)
            NavigationStack { BudgetsView() }
                .tabItem { Label("Orçamentos", systemImage: "chart.pie") }
                .tag(AppTab.budgets)
            NavigationStack { VaultView() }
                .tabItem { Label("Cofre", systemImage: "lock.square") }
                .tag(AppTab.vault)
            NavigationStack { MoreView() }
                .tabItem { Label("Mais", systemImage: "ellipsis") }
                .tag(AppTab.more)
        }
    }
}

/// Botão flutuante "+" para nova transação.
struct NewTransactionFAB: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        Button { router.showNewTransaction = true } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Theme.primary, in: Circle())
                .shadow(color: Theme.primary.opacity(0.35), radius: 12, y: 6)
        }
        .accessibilityLabel("Nova transação")
        .padding(.trailing, Theme.margin)
        .padding(.bottom, 12)
    }
}
