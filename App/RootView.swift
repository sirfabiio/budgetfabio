import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Painel", systemImage: "chart.pie.fill") }
            NavigationStack { LedgerView() }
                .tabItem { Label("Histórico", systemImage: "list.bullet.rectangle") }
            NavigationStack { BudgetsView() }
                .tabItem { Label("Orçamentos", systemImage: "gauge.with.dots.needle.33percent") }
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
            }
            Section("Definições") {
                NavigationLink { SettingsView() } label: { Label("Definições", systemImage: "gearshape") }
            }
        }
        .navigationTitle("Mais")
    }
}
