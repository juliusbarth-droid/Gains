import SwiftUI

// MARK: - RunWorkoutsTab
//
// "Workouts"-Tab im Lauf-Hub. Zeigt alle strukturierten Lauf-Workouts
// (Builtin + Custom) als Cards. Tap → Detail-Sheet, von dort Workout starten.

struct RunWorkoutsTab: View {
  @EnvironmentObject private var store: GainsStore
  @Binding var presentedWorkout: StructuredRunWorkout?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header

      VStack(spacing: 14) {
        ForEach(store.structuredWorkoutsSorted) { workout in
          Button {
            presentedWorkout = workout
          } label: {
            workoutCard(workout)
          }
          .buttonStyle(.plain)
          .accessibilityHint("Öffnet Workoutdetails mit Ablauf und Pace-Vorgaben")
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      SlashLabel(
        parts: ["STRUKTURIERTE", "WORKOUTS"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )
      Text("Intervalle, Tempo, Fartlek — Schritt-für-Schritt geführt mit Pace-Vorgabe und Audio-Cues.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
  }

  private func workoutCard(_ workout: StructuredRunWorkout) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: workout.systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(GainsColor.moss)
          .frame(width: 42, height: 42)
          .background(GainsColor.lime.opacity(0.22))
          .clipShape(Circle())

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(workout.title)
              .font(GainsFont.title(17))
              .foregroundStyle(GainsColor.ink)
            if !workout.isBuiltin {
              Text("CUSTOM")
                .font(GainsFont.label(8))
                .tracking(1.2)
                .foregroundStyle(GainsColor.lime)
                .padding(.horizontal, 6)
                .frame(height: 16)
                .background(GainsColor.lime.opacity(0.18))
                .clipShape(Capsule())
            }
          }
          Text(workout.summary)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(GainsColor.softInk.opacity(0.4))
      }

      HStack(spacing: 0) {
        workoutStat(label: "DISTANZ", value: distanceLabel(workout), unit: "km")
        Rectangle()
          .fill(GainsColor.border.opacity(0.4))
          .frame(width: 1, height: 28)
        workoutStat(label: "DAUER", value: "\(workout.estimatedDurationMinutes)", unit: "min")
        Rectangle()
          .fill(GainsColor.border.opacity(0.4))
          .frame(width: 1, height: 28)
        workoutStat(label: "STEPS", value: "\(workout.expandedSteps.count)", unit: "")
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  private func workoutStat(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        if !unit.isEmpty {
          Text(unit)
            .font(GainsFont.body(10))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func distanceLabel(_ workout: StructuredRunWorkout) -> String {
    let km = workout.estimatedDistanceKm
    if km <= 0 { return "—" }
    if km >= 10 { return String(format: "%.0f", km) }
    return String(format: "%.1f", km)
  }
}

// MARK: - StructuredWorkoutDetailSheet

struct StructuredWorkoutDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  let workout: StructuredRunWorkout
  let onStart: () -> Void

  @State private var isConfirmingDelete = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          headerBlock
          summaryStats
          stepsSection
        }
        .padding(20)
      }
      .background(GainsColor.background.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        }
        if !workout.isBuiltin {
          ToolbarItem(placement: .topBarTrailing) {
            Button(role: .destructive) {
              isConfirmingDelete = true
            } label: {
              Image(systemName: "trash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GainsColor.ink)
                .frame(width: 32, height: 32)
                .background(GainsColor.card)
                .clipShape(Circle())
            }
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        Button {
          store.startStructuredWorkout(workout)
          onStart()
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "play.fill")
              .font(.system(size: 14, weight: .semibold))
            Text("Workout starten")
              .font(GainsFont.label(13))
              .tracking(1.4)
          }
          .foregroundStyle(GainsColor.onLime)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(GainsColor.lime)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(store.activeRun != nil)
        .opacity(store.activeRun == nil ? 1 : 0.45)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(GainsColor.background)
      }
      .confirmationDialog(
        "Workout löschen?",
        isPresented: $isConfirmingDelete,
        titleVisibility: .visible
      ) {
        Button("Löschen", role: .destructive) {
          store.deleteStructuredWorkout(workout.id)
          dismiss()
        }
        Button("Abbrechen", role: .cancel) {}
      }
    }
  }

  private var headerBlock: some View {
    VStack(alignment: .leading, spacing: 10) {
      Image(systemName: workout.systemImage)
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 60, height: 60)
        .background(GainsColor.lime.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      Text(workout.title)
        .font(GainsFont.title(28))
        .foregroundStyle(GainsColor.ink)

      Text(workout.summary)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
    }
  }

  private var summaryStats: some View {
    HStack(spacing: 0) {
      summaryCell(label: "DISTANZ", value: String(format: "%.1f", workout.estimatedDistanceKm), unit: "km")
      Rectangle().fill(GainsColor.border.opacity(0.4)).frame(width: 1, height: 38)
      summaryCell(label: "DAUER", value: "\(workout.estimatedDurationMinutes)", unit: "min")
      Rectangle().fill(GainsColor.border.opacity(0.4)).frame(width: 1, height: 38)
      summaryCell(label: "STEPS", value: "\(workout.expandedSteps.count)", unit: "")
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 12)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func summaryCell(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        if !unit.isEmpty {
          Text(unit)
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var stepsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["AUFBAU", "SCHRITTE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(spacing: 0) {
        ForEach(Array(workout.steps.enumerated()), id: \.element.id) { idx, step in
          stepRow(index: idx + 1, step: step)
          if idx < workout.steps.count - 1 {
            Divider().background(GainsColor.border.opacity(0.4))
          }
        }
      }
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private func stepRow(index: Int, step: RunWorkoutStep) -> some View {
    HStack(spacing: 12) {
      Image(systemName: step.kind.systemImage)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(stepColor(step.kind))
        .frame(width: 32, height: 32)
        .background(stepColor(step.kind).opacity(0.18))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(step.kind.title)
            .font(GainsFont.title(14))
            .foregroundStyle(GainsColor.ink)
          if step.repeats > 1 {
            Text("\(step.repeats)×")
              .font(GainsFont.label(9))
              .tracking(0.8)
              .foregroundStyle(GainsColor.lime)
          }
        }
        Text(step.target.displayLabel + (step.targetPaceSeconds > 0
          ? " · \(paceLabel(step.targetPaceSeconds)) /km"
          : ""))
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      Text("#\(index)")
        .font(GainsFont.label(9))
        .tracking(0.6)
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(12)
  }

  private func stepColor(_ kind: RunWorkoutStepKind) -> Color {
    switch kind {
    case .warmup:   return GainsColor.zone2
    case .work:     return GainsColor.zone4
    case .recovery: return GainsColor.zone1
    case .cooldown: return GainsColor.accentCool
    case .free:     return GainsColor.lime
    }
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "—" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
