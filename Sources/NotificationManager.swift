import Foundation
import UserNotifications
import AppKit

public class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()

    private let categoryIdentifier = "WATER_REMINDER_CATEGORY"
    private let actionDrink250 = "ACTION_DRINK_250"
    private let actionDrink500 = "ACTION_DRINK_500"
    private let actionSnooze10 = "ACTION_SNOOZE_10"

    private override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        setupCategories()
    }

    public func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }

    private func setupCategories() {
        let drink250Action = UNNotificationAction(
            identifier: actionDrink250,
            title: "💧 Drink 250ml",
            options: .foreground
        )
        let drink500Action = UNNotificationAction(
            identifier: actionDrink500,
            title: "🥛 Drink 500ml",
            options: .foreground
        )
        let snoozeAction = UNNotificationAction(
            identifier: actionSnooze10,
            title: "⏳ Snooze 10m",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [drink250Action, drink500Action, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    public func sendReminderNotification(current: Int, goal: Int, soundName: String?) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "💧 Time to Drink Water!"

        let percent = goal > 0 ? (current * 100 / goal) : 0
        if current >= goal {
            content.body = "You reached your daily goal (\(current)ml)! Keep staying hydrated with a small sip."
        } else {
            let remaining = goal - current
            content.body = "Stay refreshed! You're at \(current)/\(goal)ml (\(percent)%). \(remaining)ml left for today."
        }

        content.categoryIdentifier = categoryIdentifier

        if let soundName = soundName, !soundName.isEmpty {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
            // Also play sound immediately through NSSound for guaranteed audio playback
            if let sound = NSSound(named: NSSound.Name(soundName)) {
                sound.play()
            }
        } else {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
                // Fallback to AppleScript display notification
                Self.fallbackNotification(title: content.title, message: content.body)
            }
        }
    }

    // In case notification center doesn't deliver in ad-hoc terminal mode
    private static func fallbackNotification(title: String, message: String) {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "display notification \"\(escapedMessage)\" with title \"\(escapedTitle)\""
        if let appleScript = NSAppleScript(source: script) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification banner and play sound even if app is focused
        completionHandler([.banner, .sound, .list])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            switch response.actionIdentifier {
            case self.actionDrink250:
                WaterStore.shared.addWater(amount: 250)
            case self.actionDrink500:
                WaterStore.shared.addWater(amount: 500)
            case self.actionSnooze10:
                WaterStore.shared.snooze(minutes: 10)
            default:
                break
            }
            completionHandler()
        }
    }
}
