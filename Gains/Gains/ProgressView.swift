import SwiftUI

// MARK: - Verlauf-Filter

private enum HistoryFilter: String, CaseIterable, Identifiable {
  case all, strength, cardio
  var id: Self { self }

  var label: String {
    switch self {
    case .all:      return "Alle"
    case .strength: return "Krafttraining"
    case .cardio:   return "Laufen"
    }
  }
}

private enum HistoryEntry: Identifiable {
  case workout(CompletedWorkoutSummary)
  case run(CompletedRunSummary)

  var id: UUID {
    switch self {
    case .workout(let w): return w.id
    case .run(let r):     return r.id
    }
  }

  var date: Date {
    switch self {
    case .workout(let w): return w.finishedAt
    case .run(let r):     return r.finishedAt
    }
  }
}

// MARK: - 365-Tage-Aktivitätsgrid Datenmodell (Brand-Loop 7)
//
// 2026-05-15 Perf-Loop: Berechnung in GainsStore mit Cache verschoben
// (O(n+m+365) nur bei Datenänderungen, nicht bei jedem Render).
// `YearActivityData` ist jetzt `GainsStore.YearActivityData`.
private typealias YearActivityData = GainsStore.YearActivityData

// MARK: - Highlights (PRs + Milestones gemerged)

private enum HighlightKind {
  case personalRecord
  case milestone
  case streak
  case run
}

private struct HighlightEntry: Identifiable {
  let id = UUID()
  let kind: HighlightKind
  let title: String
  let detail: String
  let date: Date
  let dateLabel: String
}

// MARK: - Story-Hero (dynamische Variante)

private enum ProgressHero {
  case personalRecord(exercise: String, weight: String, delta: String)
  case streak(days: Int)
  case weightLow(weight: Double, deltaFromStart: Double)
  case weekComplete(sessions: Int)
  case longestRun(km: Double)
  case comeback(daysAway: Int)
  case onTrack(done: Int, goal: Int, percent: Int)
  case starting

  var eyebrow: String {
    switch self {
    case .personalRecord: return "PERSONAL RECORD"
    case .streak:         return "STREAK"
    case .weightLow:      return "NEUER TIEFSTWERT"
    case .weekComplete:   return "WOCHENZIEL"
    case .longestRun:     return "DISTANZ-PR"
    case .comeback:       return "COMEBACK"
    case .onTrack:        return "DIESE WOCHE"
    case .starting:       return "GAINS. · START"
    }
  }

  var icon: String {
    switch self {
    case .personalRecord: return "bolt.fill"
    case .streak:         return "flame.fill"
    case .weightLow:      return "arrow.down.right.circle.fill"
    case .weekComplete:   return "checkmark.seal.fill"
    case .longestRun:     return "figure.run"
    case .comeback:       return "arrow.uturn.up.circle.fill"
    case .onTrack:        return "target"
    case .starting:       return "sparkles"
    }
  }

  var accent: Color {
    switch self {
    case .personalRecord, .weekComplete, .streak, .onTrack:
      return GainsColor.lime
    case .weightLow, .longestRun:
      return GainsColor.accentCool
    case .comeback:
      return GainsColor.ember
    case .starting:
      return GainsColor.lime
    }
  }
}

/// Vollbild-Variante des Fortschritts (wird als Sheet vom Home-Screen geöffnet).
struct ProgressView: View {
  var body: some View {
    GainsScreen {
      // Kein LazyVStack hier: ProgressContentView ist ein einzelner
      // Block – LazyVStack bringt bei 2 Items keinen Vorteil, erzeugt
      // aber Layout-Ambiguität wenn innen ebenfalls ein (Lazy)VStack
      // liegt (verschachtelte Lazy-Stacks können keine Höhen auflösen).
      VStack(alignment: .leading, spacing: GainsSpacing.l) {
        screenHeader(
          eyebrow: "BODY / REFLECTION",
          title: "Fortschritt",
          subtitle: "Story der Woche, Coach-Hinweis und dein Bild in Zahlen."
        )
        ProgressContentView()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// Inhaltsteil ohne Wrapper. Story-Hero zuerst, dann ein einziger Coach-Insight,
/// dann Pulse-Strip + drei Story-Karten (Stärke / Körper / Cardio), darunter
/// Ziele, Readiness, Highlights und ein kompakter Verlauf.
struct ProgressContentView: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore
  // 2026-05-15 (P0 #2): Dismiss-Hook damit das Sheet sich schließt BEVOR
  // ein Tab-Wechsel oder Fullscreen-Cover präsentiert wird. Ohne dismiss()
  // bleibt das ProgressView-Sheet offen und verdeckt den Ziel-Tab.
  @Environment(\.dismiss) private var dismiss

  @State private var historyFilter: HistoryFilter = .all
  @State private var coachInsightIndex: Int = 0
  @State private var isShowingRunTracker = false
  @State private var isShowingWorkoutTracker = false

  var body: some View {
    // VStack statt LazyVStack: Fortschritt-Seite ist eine einzige
    // zusammenhängende Story-Seite, kein langer Feed. LazyVStack
    // innerhalb eines anderen (Lazy)VStack bricht die Höhenberechnung
    // und erzeugt Scroll-Ruckler. VStack lässt SwiftUI alle Höhen
    // vorab berechnen → flüssiges Scrollen.
    VStack(alignment: .leading, spacing: GainsSpacing.xl) {
      heroBanner
      coachInsightCard
      readinessRow
      pulseStrip
      yearActivityGrid
      storyCardsBlock
      goalsSection
      highlightsSection
      historySection
      // H4-Fix (2026-05-01): Footer-CTA, damit der lange Scroll nicht
      // ohne nächstes Schritt-Signal endet. Verlinkt kontextsensitiv:
      // wenn heute geplant ist → Plan, sonst → Training starten.
      progressFooterCTA
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .sheet(isPresented: $isShowingRunTracker) {
      RunTrackerView()
        .environmentObject(store)
    }
    .fullScreenCover(isPresented: $isShowingWorkoutTracker) {
      WorkoutTrackerView()
        .environmentObject(store)
    }
  }

  /// Footer-CTA, der am Ende der ProgressContentView den nächsten Schritt
  /// signalisiert. Wirkt wie ein Pulsschluss am Ende der Story-Sektionen.
  private var progressFooterCTA: some View {
    let plan = store.todayPlannedDay
    let isPlanned = plan.status == .planned
    let opensRun = plan.runTemplate != nil || plan.sessionKind?.isRun == true
    let title: String = isPlanned ? (opensRun ? "Lauftraining öffnen" : "Krafttraining öffnen") : "Wochenplan öffnen"
    let subtitle: String = isPlanned
      ? plan.runTemplate?.title ?? plan.workoutPlan?.title ?? plan.title
      : "Wochenplan anpassen"
    let icon: String = isPlanned ? "play.fill" : "calendar"

    return Button {
      if isPlanned {
        dismiss()
        navigation.openTraining(workspace: opensRun ? .laufen : .kraft)
      } else {
        dismiss()
        navigation.openWeekPlanFullscreen()
      }
    } label: {
      let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

      HStack(spacing: GainsSpacing.m) {
        ZStack {
          Circle()
            .fill(GainsColor.lime.opacity(0.18))
            .frame(width: 42, height: 42)
          Image(systemName: icon)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(GainsColor.onLime)
        }
        .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text("NÄCHSTER SCHRITT")
            .gainsEyebrow(GainsColor.lime, size: 9, tracking: 1.4)
          Text(trimmedTitle.isEmpty ? "Nächster Schritt" : trimmedTitle)
            .font(GainsFont.title(17))
            .foregroundStyle(GainsColor.ink)
          Text(trimmedSubtitle.isEmpty ? "ohne Detailangabe" : trimmedSubtitle)
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right")
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(GainsColor.softInk)
          .accessibilityHidden(true)
      }
      .padding(GainsSpacing.m)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
    .contentShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .accessibilityLabel(isPlanned ? (opensRun ? "Nächster Schritt, Lauftraining öffnen" : "Nächster Schritt, Krafttraining öffnen") : "Nächster Schritt, Wochenplan öffnen")
    .accessibilityValue(
      {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let spokenTitle = trimmedTitle.isEmpty ? "Nächster Schritt" : trimmedTitle
        let spokenSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if isPlanned {
          return spokenSubtitle.isEmpty ? spokenTitle : "\(spokenTitle). \(spokenSubtitle)"
        }
        return spokenSubtitle.isEmpty ? "\(spokenTitle). Nächster offener Planungsschritt" : "\(spokenTitle). \(spokenSubtitle). Nächster offener Planungsschritt"
      }()
    )
    .accessibilityHint(
      isPlanned
        ? (opensRun
            ? "Schließt den Fortschritt und öffnet den Lauftraining-Bereich"
            : "Schließt den Fortschritt und öffnet den Krafttraining-Bereich")
        : "Schließt den Fortschritt und öffnet deinen Wochenplan"
    )
  }

  // MARK: - 1. Story-Hero (dynamisch)

  private var heroBanner: some View {
    let variant = heroVariant
    let copy = heroCopy(for: variant)

    return ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
        .fill(GainsColor.ctaSurface)

      RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
        .stroke(variant.accent.opacity(0.22), lineWidth: 1)

      // B5 (Hero-Glow per Variante): jede Hero-Variante bringt jetzt eine
      // eigene Glow-Signatur — Streak hat zwei pulsierende Halos, PR ein
      // diagonales Sparkle-Trio, Comeback einen welligen Pulse-Ring usw.
      // `heroGlowOverlay(variant:)` zeichnet dafür einen variant-spezifischen
      // Hintergrund-Layer; der bisherige zentrale Blur-Circle bleibt als
      // Fallback bestehen.
      Circle()
        .fill(variant.accent.opacity(0.18))
        .frame(width: 220, height: 220)
        .blur(radius: 70)
        .offset(x: 130, y: -110)

      heroGlowOverlay(variant: variant)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))

      VStack(alignment: .leading, spacing: GainsSpacing.m) {
        HStack(spacing: GainsSpacing.xsPlus) {
          Image(systemName: variant.icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(variant.accent)
            .frame(width: 22, height: 22)
            .background(variant.accent.opacity(0.16))
            .clipShape(Circle())

          Text(variant.eyebrow)
            .font(GainsFont.label(10))
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(variant.accent)

          Spacer()

          Text("KW \(weekNumber)")
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.55))
            .padding(.horizontal, GainsSpacing.xsPlus)
            .padding(.vertical, GainsSpacing.xxs)
            .background(GainsColor.onCtaSurface.opacity(0.08))
            .clipShape(Capsule())
        }

        Text(copy.headline)
          .font(.system(size: 30, weight: .semibold))
          .foregroundStyle(GainsColor.onCtaSurface)
          .lineLimit(2)
          .minimumScaleFactor(0.7)
          .padding(.top, GainsSpacing.xxs)

        Text(copy.subline)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.72))
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: GainsSpacing.m) {
          Rectangle()
            .fill(variant.accent.opacity(0.7))
            .frame(width: 44, height: 2)

          if let badge = copy.badge {
            Text(badge)
              .font(GainsFont.label(9))
              .tracking(GainsTracking.eyebrow)
              .foregroundStyle(variant.accent)
          }

          Spacer()

          Button {
            heroAction(for: variant)
          } label: {
            HStack(spacing: GainsSpacing.xs) {
              Text(copy.cta)
                .font(GainsFont.label(10))
                .tracking(1.4)
              Image(systemName: "arrow.up.right")
                .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(variant.accent)
            .padding(.horizontal, GainsSpacing.s)
            .frame(minHeight: 32)
            .background(variant.accent.opacity(0.12))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
        .padding(.top, GainsSpacing.xxs)
      }
      .padding(GainsSpacing.l)
    }
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
  }

  private func heroCopy(for hero: ProgressHero) -> (headline: String, subline: String, badge: String?, cta: String) {
    switch hero {
    case let .personalRecord(name, weight, delta):
      return (
        headline: "\(name) — \(weight)",
        subline: "Frischer Top-Wert. Im nächsten Block 2.5 kg drauf, 3×5 saubere Reps.",
        badge: delta,
        cta: "Krafttraining öffnen"
      )
    case let .streak(days):
      let line: String
      if days >= 100      { line = "Triple-Digit-Streak. Routine ist nicht mehr verhandelbar." }
      else if days >= 30  { line = "Ein Monat am Stück. Jetzt auf Volumen-Progression schauen." }
      else if days >= 14  { line = "Doppel-Woche durchgezogen. Recovery jetzt mitsteuern." }
      else                { line = "Eine Woche Momentum — jetzt zur Routine machen." }
      return (
        headline: "\(days) Tage am Stück",
        subline: line,
        badge: "STREAK · \(days)d",
        cta: "Wochenplan öffnen"
      )
    case let .weightLow(weight, delta):
      let deltaTxt = abs(delta) >= 0.05
        ? String(format: "%.1f kg unter Start", abs(delta))
        : "Neuer Tiefstwert"
      return (
        headline: String(format: "%.1f kg", weight),
        subline: "Gewicht arbeitet runter. Protein bei 1.8 g/kg halten — Muskel schützen, Fett verlieren.",
        badge: deltaTxt,
        cta: "Eintrag loggen"
      )
    case let .weekComplete(sessions):
      let sessionLabel = sessions == 1 ? "1 Session" : "\(sessions) Sessions"
      return (
        headline: "Wochenziel durchgezogen",
        subline: "\(sessionLabel) im Kasten. Bonus-Session ist jetzt Ass im Ärmel, nicht Pflicht.",
        badge: "\(sessions)/\(store.weeklyGoalCount) ✓",
        cta: "Krafttraining öffnen"
      )
    case let .longestRun(km):
      return (
        headline: String(format: "%.1f km gelaufen", km),
        subline: "Längster Lauf seit Trainingsstart. Nächste Woche 10 % drauf — saubere Steigerung.",
        badge: "DISTANZ-PR",
        cta: "Lauf öffnen"
      )
    case let .comeback(daysAway):
      return (
        headline: "Zurück nach \(daysAway) Tagen",
        subline: "Erste Session nach Pause sitzt. Halte heute die Intensität niedrig — Comeback nicht überdrehen.",
        badge: "COMEBACK",
        cta: "Wochenplan öffnen"
      )
    case let .onTrack(done, goal, percent):
      let remaining = max(goal - done, 0)
      let line: String
      if remaining == 0       { line = "Alle Sessions sitzen. Nächste Woche: gleiche Frequenz, mehr Volumen." }
      else if remaining == 1  { line = "Eine Einheit noch. Du brauchst 45 Minuten — die hast du." }
      else                    { line = "\(remaining) Einheiten offen. Plan check, dann eintakten." }
      return (
        headline: "\(done) von \(goal) — \(percent) %",
        subline: line,
        badge: "WOCHENPLAN",
        cta: "Krafttraining öffnen"
      )
    case .starting:
      return (
        headline: "Fortschritt sichtbar machen",
        subline: "Logge dein erstes Workout oder einen Check-in — ab dann erzählt sich diese Seite selbst.",
        badge: "TAG 1",
        cta: "Wochenplan öffnen"
      )
    }
  }

  // MARK: - Hero-Glow per Variante
  //
  // B5: Jede Hero-Variante bekommt einen eigenen subtilen Hintergrund-Layer.
  // Bewusst zurückhaltend gehalten — es geht um Differenzierung, nicht um
  // Disco. Die Animationen laufen langsam (3-5s), um peripheres Sehen nicht
  // zu stören.

  @ViewBuilder
  private func heroGlowOverlay(variant: ProgressHero) -> some View {
    switch variant {
    case .personalRecord:
      heroSparkleGlow(accent: variant.accent)
    case .streak:
      heroDualHaloGlow(accent: variant.accent)
    case .weightLow, .longestRun:
      heroDiagonalShineGlow(accent: variant.accent)
    case .weekComplete:
      heroCheckmarkGlow(accent: variant.accent)
    case .comeback:
      heroPulseRingGlow(accent: variant.accent)
    case .onTrack, .starting:
      EmptyView()
    }
  }

  /// Drei kleine Sparkles diagonal verteilt — für PR-Variante. Jeder mit
  /// leichter Phasenverschiebung in der Atmung, damit es lebt ohne flackernd
  /// zu wirken.
  private func heroSparkleGlow(accent: Color) -> some View {
    HeroSparklesView(accent: accent)
  }

  /// Zwei konzentrische Halos die wie eine pulsierende Flamme wirken —
  /// passt zur Streak/Flame-Metapher.
  private func heroDualHaloGlow(accent: Color) -> some View {
    HeroDualHaloView(accent: accent)
  }

  /// Diagonaler Lichtstreifen (oben rechts → unten links) — nutzt der Cyan-
  /// Akzent für Distanz-PR und Weight-Low.
  private func heroDiagonalShineGlow(accent: Color) -> some View {
    LinearGradient(
      colors: [
        accent.opacity(0.22),
        accent.opacity(0.0),
        accent.opacity(0.0),
        accent.opacity(0.10)
      ],
      startPoint: .topTrailing,
      endPoint: .bottomLeading
    )
    .blendMode(.plusLighter)
  }

  /// Diffuser Halo von oben — passt zu „Wochenziel durchgezogen" als
  /// abrundender Glanz.
  private func heroCheckmarkGlow(accent: Color) -> some View {
    LinearGradient(
      colors: [accent.opacity(0.20), accent.opacity(0.0)],
      startPoint: .top,
      endPoint: .bottom
    )
    .blendMode(.plusLighter)
  }

  /// Konzentrische Pulse-Ringe — Comeback-Variante.
  private func heroPulseRingGlow(accent: Color) -> some View {
    HeroPulseRingView(accent: accent)
  }

  private func heroAction(for hero: ProgressHero) {
    switch hero {
    case .personalRecord, .streak, .weekComplete, .onTrack:
      dismiss()
      navigation.openTraining(workspace: .kraft)
    case .starting:
      // H6-Fix (2026-05-01): Erstanfänger ohne Plan/Daten landeten via
      // openTraining(.kraft) in einer leeren Gym-Session. Stattdessen
      // den Planner öffnen, damit sie zuerst einen Plan auswählen oder
      // einen eigenen anlegen.
      dismiss()
      navigation.openWeekPlanFullscreen()
    case .weightLow:
      store.logWeightCheckIn()
    case .longestRun:
      dismiss()
      navigation.openTraining(workspace: .laufen)
    case .comeback:
      dismiss()
      navigation.openWeekPlanFullscreen()
    }
  }

  // MARK: - Hero-Variante bestimmen (Priorität)

  private var heroVariant: ProgressHero {
    if let pr = recentPersonalRecord { return pr }
    if let milestone = streakMilestone { return milestone }
    if let low = recentWeightLow { return low }
    if store.weeklyGoalCount > 0,
       store.weeklySessionsCompleted >= store.weeklyGoalCount {
      return .weekComplete(sessions: store.weeklySessionsCompleted)
    }
    if let lr = recentLongestRun { return lr }
    if let cb = recentComeback { return cb }
    if store.weeklyGoalCount > 0 {
      let pct = Int(Double(store.weeklySessionsCompleted) / Double(store.weeklyGoalCount) * 100)
      return .onTrack(
        done: store.weeklySessionsCompleted,
        goal: store.weeklyGoalCount,
        percent: pct
      )
    }
    return .starting
  }

  private var recentPersonalRecord: ProgressHero? {
    let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
    // Single-Pass statt 2× O(n): Verlauf einmalig durchgehen,
    // jeweils in „recent" (≥cutoff) und „allTime" (<cutoff) einordnen.
    var bestRecent: [String: Double] = [:]
    var bestAllTime: [String: Double] = [:]
    var hasRecent = false
    for workout in store.workoutHistory {
      let isRecent = workout.finishedAt >= cutoff
      if isRecent { hasRecent = true }
      for ex in workout.exercises where ex.topWeight > 0 {
        if isRecent {
          bestRecent[ex.name] = max(bestRecent[ex.name] ?? 0, ex.topWeight)
        } else {
          bestAllTime[ex.name] = max(bestAllTime[ex.name] ?? 0, ex.topWeight)
        }
      }
    }
    guard hasRecent else { return nil }

    var bestDelta: (name: String, weight: Double, delta: Double)?
    for (name, weight) in bestRecent {
      let baseline = bestAllTime[name] ?? 0
      let delta = weight - baseline
      if delta > 0.01 {
        if let current = bestDelta {
          if delta > current.delta {
            bestDelta = (name, weight, delta)
          }
        } else {
          bestDelta = (name, weight, delta)
        }
      }
    }

    guard let pr = bestDelta else { return nil }
    let deltaText = (bestAllTime[pr.name] ?? 0) == 0
      ? "ERSTER TOP-WERT"
      : String(format: "+%.1f kg", pr.delta)
    return .personalRecord(
      exercise: pr.name,
      weight: String(format: "%.1f kg", pr.weight),
      delta: deltaText
    )
  }

  private var streakMilestone: ProgressHero? {
    let milestones: Set<Int> = [7, 14, 21, 30, 60, 100, 200, 365]
    return milestones.contains(store.streakDays) ? .streak(days: store.streakDays) : nil
  }

  private var recentWeightLow: ProgressHero? {
    let points = store.weightTrend
    guard let latest = points.last, points.count >= 3 else { return nil }
    let priorMin = points.dropLast().map(\.value).min() ?? latest.value
    guard latest.value < priorMin - 0.05 else { return nil }
    let delta = latest.value - store.startingWeight
    return .weightLow(weight: latest.value, deltaFromStart: delta)
  }

  private var recentLongestRun: ProgressHero? {
    let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
    // Single-Pass statt 2× O(n): beide Buckets in einem Lauf.
    var recentMax: CompletedRunSummary? = nil
    var allTimeMax = 0.0
    for run in store.runHistory {
      if run.finishedAt >= cutoff {
        if run.distanceKm > (recentMax?.distanceKm ?? 0) {
          recentMax = run
        }
      } else {
        if run.distanceKm > allTimeMax { allTimeMax = run.distanceKm }
      }
    }
    guard let latest = recentMax, latest.distanceKm > allTimeMax + 0.1 else { return nil }
    return .longestRun(km: latest.distanceKm)
  }

  private var recentComeback: ProgressHero? {
    // Statt O((n+m) log(n+m)) sort: beide Histories sind bereits newest-first.
    // Wir brauchen nur Top-2 Dates — lineares Merge der ersten Elemente reicht.
    let wTop = store.workoutHistory.first?.finishedAt
    let rTop = store.runHistory.first?.finishedAt
    // Bestimme die neueste und zweit-neueste Datum ohne Vollsort.
    let latest: Date
    let secondDate: Date
    switch (wTop, rTop) {
    case (nil, nil): return nil
    case (let w?, nil):
      guard store.workoutHistory.count >= 2 else { return nil }
      latest = w
      secondDate = store.workoutHistory[1].finishedAt
    case (nil, let r?):
      guard store.runHistory.count >= 2 else { return nil }
      latest = r
      secondDate = store.runHistory[1].finishedAt
    case (let w?, let r?):
      if w >= r {
        latest = w
        // Zweitgrößte: entweder workoutHistory[1] oder runHistory[0]
        let w2 = store.workoutHistory.count >= 2 ? store.workoutHistory[1].finishedAt : Date.distantPast
        secondDate = max(r, w2)
      } else {
        latest = r
        let r2 = store.runHistory.count >= 2 ? store.runHistory[1].finishedAt : Date.distantPast
        secondDate = max(w, r2)
      }
    }
    let cal = Calendar.current
    let daysBetween = cal.dateComponents([.day], from: secondDate, to: latest).day ?? 0
    let daysSinceLatest = cal.dateComponents([.day], from: latest, to: Date()).day ?? 0
    guard daysBetween >= 4, daysSinceLatest <= 1 else { return nil }
    return .comeback(daysAway: daysBetween)
  }

  // MARK: - 2. Coach-Insight

  private var coachInsightCard: some View {
    let insights = coachInsights
    let safeIndex = insights.isEmpty ? 0 : coachInsightIndex % max(insights.count, 1)
    let current = insights.indices.contains(safeIndex) ? insights[safeIndex] : coachFallback

    let canCycle = insights.count > 1
    return Button {
      guard canCycle else { return }
      withAnimation(.easeInOut(duration: 0.22)) {
        coachInsightIndex = (coachInsightIndex + 1) % insights.count
      }
    } label: {
      // B5 (Coach-Insight-Tone): Card bekommt einen subtilen Hintergrund-Wash
      // in der Akzent-Farbe (Lime/Cyan/Ember) plus eine Akzent-Border-Linie
      // links als HUD-Marker. Icon-Plate von 38pt → 44pt mit Halo. Title-Eyebrow
      // mit zusätzlichem Status-Wort („MOMENTUM" / „WARNUNG" / „INFO") nach Tone.
      HStack(alignment: .top, spacing: GainsSpacing.m) {
        coachIconPlate(icon: current.icon, accent: current.accent)

        VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
          HStack(spacing: GainsSpacing.xs) {
            Text("COACH")
              .font(GainsFont.label(9))
              .tracking(GainsTracking.eyebrowWide)
              .foregroundStyle(current.accent)
            Text("·")
              .font(GainsFont.label(9))
              .foregroundStyle(GainsColor.softInk.opacity(0.6))
            Text(coachToneLabel(for: current.accent))
              .font(GainsFont.label(9))
              .tracking(GainsTracking.eyebrow)
              .foregroundStyle(GainsColor.softInk)
            if insights.count > 1 {
              Text("\(safeIndex + 1)/\(insights.count)")
                .font(GainsFont.label(8))
                .tracking(GainsTracking.eyebrowTight)
                .foregroundStyle(GainsColor.softInk.opacity(0.85))
                .padding(.horizontal, GainsSpacing.xs)
                .frame(minHeight: 16)
                .background(GainsColor.surfaceDeep.opacity(0.7))
                .clipShape(Capsule())
            }
            Spacer()
            if insights.count > 1 {
              Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(current.accent.opacity(0.7))
            }
          }

          let trimmedCurrentText = current.text.trimmingCharacters(in: .whitespacesAndNewlines)

          Text(trimmedCurrentText.isEmpty ? "Noch kein Fortschrittshinweis" : trimmedCurrentText)
            .font(GainsFont.body(15))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
        }
      }
      // A13 (Cleaner-Pass): cornerRadius 18→16 (`GainsRadius.standard`,
      // konsistent mit gainsCardStyle), Akzent-Glow 0.15→0.07,
      // Black-Shadow 0.45→0.32. Coach-Insight bleibt spürbar tone-getragen,
      // ohne als zweite Hero-Card zu konkurrieren.
      .padding(GainsSpacing.m)
      .background(coachInsightBackground(accent: current.accent))
      .overlay(coachInsightBorder(accent: current.accent))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .shadow(color: current.accent.opacity(0.07), radius: 10, x: 0, y: 5)
      .gainsSoftShadow()
      .id("coach-\(safeIndex)") // Forces transition on insight change
      .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
    .buttonStyle(.plain)
    .contentShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .accessibilityLabel("Coach Hinweis")
    .accessibilityValue(
      {
        let trimmedText = current.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if canCycle {
          return "Hinweis \(safeIndex + 1) von \(insights.count). \(trimmedText.isEmpty ? "Kein Hinweistext" : trimmedText)"
        }
        return trimmedText.isEmpty ? "Kein Hinweistext" : trimmedText
      }()
    )
    .accessibilityHint(canCycle ? "Doppeltippen, um zum nächsten Coaching-Hinweis zu wechseln" : "Zeigt deinen aktuellen Coaching-Hinweis")
  }

  /// Größere Icon-Plate (44pt) mit Halo + leichtem Akzent-Glow — Insights
  /// bekommen damit ein klares visuelles Gewicht je nach Tone.
  private func coachIconPlate(icon: String, accent: Color) -> some View {
    // A13 (Cleaner-Pass): Border 0.45→0.35, Glow 0.35→0.16. Icon-Plate
    // bleibt klar identifizierbar (Akzentfarbe + leichter Halo), aber
    // konkurriert nicht mehr mit dem Hero-Story-Card-Akzent.
    ZStack {
      Circle()
        .fill(accent.opacity(0.10))
      Circle()
        .strokeBorder(accent.opacity(0.35), lineWidth: GainsBorder.hairline)
      Image(systemName: icon)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(accent)
    }
    .frame(width: 44, height: 44)
    .shadow(color: accent.opacity(0.16), radius: 6)
    .accessibilityHidden(true)
  }

  /// Tone-spezifischer Hintergrund-Wash: Lime = Momentum, Ember = Warnung,
  /// Cool = Info. Jeweils ein sehr dezenter Diagonal-Gradient von der
  /// Akzent-Farbe zur Card-Surface, sodass die Card die Stimmung trägt
  /// ohne laut zu werden.
  private func coachInsightBackground(accent: Color) -> some View {
    LinearGradient(
      colors: [
        accent.opacity(0.13),
        accent.opacity(0.04),
        GainsColor.card
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  /// Akzent-Border oben → blass unten — der HUD-Marker, der die Card
  /// als „aktiv" markiert. Anstelle der gleichmäßigen Hairline der
  /// Standard-Card-Style gibt das eine direktere Tone-Lesart.
  private func coachInsightBorder(accent: Color) -> some View {
    // A13: Border-Top-Stop 0.55→0.40, lineWidth 0.8 → GainsBorder.accent (0.8).
    // Konsistent zur HeroCard-Border-Stärke.
    RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
      .strokeBorder(
        LinearGradient(
          colors: [
            accent.opacity(0.40),
            accent.opacity(0.08),
            GainsColor.border.opacity(0.6)
          ],
          startPoint: .top,
          endPoint: .bottom
        ),
        lineWidth: GainsBorder.accent
      )
  }

  /// Status-Wort, das den Tone benennt — sitzt neben „COACH" im Eyebrow.
  /// Lime = Momentum, Ember = Warnung, Cool = Info, sonst Hinweis.
  private func coachToneLabel(for accent: Color) -> String {
    if accent == GainsColor.lime  { return "MOMENTUM" }
    if accent == GainsColor.ember { return "WARNUNG" }
    if accent == GainsColor.accentCool { return "INFO" }
    return "HINWEIS"
  }

  private struct CoachInsight {
    let icon: String
    let text: String
    let accent: Color
  }

  private var coachFallback: CoachInsight {
    CoachInsight(
      icon: "sparkles",
      text: "Sobald deine ersten Einheiten oder Check-ins drin sind, wird hier eine echte Beobachtung stehen.",
      accent: GainsColor.lime
    )
  }

  private var coachInsights: [CoachInsight] {
    var list: [CoachInsight] = []

    if store.streakDays >= 7 {
      list.append(CoachInsight(
        icon: "flame.fill",
        text: "Du trainierst seit \(store.streakDays) Tagen am Stück. Routine sitzt — der nächste Hebel ist Volumen-Progression in deinen 2 schwächsten Übungen.",
        accent: GainsColor.lime
      ))
    } else if store.streakDays == 0 && (store.workoutHistory.isEmpty == false || store.runHistory.isEmpty == false) {
      list.append(CoachInsight(
        icon: "arrow.triangle.2.circlepath",
        text: "Streak ist gerissen. Eine kurze Session heute reicht, um den Counter wieder auf 1 zu setzen — Anker zählt mehr als Perfektion.",
        accent: GainsColor.ember
      ))
    }

    let remaining = max(store.weeklyGoalCount - store.weeklySessionsCompleted, 0)
    if remaining > 0 && store.weeklyGoalCount > 0 {
      let calendar = Calendar.current
      let weekday = calendar.component(.weekday, from: Date())
      let isLateWeek = weekday >= 5 || weekday == 1
      if isLateWeek && remaining >= 2 {
        list.append(CoachInsight(
          icon: "exclamationmark.triangle.fill",
          text: "Späte Wochenhälfte und noch \(remaining) Einheiten offen. Realistisch: heute 1 Einheit retten, morgen die zweite — Rest plan-mäßig in nächste Woche schieben.",
          accent: GainsColor.ember
        ))
      }
    }

    if store.personalRecordCount >= 1 {
      list.append(CoachInsight(
        icon: "bolt.fill",
        text: "\(store.personalRecordCount) Volumen-PR\(store.personalRecordCount == 1 ? "" : "s") in der Historie. Halte das mit 0.5–2.5 kg Steigerung pro Woche und sauberer RPE-Kontrolle.",
        accent: GainsColor.lime
      ))
    }

    let weightDelta = store.startingWeight - store.currentWeight
    if weightDelta > 0.5 {
      list.append(CoachInsight(
        icon: "arrow.down.right.circle.fill",
        text: String(format: "%.1f kg unter Startgewicht. Tempo passt — Protein bei 1.8 g/kg, Schritte ≥ 8.000 als unsichtbarer Bodyweight-Hebel.", weightDelta),
        accent: GainsColor.accentCool
      ))
    } else if weightDelta < -0.5 {
      list.append(CoachInsight(
        icon: "arrow.up.right.circle.fill",
        text: String(format: "+%.1f kg über Start. Bei Bulk: Volumen halten, Surplus auf 200–300 kcal kappen, sonst kippt's in Fett.", abs(weightDelta)),
        accent: GainsColor.ember
      ))
    }

    if let latestRun = store.runHistory.first {
      let daysAgo = Calendar.current.dateComponents([.day], from: latestRun.finishedAt, to: Date()).day ?? 0
      if daysAgo >= 7 {
        list.append(CoachInsight(
          icon: "figure.run",
          text: "Dein letzter Lauf liegt \(daysAgo) Tage zurück. Eine lockere 30-Minuten-Einheit diese Woche reicht, um deine aerobe Basis nicht zu verlieren.",
          accent: GainsColor.accentCool
        ))
      }
    }

    if let hrv = vitalValue(named: "HRV"), let hrvNumber = parseInt(hrv.value) {
      if hrvNumber < 55 {
        list.append(CoachInsight(
          icon: "waveform.path.ecg",
          text: "HRV \(hrvNumber) ms — unter Baseline. Heute eher mobilisieren, Zone 2 oder regenerative Einheit statt schwerer Belastung.",
          accent: GainsColor.ember
        ))
      } else if hrvNumber >= 70 {
        list.append(CoachInsight(
          icon: "waveform.path.ecg",
          text: "HRV \(hrvNumber) ms — Erholung offen. Heute kannst du beim Hauptlift anziehen, ohne ins Risiko zu gehen.",
          accent: GainsColor.lime
        ))
      }
    }

    if let sleep = vitalValue(named: "Schlaf"), let sleepHours = parseSleepHours(sleep.value) {
      if sleepHours < 6.5 {
        list.append(CoachInsight(
          icon: "moon.zzz.fill",
          text: String(format: "Nur %.1f h Schlaf. Cap die Trainingsintensität bei RPE 7 und schiebe Top-Sets, wenn nötig, einen Tag.", sleepHours),
          accent: GainsColor.ember
        ))
      }
    }

    for goal in store.currentGoals {
      let progress = goalProgressLocal(goal)
      let trimmedGoalTitle = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
      if progress >= 0.85 && progress < 1.0 {
        list.append(CoachInsight(
          icon: "scope",
          text: "\(trimmedGoalTitle.isEmpty ? "Ziel" : trimmedGoalTitle) liegt bei \(Int(progress * 100)) %. Letzte Meile — kein Sprint, einfach den Plan zu Ende fahren.",
          accent: GainsColor.lime
        ))
        break
      }
    }

    return list
  }

  private func vitalValue(named name: String) -> VitalReading? {
    store.currentVitalReadings.first(where: { $0.title.localizedCaseInsensitiveContains(name) })
  }

  private func parseInt(_ text: String) -> Int? {
    let digits = text.filter { $0.isNumber }
    return Int(digits)
  }

  private func parseSleepHours(_ text: String) -> Double? {
    if let hh = Double(text.replacingOccurrences(of: "h", with: "").trimmingCharacters(in: .whitespaces)) {
      return hh
    }
    let parts = text.split(separator: ":")
    if parts.count == 2,
       let h = Double(parts[0]),
       let m = Double(parts[1]) {
      return h + m / 60.0
    }
    return nil
  }

  // MARK: - 3. Readiness-Row (kompakt, 4 Mini-Zellen)

  @ViewBuilder
  private var readinessRow: some View {
    let vitals = readinessQuickVitals
    if !vitals.isEmpty {
      VStack(alignment: .leading, spacing: GainsSpacing.tight) {
        SlashLabel(
          parts: ["READINESS", "HEUTE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        HStack(spacing: GainsSpacing.xsPlus) {
          ForEach(vitals.prefix(4)) { vital in
            readinessCell(vital)
          }
        }

        if !store.hasConnectedAppleHealth {
          Button { store.syncVitalData() } label: {
            HStack(spacing: GainsSpacing.xsPlus) {
              Image(systemName: "heart.text.square.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GainsColor.lime)
              Text("Apple Health verbinden für Live-HRV/Schlaf")
                .font(GainsFont.label(11))
                .tracking(0.6)
                .foregroundStyle(GainsColor.softInk)
                .lineLimit(2)
              Spacer()
              Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(GainsColor.border)
            }
            .padding(.horizontal, GainsSpacing.s)
            .frame(minHeight: 36)
            .background(GainsColor.card)
            .overlay(
              RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          }
          .buttonStyle(.plain)
          .contentShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          .accessibilityLabel("Apple Health für Readiness verbinden")
          .accessibilityValue("HRV- und Schlafdaten für deine Readiness aktivieren")
          .accessibilityHint("Verbindet Apple Health und startet den Datenabgleich für HRV und Schlaf")
        }
      }
    }
  }

  private var readinessQuickVitals: [VitalReading] {
    let preferred = ["HRV", "Schlaf", "Ruhepuls", "VO2max"]
    var picked: [VitalReading] = []
    for name in preferred {
      if let v = store.currentVitalReadings.first(where: { $0.title == name }) {
        picked.append(v)
      }
    }
    if picked.count < 4 {
      for v in store.currentVitalReadings where !picked.contains(where: { $0.id == v.id }) {
        picked.append(v)
        if picked.count >= 4 { break }
      }
    }
    return picked
  }

  private func readinessCell(_ vital: VitalReading) -> some View {
    let trimmedTitle = vital.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedValue = vital.value.trimmingCharacters(in: .whitespacesAndNewlines)

    Button { store.syncVitalData() } label: {
      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text((trimmedTitle.isEmpty ? "Readiness" : trimmedTitle).uppercased())
          .font(GainsFont.label(8))
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
        Text(trimmedValue.isEmpty || trimmedValue == "—" ? "Noch keine Daten" : trimmedValue)
          .font(GainsFont.metricSmall)
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
          .minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, GainsSpacing.tight)
      .padding(.vertical, GainsSpacing.tight)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
    .contentShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .accessibilityLabel("Readiness-Wert \(trimmedTitle.isEmpty ? "Readiness" : trimmedTitle)")
    .accessibilityValue({
      let trimmedValue = vital.value.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmedValue.isEmpty || trimmedValue == "—" ? "Noch keine Daten" : trimmedValue
    }())
    .accessibilityHint(
      store.hasConnectedAppleHealth
        ? "Doppeltippen, um \(trimmedTitle.isEmpty ? "deine Readiness" : trimmedTitle) für deine Readiness zu aktualisieren"
        : "Doppeltippen, um Apple Health zu verbinden und \(trimmedTitle.isEmpty ? "deine Readiness" : trimmedTitle) für deine Readiness zu laden"
    )
  }

  // MARK: - 4. Pulse-Strip (Wochen-Snapshot in 4 Zellen)

  private var pulseStrip: some View {
    HStack(spacing: GainsSpacing.xsPlus) {
      pulseCell(
        ringValue: store.weeklyGoalCount > 0 ? weekProgress : nil,
        icon: store.weeklyGoalCount == 0 ? "calendar.badge.exclamationmark" : nil,
        title: "PLAN",
        value: store.weeklyGoalCount > 0
          ? "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)"
          : "—",
        accent: store.weeklyGoalCount > 0 ? GainsColor.lime : GainsColor.softInk,
        accessibilityLabel: "Wochenplan",
        accessibilityValue: store.weeklyGoalCount > 0
          ? "\(store.weeklySessionsCompleted) von \(store.weeklyGoalCount) \(store.weeklyGoalCount == 1 ? "Einheit" : "Einheiten") geschafft"
          : "Noch kein Wochenziel gesetzt",
        accessibilityHint: store.weeklyGoalCount > 0
          ? "Zeigt deinen Fortschritt im Wochenplan"
          : "Zeigt, dass noch kein Wochenziel gesetzt ist"
      )
      pulseCell(
        icon: store.streakDays >= 7 ? "flame.fill" : "flame",
        title: "STREAK",
        value: "\(store.streakDays) T",
        accent: store.streakDays >= 3 ? GainsColor.lime : GainsColor.softInk,
        accessibilityLabel: "Aktivitätsserie",
        accessibilityValue: store.streakDays > 1
          ? "\(store.streakDays) Tage in Folge aktiv"
          : store.streakDays == 1
            ? "1 Tag in Folge aktiv"
            : "Noch keine aktive Serie",
        accessibilityHint: store.streakDays > 1
          ? "Zeigt deine aktuelle Aktivitätsserie"
          : store.streakDays == 1
            ? "Zeigt, dass du aktuell seit einem Tag aktiv bist"
            : "Zeigt, dass aktuell noch keine Aktivitätsserie läuft"
      )
      pulseCell(
        icon: "chart.bar.fill",
        title: "VOL/W",
        value: store.weeklyVolumeTons > 0 ? String(format: "%.1f t", store.weeklyVolumeTons) : "ohne Volumenangabe",
        accent: GainsColor.lime,
        accessibilityLabel: "Wochenvolumen",
        accessibilityValue: store.weeklyVolumeTons > 0
          ? String(format: "%.1f Tonnen diese Woche", store.weeklyVolumeTons)
          : "Noch kein Trainingsvolumen diese Woche",
        accessibilityHint: store.weeklyVolumeTons > 0
          ? "Zeigt dein gesamtes Trainingsvolumen dieser Woche"
          : "Zeigt, dass diese Woche noch kein Trainingsvolumen erfasst wurde"
      )
      pulseCell(
        icon: "bolt.fill",
        title: "PR",
        value: "\(store.personalRecordCount)",
        accent: store.personalRecordCount > 0 ? GainsColor.lime : GainsColor.softInk,
        accessibilityLabel: "Persönliche Rekorde",
        accessibilityValue: store.personalRecordCount > 1
          ? "\(store.personalRecordCount) persönliche Rekorde"
          : store.personalRecordCount == 1
            ? "1 persönlicher Rekord"
            : "Noch kein persönlicher Rekord diese Woche",
        accessibilityHint: store.personalRecordCount > 1
          ? "Zeigt deine persönlichen Rekorde dieser Woche"
          : store.personalRecordCount == 1
            ? "Zeigt deinen persönlichen Rekord dieser Woche"
            : "Zeigt, dass diese Woche noch kein persönlicher Rekord gesetzt wurde"
      )
    }
  }

  private func pulseCell(
    ringValue: Double? = nil,
    icon: String? = nil,
    title: String,
    value: String,
    accent: Color,
    accessibilityLabel: String,
    accessibilityValue: String,
    accessibilityHint: String
  ) -> some View {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      HStack {
        if let ring = ringValue {
          ZStack {
            Circle()
              .stroke(GainsColor.border.opacity(0.6), lineWidth: 2)
            Circle()
              .trim(from: 0, to: ring)
              .stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
              .rotationEffect(.degrees(-90))
          }
          .frame(width: 16, height: 16)
        } else if let icon = icon {
          Image(systemName: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(accent)
        }

        Spacer()
      }

      Text(trimmedValue.isEmpty ? "—" : trimmedValue)
        .font(GainsFont.metricSmall)
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)
        .minimumScaleFactor(0.7)

      Text(trimmedTitle.isEmpty ? "Status" : trimmedTitle)
        .font(GainsFont.label(8))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, GainsSpacing.s)
    .padding(.vertical, GainsSpacing.s)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(accessibilityValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Noch keine Daten" : accessibilityValue)
    .accessibilityHint(accessibilityHint)
  }

  // MARK: - 4b. 365-Tage-Aktivitäts-Grid (Brand-Loop 7, 2026-05-14)
  //
  // GitHub-Commit-Heatmap, aber für Gains: pro Tag ein Quadrat, Intensität
  // nach Anzahl Workouts/Läufe an dem Tag. 7 Zeilen (Mo-So) × ~53 Spalten
  // (Wochen, älteste links → heute rechts). Tap-frei, rein visuelles Asset
  // — die emotionale Aussage ist „so oft warst du dran, schau die Linie an".
  //
  // Why: User-Feedback aus dem Brand-Re-Alignment-Loop „Streak ist das
  // emotionale Zentrum". Ein einzelner Streak-Zähler bleibt abstrakt — die
  // Heatmap macht Konsistenz, Pausen, Comebacks sofort lesbar.

  private var yearActivityGrid: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["365", "TAGE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text(yearActivityDays.totalActiveDays == 1 ? "1 Tag aktiv" : "\(yearActivityDays.totalActiveDays) Tage aktiv")
          .font(GainsFont.label(10))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
      }

      yearActivityGridBody

      HStack(spacing: GainsSpacing.xs) {
        Text("WENIGER")
          .font(GainsFont.label(8))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
        ForEach(0..<4) { level in
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(yearActivityColor(for: level))
            .frame(width: 10, height: 10)
        }
        Text("MEHR")
          .font(GainsFont.label(8))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle(GainsColor.card)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("365 Tage Aktivität")
    .accessibilityValue(yearActivityDays.totalActiveDays == 0 ? "Noch keine Aktivität in den letzten 365 Tagen" : yearActivityDays.totalActiveDays == 1 ? "1 Tag aktiv in den letzten 365 Tagen" : "\(yearActivityDays.totalActiveDays) Tage aktiv in den letzten 365 Tagen")
    .accessibilityHint("Zeigt eine Aktivitätsübersicht der letzten 365 Tage, von weniger bis mehr Aktivität")
  }

  private var yearActivityGridBody: some View {
    let cellSize: CGFloat = 9
    let cellSpacing: CGFloat = 2
    let dayLevels = yearActivityDays
    return ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        // Polish-Loop 198 (2026-05-14): 365-Tage-Grid-Zellen mit
        // plusLighter Inner-Light + Lime-Glow auf hohen Aktivitäts-
        // Levels (level 3) — wirkt wie LED-Map statt flacher Heatmap.
        HStack(alignment: .top, spacing: cellSpacing) {
          ForEach(0..<dayLevels.weeks.count, id: \.self) { weekIdx in
            VStack(spacing: cellSpacing) {
              ForEach(0..<7, id: \.self) { rowIdx in
                if let level = dayLevels.weeks[weekIdx][rowIdx] {
                  ZStack {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                      .fill(yearActivityColor(for: level))
                    if level > 0 {
                      RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                          LinearGradient(
                            colors: [
                              Color.white.opacity(level == 3 ? 0.16 : 0.05),
                              Color.white.opacity(0.00)
                            ],
                            startPoint: .top,
                            endPoint: .center
                          )
                        )
                        .blendMode(.plusLighter)
                    }
                  }
                  .frame(width: cellSize, height: cellSize)
                  // Fix 2026-05-16: Per-Zelle-Shadow entfernt — bei ~370 Zellen
                  // erzeugt jeder .shadow einen eigenen Compositing-Pass (GPU-Spike).
                  // Glow wird über drawingGroup() auf der ganzen HStack gelöst.
                } else {
                  // Slot vor dem 365-Tage-Window (kein Datum) — transparent
                  Color.clear.frame(width: cellSize, height: cellSize)
                }
              }
            }
            .id(weekIdx)
          }
        }
        // drawingGroup() flattet alle ~370 Zellen in eine einzige Metal-Textur —
        // eliminiert O(n) Shadow-Compositing-Pässe bei aktiven Tagen.
        .drawingGroup()
        .padding(.trailing, 2)
      }
      .frame(height: 7 * cellSize + 6 * cellSpacing)
      // Auto-Scroll an den rechten Rand (heute) beim ersten Layout, sodass
      // der User mit der aktuellen Woche startet statt vor 12 Monaten.
      .onAppear {
        guard !dayLevels.weeks.isEmpty else { return }
        proxy.scrollTo(dayLevels.weeks.count - 1, anchor: .trailing)
      }
      .accessibilityHidden(true)
    }
  }

  /// Delegiert an den gecachten Store-Property (O(1) nach erstem Render).
  private var yearActivityDays: YearActivityData { store.yearActivityData }

  private func yearActivityColor(for level: Int) -> Color {
    switch level {
    case 0:  return GainsColor.card.opacity(0.9)
    case 1:  return GainsColor.lime.opacity(0.32)
    case 2:  return GainsColor.lime.opacity(0.62)
    default: return GainsColor.lime
    }
  }

  // MARK: - 5. Drei Story-Karten (Stärke / Körper / Cardio)

  private var storyCardsBlock: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["STORY", "DEEP DIVE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(spacing: GainsSpacing.s) {
        strengthStoryCard
        bodyStoryCard
        cardioStoryCard
      }
    }
  }

  // ---- Stärke ----

  @ViewBuilder
  private var strengthStoryCard: some View {
    let topExercise = store.exerciseStrengthProgress.first
    let volumes = Array(store.workoutHistory.prefix(6).map(\.volume).reversed())

    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text("STÄRKE")
            .font(GainsFont.label(9))
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.lime)
          Text(topExercise?.exerciseName ?? "Top-Übung")
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)
        }
        Spacer()
        if let ex = topExercise {
          VStack(alignment: .trailing, spacing: 2) {
            Text(ex.currentValue)
              .font(GainsFont.metric)
              .foregroundStyle(GainsColor.ink)
            Text(ex.deltaLabel)
              .font(GainsFont.label(9))
              .tracking(GainsTracking.eyebrowTight)
              .foregroundStyle(GainsColor.lime)
          }
        }
      }

      if !volumes.isEmpty {
        volumeSparkline(values: volumes)
      } else {
        emptyHint("Sobald du Workouts loggst, erscheint dein Volumenverlauf hier.")
      }

      if store.exerciseStrengthProgress.count > 1 {
        VStack(spacing: GainsSpacing.xsPlus) {
          ForEach(Array(store.exerciseStrengthProgress.dropFirst().prefix(3))) { ex in
            HStack {
              Text(ex.exerciseName)
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
                .lineLimit(2)
              Spacer()
              Text(ex.currentValue)
                .font(GainsFont.label(11))
                .foregroundStyle(GainsColor.ink)
              Text(ex.deltaLabel)
                .font(GainsFont.label(9))
                .tracking(1.0)
                .foregroundStyle(ex.deltaLabel.contains("+") ? GainsColor.lime : GainsColor.softInk)
                .frame(minWidth: 50, alignment: .trailing)
            }
          }
        }
        .padding(.top, GainsSpacing.xxs)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
    .accessibilityElement(children: .combine)
    .accessibilityLabel(topExercise.map { "Krafttraining, \($0.exerciseName)" } ?? "Krafttraining")
    .accessibilityValue(
      topExercise.map {
        let currentValue = $0.currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let deltaLabel = $0.deltaLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentValue.isEmpty {
          return deltaLabel.isEmpty ? "Führende Übung" : "Führende Übung, \(deltaLabel)"
        }
        return deltaLabel.isEmpty ? "Führende Übung, \(currentValue)" : "Führende Übung, \(currentValue), \(deltaLabel)"
      } ?? "Noch keine Krafttraining-Daten"
    )
    .accessibilityHint(topExercise == nil ? "Zeigt, dass noch keine Krafttraining-Daten vorliegen und nach deinen ersten Sessions hier Fortschritt erscheint" : "Öffnet deinen Kraftfortschritt mit weiteren Details zu dieser führenden Übung")
  }

  private func volumeSparkline(values: [Double]) -> some View {
    // B5: Vorher flache Lime/Elevated-Bars. Jetzt GainsSparklineBar mit
    // Gradient-Fills, Average-Linie, Min/Max-Markern und Trend-Indikator.
    GainsSparklineBar(
      values: values,
      accent: GainsColor.lime,
      height: 56
    )
  }

  // ---- Körper ----

  private var bodyStoryCard: some View {
    let latest = store.weightTrend.last?.value ?? store.currentWeight
    let first  = store.weightTrend.first?.value ?? latest
    let delta  = latest - first

    return VStack(alignment: .leading, spacing: GainsSpacing.m) {
      Button { store.logWeightCheckIn() } label: {
        VStack(alignment: .leading, spacing: GainsSpacing.m) {
          HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
              Text("KÖRPER")
                .font(GainsFont.label(9))
                .tracking(GainsTracking.eyebrowWide)
                .foregroundStyle(GainsColor.accentCool)
              Text("Gewicht")
                .font(GainsFont.title(20))
                .foregroundStyle(GainsColor.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
              Text(String(format: "%.1f kg", latest))
                .font(GainsFont.metric)
                .foregroundStyle(GainsColor.ink)
              Text(deltaLabel(delta))
                .font(GainsFont.label(9))
                .tracking(GainsTracking.eyebrowTight)
                .foregroundStyle(delta <= 0 ? GainsColor.accentCool : GainsColor.ember)
            }
          }

          if store.weightTrend.count >= 2 {
            weightSparkline
          } else {
            emptyHint("Logge dein Gewicht regelmäßig — die Linie braucht mindestens zwei Punkte.")
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Körper, Gewicht")
      .accessibilityValue(
        store.weightTrend.count >= 2
          ? "\(String(format: "%.1f Kilogramm", latest)), \(spokenWeightDeltaLabel(delta))"
          : latest > 0
            ? "\(String(format: "%.1f Kilogramm", latest)), noch kein Gewichtstrend"
            : "Noch kein Gewichtseintrag"
      )
      .accessibilityHint(
        store.weightTrend.count >= 2
          ? "Öffnet den Check-in für dein Gewicht"
          : latest > 0
            ? "Öffnet den Check-in, damit du deinen Gewichtstrend weiter aufbauen kannst"
            : "Öffnet den Check-in, damit du deinen Startwert bestätigen und deinen Gewichtstrend aufbauen kannst"
      )

      Button { store.logWaistCheckIn() } label: {
        HStack(spacing: GainsSpacing.tight) {
          Image(systemName: "ruler.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.accentCool)
          Text("Taille \(String(format: "%.1f cm", store.waistMeasurement))")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
          Spacer()
          Text(waistDeltaText)
            .font(GainsFont.label(9))
            .tracking(GainsTracking.eyebrowTight)
            .foregroundStyle(GainsColor.softInk)
          Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(GainsColor.border)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Körper, Taille")
      .accessibilityValue(abs(store.startingWaist - store.waistMeasurement) < 0.05 ? "\(String(format: "%.1f Zentimeter", store.waistMeasurement)), noch kein Taillenverlauf" : "\(String(format: "%.1f Zentimeter", store.waistMeasurement)), \(waistDeltaText)")
      .accessibilityHint(abs(store.startingWaist - store.waistMeasurement) < 0.05 ? (store.waistMeasurement > 0 ? "Öffnet den Check-in, damit du deinen Taillenverlauf weiter aufbauen kannst" : "Öffnet den Check-in, damit du deinen Taillenverlauf aufbauen kannst") : "Öffnet den Check-in für deine Taille")
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
    .contentShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private var weightSparkline: some View {
    // B5: GainsSparklineLine mit Average-Linie, Min/Max-Markern und Latest-
    // Halo. Optisch identisch zur alten Implementierung an den Hauptpunkten,
    // ergänzt durch die neuen Annotations.
    let mapped = store.weightTrend.enumerated().map { idx, point in
      GainsSparklineLine.Point(id: AnyHashable(idx), value: point.value)
    }
    return GainsSparklineLine(
      points: mapped,
      accent: GainsColor.accentCool,
      height: 60
    )
  }

  // ---- Cardio ----

  @ViewBuilder
  private var cardioStoryCard: some View {
    let latest = store.runHistory.first
    let recent = Array(store.runHistory.prefix(7).reversed())

    Button {
      if store.activeWorkout != nil {
        isShowingWorkoutTracker = true
      } else if store.activeRun != nil {
        isShowingRunTracker = true
      } else {
        dismiss()
        navigation.openTraining(workspace: .laufen)
      }
    } label: {
      let trimmedLatestTitle = latest?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

      VStack(alignment: .leading, spacing: GainsSpacing.m) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
            Text("CARDIO")
              .font(GainsFont.label(9))
              .tracking(GainsTracking.eyebrowWide)
              .foregroundStyle(GainsColor.ember)
            Text(trimmedLatestTitle.isEmpty ? "Letzte Session" : trimmedLatestTitle)
              .font(GainsFont.title(20))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(2)
          }
          Spacer()
          if let r = latest {
            VStack(alignment: .trailing, spacing: 2) {
              Text(String(format: "%.1f km", r.distanceKm))
                .font(GainsFont.metric)
                .foregroundStyle(GainsColor.ink)
              Text(r.averagePaceSeconds > 0 ? paceLabel(r.averagePaceSeconds) : "ohne Paceangabe")
                .font(GainsFont.label(9))
                .tracking(GainsTracking.eyebrowTight)
                .foregroundStyle(GainsColor.ember)
            }
          }
        }

        if recent.count >= 1 {
          cardioDistanceSparkline(values: recent.map(\.distanceKm))
        } else {
          emptyHint("Sobald du Cardio loggst, erscheint dein Distanz-Verlauf hier.")
        }

        if let r = latest {
          HStack(spacing: GainsSpacing.s) {
            Label(r.averageHeartRate > 0 ? "\(r.averageHeartRate) bpm" : "ohne Herzfrequenzdaten", systemImage: "heart.fill")
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.softInk)
            Label("\(r.durationMinutes) min", systemImage: "clock")
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.softInk)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(GainsColor.border)
          }
        }
      }
      .padding(GainsSpacing.m)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
    .contentShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .accessibilityLabel(
      latest.map {
        let title = $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Lauftraining" : "Lauftraining, \(title)"
      } ?? "Lauftraining"
    )
    .accessibilityValue(latest.map {
      let minutesLabel = $0.durationMinutes == 1 ? "1 Minute" : "\($0.durationMinutes) Minuten"
      let heartRateLabel = $0.averageHeartRate > 0 ? "\($0.averageHeartRate) bpm" : "ohne Herzfrequenzdaten"
      let paceLabel = $0.averagePaceSeconds > 0 ? spokenPaceLabel($0.averagePaceSeconds) : "ohne Paceangabe"
      return String(format: "%.1f Kilometer, %@, %@, %@", $0.distanceKm, minutesLabel, paceLabel, heartRateLabel)
    } ?? "Noch kein Lauftraining geloggt")
    .accessibilityHint(latest == nil ? "Schließt den Fortschritt und öffnet den Laufbereich für dein erstes Cardio-Training" : "Schließt den Fortschritt und öffnet den Lauftraining-Bereich für weitere Details zu dieser letzten Cardio-Einheit")
  }

  private func cardioDistanceSparkline(values: [Double]) -> some View {
    // B5: Ember-Variante der GainsSparklineBar — gleiches Vokabular wie der
    // Volumen-Chart, nur in der Cardio-Akzentfarbe.
    GainsSparklineBar(
      values: values,
      accent: GainsColor.ember,
      height: 48
    )
  }

  // MARK: - 6. Ziele (kompakt, 1 Zeile pro Ziel)

  @ViewBuilder
  private var goalsSection: some View {
    if !store.currentGoals.isEmpty {
      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        SlashLabel(
          parts: ["ZIELE", "AKTIV"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        VStack(spacing: GainsSpacing.xsPlus) {
          ForEach(store.currentGoals) { goal in
            goalCompactRow(goal)
          }
        }
      }
    }
  }

  private func goalCompactRow(_ goal: ProgressGoal) -> some View {
    let progress = goalProgressLocal(goal)
    let isDone = progress >= 1.0

    let trimmedTitle = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedUnit = goal.unit.trimmingCharacters(in: .whitespacesAndNewlines)

    return Button { goalAction(for: goal)() } label: {
      VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
        HStack(alignment: .firstTextBaseline, spacing: GainsSpacing.tight) {
          Text(trimmedTitle.isEmpty ? "Ziel" : trimmedTitle)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
          Spacer()
          Text(trimmedUnit.isEmpty ? String(format: "%.0f / %.0f", goal.current, goal.target) : String(format: "%.0f / %.0f %@", goal.current, goal.target, trimmedUnit))
            .font(GainsFont.label(10))
            .tracking(0.6)
            .foregroundStyle(GainsColor.softInk)
          Text(isDone ? "✓" : "\(Int(progress * 100))%")
            .font(GainsFont.label(10))
            .tracking(1.0)
            .foregroundStyle(isDone ? GainsColor.moss : GainsColor.lime)
            .frame(minWidth: 30, alignment: .trailing)
        }
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(GainsColor.border.opacity(0.4))
              .frame(height: 4)
            Capsule()
              .fill(isDone ? GainsColor.moss : GainsColor.lime)
              .frame(width: proxy.size.width * progress, height: 4)
              .animation(.easeOut(duration: 0.5), value: progress)
          }
        }
        .frame(height: 4)
      }
      .padding(.horizontal, GainsSpacing.m)
      .padding(.vertical, GainsSpacing.s)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Ziel, \(trimmedTitle.isEmpty ? "Ziel" : trimmedTitle)")
    .accessibilityValue(
      goal.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? String(
            format: "%.0f von %.0f, %@",
            goal.current,
            goal.target,
            isDone ? "erreicht" : "\(Int(progress * 100)) Prozent"
          )
        : String(
            format: "%.0f von %.0f %@, %@",
            goal.current,
            goal.target,
            goal.unit,
            isDone ? "erreicht" : "\(Int(progress * 100)) Prozent"
          )
    )
    .accessibilityHint(
      trimmedTitle == "Körpergewicht"
        ? (isDone ? "Öffnet den Gewichts-Check-in, um dein erreichtes Ziel weiter zu pflegen" : "Öffnet den Check-in für dein Gewicht")
        : trimmedTitle == "Taillenumfang"
          ? (isDone ? "Öffnet den Taillen-Check-in, um dein erreichtes Ziel weiter zu pflegen" : "Öffnet den Check-in für deine Taille")
          : (isDone ? "Öffnet den Protein-Check-in, um dein erreichtes Ziel weiter zu pflegen" : "Öffnet den Check-in für dein Protein-Ziel")
    )
  }

  // MARK: - 7. Highlights (PRs + Milestones merged, kompakte Timeline)

  @ViewBuilder
  private var highlightsSection: some View {
    let highlights = mergedHighlights
    if !highlights.isEmpty {
      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        SlashLabel(
          parts: ["HIGH", "LIGHTS"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(highlights.prefix(5).enumerated()), id: \.element.id) { index, h in
            highlightRow(h, isLast: index == min(highlights.count, 5) - 1)
          }
        }
        .padding(GainsSpacing.m)
        .gainsCardStyle()
      }
    }
  }

  private var mergedHighlights: [HighlightEntry] {
    var entries: [HighlightEntry] = []

    if store.streakDays >= 7 {
      entries.append(HighlightEntry(
        kind: .streak,
        title: "\(store.streakDays)-Tage-Streak",
        detail: "Routine läuft am Stück durch.",
        date: Date(),
        dateLabel: "aktiv"
      ))
    }

    if let longest = store.runHistory.max(by: { $0.distanceKm < $1.distanceKm }) {
      let longestPaceDetail = longest.averagePaceSeconds > 0 ? paceLabel(longest.averagePaceSeconds) : "ohne Paceangabe"
      let longestHeartRateDetail = longest.averageHeartRate > 0 ? "\(longest.averageHeartRate) bpm" : "ohne Herzfrequenzdaten"
      entries.append(HighlightEntry(
        kind: .run,
        title: String(format: "%.1f km längster Lauf", longest.distanceKm),
        detail: "\(longestPaceDetail) · \(longestHeartRateDetail)",
        date: longest.finishedAt,
        dateLabel: longest.finishedAt.formatted(.dateTime.day().month())
      ))
    }

    if let prExercise = store.exerciseStrengthProgress.first(where: { $0.deltaLabel.contains("+") }) {
      let date = store.workoutHistory
        .first(where: { $0.exercises.contains(where: { $0.name == prExercise.exerciseName }) })?
        .finishedAt ?? Date()
      entries.append(HighlightEntry(
        kind: .personalRecord,
        title: "\(prExercise.exerciseName) PR",
        detail: "\(prExercise.currentValue) · \(prExercise.deltaLabel)",
        date: date,
        dateLabel: date.formatted(.dateTime.day().month())
      ))
    }

    for m in store.currentMilestones.prefix(4) {
      entries.append(HighlightEntry(
        kind: .milestone,
        title: m.title,
        detail: m.detail,
        date: Date(),
        dateLabel: m.dateLabel
      ))
    }

    return entries.sorted { $0.date > $1.date }
  }

  private func highlightRow(_ h: HighlightEntry, isLast: Bool) -> some View {
    HStack(alignment: .top, spacing: GainsSpacing.m) {
      VStack(spacing: 0) {
        ZStack {
          Circle()
            .fill(highlightColor(h.kind).opacity(0.18))
            .frame(width: 28, height: 28)
          Image(systemName: highlightIcon(h.kind))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(highlightColor(h.kind))
        }
        if !isLast {
          Rectangle()
            .fill(GainsColor.border.opacity(0.4))
            .frame(width: 2)
            .frame(maxHeight: .infinity)
            .padding(.vertical, GainsSpacing.xxs)
        }
      }
      .frame(width: 28)

      let trimmedTitle = h.title.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedDetail = h.detail.trimmingCharacters(in: .whitespacesAndNewlines)

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        HStack {
          Text(trimmedTitle.isEmpty ? "Highlight" : trimmedTitle)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
          Spacer()
          Text(h.dateLabel)
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(GainsColor.softInk)
        }
        if !trimmedDetail.isEmpty {
          Text(trimmedDetail)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }
      }
      .padding(.bottom, isLast ? 0 : 14)
    }
  }

  private func highlightIcon(_ kind: HighlightKind) -> String {
    switch kind {
    case .personalRecord: return "bolt.fill"
    case .milestone:      return "checkmark.seal.fill"
    case .streak:         return "flame.fill"
    case .run:            return "figure.run"
    }
  }

  private func highlightColor(_ kind: HighlightKind) -> Color {
    switch kind {
    case .personalRecord, .milestone, .streak: return GainsColor.lime
    case .run:                                 return GainsColor.accentCool
    }
  }

  // MARK: - 8. Verlauf (kompakt)

  @ViewBuilder
  private var historySection: some View {
    let merged = mergedHistory(filter: historyFilter, limit: 5)
    if !merged.isEmpty || !store.workoutHistory.isEmpty || !store.runHistory.isEmpty {
      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        HStack {
          SlashLabel(
            parts: ["VERLAUF"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )
          Spacer()
          HStack(spacing: GainsSpacing.xs) {
            ForEach(HistoryFilter.allCases) { filter in
              let trimmedFilterLabel = filter.label.trimmingCharacters(in: .whitespacesAndNewlines)
              Button {
                withAnimation(.easeInOut(duration: 0.15)) { historyFilter = filter }
              } label: {
                Text(trimmedFilterLabel.isEmpty ? "Filter" : trimmedFilterLabel)
                  .font(GainsFont.label(9))
                  .tracking(1.0)
                  .foregroundStyle(historyFilter == filter ? GainsColor.onLime : GainsColor.softInk)
                  .padding(.horizontal, GainsSpacing.tight)
                  .frame(minHeight: 24)
                  .background(historyFilter == filter ? GainsColor.lime : GainsColor.card)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
              .accessibilityLabel(filter == .strength ? "Verlaufsfilter Krafttraining" : filter == .cardio ? "Verlaufsfilter Laufen" : "Verlaufsfilter alle Aktivitäten")
              .accessibilityValue(historyFilter == filter ? "Ausgewählt" : "Nicht ausgewählt")
              .accessibilityHint(historyFilter == filter ? "Dieser Filter ist bereits aktiv" : historyFilterAccessibilityHint(filter))
              .accessibilityAddTraits(historyFilter == filter ? .isSelected : [])
              .disabled(historyFilter == filter)
            }
          }
        }

        if merged.isEmpty {
          EmptyStateView(
            style: .inline,
            title: emptyHistoryTitle,
            message: emptyHistoryMessage,
            icon: "clock.arrow.circlepath"
          )
        } else {
          VStack(spacing: GainsSpacing.xs) {
            ForEach(merged.prefix(5)) { entry in
              historyRowCompact(entry)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  private func historyRowCompact(_ entry: HistoryEntry) -> some View {
    Button {
      dismiss()
      switch entry {
      case .workout: navigation.openTraining(workspace: .kraft)
      case .run:     navigation.openTraining(workspace: .laufen)
      }
    } label: {
      HStack(spacing: GainsSpacing.s) {
        Image(systemName: historyIcon(entry))
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(historyAccent(entry))
          .frame(width: 24, height: 24)
          .background(historyAccent(entry).opacity(0.14))
          .clipShape(Circle())

        let trimmedSubtitle = historySubtitle(entry).trimmingCharacters(in: .whitespacesAndNewlines)

        VStack(alignment: .leading, spacing: 1) {
          Text(historyTitle(entry))
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
          Text(trimmedSubtitle.isEmpty ? "ohne Detailangabe" : trimmedSubtitle)
            .font(GainsFont.label(9))
            .tracking(0.6)
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }

        Spacer()

        Text(entry.date.formatted(.dateTime.day().month()))
          .font(GainsFont.label(10))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)

        Image(systemName: "chevron.right")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(GainsColor.border)
      }
      .padding(.horizontal, GainsSpacing.s)
      .padding(.vertical, GainsSpacing.tight)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
    .contentShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .accessibilityLabel(historyAccessibilityLabel(entry))
    .accessibilityValue(historyAccessibilityValue(entry))
    .accessibilityHint(entryHistoryAccessibilityHint(entry))
  }

  private func historyIcon(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout: return "dumbbell.fill"
    case .run:     return "figure.run"
    }
  }

  private func historyAccent(_ entry: HistoryEntry) -> Color {
    switch entry {
    case .workout: return GainsColor.lime
    case .run:     return GainsColor.accentCool
    }
  }

  private func historyFilterAccessibilityHint(_ filter: HistoryFilter) -> String {
    switch filter {
    case .all:
      return "Filtert den Verlauf auf alle Aktivitäten"
    case .strength:
      return "Filtert den Verlauf auf Krafttraining"
    case .cardio:
      return "Filtert den Verlauf auf Lauftraining"
    }
  }

  private var emptyHistoryTitle: String {
    switch historyFilter {
    case .all:
      return "Noch kein Training"
    case .strength:
      return "Noch kein Krafttraining"
    case .cardio:
      return "Noch kein Lauftraining"
    }
  }

  private var emptyHistoryMessage: String {
    switch historyFilter {
    case .all:
      return "Sobald du Kraft- oder Lauftrainings abschließt, sammeln sich hier deine letzten Aktivitäten."
    case .strength:
      return "Sobald du ein Krafttraining abschließt, erscheint es hier in deinem Verlauf."
    case .cardio:
      return "Sobald du ein Lauftraining abschließt, erscheint es hier in deinem Verlauf."
    }
  }

  private func historyAccessibilityLabel(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout(let w):
      let title = w.title.trimmingCharacters(in: .whitespacesAndNewlines)
      return "Krafttraining, \(title.isEmpty ? "Training" : title)"
    case .run(let r):
      let title = r.title.trimmingCharacters(in: .whitespacesAndNewlines)
      return "Lauftraining, \(title.isEmpty ? "Lauftraining" : title)"
    }
  }

  private func historyAccessibilityValue(_ entry: HistoryEntry) -> String {
    let date = entry.date.formatted(.dateTime.day().month())
    switch entry {
    case .workout(let w):
      let setLabel = w.completedSets == 1 ? "1 Satz" : "\(w.completedSets) Sätze"
      let completion = w.totalSets > 0 ? Int((Double(w.completedSets) / Double(w.totalSets)) * 100) : 0
      let volumeLabel = w.volume > 0 ? String(format: "Volumen %.1f Tonnen", w.volume / 1000) : "ohne Volumenangabe"
      return "\(volumeLabel), \(setLabel), \(completion) Prozent abgeschlossen, am \(date)"
    case .run(let r):
      let minutesLabel = r.durationMinutes == 1 ? "1 Minute" : "\(r.durationMinutes) Minuten"
      let paceLabel = r.averagePaceSeconds > 0 ? "Pace \(spokenPaceLabel(r.averagePaceSeconds))" : "ohne Paceangabe"
      return "\(String(format: "%.1f Kilometer", r.distanceKm)), \(minutesLabel), \(paceLabel), am \(date)"
    }
  }

  private func historyTitle(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout(let w):
      let title = w.title.trimmingCharacters(in: .whitespacesAndNewlines)
      return title.isEmpty ? "Training" : title
    case .run(let r):
      let title = r.title.trimmingCharacters(in: .whitespacesAndNewlines)
      return title.isEmpty ? "Lauftraining" : title
    }
  }

  private func historySubtitle(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout(let w):
      let setLabel = w.completedSets == 1 ? "1 Satz" : "\(w.completedSets) Sätze"
      return w.volume > 0
        ? String(format: "%.1f t · %@", w.volume / 1000, setLabel)
        : "ohne Volumenangabe · \(setLabel)"
    case .run(let r):
      let pace = r.averagePaceSeconds > 0 ? paceLabel(r.averagePaceSeconds) : "ohne Paceangabe"
      return "\(String(format: "%.1f km", r.distanceKm)) · \(pace)"
    }
  }

  private func entryHistoryAccessibilityHint(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout:
      return "Schließt den Fortschritt und öffnet den Krafttraining-Bereich"
    case .run:
      return "Schließt den Fortschritt und öffnet den Lauftraining-Bereich"
    }
  }

  private func mergedHistory(filter: HistoryFilter, limit: Int? = nil) -> [HistoryEntry] {
    // Beide Historien sind bereits newest-first sortiert. Statt concat+sort
    // (O((n+m) log(n+m))) verwenden wir einen linearen Merge (O(n+m)).
    // Perf (2026-05-31): Optionales `limit` stoppt den Merge nach den n
    // neuesten Einträgen — der Verlaufs-Block zeigt nur 5, muss also nicht
    // die komplette Historie materialisieren.
    switch filter {
    case .strength:
      let items = limit.map { Array(store.workoutHistory.prefix($0)) } ?? store.workoutHistory
      return items.map(HistoryEntry.workout)
    case .cardio:
      let items = limit.map { Array(store.runHistory.prefix($0)) } ?? store.runHistory
      return items.map(HistoryEntry.run)
    case .all:
      let workouts = store.workoutHistory
      let runs     = store.runHistory
      var result   = [HistoryEntry]()
      result.reserveCapacity(limit ?? (workouts.count + runs.count))
      var wi = workouts.startIndex
      var ri = runs.startIndex
      while wi < workouts.endIndex && ri < runs.endIndex {
        if let limit, result.count >= limit { return result }
        if workouts[wi].finishedAt >= runs[ri].finishedAt {
          result.append(.workout(workouts[wi])); wi = workouts.index(after: wi)
        } else {
          result.append(.run(runs[ri]));         ri = runs.index(after: ri)
        }
      }
      while wi < workouts.endIndex {
        if let limit, result.count >= limit { return result }
        result.append(.workout(workouts[wi])); wi = workouts.index(after: wi)
      }
      while ri < runs.endIndex {
        if let limit, result.count >= limit { return result }
        result.append(.run(runs[ri]));         ri = runs.index(after: ri)
      }
      return result
    }
  }

  // MARK: - Helpers

  private var weekNumber: Int {
    Calendar.current.component(.weekOfYear, from: Date())
  }

  private var weekProgress: Double {
    min(Double(store.weeklySessionsCompleted) / Double(max(store.weeklyGoalCount, 1)), 1.0)
  }

  private func deltaLabel(_ delta: Double) -> String {
    if abs(delta) < 0.05 { return "STABIL" }
    return delta < 0
      ? String(format: "%.1f kg", delta)
      : String(format: "+%.1f kg", delta)
  }

  private func spokenWeightDeltaLabel(_ delta: Double) -> String {
    if abs(delta) < 0.05 { return "Gewicht stabil" }
    return delta < 0
      ? String(format: "%.1f Kilogramm unter Start", abs(delta))
      : String(format: "%.1f Kilogramm über Start", delta)
  }

  private var waistDeltaText: String {
    let delta = store.startingWaist - store.waistMeasurement
    if abs(delta) < 0.05 { return "stabil" }
    return String(format: "%.1f cm", abs(delta)) + (delta > 0 ? " runter" : " hoch")
  }

  private func emptyHint(_ message: String) -> some View {
    HStack(spacing: GainsSpacing.xsPlus) {
      Image(systemName: "info.circle")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)
      Text(message)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, GainsSpacing.xxs)
  }

  private func goalProgressLocal(_ goal: ProgressGoal) -> Double {
    let trimmedGoalTitle = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)

    switch trimmedGoalTitle {
    case "Körpergewicht":
      let start  = store.startingWeight
      let target = goal.target
      let current = goal.current
      let totalChange = target - start
      // Ziel-Richtung bestimmen: Abnahme (totalChange < 0) oder Zunahme (totalChange > 0)
      guard abs(totalChange) > 0.1 else { return current == target ? 1 : 0 }
      if totalChange < 0 {
        // Abnehmen: je näher current an target (kleiner), desto mehr Fortschritt
        return min(max((start - current) / abs(totalChange), 0), 1)
      } else {
        // Zunehmen: je näher current an target (größer), desto mehr Fortschritt
        return min(max((current - start) / totalChange, 0), 1)
      }
    case "Taillenumfang":
      let start  = store.startingWaist
      let target = goal.target
      let current = goal.current
      let totalChange = target - start
      guard abs(totalChange) > 0.1 else { return current == target ? 1 : 0 }
      if totalChange < 0 {
        return min(max((start - current) / abs(totalChange), 0), 1)
      } else {
        return min(max((current - start) / totalChange, 0), 1)
      }
    default:
      return min(goal.current / max(goal.target, 0.1), 1)
    }
  }

  private func goalAction(for goal: ProgressGoal) -> () -> Void {
    let trimmedGoalTitle = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)

    switch trimmedGoalTitle {
    case "Körpergewicht": return store.logWeightCheckIn
    case "Taillenumfang": return store.logWaistCheckIn
    default:              return store.logProteinCheckIn
    }
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "ohne Paceangabe" }
    return String(format: "%d:%02d /km", seconds / 60, seconds % 60)
  }

  private func spokenPaceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "unbekannt pro Kilometer" }
    return String(format: "%d:%02d pro Kilometer", seconds / 60, seconds % 60)
  }
}

// MARK: - Hero-Glow Helper-Views (B5)
//
// Drei animierte Subviews, die jeweils eine Hero-Variante visuell
// differenzieren. Bewusst dezent + langsam — nicht zur Hauptattraktion
// werden, aber dem Hero ein wiedererkennbares Gesicht geben.

/// Drei kleine Sparkle-Punkte diagonal verteilt mit unabhängiger Atmung.
/// Wird für `personalRecord`-Variante eingesetzt.
private struct HeroSparklesView: View {
  let accent: Color
  @State private var phase1 = false
  @State private var phase2 = false
  @State private var phase3 = false

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        sparkle(at: CGPoint(x: proxy.size.width * 0.78, y: proxy.size.height * 0.18), size: 18, phase: phase1)
        sparkle(at: CGPoint(x: proxy.size.width * 0.92, y: proxy.size.height * 0.55), size: 12, phase: phase2)
        sparkle(at: CGPoint(x: proxy.size.width * 0.65, y: proxy.size.height * 0.78), size: 10, phase: phase3)
      }
    }
    // drawingGroup: GPU-Compositing via Metal — Animation läuft auf
    // einem separaten Render-Pass, blockiert den Scroll-Thread nicht.
    .drawingGroup()
    .onAppear {
      withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
        phase1 = true
      }
      withAnimation(.easeInOut(duration: 3.1).repeatForever(autoreverses: true).delay(0.4)) {
        phase2 = true
      }
      withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(0.8)) {
        phase3 = true
      }
    }
  }

  private func sparkle(at point: CGPoint, size: CGFloat, phase: Bool) -> some View {
    Image(systemName: "sparkle")
      .font(.system(size: size, weight: .heavy))
      .foregroundStyle(accent.opacity(phase ? 0.55 : 0.18))
      .shadow(color: accent.opacity(phase ? 0.6 : 0.0), radius: 8)
      .position(point)
  }
}

/// Zwei konzentrische Halos, die wie eine pulsierende Flamme atmen —
/// Streak-Variante.
private struct HeroDualHaloView: View {
  let accent: Color
  @State private var pulsing = false

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        // Outer halo — größer, später, transparenter
        Circle()
          .fill(accent.opacity(pulsing ? 0.10 : 0.04))
          .frame(width: 260, height: 260)
          .blur(radius: 40)
          .offset(x: proxy.size.width * 0.55, y: -120)
          .scaleEffect(pulsing ? 1.05 : 0.92)

        // Inner halo — kleiner, kräftiger
        Circle()
          .fill(accent.opacity(pulsing ? 0.22 : 0.10))
          .frame(width: 140, height: 140)
          .blur(radius: 30)
          .offset(x: proxy.size.width * 0.65, y: -90)
          .scaleEffect(pulsing ? 1.08 : 0.94)
      }
    }
    .drawingGroup()
    .onAppear {
      withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
        pulsing = true
      }
    }
  }
}

/// Konzentrische, langsam ausdehnende Pulse-Ringe — Comeback-Variante.
private struct HeroPulseRingView: View {
  let accent: Color
  @State private var animating = false

  var body: some View {
    GeometryReader { proxy in
      let center = CGPoint(x: proxy.size.width * 0.85, y: proxy.size.height * 0.18)
      ZStack {
        ring(scale: animating ? 2.4 : 0.8, opacity: animating ? 0.0 : 0.32, center: center)
        ring(scale: animating ? 1.8 : 0.6, opacity: animating ? 0.0 : 0.45, center: center)
      }
    }
    .drawingGroup()
    .onAppear {
      withAnimation(.easeOut(duration: 3.0).repeatForever(autoreverses: false)) {
        animating = true
      }
    }
  }

  private func ring(scale: CGFloat, opacity: Double, center: CGPoint) -> some View {
    Circle()
      .stroke(accent.opacity(opacity), lineWidth: 1.2)
      .frame(width: 80, height: 80)
      .scaleEffect(scale)
      .position(center)
  }
}
