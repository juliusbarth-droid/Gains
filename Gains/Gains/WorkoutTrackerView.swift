import AudioToolbox
import Combine
import SwiftUI
import UIKit

// 2026-05-29 (Polish-Pass — Julius-Direktive „normale Schriftart"):
// Der Tracker verlässt das monospaced HUD-Vokabular und nutzt die normale
// proportionale System-Schrift. Zahlen bekommen an den dynamischen Stellen
// `.monospacedDigit()` (tabellarische Ziffern, kein Jitter bei Live-Timern),
// aber die Glyphen selbst sind proportional. Lokal gehalten, damit der Rest
// der App (bewusst monospaced) unberührt bleibt — bei Bedarf app-weit ziehen.
private enum TrackerType {
  static let eyebrow = Font.system(size: 11, weight: .semibold)
  static let metricSmall = Font.system(size: 16, weight: .semibold)
  static let metric = Font.system(size: 20, weight: .semibold)
}

struct WorkoutTrackerView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  @ObservedObject private var healthKit = HealthKitManager.shared

  @State private var activeSetID: UUID?
  @State private var activeSetStartedAt: Date?
  // 2026-05-01 P1-3: restTimerEndsAt und restDuration leben jetzt im
  // GainsStore (`activeRestTimerEndsAt` / `activeRestDuration`), damit
  // der Pause-Timer View-Resets übersteht (Tab-Switch, Memory-Pressure).
  // Wir wrappen den Store-Zugriff in lokale Computed-Properties, damit
  // bestehende Call-Sites unverändert bleiben.
  private var restTimerEndsAt: Date? {
    get { store.activeRestTimerEndsAt }
    nonmutating set { store.activeRestTimerEndsAt = newValue }
  }
  private var restDuration: Int {
    get { store.activeRestDuration }
    nonmutating set { store.activeRestDuration = newValue }
  }
  @State private var isFinishing = false
  @State private var collapsedExerciseIDs: Set<UUID> = []
  @State private var formGuideExercise: ExerciseLibraryItem?
  // Optimierungs-Sweep 2026-05-03:
  // - skipConfirmExercise: Mis-Tap-Schutz für „ÜBERSPRINGEN".
  // - lastAutoCollapsedID: Track, welche Übung wir zuletzt beim
  //   Erreichen von „all done" automatisch eingeklappt haben — verhindert
  //   ständiges Re-Collapsen, wenn der User die Karte manuell wieder
  //   öffnet.
  @State private var skipConfirmExercise: TrackedExercise?
  @State private var lastAutoCollapsedID: UUID?
  // 2026-05-31 (Bearbeiten-Modus): Aus dem reinen Reorder-Toggle wird ein
  // vollwertiger „Bearbeiten"-Modus. Aktiv blendet er pro Übung eine
  // kompakte Edit-Zeile ein (Sortier-Pfeile + Löschen) statt der vollen
  // Tracking-Karte — entdeckbar statt im versteckten Long-Press-Menü.
  @State private var isEditMode = false
  // 2026-05-31: „Übung hinzufügen" während der laufenden Session. Öffnet
  // die geteilte ExercisePickerSheet (Single Source of Truth mit dem
  // Pre-Workout-Setup) und hängt die Auswahl über
  // `store.appendActiveExercise` an das aktive Workout an.
  @State private var isShowingExercisePicker = false
  // Ziel für den Auto-Scroll, sobald eine neue Übung angehängt wurde —
  // schiebt die frische Karte sanft ins Sichtfeld.
  @State private var scrollToExerciseID: UUID?
  // 2026-05-14 Audit-Step 2: Undo-Snackbar für destruktive Aktionen.
  // Hält den letzten gelöschten Set / die letzte gelöschte Übung als
  // Snapshot, plus eine `undo`-Closure. Wird nach 4 s automatisch
  // ausgeblendet.
  @State private var pendingUndo: PendingTrackerUndo?

  // 2026-05-14: Drag&Drop-State für Übungs-Reorder.
  //
  // - `draggingExerciseID` markiert die Karte, die der User aktiv
  //   hochhebt — wird genutzt um Source-Card zu dimmen.
  // - `dropHoverID` zeigt an, über welcher Karte der Drag gerade
  //   schwebt — die Ziel-Karte bekommt einen Lime-Insertion-Indicator.
  @State private var draggingExerciseID: UUID?
  @State private var dropHoverID: UUID?

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        GainsAppBackground()

        if let workout = store.activeWorkout {
          ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
              VStack(spacing: GainsSpacing.m) {
                commandBar(workout)
                exercisesList(workout)
              }
              .padding(.horizontal, GainsSpacing.l)
              .padding(.top, GainsSpacing.tight)
              .padding(.bottom, 124)
            }
            // Auto-Scroll zur aktiven Übung (Optimierungs-Sweep 2026-05-03):
            // Sobald sich die `nextPending`-Übung ändert (Satz fertig →
            // letzter Satz der Übung erledigt → springt zur nächsten),
            // schiebt der Reader die neue Karte sanft an den oberen Rand.
            // Verzögert leicht, damit Auto-Collapse vorher durchläuft.
            .onChange(of: currentExerciseID(in: workout)) { _, newID in
              guard let newID else { return }
              // 2026-05-14 (Sheet-Race-Hardening): Task statt asyncAfter,
              // damit der Scroll-Trigger sauber mit der View-Lifetime
              // verschwindet (vermeidet Stale-Animation nach Sheet-Close).
              Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                guard let liveWorkout = store.activeWorkout,
                      liveWorkout.id == workout.id,
                      currentExerciseID(in: liveWorkout) == newID else { return }
                withAnimation(.easeInOut(duration: 0.32)) {
                  proxy.scrollTo(newID, anchor: .top)
                }
              }
            }
            // 2026-05-31: Auto-Scroll zur frisch hinzugefügten Übung.
            // Da eine angehängte Übung `nextPending` nicht verändert (die
            // aktive Übung bleibt vorne), triggert der obige Handler nicht —
            // deshalb ein eigener Scroll-Trigger auf die neue Karte.
            .onChange(of: scrollToExerciseID) { _, target in
              guard let target else { return }
              Task { @MainActor in
                try? await Task.sleep(nanoseconds: 80_000_000)
                guard scrollToExerciseID == target else { return }
                guard let liveWorkout = store.activeWorkout,
                      liveWorkout.id == workout.id,
                      liveWorkout.exercises.contains(where: { $0.id == target })
                else {
                  if scrollToExerciseID == target {
                    scrollToExerciseID = nil
                  }
                  return
                }
                withAnimation(.easeInOut(duration: 0.34)) {
                  proxy.scrollTo(target, anchor: .center)
                }
                if scrollToExerciseID == target {
                  scrollToExerciseID = nil
                }
              }
            }
          }

          VStack(spacing: GainsSpacing.s) {
            // 2026-05-14 Audit-Step 2: Undo-Snackbar — schwebt über dem
            // bottomCTA, blendet sich automatisch nach 4 s wieder aus.
            if let undo = pendingUndo {
              GainsUndoSnackbar(
                message: undo.message,
                onUndo: {
                  focusedField = nil
                  undo.perform()
                  withAnimation(.easeOut(duration: 0.22)) {
                    pendingUndo = nil
                  }
                  UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
              )
              .padding(.horizontal, GainsSpacing.l)
              .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if isEditMode {
              editDoneBar
                .padding(.horizontal, GainsSpacing.l)
            } else {
              bottomCTA(workout)
                .padding(.horizontal, GainsSpacing.l)
            }
          }
          .padding(.bottom, GainsSpacing.l)
        } else {
          // 2026-05-14 (Polish-Loop 55): Empty-State mit Halo-Icon-
          // Plate + ruhiger Typografie. Sollte selten zu sehen sein,
          // aber wenn doch — wirkt jetzt einladend, nicht „leer".
          VStack(spacing: GainsSpacing.m) {
            ZStack {
              Circle()
                .fill(GainsColor.lime.opacity(0.10))
                .frame(width: 80, height: 80)
              Circle()
                .strokeBorder(
                  LinearGradient(
                    colors: [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                  ),
                  lineWidth: 1
                )
                .frame(width: 80, height: 80)
              Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(GainsColor.lime)
                .shadow(color: GainsColor.lime.opacity(0.225), radius: 6)
            }
            .compositingGroup()
            .shadow(color: GainsColor.lime.opacity(0.11), radius: 16)

            VStack(spacing: GainsSpacing.xs) {
              Text("Kein aktives Training")
                .font(GainsFont.title(20))
                .foregroundStyle(GainsColor.ink)
              Text("Starte ein Training vom Plan oder der Bibliothek.")
                .font(GainsFont.body)
                .foregroundStyle(GainsColor.softInk)
                .multilineTextAlignment(.center)
            }

            Button {
              focusedField = nil
              scrollToExerciseID = nil
              dismiss()
            } label: {
              Text("SCHLIESSEN")
                .font(TrackerType.eyebrow)
                .tracking(GainsTracking.eyebrowTight)
                .foregroundStyle(GainsColor.softInk)
                .padding(.horizontal, GainsSpacing.l)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .overlay(
                  Capsule().stroke(GainsColor.border.opacity(0.6), lineWidth: 1)
                )
                .clipShape(Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Leeren Trainingsbildschirm schließen")
            .accessibilityValue("Kein aktives Training geöffnet, bereit zur Rückkehr zur Trainingsübersicht")
            .accessibilityHint("Schließt den leeren Trainingsbildschirm und kehrt direkt zur Trainingsübersicht zurück")
            .padding(.top, GainsSpacing.xs)
          }
          .padding(.horizontal, GainsSpacing.l)
          .accessibilityElement(children: .contain)
          .accessibilityLabel("Kein aktives Training")
          .accessibilityValue("Kein aktives Training geöffnet, bereit zum Starten über Plan oder Bibliothek")
          .accessibilityHint("Wähle jetzt einen Plan oder direkt eine Übung aus der Bibliothek, um dein aktives Training zu starten")
        }
      }
      // Pause-Ende-Trigger (Optimierungs-Sweep 2026-05-03):
      // .task(id:) wird neu gestartet, sobald restTimerEndsAt sich ändert
      // (Set abgeschlossen → neuer Endzeitpunkt; ÜBERSPRINGEN → nil).
      // Wir schlafen bis zum exakten Ende und feuern dann Haptik + Sound,
      // bevor der Endzeitpunkt geräuschlos auf nil gesetzt wird. So gibt
      // es genau eine Benachrichtigung pro Pause, kein 1s-Polling nötig.
      // 2026-05-14 Audit-Step 2: Auto-Dismiss der Undo-Snackbar nach 4 s.
      // `.task(id:)` startet neu, sobald ein neues `pendingUndo` gesetzt
      // wird — alte Tasks werden cancelled, sodass die Lebenszeit klar
      // mit dem aktuellsten Undo verknüpft ist.
      .task(id: pendingUndo?.id) {
        guard pendingUndo != nil else { return }
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.22)) {
          pendingUndo = nil
        }
      }
      .task(id: restTimerEndsAt) {
        guard let end = restTimerEndsAt else { return }
        let interval = end.timeIntervalSinceNow
        // Bug-Fix: Wenn der Timer bereits abgelaufen ist (z.B. View war kurz
        // geschlossen), leise clearen ohne Haptik/Sound. Andernfalls würde
        // beim Wiederöffnen des Trackers sofort ein verspätetes „Pause vorbei"
        // feuern, obwohl der User davon nichts mitbekommen hat.
        guard interval > 0 else {
          restTimerEndsAt = nil
          return
        }
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        guard !Task.isCancelled, restTimerEndsAt == end else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        // 1057 = "Tink" (kurz, dezent — passt zu „Pause vorbei")
        AudioServicesPlaySystemSound(SystemSoundID(1057))
        restTimerEndsAt = nil
      }
      .onAppear {
        HealthKitManager.shared.startHeartRateObserver()
      }
      .onDisappear {
        HealthKitManager.shared.stopHeartRateObserver()
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            focusedField = nil
            scrollToExerciseID = nil
            dismiss()
          } label: {
            Image(systemName: "chevron.down")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 36, height: 36)
              .background(GainsColor.card)
              .clipShape(Circle())
              .contentShape(Circle())
          }
          .accessibilityLabel("Aktiven Trainingsbildschirm schließen")
          .accessibilityValue("Dein aktives Training bleibt erhalten, bereit zur Rückkehr zur Trainingsübersicht")
          .accessibilityHint("Schließt den aktiven Trainingsbildschirm, dein aktives Training bleibt erhalten und du kehrst direkt zur Trainingsübersicht zurück")
        }
        ToolbarItem(placement: .principal) {
          Text("KRAFT-TRAINER")
            .font(TrackerType.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            focusedField = nil
            scrollToExerciseID = nil
            isFinishing = true
          } label: {
            HStack(spacing: GainsSpacing.xs) {
              Image(systemName: "flag.checkered")
                .font(.system(size: 10, weight: .heavy))
              Text("ABSCHLUSSBESTÄTIGUNG ÖFFNEN")
                .font(TrackerType.eyebrow)
                .tracking(GainsTracking.eyebrowTight)
            }
            // 2026-05-29 (Kohäsions-Pass): ENDE neutral statt Coral — eine
            // konkurrierende Hue weniger. Glas/Outline statt Farb-Fill.
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.75))
            .padding(.horizontal, GainsSpacing.s)
            .frame(height: 32)
            .overlay(
              Capsule().strokeBorder(GainsColor.onCtaSurface.opacity(0.22), lineWidth: 1)
            )
            .clipShape(Capsule())
            .contentShape(Capsule())
          }
          .disabled(store.activeWorkout?.exercises.isEmpty != false)
          .accessibilityLabel("Abschlussbestätigung deines aktiven Trainings öffnen")
          .accessibilityValue(store.activeWorkout == nil ? "Kein aktives Training geöffnet, Abschluss nicht verfügbar" : (store.activeWorkout?.exercises.isEmpty == true ? "Dein aktives Training enthält noch keine Übung, Abschluss nicht verfügbar" : "Dein aktives Training ist bereit zum Speichern, Fortsetzen oder Verwerfen"))
          .accessibilityHint(store.activeWorkout == nil ? "Nicht verfügbar, weil aktuell kein Training geöffnet ist" : (store.activeWorkout?.exercises.isEmpty == true ? "Nicht verfügbar, weil dein aktives Training erst mindestens eine Übung braucht" : "Öffnet die Abschlussbestätigung deines aktiven Trainings, in der du es speichern, fortsetzen oder verwerfen kannst"))
        }
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Fertig") {
            UIApplication.shared.sendAction(
              #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
          }
          .font(GainsFont.label(12))
          .foregroundStyle(GainsColor.moss)
        }
      }
      .sheet(item: $formGuideExercise) { item in
        NavigationStack {
          ExerciseDetailSheet(exercise: item)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
      }
      // 2026-05-31: „Übung hinzufügen" während der Session. Wiederverwendung
      // der geteilten ExercisePickerSheet. Nach der Auswahl wird die Übung
      // ans aktive Workout angehängt, der Picker geschlossen, ein Auto-Scroll
      // zur frischen Karte ausgelöst und ein Success-Haptik gefeuert.
      .sheet(isPresented: $isShowingExercisePicker) {
        ExercisePickerSheet { item in
          store.appendActiveExercise(from: item)
          isShowingExercisePicker = false
          if let newID = store.activeWorkout?.exercises.last?.id {
            // Frisch angehängte Übung soll offen & sichtbar sein.
            collapsedExerciseIDs.remove(newID)
            scrollToExerciseID = newID
          }
          UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .environmentObject(store)
      }
      // 2026-05-03 Intuitivitäts-Sweep P1-10: Reihenfolge so, dass die
      // gewünschte Aktion (Speichern) als „bequemster" Button greifbar ist
      // und „Verwerfen" als destructive sichtbar getrennt ganz unten landet.
      // iOS bündelt destructive Buttons sowieso unten — wir sortieren sie
      // explizit, damit der Mis-Tap-Abstand zur primären Save-Aktion größer
      // wird.
      .alert("Aktives Training speichern, fortsetzen oder verwerfen", isPresented: $isFinishing) {
        Button("Aktives Training speichern") {
          scrollToExerciseID = nil
          if activeSetID != nil {
            stopActiveSet()
          }
          restTimerEndsAt = nil
          store.finishWorkout()
          dismiss()
        }
        Button("Aktives Training fortsetzen", role: .cancel) {
          scrollToExerciseID = nil
          isFinishing = false
        }
        Button("Aktives Training verwerfen", role: .destructive) {
          scrollToExerciseID = nil
          if activeSetID != nil {
            stopActiveSet()
          }
          restTimerEndsAt = nil
          store.discardWorkout()
          dismiss()
        }
      } message: {
        Text("Wenn du dein aktives Training speicherst, wird es gespeichert und dein aktueller Fortschritt bleibt erhalten. Wenn du dein aktives Training fortsetzt, kehrst du direkt zu deinem aktiven Training zurück. Wenn du dein aktives Training verwirfst, wird es verworfen und dein aktueller Fortschritt geht verloren.")
      }
      .onChange(of: store.activeWorkout?.id) { oldID, newID in
        if oldID != newID {
          activeSetID = nil
          activeSetStartedAt = nil
          restTimerEndsAt = nil
          isFinishing = false
          isEditMode = false
          isShowingExercisePicker = false
          skipConfirmExercise = nil
          lastAutoCollapsedID = nil
          formGuideExercise = nil
          scrollToExerciseID = nil
          pendingUndo = nil
          focusedField = nil
          collapsedExerciseIDs = []
          draggingExerciseID = nil
          dropHoverID = nil
        }
      }
      .onChange(of: store.activeWorkout?.exercises.isEmpty) { _, isEmpty in
        if isEmpty == true {
          activeSetID = nil
          activeSetStartedAt = nil
          restTimerEndsAt = nil
          isFinishing = false
          isEditMode = false
          isShowingExercisePicker = false
          skipConfirmExercise = nil
          lastAutoCollapsedID = nil
          formGuideExercise = nil
          scrollToExerciseID = nil
          pendingUndo = nil
          focusedField = nil
          collapsedExerciseIDs = []
          draggingExerciseID = nil
          dropHoverID = nil
        }
      }
      // Mis-Tap-Schutz für Skip (Optimierungs-Sweep 2026-05-03)
      .confirmationDialog(
        skipConfirmExercise.map { "'\($0.name)' überspringen?" } ?? "Übung überspringen?",
        isPresented: Binding(
          get: { skipConfirmExercise != nil },
          set: { if !$0 { skipConfirmExercise = nil } }
        ),
        titleVisibility: .visible,
        presenting: skipConfirmExercise
      ) { exercise in
        let pending = exercise.sets.filter { !$0.isCompleted }.count
        let actionTitle: String = {
          switch pending {
          case 0: return "Übung überspringen"
          case 1: return "Übung mit 1 offenem Satz überspringen"
          default: return "Übung mit \(pending) offenen Sätzen überspringen"
          }
        }()

        Button(actionTitle, role: .destructive) {
          performSkipExercise(exercise)
        }
        Button("Übung behalten", role: .cancel) {}
      } message: { exercise in
        // 2026-05-03 Intuitivitäts-Sweep P1-12: Wording ehrlich machen.
        // Skip ≠ erledigt — die offenen Sätze bleiben ungezählt, damit
        // Volumen/Stats nicht verfälscht werden. Du kannst die Übung später
        // wieder aufklappen und Sätze nachtragen.
        let pending = exercise.sets.filter { !$0.isCompleted }.count
        let message: String = {
          switch pending {
          case 0:
            return "Wenn du die Übung behältst, kehrst du direkt in dein aktives Training zu ihr zurück. Wenn du sie überspringst, wird sie nur eingeklappt."
          case 1:
            return "Wenn du die Übung behältst, kehrst du direkt in dein aktives Training zu deinem offenen Satz zurück. Wenn du sie überspringst, bleibt 1 offener Satz ungezählt und Volumen sowie Stats bleiben korrekt."
          default:
            return "Wenn du die Übung behältst, kehrst du direkt in dein aktives Training zu deinen offenen Sätzen zurück. Wenn du sie überspringst, bleiben \(pending) offene Sätze ungezählt und Volumen sowie Stats bleiben korrekt."
          }
        }()
        Text(message)
      }
    }
  }

  // MARK: - Command Bar (Header + Timer + Stats fusioniert)

  private func commandBar(_ workout: WorkoutSession) -> some View {
    // Optimierungs-Sweep 2026-05-03:
    // isRest/isSet werden hier nur noch grob ermittelt (existiert die
    // Pause überhaupt? läuft ein Satz?). Die Sekunden-genaue Anzeige
    // läuft in TimelineView-Subviews, sodass der Body nicht mehr jede
    // Sekunde re-rendert. Der Body ändert sich nur noch bei echten
    // State-Wechseln (Pause start/Ende, Set-Toggle).
    let isRest = restTimerEndsAt != nil
    let isSet = activeSetID != nil
    // 2026-05-29 (Kohäsions-Pass): Pause nicht mehr coral — Arbeit = grün,
    // Pause = neutral/weiß. Ein Akzent (grün) statt grün↔coral-Wechsel.
    let accent: Color = isSet ? GainsColor.lime : GainsColor.onCtaSurface.opacity(0.9)

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      // Zeile 1: LIVE-Chip · Titel · Gesamtdauer
      HStack(alignment: .center, spacing: GainsSpacing.tight) {
        HStack(spacing: GainsSpacing.xs) {
          Circle()
            .fill(GainsColor.lime)
            .frame(width: 6, height: 6)
          Text("AKTIV")
            .font(TrackerType.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.72))
        }
        .layoutPriority(0)

        Text(workout.title)
          .font(GainsFont.title)
          .foregroundStyle(GainsColor.onCtaSurface)
          .lineLimit(2)
          .minimumScaleFactor(0.78)
          .layoutPriority(2)

        Spacer(minLength: 6)

        // 2026-05-31 (Bearbeiten-Modus): Sichtbarer Toggle. Aktiv zeigt jede
        // Übung eine kompakte Edit-Zeile mit Sortier-Pfeilen + Löschen.
        Button {
          withAnimation(.easeInOut(duration: 0.22)) {
            isEditMode.toggle()
            focusedField = nil
            if !isEditMode {
              draggingExerciseID = nil
              dropHoverID = nil
            }
          }
          UISelectionFeedbackGenerator().selectionChanged()
        } label: {
          HStack(spacing: GainsSpacing.xs) {
            Image(systemName: isEditMode ? "checkmark" : "pencil")
              .font(.system(size: 10, weight: .heavy))
            Text(isEditMode ? "FERTIG" : "BEARBEITEN")
              .font(TrackerType.eyebrow)
              .tracking(GainsTracking.eyebrowTight)
          }
          .foregroundStyle(isEditMode ? GainsColor.onLime : GainsColor.onCtaSurface.opacity(0.85))
          .padding(.horizontal, GainsSpacing.s)
          .frame(height: 28)
          .background(
            Capsule().fill(isEditMode ? GainsColor.lime : GainsColor.onCtaSurface.opacity(0.10))
          )
          .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEditMode ? "Bearbeiten beenden" : "Übungen bearbeiten")
        .accessibilityValue(isEditMode ? "Bearbeiten-Modus für dein aktives Training aktiv, bereit zur direkten Rückkehr" : "Bearbeiten-Modus für dein aktives Training aus, bereit zum Öffnen")
        .accessibilityHint(isEditMode ? "Schließt den Bearbeiten-Modus und kehrt direkt zu deinem aktiven Training zurück" : "Öffnet den Bearbeiten-Modus zum Sortieren, Entfernen und Hinzufügen von Übungen in deinem aktiven Training")

        HStack(spacing: GainsSpacing.xxs) {
          Image(systemName: "clock")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.55))
          // Nur dieser kleine Subtree tickt jede Sekunde — nicht der
          // ganze Tracker. ⚡
          TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(sessionTimeString(start: workout.startedAt, now: context.date))
              .font(TrackerType.metricSmall)
              .monospacedDigit()
              .foregroundStyle(GainsColor.onCtaSurface.opacity(0.92))
          }
        }
        .layoutPriority(1)
      }

      // Zeile 2: Großer Status-Timer + kontextuelle Actions
      timerRow(workout: workout, isRest: isRest, isSet: isSet, accent: accent)

      // Trennlinie (Hairline)
      Rectangle()
        .fill(GainsColor.onCtaSurface.opacity(0.08))
        .frame(height: 0.5)
        .padding(.vertical, 2)

      // Zeile 3: Inline-Stats (Sätze · Volumen · HF) als kompakte Pills
      statsRow(workout)
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.m)
    .background(
      // 2026-05-14 (Polish-Loop 12): CommandBar bekommt die gleiche
      // zweiseitige Akzent-Glow-Komposition wie der Coach-Brief. Bei
      // rest/set-Zuständen leuchten oben-leading + unten-trailing
      // beide in der State-Farbe; idle bleibt ruhig.
      ZStack {
        LinearGradient(
          colors: [GainsColor.ctaSurface, GainsColor.surfaceDeep],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        if isRest || isSet {
          // 2026-05-29 (Polish-Pass): Ein einzelner Akzent-Pool oben-leading
          // statt zwei gegenüberliegender Glühflächen — ruhiger, immer noch Glas.
          RadialGradient(
            colors: [accent.opacity(0.14), accent.opacity(0.03), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 260
          )
          .blendMode(.screen)
        }
        LinearGradient(
          colors: [GainsColor.glassInnerLight, Color.clear],
          startPoint: .top,
          endPoint: .center
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [
              accent.opacity(isRest || isSet ? 0.45 : 0.20),
              accent.opacity(isRest || isSet ? 0.10 : 0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.accent
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
    // 2026-05-29 (Polish-Pass): ein einzelner, ruhiger Akzent-Glow statt der
    // gestapelten 22+40-Halos — die Tiefe trägt der Float-Shadow.
    .shadow(color: accent.opacity(isRest || isSet ? 0.16 : 0), radius: 20, x: 0, y: 0)
    .shadow(color: GainsColor.shadowFloatAmbient, radius: 18, x: 0, y: 12)
    .animation(.easeInOut(duration: 0.22), value: isRest)
    .animation(.easeInOut(duration: 0.18), value: isSet)
  }

  private func timerRow(workout: WorkoutSession, isRest: Bool, isSet: Bool, accent: Color) -> some View {
    HStack(alignment: .center, spacing: GainsSpacing.s) {
      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text(statusLabel(isRest: isRest, isSet: isSet))
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
        // TimelineView (Optimierungs-Sweep 2026-05-03):
        // Nur dieser Text re-rendert sekündlich. Der Watch-Style-Ring
        // wird als Overlay um den Pause-Countdown gelegt.
        //
        // Layout-Fix 2026-05-14: Pause-Modus zeigt jetzt einen
        // CONCENTRIC Stack (Ring + Numerik im selben Bounding-Box,
        // beide zentriert). Vorher war der Ring 80pt mit -14 Offset
        // und der Text mit 6pt Padding-Leading – das wirkte wie zwei
        // entkoppelte Elemente. Jetzt: 132pt Ring umschließt die
        // 48pt-Mono-Numerik exakt mittig.
        TimelineView(.periodic(from: .now, by: 1)) { context in
          let liveIsRest = restTimerEndsAt != nil
          let liveIsSet  = activeSetID != nil
          let liveAccent: Color = liveIsSet ? GainsColor.lime
            : GainsColor.onCtaSurface.opacity(0.9)
          let label = liveTimerLabel(isRest: liveIsRest, isSet: liveIsSet, now: context.date)
          if liveIsRest {
            // Pause-Hero: konzentrischer Ring + Countdown. Ein einzelner
            // ruhiger Glow statt zwei gestapelter Halos (Polish-Pass 2026-05-29).
            ZStack {
              RadialGradient(
                colors: [liveAccent.opacity(0.16), liveAccent.opacity(0.0)],
                center: .center,
                startRadius: 0,
                endRadius: 90
              )
              .blendMode(.plusLighter)
              watchStyleRestRing(now: context.date, accent: liveAccent)
              Text(label)
                .font(.system(size: 36, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(liveAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .shadow(color: liveAccent.opacity(0.40), radius: 9, x: 0, y: 0)
            }
            .frame(width: 132, height: 132)
            .padding(.top, GainsSpacing.xxs)
          } else if liveIsSet {
            // Satz aktiv: große Hero-Numerik mit einem fokussierten Halo.
            Text(label)
              .font(.system(size: 64, weight: .semibold))
              .monospacedDigit()
              .foregroundStyle(liveAccent)
              .lineLimit(1)
              .minimumScaleFactor(0.55)
              .shadow(color: liveAccent.opacity(0.38), radius: 12, x: 0, y: 0)
          } else {
            // Idle: kein toter 00:00-Hero mehr. Der große Timer erscheint
            // nur, wenn ein Satz oder eine Pause wirklich läuft — hier ein
            // ruhiger, zustands-bewusster Prompt statt einer großen Null
            // (Polish-Pass 2026-05-29).
            Text(nextPending(in: workout) == nil ? "Abschlussbestätigung öffnen" : "Starte den nächsten Satz")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(GainsColor.onCtaSurface.opacity(0.92))
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.top, 2)
          }
        }
      }

      Spacer(minLength: 8)

      contextActions(workout: workout, isRest: isRest, isSet: isSet)
    }
  }

  // Watch-Style Pause-Ring (Optimierungs-Sweep 2026-05-03):
  // Ringförmiger Fortschritt um den Pause-Countdown — leichter Glow,
  // animierter Trim, ähnlich Apple-Watch Timer-App.
  private func watchStyleRestRing(now: Date, accent: Color) -> some View {
    let remaining: Int = {
      guard let end = restTimerEndsAt else { return 0 }
      return max(Int(end.timeIntervalSince(now)), 0)
    }()
    let total = max(restDuration, 1)
    let progress = Double(remaining) / Double(total)
    // A17 (Liquid): Dual-Stroke-Ring mit konzentrischem Inner-Glow.
    // Track wird zur Gradient-Spur (oben heller, unten dunkler),
    // der Fortschritts-Stroke bekommt einen sanften Akzent-Glow.
    return ZStack {
      Circle()
        .stroke(
          LinearGradient(
            colors: [accent.opacity(0.22), accent.opacity(0.08)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 5
        )
      Circle()
        .trim(from: 0, to: max(progress, 0.001))
        .stroke(
          accent,
          style: StrokeStyle(lineWidth: 5, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .shadow(color: accent.opacity(0.55), radius: 8)
        .shadow(color: accent.opacity(0.30), radius: 16)
        .animation(.linear(duration: 1.0), value: progress)
    }
  }

  @ViewBuilder
  private func contextActions(workout: WorkoutSession, isRest: Bool, isSet: Bool) -> some View {
    if isRest {
      VStack(alignment: .trailing, spacing: GainsSpacing.xs) {
        if let pending = nextPending(in: workout) {
          VStack(alignment: .trailing, spacing: 4) {
            Text("ALS NÄCHSTES")
              .font(TrackerType.eyebrow)
              .tracking(GainsTracking.eyebrow)
              .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
            Text("Satz \(pending.set.order) · \(pending.exercise.name)")
              .font(GainsFont.label(12))
              .foregroundStyle(GainsColor.onCtaSurface)
              .lineLimit(2)
              .multilineTextAlignment(.trailing)
            Text(setContextDetail(pending.set))
              .font(GainsFont.label(10))
              .foregroundStyle(GainsColor.onCtaSurface.opacity(0.72))
          }
          .padding(.horizontal, GainsSpacing.tight)
          .padding(.vertical, GainsSpacing.xs)
          .background(GainsColor.onCtaSurface.opacity(0.08))
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Als Nächstes in deinem aktiven Training")
          .accessibilityValue("Satz \(pending.set.order) in \(pending.exercise.name), \(setContextDetail(pending.set))")
          .accessibilityHint("Zeigt dir den nächsten offenen Satz nach der aktuellen Erholungspause")
        }

        HStack(spacing: GainsSpacing.xs) {
          adjustChip("−15", tone: .neutral) { adjustRest(by: -15) }
            .accessibilityLabel("Aktuelle Pause um 15 Sekunden verkürzen")
            .accessibilityValue("Aktuelle Erholungspause in deinem aktiven Training läuft gerade")
            .accessibilityHint("Verkürzt die aktuelle Erholungspause in deinem aktiven Training um 15 Sekunden")
          adjustChip("+15", tone: .neutral) { adjustRest(by: 15) }
            .accessibilityLabel("Aktuelle Pause um 15 Sekunden verlängern")
            .accessibilityValue("Aktuelle Erholungspause in deinem aktiven Training läuft gerade")
            .accessibilityHint("Verlängert die aktuelle Erholungspause in deinem aktiven Training um 15 Sekunden")
        }
        adjustChip("PAUSE BEENDEN", tone: .accent) {
          focusedField = nil
          restTimerEndsAt = nil
        }
        .accessibilityLabel("Aktuelle Pause beenden")
        .accessibilityValue("Aktuelle Erholungspause in deinem aktiven Training läuft gerade")
        .accessibilityHint("Beendet die aktuelle Erholungspause in deinem aktiven Training sofort")
      }
    } else if isSet {
      VStack(alignment: .trailing, spacing: 4) {
        if let active = activeSetContext(in: workout) {
          Group {
            Text("AKTUELL")
              .font(TrackerType.eyebrow)
              .tracking(GainsTracking.eyebrow)
              .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
            Text("Satz \(active.set.order) · \(active.exercise.name)")
              .font(GainsFont.label(12))
              .foregroundStyle(GainsColor.onCtaSurface)
              .lineLimit(2)
              .multilineTextAlignment(.trailing)
            Text(setContextDetail(active.set))
              .font(GainsFont.label(10))
              .foregroundStyle(GainsColor.onCtaSurface.opacity(0.72))
          }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Aktuell in deinem aktiven Training")
          .accessibilityValue("Satz \(active.set.order) in \(active.exercise.name), \(setContextDetail(active.set))")
          .accessibilityHint("Zeigt dir den gerade laufenden Satz in deinem aktiven Training")
        }
        adjustChip("SATZ STOPPEN", tone: .accent) {
          stopActiveSet()
        }
        .accessibilityLabel("Aktiven Satz stoppen")
        .accessibilityValue("Aktiver Satz in deinem aktiven Training läuft gerade")
        .accessibilityHint("Stoppt den Timer für den aktuellen Satz in deinem aktiven Training sofort")
      }
    } else if let pending = nextPending(in: workout) {
      VStack(alignment: .trailing, spacing: 4) {
        Text("ALS NÄCHSTES")
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
        Text("Satz \(pending.set.order) · \(pending.exercise.name)")
          .font(GainsFont.label(12))
          .foregroundStyle(GainsColor.onCtaSurface)
          .lineLimit(2)
          .multilineTextAlignment(.trailing)
        Text(setContextDetail(pending.set))
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.72))
      }
      .padding(.horizontal, GainsSpacing.tight)
      .padding(.vertical, GainsSpacing.xs)
      .background(GainsColor.onCtaSurface.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Als Nächstes in deinem aktiven Training")
      .accessibilityValue("Satz \(pending.set.order) in \(pending.exercise.name), \(setContextDetail(pending.set))")
      .accessibilityHint("Zeigt dir den nächsten offenen Satz in deinem aktiven Training")
    } else if let bpm = healthKit.liveHeartRate {
      HStack(spacing: GainsSpacing.xxs) {
        Image(systemName: "heart.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(GainsColor.ember)
        Text("\(bpm)")
          .font(TrackerType.metricSmall)
          .foregroundStyle(GainsColor.onCtaSurface)
        Text("BPM")
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
      }
      .padding(.horizontal, GainsSpacing.tight)
      .padding(.vertical, GainsSpacing.xs)
      // 2026-05-29 (Kohäsions-Pass): HR-Pille auf neutrales Glas — nur das
      // Herz-Glyph bleibt als semantisches Rot, kein Coral-Block mehr.
      .background(GainsColor.onCtaSurface.opacity(0.08))
      .clipShape(Capsule())
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Live-Herzfrequenz in deinem aktiven Training")
      .accessibilityValue("\(bpm) Schläge pro Minute")
      .accessibilityHint("Zeigt dir die aktuelle Live-Herzfrequenz, solange kein nächster Satz hervorgehoben wird")
    } else {
      VStack(alignment: .trailing, spacing: 4) {
        Text("BEREIT FÜR DEN NÄCHSTEN SATZ")
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
        Text("Starte einen Satz oder hake ihn direkt ab.")
          .font(GainsFont.label(11))
          .foregroundStyle(GainsColor.onCtaSurface)
          .multilineTextAlignment(.trailing)
      }
      .padding(.horizontal, GainsSpacing.tight)
      .padding(.vertical, GainsSpacing.xs)
      .background(GainsColor.onCtaSurface.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
  }

  private enum AdjustTone { case neutral, accent }

  private func adjustChip(_ title: String, tone: AdjustTone, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(TrackerType.eyebrow)
        .tracking(GainsTracking.eyebrowTight)
        .foregroundStyle(tone == .accent ? GainsColor.lime : GainsColor.onCtaSurface.opacity(0.85))
        .frame(minWidth: 60, minHeight: 32)
        .padding(.horizontal, GainsSpacing.s)
        .background(
          tone == .accent
            ? GainsColor.lime.opacity(0.18)
            : GainsColor.onCtaSurface.opacity(0.1)
        )
        .clipShape(Capsule())
        .contentShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private func statsRow(_ workout: WorkoutSession) -> some View {
    // stats einmalig berechnen — totalSets/completedSets/totalVolume wären
    // 3 separate O(n²)-Walks; hier 1 Walk für alle drei Werte.
    let s = workout.stats
    return HStack(spacing: GainsSpacing.tight) {
      // 2026-05-29 (Kohäsions-Pass): Stat-Ticks neutral — vorher lime /
      // sage-teal / coral nebeneinander (drei konkurrierende Hues). Jetzt ist
      // die einzige Farbe im Strip der grüne Progress-Ring rechts.
      inlineStat(
        label: "SÄTZE",
        value: "\(s.completedSets)/\(s.totalSets)",
        accent: GainsColor.onCtaSurface.opacity(0.28)
      )
      inlineStat(
        label: "VOLUMEN",
        value: "\(Int(s.totalVolume)) kg",
        accent: GainsColor.onCtaSurface.opacity(0.28)
      )
      inlineStat(
        label: "Ø HF",
        value: healthKit.liveHeartRate.map { "\($0)" } ?? "--",
        accent: GainsColor.onCtaSurface.opacity(0.28)
      )

      Spacer(minLength: 0)

      // Mini-Progress: Anteil der erledigten Sätze
      let progress: CGFloat =
        s.totalSets == 0 ? 0 : CGFloat(s.completedSets) / CGFloat(s.totalSets)
      ZStack {
        Circle()
          .stroke(GainsColor.onCtaSurface.opacity(0.18), lineWidth: 3)
          .frame(width: 32, height: 32)
        Circle()
          .trim(from: 0, to: max(progress, 0.001))
          .stroke(
            GainsColor.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
          .frame(width: 32, height: 32)
          .rotationEffect(.degrees(-90))
        Text("\(Int(progress * 100))")
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .monospacedDigit()
          .foregroundStyle(GainsColor.onCtaSurface)
      }
    }
  }

  private func inlineStat(label: String, value: String, accent: Color) -> some View {
    HStack(spacing: GainsSpacing.xs) {
      RoundedRectangle(cornerRadius: 1.5, style: .continuous)
        .fill(accent)
        .frame(width: 3, height: 22)
      VStack(alignment: .leading, spacing: 1) {
        Text(label)
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.55))
        Text(value)
          .font(TrackerType.metricSmall)
          .foregroundStyle(GainsColor.onCtaSurface)
          .lineLimit(2)
          .minimumScaleFactor(0.8)
      }
    }
  }

  // MARK: - Übungsliste (kompakte, einheitliche Karten)

  @ViewBuilder
  private func exercisesList(_ workout: WorkoutSession) -> some View {
    if isEditMode {
      editModeList(workout)
    } else {
      trackingList(workout)
    }
  }

  // MARK: Tracking-Modus (volle Übungskarten)

  @ViewBuilder
  private func trackingList(_ workout: WorkoutSession) -> some View {
    // nextPending einmalig berechnen — vorher wurde es 3× pro Render aufgerufen:
    // currentExerciseID → nextPending, zweites `nextPending` für nil-Check,
    // drittes für focusSetID. Alle drei verwenden jetzt denselben Wert.
    let pending  = nextPending(in: workout)
    let currentID = pending?.exercise.id

    // 2026-05-31 (Stabilität): Leeres Workout sauber abfangen. Vorher zeigte
    // ein Workout ohne Übungen fälschlich die „Alle Sätze erledigt"-Card —
    // jetzt gibt es einen ehrlichen Empty-State mit Hinzufügen-CTA.
    if workout.exercises.isEmpty {
      emptyExercisesCard
    } else if pending == nil {
      finishedCard(workout)
    }

    VStack(spacing: GainsSpacing.tight) {
      ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
        ZStack(alignment: .trailing) {
          // 2026-05-14: Drop-Hover-Insertion-Marker — wenn der User
          // gerade über dieser Karte schwebt, blendet eine 2pt-Lime-
          // Linie OBEN auf, die anzeigt: „hier wird eingefügt".
          if dropHoverID == exercise.id && draggingExerciseID != exercise.id {
            VStack(spacing: 0) {
              RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(GainsColor.lime)
                .frame(height: 2)
                .shadow(color: GainsColor.lime.opacity(0.3), radius: 4)
              Spacer()
            }
            .padding(.top, -4)
            .transition(.opacity)
          }

          let isActive = exercise.id == currentID
          exerciseCard(
            exercise,
            index: index + 1,
            isActive: isActive,
            focusSetID: isActive ? pending?.set.id : nil
          )
          // Aktive Drag-Quelle dimmen + leicht skalieren — gibt
          // taktiles Feedback „du hast diese Karte angehoben".
          .opacity(draggingExerciseID == exercise.id ? 0.45 : 1.0)
          .scaleEffect(draggingExerciseID == exercise.id ? 0.98 : 1.0)
          .animation(.easeOut(duration: 0.18), value: draggingExerciseID)
        }
        // 2026-05-14: Drag-Source. Lange drücken → Karte „hebt sich".
        // Wir transferieren den UUID-String, weil UUID selbst kein
        // Transferable conformt. iOS 17 zeigt automatisch ein Preview.
        .draggable(exercise.id.uuidString) {
          // Drag-Preview: kompakte Pille mit Titel + Index, leicht
          // versetzt vom Finger.
          dragPreviewCard(exercise: exercise, index: index + 1)
            .onAppear {
              draggingExerciseID = exercise.id
              UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            .onDisappear {
              if draggingExerciseID == exercise.id {
                draggingExerciseID = nil
              }
            }
        }
        // Drop-Target — jede Karte ist ein Reorder-Slot.
        .dropDestination(for: String.self) { items, _ in
          handleDrop(items: items, onto: exercise.id, in: workout)
          return true
        } isTargeted: { isTargeted in
          // Hover-State steuert den Insertion-Marker oben.
          if isTargeted {
            dropHoverID = exercise.id
          } else if dropHoverID == exercise.id {
            dropHoverID = nil
          }
        }
        // ID-Marker für ScrollViewReader → ermöglicht
        // proxy.scrollTo(exercise.id, anchor: .top)
        // 2026-05-31: Das alte Long-Press-ContextMenu (Reorder/Löschen) ist
        // entfallen — es kollidierte mit `.draggable` (beide reagieren auf
        // Long-Press, was Drag-Pickups verschluckte). Reorder & Löschen
        // leben jetzt im sichtbaren Bearbeiten-Modus; Drag&Drop bleibt als
        // Schnell-Reorder erhalten.
        .id(exercise.id)
      }
    }

    addExerciseButton
      .padding(.top, GainsSpacing.xs)
  }

  // MARK: Bearbeiten-Modus (kompakte Edit-Zeilen)

  @ViewBuilder
  private func editModeList(_ workout: WorkoutSession) -> some View {
    let total = workout.exercises.count
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: "slider.horizontal.3")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(GainsColor.softInk)
        Text("SORTIEREN & ENTFERNEN")
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
      }
      .padding(.horizontal, GainsSpacing.xs)
      .padding(.top, GainsSpacing.xxs)

      if workout.exercises.isEmpty {
        emptyExercisesCard
      } else {
        ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
          editRow(exercise: exercise, index: index, total: total)
            .id(exercise.id)
        }
      }

      addExerciseButton
        .padding(.top, GainsSpacing.xxs)
    }
  }

  /// Kompakte Edit-Zeile: Index · Name/Muskel · Sortier-Pfeile · Löschen.
  private func editRow(exercise: TrackedExercise, index: Int, total: Int) -> some View {
    let completed = exercise.sets.filter(\.isCompleted).count
    return HStack(spacing: GainsSpacing.s) {
      Text("\(index + 1)")
        .font(TrackerType.metricSmall)
        .foregroundStyle(GainsColor.ink)
        .frame(width: 28, height: 28)
        .background(GainsColor.background.opacity(0.8))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(exercise.name)
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
          .minimumScaleFactor(0.85)
        Text("\(exercise.targetMuscle.uppercased()) · \(completed)/\(exercise.sets.count) SÄTZE")
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(2)
      }

      Spacer(minLength: GainsSpacing.xs)

      editMoveButton(symbol: "chevron.up", enabled: index > 0) {
        moveExercise(at: index, by: -1)
      }
      editMoveButton(symbol: "chevron.down", enabled: index < total - 1) {
        moveExercise(at: index, by: 1)
      }

      Button {
        deleteExercise(exercise, at: index)
      } label: {
        Image(systemName: "trash")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(GainsColor.ember)
          .frame(width: 34, height: 34)
          .background(GainsColor.ember.opacity(0.12))
          .clipShape(Circle())
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(exercise.name) entfernen")
      .accessibilityValue("In deinem aktiven Training: \(exercise.name), \(completed) von \(exercise.sets.count) Sätzen erledigt")
      .accessibilityHint("Entfernt \(exercise.name) aus deinem aktiven Training")
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .gainsCardStyle(GainsColor.card)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(exercise.name)
    .accessibilityValue("In deinem aktiven Training: \(exercise.targetMuscle), \(completed) von \(exercise.sets.count) Sätzen erledigt")
    .accessibilityHint("Zeigt \(exercise.name) in deinem aktiven Training mit Sortieren- und Entfernen-Aktionen")
  }

  /// Sortier-Pfeil-Button für die Edit-Zeile.
  private func editMoveButton(
    symbol: String, enabled: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 12, weight: .heavy))
        .foregroundStyle(enabled ? GainsColor.moss : GainsColor.softInk.opacity(0.35))
        .frame(width: 34, height: 34)
        .background(GainsColor.background.opacity(0.85))
        .overlay(Circle().stroke(GainsColor.border.opacity(0.5), lineWidth: 1))
        .clipShape(Circle())
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
    .accessibilityLabel(symbol == "chevron.up" ? "Nach oben" : "Nach unten")
    .accessibilityHint(enabled ? (symbol == "chevron.up" ? "Verschiebt \(exercise.name) eine Position nach oben" : "Verschiebt \(exercise.name) eine Position nach unten") : (symbol == "chevron.up" ? "Nicht verfügbar, weil \(exercise.name) bereits ganz oben steht" : "Nicht verfügbar, weil \(exercise.name) bereits ganz unten steht"))
  }

  // MARK: - Hinzufügen / Löschen / Empty-State (2026-05-31)

  /// Voll-breiter „Übung hinzufügen"-Button — öffnet die geteilte
  /// ExercisePickerSheet. Sitzt am Listenende in beiden Modi.
  private var addExerciseButton: some View {
    Button {
      focusedField = nil
      scrollToExerciseID = nil
      isShowingExercisePicker = true
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: "plus")
          .font(.system(size: 12, weight: .heavy))
          .accessibilityHidden(true)
        Text(store.activeWorkout?.exercises.isEmpty == true ? "ERSTE ÜBUNG HINZUFÜGEN" : "NEUE ÜBUNG HINZUFÜGEN")
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
      }
      .foregroundStyle(GainsColor.moss)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(GainsColor.lime.opacity(0.07))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(
            GainsColor.lime.opacity(0.55),
            style: StrokeStyle(lineWidth: 1.4, dash: [6, 5])
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(store.activeWorkout?.exercises.isEmpty == true ? "Erste Übung zum aktiven Training hinzufügen" : "Neue Übung zum aktiven Training hinzufügen")
    .accessibilityValue(store.activeWorkout?.exercises.isEmpty == true ? (isEditMode ? "Bearbeiten-Modus für dein aktives Training aktiv, bereit zum Hinzufügen der ersten Übung" : "Bearbeiten-Modus für dein aktives Training aus, bereit zum Hinzufügen der ersten Übung") : (isEditMode ? "Bearbeiten-Modus für dein aktives Training aktiv, bereit zum Hinzufügen einer neuen Übung" : "Bearbeiten-Modus für dein aktives Training aus, bereit zum Hinzufügen einer neuen Übung"))
    .accessibilityHint(store.activeWorkout?.exercises.isEmpty == true ? "Öffnet die Übungsauswahl, um deinem aktiven Training direkt die erste Übung hinzuzufügen" : "Öffnet die Übungsauswahl, um deinem aktiven Training direkt eine neue Übung hinzuzufügen")
  }

  /// Löscht eine Übung aus dem aktiven Workout — mit Undo-Snackbar.
  /// Extrahiert aus dem früheren Long-Press-ContextMenu, jetzt vom
  /// Bearbeiten-Modus aufgerufen.
  private func deleteExercise(_ exercise: TrackedExercise, at index: Int) {
    focusedField = nil
    if activeSetID != nil, exercise.sets.contains(where: { $0.id == activeSetID }) {
      stopActiveSet()
    }
    let snapshotExercise = exercise
    let snapshotIndex = index
    let exerciseName = exercise.name
    store.removeActiveExercise(id: exercise.id)
    withAnimation(.easeInOut(duration: 0.22)) {
      pendingUndo = PendingTrackerUndo(
        message: "„\(exerciseName)” entfernt",
        perform: {
          var workout = store.activeWorkout
          let safeIndex = min(snapshotIndex, workout?.exercises.count ?? 0)
          workout?.exercises.insert(snapshotExercise, at: safeIndex)
          if let updated = workout { store.activeWorkout = updated }
        }
      )
    }
    UINotificationFeedbackGenerator().notificationOccurred(.warning)
  }

  /// Empty-State, wenn (noch) keine Übung im Workout ist.
  private var emptyExercisesCard: some View {
    VStack(spacing: GainsSpacing.s) {
      ZStack {
        Circle()
          .fill(GainsColor.lime.opacity(0.10))
          .frame(width: 64, height: 64)
        Image(systemName: "dumbbell")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(GainsColor.moss)
      }
      .accessibilityHidden(true)
      VStack(spacing: GainsSpacing.xxs) {
        Text("Noch keine Übung")
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
        Text("Füge deine erste Übung hinzu, um loszulegen.")
          .font(GainsFont.caption)
          .foregroundStyle(GainsColor.softInk)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, GainsSpacing.l)
    .padding(.horizontal, GainsSpacing.m)
    .gainsCardStyle(GainsColor.elevated)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Noch keine Übung")
    .accessibilityValue(isEditMode ? "Noch keine Übung in deinem aktiven Training, Bearbeiten-Modus aktiv und bereit zum Hinzufügen der ersten Übung" : "Noch keine Übung in deinem aktiven Training, Bearbeiten-Modus aus und bereit zum Hinzufügen der ersten Übung")
    .accessibilityHint("Füge jetzt die erste Übung zu deinem aktiven Training hinzu, um direkt loszulegen")
  }

  /// „Fertig"-Leiste, die im Bearbeiten-Modus die Satz-CTA ersetzt.
  private var editDoneBar: some View {
    Button {
      withAnimation(.easeInOut(duration: 0.22)) {
        isEditMode = false
        focusedField = nil
        draggingExerciseID = nil
        dropHoverID = nil
      }
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      HStack(spacing: GainsSpacing.s) {
        Image(systemName: "checkmark")
          .font(.system(size: 13, weight: .heavy))
          .accessibilityHidden(true)
        Text("FERTIG")
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
      }
      .foregroundStyle(GainsColor.lime)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(GainsColor.ctaSurface)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
          .strokeBorder(GainsColor.lime.opacity(0.55), lineWidth: GainsBorder.accent)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Bearbeiten beenden")
    .accessibilityValue("Bearbeiten-Modus für dein aktives Training aktiv, bereit zur direkten Rückkehr")
    .accessibilityHint("Schließt den Bearbeiten-Modus und kehrt direkt zu deinem aktiven Training zurück")
  }

  // MARK: - Drag&Drop-Reorder (2026-05-14)

  /// Drag-Preview-Karte — kompakt, glasig, mit Akzent-Glow. Wird
  /// automatisch vom System unter dem Finger gerendert.
  @ViewBuilder
  private func dragPreviewCard(exercise: TrackedExercise, index: Int) -> some View {
    HStack(spacing: GainsSpacing.s) {
      Text("\(index)")
        .font(TrackerType.metricSmall)
        .foregroundStyle(GainsColor.onLime)
        .frame(width: 28, height: 28)
        .background(GainsColor.lime)
        .clipShape(Circle())
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(exercise.name)
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
        Text(exercise.targetMuscle.uppercased())
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer(minLength: 8)

      Image(systemName: "line.3.horizontal")
        .font(.system(size: 14, weight: .heavy))
        .foregroundStyle(GainsColor.lime)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .background(
      ZStack {
        GainsColor.glassUndertone
        Rectangle().fill(.regularMaterial)
        RadialGradient(
          colors: [GainsColor.lime.opacity(0.16), .clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 200
        )
        .blendMode(.screen)
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .shadow(color: GainsColor.lime.opacity(0.1), radius: 16)
    .frame(maxWidth: 320)
  }

  /// Verarbeitet einen Drop auf eine Ziel-Karte. Berechnet Source-/
  /// Target-Index und ruft `reorderActiveExercises`. Setzt anschließend
  /// die Drag-States zurück.
  private func handleDrop(items: [String], onto targetID: UUID, in workout: WorkoutSession) {
    focusedField = nil
    defer {
      // States immer aufräumen — auch wenn der Drop fehlschlägt
      withAnimation(.easeOut(duration: 0.18)) {
        draggingExerciseID = nil
        dropHoverID = nil
      }
    }
    guard
      let idString = items.first,
      let droppedID = UUID(uuidString: idString),
      droppedID != targetID,
      let from = workout.exercises.firstIndex(where: { $0.id == droppedID }),
      let to = workout.exercises.firstIndex(where: { $0.id == targetID })
    else { return }
    // SwiftUI `move(fromOffsets:toOffset:)` will: bei Verschiebung
    // nach unten muss das Ziel-Insert hinter der Source liegen
    // (toOffset == target + 1), nach oben einfach == target.
    let destination = to > from ? to + 1 : to
    withAnimation(.easeInOut(duration: 0.24)) {
      store.reorderActiveExercises(from: IndexSet(integer: from), to: destination)
    }
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }

  // MARK: - Reorder-Helfer (2026-05-14)

  /// Verschiebt eine Übung um ±1 Position. Wird vom ContextMenu aufgerufen.
  private func moveExercise(at index: Int, by delta: Int) {
    focusedField = nil
    guard let workout = store.activeWorkout else { return }
    let target = index + delta
    guard target >= 0, target < workout.exercises.count else { return }
    // SwiftUI `move(fromOffsets:toOffset:)` braucht für „nach unten"
    // ein Ziel hinter der Quelle (Insert-Index), für „nach oben" davor.
    let destination = delta > 0 ? target + 1 : target
    withAnimation(.easeInOut(duration: 0.22)) {
      store.reorderActiveExercises(from: IndexSet(integer: index), to: destination)
    }
    UISelectionFeedbackGenerator().selectionChanged()
  }

  /// Verschiebt eine Übung auf eine absolute Zielposition (Anfang/Ende).
  private func moveExercise(at index: Int, to target: Int) {
    focusedField = nil
    guard let workout = store.activeWorkout else { return }
    guard target >= 0, target < workout.exercises.count, target != index else { return }
    let destination = target > index ? target + 1 : target
    withAnimation(.easeInOut(duration: 0.22)) {
      store.reorderActiveExercises(from: IndexSet(integer: index), to: destination)
    }
    UISelectionFeedbackGenerator().selectionChanged()
  }

  private func exerciseCard(
    _ exercise: TrackedExercise, index: Int, isActive: Bool, focusSetID: UUID?
  ) -> some View {
    let completed = exercise.sets.filter(\.isCompleted).count
    let total = exercise.sets.count
    let isAllDone = completed == total && total > 0
    let isCollapsed = collapsedExerciseIDs.contains(exercise.id) && !isActive
    let accentBorder: Color =
      isActive ? GainsColor.lime.opacity(0.55)
      : (isAllDone ? GainsColor.moss.opacity(0.45) : GainsColor.border.opacity(0.45))

    // 2026-05-14 Audit-Step 6: Card-Level A11y. Damit VoiceOver-User die
    // gesamte Karte als atomisches Element vorgelesen bekommen statt 12
    // einzelne Sub-Elemente abzulaufen.
    let cardLabel: String = {
      let stateLabel: String
      if isAllDone { stateLabel = "abgeschlossen" }
      else if isActive { stateLabel = "aktiv" }
      else { stateLabel = "geplant" }
      return "\(exercise.name), \(exercise.targetMuscle), \(completed) von \(total) Sätzen, \(stateLabel)"
    }()

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      // Header (kein verschachtelter Button — Tap-Gesture für Collapse)
      HStack(alignment: .center, spacing: GainsSpacing.s) {
        // Index-Badge + Titel-Block ist tappable für Collapse
        HStack(alignment: .center, spacing: GainsSpacing.s) {
          // 2026-05-14 (Polish-Loop 60): Index-Badge mit Inner-Light
          // + Glow bei aktiv/all-done.
          Text("\(index)")
            .font(TrackerType.metricSmall)
            .foregroundStyle(
              isAllDone ? GainsColor.onLime : (isActive ? GainsColor.onLime : GainsColor.ink)
            )
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
            .background(
              ZStack {
                Circle()
                  .fill(
                    isAllDone
                      ? GainsColor.moss
                      : (isActive ? GainsColor.lime : GainsColor.background.opacity(0.8))
                  )
                if isAllDone || isActive {
                  Circle()
                    .fill(
                      LinearGradient(
                        colors: [Color.white.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .center
                      )
                    )
                    .blendMode(.plusLighter)
                }
              }
            )
            .clipShape(Circle())
            .compositingGroup()
            .shadow(
              color: isActive
                ? GainsColor.lime.opacity(0.30)
                : (isAllDone ? GainsColor.moss.opacity(0.22) : .clear),
              radius: 6
            )

          VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
            HStack(spacing: GainsSpacing.xs) {
              Text(exercise.name)
                .font(GainsFont.headline)
                .foregroundStyle(GainsColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
              if isActive {
                // 2026-05-29 (Polish-Pass): AKTIV-Badge auf eine flache
                // Lime-Pille reduziert — kein plusLighter-Inner-Light, kein
                // Glow. Der kleine Live-Dot bleibt als ruhiger Indikator.
                HStack(spacing: 4) {
                  Circle()
                    .fill(GainsColor.onLime)
                    .frame(width: 4, height: 4)
                    .accessibilityHidden(true)
                  Text("AKTIV")
                    .font(TrackerType.eyebrow)
                    .tracking(GainsTracking.eyebrowTight)
                    .foregroundStyle(GainsColor.onLime)
                }
                .accessibilityHidden(true)
                .padding(.horizontal, GainsSpacing.xs)
                .frame(height: 18)
                .background(Capsule().fill(GainsColor.lime))
                .clipShape(Capsule())
              }
            }
            HStack(spacing: GainsSpacing.xs) {
              Text(exercise.targetMuscle.uppercased())
                .font(TrackerType.eyebrow)
                .tracking(GainsTracking.eyebrow)
                .foregroundStyle(GainsColor.softInk)
              progressDots(exercise: exercise)
            }
          }
        }
        .contentShape(Rectangle())
        .onTapGesture {
          guard !isActive else { return }
          if collapsedExerciseIDs.contains(exercise.id) {
            collapsedExerciseIDs.remove(exercise.id)
          } else {
            collapsedExerciseIDs.insert(exercise.id)
          }
        }

        Spacer(minLength: 6)

        // Info-Button zeigt die Ausführung als Sheet
        let hasGuide = hasFormGuide(for: exercise)
        Button {
          openFormGuide(for: exercise)
        } label: {
          Image(systemName: hasGuide ? "book.closed.fill" : "questionmark.circle")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(hasGuide ? GainsColor.lime : GainsColor.softInk)
            .frame(width: 32, height: 32)
            .background((hasGuide ? GainsColor.lime : GainsColor.softInk).opacity(0.16))
            .clipShape(Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasGuide ? "Ausführung für \(exercise.name) anzeigen" : "Hinweis zu \(exercise.name) anzeigen")
        .accessibilityValue("In deinem aktiven Training: \(exercise.name), \(completed) von \(total) Sätzen erledigt")
        .accessibilityHint("Öffnet die Hilfe für \(exercise.name) in deinem aktiven Training")

        Text("\(completed)/\(total)")
          .font(TrackerType.metricSmall)
          .foregroundStyle(isAllDone ? GainsColor.moss : GainsColor.ink)
          .accessibilityHidden(true)

        if !isActive {
          Button {
            if collapsedExerciseIDs.contains(exercise.id) {
              collapsedExerciseIDs.remove(exercise.id)
            } else {
              collapsedExerciseIDs.insert(exercise.id)
            }
          } label: {
            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(GainsColor.softInk)
              .accessibilityHidden(true)
              .frame(width: 30, height: 30)
              .background(GainsColor.background.opacity(0.7))
              .clipShape(Circle())
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(isCollapsed ? "\(exercise.name) ausklappen" : "\(exercise.name) einklappen")
          .accessibilityValue("In deinem aktiven Training: \(exercise.name), \(completed) von \(total) Sätzen erledigt")
          .accessibilityHint(isCollapsed ? "Zeigt wieder alle Sätze von \(exercise.name) in deinem aktiven Training" : "Blendet die Satzliste von \(exercise.name) in deinem aktiven Training aus")
        }
      }

      if !isCollapsed {
        let nextExerciseSet = exercise.sets.first(where: { !$0.isCompleted }) ?? exercise.sets.first

        // Letztes Mal Hinweis + "Ausführung"-Hinweis bei aktiver Übung
        HStack(spacing: GainsSpacing.xsPlus) {
          if let nextExerciseSet, !isAllDone {
            HStack(spacing: GainsSpacing.xs) {
              if isActive {
                Text("NÄCHSTER SATZ \(nextExerciseSet.order)")
                  .font(TrackerType.eyebrow)
                  .tracking(GainsTracking.eyebrowTight)
                  .foregroundStyle(GainsColor.lime)
              }

              Text(
                "Ziel: \(formattedWeightInline(nextExerciseSet.weight)) kg × \(nextExerciseSet.reps) Reps"
              )
              .font(GainsFont.caption)
              .foregroundStyle(GainsColor.softInk)
            }
          }

          if isActive, hasFormGuide(for: exercise) {
            Spacer(minLength: 4)
            Button {
              openFormGuide(for: exercise)
            } label: {
              HStack(spacing: GainsSpacing.xs) {
                Image(systemName: "play.rectangle.fill")
                  .font(.system(size: 10, weight: .bold))
                  .accessibilityHidden(true)
                Text("AUSFÜHRUNG")
                  .font(TrackerType.eyebrow)
                  .tracking(GainsTracking.eyebrowTight)
              }
              .foregroundStyle(GainsColor.onLime)
              .padding(.horizontal, GainsSpacing.tight)
              .frame(height: 24)
              .background(GainsColor.lime)
              .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ausführung für \(exercise.name) anzeigen")
            .accessibilityValue("In deinem aktiven Training: \(exercise.name), \(completed) von \(total) Sätzen erledigt")
            .accessibilityHint("Öffnet die Ausführungshilfe für \(exercise.name) in deinem aktiven Training")
          }
        }

        VStack(spacing: GainsSpacing.xs) {
          ForEach(exercise.sets) { set in
            CompactSetRow(
              exerciseID: exercise.id,
              set: set,
              isFocused: set.id == focusSetID,
              isTimerRunning: activeSetID == set.id,
              canDelete: exercise.sets.count > 1,
              onTogglePlay: {
                toggleSetTimer(for: set.id)
              },
              onComplete: {
                completeSet(exerciseID: exercise.id, set: set)
              },
              onDuplicate: {
                focusedField = nil
                if activeSetID == set.id {
                  stopActiveSet()
                }
                if store.duplicateSet(exerciseID: exercise.id, setID: set.id) {
                  UISelectionFeedbackGenerator().selectionChanged()
                }
              },
              onDelete: {
                focusedField = nil
                // Falls der zu löschende Satz gerade aktiv läuft → Timer
                // sauber stoppen, sonst hängt activeSetID auf einer ID,
                // die nicht mehr existiert.
                if activeSetID == set.id { stopActiveSet() }
                // 2026-05-14 Audit-Step 2: Snapshot der Werte VOR Delete,
                // damit Undo den Satz mit korrektem Weight/Reps wieder
                // einfügen kann.
                let snapshotWeight = set.weight
                let snapshotReps = set.reps
                let exerciseID = exercise.id
                store.removeSet(exerciseID: exerciseID, setID: set.id)
                withAnimation(.easeInOut(duration: 0.22)) {
                  pendingUndo = PendingTrackerUndo(
                    message: "Satz gelöscht",
                    perform: {
                      // Vereinfacht: neuen Satz mit den alten Werten hinten anhängen.
                      // Position vor dem Löschen exakt wiederherzustellen ist
                      // hier nicht notwendig — der User kann nach Restore
                      // problemlos per Drag bzw. Set-Order reorder.
                      store.addSet(to: exerciseID)
                      if let restored = store.activeWorkout?
                        .exercises.first(where: { $0.id == exerciseID })?
                        .sets.last
                      {
                        store.updateSet(
                          exerciseID: exerciseID,
                          setID: restored.id,
                          weight: snapshotWeight
                        )
                        store.updateSet(
                          exerciseID: exerciseID,
                          setID: restored.id,
                          reps: snapshotReps
                        )
                      }
                    }
                  )
                }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
              }
            )
          }
        }

        HStack(spacing: GainsSpacing.xsPlus) {
          Button {
            focusedField = nil
            if let activeSetID,
              exercise.sets.contains(where: { $0.id == activeSetID })
            {
              stopActiveSet()
            }
            store.addSet(to: exercise.id)
          } label: {
            chipButton(icon: "plus", title: "Satz")
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Satz zu \(exercise.name) hinzufügen")
          .accessibilityValue("In deinem aktiven Training: \(exercise.name), aktuell \(exercise.sets.count) Sätze, bereit zum Hinzufügen")
          .accessibilityHint("Hinzufügen ist bereit und fügt \(exercise.name) in deinem aktiven Training einen neuen Satz hinzu")

          Button {
            focusedField = nil
            if let lastSet = exercise.sets.last, activeSetID == lastSet.id {
              stopActiveSet()
            }
            store.removeLastSet(from: exercise.id)
          } label: {
            chipButton(icon: "minus", title: "Satz")
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Letzten Satz von \(exercise.name) entfernen")
          .accessibilityValue(exercise.sets.count <= 1 ? "In deinem aktiven Training: \(exercise.name), nicht entfernbar, mindestens ein Satz muss bleiben" : "In deinem aktiven Training: \(exercise.name), aktuell \(exercise.sets.count) Sätze, bereit zum Entfernen")
          .accessibilityHint(exercise.sets.count <= 1 ? "Nicht verfügbar, weil mindestens ein Satz für \(exercise.name) in deinem aktiven Training bestehen bleiben muss" : "Entfernen ist bereit und entfernt den letzten Satz von \(exercise.name) aus deinem aktiven Training")
          .disabled(exercise.sets.count <= 1)
          .opacity(exercise.sets.count <= 1 ? 0.4 : 1)

          // G4-Fix (2026-05-01): „Wdh." legt einen neuen, bereits abge-
          // schlossenen Satz mit Gewicht/Reps des letzten Satzes an und
          // startet den Rest-Timer. Spart 2 Taps gegenüber „+ Satz" →
          // Werte tippen → „Complete".
          Button {
            focusedField = nil
            if let activeSetID,
              exercise.sets.contains(where: { $0.id == activeSetID })
            {
              stopActiveSet()
            }
            if store.repeatLastSet(for: exercise.id) {
              restTimerEndsAt = Calendar.current.date(
                byAdding: .second,
                value: restDuration,
                to: Date()
              )
              UISelectionFeedbackGenerator().selectionChanged()
            }
          } label: {
            chipButton(icon: "arrow.uturn.forward", title: "Wdh.")
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Letzten Satz von \(exercise.name) wiederholen")
          .accessibilityValue(exercise.sets.isEmpty ? "In deinem aktiven Training: \(exercise.name), nicht wiederholbar, noch kein Satz vorhanden" : "In deinem aktiven Training: \(exercise.name), aktuell \(exercise.sets.count) Sätze, bereit zum Wiederholen")
          .accessibilityHint(exercise.sets.isEmpty ? "Nicht verfügbar, weil es für \(exercise.name) in deinem aktiven Training noch keinen Satz zum Wiederholen gibt" : "Wiederholung ist bereit und fügt \(exercise.name) in deinem aktiven Training einen neuen Satz mit den Werten des letzten Satzes hinzu")
          .disabled(exercise.sets.isEmpty)
          .opacity(exercise.sets.isEmpty ? 0.4 : 1)

          Spacer()

          if !isAllDone {
            Button {
              focusedField = nil
              scrollToExerciseID = nil
              skipConfirmExercise = exercise
            } label: {
              HStack(spacing: GainsSpacing.xs) {
                Image(systemName: "forward.fill")
                  .font(.system(size: 10, weight: .bold))
                  .accessibilityHidden(true)
                Text("ÜBERSPRINGEN")
                  .font(TrackerType.eyebrow)
                  .tracking(GainsTracking.eyebrowTight)
              }
              .foregroundStyle(GainsColor.softInk)
              .padding(.horizontal, GainsSpacing.tight)
              .frame(height: 28)
              .overlay(
                Capsule()
                  .stroke(GainsColor.border.opacity(0.55), lineWidth: 1)
              )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(exercise.name) überspringen")
            .accessibilityValue("In deinem aktiven Training: \(exercise.name), \(completed) von \(total) Sätzen erledigt, Übung kann behalten oder übersprungen werden")
            .accessibilityHint("Öffnet die Bestätigung, in der du \(exercise.name) in deinem aktiven Training behalten oder überspringen kannst")
          }
        }
      }
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .background(
      // 2026-05-14 (Polish-Loop 36): Aktive Karte bekommt einen
      // dezenten Lime-Glow oben-leading — passt zum Coach-Brief und
      // Tracker-CommandBar-Vokabular. AllDone-Karte bleibt elevated
      // (ruhig), nicht-aktive Karten bleiben card-flat.
      ZStack {
        if isActive {
          GainsColor.card
          RadialGradient(
            colors: [GainsColor.lime.opacity(0.12), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 220
          )
          .blendMode(.screen)
        } else if isAllDone {
          GainsColor.elevated
        } else {
          GainsColor.card
        }
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(accentBorder, lineWidth: isActive ? 1.4 : 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
    // 2026-05-29 (Polish-Pass): Aktive Karte definiert sich über ihre
    // Lime-Edge + Inner-Light statt über einen breiten Lime-Halo. Nur noch
    // ein dezenter Akzent plus echte Tiefe (Glas-Float); inaktive bleiben flach.
    .shadow(color: isActive ? GainsColor.lime.opacity(0.08) : .clear, radius: 12, x: 0, y: 0)
    .shadow(color: isActive ? GainsColor.shadowCardKey : .clear, radius: 10, x: 0, y: 5)
    .animation(.easeInOut(duration: 0.18), value: isCollapsed)
    // 2026-05-14 Audit-Step 6: VoiceOver-Combined-Label für die Karte.
    .accessibilityElement(children: .contain)
    .accessibilityLabel(cardLabel)
    // Auto-Collapse fertiger Übungen (Optimierungs-Sweep 2026-05-03):
    // Sobald alle Sätze einer Übung erledigt sind, klappt die Karte
    // einmalig automatisch ein. `lastAutoCollapsedID` verhindert, dass
    // wir die Karte erneut einklappen, falls der User sie manuell wieder
    // öffnet (sonst wäre das Verhalten frustrierend).
    .onChange(of: isAllDone) { _, allDone in
      guard allDone, lastAutoCollapsedID != exercise.id else { return }
      withAnimation(.easeInOut(duration: 0.22)) {
        _ = collapsedExerciseIDs.insert(exercise.id)
      }
      lastAutoCollapsedID = exercise.id
    }
  }

  // 2026-05-29 (Polish-Pass): Progress-Dots flach — kein Per-Dot-Glow mehr.
  // Saubere gefüllte Punkte statt LED-Optik.
  private func progressDots(exercise: TrackedExercise) -> some View {
    HStack(spacing: GainsSpacing.xxs) {
      ForEach(exercise.sets) { set in
        Circle()
          .fill(set.isCompleted ? GainsColor.lime : GainsColor.border.opacity(0.55))
          .frame(width: 5, height: 5)
      }
    }
    .accessibilityHidden(true)
  }

  private func chipButton(icon: String, title: String) -> some View {
    // 2026-05-14 (Polish-Loop 34): Chip-Pille jetzt mit Glas-Surface +
    // dezenter Light-Edge — konsistent mit Tab-Bar / Snackbar / Buttons.
    HStack(spacing: GainsSpacing.xs) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .bold))
        .accessibilityHidden(true)
      Text(title.uppercased())
        .font(TrackerType.eyebrow)
        .tracking(GainsTracking.eyebrow)
    }
    .foregroundStyle(GainsColor.ink)
    .accessibilityHidden(true)
    .padding(.horizontal, GainsSpacing.tight)
    .frame(height: 28)
    .background(
      ZStack {
        Capsule().fill(GainsColor.background.opacity(0.85))
        Capsule()
          .fill(
            LinearGradient(
              colors: [GainsColor.glassInnerLight, .clear],
              startPoint: .top,
              endPoint: .center
            )
          )
      }
    )
    .overlay(
      Capsule()
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.border.opacity(0.85), GainsColor.border.opacity(0.35)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
    )
    .clipShape(Capsule())
  }

  private func finishedCard(_ workout: WorkoutSession) -> some View {
    // stats-Single-Pass statt separater filter+completedSets+totalVolume-Calls.
    let s = workout.stats
    let completedExercises = workout.exercises.filter { exercise in
      exercise.sets.allSatisfy(\.isCompleted)
    }.count

    return HStack(alignment: .center, spacing: GainsSpacing.s) {
      // Polish-Loop 179 (2026-05-14): Seal-Icon mit Halo + Inner-Light —
      // wirkt wie geprägtes Siegel auf der „Du bist fertig"-Card.
      ZStack {
        Circle().fill(GainsColor.moss.opacity(0.18))
        Circle()
          .fill(
            RadialGradient(
              colors: [GainsColor.moss.opacity(0.35), .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 28
            )
          )
          .blendMode(.plusLighter)
        Image(systemName: "checkmark.seal.fill")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(GainsColor.moss)
          .shadow(color: GainsColor.moss.opacity(0.55), radius: 4)
      }
      .frame(width: 40, height: 40)
      .accessibilityHidden(true)
      .overlay(
        Circle().strokeBorder(GainsColor.moss.opacity(0.40), lineWidth: GainsBorder.hairline)
      )
      .compositingGroup()
      .shadow(color: GainsColor.moss.opacity(0.28), radius: 6, y: 1)

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text("Alle Sätze erledigt")
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
        Text("Stark – jetzt die Abschlussbestätigung öffnen und dein aktives Training speichern, fortsetzen oder verwerfen.")
          .font(GainsFont.caption)
          .foregroundStyle(GainsColor.softInk)

        LazyVGrid(
          columns: [
            GridItem(.flexible(), spacing: GainsSpacing.s),
            GridItem(.flexible(), spacing: GainsSpacing.s)
          ],
          alignment: .leading,
          spacing: GainsSpacing.xsPlus
        ) {
          finishedMetric(label: "SÄTZE", value: "\(s.completedSets)/\(s.totalSets)")
          finishedMetric(label: "ÜBUNGEN", value: "\(completedExercises)/\(workout.exercises.count)")
          finishedMetric(label: "VOLUMEN", value: "\(Int(s.totalVolume)) kg")
          finishedMetric(label: "DAUER", value: sessionTimeString(start: workout.startedAt, now: Date()))
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
      }
      .accessibilityHidden(true)

      Spacer()
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .background(
      // 2026-05-14 (Polish-Loop 35): finishedCard mit Moss-Akzent-Glow
      // — die Card sagt „du bist fertig", deshalb ein leiser Stolz-Halo
      // statt einer flachen Elevated-Color.
      ZStack {
        GainsColor.elevated
        RadialGradient(
          colors: [GainsColor.moss.opacity(0.20), .clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 220
        )
        .blendMode(.screen)
        LinearGradient(
          colors: [GainsColor.glassInnerLight, .clear],
          startPoint: .top,
          endPoint: .center
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.moss.opacity(0.65), GainsColor.moss.opacity(0.15)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
    .shadow(color: GainsColor.moss.opacity(0.20), radius: 14, x: 0, y: 0)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Alle Sätze erledigt")
    .accessibilityValue("In deinem aktiven Training: \(s.completedSets) von \(s.totalSets) Sätzen, \(completedExercises) von \(workout.exercises.count) Übungen, \(Int(s.totalVolume)) Kilogramm Volumen, \(sessionTimeString(start: workout.startedAt, now: Date())) Dauer. Dein aktives Training ist bereit zum Speichern, Fortsetzen oder Verwerfen")
    .accessibilityHint("Öffnet die Abschlussbestätigung deines aktiven Trainings, in der du es speichern, fortsetzen oder verwerfen kannst")
  }

  private func finishedMetric(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(label)
        .font(TrackerType.eyebrow)
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.label(11))
        .foregroundStyle(GainsColor.ink)
    }
  }

  // MARK: - Bottom CTA

  private func bottomCTA(_ workout: WorkoutSession) -> some View {
    let wStats = workout.stats  // single-pass — verhindert 2× stats-Traversal
    let pending = nextPending(in: workout)
    let active = activeSetContext(in: workout)
    // 2026-05-31 (Stabilität): Leeres Workout zuerst — sonst zeigt die CTA
    // fälschlich „WORKOUT BEENDEN", weil pending dann ebenfalls nil ist.
    let isEmpty = workout.exercises.isEmpty
    let isComplete = !isEmpty && pending == nil
    let isSetActive = activeSetID != nil
    let isActivePendingSet = {
      guard let active, let pending else { return false }
      return active.set.id == pending.set.id
    }()
    let title: String = {
      if isEmpty { return "ERSTE ÜBUNG HINZUFÜGEN" }
      if isComplete { return "ABSCHLUSSBESTÄTIGUNG ÖFFNEN" }
      if isSetActive { return isActivePendingSet ? "SATZ ABSCHLIESSEN" : "SATZ STOPPEN" }
      if let pending {
        let exerciseName = pending.exercise.name.uppercased()
        let order = pending.set.order
        return order == 1 && pending.exercise.sets.allSatisfy({ !$0.isCompleted })
          ? "ERSTEN SATZ IN \(exerciseName) STARTEN"
          : "SATZ \(order) IN \(exerciseName) STARTEN"
      }
      return "STARTE DEN ERSTEN SATZ"
    }()
    let detail: String? = {
      if let active { return setContextDetail(active.set) }
      if let pending { return setContextDetail(pending.set) }
      return nil
    }()
    let icon: String = {
      if isEmpty { return "plus" }
      if isComplete { return "checkmark" }
      if isSetActive { return isActivePendingSet ? "checkmark.circle.fill" : "stop.fill" }
      return "play.fill"
    }()

    return Button {
      focusedField = nil
      if isEmpty {
        scrollToExerciseID = nil
        isShowingExercisePicker = true
        return
      }
      if isComplete {
        focusedField = nil
        scrollToExerciseID = nil
        isFinishing = true
        return
      }
      if isSetActive, let id = activeSetID {
        if let pending, pending.set.id == id {
          completeSet(exerciseID: pending.exercise.id, set: pending.set)
        } else {
          stopActiveSet()
        }
        return
      }
      if let pending {
        toggleSetTimer(for: pending.set.id)
      }
    } label: {
      HStack(spacing: GainsSpacing.s) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(TrackerType.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.lime)
            .lineLimit(2)
            .minimumScaleFactor(0.75)

          if let detail, !isComplete {
            Text(detail)
              .font(GainsFont.label(10))
              .foregroundStyle(GainsColor.lime.opacity(0.72))
              .lineLimit(2)
              .accessibilityHidden(true)
          }
        }
        .accessibilityHidden(true)

        Spacer()

        if !isComplete && !isEmpty {
          Text("\(wStats.completedSets)/\(wStats.totalSets)")
            .font(TrackerType.metricSmall)
            .foregroundStyle(GainsColor.lime.opacity(0.7))
            .accessibilityHidden(true)
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      .frame(height: 60)
      .background(
        // 2026-05-29 (Polish-Pass): BottomCTA bleibt der einzige starke
        // Lime-Anker der View — Glas-Pille mit klarer Lichtkante (ohne
        // plusLighter-Blowout) und ruhigem Bottom-Dim für Tiefe.
        ZStack {
          GainsColor.ctaSurface
          LinearGradient(
            colors: [GainsColor.lime.opacity(0.10), .clear],
            startPoint: .top,
            endPoint: .center
          )
          LinearGradient(
            colors: [.clear, Color.black.opacity(0.20)],
            startPoint: .center,
            endPoint: .bottom
          )
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [GainsColor.lime.opacity(0.70), GainsColor.lime.opacity(0.18)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.accent
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
      .compositingGroup()
      .shadow(color: GainsColor.lime.opacity(0.16), radius: 18, x: 0, y: 0)
      .shadow(color: GainsColor.shadowCardKey, radius: 14, x: 0, y: 8)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
    .accessibilityValue(detail ?? (isComplete ? "Dein aktives Training ist bereit zum Speichern, Fortsetzen oder Verwerfen" : isEmpty ? "Noch keine Übung in deinem aktiven Training, bereit zum Hinzufügen der ersten Übung" : isSetActive ? (isActivePendingSet ? "Aktiver Satz in deinem aktiven Training, bereit zum Abschließen" : "Aktiver Satz in deinem aktiven Training, Timer läuft") : "In deinem aktiven Training sind \(wStats.completedSets) von \(wStats.totalSets) Sätzen und \(wStats.completedExercises) von \(workout.exercises.count) Übungen erledigt"))
    .accessibilityHint(isEmpty ? "Öffnet die Übungsauswahl, um deinem aktiven Training direkt die erste Übung hinzuzufügen" : isComplete ? "Öffnet die Abschlussbestätigung deines aktiven Trainings, in der du es speichern, fortsetzen oder verwerfen kannst" : isSetActive ? (isActivePendingSet ? "Markiert diesen aktiven Satz in deinem aktiven Training als abgeschlossen" : "Stoppt den Timer für diesen aktiven Satz in deinem aktiven Training") : "Startet den nächsten offenen Satz in deinem aktiven Training")
  }

  // MARK: - Logic Helpers

  private func currentExerciseID(in workout: WorkoutSession) -> UUID? {
    if let active = activeSetContext(in: workout) {
      return active.exercise.id
    }
    return nextPending(in: workout)?.exercise.id
  }

  private func activeSetContext(in workout: WorkoutSession) -> (
    exercise: TrackedExercise, set: TrackedSet
  )? {
    guard let activeSetID else { return nil }

    for exercise in workout.exercises {
      if let activeSet = exercise.sets.first(where: { $0.id == activeSetID }) {
        return (exercise, activeSet)
      }
    }

    return nil
  }

  private func nextPending(in workout: WorkoutSession) -> (
    exercise: TrackedExercise, set: TrackedSet
  )? {
    for exercise in workout.exercises {
      if let next = exercise.sets.first(where: { !$0.isCompleted }) {
        return (exercise, next)
      }
    }
    return nil
  }

  private func toggleSetTimer(for setID: UUID) {
    focusedField = nil
    scrollToExerciseID = nil
    if activeSetID == setID {
      stopActiveSet()
    } else {
      restTimerEndsAt = nil
      activeSetID = setID
      activeSetStartedAt = Date()
    }
  }

  private func stopActiveSet() {
    focusedField = nil
    activeSetID = nil
    activeSetStartedAt = nil
  }

  private func completeSet(exerciseID: UUID, set: TrackedSet) {
    focusedField = nil
    scrollToExerciseID = nil
    let wasCompleted = set.isCompleted
    if activeSetID == set.id {
      stopActiveSet()
    }
    store.toggleSet(exerciseID: exerciseID, setID: set.id)
    if !wasCompleted {
      // Bug-Fix: Kein Rest-Timer nach dem allerletzten Satz — es gibt nichts
      // mehr, wofür man sich erholen müsste. nextPending liest den aktuellen
      // Store-Zustand (nach toggleSet), daher ist die Prüfung korrekt.
      if let workout = store.activeWorkout, nextPending(in: workout) != nil {
        restTimerEndsAt = Calendar.current.date(byAdding: .second, value: restDuration, to: Date())
      }
    } else {
      restTimerEndsAt = nil
    }
  }

  private func adjustRest(by delta: Int) {
    focusedField = nil
    guard let end = restTimerEndsAt else { return }
    let newEnd = Calendar.current.date(byAdding: .second, value: delta, to: end) ?? end
    if newEnd <= Date() {
      restTimerEndsAt = nil
    } else {
      restTimerEndsAt = newEnd
    }
  }

  private func performSkipExercise(_ exercise: TrackedExercise) {
    focusedField = nil
    scrollToExerciseID = nil
    // 2026-05-03 Intuitivitäts-Sweep P1-12: Skip darf Volumen/Stats nicht
    // verfälschen — offene Sätze bleiben ungezählt (nicht auf erledigt
    // gesetzt). Wir collapsen die Übung lediglich und stoppen ggf. den
    // aktiven Satz. So stimmt das Tracker-„X / Y"-Verhältnis am Ende mit
    // dem überein, was wirklich gemacht wurde.
    let isSkippingActiveSet = {
      guard let active = activeSetID else { return false }
      return exercise.sets.contains(where: { $0.id == active })
    }()

    if isSkippingActiveSet {
      stopActiveSet()
      restTimerEndsAt = nil
    }
    collapsedExerciseIDs.insert(exercise.id)
    skipConfirmExercise = nil
    UISelectionFeedbackGenerator().selectionChanged()
  }

  // Optimierungs-Sweep 2026-05-03: alle Time-Helper akzeptieren jetzt
  // einen expliziten `now`-Parameter, damit sie aus TimelineView heraus
  // mit context.date gefüttert werden können — kein @State mehr nötig.

  private func remainingRestSeconds(now: Date) -> Int {
    guard let endDate = restTimerEndsAt else { return 0 }
    return max(Int(endDate.timeIntervalSince(now)), 0)
  }

  private func restTimerLabel(now: Date) -> String {
    let seconds = remainingRestSeconds(now: now)
    let minutes = seconds / 60
    let rest = seconds % 60
    return String(format: "%02d:%02d", minutes, rest)
  }

  private func elapsedLabel(since date: Date?, now: Date) -> String {
    guard let date else { return "00:00" }
    let seconds = max(Int(now.timeIntervalSince(date)), 0)
    let minutes = seconds / 60
    let rest = seconds % 60
    return String(format: "%02d:%02d", minutes, rest)
  }

  private func sessionTimeString(start: Date, now: Date) -> String {
    let seconds = max(Int(now.timeIntervalSince(start)), 0)
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
      return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
  }

  private func statusLabel(isRest: Bool, isSet: Bool) -> String {
    if isRest { return "PAUSE" }
    if isSet { return "SATZ AKTIV" }
    return "BEREIT"
  }

  private func liveTimerLabel(isRest: Bool, isSet: Bool, now: Date) -> String {
    if isRest { return restTimerLabel(now: now) }
    if isSet { return elapsedLabel(since: activeSetStartedAt, now: now) }
    return "00:00"
  }

  private func setContextDetail(_ set: TrackedSet) -> String {
    "\(formattedWeightInline(set.weight)) kg × \(set.reps) Wdh."
  }

  private func formattedWeightInline(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
      return "\(Int(value))"
    }
    return String(format: "%.1f", value)
  }

  // MARK: - Form Guide Lookup

  private func libraryItem(for exercise: TrackedExercise) -> ExerciseLibraryItem? {
    let target = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let exact = ExerciseLibraryItem.fullCatalog.first(where: {
      $0.name.localizedCaseInsensitiveCompare(target) == .orderedSame
    }) {
      return exact
    }
    return ExerciseLibraryItem.fullCatalog.first(where: {
      $0.name.localizedCaseInsensitiveContains(target)
        || target.localizedCaseInsensitiveContains($0.name)
    })
  }

  private func hasFormGuide(for exercise: TrackedExercise) -> Bool {
    libraryItem(for: exercise) != nil
  }

  private func openFormGuide(for exercise: TrackedExercise) {
    focusedField = nil
    scrollToExerciseID = nil
    if let item = libraryItem(for: exercise) {
      formGuideExercise = item
    } else {
      // Fallback: synthetisches Item, damit der User wenigstens eine Karte sieht
      formGuideExercise = ExerciseLibraryItem(
        name: exercise.name,
        primaryMuscle: exercise.targetMuscle,
        equipment: "—",
        defaultSets: exercise.sets.count,
        defaultReps: exercise.sets.first?.reps ?? 8,
        suggestedWeight: exercise.sets.first?.weight ?? 0,
        instructions: [
          "Für diese Übung liegt aktuell keine Schritt-für-Schritt-Anleitung vor.",
          "Im nächsten Update zeigen wir hier die Ausführung als Animation."
        ],
        tips: [
          "Konzentriere dich auf saubere Form und kontrolliertes Tempo.",
          "Nutze einen Spiegel oder filme dich kurz, wenn du unsicher bist."
        ]
      )
    }
  }
}

// MARK: - Compact Set Row mit Steppern

private struct CompactSetRow: View {
  @EnvironmentObject private var store: GainsStore

  let exerciseID: UUID
  let set: TrackedSet
  let isFocused: Bool
  let isTimerRunning: Bool
  let canDelete: Bool
  let onTogglePlay: () -> Void
  let onComplete: () -> Void
  let onDuplicate: () -> Void
  let onDelete: () -> Void

  @State private var weightText: String = ""
  @State private var repsText: String = ""
  @FocusState private var focusedField: Field?

  private enum Field: Hashable {
    case weight, reps
  }

  var body: some View {
    let isCompleted = set.isCompleted
    let accent: Color = {
      if isCompleted { return GainsColor.moss.opacity(0.45) }
      if isTimerRunning { return GainsColor.lime }
      if isFocused { return GainsColor.lime.opacity(0.5) }
      return GainsColor.border.opacity(0.4)
    }()

    return HStack(spacing: GainsSpacing.xsPlus) {
      // Set-Index — 2026-05-14 (Polish-Loop 59): Plate-Inner-Light bei
      // completed/focused, kompositioniert.
      Text("\(set.order)")
        .font(TrackerType.metricSmall)
        .foregroundStyle(
          isCompleted ? GainsColor.onLime : (isFocused ? GainsColor.onLime : GainsColor.ink)
        )
        .frame(width: 28, height: 28)
        .background(
          ZStack {
            Circle()
              .fill(
                isCompleted
                  ? GainsColor.lime
                  : (isFocused ? GainsColor.lime.opacity(0.85) : GainsColor.background.opacity(0.85))
              )
            if isCompleted || isFocused {
              Circle()
                .fill(
                  LinearGradient(
                    colors: [Color.white.opacity(0.22), .clear],
                    startPoint: .top,
                    endPoint: .center
                  )
                )
                .blendMode(.plusLighter)
            }
          }
        )
        .clipShape(Circle())
        .compositingGroup()
        .shadow(
          color: (isCompleted || isFocused) ? GainsColor.lime.opacity(0.30) : .clear,
          radius: 6
        )

      // KG mit ±-Steppern
      stepperBlock(
        unit: "KG",
        text: $weightText,
        field: .weight,
        keyboard: .decimalPad,
        commit: commitWeight,
        onMinus: {
          stopRunningSetIfNeeded()
          adjustWeight(by: -2.5)
        },
        onPlus: {
          stopRunningSetIfNeeded()
          adjustWeight(by: 2.5)
        }
      )

      // REPS mit ±-Steppern
      stepperBlock(
        unit: "REPS",
        text: $repsText,
        field: .reps,
        keyboard: .numberPad,
        commit: commitReps,
        onMinus: {
          stopRunningSetIfNeeded()
          adjustReps(by: -1)
        },
        onPlus: {
          stopRunningSetIfNeeded()
          adjustReps(by: 1)
        }
      )

      // Play / Pause
      Button(action: onTogglePlay) {
        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(isTimerRunning ? GainsColor.onLime : GainsColor.lime)
          .frame(width: 36, height: 36)
          .background(isTimerRunning ? GainsColor.lime : GainsColor.ctaSurface)
          .clipShape(Circle())
          .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .opacity(isCompleted ? 0.45 : 1)
      .disabled(isCompleted)
      .accessibilityLabel(isTimerRunning ? "Satz \(set.order) pausieren" : "Satz \(set.order) starten")
      .accessibilityValue(isCompleted ? "Satz \(set.order) in deinem aktiven Training bereits abgeschlossen, Timer nicht verfügbar" : (isTimerRunning ? "Satz \(set.order) in deinem aktiven Training aktiv, Timer läuft" : "Satz \(set.order) in deinem aktiven Training offen, bereit zum Starten"))
      .accessibilityHint(isCompleted ? "Nicht verfügbar, weil Satz \(set.order) in deinem aktiven Training bereits abgeschlossen ist" : (isTimerRunning ? "Pausiert den Timer für Satz \(set.order) in deinem aktiven Training" : "Startet den Timer für Satz \(set.order) in deinem aktiven Training"))

      // Erledigt-Toggle
      Button(action: onComplete) {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(isCompleted ? GainsColor.moss : GainsColor.softInk)
          .frame(width: 36, height: 36)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isCompleted ? "Satz \(set.order) erledigt" : "Satz \(set.order) als erledigt markieren")
      .accessibilityValue(isCompleted ? "Satz \(set.order) in deinem aktiven Training bereits abgeschlossen, nicht erneut markierbar" : "Satz \(set.order) in deinem aktiven Training noch offen, bereit zum Abschließen")
      .accessibilityHint(isCompleted ? "Satz \(set.order) ist in deinem aktiven Training bereits als erledigt markiert" : "Markiert Satz \(set.order) in deinem aktiven Training als erledigt")
    }
    .padding(.horizontal, GainsSpacing.xsPlus)
    .padding(.vertical, GainsSpacing.xsPlus)
    .background {
      // 2026-05-29 (Polish-Pass): Glow-Fokus liegt jetzt allein auf der
      // echt LAUFENDEN Row. Fokussiert-aber-nicht-laufend ist ruhiges Glas
      // mit Lime-Edge (kein Wash, kein Glow) — so leuchtet nicht die halbe
      // Liste mit, wenn man nur scrollt/antippt.
      ZStack {
        if isCompleted {
          GainsColor.lime.opacity(0.12)
        } else if isTimerRunning {
          Rectangle().fill(.ultraThinMaterial)
          LinearGradient(
            colors: [GainsColor.lime.opacity(0.12), .clear],
            startPoint: .top,
            endPoint: .bottom
          )
          RadialGradient(
            colors: [GainsColor.lime.opacity(0.16), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 120
          )
          .blendMode(.screen)
        } else if isFocused {
          Rectangle().fill(.ultraThinMaterial)
        } else {
          GainsColor.background.opacity(0.35)
        }
        LinearGradient(
          colors: [GainsColor.glassInnerLight, .clear],
          startPoint: .top,
          endPoint: .center
        )
      }
    }
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [accent, accent.opacity(0.4)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: isFocused || isTimerRunning ? 1.3 : 1
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
    .shadow(
      color: isTimerRunning ? GainsColor.lime.opacity(0.18) : .clear,
      radius: 10,
      x: 0,
      y: 0
    )
    .onAppear {
      weightText = formattedWeight(set.weight)
      repsText = "\(set.reps)"
    }
    .onChange(of: set.weight) { _, newValue in
      if focusedField != .weight {
        weightText = formattedWeight(newValue)
      }
    }
    .onChange(of: set.reps) { _, newValue in
      if focusedField != .reps {
        repsText = "\(newValue)"
      }
    }
    // Set-Context-Menu (Optimierungs-Sweep 2026-05-03):
    // Long-press auf eine Set-Row → Duplizieren oder Löschen. Swipe
    // funktioniert nicht, weil Sätze in einem VStack sitzen, nicht in
    // einer List. Long-Press ist auch schwerer aus Versehen auszulösen
    // als Swipe.
    .contextMenu {
      Button {
        onDuplicate()
      } label: {
        Label("Satz duplizieren", systemImage: "plus.square.on.square")
      }
      if canDelete {
        Button(role: .destructive) {
          onDelete()
        } label: {
          Label("Satz löschen", systemImage: "trash")
        }
      }
    }
  }

  private func stepperBlock(
    unit: String,
    text: Binding<String>,
    field: Field,
    keyboard: UIKeyboardType,
    commit: @escaping () -> Void,
    onMinus: @escaping () -> Void,
    onPlus: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 0) {
      Button(action: onMinus) {
        Image(systemName: "minus")
          .font(.system(size: 11, weight: .heavy))
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 28, height: 40)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(unit) verringern")
      .accessibilityValue("Aktuell \(text.wrappedValue.isEmpty ? "0" : text.wrappedValue) \(unit)\(focusedField == field ? ", direkte Eingabe aktiv" : "")")
      .accessibilityHint(focusedField == field ? "Direkte Eingabe für \(unit) ist aktiv, verringert den Wert um einen Schritt" : "Verringert den Wert für \(unit) in der direkten Eingabe um einen Schritt")

      VStack(spacing: 1) {
        Text(unit)
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
        TextField("0", text: text)
          .font(TrackerType.metric)
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)
          .keyboardType(keyboard)
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .focused($focusedField, equals: field)
          .submitLabel(.done)
          .accessibilityLabel("\(unit) eingeben")
          .accessibilityValue("Aktuell \(text.wrappedValue.isEmpty ? "0" : text.wrappedValue) \(unit)\(focusedField == field ? ", direkte Eingabe aktiv" : "")")
          .accessibilityHint(focusedField == field ? "Direkte Eingabe für \(unit) ist aktiv, Wert kann direkt bearbeitet werden" : "Öffnet die direkte Eingabe für \(unit)")
          .onSubmit(commit)
          .onChange(of: focusedField) { _, newValue in
            if newValue != field {
              commit()
            }
          }
      }
      .frame(maxWidth: .infinity, minHeight: 40)
      .padding(.vertical, 2)
      .contentShape(Rectangle())
      .onTapGesture {
        focusedField = field
      }

      Button(action: onPlus) {
        Image(systemName: "plus")
          .font(.system(size: 11, weight: .heavy))
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 28, height: 40)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("\(unit) erhöhen")
      .accessibilityValue("Aktuell \(text.wrappedValue.isEmpty ? "0" : text.wrappedValue) \(unit)\(focusedField == field ? ", direkte Eingabe aktiv" : "")")
      .accessibilityHint(focusedField == field ? "Direkte Eingabe für \(unit) ist aktiv, erhöht den Wert um einen Schritt" : "Erhöht den Wert für \(unit) in der direkten Eingabe um einen Schritt")
    }
    .background(
      // 2026-05-29 (Polish-Pass): Stepper-Block ruhig — kein Radial-Glow,
      // kein Focus-Shadow mehr. Die Lime-Edge allein signalisiert das aktive
      // Feld, sonst sauberes Glas.
      GainsColor.card
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(
          focusedField == field ? GainsColor.lime.opacity(0.55) : GainsColor.border.opacity(0.4),
          lineWidth: 1
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
  }

  private func stopRunningSetIfNeeded() {
    if isTimerRunning {
      onTogglePlay()
    }
  }

  private func commitWeight() {
    focusedField = nil
    let normalized = weightText.replacingOccurrences(of: ",", with: ".")
    if let value = Double(normalized) {
      stopRunningSetIfNeeded()
      let rounded = max(0, value)
      store.updateSet(exerciseID: exerciseID, setID: set.id, weight: rounded)
      weightText = formattedWeight(rounded)
    } else {
      weightText = formattedWeight(set.weight)
    }
  }

  private func commitReps() {
    focusedField = nil
    if let value = Int(repsText) {
      stopRunningSetIfNeeded()
      let bounded = max(0, value)
      store.updateSet(exerciseID: exerciseID, setID: set.id, reps: bounded)
      repsText = "\(bounded)"
    } else {
      repsText = "\(set.reps)"
    }
  }

  private func adjustWeight(by delta: Double) {
    focusedField = nil
    let base = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? set.weight
    let next = max(0, base + delta)
    let rounded = (next * 2).rounded() / 2  // 0.5er-Schritte
    store.updateSet(exerciseID: exerciseID, setID: set.id, weight: rounded)
    weightText = formattedWeight(rounded)
  }

  private func adjustReps(by delta: Int) {
    focusedField = nil
    let base = Int(repsText) ?? set.reps
    let next = max(0, base + delta)
    store.updateSet(exerciseID: exerciseID, setID: set.id, reps: next)
    repsText = "\(next)"
  }

  private func formattedWeight(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
      return "\(Int(value))"
    }
    return String(format: "%.1f", value)
  }
}

// MARK: - Undo-Snackbar (Audit-Step 2, 2026-05-14)

/// Snapshot eines destruktiven Vorgangs, der per Snackbar rückgängig
/// gemacht werden kann. Lebt nur während einer Tracker-Session.
struct PendingTrackerUndo: Identifiable, Equatable {
  let id = UUID()
  let message: String
  let perform: () -> Void

  static func == (lhs: PendingTrackerUndo, rhs: PendingTrackerUndo) -> Bool {
    lhs.id == rhs.id
  }
}

/// Snackbar-Komponente für die Tracker-View. Bewusst kompakt:
/// Beschreibung links, „Rückgängig"-Pille rechts. Auto-Dismiss nach 4 s
/// liegt im Aufrufer (`.task(id:)`-Pattern), damit sie deterministisch
/// in den Sheet-Lifecycle eingebettet ist.
struct GainsUndoSnackbar: View {
  let message: String
  let onUndo: () -> Void

  var body: some View {
    HStack(spacing: GainsSpacing.s) {
      Image(systemName: "arrow.uturn.backward.circle.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
      Text(message)
        .font(GainsFont.label(13))
        .foregroundStyle(GainsColor.onCtaSurface)
        .lineLimit(2)
      Spacer(minLength: GainsSpacing.s)
      Button(action: onUndo) {
        Text("RÜCKGÄNGIG")
          .font(TrackerType.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.onLime)
          .padding(.horizontal, GainsSpacing.m)
          .frame(height: 30)
          .background(GainsColor.lime)
          .clipShape(Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Letzte Aktion im aktiven Training rückgängig machen")
      .accessibilityValue("Letzte Aktion in deinem aktiven Training kann rückgängig gemacht werden")
      .accessibilityHint("Stellt den zuletzt entfernten oder verschobenen Schritt in deinem aktiven Training direkt wieder her")
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .background(
      // 2026-05-14 (Polish-Loop 19): Snackbar bekommt jetzt dieselbe
      // zweiseitige Glow-Komposition wie ErrorBanner & Coach-Brief.
      // Die „Rückgängig"-Pille leuchtet konsistent mit dem
      // App-Glow-System, statt isoliert auf einer flachen Surface zu sitzen.
      ZStack {
        GainsColor.glassUndertone
        Rectangle().fill(.ultraThinMaterial)
        GainsColor.ctaSurface.opacity(0.45)
        RadialGradient(
          colors: [GainsColor.lime.opacity(0.18), GainsColor.lime.opacity(0.04), .clear],
          center: .leading,
          startRadius: 0,
          endRadius: 200
        )
        .blendMode(.screen)
        RadialGradient(
          colors: [GainsColor.lime.opacity(0.08), .clear],
          center: .trailing,
          startRadius: 0,
          endRadius: 160
        )
        .blendMode(.screen)
        LinearGradient(
          colors: [GainsColor.glassInnerLight, Color.clear],
          startPoint: .top,
          endPoint: .center
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.12)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .shadow(color: GainsColor.lime.opacity(0.08), radius: 18, x: 0, y: 0)
    .shadow(color: GainsColor.shadowHeroKey, radius: 16, x: 0, y: 8)
  }
}
