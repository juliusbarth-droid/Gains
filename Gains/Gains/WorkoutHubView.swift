import CoreLocation
import MapKit
import SwiftUI
import UIKit

// MARK: - WorkoutHubView
//
// Run-fokussierte Hub-View (Tab „LAUFEN" der App). Frühere Versionen
// enthielten auch Kraft- und Plan-Workspaces — diese sind jetzt im GymView
// gebündelt. Hier bleibt nur, was direkt mit dem Lauf-Workflow zu tun hat:
// Hero-Card, Live-Tracker, Vorlagen, Wochen-/YTD-Statistiken, PRs,
// Pace-Zonen und der Run-Feed.
//
// A9 (Übersichtlichkeit / Dark-Tech-Iteration):
// - Hero-Card baut jetzt auf der zentralen `GainsHeroCard` aus dem Design-
//   System. Vorher gab es eine zweite Eigenbau-Hero mit eigener `darkMetricCard`-
//   Tile, die optisch dicht neben — aber leicht anders als — der Gym-Hero stand.
// - `tabPicker` nutzt jetzt das gleiche segmented-Pill-Vokabular wie
//   `GymView.tabPicker` (statt scrollbarer Capsule-Chips mit Icon).
// - Live-Banner ist kompakter und nutzt `GainsMetricTile(.subdued)` statt
//   einer eigenen `workoutStatCard`-Implementierung.
// - „Letzter Lauf"-Card ist entfallen, weil derselbe Lauf direkt darunter im
//   Feed mit „ZULETZT"-Eyebrow auftauchte (Doppelung).
// - YTD-Tile, Lauf-Templates und Run-Activity-Cards greifen alle auf
//   `GainsMetricTile`/Hairline-Stripes zurück, statt eigene Mini-Layouts
//   zu führen.

/// Tabs im Run-Hub. Wird im UI als segmented-Picker gerendert.
enum RunHubTab: String, CaseIterable, Identifiable {
  // 2026-05-29: `feed` entfernt — die Aktivitäten stehen jetzt als
  // „Letzte Läufe" direkt im Hub-Hauptfluss unter der Hero-Kachel
  // (Strava-Modell). Der Picker bündelt nur noch die Tiefen-Tools.
  case routes
  case segments
  case workouts
  case stats

  var id: String { rawValue }

  /// Kurzer, getrackter Label-Text für die segmentierte Tab-Bar.
  var label: String {
    switch self {
    case .routes:   return "ROUTEN"
    case .segments: return "SEGMENTE"
    case .workouts: return "PLÄNE"
    // 2026-05-15 (Audit-Loop 21): „DATEN" → „STATS", konsistent mit
    // dem Gym-Tab (GymView P0-1, 2026-05-03). Day-One-Tour, Coach-
    // Actions und Pulse-Chevrons nutzen ohnehin „STATS" — der Cardio-
    // Hub war der einzige verbleibende „DATEN"-Ausreißer.
    case .stats:    return "STATS"
    }
  }
}

struct WorkoutHubView: View {
  @EnvironmentObject private var store: GainsStore
  @State private var isShowingRunTracker = false
  @State private var selectedRun: CompletedRunSummary? = nil
  @State private var presentedRoute: SavedRoute? = nil
  @State private var presentedSegment: RunSegment? = nil
  @State private var presentedWorkout: StructuredRunWorkout? = nil
  @State private var showsSegmentCreator = false
  @State private var selectedTab: RunHubTab = .routes
  @State private var pendingAfterSelectedRun: (() -> Void)? = nil
  @State private var pendingAfterPresentedWorkout: (() -> Void)? = nil
  // 2026-05-29: „Alle anzeigen"-Sheet für die komplette (modus-gefilterte)
  // Aktivitäten-Liste. `pendingDetailRun` öffnet nach dem Schließen des
  // Listen-Sheets das Detail-Sheet (Sheet-über-Sheet-Race vermeiden).
  @State private var showsAllRuns = false
  @State private var pendingDetailRun: CompletedRunSummary? = nil

  // Polish-Loop 136 (2026-05-14): Modus-Toggle v2 — matchedGeometry für
  // glatte Pill-Schiebe-Animation zwischen Lauf/Rad/Indoor.
  @Namespace private var modalityNS

  // 2026-05-03 (P1-2): User wählt Modus oben im Hub. Default ist die zuletzt
  // genutzte Modalität — beim ersten Start `.run`. Persistenz via AppStorage,
  // damit Bike-Nutzer nach App-Restart nicht in den Lauf-Default fallen.
  @AppStorage("gains.cardio.preferredModality") private var preferredModalityRaw: String = CardioModality.run.rawValue

  private var preferredModality: CardioModality {
    CardioModality(rawValue: preferredModalityRaw) ?? .run
  }

  /// Im Hero/Headline gerenderte Modalität. Eine aktive Session erzwingt ihre
  /// eigene Modalität; sonst gilt die `preferredModality`.
  private var displayedModality: CardioModality {
    store.activeRun?.modality ?? preferredModality
  }

  // Welle 2 — Day-One: Cardio-Hub hat fünf Sub-Tabs (Feed/Routen/Segmente/
  // Pläne/Stats) — viel auf einmal. Ein Mini-Tour-Banner über dem Hero
  // ordnet das ein, solange der User noch nie einen Lauf abgeschlossen hat
  // (oder seit Onboarding < 24h vergangen sind).
  @AppStorage(GainsKey.onboardingCompletedAt) private var onboardingCompletedAt: Double = 0

  private var isInRunDayOneWindow: Bool {
    // 2026-05-15 (Audit-Loop 11): 24h-Cap entfernt — analog zum
    // GymTodayTab-Fix (P1-2, 2026-05-03). Wer abends onboardet und am
    // nächsten Morgen die App öffnet, würde die Tour sonst nie sehen,
    // obwohl noch kein Lauf absolviert wurde. Jetzt: Tour läuft, bis der
    // User mindestens einen Lauf in der `runHistory` hat.
    guard onboardingCompletedAt > 0 else { return false }
    if !store.runHistory.isEmpty { return false }
    return true
  }

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
        trainHeader
        if isInRunDayOneWindow {
          dayOneRunGuide
        }
        runHeroCard
        if store.activeRun != nil {
          runLiveBanner
        }

        belowHeroContent

        tabPicker
        tabContent
      }
    }
    .sheet(isPresented: $showsAllRuns, onDismiss: {
      if let run = pendingDetailRun {
        pendingDetailRun = nil
        selectedRun = run
      }
    }) {
      allRunsSheet
    }
    .sheet(isPresented: $isShowingRunTracker) {
      RunTrackerView()
        .environmentObject(store)
    }
    .sheet(item: $selectedRun, onDismiss: { runPending(&pendingAfterSelectedRun) }) { run in
      RunDetailSheet(run: run) {
        store.startRunLike(run)
        pendingAfterSelectedRun = {
          if store.activeRun != nil {
            isShowingRunTracker = true
          }
        }
        selectedRun = nil
      }
      .environmentObject(store)
    }
    .sheet(item: $presentedRoute) { route in
      SavedRouteDetailSheet(route: route)
        .environmentObject(store)
    }
    .sheet(item: $presentedSegment) { segment in
      RunSegmentDetailSheet(segment: segment)
        .environmentObject(store)
    }
    .sheet(item: $presentedWorkout, onDismiss: { runPending(&pendingAfterPresentedWorkout) }) { workout in
      StructuredWorkoutDetailSheet(workout: workout) {
        pendingAfterPresentedWorkout = {
          if store.activeRun != nil {
            isShowingRunTracker = true
          }
        }
        presentedWorkout = nil
      }
      .environmentObject(store)
    }
    .sheet(isPresented: $showsSegmentCreator) {
      SegmentCreatorSheet(runs: store.runHistory)
        .environmentObject(store)
    }
  }

  // MARK: - Below-Hero-Content
  //
  // Gebündelt in einer Sub-View, damit die Body-VStack unter dem 10-Kinder-
  // Limit des @ViewBuilder bleibt. Eigenes xl-Spacing = optisch identisch zu
  // direkten VStack-Kindern. Reihenfolge (Strava-Modell): heute geplant →
  // Bestzeiten → letzte Läufe → Wochen-Trend → Vorschläge.
  private var belowHeroContent: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xl) {
      // „Heute geplant" — wenn der Plan für heute eine offene Lauf-/Cardio-
      // Session vorsieht. Ein Tap füllt das Ziel vor und startet.
      if let planned = todayPlannedCardio, store.activeRun == nil {
        todayPlannedRow(planned)
      }

      // Bestzeiten direkt sichtbar — ohne in den STATS-Tab zu wechseln.
      if displayedModality == .run && !store.distancePRs.isEmpty {
        runQuickPRStrip
      }
      if displayedModality.isCycling && !store.bikePersonalBests.isEmpty {
        bikeQuickPRStrip
      }

      // Strava-Modell: letzte Läufe direkt unter der Kachel, modus-gefiltert,
      // mit Mini-Map. Darunter Wochen-Trend + Vorschläge.
      recentRunsSection
      weeklyTrendSection
      runningTemplatesSection
    }
  }

  // MARK: - Header
  //
  // 2026-05-03 (P1-1): Vorher hatte der Hub einen `screenHeader` mit
  // grossem Title „Lauf starten" — exakt der Text, der als Hero-CTA direkt
  // darunter erscheint. Doppelung. Title ist raus; statt dessen rendert die
  // `GainsHeroCard` die identitätsstiftende Bühne. Hier bleibt nur ein
  // schlanker Eyebrow-Streifen für Tab-Identität.

  private var trainHeader: some View {
    HStack(alignment: .firstTextBaseline) {
      SlashLabel(
        parts: ["KARDIO", "TRAINING"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )
      Spacer()
      // Quick-Toggle für Modalität — drei Glyphen, kein Text. Aktive Session
      // sperrt den Toggle (Modus während Live-Session nicht wechselbar).
      modalityToggle
    }
  }

  /// Drei-Wege Modus-Toggle (Lauf / Rad / Indoor). Tap setzt
  /// `preferredModalityRaw`. Hero & Headline reagieren live darauf.
  ///
  /// Polish-Loop 136 v2 (2026-05-14): Aktive Pille wird via
  /// `matchedGeometryEffect` zwischen den drei Slots animiert.
  /// Container bekommt `.ultraThinMaterial`-Glas-Unterton, Inner-Light
  /// oben und eine feine Akzent-Hairline für Premium-Look — passt zu den
  /// neuen Glas-Switches an anderen Stellen (Nutrition Tracker/Rezepte).
  @ViewBuilder
  private var modalityToggle: some View {
    HStack(spacing: 0) {
      ForEach(CardioModality.allCases, id: \.self) { modality in
        let isActive = displayedModality == modality
        let isLocked = store.activeRun != nil && store.activeRun?.modality != modality

        Button {
          guard store.activeRun == nil else { return }
          UISelectionFeedbackGenerator().selectionChanged()
          withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            preferredModalityRaw = modality.rawValue
          }
        } label: {
          ZStack {
            if isActive {
              RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
                .fill(GainsColor.lime)
                .overlay(
                  RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
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
                .shadow(color: GainsColor.lime.opacity(0.15), radius: 8, y: 2)
                .matchedGeometryEffect(id: "modalityPill", in: modalityNS)
            }
            Image(systemName: modality.systemImage)
              .font(.system(size: 12, weight: isActive ? .bold : .semibold))
              .foregroundStyle(
                isActive ? GainsColor.onLime
                : isLocked ? GainsColor.softInk.opacity(0.4)
                : GainsColor.softInk
              )
          }
          .frame(width: 36, height: 30)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel("\(modality.displayName) wählen")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
      }
    }
    .padding(GainsSpacing.xxs)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(GainsColor.glassUndertone)
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(.ultraThinMaterial)
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(0.06),
                Color.white.opacity(0.00)
              ],
              startPoint: .top,
              endPoint: .center
            )
          )
          .blendMode(.plusLighter)
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [
              GainsColor.border.opacity(0.55),
              GainsColor.border.opacity(0.25)
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
    .shadow(color: GainsColor.shadowRest, radius: 6, y: 2)
    .animation(.spring(response: 0.32, dampingFraction: 0.78), value: displayedModality)
  }

  // MARK: - Day-One Run Guide
  //
  // Mini-Tour, die den Cardio-Hub erklärt: Hero startet sofort einen Lauf,
  // die Sub-Tabs darunter sammeln Verlauf und Tools. Bewusst dezent — der
  // Hero und der „Lauf starten"-CTA sind die Bühne, der Banner liefert nur
  // mentales Modell. Verschwindet nach erstem abgeschlossenem Lauf.

  private var dayOneRunGuide: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack(spacing: GainsSpacing.xsPlus) {
        Image(systemName: "sparkles")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(GainsColor.ember)
        Text("ERSTER BLICK")
          .gainsEyebrow(GainsColor.ember, size: 11, tracking: 1.4)
      }

      Text("Lauf, Rad, alles drin.")
        .font(GainsFont.title(15))
        .foregroundStyle(GainsColor.ink)
        .fixedSize(horizontal: false, vertical: true)

      Text("Wähle oben rechts deinen Modus — Lauf, Rad oder Heimtrainer — und tippe den Hero. Pace bzw. Geschwindigkeit, Distanz und Splits laufen automatisch mit.")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .fixedSize(horizontal: false, vertical: true)

      VStack(spacing: GainsSpacing.xs) {
        dayOneRunTourRow(icon: "list.bullet.clipboard.fill", title: "Pläne",
                         detail: "Easy, Tempo, Intervalle, Long Run.")
        dayOneRunTourRow(icon: "map.fill", title: "Routen",
                         detail: "Gespeicherte Strecken, die du wiederholen willst.")
        dayOneRunTourRow(icon: "chart.bar.fill", title: "Daten",
                         detail: "Volumen, Pace-Trend, Distanz-PRs.")
      }
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [GainsColor.ember.opacity(0.06), GainsColor.card],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.ember.opacity(0.28), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private func dayOneRunTourRow(icon: String, title: String, detail: String) -> some View {
    HStack(spacing: GainsSpacing.tight) {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(GainsColor.ember)
        .frame(width: 22, height: 22)
        .background(Circle().fill(GainsColor.ember.opacity(0.12)))
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

  // MARK: - Hero
  //
  // A9: Statt eigener `runningStarterSection` jetzt `GainsHeroCard`. Das
  // gibt dem Run-Tab dieselbe Bühne wie dem Gym-HEUTE-Tab — gleiche
  // Eyebrow-/CTA-/Metrik-Architektur.

  private var runHeroCard: some View {
    let isLive = store.activeRun != nil
    let modality = displayedModality
    return GainsHeroCard(
      eyebrow: heroEyebrow(for: modality, isLive: isLive),
      title: store.runningHeadline,
      subtitle: isLive
        ? heroLiveSubtitle(for: modality)
        : nil,
      primaryCtaTitle: heroCtaTitle(for: modality, isLive: isLive),
      primaryCtaIcon: isLive ? "play.fill" : "record.circle.fill",
      primaryCtaAction: { startOrResumeCardio() },
      metrics: heroMetrics(for: modality),
      trailingBadge: { heroBadge(isLive: isLive) }
    )
  }

  /// Eyebrow-Pärchen für den Hero. „LIVE"-Variante macht die aktive Session
  /// sofort lesbar; sonst kontextspezifische „LAUF"/„RAD"/„INDOOR"-Eyebrow.
  private func heroEyebrow(for modality: CardioModality, isLive: Bool) -> [String] {
    if isLive {
      return [modality.shortLabel, "LIVE"]
    }
    return [modality.shortLabel, "QUICK START"]
  }

  /// Live-Subtitle pro Modus — bei Bike kein Wort von „Run".
  private func heroLiveSubtitle(for modality: CardioModality) -> String {
    switch modality {
    case .run:
      return "Öffne den aktiven Lauf für Karte, Splits und Live-Steuerung."
    case .bikeOutdoor:
      return "Öffne die Tour für Karte, Geschwindigkeit und Live-Steuerung."
    case .bikeIndoor:
      return "Öffne den Tracker für Distanz, Geschwindigkeit und Live-Steuerung."
    }
  }

  /// CTA-Wording — Live öffnet, sonst startet Modalität-spezifisch.
  private func heroCtaTitle(for modality: CardioModality, isLive: Bool) -> String {
    if isLive {
      return modality.isCycling ? "Tour öffnen" : "Lauf öffnen"
    }
    switch modality {
    case .run:         return "Lauf starten"
    case .bikeOutdoor: return "Tour starten"
    case .bikeIndoor:  return "Heimtrainer starten"
    }
  }

  /// Drei Hero-Tiles. Bike-Modus zeigt km/h statt Pace; Indoor-Modus
  /// ersetzt das „7 TAGE"-Wert-Tile durch eine Indoor-Distanz-Summe.
  private func heroMetrics(for modality: CardioModality) -> [GainsHeroMetric] {
    if modality.isCycling {
      let bikeKm = store.weeklyBikeDistanceKm
      let speed = store.averageBikeSpeedKmh
      return [
        .init("7 TAGE", String(format: "%.0f km", bikeKm)),
        .init("TOUREN", "\(store.bikeOnlyCountThisWeek) / Wo."),
        .init("Ø TEMPO", speed > 0 ? String(format: "%.1f km/h", speed) : "--"),
      ]
    }
    return [
      .init("7 TAGE", String(format: "%.1f km", store.weeklyRunOnlyDistanceKm)),
      .init("LÄUFE", "\(store.weeklyRunOnlyCountThisWeek) / Wo."),
      .init("Ø PACE", runPaceLabel(store.averageRunPaceSeconds)),
    ]
  }

  private func runPending(_ action: inout (() -> Void)?) {
    let next = action
    action = nil
    next?()
  }

  // MARK: - (entfallen) Modus-Chips
  //
  // 2026-05-03 (P1-2): Die drei Quick-Start-Chips unter dem Hero sind
  // entfallen — der dieselbe Funktion erfüllende Modus-Toggle sitzt jetzt
  // direkt im Header. Dadurch ist der Hero-CTA modus-spezifisch, der
  // Hub-Header schmaler, und der Above-the-Fold-Bereich übersichtlicher.

  @ViewBuilder
  private func heroBadge(isLive: Bool) -> some View {
    if isLive {
      GainsHeroStatusBadge(label: "LIVE", tone: .live)
    } else if store.runStreak > 0 {
      streakBadge(store.runStreak)
    } else {
      EmptyView()
    }
  }

  // Polish-Loop 161 (2026-05-14): Run-Streak-Badge mit Glas-Komposition
  // statt flacher Lime-Opacity-Wash. Mono-Zähler + Inner-Light + Lime-
  // Gradient-Border passt zum App-Vokabular.
  private func streakBadge(_ days: Int) -> some View {
    HStack(spacing: GainsSpacing.xs) {
      Image(systemName: "flame.fill")
        .font(.system(size: 11, weight: .bold))
        .shadow(color: GainsColor.lime.opacity(0.275), radius: 3)
      Text("\(days)")
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
      Text("TG")
        .font(GainsFont.eyebrow(10))
        .tracking(1.3)
        .foregroundStyle(GainsColor.lime.opacity(0.85))
    }
    .foregroundStyle(GainsColor.lime)
    .padding(.horizontal, GainsSpacing.s)
    .frame(height: 26)
    .background(
      ZStack {
        Capsule().fill(GainsColor.lime.opacity(0.12))
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
      Capsule().strokeBorder(
        LinearGradient(
          colors: [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.15)],
          startPoint: .top,
          endPoint: .bottom
        ),
        lineWidth: GainsBorder.hairline
      )
    )
    .clipShape(Capsule())
    .compositingGroup()
    .shadow(color: GainsColor.lime.opacity(0.15), radius: 8, x: 0, y: 0)
  }

  // MARK: - Live-Banner
  //
  // A9: Aufgeräumt. Drei `GainsMetricTile(.subdued)` statt drei verschiedener
  // Custom-Cells, ein einziger Lime-CTA, gleicher Hairline-Border wie die
  // Hero-Card. Senkt die Höhe spürbar.

  @ViewBuilder
  private var runLiveBanner: some View {
    if let activeRun = store.activeRun {
      VStack(alignment: .leading, spacing: GainsSpacing.m) {
        HStack(spacing: GainsSpacing.xsPlus) {
          PulsingDot()
          Text("\(activeRun.modality.shortLabel) AKTIV")
            .font(GainsFont.eyebrow(10))
            .tracking(2.0)
            .foregroundStyle(GainsColor.lime)
          Spacer()
        }

        HStack(spacing: GainsSpacing.xsPlus) {
          GainsMetricTile(
            label: "DISTANZ",
            value: String(format: "%.2f", activeRun.distanceKm),
            unit: "km",
            style: .onyx
          )
          if activeRun.modality.isCycling {
            GainsMetricTile(
              label: "TEMPO",
              value: bikeSpeedLabel(activeRun.averagePaceSeconds),
              unit: "",
              style: .onyx
            )
          } else {
            GainsMetricTile(
              label: "PACE",
              value: runPaceLabel(activeRun.averagePaceSeconds),
              unit: "/km",
              style: .onyx
            )
          }
          GainsMetricTile(
            label: "PULS",
            value: "\(activeRun.currentHeartRate)",
            unit: "bpm",
            style: .onyx
          )
        }

        // A10: Live-Banner-CTA nutzt jetzt dieselbe Premium-Pille wie die
        // Hero-Card (Gradient + Icon-Plate + atmender Halo) — visueller
        // Anker für „weitermachen" statt flacher Lime-Streifen.
        HeroPrimaryCTAButton(
          title: "Tracker & Karte öffnen",
          icon: "map.fill",
          action: {
            guard store.activeRun != nil else { return }
            isShowingRunTracker = true
          }
        )
      }
      .padding(GainsSpacing.m)
      .gainsInteractiveCardStyle(GainsColor.card, accent: GainsColor.lime)
    }
  }

  // MARK: - Tab-Picker
  //
  // A9: Segmented-Pill identisch zur GymView-Tab-Bar. 5 Tabs sind eng,
  // deshalb monospace-eyebrow + minimumScaleFactor — das hält das Layout
  // stabil ohne horizontalen Scroll.

  private var tabPicker: some View {
    HStack(spacing: 0) {
      ForEach(Array(RunHubTab.allCases.enumerated()), id: \.element) { index, tab in
        let isActive = selectedTab == tab
        let isNextActive = index < RunHubTab.allCases.count - 1 && selectedTab == RunHubTab.allCases[index + 1]
        let showsTrailingDivider = index < RunHubTab.allCases.count - 1 && !isActive && !isNextActive

        Button {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            selectedTab = tab
          }
        } label: {
          Text(tab.label)
            .font(GainsFont.label(10))
            .tracking(1.3)
            .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.softInk)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .padding(.horizontal, GainsSpacing.xxs)
            .background(
              // Polish-Loop 164 (2026-05-14): Active-Pill mit Inner-Light +
              // Bottom-Dim + Lime-Glow — konsistent zum GymView-Switcher.
              ZStack {
                RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                  .fill(isActive ? GainsColor.lime : Color.clear)
                if isActive {
                  RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                    .fill(
                      LinearGradient(
                        colors: [Color.white.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .center
                      )
                    )
                    .blendMode(.plusLighter)
                  RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                    .fill(
                      LinearGradient(
                        colors: [.clear, Color.black.opacity(0.16)],
                        startPoint: .center,
                        endPoint: .bottom
                      )
                    )
                }
              }
            )
            .overlay(alignment: .trailing) {
              if showsTrailingDivider {
                Rectangle()
                  .fill(GainsColor.border.opacity(0.45))
                  .frame(width: 1, height: 20)
                  .offset(x: 0.5)
              }
            }
            .contentShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
            .compositingGroup()
            .shadow(color: isActive ? GainsColor.lime.opacity(0.30) : .clear, radius: 6)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(GainsSpacing.xxs)
    .background(
      // Container mit Glas-Unterton + ultraThinMaterial (Loop 47-Pattern).
      ZStack {
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .fill(GainsColor.glassUndertone)
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .fill(.ultraThinMaterial)
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .fill(GainsColor.card.opacity(0.55))
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.border.opacity(0.65), GainsColor.border.opacity(0.30)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
  }

  // MARK: - Tab-Content

  @ViewBuilder
  private var tabContent: some View {
    switch selectedTab {
    case .routes:
      RunRoutesTab(presentedRoute: $presentedRoute)
        .environmentObject(store)
    case .segments:
      RunSegmentsTab(
        presentedSegment: $presentedSegment,
        onCreateFromRun: { showsSegmentCreator = true }
      )
      .environmentObject(store)
    case .workouts:
      RunWorkoutsTab(presentedWorkout: $presentedWorkout)
        .environmentObject(store)
    case .stats:
      statsTab
    }
  }

  // MARK: - Heute geplant
  //
  // Wenn der Wochenplan für heute eine offene Lauf-/Cardio-Session vorsieht,
  // bietet der Hub sie als One-Tap-Start an (Ziel aus dem Template vorbefüllt).

  private var todayPlannedCardio: WorkoutDayPlan? {
    store.weeklyWorkoutSchedule.first { plan in
      plan.isToday
        && (plan.sessionKind?.isRun ?? false)
        && !store.isPlannedSessionCompletedToday(for: plan.weekday)
    }
  }

  private func todayPlannedRow(_ plan: WorkoutDayPlan) -> some View {
    let kind = plan.sessionKind ?? .easyRun
    let template = plan.runTemplate ?? RunTemplate.template(for: kind)
    let detail: String = {
      if let t = template {
        return "\(kind.title) · \(String(format: "%.1f", t.targetDistanceKm)) km · \(t.targetPaceLabel)"
      }
      return kind.title
    }()

    return HStack(spacing: GainsSpacing.s) {
      ZStack {
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(GainsColor.accentCool.opacity(0.16))
        Image(systemName: "calendar.badge.clock")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(GainsColor.accentCool)
      }
      .frame(width: 38, height: 38)

      VStack(alignment: .leading, spacing: 2) {
        Text("HEUTE GEPLANT")
          .font(GainsFont.eyebrow(9))
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.accentCool)
        Text(detail)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
      }

      Spacer(minLength: GainsSpacing.xs)

      Button {
        guard store.activeWorkout == nil else { return }
        if let template {
          store.startRun(from: template)
        } else {
          store.startQuickRun(modality: .run)
        }
        isShowingRunTracker = true
      } label: {
        Text("Starten")
          .font(GainsFont.label(11))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.lime)
          .padding(.horizontal, GainsSpacing.s)
          .frame(height: 34)
          .background(GainsColor.surfaceDeep)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // MARK: - Letzte Läufe (Strava-Feed direkt unter der Kachel)

  /// Aktivitäten gefiltert nach aktivem Hub-Modus. Lauf zeigt nur `.run`,
  /// Bike alle Cycling-Sessions — löst Julius' „Distanz nur getrennt"-Punkt.
  private var recentSessionsForModality: [CompletedRunSummary] {
    store.runHistory.filter { run in
      displayedModality.isCycling ? run.modality.isCycling : (run.modality == .run)
    }
  }

  private var recentRunsSection: some View {
    let sessions = recentSessionsForModality
    let preview = Array(sessions.prefix(3))

    return VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["LETZTE", displayedModality.isCycling ? "TOUREN" : "LÄUFE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        if sessions.count > preview.count {
          Button { showsAllRuns = true } label: {
            HStack(spacing: GainsSpacing.xxs) {
              Text("Alle · \(sessions.count)")
                .font(GainsFont.eyebrow(9))
                .tracking(GainsTracking.eyebrowTight)
              Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(GainsColor.lime)
          }
          .buttonStyle(.plain)
        }
      }

      if preview.isEmpty {
        EmptyStateView(
          style: .inline,
          title: displayedModality.isCycling
            ? "Noch keine Tour aufgezeichnet"
            : "Bereit für deinen ersten Lauf?",
          message: "Starte oben über den Hero-Button — danach erscheint hier deine Aktivität mit Karte und Splits.",
          icon: "figure.run.circle.fill",
          actionLabel: "Quick-Start",
          action: {
            guard store.activeWorkout == nil else { return }
            store.startQuickRun(modality: preferredModality)
            if store.activeRun != nil {
              isShowingRunTracker = true
            }
          }
        )
      } else {
        ForEach(Array(preview.enumerated()), id: \.element.id) { index, run in
          Button {
            selectedRun = run
          } label: {
            runActivityCard(run, isLatest: index == 0)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: - Wochen-Trend (Sparkline)

  @ViewBuilder
  private var weeklyTrendSection: some View {
    let buckets = store.weeklyDistanceTrend(modality: displayedModality)
    let maxKm = max(buckets.map(\.km).max() ?? 0, 0.1)
    let weeksWithData = buckets.filter { $0.km > 0 }.count

    // Erst ab 2 Wochen mit Daten sinnvoll — sonst ist ein „Trend" irreführend.
    if weeksWithData >= 2 {
      let avg = buckets.reduce(0.0) { $0 + $1.km } / Double(max(buckets.count, 1))
      VStack(alignment: .leading, spacing: GainsSpacing.m) {
        HStack {
          SlashLabel(
            parts: ["\(buckets.count) WOCHEN", "TREND"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk)
          Spacer()
          Text(String(format: "Ø %.1f km", avg))
            .font(GainsFont.metricMono(14))
            .foregroundStyle(GainsColor.softInk)
        }

        HStack(alignment: .bottom, spacing: GainsSpacing.xs) {
          ForEach(buckets) { bucket in
            let fraction = bucket.km > 0 ? max(bucket.km / maxKm, 0.08) : 0.05
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .fill(
                bucket.km <= 0
                  ? GainsColor.border.opacity(0.5)
                  : bucket.isCurrent ? GainsColor.lime : GainsColor.lime.opacity(0.45)
              )
              .frame(height: 56 * fraction)
              .frame(maxWidth: .infinity)
          }
        }
        .frame(height: 56, alignment: .bottom)
      }
      .padding(GainsSpacing.l)
      .gainsCardStyle()
    }
  }

  // MARK: - „Alle anzeigen"-Sheet

  private var allRunsSheet: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        LazyVStack(spacing: GainsSpacing.m) {
          ForEach(Array(recentSessionsForModality.enumerated()), id: \.element.id) { index, run in
            Button {
              // Erst Liste schließen, dann Detail über den Parent-Sheet öffnen
              // (Sheet-über-Sheet-Race vermeiden, s. pendingDetailRun).
              pendingDetailRun = run
              showsAllRuns = false
            } label: {
              runActivityCard(run, isLatest: index == 0)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(GainsSpacing.l)
      }
      .background(GainsColor.background.ignoresSafeArea())
      .navigationTitle(displayedModality.isCycling ? "Alle Touren" : "Alle Läufe")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { showsAllRuns = false } label: {
            Image(systemName: "xmark")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(GainsColor.softInk)
          }
        }
      }
    }
  }

  // MARK: - STATS-Tab

  private var statsTab: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.l) {
      weeklyDistanceChartSection
      ytdStatsSection
      distancePRsSection
      paceZonesSection
    }
  }

  // MARK: - Templates / Vorschläge
  //
  // 2026-05-03 (P1-4): Eyebrow vorher „VORSCHLÄGE / ROUTEN" — kollidierte
  // mit dem Sub-Tab „ROUTEN" (gespeicherte GPS-Strecken). Jetzt
  // „VORSCHLÄGE / WORKOUTS".
  // 2026-05-03 (P1-7): Templates werden nach `displayedModality` gefiltert,
  // damit Bike-Nutzer keine Lauf-Pläne sehen und umgekehrt. Templates ohne
  // explizite Modality (Legacy) werden Lauf zugeordnet.

  private var runningTemplatesSection: some View {
    let filtered = store.runningTemplates.filter { template in
      let m = template.modality ?? .run
      // Outdoor- und Indoor-Bike teilen sich das Bike-Bucket
      if displayedModality.isCycling {
        return m.isCycling
      }
      return m == .run
    }

    return VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      SlashLabel(
        parts: ["VORSCHLÄGE", "WORKOUTS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if filtered.isEmpty {
        EmptyStateView(
          style: .inline,
          title: "Keine Vorlagen für diesen Modus",
          message: "Wähle oben rechts einen anderen Modus oder starte eine Quick-Session über den Hero-Button.",
          icon: "list.bullet.clipboard"
        )
      } else {
        VStack(spacing: GainsSpacing.xsPlus) {
          ForEach(filtered) { template in
            templateCard(template)
          }
        }
      }
    }
  }

  private func templateCard(_ template: RunTemplate) -> some View {
    let isLocked = store.activeRun != nil
    return Button {
      store.startRun(from: template)
      if store.activeRun != nil {
        isShowingRunTracker = true
      }
    } label: {
      HStack(spacing: GainsSpacing.s) {
        // Polish-Loop 140 (2026-05-14): Template-Icon mit Inner-Light +
        // dezentem Lime-Glow, damit der Play-Affordance auf der linken Seite
        // visuell mit dem Play-Button auf der rechten Seite zusammenklingt.
        ZStack {
          Circle()
            .fill(isLocked ? GainsColor.softInk.opacity(0.08) : GainsColor.lime.opacity(0.14))
          if !isLocked {
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
          }
          Image(systemName: template.systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isLocked ? GainsColor.softInk.opacity(0.5) : GainsColor.lime)
        }
        .frame(width: 30, height: 30)
        .overlay(
          Circle()
            .strokeBorder(
              isLocked ? GainsColor.border.opacity(0.4) : GainsColor.lime.opacity(0.40),
              lineWidth: GainsBorder.hairline
            )
        )
        .clipShape(Circle())
        .compositingGroup()
        .shadow(color: isLocked ? .clear : GainsColor.lime.opacity(0.18), radius: 5, y: 1)

        VStack(alignment: .leading, spacing: 2) {
          Text(template.title)
            .font(GainsFont.title(15))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          HStack(spacing: GainsSpacing.xs) {
            Text(String(format: "%.1f km", template.targetDistanceKm))
            Text("·").foregroundStyle(GainsColor.softInk.opacity(0.4))
            Text("\(template.targetDurationMinutes) Min")
            Text("·").foregroundStyle(GainsColor.softInk.opacity(0.4))
            Text(template.targetPaceLabel)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .font(GainsFont.label(10))
          .tracking(0.4)
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(1)
        }

        Spacer(minLength: 6)

        // Polish-Loop 140 (2026-05-14): Play-CTA mit Inner-Light + Glow,
        // damit der CTA-Affordance auf den ersten Blick lesbar ist.
        ZStack {
          Circle()
            .fill(isLocked ? GainsColor.background.opacity(0.6) : GainsColor.lime)
          if !isLocked {
            Circle()
              .fill(
                LinearGradient(
                  colors: [
                    Color.white.opacity(0.32),
                    Color.white.opacity(0.00)
                  ],
                  startPoint: .top,
                  endPoint: .center
                )
              )
              .blendMode(.plusLighter)
          }
          Image(systemName: "play.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(isLocked ? GainsColor.softInk : GainsColor.onLime)
            .offset(x: 1)
        }
        .frame(width: 28, height: 28)
        .compositingGroup()
        .shadow(color: isLocked ? .clear : GainsColor.lime.opacity(0.28), radius: 6, y: 2)
      }
      .padding(.horizontal, GainsSpacing.s)
      .padding(.vertical, GainsSpacing.tight)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
    .disabled(isLocked)
  }

  // MARK: - Run-Activity-Card
  //
  // A9: Aufgeräumte Hierarchie:
  //   1. Eyebrow-Zeile (Datum + Route, optional „ZULETZT" als Lime-Eyebrow)
  //   2. Title (Lauf-Name)
  //   3. Stat-Strip: 3–4 Zellen, gleiche Höhe, Hairline-Trenner
  //   4. Optionaler Splits-Bar-Strip mit „KILOMETER-SPLITS"-Eyebrow
  //   5. Footer „Erneut laufen" als unterer Action-Stripe (durch Trenner getrennt)
  //
  // Vorher waren Padding-Werte zwischen den Zonen ungleichmäßig (16/12/14/4)
  // und der Footer-Button hatte kein Trenner-Pendant.

  private func runActivityCard(_ run: CompletedRunSummary, isLatest: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // 0. Mini-Map-Kopf (Strava-Look). Outdoor mit Route-Polyline, Indoor /
      // ohne GPS ein dezentes Fallback-Panel mit Modus-Glyphe. Die Card
      // clippt via `gainsCardStyle()` automatisch die oberen Ecken.
      runActivityMap(run)

      // 1. Eyebrow + Title
      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        HStack(spacing: GainsSpacing.xsPlus) {
          if isLatest {
            Text("ZULETZT")
              .font(GainsFont.eyebrow(9))
              .tracking(GainsTracking.eyebrow)
              .foregroundStyle(GainsColor.lime)
          }
          Image(systemName: run.modality.systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
          Text(run.finishedAt.formatted(date: .abbreviated, time: .omitted).uppercased())
            .font(GainsFont.eyebrow(9))
            .tracking(GainsTracking.eyebrowTight)
            .foregroundStyle(GainsColor.softInk)
          Text("·")
            .foregroundStyle(GainsColor.softInk.opacity(0.5))
          Text(run.routeName)
            .font(GainsFont.eyebrow(9))
            .tracking(0.8)
            .foregroundStyle(GainsColor.moss)
            .lineLimit(1)
          Spacer(minLength: 0)
          Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.softInk.opacity(0.45))
        }
        Text(run.title)
          .font(GainsFont.title(20))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
      }
      .padding(.horizontal, GainsSpacing.m)
      .padding(.top, GainsSpacing.m)
      .padding(.bottom, GainsSpacing.m)

      // 2. Stat-Strip — Clean-Glass (2026-05-29): kein dunkles Inset-Panel
      // mehr, sondern Werte direkt auf der Glas-Karte. Wert oben / Label
      // drunter, links ausgerichtet (Strava-Hierarchie), eine feine Top-
      // Hairline trennt vom Titel. Bike sieht km/h statt Pace, Indoor
      // verzichtet auf die Höhen-Spalte (kein GPS).
      HStack(alignment: .top, spacing: GainsSpacing.xs) {
        runStatCell(label: "DISTANZ", value: String(format: "%.2f", run.distanceKm), unit: "km")
        if run.modality.isCycling {
          runStatCell(label: "TEMPO", value: bikeSpeedLabel(run.averagePaceSeconds), unit: "")
        } else {
          runStatCell(label: "PACE", value: runPaceLabel(run.averagePaceSeconds), unit: "")
        }
        runStatCell(label: "DAUER", value: formattedDuration(run.durationMinutes), unit: "")
        if run.elevationGain > 0, !run.modality.isIndoor {
          runStatCell(label: "HÖHE", value: "\(run.elevationGain)", unit: "m")
        }
      }
      .padding(.horizontal, GainsSpacing.m)
      .padding(.top, GainsSpacing.s)
      .padding(.bottom, GainsSpacing.m)
      .overlay(alignment: .top) {
        Rectangle()
          .fill(GainsColor.border.opacity(0.30))
          .frame(height: 0.6)
          .padding(.horizontal, GainsSpacing.m)
      }

      // 3. Splits-Bar-Strip (nur wenn vorhanden)
      if !run.splits.isEmpty {
        runSplitBars(run.splits)
          .padding(.horizontal, GainsSpacing.m)
          .padding(.top, GainsSpacing.m)
          .padding(.bottom, GainsSpacing.m)
      }

      Rectangle()
        .fill(GainsColor.border.opacity(0.45))
        .frame(height: 0.6)

      // 4. Footer-Action — modality-aware (P2-7).
      Button {
        guard store.activeWorkout == nil else { return }
        store.startRunLike(run)
        if store.activeRun != nil {
          isShowingRunTracker = true
        }
      } label: {
        HStack(spacing: GainsSpacing.xs) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 11, weight: .semibold))
          Text(repeatActionLabel(for: run.modality))
            .font(GainsFont.eyebrow(10))
            .tracking(1.4)
        }
        .foregroundStyle(store.activeRun == nil ? GainsColor.lime : GainsColor.softInk)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
      }
      .buttonStyle(.plain)
      .disabled(store.activeRun != nil)
    }
    .gainsCardStyle()
  }

  // MARK: - Mini-Map-Kopf der Activity-Card
  //
  // Wiederverwendung des Map-Patterns aus `RunRoutesView.routeCard`: stille
  // (disabled) Map mit Route-Polyline + Start-/End-Punkt. Lauf = Lime,
  // Rad = Cool-Accent. Indoor/ohne GPS-Spur ein Fallback-Panel.

  @ViewBuilder
  private func runActivityMap(_ run: CompletedRunSummary) -> some View {
    let accent = run.modality.isCycling ? GainsColor.accentCool : GainsColor.lime
    if run.routeCoordinates.count > 1 {
      Map(position: .constant(.region(runRegion(run)))) {
        MapPolyline(coordinates: run.routeCoordinates)
          .stroke(accent, lineWidth: 4)
        if let start = run.routeCoordinates.first {
          Annotation("", coordinate: start) {
            Circle().fill(.white).frame(width: 10, height: 10)
              .overlay(Circle().stroke(accent, lineWidth: 2))
          }
        }
        if let end = run.routeCoordinates.last {
          Annotation("", coordinate: end) {
            Circle().fill(accent).frame(width: 12, height: 12)
              .overlay(Circle().stroke(.white, lineWidth: 2))
          }
        }
      }
      .mapStyle(.standard(elevation: .flat))
      .frame(height: 118)
      .disabled(true)
      .allowsHitTesting(false)
    } else {
      ZStack {
        GainsColor.surfaceDeep
        VStack(spacing: GainsSpacing.xs) {
          Image(systemName: run.modality.systemImage)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
          Text(run.modality.isIndoor ? "INDOOR · KEINE ROUTE" : "KEINE GPS-SPUR")
            .font(GainsFont.eyebrow(9))
            .tracking(GainsTracking.eyebrowTight)
            .foregroundStyle(GainsColor.softInk)
        }
      }
      .frame(height: 118)
    }
  }

  /// Karten-Region aus den Route-Koordinaten (mit neutralem Greenwich-Fallback
  /// bei leerer/korrupter Spur — analog `RunRoutesView.routeRegion`).
  private func runRegion(_ run: CompletedRunSummary) -> MKCoordinateRegion {
    let fallback = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
      span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
    )
    let coords = run.routeCoordinates
    guard !coords.isEmpty else { return fallback }
    let lats = coords.map(\.latitude)
    let lons = coords.map(\.longitude)
    guard
      let minLat = lats.min(), let maxLat = lats.max(),
      let minLon = lons.min(), let maxLon = lons.max()
    else { return fallback }
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
      ),
      span: MKCoordinateSpan(
        latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
        longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
      )
    )
  }

  private func runSplitBars(_ splits: [RunSplit]) -> some View {
    let displayed = Array(splits.prefix(8))
    let paces = displayed.map(\.paceSeconds).filter { $0 > 0 }
    let minPace = paces.min() ?? 1
    let maxPace = max(paces.max() ?? 1, minPace + 1)

    return VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text("KILOMETER-SPLITS")
        .font(GainsFont.eyebrow(9))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)

      HStack(alignment: .bottom, spacing: GainsSpacing.xs) {
        ForEach(displayed, id: \.id) { split in
          let pace = split.paceSeconds
          let fraction: Double = pace > 0
            ? 1.0 - (Double(pace - minPace) / Double(maxPace - minPace)) * 0.6
            : 0.15
          let isFastest = pace == minPace && pace > 0

          VStack(spacing: GainsSpacing.xxs) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .fill(isFastest ? GainsColor.lime : GainsColor.lime.opacity(0.45 + fraction * 0.35))
              .frame(height: max(fraction * 44, 6))

            Text("\(split.index)")
              .font(GainsFont.eyebrow(8))
              .tracking(0.5)
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 56, alignment: .bottom)

      HStack {
        Text("schnell \(runPaceLabel(minPace))")
          .font(GainsFont.eyebrow(9))
          .foregroundStyle(GainsColor.lime)
        Spacer()
        Text("langsam \(runPaceLabel(maxPace))")
          .font(GainsFont.eyebrow(9))
          .foregroundStyle(GainsColor.softInk)
      }
    }
  }

  private func runStatCell(label: String, value: String, unit: String) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(GainsFont.metricMono(18))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        if !unit.isEmpty {
          Text(unit)
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
        }
      }
      Text(label)
        .font(GainsFont.eyebrow(9))
        .tracking(1.2)
        .foregroundStyle(GainsColor.mutedInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func formattedDuration(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    return h > 0 ? "\(h):\(String(format: "%02d", m))" : "\(m) min"
  }

  private func runPaceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:-- /km" }
    let minutes = seconds / 60
    let secs = seconds % 60
    return String(format: "%d:%02d /km", minutes, secs)
  }

  /// Wandelt eine Pace (Sek./km) in km/h um. Wird nur für Rad-Sessions
  /// genutzt (Distanz/Pace ist intern weiterhin in Sekunden gespeichert,
  /// damit der gemeinsame Codepfad mit Lauf erhalten bleibt).
  private func bikeSpeedLabel(_ secondsPerKm: Int) -> String {
    guard secondsPerKm > 0 else { return "--,- km/h" }
    let kmh = 3600.0 / Double(secondsPerKm)
    return String(format: "%.1f km/h", kmh)
  }

  // MARK: - Stats: Wochen-Distanz

  private var weeklyDistanceChartSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack {
        SlashLabel(
          parts: ["WOCHE", "DISTANZ"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        Text(String(format: "%.1f km", store.weeklyRunDistanceKm))
          .font(GainsFont.metricMono(16))
          .foregroundStyle(GainsColor.ink)
      }

      let days = store.weeklyRunsByDay
      let maxKm = max(days.map(\.km).max() ?? 1, 1)

      HStack(alignment: .bottom, spacing: GainsSpacing.xs) {
        ForEach(days) { day in
          VStack(spacing: GainsSpacing.xs) {
            if day.km > 0 {
              Text(String(format: "%.1f", day.km))
                .font(GainsFont.eyebrow(8))
                .tracking(0.5)
                .foregroundStyle(day.isToday ? GainsColor.moss : GainsColor.softInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            } else {
              Text("")
                .font(GainsFont.eyebrow(8))
            }

            // Polish-Loop 147 (2026-05-14): Weekly-Distance-Bars mit Gradient
            // + plusLighter-Inner-Light, „heute" sticht durch Glow heraus.
            GeometryReader { geo in
              VStack(spacing: 0) {
                Spacer()
                let fraction = day.km > 0 ? max(day.km / maxKm, 0.06) : 0.04
                let isToday = day.isToday
                Group {
                  if day.km > 0 {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                      .fill(
                        LinearGradient(
                          colors: isToday
                            ? [GainsColor.lime, GainsColor.lime.opacity(0.78)]
                            : [GainsColor.lime.opacity(0.62), GainsColor.lime.opacity(0.42)],
                          startPoint: .top,
                          endPoint: .bottom
                        )
                      )
                      .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                          .fill(
                            LinearGradient(
                              colors: [
                                Color.white.opacity(isToday ? 0.30 : 0.10),
                                Color.white.opacity(0.00)
                              ],
                              startPoint: .top,
                              endPoint: .center
                            )
                          )
                          .blendMode(.plusLighter)
                      )
                      .shadow(color: isToday ? GainsColor.lime.opacity(0.28) : .clear, radius: 5, y: -1)
                  } else {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                      .fill(GainsColor.border.opacity(0.5))
                  }
                }
                .frame(height: geo.size.height * fraction)
              }
            }
            .frame(height: 72)

            Text(day.dayLabel)
              .font(GainsFont.eyebrow(9))
              .tracking(1.0)
              .foregroundStyle(day.isToday ? GainsColor.ink : GainsColor.softInk)
              .fontWeight(day.isToday ? .semibold : .regular)
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
    .padding(GainsSpacing.l)
    .gainsCardStyle()
  }

  // MARK: - Stats: YTD

  private var ytdStatsSection: some View {
    let year = Calendar.current.component(.year, from: Date())
    let hours = store.yearlyRunDurationMinutes / 60
    let minutes = store.yearlyRunDurationMinutes % 60
    let timeString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) min"

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["\(year)", "GESAMT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: GainsSpacing.tight), GridItem(.flexible(), spacing: GainsSpacing.tight)],
        spacing: GainsSpacing.tight
      ) {
        GainsMetricTile(
          label: "DISTANZ",
          value: String(format: "%.0f", store.yearlyRunDistanceKm),
          unit: "km",
          style: .onyx
        )
        GainsMetricTile(
          label: "LÄUFE",
          value: "\(store.yearlyRunCount)",
          unit: "absolviert",
          style: .onyx
        )
        GainsMetricTile(
          label: "ZEIT",
          value: timeString,
          unit: "auf der Strecke",
          style: .onyx
        )
        GainsMetricTile(
          label: "HÖHE",
          value: "\(store.yearlyElevationGain)",
          unit: "m gesamt",
          style: .onyx
        )
      }
    }
  }

  // MARK: - Stats: Pace-Zonen

  private var paceZonesSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      SlashLabel(
        parts: ["PACE", "ZONEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      let zones = store.paceZones
      if zones.isEmpty {
        Text("Starte deine ersten Läufe, um deine Pace-Zonen zu sehen.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .padding(.vertical, GainsSpacing.xsPlus)
      } else {
        VStack(spacing: GainsSpacing.tight) {
          let zoneColors: [Color] = [
            GainsColor.lime.opacity(0.5),
            GainsColor.lime.opacity(0.75),
            GainsColor.lime,
            GainsColor.moss,
          ]
          ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
            VStack(alignment: .leading, spacing: GainsSpacing.xs) {
              HStack {
                Text(zone.label)
                  .font(GainsFont.title(14))
                  .foregroundStyle(GainsColor.ink)
                Text(zone.description)
                  .font(GainsFont.body(12))
                  .foregroundStyle(GainsColor.softInk)
                Spacer()
                Text(String(format: "%.0f%%", zone.fraction * 100))
                  .font(GainsFont.metricMono(14))
                  .foregroundStyle(GainsColor.ink)
              }
              // Polish-Loop 146 (2026-05-14): Pace-Zone-Bars mit Track-Border,
              // gradient-Fill und plusLighter-Inner-Light. Jede Zone behält
              // ihren Lime/Moss-Akzent, gewinnt aber durch den Gradient
              // visuelle Tiefe.
              GeometryReader { geo in
                let color = zoneColors[min(index, zoneColors.count - 1)]
                ZStack(alignment: .leading) {
                  RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(GainsColor.background.opacity(0.55))
                  RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(GainsColor.border.opacity(0.35), lineWidth: GainsBorder.hairline)
                  RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                      LinearGradient(
                        colors: [color.opacity(0.85), color],
                        startPoint: .leading,
                        endPoint: .trailing
                      )
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                          LinearGradient(
                            colors: [
                              Color.white.opacity(0.22),
                              Color.white.opacity(0.00)
                            ],
                            startPoint: .top,
                            endPoint: .center
                          )
                        )
                        .blendMode(.plusLighter)
                    )
                    .frame(width: max(geo.size.width * zone.fraction, 4))
                }
                .compositingGroup()
              }
              .frame(height: 8)
            }
          }
        }
      }
    }
    .padding(GainsSpacing.l)
    .gainsCardStyle()
  }

  // MARK: - Stats: Distanz-PRs
  //
  // 2026-05-03 (P1-3): Vorher dieselbe Tabelle wie der Quick-Strip oben —
  // doppelte Information ohne Mehrwert im STATS-Tab. Jetzt Detail-Variante:
  // pro PR eine Karte mit Wert + zusätzlichem Datum, Tab-Footer für „PR
  // verbessern" zum Setup-Sheet (zukünftig). Bike-Bestzeiten kommen als
  // separate Sektion darunter, sobald welche existieren.

  private var distancePRsSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        SlashLabel(
          parts: ["BESTZEITEN", "LAUF"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        let prs = store.distancePRs
        if prs.isEmpty {
          EmptyStateView(
            style: .inline,
            title: "Noch keine Bestzeiten",
            message: "Läufe ab 5 km reichen, um deine ersten PR-Zeiten zu sammeln.",
            icon: "trophy"
          )
        } else {
          VStack(spacing: GainsSpacing.xsPlus) {
            ForEach(Array(prs.enumerated()), id: \.element.id) { index, pr in
              prDetailCard(pr, accent: prAccentColor(at: index))
            }
          }
        }
      }

      if !store.bikePersonalBests.isEmpty {
        VStack(alignment: .leading, spacing: GainsSpacing.s) {
          SlashLabel(
            parts: ["BESTWERTE", "RAD"], primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk)

          VStack(spacing: GainsSpacing.xsPlus) {
            ForEach(Array(store.bikePersonalBests.enumerated()), id: \.element.id) { index, pr in
              prDetailCard(pr, accent: prAccentColor(at: index))
            }
          }
        }
      }
    }
  }

  /// Detail-Karte pro PR — wird im STATS-Tab gerendert (P1-3-Variante).
  /// Trophy-Icon links als Akzent, in der rechten Spalte Wert + Kontext-
  /// Zeile mit Route.
  private func prDetailCard(_ pr: RunPersonalBest, accent: Color) -> some View {
    HStack(spacing: GainsSpacing.m) {
      // Polish-Loop 152 (2026-05-14): PR-Trophy-Badge im Cardio-Stats-Tab
      // mit plusLighter-Inner-Light und Akzent-Glow — passt zum
      // Trophy-Badge in GymStatsTab (Loop 142).
      ZStack {
        Circle()
          .fill(accent.opacity(0.14))
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
        Image(systemName: "trophy.fill")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(accent)
      }
      .frame(width: 36, height: 36)
      .overlay(
        Circle().strokeBorder(accent.opacity(0.4), lineWidth: GainsBorder.hairline)
      )
      .compositingGroup()
      .shadow(color: accent.opacity(0.22), radius: 5, y: 1)

      VStack(alignment: .leading, spacing: 2) {
        Text(pr.title)
          .font(GainsFont.eyebrow(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
        Text(pr.value)
          .font(GainsFont.metricMono(20))
          .foregroundStyle(GainsColor.ink)
      }

      Spacer(minLength: 8)

      Text(pr.context)
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 130, alignment: .trailing)
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  /// Lime-Schattierungen für PR-Karten — frischere visuelle Hierarchie.
  private func prAccentColor(at index: Int) -> Color {
    switch index % 4 {
    case 0: return GainsColor.lime
    case 1: return GainsColor.moss
    case 2: return GainsColor.lime.opacity(0.75)
    default: return GainsColor.lime.opacity(0.55)
    }
  }

  // MARK: - Quick-PR-Strip
  //
  // Kompakte Chip-Leiste mit Distanz-Bestzeiten (5K / 10K / Halbmarathon /
  // Marathon). Sitzt direkt unter der Hero-Card — immer im sichtbaren Bereich,
  // ohne dass Nutzer in den STATS-Tab wechseln müssen.
  // Wird ausgeblendet, wenn noch keine PRs existieren.

  private var runQuickPRStrip: some View {
    quickPRStrip(label: "BESTZEITEN", prs: store.distancePRs)
  }

  /// Bike-Variante des Quick-PR-Strips. Wird im Hub angezeigt, sobald die
  /// Modalität auf Rad steht und mindestens ein Bike-PR existiert.
  private var bikeQuickPRStrip: some View {
    quickPRStrip(label: "RAD-RECORDS", prs: store.bikePersonalBests)
  }

  private func quickPRStrip(label: String, prs: [RunPersonalBest]) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: [label], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        Button {
          selectedTab = .stats
        } label: {
          HStack(spacing: GainsSpacing.xxs) {
            Text("Alle Stats")
              .font(GainsFont.eyebrow(9))
              .tracking(GainsTracking.eyebrowTight)
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .bold))
          }
          .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.xsPlus) {
          ForEach(prs) { pr in
            prChip(pr)
          }
        }
        .padding(.vertical, 2)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  /// Modus-spezifischer Footer-Text für die Run-Activity-Card.
  private func repeatActionLabel(for modality: CardioModality) -> String {
    switch modality {
    case .run:         return "Erneut laufen"
    case .bikeOutdoor: return "Erneut fahren"
    case .bikeIndoor:  return "Wieder am Heimtrainer"
    }
  }

  private func prChip(_ pr: RunPersonalBest) -> some View {
    // Polish-Loop 153 (2026-05-14): Quick-PR-Chip mit Glas-Komposition +
    // sehr dezentem Lime-Glow-Edge, damit die horizontale Scroll-Leiste
    // sich vom Card-Background absetzt und premium wirkt.
    HStack(spacing: GainsSpacing.xs) {
      Image(systemName: "trophy.fill")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(GainsColor.lime)
        .shadow(color: GainsColor.lime.opacity(0.225), radius: 2)
      Text(pr.title)
        .font(GainsFont.eyebrow(9))
        .tracking(GainsTracking.eyebrowTight)
        .foregroundStyle(GainsColor.softInk)
      Text("·")
        .foregroundStyle(GainsColor.softInk.opacity(0.5))
      Text(pr.value)
        .font(GainsFont.metricMono(13))
        .foregroundStyle(GainsColor.ink)
    }
    .padding(.horizontal, GainsSpacing.s)
    .frame(height: 32)
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
      Capsule().strokeBorder(
        LinearGradient(
          colors: [GainsColor.lime.opacity(0.45), GainsColor.lime.opacity(0.12)],
          startPoint: .top,
          endPoint: .bottom
        ),
        lineWidth: GainsBorder.hairline
      )
    )
    .clipShape(Capsule())
    .compositingGroup()
  }

  // MARK: - Helpers

  /// Einheitlicher Hero-CTA-Pfad (P1-2 + P0-3): Startet eine neue Quick-
  /// Session in der gerade gewählten Modalität oder öffnet die laufende.
  /// Der Hero sitzt im Hub-Zustand, also ist der Tracker hier nicht bereits
  /// präsentiert. Ein direktes `true` vermeidet das fragile `false → true`-
  /// Toggle, das SwiftUI in demselben Tick schlucken kann.
  private func startOrResumeCardio() {
    if store.activeRun == nil {
      store.startQuickRun(modality: preferredModality)
    }
    if store.activeRun != nil {
      isShowingRunTracker = true
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
  @State private var searchText = ""
  @State private var selectedMuscle = "Alle"
  @State private var selectedExercises: [EditableExercise] = []
  @State private var editingExerciseID: UUID? = nil  // welcher Stepper offen ist
  @State private var inspectingExercise: ExerciseLibraryItem? = nil

  // 2026-05-03 Cleanup: Manuelle Split-Auswahl entfällt — der User
  // entscheidet selbst, was er trainiert. Anzeige-Tag wird aus den
  // ausgewählten Übungen abgeleitet (siehe `derivedSplit`).
  /// Leitet ein Kurz-Tag aus den ausgewählten Übungen ab — die
  /// dominanteste Muskelgruppe oder „Eigenes" als Fallback.
  private var derivedSplit: String {
    guard !selectedExercises.isEmpty else { return "Eigenes" }
    let counts = selectedExercises.reduce(into: [String: Int]()) { acc, ex in
      acc[ex.base.primaryMuscle, default: 0] += 1
    }
    return counts.max(by: { $0.value < $1.value })?.key ?? "Eigenes"
  }

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
          VStack(alignment: .leading, spacing: GainsSpacing.xl) {
            // Header
            screenHeader(
              eyebrow: isEditing ? "WORKOUT / BEARBEITEN" : "WORKOUT / ERSTELLEN",
              title: isEditing ? "Training bearbeiten" : "Eigenes Training",
              subtitle: isEditing
                ? "Passe Name und Übungen an – deine Pläne aktualisieren sich automatisch."
                : "Drei Schritte: Name, Übungen wählen, Sätze & Reps anpassen."
            )

            nameSection
            selectedExercisesSection
            exerciseLibrarySection
            // Spacer für den sticky Button
            Color.clear.frame(height: 80)
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.m)
        }
        // ── Sticky Save-Button ─────────────────────────────────────
        stickyActionBar
          .padding(.horizontal, GainsSpacing.l)
          .padding(.bottom, GainsSpacing.l)
      }
      .onAppear {
        if let plan = editingPlan {
          workoutName = plan.title
          // Reconstruct EditableExercise from plan exercises.
          // Hinweis: `plan.split` wird beim Speichern automatisch neu
          // aus den Übungen hergeleitet — wir brauchen ihn hier nicht
          // mehr in den State übernehmen.
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
          .accessibilityLabel("Schließen")
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

  // MARK: - Name (Schritt 1)
  //
  // 2026-05-03 Cleanup: Vorher gab es hier zusätzlich Split-Chips.
  // Die sind weg — der User entscheidet selbst, was er trainiert. Das
  // Anzeige-Tag wird beim Speichern automatisch aus den ausgewählten
  // Übungen abgeleitet (siehe `derivedSplit`).

  private var nameSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      SlashLabel(
        parts: ["NAME", "WORKOUT"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      HStack(spacing: GainsSpacing.tight) {
        Image(systemName: "pencil")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
        TextField("z. B. Push Day · Pull A · Beine schwer", text: $workoutName)
          .textInputAutocapitalization(.words)
          .autocorrectionDisabled()
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
      }
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 52)
      // Eingabefeld bleibt bewusst flach/recessed (kein Glas-Float) — der
      // State-Rahmen (lime bei Eingabe) trägt das Feedback.
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(
            workoutName.isEmpty ? GainsColor.border.opacity(0.5) : GainsColor.lime.opacity(0.5),
            lineWidth: 1.5
          )
      )

      // Live-Hinweis: Was wird beim Speichern getaggt?
      if !selectedExercises.isEmpty {
        HStack(spacing: GainsSpacing.xs) {
          Image(systemName: "tag.fill")
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(GainsColor.lime)
          Text("Auto-Tag · \(derivedSplit.uppercased())")
            .font(GainsFont.eyebrow)
            .tracking(1.4)
            .foregroundStyle(GainsColor.softInk)
          Text("· \(selectedExercises.count) Übungen")
            .font(GainsFont.caption)
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(.top, 2)
      }
    }
    .padding(GainsSpacing.l)
    .gainsCardStyle()
  }

  // MARK: - Ausgewählte Übungen (Drag-to-Reorder + Sets/Reps Stepper)

  @ViewBuilder
  private var selectedExercisesSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      HStack {
        SlashLabel(
          parts: ["AUSGEWÄHLT", "\(selectedExercises.count) ÜBUNGEN"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        if !selectedExercises.isEmpty {
          Text("\(selectedExercises.count) ausgewählt")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrow)
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
                .padding(.horizontal, GainsSpacing.m)
            }
          }
        }
        // A13 (Cleaner-Pass): cornerRadius 18→16, lineWidth 1→0.6 (hairline).
        .gainsCardStyle(GainsColor.card)
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
      HStack(spacing: GainsSpacing.s) {
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

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(ex.base.name)
            .font(GainsFont.headline)
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Text("\(ex.base.primaryMuscle) · \(ex.base.equipment)")
            .font(GainsFont.caption)
            .foregroundStyle(GainsColor.softInk)
        }

        Spacer()

        // Sets × Reps badge — antippen öffnet Stepper
        Button {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            editingExerciseID = isOpen ? nil : ex.id
          }
        } label: {
          HStack(spacing: GainsSpacing.xxs) {
            Text("\(ex.sets)×\(ex.reps)")
              .font(GainsFont.metricSmall)
              .foregroundStyle(isOpen ? GainsColor.ink : GainsColor.moss)
            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(isOpen ? GainsColor.ink : GainsColor.moss)
          }
          .padding(.horizontal, GainsSpacing.s)
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
        .accessibilityLabel("Übung entfernen")
      }
      .padding(.horizontal, GainsSpacing.m)
      .padding(.vertical, GainsSpacing.m)

      // ── Inline Stepper (nur wenn offen) ──────────────────────────
      if isOpen {
        HStack(spacing: 0) {
          builderStepper(
            label: "SÄTZE",
            value: Binding(
              // Bounds-Guard: selectedExercises kann sich ändern während
              // Binding noch existiert (z.B. paralleles Delete mit Animation).
              get: { index < selectedExercises.count ? selectedExercises[index].sets : 1 },
              set: { if index < selectedExercises.count { selectedExercises[index].sets = $0 } }
            ),
            range: 1...8
          )
          Divider()
            .background(GainsColor.border.opacity(0.4))
            .frame(height: 50)
          builderStepper(
            label: "WDHL.",
            value: Binding(
              get: { index < selectedExercises.count ? selectedExercises[index].reps : 1 },
              set: { if index < selectedExercises.count { selectedExercises[index].reps = $0 } }
            ),
            range: 1...30
          )
        }
        .background(GainsColor.lime.opacity(0.08))
        .padding(.horizontal, GainsSpacing.m)
        .padding(.bottom, GainsSpacing.m)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  private func builderStepper(label: String, value: Binding<Int>, range: ClosedRange<Int>)
    -> some View
  {
    HStack(spacing: GainsSpacing.m) {
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
          .font(GainsFont.metric)
          .foregroundStyle(GainsColor.ink)
        Text(label)
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
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
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      SlashLabel(
        parts: ["GYM", "BIBLIOTHEK"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      // Suchfeld
      HStack(spacing: GainsSpacing.tight) {
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
          .accessibilityLabel("Suche leeren")
        }
      }
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 48)
      // Such-/Filterfeld bleibt flach (recessed Input, kein Glas-Float).
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(GainsColor.border.opacity(0.6), lineWidth: 1)
      )

      // Muskelgruppen-Filter-Chips
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.xsPlus) {
          ForEach(allMuscles, id: \.self) { muscle in
            Button {
              selectedMuscle = muscle
            } label: {
              Text(muscle.uppercased())
                .font(GainsFont.eyebrow)
                .tracking(GainsTracking.eyebrowTight)
                .foregroundStyle(selectedMuscle == muscle ? GainsColor.ink : GainsColor.softInk)
                .padding(.horizontal, GainsSpacing.m)
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
        HStack(spacing: GainsSpacing.s) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(GainsColor.softInk)
          Text("Keine Übung gefunden. Probiere einen anderen Begriff.")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(GainsSpacing.l)
        .gainsCardStyle()
      } else {
        // Perf (2026-05-31): LazyVStack statt VStack — die ~105 Bibliotheks-
        // Zeilen werden erst beim Scrollen gebaut. `lastID` einmal vor dem
        // ForEach binden, statt `filteredExercises.last?.id` pro Zeile neu zu
        // filtern (war O(n²)).
        let lastID = filteredExercises.last?.id
        LazyVStack(spacing: 0) {
          ForEach(filteredExercises) { exercise in
            libraryExerciseRow(exercise)
            if exercise.id != lastID {
              Divider()
                .background(GainsColor.border.opacity(0.3))
                .padding(.horizontal, GainsSpacing.m)
            }
          }
        }
        // A13 (Cleaner-Pass): cornerRadius 18→16, lineWidth 1→0.6.
        .gainsCardStyle(GainsColor.card)
      }
    }
  }

  private func libraryExerciseRow(_ exercise: ExerciseLibraryItem) -> some View {
    let selected = isSelected(exercise)
    return HStack(spacing: GainsSpacing.s) {
      // Muskelgruppen-Farbpunkt
      Circle()
        .fill(muscleColor(exercise.primaryMuscle))
        .frame(width: 10, height: 10)

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text(exercise.name)
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
        Text("\(exercise.primaryMuscle) · \(exercise.equipment)")
          .font(GainsFont.caption)
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      Text("\(exercise.defaultSets)×\(exercise.defaultReps)")
        .font(GainsFont.metricSmall)
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
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
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
      HStack(spacing: GainsSpacing.tight) {
        Image(systemName: canSave ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 16, weight: .semibold))
        Text(isEditing ? "Änderungen speichern" : "Workout speichern")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
        if !selectedExercises.isEmpty {
          Text("· \(selectedExercises.count) Übungen")
            .font(GainsFont.caption)
            .opacity(0.78)
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
      // A13 (Cleaner-Pass): cornerRadius 18→16, Glow 0.35→0.18, Radius 12→8.
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .shadow(
        color: canSave ? GainsColor.lime.opacity(0.18) : .clear,
        radius: 8, x: 0, y: 4)
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

    // Split wird automatisch aus den getroffenen Übungen abgeleitet —
    // siehe `derivedSplit`. Es gibt keine User-Auswahl mehr.
    let autoSplit = derivedSplit

    if let plan = editingPlan {
      if let updated = store.updateWorkout(
        plan, named: trimmedName, split: autoSplit, exercises: libraryItems)
      {
        onSaved?(updated)
      }
    } else {
      if let created = store.saveWorkout(
        named: trimmedName, split: autoSplit, exercises: libraryItems)
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
