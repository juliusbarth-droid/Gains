import Combine
import SwiftUI
import UIKit

struct WorkoutTrackerView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  @ObservedObject private var healthKit = HealthKitManager.shared

  @State private var activeSetID: UUID?
  @State private var activeSetStartedAt: Date?
  @State private var restTimerEndsAt: Date?
  @State private var restDuration: Int = 90
  @State private var currentTime = Date()
  @State private var isFinishing = false

  private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
  private let restPresets: [Int] = [60, 90, 120, 180]

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        GainsAppBackground()

        if let workout = store.activeWorkout {
          ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
              header(workout)
              integratedTimerCard
              allExercisesSection(workout)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 130)
          }

          bottomCTA(workout)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        } else {
          VStack(spacing: 12) {
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
      .onReceive(ticker) { now in
        currentTime = now
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
              .frame(width: 30, height: 30)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
        }
        ToolbarItem(placement: .principal) {
          Text("STRENGTH TRAINER")
            .font(GainsFont.label(11))
            .tracking(2.2)
            .foregroundStyle(GainsColor.ink)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isFinishing = true
          } label: {
            Text("BEENDEN")
              .font(GainsFont.label(10))
              .tracking(1.6)
              .foregroundStyle(GainsColor.ember)
          }
          .disabled(store.activeWorkout == nil)
        }
      }
      .toolbar {
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
      .alert("Workout beenden?", isPresented: $isFinishing) {
        Button("Verwerfen", role: .destructive) {
          store.discardWorkout()
          dismiss()
        }
        Button("Speichern") {
          store.finishWorkout()
          dismiss()
        }
        Button("Weiter trainieren", role: .cancel) {}
      } message: {
        Text("Speicher deinen Fortschritt oder verwirf das aktuelle Workout.")
      }
    }
  }

  // MARK: - Header

  private func header(_ workout: WorkoutSession) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            Circle()
              .fill(GainsColor.lime)
              .frame(width: 6, height: 6)
            Text("LIVE TRAINING")
              .font(GainsFont.label(10))
              .tracking(2.2)
              .foregroundStyle(GainsColor.card.opacity(0.78))
          }

          Text(workout.title)
            .font(GainsFont.display(30))
            .foregroundStyle(GainsColor.card)
            .lineLimit(2)
            .minimumScaleFactor(0.78)

          Text(headerMotivation(for: workout))
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.card.opacity(0.72))
            .lineLimit(2)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 6) {
          Text("DAUER")
            .font(GainsFont.label(9))
            .tracking(1.8)
            .foregroundStyle(GainsColor.card.opacity(0.66))
          Text(sessionTimeString(workout.startedAt))
            .font(GainsFont.display(24))
            .foregroundStyle(GainsColor.card)
            .monospacedDigit()
        }
      }

      progressBar(workout)

      HStack(spacing: 10) {
        statChip(
          label: "SÄTZE", value: "\(workout.completedSets)/\(workout.totalSets)",
          accent: GainsColor.lime,
          isDark: true
        )
        statChip(
          label: "VOLUMEN", value: "\(Int(workout.totalVolume)) kg",
          accent: GainsColor.card,
          isDark: true
        )
        statChip(
          label: "HF",
          value: healthKit.liveHeartRate.map { "\($0)" } ?? "--",
          accent: GainsColor.ember,
          isDark: true
        )
      }
    }
    .padding(20)
    .background(
      LinearGradient(
        colors: [GainsColor.ctaSurface, GainsColor.surfaceDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.2), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  private func progressBar(_ workout: WorkoutSession) -> some View {
    GeometryReader { proxy in
      let progress: CGFloat =
        workout.totalSets == 0 ? 0 : CGFloat(workout.completedSets) / CGFloat(workout.totalSets)
      ZStack(alignment: .leading) {
        Capsule()
          .fill(GainsColor.card.opacity(0.14))
          .frame(height: 7)
        Capsule()
          .fill(GainsColor.lime)
          .frame(width: max(proxy.size.width * progress, progress > 0 ? 10 : 0), height: 7)
      }
    }
    .frame(height: 7)
  }

  private func statChip(label: String, value: String, accent: Color = GainsColor.lime, isDark: Bool = false) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(GainsFont.label(9))
        .tracking(1.6)
        .foregroundStyle(isDark ? GainsColor.card.opacity(0.62) : GainsColor.softInk)

      Text(value)
        .font(GainsFont.title(16))
        .foregroundStyle(isDark ? GainsColor.card : GainsColor.ink)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Capsule()
        .fill(accent.opacity(isDark ? 0.95 : 0.8))
        .frame(width: 28, height: 4)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .background(isDark ? GainsColor.card.opacity(0.08) : GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke((isDark ? GainsColor.card : GainsColor.border).opacity(0.16), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - Unified session body

  /// Zeigt Timer+Pause in einer integrierten Karte (kein Tab-Switch nötig).
  @ViewBuilder
  private func allExercisesSection(_ workout: WorkoutSession) -> some View {
    let currentID = currentExerciseID(in: workout)

    if nextPending(in: workout) == nil {
      finishedCard
    }

    VStack(spacing: 14) {
      ForEach(workout.exercises) { exercise in
        if let pending = nextPending(in: workout), exercise.id == currentID {
          activeExerciseCard(pending.exercise, focusSet: pending.set)
        } else {
          exerciseDetailCard(exercise)
        }
      }
    }
  }

  /// Timer + Pause-Presets in einer einzigen integrierten Karte.
  private var integratedTimerCard: some View {
    let isRest = (restTimerEndsAt != nil) && remainingRestSeconds > 0
    let isSet = activeSetID != nil
    let mainLabel: String = {
      if isRest { return "PAUSE" }
      if isSet { return "SATZ AKTIV" }
      return "BEREIT"
    }()
    let mainTime: String = {
      if isRest { return restTimerLabel }
      if isSet { return elapsedLabel(since: activeSetStartedAt) }
      return "00:00"
    }()
    let accent: Color = isRest ? GainsColor.ember : (isSet ? GainsColor.lime : GainsColor.softInk)

    return VStack(alignment: .leading, spacing: 18) {

      // ── Status-Zeile ──────────────────────────────────────────────
      HStack(spacing: 10) {
        Circle()
          .fill(accent)
          .frame(width: 8, height: 8)
        Text(mainLabel)
          .font(GainsFont.label(10))
          .tracking(2)
          .foregroundStyle(GainsColor.card.opacity(0.7))
        Spacer()
        if let bpm = healthKit.liveHeartRate {
          HStack(spacing: 4) {
            Image(systemName: "heart.fill")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(GainsColor.ember)
            Text("\(bpm) bpm")
              .font(GainsFont.label(10))
              .tracking(1.2)
              .foregroundStyle(GainsColor.card.opacity(0.85))
          }
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(GainsColor.ember.opacity(0.15))
          .clipShape(Capsule())
        }
        if isRest {
          Button { restTimerEndsAt = nil } label: {
            Text("ÜBERSPRINGEN")
              .font(GainsFont.label(10))
              .tracking(1.6)
              .foregroundStyle(GainsColor.lime)
              .padding(.horizontal, 10)
              .frame(height: 28)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        } else if isSet {
          Button { stopActiveSet() } label: {
            Text("STOP")
              .font(GainsFont.label(10))
              .tracking(1.6)
              .foregroundStyle(GainsColor.lime)
              .padding(.horizontal, 12)
              .frame(height: 28)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }

      // ── Haupt-Timer ───────────────────────────────────────────────
      Text(mainTime)
        .font(.system(size: 64, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(GainsColor.card)
        .frame(maxWidth: .infinity, alignment: .leading)

      // Fortschrittsbalken (Pause) oder Hinweis-Text
      if isRest {
        SwiftUI.ProgressView(value: Double(remainingRestSeconds), total: Double(max(restDuration, 1)))
          .tint(GainsColor.ember)
      } else {
        Text(
          isSet
            ? "Saubere Reps. Stop sobald fertig."
            : "Play-Button am Satz antippen zum Starten."
        )
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.card.opacity(0.7))
      }

      // ── Trennlinie ────────────────────────────────────────────────
      Rectangle()   
        .fill(GainsColor.card.opacity(0.12))
        .frame(height: 1)

      // ── Pause-Presets ─────────────────────────────────────────────
      HStack(spacing: 0) {
        Text("PAUSE")
          .font(GainsFont.label(9))
          .tracking(1.8)
          .foregroundStyle(GainsColor.card.opacity(0.5))

        Spacer()

        HStack(spacing: 6) {
          ForEach(restPresets, id: \.self) { seconds in
            Button {
              restDuration = seconds
              if restTimerEndsAt != nil {
                restTimerEndsAt = Calendar.current.date(
                  byAdding: .second, value: seconds, to: Date())
              }
            } label: {
              Text(formattedRestPreset(seconds))
                .font(GainsFont.label(11))
                .tracking(1.2)
                .foregroundStyle(restDuration == seconds ? GainsColor.onLime : GainsColor.card.opacity(0.8))
                .frame(minWidth: 44, minHeight: 30)
                .background(restDuration == seconds ? GainsColor.lime : GainsColor.card.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .padding(20)
    .background(
      LinearGradient(
        colors: [GainsColor.ctaSurface, GainsColor.surfaceDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .stroke(accent.opacity(0.34), lineWidth: 1.1)
    )
    .shadow(color: accent.opacity(0.1), radius: 16, x: 0, y: 10)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private func headerMotivation(for workout: WorkoutSession) -> String {
    let remainingSets = max(workout.totalSets - workout.completedSets, 0)

    if remainingSets == 0 {
      return "Stark, alle Sätze sind erledigt. Jetzt nur noch sauber abschließen."
    }

    if remainingSets == 1 {
      return "Nur noch ein Satz. Zieh ihn sauber durch und mach den Eintrag fertig."
    }

    return "Noch \(remainingSets) Sätze offen. Fokus auf saubere Reps und konstantes Tempo."
  }

  private func trackerMetaPill(title: String, accent: Color, usesDarkText: Bool = true) -> some View {
    Text(title)
      .font(GainsFont.label(10))
      .tracking(1.2)
      .foregroundStyle(usesDarkText ? GainsColor.onLime : GainsColor.card.opacity(0.8))
      .padding(.horizontal, 10)
      .frame(height: 28)
      .background(usesDarkText ? accent : GainsColor.card.opacity(0.12))
      .clipShape(Capsule())
  }


  private func formattedRestPreset(_ seconds: Int) -> String {
    let minutes = seconds / 60
    let rest = seconds % 60
    if rest == 0 { return "\(minutes):00" }
    return String(format: "%d:%02d", minutes, rest)
  }

  private func activeExerciseCard(_ exercise: TrackedExercise, focusSet: TrackedSet) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("AKTUELLE ÜBUNG")
            .font(GainsFont.label(10))
            .tracking(2)
            .foregroundStyle(GainsColor.softInk)
          Text(exercise.name)
            .font(GainsFont.title(22))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
          Text(exercise.targetMuscle.uppercased())
            .font(GainsFont.label(10))
            .tracking(1.4)
            .foregroundStyle(GainsColor.moss)
        }
        Spacer()
        Text("\(exercise.sets.filter(\.isCompleted).count)/\(exercise.sets.count)")
          .font(GainsFont.title(20))
          .monospacedDigit()
          .foregroundStyle(GainsColor.moss)
      }

      VStack(spacing: 10) {
        ForEach(exercise.sets) { set in
          TrackerSetRow(
            exerciseID: exercise.id,
            set: set,
            isFocused: set.id == focusSet.id,
            isTimerRunning: activeSetID == set.id,
            onTogglePlay: {
              toggleSetTimer(for: set.id)
            },
            onComplete: {
              completeSet(exerciseID: exercise.id, set: set)
            }
          )
        }
      }

      HStack(spacing: 10) {
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
      }
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func chipButton(icon: String, title: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .bold))
      Text(title.uppercased())
        .font(GainsFont.label(10))
        .tracking(1.6)
    }
    .foregroundStyle(GainsColor.ink)
    .padding(.horizontal, 12)
    .frame(height: 32)
    .background(GainsColor.background.opacity(0.85))
    .overlay(
      Capsule()
        .stroke(GainsColor.border.opacity(0.55), lineWidth: 1)
    )
    .clipShape(Capsule())
  }


  private var finishedCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Alle Sätze sind erledigt")
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)
      Text("Stark! Schließe das Workout ab und sicher dir den Eintrag in deiner Historie.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .gainsCardStyle(GainsColor.lime.opacity(0.4))
  }

  private func exerciseDetailCard(_ exercise: TrackedExercise) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(exercise.name)
            .font(GainsFont.title(19))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
          Text(exercise.targetMuscle.uppercased())
            .font(GainsFont.label(10))
            .tracking(1.6)
            .foregroundStyle(GainsColor.softInk)
        }

        Spacer()

        Text("\(exercise.sets.filter(\.isCompleted).count)/\(exercise.sets.count)")
          .font(GainsFont.title(18))
          .monospacedDigit()
          .foregroundStyle(GainsColor.moss)
      }

      VStack(spacing: 10) {
        ForEach(exercise.sets) { set in
          TrackerSetRow(
            exerciseID: exercise.id,
            set: set,
            isFocused: false,
            isTimerRunning: activeSetID == set.id,
            onTogglePlay: { toggleSetTimer(for: set.id) },
            onComplete: { completeSet(exerciseID: exercise.id, set: set) }
          )
        }
      }

      HStack(spacing: 10) {
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
      }
    }
    .padding(18)
    .gainsCardStyle()
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
        let order = pending.set.order
        return order == 1 && pending.exercise.sets.allSatisfy({ !$0.isCompleted })
          ? "STARTE DEN ERSTEN SATZ"
          : "SATZ \(order) STARTEN"
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
        // Stop the timer and mark current focus set complete.
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
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(GainsColor.lime)

        Text(title)
          .font(GainsFont.label(13))
          .tracking(2)
          .foregroundStyle(GainsColor.lime)

        Spacer()

        if !isComplete {
          Text("\(workout.completedSets)/\(workout.totalSets)")
            .font(GainsFont.label(10))
            .tracking(1.4)
            .foregroundStyle(GainsColor.lime.opacity(0.7))
            .monospacedDigit()
        }
      }
      .padding(.horizontal, 22)
      .frame(height: 64)
      .background(GainsColor.ctaSurface)
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(GainsColor.lime.opacity(0.55), lineWidth: 1.4)
      )
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .shadow(color: GainsColor.lime.opacity(0.18), radius: 18, x: 0, y: 10)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Logic helpers

  private func currentExerciseID(in workout: WorkoutSession) -> UUID? {
    nextPending(in: workout)?.exercise.id
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
      restTimerEndsAt = Calendar.current.date(byAdding: .second, value: restDuration, to: Date())
    } else {
      restTimerEndsAt = nil
    }
  }

  private var remainingRestSeconds: Int {
    guard let restTimerEndsAt else { return 0 }
    return max(Int(restTimerEndsAt.timeIntervalSince(currentTime)), 0)
  }

  private var restTimerLabel: String {
    let seconds = remainingRestSeconds
    let minutes = seconds / 60
    let rest = seconds % 60
    return String(format: "%02d:%02d", minutes, rest)
  }

  private func elapsedLabel(since date: Date?) -> String {
    guard let date else { return "00:00" }
    let seconds = max(Int(currentTime.timeIntervalSince(date)), 0)
    let minutes = seconds / 60
    let rest = seconds % 60
    return String(format: "%02d:%02d", minutes, rest)
  }

  private func sessionTimeString(_ start: Date) -> String {
    let seconds = max(Int(currentTime.timeIntervalSince(start)), 0)
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
      return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
  }
}

// MARK: - Set row with manual keyboard input

private struct TrackerSetRow: View {
  @EnvironmentObject private var store: GainsStore

  let exerciseID: UUID
  let set: TrackedSet
  let isFocused: Bool
  let isTimerRunning: Bool
  let onTogglePlay: () -> Void
  let onComplete: () -> Void

  @State private var weightText: String = ""
  @State private var repsText: String = ""
  @FocusState private var focusedField: Field?

  enum Field: Hashable {
    case weight, reps
  }

  var body: some View {
    let accent: Color = {
      if set.isCompleted { return GainsColor.moss }
      if isTimerRunning { return GainsColor.lime }
      if isFocused { return GainsColor.lime.opacity(0.55) }
      return GainsColor.border.opacity(0.45)
    }()

    return HStack(spacing: 12) {
      VStack(spacing: 2) {
        Text("S\(set.order)")
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(set.isCompleted ? GainsColor.onLime : GainsColor.ink)
      }
      .frame(width: 36, height: 36)
      .background(set.isCompleted ? GainsColor.lime : GainsColor.background.opacity(0.85))
      .clipShape(Circle())

      inputField(
        title: "KG",
        text: $weightText,
        field: .weight,
        keyboard: .decimalPad,
        commit: commitWeight
      )

      inputField(
        title: "REPS",
        text: $repsText,
        field: .reps,
        keyboard: .numberPad,
        commit: commitReps
      )

      Button(action: onTogglePlay) {
        Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(isTimerRunning ? GainsColor.onLime : GainsColor.lime)
          .frame(width: 38, height: 38)
          .background(isTimerRunning ? GainsColor.lime : GainsColor.ctaSurface)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)

      Button(action: onComplete) {
        Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(set.isCompleted ? GainsColor.moss : GainsColor.softInk)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 12)
    .background(
      set.isCompleted
        ? GainsColor.lime.opacity(0.18)
        : (isFocused ? GainsColor.background.opacity(0.6) : GainsColor.background.opacity(0.4))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(accent, lineWidth: isFocused || isTimerRunning ? 1.4 : 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
  }

  private func inputField(
    title: String,
    text: Binding<String>,
    field: Field,
    keyboard: UIKeyboardType,
    commit: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(GainsFont.label(9))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      TextField("0", text: text)
        .font(GainsFont.title(20))
        .monospacedDigit()
        .foregroundStyle(GainsColor.ink)
        .keyboardType(keyboard)
        .multilineTextAlignment(.leading)
        .focused($focusedField, equals: field)
        .onSubmit(commit)
        .onChange(of: focusedField) { _, newValue in
          if newValue != field {
            commit()
          }
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(
          focusedField == field ? GainsColor.lime.opacity(0.6) : GainsColor.border.opacity(0.4),
          lineWidth: 1
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

  private func formattedWeight(_ value: Double) -> String {
    if value.truncatingRemainder(dividingBy: 1) == 0 {
      return "\(Int(value))"
    }
    return String(format: "%.1f", value)
  }
}
