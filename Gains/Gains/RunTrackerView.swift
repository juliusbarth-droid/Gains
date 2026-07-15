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
  @State private var suppressNextAutoPauseSync = false
  /// 2026-05-01 P1-4: Bestätigungs-Dialog wenn der User im Countdown auf
  /// „Schließen" tippt — vorher wurde der Lauf in der Vorbereitung sofort
  /// verworfen, was ärgerlich ist wenn man Ziel/Modus schon eingestellt hat.
  @State private var isConfirmingCountdownAbort = false

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
              onStop: {
                isConfirmingCountdownAbort = false
                suppressNextAutoPauseSync = false
                showsStopSheet = true
              }
            )
          } else {
            PreRunSetupView(
              store: store,
              gpsTracker: gpsTracker,
              onStart: beginCountdown
            )
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(hasVisibleLiveRun ? "Abschließen" : "Schließen") {
            if hasVisibleLiveRun {
              isConfirmingCountdownAbort = false
              suppressNextAutoPauseSync = false
              showsStopSheet = true
            } else {
              switch phase {
              case .countdown:
                // P1-4: Im Countdown-Phase Bestätigung verlangen, weil
                // Setup (Ziel/Modus/Audio-Cues) sonst verloren ist.
                showsStopSheet = false
                suppressNextAutoPauseSync = false
                isConfirmingCountdownAbort = true
              case .setup, .live:
                showsStopSheet = false
                showsWearablePicker = false
                isConfirmingCountdownAbort = false
                suppressNextAutoPauseSync = false
                stopTracking()
                if store.activeRun != nil {
                  store.discardActiveRun()
                }
                dismiss()
              }
            }
          }
          .foregroundStyle(GainsColor.ink)
          .accessibilityLabel(hasVisibleLiveRun ? "Lauf abschließen" : "Laufansicht schließen")
          .accessibilityValue(hasVisibleLiveRun ? "Aktiver Lauf, kann gespeichert, fortgesetzt oder verworfen werden" : (phase == .countdown ? "Lauf wird vorbereitet" : "Kein aktiver Lauf"))
          .accessibilityHint(hasVisibleLiveRun ? "Öffnet die Abschlussansicht, in der du deinen aktiven Lauf speichern, fortsetzen oder verwerfen kannst" : (phase == .countdown ? "Öffnet die Bestätigung, in der du die aktuelle Lauf-Vorbereitung fortsetzen oder verwerfen kannst" : "Schließt die Laufansicht und verwirft den aktuellen Einstieg"))
        }
      }
      // 2026-05-15 (Audit-Loop 20): Labels waren irreführend — „Abbrechen"
      // war als destructive markiert (= Setup verwerfen), was im Dialog-
      // Kontext genau umgekehrt zur User-Erwartung ist (Abbrechen = Dialog
      // schließen, nicht Daten verwerfen). Jetzt klare Labels.
      .confirmationDialog(
        "Lauf-Vorbereitung verwerfen?",
        isPresented: $isConfirmingCountdownAbort,
        titleVisibility: .visible
      ) {
        Button("Vorbereitung verwerfen", role: .destructive) {
          isConfirmingCountdownAbort = false
          suppressNextAutoPauseSync = false
          cancelCountdown()
          countdownValue = 3
          lastSpokenKilometer = 0
          lastSpokenStepIndex = -1
          gpsTracker.currentHeartRate = 0
          showsWearablePicker = false
          stopTracking()
          if store.activeRun != nil {
            store.discardActiveRun()
          }
          showsStopSheet = false
          phase = .setup
          dismiss()
        }
        Button("Vorbereitung fortsetzen", role: .cancel) {}
      } message: {
        Text("Wenn du die Vorbereitung fortsetzt, bleiben Ziel und Modus erhalten. Wenn du sie verwirfst, gehen sie verloren.")
      }
      .sheet(isPresented: $showsStopSheet) {
        StopRunSheet(
          run: store.activeRun,
          isAutoPaused: gpsTracker.autoPaused,
          // 2026-05-01 P1-5: Sekunden-genaue Save-Bedingung — durationMinutes
          // (Int) ist 0 für Läufe < 60s, dadurch konnte ein 45s-Lauf nicht
          // gespeichert werden. Wir reichen die exakten Sekunden aus dem
          // GPS-Tracker durch.
          elapsedSeconds: gpsTracker.elapsedSeconds,
          onSave: { title, note, feel in
            isConfirmingCountdownAbort = false
            suppressNextAutoPauseSync = false
            cancelCountdown()
            countdownValue = 3
            lastSpokenKilometer = 0
            lastSpokenStepIndex = -1
            showsWearablePicker = false
            finishRun(title: title, note: note, feel: feel)
            phase = .setup
            showsStopSheet = false
            dismiss()
          },
          onDiscard: {
            isConfirmingCountdownAbort = false
            suppressNextAutoPauseSync = false
            cancelCountdown()
            countdownValue = 3
            lastSpokenKilometer = 0
            lastSpokenStepIndex = -1
            showsWearablePicker = false
            stopTracking()
            store.discardActiveRun()
            phase = .setup
            showsStopSheet = false
            dismiss()
          },
          onResume: {
            isConfirmingCountdownAbort = false
            showsStopSheet = false
            if let run = store.activeRun {
              phase = .live
              if run.isPaused {
                suppressNextAutoPauseSync = true
                store.toggleRunPause()
                HealthKitManager.shared.startHeartRateObserver()
                gpsTracker.resumeTracking()
              } else {
                suppressNextAutoPauseSync = false
                synchronizeTrackerState()
              }
            } else {
              suppressNextAutoPauseSync = false
              phase = .setup
              showsWearablePicker = false
              cancelCountdown()
              countdownValue = 3
              lastSpokenKilometer = 0
              lastSpokenStepIndex = -1
              gpsTracker.currentHeartRate = 0
            }
          }
        )
        .environmentObject(store)
        .presentationDetents([.medium, .large])
      }
    }
    .onAppear {
      showsStopSheet = false
      isConfirmingCountdownAbort = false
      suppressNextAutoPauseSync = false

      if store.activeRun == nil, store.activeStructuredWorkout != nil {
        store.endStructuredWorkout()
      }

      // Wenn beim Öffnen schon ein Lauf aktiv ist (z.B. App im Hintergrund war),
      // direkt in den Live-Screen springen und State synchronisieren.
      if store.activeRun != nil {
        showsWearablePicker = false
        phase = .live
        synchronizeTrackerState()
      } else {
        showsStopSheet = false
        showsWearablePicker = false
        phase = .setup
        cancelCountdown()
        countdownValue = 3
        lastSpokenKilometer = 0
        lastSpokenStepIndex = -1
        gpsTracker.currentHeartRate = 0
        stopTracking()
      }
    }
    .onDisappear {
      showsStopSheet = false
      isConfirmingCountdownAbort = false
      showsWearablePicker = false
      suppressNextAutoPauseSync = false
      cancelCountdown()
      if store.activeRun == nil {
        phase = .setup
        countdownValue = 3
        lastSpokenKilometer = 0
        lastSpokenStepIndex = -1
        stopTracking()
      } else {
        HealthKitManager.shared.stopHeartRateObserver()
      }
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
      guard !showsStopSheet, !isConfirmingCountdownAbort else { return }
      guard let run = store.activeRun, !run.isPaused else { return }
      guard let bpm else {
        gpsTracker.currentHeartRate = 0
        store.clearRunHeartRateLive()
        return
      }
      gpsTracker.currentHeartRate = bpm
      store.updateRunHeartRateLive(bpm)
    }
    .onChange(of: store.activeRun?.id) { _, _ in
      guard !showsStopSheet, !isConfirmingCountdownAbort else { return }
      if store.activeRun != nil {
        phase = .live
      }
      synchronizeTrackerState()
    }
    .onChange(of: gpsTracker.authorizationStatus) { _, _ in
      guard
        let activeRun = store.activeRun,
        activeRun.modality.requiresGPS,
        phase == .live,
        !showsStopSheet,
        !isConfirmingCountdownAbort
      else { return }
      synchronizeTrackerState()
    }
  }

  private var hasVisibleLiveRun: Bool {
    phase == .live && store.activeRun != nil
  }

  // MARK: – Phase-Übergänge

  private func beginCountdown() {
    showsStopSheet = false
    showsWearablePicker = false
    isConfirmingCountdownAbort = false
    suppressNextAutoPauseSync = false
    lastSpokenKilometer = 0
    lastSpokenStepIndex = -1
    gpsTracker.currentHeartRate = 0
    countdownValue = 3
    phase = .countdown
    audio.speak("Drei.")
    countdownTimer?.invalidate()
    let ct = Timer(timeInterval: 1, repeats: true) { _ in
      countdownValue -= 1
      if countdownValue == 2 { audio.speak("Zwei.") }
      if countdownValue == 1 { audio.speak("Eins.") }
      if countdownValue <= 0 {
        countdownTimer?.invalidate()
        countdownTimer = nil
        startRunNow()
      }
    }
    RunLoop.main.add(ct, forMode: .common)
    countdownTimer = ct
  }

  private func cancelCountdown() {
    countdownTimer?.invalidate()
    countdownTimer = nil
  }

  private func startRunNow() {
    cancelCountdown()
    showsStopSheet = false
    showsWearablePicker = false
    isConfirmingCountdownAbort = false
    suppressNextAutoPauseSync = false
    lastSpokenKilometer = 0
    lastSpokenStepIndex = -1
    gpsTracker.currentHeartRate = 0
    countdownValue = 3
    phase = .live
    if store.activeRun == nil {
      store.startQuickRun()
    }
    if store.activeRun?.modality.requiresGPS == true {
      gpsTracker.requestAuthorization()
    }
    HealthKitManager.shared.startHeartRateObserver()
    let modality = store.activeRun?.modality ?? .run
    switch modality {
    case .run:         audio.speak("Lauf gestartet.")
    case .bikeOutdoor: audio.speak("Fahrt gestartet.")
    case .bikeIndoor:  audio.speak("Indoor-Bike gestartet.")
    }
    synchronizeTrackerState()
  }

  // MARK: – Tracker-Sync

  private func synchronizeTrackerState() {
    guard let run = store.activeRun else {
      showsStopSheet = false
      showsWearablePicker = false
      isConfirmingCountdownAbort = false
      suppressNextAutoPauseSync = false
      cancelCountdown()
      phase = .setup
      countdownValue = 3
      lastSpokenKilometer = 0
      lastSpokenStepIndex = -1
      gpsTracker.currentHeartRate = 0
      stopTracking()
      return
    }

    gpsTracker.autoPauseEnabled = run.autoPauseEnabled
    // 2026-05-01 P1 Bike-Fix: Modalität in den GPS-Tracker spiegeln, damit die
    // Speed-Validation den richtigen Schwellwert nutzt (Lauf 10 m/s vs. Rad
    // 25 m/s). Vorher blieb der Wert konstant `.run` — Bike-Sessions haben
    // legitime Punkte oberhalb von 36 km/h verworfen.
    gpsTracker.cardioModality = run.modality

    guard !run.isPaused else {
      suppressNextAutoPauseSync = false
      if run.modality.requiresGPS {
        gpsTracker.requestAuthorization()
      }
      HealthKitManager.shared.stopHeartRateObserver()
      gpsTracker.currentHeartRate = 0
      store.clearRunHeartRateLive()
      gpsTracker.restorePausedTracking(from: run)
      return
    }

    // 2026-05-03: Indoor-Bike (Heimtrainer/Spinning) bekommt einen eigenen
    // Tracking-Pfad ohne GPS — kein Authorize, kein Map-Updates, nur Timer.
    // Distanz wird vom LiveRunView per Stepper-Tile manuell hochgeschoben.
    if !run.modality.requiresGPS {
      gpsTracker.beginIndoorTracking(from: run)
      return
    }

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
    guard gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback || gpsTracker.isIndoor else { return }
    guard store.activeRun != nil else {
      guard !showsStopSheet, !isConfirmingCountdownAbort else { return }
      synchronizeTrackerState()
      return
    }
    store.syncActiveRunGPS(
      distanceKm: gpsTracker.trackedDistanceKm,
      durationMinutes: gpsTracker.durationMinutes,
      elevationGain: gpsTracker.elevationGain,
      routeCoordinates: gpsTracker.routeCoordinates,
      splits: gpsTracker.splits
    )
  }

  private func tickHRZoneAndCues() {
    guard !showsStopSheet, !isConfirmingCountdownAbort else { return }
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
        audio.speak("Training abgeschlossen. Lauf läuft frei weiter.")
      }
    }
  }

  private func displayedPaceLabel(for tracker: RunLocationTracker) -> String {
    guard tracker.trackedDistanceKm > 0 else { return "noch unbekannt" }
    if tracker.cardioModality.isCycling {
      let kmh = (Double(tracker.elapsedSeconds) > 0)
        ? tracker.trackedDistanceKm * 3600.0 / Double(tracker.elapsedSeconds)
        : 0
      return String(format: "%.1f Kilometer pro Stunde", kmh)
    }
    let secsPerKm = Int(Double(tracker.elapsedSeconds) / tracker.trackedDistanceKm)
    let m = secsPerKm / 60
    let s = secsPerKm % 60
    return "\(m) Minuten \(s) Sekunden pro Kilometer"
  }

  // MARK: – Aktionen

  private func pauseAnnouncement(for modality: CardioModality) -> String {
    switch modality {
    case .run: return "Pausiert."
    case .bikeOutdoor: return "Fahrt pausiert."
    case .bikeIndoor: return "Indoor-Bike pausiert."
    }
  }

  private func autoPauseAnnouncement(for modality: CardioModality) -> String {
    switch modality {
    case .run: return "Auto-Pause."
    case .bikeOutdoor: return "Fahrt automatisch pausiert."
    case .bikeIndoor: return "Indoor-Bike automatisch pausiert."
    }
  }

  private func resumeAnnouncement(for modality: CardioModality) -> String {
    switch modality {
    case .run: return "Lauf fortgesetzt."
    case .bikeOutdoor: return "Fahrt fortgesetzt."
    case .bikeIndoor: return "Indoor-Bike fortgesetzt."
    }
  }

  private func togglePause(_ run: ActiveRunSession) {
    store.toggleRunPause()
    // Nach dem Toggle den neuen State aus dem Store lesen (nicht `run` — das ist
    // eine struct-Kopie mit dem PRE-toggle-Wert und würde die Logik umkehren).
    let nowPaused = store.activeRun?.isPaused ?? false
    // Manuelle Pause/Resume-Aktionen lösen im Tracker selbst `autoPaused`
    // Publishes aus. Die dürfen nicht erneut durch `handleAutoPause(_:)`
    // laufen, sonst kann der Store direkt wieder zurückgetoggelt werden.
    suppressNextAutoPauseSync = true
    if nowPaused {
      gpsTracker.currentHeartRate = 0
      store.clearRunHeartRateLive()
      gpsTracker.pauseTracking()
      audio.speak(pauseAnnouncement(for: run.modality))
    } else {
      HealthKitManager.shared.startHeartRateObserver()
      gpsTracker.resumeTracking()
      audio.speak(resumeAnnouncement(for: run.modality))
    }
  }

  private func handleAutoPause(_ paused: Bool) {
    guard !showsStopSheet, !isConfirmingCountdownAbort else { return }
    if suppressNextAutoPauseSync {
      suppressNextAutoPauseSync = false
      return
    }
    guard let run = store.activeRun, run.autoPauseEnabled, run.modality.requiresGPS else { return }
    if paused, !run.isPaused {
      store.toggleRunPause()
      gpsTracker.currentHeartRate = 0
      store.clearRunHeartRateLive()
      gpsTracker.pauseTracking(clearAutoPause: false, stopLocationUpdates: false)
      audio.speak(autoPauseAnnouncement(for: run.modality))
    } else if !paused, run.isPaused {
      suppressNextAutoPauseSync = true
      store.toggleRunPause()
      HealthKitManager.shared.startHeartRateObserver()
      gpsTracker.resumeTracking()
      audio.speak(resumeAnnouncement(for: run.modality))
    }
  }

  private func handleManualLap() {
    // Der Tracker fügt den Lap an `splits` an; via `syncStoreWithTracker`
    // (onReceive auf gpsTracker.$splits) landet er automatisch im Store.
    _ = gpsTracker.recordManualLap()
    audio.speak("Runde.")
  }

  private func stopTracking() {
    gpsTracker.currentHeartRate = 0
    HealthKitManager.shared.stopHeartRateObserver()
    gpsTracker.stopTracking()
  }

  private func finishRun(title: String, note: String, feel: RunFeel?) {
    syncStoreWithTracker()
    let modality = store.activeRun?.modality ?? .run
    stopTracking()
    switch modality {
    case .run:         audio.speak("Lauf beendet.")
    case .bikeOutdoor: audio.speak("Fahrt beendet.")
    case .bikeIndoor:  audio.speak("Indoor-Bike beendet.")
    }
    store.finishRun(customTitle: title, note: note, feel: feel)
  }
}

// MARK: - PreRunSetupView

private struct PreRunSetupView: View {
  @ObservedObject var store: GainsStore
  @ObservedObject var gpsTracker: RunLocationTracker
  @ObservedObject private var ble = BLEHeartRateManager.shared
  let onStart: () -> Void

  @State private var selectedIntensity: RunIntensity = .free
  @State private var selectedModality: CardioModality = .run
  @State private var targetMode: RunTargetMode = .free
  @State private var targetDistance: Double = 5.0
  @State private var targetDurationMinutes: Int = 30
  /// Pace-Ziel — bei Lauf interpretiert als Sekunden pro Kilometer
  /// (`5:30 /km`), bei Rad als Sekunden pro Kilometer der gewünschten
  /// Durchschnittsgeschwindigkeit (intern: 30 km/h ≙ 120 s/km).
  @State private var targetPaceSeconds: Int = 5 * 60 + 30  // 5:30 /km
  /// Ziel-Geschwindigkeit für Bike-Modi in km/h. Wird nur in der Bike-Pace-
  /// Anzeige verwendet und beim Apply in `targetPaceSeconds` umgerechnet.
  @State private var targetSpeedKmh: Double = 25.0
  @State private var autoPauseEnabled: Bool = true
  @State private var audioCuesEnabled: Bool = true
  // C1/C2-Fix (2026-05-01): Settings standardmäßig zugeklappt. Default-
  // Zustand (Frei/Frei/Auto-Pause/Audio) ist für 80 % der Läufe genau
  // richtig — Quick-Start-CTA reicht aus. Power-User klappen auf.
  @State private var showsAdvanced: Bool = false
  // C3-Fix (2026-05-01): HF-Sensor-Suggestion inline statt vergraben
  // im globalen Picker. User-Tap öffnet das WearablePickerSheet.
  @State private var showsWearablePicker: Bool = false
  @State private var hfHintDismissed: Bool = false

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
        header

        modalityPicker

        if showsHFSensorHint {
          hfSensorHint
        }

        quickStartCard

        advancedDisclosure

        Color.clear.frame(height: 12)
      }
      .padding(.horizontal, GainsSpacing.xl)
      .padding(.top, GainsSpacing.xsPlus)
    }
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: GainsSpacing.xsPlus) {
        modalityStatusRow
        Button {
          applyAndStart()
        } label: {
          HStack(spacing: GainsSpacing.xs) {
            Image(systemName: "play.fill")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(GainsColor.moss)
            Text(primaryCTALabel)
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(GainsColor.ink)
          }
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .gainsGlassCTA(corner: GainsRadius.standard, accent: GainsColor.lime)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, GainsSpacing.l)
      .padding(.bottom, GainsSpacing.l)
      .padding(.top, GainsSpacing.s)
      .background(GainsColor.background)
    }
    .onAppear { syncModalityFromActiveRun() }
    .onDisappear {
      cancelCountdown()
      countdownValue = 3
      lastSpokenKilometer = 0
      lastSpokenStepIndex = -1
      gpsTracker.currentHeartRate = 0
      selectedIntensity = .free
      selectedModality = .run
      targetMode = .free
      targetDistance = 5.0
      targetDurationMinutes = 30
      targetPaceSeconds = 5 * 60 + 30
      targetSpeedKmh = 25.0
      autoPauseEnabled = true
      audioCuesEnabled = true
      showsAdvanced = false
      showsWearablePicker = false
      hfHintDismissed = false
    }
    .sheet(isPresented: $showsWearablePicker) {
      WearablePickerSheet()
    }
  }

  // MARK: – Modality-Picker (Lauf / Rad / Rad Indoor)

  /// Drei-Segment-Picker: Lauf / Rad / Rad Indoor. Schaltet UI-Beschriftungen
  /// (km/h vs. min/km) sowie die GPS-Status-Zeile. Wird im Apply per
  /// `store.setRunModality` in den aktiven Run gespiegelt.
  private var modalityPicker: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      Text("MODUS")
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: GainsSpacing.xsPlus) {
        ForEach(CardioModality.allCases, id: \.self) { modality in
          Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
              selectedModality = modality
            }
          } label: {
            modalityChip(for: modality, isSelected: modality == selectedModality)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func modalityChip(for modality: CardioModality, isSelected: Bool) -> some View {
    VStack(spacing: GainsSpacing.xs) {
      Image(systemName: modality.systemImage)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.softInk)
      Text(modality.displayName)
        .font(.system(size: 12, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .foregroundStyle(isSelected ? GainsColor.ink : GainsColor.softInk)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, GainsSpacing.s)
    .runPickerChip(selected: isSelected, corner: GainsRadius.small)
  }

  private func syncModalityFromActiveRun() {
    if let modality = store.activeRun?.modality {
      selectedModality = modality
    }
  }

  private var primaryCTALabel: String {
    switch selectedModality {
    case .run:         return "Lauf starten"
    case .bikeOutdoor: return "Fahrt starten"
    case .bikeIndoor:  return "Indoor-Bike starten"
    }
  }

  // MARK: HF-Sensor-Suggestion (C3)

  /// True, wenn weder BLE-HR noch HealthKit-HR live sind und der User die
  /// Suggestion nicht in dieser Sitzung weggetippt hat.
  private var showsHFSensorHint: Bool {
    if hfHintDismissed { return false }
    if ble.isConnected || ble.liveHeartRate != nil { return false }
    if HealthKitManager.shared.liveHeartRate != nil { return false }
    return true
  }

  private var hfSensorHint: some View {
    HStack(spacing: GainsSpacing.s) {
      Image(systemName: "heart.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(GainsColor.accentCool)
        .frame(width: 36, height: 36)
        .background(GainsColor.accentCool.opacity(0.16))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text("HERZFREQUENZ NICHT VERBUNDEN")
          .gainsEyebrow(GainsColor.accentCool, size: 9, tracking: 1.4)
        Text("Sensor verbinden für genaue Zonen.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.ink)
      }

      Spacer(minLength: 0)

      Button {
        showsWearablePicker = true
      } label: {
        Text("VERBINDEN")
          .font(GainsFont.label(11))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.accentCool)
          .padding(.horizontal, GainsSpacing.s)
          .frame(height: 32)
          .background(.ultraThinMaterial, in: Capsule())
          .overlay(Capsule().strokeBorder(GainsColor.accentCool.opacity(0.5), lineWidth: GainsBorder.accent))
      }
      .buttonStyle(.plain)

      Button {
        withAnimation(.spring(response: 0.3)) {
          hfHintDismissed = true
        }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 22, height: 22)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Hinweis ausblenden")
      .accessibilityValue("Hinweis sichtbar")
      .accessibilityHint("Blendet nur diesen Hinweis aus und lässt deine Laufeinstellungen unverändert")
    }
    .padding(GainsSpacing.s)
    .gainsGlassSurface(corner: GainsRadius.small, material: .thin, tint: GainsColor.accentCool.opacity(0.05), depth: .rest)
  }

  // MARK: Quick-Start-Card (C1/C2)

  /// Eine fett gerandete Hero-Card mit dem aktuellen Setup als One-Liner +
  /// großem „Sofort starten"-CTA. Wer nichts anpasst, ist mit zwei Taps
  /// (Sheet öffnen → Sofort starten) draußen.
  private var quickStartCard: some View {
    Button {
      applyAndStart()
    } label: {
      HStack(alignment: .center, spacing: GainsSpacing.m) {
        ZStack {
          Circle()
            .fill(GainsColor.lime.opacity(0.18))
            .frame(width: 52, height: 52)
          Image(systemName: "play.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(GainsColor.moss)
        }
        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text("SOFORT STARTEN")
            .gainsEyebrow(GainsColor.moss, size: 10, tracking: 1.6)
          Text(quickStartHeadline)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
          Text(quickStartSubtitle)
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(GainsSpacing.m)
      .gainsGlassSurface(corner: GainsRadius.standard, tint: GainsColor.lime.opacity(0.06))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.accent)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Lauf sofort starten — \(quickStartSubtitle)")
    .accessibilityValue("\(quickStartHeadline), \(quickStartSubtitle)")
    .accessibilityHint(selectedModality.isCycling ? "Startet sofort eine neue Tour mit den gewählten Cardio-Einstellungen" : "Startet sofort einen neuen Lauf mit den gewählten Cardio-Einstellungen")
  }

  private var quickStartHeadline: String {
    switch targetMode {
    case .free:     return selectedModality.freshTitle
    case .distance: return String(format: "%.1f km", targetDistance)
    case .duration: return "\(targetDurationMinutes) min"
    case .pace:
      if selectedModality.isCycling {
        return String(format: "%.0f km/h", targetSpeedKmh)
      } else {
        return paceLabel(targetPaceSeconds) + " /km"
      }
    }
  }

  private var quickStartSubtitle: String {
    var parts: [String] = [selectedIntensity.title]
    if autoPauseEnabled { parts.append("Auto-Pause") }
    if audioCuesEnabled { parts.append("Audio") }
    return parts.joined(separator: " · ")
  }

  private var advancedDisclosure: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
          showsAdvanced.toggle()
        }
      } label: {
        HStack {
          Text(showsAdvanced ? "Anpassen ausblenden" : "Anpassen")
            .font(GainsFont.label(12))
            .tracking(1.4)
            .foregroundStyle(GainsColor.softInk)
          Spacer(minLength: 0)
          Image(systemName: showsAdvanced ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(.vertical, GainsSpacing.xsPlus)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(showsAdvanced ? "Anpassen ausblenden" : "Anpassen")
      .accessibilityValue(showsAdvanced ? "Erweiterte Einstellungen geöffnet" : "Erweiterte Einstellungen geschlossen")
      .accessibilityHint(showsAdvanced ? "Blendet Intensität, Ziel und Optionen wieder aus" : "Öffnet Intensität, Ziel und weitere Optionen für deinen Lauf")

      if showsAdvanced {
        VStack(alignment: .leading, spacing: GainsSpacing.xl) {
          intensityPicker
          targetSection
          optionsSection
        }
        .padding(.top, GainsSpacing.m)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  // MARK: Header

  private var header: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      Text(selectedModality.shortLabel)
        .gainsEyebrow(GainsColor.softInk, size: 12, tracking: 2.4)

      Text(primaryCTALabel)
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
    return parts.isEmpty ? "Wähle Intensität, Ziel und Optionen. Alles lässt sich später anpassen." : parts.joined(separator: "  ·  ")
  }

  // MARK: Intensity

  private var intensityPicker: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      Text("INTENSITÄT")
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.tight) {
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
    HStack(spacing: GainsSpacing.xsPlus) {
      Image(systemName: intensity.systemImage)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.softInk)
      Text(intensity.title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isSelected ? GainsColor.ink : GainsColor.softInk)
    }
    .padding(.horizontal, GainsSpacing.m)
    .frame(height: 38)
    .runPickerChip(selected: isSelected, corner: 100)
  }

  // MARK: Target

  private var targetSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Text("ZIEL")
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: GainsSpacing.xsPlus) {
        ForEach(RunTargetMode.allCases, id: \.self) { mode in
          Button { targetMode = mode } label: {
            Text(mode.title)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(targetMode == mode ? GainsColor.ink : GainsColor.softInk)
              .frame(maxWidth: .infinity)
              .frame(height: 36)
              .runPickerChip(selected: targetMode == mode, corner: GainsRadius.small)
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
      Text("Freier Lauf mit normalem Live-Tracking, nur ohne festes Distanz-, Zeit- oder Pace-Ziel.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .padding(.vertical, GainsSpacing.xxs)
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
      if selectedModality.isCycling {
        stepperRow(
          label: "Speed",
          valueText: String(format: "%.0f km/h", targetSpeedKmh),
          decrement: { targetSpeedKmh = max(targetSpeedKmh - 1, 8) },
          increment: { targetSpeedKmh = min(targetSpeedKmh + 1, 60) }
        )
      } else {
        stepperRow(
          label: "Pace",
          valueText: paceLabel(targetPaceSeconds) + " /km",
          decrement: { targetPaceSeconds = max(targetPaceSeconds - 5, 3 * 60) },
          increment: { targetPaceSeconds = min(targetPaceSeconds + 5, 9 * 60) }
        )
      }
    }
  }

  private func stepperRow(label: String, valueText: String, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
    HStack(spacing: GainsSpacing.m) {
      Text(label)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.ink)

      Spacer()

      Button(action: decrement) {
        Image(systemName: "minus")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(GainsColor.ink)
          .frame(width: 36, height: 36)
          .background(.ultraThinMaterial, in: Circle())
          .overlay(Circle().strokeBorder(GainsColor.border.opacity(0.7), lineWidth: GainsBorder.hairline))
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
          .background(.ultraThinMaterial, in: Circle())
          .overlay(Circle().strokeBorder(GainsColor.border.opacity(0.7), lineWidth: GainsBorder.hairline))
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, GainsSpacing.xxs)
  }

  // MARK: Options

  private var optionsSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Text("OPTIONEN")
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)

      // Indoor: Auto-Pause ergibt keinen Sinn (Heimtrainer steht ohnehin),
      // also blenden wir den Toggle aus, statt den User mit toter Option
      // zu konfrontieren.
      if !selectedModality.isIndoor {
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
      }

      Toggle(isOn: $audioCuesEnabled) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Audio-Hinweise")
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
          Text(selectedModality.isCycling
               ? "Sprachausgabe bei jedem Kilometer mit aktueller Geschwindigkeit."
               : "Sprachausgabe bei jedem Kilometer mit aktueller Pace.")
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
        }
      }
      .tint(GainsColor.lime)
    }
    .padding(GainsSpacing.m)
    .gainsGlassSurface(corner: GainsRadius.standard, material: .thin, depth: .rest)
  }

  // MARK: GPS- bzw. Modus-Status

  /// Zeile im Bottom-Inset: GPS-Status für Outdoor-Aktivitäten, Indoor-Hinweis
  /// für stationäre Sessions (kein GPS, manuelle Distanz-Eingabe).
  @ViewBuilder
  private var modalityStatusRow: some View {
    if selectedModality.isIndoor {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: "house.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(GainsColor.softInk)
        Text("INDOOR · DISTANZ MANUELL · KEIN GPS")
          .font(GainsFont.label(10))
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
      }
    } else {
      HStack(spacing: GainsSpacing.xs) {
        Circle()
          .fill(gpsTracker.canStartTracking ? GainsColor.lime : GainsColor.softInk)
          .frame(width: 6, height: 6)
        Text(gpsTracker.canStartTracking ? "GPS BEREIT" : "GPS WIRD AKTIVIERT")
          .font(GainsFont.label(10))
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
      }
    }
  }

  // MARK: Apply

  private func applyAndStart() {
    if store.activeRun == nil {
      store.startQuickRun(modality: selectedModality)
    }
    // Modus auch nachträglich spiegeln, damit Mode-Wechsel im offenen Sheet
    // („User hat erst Lauf gewählt, dann auf Rad gewechselt") greift.
    store.setRunModality(selectedModality)
    store.setRunIntensity(selectedIntensity)
    // Bike-Pace-Ziel ist als km/h gewählt, intern brauchen wir Sekunden/km.
    let appliedPaceSeconds: Int = {
      if selectedModality.isCycling, targetSpeedKmh > 0 {
        return Int((3600.0 / targetSpeedKmh).rounded())
      }
      return targetPaceSeconds
    }()
    store.setRunTarget(
      mode: targetMode,
      distanceKm: targetDistance,
      durationMinutes: targetDurationMinutes,
      paceSeconds: appliedPaceSeconds
    )
    // Indoor erzwingt Auto-Pause aus (Heimtrainer steht — sonst würde der
    // Tracker fälschlich pausieren). Outdoor übernimmt die Toggle-Wahl.
    store.setAutoPause(selectedModality.isIndoor ? false : autoPauseEnabled)
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
    VStack(spacing: GainsSpacing.m) {
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
      VStack(spacing: GainsSpacing.m) {
        statusRow

        // Hero-Numerik — 72pt, monochrom ohne Glow (Clean-Glass 2026-05-30):
        // ruhiger Hauptdarsteller, Lime lebt nur noch im Live-Dot + Zielbalken.
        // 2026-05-31 (Live-Polish): Sekunden rollen jetzt via numericText statt
        // hart umzuspringen — gibt dem Timer den ruhigen „Stoppuhr läuft"-Puls,
        // ohne dass die monospaced-Breite jittert.
        Text(formattedRunTime)
          .font(.system(size: 72, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.32, dampingFraction: 0.9), value: displayedDurationSeconds)
          .minimumScaleFactor(0.55)
          .lineLimit(1)

        if run.targetMode != .free {
          targetProgressBar
        }

        if let workout = activeWorkout, !workout.isFinished {
          structuredWorkoutBanner(workout)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, GainsSpacing.xl)
      .padding(.top, GainsSpacing.xsPlus)
      .padding(.bottom, GainsSpacing.l)

      routeSection

      VStack(spacing: GainsSpacing.m) {
        liveMetricsRow
        if run.currentHeartRate > 0 {
          hrZoneRow
        }
        liveControls
        if !displayedSplits.isEmpty {
          splitsStrip
        }
      }
      .padding(.horizontal, GainsSpacing.l)
      .padding(.top, GainsSpacing.l)
      .padding(.bottom, GainsSpacing.l)
      .gainsGlassSurface(corner: GainsRadius.hero, material: .thick, depth: .hero)
      .padding(.horizontal, GainsSpacing.s)
      .padding(.bottom, GainsSpacing.xs)
    }
  }

  // MARK: Status

  private var statusRow: some View {
    HStack(spacing: GainsSpacing.xsPlus) {
      GainsSignalDot(
        active: gpsTracker.autoPaused || !run.isPaused,
        color: gpsTracker.autoPaused ? GainsColor.ember : GainsColor.signal,
        size: 8
      )

      Text(statusText)
        .font(GainsFont.label(11))
        .tracking(GainsTracking.eyebrowWide)
        .foregroundStyle(GainsColor.softInk)

      Spacer()

      Text(run.intensity.shortLabel)
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.moss)
    }
  }

  private var statusText: String {
    if run.isPaused {
      return gpsTracker.autoPaused ? "AUTO-PAUSE" : "PAUSIERT"
    }
    if gpsTracker.isIndoor { return "\(run.modality.shortLabel) AKTIV" }
    if gpsTracker.isUsingGPS { return "GPS AKTIV" }
    return "AKTIV"
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

    return VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      HStack(spacing: GainsSpacing.tight) {
        Image(systemName: step?.kind.systemImage ?? "figure.run")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(stepColor)
          .frame(width: 28, height: 28)
          .background(stepColor.opacity(0.18))
          .clipShape(Circle())

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: GainsSpacing.xs) {
            Text((step?.kind.title ?? "—").uppercased())
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(stepColor)
            Text("SCHRITT \(workout.currentStepIndex + 1)/\(workout.steps.count)")
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
            .fill(GainsColor.surfaceDeep)
            .frame(height: 5)
          Capsule()
            .fill(
              LinearGradient(
                colors: [stepColor.opacity(0.75), stepColor],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: max(geo.size.width * progress, 5), height: 5)
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: progress)
        }
      }
      .frame(height: 5)
    }
    .padding(GainsSpacing.s)
    .gainsGlassSurface(corner: GainsRadius.small, material: .thin, depth: .rest)
  }

  // MARK: Target Progress

  private var targetProgressBar: some View {
    let progress = run.progressFraction(elapsedSeconds: gpsTracker.elapsedSeconds)
    return VStack(spacing: GainsSpacing.xxs) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.surfaceDeep)
            .frame(height: 6)
          // 2026-05-31 (Live-Polish): Fill als feiner Lime→signalDeep-Verlauf
          // mit einem hellen Lauf-Highlight an der Spitze, weiche Feder-Animation
          // beim Fortschritt. Der Zielbalken bleibt die einzige Lime-Vollfläche
          // im Live-View — jetzt mit etwas mehr Tiefe statt flachem Block.
          Capsule()
            .fill(
              LinearGradient(
                colors: [GainsColor.signalDeep, GainsColor.lime],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: max(geo.size.width * progress, 6), height: 6)
            .overlay(alignment: .trailing) {
              Circle()
                .fill(GainsColor.lime)
                .frame(width: 6, height: 6)
                .shadow(color: GainsColor.lime.opacity(0.6), radius: 3)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: progress)
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
          .foregroundStyle(GainsColor.moss)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.4, dampingFraction: 0.9), value: progress)
      }
    }
  }

  private var targetLabel: String {
    switch run.targetMode {
    case .free:     return ""
    case .distance: return "ZIEL · \(String(format: "%.1f", run.targetDistanceKm)) km"
    case .duration: return "ZIEL · \(run.targetDurationMinutes) min"
    case .pace:
      if run.modality.isCycling, run.targetPaceSeconds > 0 {
        let kmh = 3600.0 / Double(run.targetPaceSeconds)
        return String(format: "ZIEL · %.0f km/h", kmh)
      }
      return "ZIEL · \(formatPace(run.targetPaceSeconds)) /km"
    }
  }

  // MARK: Map / Route

  /// Outdoor-Aktivitäten: Karte mit Tracklinie. Indoor-Bike: Manueller
  /// Distanz-Stepper, weil ohne GPS nichts zu zeichnen wäre.
  @ViewBuilder
  private var routeSection: some View {
    if run.modality.isIndoor {
      indoorDistanceTile
    } else {
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
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [GainsColor.glassEdgeTop, GainsColor.glassEdgeBottom],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 0.8
          )
      )
      .padding(.horizontal, GainsSpacing.s)
      .padding(.top, GainsSpacing.xs)
    }
  }

  /// Indoor-Tile: zeigt die aufaddierte Distanz groß und bietet ±0.5/±1.0 km
  /// Stepper, damit der Anwender beim Heimtrainer-Display die gefahrenen km
  /// nachpflegen kann. Tap auf einen Button schiebt den GPS-Tracker hoch und
  /// erzeugt automatisch 1-km-Splits — derselbe Pfad wie beim Outdoor-Lauf.
  private var indoorDistanceTile: some View {
    VStack(spacing: GainsSpacing.l) {
      VStack(spacing: GainsSpacing.xxs) {
        Text("INDOOR · DISTANZ MANUELL")
          .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.6)
        // Hero-Distanz 56pt, monochrom (Glow entfernt — Clean-Glass 2026-05-30).
        Text(String(format: "%.2f km", displayedDistance))
          .font(.system(size: 56, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)
        Text("z. B. vom Display deines Heimtrainers")
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(spacing: GainsSpacing.tight) {
        indoorStepperButton(label: "−1.0", deltaKm: -1.0)
        indoorStepperButton(label: "−0.5", deltaKm: -0.5)
        indoorStepperButton(label: "+0.5", deltaKm: 0.5, accent: true)
        indoorStepperButton(label: "+1.0", deltaKm: 1.0, accent: true)
      }
      .padding(.horizontal, GainsSpacing.xsPlus)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, GainsSpacing.xl)
    .padding(.horizontal, GainsSpacing.l)
    .gainsGlassSurface(corner: GainsRadius.hero, material: .thick, depth: .hero)
    .padding(.horizontal, GainsSpacing.s)
  }

  private func indoorStepperButton(label: String, deltaKm: Double, accent: Bool = false) -> some View {
    Button {
      gpsTracker.adjustIndoorDistance(by: deltaKm)
    } label: {
      Text(label)
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(GainsColor.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .runPickerChip(selected: accent, corner: GainsRadius.small)
    }
    .buttonStyle(.plain)
    .disabled(run.isPaused)
    .accessibilityLabel(deltaKm > 0
      ? "Distanz um \(label) Kilometer erhöhen"
      : "Distanz um \(label) Kilometer reduzieren")
    .accessibilityValue(run.isPaused ? "Pausierter Lauf, Distanzanpassung erst nach dem Fortsetzen möglich" : "Aktiver Lauf, bereit für Distanzanpassung")
    .accessibilityHint(run.isPaused ? "Nicht verfügbar, weil die Distanzanpassung erst nach dem Fortsetzen deines Laufs möglich ist" : (deltaKm > 0 ? "Erhöht deine Indoor-Distanz während des laufenden Trainings" : "Reduziert deine Indoor-Distanz während des laufenden Trainings"))
  }

  // MARK: Metrics

  private var liveMetricsRow: some View {
    HStack(spacing: 0) {
      metric(title: "DISTANZ", value: String(format: "%.2f", displayedDistance), unit: "km")
      metricSeparator
      // Pace (Lauf) vs. Geschwindigkeit (Rad outdoor + indoor). Wir prüfen
      // die Modalität direkt am Run, damit auch Indoor-Sessions (kein GPS)
      // konsistent km/h anzeigen.
      // 2026-05-31 (Live-Polish): Pace/Tempo ist die Kennzahl, auf die man im
      // Lauf am häufigsten schaut → `emphasized` gibt ihrem Label den Moss-Tint
      // als leisen Anker, ohne die Spaltenausrichtung zu stören.
      if run.modality.isCycling {
        metric(title: "TEMPO", value: speedCompact(displayedSpeedKmh), unit: "km/h", emphasized: true)
      } else {
        metric(title: "PACE", value: paceCompact(displayedPace), unit: "/km", emphasized: true)
      }
      metricSeparator
      metric(title: "HF", value: run.currentHeartRate > 0 ? "\(run.currentHeartRate)" : "–", unit: "bpm")
      metricSeparator
      // Indoor-Bike hat keine echte Höhe (Heimtrainer steht still) — wir
      // zeigen statt „+0 m" eine Kalorien-Schätzung, die der Anwender im
      // Eifer der Session direkt sieht.
      if run.modality.isIndoor {
        metric(title: "KCAL", value: "\(estimatedCalories)", unit: "kcal")
      } else {
        metric(title: "ELEV", value: "+\(displayedElevation)", unit: "m")
      }
    }
  }

  /// Sehr grobe Kalorien-Schätzung für Indoor-Bike (kein Powermeter):
  /// `kcal ≈ MET × 75 kg × Stunden`. Dient als Motivations-Anzeige, nicht als
  /// medizinische Größe — Anwender wird darauf nicht aufgebaut.
  private var estimatedCalories: Int {
    let hours = Double(displayedDurationSeconds) / 3600.0
    return Int((run.modality.defaultMET * 75.0 * hours).rounded())
  }

  /// Pace (Sek/km) → km/h. 0 wenn Pace 0 ist.
  private var displayedSpeedKmh: Double {
    let pace = displayedPace
    guard pace > 0 else { return 0 }
    return 3600.0 / Double(pace)
  }

  private func speedCompact(_ kmh: Double) -> String {
    guard kmh > 0 else { return "–" }
    return String(format: "%.1f", kmh)
  }

  private var metricSeparator: some View {
    // 2026-05-31 (Live-Polish): harte 1×28-Linie → an den Enden ausblendende
    // Hairline. Trennt die Kennzahlen, ohne als eigene Kante zu „lärmen".
    Capsule()
      .fill(
        LinearGradient(
          colors: [
            GainsColor.border.opacity(0),
            GainsColor.border.opacity(0.45),
            GainsColor.border.opacity(0)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .frame(width: 1, height: 30)
  }

  private func metric(title: String, value: String, unit: String, emphasized: Bool = false) -> some View {
    // Heavy-Weight rückgängig (User-Direktive 2026-05-14) — zurück auf
    // 20pt .semibold rounded wie vor Polish-Loop 49.
    // 2026-05-31 (Live-Polish): monospacedDigit hält die Breite stabil und
    // numericText lässt die Ziffern bei jedem Tick weich rollen statt zu
    // springen — die Kennzahlen lesen sich wie eine echte HUD-Anzeige.
    VStack(spacing: GainsSpacing.xs) {
      Text(title)
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(emphasized ? GainsColor.moss : GainsColor.softInk)

      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 20, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.35, dampingFraction: 0.9), value: value)
          .lineLimit(1)
          .minimumScaleFactor(0.6)

        Text(unit)
          .font(GainsFont.body(11))
          .foregroundStyle(emphasized ? GainsColor.moss.opacity(0.8) : GainsColor.softInk)
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: HF-Zone

  private var hrZoneRow: some View {
    let zone = HRZone.zone(for: run.currentHeartRate, maxHR: maxHeartRate)
    return HStack(spacing: GainsSpacing.tight) {
      ForEach(HRZone.allCases, id: \.self) { z in
        // 2026-05-31 (Live-Polish): aktive Zone bekommt einen weichen Halo in
        // ihrer Farbe — der Puls „leuchtet" auf der richtigen Stufe, ohne dass
        // die ruhigen inaktiven Dots an Gewicht gewinnen. Fixe 22er-Box hält
        // das Spacing stabil, während der aktive Dot wächst.
        ZStack {
          if zone == z {
            Circle()
              .fill(z.color())
              .frame(width: 22, height: 22)
              .blur(radius: 6)
              .opacity(0.55)
          }
          Circle()
            .fill(z.color(active: zone == z))
            .frame(width: zone == z ? 14 : 10, height: zone == z ? 14 : 10)
            .overlay {
              if zone == z {
                Circle().stroke(GainsColor.ink, lineWidth: 1.5)
              }
            }
        }
        .frame(width: 22, height: 22)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: zone)
      }
      Spacer()
      Text((zone?.title ?? "—").uppercased())
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
    }
    .padding(.horizontal, GainsSpacing.s)
    .frame(height: 36)
    .gainsGlassSurface(corner: GainsRadius.small, material: .thin, depth: .rest)
  }

  // MARK: Controls

  private var liveControls: some View {
    HStack(spacing: GainsSpacing.tight) {
      Button(action: onTogglePause) {
        Text(gpsTracker.autoPaused ? "Weiter" : (run.isPaused ? "Fortsetzen" : "Pause"))
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(GainsColor.ink)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .gainsGlassSurface(corner: GainsRadius.small, material: .thin, depth: .rest)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(gpsTracker.autoPaused ? "Lauf nach Auto-Pause fortsetzen" : (run.isPaused ? "Lauf fortsetzen" : "Lauf pausieren"))
      .accessibilityValue(gpsTracker.autoPaused ? "Automatisch pausierter Lauf, kann direkt weiterlaufen" : (run.isPaused ? "Pausierter Lauf, kann direkt fortgesetzt werden" : "Aktiver Lauf, kann direkt pausiert werden"))
      .accessibilityHint(gpsTracker.autoPaused ? "Setzt deinen automatisch pausierten Lauf direkt wieder in Bewegung" : (run.isPaused ? "Setzt deinen pausierten Lauf direkt fort" : "Pausiert deinen aktuell laufenden Lauf"))

      Button(action: onLap) {
        VStack(spacing: 2) {
          Image(systemName: "flag.checkered")
            .font(.system(size: 14, weight: .semibold))
          Text("Runde")
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(GainsColor.ink)
        .frame(width: 60, height: 50)
        .gainsGlassSurface(corner: GainsRadius.small, material: .thin, depth: .rest)
      }
      .buttonStyle(.plain)
      .disabled(run.isPaused)
      .accessibilityLabel("Runde markieren")
      .accessibilityValue(gpsTracker.autoPaused ? "Automatisch pausierter Lauf, neue Runde erst nach dem Weiterlaufen möglich" : (run.isPaused ? "Pausierter Lauf, neue Runde kann erst nach dem Fortsetzen markiert werden" : "Aktiver Lauf, neue Runde kann direkt markiert werden"))
      .accessibilityHint(gpsTracker.autoPaused ? "Nicht verfügbar, weil eine neue Runde erst nach dem Weiterlaufen deines automatisch pausierten Laufs markiert werden kann" : (run.isPaused ? "Nicht verfügbar, weil eine neue Runde erst nach dem Fortsetzen deines Laufs markiert werden kann" : "Markiert eine neue Runde in deinem laufenden Training"))

      Button(action: onStop) {
        HStack(spacing: GainsSpacing.xs) {
          Image(systemName: "stop.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(GainsColor.moss)
          Text("Abschließen")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(GainsColor.ink)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .gainsGlassCTA(corner: GainsRadius.small, accent: GainsColor.lime)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Lauf abschließen")
      .accessibilityValue(gpsTracker.autoPaused ? "Automatisch pausierter Lauf, kann gespeichert, weitergeführt oder verworfen werden" : (run.isPaused ? "Pausierter Lauf, kann gespeichert, fortgesetzt oder verworfen werden" : "Aktiver Lauf, kann gespeichert, fortgesetzt oder verworfen werden"))
      .accessibilityHint(gpsTracker.autoPaused ? "Öffnet die Abschlussansicht, in der du deinen automatisch pausierten Lauf speichern, weiterführen oder verwerfen kannst" : (run.isPaused ? "Öffnet die Abschlussansicht, in der du deinen pausierten Lauf speichern, fortsetzen oder verwerfen kannst" : "Öffnet die Abschlussansicht, in der du deinen aktiven Lauf speichern, fortsetzen oder verwerfen kannst"))
    }
  }

  // MARK: Splits Strip

  private var splitsStrip: some View {
    let splits = Array(displayedSplits.suffix(3))
    // Schnellster der angezeigten Splits → bekommt eine feine Lime-Hairline +
    // Bolt-Marker. Erst ab 2 Splits, damit ein einzelner nicht „Bestzeit" heißt.
    let fastestPace = splits.map(\.paceSeconds).filter { $0 > 0 }.min()

    return VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text("LETZTE RUNDEN")
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: GainsSpacing.xsPlus) {
        ForEach(splits, id: \.id) { split in
          let isFastest = splits.count > 1
            && split.paceSeconds > 0
            && split.paceSeconds == fastestPace
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: GainsSpacing.xxs) {
              Text(split.isManualLap ? "RUNDE \(split.index)" : "KILOMETER \(split.index)")
                .font(GainsFont.label(9))
                .tracking(1.4)
                .foregroundStyle(isFastest ? GainsColor.moss : GainsColor.softInk)
              if split.isManualLap {
                Image(systemName: "flag.checkered")
                  .font(.system(size: 8, weight: .semibold))
                  .foregroundStyle(GainsColor.moss)
              }
              if isFastest {
                Image(systemName: "bolt.fill")
                  .font(.system(size: 8, weight: .bold))
                  .foregroundStyle(GainsColor.lime)
              }
            }

            Text(paceCompact(split.paceSeconds))
              .font(.system(size: 16, weight: .semibold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(GainsColor.ink)

            Text("\(split.averageHeartRate) bpm")
              .font(GainsFont.body(11))
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, GainsSpacing.tight)
          .padding(.vertical, GainsSpacing.xsPlus)
          .runPickerChip(selected: isFastest, corner: GainsRadius.small)
          .transition(.move(edge: .trailing).combined(with: .opacity))
        }
      }
      .animation(.spring(response: 0.4, dampingFraction: 0.85), value: splits.count)
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

  /// True, sobald ein Tracker (GPS, Fallback oder Indoor) den Run aktiv
  /// fortschreibt. Wird mehrfach in den `displayed*`-Helfern genutzt.
  private var isTrackerActive: Bool {
    gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback || gpsTracker.isIndoor
  }

  private var displayedDurationSeconds: Int {
    if isTrackerActive {
      return gpsTracker.elapsedSeconds
    }
    return run.durationMinutes * 60
  }

  private var displayedDistance: Double {
    isTrackerActive ? gpsTracker.trackedDistanceKm : run.distanceKm
  }

  private var displayedElevation: Int {
    isTrackerActive ? gpsTracker.elevationGain : run.elevationGain
  }

  private var displayedPace: Int {
    guard displayedDistance > 0 else { return 0 }
    return Int(Double(displayedDurationSeconds) / displayedDistance)
  }

  private var displayedSplits: [RunSplit] {
    isTrackerActive ? gpsTracker.splits : run.splits
  }

  private var displayedRouteCoordinates: [CLLocationCoordinate2D] {
    isTrackerActive ? gpsTracker.routeCoordinates : run.routeCoordinates
  }
}

// MARK: - StopRunSheet

private struct StopRunSheet: View {
  let run: ActiveRunSession?
  let isAutoPaused: Bool
  /// Aktuelle Lauf-Dauer in Sekunden (vom GPS-Tracker durchgereicht).
  /// Wird statt `run.durationMinutes` (Int, rundet < 60s auf 0) für die
  /// Save-Bedingung benutzt — siehe P1-5.
  let elapsedSeconds: Int
  let onSave: (_ title: String, _ note: String, _ feel: RunFeel?) -> Void
  let onDiscard: () -> Void
  let onResume: () -> Void

  @State private var title: String = ""
  @State private var note: String = ""
  @State private var feel: RunFeel? = nil
  @State private var isConfirmingDiscard = false

  /// Speichern erlauben, sobald der Lauf entweder Distanz ODER mindestens
  /// 30 Sekunden Dauer aufgebaut hat. Vorher: `durationMinutes >= 1` →
  /// 45s-Lauf landete bei 0 Minuten und konnte nicht gespeichert werden;
  /// 65s wurde als „1 min" gerundet. Jetzt: Sekunden-genau aus dem Tracker.
  private var canSaveRun: Bool {
    guard let run else { return false }
    return run.distanceKm > 0 || elapsedSeconds >= 30
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: GainsSpacing.xl) {
          summaryHeader

          VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
            Text("NAME")
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(GainsColor.softInk)
            TextField(run?.title ?? "Lauf", text: $title)
              .textFieldStyle(.plain)
              .padding(GainsSpacing.s)
              .gainsGlassSurface(corner: GainsRadius.small, material: .thin, depth: .rest)
          }

          feelPicker

          VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
            Text("NOTIZ")
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(GainsColor.softInk)
            TextField("Wie hat sich der Lauf angefühlt?", text: $note, axis: .vertical)
              .textFieldStyle(.plain)
              .lineLimit(3...6)
              .padding(GainsSpacing.s)
              .gainsGlassSurface(corner: GainsRadius.small, material: .thin, depth: .rest)
          }
        }
        .padding(GainsSpacing.l)
      }
      .background(GainsColor.background.ignoresSafeArea())
      .navigationTitle("Lauf abschließen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(isAutoPaused ? "Weiter" : "Lauf fortsetzen", action: onResume)
            .foregroundStyle(GainsColor.ink)
            .accessibilityLabel(isAutoPaused ? "Lauf nach Auto-Pause weiterführen" : "Lauf fortsetzen")
            .accessibilityValue(isAutoPaused ? "Automatisch pausierter Lauf, kann direkt weiterlaufen" : (run?.isPaused == true ? "Pausierter Lauf, kann direkt fortgesetzt werden" : "Aktiver Lauf, kann direkt fortgesetzt werden"))
            .accessibilityHint(isAutoPaused ? "Schließt die Abschlussansicht und setzt deinen automatisch pausierten Lauf direkt wieder in Bewegung" : "Schließt die Abschlussansicht und setzt deinen aktuellen Lauf direkt fort")
        }
      }
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: GainsSpacing.tight) {
          Button {
            onSave(title, note, feel)
          } label: {
            HStack(spacing: GainsSpacing.xs) {
              Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GainsColor.moss)
              Text("Lauf speichern")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GainsColor.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .gainsGlassCTA(corner: GainsRadius.standard, accent: GainsColor.lime, isEnabled: canSaveRun)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Lauf speichern")
          .accessibilityValue(canSaveRun ? "Bereit zum Speichern, dein Lauf landet im Feed und in den Routen" : "Noch nicht speicherbar, du kannst den Lauf erst nach mindestens 30 Sekunden oder 0,01 Kilometer speichern")
          .accessibilityHint(canSaveRun ? "Speichert deinen Lauf mit Titel, Notiz und Gefühl und legt ihn danach im Feed und in den Routen ab" : "Nicht verfügbar, bis dein Lauf mindestens 30 Sekunden oder 0,01 Kilometer erreicht hat")
          .disabled(!canSaveRun)
          .opacity(canSaveRun ? 1 : 0.5)

          // C4-Fix (2026-05-01): Klar machen, was Speichern bewirkt und —
          // wenn die Save-Bedingung NICHT erfüllt ist — warum nicht.
          if !canSaveRun {
            Text("Du kannst den Lauf erst nach mindestens 30 Sekunden oder 0,01 km speichern, sonst landet er nicht im Feed oder in den Routen.")
              .font(GainsFont.label(11))
              .foregroundStyle(GainsColor.softInk)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .padding(.horizontal, GainsSpacing.xxs)
          } else {
            Text("Wenn du den Lauf speicherst, landet er im Feed und in den Routen.")
              .font(GainsFont.label(11))
              .foregroundStyle(GainsColor.softInk)
              .multilineTextAlignment(.center)
              .frame(maxWidth: .infinity)
              .padding(.horizontal, GainsSpacing.xxs)
          }

          Button {
            isConfirmingDiscard = true
          } label: {
            Text("Lauf verwerfen")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(GainsColor.softInk)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .gainsGlassSurface(corner: GainsRadius.small, material: .thin, depth: .rest)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Lauf verwerfen")
          .accessibilityValue("Noch nicht gespeichert, aktiver Lauf kann behalten oder verworfen werden")
          .accessibilityHint("Öffnet die Bestätigung, in der du deinen aktiven Lauf behalten oder verwerfen kannst")
        }
        .padding(.horizontal, GainsSpacing.l)
        .padding(.bottom, GainsSpacing.m)
        .padding(.top, GainsSpacing.xsPlus)
        .background(GainsColor.background)
      }
      .confirmationDialog(
        "Lauf wirklich verwerfen?",
        isPresented: $isConfirmingDiscard,
        titleVisibility: .visible
      ) {
        Button("Lauf verwerfen", role: .destructive, action: onDiscard)
        Button("Lauf behalten", role: .cancel) {}
      } message: {
        Text("Wenn du den Lauf behältst, kehrst du direkt zu deinem aktiven Lauf zurück und kannst ihn fortsetzen oder speichern. Wenn du ihn verwirfst, wird dein aktiver Lauf verworfen und Distanz, Pace sowie Runden landen nicht im Feed oder in den Routen.")
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
    return HStack(alignment: .lastTextBaseline, spacing: GainsSpacing.m) {
      summaryCell(value: String(format: "%.2f", distance), unit: "km")
      summaryCell(value: pace > 0 ? String(format: "%d:%02d", pace / 60, pace % 60) : "–:–", unit: "/km")
      summaryCell(value: "\(duration)", unit: "min")
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, GainsSpacing.xxs)
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
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text("WIE WAR'S?")
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: GainsSpacing.xsPlus) {
        ForEach(RunFeel.allCases, id: \.self) { f in
          Button { feel = (feel == f ? nil : f) } label: {
            VStack(spacing: GainsSpacing.xxs) {
              Image(systemName: f.emojiSymbol)
                .font(.system(size: 18, weight: .semibold))
              Text("\(f.rawValue)")
                .font(GainsFont.label(9))
                .tracking(1.0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GainsSpacing.tight)
            .foregroundStyle(feel == f ? GainsColor.ink : GainsColor.softInk)
            .runPickerChip(selected: feel == f, corner: GainsRadius.small)
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
  // routeCoordinates wird nicht per @Published bei jeder Koordinate gepublisht —
  // das würde bei distanceFilter=5m und einem 1h-Lauf ~720 SwiftUI-Redraws
  // pro Minute erzeugen. Stattdessen sammeln wir intern und senden
  // objectWillChange manuell alle _routePublishInterval Updates, damit die
  // Karte flüssig bleibt ohne jede Sekunde einen vollständigen Body-Rebuild
  // auszulösen. Direktzugriff auf `routeCoordinates` (z.B. beim Speichern)
  // funktioniert weiterhin unverändert.
  private(set) var routeCoordinates: [CLLocationCoordinate2D] = [] {
    willSet { _routeUpdateCounter += 1 }
    didSet {
      if _routeUpdateCounter % _routePublishInterval == 0 {
        objectWillChange.send()
      }
    }
  }
  private var _routeUpdateCounter = 0
  private let _routePublishInterval = 4   // Publish jede 4. Koordinate (≈ alle 20m)
  @Published var trackedDistanceKm: Double = 0
  @Published var elevationGain: Int = 0
  @Published var durationMinutes: Int = 0
  @Published var elapsedSeconds: Int = 0
  @Published var splits: [RunSplit] = []
  @Published var isUsingGPS = false
  @Published var isTrackingFallback = false
  /// True, wenn der Tracker im Indoor-Modus läuft (Heimtrainer/Spinning).
  /// Kein GPS, keine Map, Distanz wird vom View per `adjustIndoorDistance`
  /// hochgeschoben. Der Timer für Dauer/Splits läuft normal weiter.
  @Published var isIndoor = false
  @Published var autoPaused = false

  /// Wird vom View aus HealthKit befüllt und für Split-Durchschnitte genutzt.
  var currentHeartRate: Int = 0
  var autoPauseEnabled: Bool = true
  /// 2026-05-01 P1-7: Modus-Differenzierung für GPS-Plausibilitätsprüfung.
  /// Lauf akzeptiert bis 10 m/s (~36 km/h Sprint), Rad bis 25 m/s (~90 km/h).
  /// Wird vom View beim Start des Trackings aus `ActiveRunSession.modality`
  /// gesetzt; Default `.run` bleibt für den Bestandsfall.
  var cardioModality: CardioModality = .run

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

  deinit {
    // Defensive: Wenn der Tracker durch View-Recycling deallociert wird,
    // ohne dass stopTracking() lief, würde der Timer sonst auf einer toten
    // Instanz weiterfeuern (weak self verhindert Crash, aber RunLoop hält
    // einen Strong-Ref auf den Timer selbst). Außerdem stoppen wir das
    // CLLocationManager-Streaming, damit kein Akkuverbrauch übrig bleibt.
    timer?.invalidate()
    timer = nil
    if Self.hasLocationBackgroundMode {
      manager.allowsBackgroundLocationUpdates = false
    }
    manager.stopUpdatingLocation()
    manager.delegate = nil
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

    let preservedElapsedSeconds = elapsedSeconds
    let preservedDurationMinutes = durationMinutes
    let preservedSplitAnchorDurationSeconds = splitAnchorDurationSeconds
    let preservedManualLapAnchorDurationSeconds = manualLapAnchorDurationSeconds
    let preservedSplitAnchorDistance = splitAnchorDistance
    let preservedManualLapAnchorDistance = manualLapAnchorDistance
    let preservedRouteCoordinates = routeCoordinates

    // Falls bereits ein Fallback- oder Indoor-Tracking läuft, fließend auf
    // GPS umschalten. Dabei vorher den alten Modus sauber räumen, damit kein
    // Timer/Mode-Flag aus dem vorherigen Pfad hängen bleibt.
    if isTrackingFallback || isIndoor {
      isTrackingFallback = false
      isIndoor = false
      stopTimer()
    }

    prepareTrackingState(from: run)
    if preservedElapsedSeconds > elapsedSeconds {
      elapsedSeconds = preservedElapsedSeconds
      durationMinutes = max(preservedDurationMinutes, Int(Double(preservedElapsedSeconds) / 60.0))
      startReferenceDate = Date().addingTimeInterval(-TimeInterval(preservedElapsedSeconds))
      splitAnchorDurationSeconds = max(preservedSplitAnchorDurationSeconds, splitAnchorDurationSeconds)
      manualLapAnchorDurationSeconds = max(preservedManualLapAnchorDurationSeconds, manualLapAnchorDurationSeconds)
      splitAnchorDistance = max(preservedSplitAnchorDistance, splitAnchorDistance)
      manualLapAnchorDistance = max(preservedManualLapAnchorDistance, manualLapAnchorDistance)
    }
    if preservedRouteCoordinates.count > routeCoordinates.count {
      routeCoordinates = preservedRouteCoordinates
    }
    cardioModality = run.modality
    autoPauseEnabled = run.autoPauseEnabled
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
    let preservedElapsedSeconds = elapsedSeconds
    let preservedDurationMinutes = durationMinutes
    let preservedSplitAnchorDurationSeconds = splitAnchorDurationSeconds
    let preservedManualLapAnchorDurationSeconds = manualLapAnchorDurationSeconds
    let preservedSplitAnchorDistance = splitAnchorDistance
    let preservedManualLapAnchorDistance = manualLapAnchorDistance
    let preservedRouteCoordinates = routeCoordinates

    if isUsingGPS {
      if Self.hasLocationBackgroundMode {
        manager.allowsBackgroundLocationUpdates = false
      }
      manager.stopUpdatingLocation()
      isUsingGPS = false
      stopTimer()
    }
    if isIndoor {
      isIndoor = false
      stopTimer()
    }
    guard !isTrackingFallback else { return }

    prepareTrackingState(from: run)
    if preservedElapsedSeconds > elapsedSeconds {
      elapsedSeconds = preservedElapsedSeconds
      durationMinutes = max(preservedDurationMinutes, Int(Double(preservedElapsedSeconds) / 60.0))
      startReferenceDate = Date().addingTimeInterval(-TimeInterval(preservedElapsedSeconds))
      splitAnchorDurationSeconds = max(preservedSplitAnchorDurationSeconds, splitAnchorDurationSeconds)
      manualLapAnchorDurationSeconds = max(preservedManualLapAnchorDurationSeconds, manualLapAnchorDurationSeconds)
      splitAnchorDistance = max(preservedSplitAnchorDistance, splitAnchorDistance)
      manualLapAnchorDistance = max(preservedManualLapAnchorDistance, manualLapAnchorDistance)
    }
    if preservedRouteCoordinates.count > routeCoordinates.count {
      routeCoordinates = preservedRouteCoordinates
    }
    cardioModality = run.modality
    isTrackingFallback = true
    autoPauseEnabled = run.autoPauseEnabled
    fallbackPaceSeconds = max(run.averagePaceSeconds, 330)
    startTimer()
  }

  /// Indoor-Tracking ohne GPS — der Heimtrainer/Spinning-Pfad. Es läuft nur
  /// der Sekunden-Timer; Distanz wird vom View über `adjustIndoorDistance(by:)`
  /// hochgeschoben (Stepper-UI). Auto-Pause ist hier sinnlos und bleibt aus.
  func beginIndoorTracking(from run: ActiveRunSession) {
    let preservedElapsedSeconds = elapsedSeconds
    let preservedDurationMinutes = durationMinutes
    let preservedSplitAnchorDurationSeconds = splitAnchorDurationSeconds
    let preservedManualLapAnchorDurationSeconds = manualLapAnchorDurationSeconds
    let preservedSplitAnchorDistance = splitAnchorDistance
    let preservedManualLapAnchorDistance = manualLapAnchorDistance
    let preservedRouteCoordinates = routeCoordinates

    if isUsingGPS {
      if Self.hasLocationBackgroundMode {
        manager.allowsBackgroundLocationUpdates = false
      }
      manager.stopUpdatingLocation()
      isUsingGPS = false
      stopTimer()
    }
    if isTrackingFallback {
      isTrackingFallback = false
      stopTimer()
    }
    guard !isIndoor else { return }
    prepareTrackingState(from: run)
    if preservedElapsedSeconds > elapsedSeconds {
      elapsedSeconds = preservedElapsedSeconds
      durationMinutes = max(preservedDurationMinutes, Int(Double(preservedElapsedSeconds) / 60.0))
      startReferenceDate = Date().addingTimeInterval(-TimeInterval(preservedElapsedSeconds))
      splitAnchorDurationSeconds = max(preservedSplitAnchorDurationSeconds, splitAnchorDurationSeconds)
      manualLapAnchorDurationSeconds = max(preservedManualLapAnchorDurationSeconds, manualLapAnchorDurationSeconds)
      splitAnchorDistance = max(preservedSplitAnchorDistance, splitAnchorDistance)
      manualLapAnchorDistance = max(preservedManualLapAnchorDistance, manualLapAnchorDistance)
    }
    if preservedRouteCoordinates.count > routeCoordinates.count {
      routeCoordinates = preservedRouteCoordinates
    }
    cardioModality = run.modality
    isIndoor = true
    autoPauseEnabled = false
    startTimer()
  }

  /// Erhöht (oder reduziert, wenn negativ) die Indoor-Distanz manuell.
  /// Erzeugt automatische 1-km-Splits genau wie der GPS-Pfad.
  func adjustIndoorDistance(by deltaKm: Double) {
    guard isIndoor else { return }
    let nextDistance = max(0, trackedDistanceKm + deltaKm)
    trackedDistanceKm = nextDistance
    generateAutomaticSplits(currentHeartRate: currentHeartRate > 0 ? currentHeartRate : 130)
  }

  func restorePausedTracking(from run: ActiveRunSession) {
    let preservedElapsedSeconds = elapsedSeconds
    let preservedDurationMinutes = durationMinutes
    let preservedSplitAnchorDurationSeconds = splitAnchorDurationSeconds
    let preservedManualLapAnchorDurationSeconds = manualLapAnchorDurationSeconds
    let preservedSplitAnchorDistance = splitAnchorDistance
    let preservedManualLapAnchorDistance = manualLapAnchorDistance
    let preservedRouteCoordinates = routeCoordinates
    let preservedLastLocation = lastLocation
    let preservedLastMovementDate = lastMovementDate
    let preservedAutoPaused = autoPaused
    let preservedPauseDate = pauseDate
    if Self.hasLocationBackgroundMode {
      manager.allowsBackgroundLocationUpdates = false
    }
    if isUsingGPS {
      manager.stopUpdatingLocation()
    }
    stopTimer()

    prepareTrackingState(from: run)
    currentHeartRate = run.currentHeartRate
    cardioModality = run.modality
    isUsingGPS = false
    isTrackingFallback = false
    isIndoor = false

    if !run.modality.requiresGPS {
      isIndoor = true
      autoPauseEnabled = false
    } else if canStartTracking {
      isUsingGPS = true
      autoPauseEnabled = run.autoPauseEnabled
    } else {
      isTrackingFallback = true
      autoPauseEnabled = run.autoPauseEnabled
      fallbackPaceSeconds = max(run.averagePaceSeconds, 330)
    }

    if preservedElapsedSeconds > elapsedSeconds {
      elapsedSeconds = preservedElapsedSeconds
      durationMinutes = max(preservedDurationMinutes, Int(Double(preservedElapsedSeconds) / 60.0))
      startReferenceDate = Date().addingTimeInterval(-TimeInterval(preservedElapsedSeconds))
      splitAnchorDurationSeconds = max(preservedSplitAnchorDurationSeconds, splitAnchorDurationSeconds)
      manualLapAnchorDurationSeconds = max(preservedManualLapAnchorDurationSeconds, manualLapAnchorDurationSeconds)
      splitAnchorDistance = max(preservedSplitAnchorDistance, splitAnchorDistance)
      manualLapAnchorDistance = max(preservedManualLapAnchorDistance, manualLapAnchorDistance)
    }
    if preservedRouteCoordinates.count > routeCoordinates.count {
      routeCoordinates = preservedRouteCoordinates
    }
    lastLocation = preservedLastLocation
    lastMovementDate = preservedLastMovementDate
    autoPaused = preservedAutoPaused
    pauseDate = preservedPauseDate ?? Date()
    if isUsingGPS, Self.hasLocationBackgroundMode {
      manager.allowsBackgroundLocationUpdates = false
    }
    objectWillChange.send()
  }

  func pauseTracking(clearAutoPause: Bool = true, stopLocationUpdates: Bool = true) {
    guard isUsingGPS || isTrackingFallback || isIndoor else { return }
    if clearAutoPause {
      autoPaused = false
    }
    pauseDate = Date()
    if isUsingGPS, stopLocationUpdates {
      if Self.hasLocationBackgroundMode {
        manager.allowsBackgroundLocationUpdates = false
      }
      manager.stopUpdatingLocation()
    }
    stopTimer()
  }

  func resumeTracking() {
    guard isUsingGPS || isTrackingFallback || isIndoor else { return }

    if let pauseDate {
      pausedDuration += Date().timeIntervalSince(pauseDate)
      self.pauseDate = nil
    }
    autoPaused = false

    if isUsingGPS {
      if let currentLocation = manager.location, currentLocation.horizontalAccuracy > 0 {
        lastLocation = currentLocation
        lastMovementDate = currentLocation.timestamp
      } else {
        lastLocation = nil
        lastMovementDate = Date()
      }
      if Self.hasLocationBackgroundMode {
        manager.allowsBackgroundLocationUpdates = true
      }
      if canRequestPermission {
        manager.requestWhenInUseAuthorization()
      }
      manager.startUpdatingLocation()
    } else {
      lastMovementDate = Date()
    }

    startTimer()
  }

  func stopTracking() {
    isUsingGPS = false
    isTrackingFallback = false
    isIndoor = false
    autoPaused = false
    trackedDistanceKm = 0
    elevationGain = 0
    durationMinutes = 0
    elapsedSeconds = 0
    splits = []
    routeCoordinates = []
    currentHeartRate = 0
    objectWillChange.send()
    // Alle internen State-Variablen zurücksetzen, damit ein erneuter Start
    // (z.B. direkt nach Verwerfen → neues Setup) keine stale-Werte trägt.
    lastLocation = nil
    startReferenceDate = nil
    pauseDate = nil
    pausedDuration = 0
    lastMovementDate = Date()
    // Coordinate-Counter reset — nächster Start beginnt bei 0.
    _routeUpdateCounter = 0
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
        if autoPaused {
          autoPaused = false
          lastLocation = location
          continue
        }
      }

      if autoPaused {
        lastLocation = location
        continue
      }

      if let lastLocation {
        let delta = location.distance(from: lastLocation)
        // 2026-05-01 P1-7: GPS-Plausibilitätsprüfung speed-basiert statt fix
        // 250m. Vorher: feste Obergrenze schluckte legitime schnelle Sprints
        // (Bergab) und längere Tunnel-Recovery-Updates. Jetzt: berechne
        // implizite Geschwindigkeit über dt und vergleiche gegen einen
        // realistischen Modus-Threshold (Lauf ~10 m/s, Rad ~25 m/s).
        // Untergrenze 3m bleibt — Filter gegen GPS-Jitter im Stand.
        let dt = max(location.timestamp.timeIntervalSince(lastLocation.timestamp), 0.001)
        let impliedSpeed = delta / dt // m/s
        // Modus-spezifische Speed-Grenze (Lauf 10 m/s, Rad 25 m/s, Indoor wird
        // hier ohnehin nicht durchlaufen, da `isUsingGPS` dann false ist).
        let maxSpeed: Double = cardioModality.maxPlausibleSpeed
        if delta >= 3, impliedSpeed <= maxSpeed {
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
    currentHeartRate = run.currentHeartRate
    // Kapazität vorallozieren: bei 1h Lauf + distanceFilter=5m ≈ 720 Coords.
    // `reserveCapacity` verhindert mehrfache Array-Reallokationen und reduziert
    // Heap-Fragmentierung. 2000 slots decken ≈ 10km ab, wachsen aber weiter.
    var coords = run.routeCoordinates
    if coords.capacity < 2000 { coords.reserveCapacity(2000) }
    routeCoordinates = coords
    _routeUpdateCounter = 0
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
    // .common RunLoop-Modus: Timer feuert auch während Scroll/Touch-Tracking
    // (UIScrollView wechselt in .tracking-Modus, Default-Timer pausieren dann).
    let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      self?.updateDuration()
      self?.checkAutoPause()
    }
    RunLoop.main.add(t, forMode: .common)
    timer = t
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

// MARK: - Glass-Picker-Chip (Run-lokal)

private extension View {
  /// Glas-Chip-Hintergrund für die Run-Picker (Modus / Intensität / Ziel /
  /// Feel) und die Indoor-Stepper. Ausgewählt: frostige Glasfläche + feine
  /// Lime-Akzent-Hairline. Sonst: ruhiges Glas/Outline ohne Farbe.
  ///
  /// Ersetzt das alte `isSelected ? Lime-Fill : card`-Muster — Lime lebt nur
  /// noch in der Hairline, nie als Vollfläche (Design-Richtung 2026-05-29:
  /// hell/luftiger Clean-Glass, Lime = reiner Akzent ohne Glow).
  func runPickerChip(
    selected: Bool,
    corner: CGFloat = GainsRadius.small,
    accent: Color = GainsColor.lime
  ) -> some View {
    let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
    return self
      .background {
        ZStack {
          shape.fill(GainsColor.glassUndertone)
          shape.fill(.ultraThinMaterial)
          if selected { shape.fill(accent.opacity(0.10)) }
          shape.fill(
            LinearGradient(
              colors: [GainsColor.glassInnerLight, .clear],
              startPoint: .topLeading,
              endPoint: .center
            )
          )
        }
      }
      .overlay {
        shape.strokeBorder(
          selected ? accent.opacity(0.55) : GainsColor.border.opacity(0.7),
          lineWidth: selected ? GainsBorder.accent : GainsBorder.hairline
        )
      }
      .clipShape(shape)
  }
}
