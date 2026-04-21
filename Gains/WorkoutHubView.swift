import SwiftUI

private enum WorkoutWorkspace: String, CaseIterable, Identifiable {
  case kraft
  case laufen
  case fortschritt

  init(appWorkspace: AppWorkoutWorkspace) {
    switch appWorkspace {
    case .kraft:
      self = .kraft
    case .laufen:
      self = .laufen
    case .fortschritt:
      self = .fortschritt
    }
  }

  var appWorkspace: AppWorkoutWorkspace {
    switch self {
    case .kraft:
      return .kraft
    case .laufen:
      return .laufen
    case .fortschritt:
      return .fortschritt
    }
  }

  var id: Self { self }

  var title: String {
    switch self {
    case .kraft:
      return "Krafttraining"
    case .laufen:
      return "Kardiotraining"
    case .fortschritt:
      return "Verlauf"
    }
  }

  var systemImage: String {
    switch self {
    case .kraft:
      return "dumbbell.fill"
    case .laufen:
      return "figure.run"
    case .fortschritt:
      return "chart.xyaxis.line"
    }
  }
}

private enum HistorySurface: String, CaseIterable, Identifiable {
  case all
  case workouts
  case runs

  var id: Self { self }

  var title: String {
    switch self {
    case .all:
      return "Alle"
    case .workouts:
      return "Workouts"
    case .runs:
      return "Läufe"
    }
  }
}

private enum HistoryEntry: Identifiable {
  case workout(CompletedWorkoutSummary)
  case run(CompletedRunSummary)

  var id: String {
    switch self {
    case .workout(let workout):
      return "workout-\(workout.id.uuidString)"
    case .run(let run):
      return "run-\(run.id.uuidString)"
    }
  }

  var date: Date {
    switch self {
    case .workout(let workout):
      return workout.finishedAt
    case .run(let run):
      return run.finishedAt
    }
  }
}

struct WorkoutHubView: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore
  let viewModel: WorkoutHubViewModel
  @State private var isShowingWorkoutTracker = false
  @State private var isShowingRunTracker = false
  @State private var isShowingWorkoutBuilder = false
  @State private var selectedWorkspace: WorkoutWorkspace = .kraft
  @State private var selectedHistorySurface: HistorySurface = .all
  @State private var showsTrainingLibrary = false
  @State private var showsWeeklyPlan = true

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        quickStartSection
        screenHeader(
          eyebrow: "WORKOUT / TRAINING",
          title: "Dein Workout-Bereich",
          subtitle: viewModel.subtitle
        )

        workspacePicker
        workspaceHero
        workspaceContent
      }
    }
    .onAppear {
      selectedWorkspace = WorkoutWorkspace(appWorkspace: navigation.preferredWorkoutWorkspace)
    }
    .onChange(of: navigation.preferredWorkoutWorkspace) { _, workspace in
      selectedWorkspace = WorkoutWorkspace(appWorkspace: workspace)
    }
    .sheet(isPresented: $isShowingWorkoutTracker) {
      WorkoutTrackerView()
        .environmentObject(store)
    }
    .sheet(isPresented: $isShowingWorkoutBuilder) {
      WorkoutBuilderView()
        .environmentObject(store)
    }
    .sheet(isPresented: $isShowingRunTracker) {
      RunTrackerView()
        .environmentObject(store)
    }
  }

  private var workspacePicker: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["WORKOUT", "BEREICHE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(WorkoutWorkspace.allCases) { workspace in
            Button {
              selectedWorkspace = workspace
              navigation.preferredWorkoutWorkspace = workspace.appWorkspace
            } label: {
              workspaceCard(for: workspace)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 2)
      }
    }
  }

  private var quickStartSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      screenHeader(
        eyebrow: "WORKOUT / TRAINING",
        title: "Heute wirklich nutzbar",
        subtitle:
          "Starte dein Gym-Workout, springe in Cardio oder öffne deinen Verlauf, ohne dich erst durch alle Bereiche zu kämpfen."
      )

      quickTrainingSummaryRow

      HStack(spacing: 10) {
        quickStartCard(
          title: store.activeWorkout == nil ? "Gym starten" : "Workout fortsetzen",
          subtitle: store.activeWorkout == nil
            ? (store.todayPlannedWorkout?.title ?? store.currentWorkoutPreview.title)
            : "Aktive Session öffnen",
          systemImage: "dumbbell.fill",
          accent: GainsColor.lime,
          action: {
            navigation.preferredWorkoutWorkspace = .kraft
            selectedWorkspace = .kraft
            startOrResumeTodayWorkout()
          }
        )

        quickStartCard(
          title: store.activeRun == nil ? "Run starten" : "Run fortsetzen",
          subtitle: store.activeRun == nil ? "Kardiotraining direkt öffnen" : "Live-Run öffnen",
          systemImage: "figure.run",
          accent: GainsColor.moss,
          action: {
            navigation.preferredWorkoutWorkspace = .laufen
            selectedWorkspace = .laufen
            startOrResumeRun()
          }
        )
      }
    }
  }

  private var workspaceHero: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: selectedWorkspace.systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(GainsColor.moss)

        Text(selectedWorkspace.title)
          .font(GainsFont.title(26))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
      }

      Text(workspaceSubtitle)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
    .padding(18)
    .gainsCardStyle(GainsColor.lime.opacity(0.14))
  }

  @ViewBuilder
  private var workspaceContent: some View {
    switch selectedWorkspace {
    case .kraft:
      kraftWorkspace
    case .laufen:
      runningWorkspace
    case .fortschritt:
      historyWorkspace
    }
  }

  private var kraftWorkspace: some View {
    VStack(alignment: .leading, spacing: 22) {
      trainingFocusHeader
      plannerStatusCard
      overviewSection
      todaySection
      plannerSection
      assignedWorkoutsSection
      collapsibleTrainingSection(
        title: "Wochenplan",
        subtitle: "Split und Trainingstage im Zusammenhang sehen",
        isExpanded: $showsWeeklyPlan,
        content: { weeklyPlanSection }
      )
      evidenceSection

      if let activeWorkout = store.activeWorkout {
        liveSection(activeWorkout)
      }

      exercisePreviewSection
      quickJumpSection
      collapsibleTrainingSection(
        title: "Workout-Bibliothek",
        subtitle: "Eigene und vorgefertigte Workouts gesammelt statt alles sofort offen",
        isExpanded: $showsTrainingLibrary,
        content: {
          VStack(alignment: .leading, spacing: 22) {
            ownWorkoutsSection
            templateWorkoutsSection
          }
        }
      )
    }
  }

  private var runningWorkspace: some View {
    VStack(alignment: .leading, spacing: 22) {
      evidenceSection
      runningSummarySection
      runningStarterSection
      runningInsightSection

      if store.activeRun != nil {
        runningLiveSection
      }

      runningTemplatesSection
      runningRecordsSection
      runningHistorySection
    }
  }

  @ViewBuilder
  private var evidenceSection: some View {
    if let recommendation = store.studyBackedRecommendations.first {
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["STUDIEN", "BASIS"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        VStack(alignment: .leading, spacing: 14) {
          Text(recommendation.title)
            .font(GainsFont.title(22))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)

          Text(recommendation.scenario)
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.moss)
            .lineLimit(1)

          VStack(alignment: .leading, spacing: 8) {
            ForEach(recommendation.sources) { source in
              HStack {
                Text(source.title)
                  .font(GainsFont.label(10))
                  .tracking(1.5)
                  .foregroundStyle(GainsColor.ink)
                  .lineLimit(1)
                Spacer()
              }
              .padding(12)
              .background(GainsColor.background.opacity(0.75))
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
          }
        }
        .padding(18)
        .gainsCardStyle()
      }
    }
  }

  private var runningInsightSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["RUN", "INSIGHTS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 14) {
        Text(store.latestRunAchievement)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)

        HStack(spacing: 10) {
          plannerMetricCard(
            title: "30 Tage", value: String(format: "%.1f km", store.monthlyRunDistanceKm),
            subtitle: "Volumen")
          plannerMetricCard(
            title: "Ø Pace", value: runPaceLabel(store.averageRunPaceSeconds), subtitle: "7 Tage")
        }

        if let latestRun = store.latestCompletedRun {
          Button {
            store.startRunLike(latestRun)
            isShowingRunTracker = true
          } label: {
            Text(store.activeRun == nil ? "Letzten Lauf erneut starten" : "Aktiven Lauf fortsetzen")
              .font(GainsFont.label(11))
              .tracking(1.4)
              .foregroundStyle(store.activeRun == nil ? GainsColor.lime : GainsColor.softInk)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .background(store.activeRun == nil ? GainsColor.ink : GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(store.activeRun != nil)
          .opacity(store.activeRun == nil ? 1 : 0.5)
        }
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var libraryWorkspace: some View {
    VStack(alignment: .leading, spacing: 22) {
      creationSection
      ownWorkoutsSection
      templateWorkoutsSection
    }
  }

  private var quickTrainingSummaryRow: some View {
    HStack(spacing: 10) {
      plannerMetricCard(
        title: "Heute", value: store.todayPlannedWorkout?.split ?? "Frei", subtitle: "Fokus")
      plannerMetricCard(
        title: "Woche", value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)", subtitle: "Sessions")
      plannerMetricCard(
        title: "Läufe", value: "\(store.weeklyRunCount)", subtitle: "7 Tage")
    }
  }

  private var workspaceSubtitle: String {
    switch selectedWorkspace {
    case .kraft:
      return "Heute trainieren, Woche planen und Workouts klarer verwalten."
    case .laufen:
      return "Runs, Templates und Fortschritt kompakter und schneller erfassbar."
    case .fortschritt:
      return "Workouts und Läufe in einem Verlauf, ohne unnötigen Ballast."
    }
  }

  private var trainingFocusHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["HEUTE", "TRAINING"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 10) {
        Text(store.plannerSummaryHeadline)
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)

        Text("Plan, heutiges Workout und Bibliothek greifen hier jetzt klarer ineinander.")
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var historyWorkspace: some View {
    VStack(alignment: .leading, spacing: 22) {
      historyOverviewSection
      historySection
    }
  }

  private var overviewSection: some View {
    HStack(spacing: 10) {
      plannerMetricCard(
        title: "Heute", value: store.todayPlannedWorkout?.split ?? "Frei", subtitle: "Tagesfokus")
      plannerMetricCard(
        title: "Woche", value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)", subtitle: "Sessions")
      Button {
        selectedWorkspace = .fortschritt
      } label: {
        plannerMetricCard(
          title: "Erreicht", value: "+\(store.personalRecordCount)", subtitle: "PRs")
      }
      .buttonStyle(.plain)
    }
  }

  private var runningSummarySection: some View {
    HStack(spacing: 10) {
      Button {
        selectedWorkspace = .fortschritt
      } label: {
        plannerMetricCard(
          title: "Distanz", value: String(format: "%.1f km", store.weeklyRunDistanceKm),
          subtitle: "7 Tage")
      }
      .buttonStyle(.plain)

      Button {
        selectedWorkspace = .fortschritt
      } label: {
        plannerMetricCard(title: "Läufe", value: "\(store.weeklyRunCount)", subtitle: "Woche")
      }
      .buttonStyle(.plain)

      Button {
        startOrResumeRun()
      } label: {
        plannerMetricCard(
          title: "Best Pace", value: runPaceLabel(store.bestRunPaceSeconds), subtitle: "PB")
      }
      .buttonStyle(.plain)
    }
  }

  private var runningStarterSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["RUN", "START"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 10) {
        Text(store.runningHeadline)
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)

        Text(store.runningDescription)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)

        HStack(spacing: 10) {
          Button {
            startOrResumeRun()
          } label: {
            Text(store.activeRun == nil ? "Lauf starten" : "Lauf weiter tracken")
              .font(GainsFont.label(12))
              .tracking(1.6)
              .foregroundStyle(GainsColor.lime)
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .background(GainsColor.ink)
              .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)

          Button {
            store.shareLatestRun()
          } label: {
            Text("Teilen")
              .font(GainsFont.label(12))
              .tracking(1.6)
              .foregroundStyle(GainsColor.ink)
              .frame(width: 96, height: 48)
              .background(GainsColor.lime)
              .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var runningLiveSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["LIVE", "RUN"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      if let activeRun = store.activeRun {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 12) {
            workoutStatCard(
              title: "Distanz", value: String(format: "%.1f", activeRun.distanceKm), subtitle: "km")
            workoutStatCard(
              title: "Pace", value: runPaceLabel(activeRun.averagePaceSeconds), subtitle: "pro km")
            workoutStatCard(title: "Puls", value: "\(activeRun.currentHeartRate)", subtitle: "bpm")
          }

          HStack(spacing: 10) {
            Button {
              store.addRunSplit()
            } label: {
              Text("Split +")
                .font(GainsFont.label(11))
                .tracking(1.4)
                .foregroundStyle(GainsColor.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(GainsColor.lime)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
              isShowingRunTracker = true
            } label: {
              Text("Tracker öffnen")
                .font(GainsFont.label(11))
                .tracking(1.4)
                .foregroundStyle(GainsColor.lime)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(GainsColor.ink)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var runningTemplatesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["RUN", "VORLAGEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ForEach(store.runningTemplates) { template in
        VStack(alignment: .leading, spacing: 14) {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: template.systemImage)
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(GainsColor.moss)
              .frame(width: 42, height: 42)
              .background(GainsColor.lime.opacity(0.24))
              .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
              Text(template.title)
                .font(GainsFont.title(20))
                .foregroundStyle(GainsColor.ink)

              Text(template.subtitle)
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()
          }

          HStack(spacing: 10) {
            plannerMetricCard(
              title: "Strecke", value: String(format: "%.1f km", template.targetDistanceKm),
              subtitle: template.routeName)
            plannerMetricCard(
              title: "Ziel", value: "\(template.targetDurationMinutes) Min",
              subtitle: template.targetPaceLabel)
          }

          Button {
            store.startRun(from: template)
            isShowingRunTracker = true
          } label: {
            Text("Diesen Lauf starten")
              .font(GainsFont.label(11))
              .tracking(1.4)
              .foregroundStyle(GainsColor.lime)
              .frame(maxWidth: .infinity)
              .frame(height: 42)
              .background(GainsColor.ink)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(store.activeRun != nil)
          .opacity(store.activeRun == nil ? 1 : 0.45)
        }
        .padding(16)
        .gainsCardStyle()
      }
    }
  }

  private var runningRecordsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["STRAVA", "STYLE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if store.runPersonalBests.isEmpty {
        emptyWorkoutLibraryCard(
          title: "Noch keine Lauf-Records",
          description:
            "Sobald du deine ersten Läufe speicherst, tauchen hier Bestzeiten und längste Runs auf."
        )
      } else {
        ForEach(store.runPersonalBests) { best in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(best.title)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)

              Text(best.context)
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()

            Text(best.value)
              .font(GainsFont.title(20))
              .foregroundStyle(GainsColor.moss)
          }
          .padding(16)
          .gainsCardStyle()
        }
      }
    }
  }

  private var runningHistorySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["RUN", "HISTORY"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      if store.runHistory.isEmpty {
        emptyWorkoutLibraryCard(
          title: "Noch keine Läufe gespeichert",
          description:
            "Starte deinen ersten Lauf und Gains baut dir hier direkt deine Historie auf."
        )
      } else {
        ForEach(store.runHistory.prefix(4)) { run in
          VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                Text(run.title)
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)

                Text(
                  "\(String(format: "%.1f", run.distanceKm)) km · \(runPaceLabel(run.averagePaceSeconds)) · \(run.averageHeartRate) bpm"
                )
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)

                Text(run.routeName)
                  .font(GainsFont.label(9))
                  .tracking(1.6)
                  .foregroundStyle(GainsColor.moss)
              }

              Spacer()

              Text(run.finishedAt, style: .date)
                .font(GainsFont.label(9))
                .foregroundStyle(GainsColor.softInk)
            }

            HStack(spacing: 10) {
              Button {
                store.startRunLike(run)
                isShowingRunTracker = true
              } label: {
                Text("Erneut laufen")
                  .font(GainsFont.label(10))
                  .tracking(1.4)
                  .foregroundStyle(store.activeRun == nil ? GainsColor.lime : GainsColor.softInk)
                  .frame(maxWidth: .infinity)
                  .frame(height: 40)
                  .background(store.activeRun == nil ? GainsColor.ink : GainsColor.card)
                  .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
              }
              .buttonStyle(.plain)
              .disabled(store.activeRun != nil)
              .opacity(store.activeRun == nil ? 1 : 0.5)

              Button {
                store.shareLatestRun()
              } label: {
                Text("Teilen")
                  .font(GainsFont.label(10))
                  .tracking(1.4)
                  .foregroundStyle(GainsColor.ink)
                  .frame(width: 88, height: 40)
                  .background(GainsColor.lime)
                  .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
              }
              .buttonStyle(.plain)
            }
          }
          .padding(16)
          .gainsCardStyle()
        }
      }
    }
  }

  private var planningFocusSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["PLAN", "SETUP"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 10) {
        Text("Plane deine Woche in Ruhe")
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)

        Text(
          "Lege Frequenz, freie Tage und Session-Länge fest. Eigene Trainingspläne verwaltest du separat im Bereich Workouts."
        )
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)

        Button {
          selectedWorkspace = .kraft
        } label: {
          Text("ZU DEINEN WORKOUTS")
            .font(GainsFont.label(12))
            .tracking(1.6)
            .foregroundStyle(GainsColor.lime)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(GainsColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var plannerStatusCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["PLANER", "STATUS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 10) {
        Text(store.plannerSummaryHeadline)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        Text(store.plannerSummaryDescription)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)
      }
      .padding(18)
      .gainsCardStyle(GainsColor.lime.opacity(0.28))
    }
  }

  private var assignedWorkoutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["WORKOUTS", "ZUWEISEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if store.scheduledPlannerDays.isEmpty {
        emptyWorkoutLibraryCard(
          title: "Noch keine Trainingstage geplant",
          description:
            "Stelle zuerst Trainingstage oder flexible Tage im Planer ein. Danach kannst du konkrete Workouts einzelnen Tagen zuweisen."
        )
      } else {
        ForEach(store.scheduledPlannerDays) { day in
          assignedWorkoutCard(for: day)
        }
      }
    }
  }

  private var creationSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["ERSTELLEN", "WORKOUT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 10) {
        Text("Baue dir eigene Trainingspläne")
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)

        Text(
          "Erstelle Upper-, Lower- oder Push/Pull/Beine-Workouts, wähle Übungen aus und speichere alles direkt in deiner Workout-Bibliothek."
        )
        .font(GainsFont.body())
        .foregroundStyle(GainsColor.softInk)

        Button {
          isShowingWorkoutBuilder = true
        } label: {
          Text("WORKOUT ERSTELLEN")
            .font(GainsFont.label(12))
            .tracking(1.8)
            .foregroundStyle(GainsColor.lime)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(GainsColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var todaySection: some View {
    let today = store.todayPlannedDay

    return VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["HEUTE", "GEPLANT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 8) {
            Text(today.title.uppercased())
              .font(GainsFont.display(28))
              .foregroundStyle(GainsColor.ink)

            if let plan = today.workoutPlan {
              Text(
                "\(plan.exercises.count) Übungen · \(store.plannerSettings.preferredSessionLength) Min · \(plan.focus)"
              )
              .font(GainsFont.body())
              .foregroundStyle(GainsColor.softInk)
            } else {
              Text(today.focus)
                .font(GainsFont.body())
                .foregroundStyle(GainsColor.softInk)
            }
          }

          Spacer()

          if today.workoutPlan != nil {
            Button(action: startOrResumeTodayWorkout) {
              Text(store.activeWorkout == nil ? "START →" : "WEITER →")
                .font(GainsFont.label())
                .tracking(1.4)
                .foregroundStyle(GainsColor.lime)
                .frame(width: 110, height: 46)
                .background(GainsColor.ink)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }

        Text(todayHeadline(for: today))
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(18)
      .gainsCardStyle(todayCardBackground(for: today))
    }
  }

  private func liveSection(_ workout: WorkoutSession) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["SESSION", "LIVE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      HStack(spacing: 12) {
        workoutStatCard(
          title: "Sätze", value: "\(workout.completedSets)/\(workout.totalSets)",
          subtitle: "erledigt")
        workoutStatCard(title: "Volumen", value: "\(Int(workout.totalVolume))", subtitle: "kg")
        workoutStatCard(title: "Fokus", value: workout.focus, subtitle: "heute")
      }
    }
  }

  private var ownWorkoutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center) {
        SlashLabel(
          parts: ["EIGENE", "WORKOUTS"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()

        Button {
          isShowingWorkoutBuilder = true
        } label: {
          Text("NEU")
            .font(GainsFont.label(10))
            .tracking(2)
            .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
      }

      if store.customWorkoutPlans.isEmpty {
        emptyWorkoutLibraryCard(
          title: "Noch keine eigenen Workouts",
          description:
            "Erstelle dir hier dein erstes eigenes Upper-, Lower- oder Push/Pull/Beine-Workout."
        )
      } else {
        ForEach(store.customWorkoutPlans) { plan in
          savedWorkoutCard(plan)
        }
      }
    }
  }

  private var templateWorkoutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["VORGEFERTIGT", "WORKOUTS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ForEach(store.templateWorkoutPlans) { plan in
        savedWorkoutCard(plan)
      }
    }
  }

  private func savedWorkoutCard(_ plan: WorkoutPlan) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          Text(plan.title)
            .font(GainsFont.title(22))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)

          Text("\(plan.split) · \(plan.focus)")
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 8) {
          workoutSourceBadge(plan.source)

          Text("\(plan.exercises.count) Übungen")
            .font(GainsFont.label(10))
            .tracking(1.4)
            .foregroundStyle(GainsColor.moss)
        }
      }

      HStack(spacing: 10) {
        plannerMetricCard(
          title: "Dauer", value: "\(plan.estimatedDurationMinutes) Min", subtitle: "Session")
        plannerMetricCard(
          title: "Übungen", value: "\(plan.exercises.count)", subtitle: "im Plan")
      }
      .padding(12)
      .background(GainsColor.lime.opacity(0.12))
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

      Text(exerciseSummary(for: plan))
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(3)

      HStack(spacing: 10) {
        Menu {
          ForEach(store.scheduledPlannerDays) { day in
            Button("\(day.title) zuweisen") {
              store.assignWorkout(plan, to: day)
            }
          }
        } label: {
          Text("Einplanen")
            .font(GainsFont.label(10))
            .tracking(1.3)
            .foregroundStyle(GainsColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }

        Button {
          openWorkout(plan)
        } label: {
          Text(actionTitle(for: plan))
            .font(GainsFont.label(11))
            .tracking(1.3)
            .foregroundStyle(
              isWorkoutButtonDisabled(for: plan) ? GainsColor.softInk : GainsColor.lime
            )
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(
              isWorkoutButtonDisabled(for: plan)
                ? GainsColor.background.opacity(0.7) : GainsColor.ink
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isWorkoutButtonDisabled(for: plan))
      }
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func assignedWorkoutCard(for day: Weekday) -> some View {
    let assignedWorkout = store.assignedWorkoutPlan(for: day)
    let effectiveWorkout =
      assignedWorkout
      ?? store.weeklyWorkoutSchedule.first(where: { $0.weekday == day })?.workoutPlan

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(day.title)
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)

          Text(
            assignedWorkout == nil ? "Automatisch aus deinem Split" : "Fix für diesen Tag gesetzt"
          )
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        }

        Spacer()

        Text(day.shortLabel)
          .font(GainsFont.label(10))
          .tracking(2)
          .foregroundStyle(GainsColor.moss)
      }

      if let effectiveWorkout {
        VStack(alignment: .leading, spacing: 6) {
          Text(effectiveWorkout.title)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)

          Text(
            "\(effectiveWorkout.split) · \(effectiveWorkout.exercises.count) Übungen · \(effectiveWorkout.focus)"
          )
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        }
      } else {
        Text("Für diesen Tag ist noch kein konkretes Workout hinterlegt.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(spacing: 10) {
        Menu {
          ForEach(store.savedWorkoutPlans) { plan in
            Button(plan.title) {
              store.assignWorkout(plan, to: day)
            }
          }

          if assignedWorkout != nil {
            Divider()

            Button("Zuweisung lösen") {
              store.clearAssignedWorkout(for: day)
            }
          }
        } label: {
          Text("Workout wählen")
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(GainsColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }

        if day == .today, let effectiveWorkout {
          Button {
            openWorkout(effectiveWorkout)
          } label: {
            Text("Heute starten")
              .font(GainsFont.label(11))
              .tracking(1.4)
              .foregroundStyle(GainsColor.lime)
              .frame(maxWidth: .infinity)
              .frame(height: 42)
              .background(GainsColor.ink)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  private func emptyWorkoutLibraryCard(title: String, description: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)

      Text(description)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(3)
    }
    .padding(16)
    .gainsCardStyle()
  }

  private var exercisePreviewSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["HEUTE", "ÜBUNGEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if let previewPlan = store.todayPlannedWorkout {
        ForEach(previewPlan.exercises.prefix(4)) { exercise in
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(exercise.name)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)

              Text("\(exercise.sets.count) Sätze · \(exercise.targetMuscle)")
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()

            Text(exercise.sets.map { "\($0.reps)" }.joined(separator: " / "))
              .font(GainsFont.label())
              .foregroundStyle(GainsColor.moss)
          }
          .padding(16)
          .gainsCardStyle()
        }
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Heute ist kein Workout fix eingeplant")
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)
        }
        .padding(16)
        .gainsCardStyle()
      }
    }
  }

  private var quickJumpSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["SCHNELL", "WEITER"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(spacing: 10) {
        HStack(spacing: 10) {
          quickJumpButton(title: "Laufen", subtitle: "Run-Bereich öffnen") {
            selectedWorkspace = .laufen
          }

          quickJumpButton(title: "Trainingsplaner", subtitle: "Woche einstellen") {
            selectedWorkspace = .kraft
          }
        }

        HStack(spacing: 10) {
          quickJumpButton(title: "Workouts", subtitle: "Pläne öffnen") {
            selectedWorkspace = .kraft
          }

          quickJumpButton(title: "Verlauf", subtitle: "Sessions prüfen") {
            selectedWorkspace = .fortschritt
          }
        }
      }
    }
  }

  private func collapsibleTrainingSection<Content: View>(
    title: String,
    subtitle: String,
    isExpanded: Binding<Bool>,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Button {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
          isExpanded.wrappedValue.toggle()
        }
      } label: {
        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 6) {
            Text(title)
              .font(GainsFont.title(20))
              .foregroundStyle(GainsColor.ink)

            Text(subtitle)
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(2)
          }

          Spacer()

          Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 34, height: 34)
            .background(GainsColor.card)
            .clipShape(Circle())
        }
        .padding(18)
        .gainsCardStyle()
      }
      .buttonStyle(.plain)

      if isExpanded.wrappedValue {
        content()
      }
    }
  }

  private var weeklyPlanSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["SPLIT", "WOCHE"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      ForEach(store.weeklyWorkoutSchedule) { day in
        HStack {
          Text(day.dayLabel)
            .font(GainsFont.label(10))
            .tracking(2)
            .foregroundStyle(day.isToday ? GainsColor.ink : GainsColor.softInk)
            .frame(width: 36, height: 36)
            .background(day.isToday ? GainsColor.lime : GainsColor.background.opacity(0.7))
            .clipShape(Circle())

          VStack(alignment: .leading, spacing: 4) {
            Text(day.title)
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.ink)

            Text(day.focus)
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.softInk)
          }

          Spacer()

          if day.isToday {
            Text("Heute")
              .font(GainsFont.label(9))
              .tracking(1.8)
              .foregroundStyle(GainsColor.moss)
          }
        }
        .padding(16)
        .gainsCardStyle(backgroundForWeekdayCard(day))
      }
    }
  }

  private var historyOverviewSection: some View {
    HStack(spacing: 10) {
      plannerMetricCard(
        title: "Workouts", value: "\(store.workoutHistory.count)", subtitle: "insgesamt")
      plannerMetricCard(title: "Läufe", value: "\(store.runHistory.count)", subtitle: "gespeichert")
      plannerMetricCard(
        title: "Woche", value: "\(store.weeklySessionsCompleted)", subtitle: "absolviert")
    }
  }

  private var historySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["HISTORY", "RECENT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(HistorySurface.allCases) { surface in
            Button {
              selectedHistorySurface = surface
            } label: {
              Text(surface.title)
                .font(GainsFont.label(10))
                .tracking(1.5)
                .foregroundStyle(
                  selectedHistorySurface == surface ? GainsColor.ink : GainsColor.softInk
                )
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(selectedHistorySurface == surface ? GainsColor.lime : GainsColor.card)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }

      if filteredHistoryEntries.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Noch kein Verlauf in diesem Bereich")
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)

          Text("Sobald du Läufe oder Workouts abschließt, erscheinen sie hier in deinem Verlauf.")
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(16)
        .gainsCardStyle()
      } else {
        ForEach(filteredHistoryEntries.prefix(10)) { entry in
          historyEntryCard(entry)
        }
      }
    }
  }

  private var filteredHistoryEntries: [HistoryEntry] {
    switch selectedHistorySurface {
    case .all:
      return
        (store.workoutHistory.map(HistoryEntry.workout) + store.runHistory.map(HistoryEntry.run))
        .sorted(by: { $0.date > $1.date })
    case .workouts:
      return store.workoutHistory.map(HistoryEntry.workout)
    case .runs:
      return store.runHistory.map(HistoryEntry.run)
    }
  }

  private func historyEntryCard(_ entry: HistoryEntry) -> some View {
    HStack(spacing: 14) {
      Circle()
        .fill(entryAccent(entry).opacity(0.18))
        .frame(width: 42, height: 42)
        .overlay {
          Image(systemName: entryIcon(entry))
            .foregroundStyle(entryAccent(entry))
        }

      VStack(alignment: .leading, spacing: 4) {
        Text(entryTitle(entry))
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)

        Text(entrySubtitle(entry))
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      Text(entry.date, style: .date)
        .font(GainsFont.label(9))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(16)
    .gainsCardStyle()
  }

  private func entryTitle(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout(let workout):
      return workout.title
    case .run(let run):
      return run.title
    }
  }

  private func entrySubtitle(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout(let workout):
      return
        "\(workout.completedSets)/\(workout.totalSets) Sätze · \(Int(workout.volume)) kg Volumen"
    case .run(let run):
      return
        "\(String(format: "%.1f", run.distanceKm)) km · \(runPaceLabel(run.averagePaceSeconds)) · \(run.averageHeartRate) bpm"
    }
  }

  private func entryIcon(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout:
      return "dumbbell.fill"
    case .run:
      return "figure.run"
    }
  }

  private func entryAccent(_ entry: HistoryEntry) -> Color {
    switch entry {
    case .workout:
      return GainsColor.lime
    case .run:
      return Color(hex: "7AB6A7")
    }
  }

  private func workoutStatCard(title: String, value: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Text(subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
    .padding(14)
    .gainsCardStyle()
  }

  private var plannerSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 16) {
        Text("Plane deine Woche")
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)

        HStack(spacing: 10) {
          plannerMetricCard(
            title: "Einheiten", value: "\(store.trainingDaysCount)", subtitle: "pro Woche")
          plannerMetricCard(
            title: "Zugewiesen", value: "\(store.plannerAssignedDaysCount)", subtitle: "mit Workout"
          )
          plannerMetricCard(
            title: "Dauer", value: "\(store.plannerSettings.preferredSessionLength)",
            subtitle: "Min")
        }

        HStack(spacing: 12) {
          Button {
            store.updateSessionsPerWeek(store.plannerSettings.sessionsPerWeek - 1)
          } label: {
            plannerStepperButton(systemImage: "minus")
          }
          .buttonStyle(.plain)
          .disabled(!store.canDecreaseSessionsPerWeek)
          .opacity(store.canDecreaseSessionsPerWeek ? 1 : 0.45)

          VStack(alignment: .leading, spacing: 4) {
            Text("Trainingsfrequenz")
              .font(GainsFont.label(10))
              .tracking(1.8)
              .foregroundStyle(GainsColor.softInk)

            Text("\(store.plannerSettings.sessionsPerWeek) Tage geplant")
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.ink)
          }

          Spacer()

          Button {
            store.updateSessionsPerWeek(store.plannerSettings.sessionsPerWeek + 1)
          } label: {
            plannerStepperButton(systemImage: "plus")
          }
          .buttonStyle(.plain)
          .disabled(!store.canIncreaseSessionsPerWeek)
          .opacity(store.canIncreaseSessionsPerWeek ? 1 : 0.45)
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("Priorität")
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.softInk)

          VStack(spacing: 8) {
            ForEach(WorkoutTrainingFocus.allCases, id: \.self) { focus in
              plannerPriorityCard(
                focus: focus,
                isSelected: store.plannerSettings.trainingFocus == focus
              ) {
                store.setTrainingFocus(focus)
              }
            }
          }
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("Ziel")
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.softInk)

          HStack(spacing: 8) {
            ForEach(WorkoutPlanningGoal.allCases, id: \.self) { goal in
              plannerChip(
                title: goal.title,
                isSelected: store.plannerSettings.goal == goal
              ) {
                store.setPlannerGoal(goal)
              }
            }
          }
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("Optimaler Wochenansatz")
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.softInk)

          VStack(spacing: 10) {
            ForEach(store.plannerRecommendations) { recommendation in
              VStack(alignment: .leading, spacing: 8) {
                Text(recommendation.title)
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)

                Text(recommendation.detail)
                  .font(GainsFont.body(13))
                  .foregroundStyle(GainsColor.softInk)
                  .lineLimit(2)

                Text(recommendation.weekdays.map(\.shortLabel).joined(separator: " · "))
                  .font(GainsFont.label(10))
                  .tracking(1.8)
                  .foregroundStyle(GainsColor.moss)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(14)
              .gainsCardStyle(GainsColor.background.opacity(0.82))
            }
          }
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("Session-Länge")
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.softInk)

          HStack(spacing: 8) {
            ForEach([45, 60, 75, 90], id: \.self) { duration in
              plannerChip(
                title: "\(duration) Min",
                isSelected: store.plannerSettings.preferredSessionLength == duration
              ) {
                store.setPreferredSessionLength(duration)
              }
            }
          }
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("Trainings- und freie Tage")
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.softInk)

          let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
          LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Weekday.allCases) { day in
              plannerDayCard(day)
            }
          }
        }
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private func startOrResumeRun() {
    if store.activeRun == nil {
      store.startQuickRun()
    }
    isShowingRunTracker = true
  }

  private func startOrResumeTodayWorkout() {
    if let todayPlan = store.todayPlannedWorkout {
      openWorkout(todayPlan)
    }
  }

  private func openWorkout(_ plan: WorkoutPlan) {
    if store.activeWorkout == nil {
      store.startWorkout(from: plan)
    }
    isShowingWorkoutTracker = true
  }

  private func isWorkoutButtonDisabled(for plan: WorkoutPlan) -> Bool {
    guard let activeWorkout = store.activeWorkout else { return false }
    return activeWorkout.title != plan.title
  }

  private func actionTitle(for plan: WorkoutPlan) -> String {
    guard let activeWorkout = store.activeWorkout else { return "STARTEN →" }
    return activeWorkout.title == plan.title ? "WEITER →" : "LIVE"
  }

  private func exerciseSummary(for plan: WorkoutPlan) -> String {
    let preview = plan.exercises.prefix(3).map(\.name).joined(separator: " · ")
    let remainingExercises = plan.exercises.count - min(plan.exercises.count, 3)

    if remainingExercises > 0 {
      return "\(preview) + \(remainingExercises) mehr"
    }

    return preview
  }

  private func todayHeadline(for day: WorkoutDayPlan) -> String {
    switch day.status {
    case .planned:
      return viewModel.headline
    case .rest:
      return
        "Heute ist als freier Tag geplant. Fokus auf Recovery, Schritte und entspanntes Dranbleiben."
    case .flexible:
      return
        "Heute ist flexibel. Du kannst spontan Cardio, Mobility oder ein zusätzliches Workout einbauen."
    }
  }

  private func todayCardBackground(for day: WorkoutDayPlan) -> Color {
    switch day.status {
    case .planned:
      return GainsColor.card
    case .rest:
      return GainsColor.background.opacity(0.9)
    case .flexible:
      return GainsColor.lime.opacity(0.22)
    }
  }

  private func backgroundForWeekdayCard(_ day: WorkoutDayPlan) -> Color {
    switch day.status {
    case .planned:
      return day.isToday ? GainsColor.lime.opacity(0.4) : GainsColor.card
    case .rest:
      return GainsColor.background.opacity(0.85)
    case .flexible:
      return GainsColor.lime.opacity(0.18)
    }
  }

  private func plannerMetricCard(title: String, value: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .gainsCardStyle(GainsColor.background.opacity(0.8))
  }

  private func workspaceCard(for workspace: WorkoutWorkspace) -> some View {
    let isSelected = selectedWorkspace == workspace
    let titleColor = GainsColor.ink
    let iconColor = isSelected ? GainsColor.moss : GainsColor.softInk
    let backgroundColor = isSelected ? GainsColor.lime : GainsColor.card

    return VStack(alignment: .leading, spacing: 8) {
      Image(systemName: workspace.systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(iconColor)

      Text(workspace.title)
        .font(GainsFont.title(16))
        .foregroundStyle(titleColor)
    }
    .frame(width: 154)
    .frame(minHeight: 84, alignment: .leading)
    .padding(14)
    .background(backgroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  private func quickStartCard(
    title: String,
    subtitle: String,
    systemImage: String,
    accent: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(accent == GainsColor.lime ? GainsColor.moss : GainsColor.ink)
          .frame(width: 42, height: 42)
          .background(accent.opacity(accent == GainsColor.lime ? 0.24 : 0.88))
          .clipShape(Circle())

        Text(title)
          .font(GainsFont.title(19))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        Text(subtitle)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(2)

        Spacer(minLength: 0)

        Text("Direkt öffnen")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.moss)
      }
      .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
      .padding(16)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
  }

  private func runPaceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:-- /km" }
    let minutes = seconds / 60
    let seconds = seconds % 60
    return String(format: "%d:%02d /km", minutes, seconds)
  }

  private func quickJumpButton(title: String, subtitle: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
      }
      .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
      .padding(14)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
  }

  private func workoutSourceBadge(_ source: WorkoutPlanSource) -> some View {
    Text(source.title.uppercased())
      .font(GainsFont.label(9))
      .tracking(1.6)
      .foregroundStyle(source == .custom ? GainsColor.moss : GainsColor.softInk)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(
        source == .custom ? GainsColor.lime.opacity(0.35) : GainsColor.background.opacity(0.85)
      )
      .clipShape(Capsule())
  }

  private func plannerStepperButton(systemImage: String) -> some View {
    Image(systemName: systemImage)
      .font(.system(size: 14, weight: .bold))
      .foregroundStyle(GainsColor.ink)
      .frame(width: 38, height: 38)
      .background(GainsColor.background.opacity(0.85))
      .clipShape(Circle())
  }

  private func plannerChip(title: String, isSelected: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Text(title)
        .font(GainsFont.label(11))
        .tracking(1.2)
        .foregroundStyle(isSelected ? GainsColor.ink : GainsColor.softInk)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .background(isSelected ? GainsColor.lime : GainsColor.background.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func plannerPriorityCard(
    focus: WorkoutTrainingFocus, isSelected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(focus.title)
            .font(GainsFont.title(16))
            .foregroundStyle(isSelected ? GainsColor.ink : GainsColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

          Text(focus.detail)
            .font(GainsFont.body(13))
            .foregroundStyle(isSelected ? GainsColor.ink.opacity(0.84) : GainsColor.softInk)
            .lineLimit(2)
        }

        Spacer()

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.ink : GainsColor.softInk)
      }
      .padding(14)
      .background(isSelected ? GainsColor.lime : GainsColor.background.opacity(0.75))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func plannerDayCard(_ day: Weekday) -> some View {
    let preference = store.dayPreference(for: day)
    let isScheduled = store.isScheduledWorkoutDay(day)
    let assignedWorkout = store.assignedWorkoutPlan(for: day)

    return Button {
      store.cycleDayPreference(day)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        Text(day.shortLabel)
          .font(GainsFont.label(10))
          .tracking(2)
          .foregroundStyle(GainsColor.softInk)

        Text(day.title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.7)

        Text(preference.title)
          .font(GainsFont.body(12))
          .foregroundStyle(preferenceAccent(preference))

        Text(plannerDayStatusText(for: preference, isScheduled: isScheduled))
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(plannerDayStatusColor(for: preference, isScheduled: isScheduled))

        if isScheduled {
          Text(assignedWorkout?.title ?? "Automatisch geplant")
            .font(GainsFont.label(9))
            .tracking(1.2)
            .foregroundStyle(assignedWorkout == nil ? GainsColor.softInk : GainsColor.moss)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 98, alignment: .leading)
      .padding(12)
      .background(preferenceBackground(preference))
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func preferenceBackground(_ preference: WorkoutDayPreference) -> Color {
    switch preference {
    case .training:
      return GainsColor.lime.opacity(0.42)
    case .rest:
      return GainsColor.background.opacity(0.85)
    case .flexible:
      return GainsColor.card
    }
  }

  private func preferenceAccent(_ preference: WorkoutDayPreference) -> Color {
    switch preference {
    case .training:
      return GainsColor.moss
    case .rest:
      return GainsColor.softInk
    case .flexible:
      return GainsColor.ink
    }
  }

  private func plannerDayStatusText(for preference: WorkoutDayPreference, isScheduled: Bool)
    -> String
  {
    switch preference {
    case .training:
      return "Fest eingeplant"
    case .rest:
      return "Bewusst frei"
    case .flexible:
      return isScheduled ? "Flexibel genutzt" : "Optional offen"
    }
  }

  private func plannerDayStatusColor(for preference: WorkoutDayPreference, isScheduled: Bool)
    -> Color
  {
    switch preference {
    case .training:
      return GainsColor.moss
    case .rest:
      return GainsColor.softInk
    case .flexible:
      return isScheduled ? GainsColor.moss : GainsColor.softInk
    }
  }
}

struct WorkoutBuilderView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  var onSaved: ((WorkoutPlan) -> Void)? = nil

  @State private var workoutName = ""
  @State private var selectedSplit = "Upper"
  @State private var searchText = ""
  @State private var selectedExercises: [ExerciseLibraryItem] = []

  private let splitOptions = ["Upper", "Lower", "Push", "Pull", "Beine", "Ganzkörper"]
  private let splitColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

  private var filteredExercises: [ExerciseLibraryItem] {
    let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedSearch.isEmpty else { return store.exerciseLibrary }

    return store.exerciseLibrary.filter { exercise in
      exercise.name.localizedCaseInsensitiveContains(trimmedSearch)
        || exercise.primaryMuscle.localizedCaseInsensitiveContains(trimmedSearch)
        || exercise.equipment.localizedCaseInsensitiveContains(trimmedSearch)
    }
  }

  private var canSave: Bool {
    !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !selectedExercises.isEmpty
  }

  var body: some View {
    NavigationStack {
      GainsScreen {
        VStack(alignment: .leading, spacing: 22) {
          screenHeader(
            eyebrow: "WORKOUT / ERSTELLEN",
            title: "Eigenes Training",
            subtitle:
              "Benenne dein Workout, wähle Übungen aus und speichere es direkt in deiner Bibliothek."
          )

          nameSection
          splitSection
          selectedExercisesSection
          searchSection
          librarySection
          saveButton
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Schließen") {
            dismiss()
          }
          .foregroundStyle(GainsColor.ink)
        }
      }
    }
  }

  private var nameSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      SlashLabel(
        parts: ["NAME", "WORKOUT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 8) {
        Text("Wie soll dein Training heißen?")
          .font(GainsFont.title(20))
          .foregroundStyle(GainsColor.ink)

        TextField("z. B. Upper A oder Push Fokus Brust", text: $workoutName)
          .textInputAutocapitalization(.words)
          .autocorrectionDisabled()
          .font(GainsFont.body())
          .padding(.horizontal, 14)
          .frame(height: 50)
          .background(GainsColor.background.opacity(0.8))
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var splitSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      SlashLabel(
        parts: ["SPLIT", "AUSWÄHLEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      LazyVGrid(columns: splitColumns, spacing: 10) {
        ForEach(splitOptions, id: \.self) { option in
          Button {
            selectedSplit = option
          } label: {
            Text(option)
              .font(GainsFont.label(11))
              .tracking(1.2)
              .foregroundStyle(selectedSplit == option ? GainsColor.ink : GainsColor.softInk)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .background(selectedSplit == option ? GainsColor.lime : GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  @ViewBuilder
  private var selectedExercisesSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      SlashLabel(
        parts: ["AUSGEWÄHLT", "ÜBUNGEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if selectedExercises.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Noch keine Übungen ausgewählt")
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)

          Text("Füge unten Übungen hinzu. Für den Start reichen schon 4 bis 6 gute Übungen.")
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(18)
        .gainsCardStyle()
      } else {
        VStack(alignment: .leading, spacing: 10) {
          ForEach(selectedExercises) { exercise in
            HStack(spacing: 12) {
              VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)

                Text(
                  "\(exercise.primaryMuscle) · \(exercise.defaultSets) Sätze × \(exercise.defaultReps)"
                )
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
              }

              Spacer()

              Button {
                removeExercise(exercise)
              } label: {
                Image(systemName: "minus.circle.fill")
                  .font(.system(size: 22, weight: .semibold))
                  .foregroundStyle(GainsColor.moss)
              }
              .buttonStyle(.plain)
            }
            .padding(16)
            .gainsCardStyle()
          }
        }
      }
    }
  }

  private var searchSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      SlashLabel(
        parts: ["SUCHEN", "ÜBUNGEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(GainsColor.softInk)

        TextField("Übungen suchen", text: $searchText)
          .textInputAutocapitalization(.words)
          .autocorrectionDisabled()
          .font(GainsFont.body())
      }
      .padding(.horizontal, 14)
      .frame(height: 50)
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(GainsColor.border.opacity(0.7), lineWidth: 1)
      )
    }
  }

  private var librarySection: some View {
    VStack(alignment: .leading, spacing: 10) {
      SlashLabel(
        parts: ["GYM", "BIBLIOTHEK"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if filteredExercises.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Keine passende Übung gefunden")
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)

          Text("Probiere einen anderen Suchbegriff wie Brust, Rücken, Kniebeugen oder Rudern.")
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(18)
        .gainsCardStyle()
      } else {
        ForEach(filteredExercises) { exercise in
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
              Text(exercise.name)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)

              Text("\(exercise.primaryMuscle) · \(exercise.equipment)")
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)

              Text("\(exercise.defaultSets) Sätze × \(exercise.defaultReps) Wiederholungen")
                .font(GainsFont.label(10))
                .tracking(1.5)
                .foregroundStyle(GainsColor.moss)
            }

            Spacer()

            Button {
              toggleSelection(of: exercise)
            } label: {
              Image(systemName: isSelected(exercise) ? "checkmark.circle.fill" : "plus.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(isSelected(exercise) ? GainsColor.moss : GainsColor.ink)
            }
            .buttonStyle(.plain)
          }
          .padding(16)
          .gainsCardStyle(isSelected(exercise) ? GainsColor.lime.opacity(0.42) : GainsColor.card)
        }
      }
    }
  }

  private var saveButton: some View {
    Button {
      if let workout = store.saveWorkout(
        named: workoutName,
        split: selectedSplit,
        exercises: selectedExercises
      ) {
        onSaved?(workout)
        dismiss()
      }
    } label: {
      Text("Workout speichern")
        .font(GainsFont.label(12))
        .tracking(1.6)
        .foregroundStyle(canSave ? GainsColor.lime : GainsColor.softInk)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(canSave ? GainsColor.ink : GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(!canSave)
  }

  private func isSelected(_ exercise: ExerciseLibraryItem) -> Bool {
    selectedExercises.contains(where: { $0.id == exercise.id })
  }

  private func toggleSelection(of exercise: ExerciseLibraryItem) {
    if isSelected(exercise) {
      removeExercise(exercise)
    } else {
      selectedExercises.append(exercise)
    }
  }

  private func removeExercise(_ exercise: ExerciseLibraryItem) {
    selectedExercises.removeAll(where: { $0.id == exercise.id })
  }
}
