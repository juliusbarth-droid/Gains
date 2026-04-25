import SwiftUI

private enum ProgressSurface: String, CaseIterable, Identifiable {
  case overview
  case health
  case history

  var id: Self { self }

  var title: String {
    switch self {
    case .overview: return "Überblick"
    case .health: return "Health"
    case .history: return "Verlauf"
    }
  }
}

struct ProgressView: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore
  let viewModel: ProgressViewModel
  @State private var selectedSurface: ProgressSurface = .overview
  @State private var showsQuickCheckIns = false

  private let quickActionColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
  private let vitalColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        screenHeader(
          eyebrow: "BODY / REFLECTION",
          title: "Readiness und Verlauf",
          subtitle:
            "Dein Fortschritt verbindet Körperdaten, Vitalwerte und Trainingsdaten in einem klaren Überblick."
        )

        bodyReadinessHero
        progressSummaryCard
        quickStatusRow
        collapsibleProgressSection(
          title: "Schnelle Check-ins",
          subtitle: "Wiegen, Taille, Protein und Vitals nur bei Bedarf einblenden",
          isExpanded: $showsQuickCheckIns,
          content: { quickActionsSection }
        )
        surfacePicker
        visibleContent
      }
    }
  }

  private var surfacePicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(ProgressSurface.allCases) { surface in
          Button {
            selectedSurface = surface
          } label: {
            Text(surface.title)
              .font(GainsFont.label(10))
              .tracking(1.5)
              .foregroundStyle(selectedSurface == surface ? GainsColor.ink : GainsColor.softInk)
              .padding(.horizontal, 16)
              .frame(height: 38)
              .background(selectedSurface == surface ? GainsColor.lime : GainsColor.card)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  @ViewBuilder
  private var visibleContent: some View {
    switch selectedSurface {
    case .overview:
      VStack(alignment: .leading, spacing: 22) {
        achievementHeroSection
        statusFocusSection
        bodyCompositionCard
        goalSection
        trainingStatsSection
        exerciseStrengthSection
        progressFeedbackSection
      }
    case .health:
      VStack(alignment: .leading, spacing: 22) {
        appleHealthSection
        trackerSection
        vitalSection
        healthMetricSection
      }
    case .history:
      VStack(alignment: .leading, spacing: 22) {
        trendSection
        runningHistorySection
        workoutHistorySection
        milestonesSection
      }
    }
  }

  private var progressSummaryCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["PROGRESS", "STATUS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 10) {
        Text(store.progressSummaryHeadline)
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        Text(store.progressSummaryDescription)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)

        Button {
          navigation.presentCapture(kind: .progress)
        } label: {
          Text("Progress teilen")
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(GainsColor.lime)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(GainsColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var bodyReadinessHero: some View {
    VStack(alignment: .leading, spacing: 18) {
      SlashLabel(
        parts: ["READINESS", readinessStatus.uppercased(), "BODY"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.card.opacity(0.72)
      )

      HStack(alignment: .center, spacing: 18) {
        ZStack {
          Circle()
            .stroke(GainsColor.card.opacity(0.12), lineWidth: 14)

          Circle()
            .trim(from: 0, to: CGFloat(readinessScore) / 100)
            .stroke(
              GainsColor.lime,
              style: StrokeStyle(lineWidth: 14, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))

          VStack(spacing: 2) {
            Text("\(readinessScore)")
              .font(GainsFont.display(42))
              .foregroundStyle(GainsColor.card)

            Text("%")
              .font(GainsFont.label(10))
              .tracking(1.6)
              .foregroundStyle(GainsColor.card.opacity(0.66))
          }
        }
        .frame(width: 126, height: 126)

        VStack(alignment: .leading, spacing: 12) {
          Text(readinessStatus)
            .font(GainsFont.title(26))
            .foregroundStyle(GainsColor.lime)

          Text(readinessSummary)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.card.opacity(0.8))
            .lineLimit(4)
        }
      }

      HStack(spacing: 10) {
        readinessMetric(title: "HRV", value: vitalValue("HRV"))
        readinessMetric(title: "RHR", value: vitalValue("Ruhepuls"))
        readinessMetric(title: "Schlaf", value: vitalValue("Schlaf"))
      }
    }
    .padding(20)
    .background(GainsColor.ink)
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  private var achievementHeroSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["ERREICHT", "DIESE WOCHE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 14) {
        Text("\(store.weeklySessionsCompleted) von \(store.weeklyGoalCount) Sessions erledigt")
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)

        Text(momentumSummary)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.onLimeSecondary)
          .lineLimit(3)

        HStack(spacing: 10) {
          achievementPill(title: "Rekorde", value: "+ \(store.personalRecordCount)")
          achievementPill(title: "Streak", value: "\(store.streakDays) Tage")
          achievementPill(title: "Check-ins", value: "\(store.goalCompletionCount)")
        }

        Button {
          navigation.openTraining(workspace: .kraft)
        } label: {
          Text(momentumCTA)
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(GainsColor.lime)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(GainsColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
      }
      .padding(20)
      .background(GainsColor.lime.opacity(0.82))
      .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
  }

  private var statusFocusSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["JETZT", "WICHTIG"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 10) {
        Text(store.progressSummaryHeadline)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        Text(store.progressSummaryDescription)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var bodyCompositionCard: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        Button {
          store.shareProgressUpdate()
        } label: {
          ProgressHighlightCard(
            title: "Start", value: String(format: "%.1f kg", store.startingWeight),
            accent: GainsColor.ink, subtitle: "Ausgangswert")
        }
        .buttonStyle(.plain)

        Button {
          store.logWeightCheckIn()
        } label: {
          ProgressHighlightCard(
            title: "Jetzt", value: String(format: "%.1f kg", store.currentWeight),
            accent: GainsColor.lime,
            subtitle: String(format: "%.1f kg Delta", store.startingWeight - store.currentWeight))
        }
        .buttonStyle(.plain)
      }

      Button {
        store.logWaistCheckIn()
      } label: {
        ProgressHighlightCard(
          title: "Taille", value: String(format: "%.1f cm", store.waistMeasurement),
          accent: GainsColor.ink,
          subtitle: String(format: "%.1f cm weniger", store.startingWaist - store.waistMeasurement))
      }
      .buttonStyle(.plain)
    }
  }

  private var momentumSummary: String {
    let sessionsLeft = max(store.weeklyGoalCount - store.weeklySessionsCompleted, 0)

    if sessionsLeft == 0 {
      return "Wochenziel erreicht. Halte den Lauf mit einem lockeren Check-in oder einer Bonus-Session am Leben."
    }

    if sessionsLeft == 1 {
      return "Noch eine Session bis zum Wochenziel. Genau solche kleinen Zwischenziele halten die Routine stabil."
    }

    if store.streakDays >= 7 {
      return "\(store.personalRecordCount) neue Rekorde, \(store.streakDays) Tage Streak und nur noch \(sessionsLeft) Sessions bis zum Wochenziel. Bleib im Rhythmus."
    }

    return "\(store.personalRecordCount) neue Rekorde, \(store.streakDays) Tage Streak und \(store.goalCompletionCount) Ziele aktuell on track. Der nächste kleine Haken zählt."
  }

  private var momentumCTA: String {
    let sessionsLeft = max(store.weeklyGoalCount - store.weeklySessionsCompleted, 0)
    return sessionsLeft <= 1 ? "Letzte Session für diese Woche öffnen" : "Nächste Session starten"
  }

  private var quickActionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["CHECK-IN", "AKTIONEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      LazyVGrid(columns: quickActionColumns, spacing: 10) {
        quickActionButton(title: "Wiegen", action: store.logWeightCheckIn)
        quickActionButton(title: "Taille", action: store.logWaistCheckIn)
        quickActionButton(title: "Protein", action: store.logProteinCheckIn)
        quickActionButton(title: "Vitals", action: store.syncVitalData)
      }
    }
  }

  private var quickStatusRow: some View {
    HStack(spacing: 10) {
      progressMiniCard(title: "Gewicht", value: String(format: "%.1f kg", store.currentWeight))
      progressMiniCard(title: "Ziele", value: "\(store.goalCompletionCount)/\(store.currentGoals.count)")
      progressMiniCard(title: "Streak", value: "\(store.streakDays) Tage")
    }
  }

  private var trainingStatsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TRAINING", "STATS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      LazyVGrid(columns: quickActionColumns, spacing: 10) {
        ForEach(store.progressPerformanceStats) { stat in
          PerformanceStatCard(stat: stat)
        }
      }
    }
  }

  @ViewBuilder
  private var exerciseStrengthSection: some View {
    if !store.exerciseStrengthProgress.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["ÜBUNGEN", "FORTSCHRITT"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        ForEach(store.exerciseStrengthProgress) { exercise in
          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
              VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exerciseName)
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)

                Text(exercise.subtitle)
                  .font(GainsFont.body(13))
                  .foregroundStyle(GainsColor.softInk)
              }

              Spacer()

              VStack(alignment: .trailing, spacing: 4) {
                Text(exercise.currentValue)
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)

                Text(exercise.deltaLabel)
                  .font(GainsFont.label(10))
                  .foregroundStyle(GainsColor.moss)
              }
            }
          }
          .padding(16)
          .gainsCardStyle()
        }
      }
    }
  }

  private var progressFeedbackSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["LIVE", "UPDATE"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      VStack(alignment: .leading, spacing: 10) {
        Text(store.lastProgressEvent)
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)

        Text("\(store.goalCompletionCount) von \(store.currentGoals.count) Zielen aktuell erfüllt")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.onLimeSecondary)
          .lineLimit(1)
      }
      .padding(16)
      .gainsCardStyle(GainsColor.lime.opacity(0.22))
    }
  }

  private var trendSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TREND", "7 TAGE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      HStack(alignment: .bottom, spacing: 12) {
        let maxValue = store.weightTrend.map(\.value).max() ?? 1
        let minValue = store.weightTrend.map(\.value).min() ?? 0
        let span = max(maxValue - minValue, 0.1)

        ForEach(store.weightTrend) { point in
          VStack(spacing: 8) {
            Text(String(format: "%.1f", point.value))
              .font(GainsFont.label(9))
              .foregroundStyle(GainsColor.softInk)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(point.value == store.weightTrend.last?.value ? GainsColor.lime : GainsColor.ink)
              .frame(height: 44 + ((maxValue - point.value) / span * 56))

            Text(point.label)
              .font(GainsFont.label(9))
              .tracking(1.6)
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 150)
      .padding(18)
      .gainsCardStyle()
      .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .onTapGesture {
        store.logWeightCheckIn()
      }
    }
  }

  private var healthMetricSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["HEALTH", "IMPACT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Cardio-Risiko")
            .font(GainsFont.title(22))
            .foregroundStyle(GainsColor.ink)
          Spacer()
          Text("-\(store.currentCardioRiskImprovement)%")
            .font(GainsFont.display(28))
            .foregroundStyle(GainsColor.onLime)
        }

        Text(store.currentBloodPanelStatus)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.onLimeSecondary)
          .lineLimit(2)

        ForEach(store.currentBloodPanelSummary) { metric in
          HStack {
            Text(metric.title)
              .font(GainsFont.body())
              .foregroundStyle(GainsColor.ink)
            Spacer()
            Text(metric.value)
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.ink)
            Text(metric.trend)
              .font(GainsFont.label())
              .foregroundStyle(GainsColor.onLimeSecondary)
              .frame(minWidth: 48, alignment: .trailing)
          }
        }
      }
      .padding(18)
      .gainsCardStyle(GainsColor.lime.opacity(0.72))
      .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .onTapGesture {
        store.syncVitalData()
      }
    }
  }

  private var appleHealthSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["APPLE", "HEALTH"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 6) {
            Text(store.appleHealthHeadline)
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(2)

            Text(store.appleHealthDescription)
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(2)
          }

          Spacer(minLength: 12)

          Button {
            store.syncVitalData()
          } label: {
            Text(store.hasConnectedAppleHealth ? "Sync" : "Verbinden")
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(store.hasConnectedAppleHealth ? GainsColor.ink : GainsColor.lime)
              .frame(width: 92, height: 36)
              .background(store.hasConnectedAppleHealth ? GainsColor.lime : GainsColor.ink)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }

        LazyVGrid(columns: quickActionColumns, spacing: 10) {
          ForEach(store.appleHealthHighlights) { stat in
            HealthSnapshotCard(stat: stat)
          }
        }
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var trackerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TRACKER", "CONNECT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ForEach(store.trackerOptions) { tracker in
        Button {
          store.toggleTrackerConnection(tracker.id)
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(tracker.name)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)
              Text(tracker.source)
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()

            Text(buttonTitle(for: tracker))
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(
                store.isTrackerConnected(tracker.id) ? GainsColor.ink : GainsColor.lime
              )
              .frame(width: 96, height: 36)
              .background(store.isTrackerConnected(tracker.id) ? GainsColor.lime : GainsColor.ink)
              .clipShape(Capsule())
          }
          .padding(16)
          .gainsCardStyle()
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var vitalSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["VITALS", "LIVE"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      LazyVGrid(columns: vitalColumns, spacing: 12) {
        ForEach(store.currentVitalReadings) { vital in
          Button {
            store.syncVitalData()
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              Text(vital.title.uppercased())
                .font(GainsFont.label(9))
                .tracking(2)
                .foregroundStyle(GainsColor.softInk)
              Text(vital.value)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)
              Text(vital.context)
                .font(GainsFont.body(12))
                .foregroundStyle(GainsColor.softInk)
            }
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
            .padding(14)
            .gainsCardStyle()
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var milestonesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["MILESTONES", "TIMELINE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ForEach(store.currentMilestones) { milestone in
        Button {
          store.shareProgressUpdate()
        } label: {
          HStack(alignment: .top, spacing: 14) {
            Text(milestone.dateLabel)
              .font(GainsFont.label(10))
              .tracking(2.4)
              .foregroundStyle(GainsColor.softInk)
              .frame(width: 60, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
              Text(milestone.title)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)

              Text(milestone.detail)
                .font(GainsFont.body(14))
                .foregroundStyle(GainsColor.softInk)
            }
          }
          .padding(16)
          .gainsCardStyle()
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var goalSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["GOALS", "AKTIV"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      ForEach(store.currentGoals) { goal in
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text(goal.title)
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.ink)

            Spacer()

            Text(String(format: "%.0f / %.0f %@", goal.current, goal.target, goal.unit))
              .font(GainsFont.label())
              .foregroundStyle(GainsColor.moss)
          }

          GeometryReader { proxy in
            let progress = progressValue(for: goal)

            ZStack(alignment: .leading) {
              Capsule()
                .fill(GainsColor.border.opacity(0.4))
                .frame(height: 6)

              Capsule()
                .fill(GainsColor.lime)
                .frame(width: proxy.size.width * progress, height: 6)
            }
          }
          .frame(height: 6)

          Button {
            goalAction(for: goal)()
          } label: {
            Text(goalActionTitle(for: goal))
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(GainsColor.lime)
              .frame(maxWidth: .infinity)
              .frame(height: 40)
              .background(GainsColor.ink)
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(.plain)
        }
        .padding(16)
        .gainsCardStyle()
      }
    }
  }

  @ViewBuilder
  private var workoutHistorySection: some View {
    if !store.workoutHistory.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["WORKOUTS", "HISTORY"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        ForEach(store.workoutHistory.prefix(3)) { workout in
          Button {
            store.shareProgressUpdate()
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)

                Text(
                  "\(workout.completedSets)/\(workout.totalSets) Sätze · \(Int(workout.volume)) kg Volumen"
                )
                .font(GainsFont.body(14))
                .foregroundStyle(GainsColor.softInk)
              }

              Spacer()

              Text(workout.finishedAt, style: .date)
                .font(GainsFont.label(9))
                .foregroundStyle(GainsColor.softInk)
            }
            .padding(16)
            .gainsCardStyle()
          }
          .buttonStyle(.plain)
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 8) {
        SlashLabel(
          parts: ["WORKOUTS", "HISTORY"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        Text("Noch keine Workouts im Progress-Verlauf")
          .font(GainsFont.title(20))
          .foregroundStyle(GainsColor.ink)
      }
      .padding(16)
      .gainsCardStyle()
    }
  }

  @ViewBuilder
  private var runningHistorySection: some View {
    if !store.runHistory.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["RUNNING", "HISTORY"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        ForEach(store.runHistory.prefix(3)) { run in
          Button {
            store.shareProgressUpdate()
          } label: {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(run.title)
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)

                Text(
                  "\(String(format: "%.1f", run.distanceKm)) km · \(paceLabel(run.averagePaceSeconds)) · \(run.averageHeartRate) bpm"
                )
                .font(GainsFont.body(14))
                .foregroundStyle(GainsColor.softInk)
              }

              Spacer()

              Text(run.finishedAt, style: .date)
                .font(GainsFont.label(9))
                .foregroundStyle(GainsColor.softInk)
            }
            .padding(16)
            .gainsCardStyle()
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func quickActionButton(title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 8) {
        Text(title.uppercased())
          .font(GainsFont.label(10))
          .tracking(2)
          .foregroundStyle(GainsColor.softInk)
      }
      .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
      .padding(14)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
  }

  private func progressValue(for goal: ProgressGoal) -> Double {
    switch goal.title {
    case "Körpergewicht":
      return min(
        max(
          (store.startingWeight - goal.current) / max(store.startingWeight - goal.target, 0.1), 0),
        1)
    case "Taillenumfang":
      return min(
        max((store.startingWaist - goal.current) / max(store.startingWaist - goal.target, 0.1), 0),
        1)
    default:
      return min(goal.current / max(goal.target, 0.1), 1)
    }
  }

  private func goalActionTitle(for goal: ProgressGoal) -> String {
    switch goal.title {
    case "Körpergewicht":
      return "Wiegen"
    case "Taillenumfang":
      return "Taille eintragen"
    default:
      return "Protein loggen"
    }
  }

  private func goalAction(for goal: ProgressGoal) -> () -> Void {
    switch goal.title {
    case "Körpergewicht":
      return store.logWeightCheckIn
    case "Taillenumfang":
      return store.logWaistCheckIn
    default:
      return store.logProteinCheckIn
    }
  }

  private func buttonTitle(for tracker: TrackerDevice) -> String {
    if tracker.source == "HealthKit" {
      return store.isTrackerConnected(tracker.id) ? "Sync" : "Health"
    }
    if tracker.source == "WHOOP OAuth" {
      return store.isTrackerConnected(tracker.id) ? "Sync" : "WHOOP"
    }
    return store.isTrackerConnected(tracker.id) ? "Verbunden" : "Connect"
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:-- /km" }
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%d:%02d /km", minutes, remainingSeconds)
  }

  private func readinessMetric(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.card.opacity(0.6))

      Text(value)
        .font(GainsFont.title(16))
        .foregroundStyle(GainsColor.card)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(GainsColor.card.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func vitalValue(_ title: String) -> String {
    store.currentVitalReadings.first(where: { $0.title == title })?.value ?? "--"
  }

  private var readinessScore: Int {
    let base = 66 + (store.weeklySessionsCompleted * 3) + store.completedCoachCheckInIDs.count
    let trackerBonus = store.connectedTrackerIDs.isEmpty ? 0 : 6
    return min(max(base + trackerBonus + store.vitalSyncCount, 40), 96)
  }

  private var readinessStatus: String {
    switch readinessScore {
    case 86...:
      return "Peak"
    case 74...85:
      return "Ready"
    case 62...73:
      return "Maintain"
    case 50...61:
      return "Recover"
    default:
      return "Overreach"
    }
  }

  private var readinessSummary: String {
    if store.connectedTrackerIDs.isEmpty {
      return "Verbinde Apple Health, WHOOP, Garmin oder Oura, damit HRV, Ruhepuls und Schlaf den Score live schaerfen."
    }

    return "Deine Vitals, Check-ins und Trainingswoche laufen hier zusammen. BODY ist bewusst der laengere Reflexionsscreen."
  }
}

  private func achievementPill(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.ink.opacity(0.58))

      Text(value)
        .font(GainsFont.title(16))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(GainsColor.card.opacity(0.62))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func collapsibleProgressSection<Content: View>(
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

  private func progressMiniCard(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .gainsCardStyle()
  }

private struct ProgressHighlightCard: View {
  let title: String
  let value: String
  let accent: Color
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title.uppercased())
        .font(GainsFont.label(10))
        .tracking(2.2)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.display(26))
        .foregroundStyle(accent)

      Text(subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
    .padding(16)
    .gainsCardStyle()
  }
}

private struct PerformanceStatCard: View {
  let stat: PerformanceProgressStat

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(stat.title.uppercased())
        .font(GainsFont.label(10))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text(stat.value)
        .font(GainsFont.display(24))
        .foregroundStyle(GainsColor.ink)

      Text(stat.subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
    .padding(16)
    .gainsCardStyle()
  }
}

private struct HealthSnapshotCard: View {
  let stat: HealthPresentationStat

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(stat.title.uppercased())
        .font(GainsFont.label(10))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text(stat.value)
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text(stat.subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
    .padding(14)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }
}
