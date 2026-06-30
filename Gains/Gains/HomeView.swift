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

  static let dayMonthDE: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "dd MMM"
    return f
  }()
}

// 2026-05-03 P0 B: Lock-States für die kurze Lücke zwischen User-Tap auf
// einen „Start …"-CTA und dem tatsächlichen Publish des `activeWorkout`/
// `activeRun`-Modells im Store. Der Coach-Brief liest diesen State und
// zeigt eine konsistente Übergangs-Variante statt zurück auf Day-One/
// Window-Brief zu fallen.
enum PendingActionLock: Equatable {
  case startingWorkout
  case startingRun
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
  // 2026-05-03 Intuitivitäts-Sweep P0 B: Wenn der User einen Coach-CTA tippt
  // (z. B. „Workout starten"), liegt zwischen Tap und tatsächlichem
  // `store.activeWorkout != nil` ein kleines Zeitfenster. In diesem Fenster
  // konnte `currentCoachBrief` zwischen Day-One/Workout-Window und „Workout
  // läuft" flackern. `pendingActionLock` zeigt der Engine an, welche
  // Variante priorisiert gehalten werden soll, bis die echte Session
  // publiziert ist (oder das Sheet wieder zugeht).
  @State private var pendingActionLock: PendingActionLock? = nil
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
  // 2026-05-15: Wochenplan via navigation.openWeekPlanFullscreen() —
  // ContentView präsentiert die Sheet global über AppNavigationStore.

  // Aktualisiert sich jede Minute, damit der Coach-Brief Variants wechselt
  // (z. B. „Workout-Fenster" → „Streak schützen") ohne dass der Nutzer die
  // App neu öffnen muss.
  //
  // 2026-05-14 Audit-Step 3: Vorher lief der Timer als
  // `Timer.publish(...).autoconnect()` permanent, auch wenn HomeView nicht
  // sichtbar war. Jetzt wird das Ticken über `.task` an den View-Lifecycle
  // gebunden — SwiftUI cancelt die Task automatisch bei onDisappear, kein
  // 60-s-Wake-Up mehr im Hintergrund.
  @State private var coachClock = Date()
  // 2026-05-14 (Brand-Loop 11): Variable-Reward Insight pro App-Start.
  // Wird beim ersten `onAppear` aus der `GainsInsightEngine` gezogen
  // (caches die ID 7 Tage, damit keine Wiederholung).
  @State private var dailyInsight: GainsInsight?

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
        // 2026-05-14 (Polish-Loop 44): VStack mit fixed width + safe
        // padding um den Content stabil zu sizen. Verhindert subtile
        // re-layouts bei elastischem Scroll.
        VStack(alignment: .leading, spacing: GainsSpacing.l) {
          // 2026-05-14 (Audit-Loop 3): Recovery-Banner ganz oben, wenn
          // ein unbeendeter Workout aus einer früheren Session gefunden
          // wurde. Liegt VOR dem Greeting — das ist die wichtigste
          // Information beim Aufmachen der App.
          if let pending = store.recoverableWorkout {
            workoutRecoveryBanner(pending)
              .transition(.opacity.combined(with: .move(edge: .top)))
          }

          // A14: Greeting + Coach-Brief sind als ein zusammengehöriges
          // Gruppen-Pärchen gedacht — engerer Abstand (`.tight` = 10pt)
          // zwischen ihnen visualisiert die Bindung, alle anderen
          // Sektionen halten `.l` (20pt).
          VStack(alignment: .leading, spacing: GainsSpacing.tight) {
            greetingHeader
            coachBriefCard
          }

          // 2026-05-14 (Polish-Loop 105): Insight-Card sitzt jetzt
          // direkt UNTER dem Coach-Brief (statt darüber). Liest sich
          // wie ein Echo zum Brief — variable reward auf einen Hero.
          if let insight = dailyInsight {
            insightCard(insight)
              .transition(.opacity.combined(with: .offset(y: -6)))
          }
          // 2026-05-03 Optim-Sweep: `plannedWeekStrip` ist in
          // `cockpitSpotlightCard` gewandert (HEUTE-Plan + 7-Tage-Pills).
          // Vorher hatten beide Karten je ein „DIESE WOCHE"-Eyebrow und
          // konkurrierende Plan-Aussagen — eine Surface reicht.
          // BPM-Banner ist nach oben unter den Greeting-Header gewandert,
          // damit der Live-Sensor-Status nicht am Scroll-Ende verschwindet.
          liveBPMBanner
          quickStartBar
          pulseStrip
          spotlightStack
          adaptiveActionGrid
          communityEntryCard
        }
        .padding(.horizontal, GainsSpacing.l)
        // 2026-05-14 (Polish-Loop 106): Top-Padding leicht angehoben,
        // damit der Wordmark unter der Status-Bar etwas Luft hat.
        .padding(.top, GainsSpacing.m)
        .padding(.bottom, 120)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Animiert das Erscheinen/Verschwinden des Recovery-Banners
        // und der Insight-Card sanft mit einer Spring-Kurve.
        .animation(.spring(duration: 0.4, bounce: 0.2), value: store.recoverableWorkout != nil)
        .animation(.easeOut(duration: 0.3), value: dailyInsight != nil)
      }
      .scrollDismissesKeyboard(.interactively)
    }
    // 2026-05-14 Audit-Step 3: coachClock-Tick an View-Lifecycle gekoppelt.
    // Läuft nur, solange HomeView im aktiven Tab/Stack sichtbar ist.
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 60_000_000_000)
        if !Task.isCancelled { coachClock = Date() }
      }
    }
    // 2026-05-14 (Brand-Loop 11): Insight-Card beim ersten App-Open
    // einer Session laden. Frische Heuristik aus der Engine, gegen den
    // 7-Tage-Recent-Cache disduped.
    .task {
      if dailyInsight == nil {
        dailyInsight = GainsInsightEngine.dailyInsight(store: store)
      }
    }
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
    // 2026-05-15 (P1 #5): fullScreenCover statt sheet — WorkoutTracker ist
    // ein dedizierter Modus, nicht wegwischbar. Konsistent mit GymView und
    // WeekPlanFullscreenView.
    .fullScreenCover(
      isPresented: $isShowingWorkoutTracker,
      onDismiss: { pendingActionLock = nil }
    ) {
      WorkoutTrackerView().environmentObject(store)
    }
    .sheet(
      isPresented: $isShowingRunTracker,
      onDismiss: { pendingActionLock = nil }
    ) {
      RunTrackerView().environmentObject(store)
    }
    .sheet(isPresented: $isShowingProgress) { progressSheet }
    .sheet(isPresented: $isShowingProfile) { profileSheet }
    // 2026-05-15: WeekPlanFullscreenView wird global via ContentView
    // präsentiert (navigation.showsWeekPlanFullscreen). Kein lokales
    // fullScreenCover in HomeView mehr nötig — eine einzige Instanz.
    // 2026-05-15: CompletionRitual nach ContentView verschoben — Ritual muss
    // auch feuern, wenn der Workout aus dem Gym-Tab heraus abgeschlossen wird.
    // P0 B: Sobald die echte Session publiziert ist, ist der Lock unnötig.
    .onChange(of: store.activeWorkout?.id) { _, newValue in
      if newValue != nil {
        pendingActionLock = nil
        isShowingWorkoutChooser = false
        isShowingWorkoutBuilder = false
        isShowingWorkoutTracker = true
        isShowingRunTracker = false
        isShowingProgress = false
        isShowingProfile = false
        arrangingPlan = nil
        pendingAfterChooser = nil
        pendingAfterBuilder = nil
        pendingAfterArrange = nil
      }
    }
    .onChange(of: store.activeRun?.id) { _, newValue in
      if newValue != nil {
        pendingActionLock = nil
        isShowingWorkoutChooser = false
        isShowingWorkoutBuilder = false
        arrangingPlan = nil
        pendingAfterChooser = nil
        pendingAfterBuilder = nil
        pendingAfterArrange = nil
        isShowingWorkoutTracker = false
        isShowingRunTracker = true
        isShowingProgress = false
        isShowingProfile = false
      }
    }
    // 2026-05-16 (Fertiger-Audit P0-6): zentrales Haptik-Feedback für die
    // Modal-Trigger Workout/Lauf/Builder/Chooser. Statt jede der ~9 Aufruf-
    // stellen einzeln zu verändern, hängen wir den Selection-Puls an die
    // Sheet-Flags. So spüren auch Long-Press-/Programm-Pfade den Übergang.
    .onChange(of: isShowingWorkoutTracker) { _, opening in
      if opening { UISelectionFeedbackGenerator().selectionChanged() }
    }
    .onChange(of: isShowingRunTracker) { _, opening in
      if opening { UISelectionFeedbackGenerator().selectionChanged() }
    }
    .onChange(of: isShowingWorkoutChooser) { _, opening in
      if opening { UISelectionFeedbackGenerator().selectionChanged() }
    }
    .onChange(of: isShowingWorkoutBuilder) { _, opening in
      if opening { UISelectionFeedbackGenerator().selectionChanged() }
    }
    // 2026-05-16 (Release-Audit P1): Safety-Net gegen hängenden Lock. Wenn
    // aus irgendeinem Grund weder Sheet öffnet (z.B. Permission-Error) noch
    // store.activeWorkout/activeRun publiziert wird, würde der Coach-Brief
    // sonst dauerhaft auf „WORKOUT STARTET …"/„LAUF STARTET …" hängen.
    // 5 Sekunden ist genug Zeit für den normalen Start-Pfad — danach
    // räumen wir den Lock auf, der Coach-Brief fällt auf den Default-Pfad
    // zurück. `task(id:)` cancelt die Wartung automatisch, sobald der
    // Lock anderweitig zurückgesetzt wird (Sheet-onDismiss oder Store-
    // Mutation oben).
    .task(id: pendingActionLock) {
      guard pendingActionLock != nil else { return }
      try? await Task.sleep(nanoseconds: 5_000_000_000)
      if !Task.isCancelled, pendingActionLock != nil {
        pendingActionLock = nil
      }
    }
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
          pendingAfterChooser = {
            if store.activeWorkout != nil {
              isShowingWorkoutTracker = true
            } else if store.activeRun != nil {
              isShowingRunTracker = true
            } else {
              presentArrange(for: plan)
            }
          }
          isShowingWorkoutChooser = false
        },
        onCreateWorkout: {
          pendingAfterChooser = {
            if store.activeWorkout != nil {
              isShowingWorkoutTracker = true
            } else if store.activeRun != nil {
              isShowingRunTracker = true
            } else {
              isShowingWorkoutBuilder = true
            }
          }
          isShowingWorkoutChooser = false
        }
      )
      .environmentObject(store)
    }
  }

  @ViewBuilder
  private var workoutBuilderSheet: some View {
    WorkoutBuilderView { workout in
      pendingAfterBuilder = {
        if store.activeWorkout != nil {
          isShowingWorkoutTracker = true
        } else if store.activeRun != nil {
          isShowingRunTracker = true
        } else {
          presentArrange(for: workout)
        }
      }
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
          let trimmedPlanTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
          if store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedPlanTitle {
            isShowingWorkoutTracker = true
          } else if store.activeWorkout != nil {
            isShowingWorkoutTracker = true
          } else if store.activeRun != nil {
            isShowingRunTracker = true
          }
          pendingAfterArrange = nil
        }
        arrangingPlan = nil
      },
      onCancel: {
        pendingAfterArrange = nil
        pendingActionLock = nil
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
    // 2026-05-14 (Polish-Loop 2): Zwei-Zeilen-Header.
    //
    //   Zeile 1: tiny `gains.` Wordmark · LIVE-Dot · Datum-Mono · Avatar
    //   Zeile 2: „Moin, Julius." (Hero-Salutation, jetzt 26pt .heavy)
    //
    // Vorher waren Wordmark + Brand-Identität auf Home gar nicht
    // präsent — die App fühlte sich „anonym" an, sobald man im Tab
    // landete. Jetzt liegt der Brand-Anker oben links, weiterhin
    // dezent.
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      HStack(alignment: .center, spacing: GainsSpacing.s) {
        GainsWordmark(size: 15)
          .accessibilityHidden(true)

        // Live-Dot zwischen Wordmark und Datum signalisiert „Daten
        // sind frisch" — der atmende Akzent passt zur neuen
        // Glow-Ästhetik.
        Circle()
          .fill(GainsColor.lime)
          .frame(width: 4, height: 4)
          .shadow(color: GainsColor.lime.opacity(0.3), radius: 2)

        // 2026-05-14 (Polish-Loop 98): Meta-Line jetzt als HStack mit
        // einzelnen Tokens (Wochentag · Datum · Bucket), der Bucket
        // bekommt einen kleinen Lime-Akzent, damit „Tageszeit" als
        // Live-Anker liest und nicht als generischer Caption-Block.
        metaPartsLine

        Spacer(minLength: 8)

        avatarButton
      }

      greetingLine
    }
  }

  /// 2026-05-14 (Polish-Loop 98): Datum-Meta in drei strukturierten
  /// Tokens — Wochentag (heller), Datum (mono), Tageszeit (Akzent).
  private var metaPartsLine: some View {
    let parts = currentDateParts
    let bucket = currentTimeBucket
    // 2026-05-16 (Polish-Loop): spacing 6 → GainsSpacing.xs, Separator-
    // Dots auf weight:.bold + monospaced — die `·` zwischen den getrackten
    // Mono-Tokens haben vorher als Default-Body-Glyph eine andere Linie
    // gehalten als die umgebende Mono-Schrift.
    return HStack(spacing: GainsSpacing.xs) {
      Text(currentWeekdayLong)
        .font(GainsFont.eyebrow)
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)
      Text("·")
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(GainsColor.mutedInk)
      Text(parts.date)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(GainsColor.softInk)
      Text("·")
        .font(.system(size: 10, weight: .bold, design: .monospaced))
        .foregroundStyle(GainsColor.mutedInk)
      Text(bucket)
        .font(GainsFont.eyebrow)
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.lime.opacity(0.85))
        .shadow(color: GainsColor.lime.opacity(0.175), radius: 2)
    }
    .lineLimit(2)
  }

  /// Profil-Avatar mit dezentem Lime-Halo. Halo läuft nur, wenn ein
  /// echtes Profilbild gesetzt ist — sonst bliebe der Glow ohne
  /// Anker.
  private var avatarButton: some View {
    Button {
      isShowingProfile = true
    } label: {
      Group {
        if let image = store.userAvatarImage {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(
              Circle().stroke(GainsColor.lime.opacity(0.55), lineWidth: GainsBorder.bold)
            )
            .compositingGroup()
            .shadow(color: GainsColor.lime.opacity(0.16), radius: 6)
        } else {
          ZStack {
            Circle()
              .fill(GainsColor.card)
              .frame(width: 36, height: 36)
            Circle()
              .stroke(
                LinearGradient(
                  colors: [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.10)],
                  startPoint: .top,
                  endPoint: .bottom
                ),
                lineWidth: GainsBorder.bold
              )
              .frame(width: 36, height: 36)
            Text({
              let trimmedUserName = store.userName.trimmingCharacters(in: .whitespacesAndNewlines)
              return trimmedUserName.isEmpty ? "·" : String(trimmedUserName.prefix(1)).uppercased()
            }())
              .font(GainsFont.label(13))
              .foregroundStyle(GainsColor.ink)
          }
          .compositingGroup()
        }
      }
      .frame(width: 44, height: 44)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Profil öffnen")
    .accessibilityValue({
      let trimmedUserName = store.userName.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmedUserName.isEmpty ? "Dein Profil" : trimmedUserName
    }())
    .accessibilityHint("Öffnet dein Profil mit deinen Daten und Einstellungen")
  }

  /// „Moin, Julius." — Anrede + Name in Lime + Punkt. Wenn kein Name
  /// gesetzt: nur die Anrede mit Ausrufezeichen.
  @ViewBuilder
  private var greetingLine: some View {
    let salutation = currentSalutation
    let trimmedUserName = store.userName.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasName = !trimmedUserName.isEmpty

    // 2026-05-14 (Polish-Loop 2): Salutation auf 26pt .heavy mit
    // tightem Tracking (−0.5). Der Name leuchtet weiterhin im Lime.
    // Punkt am Ende ist der lowercase-Brand-Anker — entspricht der
    // Wordmark-Linie.
    // 2026-05-14: Heavy-Weight rückgängig (User-Direktive), zurück auf
    // title(22) semibold wie vor Polish-Loop 2/28. CompositingGroup +
    // sanfter Shadow bleiben, damit die Glow-Optik konsistent ist —
    // nur die Schrift selbst wird wieder leichter.
    if hasName {
      HStack(alignment: .firstTextBaseline, spacing: GainsSpacing.xs) {
        Text("\(salutation), ")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
        Text("\(trimmedUserName).")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.lime)
      }
      .lineLimit(2)
      .minimumScaleFactor(0.7)
    } else {
      Text("\(salutation).")
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
    }
  }

  /// Stunde aus `coachClock` — wird in currentSalutation, currentTimeBucket,
  /// currentCoachBrief, currentSpotlight und adaptiveTiles genutzt.
  /// Einmalig pro Render-Pass via einer Property, statt 5× redundant
  /// via Calendar.current.component(.hour, from: coachClock).
  private var currentHour: Int {
    Calendar.current.component(.hour, from: coachClock)
  }

  /// Wechselt mit der Tageszeit. Bewusst kurz und warm — kein „Sehr geehrter".
  private var currentSalutation: String {
    switch currentHour {
    case 5..<10: return "Moin"
    case 10..<14: return "Hi"
    case 14..<18: return "Hey"
    case 18..<22: return "Abend"
    default: return "Späte Stunde"
    }
  }

  private var currentWeekdayLong: String {
    HomeFormatters.weekdayLongDE.string(from: coachClock).uppercased()
  }

  /// Tageszeit-Bucket (NACHT/MORGEN/MITTAG/NACHM./ABEND/SPÄT) — wird sowohl
  /// im Greeting-Eyebrow als auch (früher) im Coach-Brief-Header genutzt.
  private var currentTimeBucket: String {
    switch currentHour {
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
    // 2026-05-14 (Polish-Loop 108): Inner-Spacing aufgeteilt — Header
    // → Headline/Sub eng (Gruppe), dann l-Atem zum CTA. Liest sich
    // wie ein Brief: Eyebrow/Headline/Sub als eine Einheit, dann der
    // Action-Block.
    let brief = currentCoachBrief
    return VStack(alignment: .leading, spacing: GainsSpacing.l) {
      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        coachBriefHeader(brief)
        coachBriefHeadline(brief)
        coachBriefSub(brief)
      }

      // Trennlinie zwischen Text-Block und CTA-Block — akzentuiert
      // die Zwei-Zonen-Struktur der Karte (Kontext oben / Aktion unten)
      // ohne visuelles Gewicht zu kosten.
      LinearGradient(
        colors: [brief.accent.opacity(0.45), brief.accent.opacity(0.08), .clear],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(height: 1)
      .padding(.vertical, GainsSpacing.xxs)

      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        coachPrimaryCTA(brief)
        if let secondary = brief.secondary {
          coachSecondaryLink(secondary, accent: brief.accent)
        }
      }
    }
    .padding(GainsSpacing.l)
    // 2026-05-29 (A18 „Mehr Glas, freundlicher"): War eine immer-dunkle
    // ctaSurface-Bühne. Jetzt adaptive Frosted-Glass via gainsHeroGlass —
    // hell & milchig im Light-Mode, dunkel im Dark-Mode, mit lebendigem
    // Variant-Akzent-Glow. Helper kapselt Background + Edge + Rahmen + Shadow.
    .gainsHeroGlass(accent: brief.accent)
    // Smooth color transition wenn der Coach-Brief die Variant wechselt
    // (z. B. Uhrzeit-Tick, Workout startet). Nur Farbe, kein Layout-Flip.
    .animation(.easeInOut(duration: 0.5), value: brief.accent)
  }

  private func coachBriefHeader(_ brief: CoachBrief) -> some View {
    HStack(spacing: GainsSpacing.tight) {
      PulsingDot(color: brief.accent, coreSize: 6, haloSize: 16)
      // 2026-05-29 (A18): Eyebrow-Text von brief.accent → softInk. Auf dem
      // jetzt hellen Frosted-Glass wäre ein heller Akzent (v.a. lime, ~1.7:1)
      // praktisch unlesbar. Die Akzent-Identität trägt weiter der farbige
      // PulsingDot links + das Glyph-Badge rechts — der Eyebrow bleibt lesbar.
      Text(brief.eyebrow)
        .gainsEyebrow(GainsColor.softInk, size: 11, tracking: 1.6)
        .lineLimit(2)
      Spacer(minLength: 8)
      // Glyph-Badge: größerer Kreis mit echtem Radial-Glow + Gradient-
      // Border — korrespondiert mit dem Icon-Halo-Pattern der Tiles.
      ZStack {
        Circle()
          .fill(brief.accent.opacity(0.14))
        Circle()
          .fill(
            RadialGradient(
              colors: [brief.accent.opacity(0.32), .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 28
            )
          )
          .blendMode(.plusLighter)
        Circle()
          .strokeBorder(
            LinearGradient(
              colors: [brief.accent.opacity(0.65), brief.accent.opacity(0.15)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.accent
          )
        Image(systemName: brief.glyph)
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(brief.accent)
          .shadow(color: brief.accent.opacity(0.60), radius: 4)
      }
      .frame(width: 30, height: 30)
      .compositingGroup()
      .shadow(color: brief.accent.opacity(0.30), radius: 8)
    }
  }

  private func coachBriefHeadline(_ brief: CoachBrief) -> some View {
    // A14 (minimal): Solid Ink, kein Gradient, kein Glow.
    // Heavy-Variante zurückgerollt (User-Direktive 2026-05-14).
    // 2026-05-29 (A18): zurück auf adaptives `ink`. Die Card ist jetzt
    // adaptives Frosted-Glass (hell im Light-Mode), also dunkle Schrift auf
    // hell / helle Schrift auf dunkel — onCtaSurface wäre hier falsch herum.
    Text(brief.headline)
      .font(GainsFont.display(28))
      .foregroundStyle(GainsColor.ink)
      .lineLimit(3)
      .minimumScaleFactor(0.72)
      .fixedSize(horizontal: false, vertical: true)
  }

  private func coachBriefSub(_ brief: CoachBrief) -> some View {
    let trimmedSubline = brief.subline.trimmingCharacters(in: .whitespacesAndNewlines)

    // 2026-05-14 (Polish-Loop 107): Subline mit etwas mehr Atem zur
    // Headline, lineSpacing 4 für Lesbarkeit.
    // 2026-05-15 (Polish-Loop 202): Color von softInk → ink.opacity(0.82) —
    // gegen das dunkle Glas-Background brauchte die Subline mehr Kontrast.
    // 2026-05-29 (A18): zurück auf adaptives `softInk` — die Card ist jetzt
    // adaptives Frosted-Glass, kanonische sekundäre Schrift = softInk.
    Group {
      if trimmedSubline.isEmpty {
        EmptyView()
      } else {
        Text(trimmedSubline)
          .font(GainsFont.body(15))
          .foregroundStyle(GainsColor.softInk)
          .lineSpacing(4)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 2)
      }
    }
  }

  private func coachPrimaryCTA(_ brief: CoachBrief) -> some View {
    // 2026-05-03 Intuitivitäts-Sweep P1-1: Solid Akzent + onAccent-Text statt
    // Outline. Der Hero-Primary muss den deutlichsten Affordance-Anker auf
    // dem ganzen Screen haben — vorher konkurrierte er mit Pulse-Tiles um
    // Aufmerksamkeit. Der schmale onAccent-Stroke hält die Form definiert,
    // ohne den Solid-Look aufzubrechen.
    let trimmedPrimaryTitle = brief.primary.title.trimmingCharacters(in: .whitespacesAndNewlines)

    Button {
      runCoachAction(brief.primary.action)
    } label: {
      HStack(spacing: GainsSpacing.s) {
        Image(systemName: brief.primary.icon)
          .font(.system(size: 14, weight: .heavy))
          .foregroundStyle(GainsColor.onCtaSurface)

        Text((trimmedPrimaryTitle.isEmpty ? "Empfohlene Aktion" : trimmedPrimaryTitle).uppercased())
          .font(GainsFont.label(13))
          .tracking(GainsTracking.eyebrowWide)
          .foregroundStyle(GainsColor.onCtaSurface)

        Spacer(minLength: 0)

        if let metric = brief.primary.metric {
          Text(metric)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.85))
        }

        Image(systemName: "arrow.right")
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(GainsColor.onCtaSurface)
      }
      .padding(.horizontal, GainsSpacing.l)
      .frame(minHeight: 54)
      .background(
        // 2026-05-15 (Polish-Loop): Top-Highlight & Glow stark zurückgedreht.
        // Vorher: plusLighter-Weiß bei 22% wusch das Lime oben aus und killte
        // die Textlesbarkeit; zwei kräftige Akzent-Glows (45%/20%) ließen den
        // Button neon-mäßig leuchten. Jetzt: dezenter Top-Sheen ohne
        // plusLighter, weicher Bottom-Dim, ein einzelner sanfter Drop-Shadow.
        ZStack {
          brief.accent
          LinearGradient(
            colors: [Color.white.opacity(0.08), Color.clear],
            startPoint: .top,
            endPoint: .center
          )
          LinearGradient(
            colors: [Color.clear, Color.black.opacity(0.12)],
            startPoint: .center,
            endPoint: .bottom
          )
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(GainsColor.onCtaSurface.opacity(0.18), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .compositingGroup()
      .shadow(color: GainsColor.shadowCardAmbient, radius: 8, x: 0, y: 4)
      .contentShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(trimmedPrimaryTitle.isEmpty ? "Empfohlene nächste Aktion" : trimmedPrimaryTitle)
    .accessibilityValue(
      {
        let trimmedMetric = brief.primary.metric?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubline = brief.subline.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedMetric, !trimmedMetric.isEmpty {
          return trimmedMetric
        }
        return trimmedSubline.isEmpty ? "Empfohlene nächste Aktion" : "Empfohlene nächste Aktion. \(trimmedSubline)"
      }()
    )
    .accessibilityHint("Öffnet diese empfohlene nächste Aktion")
  }

  private func coachSecondaryLink(_ action: CoachActionDescriptor, accent: Color) -> some View {
    let trimmedTitle = action.title.trimmingCharacters(in: .whitespacesAndNewlines)

    // 2026-05-14 (Polish-Loop 52): Secondary-Link Pfeil bekommt einen
    // dezenten Akzent-Glow — markiert „weitere Option" ohne mit dem
    // Primary-CTA zu konkurrieren.
    Button {
      runCoachAction(action.action)
    } label: {
      HStack(spacing: GainsSpacing.xs) {
        // 2026-05-29 (A18): zurück auf adaptive Tokens — der Secondary-Link
        // sitzt jetzt auf adaptivem Frosted-Glass (hell im Light-Mode).
        if let metric = action.metric {
          Text(metric)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.mutedInk)
          Text("·")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(GainsColor.mutedInk)
        }
        Text(trimmedTitle.isEmpty ? "Weitere Aktion" : trimmedTitle)
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
        Image(systemName: "arrow.up.right")
          .font(.system(size: 10, weight: .heavy))
          .foregroundStyle(accent)
          .shadow(color: accent.opacity(0.45), radius: 3)
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
    return HStack(spacing: GainsSpacing.tight) {
      ForEach(stats.indices, id: \.self) { idx in
        pulseTile(stats[idx])
      }
    }
  }

  private func pulseTile(_ stat: PulseStat) -> some View {
    // 2026-05-14 (Polish-Loop 99): Pulse-Tile mit Akzent-Glow im
    // Background (oben-leading) + Gradient-Border. Liest sich konsistent
    // mit LiveTile/InsightCard/QuickStart-Tile.
    //
    // 2026-05-31 (Dark-Accent-Pass): Der Pulse-Strip ist jetzt der EINE
    // bewusste Dunkel-Anker auf Home — eine satte Onyx-HUD-Bande direkt
    // unter dem hellen Coach-Brief. Die monospaced Werte leuchten dadurch
    // wie auf einem Cockpit-Display; der Akzent-Glow je Tile bleibt erhalten.
    // Vordergrund über onCtaSurface*-Tokens (ink/softInk wären hier dunkel-
    // auf-dunkel unsichtbar). Bewusst sparsam — nur dieser eine Strip.
    Button {
      runCoachAction(stat.action)
    } label: {
      let trimmedLabel = stat.label.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedValue = stat.value.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedUnit = stat.unit.trimmingCharacters(in: .whitespacesAndNewlines)
      let trimmedDetail = stat.detail.trimmingCharacters(in: .whitespacesAndNewlines)

      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        HStack(spacing: GainsSpacing.xs) {
          Image(systemName: stat.icon)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(stat.accent)
            .shadow(color: stat.accent.opacity(0.55), radius: 4)
          Text(trimmedLabel.isEmpty ? "Cockpitstatus" : trimmedLabel)
            .gainsEyebrow(GainsColor.onCtaSurfaceMuted, size: 9, tracking: 1.2)
            .lineLimit(2)
        }
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(trimmedValue.isEmpty ? "—" : trimmedValue)
            .font(.system(size: 18, weight: .semibold, design: .monospaced))
            .foregroundStyle(GainsColor.onCtaSurface)
          if !trimmedUnit.isEmpty {
            Text(trimmedUnit)
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.onCtaSurfaceSecondary)
          }
        }
        if !trimmedDetail.isEmpty {
          Text(trimmedDetail)
            .font(GainsFont.label(9))
            .tracking(GainsTracking.eyebrowTight)
            .foregroundStyle(GainsColor.onCtaSurfaceMuted)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, GainsSpacing.s)
      .padding(.vertical, GainsSpacing.s)
      .gainsOnyxAccent(corner: GainsRadius.standard, accent: stat.accent)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      stat.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? (stat.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(stat.label): \(stat.value)"
            : "\(stat.label): \(stat.value) \(stat.unit)")
        : (stat.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "\(stat.label): \(stat.value). \(stat.detail)."
            : "\(stat.label): \(stat.value) \(stat.unit). \(stat.detail).")
    )
    .accessibilityHint("Öffnet den passenden Detailbereich zu diesem Wert")
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
    // 2026-05-03 Optim-Sweep: Spotlight absorbiert jetzt den vorherigen
    // `plannedWeekStrip` (HEUTE-Plan-Zeile + 7-Tage-Pills). Vorher hatten
    // beide Karten je ein „DIESE WOCHE"-Eyebrow und je eine HEUTE/Plan-
    // Aussage — drei Surfaces (plannedWeekStrip + cockpit + plannerTile)
    // für denselben Plan-Kontext. Sparkline ist raus, weil die Pills den
    // Done/Planned/Today-Status sauberer und tappable kommunizieren.
    // Polish-Loop 156 (2026-05-14): „Diese Woche"-Karte aufgeräumt.
    //   • Status (Auf Kurs / Warmup / …) sitzt jetzt in einer echten
    //     Status-Pille statt nackt mit Pfeil-Icon im Eyebrow-Strip.
    //   • Drei Mini-Tiles (Streak / Volumen / Sessions noch) auf der
    //     rechten Seite — füllt die Höhe vom 116pt-Ring sauber aus.
    //   • Die Trennlinie zwischen Tap-Zone 1 (Ring) und 2 (Plan) ist
    //     jetzt eine Hairline-Gradient statt eines harten 1pt-Rectangles.
    //   • plannedTodayLine bekommt einen Chevron im umgebenden Button-
    //     Wrapper unten, damit das Tap-Target sichtbar ist.
    let sessionsRemaining = max(store.weeklyGoalCount - store.weeklySessionsCompleted, 0)
    return VStack(alignment: .leading, spacing: 0) {
      Button {
        isShowingProgress = true
      } label: {
        VStack(alignment: .leading, spacing: GainsSpacing.l) {
          HStack(alignment: .center, spacing: GainsSpacing.tight) {
            Text("DIESE WOCHE")
              .gainsEyebrow(GainsColor.ink, size: 12, tracking: 1.4)
            Text(cachedDateParts.week)
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.mutedInk)

            Spacer(minLength: 0)

            // Status-Pille — gleiche Sprache wie die WOCHENPLAN-Pille
            // unten, nur kompakter. „Auf Kurs"/„Warmup"/„Ziel erreicht"
            // wird zur Glas-Pille statt orphaned arrow + text.
            HStack(spacing: GainsSpacing.xxs) {
              Text(progressDisplayTitle.uppercased())
                .gainsEyebrow(GainsColor.lime, size: 10, tracking: 1.3)
              Image(systemName: "arrow.up.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(GainsColor.lime)
                .shadow(color: GainsColor.lime.opacity(0.16), radius: 2)
            }
            .padding(.horizontal, GainsSpacing.s)
            .padding(.vertical, GainsSpacing.xs)
            .background(
              ZStack {
                Capsule().fill(GainsColor.lime.opacity(0.10))
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
            .shadow(color: GainsColor.lime.opacity(0.09), radius: 5)
          }

          HStack(alignment: .center, spacing: GainsSpacing.m) {
            weekRing
              .frame(width: 116, height: 116)

            // Mini-Tiles im 3er-Stack — füllt die Ringhöhe, statt 2 Tiles
            // mit Leerraum darüber/darunter zu lassen. xs-Spacing hält
            // die Höhe so dass der Stack visuell zum Ring passt.
            VStack(spacing: GainsSpacing.xs) {
              cockpitMiniTile(
                icon: "flame.fill",
                value: "\(store.streakDays)",
                unit: "T",
                label: "SERIE",
                accent: GainsColor.lime
              )
              cockpitMiniTile(
                icon: "scalemass.fill",
                value: store.weeklyVolumeTons > 0 ? String(format: "%.1f", store.weeklyVolumeTons) : "—",
                unit: store.weeklyVolumeTons > 0 ? "t" : "",
                label: "VOLUMEN",
                accent: GainsColor.accentCool
              )
              cockpitMiniTile(
                icon: sessionsRemaining == 0 ? "checkmark.seal.fill" : "calendar",
                value: "\(sessionsRemaining)",
                unit: "Einh.",
                label: sessionsRemaining == 0 ? "ZIEL ERREICHT" : "NOCH OFFEN",
                accent: sessionsRemaining == 0 ? GainsColor.moss : GainsColor.ember
              )
            }
          }
        }
        .padding(.bottom, GainsSpacing.m)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Fortschritt heute und diese Woche öffnen")
      .accessibilityValue("\(store.weeklySessionsCompleted) von \(store.weeklyGoalCount) Einheiten, \(store.weeklyVolumeTons > 0 ? "\(String(format: "%.1f", store.weeklyVolumeTons)) Tonnen Volumen" : "noch kein Wochenvolumen")")
      .accessibilityHint("Öffnet deinen Fortschritt mit Wochenübersicht, Serie und Volumen")

      // Refined Hairline-Gradient-Divider statt hartem 1pt-Rectangle —
      // bridged optisch zwischen den zwei Tap-Zonen, statt sie hart
      // abzuschneiden.
      Rectangle()
        .fill(
          LinearGradient(
            colors: [
              GainsColor.border.opacity(0.0),
              GainsColor.border.opacity(0.55),
              GainsColor.border.opacity(0.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(height: 0.6)
        .padding(.vertical, GainsSpacing.xs)

      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        Button {
          if store.activeWorkout != nil {
            isShowingWorkoutTracker = true
          } else if store.activeRun != nil {
            isShowingRunTracker = true
          } else {
            navigation.openWeekPlanFullscreen()
          }
        } label: {
          plannedTodayLine
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          store.activeWorkout != nil
            ? "Aktives Training öffnen"
            : store.activeRun != nil
              ? "Aktiven Lauf öffnen"
              : "Heutigen Plan öffnen"
        )
        .accessibilityHint(
          store.activeWorkout != nil
            ? "Öffnet dein bereits laufendes Training mit Übungen, Sätzen und Pausen"
            : store.activeRun != nil
              ? "Öffnet deinen bereits laufenden Lauf mit Karte, Splits und Steuerung"
              : "Öffnet deinen Wochenplan mit den geplanten Einheiten"
        )

        if let week = cachedHomeWeekPreview {
          plannedWeekPills(week.days)
        }

        // 2026-05-14 (Polish-Loop 110): Wochenplan-CTA-Pille jetzt mit
        // Glas-Composition + Radial-Glow.
        Button {
          if store.activeWorkout != nil {
            isShowingWorkoutTracker = true
          } else if store.activeRun != nil {
            isShowingRunTracker = true
          } else {
            navigation.openWeekPlanFullscreen()
          }
        } label: {
          HStack(spacing: GainsSpacing.xxs) {
            Text(
              store.activeWorkout != nil
                ? "TRAINING ÖFFNEN"
                : store.activeRun != nil
                  ? "LAUF ÖFFNEN"
                  : "WOCHENPLAN ÖFFNEN"
            )
              .gainsEyebrow(GainsColor.lime, size: 10, tracking: 1.4)
            Image(systemName: "arrow.up.right")
              .font(.system(size: 10, weight: .heavy))
              .foregroundStyle(GainsColor.lime)
              .shadow(color: GainsColor.lime.opacity(0.225), radius: 3)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, GainsSpacing.xs)
          .background(
            ZStack {
              Capsule().fill(GainsColor.lime.opacity(0.08))
              Capsule()
                .fill(
                  RadialGradient(
                    colors: [GainsColor.lime.opacity(0.18), .clear],
                    center: .leading,
                    startRadius: 0,
                    endRadius: 200
                  )
                )
                .blendMode(.screen)
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
              lineWidth: GainsBorder.bold
            )
          )
          .clipShape(Capsule())
          .compositingGroup()
          .shadow(color: GainsColor.lime.opacity(0.08), radius: 8)
          .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          store.activeWorkout != nil
            ? "Aktives Training öffnen"
            : store.activeRun != nil
              ? "Aktiven Lauf öffnen"
              : "Wochenplan öffnen"
        )
        .accessibilityHint(
          store.activeWorkout != nil
            ? "Öffnet dein bereits laufendes Training mit Übungen, Sätzen und Pausen"
            : store.activeRun != nil
              ? "Öffnet deinen bereits laufenden Lauf mit Karte, Splits und Steuerung"
              : "Öffnet deinen Wochenplan mit den geplanten Einheiten"
        )
        .padding(.top, GainsSpacing.xs)
      }
      .padding(.top, GainsSpacing.m)
    }
    .padding(GainsSpacing.l)
    .gainsCardStyle()
    // 2026-05-14 (Polish-Loop 42): compositing-group für stabiles
    // Scroll-Verhalten — die Cockpit-Card hat mehrere geschachtelte
    // Glass-Layer, die ohne Compositing während Scroll subtil driften.
    .compositingGroup()
  }

  // MARK: - Compact Cockpit Row (Footer-Variante)

  private var compactCockpitCard: some View {
    Button {
      isShowingProgress = true
    } label: {
      HStack(spacing: GainsSpacing.m) {
        // 2026-05-14 (Polish-Loop 103): Mini-Ring konsistent mit kcal-Ring /
        // Wochen-Ring.
        // 2026-05-16 (Polish-Loop): plusLighter-Inner-Glow raus, Doppel-Shadow
        // (55%/r=4 + 22%/r=10) auf einen weichen 28%/r=6 reduziert — gleiche
        // Behandlung wie der große kcal-Ring im Nutrition-Spotlight.
        ZStack {
          Circle()
            .stroke(GainsColor.border.opacity(0.55), lineWidth: 4)
          Circle()
            .trim(from: 0, to: weeklyProgressRatio)
            .stroke(
              LinearGradient(
                colors: [GainsColor.lime.opacity(0.85), GainsColor.accentCool],
                startPoint: .leading,
                endPoint: .trailing
              ),
              style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .shadow(color: GainsColor.lime.opacity(0.14), radius: 6)
        }
        .frame(width: 44, height: 44)
        .compositingGroup()

        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: GainsSpacing.xs) {
            Text("WOCHE")
              .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.4)
            Text(cachedDateParts.week)
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.mutedInk)
          }
          HStack(alignment: .firstTextBaseline, spacing: GainsSpacing.xs) {
            Text("\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)")
              .font(.system(size: 16, weight: .semibold, design: .monospaced))
              .foregroundStyle(GainsColor.ink)
            Text("Einheiten")
              .gainsCaption()
            Text("·")
              .gainsCaption()
            Text(store.weeklyVolumeTons > 0 ? String(format: "%.1f t", store.weeklyVolumeTons) : "ohne Volumenangabe")
              .font(.system(size: 12, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.softInk)
          }
        }

        Spacer(minLength: 0)

        compactPlanPill
      }
      .padding(.horizontal, GainsSpacing.m)
      .padding(.vertical, GainsSpacing.s)
      .gainsCardStyle(GainsColor.card)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Wochenfortschritt — \(store.weeklySessionsCompleted) von \(store.weeklyGoalCount) Einheiten geschafft")
    .accessibilityValue(store.weeklyVolumeTons > 0 ? String(format: "%.1f Tonnen Volumen diese Woche", store.weeklyVolumeTons) : "Noch kein Wochenvolumen")
    .accessibilityHint("Öffnet deinen Fortschritt und die Wochenübersicht")
  }

  /// Mini-Pill mit „NÄCHSTES: Push" oder „HEUTE: Push" — als Quick-Hint
  /// in der kompakten Zeile.
  @ViewBuilder
  private var compactPlanPill: some View {
    if let next = nextPlannedSchedule {
      HStack(spacing: GainsSpacing.xxs) {
        Image(systemName: next.isToday ? "play.fill" : "calendar")
          .font(.system(size: 10, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
          .shadow(color: GainsColor.lime.opacity(0.225), radius: 3)
        let prefix = next.isToday ? "HEUTE" : next.weekday.shortLabel.uppercased()
        let summary: String
        if let workout = next.workoutPlan {
          summary = "\(workout.estimatedDurationMinutes) MIN · \(workout.exercises.count) ÜB"
        } else if let run = next.runTemplate {
          summary = String(format: "%.1f KM · %d MIN", run.targetDistanceKm, run.targetDurationMinutes)
        } else {
          summary = next.title.uppercased()
        }
        Text("\(prefix) · \(summary)")
          .gainsEyebrow(GainsColor.lime, size: 9, tracking: 1.2)
          .lineLimit(2)
      }
      .padding(.horizontal, GainsSpacing.xsPlus)
      .frame(minHeight: 22)
      .background(
        // 2026-05-14 (Polish-Loop 104): Plan-Pille mit Radial-Glow +
        // Inner-Light.
        ZStack {
          Capsule().fill(GainsColor.lime.opacity(0.10))
          Capsule()
            .fill(
              RadialGradient(
                colors: [GainsColor.lime.opacity(0.18), .clear],
                center: .leading,
                startRadius: 0,
                endRadius: 80
              )
            )
            .blendMode(.screen)
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
      .shadow(color: GainsColor.lime.opacity(0.08), radius: 6)
    } else {
      Image(systemName: "arrow.up.right")
        .font(.system(size: 11, weight: .heavy))
        .foregroundStyle(GainsColor.softInk)
    }
  }

  /// Lime→Cyan Wochenring mit Mono-Zähler in der Mitte.
  private var weekRing: some View {
    // 2026-05-14 (Polish-Loop 100): Weekring auf dieselbe Tiefe-
    // Komposition wie der kcal-Ring im Nutrition-Tab.
    //   1) Innerer Background-Glow
    //   2) Hairline-Track
    //   3) Progress mit Triple-Shadow
    //   4) Hero-Numerik + Mono-Sub-Caption
    ZStack {
      // 1) Inner Glow
      Circle()
        .fill(
          RadialGradient(
            colors: [GainsColor.lime.opacity(0.16), GainsColor.lime.opacity(0.02), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 60
          )
        )
        .blendMode(.plusLighter)

      // 2) Track
      Circle()
        .stroke(GainsColor.border.opacity(0.55), lineWidth: 7)

      // 3) Progress — Guard gegen Trim=0: lineCap:.round erzeugt bei
      // ratio==0 einen kleinen Dot-Artefakt auf dem Track. Erst ab einem
      // Minimum-Threshold zeichnen, damit der Ring leer sauber aussieht.
      if weeklyProgressRatio > 0.01 {
        Circle()
          .trim(from: 0, to: weeklyProgressRatio)
          .stroke(
            AngularGradient(
              gradient: Gradient(colors: [
                GainsColor.lime.opacity(0.55),
                GainsColor.lime,
                GainsColor.accentCool
              ]),
              center: .center,
              startAngle: .degrees(-90),
              endAngle: .degrees(270)
            ),
            style: StrokeStyle(lineWidth: 7, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
          .shadow(color: GainsColor.lime.opacity(0.275), radius: 6)
          .shadow(color: GainsColor.lime.opacity(0.11), radius: 14)
      }

      // 4) Center Numerik
      VStack(spacing: 0) {
        Text("\(store.weeklySessionsCompleted)")
          .font(.system(size: 36, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)
          .shadow(color: GainsColor.lime.opacity(0.11), radius: 6)
        Text("/ \(store.weeklyGoalCount)")
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundStyle(GainsColor.softInk)
          .padding(.top, -2)
        Text("EINHEITEN")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.mutedInk)
          .padding(.top, 2)
      }
    }
    .compositingGroup()
  }

  /// Eine der zwei Mini-Tiles rechts vom Ring.
  private func cockpitMiniTile(
    icon: String,
    value: String,
    unit: String,
    label: String,
    accent: Color
  ) -> some View {
    let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)

    // 2026-05-14 (Polish-Loop 101): Mini-Tile bekommt die gleiche
    // Icon-Halo-Komposition wie ActionTile + dezenten Akzent-Glow im
    // Background.
    HStack(spacing: GainsSpacing.s) {
      ZStack {
        Circle().fill(accent.opacity(0.10))
        Circle()
          .fill(
            RadialGradient(
              colors: [accent.opacity(0.30), .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 34
            )
          )
          .blendMode(.plusLighter)
        Circle()
          .strokeBorder(
            LinearGradient(
              colors: [accent.opacity(0.55), accent.opacity(0.12)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.accent
          )
        Image(systemName: icon)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(accent)
          .shadow(color: accent.opacity(0.45), radius: 3)
      }
      .frame(width: 30, height: 30)
      .compositingGroup()
      .shadow(color: accent.opacity(0.22), radius: 5)

      VStack(alignment: .leading, spacing: 1) {
        Text(trimmedLabel.isEmpty ? "Cockpitwert" : trimmedLabel)
          .gainsEyebrow(GainsColor.mutedInk, size: 9, tracking: 1.3)
          .lineLimit(2)
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text(trimmedValue.isEmpty ? "—" : trimmedValue)
            .font(.system(size: 19, weight: .semibold, design: .monospaced))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
          if !trimmedUnit.isEmpty {
            Text(trimmedUnit)
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.softInk)
          }
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, GainsSpacing.s)
    .padding(.vertical, GainsSpacing.xs)
    .background(
      ZStack {
        GainsColor.surfaceDeep.opacity(0.6)
        RadialGradient(
          colors: [accent.opacity(0.05), .clear],
          center: .leading,
          startRadius: 0,
          endRadius: 140
        )
        .blendMode(.screen)
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [accent.opacity(0.18), GainsColor.border.opacity(0.50)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
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
    // 2026-05-14 (Polish-Loop 64): Ernährungskarte komplett überarbeitet.
    //   • Eyebrow-Zeile mit pulsing Live-Dot und Ember-Akzent statt
    //     flachem „ERNÄHRUNG · HEUTE" Text-Pärchen
    //   • kcal-Ring + Wert links jetzt prominent mit Hero-Numerik
    //     gegen Macro-Trio rechts — klare Hierarchie
    //   • Macro-Trio jetzt im 3-Spalten-Grid statt VStack: spart Höhe
    //     und liest sich wie ein KPI-Strip
    //   • Background mit Ember-Glow-Komposition statt flacher Card
    let kcalNow = store.nutritionCaloriesToday
    let kcalGoal = store.nutritionTargetCalories
    return Button {
      navigation.openNutrition()
    } label: {
      VStack(alignment: .leading, spacing: GainsSpacing.l) {
        // Header
        HStack(alignment: .center, spacing: GainsSpacing.tight) {
          PulsingDot(color: GainsColor.ember, coreSize: 6, haloSize: 16)
          Text("ERNÄHRUNG")
            .gainsEyebrow(GainsColor.ember, size: 12, tracking: 1.6)
          Text("HEUTE")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.mutedInk)

          Spacer(minLength: 0)

          HStack(spacing: GainsSpacing.xxs) {
            Text(nutritionStatusLabel.uppercased())
              .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.4)
              .lineLimit(2)
            Image(systemName: "arrow.up.right")
              .font(.system(size: 11, weight: .heavy))
              .foregroundStyle(GainsColor.ember)
              .shadow(color: GainsColor.ember.opacity(0.225), radius: 3)
          }
        }

        // Hero-Zeile: kcal-Ring links, kcal-Wert + Rest groß rechts
        HStack(alignment: .center, spacing: GainsSpacing.l) {
          kcalRing
            .frame(width: 104, height: 104)

          VStack(alignment: .leading, spacing: 2) {
            Text("KALORIEN")
              .font(GainsFont.eyebrow)
              .tracking(GainsTracking.eyebrow)
              .foregroundStyle(GainsColor.mutedInk)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
              Text("\(kcalNow)")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(GainsColor.ink)
                .shadow(color: GainsColor.ember.opacity(0.09), radius: 6)
              if kcalGoal > 0 {
                Text("/ \(kcalGoal)")
                  .font(.system(size: 14, weight: .medium, design: .monospaced))
                  .foregroundStyle(GainsColor.softInk)
              }
            }
            Text(kcalRemainingLine)
              .font(GainsFont.caption)
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(2)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }

        // Macro-Strip — drei kompakte Säulen mit Progress
        HStack(alignment: .top, spacing: GainsSpacing.tight) {
          macroColumn(
            label: "EIWEISS",
            value: store.nutritionProteinToday,
            target: store.nutritionTargetProtein,
            unit: "g",
            accent: GainsColor.ember
          )
          macroColumn(
            label: "KOHLENHYDRATE",
            value: store.nutritionCarbsToday,
            target: store.nutritionTargetCarbs,
            unit: "g",
            accent: GainsColor.lime
          )
          macroColumn(
            label: "FETT",
            value: store.nutritionFatToday,
            target: store.nutritionTargetFat,
            unit: "g",
            accent: GainsColor.accentCool
          )
        }
      }
      .padding(GainsSpacing.l)
      .background(
        // 2026-05-15 (Polish-Loop): Komposition vereinfacht. Vorher: 5 Layer
        // (glassUndertone + Material + ctaSurface + 2 RadialGradients +
        // plusLighter-Top) + zwei Shadows (ember-Glow r=18 + Black r=14).
        // Jetzt: solide Card-Surface, ein dezenter Ember-Akzent oben links,
        // ein neutraler Drop-Shadow. Card liest sich ruhig, Macro-Säulen
        // bekommen die Aufmerksamkeit zurück.
        ZStack {
          GainsColor.card
          RadialGradient(
            colors: [GainsColor.ember.opacity(0.10), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 220
          )
          .blendMode(.screen)
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [GainsColor.ember.opacity(0.28), GainsColor.border.opacity(0.45)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.hairline
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
      .compositingGroup()
      .shadow(color: GainsColor.shadowCardAmbient, radius: 10, x: 0, y: 6)
      .contentShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Ernährung öffnen")
    .accessibilityValue(kcalGoal == 0 ? "Kalorienziel noch nicht festgelegt" : "\(kcalNow) von \(kcalGoal) Kalorien")
    .accessibilityHint(kcalGoal == 0 ? "Öffnet die Ernährung, damit du zuerst dein Kalorienziel festlegen kannst" : "Öffnet deine heutige Ernährung und dein Kalorienziel")
  }

  /// Eine kompakte Macro-Säule: Eyebrow, Mono-Wert (X/Y g), und eine
  /// dünne Progress-Bar in der Akzentfarbe. Ersetzt das alte
  /// macroBar-Pattern in einem 3-Spalten-Strip.
  ///
  /// Hinweis: die Store-Macro-Felder sind `Int` (gerundete Gramm-Werte),
  /// daher nimmt diese Funktion auch `Int` — kein implicit Double-Cast
  /// am Call-Site nötig.
  private func macroColumn(
    label: String,
    value: Int,
    target: Int,
    unit: String,
    accent: Color
  ) -> some View {
    let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
    let safeTarget = max(target, 1)
    let ratio = min(Double(value) / Double(safeTarget), 1.0)
    let hasMeaningfulMacroValue = value > 0 || target > 0
    // 2026-05-15 (Polish-Loop): Wert/Target/Unit in einer einzelnen Text-
    // Komponente (verkettet, kein HStack) — vorher brach SwiftUI bei
    // schmaler Spalte zwischen den drei Texten um, was die Zahlen auf
    // zwei Reihen verteilte. Eine einzige Text-Komposition mit
    // lineLimit(1) + minimumScaleFactor skaliert sauber runter.
    let valueText = Text(hasMeaningfulMacroValue ? "\(value)" : "—")
      .font(.system(size: 16, weight: .semibold, design: .monospaced))
      .foregroundColor(GainsColor.ink)
    let targetText = hasMeaningfulMacroValue && target > 0
      ? Text("/\(target)")
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundColor(GainsColor.softInk)
      : Text("")
    let unitText = trimmedUnit.isEmpty
      ? Text("")
      : Text(trimmedUnit)
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundColor(GainsColor.mutedInk)
    return VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
      Text(trimmedLabel.isEmpty ? "Makro" : trimmedLabel)
        .font(GainsFont.eyebrow)
        .tracking(GainsTracking.eyebrowTight)
        .foregroundStyle(accent.opacity(0.85))
        .lineLimit(2)
        .minimumScaleFactor(0.7)

      (valueText + targetText + unitText)
        .lineLimit(2)
        .minimumScaleFactor(0.7)
        .fixedSize(horizontal: false, vertical: true)

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.border.opacity(0.5))
            .frame(height: 3)
          Capsule()
            .fill(
              LinearGradient(
                colors: [accent.opacity(0.85), accent],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: max(geo.size.width * ratio, 3), height: 3)
            .shadow(color: accent.opacity(0.45), radius: 3)
        }
      }
      .frame(height: 3)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// „Noch 1240 kcal" oder „Ziel erreicht" — ein Satz unter dem kcal-Wert.
  private var kcalRemainingLine: String {
    let goal = store.nutritionTargetCalories
    let now = store.nutritionCaloriesToday
    if goal == 0 { return "Kalorienziel festlegen" }
    if now >= goal { return "\(now - goal) kcal über Kalorienziel" }
    let remaining = goal - now
    return "Noch \(remaining) kcal bis Kalorienziel"
  }

  // MARK: - Compact Nutrition Row (Footer-Variante)

  private var compactNutritionCard: some View {
    Button {
      navigation.openNutrition()
    } label: {
      HStack(spacing: GainsSpacing.m) {
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
            .shadow(color: GainsColor.ember.opacity(0.2), radius: 6)
        }
        .frame(width: 44, height: 44)

        VStack(alignment: .leading, spacing: 2) {
          Text("ERNÄHRUNG · HEUTE")
            .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.4)
          HStack(alignment: .firstTextBaseline, spacing: GainsSpacing.xs) {
            Text("\(store.nutritionCaloriesToday)")
              .font(.system(size: 16, weight: .semibold, design: .monospaced))
              .foregroundStyle(GainsColor.ink)
            Text("/\(store.nutritionTargetCalories) kcal")
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.softInk)
            Text("·")
              .gainsCaption()
            Text("\(store.nutritionProteinToday) g Eiweiß")
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.ember)
          }
        }

        Spacer(minLength: 0)

        compactNutritionPill
      }
      .padding(.horizontal, GainsSpacing.m)
      .padding(.vertical, GainsSpacing.s)
      .background(
        // 2026-05-14 (Polish-Loop 66): Compact-Variante mit Ember-
        // Akzent-Glow, damit die Compact-Card visuell zur Spotlight-
        // Variante passt — nur ruhiger.
        ZStack {
          GainsColor.card
          RadialGradient(
            colors: [GainsColor.ember.opacity(0.10), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 200
          )
          .blendMode(.screen)
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [GainsColor.ember.opacity(0.32), GainsColor.border.opacity(0.45)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.hairline
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .compositingGroup()
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(store.nutritionTargetCalories == 0 ? "Ernährung" : "Ernährung — \(store.nutritionCaloriesToday) von \(store.nutritionTargetCalories) Kalorien")
    .accessibilityValue(store.nutritionTargetCalories == 0 ? "Kalorienziel noch nicht festgelegt" : "\(store.nutritionProteinToday) von \(store.nutritionTargetProtein) Gramm Eiweiß")
    .accessibilityHint(store.nutritionTargetCalories == 0 ? "Öffnet die Ernährung, damit du zuerst dein Kalorienziel festlegen kannst" : "Öffnet deine heutige Ernährung mit Kalorien und Eiweiß")
  }

  @ViewBuilder
  private var compactNutritionPill: some View {
    let remainingProtein = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
    if remainingProtein <= 0 && store.nutritionCaloriesToday > 0 {
      HStack(spacing: GainsSpacing.xxs) {
        Image(systemName: "checkmark")
          .font(.system(size: 10, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
        Text("EIWEISS ✓")
          .gainsEyebrow(GainsColor.lime, size: 9, tracking: 1.2)
      }
      .padding(.horizontal, GainsSpacing.xsPlus)
      .frame(minHeight: 22)
      .background(GainsColor.lime.opacity(0.10))
      .overlay(Capsule().strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: GainsBorder.hairline))
      .clipShape(Capsule())
    } else if remainingProtein > 0 {
      HStack(spacing: GainsSpacing.xxs) {
        Image(systemName: "fork.knife")
          .font(.system(size: 10, weight: .heavy))
          .foregroundStyle(GainsColor.ember)
        Text("\(remainingProtein) g offen")
          .gainsEyebrow(GainsColor.ember, size: 9, tracking: 1.2)
      }
      .padding(.horizontal, GainsSpacing.xsPlus)
      .frame(minHeight: 22)
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
    // 2026-05-14 (Polish-Loop 65): Ring jetzt mit echtem Background-
    // Glow + Inner-Hairline + Triple-Layer-Shadow auf der Progress-
    // Stroke. Wert in der Mitte als Hero-Numerik, kcal-Label klein
    // darunter, und ein Procent-Tag für schnelle Orientierung.
    let ratio = kcalProgressRatio
    let percent = Int((ratio * 100).rounded())
    return ZStack {
      // 2026-05-15 (Polish-Loop): plusLighter-Inner-Glow raus, Ring-Stroke-
      // Glow von 55%/r=4 + 22%/r=14 auf einen einzelnen weichen 28%/r=6.
      // Track
      Circle()
        .stroke(GainsColor.border.opacity(0.55), lineWidth: 6)

      // Progress
      Circle()
        .trim(from: 0, to: ratio)
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
          style: StrokeStyle(lineWidth: 6, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .shadow(color: GainsColor.ember.opacity(0.14), radius: 6)

      // Center Numerik
      VStack(spacing: 0) {
        Text("\(percent)")
          .font(.system(size: 28, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)
        Text("%")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
          .padding(.top, -2)
      }
    }
    .compositingGroup()
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
        GridItem(.flexible(), spacing: GainsSpacing.s),
        GridItem(.flexible(), spacing: GainsSpacing.s)
      ],
      spacing: GainsSpacing.s
    ) {
      ForEach(adaptiveTiles, id: \.kind) { tile in
        actionTile(tile)
      }
    }
  }

  // MARK: - Community-Einstieg (öffnet den Hub als Fullscreen-Overlay)
  //
  // 2026-05-30: Community ist kein eigener Tab (Tab-Bar bleibt bei 4), sondern
  // über diese Karte am Ende des Home-Feeds erreichbar. Tap ruft
  // `navigation.openCommunity()` → ContentView präsentiert CommunityHubView.

  private var communityEntryCard: some View {
    Button {
      navigation.openCommunity()
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      HStack(spacing: GainsSpacing.s) {
        ZStack {
          Circle().fill(.ultraThinMaterial)
          Circle().strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: GainsBorder.hairline)
          Image(systemName: "person.2.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
        }
        .frame(width: 44, height: 44)

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text("Community")
            .font(GainsFont.headline)
            .foregroundStyle(GainsColor.ink)
          Text("Beiträge, Forum und Treffs, sieh was die Crew heute trainiert.")
            .gainsCaption(GainsColor.softInk)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: GainsSpacing.xs)

        GainsDisclosureIndicator()
      }
      .padding(GainsSpacing.m)
      .frame(maxWidth: .infinity, alignment: .leading)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Community öffnen")
    .accessibilityValue("Feed, Forum und Treffs")
    .accessibilityHint("Öffnet den Community-Bereich, um Beiträge und Aktivitäten der Crew zu sehen")
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
    HStack(spacing: GainsSpacing.s) {
      quickStartTile(
        kind: .training,
        title: store.activeWorkout != nil ? "Öffnen" : "Training",
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
        title: store.activeRun != nil ? "Öffnen" : "Laufen",
        eyebrow: "LAUFEN",
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
      let s = aw.stats
      let volume = s.totalVolume > 0 ? String(format: "%.1f t", s.totalVolume / 1000) : "ohne Volumenangabe"
      return "\(s.completedSets)/\(s.totalSets) Sätze · \(volume)"
    }
    if store.activeRun != nil {
      return "Lauf läuft gerade"
    }
    if let plan = store.todayPlannedWorkout {
      return "Heute · \(plan.estimatedDurationMinutes) Min · \(plan.exercises.count) Übungen"
    }
    if let last = store.lastCompletedWorkout {
      let volume = last.volume > 0 ? String(format: "%.1f t", last.volume / 1000) : "ohne Volumenangabe"
      return "Zuletzt · \(last.completedSets) Sätze · \(volume)"
    }
    return "Heute · Plan wählen oder Training starten"
  }

  /// Statuszeile für die Lauf-Schnellstart-Kachel — analog zur Training-
  /// Kachel: Live-Lauf > Tagesplan > Default.
  private var quickStartCardioSubtitle: String {
    if let ar = store.activeRun {
      let h = ar.durationMinutes / 60
      let m = ar.durationMinutes % 60
      let dur = h > 0 ? String(format: "%d:%02d h", h, m) : "\(m) min"
      let pace = ar.averagePaceSeconds > 0
        ? String(format: "%d:%02d/km", ar.averagePaceSeconds / 60, ar.averagePaceSeconds % 60)
        : "ohne Paceangabe"
      return String(format: "%.1f km · %@ · %@", ar.distanceKm, dur, pace)
    }
    if let plannedRun = store.todayPlannedDay.runTemplate {
      return String(format: "Heute · %.1f km · %d Min", plannedRun.targetDistanceKm, plannedRun.targetDurationMinutes)
    }
    if store.todayPlannedDay.sessionKind?.isRun == true {
      return "Heute · \(store.todayPlannedDay.title)"
    }
    if let last = store.latestCompletedRun {
      let pace = last.averagePaceSeconds > 0
        ? String(format: "%d:%02d/km", last.averagePaceSeconds / 60, last.averagePaceSeconds % 60)
        : "ohne Paceangabe"
      return String(format: "Zuletzt · %.1f km · %@", last.distanceKm, pace)
    }
    return "Heute · Lauf starten oder Indoor tracken"
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
    let trimmedEyebrow = eyebrow.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

    Button(action: action) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 0) {
          // 2026-05-14 (Polish-Loop 41): Icon-Halo mit echtem Radial-
          // Glow statt nur Opacity-Wash.
          ZStack {
            Circle().fill(accent.opacity(0.10))
            // 2026-05-29 (Loop 9): .plusLighter → .screen.
            // quickStartTile Background ist GainsColor.card (#F2F5FC, ~weiß
            // in Light-Mode). plusLighter mit accent.0.30 würde auf dem
            // hellen Untergrund zu einem ausgeblichenen Lichtfleck führen.
            // .screen: 1 - (1-src)*(1-dst) bleibt akkurat und gibt einen
            // sichtbaren Akzent auf beiden Modes.
            Circle()
              .fill(
                RadialGradient(
                  colors: [accent.opacity(0.30), .clear],
                  center: .topLeading,
                  startRadius: 0,
                  endRadius: 40
                )
              )
              .blendMode(.screen)
            Circle()
              .strokeBorder(
                LinearGradient(
                  colors: [accent.opacity(0.55), accent.opacity(0.12)],
                  startPoint: .top,
                  endPoint: .bottom
                ),
                lineWidth: GainsBorder.accent
              )
            Image(systemName: icon)
              .font(.system(size: 16, weight: .heavy))
              .foregroundStyle(accent)
              .shadow(color: accent.opacity(0.45), radius: 4)
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

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(trimmedEyebrow.isEmpty ? "Home-Schnellzugriff" : trimmedEyebrow)
            .gainsEyebrow(accent, size: 10, tracking: 1.5)
          Text(trimmedTitle.isEmpty ? "Aktion" : trimmedTitle)
            .font(GainsFont.title(22))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
          Text(trimmedSubtitle.isEmpty ? "ohne Aktionsdetail" : trimmedSubtitle)
            .gainsCaption()
            .lineLimit(2)
            .truncationMode(.tail)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
      .padding(GainsSpacing.m)
      .background(
        ZStack {
          GainsColor.card
          RadialGradient(
            colors: [accent.opacity(isLive ? 0.16 : 0.10), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 200
          )
          .blendMode(.screen)
          if isLive {
            RadialGradient(
              colors: [accent.opacity(0.06), .clear],
              center: .bottomTrailing,
              startRadius: 0,
              endRadius: 160
            )
            .blendMode(.screen)
          }
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [accent.opacity(isLive ? 0.55 : 0.32), GainsColor.border.opacity(0.4)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.hairline
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .compositingGroup()
      .shadow(color: isLive ? accent.opacity(0.16) : .clear, radius: 14, x: 0, y: 0)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      {
        let spokenEyebrow = eyebrow.trimmingCharacters(in: .whitespacesAndNewlines)
        let spokenTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !spokenEyebrow.isEmpty && !spokenTitle.isEmpty {
          return "\(spokenEyebrow) — \(spokenTitle)"
        }
        return spokenTitle.isEmpty ? (spokenEyebrow.isEmpty ? "Home-Schnellzugriff" : spokenEyebrow) : spokenTitle
      }()
    )
    .accessibilityValue(
      {
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let liveFallback: String = {
          switch kind {
          case .training:
            return "Training läuft bereits"
          case .cardio:
            return "Lauf läuft bereits"
          }
        }()
        if trimmedSubtitle.isEmpty {
          return isLive ? liveFallback : "Home-Schnellzugriff"
        }
        return isLive ? "\(liveFallback). \(trimmedSubtitle)" : trimmedSubtitle
      }()
    )
    .accessibilityHint(isLive ? "Öffnet die bereits laufende Einheit" : kind == .cardio ? "Startet einen neuen Lauf oder öffnet per Langdruck weitere Cardio-Modi" : "Öffnet den Trainingseinstieg für ein neues Training")
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
        repeatLastWorkoutFromHome()
      } label: {
        Label("Letztes Training wiederholen", systemImage: "arrow.uturn.backward")
      }
      .accessibilityHint(store.lastCompletedWorkout == nil ? "Nicht verfügbar, solange noch kein abgeschlossenes Training vorliegt." : "Wiederholt dein zuletzt abgeschlossenes Training.")
      .disabled(store.lastCompletedWorkout == nil)
      Button {
        if store.activeWorkout != nil {
          isShowingWorkoutTracker = true
        } else if store.activeRun != nil {
          isShowingRunTracker = true
        } else {
          navigation.openTraining(workspace: .kraft)
        }
      } label: {
        Label("Trainings-Tab öffnen", systemImage: "dumbbell.fill")
      }
      Button {
        runCoachAction(.openPlanner)
      } label: {
        Label("Wochenplan öffnen", systemImage: "calendar")
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
        if store.activeRun != nil {
          isShowingRunTracker = true
        } else if store.activeWorkout != nil {
          isShowingWorkoutTracker = true
        } else {
          navigation.openTraining(workspace: .laufen)
        }
      } label: {
        Label("Laufbereich öffnen", systemImage: "rectangle.stack.fill")
      }

    case .progress, .meal, .water, .planner:
      EmptyView()
    }
  }

  private func actionTile(_ spec: ActionTileSpec) -> some View {
    let trimmedEyebrow = spec.eyebrow.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedTitle = spec.title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedSubtitle = spec.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

    Button(action: { runCoachAction(spec.action) }) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 0) {
          // 2026-05-14 (Polish-Loop 13): Icon-Plate bekommt jetzt einen
          // echten Radial-Glow + Icon-Inner-Shadow. Die Tile leuchtet
          // an genau einer Stelle — dem Icon — statt einer flachen
          // Color-Tönung.
          ZStack {
            Circle().fill(spec.accent.opacity(0.10))
            Circle()
              .fill(
                RadialGradient(
                  colors: [spec.accent.opacity(0.32), .clear],
                  center: .topLeading,
                  startRadius: 0,
                  endRadius: 32
                )
              )
              .blendMode(.plusLighter)
            Circle()
              .strokeBorder(
                LinearGradient(
                  colors: [spec.accent.opacity(0.55), spec.accent.opacity(0.10)],
                  startPoint: .top,
                  endPoint: .bottom
                ),
                lineWidth: GainsBorder.accent
              )
            Image(systemName: spec.icon)
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(spec.accent)
              .shadow(color: spec.accent.opacity(0.45), radius: 4)
          }
          .frame(width: 32, height: 32)
          .shadow(color: spec.accent.opacity(0.22), radius: 8)

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

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(trimmedEyebrow.isEmpty ? "Home-Schnellzugriff" : trimmedEyebrow)
            .gainsEyebrow(spec.accent, size: 10, tracking: 1.4)
          Text(trimmedTitle.isEmpty ? "Aktion" : trimmedTitle)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
          Text(trimmedSubtitle.isEmpty ? "ohne Aktionsdetail" : trimmedSubtitle)
            .gainsCaption()
            .lineLimit(2)
            .truncationMode(.tail)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
      .padding(GainsSpacing.m)
      .background(
        // Tile-Background bleibt ruhig (Card-Surface), aber bekommt
        // einen sehr dezenten Akzent-Halo oben-leading, der mit dem
        // Icon-Glow korrespondiert.
        ZStack {
          GainsColor.card
          RadialGradient(
            colors: [spec.accent.opacity(0.05), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 120
          )
          .blendMode(.screen)
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [spec.accent.opacity(0.22), GainsColor.border.opacity(0.4)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.hairline
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      // Scroll-Fix: 4 Tiles × Shadow im Grid sind teuer — compositing
      // hält die Card-Konturen während Scrollen stabil.
      .compositingGroup()
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      {
        let spokenEyebrow = spec.eyebrow.trimmingCharacters(in: .whitespacesAndNewlines)
        let spokenTitle = spec.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !spokenEyebrow.isEmpty && !spokenTitle.isEmpty {
          return "\(spokenEyebrow) — \(spokenTitle)"
        }
        return spokenTitle.isEmpty ? (spokenEyebrow.isEmpty ? "Home-Schnellzugriff" : spokenEyebrow) : spokenTitle
      }()
    )
    .accessibilityValue({
      let trimmedSubtitle = spec.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
      let liveFallback: String = {
        switch spec.kind {
        case .training:
          return "Training läuft bereits"
        case .cardio:
          return "Lauf läuft bereits"
        case .progress:
          return "Fortschritt ist bereits aktiv"
        case .meal:
          return "Ernährung ist bereits aktiv"
        case .water:
          return "Wasserübersicht ist bereits aktiv"
        case .community:
          return "Community ist bereits aktiv"
        case .plan:
          return "Planbereich ist bereits aktiv"
        }
      }()
      return trimmedSubtitle.isEmpty ? (spec.isLive ? liveFallback : "Home-Schnellzugriff") : trimmedSubtitle
    }())
    .accessibilityHint(actionTileAccessibilityHint(for: spec))
    .accessibilityAddTraits(spec.isLive ? .isSelected : [])
    // Welle 2 (W2-4): Power-User-Long-Press. Tap macht den Default-Pfad
    // (für Anfänger das Erwartete), Long-Press liefert 1-3 Quick-Actions
    // für Wiederholer. iOS-Standard-Geste, also ohne explizite Discovery-
    // Pille. Tiles ohne sinnvolle Shortcuts (progress, water, planner)
    // bleiben ohne Menu — das ist OK, leere ContextMenus rendern nichts.
    .contextMenu { tileContextMenu(for: spec) }
  }

  private func actionTileAccessibilityHint(for spec: ActionTileSpec) -> String {
    if spec.isLive {
      switch spec.kind {
      case .training:
        return "Öffnet dein bereits laufendes Training mit Übungen, Sätzen und Pausen"
      case .cardio:
        return "Öffnet deinen bereits laufenden Lauf mit Karte, Splits und Steuerung"
      case .progress:
        return "Öffnet deinen bereits aktiven Fortschrittsbereich"
      case .meal:
        return "Öffnet deine bereits aktive Ernährungserfassung"
      case .water:
        return "Öffnet deine bereits aktive Wasserübersicht"
      case .community:
        return "Öffnet deinen bereits aktiven Community-Bereich"
      case .plan:
        return "Öffnet deinen bereits aktiven Planbereich"
      }
    }

    switch spec.kind {
    case .training:
      return "Öffnet den Trainingseinstieg für ein neues Training"
    case .cardio:
      return "Öffnet den Lauf-Einstieg oder führt in weitere Cardio-Aktionen"
    case .progress:
      return "Öffnet deinen Fortschritt und Verlauf"
    case .meal:
      return "Öffnet die Ernährung, von dort kannst du Mahlzeiten loggen oder erfassen"
    case .water:
      return "Öffnet die Ernährung zum Wasser-Loggen"
    case .planner:
      return "Öffnet deinen Wochenplan mit den geplanten Einheiten"
    }
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
        repeatLastWorkoutFromHome()
      } label: {
        Label("Letztes Training wiederholen", systemImage: "arrow.uturn.backward")
      }
      .accessibilityHint(store.lastCompletedWorkout == nil ? "Nicht verfügbar, solange noch kein abgeschlossenes Training vorliegt." : "Wiederholt dein zuletzt abgeschlossenes Training.")
      .disabled(store.lastCompletedWorkout == nil)

      Button {
        runCoachAction(.startQuickWorkout)
      } label: {
        Label("Spontan starten", systemImage: "play.fill")
      }

      Button {
        runCoachAction(.openPlanner)
      } label: {
        Label("Wochenplan öffnen", systemImage: "calendar")
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
        if store.activeRun != nil {
          isShowingRunTracker = true
        } else if store.activeWorkout != nil {
          isShowingWorkoutTracker = true
        } else {
          navigation.openTraining(workspace: .laufen)
        }
      } label: {
        Label("Laufbereich öffnen", systemImage: "rectangle.stack.fill")
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
        HStack(spacing: GainsSpacing.tight) {
          PulsingDot(
            color: GainsColor.accentCool,
            coreSize: 6,
            haloSize: 18
          )
          Text("AKTIVE HF")
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
              .lineLimit(2)
              .truncationMode(.tail)
          }

          Image(systemName: "arrow.up.right")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(GainsColor.accentCool)
        }
        .padding(.horizontal, GainsSpacing.m)
        .padding(.vertical, GainsSpacing.tight)
        .background(
          // 2026-05-14 (Polish-Loop 61): BPM-Banner mit Cyan-Glow-
          // Komposition. Live-Sensor signalisiert „Daten kommen rein"
          // — passt zum Glow-Vokabular der App.
          ZStack {
            GainsColor.glassUndertone
            Rectangle().fill(.ultraThinMaterial)
            RadialGradient(
              colors: [GainsColor.accentCool.opacity(0.18), .clear],
              center: .leading,
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
                colors: [GainsColor.accentCool.opacity(0.55), GainsColor.accentCool.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: GainsBorder.hairline
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        .compositingGroup()
        .shadow(color: GainsColor.accentCool.opacity(0.14), radius: 12, x: 0, y: 0)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Heart-Rate-Sensor verbunden")
      .accessibilityValue((ble.liveHeartRate ?? 0) > 0 ? "\(ble.liveHeartRate!) BPM" : "Keine Live-Herzfrequenz")
      .accessibilityHint("Öffnet den verbundenen Heart-Rate-Sensor")
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
      return "Ernährungsziel erreicht"
    }
    if store.nutritionProteinToday >= store.nutritionTargetProtein {
      return "Proteinziel erreicht"
    }
    if kcalProgressRatio >= 0.66 { return "Auf Kurs" }
    if kcalProgressRatio >= 0.34 { return "In Bewegung" }
    return "Startet gerade"
  }

  private var nutritionCaptionLine: String {
    if store.todayNutritionEntries.isEmpty {
      return "Noch keine Mahlzeit getrackt — leg los, wenn du isst."
    }
    let remainingKcal = max(store.nutritionTargetCalories - store.nutritionCaloriesToday, 0)
    let remainingProtein = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
    if remainingKcal == 0 && remainingProtein == 0 {
      return "Kalorien- und Proteinziel erreicht."
    }
    if remainingProtein == 0 {
      return "Noch \(remainingKcal) kcal bis Kalorienziel · Proteinziel erreicht."
    }
    return "Noch \(remainingKcal) kcal bis Kalorienziel · \(remainingProtein) g Eiweiß bis Ziel."
  }

  private var weeklyProgressRatio: Double {
    let goal = max(store.weeklyGoalCount, 1)
    return min(Double(store.weeklySessionsCompleted) / Double(goal), 1.0)
  }

  private var progressDisplayTitle: String {
    let ratio = weeklyProgressRatio
    if store.weeklySessionsCompleted >= store.weeklyGoalCount && store.weeklyGoalCount > 0 {
      return "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Einheiten diese Woche geschafft"
    }
    if ratio >= 0.66 {
      let remaining = max(store.weeklyGoalCount - store.weeklySessionsCompleted, 0)
      return remaining == 1 ? "Noch 1 Einheit bis Ziel" : "Noch \(remaining) Einheiten bis Ziel"
    }
    if ratio >= 0.34 {
      return "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Einheiten diese Woche"
    }
    if store.weeklySessionsCompleted == 0 { return "Diese Woche starten" }
    let sessions = store.weeklySessionsCompleted
    return sessions == 1 ? "1 Einheit geschafft" : "\(sessions) Einheiten geschafft"
  }

  // MARK: - Coach Brief Engine (Variant-Picker + Render-Spec)

  /// Liefert die aktuelle Coach-Brief-Variant basierend auf Workout-State,
  /// Plan, Tageszeit, Streak und Nutrition-Lücke. Reihenfolge ist Priorität.
  private var currentCoachBrief: CoachBrief {
    let now = coachClock
    let hour = currentHour

    // P0 B: Pending-Lock — User hat gerade „Workout starten"/„Lauf starten"
    // getippt, aber `store.activeWorkout`/`activeRun` ist noch nicht
    // publiziert. Wir zeigen schon jetzt den passenden „läuft"-Brief,
    // damit der Header nicht zwischen Day-One/Window und „Workout läuft"
    // flackert.
    if let lock = pendingActionLock {
      switch lock {
      case .startingWorkout:
        return CoachBrief(
          eyebrow: "WORKOUT STARTET",
          glyph: "dumbbell.fill",
          accent: GainsColor.lime,
          headline: "Training wird geöffnet …",
          subline: "Setup läuft im Hintergrund — dein Training ist gleich bereit.",
          primary: CoachActionDescriptor(
            title: "Training öffnen",
            icon: "play.fill",
            metric: nil,
            action: .openWorkoutTracker
          ),
          secondary: nil
        )
      case .startingRun:
        return CoachBrief(
          eyebrow: "LAUF STARTET",
          glyph: "figure.run",
          accent: GainsColor.ember,
          headline: "GPS wird gesucht …",
          subline: "Setup läuft im Hintergrund — dein Lauf ist gleich bereit.",
          primary: CoachActionDescriptor(
            title: "Lauf öffnen",
            icon: "figure.run",
            metric: nil,
            action: .openRunTracker
          ),
          secondary: nil
        )
      }
    }

    // 1) Akut: laufendes Workout/Run hat IMMER Vorrang.
    if let aw = store.activeWorkout {
      // Single-pass stats — 10× Forwarder-Aufrufe (je O(exercises×sets))
      // werden auf einen einzigen Durchlauf reduziert.
      let s = aw.stats
      let remaining = max(s.totalSets - s.completedSets, 0)
      let progress = s.totalSets > 0
        ? Int((Double(s.completedSets) / Double(s.totalSets)) * 100)
        : 0
      return CoachBrief(
        eyebrow: "WORKOUT LÄUFT",
        glyph: "dumbbell.fill",
        accent: GainsColor.lime,
        headline: remaining == 0
          ? "Letzter Satz steht — Finish stark."
          : "Weiter wo du warst.",
        subline: remaining == 0
          ? "Alle \(s.totalSets) Sätze fast durch — \(aw.title) wartet auf den Schlusspunkt."
          : "\(s.completedSets)/\(s.totalSets) Sätze · \(progress) % von \(aw.title) durch.",
        primary: CoachActionDescriptor(
          title: "Training öffnen",
          icon: "play.fill",
          metric: "\(s.completedSets)/\(s.totalSets)",
          action: .openWorkoutTracker
        ),
        secondary: nil
      )
    }

    if let ar = store.activeRun {
      // durationMinutes is in minutes, so hours = /60, remainingMins = %60.
      // The headline uses ar.durationMinutes directly to show total minutes.
      let hours = ar.durationMinutes / 60
      let remainingMins = ar.durationMinutes % 60
      return CoachBrief(
        eyebrow: ar.isPaused ? "RUN PAUSIERT" : "LAUF AKTIV",
        glyph: "figure.run",
        accent: GainsColor.ember,
        headline: ar.isPaused
          ? "Lauf pausiert — bereit für Re-Start?"
          : "Lauf läuft seit \(ar.durationMinutes) Minuten.",
        subline: {
          let heartRate = ar.currentHeartRate > 0 ? "HF \(ar.currentHeartRate) bpm" : "ohne Herzfrequenzdaten"
          return String(
            format: "%.2f km · %02d:%02d · %@",
            ar.distanceKm, hours, remainingMins, heartRate
          )
        }(),
        primary: CoachActionDescriptor(
          title: "Lauf öffnen",
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
          let trimmedRunTitle = runTemplate.title.trimmingCharacters(in: .whitespacesAndNewlines)
          let runTitle = trimmedRunTitle.isEmpty ? "dein Lauf" : trimmedRunTitle
          return CoachBrief(
            eyebrow: "TAG 1",
            glyph: "sparkles",
            accent: GainsColor.ember,
            headline: "Willkommen\(warmName).",
            subline: String(
              format: "Heute steht dein erster Lauf an: %@ · %.1f km · %d Min. Du musst nichts vorbereiten — die Aufzeichnung startet das GPS für dich.",
              runTitle, runTemplate.targetDistanceKm, runTemplate.targetDurationMinutes
            ),
            primary: CoachActionDescriptor(
              title: "Ersten Lauf starten",
              icon: "play.fill",
              metric: String(format: "%.1f km", runTemplate.targetDistanceKm),
              action: .startQuickRun
            ),
            secondary: CoachActionDescriptor(
              title: "Wochenplan öffnen",
              icon: "calendar",
              metric: nil,
              action: .openPlanner
            )
          )
        }
        let trimmedWorkoutTitle = (plan.workoutPlan?.title ?? plan.title).trimmingCharacters(in: .whitespacesAndNewlines)
        let workoutTitle = trimmedWorkoutTitle.isEmpty ? "deinem Training" : trimmedWorkoutTitle
        let exerciseCount = plan.workoutPlan?.exercises.count ?? 0
        return CoachBrief(
          eyebrow: "TAG 1",
          glyph: "sparkles",
          accent: GainsColor.lime,
          headline: "Willkommen\(warmName).",
          subline: exerciseCount > 0
            ? "Heute startest du mit \(workoutTitle) — \(exerciseCount) Übungen, wir führen dich Satz für Satz."
            : "Heute startest du mit \(workoutTitle). Wir führen dich Schritt für Schritt durch dein erstes Training.",
          primary: CoachActionDescriptor(
            title: "Erstes Training",
            icon: "play.fill",
            metric: exerciseCount > 0 ? "\(exerciseCount) Übungen" : nil,
            action: .startPlannedWorkout
          ),
          secondary: CoachActionDescriptor(
            title: "Wochenplan öffnen",
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
          subline: "Heute ist Erholungstag in deinem Plan. Logge deine erste Mahlzeit, dann hast du den ersten kleinen Erfolg schon eingefahren.",
          primary: CoachActionDescriptor(
            title: "Mahlzeit loggen",
            icon: "fork.knife",
            metric: nil,
            action: .openNutritionCapture
          ),
          secondary: CoachActionDescriptor(
            title: "Wochenplan öffnen",
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
          subline: "Heute ist flexibel — du wählst. Erstes Training, kurzer Lauf oder einfach eine Mahlzeit loggen. Jeder erste Schritt zählt.",
          primary: CoachActionDescriptor(
            title: "Training starten",
            icon: "play.fill",
            metric: nil,
            action: .startQuickWorkout
          ),
          secondary: CoachActionDescriptor(
            title: "Wochenplan öffnen",
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
      let isRunPlan = plan.runTemplate != nil || plan.sessionKind?.isRun == true
      let plannedRunSummary = plan.runTemplate.map {
        String(format: "%.1f km · %d Min", $0.targetDistanceKm, $0.targetDurationMinutes)
      }
      let headline: String
      let subline: String
      if daysSince <= 2 {
        headline = "Erster Schritt steht aus\(warmName)."
        subline = isRunPlan
          ? plannedRunSummary.map { "Heute steht dein erster Lauf im Plan, \($0)." }
            ?? "Heute steht dein erster Lauf im Plan. 15 Minuten reichen schon."
          : "Heute ist ein guter Tag für dein erstes Training — kurz und gut."
      } else if daysSince <= 7 {
        headline = "Lass uns klein anfangen."
        subline = "Du hast den Plan da, jetzt fehlt nur dein erstes Training. Dauert keine 30 Minuten."
      } else {
        headline = "Frischer Start gefällig?"
        subline = "Plan steht noch. Wir gehen es langsam an — du wählst die Intensität."
      }

      let primaryAction: CoachActionDescriptor
      if isRunPlan {
        primaryAction = CoachActionDescriptor(
          title: "Ersten Lauf starten",
          icon: "play.fill",
          metric: plan.runTemplate.map { String(format: "%.1f km", $0.targetDistanceKm) },
          action: .startQuickRun
        )
      } else if plan.status == .planned {
        primaryAction = CoachActionDescriptor(
          title: "Erstes Training",
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
          title: "Wochenplan öffnen",
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
      let trimmedLastTitle = last.title.trimmingCharacters(in: .whitespacesAndNewlines)
      let lastTitleText = trimmedLastTitle.isEmpty ? "Training" : trimmedLastTitle
      // PR-Check: höchstes Volumen in der Geschichte = heute?
      let allTimePeak = store.workoutHistory.max(by: { $0.volume < $1.volume })?.volume ?? 0
      let isVolumePR = last.volume >= allTimePeak && last.volume > 0
      if isVolumePR {
        return CoachBrief(
          eyebrow: "PR GEHOLT",
          glyph: "trophy.fill",
          accent: GainsColor.lime,
          headline: "Heute war ein Tag fürs Buch.",
          subline: "\(lastTitleText) · \(last.volume > 0 ? "\(Int(last.volume)) kg Volumen" : "ohne Volumenangabe") — neuer Bestwert. Sieh dir die Story an.",
          primary: CoachActionDescriptor(
            title: "Fortschritt öffnen",
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
          eyebrow: "NACH DEM TRAINING",
          glyph: "fork.knife",
          accent: GainsColor.ember,
          headline: "Solides Training — jetzt nachladen.",
          subline: "\(lastTitleText) abgeschlossen vor \(minutesSince) Minuten. Noch \(proteinGap) g Eiweiß offen.",
          primary: CoachActionDescriptor(
            title: "Mahlzeit loggen",
            icon: "camera.fill",
            metric: "\(proteinGap) g",
            action: .openNutritionCapture
          ),
          secondary: CoachActionDescriptor(
            title: "Fortschritt öffnen",
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
          subline: "\(lastTitleText) · \(last.completedSets) Sätze · \(last.volume > 0 ? "\(Int(last.volume)) kg Volumen" : "ohne Volumenangabe"). Trink was, dann weiter.",
          primary: CoachActionDescriptor(
            title: "Fortschritt öffnen",
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
        eyebrow: "SERIE SCHÜTZEN",
        glyph: "flame.fill",
        accent: GainsColor.ember,
        headline: "Noch \(hoursLeft) h für deine \(store.streakDays)-Tage-Aktivserie.",
        subline: "Eine Mahlzeit oder ein 20-Minuten-Spaziergang reichen, um den Tag als aktiv zu markieren.",
        primary: CoachActionDescriptor(
          title: "Schnelltraining",
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
        let trimmedRunTitle = runTemplate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let runTitle = trimmedRunTitle.isEmpty ? "dein Lauf" : trimmedRunTitle.lowercased()
        return CoachBrief(
          eyebrow: "LAUF-FENSTER",
          glyph: "figure.run",
          accent: GainsColor.ember,
          headline: "Heute steht \(runTitle) an.",
          subline: String(
            format: "%.1f km · ca. %d Minuten. Bestes Timing: jetzt — Wetter & Energie passen.",
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
            title: "Wochenplan öffnen",
            icon: "calendar",
            metric: nil,
            action: .openPlanner
          )
        )
      }
      let trimmedWorkoutTitle = (plan.workoutPlan?.title ?? plan.title).trimmingCharacters(in: .whitespacesAndNewlines)
      let workoutTitle = trimmedWorkoutTitle.isEmpty ? "Dein Training" : trimmedWorkoutTitle
      let trimmedFocus = plan.focus.trimmingCharacters(in: .whitespacesAndNewlines)
      let focusLine = trimmedFocus.isEmpty ? "Heutiges Training" : "Heutiger Plan: \(trimmedFocus)"
      return CoachBrief(
        eyebrow: "WORKOUT-FENSTER",
        glyph: "dumbbell.fill",
        accent: GainsColor.lime,
        headline: "\(workoutTitle) wartet — let's go.",
        subline: "\(focusLine). Bestes Slot-Fenster läuft bis 21 Uhr.",
        primary: CoachActionDescriptor(
          title: "Training starten",
          icon: "play.fill",
          metric: plan.workoutPlan.map { "\($0.exercises.count) Übungen" },
          action: .startPlannedWorkout
        ),
        secondary: CoachActionDescriptor(
          title: "Wochenplan öffnen",
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
        let trimmedRunTitle = runTemplate.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let runTitle = trimmedRunTitle.isEmpty ? "dein Lauf" : trimmedRunTitle.lowercased()
        return CoachBrief(
          eyebrow: "GUTEN MORGEN",
          glyph: "sun.max.fill",
          accent: GainsColor.ember,
          headline: "Heute läuft \(runTitle).",
          subline: String(
            format: "%.1f km · %d Min im Plan. Empfohlene Slots: 07–09 Uhr oder 17–19 Uhr.",
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
            title: "Wochenplan öffnen",
            icon: "calendar",
            metric: nil,
            action: .openPlanner
          )
        )
      }
      let trimmedWorkoutTitle = (plan.workoutPlan?.title ?? plan.title).trimmingCharacters(in: .whitespacesAndNewlines)
      let workoutTitle = trimmedWorkoutTitle.isEmpty ? "Dein Training" : trimmedWorkoutTitle
      let trimmedFocus = plan.focus.trimmingCharacters(in: .whitespacesAndNewlines)
      let focusLine = trimmedFocus.isEmpty ? "Heutiges Training" : "Plan-Fokus: \(trimmedFocus)"
      return CoachBrief(
        eyebrow: "GUTEN MORGEN",
        glyph: "sun.max.fill",
        accent: GainsColor.lime,
        headline: "Heute steht \(workoutTitle) an.",
        subline: "\(focusLine). Slots 16–19 Uhr sind erfahrungsgemäß deine besten.",
        primary: CoachActionDescriptor(
          title: "Wochenplan öffnen",
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
      let trimmedLastTitle = last.title.trimmingCharacters(in: .whitespacesAndNewlines)
      let lastTitleText = trimmedLastTitle.isEmpty ? "Training" : trimmedLastTitle
      if days >= 4, !hasCompletedWorkoutToday {
        return CoachBrief(
          eyebrow: "COMEBACK",
          glyph: "arrow.counterclockwise",
          accent: GainsColor.accentCool,
          headline: "\(days) Tage Pause — Zeit zurück in den Rhythmus.",
          subline: "Letzter Stand: \(lastTitleText), \(last.completedSets) Sätze. Ein lockerer Start ist Gold wert.",
          primary: CoachActionDescriptor(
            title: "Spontan starten",
            icon: "play.fill",
            metric: nil,
            action: .startQuickWorkout
          ),
          secondary: CoachActionDescriptor(
            title: "Wochenplan öffnen",
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
        return "Erholungsmodus"
      }()
      return CoachBrief(
        eyebrow: "ERHOLUNGSTAG",
        glyph: "leaf.fill",
        accent: GainsColor.accentCool,
        headline: "Heute füllt sich der Tank.",
        subline: "\(hrvDetail). Spaziergang, Mobilität oder ein lockerer Rad-Schwung passen.",
        primary: CoachActionDescriptor(
          title: "Mahlzeit loggen",
          icon: "fork.knife",
          metric: nil,
          action: .openNutritionCapture
        ),
        secondary: CoachActionDescriptor(
          title: "Wochenplan öffnen",
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
          ? "Davon \(remainingProtein) g Eiweiß. Eine warme Mahlzeit schließt das sauber."
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
        subline: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Einheiten, \(store.nutritionCaloriesToday) kcal. Schlaf wird heute belohnt.",
        primary: CoachActionDescriptor(
          title: "Fortschritt öffnen",
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
        eyebrow: "FLEXIBLER TAG",
        glyph: "infinity",
        accent: GainsColor.accentCool,
        headline: "Heute bleibt offen — was passt?",
        subline: "Kein fester Plan. Spontanes Training, Lauf oder Mobilität sind alle gleich richtig.",
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
    let isRunPlan = plan.runTemplate != nil || plan.sessionKind?.isRun == true
    let trimmedTitle = (plan.runTemplate?.title ?? plan.sessionKind?.title ?? plan.workoutPlan?.title ?? plan.title).trimmingCharacters(in: .whitespacesAndNewlines)
    return CoachBrief(
      eyebrow: "BEREIT?",
      glyph: isRunPlan ? "figure.run" : "play.fill",
      accent: isRunPlan ? GainsColor.ember : GainsColor.lime,
      headline: trimmedTitle.isEmpty ? "Was passt gerade?" : "Heute: \(trimmedTitle).",
      subline: store.coachHeadline,
      primary: CoachActionDescriptor(
        title: isRunPlan ? "Lauf starten" : "Training starten",
        icon: "play.fill",
        metric: nil,
        action: plan.status == .planned ? .startPlannedWorkout : .startQuickWorkout
      ),
      secondary: CoachActionDescriptor(
        title: "Wochenplan öffnen",
        icon: "calendar",
        metric: nil,
        action: .openPlanner
      )
    )
  }

  // MARK: - Pulse Stats (3 kontextuelle Mini-Werte)

  private var currentPulseStats: [PulseStat] {
    let hour = currentHour
    let plan = store.todayPlannedDay

    // Workout läuft → Sätze, Volumen, HF.
    if let aw = store.activeWorkout {
      let aws = aw.stats   // single-pass statt 3× Forwarder
      var stats: [PulseStat] = [
        PulseStat(
          icon: "checkmark.circle.fill",
          label: "SÄTZE",
          value: "\(aws.completedSets)",
          unit: "/\(aws.totalSets)",
          detail: "Aktive Einheit",
          accent: GainsColor.lime,
          action: .openWorkoutTracker
        ),
        PulseStat(
          icon: "scalemass.fill",
          label: "VOLUMEN",
          value: aws.totalVolume > 0 ? String(format: "%.1f", aws.totalVolume / 1000) : "—",
          unit: aws.totalVolume > 0 ? "t" : "",
          detail: aws.totalVolume > 0 ? "Heutiges Volumen" : "Ohne Volumenangabe",
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
            detail: "Aktuell",
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
      // durationMinutes is in actual minutes; derive HH:MM for compact display.
      let durationHours = ar.durationMinutes / 60
      let durationRemMins = ar.durationMinutes % 60
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
          value: String(format: "%d:%02d", durationHours, durationRemMins),
          unit: "",
          detail: "Seit Start",
          accent: GainsColor.accentCool,
          action: .openRunTracker
        ),
        PulseStat(
          icon: "heart.fill",
          label: "HF",
          value: ar.currentHeartRate > 0 ? "\(ar.currentHeartRate)" : "—",
          unit: ar.currentHeartRate > 0 ? "bpm" : "",
          detail: ar.currentHeartRate > 0 ? "Aktuell" : "Ohne Live-Daten",
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
          label: "EIWEISS",
          value: proteinGap == 0 ? "✓" : "\(proteinGap)",
          unit: proteinGap == 0 ? "" : "g",
          detail: proteinGap == 0 ? "Proteinziel erreicht" : "Noch offen",
          accent: GainsColor.ember,
          action: .openNutritionCapture
        ),
        PulseStat(
          icon: "flame.fill",
          label: "KALORIEN",
          value: "\(store.nutritionCaloriesToday)",
          unit: "/\(store.nutritionTargetCalories)",
          detail: "Heutige Kalorien",
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
            detail: "Heutiger Wert",
            accent: GainsColor.ember,
            action: .openProgress
          )
        )
      }
      while stats.count < 3 {
        if stats.isEmpty { stats.append(streakStat) }
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
      label: "SERIE",
      value: "\(store.streakDays)",
      unit: "T",
      detail: store.streakDays >= 7 ? "Stark dran" : "Dranbleiben",
      accent: GainsColor.lime,
      action: .openProgress
    )
  }

  private var weeklyStat: PulseStat {
    PulseStat(
      icon: "target",
      label: "EINHEITEN",
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
      label: "KALORIEN",
      value: "\(store.nutritionCaloriesToday)",
      unit: "kcal",
      detail: pct >= 100 ? "Kalorienziel erreicht" : "\(pct) % vom Ziel",
      accent: GainsColor.ember,
      action: .openNutrition
    )
  }

  private var proteinStat: PulseStat {
    let gap = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
    return PulseStat(
      icon: "fork.knife",
      label: "EIWEISS",
      value: "\(store.nutritionProteinToday)",
      unit: "/\(store.nutritionTargetProtein) g",
      detail: gap == 0 ? "Proteinziel erreicht" : "Noch \(gap) g bis Ziel",
      accent: GainsColor.ember,
      action: .openNutrition
    )
  }

  // MARK: - Spotlight Choice (welche Card laut, welche kompakt)

  private enum SpotlightChoice { case cockpit, nutrition }

  private var currentSpotlight: SpotlightChoice {
    let hour = currentHour
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
    let hour = currentHour
    let plan = store.todayPlannedDay
    let runningRun = store.activeRun != nil
    let runningWorkout = store.activeWorkout != nil

    let trainingTile = ActionTileSpec(
      kind: .training,
      eyebrow: "PLAN",
      title: runningWorkout ? "Training öffnen" : runningRun ? "Lauf öffnen" : (plan.runTemplate != nil || plan.sessionKind?.isRun == true) ? "Laufbereich öffnen" : "Krafttraining öffnen",
      subtitle: quickStartTrainingSubtitle,
      icon: "dumbbell.fill",
      accent: GainsColor.lime,
      isLive: runningWorkout || runningRun,
      action: .openTrainingTab
    )
    let cardioTile = ActionTileSpec(
      kind: .cardio,
      eyebrow: "LAUFEN",
      title: runningRun ? "Lauf öffnen" : runningWorkout ? "Training öffnen" : "Lauf starten",
      subtitle: {
        if runningRun {
          let dm = store.activeRun?.durationMinutes ?? 0
          let h = dm / 60; let m = dm % 60
          let dur = h > 0 ? String(format: "%d:%02d h", h, m) : "\(m) min"
          let paceSeconds = store.activeRun?.averagePaceSeconds ?? 0
          let pace = paceSeconds > 0
            ? String(format: "%d:%02d/km", paceSeconds / 60, paceSeconds % 60)
            : "ohne Paceangabe"
          return String(format: "%.1f km · %@ · %@", store.activeRun?.distanceKm ?? 0, dur, pace)
        }
        if runningWorkout {
          return "Training läuft gerade"
        }
        if let plannedRun = store.todayPlannedDay.runTemplate {
          return String(format: "Heute · %.1f km · %d Min", plannedRun.targetDistanceKm, plannedRun.targetDurationMinutes)
        }
        if let last = store.latestCompletedRun {
          let pace = last.averagePaceSeconds > 0
            ? String(format: "%d:%02d/km", last.averagePaceSeconds / 60, last.averagePaceSeconds % 60)
            : "ohne Paceangabe"
          return String(format: "Zuletzt · %.1f km · %@", last.distanceKm, pace)
        }
        return "Heute · Lauf oder Indoor-Training starten"
      }(),
      icon: "figure.run",
      accent: GainsColor.ember,
      isLive: runningRun || runningWorkout,
      action: .startQuickRun
    )
    let progressTile = ActionTileSpec(
      kind: .progress,
      eyebrow: "INSIGHTS",
      title: "Fortschritt öffnen",
      subtitle: {
        let goal = max(store.weeklyGoalCount, 1)
        let progress = min(Int((Double(store.weeklySessionsCompleted) / Double(goal)) * 100), 100)
        return "Diese Woche · \(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Einheiten · \(progress)%"
      }(),
      icon: "chart.line.uptrend.xyaxis",
      accent: GainsColor.accentCool,
      isLive: false,
      action: .openProgress
    )
    let mealTile = ActionTileSpec(
      kind: .meal,
      eyebrow: "MAHLZEIT",
      title: "Schnell loggen",
      subtitle: "Heute · \(store.nutritionCaloriesToday)/\(store.nutritionTargetCalories) kcal · \(store.nutritionProteinToday) g Eiweiß",
      icon: "fork.knife",
      accent: GainsColor.ember,
      isLive: false,
      action: .openNutritionCapture
    )
    let waterTile = ActionTileSpec(
      kind: .water,
      eyebrow: "WASSER",
      title: "Ernährung öffnen",
      subtitle: "Heute · +250 ml",
      icon: "drop.fill",
      accent: GainsColor.accentCool,
      isLive: false,
      action: .openNutrition
    )
    let plannerTile = ActionTileSpec(
      kind: .planner,
      eyebrow: "WOCHE",
      title: "Wochenplan öffnen",
      subtitle: nextPlannedSchedule.map { day in
        let weekday = day.weekday.shortLabel.uppercased()
        if let workout = day.workoutPlan {
          return "\(weekday) · \(workout.estimatedDurationMinutes) Min · \(workout.exercises.count) Übungen"
        }
        if let run = day.runTemplate {
          return String(format: "%@ · %.1f km · %d Min", weekday, run.targetDistanceKm, run.targetDurationMinutes)
        }
        return "\(weekday) · \(day.title)"
      } ?? "Diese Woche · Plan anpassen",
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
        let trimmedPlanTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let planTitleFallback = trimmedPlanTitle.isEmpty ? "ohne Plandetail" : trimmedPlanTitle
        if let runTemplate = plan.runTemplate {
          return ActionTileSpec(
            kind: .cardio,
            eyebrow: "ERSTER LAUF",
            title: "Lauf starten",
            subtitle: String(format: "%.1f km · %d Min", runTemplate.targetDistanceKm, runTemplate.targetDurationMinutes),
            icon: "play.fill",
            accent: GainsColor.ember,
            isLive: false,
            action: .startQuickRun
          )
        }
        if plan.sessionKind?.isRun == true {
          return ActionTileSpec(
            kind: .cardio,
            eyebrow: "ERSTER LAUF",
            title: "Lauf starten",
            subtitle: planTitleFallback,
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
          subtitle: plan.workoutPlan.map { "\($0.estimatedDurationMinutes) Min · \($0.exercises.count) Übungen" } ?? planTitleFallback,
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
    if let bpm = ble.liveHeartRate, bpm > 0 { return bpm }
    if let bpm = HealthKitManager.shared.liveHeartRate, bpm > 0 { return bpm }
    if let bpm = store.liveWorkoutHeartRate, bpm > 0 { return bpm }
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
    // 2026-05-03 P0 A: Sheet-Race-Defense — bevor wir ein neues Sheet
    // präsentieren, dismissen wir die aktiven. SwiftUI würde sonst zwei
    // Sheets stapeln können, wenn z. B. ein Coach-Tap und ein anderer
    // Tile-Tap im selben Run-Loop landen.
    closeAllSheets()
    switch action {
    case .openWorkoutTracker:
      guard store.activeWorkout != nil else { return }
      isShowingWorkoutTracker = true
    case .openRunTracker:
      guard store.activeRun != nil else { return }
      isShowingRunTracker = true
    case .openProgress:
      isShowingProgress = true
    case .openProfile:
      isShowingProfile = true
    case .openPlanner:
      // 2026-05-15: Globaler Trigger via AppNavigationStore — eine
      // einzige Instanz statt paralleler HomeView-Cover.
      navigation.openWeekPlanFullscreen()
    case .openNutrition:
      navigation.openNutrition()
    case .openNutritionCapture:
      navigation.presentCapture(kind: .meal)
    case .openTrainingTab:
      if store.activeWorkout != nil {
        isShowingWorkoutTracker = true
      } else if store.activeRun != nil {
        isShowingRunTracker = true
      } else {
        let plan = store.todayPlannedDay
        navigation.openTraining(workspace: (plan.runTemplate != nil || plan.sessionKind?.isRun == true) ? .laufen : .kraft)
      }
    case .startQuickWorkout:
      startFreeWorkout()
    case .startQuickRun:
      startQuickRun()
    case .startPlannedWorkout:
      let plan = store.todayPlannedDay
      if let workoutPlan = store.todayPlannedWorkout {
        presentArrange(for: workoutPlan)
      } else if let runTemplate = plan.runTemplate {
        if store.activeRun != nil {
          isShowingRunTracker = true
        } else if store.activeWorkout != nil {
          isShowingWorkoutTracker = true
        } else {
          let trimmedRunTitle = runTemplate.title.trimmingCharacters(in: .whitespacesAndNewlines)
          pendingActionLock = .startingRun
          store.startRun(from: runTemplate)
          if store.activeRun?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedRunTitle {
            isShowingRunTracker = true
          }
        }
      } else if plan.sessionKind?.isRun == true {
        startQuickRun()
      } else {
        startFreeWorkout()
      }
    }
  }

  /// 2026-05-03 P0 A: Schließt alle gleichzeitig setzbaren Sheet-Booleans
  /// kurz vor dem Öffnen eines neuen Sheets. Verhindert das Stapeln zweier
  /// Sheets, wenn zwei Coach-Aktionen im selben Run-Loop dispatchen.
  private func closeAllSheets() {
    if isShowingWorkoutChooser { isShowingWorkoutChooser = false }
    if isShowingWorkoutBuilder { isShowingWorkoutBuilder = false }
    if isShowingProgress { isShowingProgress = false }
    if isShowingProfile { isShowingProfile = false }
    if arrangingPlan != nil { arrangingPlan = nil }
    pendingAfterChooser = nil
    pendingAfterBuilder = nil
    pendingAfterArrange = nil
  }

  // MARK: - Workout Helpers (unverändert)

  private func startFreeWorkout() {
    if store.activeWorkout != nil {
      isShowingWorkoutTracker = true
      return
    }
    if store.activeRun != nil {
      isShowingRunTracker = true
      return
    }
    guard let plannedWorkout = store.todayPlannedWorkout else {
      isShowingWorkoutBuilder = true
      return
    }
    let expectedTitle = plannedWorkout.title.trimmingCharacters(in: .whitespacesAndNewlines)
    // P0 B: Lock setzen, damit der Coach-Brief nicht zwischen Day-One /
    // Window-Brief und „Workout läuft" flackert, während store.activeWorkout
    // noch nil ist.
    pendingActionLock = .startingWorkout
    store.startQuickWorkout()
    if store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == expectedTitle {
      isShowingWorkoutTracker = true
    }
  }

  private func repeatLastWorkoutFromHome() {
    guard let last = store.lastCompletedWorkout else { return }

    if store.activeWorkout != nil {
      isShowingWorkoutTracker = true
      return
    }

    if store.activeRun != nil {
      isShowingRunTracker = true
      return
    }

    let trimmedLastTitle = last.title.trimmingCharacters(in: .whitespacesAndNewlines)

    if let plan = store.savedWorkoutPlans.first(where: {
      $0.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedLastTitle
    }) {
      pendingActionLock = .startingWorkout
      store.startWorkout(from: plan)
      if store.activeWorkout?.title?.trimmingCharacters(in: .whitespacesAndNewlines) == plan.title.trimmingCharacters(in: .whitespacesAndNewlines) {
        isShowingWorkoutTracker = true
      }
    } else {
      isShowingWorkoutBuilder = true
    }
  }

  private func startQuickRun() {
    if store.activeRun != nil {
      isShowingRunTracker = true
      return
    }

    if store.activeWorkout != nil {
      isShowingWorkoutTracker = true
      return
    }

    pendingActionLock = .startingRun
    store.startQuickRun()
    if store.activeRun?.modality == .run {
      isShowingRunTracker = true
    }
  }

  /// Modality-spezifischer Quick-Start. Long-Press-Shortcuts der Cardio-
  /// Kachel rufen das hier mit `.bikeOutdoor` bzw. `.bikeIndoor`, damit der
  /// User die Modus-Auswahl im Setup-Sheet überspringen kann.
  private func startQuickRun(modality: CardioModality) {
    if store.activeRun != nil {
      isShowingRunTracker = true
      return
    }

    if store.activeWorkout != nil {
      isShowingWorkoutTracker = true
      return
    }

    pendingActionLock = .startingRun
    store.startQuickRun(modality: modality)
    if store.activeRun?.modality == modality {
      isShowingRunTracker = true
    }
  }

  private func presentArrange(for plan: WorkoutPlan) {
    let trimmedPlanTitle = plan.title.trimmingCharacters(in: .whitespacesAndNewlines)

    if store.activeWorkout != nil {
      if store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedPlanTitle {
        arrangingPlan = plan
      } else {
        isShowingWorkoutTracker = true
      }
      return
    }

    if store.activeRun != nil {
      isShowingRunTracker = true
      return
    }

    pendingActionLock = .startingWorkout
    store.startWorkout(from: plan)
    guard store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedPlanTitle else { return }
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
      HomeFormatters.dayMonthDE.string(from: now).uppercased(),
      "WK \(week)"
    )
  }

  // Optim-Sweep: `cachedDateParts` delegiert an `currentDateParts`.
  // Wird an Stellen genutzt, an denen ein späteres @State-Caching
  // (coachClock-getrieben) eingebaut werden kann, ohne alle Call-Sites
  // ändern zu müssen.
  private var cachedDateParts: (day: String, date: String, week: String) {
    currentDateParts
  }

  // Gibt die aktuelle Woche (weekIndex == 0) zurück, wenn mindestens
  // ein Tag den Status `.planned` hat — analog zur Logik in `plannedWeekStrip`.
  private var cachedHomeWeekPreview: GymPlanPreviewWeek? {
    guard let week = store.nextFourWeeksSchedule.first(where: { $0.weekIndex == 0 }),
          week.days.contains(where: { $0.status == .planned }) else { return nil }
    return week
  }

  // MARK: - Insight Card (Brand-Loop 11, 2026-05-14)
  //
  // Eine Zeile, ruhig, keine Floskeln. Tap → ProgressView (Stats-Drill).
  //
  // 2026-05-14 (Polish-Loop 3): Card jetzt mit Glas-Layer + Lime-Edge-
  // Gradient + Sparkle-Icon-Halo. Spielt mit der gleichen Glow-Sprache
  // wie Coach-Brief, aber dezenter — die Insight ist ein Echo, kein
  // Hero.
  @ViewBuilder
  private func insightCard(_ insight: GainsInsight) -> some View {
    Button {
      isShowingProgress = true
    } label: {
      HStack(alignment: .top, spacing: GainsSpacing.s) {
        ZStack {
          Circle()
            .fill(GainsColor.lime.opacity(0.14))
            .frame(width: 26, height: 26)
          Image(systemName: "sparkle")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(GainsColor.lime)
            .shadow(color: GainsColor.lime.opacity(0.275), radius: 4)
        }
        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          let trimmedHeadline = insight.headline.trimmingCharacters(in: .whitespacesAndNewlines)
          let trimmedDetail = insight.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

          Text(trimmedHeadline.isEmpty ? "Fortschrittshinweis" : trimmedHeadline)
            .font(GainsFont.body)
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
          if !trimmedDetail.isEmpty {
            Text(trimmedDetail)
              .font(GainsFont.caption)
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(2)
          }
        }
        Spacer(minLength: 0)
      }
      .padding(GainsSpacing.m)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        ZStack {
          GainsColor.glassUndertone
          Rectangle().fill(.ultraThinMaterial)
          RadialGradient(
            colors: [GainsColor.lime.opacity(0.08), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 160
          )
          .blendMode(.screen)
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [GainsColor.lime.opacity(0.32), GainsColor.border.opacity(0.5)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: GainsBorder.bold
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      // Scroll-Fix: rasterisiert die Layer einmal, bevor der Shadow
      // appliziert wird — verhindert „element drift" beim Scrollen.
      .compositingGroup()
      .shadow(color: GainsColor.lime.opacity(0.05), radius: 10, x: 0, y: 0)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel({
      let trimmedHeadline = insight.headline.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmedHeadline.isEmpty ? "Fortschrittshinweis" : trimmedHeadline
    }())
    .accessibilityValue({
      let trimmedDetail = insight.detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return trimmedDetail.isEmpty ? "Fortschrittshinweis" : trimmedDetail
    }())
    .accessibilityHint("Öffnet deinen Fortschritt mit weiteren Details zu diesem Hinweis")
  }

  // MARK: - Workout-Recovery-Banner (Audit-Loop 3, 2026-05-14)
  // (Streak-Hero-Section entfernt 2026-05-14, User-Direktive:
  //  „mach die Streak weg, glow und leuchten behalten". Der Coach-Brief
  //  und das Completion-Ritual tragen den Glow weiter — Streak bleibt
  //  als Metrik in Profile/Cockpit sichtbar, aber nicht mehr als Hero.)

  /// Wird beim Cold-Start angezeigt, wenn der Persister noch einen offenen
  /// Workout findet. Zwei klare Aktionen: „Fortsetzen" öffnet den Tracker
  /// mit dem alten Stand, „Verwerfen" cleart die Persistenz.
  @ViewBuilder
  private func workoutRecoveryBanner(_ snapshot: PersistedWorkoutSession) -> some View {
    let minutesAgo = Int(max(0, Date().timeIntervalSince(snapshot.savedAt) / 60))
    let savedAgoText: String = {
      if minutesAgo <= 1 { return "vor wenigen Sekunden" }
      if minutesAgo < 60 { return "vor \(minutesAgo) Min" }
      let hours = minutesAgo / 60
      return "vor \(hours) Std"
    }()
    let completed = snapshot.exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    let total = snapshot.exercises.reduce(0) { $0 + $1.sets.count }

    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack(spacing: GainsSpacing.s) {
        ZStack {
          Circle()
            .fill(GainsColor.ember.opacity(0.22))
            .frame(width: 36, height: 36)
          Image(systemName: "exclamationmark.arrow.circlepath")
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(GainsColor.ember)
        }
        VStack(alignment: .leading, spacing: 2) {
          let trimmedSnapshotTitle = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
          let trimmedActiveWorkoutTitle = store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          let trimmedActiveRunTitle = store.activeRun?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          let recoveryTitle = !trimmedActiveWorkoutTitle.isEmpty
            ? trimmedActiveWorkoutTitle
            : !trimmedActiveRunTitle.isEmpty
              ? trimmedActiveRunTitle
              : store.activeWorkout != nil
                ? "Aktives Training"
                : store.activeRun != nil
                  ? "Aktiver Lauf"
                  : (trimmedSnapshotTitle.isEmpty ? "Gespeichertes Training" : trimmedSnapshotTitle)
          let recoveryDetail = store.activeWorkout != nil
            ? "Training läuft gerade"
            : store.activeRun != nil
              ? "Lauf läuft gerade"
              : "\(completed)/\(total) Sätze · gespeichert \(savedAgoText)"

          Text(
            store.activeWorkout != nil
              ? "WORKOUT AKTIV"
              : store.activeRun != nil
                ? "LAUF AKTIV"
                : "WORKOUT GEFUNDEN"
          )
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.ember)
          Text(recoveryTitle)
            .font(GainsFont.title(15))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
          Text(recoveryDetail)
            .font(GainsFont.caption)
            .foregroundStyle(GainsColor.softInk)
        }
        Spacer(minLength: 0)
      }
      HStack(spacing: GainsSpacing.xs) {
        Button {
          let trimmedSnapshotTitle = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)

          if store.activeWorkout != nil {
            isShowingWorkoutTracker = true
          } else if store.activeRun != nil {
            isShowingRunTracker = true
          } else {
            pendingActionLock = .startingWorkout
            store.restoreActiveWorkout(from: snapshot)
            if store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedSnapshotTitle {
              isShowingWorkoutTracker = true
              UISelectionFeedbackGenerator().selectionChanged()
            }
          }
        } label: {
          Text(store.activeWorkout != nil || store.activeRun != nil ? "ÖFFNEN" : "FORTSETZEN")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowTight)
            .foregroundStyle(GainsColor.onLime)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 36)
            .background(
              // 2026-05-14 (Polish-Loop 26): Inner-Light + Bottom-Dim
              // wie bei GainsPrimaryButton — passt zur App-weiten
              // Pille-Sprache.
              ZStack {
                Capsule().fill(GainsColor.lime)
                Capsule()
                  .fill(
                    LinearGradient(
                      colors: [Color.white.opacity(0.22), .clear],
                      startPoint: .top,
                      endPoint: .center
                    )
                  )
                  .blendMode(.plusLighter)
                Capsule()
                  .fill(
                    LinearGradient(
                      colors: [.clear, Color.black.opacity(0.16)],
                      startPoint: .center,
                      endPoint: .bottom
                    )
                  )
              }
            )
            .clipShape(Capsule())
            .compositingGroup()
            .shadow(color: GainsColor.lime.opacity(0.15), radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.activeWorkout != nil ? "Aktives Training öffnen" : store.activeRun != nil ? "Aktiven Lauf öffnen" : "Gespeichertes Training fortsetzen")
        .accessibilityValue(
          {
            let trimmedSnapshotTitle = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedActiveWorkoutTitle = store.activeWorkout?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let trimmedActiveRunTitle = store.activeRun?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if store.activeWorkout != nil || store.activeRun != nil {
              if !trimmedActiveWorkoutTitle.isEmpty { return trimmedActiveWorkoutTitle }
              if !trimmedActiveRunTitle.isEmpty { return trimmedActiveRunTitle }
              return store.activeRun != nil ? "Aktiver Lauf" : "Aktives Training"
            }
            return trimmedSnapshotTitle.isEmpty
              ? "Gespeichertes Training, \(completed) von \(total) Sätzen"
              : "\(trimmedSnapshotTitle), \(completed) von \(total) Sätzen"
          }()
        )
        .accessibilityHint(store.activeWorkout != nil ? "Öffnet dein bereits laufendes Training mit Übungen, Sätzen und Pausen" : store.activeRun != nil ? "Öffnet deinen bereits laufenden Lauf mit Karte, Splits und Steuerung" : "Stellt das gespeicherte Training wieder her und öffnet dein Training")

        Button {
          store.discardRecoverableWorkout()
        } label: {
          Text(store.activeWorkout != nil || store.activeRun != nil ? "AUSBLENDEN" : "VERWERFEN")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowTight)
            .foregroundStyle(GainsColor.softInk)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 36)
            .background(Color.clear)
            .overlay(
              Capsule().stroke(GainsColor.border.opacity(0.6), lineWidth: GainsBorder.bold)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.activeWorkout != nil || store.activeRun != nil ? "Wiederherstellungshinweis ausblenden" : "Gespeichertes Training verwerfen")
        .accessibilityHint(store.activeWorkout != nil || store.activeRun != nil ? "Blendet diesen Wiederherstellungshinweis aus, ohne die laufende Session zu verändern" : "Entfernt den gespeicherten Trainingsstand und blendet diesen Wiederherstellungshinweis aus")
      }
    }
    .padding(GainsSpacing.m)
    .background(
      // 2026-05-14 (Polish-Loop 4): Recovery-Banner als echtes Glas mit
      // konzentriertem Ember-Glow — der gleiche zweiseitige Halo wie
      // beim Coach-Brief, nur in der Warn-Farbe.
      ZStack {
        GainsColor.glassUndertone
        Rectangle().fill(.ultraThinMaterial)
        RadialGradient(
          colors: [GainsColor.ember.opacity(0.22), GainsColor.ember.opacity(0.04), .clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 220
        )
        .blendMode(.screen)
        RadialGradient(
          colors: [GainsColor.ember.opacity(0.10), .clear],
          center: .bottomTrailing,
          startRadius: 0,
          endRadius: 160
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
            colors: [GainsColor.ember.opacity(0.55), GainsColor.ember.opacity(0.12)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.accent
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    // Scroll-Fix: doppelt-Shadow auf einem Glass-Layer braucht
    // compositingGroup, sonst wandert die Kontur während fast-scroll.
    .compositingGroup()
    .shadow(color: GainsColor.ember.opacity(0.07), radius: 14, x: 0, y: 0)
    .shadow(color: GainsColor.shadowCardKey, radius: 12, x: 0, y: 8)
  }

  private var plannedWeekHeader: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("DIESE WOCHE")
        .gainsEyebrow(GainsColor.lime, size: 10, tracking: 1.6)
      Spacer()
      Button {
        if store.activeWorkout != nil {
          isShowingWorkoutTracker = true
        } else if store.activeRun != nil {
          isShowingRunTracker = true
        } else {
          navigation.openWeekPlanFullscreen()
        }
      } label: {
        HStack(spacing: GainsSpacing.xxs) {
          // 2026-05-16 (Polish-Loop): tracking 1.0 → eyebrowTight (1.2) —
          // 1.0 war Off-Token und lief in 9pt-Mono noch enger als der Rest
          // der App-Eyebrow-Linie.
          Text("Plan")
            .font(GainsFont.label(9))
            .tracking(GainsTracking.eyebrowTight)
          Image(systemName: "arrow.up.right")
            .font(.system(size: 10, weight: .heavy))
        }
        .foregroundStyle(GainsColor.softInk)
      }
      .buttonStyle(.plain)
    }
  }

  /// Zeile mit dem heutigen Plan-Highlight: Workout-Titel + Lauf-Distanz,
  /// damit der User auf einen Blick sieht, was heute ansteht — ohne in den
  /// Plan-Tab zu springen.
  private var plannedTodayLine: some View {
    let pref = store.dayPreference(for: Weekday.today)
    let assigned = store.assignedWorkoutPlan(for: Weekday.today)
    let runTemplate = store.runTemplate(for: Weekday.today)
    let isCompleted = store.isPlannedSessionCompletedToday(for: Weekday.today)

    let title: String = {
      if isCompleted { return "Heute erledigt" }
      let assignedTitle = assigned?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let runTitle = runTemplate?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      if !assignedTitle.isEmpty, !runTitle.isEmpty {
        return "\(assignedTitle) + \(runTitle)"
      }
      if !runTitle.isEmpty { return runTitle }
      if !assignedTitle.isEmpty { return assignedTitle }
      switch pref {
      case .training: return "Trainingstag · noch kein Training"
      case .flexible: return "Flexibler Tag · spontan trainieren"
      case .rest:     return "Ruhetag"
      }
    }()

    let icon: String = {
      if isCompleted { return "checkmark.seal.fill" }
      if runTemplate != nil { return "figure.run" }
      if pref == .rest { return "moon.zzz.fill" }
      return "dumbbell.fill"
    }()

    let tint: Color = {
      if isCompleted { return GainsColor.moss }
      if runTemplate != nil { return GainsColor.moss }
      if pref == .rest { return GainsColor.softInk }
      return GainsColor.lime
    }()
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

    return HStack(spacing: GainsSpacing.s) {
      // 2026-05-14 (Polish-Loop 102): Icon-Plate mit echtem Radial-Glow
      // statt 18% Opacity-Wash. „HEUTE"-Eyebrow mit Akzent.
      ZStack {
        Circle().fill(tint.opacity(0.10))
        Circle()
          .fill(
            RadialGradient(
              colors: [tint.opacity(0.30), .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 32
            )
          )
          .blendMode(.plusLighter)
        Circle()
          .strokeBorder(
            LinearGradient(
              colors: [tint.opacity(0.55), tint.opacity(0.12)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.accent
          )
        Image(systemName: icon)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(tint)
          .shadow(color: tint.opacity(0.45), radius: 3)
      }
      .frame(width: 32, height: 32)
      .compositingGroup()
      .shadow(color: tint.opacity(0.22), radius: 6)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: GainsSpacing.xxs) {
          Text("HEUTE")
            .gainsEyebrow(tint, size: 10, tracking: 1.4)
          Circle()
            .fill(tint)
            .frame(width: 3, height: 3)
            .shadow(color: tint.opacity(0.55), radius: 2)
        }
        Text(trimmedTitle.isEmpty ? "Heute ohne Planangabe" : trimmedTitle)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
      }
      Spacer(minLength: 0)

      // Polish-Loop 156 (2026-05-14): Trailing-Chevron als Tap-Affordance —
      // war vorher nur leerer Spacer, sodass die Zeile nicht als tappbar
      // gelesen wurde, obwohl sie die Wochenübersicht öffnet.
      Image(systemName: "chevron.right")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(GainsColor.softInk.opacity(0.55))
    }
  }

  private func plannedWeekPills(_ days: [GymPlanPreviewDay]) -> some View {
    // 2026-05-14 (Polish-Loop 109): Wochen-Pills in dezenten Container
    // mit Hairline-Border + Inner-Light — die 7 Pills wirken jetzt
    // als zusammenhängende Wochen-Surface, nicht als 7 lose Punkte.
    HStack(spacing: GainsSpacing.xs) {
      ForEach(days) { day in
        plannedWeekPill(day)
      }
    }
    .padding(.horizontal, GainsSpacing.xs)
    .padding(.vertical, GainsSpacing.xs)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(GainsColor.background.opacity(0.55))
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
        .strokeBorder(GainsColor.border.opacity(0.50), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
  }

  private func plannedWeekPill(_ day: GymPlanPreviewDay) -> some View {
    let isPlanned = day.status == .planned
    let isRun = day.runTemplate != nil
    let bg: Color = {
      if day.isCompleted { return GainsColor.lime }
      if isPlanned {
        return isRun
          ? (day.isToday ? GainsColor.moss.opacity(0.45) : GainsColor.moss.opacity(0.18))
          : (day.isToday ? GainsColor.lime.opacity(0.45) : GainsColor.lime.opacity(0.16))
      }
      if day.status == .rest { return GainsColor.background.opacity(0.6) }
      return GainsColor.card
    }()

    return Button {
      if store.activeWorkout != nil {
        isShowingWorkoutTracker = true
      } else if store.activeRun != nil {
        isShowingRunTracker = true
      } else {
        navigation.openWeekPlanFullscreen()
      }
    } label: {
      VStack(spacing: GainsSpacing.xxs) {
        Text(day.weekday.shortLabel)
          .font(GainsFont.label(8))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(day.isToday ? GainsColor.ink : GainsColor.softInk)
        // 2026-05-14 (Polish-Loop 29): Heute-Pill bekommt einen sanften
        // Lime-Glow als „du bist hier"-Anker. Andere Tage bleiben
        // ruhig, damit der heutige Tag visuell hervortritt.
        ZStack {
          Circle()
            .fill(bg)
            .frame(width: 26, height: 26)
          if day.isCompleted {
            Image(systemName: "checkmark")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(GainsColor.onLime)
          } else if isRun {
            Image(systemName: "figure.run")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(day.isToday ? GainsColor.onLime : GainsColor.moss)
          } else if isPlanned {
            Image(systemName: "dumbbell.fill")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(day.isToday ? GainsColor.onLime : GainsColor.lime)
          } else {
            Text("\(Calendar.current.component(.day, from: day.date))")
              .font(.system(size: 10, weight: .semibold, design: .rounded))
              .foregroundStyle(GainsColor.softInk)
          }
        }
        .compositingGroup()
        // 2026-05-16 (Polish-Loop): Heute-Glow von 0.45/r=6 auf 0.30/r=5 —
        // gleiche Behandlung wie alle anderen „Heute"-Akzente in der App
        // (Coach-Pille, Cockpit-Status, Pulse-Tile).
        .shadow(
          color: day.isToday ? GainsColor.lime.opacity(0.30) : .clear,
          radius: day.isToday ? 5 : 0
        )
      }
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(day.isToday ? "Heute, \(day.weekday.label)" : day.weekday.label)
    .accessibilityValue(
      day.isCompleted
        ? "Abgeschlossen"
        : isPlanned
          ? (isRun ? "Geplanter Lauf" : "Geplantes Workout")
          : day.status == .rest
            ? "Ruhetag"
            : "Kein Plan"
    )
    .accessibilityHint(
      store.activeWorkout != nil
        ? "Öffnet dein bereits laufendes Training mit Übungen, Sätzen und Pausen"
        : store.activeRun != nil
          ? "Öffnet deinen bereits laufenden Lauf mit Karte, Splits und Steuerung"
          : "Öffnet deinen Wochenplan mit diesem Tag"
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
    HStack(spacing: GainsSpacing.xxs) {
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
              .padding(.horizontal, GainsSpacing.l)
              .padding(.top, GainsSpacing.xsPlus)
              .padding(.bottom, GainsSpacing.s)

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
              .padding(.horizontal, GainsSpacing.l)
              .padding(.bottom, GainsSpacing.l)
          }
        } else {
          VStack(spacing: GainsSpacing.s) {
            SwiftUI.ProgressView()
            Text("Training wird vorbereitet ...")
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
          .accessibilityLabel("Abbrechen")
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
    let trimmedWorkoutTitle = workout.title.trimmingCharacters(in: .whitespacesAndNewlines)

    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text(trimmedWorkoutTitle.isEmpty ? "Workout" : trimmedWorkoutTitle)
        .font(GainsFont.display(28))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)
        .minimumScaleFactor(0.78)

      HStack(spacing: GainsSpacing.xsPlus) {
        metaPill(
          icon: "list.bullet",
          text: workout.exercises.isEmpty ? "ohne Übungsangabe" : "\(workout.exercises.count) Übungen"
        )
        metaPill(
          icon: "repeat",
          text: workout.totalSets > 0 ? "\(workout.totalSets) Sätze" : "ohne Satzangabe"
        )
        metaPill(
          icon: "clock",
          text: plan.estimatedDurationMinutes > 0 ? "\(plan.estimatedDurationMinutes) min" : "ohne Zeitangabe"
        )
      }

      Text("Reihenfolge ändern, Übungen entfernen oder hinzufügen – dann starten.")
        .gainsBody(secondary: true)
        .lineLimit(2)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func metaPill(icon: String, text: String) -> some View {
    let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

    HStack(spacing: GainsSpacing.xs) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(GainsColor.moss)
      Text(trimmedText.isEmpty ? "ohne Planangabe" : trimmedText)
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrowTight)
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(.horizontal, GainsSpacing.tight)
    .frame(minHeight: 28)
    .background(GainsColor.lime.opacity(0.18))
    .clipShape(Capsule())
  }

  private var sectionLabel: some View {
    HStack(spacing: GainsSpacing.xsPlus) {
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

    return HStack(spacing: GainsSpacing.s) {
      Text(String(format: "%02d", index + 1))
        .font(GainsFont.label(11))
        .tracking(1.4)
        .foregroundStyle(GainsColor.moss)
        .frame(width: 32, height: 32)
        .background(GainsColor.lime.opacity(0.22))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text(exercise.name)
          .font(GainsFont.title(17))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        Text(
          "\(exercise.targetMuscle.uppercased()) · \(exercise.sets.count) Sätze"
        )
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
      }

      Spacer()

      Image(systemName: "line.3.horizontal")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.softInk.opacity(0.7))
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .gainsCardStyle(GainsColor.card)
  }

  private var addExerciseRow: some View {
    HStack(spacing: GainsSpacing.s) {
      Image(systemName: "plus")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 32, height: 32)
        .background(GainsColor.ctaSurface)
        .clipShape(Circle())

      Text("ÜBUNG HINZUFÜGEN")
        .font(GainsFont.label(11))
        .tracking(GainsTracking.eyebrowWide)
        .foregroundStyle(GainsColor.ink)

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.m)
    .background(GainsColor.card.opacity(0.6))
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .foregroundStyle(GainsColor.lime.opacity(0.55))
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private func startCTA(for workout: WorkoutSession) -> some View {
    let startHint = workout.exercises.isEmpty
      ? "Nicht verfügbar, solange dieses Workout noch keine Übungen enthält."
      : "Startet dieses Workout mit deinen aktuellen Übungen."

    return Button {
      onStart()
    } label: {
      HStack(spacing: GainsSpacing.s) {
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
      .padding(.horizontal, GainsSpacing.xl)
      .frame(minHeight: 64)
      .background(GainsColor.ctaSurface)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
          .stroke(GainsColor.lime.opacity(0.55), lineWidth: 1.4)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
      .shadow(color: GainsColor.lime.opacity(0.09), radius: 18, x: 0, y: 10)
      .opacity(workout.exercises.isEmpty ? 0.45 : 1)
    }
    .buttonStyle(.plain)
    .accessibilityHint(startHint)
    .disabled(workout.exercises.isEmpty)
  }
}

// 2026-05-31: `private` entfernt, damit der Live-WorkoutTracker dieselbe
// Übungs-Auswahl wiederverwenden kann („Übung hinzufügen" während der
// Session). Single Source of Truth — keine zweite Picker-Implementierung.
struct ExercisePickerSheet: View {
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
        VStack(alignment: .leading, spacing: GainsSpacing.m) {
          searchField

          if filteredExercises.isEmpty {
            VStack(alignment: .leading, spacing: GainsSpacing.xs) {
              Text("Keine Übung gefunden")
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)
              Text("Versuch einen anderen Suchbegriff oder eine Muskelgruppe.")
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GainsSpacing.m)
            .gainsCardStyle()
          } else {
            // Perf (2026-05-31): LazyVStack — Bibliothekszeilen erst beim
            // Scrollen rendern statt alle ~105 vorab.
            LazyVStack(spacing: GainsSpacing.tight) {
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
          .accessibilityLabel("Schließen")
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
    HStack(spacing: GainsSpacing.tight) {
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
        .accessibilityLabel("Suche leeren")
      }
    }
    .padding(.horizontal, GainsSpacing.m)
    .frame(minHeight: 46)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private func exerciseRow(_ item: ExerciseLibraryItem) -> some View {
    HStack(spacing: GainsSpacing.s) {
      Image(systemName: "dumbbell.fill")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 38, height: 38)
        .background(GainsColor.ctaSurface)
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text(item.name)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        Text("\(item.primaryMuscle.uppercased()) · \(item.equipment)")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(2)
      }

      Spacer()

      Text("\(item.defaultSets)×\(item.defaultReps)")
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrowTight)
        .foregroundStyle(GainsColor.moss)
        .padding(.horizontal, GainsSpacing.tight)
        .frame(minHeight: 26)
        .background(GainsColor.lime.opacity(0.22))
        .clipShape(Capsule())

      Image(systemName: "plus")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(GainsColor.onLime)
        .frame(width: 28, height: 28)
        .background(GainsColor.lime)
        .clipShape(Circle())
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .gainsCardStyle(GainsColor.card)
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
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)

    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      Text(trimmedTitle.isEmpty ? "Kennzahl" : trimmedTitle)
        .font(GainsFont.label(10))
        .tracking(2)
        .foregroundStyle(foreground.opacity(0.7))

      valueView

      Spacer(minLength: 0)

      Text(trimmedSubtitle.isEmpty ? "ohne Kennzahldetail" : trimmedSubtitle)
        .font(GainsFont.body(13))
        .foregroundStyle(foreground.opacity(0.72))
    }
    .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
    .padding(GainsSpacing.m)
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  @ViewBuilder
  private var valueView: some View {
    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

    if valueAccent, trimmedValue.contains("/") {
      let components = trimmedValue.split(separator: "/", omittingEmptySubsequences: false).map(
        String.init)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(components.first ?? trimmedValue)
        Text("/")
          .foregroundStyle(GainsColor.lime)
        Text(components.dropFirst().first ?? "")
      }
      .font(GainsFont.display(28))
      .foregroundStyle(foreground)
    } else {
      Text(trimmedValue.isEmpty ? "—" : trimmedValue)
        .font(GainsFont.display(28))
        .foregroundStyle(foreground)
    }
  }
}
