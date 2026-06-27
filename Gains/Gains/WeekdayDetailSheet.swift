import SwiftUI

// MARK: - WeekdayPostDismissAction
//
// 2026-05-14 (Sheet-Race-Hardening): Typisiertes Signal vom Detail-Sheet an
// den Parent. Statt `dismiss()` + `asyncAfter` schreibt das Sheet hier rein
// und der Parent reagiert im `onDismiss`-Callback seines `.sheet(item:)`.
enum WeekdayPostDismissAction {
  case startWorkoutTracker(String)
  /// 2026-05-15 (P1 #6): RunTracker direkt starten statt Tab-Switch zum
  /// Cardio-Hub. Der Parent öffnet RunTrackerView nach Sheet-Teardown.
  case startRunTracker(String)
}

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
  // 2026-05-15 (Audit-Loop 16): `navigation`-EnvironmentObject war
  // deklariert aber nie verwendet — und in `GymPlanTab` wurde es nicht
  // an die Sheet weitergereicht. Das hätte beim ersten Zugriff auf
  // `navigation.…` zu einem Runtime-Crash geführt. Entfernt, da das
  // Sheet ausschließlich über `pendingPostDismiss` mit der Außenwelt
  // kommuniziert. Wenn künftig Navigation-Calls nötig werden, müssen
  // ALLE Aufrufer (GymPlanTab + WeekPlanFullscreenView) das Env-Object
  // injizieren.

  let weekday: Weekday
  /// Konkreter Datums-Bezug (für die 4-Wochen-Vorschau wichtig — dann zeigt
  /// das Sheet z. B. "Mo · 11. MAI" statt nur den aktuellen Wochentag).
  let referenceDate: Date

  /// 2026-05-14 (Sheet-Race-Hardening): Statt `isShowingWorkoutTracker`
  /// direkt zu setzen + `asyncAfter`, signalisiert dieses Sheet jetzt nur
  /// noch eine deferred Action über ein typisiertes Binding. Der Parent
  /// liest die Action im `onDismiss`-Callback seines `.sheet(item:)` aus
  /// und triggert dann den Tracker — race-frei, da SwiftUI den Sheet-
  /// Dismiss-Lifecycle vollständig durchläuft, bevor onDismiss feuert.
  @Binding var pendingPostDismiss: WeekdayPostDismissAction?

  // MARK: Body

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: GainsSpacing.l) {
            headerCard
            statusSwitcher
            swapDayRow

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
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.s)
          .padding(.bottom, GainsSpacing.xl)
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
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .firstTextBaseline) {
        Text(eyebrowLabel)
          .font(GainsFont.label(10))
          .tracking(GainsTracking.eyebrow)
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
        HStack(spacing: GainsSpacing.tight) {
          ForEach(metrics, id: \.label) { metric in
            metricPill(metric)
          }
        }
      }
    }
    .padding(GainsSpacing.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private struct HeaderMetric {
    let label: String
    let value: String
  }

  private func metricPill(_ metric: HeaderMetric) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
      Text(metric.label)
        .font(GainsFont.label(9))
        .tracking(GainsTracking.eyebrowTight)
        .foregroundStyle(GainsColor.softInk)
      Text(metric.value)
        .font(GainsFont.metricSmall)
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, GainsSpacing.tight)
    .padding(.horizontal, GainsSpacing.s)
    // 2026-05-29 (Loop 10 bonus): white.opacity(0.04) = unsichtbar in
    // Light-Mode. surfaceDeep.opacity(0.6) ergibt eine dezente Pill-
    // Trennung die in beiden Modi sichtbar ist.
    .background(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .fill(GainsColor.surfaceDeep.opacity(0.6))
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
      return "\(String(format: "%.1f km", run.targetDistanceKm)) · \(run.targetDurationMinutes) Min · \(pace)"
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
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text("STATUS")
        .font(GainsFont.label(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: GainsSpacing.xsPlus) {
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

  // MARK: - Swap-Day Row
  //
  // 2026-05-03: Häufiger Use-Case: „Heute kann ich nicht trainieren — geht
  // morgen". Vorher: Status auf Rest setzen, anderen Tag finden, dort Status
  // auf Training setzen, dort Workout zuweisen — vier Schritte. Jetzt: Tag
  // tauschen mit … Workout, Status und manuelles SessionKind wandern in einem
  // Schritt mit (siehe `GainsStore.swapDayAssignments`).
  private var swapDayRow: some View {
    Menu {
      ForEach(Weekday.allCases.filter { $0 != weekday }) { other in
        Button {
          store.swapDayAssignments(weekday, other)
        } label: {
          let pref = store.dayPreference(for: other)
          let assigned = store.assignedWorkoutPlan(for: other)
          let suffix: String = {
            if let assigned { return " · \(assigned.title)" }
            if pref == .rest { return " · Ruhe" }
            if pref == .flexible { return " · Flex" }
            return ""
          }()
          Text("\(other.title)\(suffix)")
        }
      }
    } label: {
      HStack(spacing: GainsSpacing.s) {
        Image(systemName: "arrow.left.arrow.right")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        VStack(alignment: .leading, spacing: 2) {
          Text("TAG TAUSCHEN")
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(GainsColor.softInk)
          Text("Workout, Status und Lauf-Typ wandern mit")
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(GainsColor.softInk.opacity(0.6))
      }
      // Polish-Loop 181 (2026-05-14): Swap-Day-Row mit Glas-Komposition
      // statt flachem `white.opacity(0.04)` — wirkt als Menu-Trigger.
      .padding(GainsSpacing.s)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(Color.white.opacity(0.04))
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
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
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .strokeBorder(GainsColor.border.opacity(0.40), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      .compositingGroup()
    }
  }

  private func statusOptionButton(
    preference: WorkoutDayPreference,
    icon: String,
    label: String,
    tint: Color
  ) -> some View {
    let isActive = currentPreference == preference

    // Polish-Loop 180 (2026-05-14): Status-Option-Button mit plusLighter
    // Inner-Light + Bottom-Dim auf aktiver Pille + Tint-Glow.
    return Button {
      store.setDayPreference(preference, for: weekday)
    } label: {
      VStack(spacing: GainsSpacing.xs) {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(isActive ? GainsColor.onLime : tint)
          .shadow(color: isActive ? Color.white.opacity(0.30) : tint.opacity(0.40), radius: 3)
        Text(label)
          .font(GainsFont.label(10))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.ink)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, GainsSpacing.s)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(isActive ? tint : Color.white.opacity(0.04))
          if isActive {
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [Color.white.opacity(0.22), .clear],
                  startPoint: .top,
                  endPoint: .center
                )
              )
              .blendMode(.plusLighter)
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [.clear, Color.black.opacity(0.14)],
                  startPoint: .center,
                  endPoint: .bottom
                )
              )
          }
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .strokeBorder(
            isActive ? tint.opacity(0.6) : GainsColor.border.opacity(0.45),
            lineWidth: isActive ? GainsBorder.accent : GainsBorder.hairline
          )
      )
      .compositingGroup()
      .shadow(color: isActive ? tint.opacity(0.30) : .clear, radius: 7)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Primary Action Card

  private var primaryActionCard: some View {
    Button(action: handlePrimaryAction) {
      HStack(spacing: GainsSpacing.s) {
        Image(systemName: primaryActionIcon)
          .font(.system(size: 14, weight: .bold))
        Text(primaryActionTitle)
          .font(GainsFont.label(12))
          .tracking(1.4)
        Spacer(minLength: 0)
        Image(systemName: "arrow.right")
          .font(.system(size: 12, weight: .bold))
      }
      .foregroundStyle(GainsColor.ink)
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 52)
      .frame(maxWidth: .infinity)
      .gainsGlassCTA(corner: GainsRadius.small)
    }
    .buttonStyle(.plain)
  }

  // Die Primary-Action-Helpers werden nur aufgerufen, wenn `isToday == true`
  // (Card ist sonst nicht sichtbar). Dadurch bleibt die Logik kompakt.

  private var primaryActionTitle: String {
    if store.activeRun != nil { return "Run öffnen" }
    if store.activeWorkout != nil { return "Workout öffnen" }
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
    if let runTemplate,
       store.activeRun?.title.trimmingCharacters(in: .whitespacesAndNewlines) == runTemplate.title.trimmingCharacters(in: .whitespacesAndNewlines) {
      pendingPostDismiss = .startRunTracker(runTemplate.title)
      dismiss()
      return
    }
    if let activeTitle = store.activeRun?.title, runTemplate == nil {
      pendingPostDismiss = .startRunTracker(activeTitle)
      dismiss()
      return
    }
    if let activeTitle = store.activeWorkout?.title {
      pendingPostDismiss = .startWorkoutTracker(activeTitle)
      dismiss()
      return
    }
    if let runTemplate {
      let trimmedRunTitle = runTemplate.title.trimmingCharacters(in: .whitespacesAndNewlines)
      store.startRun(from: runTemplate)
      // 2026-05-15 (P1 #6): Kein Tab-Switch mehr — RunTracker startet direkt
      // via pendingPostDismiss-Pattern (race-frei nach Sheet-Teardown).
      if store.activeRun?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedRunTitle {
        pendingPostDismiss = .startRunTracker(runTemplate.title)
        dismiss()
      }
      return
    }
    if let plan = assignedPlan {
      store.startWorkout(from: plan)
      // 2026-05-14: Sheet-Race-Hardening — Parent triggert Tracker im
      // onDismiss-Callback (deterministisch nach Sheet-Tear-Down).
      if let activeTitle = store.activeWorkout?.title {
        pendingPostDismiss = .startWorkoutTracker(activeTitle)
        dismiss()
      }
      return
    }
    if isRestDay || isFlexDay {
      let started: Bool
      if let last = store.lastCompletedWorkout {
        let trimmedLastTitle = last.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let plan = store.savedWorkoutPlans.first(where: {
          $0.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedLastTitle
        }) {
          store.startWorkout(from: plan)
          started = store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
          started = false
        }
      } else {
        started = false
      }
      if let activeTitle = started ? store.activeWorkout?.title : nil {
        pendingPostDismiss = .startWorkoutTracker(activeTitle)
        dismiss()
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
    return VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      HStack(spacing: GainsSpacing.xsPlus) {
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
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private var assignmentList: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
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
        VStack(spacing: GainsSpacing.xsPlus) {
          ForEach(store.savedWorkoutPlans) { plan in
            assignmentRow(plan)
          }
        }
      }
    }
  }

  private var emptyPlansHint: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      Text("Noch keine gespeicherten Workouts")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.ink)
      Text("Erstelle zuerst ein Workout im BIBLIOTHEK-Tab, dann kannst du es hier zuweisen.")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private func assignmentRow(_ plan: WorkoutPlan) -> some View {
    let isSelected = assignedPlan?.id == plan.id

    return Button {
      store.assignWorkout(plan, to: weekday)
    } label: {
      HStack(spacing: GainsSpacing.s) {
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
      .padding(GainsSpacing.s)
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
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      Text("ÜBUNGEN")
        .font(GainsFont.label(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)

      VStack(spacing: 1) {
        ForEach(Array(plan.exercises.prefix(6).enumerated()), id: \.element.id) { index, exercise in
          HStack(spacing: GainsSpacing.s) {
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
          .padding(.vertical, GainsSpacing.tight)
          .padding(.horizontal, GainsSpacing.s)
          if index < min(plan.exercises.count, 6) - 1 {
            Divider().background(GainsColor.border.opacity(0.4))
          }
        }
        if plan.exercises.count > 6 {
          Text("+ \(plan.exercises.count - 6) weitere")
            .font(GainsFont.label(10))
            .tracking(1.0)
            .foregroundStyle(GainsColor.softInk)
            .padding(.vertical, GainsSpacing.tight)
            .padding(.horizontal, GainsSpacing.s)
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
