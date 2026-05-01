import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var navigation: AppNavigationStore
  @EnvironmentObject private var store: GainsStore
  // A11/A12: Live-Heart-Rate-Manager — wird beobachtet, damit der Live-BPM-
  // Banner unter dem Action-Grid bei Verbindungs- oder Wert-Änderung neu
  // rendert.
  @ObservedObject private var ble = BLEHeartRateManager.shared
  @State private var isShowingWorkoutChooser = false
  @State private var isShowingWorkoutBuilder = false
  @State private var isShowingWorkoutTracker = false
  @State private var isShowingRunTracker = false
  @State private var isShowingProfile = false
  // A11: Home-Screen-Redesign „Cockpit". Greeting-Hero + Cockpit-Card mit
  // Wochenring, Mini-Tiles und integrierter Plan-Vorschau, Nutrition-Card
  // und 2x2-Action-Grid statt separater Listen-Zeilen.
  // A12: Eyebrow-/-Slash-Ketten und „SCHNELLZUGRIFF"-Heading entfernt,
  // Tiles kompakter, planPreviewRow in die Cockpit-Card integriert.
  @State private var isShowingProgress = false
  @State private var arrangingPlan: WorkoutPlan?

  // A6: Sheet-Choreografie über `onDismiss` statt `asyncAfter`.
  // Wenn ein Sheet beim Schließen ein anderes Sheet öffnen soll, parken wir
  // die Folge-Aktion hier und führen sie im `onDismiss`-Callback des
  // jeweiligen Sheets aus — so wartet SwiftUI deterministisch auf das Ende
  // der Dismiss-Animation.
  @State private var pendingAfterChooser: (() -> Void)? = nil
  @State private var pendingAfterBuilder: (() -> Void)? = nil
  @State private var pendingAfterArrange: (() -> Void)? = nil

  var body: some View {
    ZStack {
      GainsAppBackground()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 24) {
          topBar
          if store.activeWorkout != nil {
            activeWorkoutLine
          }
          homeHero
          cockpitCard
          nutritionCard
          actionGrid
          liveBPMBanner
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 120)
      }
    }
    .sheet(
      isPresented: $isShowingWorkoutChooser,
      onDismiss: { runPending(&pendingAfterChooser) }
    ) {
      NavigationStack {
        WorkoutTrackerEntryView(
          onSelectWorkout: { plan in
            pendingAfterChooser = { presentArrange(for: plan) }
            isShowingWorkoutChooser = false
          },
          onCreateWorkout: {
            pendingAfterChooser = { isShowingWorkoutBuilder = true }
            isShowingWorkoutChooser = false
          }
        )
        .environmentObject(store)
      }
    }
    .sheet(
      isPresented: $isShowingWorkoutBuilder,
      onDismiss: { runPending(&pendingAfterBuilder) }
    ) {
      WorkoutBuilderView { workout in
        pendingAfterBuilder = { presentArrange(for: workout) }
        isShowingWorkoutBuilder = false
      }
      .environmentObject(store)
    }
    .sheet(
      item: $arrangingPlan,
      onDismiss: { runPending(&pendingAfterArrange) }
    ) { plan in
      WorkoutArrangeView(
        plan: plan,
        onStart: {
          isShowingWorkoutTracker = false
          pendingAfterArrange = {
            isShowingWorkoutTracker = true
            pendingAfterArrange = nil
          }
          arrangingPlan = nil
        },
        onCancel: {
          pendingAfterArrange = nil
          store.discardWorkout()
          arrangingPlan = nil
        }
      )
      .environmentObject(store)
    }
    .sheet(isPresented: $isShowingWorkoutTracker) {
      WorkoutTrackerView()
        .environmentObject(store)
    }
    .sheet(isPresented: $isShowingRunTracker) {
      RunTrackerView()
        .environmentObject(store)
    }
    .sheet(isPresented: $isShowingProgress) {
      // B5 (Sheet-Polish): Drag-Indicator sichtbar, Detents auf large +
      // medium (Quick-Peek möglich), App-Background als Surface — vorher
      // war das System-Material zu hell für den Dark-Look.
      NavigationStack {
        ProgressView()
          .environmentObject(store)
          .environmentObject(navigation)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Fertig") {
                isShowingProgress = false
              }
              .foregroundStyle(GainsColor.ink)
            }
          }
      }
      .gainsSheet(detents: [.large])
    }
    .sheet(isPresented: $isShowingProfile) {
      NavigationStack {
        ProfileView()
          .environmentObject(store)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Fertig") {
                isShowingProfile = false
              }
              .foregroundStyle(GainsColor.ink)
            }
          }
      }
    }
  }

  // MARK: - Home Hero (Greeting + Premium-CTA)
  //
  // A11/A12: Greeting-Bühne — Datum (NUR Wochentag · Tag/Monat, keine /-Slash-
  // Kette), Status-Chip rechts, Display-Greeting mit Lime→Cyan-Gradient,
  // optionale PR-Pille, Subtitle und der EINE kontextsensitive Hero-CTA.

  private var homeHero: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 10) {
        PulsingDot(coreSize: 6, haloSize: 16)
        Text(heroDateLine)
          .gainsEyebrow(GainsColor.softInk, size: 12, tracking: 1.4)
        Spacer(minLength: 8)
        heroStatusChip
      }

      greetingDisplay

      if let pr = recentPersonalRecord {
        recentPRPill(pr)
      }

      Text(todayGreetingLine)
        .gainsBody(secondary: true)
        .lineLimit(2)
        .padding(.trailing, 12)

      HeroPrimaryCTAButton(
        title: heroPrimaryCtaTitle,
        icon: heroPrimaryCtaIcon,
        action: heroPrimaryCtaAction
      )
    }
  }

  /// A12: Datums-Zeile — „WOCHENTAG · 29 APR" ohne Wochennummer (die
  /// wandert ins Cockpit-Header).
  private var heroDateLine: String {
    "\(currentWeekdayLong) · \(currentDateParts.date)"
  }

  private var currentWeekdayLong: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateFormat = "EEEE"
    return formatter.string(from: Date()).uppercased()
  }

  /// PR-Pille als kleiner Wow-Moment, wenn ein recent Volumen-PR existiert.
  private func recentPRPill(_ pr: CompletedWorkoutSummary) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "trophy.fill")
        .font(.system(size: 11, weight: .heavy))
        .foregroundStyle(GainsColor.lime)
      Text("PR")
        .gainsEyebrow(GainsColor.lime, size: 11, tracking: 1.6)
      Text("·")
        .gainsEyebrow(GainsColor.mutedInk, size: 11, tracking: 1.0)
      Text(pr.title)
        .font(GainsFont.label(11))
        .tracking(1.2)
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .truncationMode(.tail)
      Text(String(format: "%.0f kg", pr.volume))
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(GainsColor.lime)
    }
    .padding(.horizontal, 12)
    .frame(height: 28)
    .background(GainsColor.lime.opacity(0.08))
    .overlay(
      Capsule().strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: 0.6)
    )
    .clipShape(Capsule())
    .shadow(color: GainsColor.lime.opacity(0.35), radius: 10, x: 0, y: 0)
  }

  /// Findet den jüngsten Workout-Volume-PR (≤14 Tage) aus der History.
  private var recentPersonalRecord: CompletedWorkoutSummary? {
    let history = store.workoutHistory.sorted { $0.finishedAt < $1.finishedAt }
    guard history.count >= 2 else { return nil }
    var runningBest: Double = 0
    var lastPR: CompletedWorkoutSummary? = nil
    for workout in history where workout.volume > runningBest {
      runningBest = workout.volume
      lastPR = workout
    }
    guard let pr = lastPR else { return nil }
    let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
    return pr.finishedAt >= cutoff ? pr : nil
  }

  private var heroPrimaryCtaTitle: String {
    if store.activeWorkout != nil { return "WORKOUT FORTSETZEN" }
    if store.activeRun != nil { return "RUN ÖFFNEN" }
    if store.todayPlannedDay.runTemplate != nil { return "LAUF STARTEN" }
    if store.todayPlannedDay.status == .rest { return "SPONTAN TRAINIEREN" }
    return "TRAINING STARTEN"
  }

  private var heroPrimaryCtaIcon: String {
    if store.activeRun != nil { return "figure.run" }
    if store.todayPlannedDay.runTemplate != nil { return "figure.run" }
    return "play.fill"
  }

  private func heroPrimaryCtaAction() {
    if store.activeWorkout != nil {
      isShowingWorkoutTracker = true
      return
    }
    if store.activeRun != nil {
      isShowingRunTracker = true
      return
    }
    if store.todayPlannedDay.runTemplate != nil {
      startQuickRun()
      return
    }
    startFreeWorkout()
  }

  /// Greeting im Display-Stil mit Lime→Cyan-Gradient auf dem Namen.
  /// A12: Eine Stufe kompakter (38pt statt 46pt) — Cockpit + Nutrition
  /// bekommen mehr Atem.
  @ViewBuilder
  private var greetingDisplay: some View {
    let hasName = !store.userName.isEmpty

    VStack(alignment: .leading, spacing: 0) {
      Text(hasName ? "Los geht's," : "Los geht's.")
        .font(GainsFont.display(38))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.6)

      if hasName {
        Text("\(store.userName).")
          .font(GainsFont.display(38))
          .foregroundStyle(
            LinearGradient(
              colors: [GainsColor.lime, GainsColor.accentCool],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .shadow(color: GainsColor.lime.opacity(0.35), radius: 18, x: 0, y: 0)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  /// Status-Chip rechts im Hero — Live-Workout/Run, Plan, Rest, Flex.
  @ViewBuilder
  private var heroStatusChip: some View {
    if store.activeWorkout != nil {
      GainsGlowChip("LIVE", icon: "dumbbell.fill")
    } else if store.activeRun != nil {
      GainsGlowChip("LIVE RUN", icon: "figure.run", accent: GainsColor.ember)
    } else {
      switch store.todayPlannedDay.status {
      case .planned:
        GainsGlowChip("PLAN", icon: "play.fill")
      case .rest:
        GainsGlowChip("REST", icon: "leaf.fill", accent: GainsColor.accentCool)
      case .flexible:
        GainsGlowChip("FLEX", icon: "infinity", accent: GainsColor.accentCool)
      }
    }
  }

  // MARK: - Active Workout Line (minimal)

  private var activeWorkoutLine: some View {
    Button {
      isShowingWorkoutTracker = true
    } label: {
      HStack(spacing: 12) {
        PulsingDot(coreSize: 7, haloSize: 22)
        Text("WORKOUT LÄUFT")
          .gainsEyebrow(GainsColor.lime, size: 12, tracking: 1.6)
        Text("·")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.mutedInk)
        Text(
          "\(store.activeWorkout?.completedSets ?? 0)/\(store.activeWorkout?.totalSets ?? 0) Sätze"
        )
        .font(GainsFont.metricMono(13))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)

        Spacer(minLength: 0)

        Text("Weiter")
          .font(GainsFont.eyebrow(11))
          .tracking(1.5)
          .foregroundStyle(GainsColor.lime)
        Image(systemName: "arrow.right")
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      // Glow + Border bewusst leiser als der Hero darüber — der Banner soll
      // präsent bleiben (Live-Status), aber nicht mit dem Hero um Aufmerksamkeit
      // konkurrieren. Vorher: 0.10/0.45/Glow 14·0.18 — wirkte als zweite Bühne.
      .background(GainsColor.lime.opacity(0.08))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(GainsColor.lime.opacity(0.32), lineWidth: 0.7)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .shadow(color: GainsColor.lime.opacity(0.10), radius: 8, x: 0, y: 0)
      .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Aktives Workout fortsetzen")
    .accessibilityValue(
      "\(store.activeWorkout?.completedSets ?? 0) von \(store.activeWorkout?.totalSets ?? 0) Sätzen"
    )
  }

  // MARK: - Cockpit Card (Wochen-Ring + Mini-Tiles + Plan-Vorschau + Sparkline)
  //
  // A11/A12: Cockpit ersetzt KPI-Strip + Tag-Punkte + Fortschritts-Quicklink
  // in EINER Card mit zwei Tap-Zonen:
  //   • Top (Header + Wochenring + Mini-Tiles) → ProgressView-Sheet
  //   • Bottom (Plan-Vorschau-Zeile + Sparkline) → Planer-Tab

  private var cockpitCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button {
        isShowingProgress = true
      } label: {
        VStack(alignment: .leading, spacing: 18) {
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("DIESE WOCHE")
              .gainsEyebrow(GainsColor.ink, size: 12, tracking: 1.4)
            Text(currentDateParts.week)
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.mutedInk)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
              Text(progressDisplayTitle.uppercased())
                .gainsEyebrow(GainsColor.lime, size: 11, tracking: 1.4)
              Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(GainsColor.lime)
            }
          }

          HStack(alignment: .center, spacing: 18) {
            weekRing
              .frame(width: 116, height: 116)

            VStack(spacing: 10) {
              cockpitMiniTile(
                icon: "flame.fill",
                value: "\(store.streakDays)",
                unit: "T",
                label: "STREAK",
                accent: GainsColor.lime
              )
              cockpitMiniTile(
                icon: "scalemass.fill",
                value: String(format: "%.1f", store.weeklyVolumeTons),
                unit: "t",
                label: "VOLUMEN",
                accent: GainsColor.accentCool
              )
            }
          }
        }
        .padding(.bottom, 16)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Fortschritt öffnen")
      .accessibilityValue(
        "\(store.weeklySessionsCompleted) von \(store.weeklyGoalCount) Sessions"
      )

      Rectangle()
        .fill(GainsColor.border.opacity(0.5))
        .frame(height: 1)

      Button {
        navigation.openPlanner()
      } label: {
        VStack(alignment: .leading, spacing: 12) {
          cockpitPlanRow
          weekVolumeSparkline
        }
        .padding(.top, 16)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(cockpitPlanA11yLabel)
      .accessibilityHint("Öffnet den Planer-Tab, um Trainingstage anzupassen.")
    }
    .padding(20)
    .gainsCardStyle()
  }

  /// A12: Plan-Vorschau-Zeile innerhalb der Cockpit-Card. Ersetzt die
  /// frühere separate planPreviewRow zwischen Cockpit und Nutrition.
  @ViewBuilder
  private var cockpitPlanRow: some View {
    if let next = nextPlannedSchedule {
      HStack(spacing: 10) {
        Image(systemName: next.isToday ? "play.fill" : "calendar.badge.clock")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 22, height: 22)
          .background(GainsColor.lime.opacity(0.12))
          .clipShape(Circle())
          .overlay(
            Circle().strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: 0.6)
          )

        VStack(alignment: .leading, spacing: 1) {
          Text(next.isToday ? "HEUTE · \(next.weekday.shortLabel.uppercased())"
                            : "ALS NÄCHSTES · \(next.weekday.shortLabel.uppercased())")
            .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.4)
          Text(next.title)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
            .truncationMode(.tail)
        }

        Spacer(minLength: 0)

        Text("ANPASSEN")
          .gainsEyebrow(GainsColor.lime, size: 11, tracking: 1.4)
        Image(systemName: "arrow.up.right")
          .font(.system(size: 11, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
      }
    } else {
      HStack(spacing: 6) {
        Text("WOCHENPLAN")
          .gainsEyebrow(GainsColor.softInk, size: 11, tracking: 1.4)
        Spacer(minLength: 0)
        Text("ANPASSEN")
          .gainsEyebrow(GainsColor.lime, size: 11, tracking: 1.4)
        Image(systemName: "arrow.up.right")
          .font(.system(size: 11, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
      }
    }
  }

  private var cockpitPlanA11yLabel: String {
    if let next = nextPlannedSchedule {
      return "Plan-Vorschau: \(next.weekday.shortLabel) — \(next.title). Tippen zum Anpassen."
    }
    return "Wochenplan anpassen"
  }

  /// 7-Tage-Mini-Bar-Sparkline mit volumen- und status-codierten Capsules.
  private var weekVolumeSparkline: some View {
    let data = sevenDayVolumeData
    let maxVolume = max(data.map(\.volume).max() ?? 0, 1)
    return HStack(alignment: .bottom, spacing: 4) {
      ForEach(data) { day in
        VStack(spacing: 6) {
          sparklineBar(for: day, maxVolume: maxVolume)
            .frame(height: 36, alignment: .bottom)

          Text(day.shortLabel)
            .font(GainsFont.label(9))
            .tracking(1.3)
            .foregroundStyle(
              day.status == .today ? GainsColor.lime : GainsColor.mutedInk
            )
        }
        .frame(maxWidth: .infinity)
      }
    }
  }

  @ViewBuilder
  private func sparklineBar(for day: SparklineDay, maxVolume: Double) -> some View {
    let ratio = max(day.volume / maxVolume, 0)
    let scaledHeight = ratio * 30
    switch day.status {
    case .today:
      Capsule()
        .fill(GainsColor.lime)
        .frame(width: 8, height: max(scaledHeight, 14))
        .shadow(color: GainsColor.lime.opacity(0.6), radius: 6)
    case .completed:
      Capsule()
        .fill(GainsColor.lime.opacity(0.9))
        .frame(width: 8, height: max(scaledHeight, 8))
    case .planned:
      Capsule()
        .strokeBorder(GainsColor.lime.opacity(0.65), lineWidth: 1)
        .frame(width: 8, height: max(scaledHeight, 14))
    case .flexible:
      Capsule()
        .strokeBorder(
          GainsColor.softInk.opacity(0.5),
          style: StrokeStyle(lineWidth: 1, dash: [2, 2])
        )
        .frame(width: 8, height: max(scaledHeight, 10))
    case .rest:
      Capsule()
        .fill(GainsColor.border.opacity(0.7))
        .frame(width: 8, height: 5)
    }
  }

  private struct SparklineDay: Identifiable {
    let id: Date
    let date: Date
    let shortLabel: String
    let status: DayProgress.Status
    let volume: Double
  }

  private var sevenDayVolumeData: [SparklineDay] {
    let calendar = Calendar.current
    let volumeByDay: [Date: Double] = Dictionary(
      grouping: store.workoutHistory,
      by: { calendar.startOfDay(for: $0.finishedAt) }
    ).mapValues { $0.reduce(0.0) { $0 + $1.volume } }

    return store.homeWeekDays.map { day in
      let key = calendar.startOfDay(for: day.date)
      return SparklineDay(
        id: key,
        date: day.date,
        shortLabel: day.shortLabel,
        status: day.status,
        volume: volumeByDay[key] ?? 0
      )
    }
  }

  /// Lime→Cyan Wochenring mit Mono-Zähler in der Mitte.
  private var weekRing: some View {
    ZStack {
      Circle()
        .stroke(GainsColor.border.opacity(0.7), lineWidth: 8)

      Circle()
        .trim(from: 0, to: weeklyProgressRatio)
        .stroke(
          AngularGradient(
            gradient: Gradient(colors: [
              GainsColor.lime,
              GainsColor.lime,
              GainsColor.accentCool
            ]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
          ),
          style: StrokeStyle(lineWidth: 8, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .shadow(color: GainsColor.lime.opacity(0.45), radius: 12, x: 0, y: 0)

      Circle()
        .fill(GainsColor.lime.opacity(0.04))
        .frame(width: 80, height: 80)
        .blur(radius: 12)

      VStack(spacing: -2) {
        Text("\(store.weeklySessionsCompleted)")
          .font(.system(size: 36, weight: .semibold, design: .monospaced))
          .foregroundStyle(GainsColor.ink)
        Text("/ \(store.weeklyGoalCount)")
          .font(.system(size: 13, weight: .medium, design: .monospaced))
          .foregroundStyle(GainsColor.softInk)
      }
    }
  }

  /// Eine der zwei Mini-Tiles rechts vom Ring.
  private func cockpitMiniTile(
    icon: String,
    value: String,
    unit: String,
    label: String,
    accent: Color
  ) -> some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(accent.opacity(0.12))
        Circle()
          .strokeBorder(accent.opacity(0.45), lineWidth: 0.7)
        Image(systemName: icon)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(accent)
      }
      .frame(width: 34, height: 34)
      .shadow(color: accent.opacity(0.32), radius: 8)

      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .gainsEyebrow(GainsColor.mutedInk, size: 10, tracking: 1.3)
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(value)
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .foregroundStyle(GainsColor.ink)
          Text(unit)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.softInk)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(GainsColor.surfaceDeep.opacity(0.6))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(GainsColor.border.opacity(0.6), lineWidth: 0.5)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  /// Sucht den nächsten geplanten Trainings-Tag in der laufenden Woche.
  private var nextPlannedSchedule: WorkoutDayPlan? {
    let schedule = store.weeklyWorkoutSchedule
    guard let todayIndex = schedule.firstIndex(where: { $0.isToday }) else {
      return schedule.first(where: { $0.status == .planned })
    }
    for offset in 0..<schedule.count {
      let idx = (todayIndex + offset) % schedule.count
      let day = schedule[idx]
      if day.status == .planned {
        return day
      }
    }
    return nil
  }

  // MARK: - Nutrition Card (kcal-Ring + Macro-Bars)
  //
  // A11/A12: Ernährungs-Bühne mit gleichem Header-Muster wie Cockpit
  // (Eyebrow links, Mono-Subtle, Status rechts). kcal-Ring 96pt mit
  // Lime→Ember-AngularGradient, drei Macro-Bars rechts, Caption unten.

  private var nutritionCard: some View {
    Button {
      navigation.openNutrition()
    } label: {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Text("ERNÄHRUNG")
            .gainsEyebrow(GainsColor.ink, size: 12, tracking: 1.4)
          Text("HEUTE")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.mutedInk)

          Spacer(minLength: 0)

          HStack(spacing: 4) {
            Text(nutritionStatusLabel.uppercased())
              .gainsEyebrow(GainsColor.ember, size: 11, tracking: 1.4)
              .lineLimit(1)
            Image(systemName: "arrow.up.right")
              .font(.system(size: 11, weight: .heavy))
              .foregroundStyle(GainsColor.ember)
          }
        }

        HStack(alignment: .center, spacing: 18) {
          kcalRing
            .frame(width: 96, height: 96)

          VStack(spacing: 9) {
            macroBar(
              label: "PROTEIN",
              value: store.nutritionProteinToday,
              target: store.nutritionTargetProtein,
              unit: "g",
              accent: GainsColor.ember
            )
            macroBar(
              label: "KOHLENHYDRATE",
              value: store.nutritionCarbsToday,
              target: store.nutritionTargetCarbs,
              unit: "g",
              accent: GainsColor.lime
            )
            macroBar(
              label: "FETT",
              value: store.nutritionFatToday,
              target: store.nutritionTargetFat,
              unit: "g",
              accent: GainsColor.accentCool
            )
          }
        }

        Text(nutritionCaptionLine)
          .gainsCaption()
          .lineLimit(2)
      }
      .padding(20)
      .gainsCardStyle()
      .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Ernährung öffnen")
    .accessibilityValue(
      "\(store.nutritionCaloriesToday) von \(store.nutritionTargetCalories) Kalorien"
    )
  }

  /// Kalorien-Ring 96pt (eine Stufe kleiner als der Wochenring).
  private var kcalRing: some View {
    ZStack {
      Circle()
        .stroke(GainsColor.border.opacity(0.7), lineWidth: 7)

      Circle()
        .trim(from: 0, to: kcalProgressRatio)
        .stroke(
          AngularGradient(
            gradient: Gradient(colors: [
              GainsColor.lime,
              GainsColor.ember
            ]),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
          ),
          style: StrokeStyle(lineWidth: 7, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .shadow(color: GainsColor.ember.opacity(0.4), radius: 10, x: 0, y: 0)

      VStack(spacing: -2) {
        Text("\(store.nutritionCaloriesToday)")
          .font(.system(size: 26, weight: .semibold, design: .monospaced))
          .foregroundStyle(GainsColor.ink)
        Text("kcal")
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundStyle(GainsColor.softInk)
      }
    }
  }

  /// Eine Macro-Zeile rechts vom kcal-Ring.
  private func macroBar(
    label: String,
    value: Int,
    target: Int,
    unit: String,
    accent: Color
  ) -> some View {
    let ratio = target > 0 ? min(Double(value) / Double(target), 1.0) : 0
    return VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Text(label)
          .gainsEyebrow(accent, size: 10, tracking: 1.3)
          .lineLimit(1)

        Spacer(minLength: 4)

        HStack(alignment: .firstTextBaseline, spacing: 1) {
          Text("\(value)")
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(GainsColor.ink)
          Text("/\(target)")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.softInk)
          Text(unit)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.mutedInk)
            .padding(.leading, 1)
        }
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.border.opacity(0.55))
            .frame(height: 4)

          Capsule()
            .fill(
              LinearGradient(
                colors: [accent.opacity(0.85), accent],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: max(geo.size.width * ratio, 4), height: 4)
            .shadow(color: accent.opacity(0.45), radius: 4, x: 0, y: 0)
        }
      }
      .frame(height: 4)
    }
  }

  // MARK: - Computed (Ernährung + Wochen-Fortschritt)

  private var kcalProgressRatio: Double {
    let goal = max(store.nutritionTargetCalories, 1)
    return min(Double(store.nutritionCaloriesToday) / Double(goal), 1.0)
  }

  private var nutritionStatusLabel: String {
    if store.todayNutritionEntries.isEmpty { return "Noch leer" }
    if store.nutritionProteinToday >= store.nutritionTargetProtein
      && store.nutritionCaloriesToday >= store.nutritionTargetCalories
    {
      return "Ziel erreicht"
    }
    if store.nutritionProteinToday >= store.nutritionTargetProtein {
      return "Protein im Ziel"
    }
    if kcalProgressRatio >= 0.66 { return "Auf Kurs" }
    if kcalProgressRatio >= 0.34 { return "In Bewegung" }
    return "Warmup"
  }

  private var nutritionCaptionLine: String {
    if store.todayNutritionEntries.isEmpty {
      return "Noch keine Mahlzeit getrackt — leg los, wenn du isst."
    }
    let remainingKcal = max(store.nutritionTargetCalories - store.nutritionCaloriesToday, 0)
    let remainingProtein = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
    if remainingKcal == 0 && remainingProtein == 0 {
      return "Tagesziele sind drin. Sauberer Tag."
    }
    if remainingProtein == 0 {
      return "Noch \(remainingKcal) kcal · Protein-Ziel erreicht."
    }
    return "Noch \(remainingKcal) kcal · \(remainingProtein) g Protein offen."
  }

  private var weeklyProgressRatio: Double {
    let goal = max(store.weeklyGoalCount, 1)
    return min(Double(store.weeklySessionsCompleted) / Double(goal), 1.0)
  }

  private var progressDisplayTitle: String {
    let ratio = weeklyProgressRatio
    if store.weeklySessionsCompleted >= store.weeklyGoalCount && store.weeklyGoalCount > 0 {
      return "Ziel erreicht"
    }
    if ratio >= 0.66 { return "Auf Kurs" }
    if ratio >= 0.34 { return "In Bewegung" }
    if store.weeklySessionsCompleted == 0 { return "Startbereit" }
    return "Warmup"
  }

  private var progressMetricLine: String {
    "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Einheiten"
  }

  // MARK: - Top Bar

  private var topBar: some View {
    HStack(alignment: .center) {
      GainsWordmark(size: 30)

      Spacer()

      Button {
        isShowingProfile = true
      } label: {
        // Sichtbarer Avatar bleibt 38pt — die Tap-Region wächst aber auf 44pt
        // (HIG-Minimum), damit der Profilzugriff nicht knapp am Wordmark
        // verfehlt wird.
        ZStack {
          Circle()
            .stroke(GainsColor.border.opacity(0.55), lineWidth: 1)
            .frame(width: 38, height: 38)
          Text(store.userName.isEmpty ? "·" : String(store.userName.prefix(1)).uppercased())
            .font(GainsFont.label(13))
            .foregroundStyle(GainsColor.ink)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Profil öffnen")
    }
  }

  private var todayGreetingLine: String {
    switch store.todayPlannedDay.status {
    case .planned:
      return "Heute steht \(store.todayPlannedWorkout?.title ?? store.currentWorkoutPreview.title) im Fokus."
    case .rest:
      return "Heute ist bewusst leichter geplant. Recovery, Schritte und Rhythmus reichen."
    case .flexible:
      return "Heute bleibt offen. Du kannst Training, Mobility oder einen lockeren Run sinnvoll einbauen."
    }
  }

  // MARK: - Action Grid (2x2 farbcodierte Quick-Tiles)
  //
  // A11/A12: Kein „SCHNELLZUGRIFF"-Heading mehr (Tiles sprechen für sich),
  // kompaktere Tiles (minHeight 128, 32pt-Halo, Title 18pt, Pfeil ohne
  // Outline-Kreis). Vier Tiles: Cardio/Ember, Plan/Lime, Insights/Cyan,
  // Mahlzeit/Ember.

  private var actionGrid: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
      ],
      spacing: 12
    ) {
      actionTile(
        eyebrow: "CARDIO",
        title: store.activeRun == nil ? "Lauf" : "Run live",
        subtitle: store.activeRun == nil
          ? "GPS · Outdoor"
          : String(
            format: "%.1f km · %02d:%02d",
            store.activeRun?.distanceKm ?? 0,
            (store.activeRun?.durationMinutes ?? 0) / 60,
            (store.activeRun?.durationMinutes ?? 0) % 60
          ),
        icon: "figure.run",
        accent: GainsColor.ember,
        isLive: store.activeRun != nil,
        action: startQuickRun
      )
      actionTile(
        eyebrow: "PLAN",
        title: "Training",
        subtitle: store.coachHeadline,
        icon: "dumbbell.fill",
        accent: GainsColor.lime,
        action: { navigation.openTraining(workspace: .kraft) }
      )
      actionTile(
        eyebrow: "INSIGHTS",
        title: "Fortschritt",
        subtitle: progressMetricLine,
        icon: "chart.line.uptrend.xyaxis",
        accent: GainsColor.accentCool,
        action: { isShowingProgress = true }
      )
      actionTile(
        eyebrow: "MAHLZEIT",
        title: "Schnell loggen",
        subtitle: "Foto · Barcode · Manuell",
        icon: "fork.knife",
        accent: GainsColor.ember,
        action: { navigation.presentCapture(kind: .meal) }
      )
    }
  }

  private func actionTile(
    eyebrow: String,
    title: String,
    subtitle: String,
    icon: String,
    accent: Color,
    isLive: Bool = false,
    isMuted: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 0) {
          ZStack {
            Circle()
              .fill(isMuted ? GainsColor.border.opacity(0.4) : accent.opacity(0.14))
            Circle()
              .strokeBorder(
                isMuted ? GainsColor.border : accent.opacity(0.5),
                lineWidth: 0.7
              )
            Image(systemName: icon)
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(isMuted ? GainsColor.softInk : accent)
          }
          .frame(width: 32, height: 32)
          .shadow(color: isMuted ? .clear : accent.opacity(0.4), radius: 9)

          Spacer(minLength: 0)

          if isLive {
            PulsingDot(color: accent, coreSize: 6, haloSize: 14)
              .frame(width: 24, height: 24)
          } else {
            Image(systemName: "arrow.up.right")
              .font(.system(size: 11, weight: .heavy))
              .foregroundStyle(isMuted ? GainsColor.mutedInk : GainsColor.softInk)
              .frame(width: 24, height: 24)
          }
        }

        Spacer(minLength: 12)

        VStack(alignment: .leading, spacing: 4) {
          Text(eyebrow)
            .gainsEyebrow(
              isMuted ? GainsColor.mutedInk : accent,
              size: 10,
              tracking: 1.4
            )
          Text(title)
            .font(GainsFont.title(18))
            .foregroundStyle(isMuted ? GainsColor.softInk : GainsColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
          Text(subtitle)
            .gainsCaption()
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
      .padding(14)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [
                isMuted ? GainsColor.border.opacity(0.7) : accent.opacity(0.5),
                GainsColor.border.opacity(0.4)
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 0.7
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .shadow(
        color: isMuted ? .black.opacity(0.4) : accent.opacity(0.10),
        radius: 14, x: 0, y: 6
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(eyebrow) — \(title)")
    .accessibilityValue(subtitle)
    .accessibilityAddTraits(isLive ? .isSelected : [])
  }

  // MARK: - Live-BPM-Banner
  //
  // A12: Erscheint nur wenn ein BLE-Sensor aktiv verbunden ist. Cyan-Pulse
  // + Mono-BPM 18pt + Device-Name; Tap öffnet das Profil-Sheet.

  @ViewBuilder
  private var liveBPMBanner: some View {
    if ble.isConnected {
      Button {
        isShowingProfile = true
      } label: {
        HStack(spacing: 10) {
          PulsingDot(
            color: GainsColor.accentCool,
            coreSize: 6,
            haloSize: 18
          )
          Text("LIVE HF")
            .gainsEyebrow(GainsColor.accentCool, size: 11, tracking: 1.5)

          if let bpm = ble.liveHeartRate {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
              Text("\(bpm)")
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(GainsColor.ink)
              Text("BPM")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(GainsColor.softInk)
            }
          } else {
            Text("Verbunden")
              .gainsCaption()
          }

          Spacer(minLength: 0)

          if let device = ble.connectedDevice {
            Text(device.name.uppercased())
              .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.2)
              .lineLimit(1)
              .truncationMode(.tail)
          }

          Image(systemName: "arrow.up.right")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(GainsColor.accentCool)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GainsColor.accentCool.opacity(0.05))
        .overlay(
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(GainsColor.accentCool.opacity(0.32), lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: GainsColor.accentCool.opacity(0.14), radius: 8, x: 0, y: 0)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(
        "Heart-Rate-Sensor verbunden\(ble.liveHeartRate.map { ", \($0) BPM" } ?? "")"
      )
    }
  }

  private func startFreeWorkout() {
    if store.activeWorkout != nil {
      isShowingWorkoutTracker = true
      return
    }

    store.startQuickWorkout()
    isShowingWorkoutTracker = true
  }

  private func startQuickRun() {
    if store.activeRun == nil {
      store.startQuickRun()
    }
    isShowingRunTracker = true
  }

  private func presentArrange(for plan: WorkoutPlan) {
    if store.activeWorkout == nil {
      store.startWorkout(from: plan)
    }
    arrangingPlan = plan
  }

  /// A6: Führt eine geparkte Folge-Aktion aus dem `onDismiss`-Callback aus
  /// und löscht den Slot. Verhindert, dass eine Aktion versehentlich
  /// mehrfach feuert, wenn ein Sheet aus anderen Gründen wieder geschlossen wird.
  private func runPending(_ slot: inout (() -> Void)?) {
    guard let action = slot else { return }
    slot = nil
    action()
  }

  private var currentDateParts: (day: String, date: String, week: String) {
    let now = Date()
    let dayFormatter = DateFormatter()
    dayFormatter.locale = Locale(identifier: "de_DE")
    dayFormatter.dateFormat = "EE"

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "dd MMM"

    let week = Calendar.current.component(.weekOfYear, from: now)
    return (
      dayFormatter.string(from: now).uppercased(),
      dateFormatter.string(from: now).uppercased(),
      "WK \(week)"
    )
  }
}

// Cleanup: `WorkoutStartSheet` wurde durch `WorkoutTrackerEntryView` ersetzt
// (Whoop-Style 3-Tab-Layout) und ist deshalb komplett entfernt worden.

struct SlashLabel: View {
  let parts: [String]
  let primaryColor: Color
  let secondaryColor: Color

  // A4: Reduziertes Tracking (2.0 → 1.3) — Buchstaben bleiben verbunden
  // lesbar bei den überall verwendeten 13pt (Floor von `GainsFont.label`).
  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
        Text(part)
          .font(GainsFont.label(10))
          .tracking(1.3)
          .foregroundStyle(index == 0 ? primaryColor : secondaryColor)

        if index < parts.count - 1 {
          Text("/")
            .font(GainsFont.label(10))
            .tracking(1.3)
            .foregroundStyle(primaryColor)
        }
      }
    }
    .textCase(.uppercase)
  }
}

private struct WorkoutArrangeView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let plan: WorkoutPlan
  let onStart: () -> Void
  let onCancel: () -> Void

  @State private var isShowingExercisePicker = false

  var body: some View {
    NavigationStack {
      ZStack {
        GainsAppBackground()

        if let workout = store.activeWorkout {
          VStack(spacing: 0) {
            headline(for: workout)
              .padding(.horizontal, 20)
              .padding(.top, 8)
              .padding(.bottom, 12)

            List {
              Section {
                ForEach(workout.exercises) { exercise in
                  exerciseRow(exercise, in: workout)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                }
                .onMove { source, destination in
                  store.reorderActiveExercises(from: source, to: destination)
                }
                .onDelete { indexSet in
                  for index in indexSet {
                    if let id = store.activeWorkout?.exercises[safe: index]?.id {
                      store.removeActiveExercise(id: id)
                    }
                  }
                }
              } header: {
                sectionLabel
                  .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                  .listRowBackground(Color.clear)
              }

              Section {
                Button {
                  isShowingExercisePicker = true
                } label: {
                  addExerciseRow
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 24, trailing: 20))
              }

              Section {
                Color.clear.frame(height: 110)
                  .listRowBackground(Color.clear)
                  .listRowSeparator(.hidden)
                  .listRowInsets(EdgeInsets())
              }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
          }

          VStack {
            Spacer()
            startCTA(for: workout)
              .padding(.horizontal, 20)
              .padding(.bottom, 18)
          }
        } else {
          VStack(spacing: 12) {
            SwiftUI.ProgressView()
            Text("Workout wird vorbereitet ...")
              .gainsBody(secondary: true)
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            onCancel()
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
          Text("TRAINING ANPASSEN")
            .font(GainsFont.label(11))
            .tracking(2.2)
            .foregroundStyle(GainsColor.ink)
        }
      }
      .sheet(isPresented: $isShowingExercisePicker) {
        ExercisePickerSheet { item in
          store.appendActiveExercise(from: item)
          isShowingExercisePicker = false
        }
        .environmentObject(store)
      }
    }
  }

  private func headline(for workout: WorkoutSession) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(workout.title)
        .font(GainsFont.display(28))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)
        .minimumScaleFactor(0.78)

      HStack(spacing: 8) {
        metaPill(icon: "list.bullet", text: "\(workout.exercises.count) Übungen")
        metaPill(icon: "repeat", text: "\(workout.totalSets) Sätze")
        metaPill(icon: "clock", text: "\(plan.estimatedDurationMinutes) min")
      }

      Text("Reihenfolge ändern, Übungen entfernen oder hinzufügen – dann starten.")
        .gainsBody(secondary: true)
        .lineLimit(2)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func metaPill(icon: String, text: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(GainsColor.moss)
      Text(text)
        .font(GainsFont.label(10))
        .tracking(1.2)
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background(GainsColor.lime.opacity(0.18))
    .clipShape(Capsule())
  }

  private var sectionLabel: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(GainsColor.lime)
        .frame(width: 5, height: 5)
      Text("ÜBUNGEN")
        .font(GainsFont.label(10))
        .tracking(2.2)
        .foregroundStyle(GainsColor.softInk)
      Rectangle()
        .fill(GainsColor.border.opacity(0.4))
        .frame(height: 1)
    }
  }

  private func exerciseRow(_ exercise: TrackedExercise, in workout: WorkoutSession) -> some View {
    let index = workout.exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0

    return HStack(spacing: 12) {
      Text(String(format: "%02d", index + 1))
        .font(GainsFont.label(11))
        .tracking(1.4)
        .foregroundStyle(GainsColor.moss)
        .frame(width: 32, height: 32)
        .background(GainsColor.lime.opacity(0.22))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text(exercise.name)
          .font(GainsFont.title(17))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)

        Text(
          "\(exercise.targetMuscle.uppercased()) · \(exercise.sets.count) Sätze"
        )
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
      }

      Spacer()

      Image(systemName: "line.3.horizontal")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.softInk.opacity(0.7))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var addExerciseRow: some View {
    HStack(spacing: 12) {
      Image(systemName: "plus")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 32, height: 32)
        .background(GainsColor.ctaSurface)
        .clipShape(Circle())

      Text("ÜBUNG HINZUFÜGEN")
        .font(GainsFont.label(11))
        .tracking(1.8)
        .foregroundStyle(GainsColor.ink)

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .background(GainsColor.card.opacity(0.6))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .foregroundStyle(GainsColor.lime.opacity(0.55))
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func startCTA(for workout: WorkoutSession) -> some View {
    Button {
      onStart()
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "play.fill")
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(GainsColor.lime)

        Text("TRAINING STARTEN")
          .font(GainsFont.label(13))
          .tracking(2)
          .foregroundStyle(GainsColor.lime)

        Spacer()

        Text("\(workout.exercises.count) ÜBUNGEN")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.lime.opacity(0.7))
      }
      .padding(.horizontal, 22)
      .frame(height: 64)
      .background(GainsColor.ctaSurface)
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(GainsColor.lime.opacity(0.55), lineWidth: 1.4)
      )
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .shadow(color: GainsColor.lime.opacity(0.18), radius: 18, x: 0, y: 10)
      .opacity(workout.exercises.isEmpty ? 0.45 : 1)
    }
    .buttonStyle(.plain)
    .disabled(workout.exercises.isEmpty)
  }
}

private struct ExercisePickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let onSelect: (ExerciseLibraryItem) -> Void

  @State private var searchText = ""

  private var filteredExercises: [ExerciseLibraryItem] {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return store.exerciseLibrary }
    return store.exerciseLibrary.filter {
      $0.name.localizedCaseInsensitiveContains(trimmed)
        || $0.primaryMuscle.localizedCaseInsensitiveContains(trimmed)
        || $0.equipment.localizedCaseInsensitiveContains(trimmed)
    }
  }

  var body: some View {
    NavigationStack {
      GainsScreen {
        VStack(alignment: .leading, spacing: 14) {
          searchField

          if filteredExercises.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Text("Keine Übung gefunden")
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)
              Text("Versuch einen anderen Suchbegriff oder eine Muskelgruppe.")
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .gainsCardStyle()
          } else {
            VStack(spacing: 10) {
              ForEach(filteredExercises) { item in
                Button {
                  onSelect(item)
                } label: {
                  exerciseRow(item)
                }
                .buttonStyle(.plain)
              }
            }
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
          Text("ÜBUNG WÄHLEN")
            .font(GainsFont.label(11))
            .tracking(2.2)
            .foregroundStyle(GainsColor.ink)
        }
      }
    }
  }

  private var searchField: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)

      TextField("Suche nach Übung oder Muskelgruppe", text: $searchText)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.ink)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)

      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 14)
    .frame(height: 46)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func exerciseRow(_ item: ExerciseLibraryItem) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "dumbbell.fill")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 38, height: 38)
        .background(GainsColor.ctaSurface)
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text(item.name)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)

        Text("\(item.primaryMuscle.uppercased()) · \(item.equipment)")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(1)
      }

      Spacer()

      Text("\(item.defaultSets)×\(item.defaultReps)")
        .font(GainsFont.label(10))
        .tracking(1.2)
        .foregroundStyle(GainsColor.moss)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(GainsColor.lime.opacity(0.22))
        .clipShape(Capsule())

      Image(systemName: "plus")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(GainsColor.onLime)
        .frame(width: 28, height: 28)
        .background(GainsColor.lime)
        .clipShape(Circle())
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}

struct StatCard: View {
  let title: String
  let value: String
  let valueAccent: Bool
  let subtitle: String
  let background: Color
  let foreground: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(GainsFont.label(10))
        .tracking(2)
        .foregroundStyle(foreground.opacity(0.7))

      valueView

      Spacer(minLength: 0)

      Text(subtitle)
        .font(GainsFont.body(13))
        .foregroundStyle(foreground.opacity(0.72))
    }
    .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
    .padding(14)
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  @ViewBuilder
  private var valueView: some View {
    if valueAccent, value.contains("/") {
      let components = value.split(separator: "/", omittingEmptySubsequences: false).map(
        String.init)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(components.first ?? value)
        Text("/")
          .foregroundStyle(GainsColor.lime)
        Text(components.dropFirst().first ?? "")
      }
      .font(GainsFont.display(28))
      .foregroundStyle(foreground)
    } else {
      Text(value)
        .font(GainsFont.display(28))
        .foregroundStyle(foreground)
    }
  }
}
