import SwiftUI

// MARK: - WeekdayDetailSheet
//
// Sheet, das beim Tippen auf einen Tag im PLAN-Tab erscheint — sowohl von
// den 7 Wochenkarten als auch von den Tagespunkten in der 4-Wochen-Vorschau.
//
// Was es tut:
//   • Zeigt den gewählten Tag mit Datum, Status-Badge und (falls vorhanden)
//     Titel + Fokus + Eckdaten des zugewiesenen Workouts / Laufs.
//   • Bietet einen einzigen klaren Primär-CTA, der zum Kontext passt:
//     "Workout starten" für heute, "Workout zuweisen/wechseln" sonst.
//   • Erlaubt einen schnellen Status-Wechsel (Training · Flex · Ruhe) als
//     Segment-Picker — was vorher in einem versteckten Menu auf den Cards
//     lag, ist jetzt eine sichtbare Option im Detail.
//   • Listet bei Trainingstagen alle gespeicherten Pläne, damit ein Wechsel
//     der Zuweisung in einem Tap erledigt ist.
//
// Warum ein eigener Sheet:
//   Vorher hatte der Wochenkalender nur ein verstecktes Menu — der Tap auf
//   einen Tag hat nichts Sichtbares geliefert, und die 4-Wochen-Vorschau war
//   komplett tot. Mit dem Sheet wird die Kalender-Karte zur eigentlichen
//   Steuerzentrale: tippen → sehen → handeln.

struct WeekdayDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore

  let weekday: Weekday
  /// Konkreter Datums-Bezug (für die 4-Wochen-Vorschau wichtig — dann zeigt
  /// das Sheet z. B. "Mo · 11. MAI" statt nur den aktuellen Wochentag).
  let referenceDate: Date

  /// Wird vom Parent gehalten — wenn das Sheet ein Workout startet, schaltet
  /// es das hier auf `true`; das Sheet schließt sich, GymView öffnet den
  /// Tracker.
  @Binding var isShowingWorkoutTracker: Bool

  // MARK: Body

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 18) {
            headerCard
            statusSwitcher

            // Primär-CTA nur auf "heute" — für andere Tage führt der einzige
            // sinnvolle Pfad sowieso in die Workout-Liste darunter.
            if isToday {
              primaryActionCard
            }

            if !isRestDay {
              workoutAssignmentSection
            }

            if let plan = assignedPlan {
              exerciseSummary(plan)
            }
          }
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 36)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(weekday.title.uppercased())
            .font(GainsFont.label(11))
            .tracking(2.4)
            .foregroundStyle(GainsColor.ink)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Fertig") { dismiss() }
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.lime)
        }
      }
    }
  }

  // MARK: - Header

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        Text(eyebrowLabel)
          .font(GainsFont.label(10))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        statusBadge
      }

      Text(headerTitle)
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)

      Text(headerSubtitle)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(3)

      if let metrics = headerMetrics, !metrics.isEmpty {
        HStack(spacing: 10) {
          ForEach(metrics, id: \.label) { metric in
            metricPill(metric)
          }
        }
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private struct HeaderMetric {
    let label: String
    let value: String
  }

  private func metricPill(_ metric: HeaderMetric) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(metric.label)
        .font(GainsFont.label(9))
        .tracking(1.2)
        .foregroundStyle(GainsColor.softInk)
      Text(metric.value)
        .font(GainsFont.metricSmall)
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 10)
    .padding(.horizontal, 12)
    .background(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .fill(Color.white.opacity(0.04))
    )
  }

  private var eyebrowLabel: String {
    let dateText = Self.dateFormatter.string(from: referenceDate).uppercased()
    let prefix = isToday ? "HEUTE" : "TAG"
    return "\(prefix) · \(weekday.shortLabel) · \(dateText)"
  }

  private var headerTitle: String {
    if let run = runTemplate {
      return run.title
    }
    if let plan = assignedPlan {
      return plan.title
    }
    if isRestDay {
      return "Ruhetag"
    }
    if isFlexDay {
      return "Flexibel"
    }
    if isTrainingDay {
      return "Trainingstag · noch kein Workout"
    }
    return "Frei"
  }

  private var headerSubtitle: String {
    if let run = runTemplate {
      let pace = run.targetPaceLabel
      return "\(Int(run.targetDistanceKm)) km · \(run.targetDurationMinutes) Min · \(pace)"
    }
    if let plan = assignedPlan {
      return plan.focus
    }
    if isRestDay {
      return "Bewusst frei. Regeneration ist Trainingsreiz."
    }
    if isFlexDay {
      return "Optionaler Slot. Spontan trainieren oder Erholung."
    }
    if isTrainingDay {
      return "Weise unten ein gespeichertes Workout zu, dann ist der Tag startklar."
    }
    return ""
  }

  private var headerMetrics: [HeaderMetric]? {
    if let run = runTemplate {
      return [
        .init(label: "DISTANZ", value: String(format: "%.1f km", run.targetDistanceKm)),
        .init(label: "DAUER",   value: "\(run.targetDurationMinutes) Min"),
        .init(label: "PACE",    value: run.targetPaceLabel),
      ]
    }
    if let plan = assignedPlan {
      return [
        .init(label: "ÜBUNGEN", value: "\(plan.exercises.count)"),
        .init(label: "DAUER",   value: "\(plan.estimatedDurationMinutes) Min"),
        .init(label: "SPLIT",   value: plan.split),
      ]
    }
    return nil
  }

  @ViewBuilder
  private var statusBadge: some View {
    if isBikeDay {
      GainsHeroStatusBadge(label: "RAD", tone: .plan)
    } else if isRunDay {
      GainsHeroStatusBadge(label: "LAUF", tone: .plan)
    } else if isTrainingDay {
      GainsHeroStatusBadge(label: "TRAINING", tone: .plan)
    } else if isFlexDay {
      GainsHeroStatusBadge(label: "FLEX", tone: .flex)
    } else {
      GainsHeroStatusBadge(label: "REST", tone: .rest)
    }
  }

  // MARK: - Status Switcher
  //
  // Sichtbare Drei-Wege-Wahl statt verstecktem Menu. Aktive Option ist die
  // aktuelle Day-Preference. Tap = sofort übernehmen, kein extra Bestätigen.

  private var statusSwitcher: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("STATUS")
        .font(GainsFont.label(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: 8) {
        statusOptionButton(
          preference: .training,
          icon: isBikeDay ? "bicycle" : (isRunDay ? "figure.run" : "dumbbell.fill"),
          label: isBikeDay ? "Rad" : (isRunDay ? "Lauf" : "Training"),
          tint: isBikeDay ? GainsColor.accentCool : (isRunDay ? GainsColor.moss : GainsColor.lime)
        )
        statusOptionButton(
          preference: .flexible,
          icon: "arrow.triangle.2.circlepath",
          label: "Flex",
          tint: GainsColor.accentCool
        )
        statusOptionButton(
          preference: .rest,
          icon: "moon.zzz.fill",
          label: "Ruhe",
          tint: GainsColor.softInk
        )
      }
    }
  }

  private func statusOptionButton(
    preference: WorkoutDayPreference,
    icon: String,
    label: String,
    tint: Color
  ) -> some View {
    let isActive = currentPreference == preference

    return Button {
      store.setDayPreference(preference, for: weekday)
    } label: {
      VStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(isActive ? GainsColor.onLime : tint)
        Text(label)
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.ink)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(isActive ? tint : Color.white.opacity(0.04))
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(isActive ? tint.opacity(0.6) : GainsColor.border.opacity(0.5), lineWidth: GainsBorder.accent)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Primary Action Card

  private var primaryActionCard: some View {
    Button(action: handlePrimaryAction) {
      HStack(spacing: 12) {
        Image(systemName: primaryActionIcon)
          .font(.system(size: 14, weight: .bold))
        Text(primaryActionTitle)
          .font(GainsFont.label(12))
          .tracking(1.4)
        Spacer(minLength: 0)
        Image(systemName: "arrow.right")
          .font(.system(size: 12, weight: .bold))
      }
      .foregroundStyle(GainsColor.onLime)
      .padding(.horizontal, 16)
      .frame(height: 52)
      .frame(maxWidth: .infinity)
      .background(GainsColor.lime)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // Die Primary-Action-Helpers werden nur aufgerufen, wenn `isToday == true`
  // (Card ist sonst nicht sichtbar). Dadurch bleibt die Logik kompakt.

  private var primaryActionTitle: String {
    if isBikeDay { return "Fahrt starten" }
    if isRunDay { return "Lauf starten" }
    if assignedPlan != nil { return "Workout starten" }
    if isRestDay || isFlexDay { return "Spontan trainieren" }
    return "Workout zuweisen"
  }

  private var primaryActionIcon: String {
    if isCardioDay || assignedPlan != nil { return "play.fill" }
    return "plus.circle.fill"
  }

  private func handlePrimaryAction() {
    if let runTemplate {
      store.startRun(from: runTemplate)
      navigation.openTraining(workspace: .laufen)
      dismiss()
      return
    }
    if let plan = assignedPlan {
      store.startWorkout(from: plan)
      dismiss()
      // Verzögerung minimal, damit das Sheet sauber zuklappt, bevor der
      // Tracker einrückt — sonst springen zwei Sheets übereinander.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        isShowingWorkoutTracker = true
      }
      return
    }
    if isRestDay || isFlexDay {
      if !store.repeatLastWorkout(), let first = store.savedWorkoutPlans.first {
        store.startWorkout(from: first)
      }
      dismiss()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        isShowingWorkoutTracker = true
      }
      return
    }
    // Trainingstag ohne Plan → User muss zuerst unten in der Liste zuweisen.
    // Kein dismiss, kein Tracker-Trigger.
  }

  // MARK: - Workout Assignment

  @ViewBuilder
  private var workoutAssignmentSection: some View {
    if isCardioDay {
      runInfoCard
    } else {
      assignmentList
    }
  }

  private var runInfoCard: some View {
    let tint = isBikeDay ? GainsColor.accentCool : GainsColor.moss
    let title = isBikeDay ? "RAD-TAG · AUTOMATISCH" : "LAUF-TAG · AUTOMATISCH"
    let body = isBikeDay
      ? "Rad-Tage werden aus deinem Plan abgeleitet. Wenn du das ändern willst, passe oben den Status an oder bearbeite den Plan im PLAN-Tab."
      : "Lauftage werden aus deinem Plan abgeleitet. Wenn du das ändern willst, passe oben den Status an oder bearbeite den Plan im PLAN-Tab."
    return VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "info.circle.fill")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(tint)
        Text(title)
          .font(GainsFont.label(9))
          .tracking(1.4)
          .foregroundStyle(tint)
      }
      Text(body)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private var assignmentList: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text("WORKOUT ZUWEISEN")
          .font(GainsFont.label(9))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        if assignedPlan != nil {
          Button {
            store.clearAssignedWorkout(for: weekday)
          } label: {
            Text("Entfernen")
              .font(GainsFont.label(9))
              .tracking(1.0)
              .foregroundStyle(GainsColor.ember)
          }
          .buttonStyle(.plain)
        }
      }

      if store.savedWorkoutPlans.isEmpty {
        emptyPlansHint
      } else {
        VStack(spacing: 8) {
          ForEach(store.savedWorkoutPlans) { plan in
            assignmentRow(plan)
          }
        }
      }
    }
  }

  private var emptyPlansHint: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Noch keine gespeicherten Workouts")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.ink)
      Text("Erstelle zuerst ein Workout im PLÄNE-Tab, dann kannst du es hier zuweisen.")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private func assignmentRow(_ plan: WorkoutPlan) -> some View {
    let isSelected = assignedPlan?.id == plan.id

    return Button {
      store.assignWorkout(plan, to: weekday)
    } label: {
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(isSelected ? GainsColor.lime : Color.white.opacity(0.06))
            .frame(width: 32, height: 32)
          Image(systemName: isSelected ? "checkmark" : "dumbbell.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.softInk)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text(plan.title)
            .font(GainsFont.title(15))
            .foregroundStyle(GainsColor.ink)
          Text("\(plan.focus) · \(plan.estimatedDurationMinutes) Min · \(plan.exercises.count) Übungen")
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(GainsColor.softInk.opacity(0.6))
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(isSelected ? GainsColor.lime.opacity(0.10) : GainsColor.card)
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(
            isSelected ? GainsColor.lime.opacity(0.55) : GainsColor.border.opacity(0.5),
            lineWidth: isSelected ? 1.0 : 0.6
          )
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Exercise Summary

  private func exerciseSummary(_ plan: WorkoutPlan) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("ÜBUNGEN")
        .font(GainsFont.label(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)

      VStack(spacing: 1) {
        ForEach(Array(plan.exercises.prefix(6).enumerated()), id: \.element.id) { index, exercise in
          HStack(spacing: 12) {
            Text(String(format: "%02d", index + 1))
              .font(GainsFont.label(10))
              .tracking(1.0)
              .foregroundStyle(GainsColor.softInk)
              .frame(width: 26, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
              Text(exercise.name)
                .font(GainsFont.body(14))
                .foregroundStyle(GainsColor.ink)
                .lineLimit(1)
              Text("\(exercise.sets.count) Sätze · \(exercise.targetMuscle)")
                .font(GainsFont.body(12))
                .foregroundStyle(GainsColor.softInk)
                .lineLimit(1)
            }
            Spacer()
          }
          .padding(.vertical, 10)
          .padding(.horizontal, 12)
          if index < min(plan.exercises.count, 6) - 1 {
            Divider().background(GainsColor.border.opacity(0.4))
          }
        }
        if plan.exercises.count > 6 {
          Text("+ \(plan.exercises.count - 6) weitere")
            .font(GainsFont.label(10))
            .tracking(1.0)
            .foregroundStyle(GainsColor.softInk)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .gainsCardStyle()
    }
  }

  // MARK: - Derived

  private var currentPreference: WorkoutDayPreference {
    store.dayPreference(for: weekday)
  }

  private var assignedPlan: WorkoutPlan? {
    store.assignedWorkoutPlan(for: weekday)
  }

  private var runTemplate: RunTemplate? {
    store.runTemplate(for: weekday)
  }

  /// 2026-04-29: `isRunDay` ist jetzt streng „echter Lauf-Tag" (Modalität
  /// = run); `isCardioDay` umfasst zusätzlich Rad-Tage. Siehe `cardioModality`
  /// auf `PlannedSessionKind`.
  private var cardioModality: CardioModality? { runTemplate?.modality }
  private var isRunDay: Bool { cardioModality == .run }
  /// 2026-05-03: `CardioModality` wurde auf `.bikeOutdoor` und `.bikeIndoor`
  /// gesplittet. Für die Tagesplan-Logik zählt jeder Rad-Modus als Bike-Tag.
  private var isBikeDay: Bool { cardioModality?.isCycling ?? false }
  private var isCardioDay: Bool { cardioModality != nil }
  private var isRestDay: Bool { currentPreference == .rest }
  private var isFlexDay: Bool { currentPreference == .flexible && !isCardioDay }
  private var isTrainingDay: Bool { currentPreference == .training || isCardioDay }

  private var isToday: Bool {
    Calendar.current.isDateInToday(referenceDate)
  }

  // MARK: - Formatter

  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "d. MMM"
    return f
  }()
}

// MARK: - Selection Wrapper
//
// `.sheet(item:)` braucht ein Identifiable. Datum ist Teil des Selectors,
// weil ein Tap auf "Mo in 3 Wochen" einen anderen Datums-Header verdient als
// ein Tap auf "Mo dieser Woche", obwohl die Day-Preference identisch ist.

struct WeekdaySheetSelection: Identifiable, Equatable {
  let weekday: Weekday
  let referenceDate: Date

  var id: String {
    "\(weekday.rawValue)-\(Int(referenceDate.timeIntervalSince1970))"
  }
}
