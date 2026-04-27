import SwiftUI
import UIKit

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
      return "KRAFT"
    case .laufen:
      return "LAUFEN"
    case .fortschritt:
      return "PLAN"
    }
  }

  var systemImage: String {
    switch self {
    case .kraft:
      return "dumbbell.fill"
    case .laufen:
      return "figure.run"
    case .fortschritt:
      return "calendar"
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
  @State private var isShowingWorkoutTracker = false
  @State private var isShowingRunTracker = false
  @State private var isShowingWorkoutBuilder = false
  @State private var selectedWorkspace: WorkoutWorkspace = .kraft
  @State private var selectedHistorySurface: HistorySurface = .all
  @State private var showsWeeklyPlan = false
  @State private var showsPlannerSetup = false
  @State private var showsTrainingHistory = false
  @State private var selectedRun: CompletedRunSummary? = nil
  @State private var showsRunStats = false
  @State private var showsRunHistory = false
  // Workout editing
  @State private var workoutToEdit: WorkoutPlan? = nil
  @State private var workoutToDelete: WorkoutPlan? = nil
  @State private var showsDeleteConfirmation = false

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        trainHeader
        runningWorkspace
      }
    }
    .sheet(isPresented: $isShowingRunTracker) {
      RunTrackerView()
        .environmentObject(store)
    }
  }

  private var workspacePicker: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TRAIN", "WORKSPACES"], primaryColor: GainsColor.lime,
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

  private var trainHeader: some View {
    screenHeader(
      eyebrow: "RUN / ACTION",
      title: store.activeRun == nil ? "Run sauber starten" : "Run ist live",
      subtitle: "Laufstart, aktuelle Form und Vorlagen sind gebündelt – Cardio bleibt klar getrennt vom Gym."
    )
  }

  @ViewBuilder
  private var workspaceContent: some View {
    switch selectedWorkspace {
    case .kraft:
      kraftWorkspace
    case .laufen:
      runningWorkspace
    case .fortschritt:
      planWorkspace
    }
  }

  private var kraftWorkspace: some View {
    VStack(alignment: .leading, spacing: 22) {
      // 1. Today CTA
      strengthHeroSection

      // 2. Live-Session — nur wenn aktiv
      if let activeWorkout = store.activeWorkout {
        liveSection(activeWorkout)
      }

      // 3. Eigene Workouts — immer sichtbar, mit Edit/Delete
      ownWorkoutsSection

      // 4. Vorlagen — sekundär, immer sichtbar
      templateWorkoutsSection
    }
  }

  private var runningWorkspace: some View {
    VStack(alignment: .leading, spacing: 20) {
      // 1. Primäre Aktion — immer sichtbar
      runningStarterSection

      // 2. Live-Tracker — nur sichtbar wenn Lauf aktiv
      if store.activeRun != nil {
        runningLiveSection
      }

      // 3. Letzter Lauf — nur der aktuellste, kompakt
      if let latestRun = store.runHistory.first {
        recentRunCard(latestRun)
      }

      // 4. Vorlagen — früh sichtbar, zentraler Aktionspfad
      runningTemplatesSection

      // 5. Statistiken — alles gefaltet hinter einem Tap
      collapsibleTrainingSection(
        title: "Statistiken & PRs",
        subtitle: "Woche, Jahr, Bestzeiten und Pace-Zonen",
        isExpanded: $showsRunStats,
        content: {
          VStack(alignment: .leading, spacing: 20) {
            weeklyDistanceChartSection
            ytdStatsSection
            distancePRsSection
            paceZonesSection
          }
        }
      )

      // 6. Alle Aktivitäten — gefaltet
      collapsibleTrainingSection(
        title: "Alle Aktivitäten",
        subtitle: store.runHistory.isEmpty
          ? "Noch kein Lauf aufgezeichnet"
          : "\(store.runHistory.count) Läufe gespeichert",
        isExpanded: $showsRunHistory,
        content: { runFeedSection }
      )
    }
    .sheet(item: $selectedRun) { run in
      RunDetailSheet(run: run) {
        store.startRunLike(run)
        selectedRun = nil
        isShowingRunTracker = true
      }
      .environmentObject(store)
    }
  }

  private func recentRunCard(_ run: CompletedRunSummary) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SlashLabel(
          parts: ["LETZTER", "LAUF"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        Text(run.finishedAt.formatted(date: .abbreviated, time: .omitted))
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }

      Button {
        selectedRun = run
      } label: {
        HStack(alignment: .top, spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text(run.title)
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.ink)
            Text(run.routeName)
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.moss)
          }

          Spacer()

          VStack(alignment: .trailing, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
              Text(String(format: "%.2f", run.distanceKm))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(GainsColor.ink)
              Text("km")
                .font(GainsFont.body(12))
                .foregroundStyle(GainsColor.softInk)
            }
            Text(runPaceLabel(run.averagePaceSeconds))
              .font(GainsFont.label(10))
              .tracking(0.8)
              .foregroundStyle(GainsColor.softInk)
          }
        }
      }
      .buttonStyle(.plain)
    }
    .padding(16)
    .gainsCardStyle()
  }

  private var strengthHeroSection: some View {
    let today = store.todayPlannedDay
    let plan = today.workoutPlan ?? store.todayPlannedWorkout ?? store.currentWorkoutPreview
    let isLive = store.activeWorkout != nil
    let title: String
    let eyebrowParts: [String]
    let primaryTitle: String
    let secondaryTitle: String

    switch today.status {
    case .planned:
      title = plan.title.uppercased()
      eyebrowParts = ["KRAFT", "HEUTE", today.dayLabel.uppercased()]
      primaryTitle = isLive ? "Workout weiter tracken" : "Workout starten"
      secondaryTitle = "Bibliothek"
    case .rest:
      title = "FREIER TAG"
      eyebrowParts = ["KRAFT", "FREI", today.dayLabel.uppercased()]
      primaryTitle = "Wochenplan öffnen"
      secondaryTitle = "Workout wählen"
    case .flexible:
      title = "FLEX DAY"
      eyebrowParts = ["KRAFT", "OPTIONAL", today.dayLabel.uppercased()]
      primaryTitle = isLive ? "Workout weiter tracken" : "Optionales Workout starten"
      secondaryTitle = "Wochenplan"
    }

    return VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 14) {
        VStack(alignment: .leading, spacing: 8) {
          SlashLabel(
            parts: eyebrowParts,
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.card.opacity(0.7)
          )

          Text(title)
            .font(GainsFont.display(30))
            .foregroundStyle(GainsColor.card)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
        }

        Spacer()

        Text(isLive ? "LIVE" : (today.status == .rest ? "REST" : "START"))
          .font(GainsFont.label(10))
          .tracking(1.5)
          .foregroundStyle(today.status == .rest ? GainsColor.ink : GainsColor.onLime)
          .padding(.horizontal, 12)
          .frame(height: 32)
          .background(today.status == .rest ? GainsColor.card : GainsColor.lime)
          .clipShape(Capsule())
      }

      Text(todayHeadline(for: today))
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.card.opacity(0.78))
        .lineLimit(3)

      HStack(spacing: 10) {
        switch today.status {
        case .planned:
          darkMetricCard(title: "Übungen", value: "\(plan.exercises.count)", subtitle: plan.focus)
          darkMetricCard(title: "Dauer", value: "\(plan.estimatedDurationMinutes)", subtitle: "Min")
          darkMetricCard(title: "Split", value: plan.split, subtitle: "Fokus")
        case .rest:
          darkMetricCard(title: "Woche", value: "\(store.weeklySessionsCompleted)", subtitle: "Sessions")
          darkMetricCard(title: "Frei", value: "\(store.restDaysCount)", subtitle: "Tage")
          darkMetricCard(title: "Volumen", value: String(format: "%.1f t", store.weeklyVolumeTons), subtitle: "7 Tage")
        case .flexible:
          darkMetricCard(
            title: "Ziel", value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)",
            subtitle: "Sessions")
          darkMetricCard(title: "Volumen", value: String(format: "%.1f t", store.weeklyVolumeTons), subtitle: "7 Tage")
          darkMetricCard(title: "Option", value: plan.split, subtitle: "Nächster Fit")
        }
      }

      HStack(spacing: 10) {
        Button {
          switch today.status {
          case .planned:
            startOrResumeTodayWorkout()
          case .rest:
            selectedWorkspace = .fortschritt
          case .flexible:
            startOrResumeTodayWorkout()
          }
        } label: {
          trainHeroActionButton(
            title: primaryTitle,
            systemImage: today.status == .rest ? "calendar" : "play.fill",
            isPrimary: true
          )
        }
        .buttonStyle(.plain)

        Button {
          switch today.status {
          case .planned:
            isShowingWorkoutBuilder = true
          case .rest, .flexible:
            selectedWorkspace = .fortschritt
          }
        } label: {
          trainHeroActionButton(
            title: secondaryTitle,
            systemImage: today.status == .planned ? "square.stack.3d.up.fill" : "arrow.right",
            isPrimary: false
          )
        }
        .buttonStyle(.plain)
      }
    }
    .padding(20)
    .background(GainsColor.ctaSurface)
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.24), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  private var planWorkspace: some View {
    VStack(alignment: .leading, spacing: 22) {
      plannerStatusCard
      weeklyPlanSection
      collapsibleTrainingSection(
        title: "Planer bearbeiten",
        subtitle: "Frequenz, Fokus, Ziel und freie Tage nur dann öffnen, wenn du wirklich umplanst",
        isExpanded: $showsPlannerSetup,
        content: { plannerSection }
      )
      collapsibleTrainingSection(
        title: "Workout-Zuweisungen",
        subtitle: "Konkrete Workouts einzelnen Trainingstagen zuordnen",
        isExpanded: $showsWeeklyPlan,
        content: { assignedWorkoutsSection }
      )
      collapsibleTrainingSection(
        title: "Trainingsverlauf",
        subtitle: "Workouts und Läufe bleiben prüfbar, aber nicht im Weg",
        isExpanded: $showsTrainingHistory,
        content: {
          VStack(alignment: .leading, spacing: 18) {
            historyOverviewSection
            historySection
          }
        }
      )
    }
  }

  // MARK: - Running Hero Card (Strava-style)

  private var runningStarterSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      // ── Top bar: title + streak ──────────────────────────────────
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          SlashLabel(
            parts: ["LAUFEN", "RECORD"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.card.opacity(0.65)
          )
          Text(store.runningHeadline)
            .font(GainsFont.title(26))
            .foregroundStyle(GainsColor.card)
            .lineLimit(2)
        }
        Spacer(minLength: 12)
        if store.runStreak > 0 {
          VStack(spacing: 2) {
            Image(systemName: "flame.fill")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(GainsColor.lime)
            Text("\(store.runStreak)")
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.lime)
            Text("Tage")
              .font(GainsFont.label(8))
              .tracking(1.0)
              .foregroundStyle(GainsColor.lime.opacity(0.7))
          }
          .frame(width: 48)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 20)
      .padding(.bottom, 16)

      // ── Quick stats strip ────────────────────────────────────────
      HStack(spacing: 0) {
        darkMetricCard(
          title: "7 Tage",
          value: String(format: "%.1f", store.weeklyRunDistanceKm),
          subtitle: "km"
        )
        darkMetricCard(title: "Läufe", value: "\(store.weeklyRunCount)", subtitle: "Woche")
        darkMetricCard(title: "Ø Pace", value: runPaceLabel(store.averageRunPaceSeconds), subtitle: "7 Tage")
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 16)

      // ── Record button ────────────────────────────────────────────
      Button {
        startOrResumeRun()
      } label: {
        HStack(spacing: 10) {
          Image(systemName: store.activeRun == nil ? "record.circle.fill" : "play.circle.fill")
            .font(.system(size: 18, weight: .semibold))
          Text(store.activeRun == nil ? "Aktivität aufzeichnen" : "Lauf weiter tracken")
            .font(GainsFont.label(13))
            .tracking(1.4)
        }
        .foregroundStyle(GainsColor.onLime)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(GainsColor.lime)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
    }
    .background(GainsColor.ctaSurface)
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.22), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
  }

  private var runningLiveSection: some View {
    Group {
      if let activeRun = store.activeRun {
        VStack(alignment: .leading, spacing: 12) {
          // Pulsing "LIVE" header
          HStack(spacing: 8) {
            Circle()
              .fill(GainsColor.lime)
              .frame(width: 8, height: 8)
            Text("LAUF AKTIV")
              .font(GainsFont.label(10))
              .tracking(2.0)
              .foregroundStyle(GainsColor.lime)
          }

          HStack(spacing: 0) {
            workoutStatCard(
              title: "Distanz",
              value: String(format: "%.2f", activeRun.distanceKm),
              subtitle: "km"
            )
            workoutStatCard(
              title: "Pace",
              value: runPaceLabel(activeRun.averagePaceSeconds),
              subtitle: "/km"
            )
            workoutStatCard(
              title: "Puls",
              value: "\(activeRun.currentHeartRate)",
              subtitle: "bpm"
            )
          }
          .background(GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

          Button {
            isShowingRunTracker = true
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "map.fill")
                .font(.system(size: 13, weight: .semibold))
              Text("Tracker & Karte öffnen")
                .font(GainsFont.label(11))
                .tracking(1.2)
            }
            .foregroundStyle(GainsColor.onLime)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
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

  private var runningTemplatesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["VORSCHLÄGE", "ROUTEN"], primaryColor: GainsColor.lime,
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
              .background(GainsColor.ctaSurface)
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

  // MARK: - Run Feed (Strava-style)

  private var runFeedSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["AKTIVITÄTEN", "FEED"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        if !store.runHistory.isEmpty {
          Text("\(store.runHistory.count) Läufe")
            .font(GainsFont.label(9))
            .tracking(1.2)
            .foregroundStyle(GainsColor.softInk)
        }
      }

      if store.runHistory.isEmpty {
        emptyWorkoutLibraryCard(
          title: "Noch keine Aktivitäten",
          description: "Starte deinen ersten Lauf – Gains baut deinen Feed automatisch auf."
        )
      } else {
        ForEach(store.runHistory) { run in
          Button {
            selectedRun = run
          } label: {
            runActivityCard(run)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func runActivityCard(_ run: CompletedRunSummary) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // ── Header ──────────────────────────────────────────────────
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Image(systemName: "figure.run")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(GainsColor.lime)
            Text(run.finishedAt.formatted(date: .abbreviated, time: .omitted).uppercased())
              .font(GainsFont.label(9))
              .tracking(1.2)
              .foregroundStyle(GainsColor.softInk)
            Text("·")
              .foregroundStyle(GainsColor.softInk.opacity(0.5))
            Text(run.routeName)
              .font(GainsFont.label(9))
              .tracking(0.8)
              .foregroundStyle(GainsColor.moss)
              .lineLimit(1)
          }
          Text(run.title)
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(GainsColor.softInk.opacity(0.4))
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 14)

      // ── Key stats ───────────────────────────────────────────────
      HStack(spacing: 0) {
        runStatCell(
          label: "DISTANZ",
          value: String(format: "%.2f", run.distanceKm),
          unit: "km"
        )
        Rectangle()
          .fill(GainsColor.border.opacity(0.4))
          .frame(width: 1, height: 34)
        runStatCell(
          label: "PACE",
          value: runPaceLabel(run.averagePaceSeconds),
          unit: ""
        )
        Rectangle()
          .fill(GainsColor.border.opacity(0.4))
          .frame(width: 1, height: 34)
        runStatCell(
          label: "DAUER",
          value: formattedDuration(run.durationMinutes),
          unit: ""
        )
        if run.elevationGain > 0 {
          Rectangle()
            .fill(GainsColor.border.opacity(0.4))
            .frame(width: 1, height: 34)
          runStatCell(
            label: "HÖHE",
            value: "\(run.elevationGain)",
            unit: "m"
          )
        }
      }
      .padding(.vertical, 12)
      .background(GainsColor.background.opacity(0.55))

      // ── Pace-Bar-Chart (Splits) ──────────────────────────────────
      if !run.splits.isEmpty {
        runSplitBars(run.splits)
          .padding(.horizontal, 16)
          .padding(.top, 14)
          .padding(.bottom, 4)
      }

      // ── Footer: "Erneut laufen" ──────────────────────────────────
      Button {
        store.startRunLike(run)
        isShowingRunTracker = true
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 11, weight: .semibold))
          Text("Erneut laufen")
            .font(GainsFont.label(10))
            .tracking(1.2)
        }
        .foregroundStyle(store.activeRun == nil ? GainsColor.lime : GainsColor.softInk)
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .background(GainsColor.background.opacity(0.6))
      }
      .buttonStyle(.plain)
      .disabled(store.activeRun != nil)
      .opacity(store.activeRun == nil ? 1 : 0.45)
      .padding(.top, 10)
      .padding(.bottom, 4)
    }
    .gainsCardStyle()
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
    )
  }

  private func runSplitBars(_ splits: [RunSplit]) -> some View {
    let displayed = Array(splits.prefix(8))
    let paces = displayed.map(\.paceSeconds).filter { $0 > 0 }
    let minPace = paces.min() ?? 1
    let maxPace = max(paces.max() ?? 1, minPace + 1)

    return VStack(alignment: .leading, spacing: 8) {
      Text("KILOMETER-SPLITS")
        .font(GainsFont.label(8))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      HStack(alignment: .bottom, spacing: 5) {
        ForEach(displayed, id: \.id) { split in
          let pace = split.paceSeconds
          // Invert: schneller (niedrigerer Wert) = höhere Bar
          let fraction: Double = pace > 0
            ? 1.0 - (Double(pace - minPace) / Double(maxPace - minPace)) * 0.6
            : 0.15
          let isFastest = pace == minPace && pace > 0

          VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .fill(isFastest ? GainsColor.lime : GainsColor.lime.opacity(0.45 + fraction * 0.35))
              .frame(height: max(fraction * 44, 6))

            Text("\(split.index)")
              .font(GainsFont.label(8))
              .tracking(0.5)
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 56, alignment: .bottom)

      // Pace labels (min / max)
      HStack {
        Text("schnell \(runPaceLabel(minPace))")
          .font(GainsFont.label(8))
          .foregroundStyle(GainsColor.lime)
        Spacer()
        Text("langsam \(runPaceLabel(maxPace))")
          .font(GainsFont.label(8))
          .foregroundStyle(GainsColor.softInk)
      }
    }
  }

  private func runStatCell(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        if !unit.isEmpty {
          Text(unit)
            .font(GainsFont.body(10))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func formattedDuration(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    return h > 0 ? "\(h):\(String(format: "%02d", m))" : "\(m) min"
  }

  // MARK: - Strava-style Running Sections

  private var weeklyDistanceChartSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        SlashLabel(
          parts: ["WOCHE", "DISTANZ"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        Text(String(format: "%.1f km", store.weeklyRunDistanceKm))
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
      }

      let days = store.weeklyRunsByDay
      let maxKm = max(days.map(\.km).max() ?? 1, 1)

      HStack(alignment: .bottom, spacing: 6) {
        ForEach(days) { day in
          VStack(spacing: 6) {
            if day.km > 0 {
              Text(String(format: "%.1f", day.km))
                .font(GainsFont.label(8))
                .tracking(0.5)
                .foregroundStyle(day.isToday ? GainsColor.moss : GainsColor.softInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            } else {
              Text("")
                .font(GainsFont.label(8))
            }

            GeometryReader { geo in
              VStack(spacing: 0) {
                Spacer()
                let fraction = day.km > 0 ? max(day.km / maxKm, 0.06) : 0.04
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                  .fill(
                    day.km > 0
                      ? (day.isToday ? GainsColor.lime : GainsColor.lime.opacity(0.55))
                      : GainsColor.border.opacity(0.5)
                  )
                  .frame(height: geo.size.height * fraction)
              }
            }
            .frame(height: 72)

            Text(day.dayLabel)
              .font(GainsFont.label(9))
              .tracking(1.0)
              .foregroundStyle(day.isToday ? GainsColor.ink : GainsColor.softInk)
              .fontWeight(day.isToday ? .semibold : .regular)
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
    .padding(18)
    .gainsCardStyle()
  }

  private var ytdStatsSection: some View {
    let year = Calendar.current.component(.year, from: Date())
    let hours = store.yearlyRunDurationMinutes / 60
    let minutes = store.yearlyRunDurationMinutes % 60
    let timeString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) min"

    return VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["\(year)", "GESAMT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      HStack(spacing: 10) {
        ytdMetricCard(
          title: "Distanz",
          value: String(format: "%.0f", store.yearlyRunDistanceKm),
          unit: "km",
          systemImage: "figure.run"
        )
        ytdMetricCard(
          title: "Läufe",
          value: "\(store.yearlyRunCount)",
          unit: "×",
          systemImage: "checkmark.circle.fill"
        )
        ytdMetricCard(
          title: "Zeit",
          value: timeString,
          unit: "",
          systemImage: "clock.fill"
        )
        ytdMetricCard(
          title: "Höhe",
          value: "\(store.yearlyElevationGain)",
          unit: "m",
          systemImage: "mountain.2.fill"
        )
      }
    }
  }

  private func ytdMetricCard(title: String, value: String, unit: String, systemImage: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: systemImage)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.lime)

      VStack(spacing: 2) {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
          Text(value)
            .font(GainsFont.title(15))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          if !unit.isEmpty {
            Text(unit)
              .font(GainsFont.body(10))
              .foregroundStyle(GainsColor.softInk)
          }
        }
        Text(title)
          .font(GainsFont.label(8))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .padding(.horizontal, 6)
    .gainsCardStyle()
  }

  private var paceZonesSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["PACE", "ZONEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      let zones = store.paceZones
      if zones.isEmpty {
        Text("Starte deine ersten Läufe, um deine Pace-Zonen zu sehen.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .padding(.vertical, 8)
      } else {
        VStack(spacing: 10) {
          let zoneColors: [Color] = [
            GainsColor.lime.opacity(0.5),
            GainsColor.lime.opacity(0.75),
            GainsColor.lime,
            GainsColor.moss,
          ]
          ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
            VStack(alignment: .leading, spacing: 6) {
              HStack {
                Text(zone.label)
                  .font(GainsFont.title(14))
                  .foregroundStyle(GainsColor.ink)
                Text(zone.description)
                  .font(GainsFont.body(12))
                  .foregroundStyle(GainsColor.softInk)
                Spacer()
                Text(String(format: "%.0f%%", zone.fraction * 100))
                  .font(GainsFont.title(14))
                  .foregroundStyle(GainsColor.ink)
              }
              GeometryReader { geo in
                ZStack(alignment: .leading) {
                  RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(GainsColor.border.opacity(0.4))
                    .frame(height: 8)
                  RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(zoneColors[min(index, zoneColors.count - 1)])
                    .frame(width: geo.size.width * zone.fraction, height: 8)
                }
              }
              .frame(height: 8)
            }
          }
        }
      }
    }
    .padding(18)
    .gainsCardStyle()
  }

  private var distancePRsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["BESTZEITEN", "DISTANZ"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      let prs = store.distancePRs
      if prs.isEmpty {
        emptyWorkoutLibraryCard(
          title: "Noch keine Bestzeiten",
          description: "Läufe ab 5 km reichen, um deine ersten PR-Zeiten zu sammeln."
        )
      } else {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
          ForEach(prs) { pr in
            VStack(alignment: .leading, spacing: 6) {
              HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                  .font(.system(size: 11, weight: .semibold))
                  .foregroundStyle(GainsColor.lime)
                Text(pr.title)
                  .font(GainsFont.label(9))
                  .tracking(1.4)
                  .foregroundStyle(GainsColor.softInk)
              }
              Text(pr.value)
                .font(GainsFont.title(20))
                .foregroundStyle(GainsColor.ink)
              Text(pr.context)
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
  }

  private var plannerStatusCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["PLAN", "STATUS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.card.opacity(0.72))

      VStack(alignment: .leading, spacing: 10) {
        Text(store.plannerSummaryHeadline)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.card)
          .lineLimit(2)

        Text(store.plannerSummaryDescription)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.card.opacity(0.78))
          .lineLimit(3)
      }

      HStack(spacing: 10) {
        darkMetricCard(
          title: "Einheiten", value: "\(store.trainingDaysCount)",
          subtitle: "pro Woche")
        darkMetricCard(
          title: "Dauer", value: "\(store.plannerSettings.preferredSessionLength)",
          subtitle: "Min")
        darkMetricCard(
          title: "Fokus", value: store.plannerSettings.trainingFocus.title,
          subtitle: store.plannerSettings.goal.title)
      }

      HStack(spacing: 10) {
        Button {
          showsPlannerSetup = true
        } label: {
          trainingActionButton(
            title: "Plan bearbeiten",
            subtitle: "Ziel, Frequenz, Split",
            isPrimary: false
          )
        }
        .buttonStyle(.plain)

        Button {
          showsWeeklyPlan = true
        } label: {
          trainingActionButton(
            title: store.scheduledPlannerDays.isEmpty ? "Trainingstage setzen" : "Workouts zuweisen",
            subtitle: store.scheduledPlannerDays.isEmpty ? "Woche vorbereiten" : "Tage konkret machen",
            isPrimary: true
          )
        }
        .buttonStyle(.plain)
      }

      if let todayWorkout = store.todayPlannedWorkout {
        Button {
          openWorkout(todayWorkout)
        } label: {
          HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
              Text("HEUTE DIREKT STARTEN")
                .font(GainsFont.label(10))
                .tracking(1.8)
                .foregroundStyle(GainsColor.card.opacity(0.7))

              Text(todayWorkout.title)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.card)
                .lineLimit(1)

              Text("\(todayWorkout.split) · \(todayWorkout.estimatedDurationMinutes) Min")
                .font(GainsFont.body(12))
                .foregroundStyle(GainsColor.card.opacity(0.72))
                .lineLimit(1)
            }

            Spacer()

            Image(systemName: "play.fill")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(GainsColor.onLime)
              .frame(width: 34, height: 34)
              .background(GainsColor.lime)
              .clipShape(Circle())
          }
          .padding(14)
          .background(GainsColor.card.opacity(0.08))
          .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(GainsColor.card.opacity(0.16), lineWidth: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(20)
    .background(GainsColor.ctaSurface)
    .overlay(
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.24), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  private func trainingActionButton(title: String, subtitle: String, isPrimary: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(GainsFont.title(16))
        .foregroundStyle(isPrimary ? GainsColor.onLime : GainsColor.card)
        .lineLimit(2)

      Text(subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(isPrimary ? GainsColor.onLimeSecondary : GainsColor.card.opacity(0.72))
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
    .padding(14)
    .background(isPrimary ? GainsColor.lime : GainsColor.card.opacity(0.08))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke((isPrimary ? GainsColor.lime : GainsColor.card).opacity(0.18), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private var assignedWorkoutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["HEUTE &", "ZUWEISEN"], primaryColor: GainsColor.lime,
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
      // ── Header mit prominentem + Button ──────────────────────────
      HStack(alignment: .center) {
        SlashLabel(
          parts: ["EIGENE", "WORKOUTS"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        Button {
          isShowingWorkoutBuilder = true
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "plus")
              .font(.system(size: 11, weight: .bold))
            Text("ERSTELLEN")
              .font(GainsFont.label(10))
              .tracking(1.6)
          }
          .foregroundStyle(GainsColor.ink)
          .padding(.horizontal, 14)
          .frame(height: 34)
          .background(GainsColor.lime)
          .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }

      // ── Workout-Karten ────────────────────────────────────────────
      if store.customWorkoutPlans.isEmpty {
        // Empty state mit eingebettetem CTA
        Button {
          isShowingWorkoutBuilder = true
        } label: {
          VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
              Image(systemName: "plus.circle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(GainsColor.lime)
              VStack(alignment: .leading, spacing: 4) {
                Text("Erstes Workout erstellen")
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)
                Text("Wähle Übungen, passe Sets & Reps an und speichere es in deiner Bibliothek.")
                  .font(GainsFont.body(13))
                  .foregroundStyle(GainsColor.softInk)
                  .lineLimit(2)
              }
            }
          }
          .padding(18)
          .gainsCardStyle()
        }
        .buttonStyle(.plain)
      } else {
        ForEach(store.customWorkoutPlans) { plan in
          customWorkoutCard(plan)
        }
      }
    }
  }

  private var templateWorkoutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["VORLAGEN", "WORKOUTS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ForEach(store.templateWorkoutPlans) { plan in
        templateWorkoutCard(plan)
      }
    }
  }

  // MARK: - WHOOP-style eigene Workout-Karte (Edit / Delete / Start)

  private func customWorkoutCard(_ plan: WorkoutPlan) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // ── Top: Titel + Overflow-Menü ────────────────────────────────
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(plan.title)
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          HStack(spacing: 6) {
            Text(plan.split)
              .font(GainsFont.label(9))
              .tracking(1.4)
              .foregroundStyle(GainsColor.moss)
            Text("·")
              .foregroundStyle(GainsColor.softInk.opacity(0.5))
            Text(plan.focus)
              .font(GainsFont.label(9))
              .tracking(1.0)
              .foregroundStyle(GainsColor.softInk)
            Text("·")
              .foregroundStyle(GainsColor.softInk.opacity(0.5))
            Text("\(plan.exercises.count) Übungen")
              .font(GainsFont.label(9))
              .tracking(1.0)
              .foregroundStyle(GainsColor.softInk)
          }
        }
        Spacer(minLength: 8)
        // Overflow-Menü: Bearbeiten / Löschen
        Menu {
          Button {
            workoutToEdit = plan
          } label: {
            Label("Bearbeiten", systemImage: "pencil")
          }
          Divider()
          Button(role: .destructive) {
            workoutToDelete = plan
            showsDeleteConfirmation = true
          } label: {
            Label("Löschen", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
            .frame(width: 34, height: 34)
            .background(GainsColor.background.opacity(0.7))
            .clipShape(Circle())
        }
      }
      .padding(.horizontal, 18)
      .padding(.top, 18)
      .padding(.bottom, 14)

      // ── Übungsvorschau als Chips ──────────────────────────────────
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(plan.exercises.prefix(5), id: \.id) { exercise in
            Text(exercise.name)
              .font(GainsFont.label(9))
              .tracking(0.8)
              .foregroundStyle(GainsColor.ink)
              .padding(.horizontal, 12)
              .frame(height: 28)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
          }
          if plan.exercises.count > 5 {
            Text("+\(plan.exercises.count - 5)")
              .font(GainsFont.label(9))
              .tracking(0.8)
              .foregroundStyle(GainsColor.softInk)
              .padding(.horizontal, 10)
              .frame(height: 28)
              .background(GainsColor.background.opacity(0.7))
              .clipShape(Capsule())
          }
        }
        .padding(.horizontal, 18)
      }
      .padding(.bottom, 14)

      // ── Metrik-Streifen ───────────────────────────────────────────
      HStack(spacing: 0) {
        workoutMetricCell(label: "DAUER", value: "\(plan.estimatedDurationMinutes)", unit: "min")
        Rectangle().fill(GainsColor.border.opacity(0.35)).frame(width: 1, height: 28)
        workoutMetricCell(label: "ÜBUNGEN", value: "\(plan.exercises.count)", unit: "")
        Rectangle().fill(GainsColor.border.opacity(0.35)).frame(width: 1, height: 28)
        workoutMetricCell(
          label: "SÄTZE",
          value: "\(plan.exercises.reduce(0) { $0 + $1.sets.count })",
          unit: "")
      }
      .padding(.vertical, 12)
      .background(GainsColor.background.opacity(0.5))

      // ── Action-Buttons ────────────────────────────────────────────
      HStack(spacing: 10) {
        // Einplanen
        Menu {
          if store.scheduledPlannerDays.isEmpty {
            Button("Kein Trainingstag geplant") {}
              .disabled(true)
          } else {
            ForEach(store.scheduledPlannerDays) { day in
              Button("\(day.title) zuweisen") {
                store.assignWorkout(plan, to: day)
              }
            }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "calendar.badge.plus")
              .font(.system(size: 12, weight: .semibold))
            Text("Einplanen")
              .font(GainsFont.label(10))
              .tracking(1.2)
          }
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
          )
        }

        // Starten
        Button {
          openWorkout(plan)
        } label: {
          HStack(spacing: 6) {
            Image(
              systemName: isWorkoutButtonDisabled(for: plan) ? "stop.circle" : "play.fill"
            )
            .font(.system(size: 12, weight: .semibold))
            Text(actionTitle(for: plan))
              .font(GainsFont.label(10))
              .tracking(1.2)
          }
          .foregroundStyle(
            isWorkoutButtonDisabled(for: plan) ? GainsColor.softInk : GainsColor.onLime
          )
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(
            isWorkoutButtonDisabled(for: plan) ? GainsColor.background.opacity(0.6) : GainsColor.lime
          )
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isWorkoutButtonDisabled(for: plan))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
  }

  // MARK: - Einfachere Template-Karte (kein Edit/Delete)

  private func templateWorkoutCard(_ plan: WorkoutPlan) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // ── Header ────────────────────────────────────────────────────
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(plan.title)
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          HStack(spacing: 6) {
            Text(plan.split)
              .font(GainsFont.label(9))
              .tracking(1.4)
              .foregroundStyle(GainsColor.moss)
            Text("·")
              .foregroundStyle(GainsColor.softInk.opacity(0.5))
            Text(plan.focus)
              .font(GainsFont.label(9))
              .foregroundStyle(GainsColor.softInk)
          }
        }
        Spacer()
        workoutSourceBadge(plan.source)
      }
      .padding(.horizontal, 18)
      .padding(.top, 18)
      .padding(.bottom, 14)

      // ── Übungsvorschau ────────────────────────────────────────────
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(plan.exercises.prefix(5), id: \.id) { exercise in
            Text(exercise.name)
              .font(GainsFont.label(9))
              .tracking(0.8)
              .foregroundStyle(GainsColor.ink)
              .padding(.horizontal, 12)
              .frame(height: 28)
              .background(GainsColor.lime.opacity(0.12))
              .clipShape(Capsule())
          }
          if plan.exercises.count > 5 {
            Text("+\(plan.exercises.count - 5)")
              .font(GainsFont.label(9))
              .foregroundStyle(GainsColor.softInk)
              .padding(.horizontal, 10)
              .frame(height: 28)
              .background(GainsColor.background.opacity(0.7))
              .clipShape(Capsule())
          }
        }
        .padding(.horizontal, 18)
      }
      .padding(.bottom, 14)

      // ── Metrik-Streifen ───────────────────────────────────────────
      HStack(spacing: 0) {
        workoutMetricCell(label: "DAUER", value: "\(plan.estimatedDurationMinutes)", unit: "min")
        Rectangle().fill(GainsColor.border.opacity(0.35)).frame(width: 1, height: 28)
        workoutMetricCell(label: "ÜBUNGEN", value: "\(plan.exercises.count)", unit: "")
        Rectangle().fill(GainsColor.border.opacity(0.35)).frame(width: 1, height: 28)
        workoutMetricCell(
          label: "SÄTZE",
          value: "\(plan.exercises.reduce(0) { $0 + $1.sets.count })",
          unit: "")
      }
      .padding(.vertical, 12)
      .background(GainsColor.background.opacity(0.5))

      // ── Action-Buttons ────────────────────────────────────────────
      HStack(spacing: 10) {
        Menu {
          if store.scheduledPlannerDays.isEmpty {
            Button("Kein Trainingstag geplant") {}
              .disabled(true)
          } else {
            ForEach(store.scheduledPlannerDays) { day in
              Button("\(day.title) zuweisen") {
                store.assignWorkout(plan, to: day)
              }
            }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "calendar.badge.plus")
              .font(.system(size: 12, weight: .semibold))
            Text("Einplanen")
              .font(GainsFont.label(10))
              .tracking(1.2)
          }
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
          )
        }

        Button {
          openWorkout(plan)
        } label: {
          HStack(spacing: 6) {
            Image(
              systemName: isWorkoutButtonDisabled(for: plan) ? "stop.circle" : "play.fill"
            )
            .font(.system(size: 12, weight: .semibold))
            Text(actionTitle(for: plan))
              .font(GainsFont.label(10))
              .tracking(1.2)
          }
          .foregroundStyle(
            isWorkoutButtonDisabled(for: plan) ? GainsColor.softInk : GainsColor.onLime
          )
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(
            isWorkoutButtonDisabled(for: plan) ? GainsColor.background.opacity(0.6) : GainsColor.lime
          )
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isWorkoutButtonDisabled(for: plan))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
  }

  private func workoutMetricCell(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 3) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 15, weight: .bold, design: .rounded))
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

  private func assignedWorkoutCard(for day: Weekday) -> some View {
    let assignedWorkout = store.assignedWorkoutPlan(for: day)
    let effectiveWorkout =
      assignedWorkout
      ?? store.weeklyWorkoutSchedule.first(where: { $0.weekday == day })?.workoutPlan
    let isToday = day == .today

    return VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            Text(day.title)
              .font(GainsFont.title(20))
              .foregroundStyle(GainsColor.ink)

            if isToday {
              Text("HEUTE")
                .font(GainsFont.label(9))
                .tracking(1.8)
                .foregroundStyle(GainsColor.ink)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(GainsColor.lime)
                .clipShape(Capsule())
            }
          }

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
        VStack(alignment: .leading, spacing: 8) {
          Text(effectiveWorkout.title)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)

          Text(
            "\(effectiveWorkout.split) · \(effectiveWorkout.exercises.count) Übungen · \(effectiveWorkout.focus)"
          )
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)
        }
        .padding(14)
        .background(isToday ? GainsColor.lime.opacity(0.16) : GainsColor.background.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
          Text(effectiveWorkout == nil ? "Workout zuweisen" : "Workout ändern")
            .font(GainsFont.label(11))
            .tracking(1.3)
            .foregroundStyle(GainsColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }

        if isToday, let effectiveWorkout {
          Button {
            openWorkout(effectiveWorkout)
          } label: {
            Text(store.activeWorkout == nil ? "Jetzt starten" : "Workout öffnen")
              .font(GainsFont.label(11))
              .tracking(1.3)
              .foregroundStyle(GainsColor.lime)
              .frame(maxWidth: .infinity)
              .frame(height: 42)
              .background(GainsColor.ctaSurface)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(16)
    .gainsCardStyle(isToday ? GainsColor.lime.opacity(0.08) : GainsColor.card)
  }

  private func emptyWorkoutLibraryCard(title: String, description: String) -> some View {
    // A3: Verwendet jetzt den einheitlichen `EmptyStateView` statt eigene Card.
    EmptyStateView(
      style: .inline,
      title: title,
      message: description,
      icon: "tray"
    )
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
        EmptyStateView(
          style: .inline,
          title: "Noch kein Verlauf in diesem Bereich",
          message: "Sobald du Läufe oder Workouts abschließt, erscheinen sie hier in deinem Verlauf.",
          icon: "clock"
        )
        .frame(maxWidth: .infinity)
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

  private func darkMetricCard(title: String, value: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.card.opacity(0.58))

      Text(value)
        .font(GainsFont.title(17))
        .foregroundStyle(GainsColor.card)
        .lineLimit(1)
        .minimumScaleFactor(0.65)

      Text(subtitle)
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.card.opacity(0.68))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
    .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
    .padding(12)
    .background(GainsColor.card.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
      return
    }

    if let fallbackPlan = store.savedWorkoutPlans.first ?? store.templateWorkoutPlans.first {
      openWorkout(fallbackPlan)
      return
    }

    isShowingWorkoutBuilder = true
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
      return "Dein Training an einem Ort"
    case .rest:
      return
        "Heute ist als freier Tag geplant. Halte nur den Rhythmus mit Schritten, Mobility oder einem spontanen Workout."
    case .flexible:
      return
        "Heute ist flexibel. Du kannst spontan Cardio, Mobility oder ein zusätzliches Workout einbauen."
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

      Text(subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
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

    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 10) {
        Image(systemName: workspace.systemImage)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(iconColor)

        Text(workspace.title)
          .font(GainsFont.title(16))
          .foregroundStyle(titleColor)

        Spacer()
      }

      Text(workspaceCardHeadline(for: workspace))
        .font(GainsFont.body(13))
        .foregroundStyle(isSelected ? GainsColor.ink.opacity(0.9) : GainsColor.softInk)
        .lineLimit(2)

      Text(workspaceCardValue(for: workspace))
        .font(GainsFont.label(9))
        .tracking(1.6)
        .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.ink.opacity(0.62))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(width: 176)
    .frame(minHeight: 116, alignment: .leading)
    .padding(14)
    .background(backgroundColor)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  private var trainingHeaderTitle: String {
    switch selectedWorkspace {
    case .kraft:
      return store.activeWorkout == nil ? "Kraft fokussieren" : "Workout ist live"
    case .laufen:
      return store.activeRun == nil ? "Run sauber starten" : "Run ist live"
    case .fortschritt:
      return "Woche sauber planen"
    }
  }

  private var trainingHeaderSubtitle: String {
    switch selectedWorkspace {
    case .kraft:
      return "\(store.todayPlannedDay.title) heute. Stärke-Flow, Wochenfortschritt und Bibliothek bleiben in einem klaren Ablauf."
    case .laufen:
      return "Laufstart, aktuelle Form und Vorlagen sind gebündelt, damit Cardio nicht wie ein zweiter Modus wirkt."
    case .fortschritt:
      return "Session-Frequenz, Tageslogik und Workout-Zuweisungen greifen hier direkt ineinander."
    }
  }

  private func workspaceCardHeadline(for workspace: WorkoutWorkspace) -> String {
    switch workspace {
    case .kraft:
      return store.todayPlannedWorkout?.title ?? store.todayPlannedDay.title
    case .laufen:
      return store.activeRun == nil ? "Cardio heute" : "Lauf aktiv"
    case .fortschritt:
      return store.plannerSummaryHeadline
    }
  }

  private func workspaceCardValue(for workspace: WorkoutWorkspace) -> String {
    switch workspace {
    case .kraft:
      return "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) SESSIONS"
    case .laufen:
      return store.activeRun == nil
        ? "\(String(format: "%.1f", store.weeklyRunDistanceKm)) KM / 7 TAGE"
        : "\(store.weeklyRunCount) RUNS / DIESE WOCHE"
    case .fortschritt:
      return "\(store.plannerAssignedDaysCount) FIX ZUGEWIESEN"
    }
  }

  private func trainHeroActionButton(title: String, systemImage: String, isPrimary: Bool) -> some View {
    HStack(spacing: 10) {
      Image(systemName: systemImage)
        .font(.system(size: 12, weight: .semibold))
      Text(title)
        .font(GainsFont.label(11))
        .tracking(1.3)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
      Spacer(minLength: 0)
    }
    .foregroundStyle(isPrimary ? GainsColor.onLime : GainsColor.card)
    .frame(maxWidth: .infinity)
    .frame(height: 46)
    .padding(.horizontal, 14)
    .background(isPrimary ? GainsColor.lime : GainsColor.card.opacity(0.08))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(isPrimary ? GainsColor.lime : GainsColor.card.opacity(0.22), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func runPaceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:-- /km" }
    let minutes = seconds / 60
    let seconds = seconds % 60
    return String(format: "%d:%02d /km", minutes, seconds)
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

// MARK: - Editable Exercise (eigene Satz/Rep-Konfiguration im Builder)

private struct EditableExercise: Identifiable {
  let id: UUID
  let base: ExerciseLibraryItem
  var sets: Int
  var reps: Int

  init(base: ExerciseLibraryItem) {
    self.id = UUID()
    self.base = base
    self.sets = base.defaultSets
    self.reps = base.defaultReps
  }
}

// MARK: - WorkoutBuilderView

struct WorkoutBuilderView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  /// Wenn gesetzt → Bearbeitungs-Modus, sonst Neu-Erstellen
  var editingPlan: WorkoutPlan? = nil
  var onSaved: ((WorkoutPlan) -> Void)? = nil

  @State private var workoutName = ""
  @State private var selectedSplit = "Upper"
  @State private var searchText = ""
  @State private var selectedMuscle = "Alle"
  @State private var selectedExercises: [EditableExercise] = []
  @State private var editingExerciseID: UUID? = nil  // welcher Stepper offen ist
  @State private var inspectingExercise: ExerciseLibraryItem? = nil

  private let splitOptions = ["Upper", "Lower", "Push", "Pull", "Beine", "Ganzkörper"]

  private var allMuscles: [String] {
    let muscles = store.exerciseLibrary.map(\.primaryMuscle)
    var unique = ["Alle"]
    for m in muscles where !unique.contains(m) { unique.append(m) }
    return unique
  }

  private var filteredExercises: [ExerciseLibraryItem] {
    let base: [ExerciseLibraryItem]
    if selectedMuscle == "Alle" {
      base = store.exerciseLibrary
    } else {
      base = store.exerciseLibrary.filter { $0.primaryMuscle == selectedMuscle }
    }
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return base }
    return base.filter {
      $0.name.localizedCaseInsensitiveContains(trimmed)
        || $0.primaryMuscle.localizedCaseInsensitiveContains(trimmed)
        || $0.equipment.localizedCaseInsensitiveContains(trimmed)
    }
  }

  private var canSave: Bool {
    !workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !selectedExercises.isEmpty
  }

  private var isEditing: Bool { editingPlan != nil }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        GainsAppBackground()
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 22) {
            // Header
            screenHeader(
              eyebrow: isEditing ? "WORKOUT / BEARBEITEN" : "WORKOUT / ERSTELLEN",
              title: isEditing ? "Training bearbeiten" : "Eigenes Training",
              subtitle: isEditing
                ? "Passe Name, Split und Übungen an – deine Pläne werden automatisch aktualisiert."
                : "Benenne dein Workout, wähle Übungen und passe Sets & Reps direkt an."
            )

            nameAndSplitSection
            selectedExercisesSection
            exerciseLibrarySection
            // Spacer für den sticky Button
            Color.clear.frame(height: 80)
          }
          .padding(.horizontal, 20)
          .padding(.top, 14)
        }
        // ── Sticky Save-Button ─────────────────────────────────────
        stickyActionBar
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
      }
      .onAppear {
        if let plan = editingPlan {
          workoutName = plan.title
          selectedSplit = plan.split
          // Reconstruct EditableExercise from plan exercises
          selectedExercises = plan.exercises.compactMap { template in
            guard let item = store.exerciseLibrary.first(where: { $0.name == template.name })
            else { return nil }
            var e = EditableExercise(base: item)
            e.sets = template.sets.count
            e.reps = template.sets.first?.reps ?? item.defaultReps
            return e
          }
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
              .frame(width: 30, height: 30)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
        }
        ToolbarItem(placement: .principal) {
          Text(isEditing ? "BEARBEITEN" : "NEUES WORKOUT")
            .font(GainsFont.label(11))
            .tracking(2.0)
            .foregroundStyle(GainsColor.ink)
        }
      }
      .toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Fertig") {
            UIApplication.shared.sendAction(
              #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
          }
        }
      }
      .sheet(item: $inspectingExercise) { exercise in
        NavigationStack {
          ExerciseDetailSheet(exercise: exercise)
        }
        .presentationDetents([.large])
      }
    }
  }

  // MARK: - Name + Split kombiniert

  private var nameAndSplitSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Name
      VStack(alignment: .leading, spacing: 10) {
        SlashLabel(
          parts: ["NAME", "WORKOUT"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        HStack(spacing: 10) {
          Image(systemName: "pencil")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
          TextField("z. B. Upper A · Push Fokus Brust", text: $workoutName)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
              workoutName.isEmpty ? GainsColor.border.opacity(0.5) : GainsColor.lime.opacity(0.5),
              lineWidth: 1.5)
        )
      }

      // Split-Chips
      VStack(alignment: .leading, spacing: 10) {
        SlashLabel(
          parts: ["SPLIT", "AUSWÄHLEN"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(splitOptions, id: \.self) { option in
              Button {
                selectedSplit = option
              } label: {
                Text(option)
                  .font(GainsFont.label(11))
                  .tracking(1.2)
                  .foregroundStyle(selectedSplit == option ? GainsColor.ink : GainsColor.softInk)
                  .padding(.horizontal, 18)
                  .frame(height: 38)
                  .background(selectedSplit == option ? GainsColor.lime : GainsColor.card)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.vertical, 2)
        }
      }
    }
    .padding(18)
    .gainsCardStyle()
  }

  // MARK: - Ausgewählte Übungen (Drag-to-Reorder + Sets/Reps Stepper)

  @ViewBuilder
  private var selectedExercisesSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        SlashLabel(
          parts: ["AUSGEWÄHLT", "\(selectedExercises.count) ÜBUNGEN"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        if !selectedExercises.isEmpty {
          Text("\(selectedExercises.count) ausgewählt")
            .font(GainsFont.label(9))
            .tracking(0.8)
            .foregroundStyle(GainsColor.moss)
        }
      }

      if selectedExercises.isEmpty {
        EmptyStateView(
          style: .card(icon: "hand.point.down"),
          title: "Noch keine Übungen gewählt",
          message: "Wähle Übungen aus der Bibliothek unten. 4 – 6 reichen für den Start."
        )
      } else {
        VStack(spacing: 0) {
          ForEach(Array(selectedExercises.enumerated()), id: \.element.id) { index, _ in
            editableExerciseRow(index: index)
            if index < selectedExercises.count - 1 {
              Divider()
                .background(GainsColor.border.opacity(0.4))
                .padding(.horizontal, 16)
            }
          }
        }
        .background(GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
        )
      }
    }
  }

  private func editableExerciseRow(index: Int) -> some View {
    let ex = selectedExercises[index]
    let isOpen = editingExerciseID == ex.id
    let isFirst = index == 0
    let isLast = index == selectedExercises.count - 1

    return VStack(alignment: .leading, spacing: 0) {
      // ── Hauptzeile ────────────────────────────────────────────────
      HStack(spacing: 12) {
        // Reihenfolge: Auf/Ab-Buttons
        VStack(spacing: 2) {
          Button {
            guard index > 0 else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
              selectedExercises.swapAt(index, index - 1)
            }
          } label: {
            Image(systemName: "chevron.up")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(isFirst ? GainsColor.border : GainsColor.softInk)
          }
          .buttonStyle(.plain)
          .disabled(isFirst)

          Button {
            guard index < selectedExercises.count - 1 else { return }
            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
              selectedExercises.swapAt(index, index + 1)
            }
          } label: {
            Image(systemName: "chevron.down")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(isLast ? GainsColor.border : GainsColor.softInk)
          }
          .buttonStyle(.plain)
          .disabled(isLast)
        }
        .frame(width: 20)

        VStack(alignment: .leading, spacing: 3) {
          Text(ex.base.name)
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Text("\(ex.base.primaryMuscle) · \(ex.base.equipment)")
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
        }

        Spacer()

        // Sets × Reps badge — antippen öffnet Stepper
        Button {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            editingExerciseID = isOpen ? nil : ex.id
          }
        } label: {
          HStack(spacing: 4) {
            Text("\(ex.sets)×\(ex.reps)")
              .font(GainsFont.label(11))
              .tracking(0.6)
              .foregroundStyle(isOpen ? GainsColor.ink : GainsColor.moss)
            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
              .font(.system(size: 9, weight: .bold))
              .foregroundStyle(isOpen ? GainsColor.ink : GainsColor.moss)
          }
          .padding(.horizontal, 12)
          .frame(height: 32)
          .background(isOpen ? GainsColor.lime : GainsColor.lime.opacity(0.18))
          .clipShape(Capsule())
        }
        .buttonStyle(.plain)

        // Entfernen
        Button {
          withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            if editingExerciseID == ex.id { editingExerciseID = nil }
            selectedExercises.remove(at: index)
          }
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(GainsColor.softInk.opacity(0.5))
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)

      // ── Inline Stepper (nur wenn offen) ──────────────────────────
      if isOpen {
        HStack(spacing: 0) {
          builderStepper(
            label: "SÄTZE",
            value: Binding(
              get: { selectedExercises[index].sets },
              set: { selectedExercises[index].sets = $0 }
            ),
            range: 1...8
          )
          Divider()
            .background(GainsColor.border.opacity(0.4))
            .frame(height: 50)
          builderStepper(
            label: "WDHL.",
            value: Binding(
              get: { selectedExercises[index].reps },
              set: { selectedExercises[index].reps = $0 }
            ),
            range: 1...30
          )
        }
        .background(GainsColor.lime.opacity(0.08))
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  private func builderStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>)
    -> some View
  {
    HStack(spacing: 16) {
      Button {
        if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
      } label: {
        Image(systemName: "minus")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(GainsColor.ink)
          .frame(width: 32, height: 32)
          .background(GainsColor.background.opacity(0.8))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)

      VStack(spacing: 2) {
        Text("\(value.wrappedValue)")
          .font(.system(size: 20, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        Text(label)
          .font(GainsFont.label(8))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
      }
      .frame(minWidth: 44)

      Button {
        if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
      } label: {
        Image(systemName: "plus")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(GainsColor.ink)
          .frame(width: 32, height: 32)
          .background(GainsColor.background.opacity(0.8))
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Übungs-Bibliothek mit Muskelgruppen-Filter

  private var exerciseLibrarySection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["GYM", "BIBLIOTHEK"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      // Suchfeld
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(GainsColor.softInk)
        TextField("Übung suchen…", text: $searchText)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
          .font(GainsFont.body())
        if !searchText.isEmpty {
          Button { searchText = "" } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(GainsColor.softInk)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 14)
      .frame(height: 48)
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(GainsColor.border.opacity(0.6), lineWidth: 1)
      )

      // Muskelgruppen-Filter-Chips
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(allMuscles, id: \.self) { muscle in
            Button {
              selectedMuscle = muscle
            } label: {
              Text(muscle)
                .font(GainsFont.label(10))
                .tracking(1.0)
                .foregroundStyle(selectedMuscle == muscle ? GainsColor.ink : GainsColor.softInk)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(selectedMuscle == muscle ? GainsColor.lime : GainsColor.card)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 2)
      }

      // Übungsliste
      if filteredExercises.isEmpty {
        HStack(spacing: 12) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(GainsColor.softInk)
          Text("Keine Übung gefunden. Probiere einen anderen Begriff.")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(18)
        .gainsCardStyle()
      } else {
        VStack(spacing: 0) {
          ForEach(filteredExercises) { exercise in
            libraryExerciseRow(exercise)
            if exercise.id != filteredExercises.last?.id {
              Divider()
                .background(GainsColor.border.opacity(0.3))
                .padding(.horizontal, 16)
            }
          }
        }
        .background(GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
        )
      }
    }
  }

  private func libraryExerciseRow(_ exercise: ExerciseLibraryItem) -> some View {
    let selected = isSelected(exercise)
    return HStack(spacing: 12) {
      // Muskelgruppen-Farbpunkt
      Circle()
        .fill(muscleColor(exercise.primaryMuscle))
        .frame(width: 10, height: 10)

      VStack(alignment: .leading, spacing: 4) {
        Text(exercise.name)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        Text("\(exercise.primaryMuscle) · \(exercise.equipment)")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      Text("\(exercise.defaultSets)×\(exercise.defaultReps)")
        .font(GainsFont.label(10))
        .tracking(0.6)
        .foregroundStyle(GainsColor.softInk)

      Button {
        inspectingExercise = exercise
      } label: {
        Image(systemName: "info.circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
      }
      .buttonStyle(.plain)

      Button {
        toggleSelection(of: exercise)
      } label: {
        Image(
          systemName: selected ? "checkmark.circle.fill" : "plus.circle"
        )
        .font(.system(size: 22, weight: .semibold))
        .foregroundStyle(selected ? GainsColor.moss : GainsColor.lime)
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
    .background(selected ? GainsColor.lime.opacity(0.12) : Color.clear)
    .contentShape(Rectangle())
    .onTapGesture {
      toggleSelection(of: exercise)
    }
  }

  // MARK: - Sticky Save-Button

  private var stickyActionBar: some View {
    Button {
      saveWorkout()
    } label: {
      HStack(spacing: 10) {
        Image(systemName: canSave ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 16, weight: .semibold))
        Text(isEditing ? "Änderungen speichern" : "Workout speichern")
          .font(GainsFont.label(13))
          .tracking(1.4)
        if !selectedExercises.isEmpty {
          Text("· \(selectedExercises.count) Übungen")
            .font(GainsFont.label(11))
            .opacity(0.72)
        }
      }
      .foregroundStyle(canSave ? GainsColor.onLime : GainsColor.softInk)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(
        canSave
          ? GainsColor.lime
          : GainsColor.card
      )
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .shadow(
        color: canSave ? GainsColor.lime.opacity(0.35) : .clear,
        radius: 12, x: 0, y: 4)
    }
    .buttonStyle(.plain)
    .disabled(!canSave)
  }

  // MARK: - Helpers

  private func saveWorkout() {
    let trimmedName = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty, !selectedExercises.isEmpty else { return }

    // Convert EditableExercise → ExerciseLibraryItem (mit angepassten Defaults)
    let libraryItems = selectedExercises.map { editable -> ExerciseLibraryItem in
      ExerciseLibraryItem(
        name: editable.base.name,
        primaryMuscle: editable.base.primaryMuscle,
        equipment: editable.base.equipment,
        defaultSets: editable.sets,
        defaultReps: editable.reps,
        suggestedWeight: editable.base.suggestedWeight
      )
    }

    if let plan = editingPlan {
      if let updated = store.updateWorkout(
        plan, named: trimmedName, split: selectedSplit, exercises: libraryItems)
      {
        onSaved?(updated)
      }
    } else {
      if let created = store.saveWorkout(
        named: trimmedName, split: selectedSplit, exercises: libraryItems)
      {
        onSaved?(created)
      }
    }
    dismiss()
  }

  private func isSelected(_ exercise: ExerciseLibraryItem) -> Bool {
    selectedExercises.contains(where: { $0.base.name == exercise.name })
  }

  private func toggleSelection(of exercise: ExerciseLibraryItem) {
    if isSelected(exercise) {
      selectedExercises.removeAll(where: { $0.base.name == exercise.name })
    } else {
      selectedExercises.append(EditableExercise(base: exercise))
    }
  }

  private func muscleColor(_ muscle: String) -> Color {
    switch muscle {
    case "Brust":    return Color(hex: "FF6B6B").opacity(0.8)
    case "Rücken":   return Color(hex: "4ECDC4").opacity(0.8)
    case "Beine":    return Color(hex: "45B7D1").opacity(0.8)
    case "Schulter": return Color(hex: "F7DC6F").opacity(0.8)
    case "Bizeps":   return Color(hex: "BB8FCE").opacity(0.8)
    case "Trizeps":  return Color(hex: "F0A500").opacity(0.8)
    case "Bauch":    return Color(hex: "E74C3C").opacity(0.8)
    case "Glutes":   return Color(hex: "E91E8C").opacity(0.8)
    case "Waden":    return Color(hex: "58D68D").opacity(0.8)
    default:         return GainsColor.lime.opacity(0.7)
    }
  }
}
