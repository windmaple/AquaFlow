/**
 * AquaFlow — Interactive macOS Popover Simulator, Web Audio Chimes & UI Logic
 * Mirrors the native SwiftUI & AppKit implementation in Sources/
 */

(function () {
  'use strict';

  const RING_RADIUS = 68;
  const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS; // 427.2566

  // Initial simulator state matching screenshot-main.png & WaterStore.swift
  const state = {
    dailyGoal: 2000,
    reminderIntervalMinutes: 45,
    secondsRemaining: 32 * 60 + 18,
    isReminderPaused: false,
    resetTimerOnDrink: true,
    selectedSound: 'Glass',
    menuBarMode: 'iconAndPercent',
    baseStreakDays: 7,
    showHistory: true,
    showSettings: false,
    entries: [
      { id: 'log-1', time: '10:45 AM', amount: 250 },
      { id: 'log-2', time: '09:50 AM', amount: 350 },
      { id: 'log-3', time: '08:30 AM', amount: 500 },
      { id: 'log-4', time: '07:40 AM', amount: 400 }
    ]
  };

  // DOM References
  const elStatusItem = document.getElementById('sim-status-item');
  const elStatusIcon = document.getElementById('sim-status-icon');
  const elStatusText = document.getElementById('sim-status-text');
  const elNsMenu = document.getElementById('sim-nsmenu');
  const elNsMenuCountdown = document.getElementById('nsmenu-countdown-label');
  const elNsMenuIntake = document.getElementById('nsmenu-intake-label');

  const elNotifBanner = document.getElementById('sim-notif-banner');
  const elNotifBody = document.getElementById('sim-notif-body');

  const elMainPane = document.getElementById('popover-main-pane');
  const elSettingsPane = document.getElementById('popover-settings-pane');

  const elStreakBadge = document.getElementById('sim-streak-badge');
  const elRingContainer = document.getElementById('sim-ring-container');
  const elRingProgress = document.getElementById('sim-ring-progress');
  const elCurrentIntake = document.getElementById('sim-current-intake');
  const elGoalLabel = document.getElementById('sim-goal-label');
  const elPercentBadge = document.getElementById('sim-percent-badge');
  const elStatusMessage = document.getElementById('sim-status-message');

  const elTimerIcon = document.getElementById('sim-timer-icon');
  const elTimerReadout = document.getElementById('sim-timer-readout');
  const elTimerCaption = document.getElementById('sim-timer-caption');
  const elBtnPauseToggle = document.getElementById('btn-pause-toggle');

  const elCustomTriggerRow = document.getElementById('custom-input-trigger-row');
  const elCustomForm = document.getElementById('custom-input-form');
  const elInputCustomMl = document.getElementById('input-custom-ml');
  const elBtnUndoLast = document.getElementById('btn-undo-last');

  const elBtnToggleHistory = document.getElementById('btn-toggle-history');
  const elHistoryList = document.getElementById('sim-history-list');

  const elSettingsGoalReadout = document.getElementById('settings-goal-readout');
  const elSettingsGoalSlider = document.getElementById('settings-goal-slider');
  const elSettingsIntervalSelect = document.getElementById('settings-interval-select');
  const elSettingsResetOnDrink = document.getElementById('settings-reset-on-drink');
  const elSettingsSoundSelect = document.getElementById('settings-sound-select');

  let notifTimeoutId = null;
  let audioCtx = null;

  // Compute total intake
  function getCurrentIntake() {
    return state.entries.reduce((sum, item) => sum + item.amount, 0);
  }

  // Compute progress [0..1]
  function getProgressPercent() {
    if (state.dailyGoal <= 0) return 0;
    return Math.min(getCurrentIntake() / state.dailyGoal, 1.0);
  }

  // Format countdown matching WaterStore.formattedCountdown
  function getFormattedCountdown() {
    if (state.isReminderPaused) {
      return 'Paused (1h)';
    }
    const mins = Math.floor(state.secondsRemaining / 60);
    const secs = state.secondsRemaining % 60;
    if (mins >= 60) {
      const hrs = Math.floor(mins / 60);
      const remMins = mins % 60;
      return `${hrs}h ${String(remMins).padStart(2, '0')}m`;
    }
    return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  }

  // Status encouragement message matching ContentView.statusMessage
  function getStatusMessage(percent) {
    if (percent >= 1.0) {
      return '🎉 Daily goal accomplished! Fantastic work!';
    } else if (percent >= 0.75) {
      return 'Almost there! Keep up the great hydration!';
    } else if (percent >= 0.50) {
      return 'Halfway to your daily goal! Keep going!';
    } else if (percent >= 0.25) {
      return 'Good progress! A sip an hour keeps fatigue away.';
    }
    return 'Time to hydrate! Grab a fresh glass of water.';
  }

  // Format current time as HH:MM AM/PM
  function formatCurrentTime() {
    const now = new Date();
    return now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  // Synthesize macOS-inspired alert chimes via Web Audio API
  function playMacChime(soundName) {
    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (!AudioContextClass) return;
      if (!audioCtx) {
        audioCtx = new AudioContextClass();
      }
      if (audioCtx.state === 'suspended') {
        audioCtx.resume();
      }

      const now = audioCtx.currentTime;
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();

      const presets = {
        Glass: { type: 'sine', f1: 1174.66, f2: 1760.0, dur: 0.45 },
        Ping: { type: 'triangle', f1: 1046.5, f2: 1046.5, dur: 0.35 },
        Tink: { type: 'sine', f1: 1567.98, f2: 1975.53, dur: 0.22 },
        Submarine: { type: 'sine', f1: 587.33, f2: 440.0, dur: 0.55 },
        Hero: { type: 'triangle', f1: 659.25, f2: 987.77, dur: 0.5 },
        Purr: { type: 'sine', f1: 329.63, f2: 392.0, dur: 0.4 },
        Pop: { type: 'sine', f1: 520.0, f2: 1280.0, dur: 0.18 }
      };

      const cfg = presets[soundName] || presets.Glass;
      osc.type = cfg.type;
      osc.frequency.setValueAtTime(cfg.f1, now);
      osc.frequency.exponentialRampToValueAtTime(cfg.f2, now + cfg.dur * 0.65);

      gain.gain.setValueAtTime(0.001, now);
      gain.gain.exponentialRampToValueAtTime(0.18, now + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, now + cfg.dur);

      osc.connect(gain);
      gain.connect(audioCtx.destination);

      osc.start(now);
      osc.stop(now + cfg.dur);
    } catch (_) {
      // Ignore audio errors if blocked by browser policy
    }
  }

  // Trigger pulse animation on ring
  function pulseRing() {
    if (!elRingContainer) return;
    elRingContainer.classList.add('pulse');
    setTimeout(() => {
      elRingContainer.classList.remove('pulse');
    }, 260);
  }

  // Add water entry
  function addWater(amount) {
    const cleanAmount = Math.max(1, Math.round(Number(amount) || 0));
    state.entries.unshift({
      id: 'log-' + Date.now() + '-' + Math.random().toString(36).slice(2, 6),
      time: formatCurrentTime(),
      amount: cleanAmount
    });
    if (state.resetTimerOnDrink) {
      state.secondsRemaining = state.reminderIntervalMinutes * 60;
    }
    pulseRing();
    render();
  }

  // Undo most recent drink
  function undoLastEntry() {
    if (state.entries.length === 0) return;
    state.entries.shift();
    render();
  }

  // Remove specific drink entry
  function removeEntryById(id) {
    const idx = state.entries.findIndex((item) => item.id === id);
    if (idx !== -1) {
      state.entries.splice(idx, 1);
      render();
    }
  }

  // Snooze countdown
  function snoozeMinutes(mins) {
    state.secondsRemaining = mins * 60;
    state.isReminderPaused = false;
    render();
  }

  // Show simulated macOS notification banner
  function triggerNotificationBanner() {
    const current = getCurrentIntake();
    const goal = state.dailyGoal;
    const pct = goal > 0 ? Math.round((current * 100) / goal) : 0;

    if (current >= goal) {
      elNotifBody.textContent = `You reached your daily goal (${current}ml)! Keep staying hydrated with a small sip.`;
    } else {
      const remaining = Math.max(0, goal - current);
      elNotifBody.textContent = `Stay refreshed! You're at ${current}/${goal}ml (${pct}%). ${remaining}ml left for today.`;
    }

    elNotifBanner.classList.remove('hidden');
    playMacChime(state.selectedSound);

    if (notifTimeoutId) {
      clearTimeout(notifTimeoutId);
    }
    notifTimeoutId = setTimeout(() => {
      elNotifBanner.classList.add('hidden');
    }, 6500);
  }

  // Render full simulator UI
  function render() {
    const intake = getCurrentIntake();
    const progress = getProgressPercent();
    const pctInt = Math.round(progress * 100);
    const rawPctInt = state.dailyGoal > 0 ? Math.round((intake / state.dailyGoal) * 100) : 0;

    // 1. Update Menu Bar Status Item (AppDelegate.updateStatusItem)
    elStatusIcon.textContent = progress >= 1.0 ? '✅' : '💧';
    if (state.menuBarMode === 'iconOnly') {
      elStatusText.textContent = '';
      elStatusText.classList.add('hidden');
    } else if (state.menuBarMode === 'iconAndPercent') {
      elStatusText.textContent = `${pctInt}%`;
      elStatusText.classList.remove('hidden');
    } else {
      elStatusText.textContent = `${intake}ml`;
      elStatusText.classList.remove('hidden');
    }

    // 2. Update Right-Click NSMenu info rows
    const countdownStr = getFormattedCountdown();
    elNsMenuCountdown.textContent = state.isReminderPaused
      ? 'Reminders: Paused'
      : `Next reminder: ${countdownStr}`;
    elNsMenuIntake.textContent = `Today: ${intake}/${state.dailyGoal} ml (${pctInt}%)`;

    // 3. Update Streak Badge
    const effectiveStreak = intake >= state.dailyGoal ? state.baseStreakDays + 1 : state.baseStreakDays;
    elStreakBadge.textContent = `🔥 ${effectiveStreak}d streak`;

    // 4. Update SVG Circular Ring
    const offset = RING_CIRCUMFERENCE * (1 - progress);
    elRingProgress.style.strokeDasharray = `${RING_CIRCUMFERENCE.toFixed(2)}`;
    elRingProgress.style.strokeDashoffset = `${offset.toFixed(2)}`;
    elCurrentIntake.textContent = `${intake}`;
    elGoalLabel.textContent = `of ${state.dailyGoal} ml goal`;
    elPercentBadge.textContent = `${rawPctInt}%`;

    // 5. Update Status Message
    elStatusMessage.textContent = getStatusMessage(progress);

    // 6. Update Countdown Timer Bar
    elTimerIcon.textContent = state.isReminderPaused ? '⏸' : '⏱';
    elTimerReadout.textContent = countdownStr;
    elTimerCaption.textContent = state.isReminderPaused ? 'Reminders paused' : 'Next reminder';
    elBtnPauseToggle.textContent = state.isReminderPaused ? '▶' : '⏸';

    // 7. Update Undo Button
    if (state.entries.length > 0) {
      elBtnUndoLast.textContent = `↩ Undo +${state.entries[0].amount}ml`;
      elBtnUndoLast.classList.remove('hidden');
    } else {
      elBtnUndoLast.classList.add('hidden');
    }

    // 8. Update History Drawer & Count
    elBtnToggleHistory.innerHTML = state.showHistory
      ? `▴ Hide Today's Logs (${state.entries.length})`
      : `🕒 Today's Logs (${state.entries.length})`;

    if (state.showHistory) {
      elHistoryList.classList.remove('hidden');
      if (state.entries.length === 0) {
        elHistoryList.innerHTML = '<div style="text-align:center; font-size:0.72rem; color:var(--ink-muted); padding:8px 0;">No drinks logged yet today.</div>';
      } else {
        elHistoryList.innerHTML = state.entries
          .map(
            (entry) => `
            <div class="history-log-row">
              <span class="history-time"><span style="color:var(--aqua-primary);">💧</span> ${entry.time}</span>
              <span class="history-amount-wrap">
                <span>+${entry.amount} ml</span>
                <button type="button" class="history-delete-btn" data-delete-id="${entry.id}" title="Delete entry" aria-label="Delete ${entry.amount}ml entry">🗑</button>
              </span>
            </div>`
          )
          .join('');
      }
    } else {
      elHistoryList.classList.add('hidden');
    }

    // 9. Sync Settings Pane Controls
    elSettingsGoalReadout.textContent = `${state.dailyGoal} ml`;
    elSettingsGoalSlider.value = String(state.dailyGoal);
    document.querySelectorAll('.goal-preset-btn').forEach((btn) => {
      const presetVal = Number(btn.getAttribute('data-goal'));
      btn.classList.toggle('active', presetVal === state.dailyGoal);
    });

    // 10. Toggle Main vs Settings Pane
    elMainPane.classList.toggle('hidden', state.showSettings);
    elSettingsPane.classList.toggle('hidden', !state.showSettings);
  }

  // Event Listeners: Quick Drink Presets
  document.querySelectorAll('.preset-drink-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      const amount = Number(btn.getAttribute('data-amount'));
      addWater(amount);
    });
  });

  // Custom Amount Inline Input
  document.getElementById('btn-show-custom').addEventListener('click', () => {
    elCustomTriggerRow.style.display = 'none';
    elCustomForm.classList.remove('hidden');
    elInputCustomMl.focus();
  });

  document.getElementById('btn-cancel-custom').addEventListener('click', () => {
    elCustomForm.classList.add('hidden');
    elCustomTriggerRow.style.display = 'flex';
  });

  document.getElementById('btn-add-custom').addEventListener('click', () => {
    const val = Number(elInputCustomMl.value);
    if (val > 0) {
      addWater(val);
    }
    elCustomForm.classList.add('hidden');
    elCustomTriggerRow.style.display = 'flex';
  });

  elBtnUndoLast.addEventListener('click', undoLastEntry);

  // History Drawer Toggle & Entry Deletion
  elBtnToggleHistory.addEventListener('click', () => {
    state.showHistory = !state.showHistory;
    render();
  });

  elHistoryList.addEventListener('click', (e) => {
    const target = e.target.closest('[data-delete-id]');
    if (target) {
      removeEntryById(target.getAttribute('data-delete-id'));
    }
  });

  // Timer Controls
  document.getElementById('btn-snooze-10').addEventListener('click', () => {
    snoozeMinutes(10);
  });

  elBtnPauseToggle.addEventListener('click', () => {
    state.isReminderPaused = !state.isReminderPaused;
    if (!state.isReminderPaused) {
      state.secondsRemaining = state.reminderIntervalMinutes * 60;
    }
    render();
  });

  // Settings Navigation
  document.getElementById('btn-open-settings').addEventListener('click', () => {
    state.showSettings = true;
    render();
  });

  document.getElementById('btn-close-settings').addEventListener('click', () => {
    state.showSettings = false;
    render();
  });

  // Settings Controls
  elSettingsGoalSlider.addEventListener('input', () => {
    state.dailyGoal = Number(elSettingsGoalSlider.value);
    render();
  });

  document.querySelectorAll('.goal-preset-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.dailyGoal = Number(btn.getAttribute('data-goal'));
      render();
    });
  });

  elSettingsIntervalSelect.addEventListener('change', () => {
    state.reminderIntervalMinutes = Number(elSettingsIntervalSelect.value);
    state.secondsRemaining = state.reminderIntervalMinutes * 60;
    render();
  });

  elSettingsResetOnDrink.addEventListener('change', () => {
    state.resetTimerOnDrink = elSettingsResetOnDrink.checked;
  });

  elSettingsSoundSelect.addEventListener('change', () => {
    state.selectedSound = elSettingsSoundSelect.value;
    playMacChime(state.selectedSound);
  });

  document.getElementById('btn-preview-sound').addEventListener('click', () => {
    playMacChime(state.selectedSound);
  });

  document.querySelectorAll('input[name="menubar-mode"]').forEach((radio) => {
    radio.addEventListener('change', () => {
      if (radio.checked) {
        state.menuBarMode = radio.value;
        render();
      }
    });
  });

  document.getElementById('btn-test-notif').addEventListener('click', triggerNotificationBanner);
  document.getElementById('btn-settings-test-notif').addEventListener('click', triggerNotificationBanner);

  document.getElementById('btn-settings-reset-today').addEventListener('click', () => {
    state.entries = [];
    render();
  });

  // Notification Banner Action Buttons
  document.getElementById('notif-btn-250').addEventListener('click', () => {
    addWater(250);
    elNotifBanner.classList.add('hidden');
  });

  document.getElementById('notif-btn-500').addEventListener('click', () => {
    addWater(500);
    elNotifBanner.classList.add('hidden');
  });

  document.getElementById('notif-btn-snooze').addEventListener('click', () => {
    snoozeMinutes(10);
    elNotifBanner.classList.add('hidden');
  });

  // Menu Bar Status Item Left/Right Click & Context Menu
  elStatusItem.addEventListener('click', () => {
    elNsMenu.classList.toggle('hidden');
  });

  elStatusItem.addEventListener('contextmenu', (e) => {
    e.preventDefault();
    elNsMenu.classList.toggle('hidden');
  });

  document.getElementById('nsmenu-drink-250').addEventListener('click', () => {
    addWater(250);
    elNsMenu.classList.add('hidden');
  });

  document.getElementById('nsmenu-drink-500').addEventListener('click', () => {
    addWater(500);
    elNsMenu.classList.add('hidden');
  });

  document.getElementById('nsmenu-snooze-10').addEventListener('click', () => {
    snoozeMinutes(10);
    elNsMenu.classList.add('hidden');
  });

  document.getElementById('nsmenu-open-popover').addEventListener('click', () => {
    state.showSettings = false;
    elNsMenu.classList.add('hidden');
    render();
  });

  // Right-Column Action Deck Buttons
  document.getElementById('deck-btn-toggle-view').addEventListener('click', () => {
    state.showSettings = !state.showSettings;
    render();
  });

  document.getElementById('deck-btn-context-menu').addEventListener('click', () => {
    elNsMenu.classList.toggle('hidden');
  });

  document.getElementById('deck-btn-trigger-notif').addEventListener('click', triggerNotificationBanner);

  document.getElementById('deck-btn-chime').addEventListener('click', () => {
    playMacChime(state.selectedSound);
  });

  // 1-Second Live Countdown Ticker
  setInterval(() => {
    if (!state.isReminderPaused && state.secondsRemaining > 0) {
      state.secondsRemaining -= 1;
      elTimerReadout.textContent = getFormattedCountdown();
      elNsMenuCountdown.textContent = `Next reminder: ${getFormattedCountdown()}`;
    }
  }, 1000);

  // =========================================================================
  // Personal Daily Hydration Goal Calculator
  // =========================================================================
  const elCalcWeight = document.getElementById('calc-weight');
  const elCalcWeightVal = document.getElementById('calc-weight-val');
  const elCalcExercise = document.getElementById('calc-exercise');
  const elCalcExerciseVal = document.getElementById('calc-exercise-val');
  const elCalcCoffee = document.getElementById('calc-coffee');
  const elCalcCoffeeVal = document.getElementById('calc-coffee-val');
  const elCalcRecMl = document.getElementById('calc-recommended-ml');
  const elCalcRecCups = document.getElementById('calc-recommended-cups');
  const elBtnApplyGoal = document.getElementById('btn-apply-calculated-goal');

  let calculatedGoalMl = 2600;

  function updateCalculator() {
    const weightKg = Number(elCalcWeight.value);
    const exerciseMins = Number(elCalcExercise.value);
    const coffeeCups = Number(elCalcCoffee.value);

    elCalcWeightVal.textContent = `${weightKg} kg`;
    elCalcExerciseVal.textContent = `${exerciseMins} min`;
    elCalcCoffeeVal.textContent = `${coffeeCups} ${coffeeCups === 1 ? 'cup' : 'cups'}`;

    // Formula: 33ml per kg + 350ml per 30m exercise + 120ml per caffeinated cup, rounded to nearest 100ml
    const rawMl = weightKg * 33 + (exerciseMins / 30) * 350 + coffeeCups * 120;
    calculatedGoalMl = Math.min(4000, Math.max(1200, Math.round(rawMl / 100) * 100));

    const glasses = (calculatedGoalMl / 250).toFixed(1);
    elCalcRecMl.textContent = `${calculatedGoalMl} ml`;
    elCalcRecCups.textContent = `≈ ${glasses} glasses (250ml each)`;
  }

  [elCalcWeight, elCalcExercise, elCalcCoffee].forEach((input) => {
    input.addEventListener('input', updateCalculator);
  });

  elBtnApplyGoal.addEventListener('click', () => {
    state.dailyGoal = calculatedGoalMl;
    pulseRing();
    render();
    elBtnApplyGoal.textContent = '✓ Synced to Simulator';
    setTimeout(() => {
      elBtnApplyGoal.textContent = 'Apply to Simulator';
    }, 1600);
  });

  // =========================================================================
  // Screenshot Showcase Switcher
  // =========================================================================
  const figMain = document.getElementById('fig-shot-main');
  const figSettings = document.getElementById('fig-shot-settings');
  const shotTabs = document.querySelectorAll('[data-filter]');

  shotTabs.forEach((tab) => {
    tab.addEventListener('click', () => {
      shotTabs.forEach((t) => t.classList.remove('active'));
      tab.classList.add('active');
      const filter = tab.getAttribute('data-filter');

      if (filter === 'main') {
        figMain.classList.remove('dimmed');
        figSettings.classList.add('dimmed');
      } else if (filter === 'settings') {
        figSettings.classList.remove('dimmed');
        figMain.classList.add('dimmed');
      } else {
        figMain.classList.remove('dimmed');
        figSettings.classList.remove('dimmed');
      }
    });
  });

  // =========================================================================
  // Terminal Installation Tabs & Clipboard Copy
  // =========================================================================
  const terminalSnippets = {
    install: {
      caption: 'Installs standalone AquaFlow.app to /Applications',
      code: `# Unzip the downloaded bundle and move to /Applications
unzip AquaFlow-macOS-arm64.zip
cp -R AquaFlow.app /Applications/

# Clear quarantine attribute (if needed) & launch AquaFlow
xattr -cr /Applications/AquaFlow.app
open /Applications/AquaFlow.app`
    },
    source: {
      caption: 'Compiles Swift sources & ad-hoc signs build/AquaFlow.app',
      code: `# Clone the repository & build AquaFlow.app from Swift source
git clone https://github.com/windmaple/AquaFlow.git
cd AquaFlow
./scripts/build.sh

# Or build and launch immediately
./scripts/run.sh`
    },
    login: {
      caption: 'Starts AquaFlow automatically when you log in to macOS',
      code: `# Option 1: macOS System Settings
# System Settings → General → Login Items → Click "+" → Select AquaFlow.app

# Option 2: Register Login Item via osascript
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/AquaFlow.app", hidden:false}'`
    }
  };

  const elTermCode = document.getElementById('terminal-code-display');
  const elTermCaption = document.getElementById('terminal-caption');
  const elBtnCopyTerm = document.getElementById('btn-copy-terminal');
  const termTabBtns = document.querySelectorAll('[data-tab]');

  termTabBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      termTabBtns.forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      const key = btn.getAttribute('data-tab');
      const item = terminalSnippets[key];
      if (item) {
        elTermCode.textContent = item.code;
        elTermCaption.textContent = item.caption;
      }
    });
  });

  elBtnCopyTerm.addEventListener('click', () => {
    const text = elTermCode.textContent;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => {
        elBtnCopyTerm.textContent = '✓ Copied!';
        setTimeout(() => {
          elBtnCopyTerm.textContent = 'Copy Commands';
        }, 1500);
      });
    }
  });

  // Initial render
  updateCalculator();
  render();
})();
