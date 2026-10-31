import SwiftUI
import SwiftData

@main
struct OrcamentoApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, PT.locale)
                .environment(\.calendar, PT.calendar)
        }
        .modelContainer(Persistence.shared)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                AppLifecycle.didBecomeActive(Persistence.shared.mainContext)
            }
        }
    }
}

@MainActor
enum AppLifecycle {
    static func didBecomeActive(_ context: ModelContext) {
        Persistence.seedIfNeeded(context)
        RecurringService.catchUp(context)
        VaultIntegrity.enforce(context)
        let enabled = UserDefaults.standard.object(forKey: SettingsKeys.notificationsEnabled) as? Bool ?? true
        RecurringService.rescheduleNotifications(context, enabled: enabled)
    }
}
