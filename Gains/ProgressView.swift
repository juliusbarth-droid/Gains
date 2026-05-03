import SwiftUI

// MARK: - Verlauf-Filter

private enum HistoryFilter: String, CaseIterable, Identifiable {
  case all, strength, cardio
  var id: Self { self }

  var label: String {
    switch self {
    case .all:      return "Alle"
    case .strength: return "Kraft"
    case .cardio:   return "Cardio"
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
    case .starting:       return "GAINS · START"
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
      LazyVStack(alignment: .leading, spacing: 20) {
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

  @State private var historyFilter: HistoryFilter = .all
  @State private var coachInsightIndex: Int = 0

  var body: some View {
    LazyVStack(alignment: .leading, spacing: 22) {
      heroBanner
      coachInsightCard
      readinessRow
      pulseStrip
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
  }

  /// Footer-CTA, der am Ende der ProgressContentView den nächsten Schritt
  /// signalisiert. Wirkt wie ein Pulsschluss am Ende der Story-Sektionen.
  private var progressFooterCTA: some View {
    let plan = store.todayPlannedDay
    let isPlanned = plan.status == .planned
    let title: String = isPlanned ? "Heute starten" : "Plan ansehen"
    let subtitle: String = isPlanned
      ? plan.workoutPlan?.title ?? plan.title
      : "Wochenplan anpassen"
    let icon: String = isPlanned ? "play.fill" : "calendar"

    return Button {
      if isPlanned {
        navigation.openTraining(workspace: .kraft)
      } else {
        navigation.openPlanner()
      }
    } label: {
      HStack(spacing: 14) {
        ZStack {
          Circle()
            .fill(GainsColor.lime.opacity(0.18))
            .frame(width: 42, height: 42)
          Image(systemName: icon)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(GainsColor.onLime)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text("NÄCHSTER SCHRITT")
            .gainsEyebrow(GainsColor.lime, size: 9, tracking: 1.4)
          Text(title)
            .font(GainsFont.title(17))
            .foregroundStyle(GainsColor.ink)
          Text(subtitle)
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }
        Spacer(minLength: 0)
        Image(systemName: "arrow.up.right")
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(14)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - 1. Story-Hero (dynamisch)

  private var heroBanner: some View {
    let variant = heroVariant
    let copy = heroCopy(for: variant)

    return ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 28, style: .continuous)
        .fill(GainsColor.ctaSurface)

      RoundedRectangle(cornerRadius: 28, style: .continuous)
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
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 8) {
          Image(systemName: variant.icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(variant.accent)
            .frame(width: 22, height: 22)
            .background(variant.accent.opacity(0.16))
            .clipShape(Circle())

          Text(variant.eyebrow)
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(variant.accent)

          Spacer()

          Text("KW \(weekNumber)")
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.55))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(GainsColor.onCtaSurface.opacity(0.08))
            .clipShape(Capsule())
        }

        Text(copy.headline)
          .font(.system(size: 30, weight: .semibold))
          .foregroundStyle(GainsColor.onCtaSurface)
          .lineLimit(2)
          .minimumScaleFactor(0.7)
          .padding(.top, 4)

        Text(copy.subline)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.72))
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)

        HStack(spacing: 14) {
          Rectangle()
            .fill(variant.accent.opacity(0.7))
            .frame(width: 44, height: 2)

          if let badge = copy.badge {
            Text(badge)
              .font(GainsFont.label(9))
              .tracking(1.6)
              .foregroundStyle(variant.accent)
          }

          Spacer()

          Button {
            heroAction(for: variant)
          } label: {
            HStack(spacing: 6) {
              Text(copy.cta)
                .font(GainsFont.label(10))
                .tracking(1.4)
              Image(systemName: "arrow.up.right")
                .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(variant.accent)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(variant.accent.opacity(0.12))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
        .padding(.top, 4)
      }
      .padding(20)
    }
    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
  }

  private func heroCopy(for hero: ProgressHero) -> (headline: String, subline: String, badge: String?, cta: String) {
    switch hero {
    case let .personalRecord(name, weight, delta):
      return (
        headline: "\(name) — \(weight)",
        subline: "Frischer Top-Wert. Im nächsten Block 2.5 kg drauf, 3×5 saubere Reps.",
        badge: delta,
        cta: "PR feiern"
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
        cta: "Plan ansehen"
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
      return (
        headline: "Wochenziel durchgezogen",
        subline: "\(sessions) Sessions im Kasten. Bonus-Session ist jetzt Ass im Ärmel, nicht Pflicht.",
        badge: "\(sessions)/\(store.weeklyGoalCount) ✓",
        cta: "Bonus starten"
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
        cta: "Heute planen"
      )
    case let .onTrack(done, goal, percent):
      let remaining = max(goal - done, 0)
      let line: String
      if remaining == 0       { line = "Alle Sessions sitzen. Nächste Woche: gleiche Frequenz, mehr Volumen." }
      else if remaining == 1  { line = "Eine Session noch. Du brauchst 45 Minuten — die hast du." }
      else                    { line = "\(remaining) Sessions offen. Plan check, dann eintakten." }
      return (
        headline: "\(done) von \(goal) — \(percent) %",
        subline: line,
        badge: "WOCHENPLAN",
        cta: "Nächste Session"
      )
    case .starting:
      return (
        headline: "Fortschritt sichtbar machen",
        subline: "Logge dein erstes Workout oder einen Check-in — ab dann erzählt sich diese Seite selbst.",
        badge: "TAG 1",
        cta: "Loslegen"
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
      navigation.openTraining(workspace: .kraft)
    case .starting:
      // H6-Fix (2026-05-01): Erstanfänger ohne Plan/Daten landeten via
      // openTraining(.kraft) in einer leeren Gym-Session. Stattdessen
      // den Planner öffnen, damit sie zuerst einen Plan auswählen oder
      // einen eigenen anlegen.
      navigation.openPlanner()
    case .weightLow:
      store.logWeightCheckIn()
    case .longestRun:
      navigation.openTraining(workspace: .laufen)
    case .comeback:
      navigation.openPlanner()
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
    let recent = store.workoutHistory.filter { $0.finishedAt >= cutoff }
    guard !recent.isEmpty else { return nil }

    var bestRecent: [String: Double] = [:]
    for workout in recent {
      for ex in workout.exercises where ex.topWeight > 0 {
        bestRecent[ex.name] = max(bestRecent[ex.name] ?? 0, ex.topWeight)
      }
    }

    var bestAllTime: [String: Double] = [:]
    for workout in store.workoutHistory where workout.finishedAt < cutoff {
      for ex in workout.exercises where ex.topWeight > 0 {
        bestAllTime[ex.name] = max(bestAllTime[ex.name] ?? 0, ex.topWeight)
      }
    }

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
    let recent = store.runHistory.filter { $0.finishedAt >= cutoff }
    guard let latest = recent.max(by: { $0.distanceKm < $1.distanceKm }) else { return nil }
    let allTimeMax = store.runHistory.filter { $0.finishedAt < cutoff }.map(\.distanceKm).max() ?? 0
    guard latest.distanceKm > allTimeMax + 0.1 else { return nil }
    return .longestRun(km: latest.distanceKm)
  }

  private var recentComeback: ProgressHero? {
    let combinedDates = store.workoutHistory.map(\.finishedAt) + store.runHistory.map(\.finishedAt)
    let sorted = combinedDates.sorted(by: >)
    guard sorted.count >= 2 else { return nil }
    let latest = sorted[0]
    let previous = sorted[1]
    let daysBetween = Calendar.current.dateComponents([.day], from: previous, to: latest).day ?? 0
    let daysSinceLatest = Calendar.current.dateComponents([.day], from: latest, to: Date()).day ?? 0
    guard daysBetween >= 4, daysSinceLatest <= 1 else { return nil }
    return .comeback(daysAway: daysBetween)
  }

  // MARK: - 2. Coach-Insight

  private var coachInsightCard: some View {
    let insights = coachInsights
    let safeIndex = insights.isEmpty ? 0 : coachInsightIndex % max(insights.count, 1)
    let current = insights.indices.contains(safeIndex) ? insights[safeIndex] : coachFallback

    return Button {
      withAnimation(.easeInOut(duration: 0.22)) {
        coachInsightIndex = (coachInsightIndex + 1) % max(insights.count, 1)
      }
    } label: {
      // B5 (Coach-Insight-Tone): Card bekommt einen subtilen Hintergrund-Wash
      // in der Akzent-Farbe (Lime/Cyan/Ember) plus eine Akzent-Border-Linie
      // links als HUD-Marker. Icon-Plate von 38pt → 44pt mit Halo. Title-Eyebrow
      // mit zusätzlichem Status-Wort („MOMENTUM" / „WARNUNG" / „INFO") nach Tone.
      HStack(alignment: .top, spacing: 14) {
        coachIconPlate(icon: current.icon, accent: current.accent)

        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 6) {
            Text("COACH")
              .font(GainsFont.label(9))
              .tracking(1.8)
              .foregroundStyle(current.accent)
            Text("·")
              .font(GainsFont.label(9))
              .foregroundStyle(GainsColor.softInk.opacity(0.6))
            Text(coachToneLabel(for: current.accent))
              .font(GainsFont.label(9))
              .tracking(1.6)
              .foregroundStyle(GainsColor.softInk)
            if insights.count > 1 {
              Text("\(safeIndex + 1)/\(insights.count)")
                .font(GainsFont.label(8))
                .tracking(1.2)
                .foregroundStyle(GainsColor.softInk.opacity(0.85))
                .padding(.horizontal, 6)
                .frame(height: 16)
                .background(GainsColor.surfaceDeep.opacity(0.7))
                .clipShape(Capsule())
            }
            Spacer()
            Image(systemName: "arrow.triangle.2.circlepath")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(current.accent.opacity(0.7))
          }

          Text(current.text)
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
      text: "Sobald deine ersten Sessions oder Check-ins drin sind, wird hier eine echte Beobachtung stehen.",
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
          text: "Späte Wochenhälfte und noch \(remaining) Sessions offen. Realistisch: heute 1 Session retten, morgen die zweite — Rest plan-mäßig in nächste Woche schieben.",
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
          text: "Dein letzter Lauf liegt \(daysAgo) Tage zurück. Eine 30-min Easy-Session diese Woche reicht, um Aerobic Base nicht zu verlieren.",
          accent: GainsColor.accentCool
        ))
      }
    }

    if let hrv = vitalValue(named: "HRV"), let hrvNumber = parseInt(hrv.value) {
      if hrvNumber < 55 {
        list.append(CoachInsight(
          icon: "waveform.path.ecg",
          text: "HRV \(hrvNumber) ms — unter Baseline. Heute eher mobilisieren, Zone-2 oder regenerative Session statt schwerer Belastung.",
          accent: GainsColor.ember
        ))
      } else if hrvNumber >= 70 {
        list.append(CoachInsight(
          icon: "waveform.path.ecg",
          text: "HRV \(hrvNumber) ms — Recovery offen. Heute kannst du beim Hauptlift anziehen, ohne ins Risiko zu gehen.",
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
      if progress >= 0.85 && progress < 1.0 {
        list.append(CoachInsight(
          icon: "scope",
          text: "\(goal.title) liegt bei \(Int(progress * 100)) %. Letzte Meile — kein Sprint, einfach den Plan zu Ende fahren.",
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
      VStack(alignment: .leading, spacing: 10) {
        SlashLabel(
          parts: ["READINESS", "HEUTE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        HStack(spacing: 8) {
          ForEach(vitals.prefix(4)) { vital in
            readinessCell(vital)
          }
        }

        if !store.hasConnectedAppleHealth {
          Button { store.syncVitalData() } label: {
            HStack(spacing: 8) {
              Image(systemName: "heart.text.square.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GainsColor.lime)
              Text("Apple Health verbinden für Live-HRV/Schlaf")
                .font(GainsFont.label(11))
                .tracking(0.6)
                .foregroundStyle(GainsColor.softInk)
                .lineLimit(1)
              Spacer()
              Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(GainsColor.border)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(GainsColor.card)
            .overlay(
              RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          }
          .buttonStyle(.plain)
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
    Button { store.syncVitalData() } label: {
      VStack(alignment: .leading, spacing: 4) {
        Text(vital.title.uppercased())
          .font(GainsFont.label(8))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
        Text(vital.value)
          .font(GainsFont.metricSmall)
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 10)
      .padding(.vertical, 10)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - 4. Pulse-Strip (Wochen-Snapshot in 4 Zellen)

  private var pulseStrip: some View {
    HStack(spacing: 8) {
      pulseCell(
        ringValue: weekProgress,
        title: "PLAN",
        value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)",
        accent: GainsColor.lime
      )
      pulseCell(
        icon: store.streakDays >= 7 ? "flame.fill" : "flame",
        title: "STREAK",
        value: "\(store.streakDays) T",
        accent: store.streakDays >= 3 ? GainsColor.lime : GainsColor.softInk
      )
      pulseCell(
        icon: "chart.bar.fill",
        title: "VOL/W",
        value: String(format: "%.1f t", store.weeklyVolumeTons),
        accent: GainsColor.lime
      )
      pulseCell(
        icon: "bolt.fill",
        title: "PR",
        value: "\(store.personalRecordCount)",
        accent: store.personalRecordCount > 0 ? GainsColor.lime : GainsColor.softInk
      )
    }
  }

  private func pulseCell(
    ringValue: Double? = nil,
    icon: String? = nil,
    title: String,
    value: String,
    accent: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
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

      Text(value)
        .font(GainsFont.metricSmall)
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      Text(title)
        .font(GainsFont.label(8))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 11)
    .padding(.vertical, 11)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  // MARK: - 5. Drei Story-Karten (Stärke / Körper / Cardio)

  private var storyCardsBlock: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["STORY", "DEEP DIVE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      LazyVStack(spacing: 12) {
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

    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text("STÄRKE")
            .font(GainsFont.label(9))
            .tracking(1.8)
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
              .tracking(1.2)
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
        VStack(spacing: 8) {
          ForEach(Array(store.exerciseStrengthProgress.dropFirst().prefix(3))) { ex in
            HStack {
              Text(ex.exerciseName)
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
                .lineLimit(1)
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
        .padding(.top, 4)
      }
    }
    .padding(16)
    .gainsCardStyle()
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

    return Button { store.logWeightCheckIn() } label: {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 3) {
            Text("KÖRPER")
              .font(GainsFont.label(9))
              .tracking(1.8)
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
              .tracking(1.2)
              .foregroundStyle(delta <= 0 ? GainsColor.accentCool : GainsColor.ember)
          }
        }

        if store.weightTrend.count >= 2 {
          weightSparkline
        } else {
          emptyHint("Logge dein Gewicht regelmäßig — die Linie braucht mindestens zwei Punkte.")
        }

        HStack(spacing: 10) {
          Image(systemName: "ruler.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.accentCool)
          Text("Taille \(String(format: "%.1f cm", store.waistMeasurement))")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
          Spacer()
          Text(waistDeltaText)
            .font(GainsFont.label(9))
            .tracking(1.2)
            .foregroundStyle(GainsColor.softInk)
          Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(GainsColor.border)
        }
        .contentShape(Rectangle())
        .onTapGesture { store.logWaistCheckIn() }
      }
      .padding(16)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
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
      navigation.openTraining(workspace: .laufen)
    } label: {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 3) {
            Text("CARDIO")
              .font(GainsFont.label(9))
              .tracking(1.8)
              .foregroundStyle(GainsColor.ember)
            Text(latest?.title ?? "Letzte Session")
              .font(GainsFont.title(20))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
          }
          Spacer()
          if let r = latest {
            VStack(alignment: .trailing, spacing: 2) {
              Text(String(format: "%.1f km", r.distanceKm))
                .font(GainsFont.metric)
                .foregroundStyle(GainsColor.ink)
              Text(paceLabel(r.averagePaceSeconds))
                .font(GainsFont.label(9))
                .tracking(1.2)
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
          HStack(spacing: 12) {
            Label("\(r.averageHeartRate) bpm", systemImage: "heart.fill")
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.softInk)
            Label("\(r.durationMinutes) min", systemImage: "clock")
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.softInk)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(GainsColor.border)
          }
        }
      }
      .padding(16)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
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
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["ZIELE", "AKTIV"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        VStack(spacing: 8) {
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

    return Button { goalAction(for: goal)() } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Text(goal.title)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Spacer()
          Text(String(format: "%.0f / %.0f %@", goal.current, goal.target, goal.unit))
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
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - 7. Highlights (PRs + Milestones merged, kompakte Timeline)

  @ViewBuilder
  private var highlightsSection: some View {
    let highlights = mergedHighlights
    if !highlights.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
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
        .padding(14)
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
      entries.append(HighlightEntry(
        kind: .run,
        title: String(format: "%.1f km längster Lauf", longest.distanceKm),
        detail: "\(paceLabel(longest.averagePaceSeconds)) · \(longest.averageHeartRate) bpm",
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
    HStack(alignment: .top, spacing: 14) {
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
            .padding(.vertical, 4)
        }
      }
      .frame(width: 28)

      VStack(alignment: .leading, spacing: 3) {
        HStack {
          Text(h.title)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Spacer()
          Text(h.dateLabel)
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(GainsColor.softInk)
        }
        Text(h.detail)
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(2)
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
    let merged = mergedHistory(filter: historyFilter)
    if !merged.isEmpty || !store.workoutHistory.isEmpty || !store.runHistory.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          SlashLabel(
            parts: ["VERLAUF"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )
          Spacer()
          HStack(spacing: 6) {
            ForEach(HistoryFilter.allCases) { filter in
              Button {
                withAnimation(.easeInOut(duration: 0.15)) { historyFilter = filter }
              } label: {
                Text(filter.label)
                  .font(GainsFont.label(9))
                  .tracking(1.0)
                  .foregroundStyle(historyFilter == filter ? GainsColor.onLime : GainsColor.softInk)
                  .padding(.horizontal, 10)
                  .frame(height: 24)
                  .background(historyFilter == filter ? GainsColor.lime : GainsColor.card)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
        }

        if merged.isEmpty {
          EmptyStateView(
            style: .inline,
            title: "Noch keine Aktivitäten",
            message: "Sobald du Trainings oder Cardio-Sessions abschließt, sammeln sich hier deine letzten Aktivitäten.",
            icon: "clock.arrow.circlepath"
          )
        } else {
          VStack(spacing: 6) {
            ForEach(merged.prefix(5)) { entry in
              historyRowCompact(entry)
            }
          }
        }
      }
    }
  }

  private func historyRowCompact(_ entry: HistoryEntry) -> some View {
    Button { store.shareProgressUpdate() } label: {
      HStack(spacing: 12) {
        Image(systemName: historyIcon(entry))
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(historyAccent(entry))
          .frame(width: 24, height: 24)
          .background(historyAccent(entry).opacity(0.14))
          .clipShape(Circle())

        VStack(alignment: .leading, spacing: 1) {
          Text(historyTitle(entry))
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Text(historySubtitle(entry))
            .font(GainsFont.label(9))
            .tracking(0.6)
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }

        Spacer()

        Text(entry.date.formatted(.dateTime.day().month()))
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
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

  private func historyTitle(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout(let w): return w.title
    case .run(let r):     return r.title
    }
  }

  private func historySubtitle(_ entry: HistoryEntry) -> String {
    switch entry {
    case .workout(let w):
      return String(format: "%.1f t · %d Sätze", w.volume / 1000, w.completedSets)
    case .run(let r):
      return "\(String(format: "%.1f km", r.distanceKm)) · \(paceLabel(r.averagePaceSeconds))"
    }
  }

  private func mergedHistory(filter: HistoryFilter) -> [HistoryEntry] {
    var entries: [HistoryEntry] = []
    if filter != .cardio   { entries += store.workoutHistory.map(HistoryEntry.workout) }
    if filter != .strength { entries += store.runHistory.map(HistoryEntry.run) }
    return entries.sorted { $0.date > $1.date }
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

  private var waistDeltaText: String {
    let delta = store.startingWaist - store.waistMeasurement
    if abs(delta) < 0.05 { return "stabil" }
    return String(format: "%.1f cm", abs(delta)) + (delta > 0 ? " runter" : " hoch")
  }

  private func emptyHint(_ message: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "info.circle")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)
      Text(message)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.vertical, 4)
  }

  private func goalProgressLocal(_ goal: ProgressGoal) -> Double {
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

  private func goalAction(for goal: ProgressGoal) -> () -> Void {
    switch goal.title {
    case "Körpergewicht": return store.logWeightCheckIn
    case "Taillenumfang": return store.logWaistCheckIn
    default:              return store.logProteinCheckIn
    }
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:-- /km" }
    return String(format: "%d:%02d /km", seconds / 60, seconds % 60)
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
