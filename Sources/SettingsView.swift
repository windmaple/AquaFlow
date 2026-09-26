import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: WaterStore
    @Binding var isPresented: Bool

    @State private var customGoalText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Spacer()

                Text("Preferences")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                // Balance spacing
                Text("Back").opacity(0).font(.system(size: 13))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Daily Goal Section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Daily Intake Goal", systemImage: "target")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)

                        HStack {
                            Slider(
                                value: Binding(
                                    get: { Double(store.dailyGoal) },
                                    set: { store.dailyGoal = Int($0) }
                                ),
                                in: 1000...4000,
                                step: 100
                            )

                            Text("\(store.dailyGoal) ml")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .frame(width: 70, alignment: .trailing)
                        }

                        HStack(spacing: 8) {
                            ForEach([1500, 2000, 2500, 3000], id: \.self) { preset in
                                Button("\(preset)ml") {
                                    store.dailyGoal = preset
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(10)

                    // Reminder Interval Section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Reminder Interval", systemImage: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)

                        Picker("Remind every", selection: $store.reminderIntervalMinutes) {
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("45 minutes").tag(45)
                            Text("60 minutes (1 hr)").tag(60)
                            Text("90 minutes (1.5 hr)").tag(90)
                            Text("120 minutes (2 hr)").tag(120)
                        }
                        .pickerStyle(.menu)

                        Toggle("Reset countdown when I log a drink", isOn: $store.resetTimerOnDrink)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))
                            .padding(.top, 2)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(10)

                    // Audio & Sound Section
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Sound & Alerts", systemImage: "speaker.wave.2")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)

                        Toggle("Play alert sound with reminder", isOn: $store.soundEnabled)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))

                        if store.soundEnabled {
                            HStack {
                                Picker("Sound", selection: $store.selectedSound) {
                                    ForEach(store.availableSounds, id: \.self) { sound in
                                        Text(sound).tag(sound)
                                    }
                                }
                                .pickerStyle(.menu)

                                Button(action: { store.playPreviewSound() }) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 15))
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.accentColor)
                                .help("Preview sound")
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(10)

                    // Quiet Hours
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Quiet Hours", systemImage: "moon.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)

                        Toggle("Enable quiet hours (mute notifications)", isOn: $store.quietHoursEnabled)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 12))

                        if store.quietHoursEnabled {
                            HStack {
                                Text("From:")
                                    .font(.system(size: 12))
                                Picker("", selection: $store.quietHoursStartHour) {
                                    ForEach(0..<24) { hour in
                                        Text(String(format: "%02d:00", hour)).tag(hour)
                                    }
                                }
                                .frame(width: 80)

                                Text("to")
                                    .font(.system(size: 12))
                                Picker("", selection: $store.quietHoursEndHour) {
                                    ForEach(0..<24) { hour in
                                        Text(String(format: "%02d:00", hour)).tag(hour)
                                    }
                                }
                                .frame(width: 80)
                            }
                            .font(.system(size: 12))
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(10)

                    // Menu Bar Style
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Menu Bar Display", systemImage: "menubar.rectangle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)

                        Picker("Display style", selection: $store.menuBarMode) {
                            ForEach(MenuBarDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .font(.system(size: 12))
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(10)

                    // Data Management
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Data & Controls", systemImage: "wrench.and.screwdriver")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)

                        HStack {
                            Button("Test Notification") {
                                store.triggerManualReminder()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Spacer()

                            Button("Reset Today") {
                                store.resetToday()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(10)

                    // Quit App
                    HStack {
                        Spacer()
                        Button(action: {
                            NSApplication.shared.terminate(nil)
                        }) {
                            HStack {
                                Image(systemName: "power")
                                Text("Quit AquaFlow")
                            }
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .frame(width: 320, height: 480)
    }
}
