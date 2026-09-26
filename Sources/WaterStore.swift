import Foundation
import Combine
import AppKit

public struct WaterLogEntry: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let amount: Int

    public init(id: UUID = UUID(), timestamp: Date = Date(), amount: Int) {
        self.id = id
        self.timestamp = timestamp
        self.amount = amount
    }
}

public enum MenuBarDisplayMode: String, CaseIterable, Codable {
    case iconOnly = "Icon Only"
    case iconAndPercent = "Icon + Percentage"
    case iconAndAmount = "Icon + Intake (ml)"
}

@MainActor
public class WaterStore: ObservableObject {
    public static let shared = WaterStore()

    // MARK: - Published Properties
    @Published public var dailyGoal: Int {
        didSet {
            UserDefaults.standard.set(dailyGoal, forKey: "dailyGoal")
        }
    }

    @Published public var reminderIntervalMinutes: Int {
        didSet {
            UserDefaults.standard.set(reminderIntervalMinutes, forKey: "reminderIntervalMinutes")
            resetTimer()
        }
    }

    @Published public var isReminderPaused: Bool = false
    @Published public var pauseUntil: Date? = nil

    @Published public var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }

    @Published public var selectedSound: String {
        didSet {
            UserDefaults.standard.set(selectedSound, forKey: "selectedSound")
        }
    }

    @Published public var resetTimerOnDrink: Bool {
        didSet {
            UserDefaults.standard.set(resetTimerOnDrink, forKey: "resetTimerOnDrink")
        }
    }

    @Published public var menuBarMode: MenuBarDisplayMode {
        didSet {
            UserDefaults.standard.set(menuBarMode.rawValue, forKey: "menuBarMode")
        }
    }

    @Published public var quietHoursEnabled: Bool {
        didSet {
            UserDefaults.standard.set(quietHoursEnabled, forKey: "quietHoursEnabled")
        }
    }

    @Published public var quietHoursStartHour: Int {
        didSet {
            UserDefaults.standard.set(quietHoursStartHour, forKey: "quietHoursStartHour")
        }
    }

    @Published public var quietHoursEndHour: Int {
        didSet {
            UserDefaults.standard.set(quietHoursEndHour, forKey: "quietHoursEndHour")
        }
    }

    @Published public private(set) var todayEntries: [WaterLogEntry] = []
    @Published public private(set) var currentIntake: Int = 0
    @Published public private(set) var streakDays: Int = 0
    @Published public private(set) var secondsRemaining: Int = 3600
    @Published public private(set) var isGoalReachedBannerDismissed: Bool = false

    // MARK: - Private
    private var countdownTimer: Timer?
    private var lastRecordedDateString: String = ""

    private let availableSoundsList = ["Glass", "Ping", "Tink", "Submarine", "Hero", "Purr", "Pop"]

    public var availableSounds: [String] {
        availableSoundsList
    }

    public init() {
        let defaults = UserDefaults.standard

        // Defaults
        self.dailyGoal = defaults.object(forKey: "dailyGoal") != nil ? defaults.integer(forKey: "dailyGoal") : 2000
        self.reminderIntervalMinutes = defaults.object(forKey: "reminderIntervalMinutes") != nil ? defaults.integer(forKey: "reminderIntervalMinutes") : 45
        self.soundEnabled = defaults.object(forKey: "soundEnabled") != nil ? defaults.bool(forKey: "soundEnabled") : true
        self.selectedSound = defaults.string(forKey: "selectedSound") ?? "Glass"
        self.resetTimerOnDrink = defaults.object(forKey: "resetTimerOnDrink") != nil ? defaults.bool(forKey: "resetTimerOnDrink") : true
        self.quietHoursEnabled = defaults.object(forKey: "quietHoursEnabled") != nil ? defaults.bool(forKey: "quietHoursEnabled") : true
        self.quietHoursStartHour = defaults.object(forKey: "quietHoursStartHour") != nil ? defaults.integer(forKey: "quietHoursStartHour") : 22 // 10 PM
        self.quietHoursEndHour = defaults.object(forKey: "quietHoursEndHour") != nil ? defaults.integer(forKey: "quietHoursEndHour") : 8   // 8 AM

        if let rawMode = defaults.string(forKey: "menuBarMode"), let mode = MenuBarDisplayMode(rawValue: rawMode) {
            self.menuBarMode = mode
        } else {
            self.menuBarMode = .iconOnly
        }

        self.lastRecordedDateString = Self.dateString(from: Date())
        loadEntries()
        calculateStreak()

        self.secondsRemaining = self.reminderIntervalMinutes * 60

        startTicker()
    }

    // MARK: - Actions
    public func addWater(amount: Int) {
        checkDayRollover()
        let entry = WaterLogEntry(amount: amount)
        todayEntries.insert(entry, at: 0)
        currentIntake += amount
        saveEntries()
        calculateStreak()

        if resetTimerOnDrink {
            resetTimer()
        }
    }

    public func removeLastEntry() {
        guard let first = todayEntries.first else { return }
        todayEntries.removeFirst()
        currentIntake = max(0, currentIntake - first.amount)
        saveEntries()
        calculateStreak()
    }

    public func removeEntry(id: UUID) {
        if let idx = todayEntries.firstIndex(where: { $0.id == id }) {
            let item = todayEntries.remove(at: idx)
            currentIntake = max(0, currentIntake - item.amount)
            saveEntries()
            calculateStreak()
        }
    }

    public func resetToday() {
        todayEntries.removeAll()
        currentIntake = 0
        saveEntries()
    }

    public func resetTimer() {
        secondsRemaining = reminderIntervalMinutes * 60
    }

    public func snooze(minutes: Int) {
        secondsRemaining = minutes * 60
        isReminderPaused = false
        pauseUntil = nil
    }

    public func pauseReminders(hours: Int) {
        isReminderPaused = true
        pauseUntil = Date().addingTimeInterval(Double(hours * 3600))
    }

    public func resumeReminders() {
        isReminderPaused = false
        pauseUntil = nil
        resetTimer()
    }

    public func triggerManualReminder() {
        NotificationManager.shared.sendReminderNotification(
            current: currentIntake,
            goal: dailyGoal,
            soundName: soundEnabled ? selectedSound : nil
        )
    }

    public func playPreviewSound() {
        if let sound = NSSound(named: NSSound.Name(selectedSound)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    // MARK: - Timer Logic
    private func startTicker() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        checkDayRollover()

        // Check if paused until a certain time
        if isReminderPaused {
            if let until = pauseUntil, Date() >= until {
                isReminderPaused = false
                pauseUntil = nil
                resetTimer()
            } else {
                return
            }
        }

        if secondsRemaining > 0 {
            secondsRemaining -= 1
        } else {
            // Timer expired: Check quiet hours before notifying
            if !isCurrentTimeInQuietHours() {
                NotificationManager.shared.sendReminderNotification(
                    current: currentIntake,
                    goal: dailyGoal,
                    soundName: soundEnabled ? selectedSound : nil
                )
            }
            // Reset for the next cycle
            resetTimer()
        }
    }

    public func isCurrentTimeInQuietHours() -> Bool {
        guard quietHoursEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        if quietHoursStartHour > quietHoursEndHour {
            // e.g. 22:00 to 08:00 (spans midnight)
            return hour >= quietHoursStartHour || hour < quietHoursEndHour
        } else {
            // e.g. 01:00 to 06:00
            return hour >= quietHoursStartHour && hour < quietHoursEndHour
        }
    }

    public var progressPercent: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(currentIntake) / Double(dailyGoal), 1.0)
    }

    public var formattedCountdown: String {
        if isReminderPaused {
            if let until = pauseUntil {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Paused until \(formatter.string(from: until))"
            }
            return "Paused"
        }
        let mins = secondsRemaining / 60
        let secs = secondsRemaining % 60
        if mins >= 60 {
            let hrs = mins / 60
            let remMins = mins % 60
            return String(format: "%dh %02dm", hrs, remMins)
        }
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Rollover and Persistence
    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public func checkDayRollover() {
        let todayStr = Self.dateString(from: Date())
        if todayStr != lastRecordedDateString {
            // New day!
            archiveYesterdayIfNeeded(oldDateString: lastRecordedDateString)
            lastRecordedDateString = todayStr
            todayEntries = []
            currentIntake = 0
            saveEntries()
            calculateStreak()
        }
    }

    private func archiveYesterdayIfNeeded(oldDateString: String) {
        guard !oldDateString.isEmpty else { return }
        var history = UserDefaults.standard.dictionary(forKey: "dailyIntakeArchive") as? [String: Int] ?? [:]
        history[oldDateString] = currentIntake
        UserDefaults.standard.set(history, forKey: "dailyIntakeArchive")
    }

    private func saveEntries() {
        let todayStr = Self.dateString(from: Date())
        if let data = try? JSONEncoder().encode(todayEntries) {
            UserDefaults.standard.set(data, forKey: "todayEntries_\(todayStr)")
            UserDefaults.standard.set(todayStr, forKey: "lastRecordedDate")
        }
    }

    private func loadEntries() {
        let todayStr = Self.dateString(from: Date())
        lastRecordedDateString = defaultsString(forKey: "lastRecordedDate", default: todayStr)

        if let data = UserDefaults.standard.data(forKey: "todayEntries_\(todayStr)"),
           let entries = try? JSONDecoder().decode([WaterLogEntry].self, from: data) {
            self.todayEntries = entries
            self.currentIntake = entries.reduce(0) { $0 + $1.amount }
        } else {
            self.todayEntries = []
            self.currentIntake = 0
        }
    }

    private func calculateStreak() {
        let archive = UserDefaults.standard.dictionary(forKey: "dailyIntakeArchive") as? [String: Int] ?? [:]
        var streak = 0
        let calendar = Calendar.current
        var checkDate = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()

        // If today's goal is already reached, count today
        if currentIntake >= dailyGoal {
            streak = 1
        }

        while true {
            let str = Self.dateString(from: checkDate)
            if let intake = archive[str], intake >= dailyGoal {
                streak += 1
                if let nextPrev = calendar.date(byAdding: .day, value: -1, to: checkDate) {
                    checkDate = nextPrev
                } else {
                    break
                }
            } else {
                break
            }
        }
        self.streakDays = streak
    }

    private func defaultsString(forKey key: String, default defaultVal: String) -> String {
        return UserDefaults.standard.string(forKey: key) ?? defaultVal
    }
}
