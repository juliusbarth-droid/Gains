import SwiftUI

// MARK: - GymPlanTab
//
// Aufgeräumter PLAN-Tab. Verbesserungen vs. der vorherigen Version:
//   • 4-Wochen-Vorschau ist jetzt **standardmäßig eingeklappt**. Verhindert,
//     dass der Tab beim ersten Öffnen mit einer riesigen Datumsmatrix erschlägt.
//   • Volumen-Vorschau wurde entfernt — sie lebt in STATS, dort gehört sie hin.
//     Vermeidet Duplikat-Inhalte zwischen PLAN und STATS.
//   • Wissenschafts-/Evidence-Block (vorher in HEUTE) ist nach hier umgezogen.
//     Plan-Tab ist der Ort, an dem man Trainingsdosis & Setup einsieht/ändert.
//   • Reihenfolge optimiert: Status → Wochen-Einteilung → Workouts zuweisen →
//     Wissenschaft → Vorschau → Lauf-Block.

struct GymPlanTab: View {
  @EnvironmentObject private var store: GainsStore

  @Binding var showsPlanWizard: Bool
  @Binding var showsCustomPlanBuilder: Bool
  /// Wird gehoben, wenn `WeekdayDetailSheet` ein Workout startet — Parent
  /// (GymView) öffnet daraufhin den `WorkoutTrackerView`-Sheet. Optional,
  /// damit ältere Aufrufstellen nicht angepasst werden müssen.
  @Binding var isShowingWorkoutTracker: Bool

  // 2026-05-03: Vorschau ist jetzt Default-AUSGEKLAPPT. Vorher haben Nutzer
  // die 4-Wochen-Vorschau praktisch nie gesehen, weil der Disclosure-Button
  // unter dem Wissenschafts-Block unauffällig saß. Mit Default-on wird der
  // Plan-Horizont sichtbar — und die Section ist trotzdem einklappbar, falls
  // sie stört.
  @State private var showsFourWeekPreview = true
  /// Aktueller Tap-Selektor für `WeekdayDetailSheet`. `weekday + referenceDate`
  /// bilden zusammen die Identity, sodass z.B. „Mo dieser Woche" und „Mo in
  /// 3 Wochen" jeweils ein eigenes Sheet öffnen.
  @State private var weekdaySelection: WeekdaySheetSelection?

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xl) {
      planStatusCard
      weeklyPreferencesSection
      assignmentsSection
      evidenceSection
      fourWeekPreviewSection
      // 2026-05-03: Lauf-Block ist jetzt eine zusammenhängende Sektion —
      // `runningSummary` (Wochenmetriken aus dem Plan) UND der
      // `RunGoalPlannerSection` (konkretes Lauf-Zielprogramm) erscheinen
      // gemeinsam ODER gar nicht. Vorher hingen die Lauf-Wochenmetriken
      // an `trainingFocus != .strength`, der Goal-Planner aber war immer
      // sichtbar — auch bei Nutzern mit reinem Krafttraining-Fokus, wo der
      // leere Goal-Setup-State schlicht fehl am Platz war.
      if showsRunningBlock {
        runningSummary
        RunGoalPlannerSection()
      }
    }
    .sheet(item: $weekdaySelection) { selection in
      WeekdayDetailSheet(
        weekday: selection.weekday,
        referenceDate: selection.referenceDate,
        isShowingWorkoutTracker: $isShowingWorkoutTracker
      )
      .environmentObject(store)
    }
  }

  /// Zeigt den Lauf-Block, wenn Cardio Teil des Plans ist ODER der Nutzer
  /// bereits ein konkretes Lauf-Ziel angelegt hat (auch Strength-Fokus mit
  /// einem 10K-Ziel als Side-Quest behält dann den Block sichtbar).
  private var showsRunningBlock: Bool {
    let isCardio = store.plannerSettings.trainingFocus != .strength
    let hasGoal = store.runGoalPlan != nil
    let hasKmTarget = store.plannerSettings.weeklyKilometerTarget > 0
    return isCardio || hasGoal || hasKmTarget
  }

  // MARK: - Plan-Status
  //
  // A9: Migriert auf `GainsHeroCard` aus dem Design-System. Vorher war die
  // Card eine eigenhändige Kopie der Hero-Anatomie (Eyebrow + Title + Body +
  // Metrik-Strip + Lime-CTA) — exakt das, was `GainsHeroCard` bereits liefert.
  // Konsistent mit GymTodayTab.todayHeroCard und WorkoutHubView.runHeroCard.

  private var planStatusCard: some View {
    let isManual = store.plannerSettings.isManualPlan

    return GainsHeroCard(
      eyebrow: ["PLAN", isManual ? "MANUELL" : "STATUS"],
      title: store.plannerSummaryHeadline,
      subtitle: store.plannerSummaryDescription,
      primaryCtaTitle: isManual ? "Plan bearbeiten" : "Plan erstellen",
      primaryCtaIcon: isManual ? "slider.horizontal.3" : "wand.and.stars",
      primaryCtaAction: {
        if isManual {
          showsCustomPlanBuilder = true
        } else {
          showsPlanWizard = true
        }
      },
      metrics: [
        .init("EINHEITEN", "\(store.trainingDaysCount)/Wo."),
        .init("PLÄNE",  "\(store.plannerAssignedDaysCount) hinterlegt"),
        .init("FOKUS",     store.plannerSettings.trainingFocus.shortTitle),
      ],
      trailingBadge: {
        // Aktiver Plan-Modus auf einen Blick. Wenn manuell aktiv ist, sieht
        // der Nutzer das im Hero — sonst kein Badge, damit die Card nicht
        // unnötig vollläuft.
        if isManual {
          GainsHeroStatusBadge(label: "MANUELL", tone: .flex)
        } else {
          EmptyView()
        }
      },
      footer: {
        // Sekundärer Einstieg neben dem primären CTA. Im Wizard-Modus
        // bietet der Footer den Wechsel zum manuellen Plan; im manuellen
        // Modus den Rückweg zum Wizard.
        HStack(spacing: GainsSpacing.tight) {
          if isManual {
            secondaryCtaButton(
              title: "Auf Wizard zurück",
              icon: "wand.and.stars"
            ) {
              store.clearManualPlan()
              showsPlanWizard = true
            }
          } else {
            secondaryCtaButton(
              title: "Eigenen Plan erstellen",
              icon: "slider.horizontal.3"
            ) { showsCustomPlanBuilder = true }
          }
        }
      }
    )
  }

  /// Sekundär-Button für die Hero-Card. Bewusst flach gehalten, damit der
  /// primäre Lime-CTA visuell die Bühne behält.
  private func secondaryCtaButton(
    title: String,
    icon: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: GainsSpacing.xsPlus) {
        Image(systemName: icon)
          .font(.system(size: 11, weight: .bold))
        Text(title)
          .font(GainsFont.label(11))
          .tracking(1.2)
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 10, weight: .semibold))
          .opacity(0.6)
      }
      .foregroundStyle(GainsColor.onCtaSurface)
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 42)
      .frame(maxWidth: .infinity)
      .background(Color.white.opacity(0.06))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .strokeBorder(Color.white.opacity(0.10), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Wochen-Einteilung (Kalender-Karten)
  //
  // Redesign (2026-04-28): Statt 21 winziger Mini-Pills (3 × 7) zeigt der
  // Wochenplaner jetzt 7 Tageskarten mit Datum, Wochentag und einem
  // prominenten Status-Icon. Ein KW-Header verortet die Woche im Kalender,
  // ein Lauf-Marker sitzt direkt im Statuskreis, und der Status-Wechsel
  // läuft über ein Menu — weniger Buttons, deutlich besser lesbar.

  private var weeklyPreferencesSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["WOCHE", "PLANEN"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text(currentWeekRangeLabel)
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }

      VStack(spacing: GainsSpacing.s) {
        HStack(alignment: .top, spacing: GainsSpacing.xs) {
          ForEach(Weekday.allCases) { day in
            weekdayCard(day)
          }
        }
        plannerLegend
      }
      .padding(GainsSpacing.m)
      .gainsCardStyle()
    }
  }

  private func weekdayCard(_ day: Weekday) -> some View {
    let pref = store.dayPreference(for: day)
    let isToday = day == .today
    let kind = store.plannedSessionKinds[day]
    let isRunDay = kind?.isRun == true
    let style = plannerCardStyle(for: pref, isRun: isRunDay)
    let assignedPlan = store.assignedWorkoutPlan(for: day)
    let runTemplate = store.runTemplate(for: day)
    // 2026-05-03: Done-Status wird aus workout/runHistory abgeleitet —
    // wenn an dem Tag in dieser Woche schon trainiert/gelaufen wurde,
    // ersetzt ein Lime-Check das Status-Icon, und das Status-Label
    // springt auf „Erledigt".
    let isCompleted = store.isPlannedSessionCompletedToday(for: day)
    // Kontextuelles Status-Label statt generischem „Kraft"/„Lauf":
    // - Erledigt: „Erledigt"
    // - Kraft mit zugewiesenem Plan: Split-Kürzel des Plans (Push/Pull/…)
    // - Lauf mit Template: Distanz in km
    // - Sonst: Default aus PlannerCardStyle
    let contextLabel: String = {
      if isCompleted { return "Erledigt" }
      if !isRunDay, let plan = assignedPlan {
        return plan.split
      }
      if isRunDay, let run = runTemplate {
        return String(format: "%g km", run.targetDistanceKm)
      }
      return style.label
    }()

    // 2026-05-01: Vorher öffnete der Tap-auf-Tag ein verstecktes Menu mit drei
    // Status-Optionen (Training/Flex/Rest). Jetzt führt der Tap in das
    // `WeekdayDetailSheet`, das Status, zugewiesenen Plan, Lauf-Daten und den
    // Primary-CTA bündelt — die drei Status-Optionen sind dort als sichtbarer
    // Switcher umgezogen.
    // 2026-05-03: Long-Press öffnet zusätzlich ein ContextMenu für Quick-Edits
    // (Status wechseln, Workout zuweisen, Tag tauschen) ohne den Sheet-Hop.
    return Button {
      weekdaySelection = WeekdaySheetSelection(
        weekday: day,
        referenceDate: dateForCurrentWeek(weekday: day)
      )
    } label: {
      VStack(spacing: GainsSpacing.xs) {
        Text(day.shortLabel)
          .font(GainsFont.label(8))
          .tracking(1.4)
          .foregroundStyle(isToday ? GainsColor.moss : GainsColor.softInk.opacity(0.85))

        Text(currentWeekDayNumber(for: day))
          .font(.system(size: 15, weight: .semibold, design: .rounded))
          .foregroundStyle(GainsColor.ink)

        ZStack {
          Circle()
            .fill(isCompleted ? GainsColor.lime : style.iconBackground)
          if isCompleted {
            Image(systemName: "checkmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(GainsColor.onLime)
          } else {
            Image(systemName: style.icon)
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(style.iconForeground)
          }
        }
        .frame(width: 28, height: 28)

        Text(contextLabel)
          .font(GainsFont.label(8))
          .tracking(0.9)
          .foregroundStyle(isCompleted ? GainsColor.moss : style.labelColor)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .padding(.vertical, GainsSpacing.tight)
      .padding(.horizontal, GainsSpacing.xxs)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(isToday ? GainsColor.lime.opacity(0.10) : GainsColor.background.opacity(0.55))
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(
            isToday ? GainsColor.lime.opacity(0.7) : GainsColor.border.opacity(0.5),
            lineWidth: isToday ? 1.4 : 0.6
          )
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .contextMenu { weekdayQuickMenu(day) }
  }

  // MARK: - Long-Press Quick-Menu
  //
  // 2026-05-03: Reduziert Sheet-Hops für die häufigsten Anpassungen.
  // Statt Tap → Sheet → Status-Switcher → Workout-Liste → Fertig kann
  // der Nutzer per Long-Press direkt den Status wechseln, ein Workout
  // zuweisen oder den Tag mit einem anderen tauschen. Bewusst flache
  // Button-Liste mit Submenus statt Section-Header — robuster über
  // iOS-Versionen hinweg und im ContextMenu-Popover gut lesbar.
  @ViewBuilder
  private func weekdayQuickMenu(_ day: Weekday) -> some View {
    let pref = store.dayPreference(for: day)

    Button {
      store.setDayPreference(.training, for: day)
    } label: {
      Label("Training", systemImage: pref == .training ? "checkmark" : "dumbbell.fill")
    }
    Button {
      store.setDayPreference(.flexible, for: day)
    } label: {
      Label("Flexibel", systemImage: pref == .flexible ? "checkmark" : "arrow.triangle.2.circlepath")
    }
    Button {
      store.setDayPreference(.rest, for: day)
    } label: {
      Label("Ruhe", systemImage: pref == .rest ? "checkmark" : "moon.zzz.fill")
    }

    Divider()

    if pref == .training,
       store.plannedSessionKinds[day]?.isRun != true,
       !store.savedWorkoutPlans.isEmpty {
      Menu {
        ForEach(store.savedWorkoutPlans) { plan in
          Button(plan.title) { store.assignWorkout(plan, to: day) }
        }
        if store.assignedWorkoutPlan(for: day) != nil {
          Divider()
          Button("Zuweisung entfernen", role: .destructive) {
            store.clearAssignedWorkout(for: day)
          }
        }
      } label: {
        Label("Workout zuweisen…", systemImage: "dumbbell")
      }
    }

    Menu {
      ForEach(Weekday.allCases.filter { $0 != day }) { other in
        Button(other.title) {
          store.swapDayAssignments(day, other)
        }
      }
    } label: {
      Label("Tag tauschen mit…", systemImage: "arrow.left.arrow.right")
    }
  }

  // Hält die Status→Style-Logik an einem Ort, damit Card und Legende
  // dieselbe Farb-/Icon-Sprache sprechen.
  private struct PlannerCardStyle {
    let icon: String
    let iconBackground: Color
    let iconForeground: Color
    let label: String
    let labelColor: Color
  }

  private func plannerCardStyle(for pref: WorkoutDayPreference, isRun: Bool) -> PlannerCardStyle {
    switch pref {
    case .training:
      if isRun {
        return PlannerCardStyle(
          icon: "figure.run",
          iconBackground: GainsColor.moss,
          iconForeground: GainsColor.onLime,
          label: "Lauf",
          labelColor: GainsColor.moss
        )
      }
      return PlannerCardStyle(
        icon: "dumbbell.fill",
        iconBackground: GainsColor.lime,
        iconForeground: GainsColor.onLime,
        label: "Kraft",
        labelColor: GainsColor.lime
      )
    case .flexible:
      return PlannerCardStyle(
        icon: "arrow.triangle.2.circlepath",
        iconBackground: GainsColor.accentCool.opacity(0.22),
        iconForeground: GainsColor.accentCool,
        label: "Flexi",
        labelColor: GainsColor.accentCool
      )
    case .rest:
      return PlannerCardStyle(
        icon: "moon.zzz.fill",
        iconBackground: GainsColor.background.opacity(0.6),
        iconForeground: GainsColor.softInk,
        label: "Ruhe",
        labelColor: GainsColor.softInk
      )
    }
  }

  private var plannerLegend: some View {
    // P2-5 (2026-05-03): „Tippen · Lang-Press = Schnellaktion"-Hint raus.
    // Die Karten sind durch Lime-Border auf today, Card-Surface und Icons
    // sichtbar tap-affordant. Auf 4-Inch-Devices brach die Zeile außerdem
    // um. Wenn das Long-Press-Pattern erklärt werden muss, gehört es in
    // den Day-One-Tooltip — nicht permanent als Subzeile.
    HStack(spacing: GainsSpacing.tight) {
      legendChip(color: GainsColor.lime, label: "Kraft")
      legendChip(color: GainsColor.moss, label: "Lauf")
      legendChip(color: GainsColor.accentCool, label: "Flexi")
      legendChip(color: GainsColor.softInk.opacity(0.65), label: "Ruhe")
      Spacer()
    }
  }

  private func legendChip(color: Color, label: String) -> some View {
    HStack(spacing: GainsSpacing.xxs) {
      Circle()
        .fill(color)
        .frame(width: 6, height: 6)
      Text(label)
        .font(GainsFont.label(8))
        .tracking(0.8)
        .foregroundStyle(GainsColor.softInk)
    }
  }

  // KW-Header — z.B. "KW 18 · 27. APR – 3. MAI". ISO-Calendar mit Montag
  // als erstem Wochentag, damit die Karte zur deutschen Wochenkonvention
  // passt.
  private var currentWeekRangeLabel: String {
    let cal = Self.plannerCalendar
    let today = Date()
    guard
      let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
      let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart)
    else {
      return ""
    }
    let week = cal.component(.weekOfYear, from: today)
    let formatter = Self.weekRangeFormatter
    return "KW \(week) · \(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
  }

  private func currentWeekDayNumber(for day: Weekday) -> String {
    let cal = Self.plannerCalendar
    let today = Date()
    guard
      let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
      let date = cal.date(byAdding: .day, value: day.mondayOffset, to: weekStart)
    else {
      return "—"
    }
    return "\(cal.component(.day, from: date))"
  }

  /// Liefert das konkrete Datum für einen Wochentag in der aktuellen Woche.
  /// Wird vom Tap auf eine Wochenkarte genutzt, damit `WeekdayDetailSheet`
  /// Datum + Wochentag kennt (z.B. „MO · 5. MAI" statt nur „Montag").
  private func dateForCurrentWeek(weekday: Weekday) -> Date {
    let cal = Self.plannerCalendar
    let today = Date()
    guard
      let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
      let date = cal.date(byAdding: .day, value: weekday.mondayOffset, to: weekStart)
    else {
      return today
    }
    return cal.startOfDay(for: date)
  }

  private static let plannerCalendar: Calendar = {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2 // Montag
    return cal
  }()

  private static let weekRangeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "d. MMM"
    return f
  }()

  // MARK: - Workout-Zuweisungen

  private var assignmentsSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["WORKOUTS", "ZUWEISEN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      if store.scheduledPlannerDays.isEmpty {
        EmptyStateView(
          style: .inline,
          title: "Noch keine Trainingstage",
          message: "Setze oben zuerst Trainingstage fest, dann kannst du jedem Kraft-Tag ein konkretes Workout zuweisen.",
          icon: "calendar"
        )
      } else {
        ForEach(store.scheduledPlannerDays) { day in
          assignmentRow(day)
        }
      }
    }
  }

  private func assignmentRow(_ day: Weekday) -> some View {
    let assigned = store.assignedWorkoutPlan(for: day)
    let plannedKind = store.plannedSessionKinds[day]
    let isToday = day == .today
    let isRunDay = plannedKind?.isRun == true
    let hasMissingAssignment = !isRunDay && assigned == nil && store.plannerSettings.dayAssignments[day] != nil

    return HStack(spacing: GainsSpacing.m) {
      ZStack {
        Circle()
          .fill(isToday ? GainsColor.lime : GainsColor.background.opacity(0.85))
          .frame(width: 38, height: 38)
        if isRunDay {
          Image(systemName: "figure.run")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(isToday ? GainsColor.onLime : GainsColor.moss)
        } else {
          Text(day.shortLabel)
            .font(GainsFont.label(10))
            .tracking(1.6)
            .foregroundStyle(isToday ? GainsColor.onLime : GainsColor.softInk)
        }
      }

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: GainsSpacing.xs) {
          Text(day.title)
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
          if isRunDay, let kind = plannedKind {
            Text(kind.shortLabel)
              .font(GainsFont.label(8))
              .tracking(1.4)
              .foregroundStyle(GainsColor.moss)
              .padding(.horizontal, GainsSpacing.xs)
              .padding(.vertical, 2)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
          }
        }
        Text(assignmentLabel(for: day, assigned: assigned, kind: plannedKind, hasMissingAssignment: hasMissingAssignment))
          .font(GainsFont.body(13))
          .foregroundStyle(hasMissingAssignment ? GainsColor.ember : (assigned == nil ? GainsColor.softInk : GainsColor.moss))
          .lineLimit(2)
      }

      Spacer()

      Menu {
        if isRunDay {
          Section("Lauf-Tag (auto)") {
            Text("Wird aus dem Plan abgeleitet")
          }
        } else {
          if hasMissingAssignment {
            Section("Zuweisung prüfen") {
              Text("Das bisher verknüpfte Workout ist nicht mehr verfügbar.")
            }
          }
          if store.savedWorkoutPlans.isEmpty {
            Section("Keine Workouts") {
              Text("Erstelle zuerst ein Workout im Workouts-Tab.")
            }
          } else {
            if !store.customWorkoutPlans.isEmpty {
              Section("Eigene Workouts") {
                ForEach(store.customWorkoutPlans) { plan in
                  Button(plan.title) { store.assignWorkout(plan, to: day) }
                }
              }
            }
            if !store.templateWorkoutPlans.isEmpty {
              Section("Vorlagen") {
                ForEach(store.templateWorkoutPlans) { plan in
                  Button(plan.title) { store.assignWorkout(plan, to: day) }
                }
              }
            }
          }
          if assigned != nil {
            Divider()
            Button("Zuweisung entfernen", role: .destructive) {
              store.clearAssignedWorkout(for: day)
            }
          }
        }
      } label: {
        HStack(spacing: GainsSpacing.xs) {
          // G3-Fix (2026-05-01): Klarere Action-Labels — „Workout
          // wählen" war passiv, „Workout zuweisen" beschreibt die
          // Wirkung des Tippens auf den Tag.
          Text(isRunDay ? "Info" : (hasMissingAssignment ? "Workout reparieren" : "Workout zuweisen"))
            .font(GainsFont.label(9))
            .tracking(1.0)
          Image(systemName: "ellipsis.circle.fill")
            .font(.system(size: 20, weight: .semibold))
        }
        .foregroundStyle(GainsColor.lime)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle(isToday ? GainsColor.lime.opacity(0.08) : GainsColor.card)
  }

  private func assignmentLabel(
    for day: Weekday,
    assigned: WorkoutPlan?,
    kind: PlannedSessionKind?,
    hasMissingAssignment: Bool
  ) -> String {
    if let assigned { return assigned.title }
    if hasMissingAssignment { return "Zugewiesenes Workout nicht mehr verfügbar" }
    return defaultAssignmentLabel(for: day, kind: kind)
  }

  private func defaultAssignmentLabel(for day: Weekday, kind: PlannedSessionKind?) -> String {
    if let kind {
      if kind.isRun { return "Lauf · \(kind.title)" }
      return "Automatisch · \(kind.title)"
    }
    return "Workout wird automatisch vorgeschlagen"
  }

  // MARK: - Wissenschafts-/Evidence-Block
  //
  // Verschoben aus dem alten HEUTE-Tab. Hier passt die Info besser hin:
  // Sie beschreibt das Setup deines Plans (Volumen-Range, Frequenz, Reps,
  // Pausen). Die "ANPASSEN"-Aktion wird über den Plan-Wizard oben gehandhabt
  // — keine doppelte Eintrittsstelle mehr.

  private var evidenceSection: some View {
    let setsRange = store.weeklySetsPerMuscleGroupRange
    let reps = store.recommendedRepRange
    let rir = store.recommendedRIRRange
    let freq = store.recommendedFrequencyPerMuscleGroup
    let isCardio = store.plannerSettings.trainingFocus == .cardio
    let kmTarget = store.plannerSettings.weeklyKilometerTarget

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["WISSENSCHAFT", "DOSIS"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("aus deinem Plan")
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: GainsSpacing.tight), GridItem(.flexible(), spacing: GainsSpacing.tight)],
        spacing: GainsSpacing.tight
      ) {
        GainsMetricTile(
          label: isCardio ? "WOCHEN-KM" : "VOLUMEN",
          value: isCardio ? "\(kmTarget) km" : "\(setsRange.lowerBound)–\(setsRange.upperBound)",
          unit: isCardio ? "Wochenziel" : "Sätze / Muskel × Wo.",
          style: .subdued
        )
        GainsMetricTile(
          label: isCardio ? "VERTEILUNG" : "FREQUENZ",
          value: isCardio ? store.plannerSettings.runIntensityModel.title : "\(freq)×",
          unit: isCardio ? "Intensitätsmodell" : "pro Muskel",
          style: .subdued
        )
        GainsMetricTile(
          label: "REPS / RIR",
          value: "\(reps.lowerBound)–\(reps.upperBound)",
          unit: "RIR \(rir.lowerBound)–\(rir.upperBound)",
          style: .subdued
        )
        GainsMetricTile(
          label: "PAUSEN",
          value: "\(store.recommendedRestSecondsCompound)s",
          unit: "Compound · \(store.recommendedRestSecondsIsolation)s Isolation",
          style: .subdued
        )
      }

      if let note = store.plannerPrimaryRecommendation.evidenceNote {
        HStack(alignment: .top, spacing: GainsSpacing.xs) {
          Image(systemName: "book.closed.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(GainsColor.moss)
          Text(note)
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(3)
        }
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // MARK: - 4-Wochen-Vorschau (collapsible)

  private var fourWeekPreviewSection: some View {
    // 2026-05-03: Section zeigt jetzt nur die KOMMENDEN Wochen (weekIndex >= 1).
    // Die aktuelle Woche steckt bereits in `weeklyPreferencesSection` ganz oben —
    // das Doppeln war redundant und hat den Tab künstlich vergrößert.
    let upcomingWeeks = store.nextFourWeeksSchedule.filter { $0.weekIndex >= 1 }

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Button {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
          showsFourWeekPreview.toggle()
        }
      } label: {
        HStack(alignment: .firstTextBaseline) {
          SlashLabel(
            parts: ["KOMMENDE", "WOCHEN"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )
          Spacer()
          HStack(spacing: GainsSpacing.xxs) {
            Text(showsFourWeekPreview ? "Einklappen" : "Anzeigen")
              .font(GainsFont.label(9))
              .tracking(1.2)
            Image(systemName: showsFourWeekPreview ? "chevron.up" : "chevron.down")
              .font(.system(size: 10, weight: .semibold))
          }
          .foregroundStyle(GainsColor.softInk)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if showsFourWeekPreview {
        VStack(spacing: GainsSpacing.tight) {
          ForEach(upcomingWeeks) { week in
            fourWeekRow(week)
          }
        }
      }
    }
  }

  private func fourWeekRow(_ week: GymPlanPreviewWeek) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      HStack {
        Text(week.label.uppercased())
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(week.weekIndex == 0 ? GainsColor.lime : GainsColor.softInk)
        Spacer()
        Text(weekRangeLabel(week))
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }
      HStack(spacing: GainsSpacing.xs) {
        ForEach(week.days) { day in
          previewDayCell(day)
        }
      }
    }
    .padding(GainsSpacing.s)
    .gainsCardStyle()
  }

  private func previewDayCell(_ day: GymPlanPreviewDay) -> some View {
    let isPast = day.date < Calendar.current.startOfDay(for: Date()) && !day.isToday
    let bg: Color = {
      if day.isCompleted { return GainsColor.lime }
      switch day.status {
      case .planned:
        if day.runTemplate != nil {
          return day.isToday ? GainsColor.moss.opacity(0.55) : GainsColor.moss.opacity(0.20)
        }
        return day.isToday ? GainsColor.lime.opacity(0.55) : GainsColor.lime.opacity(0.16)
      case .rest:     return GainsColor.background.opacity(0.7)
      case .flexible: return GainsColor.card
      }
    }()
    let fg: Color = {
      if day.isCompleted { return GainsColor.ink }
      switch day.status {
      case .planned:  return day.isToday ? GainsColor.moss : GainsColor.ink
      case .rest:     return GainsColor.softInk.opacity(0.6)
      case .flexible: return GainsColor.softInk
      }
    }()

    // 2026-05-03: Vorschau-Zellen sind jetzt tappbar — gleiche Interaktion
    // wie die Wochenkarten oben. Vorher waren die 30 Tage in der Vorschau
    // tot, was die Funktion versteckte ("warum sehe ich das, wenn ich nicht
    // damit interagieren kann?").
    return Button {
      weekdaySelection = WeekdaySheetSelection(
        weekday: day.weekday,
        referenceDate: day.date
      )
    } label: {
      VStack(spacing: GainsSpacing.xxs) {
        ZStack {
          Circle()
            .fill(bg)
            .frame(width: 30, height: 30)
          if day.isCompleted {
            Image(systemName: "checkmark")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(GainsColor.onLime)
          } else if day.runTemplate != nil {
            Image(systemName: "figure.run")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(fg)
          } else {
            Text("\(Calendar.current.component(.day, from: day.date))")
              .font(.system(size: 10, weight: .semibold, design: .rounded))
              .foregroundStyle(fg)
          }
        }
        Text(day.weekday.shortLabel)
          .font(GainsFont.label(8))
          .tracking(0.6)
          .foregroundStyle(day.isToday ? GainsColor.ink : GainsColor.softInk)
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .opacity(isPast && !day.isCompleted ? 0.55 : 1.0)
    }
    .buttonStyle(.plain)
  }

  private func weekRangeLabel(_ week: GymPlanPreviewWeek) -> String {
    guard let first = week.days.first?.date, let last = week.days.last?.date else { return "" }
    let f = Self.weekRangeFormatter
    return "\(f.string(from: first)) – \(f.string(from: last))"
  }

  // MARK: - Lauf-Block

  @ViewBuilder
  private var runningSummary: some View {
    let isCardio = store.plannerSettings.trainingFocus != .strength
    let kmTarget = store.plannerSettings.weeklyKilometerTarget

    if isCardio || kmTarget > 0 {
      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        SlashLabel(
          parts: ["LAUFEN", "IM PLAN"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        VStack(alignment: .leading, spacing: GainsSpacing.tight) {
          HStack(spacing: GainsSpacing.tight) {
            GainsMetricTile(
              label: "WOCHEN-KM",
              value: "\(kmTarget) km",
              unit: "Ziel",
              style: .subdued
            )
            GainsMetricTile(
              label: "VERTEILUNG",
              value: store.plannerSettings.runIntensityModel.title,
              unit: "Intensität",
              style: .subdued
            )
          }
          HStack(spacing: GainsSpacing.tight) {
            GainsMetricTile(
              label: "LAUFZIEL",
              value: store.plannerSettings.runningGoal.title,
              unit: "\(store.plannerSettings.runningGoal.defaultWeeklyKilometers) km empfohlen",
              style: .subdued
            )
            GainsMetricTile(
              label: "FOKUS",
              value: store.plannerSettings.trainingFocus.title,
              unit: "Aktueller Modus",
              style: .subdued
            )
          }
          Text("Lauf-Tage werden in der 4-Wochen-Vorschau und im Wochenplan automatisch markiert (figure.run).")
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
  }
}
