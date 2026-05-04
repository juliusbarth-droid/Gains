import AudioToolbox
import Combine
import SwiftUI
import UIKit

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
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.32)) {
                  proxy.scrollTo(newID, anchor: .top)
                }
              }
            }
          }

          bottomCTA(workout)
            .padding(.horizontal, GainsSpacing.l)
            .padding(.bottom, GainsSpacing.l)
        } else {
          VStack(spacing: GainsSpacing.s) {
            Image(systemName: "figure.strengthtraining.traditional")
              .font(.system(size: 28, weight: .semibold))
              .foregroundStyle(GainsColor.softInk)
            Text("Kein aktives Workout")
              .font(GainsFont.title(20))
              .foregroundStyle(GainsColor.ink)
            Button("Schließen") { dismiss() }
              .font(GainsFont.label(11))
              .foregroundStyle(GainsColor.lime)
          }
        }
      }
      // Pause-Ende-Trigger (Optimierungs-Sweep 2026-05-03):
      // .task(id:) wird neu gestartet, sobald restTimerEndsAt sich ändert
      // (Set abgeschlossen → neuer Endzeitpunkt; ÜBERSPRINGEN → nil).
      // Wir schlafen bis zum exakten Ende und feuern dann Haptik + Sound,
      // bevor der Endzeitpunkt geräuschlos auf nil gesetzt wird. So gibt
      // es genau eine Benachrichtigung pro Pause, kein 1s-Polling nötig.
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
          .accessibilityLabel("Schließen")
        }
        ToolbarItem(placement: .principal) {
          Text("KRAFT-TRAINER")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isFinishing = true
          } label: {
            HStack(spacing: GainsSpacing.xs) {
              Image(systemName: "flag.checkered")
                .font(.system(size: 10, weight: .heavy))
              Text("ENDE")
                .font(GainsFont.eyebrow)
                .tracking(GainsTracking.eyebrowTight)
            }
            .foregroundStyle(GainsColor.ember)
            .padding(.horizontal, GainsSpacing.s)
            .frame(height: 32)
            .background(GainsColor.ember.opacity(0.14))
            .clipShape(Capsule())
            .contentShape(Capsule())
          }
          .disabled(store.activeWorkout == nil)
          .accessibilityLabel("Workout beenden")
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
      // 2026-05-03 Intuitivitäts-Sweep P1-10: Reihenfolge so, dass die
      // gewünschte Aktion (Speichern) als „bequemster" Button greifbar ist
      // und „Verwerfen" als destructive sichtbar getrennt ganz unten landet.
      // iOS bündelt destructive Buttons sowieso unten — wir sortieren sie
      // explizit, damit der Mis-Tap-Abstand zur primären Save-Aktion größer
      // wird.
      .alert("Workout beenden?", isPresented: $isFinishing) {
        Button("Speichern") {
          store.finishWorkout()
          dismiss()
        }
        Button("Weiter trainieren", role: .cancel) {}
        Button("Verwerfen", role: .destructive) {
          store.discardWorkout()
          dismiss()
        }
      } message: {
        Text("Speicher deinen Fortschritt oder verwirf das aktuelle Workout.")
      }
      // Mis-Tap-Schutz für Skip (Optimierungs-Sweep 2026-05-03)
      .confirmationDialog(
        skipConfirmExercise.map { "„\($0.name)" + "\u{201C} überspringen?" } ?? "Übung überspringen?",
        isPresented: Binding(
          get: { skipConfirmExercise != nil },
          set: { if !$0 { skipConfirmExercise = nil } }
        ),
        titleVisibility: .visible,
        presenting: skipConfirmExercise
      ) { exercise in
        Button("Überspringen", role: .destructive) {
          performSkipExercise(exercise)
        }
        Button("Abbrechen", role: .cancel) {}
      } message: { exercise in
        // 2026-05-03 Intuitivitäts-Sweep P1-12: Wording ehrlich machen.
        // Skip ≠ erledigt — die offenen Sätze bleiben ungezählt, damit
        // Volumen/Stats nicht verfälscht werden. Du kannst die Übung später
        // wieder aufklappen und Sätze nachtragen.
        let pending = exercise.sets.filter { !$0.isCompleted }.count
        Text("\(pending) offene Sätze bleiben ungezählt — Volumen und Stats werden nicht verfälscht.")
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
    let accent: Color = isRest ? GainsColor.ember : (isSet ? GainsColor.lime : GainsColor.onCtaSurface.opacity(0.9))

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      // Zeile 1: LIVE-Chip · Titel · Gesamtdauer
      HStack(alignment: .center, spacing: GainsSpacing.tight) {
        HStack(spacing: GainsSpacing.xs) {
          Circle()
            .fill(GainsColor.lime)
            .frame(width: 6, height: 6)
          Text("LIVE")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.72))
        }
        .layoutPriority(0)

        Text(workout.title)
          .font(GainsFont.title)
          .foregroundStyle(GainsColor.onCtaSurface)
          .lineLimit(1)
          .minimumScaleFactor(0.78)
          .layoutPriority(2)

        Spacer(minLength: 6)

        HStack(spacing: GainsSpacing.xxs) {
          Image(systemName: "clock")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.55))
          // Nur dieser kleine Subtree tickt jede Sekunde — nicht der
          // ganze Tracker. ⚡
          TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(sessionTimeString(start: workout.startedAt, now: context.date))
              .font(GainsFont.metricSmall)
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
      LinearGradient(
        colors: [GainsColor.ctaSurface, GainsColor.surfaceDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
        .stroke(accent.opacity(isRest || isSet ? 0.32 : 0.18), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
    .shadow(color: accent.opacity(isRest || isSet ? 0.16 : 0), radius: 18, x: 0, y: 10)
    .animation(.easeInOut(duration: 0.18), value: isRest)
    .animation(.easeInOut(duration: 0.18), value: isSet)
  }

  private func timerRow(workout: WorkoutSession, isRest: Bool, isSet: Bool, accent: Color) -> some View {
    HStack(alignment: .center, spacing: GainsSpacing.s) {
      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text(statusLabel(isRest: isRest, isSet: isSet))
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
        // TimelineView (Optimierungs-Sweep 2026-05-03):
        // Nur dieser Text re-rendert sekündlich. Der Watch-Style-Ring
        // wird als Overlay um den Pause-Countdown gelegt.
        // Bug-Fix: isRest/isSet werden INNERHALB der Closure frisch aus
        // Store/State gelesen, nicht als gecapturer Outer-Value. Verhindert
        // dass Ring und Label bis zu 1s nach Timer-Ablauf noch „eingefroren"
        // als isRest=true weitergerendert werden.
        TimelineView(.periodic(from: .now, by: 1)) { context in
          let liveIsRest = restTimerEndsAt != nil
          let liveIsSet  = activeSetID != nil
          let liveAccent: Color = liveIsRest ? GainsColor.ember
            : (liveIsSet ? GainsColor.lime : GainsColor.onCtaSurface.opacity(0.9))
          let label = liveTimerLabel(isRest: liveIsRest, isSet: liveIsSet, now: context.date)
          ZStack(alignment: .leading) {
            if liveIsRest {
              watchStyleRestRing(now: context.date, accent: liveAccent)
                .frame(width: 64, height: 64)
                .offset(x: -10)
            }
            Text(label)
              .font(.system(size: 50, weight: .semibold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(liveAccent)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
              .padding(.leading, liveIsRest ? 6 : 0)
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
    return ZStack {
      Circle()
        .stroke(accent.opacity(0.18), lineWidth: 4)
      Circle()
        .trim(from: 0, to: max(progress, 0.001))
        .stroke(
          accent,
          style: StrokeStyle(lineWidth: 4, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .shadow(color: accent.opacity(0.45), radius: 6)
        .animation(.linear(duration: 1.0), value: progress)
    }
  }

  @ViewBuilder
  private func contextActions(workout: WorkoutSession, isRest: Bool, isSet: Bool) -> some View {
    if isRest {
      VStack(alignment: .trailing, spacing: GainsSpacing.xs) {
        if let pending = nextPending(in: workout) {
          VStack(alignment: .trailing, spacing: 4) {
            Text("DANACH")
              .font(GainsFont.eyebrow)
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
        }

        HStack(spacing: GainsSpacing.xs) {
          adjustChip("−15", tone: .neutral) { adjustRest(by: -15) }
          adjustChip("+15", tone: .neutral) { adjustRest(by: 15) }
        }
        adjustChip("ÜBERSPRINGEN", tone: .accent) {
          restTimerEndsAt = nil
        }
      }
    } else if isSet {
      VStack(alignment: .trailing, spacing: 4) {
        if let active = activeSetContext(in: workout) {
          Text("AKTUELL")
            .font(GainsFont.eyebrow)
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
        adjustChip("STOP", tone: .accent) {
          stopActiveSet()
        }
      }
    } else if let pending = nextPending(in: workout) {
      VStack(alignment: .trailing, spacing: 4) {
        Text("ALS NÄCHSTES")
          .font(GainsFont.eyebrow)
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
    } else if let bpm = healthKit.liveHeartRate {
      HStack(spacing: GainsSpacing.xxs) {
        Image(systemName: "heart.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(GainsColor.ember)
        Text("\(bpm)")
          .font(GainsFont.metricSmall)
          .foregroundStyle(GainsColor.onCtaSurface)
        Text("BPM")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
      }
      .padding(.horizontal, GainsSpacing.tight)
      .padding(.vertical, GainsSpacing.xs)
      .background(GainsColor.ember.opacity(0.18))
      .clipShape(Capsule())
    } else {
      VStack(alignment: .trailing, spacing: 4) {
        Text("BEREIT FÜR DEN NÄCHSTEN SATZ")
          .font(GainsFont.eyebrow)
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
        .font(GainsFont.eyebrow)
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
    HStack(spacing: GainsSpacing.tight) {
      inlineStat(
        label: "SÄTZE",
        value: "\(workout.completedSets)/\(workout.totalSets)",
        accent: GainsColor.lime
      )
      inlineStat(
        label: "VOLUMEN",
        value: "\(Int(workout.totalVolume)) kg",
        accent: GainsColor.accentCool
      )
      inlineStat(
        label: "Ø HF",
        value: healthKit.liveHeartRate.map { "\($0)" } ?? "--",
        accent: GainsColor.ember
      )

      Spacer(minLength: 0)

      // Mini-Progress: Anteil der erledigten Sätze
      let progress: CGFloat =
        workout.totalSets == 0 ? 0 : CGFloat(workout.completedSets) / CGFloat(workout.totalSets)
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
          .font(GainsFont.eyebrow)
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
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.55))
        Text(value)
          .font(GainsFont.metricSmall)
          .foregroundStyle(GainsColor.onCtaSurface)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
  }

  // MARK: - Übungsliste (kompakte, einheitliche Karten)

  @ViewBuilder
  private func exercisesList(_ workout: WorkoutSession) -> some View {
    let currentID = currentExerciseID(in: workout)

    if nextPending(in: workout) == nil {
      finishedCard(workout)
    }

    VStack(spacing: GainsSpacing.tight) {
      ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
        exerciseCard(
          exercise,
          index: index + 1,
          isActive: exercise.id == currentID,
          focusSetID: exercise.id == currentID ? nextPending(in: workout)?.set.id : nil
        )
        // ID-Marker für ScrollViewReader → ermöglicht
        // proxy.scrollTo(exercise.id, anchor: .top)
        .id(exercise.id)
      }
    }
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

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      // Header (kein verschachtelter Button — Tap-Gesture für Collapse)
      HStack(alignment: .center, spacing: GainsSpacing.s) {
        // Index-Badge + Titel-Block ist tappable für Collapse
        HStack(alignment: .center, spacing: GainsSpacing.s) {
          Text("\(index)")
            .font(GainsFont.metricSmall)
            .foregroundStyle(
              isAllDone ? GainsColor.onLime : (isActive ? GainsColor.onLime : GainsColor.ink)
            )
            .frame(width: 28, height: 28)
            .background(
              isAllDone
                ? GainsColor.moss
                : (isActive ? GainsColor.lime : GainsColor.background.opacity(0.8))
            )
            .clipShape(Circle())

          VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: GainsSpacing.xs) {
              Text(exercise.name)
                .font(GainsFont.headline)
                .foregroundStyle(GainsColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
              if isActive {
                Text("AKTIV")
                  .font(GainsFont.eyebrow)
                  .tracking(GainsTracking.eyebrowTight)
                  .foregroundStyle(GainsColor.onLime)
                  .padding(.horizontal, GainsSpacing.xs)
                  .frame(height: 18)
                  .background(GainsColor.lime)
                  .clipShape(Capsule())
              }
            }
            HStack(spacing: GainsSpacing.xs) {
              Text(exercise.targetMuscle.uppercased())
                .font(GainsFont.eyebrow)
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
        Button {
          openFormGuide(for: exercise)
        } label: {
          Image(systemName: "book.closed.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GainsColor.lime)
            .frame(width: 32, height: 32)
            .background(GainsColor.lime.opacity(0.16))
            .clipShape(Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ausführung anzeigen")

        Text("\(completed)/\(total)")
          .font(GainsFont.metricSmall)
          .foregroundStyle(isAllDone ? GainsColor.moss : GainsColor.ink)

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
              .frame(width: 30, height: 30)
              .background(GainsColor.background.opacity(0.7))
              .clipShape(Circle())
              .contentShape(Circle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(isCollapsed ? "Übung ausklappen" : "Übung einklappen")
        }
      }

      if !isCollapsed {
        let nextExerciseSet = exercise.sets.first(where: { !$0.isCompleted }) ?? exercise.sets.first

        // Letztes Mal Hinweis + "Ausführung"-Hinweis bei aktiver Übung
        HStack(spacing: GainsSpacing.xsPlus) {
          if let nextExerciseSet, !isAllDone {
            Text(
              "Ziel: \(formattedWeightInline(nextExerciseSet.weight)) kg × \(nextExerciseSet.reps) Reps"
            )
            .font(GainsFont.caption)
            .foregroundStyle(GainsColor.softInk)
          }

          if isActive, hasFormGuide(for: exercise) {
            Spacer(minLength: 4)
            Button {
              openFormGuide(for: exercise)
            } label: {
              HStack(spacing: GainsSpacing.xs) {
                Image(systemName: "play.rectangle.fill")
                  .font(.system(size: 10, weight: .bold))
                Text("AUSFÜHRUNG")
                  .font(GainsFont.eyebrow)
                  .tracking(GainsTracking.eyebrowTight)
              }
              .foregroundStyle(GainsColor.onLime)
              .padding(.horizontal, GainsSpacing.tight)
              .frame(height: 24)
              .background(GainsColor.lime)
              .clipShape(Capsule())
            }
            .buttonStyle(.plain)
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
                if store.duplicateSet(exerciseID: exercise.id, setID: set.id) {
                  UISelectionFeedbackGenerator().selectionChanged()
                }
              },
              onDelete: {
                // Falls der zu löschende Satz gerade aktiv läuft → Timer
                // sauber stoppen, sonst hängt activeSetID auf einer ID,
                // die nicht mehr existiert.
                if activeSetID == set.id { stopActiveSet() }
                store.removeSet(exerciseID: exercise.id, setID: set.id)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
              }
            )
          }
        }

        HStack(spacing: GainsSpacing.xsPlus) {
          Button {
            store.addSet(to: exercise.id)
          } label: {
            chipButton(icon: "plus", title: "Satz")
          }
          .buttonStyle(.plain)

          Button {
            store.removeLastSet(from: exercise.id)
          } label: {
            chipButton(icon: "minus", title: "Satz")
          }
          .buttonStyle(.plain)
          .disabled(exercise.sets.count <= 1)
          .opacity(exercise.sets.count <= 1 ? 0.4 : 1)

          // G4-Fix (2026-05-01): „Wdh." legt einen neuen, bereits abge-
          // schlossenen Satz mit Gewicht/Reps des letzten Satzes an und
          // startet den Rest-Timer. Spart 2 Taps gegenüber „+ Satz" →
          // Werte tippen → „Complete".
          Button {
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
          .disabled(exercise.sets.isEmpty)
          .opacity(exercise.sets.isEmpty ? 0.4 : 1)
          .accessibilityLabel("Letzten Satz wiederholen")

          Spacer()

          if !isAllDone {
            Button {
              skipConfirmExercise = exercise
            } label: {
              HStack(spacing: GainsSpacing.xs) {
                Image(systemName: "forward.fill")
                  .font(.system(size: 10, weight: .bold))
                Text("ÜBERSPRINGEN")
                  .font(GainsFont.eyebrow)
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
          }
        }
      }
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .background(
      isActive
        ? GainsColor.card
        : (isAllDone ? GainsColor.elevated : GainsColor.card)
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(accentBorder, lineWidth: isActive ? 1.4 : 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .animation(.easeInOut(duration: 0.18), value: isCollapsed)
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

  private func progressDots(exercise: TrackedExercise) -> some View {
    HStack(spacing: GainsSpacing.xxs) {
      ForEach(exercise.sets) { set in
        Circle()
          .fill(set.isCompleted ? GainsColor.lime : GainsColor.border.opacity(0.55))
          .frame(width: 5, height: 5)
      }
    }
  }

  private func chipButton(icon: String, title: String) -> some View {
    HStack(spacing: GainsSpacing.xs) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .bold))
      Text(title.uppercased())
        .font(GainsFont.eyebrow)
        .tracking(GainsTracking.eyebrow)
    }
    .foregroundStyle(GainsColor.ink)
    .padding(.horizontal, GainsSpacing.tight)
    .frame(height: 28)
    .background(GainsColor.background.opacity(0.85))
    .overlay(
      Capsule()
        .stroke(GainsColor.border.opacity(0.55), lineWidth: 1)
    )
    .clipShape(Capsule())
  }

  private func finishedCard(_ workout: WorkoutSession) -> some View {
    HStack(alignment: .center, spacing: GainsSpacing.s) {
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(GainsColor.moss)

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text("Alle Sätze erledigt")
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
        Text("Stark – jetzt Workout abschließen.")
          .font(GainsFont.caption)
          .foregroundStyle(GainsColor.softInk)

        HStack(spacing: GainsSpacing.s) {
          finishedMetric(label: "SÄTZE", value: "\(workout.completedSets)/\(workout.totalSets)")
          finishedMetric(label: "VOLUMEN", value: "\(Int(workout.totalVolume)) kg")
          finishedMetric(label: "DAUER", value: sessionTimeString(start: workout.startedAt, now: Date()))
        }
        .padding(.top, 2)
      }

      Spacer()
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .background(GainsColor.elevated)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.moss.opacity(0.45), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private func finishedMetric(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(label)
        .font(GainsFont.eyebrow)
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.label(11))
        .foregroundStyle(GainsColor.ink)
    }
  }

  // MARK: - Bottom CTA

  private func bottomCTA(_ workout: WorkoutSession) -> some View {
    let pending = nextPending(in: workout)
    let isComplete = pending == nil
    let isSetActive = activeSetID != nil
    let title: String = {
      if isComplete { return "WORKOUT BEENDEN" }
      if isSetActive { return "SATZ STOPPEN" }
      if let pending {
        let exerciseName = pending.exercise.name.uppercased()
        let order = pending.set.order
        return order == 1 && pending.exercise.sets.allSatisfy({ !$0.isCompleted })
          ? "ERSTEN SATZ IN \(exerciseName) STARTEN"
          : "SATZ \(order) IN \(exerciseName) STARTEN"
      }
      return "STARTE DEN ERSTEN SATZ"
    }()
    let icon = isSetActive ? "stop.fill" : (isComplete ? "checkmark" : "play.fill")

    return Button {
      if isComplete {
        store.finishWorkout()
        dismiss()
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

        Text(title)
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
          .foregroundStyle(GainsColor.lime)

        Spacer()

        if !isComplete {
          Text("\(workout.completedSets)/\(workout.totalSets)")
            .font(GainsFont.metricSmall)
            .foregroundStyle(GainsColor.lime.opacity(0.7))
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      .frame(height: 60)
      .background(GainsColor.ctaSurface)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
          .stroke(GainsColor.lime.opacity(0.55), lineWidth: 1.4)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
      .shadow(color: GainsColor.lime.opacity(0.18), radius: 18, x: 0, y: 10)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Logic Helpers

  private func currentExerciseID(in workout: WorkoutSession) -> UUID? {
    nextPending(in: workout)?.exercise.id
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
    if activeSetID == setID {
      stopActiveSet()
    } else {
      restTimerEndsAt = nil
      activeSetID = setID
      activeSetStartedAt = Date()
    }
  }

  private func stopActiveSet() {
    activeSetID = nil
    activeSetStartedAt = nil
  }

  private func completeSet(exerciseID: UUID, set: TrackedSet) {
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
    guard let end = restTimerEndsAt else { return }
    let newEnd = Calendar.current.date(byAdding: .second, value: delta, to: end) ?? end
    if newEnd <= Date() {
      restTimerEndsAt = nil
    } else {
      restTimerEndsAt = newEnd
    }
  }

  private func performSkipExercise(_ exercise: TrackedExercise) {
    // 2026-05-03 Intuitivitäts-Sweep P1-12: Skip darf Volumen/Stats nicht
    // verfälschen — offene Sätze bleiben ungezählt (nicht auf erledigt
    // gesetzt). Wir collapsen die Übung lediglich und stoppen ggf. den
    // aktiven Satz. So stimmt das Tracker-„X / Y"-Verhältnis am Ende mit
    // dem überein, was wirklich gemacht wurde.
    if let active = activeSetID, exercise.sets.contains(where: { $0.id == active }) {
      stopActiveSet()
    }
    restTimerEndsAt = nil
    collapsedExerciseIDs.insert(exercise.id)
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
      // Set-Index
      Text("\(set.order)")
        .font(GainsFont.metricSmall)
        .foregroundStyle(
          isCompleted ? GainsColor.onLime : (isFocused ? GainsColor.onLime : GainsColor.ink)
        )
        .frame(width: 28, height: 28)
        .background(
          isCompleted
            ? GainsColor.lime
            : (isFocused ? GainsColor.lime.opacity(0.85) : GainsColor.background.opacity(0.85))
        )
        .clipShape(Circle())

      // KG mit ±-Steppern
      stepperBlock(
        unit: "KG",
        text: $weightText,
        field: .weight,
        keyboard: .decimalPad,
        commit: commitWeight,
        onMinus: { adjustWeight(by: -2.5) },
        onPlus: { adjustWeight(by: 2.5) }
      )

      // REPS mit ±-Steppern
      stepperBlock(
        unit: "REPS",
        text: $repsText,
        field: .reps,
        keyboard: .numberPad,
        commit: commitReps,
        onMinus: { adjustReps(by: -1) },
        onPlus: { adjustReps(by: 1) }
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
      .accessibilityLabel(isTimerRunning ? "Satz pausieren" : "Satz starten")

      // Erledigt-Toggle
      Button(action: onComplete) {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(isCompleted ? GainsColor.moss : GainsColor.softInk)
          .frame(width: 36, height: 36)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(isCompleted ? "Satz erledigt" : "Satz als erledigt markieren")
    }
    .padding(.horizontal, GainsSpacing.xsPlus)
    .padding(.vertical, GainsSpacing.xsPlus)
    .background(
      isCompleted
        ? GainsColor.lime.opacity(0.14)
        : (isFocused ? GainsColor.background.opacity(0.6) : GainsColor.background.opacity(0.35))
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(accent, lineWidth: isFocused || isTimerRunning ? 1.3 : 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
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

      VStack(spacing: 1) {
        Text(unit)
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
        TextField("0", text: text)
          .font(GainsFont.metric)
          .foregroundStyle(GainsColor.ink)
          .keyboardType(keyboard)
          .multilineTextAlignment(.center)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .focused($focusedField, equals: field)
          .submitLabel(.done)
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
    }
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 11, style: .continuous)
        .stroke(
          focusedField == field ? GainsColor.lime.opacity(0.55) : GainsColor.border.opacity(0.4),
          lineWidth: 1
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
  }

  private func commitWeight() {
    let normalized = weightText.replacingOccurrences(of: ",", with: ".")
    if let value = Double(normalized) {
      let rounded = max(0, value)
      store.updateSet(exerciseID: exerciseID, setID: set.id, weight: rounded)
      weightText = formattedWeight(rounded)
    } else {
      weightText = formattedWeight(set.weight)
    }
  }

  private func commitReps() {
    if let value = Int(repsText) {
      let bounded = max(0, value)
      store.updateSet(exerciseID: exerciseID, setID: set.id, reps: bounded)
      repsText = "\(bounded)"
    } else {
      repsText = "\(set.reps)"
    }
  }

  private func adjustWeight(by delta: Double) {
    let base = Double(weightText.replacingOccurrences(of: ",", with: ".")) ?? set.weight
    let next = max(0, base + delta)
    let rounded = (next * 2).rounded() / 2  // 0.5er-Schritte
    store.updateSet(exerciseID: exerciseID, setID: set.id, weight: rounded)
    weightText = formattedWeight(rounded)
  }

  private func adjustReps(by delta: Int) {
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
