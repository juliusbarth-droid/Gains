import SwiftUI

// MARK: - GymTab

enum GymTab: String, CaseIterable {
  case heute    = "HEUTE"
  case workouts = "WORKOUTS"
  case plan     = "PLAN"
  case stats    = "STATS"
}

// MARK: - GymView

struct GymView: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore

  @State private var selectedTab: GymTab = .heute
  @State private var isShowingWorkoutTracker = false
  @State private var isShowingWorkoutBuilder = false
  @State private var showsFullLibrary = false
  @State private var showsPlanEditor = false

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 20) {

        // ── Header ───────────────────────────────────────────────
        screenHeader(
          eyebrow: "GYM / KRAFT",
          title: gymHeaderTitle
        )

        // ── Tab Picker ───────────────────────────────────────────
        tabPicker

        // ── Tab Content ──────────────────────────────────────────
        switch selectedTab {
        case .heute:    heuteTab
        case .workouts: workoutsTab
        case .plan:     planTab
        case .stats:    statsTab
        }
      }
    }
    .onAppear {
      if let pending = navigation.pendingGymTab {
        selectedTab = pending
        navigation.pendingGymTab = nil
      }
    }
    .onChange(of: navigation.pendingGymTab) { _, pending in
      if let pending {
        selectedTab = pending
        navigation.pendingGymTab = nil
      }
    }
    .sheet(isPresented: $isShowingWorkoutTracker) {
      WorkoutTrackerView()
        .environmentObject(store)
    }
    .sheet(isPresented: $isShowingWorkoutBuilder) {
      WorkoutBuilderView()
        .environmentObject(store)
    }
    .sheet(isPresented: $showsPlanEditor) {
      GymPlanWizardSheet(settings: store.plannerSettings)
        .environmentObject(store)
    }
  }

  // MARK: - Header Title

  private var gymHeaderTitle: String {
    let day = store.todayPlannedDay
    switch day.status {
    case .planned:
      if let run = day.runTemplate {
        return run.title.uppercased()
      }
      return day.workoutPlan?.title.uppercased() ?? day.title.uppercased()
    case .rest:     return "Freier Tag"
    case .flexible: return "Flex Day"
    }
  }

  // MARK: - Tab Picker

  private var tabPicker: some View {
    HStack(spacing: 0) {
      ForEach(GymTab.allCases, id: \.self) { tab in
        Button {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            selectedTab = tab
          }
        } label: {
          Text(tab.rawValue)
            .font(GainsFont.label(10))
            .tracking(1.6)
            .foregroundStyle(selectedTab == tab ? GainsColor.onLime : GainsColor.softInk)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
              selectedTab == tab
                ? GainsColor.lime
                : GainsColor.background.opacity(0.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - HEUTE Tab

  private var heuteTab: some View {
    VStack(alignment: .leading, spacing: 20) {
      if store.activeWorkout != nil {
        liveWorkoutCard
      }
      todayHeroCard
      todayMuscleDosePreview
      wochenpulsCard
      evidenceSummaryCard
    }
  }

  // MARK: - Evidence Summary (Today Tab)

  private var evidenceSummaryCard: some View {
    let setsRange = store.weeklySetsPerMuscleGroupRange
    let reps = store.recommendedRepRange
    let rir = store.recommendedRIRRange
    let freq = store.recommendedFrequencyPerMuscleGroup
    let isCardio = store.plannerSettings.trainingFocus == .cardio
    let kmTarget = store.plannerSettings.weeklyKilometerTarget

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["WISSENSCHAFT", "DOSIS"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Button {
          showsPlanEditor = true
        } label: {
          Text("ANPASSEN")
            .font(GainsFont.label(9))
            .tracking(1.6)
            .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
      }

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
        spacing: 10
      ) {
        evidenceTile(
          label: isCardio ? "WOCHEN-KM" : "VOLUMEN",
          value: isCardio ? "\(kmTarget) km"
            : "\(setsRange.lowerBound)–\(setsRange.upperBound)",
          unit: isCardio ? "Wochenziel"
            : "Sätze / Muskel × Wo."
        )
        evidenceTile(
          label: isCardio ? "VERTEILUNG" : "FREQUENZ",
          value: isCardio
            ? store.plannerSettings.runIntensityModel.title
            : "\(freq)×",
          unit: isCardio ? "Intensitätsmodell" : "pro Muskel"
        )
        evidenceTile(
          label: "REPS / RIR",
          value: "\(reps.lowerBound)–\(reps.upperBound)",
          unit: "RIR \(rir.lowerBound)–\(rir.upperBound)"
        )
        evidenceTile(
          label: "PAUSEN",
          value: "\(store.recommendedRestSecondsCompound)s",
          unit: "Compound · \(store.recommendedRestSecondsIsolation)s Isolation"
        )
      }

      if let note = store.plannerPrimaryRecommendation.evidenceNote {
        HStack(alignment: .top, spacing: 6) {
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
    .padding(16)
    .gainsCardStyle()
  }

  private func evidenceTile(label: String, value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.5)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(unit)
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(GainsColor.background.opacity(0.85))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  // MARK: - WORKOUTS Tab

  private var workoutsTab: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["MEINE", "WORKOUTS"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Button {
          isShowingWorkoutBuilder = true
        } label: {
          Text("+ NEU")
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
      }

      if !store.customWorkoutPlans.isEmpty {
        VStack(spacing: 10) {
          ForEach(store.customWorkoutPlans) { plan in
            libraryWorkoutCard(plan)
          }
        }
      }

      let templates = store.templateWorkoutPlans
      if !templates.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          Text("VORLAGEN")
            .font(GainsFont.label(9))
            .tracking(2.0)
            .foregroundStyle(GainsColor.softInk)
            .padding(.top, store.customWorkoutPlans.isEmpty ? 0 : 4)

          ForEach(showsFullLibrary ? templates : Array(templates.prefix(3))) { plan in
            libraryWorkoutCard(plan)
          }

          if templates.count > 3 {
            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                showsFullLibrary.toggle()
              }
            } label: {
              HStack(spacing: 6) {
                Text(showsFullLibrary ? "Weniger anzeigen" : "\(templates.count - 3) weitere Vorlagen")
                  .font(GainsFont.label(10))
                  .tracking(1.2)
                Image(systemName: showsFullLibrary ? "chevron.up" : "chevron.down")
                  .font(.system(size: 10, weight: .semibold))
              }
              .foregroundStyle(GainsColor.softInk)
              .frame(maxWidth: .infinity)
              .frame(height: 42)
              .background(GainsColor.background.opacity(0.8))
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
      }

      if store.customWorkoutPlans.isEmpty && store.templateWorkoutPlans.isEmpty {
        emptyCard(
          title: "Bibliothek ist leer",
          description: "Erstelle dein erstes eigenes Workout oder nutze eine Vorlage als Startpunkt."
        )
      }
    }
  }

  // MARK: - PLAN Tab

  private var planTab: some View {
    VStack(alignment: .leading, spacing: 22) {
      planStatusCard
      planWeeklyEditor
      planAssignmentsSection
      planVolumePreviewSection
      planRunningSummary
    }
  }

  // ── Plan-Status (Übersicht + Wizard-Button) ─────────────────
  private var planStatusCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      SlashLabel(
        parts: ["PLAN", "STATUS"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.card.opacity(0.72)
      )

      VStack(alignment: .leading, spacing: 8) {
        Text(store.plannerSummaryHeadline)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.card)
          .lineLimit(2)
        Text(store.plannerSummaryDescription)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.card.opacity(0.78))
          .lineLimit(3)
      }

      HStack(spacing: 10) {
        planMetricCell(
          label: "EINHEITEN",
          value: "\(store.trainingDaysCount)",
          sub: "pro Woche")
        planMetricCell(
          label: "DAUER",
          value: "\(store.plannerSettings.preferredSessionLength)",
          sub: "Min")
        planMetricCell(
          label: "FOKUS",
          value: store.plannerSettings.trainingFocus.shortTitle,
          sub: store.plannerSettings.goal.title)
      }

      Button {
        showsPlanEditor = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "wand.and.stars")
            .font(.system(size: 13, weight: .bold))
          Text("Plan-Wizard öffnen")
            .font(GainsFont.label(12))
            .tracking(1.2)
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .opacity(0.7)
        }
        .foregroundStyle(GainsColor.onLime)
        .frame(height: 50)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(GainsColor.lime)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(20)
    .background(GainsColor.ctaSurface)
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.22), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  private func planMetricCell(label: String, value: String, sub: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.4)
        .foregroundStyle(GainsColor.card.opacity(0.55))
      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.card)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(sub)
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.card.opacity(0.7))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(GainsColor.card.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  // ── Trainings/Rest/Flex je Tag (Tap = cycle) ────────────────
  private var planWeeklyEditor: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["WOCHE", "EINTEILEN"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        Text("Tap = Training → Frei → Flex")
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
        spacing: 10
      ) {
        ForEach(Weekday.allCases) { day in
          planDayPreferenceCell(day)
        }
      }
    }
  }

  private func planDayPreferenceCell(_ day: Weekday) -> some View {
    let pref = store.dayPreference(for: day)
    let isToday = day == .today
    let kind = store.plannedSessionKinds[day]

    return Button {
      store.cycleDayPreference(day)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(day.shortLabel)
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.softInk)
          if isToday {
            Spacer()
            Circle()
              .fill(GainsColor.lime)
              .frame(width: 6, height: 6)
          }
        }
        Text(pref.title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        HStack(spacing: 6) {
          Text(day.title)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
          if let kind, kind.isRun {
            Text("LAUF")
              .font(GainsFont.label(8))
              .tracking(1.4)
              .foregroundStyle(GainsColor.moss)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
          }
        }
      }
      .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
      .padding(12)
      .background(planDayCellBackground(pref))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func planDayCellBackground(_ pref: WorkoutDayPreference) -> Color {
    switch pref {
    case .training: return GainsColor.lime.opacity(0.38)
    case .rest:     return GainsColor.background.opacity(0.82)
    case .flexible: return GainsColor.card
    }
  }

  // ── Konkrete Workout-Zuweisungen je Tag ─────────────────────
  private var planAssignmentsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["WORKOUTS", "ZUWEISEN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if store.scheduledPlannerDays.isEmpty {
        emptyCard(
          title: "Noch keine Trainingstage",
          description:
            "Setze oben Tage auf Training oder Flex – dann kannst du jedem Tag ein konkretes Workout zuweisen."
        )
      } else {
        ForEach(store.scheduledPlannerDays) { day in
          planAssignmentRow(for: day)
        }
      }
    }
  }

  private func planAssignmentRow(for day: Weekday) -> some View {
    let assigned    = store.assignedWorkoutPlan(for: day)
    let plannedKind = store.plannedSessionKinds[day]
    let isToday     = day == .today
    let isRunDay    = plannedKind?.isRun == true

    return HStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(isToday ? GainsColor.lime : GainsColor.background.opacity(0.85))
          .frame(width: 38, height: 38)
        if isRunDay {
          Image(systemName: "figure.run")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(isToday ? GainsColor.ink : GainsColor.moss)
        } else {
          Text(day.shortLabel)
            .font(GainsFont.label(10))
            .tracking(1.6)
            .foregroundStyle(isToday ? GainsColor.ink : GainsColor.softInk)
        }
      }

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(day.title)
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
          if isRunDay, let kind = plannedKind {
            Text(kind.shortLabel)
              .font(GainsFont.label(8))
              .tracking(1.4)
              .foregroundStyle(GainsColor.moss)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
          }
        }
        Text(assigned?.title ?? planDefaultAssignmentLabel(for: day, kind: plannedKind))
          .font(GainsFont.body(13))
          .foregroundStyle(assigned == nil ? GainsColor.softInk : GainsColor.moss)
          .lineLimit(1)
      }

      Spacer()

      Menu {
        if isRunDay {
          Section("Lauf-Tag (auto)") {
            Text("Wird aus dem Plan abgeleitet")
          }
        }
        ForEach(store.savedWorkoutPlans) { plan in
          Button(plan.title) { store.assignWorkout(plan, to: day) }
        }
        if assigned != nil {
          Divider()
          Button("Zuweisung entfernen", role: .destructive) {
            store.clearAssignedWorkout(for: day)
          }
        }
      } label: {
        Image(systemName: "ellipsis.circle.fill")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
      }
    }
    .padding(14)
    .gainsCardStyle(isToday ? GainsColor.lime.opacity(0.08) : GainsColor.card)
  }

  private func planDefaultAssignmentLabel(for day: Weekday, kind: PlannedSessionKind?) -> String {
    if let kind {
      if kind.isRun {
        return "Lauf · \(kind.title)"
      }
      return "Auto · \(kind.title)"
    }
    return "Automatisch geplant"
  }

  // ── Lauf-Anteil im Plan (zeigt, dass Run berücksichtigt ist) ─
  private var planRunningSummary: some View {
    let isCardio = store.plannerSettings.trainingFocus != .strength
    let kmTarget = store.plannerSettings.weeklyKilometerTarget

    return VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["LAUFEN", "IM PLAN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if !isCardio && kmTarget == 0 {
        emptyCard(
          title: "Aktuell kein Lauf-Anteil",
          description:
            "Wähle im Wizard einen Hybrid- oder Cardio-Fokus, damit Läufe automatisch in deinen Wochenplan aufgenommen werden."
        )
      } else {
        VStack(alignment: .leading, spacing: 10) {
          HStack(spacing: 10) {
            evidenceTile(
              label: "WOCHEN-KM",
              value: "\(kmTarget) km",
              unit: "Ziel")
            evidenceTile(
              label: "VERTEILUNG",
              value: store.plannerSettings.runIntensityModel.title,
              unit: "Intensität")
          }
          HStack(spacing: 10) {
            evidenceTile(
              label: "LAUFZIEL",
              value: store.plannerSettings.runningGoal.title,
              unit: "\(store.plannerSettings.runningGoal.defaultWeeklyKilometers) km empfohlen")
            evidenceTile(
              label: "FOKUS",
              value: store.plannerSettings.trainingFocus.title,
              unit: "Aktueller Modus")
          }
          Text("Lauf-Tage werden im Wochenplan oben automatisch markiert (figure.run).")
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
  }

  // MARK: - STATS Tab

  private var statsTab: some View {
    VStack(alignment: .leading, spacing: 24) {
      if store.exerciseStrengthProgress.isEmpty && store.workoutHistory.isEmpty {
        emptyCard(
          title: "Noch keine Daten",
          description: "Absolviere dein erstes Training, um Fortschritt und Verlauf zu sehen."
        )
      } else {
        statsSummaryHeader
        if !store.workoutHistory.isEmpty {
          volumeTrendSection
        }
        muscleDistributionSection
        if !store.exerciseStrengthProgress.isEmpty {
          strengthProgressSection
        }
        if !store.workoutHistory.isEmpty {
          historySection
        }
      }
    }
  }

  // MARK: - Today Hero Card

  private var todayHeroCard: some View {
    let today = store.todayPlannedDay
    let plan = today.workoutPlan ?? store.todayPlannedWorkout ?? store.currentWorkoutPreview
    let isLive = store.activeWorkout != nil
    let runTemplate = today.runTemplate
    let isRunDay = runTemplate != nil

    return VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top) {
        SlashLabel(
          parts: [
            isRunDay ? "LAUFEN" : "KRAFT",
            "HEUTE",
            today.weekday.shortLabel,
          ],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.card.opacity(0.62)
        )
        Spacer()
        todayStatusBadge(today.status, isLive: isLive)
      }

      Text(todayHeroTitle(today, plan: plan))
        .font(GainsFont.display(32))
        .foregroundStyle(GainsColor.card)
        .lineLimit(2)
        .minimumScaleFactor(0.78)

      Text(todayHeroSubtitle(today))
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.card.opacity(0.72))
        .lineLimit(2)

      HStack(spacing: 0) {
        switch today.status {
        case .planned:
          if let run = runTemplate {
            gymMetricCell(label: "DISTANZ", value: String(format: "%.1f km", run.targetDistanceKm))
            gymMetricDivider()
            gymMetricCell(label: "DAUER",   value: "\(run.targetDurationMinutes) Min")
            gymMetricDivider()
            gymMetricCell(label: "PACE",    value: run.targetPaceLabel)
          } else {
            gymMetricCell(label: "ÜBUNGEN", value: "\(plan.exercises.count)")
            gymMetricDivider()
            gymMetricCell(label: "DAUER",   value: "\(plan.estimatedDurationMinutes) Min")
            gymMetricDivider()
            gymMetricCell(label: "SPLIT",   value: plan.split)
          }
        case .rest:
          gymMetricCell(label: "WOCHE",   value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)")
          gymMetricDivider()
          gymMetricCell(label: "VOLUMEN", value: String(format: "%.1f t", store.weeklyVolumeTons))
          gymMetricDivider()
          gymMetricCell(label: "STREAK",  value: "\(store.weeklySessionsCompleted)")
        case .flexible:
          gymMetricCell(label: "SESSIONS",value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)")
          gymMetricDivider()
          gymMetricCell(label: "VOLUMEN", value: String(format: "%.1f t", store.weeklyVolumeTons))
          gymMetricDivider()
          gymMetricCell(label: "OPTION",  value: plan.split)
        }
      }
      .background(GainsColor.card.opacity(0.06))
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

      HStack(spacing: 10) {
        Button {
          startOrResumeTodayWorkout()
        } label: {
          HStack(spacing: 10) {
            Image(systemName: isLive ? "play.fill" : (today.status == .rest ? "calendar" : "play.fill"))
              .font(.system(size: 13, weight: .bold))
            Text(isLive ? "Weiter tracken" : (today.status == .rest ? "Wochenplan" : "Training starten"))
              .font(GainsFont.label(12))
              .tracking(1.2)
            Spacer(minLength: 0)
          }
          .foregroundStyle(GainsColor.onLime)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .padding(.horizontal, 14)
          .background(GainsColor.lime)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)

        Button {
          if today.status == .rest {
            selectedTab = .workouts
          } else {
            selectedTab = .plan
          }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: today.status == .rest ? "square.stack.3d.up.fill" : "calendar.badge.plus")
              .font(.system(size: 13, weight: .semibold))
            Text(today.status == .rest ? "Bibliothek" : "Plan")
              .font(GainsFont.label(12))
              .tracking(1.2)
          }
          .foregroundStyle(GainsColor.card)
          .frame(height: 50)
          .frame(minWidth: 100)
          .padding(.horizontal, 16)
          .background(GainsColor.card.opacity(0.1))
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(GainsColor.card.opacity(0.2), lineWidth: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(20)
    .background(GainsColor.ctaSurface)
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.22), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  // MARK: - Live Workout Card

  private var liveWorkoutCard: some View {
    Group {
      if let session = store.activeWorkout {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 8) {
            Circle()
              .fill(GainsColor.lime)
              .frame(width: 8, height: 8)
            Text("LIVE SESSION")
              .font(GainsFont.label(10))
              .tracking(2.0)
              .foregroundStyle(GainsColor.lime)
            Spacer()
            Text(session.focus.uppercased())
              .font(GainsFont.label(9))
              .tracking(1.5)
              .foregroundStyle(GainsColor.moss)
          }

          GeometryReader { geo in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(GainsColor.border.opacity(0.4))
                .frame(height: 6)
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(GainsColor.lime)
                .frame(width: geo.size.width * sessionProgress(session), height: 6)
            }
          }
          .frame(height: 6)

          HStack(spacing: 0) {
            liveStatCell(label: "SÄTZE",   value: "\(session.completedSets)/\(session.totalSets)")
            liveStatDivider()
            liveStatCell(label: "VOLUMEN", value: "\(Int(session.totalVolume)) kg")
            liveStatDivider()
            liveStatCell(label: "ÜBUNGEN", value: "\(session.exercises.count)")
          }
          .background(GainsColor.background.opacity(0.55))
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

          Button {
            isShowingWorkoutTracker = true
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "dumbbell.fill")
                .font(.system(size: 13, weight: .semibold))
              Text("Workout Tracker öffnen")
                .font(GainsFont.label(12))
                .tracking(1.2)
            }
            .foregroundStyle(GainsColor.onLime)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
        }
        .padding(16)
        .background(GainsColor.card)
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(GainsColor.lime.opacity(0.5), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      }
    }
  }

  // MARK: - Week Strip

  private var weekStripSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["WOCHE", "ÜBERBLICK"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Sessions")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(spacing: 6) {
        ForEach(store.weeklyWorkoutSchedule) { day in
          weekDayCell(day)
        }
      }
    }
  }

  private func weekDayCell(_ day: WorkoutDayPlan) -> some View {
    let isCompleted = store.workoutHistory.contains {
      Calendar.current.isDate($0.finishedAt, inSameDayAs: day.weekday.referenceDate)
    }
    let isRun = day.runTemplate != nil

    return VStack(spacing: 6) {
      ZStack {
        Circle()
          .fill(weekDayCellBackground(day, isCompleted: isCompleted))
          .frame(width: 34, height: 34)

        if isCompleted {
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(GainsColor.ink)
        } else if isRun {
          Image(systemName: "figure.run")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(weekDayCellForeground(day))
        } else {
          Text(day.dayLabel)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(weekDayCellForeground(day))
        }
      }

      Text(day.weekday.shortLabel)
        .font(GainsFont.label(8))
        .tracking(0.8)
        .foregroundStyle(day.isToday ? GainsColor.ink : GainsColor.softInk)
        .fontWeight(day.isToday ? .semibold : .regular)
    }
    .frame(maxWidth: .infinity)
  }

  private func weekDayCellBackground(_ day: WorkoutDayPlan, isCompleted: Bool) -> Color {
    if isCompleted { return GainsColor.lime }
    let isRun = day.runTemplate != nil
    switch day.status {
    case .planned:
      if isRun {
        // Cardio-Tage werden bewusst leicht abweichend dargestellt (mossiger Ton).
        return day.isToday ? GainsColor.moss.opacity(0.55) : GainsColor.moss.opacity(0.22)
      }
      return day.isToday ? GainsColor.lime.opacity(0.55) : GainsColor.lime.opacity(0.18)
    case .rest:     return GainsColor.background.opacity(0.7)
    case .flexible: return GainsColor.card
    }
  }

  private func weekDayCellForeground(_ day: WorkoutDayPlan) -> Color {
    switch day.status {
    case .planned:  return day.isToday ? GainsColor.moss : GainsColor.ink
    case .rest:     return GainsColor.softInk.opacity(0.6)
    case .flexible: return GainsColor.softInk
    }
  }

  // MARK: - Library Workout Card (shared)

  private func libraryWorkoutCard(_ plan: WorkoutPlan) -> some View {
    let isActive  = store.activeWorkout?.title == plan.title
    let isBlocked = store.activeWorkout != nil && !isActive

    return HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          workoutSourceBadge(plan.source)
          Text(plan.split.uppercased())
            .font(GainsFont.label(9))
            .tracking(1.5)
            .foregroundStyle(GainsColor.softInk)
        }
        Text(plan.title)
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        Text("\(plan.exercises.count) Übungen · \(plan.estimatedDurationMinutes) Min · \(plan.focus)")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      Button {
        openWorkout(plan)
      } label: {
        Image(systemName: isActive ? "play.fill" : "arrow.right")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(isBlocked ? GainsColor.softInk : GainsColor.onLime)
          .frame(width: 38, height: 38)
          .background(isBlocked ? GainsColor.background : GainsColor.lime)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(isBlocked)
    }
    .padding(16)
    .gainsCardStyle()
  }

  // MARK: - Strength Progress

  private var strengthProgressSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["STÄRKE", "FORTSCHRITT"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
        spacing: 10
      ) {
        ForEach(store.exerciseStrengthProgress) { item in
          VStack(alignment: .leading, spacing: 8) {
            Text(item.exerciseName)
              .font(GainsFont.label(9))
              .tracking(1.4)
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(1)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
              Text(item.currentValue)
                .font(GainsFont.title(20))
                .foregroundStyle(GainsColor.ink)
              Text(item.deltaLabel)
                .font(GainsFont.label(10))
                .foregroundStyle(
                  item.deltaLabel.hasPrefix("+") ? GainsColor.lime : GainsColor.softInk
                )
            }

            Text(item.subtitle)
              .font(GainsFont.body(11))
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .gainsCardStyle()
        }
      }
    }
  }

  // MARK: - History

  private var historySection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["VERLAUF", "ZULETZT"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(store.workoutHistory.count) Workouts")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      VStack(spacing: 10) {
        ForEach(store.workoutHistory.prefix(4)) { workout in
          historyCard(workout)
        }
      }
    }
  }

  private func historyCard(_ workout: CompletedWorkoutSummary) -> some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: "dumbbell.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text(workout.finishedAt.formatted(date: .abbreviated, time: .omitted).uppercased())
            .font(GainsFont.label(9))
            .tracking(1.2)
            .foregroundStyle(GainsColor.softInk)
        }
        Text(workout.title)
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        Text("\(workout.completedSets)/\(workout.totalSets) Sätze · \(Int(workout.volume)) kg Volumen")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer(minLength: 0)

      ZStack {
        Circle()
          .stroke(GainsColor.lime.opacity(0.2), lineWidth: 3)
          .frame(width: 38, height: 38)
        let fraction = workout.totalSets > 0
          ? min(Double(workout.completedSets) / Double(workout.totalSets), 1.0)
          : 0
        Circle()
          .trim(from: 0, to: fraction)
          .stroke(GainsColor.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round))
          .frame(width: 38, height: 38)
          .rotationEffect(.degrees(-90))
        Text("\(Int(fraction * 100))%")
          .font(.system(size: 9, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.moss)
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  // MARK: - Today: Muscle Dose Preview

  private var todayMuscleDosePreview: some View {
    let day = store.todayPlannedDay
    let resolvedPlan = day.workoutPlan ?? store.todayPlannedWorkout
    let isStrengthDay = day.status == .planned && day.runTemplate == nil
    let canShowDose = isStrengthDay && (resolvedPlan?.exercises.isEmpty == false)

    return Group {
      if canShowDose, let plan = resolvedPlan {
        muscleDoseCard(for: plan)
      } else if day.status == .rest {
        regenerationHintCard
      } else {
        EmptyView()
      }
    }
  }

  private func muscleDoseCard(for plan: WorkoutPlan) -> some View {
    let entries = muscleDoseEntries(for: plan)
    let totalSets = plan.exercises.reduce(0) { $0 + $1.sets.count }

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["DOSIS", "HEUTE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(plan.exercises.count) Übungen · \(totalSets) Sätze")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(entries, id: \.muscle) { entry in
            muscleDoseChip(name: entry.muscle, sets: entry.sets)
          }
        }
        .padding(.vertical, 2)
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  private func muscleDoseChip(name: String, sets: Int) -> some View {
    HStack(spacing: 6) {
      Circle()
        .fill(GainsColor.lime)
        .frame(width: 6, height: 6)
      Text(name.uppercased())
        .font(GainsFont.label(10))
        .tracking(1.2)
        .foregroundStyle(GainsColor.ink)
      Text("·")
        .font(GainsFont.label(10))
        .foregroundStyle(GainsColor.softInk)
      Text("\(sets)")
        .font(GainsFont.label(10))
        .tracking(0.6)
        .foregroundStyle(GainsColor.moss)
    }
    .padding(.horizontal, 12)
    .frame(height: 30)
    .background(GainsColor.background.opacity(0.85))
    .clipShape(Capsule())
  }

  private var regenerationHintCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["REGENERATION", "TIPP"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Image(systemName: "leaf.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(GainsColor.moss)
      }
      Text("Schlaf, Eiweiß und 20 Min Spaziergang heute. Regeneration ist Trainingsreiz für morgen.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(16)
    .gainsCardStyle()
  }

  // MARK: - Today: Wochenpuls Card

  private var wochenpulsCard: some View {
    let trend = weeklyVolumeTrend
    let currentVolume = trend.last ?? 0
    let prevVolume = trend.count >= 2 ? trend[trend.count - 2] : 0
    let trendInfo = volumeTrendDelta(current: currentVolume, previous: prevVolume)

    return VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["WOCHE", "PULS"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Sessions")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(alignment: .lastTextBaseline, spacing: 6) {
        Text(String(format: "%.1f", currentVolume / 1000))
          .font(GainsFont.title(28))
          .foregroundStyle(GainsColor.ink)
        Text("t Volumen")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        Text(trendInfo.label)
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(trendInfo.color)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }

      weeklyTrendSparkline(values: trend)

      Rectangle()
        .fill(GainsColor.border.opacity(0.4))
        .frame(height: 1)

      HStack(spacing: 6) {
        ForEach(store.weeklyWorkoutSchedule) { day in
          weekDayCell(day)
        }
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  // MARK: - Stats: Summary Header

  private var statsSummaryHeader: some View {
    let trainings = store.workoutHistory.count
    let totalVolume = store.workoutHistory.reduce(0) { $0 + $1.volume } / 1000
    let totalSets = store.workoutHistory.reduce(0) { $0 + $1.completedSets }

    return LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
      ],
      spacing: 10
    ) {
      statsTile(label: "TRAININGS", value: "\(trainings)", unit: "gesamt")
      statsTile(label: "VOLUMEN", value: String(format: "%.1f t", totalVolume), unit: "lifetime")
      statsTile(label: "SÄTZE", value: "\(totalSets)", unit: "absolviert")
    }
  }

  private func statsTile(label: String, value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.5)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(unit)
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .gainsCardStyle()
  }

  // MARK: - Stats: Volume Trend

  private var volumeTrendSection: some View {
    let values = weeklyVolumeTrend
    let maxVal = max(values.max() ?? 1, 1)

    return VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["VOLUMEN", "TREND"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("Letzte 6 Wochen")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(alignment: .bottom, spacing: 8) {
        ForEach(Array(values.enumerated()), id: \.offset) { idx, val in
          VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(GainsColor.background.opacity(0.6))
                .frame(height: 96)
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(idx == values.count - 1 ? GainsColor.lime : GainsColor.lime.opacity(0.4))
                .frame(height: max(96 * (val / maxVal), 4))
            }
            Text(String(format: "%.1f", val / 1000))
              .font(GainsFont.label(9))
              .tracking(0.6)
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding(.top, 4)

      Text("Werte in t (Tonnen). Engine empfiehlt 4–6-Wochen-Progression MEV → MAV → MRV (Israetel/Helms).")
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(16)
    .gainsCardStyle()
  }

  // MARK: - Stats / Plan: Muscle Distribution

  private var muscleDistributionSection: some View {
    let entries = plannedMuscleSetsThisWeek()
    let target = store.weeklySetsPerMuscleGroupRange
    let maxSets = max(entries.map(\.sets).max() ?? target.upperBound, target.upperBound)

    return Group {
      if entries.isEmpty {
        EmptyView()
      } else {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .firstTextBaseline) {
            SlashLabel(
              parts: ["MUSKEL", "VERTEILUNG"],
              primaryColor: GainsColor.lime,
              secondaryColor: GainsColor.softInk
            )
            Spacer()
            Text("Geplante Sätze · Wo.")
              .font(GainsFont.label(9))
              .tracking(1.2)
              .foregroundStyle(GainsColor.softInk)
          }

          VStack(spacing: 10) {
            ForEach(entries, id: \.muscle) { entry in
              muscleDistributionRow(
                muscle: entry.muscle,
                sets: entry.sets,
                maxSets: maxSets,
                targetRange: target
              )
            }
          }

          HStack(spacing: 14) {
            distributionLegendDot(color: GainsColor.lime, label: "Im Zielbereich")
            distributionLegendDot(color: GainsColor.lime.opacity(0.45), label: "Unter MEV")
            distributionLegendDot(color: GainsColor.ember.opacity(0.7), label: "Über MRV")
          }
        }
        .padding(16)
        .gainsCardStyle()
      }
    }
  }

  private func distributionLegendDot(color: Color, label: String) -> some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
      Text(label)
        .font(GainsFont.body(10))
        .foregroundStyle(GainsColor.softInk)
    }
  }

  private func muscleDistributionRow(
    muscle: String,
    sets: Int,
    maxSets: Int,
    targetRange: ClosedRange<Int>
  ) -> some View {
    let inRange = targetRange.contains(sets)
    let above = sets > targetRange.upperBound
    let barColor: Color = above
      ? GainsColor.ember.opacity(0.7)
      : (inRange ? GainsColor.lime : GainsColor.lime.opacity(0.45))
    let fillRatio = min(Double(sets) / Double(max(maxSets, 1)), 1.0)

    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(muscle.uppercased())
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(GainsColor.ink)
        Spacer()
        Text("\(sets) Sätze")
          .font(GainsFont.label(10))
          .tracking(1.0)
          .foregroundStyle(inRange ? GainsColor.moss : GainsColor.softInk)
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.background.opacity(0.7))
          Capsule()
            .fill(barColor)
            .frame(width: max(geo.size.width * fillRatio, 4))
        }
      }
      .frame(height: 8)
    }
  }

  // MARK: - Plan: Volume Preview

  private var planVolumePreviewSection: some View {
    let entries = plannedMuscleSetsThisWeek()
    let target = store.weeklySetsPerMuscleGroupRange
    let maxSets = max(entries.map(\.sets).max() ?? target.upperBound, target.upperBound)

    return Group {
      if entries.isEmpty {
        EmptyView()
      } else {
        VStack(alignment: .leading, spacing: 12) {
          SlashLabel(
            parts: ["VOLUMEN", "VORSCHAU"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )
          Text("Wochensätze pro Muskelgruppe – aus deinem aktuellen Plan abgeleitet.")
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)

          VStack(spacing: 10) {
            ForEach(entries, id: \.muscle) { entry in
              muscleDistributionRow(
                muscle: entry.muscle,
                sets: entry.sets,
                maxSets: maxSets,
                targetRange: target
              )
            }
          }
        }
        .padding(16)
        .gainsCardStyle()
      }
    }
  }

  // MARK: - Trend & Distribution Helpers

  private struct MuscleDoseEntry {
    let muscle: String
    let sets: Int
  }

  private func muscleDoseEntries(for plan: WorkoutPlan) -> [MuscleDoseEntry] {
    var counts: [String: Int] = [:]
    for ex in plan.exercises {
      counts[ex.targetMuscle, default: 0] += ex.sets.count
    }
    return counts
      .map { MuscleDoseEntry(muscle: $0.key, sets: $0.value) }
      .sorted { $0.sets > $1.sets }
  }

  private func plannedMuscleSetsThisWeek() -> [MuscleDoseEntry] {
    var counts: [String: Int] = [:]
    for day in store.weeklyWorkoutSchedule where day.status == .planned {
      if let plan = day.workoutPlan {
        for ex in plan.exercises {
          counts[ex.targetMuscle, default: 0] += ex.sets.count
        }
      }
    }
    return counts
      .map { MuscleDoseEntry(muscle: $0.key, sets: $0.value) }
      .sorted { $0.sets > $1.sets }
  }

  private var weeklyVolumeTrend: [Double] {
    let calendar = Calendar.current
    let now = Date()
    return (0..<6).reversed().map { weeksAgo in
      let upper = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: now) ?? now
      let lower = calendar.date(byAdding: .day, value: -7 * (weeksAgo + 1), to: now) ?? now
      return store.workoutHistory
        .filter { $0.finishedAt >= lower && $0.finishedAt < upper }
        .reduce(0) { $0 + $1.volume }
    }
  }

  private func weeklyTrendSparkline(values: [Double]) -> some View {
    let maxVal = max(values.max() ?? 1, 1)
    return HStack(alignment: .bottom, spacing: 4) {
      ForEach(Array(values.enumerated()), id: \.offset) { index, value in
        let isLast = index == values.count - 1
        VStack(spacing: 0) {
          Spacer(minLength: 0)
          RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(isLast ? GainsColor.lime : GainsColor.lime.opacity(0.3))
            .frame(height: max(36 * (value / maxVal), 3))
        }
        .frame(maxWidth: .infinity)
      }
    }
    .frame(height: 36)
  }

  private func volumeTrendDelta(current: Double, previous: Double) -> (label: String, color: Color) {
    guard previous > 0 else {
      if current > 0 {
        return ("Erste Daten dieser Woche", GainsColor.softInk)
      }
      return ("Noch keine Trainings", GainsColor.softInk)
    }
    let pct = ((current - previous) / previous) * 100
    if abs(pct) < 1 {
      return ("stabil", GainsColor.softInk)
    } else if pct > 0 {
      return (String(format: "+%.0f %% vs Vorwoche", pct), GainsColor.moss)
    } else {
      return (String(format: "%.0f %% vs Vorwoche", pct), GainsColor.ember)
    }
  }

  // MARK: - Helper Views

  private func todayStatusBadge(_ status: WorkoutDayStatus, isLive: Bool) -> some View {
    let label = isLive ? "LIVE" : (status == .rest ? "REST" : (status == .flexible ? "FLEX" : "PLAN"))
    let bg: Color = isLive ? GainsColor.lime : (status == .rest ? GainsColor.card.opacity(0.18) : GainsColor.lime)
    let fg: Color = isLive ? GainsColor.onLime : (status == .rest ? GainsColor.card.opacity(0.7) : GainsColor.onLime)

    return Text(label)
      .font(GainsFont.label(9))
      .tracking(1.8)
      .foregroundStyle(fg)
      .padding(.horizontal, 12)
      .frame(height: 28)
      .background(bg)
      .clipShape(Capsule())
  }

  private func gymMetricCell(label: String, value: String) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.5)
        .foregroundStyle(GainsColor.card.opacity(0.52))
      Text(value)
        .font(GainsFont.title(16))
        .foregroundStyle(GainsColor.card)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
  }

  private func gymMetricDivider() -> some View {
    Rectangle()
      .fill(GainsColor.card.opacity(0.12))
      .frame(width: 1, height: 28)
  }

  private func liveStatCell(label: String, value: String) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.5)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(16))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
  }

  private func liveStatDivider() -> some View {
    Rectangle()
      .fill(GainsColor.border.opacity(0.4))
      .frame(width: 1, height: 24)
  }

  private func workoutSourceBadge(_ source: WorkoutPlanSource) -> some View {
    Text(source.title.uppercased())
      .font(GainsFont.label(9))
      .tracking(1.6)
      .foregroundStyle(source == .custom ? GainsColor.moss : GainsColor.softInk)
      .padding(.horizontal, 10)
      .frame(height: 22)
      .background(source == .custom ? GainsColor.lime.opacity(0.32) : GainsColor.background.opacity(0.85))
      .clipShape(Capsule())
  }

  private func emptyCard(title: String, description: String) -> some View {
    // A3: Verwendet jetzt den einheitlichen `EmptyStateView`.
    EmptyStateView(
      style: .inline,
      title: title,
      message: description,
      icon: "tray"
    )
  }

  private func sessionProgress(_ session: WorkoutSession) -> Double {
    guard session.totalSets > 0 else { return 0 }
    return min(Double(session.completedSets) / Double(session.totalSets), 1.0)
  }

  // MARK: - Today Content Helpers

  private func todayHeroTitle(_ day: WorkoutDayPlan, plan: WorkoutPlan) -> String {
    switch day.status {
    case .planned:
      if let run = day.runTemplate {
        return run.title.uppercased()
      }
      return plan.title.uppercased()
    case .rest:     return "FREIER TAG"
    case .flexible: return "FLEX DAY"
    }
  }

  private func todayHeroSubtitle(_ day: WorkoutDayPlan) -> String {
    switch day.status {
    case .planned:
      if let kind = day.sessionKind, kind.isRun {
        switch kind {
        case .easyRun:
          return "Easy Run – Puls unter 75 % HFmax. Aerobe Basis (Seiler 2010)."
        case .tempoRun:
          return "Tempo-Lauf – Schwellenpuls 84–88 % HFmax."
        case .intervalRun:
          return "VO₂max Intervalle – kurze, harte Reps mit voller Erholung."
        case .longRun:
          return "Long Run – ruhiger Puls, mehr Volumen für Mitochondrien & Ökonomie."
        case .recoveryRun:
          return "Recovery Run – locker, kurz, Atemfrequenz niedrig halten."
        default:
          return "Lauf-Tag laut Plan."
        }
      }
      return "Dein Plan ist bereit. Starte das Training oder passe es im Plan an."
    case .rest:
      return "Heute bewusst frei – Regeneration ist Training. Oder starte spontan ein Workout."
    case .flexible:
      return "Freier Slot. Nutze ihn für ein optionales Workout oder gönn dir Erholung."
    }
  }

  // MARK: - Actions

  private func startOrResumeTodayWorkout() {
    let today = store.todayPlannedDay
    if today.status == .rest {
      selectedTab = .plan
      return
    }
    // Lauf-Session → Run-Tracker im Run-Tab starten.
    if let runTemplate = today.runTemplate {
      store.startRun(from: runTemplate)
      navigation.openTraining(workspace: .laufen)
      return
    }
    if let plan = store.todayPlannedWorkout {
      openWorkout(plan)
    } else if let fallback = store.savedWorkoutPlans.first {
      openWorkout(fallback)
    } else {
      isShowingWorkoutBuilder = true
    }
  }

  private func openWorkout(_ plan: WorkoutPlan) {
    if store.activeWorkout == nil {
      store.startWorkout(from: plan)
    }
    isShowingWorkoutTracker = true
  }
}

// MARK: - Weekday Reference Date Helper

private extension Weekday {
  var referenceDate: Date {
    let calendar = Calendar.current
    let today = Date()
    let todayWeekday = calendar.component(.weekday, from: today)
    let diff = self.rawValue - todayWeekday
    return calendar.date(byAdding: .day, value: diff, to: today) ?? today
  }
}

// MARK: - GymPlanEditorView

struct GymPlanEditorView: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        screenHeader(
          eyebrow: "GYM / PLAN",
          title: "Wochenplan",
          subtitle: "Setze deine Rahmenbedingungen – die Engine wählt einen studienbasierten Plan."
        )

        plannerMetricsRow
        evidenceCockpitSection
        experienceSection
        equipmentSection
        splitPreferenceSection
        recoverySection
        prioritiesSection
        limitationsSection
        runningSection
        frequencySection
        dayPreferencesSection
        assignmentsSection
      }
    }
    .navigationTitle("Trainingsplan")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Fertig") { dismiss() }
          .foregroundStyle(GainsColor.lime)
      }
    }
  }

  private var plannerMetricsRow: some View {
    HStack(spacing: 10) {
      planCard(label: "EINHEITEN", value: "\(store.trainingDaysCount)", sub: "pro Woche")
      planCard(label: "DAUER",     value: "\(store.plannerSettings.preferredSessionLength)", sub: "Min")
      planCard(label: "ZIEL",      value: store.plannerSettings.goal.title, sub: store.plannerSettings.trainingFocus.shortTitle)
    }
  }

  private func planCard(label: String, value: String, sub: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.5)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(sub)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .gainsCardStyle()
  }

  private var frequencySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["FREQUENZ", "WOCHE"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      HStack(spacing: 10) {
        Button {
          store.updateSessionsPerWeek(store.plannerSettings.sessionsPerWeek - 1)
        } label: {
          Image(systemName: "minus")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 44, height: 44)
            .background(GainsColor.background.opacity(0.85))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!store.canDecreaseSessionsPerWeek)
        .opacity(store.canDecreaseSessionsPerWeek ? 1 : 0.4)

        Text("\(store.plannerSettings.sessionsPerWeek) Trainingstage")
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)
          .frame(maxWidth: .infinity)

        Button {
          store.updateSessionsPerWeek(store.plannerSettings.sessionsPerWeek + 1)
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 44, height: 44)
            .background(GainsColor.background.opacity(0.85))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!store.canIncreaseSessionsPerWeek)
        .opacity(store.canIncreaseSessionsPerWeek ? 1 : 0.4)
      }
      .padding(16)
      .gainsCardStyle()
    }
  }

  private var dayPreferencesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["TAGE", "EINTEILEN"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
        ForEach(Weekday.allCases) { day in
          dayCell(day)
        }
      }

      Text("Tippen zum Wechseln: Training → Frei → Flexibel")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
    }
  }

  private func dayCell(_ day: Weekday) -> some View {
    let pref = store.dayPreference(for: day)
    let isToday = day == .today

    return Button { store.cycleDayPreference(day) } label: {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(day.shortLabel)
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.softInk)
          if isToday {
            Spacer()
            Circle()
              .fill(GainsColor.lime)
              .frame(width: 6, height: 6)
          }
        }
        Text(pref.title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        Text(day.title)
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
      }
      .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
      .padding(12)
      .background(dayCellBackground(pref))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func dayCellBackground(_ pref: WorkoutDayPreference) -> Color {
    switch pref {
    case .training: return GainsColor.lime.opacity(0.38)
    case .rest:     return GainsColor.background.opacity(0.82)
    case .flexible: return GainsColor.card
    }
  }

  private var assignmentsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["WORKOUTS", "ZUWEISEN"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      if store.scheduledPlannerDays.isEmpty {
        EmptyStateView(
          style: .inline,
          title: "Noch keine Trainingstage",
          message: "Setze oben Trainingstage, dann kannst du konkrete Workouts zuweisen.",
          icon: "calendar"
        )
      } else {
        ForEach(store.scheduledPlannerDays) { day in
          assignmentRow(for: day)
        }
      }
    }
  }

  private func assignmentRow(for day: Weekday) -> some View {
    let assigned = store.assignedWorkoutPlan(for: day)
    let isToday  = day == .today
    let plannedKind = store.plannedSessionKinds[day]

    return HStack(spacing: 14) {
      Text(day.shortLabel)
        .font(GainsFont.label(10))
        .tracking(1.8)
        .foregroundStyle(isToday ? GainsColor.ink : GainsColor.softInk)
        .frame(width: 34, height: 34)
        .background(isToday ? GainsColor.lime : GainsColor.background.opacity(0.8))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(day.title)
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
          if let kind = plannedKind, kind != .strength {
            Text(kind.shortLabel)
              .font(GainsFont.label(8))
              .tracking(1.4)
              .foregroundStyle(GainsColor.moss)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
          }
        }
        Text(assigned?.title ?? defaultAssignmentLabel(for: day))
          .font(GainsFont.body(13))
          .foregroundStyle(assigned == nil ? GainsColor.softInk : GainsColor.moss)
          .lineLimit(1)
      }

      Spacer()

      Menu {
        ForEach(store.savedWorkoutPlans) { plan in
          Button(plan.title) { store.assignWorkout(plan, to: day) }
        }
        if assigned != nil {
          Divider()
          Button("Zuweisung entfernen", role: .destructive) {
            store.clearAssignedWorkout(for: day)
          }
        }
      } label: {
        Image(systemName: "ellipsis.circle.fill")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
      }
    }
    .padding(14)
    .gainsCardStyle(isToday ? GainsColor.lime.opacity(0.08) : GainsColor.card)
  }

  private func defaultAssignmentLabel(for day: Weekday) -> String {
    if let kind = store.plannedSessionKinds[day] {
      if kind.isRun {
        return "Lauf · \(kind.title)"
      }
      return "Auto · \(kind.title)"
    }
    return "Automatisch"
  }

  // MARK: - Evidence Cockpit

  private var evidenceCockpitSection: some View {
    let setsRange = store.weeklySetsPerMuscleGroupRange
    let reps = store.recommendedRepRange
    let rir = store.recommendedRIRRange
    let freq = store.recommendedFrequencyPerMuscleGroup

    return VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["WISSENSCHAFT", "DOSIS"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
        cockpitTile(
          label: "VOLUMEN",
          value: "\(setsRange.lowerBound)–\(setsRange.upperBound)",
          unit: "Sätze / Muskel × Wo.")
        cockpitTile(
          label: "FREQUENZ",
          value: "\(freq)×",
          unit: "pro Muskel")
        cockpitTile(
          label: "WIEDERHOLUNGEN",
          value: "\(reps.lowerBound)–\(reps.upperBound)",
          unit: "RIR \(rir.lowerBound)–\(rir.upperBound)")
        cockpitTile(
          label: "PAUSEN",
          value: "\(store.recommendedRestSecondsCompound)s",
          unit: "Compound · \(store.recommendedRestSecondsIsolation)s Isolation")
      }

      Text(store.plannerPrimaryRecommendation.evidenceNote
        ?? "Werte basieren auf Schoenfeld 2017, Helms 2018, Grgic 2018.")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .padding(.top, 2)
    }
  }

  private func cockpitTile(label: String, value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(unit)
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .gainsCardStyle()
  }

  // MARK: - Experience

  private var experienceSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["TRAININGSALTER"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)
      ForEach(TrainingExperience.allCases, id: \.self) { exp in
        plannerRadioRow(
          isSelected: store.plannerSettings.experience == exp,
          title: exp.title,
          subtitle: exp.detail
        ) { store.setTrainingExperience(exp) }
      }
    }
  }

  // MARK: - Equipment

  private var equipmentSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["EQUIPMENT"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
        ForEach(GymEquipment.allCases, id: \.self) { equip in
          plannerChoiceCard(
            title: equip.title,
            subtitle: equip.detail,
            isSelected: store.plannerSettings.equipment == equip
          ) { store.setGymEquipment(equip) }
        }
      }
    }
  }

  // MARK: - Split Preference

  private var splitPreferenceSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["SPLIT", "PRÄFERENZ"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
        ForEach(SplitPreference.allCases, id: \.self) { pref in
          plannerChoiceCard(
            title: pref.title,
            subtitle: pref == .auto ? "Engine wählt nach Frequenz, Erfahrung & Equipment." : "Erzwingt diesen Split.",
            isSelected: store.plannerSettings.splitPreference == pref
          ) { store.setSplitPreference(pref) }
        }
      }
    }
  }

  // MARK: - Recovery

  private var recoverySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["RECOVERY", "KAPAZITÄT"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)
      ForEach(RecoveryCapacity.allCases, id: \.self) { cap in
        plannerRadioRow(
          isSelected: store.plannerSettings.recoveryCapacity == cap,
          title: cap.title,
          subtitle: cap.detail
        ) { store.setRecoveryCapacity(cap) }
      }
    }
  }

  // MARK: - Priorities

  private var prioritiesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["MUSKEL", "PRIORITÄT"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)
      Text("Bekommt + 30 % Volumen pro Woche.")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)

      WrapRow(items: MuscleGroup.allCases.map(\.self)) { muscle in
        let selected = store.plannerSettings.prioritizedMuscles.contains(muscle)
        Button {
          store.toggleMusclePriority(muscle)
        } label: {
          Text(muscle.title)
            .font(GainsFont.label(11))
            .tracking(1.2)
            .foregroundStyle(selected ? GainsColor.onLime : GainsColor.ink)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(selected ? GainsColor.lime : GainsColor.background.opacity(0.85))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Limitations

  private var limitationsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["EINSCHRÄNKUNGEN"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)
      Text("Wir tauschen Übungen automatisch gegen gelenkschonende Alternativen.")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)

      WrapRow(items: WorkoutLimitation.allCases.map(\.self)) { limit in
        let selected = store.plannerSettings.limitations.contains(limit)
        Button {
          store.toggleLimitation(limit)
        } label: {
          HStack(spacing: 6) {
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
              .font(.system(size: 12, weight: .bold))
            Text(limit.title)
              .font(GainsFont.label(11))
              .tracking(1.0)
          }
          .foregroundStyle(selected ? GainsColor.onLime : GainsColor.ink)
          .padding(.horizontal, 14)
          .frame(height: 32)
          .background(selected ? GainsColor.lime : GainsColor.background.opacity(0.85))
          .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }

      let activeHints = store.plannerSettings.limitations.map { $0.hint }
      if !activeHints.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          ForEach(activeHints, id: \.self) { hint in
            HStack(alignment: .top, spacing: 6) {
              Image(systemName: "info.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GainsColor.moss)
              Text(hint)
                .font(GainsFont.body(12))
                .foregroundStyle(GainsColor.softInk)
            }
          }
        }
        .padding(12)
        .gainsCardStyle()
      }
    }
  }

  // MARK: - Running Section

  private var runningSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(parts: ["LAUFEN", "PARAMETER"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      // Ziel
      VStack(alignment: .leading, spacing: 8) {
        Text("ZIEL")
          .font(GainsFont.label(8))
          .tracking(1.5)
          .foregroundStyle(GainsColor.softInk)
        WrapRow(items: RunningGoal.allCases.map(\.self)) { goal in
          let selected = store.plannerSettings.runningGoal == goal
          Button {
            store.setRunningGoal(goal)
          } label: {
            Text(goal.title)
              .font(GainsFont.label(11))
              .tracking(1.2)
              .foregroundStyle(selected ? GainsColor.onLime : GainsColor.ink)
              .padding(.horizontal, 14)
              .frame(height: 32)
              .background(selected ? GainsColor.lime : GainsColor.background.opacity(0.85))
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(14)
      .gainsCardStyle()

      // Intensitätsmodell
      VStack(alignment: .leading, spacing: 10) {
        Text("INTENSITÄTSVERTEILUNG")
          .font(GainsFont.label(8))
          .tracking(1.5)
          .foregroundStyle(GainsColor.softInk)
        ForEach(RunIntensityModel.allCases, id: \.self) { model in
          plannerRadioRow(
            isSelected: store.plannerSettings.runIntensityModel == model,
            title: model.title,
            subtitle: model.detail
          ) { store.setRunIntensityModel(model) }
        }
      }

      // Wochen-Kilometer-Slider
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Text("WOCHENKILOMETER")
            .font(GainsFont.label(8))
            .tracking(1.5)
            .foregroundStyle(GainsColor.softInk)
          Spacer()
          Text("\(store.plannerSettings.weeklyKilometerTarget) km")
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
        }
        let bindingKm = Binding<Double>(
          get: { Double(store.plannerSettings.weeklyKilometerTarget) },
          set: { store.setWeeklyKilometerTarget(Int($0)) }
        )
        Slider(value: bindingKm, in: 0...120, step: 1)
          .tint(GainsColor.lime)
        Text("Polarisiert ≥ 80 % Easy. Ziel skaliert mit Wettkampfdistanz.")
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(14)
      .gainsCardStyle()
    }
  }

  // MARK: - Reusable choice helpers

  private func plannerRadioRow(
    isSelected: Bool,
    title: String,
    subtitle: String,
    onTap: @escaping () -> Void
  ) -> some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.lime : GainsColor.softInk)
        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
          Text(subtitle)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
        }
        Spacer(minLength: 0)
      }
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        isSelected ? GainsColor.lime.opacity(0.10) : GainsColor.card
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(isSelected ? GainsColor.lime.opacity(0.55) : Color.clear, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func plannerChoiceCard(
    title: String,
    subtitle: String,
    isSelected: Bool,
    onTap: @escaping () -> Void
  ) -> some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
        Text(subtitle)
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)
      }
      .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
      .padding(12)
      .background(
        isSelected ? GainsColor.lime.opacity(0.18) : GainsColor.card
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(isSelected ? GainsColor.lime.opacity(0.55) : Color.clear, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - GymPlanWizardSheet

struct GymPlanWizardSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  // ── Wizard Navigation ─────────────────────────────────────────
  @State private var step        = 0
  @State private var goingForward = true

  // ── Wizard Inputs (pre-filled from current settings) ──────────
  @State private var trainingFocus:      WorkoutTrainingFocus
  @State private var goal:               WorkoutPlanningGoal
  @State private var experience:         TrainingExperience
  @State private var equipment:          GymEquipment
  @State private var sessionsPerWeek:    Int
  @State private var sessionLength:      Int
  @State private var recovery:           RecoveryCapacity
  @State private var prioritizedMuscles: Set<MuscleGroup>
  @State private var limitations:        Set<WorkoutLimitation>
  @State private var runningGoal:        RunningGoal

  // ── Step Config ────────────────────────────────────────────────
  private var includesRunStep: Bool { trainingFocus != .strength }
  private var totalSteps: Int      { includesRunStep ? 9 : 8 }
  private var isSummaryStep: Bool  { step == totalSteps }

  init(settings: WorkoutPlannerSettings) {
    _trainingFocus      = State(initialValue: settings.trainingFocus)
    _goal               = State(initialValue: settings.goal)
    _experience         = State(initialValue: settings.experience)
    _equipment          = State(initialValue: settings.equipment)
    _sessionsPerWeek    = State(initialValue: settings.sessionsPerWeek)
    _sessionLength      = State(initialValue: settings.preferredSessionLength)
    _recovery           = State(initialValue: settings.recoveryCapacity)
    _prioritizedMuscles = State(initialValue: settings.prioritizedMuscles)
    _limitations        = State(initialValue: settings.limitations)
    _runningGoal        = State(initialValue: settings.runningGoal)
  }

  // ── Body ───────────────────────────────────────────────────────
  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        VStack(spacing: 0) {
          progressBar
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)

          Text("Schritt \(min(step + 1, totalSteps + 1)) von \(totalSteps + 1)")
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.mutedInk)
            .padding(.bottom, 20)

          ZStack {
            Group {
              switch step {
              case 0: focusStep
              case 1: goalStep
              case 2: experienceStep
              case 3: equipmentStep
              case 4: frequencyStep
              case 5: recoveryStep
              case 6: priorityStep
              case 7: limitationsStep
              case 8 where includesRunStep: runningStep
              default: summaryStep
              }
            }
            .transition(
              .asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                removal:   .move(edge: goingForward ? .leading  : .trailing).combined(with: .opacity)
              )
            )
            .id(step)
          }
          .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

          navigationButtons
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(stepTitle)
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .presentationDetents([.large])
  }

  // MARK: - Progress Bar

  private var progressBar: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(GainsColor.border.opacity(0.4)).frame(height: 4)
        Capsule()
          .fill(GainsColor.lime)
          .frame(width: geo.size.width * (Double(step + 1) / Double(totalSteps + 1)), height: 4)
          .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
      }
    }
    .frame(height: 4)
  }

  private var stepTitle: String {
    switch step {
    case 0: return "Trainingsfokus"
    case 1: return "Ziel"
    case 2: return "Erfahrung"
    case 3: return "Equipment"
    case 4: return "Frequenz & Dauer"
    case 5: return "Erholung"
    case 6: return "Muskelprioritäten"
    case 7: return "Einschränkungen"
    case 8 where includesRunStep: return "Laufziel"
    default: return "Dein optimaler Plan"
    }
  }

  // MARK: - Step 0: Trainingsfokus

  private var focusStep: some View {
    VStack(spacing: 24) {
      wizardHeader(
        title: "Was ist dein Trainingsfokus?",
        subtitle: "Die Engine wählt Split, Volumen und Intensität passend zu deinem Schwerpunkt."
      )
      VStack(spacing: 12) {
        ForEach(WorkoutTrainingFocus.allCases, id: \.self) { f in
          wizardChoiceRow(
            icon: focusIcon(f),
            title: f.title,
            subtitle: f.detail,
            isSelected: trainingFocus == f
          ) { withAnimation(.spring(response: 0.3)) { trainingFocus = f } }
        }
      }
      .padding(.horizontal, 24)
      Spacer()
    }
  }

  // MARK: - Step 1: Ziel

  private var goalStep: some View {
    VStack(spacing: 24) {
      wizardHeader(
        title: "Was ist dein Trainingsziel?",
        subtitle: "Bestimmt Wiederholungsbereich, RIR-Steuerung und Übungsauswahl."
      )
      VStack(spacing: 12) {
        ForEach(WorkoutPlanningGoal.allCases, id: \.self) { g in
          wizardChoiceRow(
            icon: goalIcon(g),
            title: g.title,
            subtitle: goalDetail(g),
            isSelected: goal == g
          ) { withAnimation(.spring(response: 0.3)) { goal = g } }
        }
      }
      .padding(.horizontal, 24)
      Spacer()
    }
  }

  // MARK: - Step 2: Erfahrung

  private var experienceStep: some View {
    VStack(spacing: 24) {
      wizardHeader(
        title: "Wie ist dein Trainingsalter?",
        subtitle: "Beeinflusst Split-Komplexität, Volumen und Intensitätssteuerung."
      )
      VStack(spacing: 12) {
        ForEach(TrainingExperience.allCases, id: \.self) { exp in
          wizardChoiceRow(
            icon: experienceIcon(exp),
            title: exp.title,
            subtitle: exp.detail,
            isSelected: experience == exp
          ) { withAnimation(.spring(response: 0.3)) { experience = exp } }
        }
      }
      .padding(.horizontal, 24)
      Spacer()
    }
  }

  // MARK: - Step 3: Equipment

  private var equipmentStep: some View {
    VStack(spacing: 24) {
      wizardHeader(
        title: "Was steht dir zur Verfügung?",
        subtitle: "Limitiert den Übungspool und die empfohlenen Splits."
      )
      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
        spacing: 12
      ) {
        ForEach(GymEquipment.allCases, id: \.self) { equip in
          wizardGridCard(
            title: equip.title,
            subtitle: equip.detail,
            icon: equipmentIcon(equip),
            isSelected: equipment == equip
          ) { withAnimation(.spring(response: 0.3)) { equipment = equip } }
        }
      }
      .padding(.horizontal, 24)
      Spacer()
    }
  }

  // MARK: - Step 4: Frequenz + Sessiondauer

  private var frequencyStep: some View {
    VStack(spacing: 28) {
      wizardHeader(
        title: "Wie oft und wie lange trainierst du?",
        subtitle: "Tage werden automatisch optimal auf die Woche verteilt – du musst nichts zuweisen."
      )

      VStack(spacing: 14) {
        Text("TRAININGSTAGE PRO WOCHE")
          .font(GainsFont.label(9))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24)

        Text("\(sessionsPerWeek)")
          .font(.system(size: 64, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.lime)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.3), value: sessionsPerWeek)

        HStack(spacing: 12) {
          ForEach(2...6, id: \.self) { n in
            Button {
              withAnimation(.spring(response: 0.3)) { sessionsPerWeek = n }
            } label: {
              Text("\(n)")
                .font(GainsFont.label(15))
                .foregroundStyle(sessionsPerWeek == n ? GainsColor.onLime : GainsColor.ink)
                .frame(width: 48, height: 48)
                .background(sessionsPerWeek == n ? GainsColor.lime : GainsColor.card)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
          }
        }
      }

      VStack(spacing: 14) {
        Text("DAUER PRO EINHEIT")
          .font(GainsFont.label(9))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24)

        HStack(spacing: 8) {
          ForEach([30, 45, 60, 75, 90], id: \.self) { min in
            Button {
              withAnimation(.spring(response: 0.3)) { sessionLength = min }
            } label: {
              VStack(spacing: 4) {
                Text("\(min)")
                  .font(GainsFont.title(20))
                  .foregroundStyle(sessionLength == min ? GainsColor.onLime : GainsColor.ink)
                Text("min")
                  .font(GainsFont.label(9))
                  .tracking(1.0)
                  .foregroundStyle(sessionLength == min ? GainsColor.onLime.opacity(0.8) : GainsColor.softInk)
              }
              .frame(maxWidth: .infinity)
              .frame(height: 62)
              .background(sessionLength == min ? GainsColor.lime : GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 24)
      }

      Spacer()
    }
  }

  // MARK: - Step 5: Recovery

  private var recoveryStep: some View {
    VStack(spacing: 24) {
      wizardHeader(
        title: "Wie erholst du dich aktuell?",
        subtitle: "Fließt als Volumen-Modifier ein. Ehrlichkeit schützt vor Übertraining."
      )
      VStack(spacing: 12) {
        ForEach(RecoveryCapacity.allCases, id: \.self) { cap in
          wizardChoiceRow(
            icon: recoveryIcon(cap),
            title: cap.title,
            subtitle: cap.detail,
            isSelected: recovery == cap
          ) { withAnimation(.spring(response: 0.3)) { recovery = cap } }
        }
      }
      .padding(.horizontal, 24)
      Spacer()
    }
  }

  // MARK: - Step 6: Muskel-Priorität

  private var priorityStep: some View {
    VStack(spacing: 20) {
      wizardHeader(
        title: "Welche Muskeln sollen mehr bekommen?",
        subtitle: "Optional · 0–2 Schwerpunkte · Priorisierte Muskeln erhalten +30 % Sätze pro Woche."
      )

      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: 10),
          GridItem(.flexible(), spacing: 10),
          GridItem(.flexible(), spacing: 10)
        ],
        spacing: 10
      ) {
        ForEach(MuscleGroup.allCases) { muscle in
          let selected = prioritizedMuscles.contains(muscle)
          Button {
            withAnimation(.spring(response: 0.25)) {
              if selected { prioritizedMuscles.remove(muscle) }
              else         { prioritizedMuscles.insert(muscle) }
            }
          } label: {
            VStack(spacing: 6) {
              Text(muscleIcon(muscle))
                .font(.system(size: 28))
              Text(muscle.title)
                .font(GainsFont.label(11))
                .tracking(1.0)
                .foregroundStyle(selected ? GainsColor.onLime : GainsColor.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(selected ? GainsColor.lime : GainsColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 24)

      Text("Überspringen möglich – tippe auf \"Weiter\"")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.mutedInk)

      Spacer()
    }
  }

  // MARK: - Step 7: Einschränkungen

  private var limitationsStep: some View {
    VStack(spacing: 24) {
      wizardHeader(
        title: "Hast du Einschränkungen?",
        subtitle: "Problematische Übungen werden automatisch durch gelenkschonende Alternativen ersetzt."
      )

      VStack(spacing: 10) {
        ForEach(WorkoutLimitation.allCases) { limit in
          let selected = limitations.contains(limit)
          Button {
            withAnimation(.spring(response: 0.25)) {
              if selected { limitations.remove(limit) }
              else         { limitations.insert(limit) }
            }
          } label: {
            HStack(spacing: 14) {
              Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selected ? GainsColor.lime : GainsColor.softInk)
              VStack(alignment: .leading, spacing: 3) {
                Text(limit.title)
                  .font(GainsFont.label(15))
                  .foregroundStyle(GainsColor.ink)
                Text(limit.hint)
                  .font(GainsFont.label(11))
                  .foregroundStyle(GainsColor.softInk)
                  .lineLimit(2)
              }
              Spacer()
            }
            .padding(14)
            .background(selected ? GainsColor.lime.opacity(0.06) : GainsColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                  selected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.5),
                  lineWidth: 1.2
                )
            )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 24)

      Text("Überspringen möglich – tippe auf \"Weiter\"")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.mutedInk)

      Spacer()
    }
  }

  // MARK: - Step 8 (conditional): Laufziel

  private var runningStep: some View {
    VStack(spacing: 24) {
      wizardHeader(
        title: "Was ist dein Laufziel?",
        subtitle: "Bestimmt empfohlene Wochenkilometer und die Intensitätsverteilung im Plan."
      )
      VStack(spacing: 12) {
        ForEach(RunningGoal.allCases, id: \.self) { rg in
          wizardChoiceRow(
            icon: runningGoalIcon(rg),
            title: rg.title,
            subtitle: runningGoalDetail(rg),
            isSelected: runningGoal == rg
          ) { withAnimation(.spring(response: 0.3)) { runningGoal = rg } }
        }
      }
      .padding(.horizontal, 24)
      Spacer()
    }
  }

  // MARK: - Summary Step

  private var summaryStep: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 16) {
        wizardHeader(
          title: "Dein optimaler Plan",
          subtitle: "Die Engine hat deinen Plan auf Basis aktueller Sportwissenschaft berechnet."
        )

        // ── Plan-Überblick ──────────────────────────────────────
        VStack(spacing: 14) {
          summaryRow(icon: "rectangle.split.3x1",   label: "Split",         value: autoSplitName)
          Divider().background(GainsColor.border)
          summaryRow(icon: "calendar",              label: "Trainingstage", value: "\(sessionsPerWeek)× pro Woche")
          Divider().background(GainsColor.border)
          summaryRow(icon: "clock",                 label: "Session-Dauer", value: "\(sessionLength) Min")
          Divider().background(GainsColor.border)
          summaryRow(icon: "target",                label: "Fokus",         value: "\(trainingFocus.title) · \(goal.title)")
        }
        .padding(18)
        .gainsCardStyle(GainsColor.card)
        .padding(.horizontal, 24)

        // ── Wissenschaftliche Parameter ─────────────────────────
        VStack(alignment: .leading, spacing: 0) {
          Text("WISSENSCHAFTLICHE PARAMETER")
            .font(GainsFont.label(9))
            .tracking(1.6)
            .foregroundStyle(GainsColor.softInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 12)

          LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
          ) {
            summaryMetricTile(
              label: "VOLUMEN",
              value: "\(autoSetsRange.lowerBound)–\(autoSetsRange.upperBound)",
              unit: "Sätze / Muskel × Wo.")
            summaryMetricTile(
              label: "FREQUENZ",
              value: "\(autoFrequency)×",
              unit: "pro Muskelgruppe")
            summaryMetricTile(
              label: "REPS / RIR",
              value: "\(autoRepRange.lowerBound)–\(autoRepRange.upperBound)",
              unit: "RIR \(autoRIRRange.lowerBound)–\(autoRIRRange.upperBound)")
            summaryMetricTile(
              label: "PAUSEN",
              value: "\(autoRestCompound)s",
              unit: "Compound · \(autoRestIsolation)s Isolation")
          }
          .padding(.horizontal, 14)
          .padding(.bottom, 16)
        }
        .gainsCardStyle(GainsColor.card)
        .padding(.horizontal, 24)

        // ── Lauf-Karte (nur wenn relevant) ─────────────────────
        if includesRunStep {
          VStack(spacing: 12) {
            summaryRow(icon: "figure.run",  label: "Laufziel",    value: runningGoal.title)
            Divider().background(GainsColor.border)
            summaryRow(icon: "road.lanes",  label: "Empfohlen",   value: "\(runningGoal.defaultWeeklyKilometers) km / Woche")
          }
          .padding(18)
          .gainsCardStyle(GainsColor.card)
          .padding(.horizontal, 24)
        }

        // ── Profil-Chips ────────────────────────────────────────
        VStack(spacing: 8) {
          profileChip("\(experience.title) · \(equipment.title)")
          profileChip(recovery.title + " Recovery")
          if !prioritizedMuscles.isEmpty {
            profileChip("Priorität: \(prioritizedMuscles.map(\.title).sorted().joined(separator: ", "))")
          }
          if !limitations.isEmpty {
            profileChip("Einschr.: \(limitations.map(\.title).sorted().joined(separator: ", "))")
          }
        }
        .padding(.horizontal, 24)

        Text("Quellen: Schoenfeld 2017, Helms 2018, Grgic 2018 · Wochentage werden automatisch verteilt")
          .font(.system(size: 10))
          .foregroundStyle(GainsColor.mutedInk)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)

        Spacer(minLength: 8)
      }
    }
  }

  // MARK: - Auto-Berechnungen (spiegeln die Store-Logik)

  private var autoSplitName: String {
    let light = equipment == .bodyweight || equipment == .dumbbellsOnly
    switch sessionsPerWeek {
    case ...1: return "Ganzkörper"
    case 2:    return light ? "Ganzkörper × 2"     : "Upper / Lower"
    case 3:
      if experience == .beginner || light { return "Ganzkörper × 3" }
      return "Push / Pull / Legs"
    case 4: return light ? "Ganzkörper × 4" : "Upper / Lower × 2"
    case 5:
      if experience == .advanced && !light { return "PPL + Upper / Lower" }
      return "Upper / Lower + Ganzkörper"
    case 6: return "Push / Pull / Legs × 2"
    default: return "High-Frequency"
    }
  }

  private var autoSetsRange: ClosedRange<Int> {
    let base: ClosedRange<Int>
    switch experience {
    case .beginner:     base = 8...12
    case .intermediate: base = 12...18
    case .advanced:     base = 16...22
    }
    let m = recovery.volumeMultiplier
    let lo = max(6,       Int(round(Double(base.lowerBound) * m)))
    let hi = max(lo + 2,  Int(round(Double(base.upperBound) * m)))
    return lo...hi
  }

  private var autoFrequency: Int { experience == .advanced ? 3 : 2 }

  private var autoRepRange: ClosedRange<Int> {
    switch goal {
    case .muscleGain:  return experience == .beginner ? 8...12 : 6...12
    case .fatLoss:     return 8...15
    case .performance: return experience == .beginner ? 5...8  : 3...6
    }
  }

  private var autoRIRRange: ClosedRange<Int> {
    switch goal {
    case .muscleGain:  return experience == .advanced ? 0...2 : 1...3
    case .fatLoss:     return 1...2
    case .performance: return 0...2
    }
  }

  private var autoRestCompound: Int {
    switch goal {
    case .muscleGain:  return 150
    case .fatLoss:     return 90
    case .performance: return 240
    }
  }

  private var autoRestIsolation: Int {
    switch goal {
    case .muscleGain:  return 90
    case .fatLoss:     return 60
    case .performance: return 120
    }
  }

  // MARK: - Navigation Buttons

  private var navigationButtons: some View {
    HStack(spacing: 12) {
      if step > 0 {
        Button {
          goingForward = false
          withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step -= 1 }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "chevron.left")
            Text("Zurück")
          }
          .font(GainsFont.label(15))
          .foregroundStyle(GainsColor.softInk)
          .frame(height: 54)
          .frame(maxWidth: .infinity)
          .background(GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
      }

      Button {
        if isSummaryStep {
          applySettings()
          dismiss()
        } else {
          goingForward = true
          withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step += 1 }
        }
      } label: {
        HStack(spacing: 6) {
          Text(isSummaryStep ? "Plan übernehmen" : "Weiter")
          Image(systemName: isSummaryStep ? "checkmark" : "chevron.right")
        }
        .font(GainsFont.label(15))
        .foregroundStyle(GainsColor.onLime)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .background(GainsColor.lime)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Apply Settings

  private func applySettings() {
    store.applyWizardSettings(
      focus:              trainingFocus,
      goal:               goal,
      experience:         experience,
      equipment:          equipment,
      sessionsPerWeek:    sessionsPerWeek,
      sessionLength:      sessionLength,
      recovery:           recovery,
      prioritizedMuscles: prioritizedMuscles,
      limitations:        limitations,
      runningGoal:        runningGoal
    )
  }

  // MARK: - Reusable View Helpers

  private func wizardHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
      Text(subtitle)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 24)
  }

  private func wizardChoiceRow(
    icon: String,
    title: String,
    subtitle: String,
    isSelected: Bool,
    onTap: @escaping () -> Void
  ) -> some View {
    Button(action: onTap) {
      HStack(spacing: 14) {
        Text(icon)
          .font(.system(size: 22))
          .frame(width: 44, height: 44)
          .background(isSelected ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
          Text(subtitle)
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(GainsColor.lime)
        }
      }
      .padding(14)
      .background(isSelected ? GainsColor.lime.opacity(0.06) : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(
            isSelected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.5),
            lineWidth: 1.2
          )
      )
    }
    .buttonStyle(.plain)
  }

  private func wizardGridCard(
    title: String,
    subtitle: String,
    icon: String,
    isSelected: Bool,
    onTap: @escaping () -> Void
  ) -> some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 8) {
        Text(icon)
          .font(.system(size: 28))
        Text(title)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
        Text(subtitle)
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)
      }
      .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
      .padding(14)
      .background(isSelected ? GainsColor.lime.opacity(0.18) : GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(isSelected ? GainsColor.lime.opacity(0.55) : Color.clear, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func summaryRow(icon: String, label: String, value: String) -> some View {
    HStack {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.moss)
        .frame(width: 22)
      Text(label)
        .font(GainsFont.label(13))
        .foregroundStyle(GainsColor.softInk)
      Spacer()
      Text(value)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(GainsColor.ink)
    }
  }

  private func summaryMetricTile(label: String, value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.5)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(unit)
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(GainsColor.background.opacity(0.85))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func profileChip(_ text: String) -> some View {
    Text(text)
      .font(GainsFont.label(12))
      .foregroundStyle(GainsColor.softInk)
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .background(GainsColor.elevated)
      .clipShape(Capsule())
  }

  // MARK: - Icon Helpers

  private func focusIcon(_ f: WorkoutTrainingFocus) -> String {
    switch f {
    case .strength: return "🏋️"
    case .cardio:   return "🏃"
    case .hybrid:   return "⚡️"
    }
  }

  private func goalIcon(_ g: WorkoutPlanningGoal) -> String {
    switch g {
    case .muscleGain:  return "💪"
    case .fatLoss:     return "🔥"
    case .performance: return "🎯"
    }
  }

  private func goalDetail(_ g: WorkoutPlanningGoal) -> String {
    switch g {
    case .muscleGain:  return "Muskelaufbau · Hypertrophie-Reps, moderates Volumen."
    case .fatLoss:     return "Fettabbau · Höhere Reps, kürzere Pausen, mehr Ausdauer."
    case .performance: return "Kraft & Leistung · Niedrige Reps, lange Pausen, maximale Last."
    }
  }

  private func experienceIcon(_ exp: TrainingExperience) -> String {
    switch exp {
    case .beginner:     return "🌱"
    case .intermediate: return "💫"
    case .advanced:     return "🔱"
    }
  }

  private func equipmentIcon(_ equip: GymEquipment) -> String {
    switch equip {
    case .fullGym:        return "🏟️"
    case .homeGymBarbell: return "🏠"
    case .dumbbellsOnly:  return "🏋️"
    case .bodyweight:     return "🤸"
    }
  }

  private func recoveryIcon(_ cap: RecoveryCapacity) -> String {
    switch cap {
    case .low:    return "😴"
    case .medium: return "😊"
    case .high:   return "⚡️"
    }
  }

  private func muscleIcon(_ muscle: MuscleGroup) -> String {
    switch muscle {
    case .chest:     return "🫁"
    case .back:      return "🔙"
    case .shoulders: return "🎽"
    case .arms:      return "💪"
    case .legs:      return "🦵"
    case .core:      return "🎯"
    }
  }

  private func runningGoalIcon(_ rg: RunningGoal) -> String {
    switch rg {
    case .general:      return "🏃"
    case .fiveK:        return "5️⃣"
    case .tenK:         return "🔟"
    case .halfMarathon: return "🥈"
    case .marathon:     return "🏅"
    }
  }

  private func runningGoalDetail(_ rg: RunningGoal) -> String {
    "\(rg.title) · ~\(rg.defaultWeeklyKilometers) km/Woche empfohlen"
  }
}

// MARK: - Simple wrapping flow row

/// Minimal flow-layout helper. Wir teilen die Items in Reihen vorgegebener
/// maximaler Spaltenanzahl auf – das reicht für die kurzen Chip-Listen
/// in der Editor-UI und vermeidet komplexes Layout.
private struct WrapRow<Item: Hashable, Content: View>: View {
  let items: [Item]
  let columns: Int
  let content: (Item) -> Content

  init(items: [Item], columns: Int = 3, @ViewBuilder content: @escaping (Item) -> Content) {
    self.items = items
    self.columns = max(1, columns)
    self.content = content
  }

  private var rows: [[Item]] {
    stride(from: 0, to: items.count, by: columns).map { start in
      Array(items[start..<min(start + columns, items.count)])
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(0..<rows.count, id: \.self) { index in
        HStack(spacing: 8) {
          ForEach(rows[index], id: \.self) { item in
            content(item)
          }
          Spacer(minLength: 0)
        }
      }
    }
  }
}
