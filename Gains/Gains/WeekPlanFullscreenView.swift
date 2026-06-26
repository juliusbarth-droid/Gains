import SwiftUI

// MARK: - WeekPlanFullscreenView
//
// 2026-05-30 — Vereinheitlichter Wochenplaner (Stufe 1).
//
// Eine einzige, ruhige Wochenansicht statt der vorherigen Dreifach-Redundanz
// (Wochenstrip + eingebetteter GymPlanTab mit Zuweisungs-Liste + 4-Wochen-
// Vorschau). Aufbau:
//   • Hero mit Fortschritts-Ring (erledigte / geplante Sessions).
//   • Wochen-Check: ruhige Trainings-Intelligenz (Muskel-Abdeckung + Hinweis).
//   • „Plan für mich erstellen" → Wizard (automatischer Split aus Tagen/Ziel).
//   • Tages-Lanes Mo–So: jeder Tag ist ein Stack aus PlannedSessions →
//     Hybrid-Tage (Gym + Kardio am selben Tag) sind erstmals möglich.
//   • Kommende Wochen (einklappbar, default zu).
//
// Datenbasis: `store.daySessions` + Helper aus `GainsStore+WeekPlanner`.
// Tippen auf eine Session öffnet (Stage 1) den bestehenden WeekdayDetailSheet
// als Tages-Editor; Hinzufügen läuft über ein Menu direkt in der Lane. Der
// polierte Add-Sheet mit Inline-Builder folgt als Stufe 2.

struct WeekPlanFullscreenView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore

  @State private var showsPlanWizard = false
  @State private var showsCustomPlanBuilder = false
  @State private var weekdaySelection: WeekdaySheetSelection?
  @State private var weekdayPostDismiss: WeekdayPostDismissAction?

  @State private var showsWorkoutTracker = false
  @State private var showsRunTracker = false
  @State private var showsUpcomingWeeks = false

  private var orderedDays: [Weekday] {
    Weekday.allCases.sorted { $0.mondayOffset < $1.mondayOffset }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        GainsAppBackground()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: GainsSpacing.l) {

            if store.activeWorkout != nil {
              activeWorkoutResumeBanner
            } else if store.activeRun != nil {
              activeRunResumeBanner
            }

            heroHeader

            if store.weeklyLoadCheck.hasContent {
              wochenCheckCard
            }

            planEntryCTA

            dayLanesSection

            upcomingWeeksSection
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.tight)
          .padding(.bottom, GainsSpacing.xl + GainsSpacing.l)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
              .overlay(Circle().stroke(GainsColor.border.opacity(0.6), lineWidth: 1))
          }
          .accessibilityLabel("Schließen")
        }
        ToolbarItem(placement: .principal) {
          Text("WOCHENPLAN")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.softInk)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            showsPlanWizard = true
          } label: {
            Image(systemName: "wand.and.stars")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(GainsColor.lime)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
              .overlay(Circle().stroke(GainsColor.border.opacity(0.6), lineWidth: 1))
          }
          .accessibilityLabel("Plan vorschlagen lassen")
        }
      }
      .sheet(
        item: $weekdaySelection,
        onDismiss: {
          guard let action = weekdayPostDismiss else { return }
          weekdayPostDismiss = nil
          switch action {
          case .startWorkoutTracker(let title):
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedTitle {
              showsWorkoutTracker = true
            }
          case .startRunTracker(let title):
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if store.activeRun?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedTitle {
              showsRunTracker = true
            }
          }
        }
      ) { selection in
        WeekdayDetailSheet(
          weekday: selection.weekday,
          referenceDate: selection.referenceDate,
          pendingPostDismiss: $weekdayPostDismiss
        )
        .environmentObject(store)
        .environmentObject(navigation)
      }
      .sheet(isPresented: $showsPlanWizard) {
        GymPlanWizardSheet(settings: store.plannerSettings)
          .environmentObject(store)
      }
      .sheet(isPresented: $showsCustomPlanBuilder) {
        CustomPlanBuilderSheet()
          .environmentObject(store)
      }
      .fullScreenCover(isPresented: $showsWorkoutTracker) {
        WorkoutTrackerView()
          .environmentObject(store)
      }
      .fullScreenCover(isPresented: $showsRunTracker) {
        RunTrackerView()
          .environmentObject(store)
      }
    }
  }

  // MARK: - Hero

  private var heroHeader: some View {
    HStack(alignment: .center, spacing: GainsSpacing.m) {
      HStack(alignment: .center, spacing: GainsSpacing.s) {
        PulsingDot(color: GainsColor.lime, coreSize: 6, haloSize: 16)
        VStack(alignment: .leading, spacing: GainsSpacing.xs) {
          Text("DIESE WOCHE")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.lime)
          Text(formattedWeekRange)
            .font(GainsFont.title)
            .foregroundStyle(GainsColor.ink)
          Text(weekSummaryLine)
            .font(GainsFont.caption)
            .foregroundStyle(GainsColor.softInk)
        }
      }

      Spacer(minLength: 0)

      weekProgressRing
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      ZStack {
        GainsColor.glassUndertone
        Rectangle().fill(.ultraThinMaterial)
        GainsColor.card.opacity(0.55)
        RadialGradient(
          colors: [GainsColor.lime.opacity(0.16), .clear],
          center: .topLeading, startRadius: 0, endRadius: 220
        ).blendMode(.screen)
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.lime.opacity(0.45), GainsColor.lime.opacity(0.10)],
            startPoint: .top, endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
    .shadow(color: GainsColor.lime.opacity(0.06), radius: 12, x: 0, y: 0)
  }

  private var weekProgressRing: some View {
    let total = store.weekPlannerTotalSessions
    let rawDone = store.weekPlannerDoneSessions
    let done = total > 0 ? min(rawDone, total) : rawDone
    let progress: Double = total > 0 ? min(1.0, Double(rawDone) / Double(total)) : 0

    return ZStack {
      Circle().stroke(GainsColor.border.opacity(0.35), lineWidth: 5)
      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          LinearGradient(
            colors: progress >= 1
              ? [GainsColor.lime, GainsColor.lime]
              : [GainsColor.lime, GainsColor.lime.opacity(0.5)],
            startPoint: .top, endPoint: .bottom
          ),
          style: StrokeStyle(lineWidth: 5, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut(duration: 0.5), value: progress)

      if total == 0 {
        Text("—")
          .font(.system(size: 16, weight: .heavy, design: .rounded))
          .foregroundStyle(GainsColor.softInk)
      } else {
        VStack(spacing: 0) {
          Text("\(done)")
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(GainsColor.ink)
          Text("/\(total)")
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .frame(width: 62, height: 62)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(total == 0 ? "Keine Sessions geplant" : "\(done) von \(total) Sessions erledigt")
  }

  // MARK: - Wochen-Check

  private var wochenCheckCard: some View {
    let check = store.weeklyLoadCheck
    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: "waveform.path.ecg")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        Text("WOCHEN-CHECK")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        Text("Ziel: \(store.plannerSettings.goal.title)")
          .font(GainsFont.label(9))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.moss)
      }

      if check.coverage.isEmpty {
        Text("Noch keine Gym-Sessions mit Übungen — der Check füllt sich, sobald du Workouts zuweist.")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
      } else {
        WeeklyCheckChips(items: check.coverage.map { (label: $0.muscle, count: $0.sessions, isUnder: $0.isUnder) })
      }

      if let nudge = check.nudge {
        HStack(alignment: .top, spacing: GainsSpacing.xs) {
          Image(systemName: "lightbulb.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.ember)
          Text(nudge)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(.top, GainsSpacing.xxs)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // MARK: - Plan-Entry (Wizard)

  private var planEntryCTA: some View {
    Button {
      showsPlanWizard = true
    } label: {
      HStack(spacing: GainsSpacing.s) {
        Image(systemName: "wand.and.stars")
          .font(.system(size: 17, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        VStack(alignment: .leading, spacing: 1) {
          Text("Plan für mich erstellen")
            .font(GainsFont.title(15))
            .foregroundStyle(GainsColor.ink)
          Text("Tage & Ziele angeben → optimaler Split")
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(GainsSpacing.m)
      .frame(maxWidth: .infinity, alignment: .leading)
      .gainsGlassCTA(corner: GainsRadius.standard)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Tages-Lanes

  private var dayLanesSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack(alignment: .firstTextBaseline) {
        Text("TAGE & TRAINING")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        Text("Antippen zum Bearbeiten")
          .font(GainsFont.label(9))
          .tracking(0.4)
          .foregroundStyle(GainsColor.softInk.opacity(0.55))
      }

      VStack(spacing: GainsSpacing.s) {
        ForEach(orderedDays) { day in
          dayLane(day)
        }
      }
    }
  }

  @ViewBuilder
  private func dayLane(_ day: Weekday) -> some View {
    let date = store.currentWeekDate(for: day)
    let isToday = Calendar.current.isDateInToday(date)
    let sessions = store.sessions(for: day)

    HStack(alignment: .top, spacing: GainsSpacing.s) {
      // Tages-Spalte
      VStack(spacing: 3) {
        Text(day.shortLabel)
          .font(GainsFont.label(9))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(isToday ? GainsColor.moss : GainsColor.softInk)
        ZStack {
          Circle()
            .fill(isToday ? GainsColor.lime : GainsColor.card)
            .overlay(Circle().stroke(GainsColor.border.opacity(isToday ? 0 : 0.6), lineWidth: 1))
          Text("\(Calendar.current.component(.day, from: date))")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(isToday ? GainsColor.onLime : GainsColor.ink)
        }
        .frame(width: 30, height: 30)
        if isToday {
          Text("Heute")
            .font(GainsFont.label(8))
            .tracking(0.6)
            .foregroundStyle(GainsColor.moss)
        }
      }
      .frame(width: 42)

      // Session-Stack
      VStack(spacing: GainsSpacing.xs) {
        ForEach(sessions) { session in
          sessionRow(session, day: day, date: date, isToday: isToday)
        }
        addAffordance(for: day, hasSessions: !sessions.isEmpty)
      }
      .frame(maxWidth: .infinity)
    }
    .padding(GainsSpacing.s)
    .background(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .fill(GainsColor.card)
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          isToday ? GainsColor.lime.opacity(0.85) : GainsColor.border.opacity(0.55),
          lineWidth: isToday ? 1.5 : 0.8
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  @ViewBuilder
  private func sessionRow(_ session: PlannedSession, day: Weekday, date: Date, isToday: Bool) -> some View {
    let done = store.isSessionCompleted(session, on: date)
    let tint = session.isCardio ? GainsColor.moss : GainsColor.lime
    let info = sessionDisplay(session)

    HStack(spacing: GainsSpacing.s) {
      Button {
        weekdaySelection = WeekdaySheetSelection(weekday: day, referenceDate: date)
      } label: {
        HStack(spacing: GainsSpacing.s) {
          ZStack {
            Circle().fill(done ? GainsColor.lime : tint.opacity(0.16))
            Image(systemName: done ? "checkmark" : info.icon)
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(done ? GainsColor.onLime : tint)
          }
          .frame(width: 26, height: 26)

          VStack(alignment: .leading, spacing: 1) {
            Text(info.title)
              .font(GainsFont.title(13))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            Text(done ? "Erledigt" : info.subtitle)
              .font(GainsFont.body(11))
              .foregroundStyle(done ? GainsColor.moss : GainsColor.softInk)
              .lineLimit(1)
          }
          Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if isToday && !done {
        Button {
          startSession(session)
        } label: {
          Image(systemName: "play.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .padding(.horizontal, GainsSpacing.s)
            .frame(height: 28)
            .overlay(
              Capsule().strokeBorder(GainsColor.lime, lineWidth: GainsBorder.accent)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(info.title) starten")
      }
    }
    .padding(.vertical, GainsSpacing.xs)
    .padding(.horizontal, GainsSpacing.s)
    .background(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .fill(done ? GainsColor.background.opacity(0.5) : tint.opacity(0.10))
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(tint.opacity(done ? 0.20 : 0.30), lineWidth: 0.5)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .opacity(done ? 0.85 : 1.0)
    .contextMenu {
      sessionContextMenu(session, day: day)
    }
  }

  @ViewBuilder
  private func sessionContextMenu(_ session: PlannedSession, day: Weekday) -> some View {
    if session.isGym {
      Menu {
        Button { store.updateSession(PlannedSession(id: session.id, kind: .strength, workoutPlanID: nil), on: day) } label: {
          Label("Kein festes Workout", systemImage: "minus.circle")
        }
        ForEach(store.savedWorkoutPlans) { plan in
          Button(plan.title) {
            store.updateSession(PlannedSession(id: session.id, kind: .strength, workoutPlanID: plan.id), on: day)
          }
        }
      } label: {
        Label("Workout zuweisen…", systemImage: "dumbbell")
      }
    }
    Menu {
      ForEach(orderedDays.filter { $0 != day }) { other in
        Button(other.title) { store.moveSession(session.id, from: day, to: other) }
      }
    } label: {
      Label("Verschieben nach…", systemImage: "arrow.left.arrow.right")
    }
    Divider()
    Button(role: .destructive) {
      store.removeSession(session.id, from: day)
    } label: {
      Label("Entfernen", systemImage: "trash")
    }
  }

  private func addAffordance(for day: Weekday, hasSessions: Bool) -> some View {
    Menu {
      Section("Gym") {
        Button {
          store.addSession(.gym(nil), to: day)
        } label: {
          Label("Leeres Gym (Workout später)", systemImage: "dumbbell")
        }
        ForEach(store.savedWorkoutPlans) { plan in
          Button(plan.title) { store.addSession(.gym(plan.id), to: day) }
        }
      }
      Section("Kardio") {
        Button { store.addSession(.cardio(.easyRun), to: day) }     label: { Label("Easy Run", systemImage: "figure.run") }
        Button { store.addSession(.cardio(.tempoRun), to: day) }    label: { Label("Tempo Run", systemImage: "figure.run") }
        Button { store.addSession(.cardio(.intervalRun), to: day) } label: { Label("Intervalle", systemImage: "figure.run") }
        Button { store.addSession(.cardio(.longRun), to: day) }     label: { Label("Long Run", systemImage: "figure.run") }
        Button { store.addSession(.cardio(.recoveryRun), to: day) } label: { Label("Recovery Run", systemImage: "figure.run") }
      }
    } label: {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: "plus")
          .font(.system(size: 12, weight: .bold))
        Text(hasSessions ? "Session hinzufügen" : "Gym oder Kardio hinzufügen")
          .font(GainsFont.label(11))
          .tracking(0.3)
      }
      .foregroundStyle(GainsColor.softInk)
      .frame(maxWidth: .infinity)
      .padding(.vertical, hasSessions ? GainsSpacing.xs : GainsSpacing.s)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
          .foregroundStyle(GainsColor.border.opacity(0.8))
      )
      .contentShape(Rectangle())
    }
  }

  // MARK: - Kommende Wochen (einklappbar)

  private var upcomingWeeksSection: some View {
    let upcoming = store.nextFourWeeksSchedule.filter { $0.weekIndex >= 1 }

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Button {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
          showsUpcomingWeeks.toggle()
        }
      } label: {
        HStack(alignment: .firstTextBaseline) {
          Text("KOMMENDE WOCHEN")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrow)
            .foregroundStyle(GainsColor.softInk)
          Spacer()
          HStack(spacing: GainsSpacing.xxs) {
            Text(showsUpcomingWeeks ? "Einklappen" : "Anzeigen")
              .font(GainsFont.label(9))
              .tracking(GainsTracking.eyebrowTight)
            Image(systemName: showsUpcomingWeeks ? "chevron.up" : "chevron.down")
              .font(.system(size: 10, weight: .semibold))
          }
          .foregroundStyle(GainsColor.softInk)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      if showsUpcomingWeeks {
        VStack(spacing: GainsSpacing.tight) {
          ForEach(upcoming) { week in
            upcomingWeekRow(week)
          }
          Text("Wiederholt sich aus deinem Wochenrhythmus. Einzelne Wochen abweichend bearbeiten kommt als nächste Stufe.")
            .font(GainsFont.label(9))
            .foregroundStyle(GainsColor.softInk.opacity(0.7))
            .padding(.top, GainsSpacing.xxs)
        }
      }
    }
  }

  private func upcomingWeekRow(_ week: GymPlanPreviewWeek) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text(week.label.uppercased())
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(spacing: GainsSpacing.xs) {
        ForEach(week.days) { day in
          VStack(spacing: GainsSpacing.xxs) {
            ZStack {
              Circle().fill(upcomingDotColor(day))
              if day.runTemplate != nil {
                Image(systemName: "figure.run")
                  .font(.system(size: 10, weight: .bold))
                  .foregroundStyle(day.status == .planned ? GainsColor.ink : GainsColor.softInk)
              } else if day.status == .planned {
                Image(systemName: "dumbbell.fill")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundStyle(GainsColor.ink)
              }
            }
            .frame(width: 28, height: 28)
            Text(day.weekday.shortLabel)
              .font(GainsFont.label(8))
              .tracking(0.4)
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
    .padding(GainsSpacing.s)
    .gainsCardStyle()
  }

  private func upcomingDotColor(_ day: GymPlanPreviewDay) -> Color {
    switch day.status {
    case .planned:  return day.runTemplate != nil ? GainsColor.moss.opacity(0.22) : GainsColor.lime.opacity(0.20)
    case .rest:     return GainsColor.background.opacity(0.7)
    case .flexible: return GainsColor.surfaceDeep.opacity(0.7)
    }
  }

  // MARK: - Session-Start

  private func startSession(_ session: PlannedSession) {
    UISelectionFeedbackGenerator().selectionChanged()
    if session.isGym {
      if let plan = store.workoutPlan(for: session) {
        let trimmedPlanTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedPlanTitle {
          showsWorkoutTracker = true
          return
        }
        store.startWorkout(from: plan)
        if store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedPlanTitle {
          showsWorkoutTracker = true
        }
      }
    } else if session.isCardio {
      if let template = RunTemplate.template(for: session.kind) {
        if store.activeRun?.title == template.title {
          showsRunTracker = true
          return
        }
        store.startRun(from: template)
        if store.activeRun?.title == template.title {
          showsRunTracker = true
        }
      }
    }
  }

  // MARK: - Session-Anzeige

  private struct SessionDisplay {
    let icon: String
    let title: String
    let subtitle: String
  }

  private func sessionDisplay(_ session: PlannedSession) -> SessionDisplay {
    if session.isGym {
      if let plan = store.workoutPlan(for: session) {
        return SessionDisplay(
          icon: "dumbbell.fill",
          title: plan.title,
          subtitle: "\(plan.estimatedDurationMinutes) Min · \(plan.exercises.count) Übungen"
        )
      }
      return SessionDisplay(icon: "dumbbell.fill", title: "Gym", subtitle: "Workout später zuweisen")
    }
    // Kardio
    let template = RunTemplate.template(for: session.kind)
    let subtitle = template.map { "\(String(format: "%.1f km", $0.targetDistanceKm)) · \($0.targetDurationMinutes) Min · \($0.targetPaceLabel)" } ?? "Lauf"
    return SessionDisplay(
      icon: "figure.run",
      title: session.kind.title,
      subtitle: subtitle
    )
  }

  // MARK: - Resume-Banner

  private var activeWorkoutResumeBanner: some View {
    Button {
      guard store.activeWorkout != nil else { return }
      showsWorkoutTracker = true
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      resumeBannerBody(
        icon: "figure.strengthtraining.traditional",
        title: store.activeWorkout?.title ?? "Aktives Workout"
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Laufendes Workout fortsetzen")
  }

  private var activeRunResumeBanner: some View {
    Button {
      guard store.activeRun != nil else { return }
      showsRunTracker = true
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      resumeBannerBody(
        icon: runBannerIcon,
        title: store.activeRun?.title ?? "Aktive Cardio-Session"
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Laufende Cardio-Session fortsetzen")
  }

  private func resumeBannerBody(icon: String, title: String) -> some View {
    HStack(spacing: GainsSpacing.s) {
      ZStack {
        Circle().fill(GainsColor.lime.opacity(0.22))
        Image(systemName: icon)
          .font(.system(size: 16, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
      }
      .frame(width: 38, height: 38)
      .overlay(Circle().strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.hairline))

      VStack(alignment: .leading, spacing: 2) {
        Text("LÄUFT JETZT")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
          .foregroundStyle(GainsColor.lime)
        Text(title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
      }
      Spacer(minLength: 0)
      ZStack {
        Circle().fill(GainsColor.lime)
        Image(systemName: "play.fill")
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(GainsColor.onLime)
          .offset(x: 1)
      }
      .frame(width: 32, height: 32)
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      ZStack {
        GainsColor.glassUndertone
        Rectangle().fill(.ultraThinMaterial)
        RadialGradient(
          colors: [GainsColor.lime.opacity(0.20), .clear],
          center: .topLeading, startRadius: 0, endRadius: 220
        ).blendMode(.screen)
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.lime.opacity(0.60), GainsColor.lime.opacity(0.12)],
            startPoint: .top, endPoint: .bottom
          ),
          lineWidth: GainsBorder.accent
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .shadow(color: GainsColor.shadowFloatAmbient, radius: 16, x: 0, y: 10)
  }

  private var runBannerIcon: String {
    switch store.activeRun?.modality {
    case .bikeIndoor, .bikeOutdoor: return "bicycle"
    default: return "figure.run"
    }
  }

  // MARK: - Computed / Formatter

  private static let weekRangeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "d. MMM"
    return f
  }()

  private var formattedWeekRange: String {
    let now = Date()
    let cal = Calendar(identifier: .iso8601)
    guard let interval = cal.dateInterval(of: .weekOfYear, for: now) else {
      return "Aktuelle Woche"
    }
    let start = Self.weekRangeFormatter.string(from: interval.start)
    let end = Self.weekRangeFormatter.string(from: interval.end.addingTimeInterval(-1))
    let weekNumber = cal.component(.weekOfYear, from: now)
    return "KW \(weekNumber) · \(start) – \(end)"
  }

  private var weekSummaryLine: String {
    let check = store.weeklyLoadCheck
    let total = store.weekPlannerTotalSessions
    guard total > 0 else { return "Noch kein Training geplant" }
    var parts = ["\(total) Sessions"]
    if check.gymCount > 0 { parts.append("\(check.gymCount) Gym") }
    if check.cardioCount > 0 { parts.append("\(check.cardioCount) Kardio") }
    return parts.joined(separator: " · ")
  }
}

// MARK: - FlowChips
//
// Umbrechende Chip-Reihe für die Muskel-Abdeckung im Wochen-Check. Nutzt ein
// adaptives Grid (robust, kein eigener Wrap-Algorithmus). Unter-abgedeckte
// Hauptgruppen (isUnder) bekommen einen dezenten Ember-Ton.

private struct WeeklyCheckChips: View {
  let items: [(label: String, count: Int, isUnder: Bool)]

  private let columns = [GridItem(.adaptive(minimum: 78), spacing: GainsSpacing.xs, alignment: .leading)]

  var body: some View {
    LazyVGrid(columns: columns, alignment: .leading, spacing: GainsSpacing.xs) {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        HStack(spacing: GainsSpacing.xxs) {
          Text(item.label)
            .font(GainsFont.label(10))
          Text("\(item.count)×")
            .font(GainsFont.label(10))
            .foregroundStyle(item.isUnder ? GainsColor.ember : GainsColor.moss)
        }
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
        .padding(.horizontal, GainsSpacing.s)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          Capsule().fill(item.isUnder ? GainsColor.ember.opacity(0.10) : GainsColor.surfaceDeep.opacity(0.7))
        )
        .clipShape(Capsule())
      }
    }
  }
}
