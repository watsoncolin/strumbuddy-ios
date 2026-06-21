import Foundation
import UserNotifications

/// Local daily-reminder scheduling — the missing **cue** in the habit loop
/// (wiki: Daily Practice Loop). Cue → routine → reward; the routine (Today's
/// session) and reward (streak + celebration) already exist, so this closes the
/// loop. One repeating local notification at the user's chosen time — no server,
/// no remote push. The time and enabled flag persist so the choice survives relaunch.
@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published var reminderTime: Date {
        didSet {
            persist()
            if enabled { Task { await reschedule() } }
        }
    }

    private let center = UNUserNotificationCenter.current()
    private let defaults: UserDefaults
    private let identifier = "daily-practice-reminder"
    private let enabledKey = "reminderEnabled"
    private let timeKey = "reminderTimeMinutes"   // minutes past midnight

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.enabled = defaults.bool(forKey: enabledKey)
        let minutes = defaults.object(forKey: timeKey) as? Int ?? (18 * 60)   // 6pm default
        self.reminderTime = NotificationService.date(fromMinutes: minutes)
    }

    /// Request permission and schedule the daily reminder. Returns whether it's on.
    @discardableResult
    func enableReminders() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        enabled = granted
        defaults.set(granted, forKey: enabledKey)
        if granted { await reschedule() }
        return granted
    }

    func disableReminders() {
        enabled = false
        defaults.set(false, forKey: enabledKey)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private func reschedule() async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "Time to play 🎸"
        content.body = "A few minutes keeps your streak alive — your guitar's waiting."
        content.sound = .default

        var comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        comps.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func persist() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        defaults.set((comps.hour ?? 0) * 60 + (comps.minute ?? 0), forKey: timeKey)
    }

    private static func date(fromMinutes m: Int) -> Date {
        var comps = DateComponents()
        comps.hour = m / 60
        comps.minute = m % 60
        return Calendar.current.date(from: comps) ?? Date()
    }
}
