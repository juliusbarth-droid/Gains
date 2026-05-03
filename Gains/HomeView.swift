import SwiftUI

// MARK: - Cached Formatters
// Statische DateFormatter-Instanzen verhindern, dass HomeView bei jedem
// `coachClock`-Tick (60s) bzw. bei jedem `body`-Refresh frisch allokiert.
// `formatter` ist NICHT thread-safe in älteren OS, aber alle Aufrufer hier
// laufen auf MainActor — daher OK.
private enum HomeFormatters {
  static let weekdayLongDE: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "EEEE"
    return f
  }()

  static let weekdayShortDE: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "EE"
    return f
  }()

  static let dayMonthEN: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "dd MMM"
    return f
  }()
}

struct HomeView: View {
  @EnvironmentObject private var navigation: AppNavigationStore
  @EnvironmentObject private var store: GainsStore
  // A13: Live-Heart-Rate-Manager — nicht nur für den BPM-Banner; der Coach-
  // Brief und die Pulse-Strip-Mini-Stats lesen auch live, damit sich die
  // Bühne mit dem Puls bewegt.
  @ObservedObject private var ble = BLEHeartRateManager.shared
  @State private var isShowingWorkoutChooser = false
  @State private var isShowingWorkoutBuilder = false
  @State private var isShowingWorkoutTracker = false
  @State private var isShowingRunTracker = false
  @State private var isShowingProfile = false
  // A13: Home-Screen-Redesign „Coach Brief".
  // Statt eines symmetrischen Card-Stacks (Hero + Cockpit + Nutrition + Grid)
  // gibt es jetzt EINEN Coach-Brief als Hero, der je nach Tageszeit, Plan-
  // und Workout-Status die wichtigste nächste Handlung formuliert. Pulse-
  // Strip + Spotlight (Cockpit ODER Nutrition als „lauter Ring") + Compact-
  // Pendant + adaptives 2x2-Action-Grid ordnen sich kontextabhängig an.
  // Die alten static helpers (Wochen-/kcal-Ring, Sparkline, Macro-Bars,
  // Mini-Tiles, Action-Tile-Renderer) bleiben — sie werden jetzt nur in
  // dynamischer Reihenfolge eingesetzt.
  @State private var isShowingProgress = false
  @State private var arrangingPlan: WorkoutPlan?

  // Aktualisiert sich jede Minute, damit der Coach-Brief Variants wechselt
  // (z. B. „Workout-Fenster" → „Streak schützen") ohne dass der Nutzer die
  // App neu öffnen muss.
  @State private var coachClock = Date()
  private let coachTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

  // Phase 1 Aha-Moment (2026-05-01): In den ersten 24h nach Onboarding-
  // Finish zeigt der Coach-Brief eine `.dayOne`-Variante mit warmer
  // Begrüßung + konkretem ersten CTA. Sobald der User sein erstes
  // Workout/Lauf trackt ODER 24h vergangen sind, fällt der Brief auf
  // die normale Priority-Kette zurück.
  @AppStorage(GainsKey.onboardingCompletedAt) private var onboardingCompletedAt: Double = 0

  // A6: Sheet-Choreografie über `onDismiss` statt `asyncAfter`.
  @State private var pendingAfterChooser: (() -> Void)? = nil
  @State private var pendingAfterBuilder: (() -> Void)? = nil
  @State private var pendingAfterArrange: (() -> Void)? = nil

  var body: some View {
    ZStack {
      GainsAppBackground()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: GainsSpacing.l) {
          // A14: Greeting + Coach-Brief sind als ein zusammengehöriges
          // Gruppen-Pärchen gedacht — engerer Abstand (`.tight` = 10pt)
          // zwischen ihnen visualisiert die Bindung, alle anderen
          // Sektionen halten `.l` (20pt).
          VStack(alignment: .leading, spacing: GainsSpacing.tight) {
            greetingHeader
            coachBriefCard
          }
          quickStartBar
          pulseStrip
          spotlightStack
          adaptiveActionGrid
          liveBPMBanner
        }
        .padding(.horizontal, GainsSpacing.l)
        .padding(.top, GainsSpacing.s)
        .padding(.bottom, 120)
      }
    }
    .onReceive(coachTicker) { coachClock = $0 }
    .sheet(
      isPresented: $isShowingWorkoutChooser,
      onDismiss: { runPending(&pendingAfterChooser) }
    ) { workoutChooserSheet }
    .sheet(
      isPresented: $isShowingWorkoutBuilder,
      onDismiss: { runPending(&pendingAfterBuilder) }
    ) { workoutBuilderSheet }
    .sheet(
      item: $arrangingPlan,
      onDismiss: { runPending(&pendingAfterArrange) }
    ) { plan in
      arrangePlanSheet(plan: plan)
    }
    .sheet(isPresented: $isShowingWorkoutTracker) {
      WorkoutTrackerView().environmentObject(store)
    }
    .sheet(isPresented: $isShowingRunTracker) {
      RunTrackerView().environmentObject(store)
    }
    .sheet(isPresented: $isShowingProgress) { progressSheet }
    .sheet(isPresented: $isShowingProfile) { profileSheet }
  }

  // MARK: - Sheet Content (extracted)
  //
  // Diese sieben Sheets hingen früher direkt am body und haben den
  // Hauptinhalt mit ~90 Zeilen Sheet-Boilerplate verdrängt. SwiftUI rendert
  // jeden `.sheet`-Closure als eigenständigen Subgraphen — sie hier in
  // ViewBuilder-Helper auszulagern macht den body lesbarer und reduziert
  // Recompiles auf den jeweiligen Sub-Closure.

  @ViewBuilder
  private var workoutChooserSheet: some View {
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

  @ViewBuilder
  private var workoutBuilderSheet: some View {
    WorkoutBuilderView { workout in
      pendingAfterBuilder = { presentArrange(for: workout) }
      isShowingWorkoutBuilder = false
    }
    .environmentObject(store)
  }

  @ViewBuilder
  private func arrangePlanSheet(plan: WorkoutPlan) -> some View {
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

  @ViewBuilder
  private var progressSheet: some View {
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

  @ViewBuilder
  private var profileSheet: some View {
    NavigationStack {
      ProfileView()
        .environmentObject(store)
        .environmentObject(navigation)
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

  // MARK: - Greeting Header (Hi, Julius. + Datum/Tageszeit + Avatar)
  //
  // A14: Persönlicher Begrüßungs-Strip ersetzt den reinen Wordmark/Avatar-
  // Top. Tageszeit-abhängige Anrede („Moin/Hi/Hey/Abend/Späte Stunde"),
  // Name in Lime, Datum + Wochentag + Tageszeit-Bucket als Mono-Eyebrow
  // drunter. Das Tageszeit-Label ist deshalb aus dem Coach-Brief-Header
  // wieder raus — würde sich sonst doppeln.

  private var greetingHeader: some View {
    HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        greetingLine
        Text(greetingMetaLine)
          .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.5)
          .lineLimit(1)
      }

      Spacer(minLength: 8)

      Button {
        isShowingProfile = true
      } label: {
        // 2026-05-03: Avatar im Greeting ist jetzt entweder das vom User
        // gesetzte Profilbild (siehe ProfileView/setUserAvatar) oder die
        // klassische Initial-Variante. Lime-Ring wenn ein Bild gesetzt
        // ist — sonst dezenter Hairline-Border wie vorher.
        Group {
          if let image = store.userAvatarImage {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(width: 38, height: 38)
              .clipShape(Circle())
              .overlay(
                Circle().stroke(GainsColor.lime.opacity(0.55), lineWidth: 1)
              )
          } else {
            ZStack {
              Circle()
                .stroke(GainsColor.border.opacity(0.55), lineWidth: 1)
                .frame(width: 38, height: 38)
              Text(store.userName.isEmpty ? "·" : String(store.userName.prefix(1)).uppercased())
                .font(GainsFont.label(13))
                .foregroundStyle(GainsColor.ink)
            }
          }
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Profil öffnen")
    }
  }

  /// „Moin, Julius." — Anrede + Name in Lime + Punkt. Wenn kein Name
  /// gesetzt: nur die Anrede mit Ausrufezeichen.
  @ViewBuilder
  private var greetingLine: some View {
    let salutation = currentSalutation
    let hasName = !store.userName.isEmpty

    if hasName {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("\(salutation), ")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
        Text("\(store.userName).")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.lime)
      }
      .lineLimit(1)
      .minimumScaleFactor(0.7)
    } else {
      Text("\(salutation).")
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
  }

  /// Wechselt mit der Tageszeit. Bewusst kurz und warm — kein „Sehr geehrter".
  private var currentSalutation: String {
    let hour = Calendar.current.component(.hour, from: coachClock)
    switch hour {
    case 5..<10: return "Moin"
    case 10..<14: return "Hi"
    case 14..<18: return "Hey"
    case 18..<22: return "Abend"
    default: return "Späte Stunde"
    }
  }

  /// „FREITAG · 01 MAI · ABEND" — Wochentag, Datum, Tageszeit-Bucket.
  /// Kompakt in einer Zeile.
  private var greetingMetaLine: String {
    let parts = currentDateParts
    let bucket = currentTimeBucket
    return "\(currentWeekdayLong) · \(parts.date) · \(bucket)"
  }

  private var currentWeekdayLong: String {
    HomeFormatters.weekdayLongDE.string(from: coachClock).uppercased()
  }

  /// Tageszeit-Bucket (NACHT/MORGEN/MITTAG/NACHM./ABEND/SPÄT) — wird sowohl
  /// im Greeting-Eyebrow als auch (früher) im Coach-Brief-Header genutzt.
  private var currentTimeBucket: String {
    let hour = Calendar.current.component(.hour, from: coachClock)
    switch hour {
    case 0..<5: return "NACHT"
    case 5..<11: return "MORGEN"
    case 11..<14: return "MITTAG"
    case 14..<18: return "NACHM."
    case 18..<22: return "ABEND"
    default: return "SPÄT"
    }
  }

  // MARK: - Coach Brief (Hero — das Herz)
  //
  // A13: Statt statischem Greeting + Sub-Line + generischem CTA pickt der
  // Brief je nach Kontext die wichtigste Aussage und Aktion gerade JETZT.
  // Variants priorisieren von akut (laufendes Workout) → opportun (Workout-
  // Fenster) → unterstützend (Streak schützen, Protein-Lücke) → gemütlich
  // (Recovery, Abendroutine).

  private var coachBriefCard: some View {
    let brief = currentCoachBrief
    return VStack(alignment: .leading, spacing: 18) {
      coachBriefHeader(brief)
      coachBriefHeadline(brief)
      coachBriefSub(brief)
      coachPrimaryCTA(brief)
      if let secondary = brief.secondary {
        coachSecondaryLink(secondary, accent: brief.accent)
      }
    }
    .padding(20)
    .background(coachBriefBackground(accent: brief.accent))
    .overlay(
      // A14 (minimal): Single-Tone Border statt Gradient, dünner.
      RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
        .strokeBorder(brief.accent.opacity(0.32), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
    .shadow(color: brief.accent.opacity(0.10), radius: 14, x: 0, y: 8)
  }

  private func coachBriefBackground(accent: Color) -> some View {
    // A14 (minimal): nur EIN dezenter Akzent-Glow oben links statt zwei
    // konkurrierender Gradients. Card bleibt ruhig.
    ZStack {
      GainsColor.card
      RadialGradient(
        colors: [accent.opacity(0.16), .clear],
        center: .topLeading,
        startRadius: 0,
        endRadius: 240
      )
      .blendMode(.screen)
    }
  }

  private func coachBriefHeader(_ brief: CoachBrief) -> some View {
    // A14 (minimal): Tageszeit-Label rechts ist gestrichen — die Greeting
    // oben trägt jetzt Wochentag + Datum + Bucket. Hier bleibt nur der
    // Pulse + der kontextuelle Eyebrow + ein dezenter Glyph rechts.
    HStack(spacing: 10) {
      PulsingDot(color: brief.accent, coreSize: 6, haloSize: 16)
      Text(brief.eyebrow)
        .gainsEyebrow(brief.accent, size: 11, tracking: 1.6)
        .lineLimit(1)
      Spacer(minLength: 8)
      Image(systemName: brief.glyph)
        .font(.system(size: 11, weight: .heavy))
        .foregroundStyle(brief.accent.opacity(0.6))
    }
  }

  private func coachBriefHeadline(_ brief: CoachBrief) -> some View {
    // A14 (minimal): Solid Ink, kein Gradient, kein Glow. Der Akzent kommt
    // aus dem Eyebrow + dem CTA-Border — die Headline darf still sein.
    Text(brief.headline)
      .font(GainsFont.display(28))
      .foregroundStyle(GainsColor.ink)
      .lineLimit(3)
      .minimumScaleFactor(0.72)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func coachBriefSub(_ brief: CoachBrief) -> some View {
    Text(brief.subline)
      .gainsBody(secondary: true)
      .lineLimit(3)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func coachPrimaryCTA(_ brief: CoachBrief) -> some View {
    Button {
      runCoachAction(brief.primary.action)
    } label: {
      HStack(spacing: 12) {
        Image(systemName: brief.primary.icon)
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(brief.accent)

        Text(brief.primary.title.uppercased())
          .font(GainsFont.label(13))
          .tracking(1.8)
          .foregroundStyle(GainsColor.ink)

        Spacer(minLength: 0)

        if let metric = brief.primary.metric {
          Text(metric)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(brief.accent)
        }

        Image(systemName: "arrow.right")
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(brief.accent)
      }
      .padding(.horizontal, 18)
      .frame(height: 54)
      .background(brief.accent.opacity(0.10))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(brief.accent.opacity(0.45), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .contentShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(brief.primary.title)
  }

  private func coachSecondaryLink(_ action: CoachActionDescriptor, accent: Color) -> some View {
    Button {
      runCoachAction(action.action)
    } label: {
      HStack(spacing: 6) {
        if let metric = action.metric {
          Text(metric)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.softInk)
          Text("·")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(GainsColor.mutedInk)
        }
        Text(action.title)
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
        Image(systemName: "arrow.up.right")
          .font(.system(size: 10, weight: .heavy))
          .foregroundStyle(accent)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Pulse Strip (3 kontextuelle Mini-Stats)
  //
  // A13: Drei Mini-Tiles, die je nach Tageszeit/Variant wechseln. Sie ersetzen
  // die alten Cockpit-Mini-Tiles in ihrer starren Position.

  private var pulseStrip: some View {
    let stats = currentPulseStats
    return HStack(spacing: 10) {
      ForEach(stats.indices, id: \.self) { idx in
        pulseTile(stats[idx])
      }
    }
  }

  private func pulseTile(_ stat: PulseStat) -> some View {
    Button {
      runCoachAction(stat.action)
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: stat.icon)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(stat.accent)
          Text(stat.label)
            .gainsEyebrow(GainsColor.mutedInk, size: 9, tracking: 1.2)
            .lineLimit(1)
        }
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(stat.value)
            .font(.system(size: 19, weight: .semibold, design: .monospaced))
            .foregroundStyle(GainsColor.ink)
          Text(stat.unit)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.softInk)
        }
        Text(stat.detail)
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.mutedInk)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 12)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(stat.accent.opacity(0.24), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(stat.label): \(stat.value) \(stat.unit). \(stat.detail).")
  }

  // MARK: - Spotlight Stack (eine Card laut, die andere kompakt)
  //
  // A13: Wochen-Cockpit und Nutrition stehen nicht mehr beide gleich groß da.
  // Je nach Coach-Brief und Tageszeit wird eines zum „Spotlight" mit Ring +
  // Mini-Tiles, das andere wird zur kompakten Footer-Zeile mit Mini-Pills.

  @ViewBuilder
  private var spotlightStack: some View {
    switch currentSpotlight {
    case .cockpit:
      cockpitSpotlightCard
      compactNutritionCard
    case .nutrition:
      nutritionSpotlightCard
      compactCockpitCard
    }
  }

  // MARK: - Cockpit Spotlight (vollwertige Wochen-Card)

  private var cockpitSpotlightCard: some View {
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

      // H3-Fix (2026-05-01): Trennlinie zwischen den beiden Tap-Zonen
      // (Wochenring → ProgressSheet vs. Plan-Row → openPlanner) war optisch
      // zu schwach. Stärker und etwas Padding, damit klar wird, dass es
      // sich um zwei Aktionen handelt.
      Rectangle()
        .fill(GainsColor.border)
        .frame(height: 1)
        .padding(.vertical, 2)

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
    }
    .padding(20)
    .gainsCardStyle()
  }

  // MARK: - Compact Cockpit Row (Footer-Variante)

  private var compactCockpitCard: some View {
    Button {
      isShowingProgress = true
    } label: {
      HStack(spacing: 14) {
        ZStack {
          Circle()
            .stroke(GainsColor.border.opacity(0.7), lineWidth: 4)
          Circle()
            .trim(from: 0, to: weeklyProgressRatio)
            .stroke(
              LinearGradient(
                colors: [GainsColor.lime, GainsColor.accentCool],
                startPoint: .leading,
                endPoint: .trailing
              ),
              style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: GainsColor.lime.opacity(0.4), radius: 6)
        }
        .frame(width: 44, height: 44)

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text("WOCHE")
              .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.4)
            Text(currentDateParts.week)
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.mutedInk)
          }
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)")
              .font(.system(size: 16, weight: .semibold, design: .monospaced))
              .foregroundStyle(GainsColor.ink)
            Text("Sessions")
              .gainsCaption()
            Text("·")
              .gainsCaption()
            Text(String(format: "%.1f t", store.weeklyVolumeTons))
              .font(.system(size: 12, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.softInk)
          }
        }

        Spacer(minLength: 0)

        compactPlanPill
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(GainsColor.border.opacity(0.55), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Wochenfortschritt — \(store.weeklySessionsCompleted) von \(store.weeklyGoalCount)")
  }

  /// Mini-Pill mit „NÄCHSTES: Push" oder „HEUTE: Push" — als Quick-Hint
  /// in der kompakten Zeile.
  @ViewBuilder
  private var compactPlanPill: some View {
    if let next = nextPlannedSchedule {
      HStack(spacing: 4) {
        Image(systemName: next.isToday ? "play.fill" : "calendar")
          .font(.system(size: 9, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
        Text((next.isToday ? "HEUTE · " : "\(next.weekday.shortLabel.uppercased()) · ") + next.title.uppercased())
          .gainsEyebrow(GainsColor.lime, size: 9, tracking: 1.2)
          .lineLimit(1)
      }
      .padding(.horizontal, 8)
      .frame(height: 22)
      .background(GainsColor.lime.opacity(0.10))
      .overlay(
        Capsule().strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: GainsBorder.hairline)
      )
      .clipShape(Capsule())
    } else {
      Image(systemName: "arrow.up.right")
        .font(.system(size: 11, weight: .heavy))
        .foregroundStyle(GainsColor.softInk)
    }
  }

  /// A12/A13: Plan-Vorschau-Zeile innerhalb der Cockpit-Spotlight-Card.
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
            Circle().strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: GainsBorder.hairline)
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
          .strokeBorder(accent.opacity(0.45), lineWidth: GainsBorder.hairline)
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
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(GainsColor.border.opacity(0.6), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
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

  // MARK: - Nutrition Spotlight (vollwertige Ring-Card)

  private var nutritionSpotlightCard: some View {
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
      .contentShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Ernährung öffnen")
    .accessibilityValue(
      "\(store.nutritionCaloriesToday) von \(store.nutritionTargetCalories) Kalorien"
    )
  }

  // MARK: - Compact Nutrition Row (Footer-Variante)

  private var compactNutritionCard: some View {
    Button {
      navigation.openNutrition()
    } label: {
      HStack(spacing: 14) {
        ZStack {
          Circle()
            .stroke(GainsColor.border.opacity(0.7), lineWidth: 4)
          Circle()
            .trim(from: 0, to: kcalProgressRatio)
            .stroke(
              LinearGradient(
                colors: [GainsColor.lime, GainsColor.ember],
                startPoint: .leading,
                endPoint: .trailing
              ),
              style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: GainsColor.ember.opacity(0.4), radius: 6)
        }
        .frame(width: 44, height: 44)

        VStack(alignment: .leading, spacing: 2) {
          Text("ERNÄHRUNG · HEUTE")
            .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.4)
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(store.nutritionCaloriesToday)")
              .font(.system(size: 16, weight: .semibold, design: .monospaced))
              .foregroundStyle(GainsColor.ink)
            Text("/\(store.nutritionTargetCalories) kcal")
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.softInk)
            Text("·")
              .gainsCaption()
            Text("\(store.nutritionProteinToday)g P")
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.ember)
          }
        }

        Spacer(minLength: 0)

        compactNutritionPill
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(GainsColor.border.opacity(0.55), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Ernährung — \(store.nutritionCaloriesToday) von \(store.nutritionTargetCalories) Kalorien")
  }

  @ViewBuilder
  private var compactNutritionPill: some View {
    let remainingProtein = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
    if remainingProtein <= 0 && store.nutritionCaloriesToday > 0 {
      HStack(spacing: 4) {
        Image(systemName: "checkmark")
          .font(.system(size: 9, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
        Text("PROTEIN ✓")
          .gainsEyebrow(GainsColor.lime, size: 9, tracking: 1.2)
      }
      .padding(.horizontal, 8)
      .frame(height: 22)
      .background(GainsColor.lime.opacity(0.10))
      .overlay(Capsule().strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: GainsBorder.hairline))
      .clipShape(Capsule())
    } else if remainingProtein > 0 {
      HStack(spacing: 4) {
        Image(systemName: "fork.knife")
          .font(.system(size: 9, weight: .heavy))
          .foregroundStyle(GainsColor.ember)
        Text("\(remainingProtein)g OFFEN")
          .gainsEyebrow(GainsColor.ember, size: 9, tracking: 1.2)
      }
      .padding(.horizontal, 8)
      .frame(height: 22)
      .background(GainsColor.ember.opacity(0.10))
      .overlay(Capsule().strokeBorder(GainsColor.ember.opacity(0.4), lineWidth: GainsBorder.hairline))
      .clipShape(Capsule())
    } else {
      Image(systemName: "arrow.up.right")
        .font(.system(size: 11, weight: .heavy))
        .foregroundStyle(GainsColor.softInk)
    }
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

  // MARK: - Adaptive Action Grid (4 von 6 Tiles, kontextabhängig)
  //
  // A13: Das 2x2-Grid bleibt formal — die vier Slots werden aber je nach
  // Tageszeit und Coach-Variant aus einem Pool von 6 Kandidaten gefüllt.
  // So zeigt sich morgens „Plan / Lauf / Fortschritt / Foto", post-workout
  // „Foto / Wasser / Fortschritt / Lauf", abends „Foto / Wasser / Fasten /
  // Fortschritt".

  private var adaptiveActionGrid: some View {
    LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
      ],
      spacing: 12
    ) {
      ForEach(adaptiveTiles, id: \.kind) { tile in
        actionTile(tile)
      }
    }
  }

  // MARK: - Schnellstart-Bar (Workout + Laufen — immer sichtbar)
  //
  // 2026-05-03: Permanenter Quick-Access für die zwei zentralen Aktivitäten.
  // Davor lebten Training/Cardio im adaptiven 2x2-Grid und rotierten je nach
  // Tageszeit/Post-Workout-Fenster heraus — d. h. „mal eben Workout starten"
  // war oft drei Scrolls und ein Tab-Wechsel weg. Die Schnellstart-Bar steht
  // unmittelbar unter dem Coach-Brief, damit der erste Sicht-Frame immer
  // beide Pfade enthält. Tap startet/öffnet sofort, Long-Press liefert
  // Power-User-Shortcuts (Pattern aus W2-4 / `tileContextMenu`).
  //
  // Konsequenz im Grid: training/cardio-Tiles werden in den nicht-DayOne-
  // Pfaden bewusst nicht mehr eingesetzt (siehe `adaptiveTiles`). Drei Wege
  // zum gleichen Ziel auf einer Höhe macht Wirkung unklar — siehe H1-Fix
  // beim Plan-Slot.

  private var quickStartBar: some View {
    HStack(spacing: 12) {
      quickStartTile(
        kind: .training,
        title: store.activeWorkout != nil ? "Fortsetzen" : "Workout",
        eyebrow: "TRAINING",
        subtitle: quickStartTrainingSubtitle,
        icon: store.activeWorkout != nil ? "dumbbell.fill" : "play.fill",
        accent: GainsColor.lime,
        isLive: store.activeWorkout != nil,
        action: {
          if store.activeWorkout != nil {
            isShowingWorkoutTracker = true
          } else {
            isShowingWorkoutChooser = true
          }
        }
      )
      quickStartTile(
        kind: .cardio,
        title: store.activeRun != nil ? "Fortsetzen" : "Cardio",
        eyebrow: "CARDIO",
        subtitle: quickStartCardioSubtitle,
        // Tap = Lauf (häufigster Modus). Long-Press öffnet Modi-Auswahl
        // (Rad outdoor, Rad indoor) — siehe quickStartContextMenu(.cardio).
        // Das Icon spiegelt die aktive Session, Default ist „figure.run".
        icon: store.activeRun.map { $0.modality.systemImage } ?? "figure.run",
        accent: GainsColor.ember,
        isLive: store.activeRun != nil,
        action: {
          if store.activeRun != nil {
            isShowingRunTracker = true
          } else {
            startQuickRun()
          }
        }
      )
    }
  }

  /// Statuszeile für die Workout-Schnellstart-Kachel — bevorzugt akute Live-
  /// Info, fällt zurück auf heute geplant, dann auf die letzte Session, sonst
  /// auf einen freundlichen Discovery-Hinweis.
  private var quickStartTrainingSubtitle: String {
    if let aw = store.activeWorkout {
      return "\(aw.completedSets)/\(aw.totalSets) Sätze · \(aw.title)"
    }
    if let plan = store.todayPlannedWorkout {
      return "Heute · \(plan.title)"
    }
    if let last = store.lastCompletedWorkout {
      return "Zuletzt · \(last.title)"
    }
    return "Plan wählen oder spontan"
  }

  /// Statuszeile für die Lauf-Schnellstart-Kachel — analog zur Training-
  /// Kachel: Live-Lauf > Tagesplan > Default.
  private var quickStartCardioSubtitle: String {
    if let ar = store.activeRun {
      return String(
        format: "%.1f km · %02d:%02d",
        ar.distanceKm,
        ar.durationMinutes / 60,
        ar.durationMinutes % 60
      )
    }
    if store.todayPlannedDay.runTemplate != nil {
      return "Heute geplant · GPS"
    }
    // Hinweis auf Long-Press: vom Tile aus sind alle drei Cardio-Modi
    // erreichbar (Lauf, Rad outdoor, Rad indoor). Der Subtitle soll das
    // signalisieren, ohne die Kachel zu überfrachten.
    return "Lauf · Rad · Indoor (Long-Press)"
  }

  private func quickStartTile(
    kind: ActionTileSpec.Kind,
    title: String,
    eyebrow: String,
    subtitle: String,
    icon: String,
    accent: Color,
    isLive: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 0) {
          ZStack {
            Circle()
              .fill(accent.opacity(0.14))
            Image(systemName: icon)
              .font(.system(size: 16, weight: .heavy))
              .foregroundStyle(accent)
          }
          .frame(width: 40, height: 40)

          Spacer(minLength: 0)

          if isLive {
            PulsingDot(color: accent, coreSize: 6, haloSize: 16)
              .frame(width: 24, height: 24)
          } else {
            Image(systemName: "arrow.up.right")
              .font(.system(size: 11, weight: .heavy))
              .foregroundStyle(GainsColor.softInk)
              .frame(width: 24, height: 24)
          }
        }

        Spacer(minLength: 14)

        VStack(alignment: .leading, spacing: 4) {
          Text(eyebrow)
            .gainsEyebrow(accent, size: 10, tracking: 1.5)
          Text(title)
            .font(GainsFont.title(22))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
          Text(subtitle)
            .gainsCaption()
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
      .padding(16)
      .background(
        ZStack {
          GainsColor.card
          RadialGradient(
            colors: [accent.opacity(0.10), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 180
          )
          .blendMode(.screen)
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(accent.opacity(isLive ? 0.45 : 0.30), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(eyebrow) — \(title)")
    .accessibilityValue(subtitle)
    .accessibilityAddTraits(isLive ? .isSelected : [])
    .contextMenu { quickStartContextMenu(for: kind) }
  }

  /// Long-Press-Shortcuts auf den Schnellstart-Kacheln. Bewusst breiter als
  /// die Tap-Action, damit Wiederholer ihre Lieblingspfade direkt erreichen.
  @ViewBuilder
  private func quickStartContextMenu(for kind: ActionTileSpec.Kind) -> some View {
    switch kind {
    case .training:
      Button {
        runCoachAction(.startQuickWorkout)
      } label: {
        Label("Spontan starten", systemImage: "play.fill")
      }
      Button {
        if store.repeatLastWorkout() {
          isShowingWorkoutTracker = true
        }
      } label: {
        Label("Letzte Session wiederholen", systemImage: "arrow.uturn.backward")
      }
      .disabled(store.lastCompletedWorkout == nil)
      Button {
        navigation.openTraining(workspace: .kraft)
      } label: {
        Label("Trainings-Tab öffnen", systemImage: "dumbbell.fill")
      }
      Button {
        runCoachAction(.openPlanner)
      } label: {
        Label("Plan ansehen", systemImage: "calendar")
      }

    case .cardio:
      Button {
        runCoachAction(.startQuickRun)
      } label: {
        Label("Lauf starten", systemImage: "figure.run")
      }
      Button {
        startQuickRun(modality: .bikeOutdoor)
      } label: {
        Label("Rad starten (outdoor)", systemImage: "figure.outdoor.cycle")
      }
      Button {
        startQuickRun(modality: .bikeIndoor)
      } label: {
        Label("Rad indoor starten", systemImage: "figure.indoor.cycle")
      }
      Button {
        navigation.openTraining(workspace: .laufen)
      } label: {
        Label("Cardio-Hub öffnen", systemImage: "rectangle.stack.fill")
      }

    case .progress, .meal, .water, .planner:
      EmptyView()
    }
  }

  private func actionTile(_ spec: ActionTileSpec) -> some View {
    Button(action: { runCoachAction(spec.action) }) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 0) {
          ZStack {
            Circle()
              .fill(spec.accent.opacity(0.12))
            Image(systemName: spec.icon)
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(spec.accent)
          }
          .frame(width: 32, height: 32)

          Spacer(minLength: 0)

          if spec.isLive {
            PulsingDot(color: spec.accent, coreSize: 6, haloSize: 14)
              .frame(width: 24, height: 24)
          } else {
            Image(systemName: "arrow.up.right")
              .font(.system(size: 11, weight: .heavy))
              .foregroundStyle(GainsColor.softInk)
              .frame(width: 24, height: 24)
          }
        }

        Spacer(minLength: 12)

        VStack(alignment: .leading, spacing: 4) {
          Text(spec.eyebrow)
            .gainsEyebrow(spec.accent, size: 10, tracking: 1.4)
          Text(spec.title)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
          Text(spec.subtitle)
            .gainsCaption()
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
      .padding(14)
      .background(GainsColor.card)
      .overlay(
        // A14 (minimal): einfarbiger Border, kein Gradient, kein Akzent-
        // Schatten — der Akzent lebt über das Halo-Icon und das Eyebrow.
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(GainsColor.border.opacity(0.45), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(spec.eyebrow) — \(spec.title)")
    .accessibilityValue(spec.subtitle)
    .accessibilityAddTraits(spec.isLive ? .isSelected : [])
    // Welle 2 (W2-4): Power-User-Long-Press. Tap macht den Default-Pfad
    // (für Anfänger das Erwartete), Long-Press liefert 1-3 Quick-Actions
    // für Wiederholer. iOS-Standard-Geste, also ohne explizite Discovery-
    // Pille. Tiles ohne sinnvolle Shortcuts (progress, water, planner)
    // bleiben ohne Menu — das ist OK, leere ContextMenus rendern nichts.
    .contextMenu { tileContextMenu(for: spec) }
  }

  @ViewBuilder
  private func tileContextMenu(for spec: ActionTileSpec) -> some View {
    switch spec.kind {
    case .meal:
      Button {
        navigation.presentCapture(kind: .meal)
      } label: {
        Label("Mahlzeit per Foto / Suche", systemImage: "camera.fill")
      }
      Button {
        navigation.openNutrition()
      } label: {
        Label("Ernährungs-Tab öffnen", systemImage: "fork.knife")
      }

    case .training:
      Button {
        if store.repeatLastWorkout() {
          isShowingWorkoutTracker = true
        }
      } label: {
        Label("Letzte Session wiederholen", systemImage: "arrow.uturn.backward")
      }
      .disabled(store.lastCompletedWorkout == nil)

      Button {
        runCoachAction(.startQuickWorkout)
      } label: {
        Label("Spontan starten", systemImage: "play.fill")
      }

      Button {
        runCoachAction(.openPlanner)
      } label: {
        Label("Plan ansehen", systemImage: "calendar")
      }

    case .cardio:
      Button {
        runCoachAction(.startQuickRun)
      } label: {
        Label("Lauf starten", systemImage: "figure.run")
      }
      Button {
        startQuickRun(modality: .bikeOutdoor)
      } label: {
        Label("Rad starten (outdoor)", systemImage: "figure.outdoor.cycle")
      }
      Button {
        startQuickRun(modality: .bikeIndoor)
      } label: {
        Label("Rad indoor starten", systemImage: "figure.indoor.cycle")
      }
      Button {
        navigation.openTraining(workspace: .laufen)
      } label: {
        Label("Cardio-Hub öffnen", systemImage: "rectangle.stack.fill")
      }

    case .progress, .water, .planner:
      EmptyView()
    }
  }

  // MARK: - Live-BPM-Banner

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
        .background(GainsColor.card)
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .strokeBorder(GainsColor.accentCool.opacity(0.28), lineWidth: GainsBorder.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(
        "Heart-Rate-Sensor verbunden\(ble.liveHeartRate.map { ", \($0) BPM" } ?? "")"
      )
    }
  }

  // MARK: - Computed (Ernährung + Wochen-Fortschritt)

  private var kcalProgressRatio: Double {
    // P2-Fix (2026-05-01): Wenn (noch) kein kcal-Ziel gesetzt ist, soll der
    // Ring leer bleiben statt durch `max(goal, 1)` auf 100% zu clampen,
    // sobald die ersten Kalorien geloggt sind.
    guard store.nutritionTargetCalories > 0 else { return 0 }
    return min(Double(store.nutritionCaloriesToday) / Double(store.nutritionTargetCalories), 1.0)
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

  // MARK: - Coach Brief Engine (Variant-Picker + Render-Spec)

  /// Liefert die aktuelle Coach-Brief-Variant basierend auf Workout-State,
  /// Plan, Tageszeit, Streak und Nutrition-Lücke. Reihenfolge ist Priorität.
  private var currentCoachBrief: CoachBrief {
    let now = coachClock
    let hour = Calendar.current.component(.hour, from: now)

    // 1) Akut: laufendes Workout/Run hat IMMER Vorrang.
    if let aw = store.activeWorkout {
      let remaining = max(aw.totalSets - aw.completedSets, 0)
      let progress = aw.totalSets > 0
        ? Int((Double(aw.completedSets) / Double(aw.totalSets)) * 100)
        : 0
      return CoachBrief(
        eyebrow: "WORKOUT LÄUFT",
        glyph: "dumbbell.fill",
        accent: GainsColor.lime,
        headline: remaining == 0
          ? "Letzter Satz steht — Finish stark."
          : "Weiter wo du warst.",
        subline: remaining == 0
          ? "Alle \(aw.totalSets) Sätze fast durch — \(aw.title) wartet auf den Schlusspunkt."
          : "\(aw.completedSets)/\(aw.totalSets) Sätze · \(progress) % von \(aw.title) durch.",
        primary: CoachActionDescriptor(
          title: "Trainer öffnen",
          icon: "play.fill",
          metric: "\(aw.completedSets)/\(aw.totalSets)",
          action: .openWorkoutTracker
        ),
        secondary: nil
      )
    }

    if let ar = store.activeRun {
      let mins = ar.durationMinutes / 60
      let secs = ar.durationMinutes % 60
      return CoachBrief(
        eyebrow: ar.isPaused ? "RUN PAUSIERT" : "RUN LIVE",
        glyph: "figure.run",
        accent: GainsColor.ember,
        headline: ar.isPaused
          ? "Lauf pausiert — bereit für Re-Start?"
          : "Lauf läuft seit \(mins) min.",
        subline: String(
          format: "%.2f km · %02d:%02d · HF %d bpm",
          ar.distanceKm, mins, secs, ar.currentHeartRate
        ),
        primary: CoachActionDescriptor(
          title: "Run öffnen",
          icon: "figure.run",
          metric: String(format: "%.2f km", ar.distanceKm),
          action: .openRunTracker
        ),
        secondary: nil
      )
    }

    // 1.5) Day-One-Window — User hat Onboarding < 24h fertig und noch nichts
    // getrackt. Hier formuliert der Coach-Brief NICHT den 100. Tag, sondern
    // den allerersten — warmer Empfang, konkreter erster Schritt aus dem
    // heutigen Plan. Sobald die erste Session durch ist, fällt dieser Brief
    // weg und die normale Kette übernimmt.
    if isInDayOneWindow {
      let trimmedName = store.userName.trimmingCharacters(in: .whitespacesAndNewlines)
      let warmName = trimmedName.isEmpty ? "" : ", \(trimmedName)"
      let plan = store.todayPlannedDay

      switch plan.status {
      case .planned:
        if let runTemplate = plan.runTemplate {
          return CoachBrief(
            eyebrow: "TAG 1",
            glyph: "sparkles",
            accent: GainsColor.ember,
            headline: "Willkommen\(warmName).",
            subline: String(
              format: "Heute steht dein erster Lauf an: %@ · %.1f km. Du musst nichts vorbereiten — Tracker startet das GPS für dich.",
              runTemplate.title, runTemplate.targetDistanceKm
            ),
            primary: CoachActionDescriptor(
              title: "Ersten Lauf starten",
              icon: "play.fill",
              metric: String(format: "%.1f km", runTemplate.targetDistanceKm),
              action: .startQuickRun
            ),
            secondary: CoachActionDescriptor(
              title: "Plan ansehen",
              icon: "calendar",
              metric: nil,
              action: .openPlanner
            )
          )
        }
        let workoutTitle = plan.workoutPlan?.title ?? plan.title
        let exerciseCount = plan.workoutPlan?.exercises.count ?? 0
        return CoachBrief(
          eyebrow: "TAG 1",
          glyph: "sparkles",
          accent: GainsColor.lime,
          headline: "Willkommen\(warmName).",
          subline: exerciseCount > 0
            ? "Heute startest du mit \(workoutTitle) — \(exerciseCount) Übungen, wir führen dich Satz für Satz."
            : "Heute startest du mit \(workoutTitle). Wir führen dich Schritt für Schritt durch deine erste Session.",
          primary: CoachActionDescriptor(
            title: "Erste Session",
            icon: "play.fill",
            metric: exerciseCount > 0 ? "\(exerciseCount) Übungen" : nil,
            action: .startPlannedWorkout
          ),
          secondary: CoachActionDescriptor(
            title: "Plan ansehen",
            icon: "calendar",
            metric: nil,
            action: .openPlanner
          )
        )

      case .rest:
        return CoachBrief(
          eyebrow: "TAG 1",
          glyph: "sparkles",
          accent: GainsColor.accentCool,
          headline: "Willkommen\(warmName).",
          subline: "Heute ist Recovery-Tag in deinem Plan. Log deine erste Mahlzeit, dann hast du den ersten Win schon eingefahren.",
          primary: CoachActionDescriptor(
            title: "Mahlzeit loggen",
            icon: "fork.knife",
            metric: nil,
            action: .openNutritionCapture
          ),
          secondary: CoachActionDescriptor(
            title: "Plan ansehen",
            icon: "calendar",
            metric: nil,
            action: .openPlanner
          )
        )

      case .flexible:
        return CoachBrief(
          eyebrow: "TAG 1",
          glyph: "sparkles",
          accent: GainsColor.accentCool,
          headline: "Willkommen\(warmName).",
          subline: "Heute ist flexibel — du wählst. Erstes Workout, kurzer Lauf oder einfach eine Mahlzeit loggen. Jeder erste Schritt zählt.",
          primary: CoachActionDescriptor(
            title: "Workout starten",
            icon: "play.fill",
            metric: nil,
            action: .startQuickWorkout
          ),
          secondary: CoachActionDescriptor(
            title: "Plan ansehen",
            icon: "calendar",
            metric: nil,
            action: .openPlanner
          )
        )
      }
    }

    // 1.7) Re-engagement: User hat onboardet, ist aus dem Day-One-Window
    // raus (hoursSince ≥ 24) und hat trotzdem noch nichts getrackt — weder
    // Workout noch Lauf. Ohne diesen Brief würde er den generischen
    // „BEREIT?"-Default sehen, der ihn nicht abholt. Hier kein Streak-Druck
    // (er hatte ja nie eine Streak), sondern warmer, einladender Ton.
    // Bricht weg, sobald die erste Session steht.
    if onboardingCompletedAt > 0,
       !isInDayOneWindow,
       store.workoutHistory.isEmpty,
       store.runHistory.isEmpty,
       store.lastCompletedWorkout == nil {
      let completedAt = Date(timeIntervalSince1970: onboardingCompletedAt)
      let daysSince = max(Calendar.current.dateComponents([.day], from: completedAt, to: now).day ?? 1, 1)
      let plan = store.todayPlannedDay
      let trimmedName = store.userName.trimmingCharacters(in: .whitespacesAndNewlines)
      let warmName = trimmedName.isEmpty ? "" : ", \(trimmedName)"

      // Headline-Ton skaliert mit daysSince — bewusst keine Schuldzuweisung,
      // sondern „komm rein, wir machen es leicht".
      let headline: String
      let subline: String
      if daysSince <= 2 {
        headline = "Erster Schritt steht aus\(warmName)."
        subline = plan.runTemplate != nil
          ? "Heute steht dein erster Lauf im Plan. 15 Minuten reichen schon."
          : "Heute ist ein guter Tag für die erste Session — kurz und gut."
      } else if daysSince <= 7 {
        headline = "Lass uns klein anfangen."
        subline = "Du hast den Plan da, jetzt fehlt nur die erste Session. Dauert keine 30 Minuten."
      } else {
        headline = "Frischer Start gefällig?"
        subline = "Plan steht noch. Wir gehen es langsam an — du wählst die Intensität."
      }

      let primaryAction: CoachActionDescriptor
      if plan.runTemplate != nil {
        primaryAction = CoachActionDescriptor(
          title: "Ersten Lauf starten",
          icon: "play.fill",
          metric: String(format: "%.1f km", plan.runTemplate?.targetDistanceKm ?? 0),
          action: .startQuickRun
        )
      } else if plan.status == .planned {
        primaryAction = CoachActionDescriptor(
          title: "Erste Session",
          icon: "play.fill",
          metric: plan.workoutPlan.map { "\($0.exercises.count) Übungen" },
          action: .startPlannedWorkout
        )
      } else {
        primaryAction = CoachActionDescriptor(
          title: "Spontan starten",
          icon: "play.fill",
          metric: nil,
          action: .startQuickWorkout
        )
      }

      return CoachBrief(
        eyebrow: "BEREIT WANN DU BIST",
        glyph: "leaf.fill",
        accent: GainsColor.accentCool,
        headline: headline,
        subline: subline,
        primary: primaryAction,
        secondary: CoachActionDescriptor(
          title: "Plan ansehen",
          icon: "calendar",
          metric: nil,
          action: .openPlanner
        )
      )
    }

    // 2) Frischer Workout-Abschluss heute — Nachladen anbieten.
    if let last = store.lastCompletedWorkout,
       Calendar.current.isDateInToday(last.finishedAt) {
      let minutesSince = Int(now.timeIntervalSince(last.finishedAt) / 60)
      let proteinGap = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
      // PR-Check: höchstes Volumen in der Geschichte = heute?
      let allTimePeak = store.workoutHistory.map(\.volume).max() ?? 0
      let isVolumePR = last.volume >= allTimePeak && last.volume > 0
      if isVolumePR {
        return CoachBrief(
          eyebrow: "PR GEHOLT",
          glyph: "trophy.fill",
          accent: GainsColor.lime,
          headline: "Heute war ein Tag fürs Buch.",
          subline: "\(last.title) · \(Int(last.volume)) kg Volumen — neuer Bestwert. Sieh dir die Story an.",
          primary: CoachActionDescriptor(
            title: "Story ansehen",
            icon: "chart.line.uptrend.xyaxis",
            metric: String(format: "%.1f t", last.volume / 1000),
            action: .openProgress
          ),
          secondary: proteinGap > 0
            ? CoachActionDescriptor(
                title: "Protein nachladen",
                icon: "fork.knife",
                metric: "\(proteinGap) g offen",
                action: .openNutritionCapture
              )
            : nil
        )
      }
      if minutesSince <= 90 && proteinGap >= 20 {
        return CoachBrief(
          eyebrow: "POST-WORKOUT",
          glyph: "fork.knife",
          accent: GainsColor.ember,
          headline: "Solide Session — jetzt nachladen.",
          subline: "\(last.title) abgeschlossen vor \(minutesSince) min. Noch \(proteinGap) g Protein offen.",
          primary: CoachActionDescriptor(
            title: "Mahlzeit loggen",
            icon: "camera.fill",
            metric: "\(proteinGap) g",
            action: .openNutritionCapture
          ),
          secondary: CoachActionDescriptor(
            title: "Session ansehen",
            icon: "chart.bar.fill",
            metric: nil,
            action: .openProgress
          )
        )
      }
      if minutesSince <= 30 {
        return CoachBrief(
          eyebrow: "GESCHAFFT",
          glyph: "checkmark.circle.fill",
          accent: GainsColor.lime,
          headline: "Sauber abgeliefert.",
          subline: "\(last.title) · \(last.completedSets) Sätze · \(Int(last.volume)) kg Volumen. Trink was, dann weiter.",
          primary: CoachActionDescriptor(
            title: "Wochenstand ansehen",
            icon: "chart.line.uptrend.xyaxis",
            metric: progressDisplayTitle,
            action: .openProgress
          ),
          secondary: CoachActionDescriptor(
            title: "Mahlzeit loggen",
            icon: "fork.knife",
            metric: nil,
            action: .openNutritionCapture
          )
        )
      }
    }

    // 3) Streak in Gefahr — abends, Streak ≥ 3, heute keine Aktivität.
    if store.streakDays >= 3,
       hour >= 19,
       !hasAnyActivityToday {
      let hoursLeft = max(24 - hour, 1)
      return CoachBrief(
        eyebrow: "STREAK SCHÜTZEN",
        glyph: "flame.fill",
        accent: GainsColor.ember,
        headline: "Noch \(hoursLeft) h für die \(store.streakDays)-Tage-Streak.",
        subline: "Eine Mahlzeit oder ein 20-min-Walk reichen, um den Tag als aktiv zu markieren.",
        primary: CoachActionDescriptor(
          title: "Schnell-Workout",
          icon: "play.fill",
          metric: "20 min",
          action: .startQuickWorkout
        ),
        secondary: CoachActionDescriptor(
          title: "Lauf statt Kraft",
          icon: "figure.run",
          metric: nil,
          action: .startQuickRun
        )
      )
    }

    // 4) Workout-Fenster (15-21 Uhr) — heute geplant, noch nicht trainiert.
    if hour >= 15, hour < 22,
       store.todayPlannedDay.status == .planned,
       !hasCompletedWorkoutToday {
      let plan = store.todayPlannedDay
      if let runTemplate = plan.runTemplate {
        return CoachBrief(
          eyebrow: "LAUF-FENSTER",
          glyph: "figure.run",
          accent: GainsColor.ember,
          headline: "Heute steht \(runTemplate.title.lowercased()) an.",
          subline: String(
            format: "%.1f km · ~%d min. Bestes Timing: jetzt — Wetter & Energie passen.",
            runTemplate.targetDistanceKm,
            runTemplate.targetDurationMinutes
          ),
          primary: CoachActionDescriptor(
            title: "Lauf starten",
            icon: "play.fill",
            metric: String(format: "%.1f km", runTemplate.targetDistanceKm),
            action: .startQuickRun
          ),
          secondary: CoachActionDescriptor(
            title: "Plan anpassen",
            icon: "calendar",
            metric: nil,
            action: .openPlanner
          )
        )
      }
      let workoutTitle = plan.workoutPlan?.title ?? plan.title
      return CoachBrief(
        eyebrow: "WORKOUT-FENSTER",
        glyph: "dumbbell.fill",
        accent: GainsColor.lime,
        headline: "\(workoutTitle) wartet — let's go.",
        subline: "Heutiger Plan: \(plan.focus). Bestes Slot-Fenster läuft bis 21 Uhr.",
        primary: CoachActionDescriptor(
          title: "Training starten",
          icon: "play.fill",
          metric: plan.workoutPlan.map { "\($0.exercises.count) Übungen" },
          action: .startPlannedWorkout
        ),
        secondary: CoachActionDescriptor(
          title: "Plan ansehen",
          icon: "calendar",
          metric: nil,
          action: .openPlanner
        )
      )
    }

    // 5) Morgens (vor 11 Uhr), Plan steht.
    if hour < 11, store.todayPlannedDay.status == .planned {
      let plan = store.todayPlannedDay
      if let runTemplate = plan.runTemplate {
        return CoachBrief(
          eyebrow: "GUTEN MORGEN",
          glyph: "sun.max.fill",
          accent: GainsColor.ember,
          headline: "Heute läuft \(runTemplate.title.lowercased()).",
          subline: String(
            format: "%.1f km im Plan. Empfohlene Slots: 07–09 Uhr oder 17–19 Uhr.",
            runTemplate.targetDistanceKm
          ),
          primary: CoachActionDescriptor(
            title: "Lauf starten",
            icon: "play.fill",
            metric: String(format: "%.1f km", runTemplate.targetDistanceKm),
            action: .startQuickRun
          ),
          secondary: CoachActionDescriptor(
            title: "Wochenplan",
            icon: "calendar",
            metric: nil,
            action: .openPlanner
          )
        )
      }
      let workoutTitle = plan.workoutPlan?.title ?? plan.title
      return CoachBrief(
        eyebrow: "GUTEN MORGEN",
        glyph: "sun.max.fill",
        accent: GainsColor.lime,
        headline: "Heute steht \(workoutTitle) an.",
        subline: "Plan-Fokus: \(plan.focus). Slots 16–19 Uhr sind erfahrungsgemäß deine besten.",
        primary: CoachActionDescriptor(
          title: "Plan ansehen",
          icon: "calendar",
          metric: plan.workoutPlan.map { "\($0.exercises.count) Übungen" },
          action: .openPlanner
        ),
        secondary: CoachActionDescriptor(
          title: "Direkt starten",
          icon: "play.fill",
          metric: nil,
          action: .startPlannedWorkout
        )
      )
    }

    // 6) Comeback — letzter Workout ≥ 4 Tage her.
    if let last = store.lastCompletedWorkout {
      let days = Calendar.current.dateComponents([.day], from: last.finishedAt, to: now).day ?? 0
      if days >= 4, !hasCompletedWorkoutToday {
        return CoachBrief(
          eyebrow: "COMEBACK",
          glyph: "arrow.counterclockwise",
          accent: GainsColor.accentCool,
          headline: "\(days) Tage Pause — Zeit zurück in den Rhythmus.",
          subline: "Letzter Stand: \(last.title), \(last.completedSets) Sätze. Ein lockerer Start ist Gold wert.",
          primary: CoachActionDescriptor(
            title: "Spontan starten",
            icon: "play.fill",
            metric: nil,
            action: .startQuickWorkout
          ),
          secondary: CoachActionDescriptor(
            title: "Plan ansehen",
            icon: "calendar",
            metric: nil,
            action: .openPlanner
          )
        )
      }
    }

    // 7) Rest-Tag — bewusst ruhig.
    if store.todayPlannedDay.status == .rest {
      let hrvDetail: String = {
        if let hrv = store.healthSnapshot?.heartRateVariability {
          return "HRV \(Int(hrv)) ms"
        }
        if let sleep = store.healthSnapshot?.sleepHoursLastNight {
          return String(format: "Schlaf %.1f h", sleep)
        }
        return "Recovery-Modus"
      }()
      return CoachBrief(
        eyebrow: "RECOVERY-TAG",
        glyph: "leaf.fill",
        accent: GainsColor.accentCool,
        headline: "Heute füllt sich der Tank.",
        subline: "\(hrvDetail). Spaziergang, Mobility oder ein lockerer Rad-Schwung passen.",
        primary: CoachActionDescriptor(
          title: "Mahlzeit loggen",
          icon: "fork.knife",
          metric: nil,
          action: .openNutritionCapture
        ),
        secondary: CoachActionDescriptor(
          title: "Wochenplan",
          icon: "calendar",
          metric: nil,
          action: .openPlanner
        )
      )
    }

    // 8) Nutrition-Lücke abends.
    if hour >= 18, kcalProgressRatio < 0.6 {
      let remainingKcal = max(store.nutritionTargetCalories - store.nutritionCaloriesToday, 0)
      let remainingProtein = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
      return CoachBrief(
        eyebrow: "NACHTANKEN",
        glyph: "fork.knife",
        accent: GainsColor.ember,
        headline: "Noch \(remainingKcal) kcal offen heute.",
        subline: remainingProtein > 0
          ? "Davon \(remainingProtein) g Protein. Eine warme Mahlzeit schließt das sauber."
          : "Protein steht — du brauchst noch Energie. Carb-Fokus passt.",
        primary: CoachActionDescriptor(
          title: "Mahlzeit loggen",
          icon: "camera.fill",
          metric: "\(remainingKcal) kcal",
          action: .openNutritionCapture
        ),
        secondary: CoachActionDescriptor(
          title: "Schnell-Add",
          icon: "bolt.fill",
          metric: nil,
          action: .openNutrition
        )
      )
    }

    // 9) Abendroutine — alles erledigt.
    if hour >= 21, store.weeklySessionsCompleted >= store.weeklyGoalCount,
       store.nutritionCaloriesToday >= Int(Double(store.nutritionTargetCalories) * 0.9) {
      return CoachBrief(
        eyebrow: "ABENDROUTINE",
        glyph: "moon.fill",
        accent: GainsColor.accentCool,
        headline: "Tagesziele drin — Zeit zum Runterfahren.",
        subline: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Sessions, \(store.nutritionCaloriesToday) kcal. Schlaf wird heute belohnt.",
        primary: CoachActionDescriptor(
          title: "Wochenstand",
          icon: "chart.line.uptrend.xyaxis",
          metric: progressDisplayTitle,
          action: .openProgress
        ),
        secondary: nil
      )
    }

    // 10) Flex-Tag — heute offen.
    if store.todayPlannedDay.status == .flexible {
      return CoachBrief(
        eyebrow: "FLEX-TAG",
        glyph: "infinity",
        accent: GainsColor.accentCool,
        headline: "Heute bleibt offen — was passt?",
        subline: "Kein fester Plan. Spontanes Workout, Lauf oder Mobility sind alle gleich richtig.",
        primary: CoachActionDescriptor(
          title: "Spontan trainieren",
          icon: "play.fill",
          metric: nil,
          action: .startQuickWorkout
        ),
        secondary: CoachActionDescriptor(
          title: "Lauf starten",
          icon: "figure.run",
          metric: nil,
          action: .startQuickRun
        )
      )
    }

    // 11) Default — Plan-Status anzeigen.
    let plan = store.todayPlannedDay
    let title = plan.workoutPlan?.title ?? plan.title
    return CoachBrief(
      eyebrow: "BEREIT?",
      glyph: "play.fill",
      accent: GainsColor.lime,
      headline: title.isEmpty ? "Was passt gerade?" : "Heute: \(title).",
      subline: store.coachHeadline,
      primary: CoachActionDescriptor(
        title: "Training starten",
        icon: "play.fill",
        metric: nil,
        action: plan.status == .planned ? .startPlannedWorkout : .startQuickWorkout
      ),
      secondary: CoachActionDescriptor(
        title: "Plan ansehen",
        icon: "calendar",
        metric: nil,
        action: .openPlanner
      )
    )
  }

  // MARK: - Pulse Stats (3 kontextuelle Mini-Werte)

  private var currentPulseStats: [PulseStat] {
    let hour = Calendar.current.component(.hour, from: coachClock)
    let plan = store.todayPlannedDay

    // Workout läuft → Sätze, Volumen, HF.
    if let aw = store.activeWorkout {
      var stats: [PulseStat] = [
        PulseStat(
          icon: "checkmark.circle.fill",
          label: "SÄTZE",
          value: "\(aw.completedSets)",
          unit: "/\(aw.totalSets)",
          detail: "Live-Session",
          accent: GainsColor.lime,
          action: .openWorkoutTracker
        ),
        PulseStat(
          icon: "scalemass.fill",
          label: "VOL",
          value: String(format: "%.1f", aw.totalVolume / 1000),
          unit: "t",
          detail: "Heute",
          accent: GainsColor.accentCool,
          action: .openWorkoutTracker
        )
      ]
      if let bpm = liveAnyHeartRate {
        stats.append(
          PulseStat(
            icon: "heart.fill",
            label: "HF",
            value: "\(bpm)",
            unit: "bpm",
            detail: "Live",
            accent: GainsColor.ember,
            action: .openProfile
          )
        )
      } else {
        stats.append(streakStat)
      }
      return stats
    }

    // Run läuft → Distanz, Pace, HF.
    if let ar = store.activeRun {
      let mins = ar.durationMinutes / 60
      let secs = ar.durationMinutes % 60
      return [
        PulseStat(
          icon: "ruler",
          label: "STRECKE",
          value: String(format: "%.2f", ar.distanceKm),
          unit: "km",
          detail: "Live",
          accent: GainsColor.ember,
          action: .openRunTracker
        ),
        PulseStat(
          icon: "stopwatch.fill",
          label: "ZEIT",
          value: String(format: "%d:%02d", mins, secs),
          unit: "",
          detail: "min",
          accent: GainsColor.accentCool,
          action: .openRunTracker
        ),
        PulseStat(
          icon: "heart.fill",
          label: "HF",
          value: "\(ar.currentHeartRate)",
          unit: "bpm",
          detail: "Live",
          accent: GainsColor.lime,
          action: .openRunTracker
        )
      ]
    }

    // Day-One-Window: Setup-Status statt 0t-Volumen. Drei positive Tiles,
    // die zeigen, was der User schon erreicht hat (Profil, Plan, Permissions),
    // statt Stats, die naturgemäß bei null stehen. Endowed-Progress —
    // Fortschrittsbalken nicht bei 0 starten lassen.
    if isInDayOneWindow {
      let plannedTrainingDays = store.weeklyWorkoutSchedule.filter { $0.status == .planned }.count
      let dayOneStats: [PulseStat] = [
        PulseStat(
          icon: "checkmark.seal.fill",
          label: "SETUP",
          value: "100",
          unit: "%",
          detail: "Profil + Plan",
          accent: GainsColor.lime,
          action: .openProfile
        ),
        PulseStat(
          icon: "calendar",
          label: "PLAN",
          value: "\(plannedTrainingDays)",
          unit: "T",
          detail: "diese Woche",
          accent: GainsColor.accentCool,
          action: .openPlanner
        ),
        PulseStat(
          icon: "flame.fill",
          label: "TAG",
          value: "1",
          unit: "",
          detail: "deiner Reise",
          accent: GainsColor.ember,
          action: .openProgress
        )
      ]
      return dayOneStats
    }

    // Post-Workout-Window (heute trainiert, < 2h) → Protein-offen, kcal, Streak.
    if let last = store.lastCompletedWorkout,
       Calendar.current.isDateInToday(last.finishedAt),
       coachClock.timeIntervalSince(last.finishedAt) < 7200 {
      let proteinGap = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
      return [
        PulseStat(
          icon: "fork.knife",
          label: "PROTEIN",
          value: proteinGap == 0 ? "✓" : "\(proteinGap)",
          unit: proteinGap == 0 ? "" : "g",
          detail: proteinGap == 0 ? "Im Ziel" : "Offen",
          accent: GainsColor.ember,
          action: .openNutritionCapture
        ),
        PulseStat(
          icon: "flame.fill",
          label: "KCAL",
          value: "\(store.nutritionCaloriesToday)",
          unit: "/\(store.nutritionTargetCalories)",
          detail: "Heute",
          accent: GainsColor.lime,
          action: .openNutrition
        ),
        streakStat
      ]
    }

    // Rest-Tag → Recovery-Daten + Streak.
    if plan.status == .rest {
      var stats: [PulseStat] = []
      if let hrv = store.healthSnapshot?.heartRateVariability {
        stats.append(
          PulseStat(
            icon: "waveform.path.ecg",
            label: "HRV",
            value: "\(Int(hrv))",
            unit: "ms",
            detail: "Letzte Nacht",
            accent: GainsColor.accentCool,
            action: .openProgress
          )
        )
      }
      if let sleep = store.healthSnapshot?.sleepHoursLastNight {
        stats.append(
          PulseStat(
            icon: "moon.fill",
            label: "SCHLAF",
            value: String(format: "%.1f", sleep),
            unit: "h",
            detail: "Letzte Nacht",
            accent: GainsColor.lime,
            action: .openProgress
          )
        )
      }
      if let resting = store.healthSnapshot?.restingHeartRate {
        stats.append(
          PulseStat(
            icon: "heart.fill",
            label: "RUHEPULS",
            value: "\(Int(resting))",
            unit: "bpm",
            detail: "Heute",
            accent: GainsColor.ember,
            action: .openProgress
          )
        )
      }
      while stats.count < 3 {
        if stats.count == 0 { stats.append(streakStat) }
        else if stats.count == 1 { stats.append(weeklyStat) }
        else { stats.append(kcalStat) }
      }
      return Array(stats.prefix(3))
    }

    // Abend (>= 18h) → kcal, Protein, Streak.
    if hour >= 18 {
      return [kcalStat, proteinStat, streakStat]
    }

    // Default (Morgen/Mittag) → Streak, Wochenfortschritt, kcal.
    return [streakStat, weeklyStat, kcalStat]
  }

  private var streakStat: PulseStat {
    PulseStat(
      icon: "flame.fill",
      label: "STREAK",
      value: "\(store.streakDays)",
      unit: "T",
      detail: store.streakDays >= 7 ? "Stark dran" : "Aufbauen",
      accent: GainsColor.lime,
      action: .openProgress
    )
  }

  private var weeklyStat: PulseStat {
    PulseStat(
      icon: "target",
      label: "WOCHE",
      value: "\(store.weeklySessionsCompleted)",
      unit: "/\(store.weeklyGoalCount)",
      detail: progressDisplayTitle,
      accent: GainsColor.accentCool,
      action: .openProgress
    )
  }

  private var kcalStat: PulseStat {
    let pct = Int(kcalProgressRatio * 100)
    return PulseStat(
      icon: "flame.fill",
      label: "KCAL",
      value: "\(store.nutritionCaloriesToday)",
      unit: "kcal",
      detail: "\(pct) % v. Ziel",
      accent: GainsColor.ember,
      action: .openNutrition
    )
  }

  private var proteinStat: PulseStat {
    let gap = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
    return PulseStat(
      icon: "fork.knife",
      label: "PROTEIN",
      value: "\(store.nutritionProteinToday)",
      unit: "/\(store.nutritionTargetProtein) g",
      detail: gap == 0 ? "Im Ziel" : "Noch \(gap) g",
      accent: GainsColor.ember,
      action: .openNutrition
    )
  }

  // MARK: - Spotlight Choice (welche Card laut, welche kompakt)

  private enum SpotlightChoice { case cockpit, nutrition }

  private var currentSpotlight: SpotlightChoice {
    let hour = Calendar.current.component(.hour, from: coachClock)
    // Workout läuft oder Plan-/Workout-Fenster → Cockpit zuerst.
    if store.activeWorkout != nil || store.activeRun != nil {
      return .cockpit
    }
    // Post-Workout (< 2h) → Nutrition zuerst (Nachladen).
    if let last = store.lastCompletedWorkout,
       Calendar.current.isDateInToday(last.finishedAt),
       coachClock.timeIntervalSince(last.finishedAt) < 7200 {
      return .nutrition
    }
    // Essenszeit (Mittag 12-14, Abend 18-21) → Nutrition zuerst.
    if (12...13).contains(hour) || (18...20).contains(hour) {
      return .nutrition
    }
    // Default → Cockpit (Wochenfortschritt steht oben).
    return .cockpit
  }

  // MARK: - Adaptive Tile Pool (4 von 6 Tiles, kontextuelle Reihenfolge)

  private var adaptiveTiles: [ActionTileSpec] {
    let hour = Calendar.current.component(.hour, from: coachClock)
    let plan = store.todayPlannedDay
    let runningRun = store.activeRun != nil

    let trainingTile = ActionTileSpec(
      kind: .training,
      eyebrow: "PLAN",
      title: "Training",
      subtitle: store.coachHeadline,
      icon: "dumbbell.fill",
      accent: GainsColor.lime,
      isLive: store.activeWorkout != nil,
      action: .openTrainingTab
    )
    let cardioTile = ActionTileSpec(
      kind: .cardio,
      eyebrow: "CARDIO",
      title: runningRun ? "Run live" : "Lauf",
      subtitle: runningRun
        ? String(
            format: "%.1f km · %02d:%02d",
            store.activeRun?.distanceKm ?? 0,
            (store.activeRun?.durationMinutes ?? 0) / 60,
            (store.activeRun?.durationMinutes ?? 0) % 60
          )
        : "GPS · Outdoor",
      icon: "figure.run",
      accent: GainsColor.ember,
      isLive: runningRun,
      action: .startQuickRun
    )
    let progressTile = ActionTileSpec(
      kind: .progress,
      eyebrow: "INSIGHTS",
      title: "Fortschritt",
      subtitle: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Einheiten",
      icon: "chart.line.uptrend.xyaxis",
      accent: GainsColor.accentCool,
      isLive: false,
      action: .openProgress
    )
    let mealTile = ActionTileSpec(
      kind: .meal,
      eyebrow: "MAHLZEIT",
      title: "Schnell loggen",
      subtitle: "Foto · Barcode · Manuell",
      icon: "fork.knife",
      accent: GainsColor.ember,
      isLive: false,
      action: .openNutritionCapture
    )
    let waterTile = ActionTileSpec(
      kind: .water,
      eyebrow: "HYDRATION",
      title: "Wasser",
      subtitle: "+250 ml · Tracking",
      icon: "drop.fill",
      accent: GainsColor.accentCool,
      isLive: false,
      action: .openNutrition
    )
    let plannerTile = ActionTileSpec(
      kind: .planner,
      eyebrow: "WOCHE",
      title: "Plan",
      subtitle: nextPlannedSchedule.map { "\($0.weekday.shortLabel.uppercased()) · \($0.title)" } ?? "Wochenplan anpassen",
      icon: "calendar",
      accent: GainsColor.lime,
      isLive: false,
      action: .openPlanner
    )

    // Priorisierung nach Kontext:
    // H1-Fix (2026-05-01): plannerTile war zwischenzeitlich draußen, weil
    // der cockpitPlanRow im Spotlight bereits den dedizierten Plan-Einstieg
    // lieferte. Das 2x2-Grid soll Aktionen zeigen, die nicht schon im
    // Spotlight liegen.
    //
    // 2026-05-03: Mit der Schnellstart-Bar oben sind Workout/Lauf jetzt
    // immer auf Höhe 1. trainingTile/cardioTile dürfen daher in den nicht-
    // DayOne-Pfaden NICHT mehr ins Grid — das wäre wieder „drei Wege auf
    // einer Höhe". Der frei werdende Slot wird vom plannerTile genommen
    // (cockpitPlanRow ist Insight-Card, plannerTile ist die Aktion, die
    // den Wochenplan aufmacht — andere Funktion, akzeptable Nähe).
    // `trainingTile` / `cardioTile` bleiben als Variablen für die
    // DayOne-Logik unten und für eventuelle künftige Slot-Wechsel; in den
    // Standard-Pfaden werden sie bewusst nicht zurückgegeben.
    _ = trainingTile
    _ = cardioTile

    // Day-One: Tiles auf Setup-Discovery zugeschnitten. Im ersten Tag
    // hilft kein „PR holen" — der User braucht Pfade zum Erkunden, und
    // das erste Workout/Lauf wird hier bewusst doppelt prominent (Bar
    // oben + Hero-Tile unten), weil Discovery vor Redundanz-Hygiene geht.
    if isInDayOneWindow {
      let primaryFirstAction: ActionTileSpec = {
        if plan.runTemplate != nil {
          return ActionTileSpec(
            kind: .cardio,
            eyebrow: "ERSTER LAUF",
            title: "Lauf starten",
            subtitle: "GPS · wir führen dich",
            icon: "play.fill",
            accent: GainsColor.ember,
            isLive: false,
            action: .startQuickRun
          )
        }
        return ActionTileSpec(
          kind: .training,
          eyebrow: "ERSTE SESSION",
          title: "Training starten",
          subtitle: plan.workoutPlan?.title ?? "Heute geplant",
          icon: "play.fill",
          accent: GainsColor.lime,
          isLive: false,
          action: .startPlannedWorkout
        )
      }()
      return [primaryFirstAction, mealTile, plannerTile, progressTile]
    }

    if let last = store.lastCompletedWorkout,
       Calendar.current.isDateInToday(last.finishedAt),
       coachClock.timeIntervalSince(last.finishedAt) < 7200 {
      // Post-Workout: Mahlzeit, Wasser, Fortschritt, Plan
      return [mealTile, waterTile, progressTile, plannerTile]
    }

    if plan.status == .rest {
      // Rest-Tag: Mahlzeit, Wasser, Fortschritt, Plan
      return [mealTile, waterTile, progressTile, plannerTile]
    }

    if hour >= 18 {
      // Abend: Mahlzeit, Wasser, Fortschritt, Plan (für morgen vorblicken)
      return [mealTile, waterTile, progressTile, plannerTile]
    }

    if hour < 11 {
      // Morgen: Plan voraus, Fortschritt, Mahlzeit, Wasser
      return [plannerTile, progressTile, mealTile, waterTile]
    }

    // Default (Mittag/Nachmittag): Mahlzeit, Wasser, Fortschritt, Plan
    return [mealTile, waterTile, progressTile, plannerTile]
  }

  // MARK: - Coach State Helpers

  private var hasCompletedWorkoutToday: Bool {
    guard let last = store.lastCompletedWorkout else { return false }
    return Calendar.current.isDateInToday(last.finishedAt)
  }

  private var hasAnyActivityToday: Bool {
    if hasCompletedWorkoutToday { return true }
    if !store.todayNutritionEntries.isEmpty { return true }
    if store.activeWorkout != nil || store.activeRun != nil { return true }
    return false
  }

  // Phase 1 Aha-Moment: Ersten 24h nach Onboarding gilt der User als
  // „brand-neu" — solange er noch kein einziges Workout/Lauf abgeschlossen
  // hat. Sobald die erste Session getrackt wurde (oder 24h um sind), fällt
  // der dayOne-Coach-Brief weg und die normale Priority-Kette greift.
  private var isInDayOneWindow: Bool {
    guard onboardingCompletedAt > 0 else { return false }
    let completedAt = Date(timeIntervalSince1970: onboardingCompletedAt)
    let hoursSince = coachClock.timeIntervalSince(completedAt) / 3600
    guard hoursSince >= 0, hoursSince < 24 else { return false }
    if !store.workoutHistory.isEmpty { return false }
    if store.lastCompletedWorkout != nil { return false }
    return true
  }

  private var liveAnyHeartRate: Int? {
    if let bpm = ble.liveHeartRate { return bpm }
    if let bpm = HealthKitManager.shared.liveHeartRate { return bpm }
    if let bpm = store.liveWorkoutHeartRate { return bpm }
    return nil
  }

  // MARK: - Coach Action Dispatch

  /// Single dispatch point — alle Buttons des Hero, der Pulse-Strip, des
  /// Action-Grids und der Sekundärlinks landen hier.
  ///
  /// Haptik: ein leichter Impact pro Tap — gibt dem User auf JEDEM Coach-
  /// gesteuerten Button (Hero-Primary, Hero-Secondary, Pulse-Tile, Action-
  /// Tile) sofortiges taktiles Feedback. Vorher hatte nur der Workout-
  /// Tracker Haptik, der Home-Screen war taktil stumm.
  private func runCoachAction(_ action: CoachAction) {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    switch action {
    case .openWorkoutTracker:
      isShowingWorkoutTracker = true
    case .openRunTracker:
      isShowingRunTracker = true
    case .openProgress:
      isShowingProgress = true
    case .openProfile:
      isShowingProfile = true
    case .openPlanner:
      navigation.openPlanner()
    case .openNutrition:
      navigation.openNutrition()
    case .openNutritionCapture:
      navigation.presentCapture(kind: .meal)
    case .openTrainingTab:
      navigation.openTraining(workspace: .kraft)
    case .startQuickWorkout:
      startFreeWorkout()
    case .startQuickRun:
      startQuickRun()
    case .startPlannedWorkout:
      if let plan = store.todayPlannedWorkout {
        presentArrange(for: plan)
      } else if store.todayPlannedDay.runTemplate != nil {
        startQuickRun()
      } else {
        startFreeWorkout()
      }
    }
  }

  // MARK: - Workout Helpers (unverändert)

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

  /// Modality-spezifischer Quick-Start. Long-Press-Shortcuts der Cardio-
  /// Kachel rufen das hier mit `.bikeOutdoor` bzw. `.bikeIndoor`, damit der
  /// User die Modus-Auswahl im Setup-Sheet überspringen kann.
  private func startQuickRun(modality: CardioModality) {
    if store.activeRun == nil {
      store.startQuickRun(modality: modality)
    }
    isShowingRunTracker = true
  }

  private func presentArrange(for plan: WorkoutPlan) {
    if store.activeWorkout == nil {
      store.startWorkout(from: plan)
    }
    arrangingPlan = plan
  }

  /// A6: Führt eine geparkte Folge-Aktion aus dem `onDismiss`-Callback aus.
  private func runPending(_ slot: inout (() -> Void)?) {
    guard let action = slot else { return }
    slot = nil
    action()
  }

  private var currentDateParts: (day: String, date: String, week: String) {
    let now = Date()
    let week = Calendar.current.component(.weekOfYear, from: now)
    return (
      HomeFormatters.weekdayShortDE.string(from: now).uppercased(),
      HomeFormatters.dayMonthEN.string(from: now).uppercased(),
      "WK \(week)"
    )
  }
}

// MARK: - Coach Brief Model

private struct CoachBrief {
  let eyebrow: String
  let glyph: String
  let accent: Color
  let headline: String
  let subline: String
  let primary: CoachActionDescriptor
  let secondary: CoachActionDescriptor?
}

private struct CoachActionDescriptor {
  let title: String
  let icon: String
  let metric: String?
  let action: CoachAction
}

private enum CoachAction {
  case openWorkoutTracker
  case openRunTracker
  case openProgress
  case openProfile
  case openPlanner
  case openNutrition
  case openNutritionCapture
  case openTrainingTab
  case startQuickWorkout
  case startQuickRun
  case startPlannedWorkout
}

private struct PulseStat {
  let icon: String
  let label: String
  let value: String
  let unit: String
  let detail: String
  let accent: Color
  let action: CoachAction
}

private struct ActionTileSpec {
  enum Kind: Hashable { case training, cardio, progress, meal, water, planner }

  let kind: Kind
  let eyebrow: String
  let title: String
  let subtitle: String
  let icon: String
  let accent: Color
  let isLive: Bool
  let action: CoachAction
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
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
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
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .foregroundStyle(GainsColor.lime.opacity(0.55))
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
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
        RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
          .stroke(GainsColor.lime.opacity(0.55), lineWidth: 1.4)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
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
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
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
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
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
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
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
