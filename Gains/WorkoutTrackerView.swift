import Combine
import SwiftUI

struct WorkoutTrackerView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  @State private var activeTimedSetID: UUID?
  @State private var activeSetStartedAt: Date?
  @State private var restTimerEndsAt: Date?
  @State private var currentTime = Date()
  private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    NavigationStack {
      GainsScreen {
        if let workout = store.activeWorkout {
          VStack(alignment: .leading, spacing: 22) {
            header(workout)
            progressCard(workout)
            nextStepCard(workout)
            exerciseList(workout)
          }
        }
      }
      .onReceive(ticker) { now in
        currentTime = now
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Schließen") {
            dismiss()
          }
          .foregroundStyle(GainsColor.ink)
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button("Beenden") {
            store.finishWorkout()
            dismiss()
          }
          .foregroundStyle(GainsColor.moss)
          .fontWeight(.semibold)
          .disabled(store.activeWorkout == nil)
        }
      }
    }
  }

  private func header(_ workout: WorkoutSession) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      SlashLabel(
        parts: ["TRACKER", "LIVE SESSION"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      Text(workout.title.uppercased())
        .font(GainsFont.title(30))
        .foregroundStyle(GainsColor.ink)

      Text("\(workout.focus) · \(workout.exercises.count) Übungen")
        .font(GainsFont.body())
        .foregroundStyle(GainsColor.softInk)
    }
  }

  private func progressCard(_ workout: WorkoutSession) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        VStack(alignment: .leading, spacing: 6) {
          Text("FORTSCHRITT")
            .font(GainsFont.label(10))
            .tracking(2.4)
            .foregroundStyle(GainsColor.card.opacity(0.72))

          Text("\(workout.completedSets)/\(workout.totalSets) Sätze")
            .font(GainsFont.display(34))
            .foregroundStyle(GainsColor.card)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 6) {
          Text("SESSION")
            .font(GainsFont.label(10))
            .tracking(2.4)
            .foregroundStyle(GainsColor.card.opacity(0.72))

          Text(elapsedLabel(since: workout.startedAt))
            .font(GainsFont.display(28))
            .foregroundStyle(GainsColor.lime)
        }
      }

      HStack(spacing: 10) {
        trackerMetricChip(title: "Volumen", value: "\(Int(workout.totalVolume)) kg")
        trackerMetricChip(title: "Übungen", value: "\(workout.exercises.count)")
        trackerMetricChip(
          title: "Offen", value: "\(max(workout.totalSets - workout.completedSets, 0))")
      }

      if let activeTimedSetID, let startedAt {
        HStack {
          Text("AKTIVER SATZ")
            .font(GainsFont.label(10))
            .tracking(2.2)
            .foregroundStyle(GainsColor.card.opacity(0.72))

          Spacer()

          Text(elapsedLabel(since: startedAt))
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.lime)

          Button("Stoppen") {
            stopSetTimer(for: activeTimedSetID)
          }
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.ink)
          .padding(.horizontal, 12)
          .frame(height: 30)
          .background(GainsColor.card)
          .clipShape(Capsule())
        }
      }

      if restTimerEndsAt != nil, remainingRestSeconds > 0 {
        HStack {
          Text("PAUSE")
            .font(GainsFont.label(10))
            .tracking(2.2)
            .foregroundStyle(GainsColor.card.opacity(0.72))

          Spacer()

          Text(restTimerLabel)
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.lime)

          Button("Überspringen") {
            restTimerEndsAt = nil
          }
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.ink)
          .padding(.horizontal, 12)
          .frame(height: 30)
          .background(GainsColor.card)
          .clipShape(Capsule())
        }
      }

      GeometryReader { proxy in
        let progress =
          workout.totalSets == 0 ? 0 : CGFloat(workout.completedSets) / CGFloat(workout.totalSets)
        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.white.opacity(0.12))
            .frame(height: 5)

          Capsule()
            .fill(GainsColor.lime)
            .frame(width: proxy.size.width * progress, height: 5)
        }
      }
      .frame(height: 5)
    }
    .padding(20)
    .background(GainsColor.ink)
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
  }

  private func trackerMetricChip(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.card.opacity(0.68))

      Text(value)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.card)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.white.opacity(0.06))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func nextStepCard(_ workout: WorkoutSession) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["NÄCHSTER", "SCHRITT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if let nextPending = nextPendingSet(in: workout) {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 6) {
            Text(nextPending.exercise.name)
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)

            Text(
              "Satz \(nextPending.set.order) · \(Int(nextPending.set.weight.rounded())) kg · \(nextPending.set.reps) Reps"
            )
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
          }

          Spacer()

          Button {
            toggleSetTimer(for: nextPending.set.id)
          } label: {
            Text(activeTimedSetID == nextPending.set.id ? "Läuft" : "Satz starten")
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(
                activeTimedSetID == nextPending.set.id ? GainsColor.moss : GainsColor.ink
              )
              .padding(.horizontal, 12)
              .frame(height: 36)
              .background(
                activeTimedSetID == nextPending.set.id
                  ? GainsColor.lime.opacity(0.22) : GainsColor.lime
              )
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      } else {
        Text("Alle Sätze sind erledigt. Du kannst das Workout jetzt abschließen.")
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func exerciseList(_ workout: WorkoutSession) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      ForEach(workout.exercises) { exercise in
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(exercise.name)
                .font(GainsFont.title(21))
                .foregroundStyle(GainsColor.ink)

              Text(exercise.targetMuscle.uppercased())
                .font(GainsFont.label(10))
                .tracking(2.2)
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()

            Text("\(exercise.sets.filter(\.isCompleted).count)/\(exercise.sets.count)")
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.moss)
          }

          exerciseStatusRow(exercise)

          ForEach(exercise.sets) { set in
            WorkoutSetRow(
              exerciseID: exercise.id,
              set: set,
              isTimerRunning: activeTimedSetID == set.id,
              timerLabel: activeTimedSetID == set.id
                ? elapsedLabel(since: activeSetStartedAt) : "Timer starten",
              onTimerTap: { toggleSetTimer(for: set.id) },
              onCompletionTap: {
                if activeTimedSetID == set.id {
                  stopSetTimer(for: set.id)
                }
                let wasCompleted = set.isCompleted
                store.toggleSet(exerciseID: exercise.id, setID: set.id)
                handleSetCompletionChange(becameCompleted: !wasCompleted)
              }
            )
          }
        }
        .padding(18)
        .gainsCardStyle()
      }

      Button {
        store.finishWorkout()
        dismiss()
      } label: {
        Text("Workout abschließen")
          .font(GainsFont.label(12))
          .tracking(1.5)
          .foregroundStyle(GainsColor.lime)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .background(GainsColor.ink)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)
      .padding(.top, 4)
    }
  }

  private var startedAt: Date? {
    activeSetStartedAt
  }

  private func toggleSetTimer(for setID: UUID) {
    if activeTimedSetID == setID {
      stopSetTimer(for: setID)
    } else {
      restTimerEndsAt = nil
      activeTimedSetID = setID
      activeSetStartedAt = Date()
    }
  }

  private func stopSetTimer(for setID: UUID) {
    guard activeTimedSetID == setID else { return }
    activeTimedSetID = nil
    activeSetStartedAt = nil
  }

  private func handleSetCompletionChange(becameCompleted: Bool) {
    guard becameCompleted else {
      restTimerEndsAt = nil
      return
    }
    restTimerEndsAt = Calendar.current.date(byAdding: .second, value: 90, to: Date())
  }

  private func exerciseStatusRow(_ exercise: TrackedExercise) -> some View {
    let nextOpenSet = exercise.sets.first(where: { !$0.isCompleted })
    let lastCompletedSet = exercise.sets.filter(\.isCompleted).last

    return HStack(spacing: 10) {
      if let nextOpenSet {
        trackerPill(title: "Nächster Satz", value: "S\(nextOpenSet.order)")
      }

      if let lastCompletedSet {
        trackerPill(
          title: "Zuletzt",
          value: "\(Int(lastCompletedSet.weight.rounded())) kg × \(lastCompletedSet.reps)")
      }

      if nextOpenSet == nil {
        trackerPill(title: "Status", value: "Fertig")
      }
    }
  }

  private func trackerPill(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.ink)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(GainsColor.background.opacity(0.8))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func nextPendingSet(in workout: WorkoutSession) -> (
    exercise: TrackedExercise, set: TrackedSet
  )? {
    for exercise in workout.exercises {
      if let nextSet = exercise.sets.first(where: { !$0.isCompleted }) {
        return (exercise, nextSet)
      }
    }
    return nil
  }

  private var remainingRestSeconds: Int {
    guard let restTimerEndsAt else { return 0 }
    return max(Int(restTimerEndsAt.timeIntervalSince(currentTime)), 0)
  }

  private var restTimerLabel: String {
    let seconds = remainingRestSeconds
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
  }

  private func elapsedLabel(since date: Date?) -> String {
    guard let date else { return "00:00" }
    let seconds = max(Int(currentTime.timeIntervalSince(date)), 0)
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%02d:%02d", minutes, remainingSeconds)
  }
}

private struct WorkoutSetRow: View {
  @EnvironmentObject private var store: GainsStore

  let exerciseID: UUID
  let set: TrackedSet
  let isTimerRunning: Bool
  let timerLabel: String
  let onTimerTap: () -> Void
  let onCompletionTap: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Text("S\(set.order)")
          .font(GainsFont.label(10))
          .tracking(2)
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 24)

        stepperField(
          title: "KG", value: displayWeight, onMinus: decreaseWeight, onPlus: increaseWeight)
        stepperField(
          title: "REPS", value: "\(set.reps)", onMinus: decreaseReps, onPlus: increaseReps)

        Button(action: onCompletionTap) {
          Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(set.isCompleted ? GainsColor.moss : GainsColor.border)
        }
        .buttonStyle(.plain)
      }

      Button(action: onTimerTap) {
        HStack {
          Label(timerLabel, systemImage: isTimerRunning ? "stopwatch.fill" : "stopwatch")
            .font(GainsFont.label(10))
            .tracking(1.2)
            .foregroundStyle(isTimerRunning ? GainsColor.moss : GainsColor.ink)

          Spacer()

          Text(isTimerRunning ? "Satz läuft" : "Satz starten")
            .font(GainsFont.label(10))
            .tracking(1.2)
            .foregroundStyle(isTimerRunning ? GainsColor.moss : GainsColor.softInk)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(isTimerRunning ? GainsColor.lime.opacity(0.38) : GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(14)
    .background(set.isCompleted ? GainsColor.lime.opacity(0.4) : GainsColor.background.opacity(0.7))
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private var displayWeight: String {
    if set.weight.truncatingRemainder(dividingBy: 1) == 0 {
      return "\(Int(set.weight))"
    }
    return String(format: "%.1f", set.weight)
  }

  private func stepperField(
    title: String, value: String, onMinus: @escaping () -> Void, onPlus: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: 8) {
        Button(action: onMinus) {
          Image(systemName: "minus")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 28, height: 28)
            .background(GainsColor.card)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)

        Text(value)
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)
          .frame(minWidth: 36)

        Button(action: onPlus) {
          Image(systemName: "plus")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 28, height: 28)
            .background(GainsColor.card)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func decreaseWeight() {
    store.updateSet(exerciseID: exerciseID, setID: set.id, weight: max(0, set.weight - 2.5))
  }

  private func increaseWeight() {
    store.updateSet(exerciseID: exerciseID, setID: set.id, weight: set.weight + 2.5)
  }

  private func decreaseReps() {
    store.updateSet(exerciseID: exerciseID, setID: set.id, reps: max(0, set.reps - 1))
  }

  private func increaseReps() {
    store.updateSet(exerciseID: exerciseID, setID: set.id, reps: set.reps + 1)
  }
}
