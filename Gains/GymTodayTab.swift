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

  // Welle 2 — Day-One-Window: in den ersten 24h nach Onboarding und solange
  // noch kein Workout abgeschlossen ist, zeigen wir eine kompakte Mini-Tour
  // über dem Hero, die die drei Gym-Sub-Tabs (Plan/Bibliothek/Stats) erklärt.
  // Verschwindet automatisch nach der ersten Session ODER nach 24h.
  @AppStorage(GainsKey.onboardingCompletedAt) private var onboardingCompletedAt: Double = 0

  private var isInGymDayOneWindow: Bool {
    // P1-2 (2026-05-03): 24h-Cap entfernt. Wer abends onboardet und am
    // nächsten Morgen die App öffnet, hat sonst die Tour verpasst, ohne
    // jemals ein Workout absolviert zu haben. Bedingung jetzt: Onboarding
    // ist abgeschlossen UND es liegt noch kein Trainings-Verlauf vor.
    // Nutrition-Welcome-Card im Welle-2-Build verhält sich genauso.
    guard onboardingCompletedAt > 0 else { return false }
    if !store.workoutHistory.isEmpty { return false }
    if store.lastCompletedWorkout != nil { return false }
    return true
  }

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
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
        if isInGymDayOneWindow {
          dayOneGymGuide
        }

        todayHeroCard

        compactWeeklyPulse

        secondaryActionsRow

        contextCard

        // 2026-05-01: lastWorkoutBanner war Dead-Code — aktiviert, damit der
        // Header-Comment ("Letztes-Training-Banner sorgt für Kontinuität")
        // wieder zur Realität passt.
        if let last = store.lastCompletedWorkout {
          lastWorkoutBanner(last)
        }
      }
    }
  }

  // MARK: - Day-One Gym Guide
  //
  // Mini-Tour für Tab-Erstkontakt: Erklärt die drei Sub-Tabs in einer
  // einzigen Card, damit der User den Gym-Bereich auf einen Blick mental
  // einsortieren kann. Bewusst kompakter als die Nutrition-Welcome-Card —
  // der Hero darunter erklärt sich selbst, hier geht es nur um Orientierung.

  private var dayOneGymGuide: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack(spacing: GainsSpacing.xsPlus) {
        Image(systemName: "sparkles")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        Text("ERSTER BLICK")
          .gainsEyebrow(GainsColor.lime, size: 11, tracking: 1.4)
      }

      Text("So findest du dich im Gym zurecht.")
        .font(GainsFont.title(15))
        .foregroundStyle(GainsColor.ink)
        .fixedSize(horizontal: false, vertical: true)

      VStack(spacing: GainsSpacing.xs) {
        dayOneTourRow(icon: "calendar.badge.clock", title: "Plan",
                      detail: "Deine Wochenstruktur — anpassen oder neu bauen.")
        dayOneTourRow(icon: "square.stack.3d.up.fill", title: "Bibliothek",
                      detail: "Fertige Vorlagen + deine eigenen Workouts.")
        dayOneTourRow(icon: "chart.bar.fill", title: "Stats",
                      detail: "Volumen, Frequenz, persönliche Rekorde.")
      }
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [GainsColor.lime.opacity(0.06), GainsColor.card],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.28), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private func dayOneTourRow(icon: String, title: String, detail: String) -> some View {
    HStack(spacing: GainsSpacing.tight) {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 22, height: 22)
        .background(Circle().fill(GainsColor.lime.opacity(0.12)))
      Text(title)
        .font(GainsFont.title(12))
        .foregroundStyle(GainsColor.ink)
        .frame(width: 78, alignment: .leading)
      Text(detail)
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Sekundäre Aktionen (Live-Modus)
  //
  // Im Live-Modus gibt es keine "Letztes wiederholen" oder Plan-Sprünge —
  // die Session läuft. Hier nur Bibliothek/Stats als Kontextwechsel.

  private var liveSecondaryActionsRow: some View {
    HStack(spacing: GainsSpacing.tight) {
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
      // P0-3: war „Daten" — angeglichen an Tab-Label „STATS" und an die
      // Default-Reihe weiter unten, die ebenfalls „Stats" nutzt.
      secondaryActionButton(
        icon: "chart.bar.fill",
        title: "Stats"
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
      // P1-1: 3. Slot war früher „STREAK" mit demselben Wert wie „WOCHE" —
      // Duplikat. Recovery-Day-Hero ist der bessere Platz für den Ernährungs-
      // Hinweis: heute kein Trainingsreiz, also rückt Protein nach vorn.
      return [
        .init("WOCHE",   "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)"),
        .init("VOLUMEN", String(format: "%.1f t", store.weeklyVolumeTons)),
        .init("PROTEIN", "\(store.nutritionProteinToday) / \(store.nutritionTargetProtein) g"),
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
    // 2026-05-03 Intuitivitäts-Sweep P0 C: Repeat-Last-CTA war im
    // Audit „nicht prominent". Sobald `lastCompletedWorkout` existiert,
    // bekommt die Default-Reihe einen vierten Button „Letztes wdh.", der
    // den Tracker mit der vorherigen Session direkt vorlädt — ohne dass
    // der User durch Plan/Bibliothek navigieren muss.
    HStack(spacing: GainsSpacing.tight) {
      if let last = store.lastCompletedWorkout {
        secondaryActionButton(
          icon: "arrow.uturn.backward.circle",
          title: "Wdh."
        ) {
          repeatLastWorkout(reference: last)
        }
      }

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

  // P0 C: Wiederhole die letzte abgeschlossene Session in einem Tap.
  // GainsStore.repeatLastWorkout() startet das Workout, falls möglich,
  // sonst Fallback auf Builder.
  private func repeatLastWorkout(reference: CompletedWorkoutSummary) {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    if store.repeatLastWorkout() {
      isShowingWorkoutTracker = true
    } else if let plan = store.savedWorkoutPlans.first(where: { $0.title == reference.title }) {
      store.startWorkout(from: plan)
      isShowingWorkoutTracker = true
    } else if let any = store.savedWorkoutPlans.first {
      store.startWorkout(from: any)
      isShowingWorkoutTracker = true
    } else {
      isShowingWorkoutBuilder = true
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
    // G1/G2-Fix (2026-05-01): Doppelte State-Toggles entfernt.
    // SwiftUI batcht synchrone Bindings-Updates, daher hatte das Setzen
    // von `isShowingWorkoutTracker = false; isShowingWorkoutTracker = true`
    // KEINE Wirkung (gleicher Tick → keine View-Diff → kein Re-Present).
    // Stattdessen einfach einmal auf `true` setzen.
    if isLive {
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
      isShowingWorkoutTracker = true
      return
    }

    if let plan = store.todayPlannedWorkout {
      store.startWorkout(from: plan)
      isShowingWorkoutTracker = true
    } else if let fallback = store.savedWorkoutPlans.first {
      store.startWorkout(from: fallback)
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
      HStack(spacing: GainsSpacing.xsPlus) {
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
      .padding(.horizontal, GainsSpacing.s)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.6), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Live Session Card

  private var liveSessionCard: some View {
    Group {
      if let session = store.activeWorkout {
        VStack(alignment: .leading, spacing: GainsSpacing.m) {
          // Live-Indikator + Fokus + Elapsed Time
          HStack(spacing: GainsSpacing.xsPlus) {
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
          VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
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
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

          // A10: Live-Session-CTA nutzt die neue Premium-Pille — gleiche
          // Sprache wie der Hero-Start-Button, damit „weitermachen" und
          // „starten" als zusammenhängendes Vokabular gelesen werden.
          HeroPrimaryCTAButton(
            title: "Tracker öffnen & weitermachen",
            icon: "dumbbell.fill",
            action: { isShowingWorkoutTracker = true }
          )
        }
        // A13 (Cleaner-Pass): Hero-Resume-Card auf Standard-Card-Geometrie
        // (`GainsRadius.standard` 16, accent-Border statt 1.5pt-Stroke).
        // Der CTA-Button trägt jetzt den Akzent — die Card muss nicht
        // zusätzlich glühen.
        .padding(GainsSpacing.l)
        .background(GainsColor.card)
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .strokeBorder(GainsColor.lime.opacity(0.32), lineWidth: GainsBorder.accent)
        )
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
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
    VStack(spacing: GainsSpacing.xxs) {
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
    .padding(.vertical, GainsSpacing.tight)
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

    VStack(alignment: .leading, spacing: GainsSpacing.s) {
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
        HStack(spacing: GainsSpacing.xsPlus) {
          ForEach(entries) { entry in
            muscleChip(name: entry.muscle, sets: entry.sets)
          }
        }
        .padding(.vertical, 2)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  private func muscleChip(name: String, sets: Int) -> some View {
    HStack(spacing: GainsSpacing.xs) {
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
    .padding(.horizontal, GainsSpacing.s)
    .frame(height: 30)
    .background(GainsColor.background.opacity(0.85))
    .clipShape(Capsule())
  }

  private var regenerationHintCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
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
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // MARK: - Compact Wochenpuls (Streifen + Volumen-Inline)

  private var compactWeeklyPulse: some View {
    let trend = weeklyVolumeTrend
    let currentVolume = trend.last ?? 0
    let prevVolume = trend.count >= 2 ? trend[trend.count - 2] : 0
    let trendInfo = volumeTrendDelta(current: currentVolume, previous: prevVolume)

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
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
      HStack(spacing: GainsSpacing.xsPlus) {
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
          HStack(spacing: GainsSpacing.xxs) {
            // P0-3: Vorher „Statistik" — Tab heißt aber „STATS", Day-One-
            // Tour und Action-Button sagen ebenfalls „Stats". Drei Begriffe
            // für denselben Ziel-Tab → einheitlich auf „Stats".
            Text("Stats")
              .font(GainsFont.label(9))
              .tracking(1.4)
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .bold))
          }
          .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(GainsSpacing.m)
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
      HStack(spacing: GainsSpacing.s) {
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
      .padding(GainsSpacing.m)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
  }
}
