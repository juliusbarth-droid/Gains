import SwiftUI

private enum ProgressSurface: String, CaseIterable, Identifiable {
  case overview
  case health
  case history

  var id: Self { self }

  var title: String {
    switch self {
    case .overview: return "Überblick"
    case .health:   return "Health"
    case .history:  return "Verlauf"
    }
  }
}

/// Vollbild-Variante des Fortschritts (mit Wordmark, Hintergrund und ScrollView).
/// Wird aktuell nicht mehr direkt angezeigt — der Fortschritt erscheint nur noch
/// als aufklappbarer Bereich auf dem Home-Screen via `ProgressContentView`.
/// Bleibt als Wrapper bestehen, falls künftig wieder ein eigenständiges
/// Fortschritts-Surface gebraucht wird.
struct ProgressView: View {
  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 20) {
        screenHeader(
          eyebrow: "BODY / REFLECTION",
          title: "Fortschritt",
          subtitle: "Training, Gewicht und Readiness auf einen Blick."
        )
        ProgressContentView()
      }
    }
  }
}

/// Inhaltsteil des Fortschritts ohne `GainsScreen`-Wrapper und ohne Header,
/// damit er sich problemlos in andere Screens (z. B. den Home-Screen als
/// aufklappbarer Bereich) einbetten lässt.
struct ProgressContentView: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore
  @State private var selectedSurface: ProgressSurface = .overview
  @State private var showsQuickCheckIns = false

  private let twoColumnGrid = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
  private let vitalColumns   = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      weekHeroCard
      sessionDotsStrip
      compactStatsRow

      collapsibleProgressSection(
        title: "Check-ins",
        subtitle: "Gewicht, Taille, Protein und Vitals",
        isExpanded: $showsQuickCheckIns,
        content: { quickActionsSection }
      )

      surfacePicker
      visibleContent
    }
  }

  // MARK: - Week Hero Card

  private var weekHeroCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["WOCHE", weekLabel, "TRAINING"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.onCtaSurface.opacity(0.6)
      )

      HStack(alignment: .center, spacing: 16) {
        // Ring
        ZStack {
          Circle()
            .stroke(GainsColor.onCtaSurface.opacity(0.15), lineWidth: 11)
          Circle()
            .trim(from: 0, to: weekProgress)
            .stroke(GainsColor.lime, style: StrokeStyle(lineWidth: 11, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(.easeOut(duration: 0.6), value: weekProgress)
          VStack(spacing: 0) {
            Text("\(store.weeklySessionsCompleted)")
              .font(GainsFont.display(38))
              .foregroundStyle(GainsColor.onCtaSurface)
            Text("/ \(store.weeklyGoalCount)")
              .font(GainsFont.label(11))
              .tracking(1.2)
              .foregroundStyle(GainsColor.onCtaSurface.opacity(0.55))
          }
        }
        .frame(width: 110, height: 110)

        VStack(alignment: .leading, spacing: 8) {
          Text(sessionStatusLabel)
            .font(GainsFont.title(22))
            .foregroundStyle(GainsColor.lime)
            .lineLimit(2)

          Text(motivationText)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.76))
            .lineLimit(3)
        }
      }

      Button {
        navigation.openTraining(workspace: .kraft)
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "bolt.fill")
            .font(.system(size: 11, weight: .bold))
          Text(momentumCTA)
            .font(GainsFont.label(11))
            .tracking(1.4)
        }
        .foregroundStyle(GainsColor.lime)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(GainsColor.onCtaSurface.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(20)
    .background(GainsColor.ctaSurface)
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  // MARK: - Session Dots Strip (NEW)

  private var sessionDotsStrip: some View {
    HStack(spacing: 0) {
      HStack(spacing: 7) {
        ForEach(0..<max(store.weeklyGoalCount, 1), id: \.self) { index in
          ZStack {
            Circle()
              .fill(
                index < store.weeklySessionsCompleted
                  ? GainsColor.lime
                  : GainsColor.border.opacity(0.35)
              )
              .frame(width: 11, height: 11)
            if index < store.weeklySessionsCompleted {
              Image(systemName: "checkmark")
                .font(.system(size: 6, weight: .black))
                .foregroundStyle(GainsColor.ctaSurface)
            }
          }
        }
      }

      Spacer()

      let remaining = max(store.weeklyGoalCount - store.weeklySessionsCompleted, 0)
      Text(
        remaining == 0
          ? "Wochenziel erreicht ✓"
          : "\(remaining) Session\(remaining == 1 ? "" : "s") fehlen noch"
      )
      .font(GainsFont.label(10))
      .tracking(1.3)
      .foregroundStyle(
        remaining == 0 ? GainsColor.moss : GainsColor.softInk
      )
    }
    .padding(.horizontal, 2)
  }

  // MARK: - Compact Stats Row (improved)

  private var compactStatsRow: some View {
    HStack(spacing: 10) {
      compactStatCard(
        label: "GEWICHT",
        value: String(format: "%.1f kg", store.currentWeight),
        detail: weightDeltaLabel,
        detailColor: weightDeltaColor,
        icon: weightDeltaIcon,
        iconColor: weightDeltaColor
      )
      compactStatCard(
        label: "STREAK",
        value: "\(store.streakDays)T",
        detail: store.streakDays >= 7 ? "Starker Rhythmus" : "Dranbleiben",
        detailColor: store.streakDays >= 7 ? GainsColor.moss : GainsColor.softInk,
        icon: store.streakDays >= 7 ? "flame.fill" : "flame",
        iconColor: store.streakDays >= 3 ? GainsColor.lime : GainsColor.softInk
      )
      compactStatCard(
        label: "SCORE",
        value: "\(bodyProgressScore)",
        detail: scoreLabel,
        detailColor: scoreColor,
        icon: "chart.line.uptrend.xyaxis",
        iconColor: scoreColor
      )
    }
  }

  private func compactStatCard(
    label: String,
    value: String,
    detail: String,
    detailColor: Color,
    icon: String,
    iconColor: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        Text(label)
          .font(GainsFont.label(9))
          .tracking(1.8)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        Image(systemName: icon)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(iconColor)
      }

      Text(value)
        .font(GainsFont.title(19))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text(detail)
        .font(GainsFont.body(11))
        .foregroundStyle(detailColor)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(13)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
    )
  }

  // MARK: - Surface Picker

  private var surfacePicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(ProgressSurface.allCases) { surface in
          Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedSurface = surface }
          } label: {
            Text(surface.title)
              .font(GainsFont.label(10))
              .tracking(1.5)
              .foregroundStyle(selectedSurface == surface ? GainsColor.onLime : GainsColor.softInk)
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

  // MARK: - Tab Content Router

  @ViewBuilder
  private var visibleContent: some View {
    switch selectedSurface {
    case .overview:
      VStack(alignment: .leading, spacing: 22) {
        progressScoreSection
        bodyCompositionCard
        goalSection
        trainingStatsSection
        exerciseStrengthSection
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
        weeklyVolumeSection
        workoutHistorySection
        runningHistorySection
        milestonesSection
      }
    }
  }

  // MARK: - Overview: Progress Score (NEW)

  private var progressScoreSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["DEIN", "SCORE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      HStack(spacing: 16) {
        // Score Ring
        ZStack {
          Circle()
            .stroke(GainsColor.border.opacity(0.25), lineWidth: 9)
          Circle()
            .trim(from: 0, to: CGFloat(bodyProgressScore) / 100.0)
            .stroke(
              scoreRingColor,
              style: StrokeStyle(lineWidth: 9, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .animation(.easeOut(duration: 0.8), value: bodyProgressScore)
          VStack(spacing: 1) {
            Text("\(bodyProgressScore)")
              .font(GainsFont.display(28))
              .foregroundStyle(GainsColor.ink)
            Text("/ 100")
              .font(GainsFont.label(9))
              .tracking(1.2)
              .foregroundStyle(GainsColor.softInk)
          }
        }
        .frame(width: 86, height: 86)

        VStack(alignment: .leading, spacing: 10) {
          // Score breakdown pills
          scorePill(
            label: "Woche",
            value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)",
            fraction: weekProgress,
            color: GainsColor.lime
          )
          scorePill(
            label: "Streak",
            value: "\(store.streakDays)T",
            fraction: min(Double(store.streakDays) / 14.0, 1.0),
            color: store.streakDays >= 7 ? GainsColor.lime : GainsColor.border.opacity(0.6)
          )
          scorePill(
            label: "Ziele",
            value: "\(store.goalCompletionCount)/\(store.currentGoals.count)",
            fraction: store.currentGoals.isEmpty ? 0 : Double(store.goalCompletionCount) / Double(store.currentGoals.count),
            color: GainsColor.moss
          )
        }
        .frame(maxWidth: .infinity)
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private func scorePill(label: String, value: String, fraction: Double, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        Text(label.uppercased())
          .font(GainsFont.label(9))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        Text(value)
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(GainsColor.ink)
      }
      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule().fill(GainsColor.border.opacity(0.3)).frame(height: 5)
          Capsule().fill(color).frame(width: proxy.size.width * max(fraction, 0), height: 5)
        }
      }
      .frame(height: 5)
    }
  }

  // MARK: - Overview: Body Composition Card

  private var bodyCompositionCard: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        Button { store.shareProgressUpdate() } label: {
          ProgressHighlightCard(
            title: "Start",
            value: String(format: "%.1f kg", store.startingWeight),
            accent: GainsColor.softInk,
            subtitle: "Ausgangswert"
          )
        }
        .buttonStyle(.plain)

        Button { store.logWeightCheckIn() } label: {
          ProgressHighlightCard(
            title: "Jetzt",
            value: String(format: "%.1f kg", store.currentWeight),
            accent: GainsColor.lime,
            subtitle: weightDeltaBadge
          )
        }
        .buttonStyle(.plain)
      }

      Button { store.logWaistCheckIn() } label: {
        ProgressHighlightCard(
          title: "Taille",
          value: String(format: "%.1f cm", store.waistMeasurement),
          accent: GainsColor.ink,
          subtitle: waistDeltaBadge
        )
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Overview: Goals (improved — % + celebration)

  private var goalSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["GOALS", "AKTIV"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      ForEach(store.currentGoals) { goal in
        let progress = progressValue(for: goal)
        let isDone = progress >= 1.0

        VStack(alignment: .leading, spacing: 10) {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(goal.title)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)
              Text(String(format: "%.0f / %.0f %@", goal.current, goal.target, goal.unit))
                .font(GainsFont.label(10))
                .tracking(1.2)
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()

            if isDone {
              HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                  .font(.system(size: 14))
                Text("Erreicht")
                  .font(GainsFont.label(10))
                  .tracking(1.2)
              }
              .foregroundStyle(GainsColor.moss)
            } else {
              Text(String(format: "%.0f%%", progress * 100))
                .font(GainsFont.title(18))
                .foregroundStyle(progress > 0.7 ? GainsColor.moss : GainsColor.softInk)
            }
          }

          GeometryReader { proxy in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(GainsColor.border.opacity(0.3))
                .frame(height: 7)
              Capsule()
                .fill(isDone ? GainsColor.moss : GainsColor.lime)
                .frame(width: proxy.size.width * progress, height: 7)
                .animation(.easeOut(duration: 0.5), value: progress)
            }
          }
          .frame(height: 7)

          if !isDone {
            Button {
              goalAction(for: goal)()
            } label: {
              Text(goalActionTitle(for: goal))
                .font(GainsFont.label(10))
                .tracking(1.4)
                .foregroundStyle(GainsColor.lime)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(GainsColor.ctaSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(16)
        .gainsCardStyle(isDone ? GainsColor.moss.opacity(0.08) : nil)
      }
    }
  }

  // MARK: - Overview: Training Stats

  private var trainingStatsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TRAINING", "STATS"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      LazyVGrid(columns: twoColumnGrid, spacing: 10) {
        ForEach(store.progressPerformanceStats) { stat in
          PerformanceStatCard(stat: stat)
        }
      }
    }
  }

  // MARK: - Overview: Exercise Strength (improved — PR badge)

  @ViewBuilder
  private var exerciseStrengthSection: some View {
    if !store.exerciseStrengthProgress.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["ÜBUNGEN", "FORTSCHRITT"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        ForEach(store.exerciseStrengthProgress) { exercise in
          let isPR = exercise.deltaLabel.contains("+")

          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
              HStack(spacing: 8) {
                Text(exercise.exerciseName)
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)

                if isPR {
                  Text("PR")
                    .font(GainsFont.label(8))
                    .tracking(1.4)
                    .foregroundStyle(GainsColor.ctaSurface)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(GainsColor.lime)
                    .clipShape(Capsule())
                }
              }

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
                .tracking(1.2)
                .foregroundStyle(isPR ? GainsColor.moss : GainsColor.softInk)
            }
          }
          .padding(16)
          .gainsCardStyle(isPR ? GainsColor.lime.opacity(0.07) : nil)
        }
      }
    }
  }

  // MARK: - Check-ins Section (icons added)

  private var quickActionsSection: some View {
    LazyVGrid(columns: twoColumnGrid, spacing: 10) {
      quickActionButton(title: "Wiegen",  icon: "scalemass.fill",    action: store.logWeightCheckIn)
      quickActionButton(title: "Taille",  icon: "ruler.fill",         action: store.logWaistCheckIn)
      quickActionButton(title: "Protein", icon: "bolt.fill",           action: store.logProteinCheckIn)
      quickActionButton(title: "Vitals",  icon: "heart.text.square.fill", action: store.syncVitalData)
    }
  }

  private func quickActionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(GainsColor.lime)

        Text(title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)

        Text("Eintragen")
          .font(GainsFont.label(9))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
      }
      .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
      .padding(14)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
  }

  // MARK: - History: Weight Trend

  private var trendSection: some View {
    let latest = store.weightTrend.last?.value ?? store.currentWeight
    let first  = store.weightTrend.first?.value ?? latest
    let delta  = latest - first

    return VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TREND", "7 TAGE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 6) {
            Text("Gewichtstrend")
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)
            Text(
              delta == 0 ? "Stabil über 7 Tage"
              : delta < 0 ? "\(String(format: "%.1f", abs(delta))) kg runter"
              : "+\(String(format: "%.1f", delta)) kg in 7 Tagen"
            )
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
          }
          Spacer()
          Text(String(format: "%.1f kg", latest))
            .font(GainsFont.display(28))
            .foregroundStyle(GainsColor.lime)
        }

        HStack(spacing: 10) {
          trendStatPill(title: "Start", value: String(format: "%.1f", first))
          trendStatPill(title: "Jetzt", value: String(format: "%.1f", latest))
          trendStatPill(
            title: "Delta",
            value: delta == 0 ? "±0.0" : String(format: "%@%.1f", delta > 0 ? "+" : "", delta)
          )
        }

        weightTrendChart
      }
      .padding(18)
      .gainsCardStyle()
      .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .onTapGesture { store.logWeightCheckIn() }
    }
  }

  private var weightTrendChart: some View {
    let points   = store.weightTrend
    let maxValue = points.map(\.value).max() ?? 1
    let minValue = points.map(\.value).min() ?? 0
    let span     = max(maxValue - minValue, 0.1)

    return VStack(alignment: .leading, spacing: 12) {
      GeometryReader { proxy in
        let w      = proxy.size.width
        let h      = proxy.size.height
        let stepX  = points.count > 1 ? w / CGFloat(points.count - 1) : w

        ZStack(alignment: .topLeading) {
          // Grid lines
          VStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { _ in
              Rectangle().fill(GainsColor.border.opacity(0.18)).frame(height: 1)
              Spacer()
            }
            Rectangle().fill(GainsColor.border.opacity(0.18)).frame(height: 1)
          }

          // Fill area
          Path { path in
            guard !points.isEmpty else { return }
            for (i, p) in points.enumerated() {
              let x = CGFloat(i) * stepX
              let y = h - CGFloat((p.value - minValue) / span) * (h - 12) - 6
              if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
              else       { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.addLine(to: CGPoint(x: CGFloat(points.count - 1) * stepX, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.closeSubpath()
          }
          .fill(LinearGradient(
            colors: [GainsColor.lime.opacity(0.22), GainsColor.lime.opacity(0.02)],
            startPoint: .top, endPoint: .bottom
          ))

          // Line
          Path { path in
            for (i, p) in points.enumerated() {
              let x = CGFloat(i) * stepX
              let y = h - CGFloat((p.value - minValue) / span) * (h - 12) - 6
              if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
              else       { path.addLine(to: CGPoint(x: x, y: y)) }
            }
          }
          .stroke(GainsColor.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

          // Dots + labels
          ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
            let x      = CGFloat(index) * stepX
            let y      = h - CGFloat((point.value - minValue) / span) * (h - 12) - 6
            let isLast = point.id == points.last?.id

            VStack(spacing: 5) {
              if isLast {
                Text(String(format: "%.1f", point.value))
                  .font(GainsFont.label(9))
                  .foregroundStyle(GainsColor.lime)
              }
              Circle()
                .fill(isLast ? GainsColor.lime : GainsColor.ctaSurface)
                .frame(width: isLast ? 11 : 8, height: isLast ? 11 : 8)
                .overlay(Circle().stroke(GainsColor.card, lineWidth: 2))
            }
            .position(x: x, y: max(y - (isLast ? 14 : 10), 14))
          }
        }
      }
      .frame(height: 160)

      // Day labels
      HStack(spacing: 0) {
        ForEach(store.weightTrend) { point in
          Text(point.label)
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(
              point.id == store.weightTrend.last?.id ? GainsColor.lime : GainsColor.softInk
            )
            .frame(maxWidth: .infinity)
        }
      }
    }
  }

  private func trendStatPill(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - History: Weekly Volume (NEW)

  @ViewBuilder
  private var weeklyVolumeSection: some View {
    let history = store.workoutHistory
    if !history.isEmpty {
      let volumes   = Array(history.prefix(6).map(\.volume).reversed())
      let maxVolume = volumes.max() ?? 1

      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["VOLUMEN", "TREND"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        VStack(alignment: .leading, spacing: 16) {
          HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
              Text("Trainingsvolumen")
                .font(GainsFont.title(20))
                .foregroundStyle(GainsColor.ink)
              Text("Letzte \(volumes.count) Sessions")
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }
            Spacer()
            if let peak = volumes.last {
              Text(String(format: "%.1f t", peak / 1000))
                .font(GainsFont.display(26))
                .foregroundStyle(GainsColor.lime)
            }
          }

          // Bar chart
          HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(volumes.enumerated()), id: \.offset) { index, vol in
              let fraction = CGFloat(vol / maxVolume)
              let isLatest = index == volumes.count - 1

              VStack(spacing: 5) {
                Text(String(format: "%.0f", vol / 1000) + "t")
                  .font(GainsFont.label(8))
                  .tracking(0.8)
                  .foregroundStyle(isLatest ? GainsColor.lime : GainsColor.softInk)

                GeometryReader { proxy in
                  VStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                      .fill(isLatest ? GainsColor.lime : GainsColor.elevated)
                      .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                          .stroke(GainsColor.border.opacity(0.3), lineWidth: 1)
                      )
                      .frame(height: max(proxy.size.height * fraction, 8))
                  }
                }
              }
              .frame(maxWidth: .infinity)
            }
          }
          .frame(height: 110)
        }
        .padding(18)
        .gainsCardStyle()
      }
    }
  }

  // MARK: - History: Workout List

  @ViewBuilder
  private var workoutHistorySection: some View {
    if !store.workoutHistory.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["WORKOUTS", "HISTORY"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        ForEach(store.workoutHistory.prefix(3)) { workout in
          Button { store.shareProgressUpdate() } label: {
            HStack(spacing: 14) {
              // Volume badge
              VStack(spacing: 2) {
                Text(String(format: "%.1f", workout.volume / 1000))
                  .font(GainsFont.title(16))
                  .foregroundStyle(GainsColor.lime)
                Text("t")
                  .font(GainsFont.label(9))
                  .tracking(1.4)
                  .foregroundStyle(GainsColor.softInk)
              }
              .frame(width: 42, alignment: .center)

              Rectangle()
                .fill(GainsColor.border.opacity(0.3))
                .frame(width: 1, height: 36)

              VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                  .font(GainsFont.title(17))
                  .foregroundStyle(GainsColor.ink)
                Text("\(workout.completedSets) Sätze · \(workout.finishedAt.formatted(.dateTime.day().month()))")
                  .font(GainsFont.body(13))
                  .foregroundStyle(GainsColor.softInk)
              }

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GainsColor.border)
            }
            .padding(16)
            .gainsCardStyle()
          }
          .buttonStyle(.plain)
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["WORKOUTS", "HISTORY"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        EmptyStateView(
          style: .inline,
          title: "Noch keine Workouts im Verlauf",
          message: "Sobald du Trainings abschließt, erscheinen hier deine Sätze, dein Volumen und persönlichen Bestleistungen.",
          icon: "dumbbell"
        )
      }
    }
  }

  // MARK: - History: Run List

  @ViewBuilder
  private var runningHistorySection: some View {
    if !store.runHistory.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["RUNNING", "HISTORY"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        ForEach(store.runHistory.prefix(3)) { run in
          Button { store.shareProgressUpdate() } label: {
            HStack(spacing: 14) {
              // Distance badge
              VStack(spacing: 2) {
                Text(String(format: "%.1f", run.distanceKm))
                  .font(GainsFont.title(16))
                  .foregroundStyle(GainsColor.lime)
                Text("km")
                  .font(GainsFont.label(9))
                  .tracking(1.4)
                  .foregroundStyle(GainsColor.softInk)
              }
              .frame(width: 42, alignment: .center)

              Rectangle()
                .fill(GainsColor.border.opacity(0.3))
                .frame(width: 1, height: 36)

              VStack(alignment: .leading, spacing: 4) {
                Text(run.title)
                  .font(GainsFont.title(17))
                  .foregroundStyle(GainsColor.ink)
                Text("\(paceLabel(run.averagePaceSeconds)) · \(run.averageHeartRate) bpm · \(run.finishedAt.formatted(.dateTime.day().month()))")
                  .font(GainsFont.body(13))
                  .foregroundStyle(GainsColor.softInk)
              }

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GainsColor.border)
            }
            .padding(16)
            .gainsCardStyle()
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: - History: Milestones Timeline (improved)

  private var milestonesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["MILESTONES", "TIMELINE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(store.currentMilestones.enumerated()), id: \.element.id) { index, milestone in
          HStack(alignment: .top, spacing: 14) {
            // Timeline spine
            VStack(spacing: 0) {
              Circle()
                .fill(GainsColor.lime)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

              if index < store.currentMilestones.count - 1 {
                Rectangle()
                  .fill(GainsColor.border.opacity(0.4))
                  .frame(width: 2)
                  .frame(maxHeight: .infinity)
                  .padding(.vertical, 4)
              }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text(milestone.title)
                  .font(GainsFont.title(17))
                  .foregroundStyle(GainsColor.ink)
                Spacer()
                Text(milestone.dateLabel)
                  .font(GainsFont.label(9))
                  .tracking(2)
                  .foregroundStyle(GainsColor.softInk)
              }
              Text(milestone.detail)
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }
            .padding(.bottom, index < store.currentMilestones.count - 1 ? 16 : 0)
          }
        }
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  // MARK: - Health: Apple Health

  private var appleHealthSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["APPLE", "HEALTH"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

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
          Button { store.syncVitalData() } label: {
            Text(store.hasConnectedAppleHealth ? "Sync" : "Verbinden")
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(store.hasConnectedAppleHealth ? GainsColor.onLime : GainsColor.lime)
              .frame(width: 92, height: 36)
              .background(store.hasConnectedAppleHealth ? GainsColor.lime : GainsColor.ctaSurface)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }

        LazyVGrid(columns: twoColumnGrid, spacing: 10) {
          ForEach(store.appleHealthHighlights) { stat in
            HealthSnapshotCard(stat: stat)
          }
        }
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  // MARK: - Health: Trackers

  private var trackerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TRACKER", "CONNECT"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      ForEach(store.trackerOptions) { tracker in
        Button { store.toggleTrackerConnection(tracker.id) } label: {
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
                store.isTrackerConnected(tracker.id) ? GainsColor.onLime : GainsColor.lime
              )
              .frame(width: 96, height: 36)
              .background(store.isTrackerConnected(tracker.id) ? GainsColor.lime : GainsColor.ctaSurface)
              .clipShape(Capsule())
          }
          .padding(16)
          .gainsCardStyle()
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Health: Vitals

  private var vitalSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["VITALS", "LIVE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      LazyVGrid(columns: vitalColumns, spacing: 12) {
        ForEach(store.currentVitalReadings) { vital in
          Button { store.syncVitalData() } label: {
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

  // MARK: - Health: Health Impact

  private var healthMetricSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["HEALTH", "IMPACT"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(alignment: .leading, spacing: 16) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Cardio-Risiko")
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)
            Text(store.currentBloodPanelStatus)
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(2)
          }
          Spacer()
          Text("-\(store.currentCardioRiskImprovement)%")
            .font(GainsFont.display(28))
            .foregroundStyle(GainsColor.onLime)
        }

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
      .gainsCardStyle(GainsColor.lime.opacity(0.6))
      .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .onTapGesture { store.syncVitalData() }
    }
  }

  // MARK: - Collapsible Wrapper

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
        HStack(spacing: 12) {
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

  // MARK: - Computed Properties

  private var weekLabel: String {
    "KW\(Calendar.current.component(.weekOfYear, from: Date()))"
  }

  private var weekProgress: Double {
    min(Double(store.weeklySessionsCompleted) / Double(max(store.weeklyGoalCount, 1)), 1.0)
  }

  private var sessionStatusLabel: String {
    let remaining = max(store.weeklyGoalCount - store.weeklySessionsCompleted, 0)
    if remaining == 0 { return "Wochenziel erreicht 🎯" }
    if remaining == 1 { return "Noch eine Session" }
    return "\(remaining) Sessions offen"
  }

  private var weightDeltaLabel: String {
    let delta = store.startingWeight - store.currentWeight
    if abs(delta) < 0.05 { return "Stabil" }
    return String(format: "%@%.1f kg", delta > 0 ? "–" : "+", abs(delta))
  }

  private var weightDeltaColor: Color {
    let delta = store.startingWeight - store.currentWeight
    if abs(delta) < 0.05 { return GainsColor.softInk }
    return delta > 0 ? GainsColor.moss : GainsColor.softInk
  }

  private var weightDeltaIcon: String {
    let delta = store.startingWeight - store.currentWeight
    if abs(delta) < 0.05 { return "minus" }
    return delta > 0 ? "arrow.down" : "arrow.up"
  }

  private var weightDeltaBadge: String {
    let delta = store.startingWeight - store.currentWeight
    if abs(delta) < 0.05 { return "Stabil" }
    return String(format: "%@%.1f kg seit Start", delta > 0 ? "–" : "+", abs(delta))
  }

  private var waistDeltaBadge: String {
    let delta = store.startingWaist - store.waistMeasurement
    if abs(delta) < 0.05 { return "Stabil" }
    return String(format: "%.1f cm weniger", abs(delta))
  }

  private var motivationText: String {
    if store.personalRecordCount > 0 {
      let word = store.personalRecordCount == 1 ? "Rekord" : "Rekorde"
      return "\(store.personalRecordCount) neue \(word) diese Woche."
    }
    if store.streakDays >= 14 {
      return "\(store.streakDays) Tage am Stück — das ist deine neue Baseline."
    }
    if store.streakDays >= 7 {
      return "Eine Woche Momentum. Jetzt zur Routine machen."
    }
    if weekProgress >= 1.0 {
      return "Wochenziel gecheckt. Jede Session zählt."
    }
    let remaining = max(store.weeklyGoalCount - store.weeklySessionsCompleted, 0)
    return remaining == 1
      ? "Noch eine Session bis zum Wochenziel."
      : "\(remaining) Sessions bis zum Wochenziel."
  }

  private var momentumCTA: String {
    let sessionsLeft = max(store.weeklyGoalCount - store.weeklySessionsCompleted, 0)
    if sessionsLeft == 0 { return "Bonus-Session starten" }
    return sessionsLeft == 1 ? "Letzte Session diese Woche" : "Nächste Session starten"
  }

  // MARK: - Body Progress Score (composite 0–100)

  private var bodyProgressScore: Int {
    // Weight component (40 pts): progress toward weight goal
    let weightGoal = store.currentGoals.first(where: { $0.title == "Körpergewicht" })
    let weightPts: Double
    if let goal = weightGoal {
      let totalToLose = max(store.startingWeight - goal.target, 0.1)
      let lost = store.startingWeight - store.currentWeight
      weightPts = min(max(lost / totalToLose, 0), 1.0) * 40
    } else {
      weightPts = 0
    }

    // Session component (35 pts): weekly sessions vs goal
    let sessionPts = min(
      Double(store.weeklySessionsCompleted) / Double(max(store.weeklyGoalCount, 1)), 1.0
    ) * 35

    // Streak component (25 pts): streak up to 14 days = full
    let streakPts = min(Double(store.streakDays) / 14.0, 1.0) * 25

    return Int((weightPts + sessionPts + streakPts).rounded())
  }

  private var scoreLabel: String {
    switch bodyProgressScore {
    case 80...100: return "Ausgezeichnet"
    case 60..<80:  return "Auf Kurs"
    case 40..<60:  return "Solide Basis"
    default:       return "Aufbauen"
    }
  }

  private var scoreColor: Color {
    switch bodyProgressScore {
    case 80...100: return GainsColor.moss
    case 60..<80:  return GainsColor.lime
    default:       return GainsColor.softInk
    }
  }

  private var scoreRingColor: Color {
    switch bodyProgressScore {
    case 80...100: return GainsColor.moss
    case 50..<80:  return GainsColor.lime
    default:       return GainsColor.border.opacity(0.7)
    }
  }

  // MARK: - Goal Helpers

  private func progressValue(for goal: ProgressGoal) -> Double {
    switch goal.title {
    case "Körpergewicht":
      return min(
        max((store.startingWeight - goal.current) / max(store.startingWeight - goal.target, 0.1), 0),
        1
      )
    case "Taillenumfang":
      return min(
        max((store.startingWaist - goal.current) / max(store.startingWaist - goal.target, 0.1), 0),
        1
      )
    default:
      return min(goal.current / max(goal.target, 0.1), 1)
    }
  }

  private func goalActionTitle(for goal: ProgressGoal) -> String {
    switch goal.title {
    case "Körpergewicht": return "Wiegen"
    case "Taillenumfang": return "Taille eintragen"
    default:              return "Protein loggen"
    }
  }

  private func goalAction(for goal: ProgressGoal) -> () -> Void {
    switch goal.title {
    case "Körpergewicht": return store.logWeightCheckIn
    case "Taillenumfang": return store.logWaistCheckIn
    default:              return store.logProteinCheckIn
    }
  }

  // MARK: - Tracker Helpers

  private func buttonTitle(for tracker: TrackerDevice) -> String {
    if tracker.source == "HealthKit"    { return store.isTrackerConnected(tracker.id) ? "Sync"     : "Health" }
    if tracker.source == "WHOOP OAuth"  { return store.isTrackerConnected(tracker.id) ? "Sync"     : "WHOOP"  }
    return store.isTrackerConnected(tracker.id) ? "Verbunden" : "Connect"
  }

  // MARK: - Run Helper

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:-- /km" }
    return String(format: "%d:%02d /km", seconds / 60, seconds % 60)
  }
}

// MARK: - Private Card Components

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

// MARK: - gainsCardStyle overload accepting optional background

private extension View {
  @ViewBuilder
  func gainsCardStyle(_ background: Color?) -> some View {
    if let bg = background {
      self.gainsCardStyle(bg)
    } else {
      self.gainsCardStyle()
    }
  }
}
