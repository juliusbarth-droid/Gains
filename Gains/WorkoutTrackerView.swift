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
  /// Standard-Satzpause: 2:30 Minuten. Wird per Preset-Reihe oder ±15-Chips angepasst.
  @State private var restDuration: Int = 150
  @State private var currentTime = Date()
  @State private var isFinishing = false
  @State private var collapsedExerciseIDs: Set<UUID> = []
  @State private var formGuideExercise: ExerciseLibraryItem?

  private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        GainsAppBackground()

        if let workout = store.activeWorkout {
          ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
              commandBar(workout)
              exercisesList(workout)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 124)
          }

          bottomCTA(workout)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
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
              .frame(width: 36, height: 36)
              .background(GainsColor.card)
              .clipShape(Circle())
              .contentShape(Circle())
          }
          .accessibilityLabel("Schließen")
        }
        ToolbarItem(placement: .principal) {
          Text("KRAFT-TRAINER")
            .font(GainsFont.label(11))
            .tracking(2.2)
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isFinishing = true
          } label: {
            HStack(spacing: 5) {
              Image(systemName: "flag.checkered")
                .font(.system(size: 10, weight: .heavy))
              Text("ENDE")
                .font(GainsFont.label(10))
                .tracking(1.4)
            }
            .foregroundStyle(GainsColor.ember)
            .padding(.horizontal, 12)
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

  // MARK: - Command Bar (Header + Timer + Stats fusioniert)

  private func commandBar(_ workout: WorkoutSession) -> some View {
    let isRest = restTimerEndsAt != nil && remainingRestSeconds > 0
    let isSet = activeSetID != nil
    let accent: Color = isRest ? GainsColor.ember : (isSet ? GainsColor.lime : GainsColor.onCtaSurface.opacity(0.9))

    return VStack(alignment: .leading, spacing: 12) {
      // Zeile 1: LIVE-Chip · Titel · Gesamtdauer
      HStack(alignment: .center, spacing: 10) {
        HStack(spacing: 6) {
          Circle()
            .fill(GainsColor.lime)
            .frame(width: 6, height: 6)
          Text("LIVE")
            .font(GainsFont.label(9))
            .tracking(2)
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.72))
        }
        .layoutPriority(0)

        Text(workout.title)
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.onCtaSurface)
          .lineLimit(1)
          .minimumScaleFactor(0.78)
          .layoutPriority(2)

        Spacer(minLength: 6)

        HStack(spacing: 4) {
          Image(systemName: "clock")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.55))
          Text(sessionTimeString(workout.startedAt))
            .font(GainsFont.title(15))
            .monospacedDigit()
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.92))
        }
        .layoutPriority(1)
      }

      // Zeile 2: Großer Status-Timer + kontextuelle Actions
      timerRow(isRest: isRest, isSet: isSet, accent: accent)

      // Optionaler Pause-Fortschrittsbalken
      if isRest {
        SwiftUI.ProgressView(
          value: Double(remainingRestSeconds),
          total: Double(max(restDuration, 1))
        )
        .tint(GainsColor.ember)
        .frame(height: 4)
      }

      // Trennlinie (Hairline)
      Rectangle()
        .fill(GainsColor.onCtaSurface.opacity(0.08))
        .frame(height: 0.5)
        .padding(.vertical, 2)

      // Zeile 3: Inline-Stats (Sätze · Volumen · HF) als kompakte Pills
      statsRow(workout)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .background(
      LinearGradient(
        colors: [GainsColor.ctaSurface, GainsColor.surfaceDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(accent.opacity(isRest || isSet ? 0.32 : 0.18), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .shadow(color: accent.opacity(isRest || isSet ? 0.16 : 0), radius: 18, x: 0, y: 10)
    .animation(.easeInOut(duration: 0.18), value: isRest)
    .animation(.easeInOut(duration: 0.18), value: isSet)
  }

  private func timerRow(isRest: Bool, isSet: Bool, accent: Color) -> some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(statusLabel(isRest: isRest, isSet: isSet))
          .font(GainsFont.label(9))
          .tracking(2)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
        Text(currentTimerLabel(isRest: isRest, isSet: isSet))
          .font(.system(size: 44, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(accent)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }

      Spacer(minLength: 8)

      contextActions(isRest: isRest, isSet: isSet)
    }
  }

  @ViewBuilder
  private func contextActions(isRest: Bool, isSet: Bool) -> some View {
    if isRest {
      VStack(spacing: 6) {
        HStack(spacing: 6) {
          adjustChip("−15", tone: .neutral) { adjustRest(by: -15) }
          adjustChip("+15", tone: .neutral) { adjustRest(by: 15) }
        }
        adjustChip("ÜBERSPRINGEN", tone: .accent) {
          restTimerEndsAt = nil
        }
      }
    } else if isSet {
      adjustChip("STOP", tone: .accent) {
        stopActiveSet()
      }
    } else if let bpm = healthKit.liveHeartRate {
      HStack(spacing: 4) {
        Image(systemName: "heart.fill")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(GainsColor.ember)
        Text("\(bpm)")
          .font(GainsFont.title(15))
          .monospacedDigit()
          .foregroundStyle(GainsColor.onCtaSurface)
        Text("BPM")
          .font(GainsFont.label(8))
          .tracking(1.6)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.6))
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(GainsColor.ember.opacity(0.18))
      .clipShape(Capsule())
    }
  }

  private enum AdjustTone { case neutral, accent }

  private func adjustChip(_ title: String, tone: AdjustTone, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title)
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(tone == .accent ? GainsColor.lime : GainsColor.onCtaSurface.opacity(0.85))
        .frame(minWidth: 60, minHeight: 32)
        .padding(.horizontal, 12)
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
    HStack(spacing: 10) {
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
          .font(GainsFont.label(9))
          .tracking(0.6)
          .monospacedDigit()
          .foregroundStyle(GainsColor.onCtaSurface)
      }
    }
  }

  private func inlineStat(label: String, value: String, accent: Color) -> some View {
    HStack(spacing: 6) {
      RoundedRectangle(cornerRadius: 1.5, style: .continuous)
        .fill(accent)
        .frame(width: 3, height: 22)
      VStack(alignment: .leading, spacing: 1) {
        Text(label)
          .font(GainsFont.label(8))
          .tracking(1.4)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.55))
        Text(value)
          .font(GainsFont.title(13))
          .monospacedDigit()
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
      finishedCard
    }

    VStack(spacing: 10) {
      ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { index, exercise in
        exerciseCard(
          exercise,
          index: index + 1,
          isActive: exercise.id == currentID,
          focusSetID: exercise.id == currentID ? nextPending(in: workout)?.set.id : nil
        )
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

    return VStack(alignment: .leading, spacing: 12) {
      // Header (kein verschachtelter Button — Tap-Gesture für Collapse)
      HStack(alignment: .center, spacing: 12) {
        // Index-Badge + Titel-Block ist tappable für Collapse
        HStack(alignment: .center, spacing: 12) {
          Text("\(index)")
            .font(GainsFont.title(13))
            .monospacedDigit()
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
            HStack(spacing: 6) {
              Text(exercise.name)
                .font(GainsFont.title(15))
                .foregroundStyle(GainsColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
              if isActive {
                Text("AKTIV")
                  .font(GainsFont.label(8))
                  .tracking(1.4)
                  .foregroundStyle(GainsColor.onLime)
                  .padding(.horizontal, 6)
                  .frame(height: 16)
                  .background(GainsColor.lime)
                  .clipShape(Capsule())
              }
            }
            HStack(spacing: 6) {
              Text(exercise.targetMuscle.uppercased())
                .font(GainsFont.label(9))
                .tracking(1.4)
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
          .font(GainsFont.title(14))
          .monospacedDigit()
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
        // Letztes Mal Hinweis + "Ausführung"-Hinweis bei aktiver Übung
        HStack(spacing: 8) {
          if let firstSet = exercise.sets.first, !isAllDone {
            Text(
              "Ziel: \(formattedWeightInline(firstSet.weight)) kg × \(firstSet.reps) Reps"
            )
            .font(GainsFont.label(10))
            .tracking(0.6)
            .foregroundStyle(GainsColor.softInk)
          }

          if isActive, hasFormGuide(for: exercise) {
            Spacer(minLength: 4)
            Button {
              openFormGuide(for: exercise)
            } label: {
              HStack(spacing: 5) {
                Image(systemName: "play.rectangle.fill")
                  .font(.system(size: 10, weight: .bold))
                Text("AUSFÜHRUNG")
                  .font(GainsFont.label(9))
                  .tracking(1.2)
              }
              .foregroundStyle(GainsColor.onLime)
              .padding(.horizontal, 10)
              .frame(height: 24)
              .background(GainsColor.lime)
              .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }

        VStack(spacing: 6) {
          ForEach(exercise.sets) { set in
            CompactSetRow(
              exerciseID: exercise.id,
              set: set,
              isFocused: set.id == focusSetID,
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

        HStack(spacing: 8) {
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

          Spacer()

          if !isAllDone {
            Button {
              skipExercise(exercise)
            } label: {
              HStack(spacing: 5) {
                Image(systemName: "forward.fill")
                  .font(.system(size: 9, weight: .bold))
                Text("ÜBERSPRINGEN")
                  .font(GainsFont.label(9))
                  .tracking(1.2)
              }
              .foregroundStyle(GainsColor.softInk)
              .padding(.horizontal, 10)
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
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      isActive
        ? GainsColor.card
        : (isAllDone ? GainsColor.elevated : GainsColor.card)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(accentBorder, lineWidth: isActive ? 1.4 : 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .animation(.easeInOut(duration: 0.18), value: isCollapsed)
  }

  private func progressDots(exercise: TrackedExercise) -> some View {
    HStack(spacing: 4) {
      ForEach(exercise.sets) { set in
        Circle()
          .fill(set.isCompleted ? GainsColor.lime : GainsColor.border.opacity(0.55))
          .frame(width: 5, height: 5)
      }
    }
  }

  private func chipButton(icon: String, title: String) -> some View {
    HStack(spacing: 5) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .bold))
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.4)
    }
    .foregroundStyle(GainsColor.ink)
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background(GainsColor.background.opacity(0.85))
    .overlay(
      Capsule()
        .stroke(GainsColor.border.opacity(0.55), lineWidth: 1)
    )
    .clipShape(Capsule())
  }

  private var finishedCard: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(GainsColor.moss)
      VStack(alignment: .leading, spacing: 4) {
        Text("Alle Sätze erledigt")
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        Text("Stark – jetzt Workout abschließen.")
          .font(GainsFont.label(11))
          .tracking(0.6)
          .foregroundStyle(GainsColor.softInk)
      }
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(GainsColor.elevated)
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(GainsColor.moss.opacity(0.45), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
      .frame(height: 60)
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

  // MARK: - Logic Helpers

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

  private func adjustRest(by delta: Int) {
    guard let end = restTimerEndsAt else { return }
    let newEnd = Calendar.current.date(byAdding: .second, value: delta, to: end) ?? end
    if newEnd <= Date() {
      restTimerEndsAt = nil
    } else {
      restTimerEndsAt = newEnd
    }
  }

  private func skipExercise(_ exercise: TrackedExercise) {
    // Markiere alle ausstehenden Sätze als erledigt, um zur nächsten Übung zu springen.
    for set in exercise.sets where !set.isCompleted {
      store.toggleSet(exerciseID: exercise.id, setID: set.id)
    }
    if let active = activeSetID, exercise.sets.contains(where: { $0.id == active }) {
      stopActiveSet()
    }
    restTimerEndsAt = nil
    collapsedExerciseIDs.insert(exercise.id)
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

  private func statusLabel(isRest: Bool, isSet: Bool) -> String {
    if isRest { return "PAUSE" }
    if isSet { return "SATZ AKTIV" }
    return "BEREIT"
  }

  private func currentTimerLabel(isRest: Bool, isSet: Bool) -> String {
    if isRest { return restTimerLabel }
    if isSet { return elapsedLabel(since: activeSetStartedAt) }
    return "00:00"
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
  let onTogglePlay: () -> Void
  let onComplete: () -> Void

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

    return HStack(spacing: 8) {
      // Set-Index
      Text("\(set.order)")
        .font(GainsFont.label(11))
        .tracking(0.4)
        .monospacedDigit()
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
    .padding(.horizontal, 8)
    .padding(.vertical, 8)
    .background(
      isCompleted
        ? GainsColor.lime.opacity(0.14)
        : (isFocused ? GainsColor.background.opacity(0.6) : GainsColor.background.opacity(0.35))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(accent, lineWidth: isFocused || isTimerRunning ? 1.3 : 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
          .font(GainsFont.label(8))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
        TextField("0", text: text)
          .font(GainsFont.title(15))
          .monospacedDigit()
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
