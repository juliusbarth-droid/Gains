import SwiftUI

// MARK: - GymTodayTab
//
// Aufgeräumter HEUTE-Tab. Verbesserungen vs. der vorherigen Version:
//   • Hero und Primär-Aktion in EINER Karte — kein Sprung mehr zwischen
//     "Inhalt lesen" und "Button drücken".
//   • Sekundäre Aktionen direkt unter dem Hero, kontextabhängig.
//   • Evidence/Wissenschafts-Card ist nach PLAN umgezogen — gehört zum
//     Plan/Setup, nicht in den Tagesfokus.
//   • Wochenpuls deutlich kompakter (eine Mini-Karte statt großem Block
//     mit Sparkline + Streifen).
//   • Neu: Letztes-Training-Banner sorgt für Kontinuität, wenn keine
//     Live-Session läuft.

struct GymTodayTab: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore

  @Binding var selectedTab: GymTab
  @Binding var isShowingWorkoutTracker: Bool
  @Binding var isShowingWorkoutBuilder: Bool
  @Binding var showsPlanWizard: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if store.activeWorkout != nil {
        // Live-Modus: Live-Card ist die Bühne. Hero/CTA werden zurückgefahren,
        // damit nichts gegen die offene Session konkurriert.
        liveSessionCard
        liveSecondaryActionsRow
      } else {
        // Default-Modus: Hero → Wochenpuls (Key-Metriken direkt sichtbar) →
        // Sekundäre Aktionen → Kontext → Letztes Training.
        // Wochenpuls ist jetzt nach oben gezogen, damit Sessions/Volumen/Trend
        // ohne Scrollen einsehbar sind — das ist, was Nutzer täglich zuerst
        // sehen wollen.
        todayHeroCard

        compactWeeklyPulse

        secondaryActionsRow

        contextCard
      }
    }
  }

  // MARK: - Sekundäre Aktionen (Live-Modus)
  //
  // Im Live-Modus gibt es keine "Letztes wiederholen" oder Plan-Sprünge —
  // die Session läuft. Hier nur Bibliothek/Stats als Kontextwechsel.

  private var liveSecondaryActionsRow: some View {
    HStack(spacing: 10) {
      secondaryActionButton(
        icon: "calendar.badge.clock",
        title: "Plan"
      ) {
        selectedTab = .plan
      }
      secondaryActionButton(
        icon: "square.stack.3d.up.fill",
        title: "Bibliothek"
      ) {
        selectedTab = .workouts
      }
      secondaryActionButton(
        icon: "chart.bar.fill",
        title: "Daten"
      ) {
        selectedTab = .stats
      }
    }
  }

  // MARK: - Today Hero (Hero + Primary CTA + Secondary Actions in einer Karte)

  // A8: Hero-Card baut jetzt auf der zentralen `GainsHeroCard`-Komponente
  // (siehe DesignSystem.swift). Das ehemalige inline-Layout hatte einen
  // Foreground-Bug — Title und Texte nutzten `GainsColor.card` als helle
  // Foreground-Farbe, was im Dark-Only-Re-Design dunkel-auf-dunkel ergab.
  // Die neue Komponente nutzt die richtigen `onCtaSurface*`-Tokens.
  @ViewBuilder
  private var todayHeroCard: some View {
    let day = store.todayPlannedDay
    let plan = day.workoutPlan ?? store.todayPlannedWorkout ?? store.currentWorkoutPreview
    let isRunDay = day.runTemplate != nil
    let isLive = store.activeWorkout != nil

    GainsHeroCard(
      eyebrow: [
        isRunDay ? "LAUFEN" : "KRAFT",
        "HEUTE",
        day.weekday.shortLabel,
      ],
      title: heroTitle(day: day, plan: plan),
      subtitle: heroSubtitle(day),
      primaryCtaTitle: primaryActionTitle(day: day, isLive: isLive),
      primaryCtaIcon: primaryActionIcon(day: day, isLive: isLive),
      primaryCtaAction: { handlePrimaryAction(day: day, isLive: isLive) },
      metrics: heroMetricsList(day: day, plan: plan),
      trailingBadge: { heroStatusBadge(for: day.status, isLive: isLive) }
    )
  }

  private func primaryActionIcon(day: WorkoutDayPlan, isLive: Bool) -> String {
    if isLive { return "play.fill" }
    if day.status == .rest { return "plus.circle.fill" }
    return "play.fill"
  }

  private func heroStatusBadge(for status: WorkoutDayStatus, isLive: Bool) -> some View {
    let (label, tone): (String, GainsHeroStatusBadge.Tone) = {
      if isLive { return ("LIVE", .live) }
      switch status {
      case .rest:     return ("REST", .rest)
      case .flexible: return ("FLEX", .flex)
      case .planned:  return ("PLAN", .plan)
      }
    }()
    return GainsHeroStatusBadge(label: label, tone: tone)
  }

  private func heroMetricsList(day: WorkoutDayPlan, plan: WorkoutPlan) -> [GainsHeroMetric] {
    switch day.status {
    case .planned:
      if let run = day.runTemplate {
        return [
          .init("DISTANZ", String(format: "%.1f km", run.targetDistanceKm)),
          .init("DAUER",   "\(run.targetDurationMinutes) Min"),
          .init("PACE",    run.targetPaceLabel),
        ]
      }
      return [
        .init("ÜBUNGEN", "\(plan.exercises.count)"),
        .init("DAUER",   "\(plan.estimatedDurationMinutes) Min"),
        .init("SPLIT",   plan.split),
      ]
    case .rest:
      return [
        .init("WOCHE",   "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)"),
        .init("VOLUMEN", String(format: "%.1f t", store.weeklyVolumeTons)),
        .init("STREAK",  "\(store.weeklySessionsCompleted)"),
      ]
    case .flexible:
      return [
        .init("SESSIONS", "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)"),
        .init("VOLUMEN",  String(format: "%.1f t", store.weeklyVolumeTons)),
        .init("OPTION",   plan.split),
      ]
    }
  }

  // MARK: - Sekundäre Aktionen (Default-Modus)
  //
  // Sitzen direkt unter der Hero-Karte. Drei Buttons sind die Maximalbreite,
  // die ohne Abschneiden lesbar bleibt — wir wählen kontextabhängig.
  // Wird nur im Default-Modus angezeigt; Live-Modus hat eine eigene Reihe.

  @ViewBuilder
  private var secondaryActionsRow: some View {
    HStack(spacing: 10) {
      secondaryActionButton(
        icon: "calendar.badge.clock",
        title: "Plan"
      ) {
        selectedTab = .plan
      }

      secondaryActionButton(
        icon: "square.stack.3d.up.fill",
        title: "Bibliothek"
      ) {
        selectedTab = .workouts
      }

      secondaryActionButton(
        icon: "chart.bar.fill",
        title: "Stats"
      ) {
        selectedTab = .stats
      }
    }
  }

  // MARK: - Hero Helpers
  //
  // A8: heroMetrics / metricCell / divider / statusBadge sind weggefallen,
  // weil GainsHeroCard die Pattern intern abdeckt. Die Builder oben
  // (heroMetricsList, heroStatusBadge) füttern die Komponente.

  private func heroTitle(day: WorkoutDayPlan, plan: WorkoutPlan) -> String {
    switch day.status {
    case .planned:
      if let run = day.runTemplate { return run.title.uppercased() }
      return plan.title.uppercased()
    case .rest:     return "FREIER TAG"
    case .flexible: return "FLEX DAY"
    }
  }

  private func heroSubtitle(_ day: WorkoutDayPlan) -> String {
    switch day.status {
    case .planned:
      if let kind = day.sessionKind, kind.isRun {
        switch kind {
        case .easyRun:     return "Easy Run – Puls unter 75 % HFmax. Aerobe Basis."
        case .tempoRun:    return "Tempo-Lauf – Schwellenpuls 84–88 % HFmax."
        case .intervalRun: return "VO₂max Intervalle – kurz, hart, volle Erholung."
        case .longRun:     return "Long Run – ruhiger Puls, mehr Volumen."
        case .recoveryRun: return "Recovery Run – locker, Atmung niedrig."
        default: return "Lauf-Tag laut Plan."
        }
      }
      return "Plan steht. Direkt loslegen oder im Plan-Tab anpassen."
    case .rest:
      return "Heute bewusst frei – Regeneration ist Trainingsreiz."
    case .flexible:
      return "Freier Slot. Optionales Workout oder Erholung."
    }
  }

  // MARK: - Primary / Secondary Actions
  //
  // A8: Der inline-`primaryActionButton` ist weg — die Hero-CTA wird jetzt
  // von `GainsHeroCard` selbst gerendert. `primaryActionTitle` /
  // `handlePrimaryAction` bleiben als Helfer, weil sie auch von der
  // Closure aus dem Hero aufgerufen werden.

  private func primaryActionTitle(day: WorkoutDayPlan, isLive: Bool) -> String {
    if isLive { return "Weiter tracken" }
    if day.status == .rest { return "Spontan trainieren" }
    if day.runTemplate != nil { return "Lauf starten" }
    return "Training starten"
  }

  private func handlePrimaryAction(day: WorkoutDayPlan, isLive: Bool) {
    if isLive {
      isShowingWorkoutTracker = false
      isShowingWorkoutTracker = true
      return
    }

    if let runTemplate = day.runTemplate {
      store.startRun(from: runTemplate)
      navigation.openTraining(workspace: .laufen)
      return
    }

    if day.status == .rest {
      if !store.repeatLastWorkout() {
        if let first = store.savedWorkoutPlans.first {
          store.startWorkout(from: first)
        } else {
          isShowingWorkoutBuilder = true
          return
        }
      }
      isShowingWorkoutTracker = false
      isShowingWorkoutTracker = true
      return
    }

    if let plan = store.todayPlannedWorkout {
      store.startWorkout(from: plan)
      isShowingWorkoutTracker = false
      isShowingWorkoutTracker = true
    } else if let fallback = store.savedWorkoutPlans.first {
      store.startWorkout(from: fallback)
      isShowingWorkoutTracker = false
      isShowingWorkoutTracker = true
    } else {
      isShowingWorkoutBuilder = true
    }
  }

  private func secondaryActionButton(
    icon: String,
    title: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 12, weight: .semibold))
        Text(title)
          .font(GainsFont.label(11))
          .tracking(1.0)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
      }
      .foregroundStyle(GainsColor.ink)
      .frame(maxWidth: .infinity)
      .frame(height: 44)
      .padding(.horizontal, 12)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(GainsColor.border.opacity(0.6), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Live Session Card

  private var liveSessionCard: some View {
    Group {
      if let session = store.activeWorkout {
        VStack(alignment: .leading, spacing: 16) {
          // Live-Indikator + Fokus + Elapsed Time
          HStack(spacing: 8) {
            Circle()
              .fill(GainsColor.lime)
              .frame(width: 8, height: 8)
            Text("LIVE SESSION")
              .font(GainsFont.label(10))
              .tracking(2.0)
              .foregroundStyle(GainsColor.lime)
            Spacer()
            Text(elapsedLabel(since: session.startedAt))
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(GainsColor.moss)
              .monospacedDigit()
          }

          // Titel + Fokus prominent
          VStack(alignment: .leading, spacing: 4) {
            Text(session.title)
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
              .minimumScaleFactor(0.78)
            Text(session.focus.uppercased())
              .font(GainsFont.label(9))
              .tracking(1.5)
              .foregroundStyle(GainsColor.softInk)
          }

          GeometryReader { geo in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(GainsColor.border.opacity(0.4))
                .frame(height: 6)
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(GainsColor.lime)
                .frame(width: geo.size.width * progress(session), height: 6)
            }
          }
          .frame(height: 6)

          HStack(spacing: 0) {
            liveStat("SÄTZE", "\(session.completedSets)/\(session.totalSets)")
            liveStatDivider()
            liveStat("VOLUMEN", "\(Int(session.totalVolume)) kg")
            liveStatDivider()
            liveStat("ÜBUNGEN", "\(session.exercises.count)")
          }
          .background(GainsColor.background.opacity(0.55))
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

          // A10: Live-Session-CTA nutzt die neue Premium-Pille — gleiche
          // Sprache wie der Hero-Start-Button, damit „weitermachen" und
          // „starten" als zusammenhängendes Vokabular gelesen werden.
          HeroPrimaryCTAButton(
            title: "Tracker öffnen & weitermachen",
            icon: "dumbbell.fill",
            action: { isShowingWorkoutTracker = true }
          )
        }
        .padding(18)
        .background(GainsColor.card)
        .overlay(
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(GainsColor.lime.opacity(0.5), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      }
    }
  }

  /// "00:42" / "1:23 h" – kurze Anzeige der Trainingsdauer.
  private func elapsedLabel(since start: Date) -> String {
    let totalSeconds = max(Int(Date().timeIntervalSince(start)), 0)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    if hours > 0 {
      return String(format: "%d:%02d h", hours, minutes)
    }
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d", minutes, seconds)
  }

  private func liveStat(_ label: String, _ value: String) -> some View {
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

  private func progress(_ session: WorkoutSession) -> Double {
    guard session.totalSets > 0 else { return 0 }
    return min(Double(session.completedSets) / Double(session.totalSets), 1.0)
  }

  // MARK: - Context Card (Muskel-Dosis ODER Regenerations-Hinweis)

  @ViewBuilder
  private var contextCard: some View {
    let day = store.todayPlannedDay
    let resolvedPlan = day.workoutPlan ?? store.todayPlannedWorkout
    let isStrengthDay = day.status == .planned && day.runTemplate == nil
    let canShowDose = isStrengthDay && (resolvedPlan?.exercises.isEmpty == false)

    if canShowDose, let plan = resolvedPlan {
      muscleDoseCard(plan: plan)
    } else if day.status == .rest {
      regenerationHintCard
    } else {
      EmptyView()
    }
  }

  @ViewBuilder
  private func muscleDoseCard(plan: WorkoutPlan) -> some View {
    let entries: [GymMuscleDoseEntry] = .from(plan: plan)

    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["DOSIS", "HEUTE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(plan.exercises.count) Übungen")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(entries) { entry in
            muscleChip(name: entry.muscle, sets: entry.sets)
          }
        }
        .padding(.vertical, 2)
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  private func muscleChip(name: String, sets: Int) -> some View {
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

  // MARK: - Compact Wochenpuls (Streifen + Volumen-Inline)

  private var compactWeeklyPulse: some View {
    let trend = weeklyVolumeTrend
    let currentVolume = trend.last ?? 0
    let prevVolume = trend.count >= 2 ? trend[trend.count - 2] : 0
    let trendInfo = volumeTrendDelta(current: currentVolume, previous: prevVolume)

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["WOCHE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Sessions")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      // Wochenstreifen Mo-So
      GymWeekStrip()

      // Inline Volumen-Info — keine eigene Zeile mit Riesen-Zahl mehr.
      HStack(spacing: 8) {
        Image(systemName: "scalemass.fill")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(GainsColor.moss)
        Text(String(format: "%.1f t Volumen", currentVolume / 1000))
          .font(GainsFont.label(10))
          .tracking(1.0)
          .foregroundStyle(GainsColor.ink)
        Text("·")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.softInk)
        Text(trendInfo.label)
          .font(GainsFont.label(10))
          .tracking(1.0)
          .foregroundStyle(trendInfo.color)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer(minLength: 0)
        Button {
          selectedTab = .stats
        } label: {
          HStack(spacing: 4) {
            Text("Statistik")
              .font(GainsFont.label(9))
              .tracking(1.4)
            Image(systemName: "chevron.right")
              .font(.system(size: 9, weight: .bold))
          }
          .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(14)
    .gainsCardStyle()
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

  private func volumeTrendDelta(current: Double, previous: Double) -> (label: String, color: Color) {
    guard previous > 0 else {
      if current > 0 { return ("Erste Daten dieser Woche", GainsColor.softInk) }
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

  // MARK: - Letztes Training Banner (Kontinuität)

  private func lastWorkoutBanner(_ last: CompletedWorkoutSummary) -> some View {
    let daysAgo = max(
      Calendar.current.dateComponents([.day], from: last.finishedAt, to: Date()).day ?? 0, 0
    )
    let when: String = {
      switch daysAgo {
      case 0: return "Heute"
      case 1: return "Gestern"
      default: return "vor \(daysAgo) Tagen"
      }
    }()
    let completion = last.totalSets > 0
      ? Int((Double(last.completedSets) / Double(last.totalSets)) * 100)
      : 0

    return Button {
      selectedTab = .stats
    } label: {
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(GainsColor.lime.opacity(0.18))
            .frame(width: 36, height: 36)
          Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(GainsColor.moss)
        }

        VStack(alignment: .leading, spacing: 3) {
          Text("LETZTES TRAINING · \(when.uppercased())")
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(GainsColor.softInk)
          Text(last.title)
            .font(GainsFont.title(15))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Text("\(last.completedSets)/\(last.totalSets) Sätze · \(Int(last.volume)) kg · \(completion) %")
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(14)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
  }
}
