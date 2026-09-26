# 💧 AquaFlow - Native macOS Water Reminder

**AquaFlow** is a lightweight, modern macOS menu bar application crafted with Swift and SwiftUI to help you maintain healthy hydration throughout your workday.

---

## ✨ Features

- **Menu Bar Resident**: Sits unobtrusively in your macOS status bar (`LSUIElement`) with a droplet icon.
- **Customizable Display Mode**:
  - Icon only (`💧`)
  - Icon + Percentage (`💧 65%`)
  - Icon + Intake (`💧 1250ml`)
- **Quick Logging**:
  - One-click presets for common drink sizes:
    - ☕️ **150 ml** (Cup)
    - 🥛 **250 ml** (Glass)
    - 🫖 **350 ml** (Mug)
    - 🧴 **500 ml** (Bottle)
  - Custom amount input for any specific volume.
  - Quick **Undo** button in case you tap by accident.
- **Visual Progress Ring**: Smooth circular gradient animation displaying your daily progress, total intake, and daily goal.
- **Smart Countdown Timer**:
  - Live countdown to your next reminder (e.g., `45:00`).
  - Automatically resets timer when you take a drink (configurable).
  - Quick `+10m` Snooze button.
  - Pause reminders (1 hour or until tomorrow).
- **macOS Notifications with Actions**:
  - Rich notifications via `UserNotifications`.
  - Notification action buttons to drink or snooze directly from the banner.
  - Audio alert chimes (Glass, Submarine, Tink, Ping, Hero, etc.) with preview.
- **Quiet Hours**: Mute notifications automatically during rest hours (e.g., 10:00 PM to 8:00 AM).
- **Streak & Daily Tracking**:
  - Tracks consecutive days reaching your daily hydration goal.
  - Daily log drawer with timestamps and delete buttons.
  - Automatic midnight rollover and daily archiving.
- **Right-Click Context Menu**:
  - Right-click the menu bar icon for instant actions (Log 250ml, Log 500ml, Snooze 10m, Quit).

---

## 🚀 How to Run

### Quick Start
You can launch the pre-compiled app directly:
```bash
./scripts/run.sh
```

### Rebuilding from Source
To rebuild the standalone macOS application bundle:
```bash
./scripts/build.sh
```
The compiled bundle will be generated at `build/AquaFlow.app`.

### Cleaning Build Artifacts
To clean all generated build artifacts:
```bash
./scripts/clean.sh
```

### Optional: Move to Applications Folder
If you'd like to install it permanently in your Applications folder:
```bash
cp -R build/AquaFlow.app /Applications/
```

### Optional: Launch at Login
To have AquaFlow start automatically when you log into your Mac:
1. Open **System Settings** → **General** → **Login Items**.
2. Click the **+** button under **Open at Login**.
3. Select `AquaFlow.app` (from `/Applications` or `build/AquaFlow.app`).

---

## 🛠 Project Structure

```
water-reminder/
├── Sources/
│   ├── main.swift                 # Application entry point
│   ├── AppDelegate.swift          # NSStatusItem & NSPopover lifecycle
│   ├── WaterStore.swift           # Hydration state, timer & UserDefaults persistence
│   ├── ContentView.swift          # SwiftUI UI (Circular gauge, presets, history)
│   ├── SettingsView.swift         # Preferences (Interval, goal, audio, quiet hours)
│   └── NotificationManager.swift  # UserNotifications & alert management
├── Resources/
│   ├── Info.plist                 # App bundle configuration & LSUIElement
│   └── AppIcon.icns               # High-res macOS application icon
├── scripts/
│   ├── build.sh                   # Builds & codesigns AquaFlow.app
│   ├── clean.sh                   # Removes generated build artifacts
│   └── run.sh                     # Builds (if needed) and launches AquaFlow
└── README.md
```
