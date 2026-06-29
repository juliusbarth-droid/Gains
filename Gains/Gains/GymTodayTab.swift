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
  // 2026-05-15 (Audit-Loop 14): `showsPlanWizard`-Binding war ein
  // verwaister Pass-Through aus GymView — wurde nie gelesen oder
  // gesetzt. Entfernt. Wenn der Plan-Wizard von hier aus aufgerufen
  // werden soll, geht das via `selectedTab = .plan` und dort über die
  // bestehende Plan-Tab-Logik.

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
        dayOneTourRow(icon: "chart.bar.fill", title: "Statistik",
                      detail: "Volumen, Frequenz, persönliche Rekorde.")
      }
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      // 2026-05-14 (Polish-Loop 112): Day-One-Guide mit Lime-
      // Glow-Komposition statt flachem Diagonal-Gradient.
      ZStack {
        GainsColor.card
        RadialGradient(
          colors: [GainsColor.lime.opacity(0.18), .clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 240
        )
        .blendMode(.screen)
        LinearGradient(
          colors: [GainsColor.glassInnerLight, .clear],
          startPoint: .top,
          endPoint: .center
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.lime.opacity(0.50), GainsColor.lime.opacity(0.12)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
    .shadow(color: GainsColor.lime.opacity(0.07), radius: 12)
  }

  private func dayOneTourRow(icon: String, title: String, detail: String) -> some View {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)

    HStack(spacing: GainsSpacing.tight) {
      ZStack {
        Circle().fill(GainsColor.lime.opacity(0.10))
        Circle()
          .fill(
            RadialGradient(
              colors: [GainsColor.lime.opacity(0.28), .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 22
            )
          )
          .blendMode(.plusLighter)
        Image(systemName: icon)
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .shadow(color: GainsColor.lime.opacity(0.225), radius: 3)
      }
      .frame(width: 22, height: 22)
      Text(trimmedTitle.isEmpty ? "Schritt" : trimmedTitle)
        .font(GainsFont.title(12))
        .foregroundStyle(GainsColor.ink)
        .frame(width: 78, alignment: .leading)
      Text(trimmedDetail.isEmpty ? "ohne Detailangabe" : trimmedDetail)
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
      secondaryActionButton(
        icon: "chart.bar.fill",
        title: "Statistik"
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
    let plan = day.workoutPlan ?? store.todayPlannedWorkout
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
      if isLive { return ("AKTIV", .live) }
      switch status {
      case .rest:     return ("PAUSE", .rest)
      case .flexible: return ("FREI", .flex)
      case .planned:  return ("PLAN", .plan)
      }
    }()
    return GainsHeroStatusBadge(label: label, tone: tone)
  }

  private func heroMetricsList(day: WorkoutDayPlan, plan: WorkoutPlan?) -> [GainsHeroMetric] {
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
        .init("ÜBUNGEN", plan.map { "\($0.exercises.count)" } ?? "—"),
        .init("DAUER",   plan.map { "\($0.estimatedDurationMinutes) Min" } ?? "—"),
        .init("SPLIT",   plan?.split ?? "Nicht geplant"),
      ]
    case .rest:
      // P1-1: 3. Slot war früher „STREAK" mit demselben Wert wie „WOCHE" —
      // Duplikat. Recovery-Day-Hero ist der bessere Platz für den Ernährungs-
      // Hinweis: heute kein Trainingsreiz, also rückt Protein nach vorn.
      return [
        .init("WOCHE",   "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)"),
        .init("VOLUMEN", store.weeklyVolumeTons > 0 ? String(format: "%.1f t", store.weeklyVolumeTons) : "ohne Volumenangabe"),
        .init("PROTEIN", "\(store.nutritionProteinToday) / \(store.nutritionTargetProtein) g"),
      ]
    case .flexible:
      return [
        .init("EINHEITEN", "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)"),
        .init("VOLUMEN",  store.weeklyVolumeTons > 0 ? String(format: "%.1f t", store.weeklyVolumeTons) : "ohne Volumenangabe"),
        .init("OPTION",   plan?.split ?? "Frei"),
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
        let trimmedLastTitle = last.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastTitleText = trimmedLastTitle.isEmpty ? "Training" : trimmedLastTitle
        let activeWorkoutTitle = store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        secondaryActionButton(
          icon: "arrow.uturn.backward.circle",
          title: "Wdh.",
          accessibilityLabel: "Letztes Workout wiederholen",
          accessibilityValue: store.activeWorkout != nil ? "Bereits aktiv, \(activeWorkoutTitle.isEmpty ? lastTitleText : activeWorkoutTitle)" : store.activeRun != nil ? "Aktiver Lauf, öffnet dein laufendes Lauftraining" : "\(lastTitleText), \(last.completedSets) von \(last.totalSets) Sätzen zuletzt abgeschlossen",
          accessibilityHint: store.activeWorkout != nil ? "Öffnet dein bereits laufendes Training mit Übungen, Sätzen und Pausen" : store.activeRun != nil ? "Öffnet deinen bereits laufenden Lauf mit Karte, Splits und Steuerung" : "Startet dein letztes Workout erneut oder öffnet dessen Wiederaufnahme"
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
        title: "Statistik"
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

    if store.activeWorkout != nil {
      isShowingWorkoutTracker = true
      return
    }

    if store.activeRun != nil {
      isShowingRunTracker = true
      return
    }

    let trimmedReferenceTitle = reference.title.trimmingCharacters(in: .whitespacesAndNewlines)

    if store.repeatLastWorkout(),
       store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedReferenceTitle {
      isShowingWorkoutTracker = true
    } else if let plan = store.savedWorkoutPlans.first(where: {
      $0.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedReferenceTitle
    }) {
      store.startWorkout(from: plan)
      if store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == plan.title.trimmingCharacters(in: .whitespacesAndNewlines) {
        isShowingWorkoutTracker = true
      }
    } else {
      isShowingWorkoutBuilder = true
    }
  }

  // MARK: - Hero Helpers
  //
  // A8: heroMetrics / metricCell / divider / statusBadge sind weggefallen,
  // weil GainsHeroCard die Pattern intern abdeckt. Die Builder oben
  // (heroMetricsList, heroStatusBadge) füttern die Komponente.

  private func heroTitle(day: WorkoutDayPlan, plan: WorkoutPlan?) -> String {
    switch day.status {
    case .planned:
      if let run = day.runTemplate { return run.title.uppercased() }
      return plan?.title.uppercased() ?? "TRAINING HEUTE"
    case .rest:     return "FREIER TAG"
    case .flexible: return "FLEXIBLER TAG"
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
    if isLive { return "Training öffnen" }
    if store.activeRun != nil { return "Lauf öffnen" }
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
      guard store.activeWorkout != nil else { return }
      isShowingWorkoutTracker = true
      return
    }

    if store.activeRun != nil {
      isShowingRunTracker = true
      return
    }

    if let runTemplate = day.runTemplate {
      if store.activeWorkout != nil {
        isShowingWorkoutTracker = true
      } else {
        let trimmedRunTitle = runTemplate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        store.startRun(from: runTemplate)
        if store.activeRun?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedRunTitle {
          isShowingRunTracker = true
        }
      }
      return
    }

    if day.status == .rest {
      let started: Bool
      if let last = store.lastCompletedWorkout {
        let trimmedLastTitle = last.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let plan = store.savedWorkoutPlans.first(where: {
          $0.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedLastTitle
        }) {
          store.startWorkout(from: plan)
          started = store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
          isShowingWorkoutBuilder = true
          return
        }
      } else {
        isShowingWorkoutBuilder = true
        return
      }
      if started {
        isShowingWorkoutTracker = true
      }
      return
    }

    if let plan = store.todayPlannedWorkout {
      store.startWorkout(from: plan)
      if store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == plan.title.trimmingCharacters(in: .whitespacesAndNewlines) {
        isShowingWorkoutTracker = true
      }
    } else {
      isShowingWorkoutBuilder = true
    }
  }

  private func secondaryActionButton(
    icon: String,
    title: String,
    accessibilityLabel: String? = nil,
    accessibilityValue: String? = nil,
    accessibilityHint: String? = nil,
    action: @escaping () -> Void
  ) -> some View {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    // Polish-Loop 151 (2026-05-14): Secondary-Action-Buttons mit Glas-
    // Composition (glassUndertone + ultraThinMaterial + plusLighter Inner-
    // Light) statt flachem GainsColor.card. Hairline-Border als
    // LinearGradient für Premium-Tiefe.
    Button(action: action) {
      HStack(spacing: GainsSpacing.xsPlus) {
        Image(systemName: icon)
          .font(.system(size: 12, weight: .semibold))
        Text(trimmedTitle.isEmpty ? "Gym-Schnellzugriff" : trimmedTitle)
          .font(GainsFont.label(11))
          .tracking(1.0)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
      }
      .foregroundStyle(GainsColor.ink)
      .frame(maxWidth: .infinity)
      .frame(height: 44)
      .padding(.horizontal, GainsSpacing.s)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(GainsColor.glassUndertone)
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(.ultraThinMaterial)
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(GainsColor.card.opacity(0.45))
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(
              LinearGradient(
                colors: [GainsColor.glassInnerLight, .clear],
                startPoint: .top,
                endPoint: .center
              )
            )
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [
                GainsColor.border.opacity(0.75),
                GainsColor.border.opacity(0.35)
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.hairline
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      .compositingGroup()
      .shadow(color: GainsColor.shadowRest, radius: 5, y: 2)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      accessibilityLabel ?? ({
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Gym-Schnellzugriff" : trimmedTitle
      }())
    )
    .accessibilityValue(accessibilityValue ?? secondaryActionAccessibilityValue(for: title))
    .accessibilityHint(accessibilityHint ?? secondaryActionAccessibilityHint(for: title))
  }

  private func secondaryActionAccessibilityValue(for title: String) -> String {
    switch title.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "Plan":
      return "Wochenplan"
    case "Bibliothek":
      return "Workout-Bibliothek"
    case "Statistik":
      return "Trainingsstatistiken"
    default:
      return "Gym-Schnellzugriff"
    }
  }

  private func secondaryActionAccessibilityHint(for title: String) -> String {
    switch title.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "Plan":
      return "Öffnet deinen Wochenplan"
    case "Bibliothek":
      return "Öffnet deine Workout-Bibliothek"
    case "Statistik":
      return "Öffnet deine Trainingsstatistiken"
    default:
      return "Öffnet diesen Gym-Schnellzugriff"
    }
  }

  // MARK: - Live Session Card

  private var liveSessionCard: some View {
    Group {
      if let session = store.activeWorkout {
        // Single-pass stats — statt 5 separater .stats-Aufrufe
        // (2× via progress() + 3× direkt) wird der O(exercises×sets)-
        // Durchlauf genau einmal pro Render durchgeführt.
        let s = session.stats
        VStack(alignment: .leading, spacing: GainsSpacing.m) {
          // Live-Indikator + Fokus + Elapsed Time
          HStack(spacing: GainsSpacing.xsPlus) {
            Circle()
              .fill(GainsColor.lime)
              .frame(width: 8, height: 8)
            Text("LIVE EINHEIT")
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
            Text({
              let trimmedTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
              return trimmedTitle.isEmpty ? "Training" : trimmedTitle
            }())
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
              .minimumScaleFactor(0.78)
            Text({
              let trimmedFocus = session.focus.trimmingCharacters(in: .whitespacesAndNewlines)
              return trimmedFocus.isEmpty ? "OHNE FOKUSANGABE" : trimmedFocus.uppercased()
            }())
              .font(GainsFont.label(9))
              .tracking(1.5)
              .foregroundStyle(GainsColor.softInk)
          }

          // Polish-Loop 145 (2026-05-14): Progress-Bar mit Track-Border,
          // Lime-Gradient + Inner-Light auf dem Füllstand und subtilem
          // Glow am rechten Rand — wirkt wie ein Telemetrie-Balken.
          GeometryReader { geo in
            let fraction: Double = s.totalSets > 0
              ? min(Double(s.completedSets) / Double(s.totalSets), 1.0) : 0
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(GainsColor.background.opacity(0.65))
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(GainsColor.border.opacity(0.45), lineWidth: GainsBorder.hairline)
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                  LinearGradient(
                    colors: [GainsColor.lime.opacity(0.85), GainsColor.lime],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                      LinearGradient(
                        colors: [
                          Color.white.opacity(0.30),
                          Color.white.opacity(0.00)
                        ],
                        startPoint: .top,
                        endPoint: .center
                      )
                    )
                    .blendMode(.plusLighter)
                )
                .frame(width: max(geo.size.width * fraction, 4))
                .shadow(color: GainsColor.lime.opacity(0.15), radius: 4, x: 1, y: 0)
            }
          }
          .frame(height: 6)
          .compositingGroup()

          HStack(spacing: 0) {
            liveStat("SÄTZE", "\(s.completedSets)/\(s.totalSets)")
            liveStatDivider()
            liveStat("VOLUMEN", s.totalVolume > 0 ? "\(Int(s.totalVolume)) kg" : "ohne Volumenangabe")
            liveStatDivider()
            liveStat("ÜBUNGEN", "\(session.exercises.count)")
          }
          .background(GainsColor.background.opacity(0.55))
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

          // A10: Live-Session-CTA nutzt die neue Premium-Pille — gleiche
          // Sprache wie der Hero-Start-Button, damit „weitermachen" und
          // „starten" als zusammenhängendes Vokabular gelesen werden.
          HeroPrimaryCTAButton(
            title: "Training öffnen",
            icon: "dumbbell.fill",
            action: {
              guard store.activeWorkout != nil else { return }
              isShowingWorkoutTracker = true
            }
          )
          .accessibilityLabel("Aktives Training öffnen")
          .accessibilityValue({
            let trimmedTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedFocus = session.focus.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(trimmedTitle.isEmpty ? "Training" : trimmedTitle), \(trimmedFocus.isEmpty ? "ohne Fokusangabe" : trimmedFocus), \(s.completedSets) von \(s.totalSets) Sätzen abgeschlossen"
          }())
          .accessibilityHint("Öffnet dein laufendes Training mit Übungen, Sätzen und Pausen und führt zur aktuellen Einheit zurück")
        }
        // A13 (Cleaner-Pass): Hero-Resume-Card auf Standard-Card-Geometrie
        // (`GainsRadius.standard` 16, accent-Border statt 1.5pt-Stroke).
        // Der CTA-Button trägt jetzt den Akzent — die Card muss nicht
        // zusätzlich glühen.
        .padding(GainsSpacing.l)
        .background(
          // 2026-05-14 (Polish-Loop 68): Live-Session-Card mit Lime-
          // Glow-Komposition. Sie ist während aktiver Session der
          // primäre Anker im Today-Tab.
          ZStack {
            GainsColor.card
            RadialGradient(
              colors: [GainsColor.lime.opacity(0.18), GainsColor.lime.opacity(0.04), .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 240
            )
            .blendMode(.screen)
            RadialGradient(
              colors: [GainsColor.lime.opacity(0.08), .clear],
              center: .bottomTrailing,
              startRadius: 0,
              endRadius: 200
            )
            .blendMode(.screen)
            LinearGradient(
              colors: [GainsColor.glassInnerLight, Color.clear],
              startPoint: .top,
              endPoint: .center
            )
          }
        )
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .strokeBorder(
              LinearGradient(
                colors: [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: GainsBorder.accent
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        .compositingGroup()
        .shadow(color: GainsColor.lime.opacity(0.09), radius: 14, x: 0, y: 0)
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

  // Polish-Loop 154 (2026-05-14): Live-Stat-Werte als monospacedDigit-
  // Metric, damit Stellenbreiten beim Live-Tick nicht springen.
  private func liveStat(_ label: String, _ value: String) -> some View {
    let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

    VStack(spacing: GainsSpacing.xxs) {
      Text(trimmedLabel.isEmpty ? "Status" : trimmedLabel)
        .font(GainsFont.label(8))
        .tracking(1.5)
        .foregroundStyle(GainsColor.softInk)
      Text(trimmedValue.isEmpty ? "—" : trimmedValue)
        .font(GainsFont.metricMono(16))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, GainsSpacing.tight)
  }

  private func liveStatDivider() -> some View {
    Rectangle()
      .fill(GainsColor.border.opacity(0.4))
      .frame(width: 1, height: 24)
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
          .tracking(GainsTracking.eyebrowTight)
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
    // 2026-05-14 (Polish-Loop 113): Muskel-Chip mit Inner-Light +
    // Mono-Set-Count + Hairline-Border.
    HStack(spacing: GainsSpacing.xs) {
      Circle()
        .fill(GainsColor.lime)
        .frame(width: 6, height: 6)
        .shadow(color: GainsColor.lime.opacity(0.275), radius: 2)
      Text(name.uppercased())
        .font(GainsFont.eyebrow)
        .tracking(GainsTracking.eyebrowTight)
        .foregroundStyle(GainsColor.ink)
      Text("·")
        .font(.system(size: 10))
        .foregroundStyle(GainsColor.mutedInk)
      Text("\(sets)")
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(GainsColor.moss)
    }
    .padding(.horizontal, GainsSpacing.s)
    .frame(height: 30)
    .background(
      ZStack {
        Capsule().fill(GainsColor.background.opacity(0.85))
        Capsule()
          .fill(
            LinearGradient(
              colors: [GainsColor.glassInnerLight, .clear],
              startPoint: .top,
              endPoint: .center
            )
          )
      }
    )
    .overlay(
      Capsule().strokeBorder(GainsColor.border.opacity(0.55), lineWidth: 0.6)
    )
    .clipShape(Capsule())
  }

  // Polish-Loop 172 (2026-05-14): Regenerations-Karte mit Moss-Glow-
  // Komposition + Leaf-Icon-Halo statt flacher gainsCardStyle. Hebt
  // den Ruhetag visuell von einer Trainingstag-Card ab.
  private var regenerationHintCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["REGENERATION", "TIPP"],
          primaryColor: GainsColor.moss,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        ZStack {
          Circle().fill(GainsColor.moss.opacity(0.18))
          Circle()
            .fill(
              LinearGradient(
                colors: [Color.white.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .center
              )
            )
            .blendMode(.plusLighter)
          Image(systemName: "leaf.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(GainsColor.moss)
            .shadow(color: GainsColor.moss.opacity(0.55), radius: 3)
        }
        .frame(width: 26, height: 26)
        .overlay(
          Circle().strokeBorder(GainsColor.moss.opacity(0.40), lineWidth: GainsBorder.hairline)
        )
        .compositingGroup()
        .shadow(color: GainsColor.moss.opacity(0.24), radius: 5, y: 1)
      }
      Text("Schlaf, Eiweiß und 20 Min Spaziergang heute. Regeneration ist Trainingsreiz für morgen.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(GainsSpacing.m)
    .background(
      ZStack {
        GainsColor.card
        RadialGradient(
          colors: [GainsColor.moss.opacity(0.12), .clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 200
        )
        .blendMode(.screen)
        LinearGradient(
          colors: [GainsColor.glassInnerLight, .clear],
          startPoint: .top,
          endPoint: .center
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.moss.opacity(0.40), GainsColor.moss.opacity(0.10)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
    .shadow(color: GainsColor.moss.opacity(0.12), radius: 10)
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
        Text("\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Einheiten")
          .font(GainsFont.label(9))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
      }

      // Wochenstreifen Mo-So
      GymWeekStrip()

      // Inline Volumen-Info — keine eigene Zeile mit Riesen-Zahl mehr.
      HStack(spacing: GainsSpacing.xsPlus) {
        Image(systemName: "scalemass.fill")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(GainsColor.moss)
        Text(currentVolume > 0 ? String(format: "%.1f t Volumen", currentVolume / 1000) : "ohne Volumenangabe")
          .font(GainsFont.label(10))
          .tracking(1.0)
          .foregroundStyle(GainsColor.ink)
        Text("·")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.softInk)
        Text({
          let trimmedTrendLabel = trendInfo.label.trimmingCharacters(in: .whitespacesAndNewlines)
          return trimmedTrendLabel.isEmpty ? "keine Trendangabe" : trimmedTrendLabel
        }())
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
            Text("Statistik")
              .font(GainsFont.label(9))
              .tracking(1.4)
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .bold))
          }
          .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trainingsstatistiken öffnen")
        .accessibilityValue({
          let trimmedTrendLabel = trendInfo.label.trimmingCharacters(in: .whitespacesAndNewlines)
          return "\(store.weeklySessionsCompleted) von \(store.weeklyGoalCount) Einheiten, \(currentVolume > 0 ? "\(String(format: "%.1f", currentVolume / 1000)) Tonnen Volumen" : "noch keine Volumendaten")\(trimmedTrendLabel.isEmpty ? "" : ", \(trimmedTrendLabel)")"
        }())
        .accessibilityHint("Öffnet den Statistikbereich mit Volumen, Trends und weiteren Trainingsdaten")
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  private var weeklyVolumeTrend: [Double] {
    // Single-pass über workoutHistory statt 6 × filter+reduce (O(6n) → O(n)).
    // Gleiche Strategie wie GymStatsTab.weeklyVolumeTrend.
    let calendar = Calendar.current
    let now = Date()
    let buckets: [(lower: Date, upper: Date)] = (0..<6).reversed().map { weeksAgo in
      let upper = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: now) ?? now
      let lower = calendar.date(byAdding: .day, value: -7 * (weeksAgo + 1), to: now) ?? now
      return (lower, upper)
    }
    guard let earliest = buckets.first?.lower else { return Array(repeating: 0, count: 6) }
    var volumes = Array(repeating: 0.0, count: 6)
    for workout in store.workoutHistory {
      let date = workout.finishedAt
      guard date >= earliest else { break } // newest-first → früher Ausstieg
      for (idx, bucket) in buckets.enumerated() {
        if date >= bucket.lower && date < bucket.upper {
          volumes[idx] += workout.volume
          break
        }
      }
    }
    return volumes
  }

  private func volumeTrendDelta(current: Double, previous: Double) -> (label: String, color: Color) {
    guard previous > 0 else {
      if current > 0 { return ("Erste Daten dieser Woche", GainsColor.softInk) }
      return ("Noch kein Training diese Woche", GainsColor.softInk)
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
        // Polish-Loop 167 (2026-05-14): Check-Badge mit Inner-Light +
        // Hairline + Lime-Glow — wirkt wie geprägte Medaille statt Wash.
        ZStack {
          Circle().fill(GainsColor.lime.opacity(0.18))
          Circle()
            .fill(
              LinearGradient(
                colors: [
                  Color.white.opacity(0.18),
                  Color.white.opacity(0.00)
                ],
                startPoint: .top,
                endPoint: .center
              )
            )
            .blendMode(.plusLighter)
          Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(GainsColor.moss)
        }
        .frame(width: 36, height: 36)
        .overlay(
          Circle()
            .strokeBorder(GainsColor.lime.opacity(0.40), lineWidth: GainsBorder.hairline)
        )
        .compositingGroup()
        .shadow(color: GainsColor.lime.opacity(0.1), radius: 5, y: 1)

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text("LETZTES TRAINING · \(when.uppercased())")
            .font(GainsFont.label(10))
            .tracking(1.4)
            .foregroundStyle(GainsColor.softInk)
          Text({
            let trimmedTitle = last.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedTitle.isEmpty ? "Training" : trimmedTitle
          }())
            .font(GainsFont.title(15))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Text("\(last.completedSets)/\(last.totalSets) Sätze · \(last.volume > 0 ? "\(Int(last.volume)) kg" : "ohne Volumenangabe") · \(completion) %")
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
    .accessibilityLabel("Letztes Training")
    .accessibilityValue({
      let trimmedTitle = last.title.trimmingCharacters(in: .whitespacesAndNewlines)
      return "\(trimmedTitle.isEmpty ? "Training" : trimmedTitle), \(when), \(last.completedSets) von \(last.totalSets) Sätzen, \(last.volume > 0 ? "\(Int(last.volume)) Kilogramm" : "ohne Volumenangabe"), \(completion) Prozent abgeschlossen"
    }())
    .accessibilityHint("Öffnet deine Trainingsstatistiken mit weiteren Details zu dieser letzten Einheit")
  }
}
