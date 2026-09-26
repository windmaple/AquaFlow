import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WaterStore
    @State private var showSettings: Bool = false
    @State private var showHistory: Bool = false
    @State private var showCustomInput: Bool = false
    @State private var customAmount: String = ""
    @State private var justLoggedAnimation: Bool = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(store: store, isPresented: $showSettings)
            } else {
                mainView
            }
        }
        .frame(width: 330, height: 490)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    private var mainView: some View {
        VStack(spacing: 12) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                    Text("AquaFlow")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }

                Spacer()

                // Streak badge
                if store.streakDays > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("\(store.streakDays)d streak")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Circular Progress Visualizer
            ZStack {
                // Background Track
                Circle()
                    .stroke(
                        Color.blue.opacity(0.12),
                        lineWidth: 12
                    )

                // Progress Fill
                Circle()
                    .trim(from: 0, to: CGFloat(store.progressPercent))
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.1, green: 0.75, blue: 1.0), Color(red: 0.05, green: 0.45, blue: 0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: store.progressPercent)

                // Inner content
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(store.currentIntake)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("ml")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Text("of \(store.dailyGoal) ml goal")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text("\(Int(store.progressPercent * 100))%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                        .padding(.top, 2)
                }
            }
            .frame(width: 155, height: 155)
            .scaleEffect(justLoggedAnimation ? 1.04 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: justLoggedAnimation)

            // Encouragement message
            Text(statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            // Timer & Reminder Card
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: store.isReminderPaused ? "pause.circle.fill" : "timer")
                        .foregroundColor(store.isReminderPaused ? .orange : .blue)
                        .font(.system(size: 13))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.formattedCountdown)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Text(store.isReminderPaused ? "Reminders paused" : "Next reminder")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Button(action: {
                        store.snooze(minutes: 10)
                    }) {
                        Text("+10m")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Snooze reminder for 10 minutes")

                    if store.isReminderPaused {
                        Button(action: { store.resumeReminders() }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Resume reminders")
                    } else {
                        Button(action: { store.pauseReminders(hours: 1) }) {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Pause reminders for 1 hour")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
            .cornerRadius(8)
            .padding(.horizontal, 16)

            // Quick Log Buttons
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    quickDrinkButton(icon: "cup.and.saucer.fill", amount: 150, label: "150ml")
                    quickDrinkButton(icon: "waterbottle.fill", amount: 250, label: "250ml")
                    quickDrinkButton(icon: "mug.fill", amount: 350, label: "350ml")
                    quickDrinkButton(icon: "waterbottle", amount: 500, label: "500ml")
                }

                // Custom amount row / input
                if showCustomInput {
                    HStack(spacing: 6) {
                        TextField("ml", text: $customAmount)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                            .font(.system(size: 12))

                        Button("Add") {
                            if let val = Int(customAmount), val > 0 {
                                logDrink(amount: val)
                                customAmount = ""
                                showCustomInput = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Cancel") {
                            showCustomInput = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 2)
                } else {
                    HStack {
                        Button(action: { showCustomInput = true }) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                Text("Custom amount")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if let last = store.todayEntries.first {
                            Button(action: { store.removeLastEntry() }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Undo +\(last.amount)ml")
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16)

            Divider()
                .padding(.horizontal, 16)

            // Bottom bar / History Drawer
            HStack {
                Button(action: { showHistory.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showHistory ? "chevron.up" : "clock")
                        Text(showHistory ? "Hide Today's Logs" : "Today's Logs (\(store.todayEntries.count))")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    store.triggerManualReminder()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.badge")
                        Text("Test")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Test hydration reminder notification")
            }
            .padding(.horizontal, 16)

            if showHistory {
                historyList
                    .frame(height: 70)
                    .padding(.horizontal, 16)
            }

            Spacer(minLength: 4)
        }
    }

    private var historyList: some View {
        ScrollView {
            if store.todayEntries.isEmpty {
                Text("No drinks logged yet today.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(store.todayEntries) { entry in
                        HStack {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)

                            Text(timeFormatter.string(from: entry.timestamp))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("+\(entry.amount) ml")
                                .font(.system(size: 11, weight: .semibold))

                            Button(action: { store.removeEntry(id: entry.id) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 4)
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                        .cornerRadius(4)
                    }
                }
            }
        }
    }

    private func quickDrinkButton(icon: String, amount: Int, label: String) -> some View {
        Button(action: {
            logDrink(amount: amount)
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(.blue)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func logDrink(amount: Int) {
        store.addWater(amount: amount)
        justLoggedAnimation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            justLoggedAnimation = false
        }
    }

    private var statusMessage: String {
        let percent = store.progressPercent
        if percent >= 1.0 {
            return "🎉 Daily goal accomplished! Fantastic work!"
        } else if percent >= 0.75 {
            return "Almost there! Keep up the great hydration!"
        } else if percent >= 0.50 {
            return "Halfway to your daily goal! Keep going!"
        } else if percent >= 0.25 {
            return "Good progress! A sip an hour keeps fatigue away."
        } else {
            return "Time to hydrate! Grab a fresh glass of water."
        }
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

// Background blur helper
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
