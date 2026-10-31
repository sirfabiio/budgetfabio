import Foundation
import SwiftData
import UserNotifications

@MainActor
enum RecurringService {
    /// Gera todas as ocorrências em atraso (o iOS não garante execução em background,
    /// por isso isto corre sempre que a app fica ativa). Devolve o número de transações criadas.
    @discardableResult
    static func catchUp(_ context: ModelContext, now: Date = .now) -> Int {
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        var created = 0
        for rule in rules where rule.isActive {
            let due = RecurrenceEngine.dueOccurrences(rule.schedule, lastGenerated: rule.lastGeneratedDate, now: now)
            for date in due {
                let t = FinTransaction(amountCents: rule.amountCents, kind: rule.kind, date: date, category: rule.category,
                                       method: rule.method, note: rule.name, recurringRuleID: rule.id)
                context.insert(t)
                created += 1
            }
            if let last = due.last { rule.lastGeneratedDate = last }
        }
        if created > 0 { try? context.save() }
        return created
    }

    /// Agenda uma notificação local para a próxima ocorrência de cada regra ativa.
    static func rescheduleNotifications(_ context: ModelContext, enabled: Bool) {
        let center = UNUserNotificationCenter.current()
        let rules = (try? context.fetch(FetchDescriptor<RecurringRule>())) ?? []
        center.removePendingNotificationRequests(withIdentifiers: rules.map { "recorrente-\($0.id.uuidString)" })
        guard enabled else { return }
        let now = Date.now
        for rule in rules where rule.isActive && rule.notify {
            guard let next = RecurrenceEngine.nextOccurrence(rule.schedule, after: max(now, rule.lastGeneratedDate ?? .distantPast)) else { continue }
            var comps = PT.calendar.dateComponents([.year, .month, .day], from: next)
            comps.hour = 9
            let content = UNMutableNotificationContent()
            content.title = rule.kind == .income ? "Receita recorrente" : "Pagamento recorrente"
            content.body = "\(rule.name): \(MoneyFormat.string(rule.amountCents)) hoje."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "recorrente-\(rule.id.uuidString)", content: content, trigger: trigger))
        }
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
