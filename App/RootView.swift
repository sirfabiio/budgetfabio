import SwiftUI

struct RootView: View {
    @StateObject private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        tabs
            .overlay {
                if lock.isLocked { LockScreen(lock: lock) }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { lock.lockIfEnabled() }
            }
    }

    private var tabs: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Painel", systemImage: "chart.pie.fill") }
            NavigationStack { LedgerView() }
                .tabItem { Label("Histórico", systemImage: "list.bullet.rectangle") }
            NavigationStack { BudgetsView() }
                .tabItem { Label("Orçamentos", systemImage: "gauge.with.dots.needle.33percent") }
            NavigationStack { VaultView() }
                .tabItem { Label("Cofre", systemImage: "lock.square.stack.fill") }
            NavigationStack { MoreView() }
                .tabItem { Label("Mais", systemImage: "ellipsis.circle") }
        }
    }
}

struct MoreView: View {
    var body: some View {
        List {
            Section("Organização") {
                NavigationLink { CategoriesView() } label: { Label("Categorias", systemImage: "square.grid.2x2") }
                NavigationLink { RecurringView() } label: { Label("Recorrentes", systemImage: "repeat") }
                NavigationLink { GoalsView() } label: { Label("Objetivos", systemImage: "target") }
                NavigationLink { SplitGroupsView() } label: { Label("Divisão de despesas", systemImage: "person.3") }
            }
            Section("Análise e dados") {
                NavigationLink { AnalyticsView() } label: { Label("Análise", systemImage: "chart.xyaxis.line") }
                NavigationLink { ImportExportView() } label: { Label("Importar e exportar", systemImage: "arrow.up.arrow.down.square") }
            }
            Section("Automação") {
                NavigationLink { ApplePayHelpView() } label: { Label("Captura Apple Pay", systemImage: "wave.3.right.circle") }
                NavigationLink { ReviewQueueView() } label: { Label("Por rever", systemImage: "exclamationmark.bubble") }
            }
            Section {
                NavigationLink { SettingsView() } label: { Label("Definições", systemImage: "gearshape") }
            }
        }
        .navigationTitle("Mais")
    }
}
