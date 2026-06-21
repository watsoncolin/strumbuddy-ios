import SwiftUI

/// App settings. v0.1 scope: notification preferences for the daily-practice
/// reminder (the habit-loop cue — see wiki: Daily Practice Loop). Reachable from
/// the gear in the Today screen.
struct SettingsView: View {
    @ObservedObject var notifications: NotificationService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily reminder", isOn: reminderToggle)
                    if notifications.enabled {
                        DatePicker("Reminder time", selection: $notifications.reminderTime,
                                   displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(notifications.enabled
                         ? "We'll nudge you once a day to keep your streak alive."
                         : "A daily reminder is the single biggest thing that keeps a habit going.")
                }

                // Escape hatch when permission was denied at the OS level — the in-app
                // toggle can't re-prompt, so send the user to the system settings.
                Section {
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } footer: {
                    Text("If reminders won't turn on, enable notifications for Strumbuddy in iOS Settings.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Turning on requests permission (reverts if denied); turning off cancels it.
    private var reminderToggle: Binding<Bool> {
        Binding(
            get: { notifications.enabled },
            set: { on in
                Task {
                    if on { await notifications.enableReminders() }
                    else { notifications.disableReminders() }
                }
            })
    }
}
