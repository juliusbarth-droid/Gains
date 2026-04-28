import AVFoundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - RunTrackerView

/// Lauf-Hauptbildschirm. Drei Phasen:
/// 1. Pre-Run-Setup (Intensität + Ziel + Optionen)
/// 2. Countdown 3-2-1
/// 3. Live-Tracking (mit HF-Zone, Auto-Pause, manueller Lap, Audio-Cues)
struct RunTrackerView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  @StateObject private var gpsTracker = RunLocationTracker()
  @StateObject private var audio = RunAudioCueManager()
  @ObservedObject private var healthKit = HealthKitManager.shared

  @State private var phase: Phase = .setup
  @State private var countdownValue: Int = 3
  @State private var countdownTimer: Timer? = nil
  @State private var showsStopSheet = false
  @State private var lastSpokenKilometer: Int = 0
  /// Letzter vom Audio-Cue gesprochener Step-Index — vermeidet doppelte Sprachausgabe.
  @State private var lastSpokenStepIndex: Int = -1

  private enum Phase {
    case setup
    case countdown
    case live
  }

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        switch phase {
        case .setup:
          PreRunSetupView(
            store: store,
            gpsTracker: gpsTracker,
            onStart: beginCountdown
          )
        case .countdown:
          CountdownView(value: countdownValue)
        case .live:
          if let run = store.activeRun {
            LiveRunView(
              run: run,
              gpsTracker: gpsTracker,
              maxHeartRate: store.estimatedMaxHeartRate,
              activeWorkout: store.activeStructuredWorkout,
              onTogglePause: { togglePause(run) },
              onLap: handleManualLap,
              onStop: { showsStopSheet = true }
            )
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Schließen") {
            if phase == .live {
              showsStopSheet = true
            } else {
              cancelCountdown()
              stopTracking()
              if store.activeRun != nil {
                store.discardActiveRun()
              }
              dismiss()
            }
          }
          .foregroundStyle(GainsColor.ink)
        }
      }
      .sheet(isPresented: $showsStopSheet) {
        StopRunSheet(
          run: store.activeRun,
          onSave: { title, note, feel in
            finishRun(title: title, note: note, feel: feel)
            showsStopSheet = false
            dismiss()
          },
          onDiscard: {
            stopTracking()
            store.discardActiveRun()
            showsStopSheet = false
            dismiss()
          },
          onResume: {
            showsStopSheet = false
          }
        )
        .environmentObject(store)
        .presentationDetents([.medium, .large])
      }
    }
    .onAppear {
      gpsTracker.requestAuthorization()
      HealthKitManager.shared.startHeartRateObserver()

      // Wenn beim Öffnen schon ein Lauf aktiv ist (z.B. App im Hintergrund war),
      // direkt in den Live-Screen springen und State synchronisieren.
      if store.activeRun != nil {
        phase = .live
        synchronizeTrackerState()
      }
    }
    .onDisappear {
      HealthKitManager.shared.stopHeartRateObserver()
      cancelCountdown()
    }
    // Stabilitäts-Fix: vorher feuerten 4 separate onReceive-Publisher alle
    // syncStoreWithTracker() — in der Praxis 3–4× pro GPS-Update (ca. 1 Hz),
    // weil trackedDistanceKm, durationMinutes, elevationGain und splits fast
    // gleichzeitig publiziert wurden. Das führte zu redundanten Store-Writes
    // und ließ tickHRZoneAndCues() öfter feuern als nötig (Audio-Cues konnten
    // sich überlappen, Step-Wechsel wurden mehrfach erkannt).
    // Jetzt: ein einziger Publisher auf elapsedSeconds (1× pro Sekunde, vom
    // Timer), der Store-Sync und Cues sequentiell abarbeitet.
    // Der Store-Sync vor finishRun() bleibt separat und deckt die letzte Lücke.
    .onReceive(gpsTracker.$elapsedSeconds) { _ in
      syncStoreWithTracker()
      tickHRZoneAndCues()
    }
    .onReceive(gpsTracker.$autoPaused) { paused in handleAutoPause(paused) }
    .onReceive(healthKit.$liveHeartRate)    { bpm in
      guard let bpm else { return }
      gpsTracker.currentHeartRate = bpm
      if store.activeRun != nil {
        store.updateRunHeartRateLive(bpm)
      }
    }
    .onChange(of: gpsTracker.authorizationStatus) { _, _ in
      synchronizeTrackerState()
    }
  }

  // MARK: – Phase-Übergänge

  private func beginCountdown() {
    countdownValue = 3
    phase = .countdown
    audio.speak("Drei.")
    countdownTimer?.invalidate()
    countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      countdownValue -= 1
      if countdownValue == 2 { audio.speak("Zwei.") }
      if countdownValue == 1 { audio.speak("Eins.") }
      if countdownValue <= 0 {
        countdownTimer?.invalidate()
        countdownTimer = nil
        startRunNow()
      }
    }
  }

  private func cancelCountdown() {
    countdownTimer?.invalidate()
    countdownTimer = nil
  }

  private func startRunNow() {
    phase = .live
    if store.activeRun == nil {
      store.startQuickRun()
    }
    audio.speak("Lauf gestartet.")
    synchronizeTrackerState()
  }

  // MARK: – Tracker-Sync

  private func synchronizeTrackerState() {
    guard let run = store.activeRun else {
      stopTracking()
      return
    }

    gpsTracker.autoPauseEnabled = run.autoPauseEnabled

    guard !run.isPaused else { return }

    if gpsTracker.canStartTracking {
      gpsTracker.beginTracking(from: run)
    } else {
      // Bug-Fix: vorher wurde bei `.notDetermined` nur `requestAuthorization()`
      // gerufen — der Lauf-Timer lief nie los und Distanz blieb 0. Das endete
      // damit, dass der „Speichern"-Button im StopRunSheet dauerhaft disabled
      // war und der Nutzer den Lauf gar nicht aufzeichnen konnte.
      // Jetzt: Fallback-Tracking starten, damit Zeit/Distanz mitlaufen, und
      // parallel die Berechtigung anfragen. Sobald die Permission erteilt
      // wird, schaltet `.onChange(authorizationStatus)` auf echtes GPS um.
      if gpsTracker.canRequestPermission {
        gpsTracker.requestAuthorization()
      }
      gpsTracker.beginFallbackTracking(from: run)
    }
  }

  private func syncStoreWithTracker() {
    guard gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback else { return }
    store.syncActiveRunGPS(
      distanceKm: gpsTracker.trackedDistanceKm,
      durationMinutes: gpsTracker.durationMinutes,
      elevationGain: gpsTracker.elevationGain,
      routeCoordinates: gpsTracker.routeCoordinates,
      splits: gpsTracker.splits
    )
  }

  private func tickHRZoneAndCues() {
    guard let run = store.activeRun, !run.isPaused else { return }
    if run.currentHeartRate > 0 {
      store.tickRunHeartRateZone(currentBpm: run.currentHeartRate)
    }
    // Audio-Cue an jedem vollen Kilometer
    let currentKm = Int(gpsTracker.trackedDistanceKm)
    if run.audioCuesEnabled, currentKm > lastSpokenKilometer, currentKm >= 1 {
      lastSpokenKilometer = currentKm
      let pace = displayedPaceLabel(for: gpsTracker)
      audio.speak("Kilometer \(currentKm). Pace \(pace).")
    }
    // Strukturiertes Workout: Step-Wechsel triggern + Audio-Cue beim neuen Step.
    if store.activeStructuredWorkout != nil {
      let previousIndex = store.activeStructuredWorkout?.currentStepIndex ?? -1
      let stepChanged = store.tickStructuredWorkout(
        distanceKm: gpsTracker.trackedDistanceKm,
        elapsedSeconds: gpsTracker.elapsedSeconds
      )
      if stepChanged, run.audioCuesEnabled,
         let active = store.activeStructuredWorkout,
         let step = active.currentStep,
         active.currentStepIndex != lastSpokenStepIndex,
         active.currentStepIndex != previousIndex {
        lastSpokenStepIndex = active.currentStepIndex
        let label = step.target.displayLabel
        audio.speak("\(step.kind.title). \(label).")
      } else if !stepChanged, store.activeStructuredWorkout?.isFinished == true,
                lastSpokenStepIndex != Int.max, run.audioCuesEnabled {
        lastSpokenStepIndex = Int.max
        audio.speak("Workout abgeschlossen. Lauf läuft frei weiter.")
      }
    }
  }

  private func displayedPaceLabel(for tracker: RunLocationTracker) -> String {
    guard tracker.trackedDistanceKm > 0 else { return "noch unbekannt" }
    let secsPerKm = Int(Double(tracker.elapsedSeconds) / tracker.trackedDistanceKm)
    let m = secsPerKm / 60
    let s = secsPerKm % 60
    return "\(m) Minuten \(s) Sekunden pro Kilometer"
  }

  // MARK: – Aktionen

  private func togglePause(_ run: ActiveRunSession) {
    store.toggleRunPause()
    // Nach dem Toggle den neuen State aus dem Store lesen (nicht `run` — das ist
    // eine struct-Kopie mit dem PRE-toggle-Wert und würde die Logik umkehren).
    let nowPaused = store.activeRun?.isPaused ?? false
    if nowPaused {
      gpsTracker.pauseTracking()
      audio.speak("Pausiert.")
    } else {
      gpsTracker.resumeTracking()
      audio.speak("Lauf fortgesetzt.")
    }
  }

  private func handleAutoPause(_ paused: Bool) {
    guard let run = store.activeRun, run.autoPauseEnabled else { return }
    if paused, !run.isPaused {
      store.toggleRunPause()
      audio.speak("Auto-Pause.")
    } else if !paused, run.isPaused {
      store.toggleRunPause()
      audio.speak("Lauf fortgesetzt.")
    }
  }

  private func handleManualLap() {
    // Der Tracker fügt den Lap an `splits` an; via `syncStoreWithTracker`
    // (onReceive auf gpsTracker.$splits) landet er automatisch im Store.
    _ = gpsTracker.recordManualLap()
    audio.speak("Lap.")
  }

  private func stopTracking() {
    gpsTracker.stopTracking()
  }

  private func finishRun(title: String, note: String, feel: RunFeel?) {
    syncStoreWithTracker()
    stopTracking()
    audio.speak("Lauf beendet.")
    store.finishRun(customTitle: title, note: note, feel: feel)
  }
}

// MARK: - PreRunSetupView

private struct PreRunSetupView: View {
  @ObservedObject var store: GainsStore
  @ObservedObject var gpsTracker: RunLocationTracker
  let onStart: () -> Void

  @State private var selectedIntensity: RunIntensity = .free
  @State private var targetMode: RunTargetMode = .free
  @State private var targetDistance: Double = 5.0
  @State private var targetDurationMinutes: Int = 30
  @State private var targetPaceSeconds: Int = 5 * 60 + 30  // 5:30 /km
  @State private var autoPauseEnabled: Bool = true
  @State private var audioCuesEnabled: Bool = true

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 22) {
        header

        intensityPicker

        targetSection

        optionsSection

        Color.clear.frame(height: 12)
      }
      .padding(.horizontal, 24)
      .padding(.top, 8)
    }
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 8) {
        gpsStatusRow
        Button {
          applyAndStart()
        } label: {
          Text("Lauf starten")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(GainsColor.onLime)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 18)
      .padding(.top, 12)
      .background(GainsColor.background)
    }
  }

  // MARK: Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("LAUF")
        .gainsEyebrow(GainsColor.softInk, size: 12, tracking: 2.4)

      Text("Bereit?")
        .font(.system(size: 38, weight: .semibold))
        .foregroundStyle(GainsColor.ink)

      Text(summaryLine)
        .font(GainsFont.body(15))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var summaryLine: String {
    var parts: [String] = []
    if let run = store.latestCompletedRun {
      parts.append("Zuletzt: \(String(format: "%.1f", run.distanceKm)) km · \(run.routeName)")
    }
    let pace = store.averageRunPaceSeconds
    if pace > 0 {
      let m = pace / 60
      let s = pace % 60
      parts.append(String(format: "Ø %d:%02d /km", m, s))
    }
    return parts.isEmpty ? "Wähle Intensität und Ziel — du kannst später jederzeit anpassen." : parts.joined(separator: "  ·  ")
  }

  // MARK: Intensity

  private var intensityPicker: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("INTENSITÄT")
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(RunIntensity.allCases, id: \.self) { intensity in
            Button { selectedIntensity = intensity } label: {
              intensityChip(for: intensity, isSelected: intensity == selectedIntensity)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func intensityChip(for intensity: RunIntensity, isSelected: Bool) -> some View {
    HStack(spacing: 8) {
      Image(systemName: intensity.systemImage)
        .font(.system(size: 13, weight: .semibold))
      Text(intensity.title)
        .font(.system(size: 13, weight: .semibold))
    }
    .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.ink)
    .padding(.horizontal, 14)
    .frame(height: 38)
    .background(isSelected ? GainsColor.lime : GainsColor.card)
    .clipShape(Capsule())
  }

  // MARK: Target

  private var targetSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("ZIEL")
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: 8) {
        ForEach(RunTargetMode.allCases, id: \.self) { mode in
          Button { targetMode = mode } label: {
            Text(mode.title)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(targetMode == mode ? GainsColor.onLime : GainsColor.ink)
              .frame(maxWidth: .infinity)
              .frame(height: 36)
              .background(targetMode == mode ? GainsColor.lime : GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }

      targetDetailRow
    }
  }

  @ViewBuilder
  private var targetDetailRow: some View {
    switch targetMode {
    case .free:
      Text("Du läufst frei — kein Distanz- oder Zeit-Ziel.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .padding(.vertical, 4)
    case .distance:
      stepperRow(
        label: "Distanz",
        valueText: String(format: "%.1f km", targetDistance),
        decrement: { targetDistance = max(targetDistance - 0.5, 0.5) },
        increment: { targetDistance = min(targetDistance + 0.5, 60) }
      )
    case .duration:
      stepperRow(
        label: "Dauer",
        valueText: "\(targetDurationMinutes) min",
        decrement: { targetDurationMinutes = max(targetDurationMinutes - 5, 5) },
        increment: { targetDurationMinutes = min(targetDurationMinutes + 5, 240) }
      )
    case .pace:
      stepperRow(
        label: "Pace",
        valueText: paceLabel(targetPaceSeconds) + " /km",
        decrement: { targetPaceSeconds = max(targetPaceSeconds - 5, 3 * 60) },
        increment: { targetPaceSeconds = min(targetPaceSeconds + 5, 9 * 60) }
      )
    }
  }

  private func stepperRow(label: String, valueText: String, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
    HStack(spacing: 14) {
      Text(label)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.ink)

      Spacer()

      Button(action: decrement) {
        Image(systemName: "minus")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(GainsColor.ink)
          .frame(width: 36, height: 36)
          .background(GainsColor.card)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)

      Text(valueText)
        .font(.system(size: 18, weight: .semibold, design: .rounded))
        .foregroundStyle(GainsColor.ink)
        .frame(minWidth: 100)

      Button(action: increment) {
        Image(systemName: "plus")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(GainsColor.ink)
          .frame(width: 36, height: 36)
          .background(GainsColor.card)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 4)
  }

  // MARK: Options

  private var optionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("OPTIONEN")
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      Toggle(isOn: $autoPauseEnabled) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Auto-Pause")
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
          Text("Stoppt die Zeit automatisch, wenn du stehen bleibst.")
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
        }
      }
      .tint(GainsColor.lime)

      Toggle(isOn: $audioCuesEnabled) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Audio-Hinweise")
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
          Text("Sprachausgabe bei jedem Kilometer mit aktueller Pace.")
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
        }
      }
      .tint(GainsColor.lime)
    }
    .padding(14)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: GPS-Status

  private var gpsStatusRow: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(gpsTracker.canStartTracking ? GainsColor.lime : GainsColor.softInk)
        .frame(width: 6, height: 6)
      Text(gpsTracker.canStartTracking ? "GPS BEREIT" : "GPS WIRD VORBEREITET")
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)
      Spacer()
    }
  }

  // MARK: Apply

  private func applyAndStart() {
    if store.activeRun == nil {
      store.startQuickRun()
    }
    store.setRunIntensity(selectedIntensity)
    store.setRunTarget(
      mode: targetMode,
      distanceKm: targetDistance,
      durationMinutes: targetDurationMinutes,
      paceSeconds: targetPaceSeconds
    )
    store.setAutoPause(autoPauseEnabled)
    store.setAudioCues(audioCuesEnabled)
    onStart()
  }

  private func paceLabel(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
  }
}

// MARK: - CountdownView

private struct CountdownView: View {
  let value: Int

  var body: some View {
    VStack(spacing: 16) {
      Text("START IN")
        .font(GainsFont.label(11))
        .tracking(2.0)
        .foregroundStyle(GainsColor.softInk)

      Text(value > 0 ? "\(value)" : "GO")
        .font(.system(size: 140, weight: .black, design: .rounded))
        .foregroundStyle(GainsColor.lime)
        .contentTransition(.numericText())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: value)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - LiveRunView

private struct LiveRunView: View {
  let run: ActiveRunSession
  @ObservedObject var gpsTracker: RunLocationTracker
  let maxHeartRate: Int
  /// Optional: aktives strukturiertes Workout — zeigt Schritt-Banner.
  let activeWorkout: ActiveStructuredWorkout?
  let onTogglePause: () -> Void
  let onLap: () -> Void
  let onStop: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 14) {
        statusRow

        Text(formattedRunTime)
          .font(.system(size: 56, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)

        if run.targetMode != .free {
          targetProgressBar
        }

        if let workout = activeWorkout, !workout.isFinished {
          structuredWorkoutBanner(workout)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 24)
      .padding(.top, 8)
      .padding(.bottom, 18)

      routeSection

      VStack(spacing: 16) {
        liveMetricsRow
        if run.currentHeartRate > 0 {
          hrZoneRow
        }
        liveControls
        if !displayedSplits.isEmpty {
          splitsStrip
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 18)
      .background(GainsColor.card)
    }
  }

  // MARK: Status

  private var statusRow: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(run.isPaused ? GainsColor.softInk : GainsColor.lime)
        .frame(width: 8, height: 8)

      Text(statusText)
        .font(GainsFont.label(11))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      Spacer()

      Text(run.intensity.shortLabel)
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.lime)
    }
  }

  private var statusText: String {
    if run.isPaused { return "PAUSIERT" }
    if gpsTracker.isUsingGPS { return "GPS LIVE" }
    return "LIVE"
  }

  // MARK: Structured Workout Banner

  private func structuredWorkoutBanner(_ workout: ActiveStructuredWorkout) -> some View {
    let step = workout.currentStep
    let progress = workout.currentStepProgress(
      distanceKm: gpsTracker.trackedDistanceKm,
      elapsedSeconds: gpsTracker.elapsedSeconds
    )
    let remaining = workout.remainingLabel(
      distanceKm: gpsTracker.trackedDistanceKm,
      elapsedSeconds: gpsTracker.elapsedSeconds
    )
    let stepColor: Color = {
      switch step?.kind {
      case .warmup:   return GainsColor.zone2
      case .work:     return GainsColor.zone4
      case .recovery: return GainsColor.zone1
      case .cooldown: return GainsColor.accentCool
      case .free:     return GainsColor.lime
      case .none:     return GainsColor.softInk
      }
    }()

    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Image(systemName: step?.kind.systemImage ?? "figure.run")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(stepColor)
          .frame(width: 28, height: 28)
          .background(stepColor.opacity(0.18))
          .clipShape(Circle())

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text((step?.kind.title ?? "—").uppercased())
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(stepColor)
            Text("STEP \(workout.currentStepIndex + 1)/\(workout.steps.count)")
              .font(GainsFont.label(9))
              .tracking(1.0)
              .foregroundStyle(GainsColor.softInk)
          }
          if let target = step?.target.displayLabel {
            Text(target + ((step?.targetPaceSeconds ?? 0) > 0
              ? " · Ziel \(formatPace(step?.targetPaceSeconds ?? 0)) /km"
              : ""))
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.ink)
          }
        }

        Spacer()

        Text(remaining)
          .font(.system(size: 17, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.card)
            .frame(height: 5)
          Capsule()
            .fill(stepColor)
            .frame(width: max(geo.size.width * progress, 4), height: 5)
        }
      }
      .frame(height: 5)
    }
    .padding(12)
    .background(GainsColor.card.opacity(0.85))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  // MARK: Target Progress

  private var targetProgressBar: some View {
    let progress = run.progressFraction(elapsedSeconds: gpsTracker.elapsedSeconds)
    return VStack(spacing: 4) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.card)
            .frame(height: 6)
          Capsule()
            .fill(GainsColor.lime)
            .frame(width: max(geo.size.width * progress, 4), height: 6)
        }
      }
      .frame(height: 6)

      HStack {
        Text(targetLabel)
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        Text("\(Int(progress * 100)) %")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
      }
    }
  }

  private var targetLabel: String {
    switch run.targetMode {
    case .free:     return ""
    case .distance: return "ZIEL · \(String(format: "%.1f", run.targetDistanceKm)) km"
    case .duration: return "ZIEL · \(run.targetDurationMinutes) min"
    case .pace:     return "ZIEL · \(formatPace(run.targetPaceSeconds)) /km"
    }
  }

  // MARK: Map / Route

  private var routeSection: some View {
    Map(position: .constant(gpsTracker.cameraPosition)) {
      if !displayedRouteCoordinates.isEmpty {
        MapPolyline(coordinates: displayedRouteCoordinates)
          .stroke(GainsColor.lime, lineWidth: 5)
      }
      if let coord = displayedRouteCoordinates.last ?? gpsTracker.currentCoordinate {
        Annotation("Aktuell", coordinate: coord) {
          Circle()
            .fill(GainsColor.lime)
            .frame(width: 16, height: 16)
            .overlay { Circle().stroke(GainsColor.ink, lineWidth: 3) }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: Metrics

  private var liveMetricsRow: some View {
    HStack(spacing: 0) {
      metric(title: "DISTANZ", value: String(format: "%.2f", displayedDistance), unit: "km")
      metricSeparator
      metric(title: "PACE", value: paceCompact(displayedPace), unit: "/km")
      metricSeparator
      metric(title: "HF", value: run.currentHeartRate > 0 ? "\(run.currentHeartRate)" : "–", unit: "bpm")
      metricSeparator
      metric(title: "ELEV", value: "+\(displayedElevation)", unit: "m")
    }
  }

  private var metricSeparator: some View {
    Rectangle()
      .fill(GainsColor.border.opacity(0.3))
      .frame(width: 1, height: 28)
  }

  private func metric(title: String, value: String, unit: String) -> some View {
    VStack(spacing: 6) {
      Text(title)
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 20, weight: .semibold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.6)

        Text(unit)
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: HF-Zone

  private var hrZoneRow: some View {
    let zone = HRZone.zone(for: run.currentHeartRate, maxHR: maxHeartRate)
    return HStack(spacing: 10) {
      ForEach(HRZone.allCases, id: \.self) { z in
        Circle()
          .fill(z.color(active: zone == z))
          .frame(width: zone == z ? 14 : 10, height: zone == z ? 14 : 10)
          .overlay {
            if zone == z {
              Circle().stroke(GainsColor.ink, lineWidth: 1.5)
            }
          }
          .animation(.spring(response: 0.3, dampingFraction: 0.7), value: zone)
      }
      Spacer()
      Text((zone?.title ?? "—").uppercased())
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
    }
    .padding(.horizontal, 12)
    .frame(height: 36)
    .background(GainsColor.background.opacity(0.85))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  // MARK: Controls

  private var liveControls: some View {
    HStack(spacing: 10) {
      Button(action: onTogglePause) {
        Text(run.isPaused ? "Fortsetzen" : "Pause")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(GainsColor.ink)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)

      Button(action: onLap) {
        VStack(spacing: 2) {
          Image(systemName: "flag.checkered")
            .font(.system(size: 14, weight: .semibold))
          Text("Lap")
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(GainsColor.ink)
        .frame(width: 60, height: 50)
        .background(GainsColor.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(run.isPaused)

      Button(action: onStop) {
        Text("Stopp")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(GainsColor.onLime)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(GainsColor.lime)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: Splits Strip

  private var splitsStrip: some View {
    let splits = displayedSplits.suffix(3)

    return VStack(alignment: .leading, spacing: 8) {
      Text("LETZTE SPLITS")
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: 8) {
        ForEach(Array(splits), id: \.id) { split in
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
              Text(split.isManualLap ? "LAP \(split.index)" : "KM \(split.index)")
                .font(GainsFont.label(9))
                .tracking(1.4)
                .foregroundStyle(GainsColor.softInk)
              if split.isManualLap {
                Image(systemName: "flag.checkered")
                  .font(.system(size: 8, weight: .semibold))
                  .foregroundStyle(GainsColor.lime)
              }
            }

            Text(paceCompact(split.paceSeconds))
              .font(.system(size: 16, weight: .semibold, design: .rounded))
              .foregroundStyle(GainsColor.ink)

            Text("\(split.averageHeartRate) bpm")
              .font(GainsFont.body(11))
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(GainsColor.background.opacity(0.9))
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
      }
    }
  }

  // MARK: Helpers

  private func paceCompact(_ seconds: Int) -> String {
    guard seconds > 0 else { return "–" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  private func formatPace(_ seconds: Int) -> String {
    guard seconds > 0 else { return "—" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  private var formattedRunTime: String {
    let totalSeconds = displayedDurationSeconds
    let h = totalSeconds / 3600
    let m = (totalSeconds % 3600) / 60
    let s = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
  }

  private var displayedDurationSeconds: Int {
    if gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback {
      return gpsTracker.elapsedSeconds
    }
    return run.durationMinutes * 60
  }

  private var displayedDistance: Double {
    (gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback)
      ? gpsTracker.trackedDistanceKm : run.distanceKm
  }

  private var displayedElevation: Int {
    (gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback)
      ? gpsTracker.elevationGain : run.elevationGain
  }

  private var displayedPace: Int {
    guard displayedDistance > 0 else { return 0 }
    return Int(Double(displayedDurationSeconds) / displayedDistance)
  }

  private var displayedSplits: [RunSplit] {
    (gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback)
      ? gpsTracker.splits : run.splits
  }

  private var displayedRouteCoordinates: [CLLocationCoordinate2D] {
    if gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback {
      return gpsTracker.routeCoordinates
    }
    return run.routeCoordinates
  }
}

// MARK: - StopRunSheet

private struct StopRunSheet: View {
  let run: ActiveRunSession?
  let onSave: (_ title: String, _ note: String, _ feel: RunFeel?) -> Void
  let onDiscard: () -> Void
  let onResume: () -> Void

  @State private var title: String = ""
  @State private var note: String = ""
  @State private var feel: RunFeel? = nil
  @State private var isConfirmingDiscard = false

  /// Speichern erlauben, sobald der Lauf entweder Distanz ODER mindestens
  /// eine halbe Minute Dauer aufgebaut hat. Vorher war ausschließlich
  /// `distanceKm > 0` ausschlaggebend — dadurch konnte der Nutzer einen Lauf
  /// nicht speichern, wenn das GPS keine Distanz lieferte (Indoor-Treadmill,
  /// fehlende Berechtigung, kein Fix). Jetzt reicht eine messbare Dauer.
  private var canSaveRun: Bool {
    guard let run else { return false }
    return run.distanceKm > 0 || run.durationMinutes >= 1
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          summaryHeader

          VStack(alignment: .leading, spacing: 8) {
            Text("NAME")
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(GainsColor.softInk)
            TextField(run?.title ?? "Lauf", text: $title)
              .textFieldStyle(.plain)
              .padding(12)
              .background(GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }

          feelPicker

          VStack(alignment: .leading, spacing: 8) {
            Text("NOTIZ")
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(GainsColor.softInk)
            TextField("Wie hat sich der Lauf angefühlt?", text: $note, axis: .vertical)
              .textFieldStyle(.plain)
              .lineLimit(3...6)
              .padding(12)
              .background(GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
        }
        .padding(20)
      }
      .background(GainsColor.background.ignoresSafeArea())
      .navigationTitle("Lauf beenden")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Weiter laufen", action: onResume)
            .foregroundStyle(GainsColor.ink)
        }
      }
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 10) {
          Button {
            onSave(title, note, feel)
          } label: {
            Text("Speichern")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(GainsColor.onLime)
              .frame(maxWidth: .infinity)
              .frame(height: 52)
              .background(GainsColor.lime)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(!canSaveRun)
          .opacity(canSaveRun ? 1 : 0.5)

          Button {
            isConfirmingDiscard = true
          } label: {
            Text("Verwerfen")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(GainsColor.softInk)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .background(GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .padding(.top, 8)
        .background(GainsColor.background)
      }
      .confirmationDialog(
        "Lauf wirklich verwerfen?",
        isPresented: $isConfirmingDiscard,
        titleVisibility: .visible
      ) {
        Button("Verwerfen", role: .destructive, action: onDiscard)
        Button("Abbrechen", role: .cancel) {}
      } message: {
        Text("Distanz, Pace und Splits werden nicht in deine Historie übernommen.")
      }
      .onAppear {
        if title.isEmpty { title = run?.title ?? "" }
      }
    }
  }

  // MARK: Header

  private var summaryHeader: some View {
    let distance = run?.distanceKm ?? 0
    let duration = run?.durationMinutes ?? 0
    let pace = run?.averagePaceSeconds ?? 0
    return HStack(alignment: .lastTextBaseline, spacing: 16) {
      summaryCell(value: String(format: "%.2f", distance), unit: "km")
      summaryCell(value: pace > 0 ? String(format: "%d:%02d", pace / 60, pace % 60) : "–:–", unit: "/km")
      summaryCell(value: "\(duration)", unit: "min")
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 4)
  }

  private func summaryCell(value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.system(size: 26, weight: .bold, design: .rounded))
        .foregroundStyle(GainsColor.ink)
      Text(unit)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Feel

  private var feelPicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("WIE WAR'S?")
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: 8) {
        ForEach(RunFeel.allCases, id: \.self) { f in
          Button { feel = (feel == f ? nil : f) } label: {
            VStack(spacing: 4) {
              Image(systemName: f.emojiSymbol)
                .font(.system(size: 18, weight: .semibold))
              Text("\(f.rawValue)")
                .font(GainsFont.label(9))
                .tracking(1.0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(feel == f ? GainsColor.onLime : GainsColor.ink)
            .background(feel == f ? GainsColor.lime : GainsColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }
}

// MARK: - RunAudioCueManager

/// Wrapper um AVSpeechSynthesizer für deutsche TTS-Cues (Audio-Hinweise).
final class RunAudioCueManager: ObservableObject {
  private let synth = AVSpeechSynthesizer()

  func speak(_ text: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
    utterance.rate = 0.5
    synth.stopSpeaking(at: .immediate)
    synth.speak(utterance)
  }
}

// MARK: - RunLocationTracker

final class RunLocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var authorizationStatus: CLAuthorizationStatus
  @Published var routeCoordinates: [CLLocationCoordinate2D] = []
  @Published var trackedDistanceKm: Double = 0
  @Published var elevationGain: Int = 0
  @Published var durationMinutes: Int = 0
  @Published var elapsedSeconds: Int = 0
  @Published var splits: [RunSplit] = []
  @Published var isUsingGPS = false
  @Published var isTrackingFallback = false
  @Published var autoPaused = false

  /// Wird vom View aus HealthKit befüllt und für Split-Durchschnitte genutzt.
  var currentHeartRate: Int = 0
  var autoPauseEnabled: Bool = true

  private let manager = CLLocationManager()
  private var lastLocation: CLLocation?
  private var timer: Timer?
  private var startReferenceDate: Date?
  private var pauseDate: Date?
  private var pausedDuration: TimeInterval = 0
  private var splitAnchorDistance: Double = 0
  private var splitAnchorDurationSeconds: Int = 0
  private var manualLapAnchorDistance: Double = 0
  private var manualLapAnchorDurationSeconds: Int = 0
  private var lastMovementDate: Date = Date()
  private var fallbackPaceSeconds = 381

  override init() {
    authorizationStatus = manager.authorizationStatus
    super.init()
    manager.delegate = self
    manager.activityType = .fitness
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 5
    // `allowsBackgroundLocationUpdates` wird erst in `beginTracking` aktiviert
    // (zusammen mit `showsBackgroundLocationIndicator`). Damit läuft das GPS
    // weiter, wenn der Nutzer das Display sperrt — Voraussetzung dafür ist der
    // `UIBackgroundModes = location`-Eintrag in den Build-Settings.
    // Außerhalb eines aktiven Laufs bleibt der Flag aus, damit iOS die App
    // nicht unnötig im Hintergrund hält.
    manager.allowsBackgroundLocationUpdates = false
    manager.pausesLocationUpdatesAutomatically = false
    if #available(iOS 11.0, *) {
      manager.showsBackgroundLocationIndicator = true
    }
    // Bug-Fix: KEIN direktes `startUpdatingLocation()` mehr im init.
    // Das lief vorher bereits beim Öffnen des Pre-Run-Setup-Bildschirms,
    // hat (a) den Akku unnötig belastet und (b) `didUpdateLocations`
    // gefüttert, was — zusammen mit dem fehlenden isUsingGPS-Gate im
    // Delegate — `trackedDistanceKm` schon vor dem Lauf hochzählen ließ.
    // Wir starten Updates jetzt explizit in `beginTracking(from:)`.
  }

  var canRequestPermission: Bool {
    authorizationStatus == .notDetermined
  }

  var canStartTracking: Bool {
    authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
  }

  var currentCoordinate: CLLocationCoordinate2D? {
    manager.location?.coordinate
  }

  var cameraPosition: MapCameraPosition {
    if let last = routeCoordinates.last {
      return .region(
        MKCoordinateRegion(
          center: last,
          span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
      )
    }
    if let coord = currentCoordinate {
      return .region(
        MKCoordinateRegion(
          center: coord,
          span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
      )
    }
    return .region(
      MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
      )
    )
  }

  func requestAuthorization() {
    manager.requestWhenInUseAuthorization()
  }

  func beginTracking(from run: ActiveRunSession) {
    guard canStartTracking else { return }
    guard !isUsingGPS else { return }

    // Falls bereits ein Fallback-Tracking läuft (Berechtigung wurde während
    // eines laufenden Laufs erteilt), fließend auf GPS umschalten — bestehende
    // Distanz/Zeit bleiben über `prepareTrackingState(from: run)` erhalten,
    // weil der Store via `syncStoreWithTracker` die Fallback-Werte schon
    // mitführt.
    if isTrackingFallback {
      isTrackingFallback = false
      stopTimer()
    }

    prepareTrackingState(from: run)
    isUsingGPS = true
    // Hintergrund-Location erst jetzt erlauben — sonst hält iOS die App
    // dauerhaft im Hintergrund am Leben. Beim Stop wird der Flag wieder
    // entfernt. Defensiv: nur setzen, wenn `UIBackgroundModes` tatsächlich
    // `location` enthält — sonst löst iOS einen Hard-Crash aus.
    if Self.hasLocationBackgroundMode {
      manager.allowsBackgroundLocationUpdates = true
    }
    manager.startUpdatingLocation()
    startTimer()
  }

  /// Liest Info.plist einmalig: enthält `UIBackgroundModes` den Wert `location`?
  /// Schützt davor, `allowsBackgroundLocationUpdates` zu setzen, wenn die
  /// Build-Konfiguration den Background-Mode nicht eingetragen hat — in dem
  /// Fall stürzt iOS sonst die App ab.
  private static let hasLocationBackgroundMode: Bool = {
    let raw = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes")
    if let array = raw as? [String] {
      return array.contains("location")
    }
    if let single = raw as? String {
      return single.contains("location")
    }
    return false
  }()

  func beginFallbackTracking(from run: ActiveRunSession) {
    guard !isUsingGPS else { return }
    guard !isTrackingFallback else { return }

    prepareTrackingState(from: run)
    isTrackingFallback = true
    fallbackPaceSeconds = max(run.averagePaceSeconds, 330)
    startTimer()
  }

  func pauseTracking() {
    guard isUsingGPS || isTrackingFallback else { return }
    pauseDate = Date()
    manager.stopUpdatingLocation()
    stopTimer()
  }

  func resumeTracking() {
    guard isUsingGPS || isTrackingFallback else { return }

    if let pauseDate {
      pausedDuration += Date().timeIntervalSince(pauseDate)
      self.pauseDate = nil
    }
    autoPaused = false
    lastMovementDate = Date()

    if isUsingGPS {
      manager.startUpdatingLocation()
    }

    startTimer()
  }

  func stopTracking() {
    isUsingGPS = false
    isTrackingFallback = false
    autoPaused = false
    manager.stopUpdatingLocation()
    // Hintergrund-Berechtigung wieder einkassieren — die App soll außerhalb
    // eines Laufs nicht in den Hintergrund-Lebenszyklus eingebucht bleiben.
    // Symmetrisch zu `beginTracking`: nur zurücksetzen, wenn der Background-
    // Mode tatsächlich konfiguriert ist.
    if Self.hasLocationBackgroundMode {
      manager.allowsBackgroundLocationUpdates = false
    }
    stopTimer()
  }

  // MARK: – Manueller Lap

  struct LapResult {
    let distanceKm: Double
    let durationSeconds: Int
    let heartRate: Int
  }

  /// Zeichnet einen manuellen Lap auf — Distanz/Zeit ab dem letzten Lap-Anker.
  @discardableResult
  func recordManualLap() -> LapResult {
    let distance = max(trackedDistanceKm - manualLapAnchorDistance, 0.05)
    let duration = max(elapsedSeconds - manualLapAnchorDurationSeconds, 1)
    let hr = currentHeartRate > 0 ? currentHeartRate : 0
    let split = RunSplit(
      id: UUID(),
      index: splits.count + 1,
      distanceKm: distance,
      durationMinutes: max(Int((Double(duration) / 60).rounded()), 1),
      averageHeartRate: hr,
      isManualLap: true
    )
    splits.append(split)
    manualLapAnchorDistance = trackedDistanceKm
    manualLapAnchorDurationSeconds = elapsedSeconds
    return LapResult(distanceKm: distance, durationSeconds: duration, heartRate: hr)
  }

  // MARK: – CLLocationManagerDelegate

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // Bug-Fix: Updates nur verarbeiten, wenn wir tatsächlich tracken.
    // Vorher liefen `trackedDistanceKm`, `routeCoordinates` etc. schon im
    // Pre-Run-Setup mit, weil `manager.startUpdatingLocation()` im init
    // gerufen wurde. `beginTracking` setzt zwar `prepareTrackingState`,
    // aber zwischen Setup und beginTracking konnten Werte verloren gehen
    // (durch reset) bzw. landete unnötiges Logging im Tracker.
    guard isUsingGPS else { return }

    for location in locations where location.horizontalAccuracy > 0 {
      // Stabilitäts-Fix: updateDuration() hier entfernt. Der 1-Sekunden-Timer
      // ruft updateDuration() bereits zuverlässig auf. GPS-Updates kommen je
      // nach Fix-Rate ≥1 Hz und lösten updateDuration() damit häufiger als
      // nötig aus — das publizierte elapsedSeconds unkontrolliert schnell und
      // ließ tickHRZoneAndCues() (Audio-Cues, Step-Fortschritt) mehrfach pro
      // Sekunde feuern. Jetzt läuft der Takt ausschließlich über den Timer.

      // Auto-Pause-Erkennung — Geschwindigkeit + Bewegung seit Last-Update
      let speed = max(location.speed, 0) // m/s
      if speed > 0.5 {
        lastMovementDate = location.timestamp
        if autoPaused { autoPaused = false }
      }

      if let lastLocation {
        let delta = location.distance(from: lastLocation)
        if delta >= 3, delta <= 250 {
          trackedDistanceKm += delta / 1000

          let elevationDelta = location.altitude - lastLocation.altitude
          if elevationDelta > 0 {
            elevationGain += Int(elevationDelta.rounded())
          }
        }
      }

      lastLocation = location
      routeCoordinates.append(location.coordinate)
      generateAutomaticSplits(currentHeartRate: currentHeartRate > 0 ? currentHeartRate : 140)
    }
  }

  // MARK: – Privates

  private func prepareTrackingState(from run: ActiveRunSession) {
    trackedDistanceKm = run.distanceKm
    elevationGain = run.elevationGain
    durationMinutes = run.durationMinutes
    elapsedSeconds = run.durationMinutes * 60
    routeCoordinates = run.routeCoordinates
    splits = run.splits
    splitAnchorDistance = run.distanceKm
    splitAnchorDurationSeconds = run.durationMinutes * 60
    manualLapAnchorDistance = run.distanceKm
    manualLapAnchorDurationSeconds = run.durationMinutes * 60
    lastLocation = nil
    pausedDuration = 0
    pauseDate = nil
    autoPaused = false
    lastMovementDate = Date()
    startReferenceDate = Date().addingTimeInterval(-TimeInterval(run.durationMinutes * 60))
  }

  private func startTimer() {
    guard timer == nil else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.updateDuration()
      self?.checkAutoPause()
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  private func updateDuration() {
    guard let startReferenceDate else { return }
    let effectiveElapsed = Date().timeIntervalSince(startReferenceDate) - pausedDuration
    elapsedSeconds = max(Int(effectiveElapsed), elapsedSeconds)
    durationMinutes = max(Int(effectiveElapsed / 60), durationMinutes)

    if isTrackingFallback {
      trackedDistanceKm = max(
        trackedDistanceKm, Double(elapsedSeconds) / Double(fallbackPaceSeconds))
      generateAutomaticSplits(currentHeartRate: currentHeartRate > 0 ? currentHeartRate : 140)
    }
  }

  /// Auto-Pause: Wenn länger als 5 Sekunden keine echte Bewegung (Speed < 0.5 m/s
  /// bzw. keine GPS-Positionsänderung), markieren wir den Tracker als
  /// `autoPaused`. Die View kann darauf reagieren und den Store synchronisieren.
  private func checkAutoPause() {
    guard autoPauseEnabled, isUsingGPS else { return }
    let stationaryFor = Date().timeIntervalSince(lastMovementDate)
    if !autoPaused, stationaryFor > 5 {
      autoPaused = true
    }
  }

  private func generateAutomaticSplits(currentHeartRate: Int) {
    while trackedDistanceKm - splitAnchorDistance >= 1.0 {
      let durationDelta = max(elapsedSeconds - splitAnchorDurationSeconds, 1)
      splits.append(
        RunSplit(
          id: UUID(),
          index: splits.count + 1,
          distanceKm: 1.0,
          durationMinutes: max(Int((Double(durationDelta) / 60).rounded()), 1),
          averageHeartRate: currentHeartRate,
          isManualLap: false
        )
      )
      splitAnchorDistance += 1.0
      splitAnchorDurationSeconds = elapsedSeconds
    }
  }
}
