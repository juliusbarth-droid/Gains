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
  case feed
  case routes
  case segments
  case workouts
  case stats

  var id: String { rawValue }

  /// Kurzer, getrackter Label-Text für die segmentierte Tab-Bar.
  var label: String {
    switch self {
    case .feed:     return "FEED"
    case .routes:   return "ROUTEN"
    case .segments: return "SEGMENTE"
    case .workouts: return "PLÄNE"
    case .stats:    return "DATEN"
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
  @State private var selectedTab: RunHubTab = .feed
  @State private var pendingAfterSelectedRun: (() -> Void)? = nil
  @State private var pendingAfterPresentedWorkout: (() -> Void)? = nil

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
    guard onboardingCompletedAt > 0 else { return false }
    let completedAt = Date(timeIntervalSince1970: onboardingCompletedAt)
    let hoursSince = Date().timeIntervalSince(completedAt) / 3600
    guard hoursSince >= 0, hoursSince < 24 else { return false }
    if !store.runHistory.isEmpty { return false }
    return true
  }

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        trainHeader
        if isInRunDayOneWindow {
          dayOneRunGuide
        }
        runHeroCard
        if store.activeRun != nil {
          runLiveBanner
        }

        // Bestzeiten direkt sichtbar — ohne in den STATS-Tab wechseln zu
        // müssen. Bike-Quick-Strip nur, wenn der Hub-Modus auf Rad steht
        // und Bike-Bestzeiten vorhanden sind.
        if displayedModality == .run && !store.distancePRs.isEmpty {
          runQuickPRStrip
        }
        if displayedModality.isCycling && !store.bikePersonalBests.isEmpty {
          bikeQuickPRStrip
        }

        tabPicker
        tabContent
      }
    }
    .sheet(isPresented: $isShowingRunTracker) {
      RunTrackerView()
        .environmentObject(store)
    }
    .sheet(item: $selectedRun, onDismiss: { runPending(&pendingAfterSelectedRun) }) { run in
      RunDetailSheet(run: run) {
        store.startRunLike(run)
        isShowingRunTracker = false
        pendingAfterSelectedRun = { isShowingRunTracker = true }
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
        isShowingRunTracker = false
        pendingAfterPresentedWorkout = { isShowingRunTracker = true }
        presentedWorkout = nil
      }
      .environmentObject(store)
    }
    .sheet(isPresented: $showsSegmentCreator) {
      SegmentCreatorSheet(runs: store.runHistory)
        .environmentObject(store)
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
  @ViewBuilder
  private var modalityToggle: some View {
    HStack(spacing: 4) {
      ForEach(CardioModality.allCases, id: \.self) { modality in
        let isActive = displayedModality == modality
        let isLocked = store.activeRun != nil && store.activeRun?.modality != modality

        Button {
          guard store.activeRun == nil else { return }
          UISelectionFeedbackGenerator().selectionChanged()
          preferredModalityRaw = modality.rawValue
        } label: {
          Image(systemName: modality.systemImage)
            .font(.system(size: 12, weight: isActive ? .bold : .semibold))
            .foregroundStyle(
              isActive ? GainsColor.onLime
              : isLocked ? GainsColor.softInk.opacity(0.4)
              : GainsColor.softInk
            )
            .frame(width: 32, height: 28)
            .background(
              RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
                .fill(isActive ? GainsColor.lime : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel("\(modality.displayName) wählen")
      }
    }
    .padding(3)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(GainsColor.border.opacity(0.5), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  // MARK: - Day-One Run Guide
  //
  // Mini-Tour, die den Cardio-Hub erklärt: Hero startet sofort einen Lauf,
  // die Sub-Tabs darunter sammeln Verlauf und Tools. Bewusst dezent — der
  // Hero und der „Lauf starten"-CTA sind die Bühne, der Banner liefert nur
  // mentales Modell. Verschwindet nach erstem abgeschlossenem Lauf.

  private var dayOneRunGuide: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
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

      VStack(spacing: 6) {
        dayOneRunTourRow(icon: "list.bullet.clipboard.fill", title: "Pläne",
                         detail: "Easy, Tempo, Intervalle, Long Run.")
        dayOneRunTourRow(icon: "map.fill", title: "Routen",
                         detail: "Gespeicherte Strecken, die du wiederholen willst.")
        dayOneRunTourRow(icon: "chart.bar.fill", title: "Daten",
                         detail: "Volumen, Pace-Trend, Distanz-PRs.")
      }
    }
    .padding(14)
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
    HStack(spacing: 10) {
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

  private func streakBadge(_ days: Int) -> some View {
    HStack(spacing: 6) {
      Image(systemName: "flame.fill")
        .font(.system(size: 11, weight: .bold))
      Text("\(days) TG")
        .font(GainsFont.eyebrow(11))
        .tracking(1.4)
    }
    .foregroundStyle(GainsColor.lime)
    .padding(.horizontal, 12)
    .frame(height: 26)
    .background(GainsColor.lime.opacity(0.14))
    .overlay(
      Capsule().strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.hairline)
    )
    .clipShape(Capsule())
    .shadow(color: GainsColor.lime.opacity(0.35), radius: 10, x: 0, y: 0)
  }

  // MARK: - Live-Banner
  //
  // A9: Aufgeräumt. Drei `GainsMetricTile(.subdued)` statt drei verschiedener
  // Custom-Cells, ein einziger Lime-CTA, gleicher Hairline-Border wie die
  // Hero-Card. Senkt die Höhe spürbar.

  @ViewBuilder
  private var runLiveBanner: some View {
    if let activeRun = store.activeRun {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 8) {
          PulsingDot()
          Text("\(activeRun.modality.shortLabel) AKTIV")
            .font(GainsFont.eyebrow(10))
            .tracking(2.0)
            .foregroundStyle(GainsColor.lime)
          Spacer()
        }

        HStack(spacing: 8) {
          GainsMetricTile(
            label: "DISTANZ",
            value: String(format: "%.2f", activeRun.distanceKm),
            unit: "km",
            style: .subdued
          )
          if activeRun.modality.isCycling {
            GainsMetricTile(
              label: "TEMPO",
              value: bikeSpeedLabel(activeRun.averagePaceSeconds),
              unit: "",
              style: .subdued
            )
          } else {
            GainsMetricTile(
              label: "PACE",
              value: runPaceLabel(activeRun.averagePaceSeconds),
              unit: "/km",
              style: .subdued
            )
          }
          GainsMetricTile(
            label: "PULS",
            value: "\(activeRun.currentHeartRate)",
            unit: "bpm",
            style: .subdued
          )
        }

        // A10: Live-Banner-CTA nutzt jetzt dieselbe Premium-Pille wie die
        // Hero-Card (Gradient + Icon-Plate + atmender Halo) — visueller
        // Anker für „weitermachen" statt flacher Lime-Streifen.
        HeroPrimaryCTAButton(
          title: "Tracker & Karte öffnen",
          icon: "map.fill",
          action: {
            isShowingRunTracker = true
          }
        )
      }
      .padding(16)
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
            .padding(.horizontal, 4)
            .background(
              RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                .fill(isActive ? GainsColor.lime : Color.clear)
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
        }
        .buttonStyle(.plain)
      }
    }
    .padding(4)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  // MARK: - Tab-Content

  @ViewBuilder
  private var tabContent: some View {
    switch selectedTab {
    case .feed:
      feedTab
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

  // MARK: - FEED-Tab
  //
  // A9: „LETZTER LAUF"-Card raus — der erste Eintrag im Feed ist derselbe
  // Lauf in identischer Detail-Card. Stattdessen markiert der Feed selbst
  // seinen ersten Eintrag.

  private var feedTab: some View {
    VStack(alignment: .leading, spacing: 18) {
      runningTemplatesSection
      runFeedSection
    }
  }

  // MARK: - STATS-Tab

  private var statsTab: some View {
    VStack(alignment: .leading, spacing: 20) {
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

    return VStack(alignment: .leading, spacing: 8) {
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
        VStack(spacing: 8) {
          ForEach(filtered) { template in
            templateCard(template)
          }
        }
      }
    }
  }

  private func templateCard(_ template: RunTemplate) -> some View {
    Button {
      store.startRun(from: template)
      isShowingRunTracker = true
    } label: {
      HStack(spacing: 12) {
        Image(systemName: template.systemImage)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 30, height: 30)
          .background(GainsColor.lime.opacity(0.14))
          .overlay(Circle().strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: GainsBorder.hairline))
          .clipShape(Circle())

        VStack(alignment: .leading, spacing: 2) {
          Text(template.title)
            .font(GainsFont.title(15))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          HStack(spacing: 5) {
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

        Image(systemName: "play.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(store.activeRun == nil ? GainsColor.onLime : GainsColor.softInk)
          .frame(width: 28, height: 28)
          .background(store.activeRun == nil ? GainsColor.lime : GainsColor.background.opacity(0.6))
          .clipShape(Circle())
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
    .disabled(store.activeRun != nil)
  }

  // MARK: - Run Feed

  private var runFeedSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["AKTIVITÄTEN", "FEED"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        if !store.runHistory.isEmpty {
          Text("\(store.runHistory.count) Sessions")
            .font(GainsFont.eyebrow(9))
            .tracking(1.2)
            .foregroundStyle(GainsColor.softInk)
        }
      }

      if store.runHistory.isEmpty {
        EmptyStateView(
          style: .inline,
          title: "Noch keine Aktivitäten",
          message: "Starte deine erste Cardio-Session — Lauf, Rad oder Heimtrainer. Gains baut den Feed automatisch auf.",
          icon: "tray"
        )
      } else {
        ForEach(Array(store.runHistory.enumerated()), id: \.element.id) { index, run in
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
      // 1. Eyebrow + Title
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          if isLatest {
            Text("ZULETZT")
              .font(GainsFont.eyebrow(9))
              .tracking(1.6)
              .foregroundStyle(GainsColor.lime)
          }
          Image(systemName: run.modality.systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
          Text(run.finishedAt.formatted(date: .abbreviated, time: .omitted).uppercased())
            .font(GainsFont.eyebrow(9))
            .tracking(1.2)
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
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 14)

      // 2. Stat-Strip — Bike-Sessions sehen Geschwindigkeit (km/h) statt Pace
      // (min/km), Indoor-Sessions verzichten auf die Höhen-Spalte (kein GPS).
      HStack(spacing: 0) {
        runStatCell(label: "DISTANZ", value: String(format: "%.2f", run.distanceKm), unit: "km")
        runStatDivider()
        if run.modality.isCycling {
          runStatCell(label: "TEMPO", value: bikeSpeedLabel(run.averagePaceSeconds), unit: "")
        } else {
          runStatCell(label: "PACE", value: runPaceLabel(run.averagePaceSeconds), unit: "")
        }
        runStatDivider()
        runStatCell(label: "DAUER", value: formattedDuration(run.durationMinutes), unit: "")
        if run.elevationGain > 0, !run.modality.isIndoor {
          runStatDivider()
          runStatCell(label: "HÖHE", value: "\(run.elevationGain)", unit: "m")
        }
      }
      .padding(.vertical, 12)
      .background(GainsColor.surfaceDeep.opacity(0.6))

      // 3. Splits-Bar-Strip (nur wenn vorhanden)
      if !run.splits.isEmpty {
        runSplitBars(run.splits)
          .padding(.horizontal, 16)
          .padding(.top, 14)
          .padding(.bottom, 14)
      }

      Rectangle()
        .fill(GainsColor.border.opacity(0.45))
        .frame(height: 0.6)

      // 4. Footer-Action — modality-aware (P2-7).
      Button {
        store.startRunLike(run)
        isShowingRunTracker = true
      } label: {
        HStack(spacing: 6) {
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

  private func runSplitBars(_ splits: [RunSplit]) -> some View {
    let displayed = Array(splits.prefix(8))
    let paces = displayed.map(\.paceSeconds).filter { $0 > 0 }
    let minPace = paces.min() ?? 1
    let maxPace = max(paces.max() ?? 1, minPace + 1)

    return VStack(alignment: .leading, spacing: 8) {
      Text("KILOMETER-SPLITS")
        .font(GainsFont.eyebrow(9))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      HStack(alignment: .bottom, spacing: 5) {
        ForEach(displayed, id: \.id) { split in
          let pace = split.paceSeconds
          let fraction: Double = pace > 0
            ? 1.0 - (Double(pace - minPace) / Double(maxPace - minPace)) * 0.6
            : 0.15
          let isFastest = pace == minPace && pace > 0

          VStack(spacing: 4) {
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
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.eyebrow(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(GainsFont.metricMono(16))
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

  private func runStatDivider() -> some View {
    Rectangle()
      .fill(GainsColor.border.opacity(0.45))
      .frame(width: 0.6, height: 30)
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
    VStack(alignment: .leading, spacing: 14) {
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

      HStack(alignment: .bottom, spacing: 6) {
        ForEach(days) { day in
          VStack(spacing: 6) {
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
              .font(GainsFont.eyebrow(9))
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

  // MARK: - Stats: YTD

  private var ytdStatsSection: some View {
    let year = Calendar.current.component(.year, from: Date())
    let hours = store.yearlyRunDurationMinutes / 60
    let minutes = store.yearlyRunDurationMinutes % 60
    let timeString = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes) min"

    return VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["\(year)", "GESAMT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
        spacing: 10
      ) {
        GainsMetricTile(
          label: "DISTANZ",
          value: String(format: "%.0f", store.yearlyRunDistanceKm),
          unit: "km",
          style: .card
        )
        GainsMetricTile(
          label: "LÄUFE",
          value: "\(store.yearlyRunCount)",
          unit: "absolviert",
          style: .card
        )
        GainsMetricTile(
          label: "ZEIT",
          value: timeString,
          unit: "auf der Strecke",
          style: .card
        )
        GainsMetricTile(
          label: "HÖHE",
          value: "\(store.yearlyElevationGain)",
          unit: "m gesamt",
          style: .card
        )
      }
    }
  }

  // MARK: - Stats: Pace-Zonen

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
                  .font(GainsFont.metricMono(14))
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

  // MARK: - Stats: Distanz-PRs
  //
  // 2026-05-03 (P1-3): Vorher dieselbe Tabelle wie der Quick-Strip oben —
  // doppelte Information ohne Mehrwert im STATS-Tab. Jetzt Detail-Variante:
  // pro PR eine Karte mit Wert + zusätzlichem Datum, Tab-Footer für „PR
  // verbessern" zum Setup-Sheet (zukünftig). Bike-Bestzeiten kommen als
  // separate Sektion darunter, sobald welche existieren.

  private var distancePRsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 12) {
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
          VStack(spacing: 8) {
            ForEach(Array(prs.enumerated()), id: \.element.id) { index, pr in
              prDetailCard(pr, accent: prAccentColor(at: index))
            }
          }
        }
      }

      if !store.bikePersonalBests.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          SlashLabel(
            parts: ["BESTWERTE", "RAD"], primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk)

          VStack(spacing: 8) {
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
    HStack(spacing: 14) {
      Image(systemName: "trophy.fill")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(accent)
        .frame(width: 36, height: 36)
        .background(accent.opacity(0.14))
        .overlay(Circle().strokeBorder(accent.opacity(0.4), lineWidth: GainsBorder.hairline))
        .clipShape(Circle())

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
    .padding(14)
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
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: [label], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Spacer()
        Button {
          selectedTab = .stats
        } label: {
          HStack(spacing: 4) {
            Text("Alle Stats")
              .font(GainsFont.eyebrow(9))
              .tracking(1.2)
            Image(systemName: "chevron.right")
              .font(.system(size: 9, weight: .bold))
          }
          .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
      }

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(prs) { pr in
            prChip(pr)
          }
        }
        .padding(.vertical, 2)
      }
    }
    .padding(14)
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
    HStack(spacing: 6) {
      Image(systemName: "trophy.fill")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(GainsColor.lime)
      Text(pr.title)
        .font(GainsFont.eyebrow(9))
        .tracking(1.2)
        .foregroundStyle(GainsColor.softInk)
      Text("·")
        .foregroundStyle(GainsColor.softInk.opacity(0.5))
      Text(pr.value)
        .font(GainsFont.metricMono(13))
        .foregroundStyle(GainsColor.ink)
    }
    .padding(.horizontal, 12)
    .frame(height: 32)
    .background(GainsColor.background.opacity(0.85))
    .overlay(
      Capsule().strokeBorder(GainsColor.lime.opacity(0.3), lineWidth: GainsBorder.hairline)
    )
    .clipShape(Capsule())
  }

  // MARK: - Helpers

  /// Einheitlicher Hero-CTA-Pfad (P1-2 + P0-3): Startet eine neue Quick-
  /// Session in der gerade gewählten Modalität oder öffnet die laufende.
  /// Vorher gab es zwei Funktionen (`startOrResumeRun`/`startQuickCardio`),
  /// jeweils mit dem fehleranfälligen `isShowingRunTracker = false; = true`-
  /// Pattern. Da das Hub-Sheet `isShowingRunTracker` zu diesem Zeitpunkt
  /// niemals offen ist (Hero ist nur sichtbar, wenn kein Sheet aktiv ist),
  /// reicht ein einzelnes `= true`.
  private func startOrResumeCardio() {
    if store.activeRun == nil {
      store.startQuickRun(modality: preferredModality)
    }
    isShowingRunTracker = true
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
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
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
        // A13 (Cleaner-Pass): cornerRadius 18→16, lineWidth 1→0.6 (hairline).
        .background(GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .strokeBorder(GainsColor.border.opacity(0.5), lineWidth: GainsBorder.hairline)
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
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
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
        // A13 (Cleaner-Pass): cornerRadius 18→16, lineWidth 1→0.6.
        .background(GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .strokeBorder(GainsColor.border.opacity(0.5), lineWidth: GainsBorder.hairline)
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
