import SwiftUI

// MARK: - Cached Formatters

private enum NutritionFormatters {
  static let weekdayDayMonthDE: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "EEE, d. MMM"
    return f
  }()
}

// MARK: - Nutrition Tracker Hub

struct NutritionTrackerView: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore
  @State private var selectedTab: NutritionTab = .tracker
  /// Namespace für die matchedGeometryEffect-Animation der Switch-Pille
  /// — sorgt dafür, dass der Lime-Indicator zwischen den Tabs sauber
  /// gleitet statt zu „springen".
  @Namespace private var switchNamespace

  enum NutritionTab: String, CaseIterable {
    case tracker = "Tracker"
    case recipes = "Rezepte"

    /// SF-Symbol pro Tab — Icons machen den Switch sichtbar sofort als
    /// Switch erkennbar (statt als statischer Header) und kommunizieren
    /// Rezepte als gleichberechtigte Surface neben Tracker.
    var icon: String {
      switch self {
      case .tracker: return "list.bullet.clipboard.fill"
      case .recipes: return "book.closed.fill"
      }
    }
  }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .top) {
        GainsAppBackground()

        VStack(spacing: 0) {
          // Sub-tab picker
          nutritionTabBar

          // Content — ZStack hält beide Views dauerhaft im Baum.
          // if/else würde bei jedem Tab-Wechsel die inaktive View
          // komplett zerstören: alle ~12 @State-Flags (Sheets,
          // selectedDate, expandedSections, …) gehen verloren und
          // laufende Sheet-Animationen werden mid-frame abgebrochen
          // → Crash-Risiko. Mit ZStack + opacity/allowsHitTesting
          // bleiben beide Views am Leben, behalten ihren State und
          // kein Sheet wird jemals gerissen.
          ZStack {
            CalorienTrackerView()
              .environmentObject(store)
              .environmentObject(navigation)
              .opacity(selectedTab == .tracker ? 1 : 0)
              .allowsHitTesting(selectedTab == .tracker)

            RecipesView()
              .environmentObject(store)
              .environmentObject(navigation)
              .opacity(selectedTab == .recipes ? 1 : 0)
              .allowsHitTesting(selectedTab == .recipes)
          }
        }
      }
    }
  }

  private var nutritionTabBar: some View {
    // 2026-05-14 (Polish-Loop 128): Switch v2 — Icons + matched-
    // GeometryEffect.
    //
    // Vorher steuerte ein per Hand berechnetes `.position()` die
    // Indicator-Animation. Das funktionierte, war aber für SwiftUI
    // schwer zu interpolieren (no implicit geometry-matched). Jetzt:
    // jedem Tab-Button gehört SELBST die Indicator-Capsule (via
    // matchedGeometryEffect), SwiftUI handelt die Animation komplett
    // selbst — sauberes Sliden, kein Springen.
    //
    // Discoverability:
    //   • Icons direkt links neben dem Text (Tracker = Klemmbrett,
    //     Rezepte = Buch). Macht den Switch sofort als „zwei Modi"
    //     erkennbar statt als statisches Tab-Label.
    //   • Container vergrößert: 56pt statt 50pt — mehr Tap-Komfort
    //   • Inaktive Tabs jetzt mit dezenter Lime-Andeutung statt
    //     reinem mutedInk → klarer Hinweis „du kannst hier wechseln"
    HStack(spacing: GainsSpacing.xxs) {
      ForEach(NutritionTab.allCases, id: \.self) { tab in
        nutritionTabButton(tab)
      }
    }
    .padding(GainsSpacing.xxs)
    .background(
      ZStack {
        GainsColor.glassUndertone
        Rectangle().fill(.ultraThinMaterial)
        GainsColor.card.opacity(0.55)
        LinearGradient(
          colors: [GainsColor.glassInnerLight, .clear],
          startPoint: .top,
          endPoint: .center
        )
      }
    )
    .overlay(
      Capsule()
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.border.opacity(0.85), GainsColor.border.opacity(0.35)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
    )
    .clipShape(Capsule())
    .compositingGroup()
    .padding(.horizontal, GainsSpacing.l)
    .padding(.top, GainsSpacing.tight)
    .padding(.bottom, GainsSpacing.s)
  }

  /// Ein einzelner Tab-Slot — bei aktivem Zustand ankert die Lime-
  /// Pille hier per matchedGeometry, sodass SwiftUI sie zwischen den
  /// Slots animiert gleiten lässt.
  private func nutritionTabButton(_ tab: NutritionTab) -> some View {
    let isActive = selectedTab == tab
    return Button {
      withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
        selectedTab = tab
      }
      UISelectionFeedbackGenerator().selectionChanged()
    } label: {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: tab.icon)
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.lime.opacity(0.65))
        Text(tab.rawValue.uppercased())
          .font(.system(size: 12, weight: .heavy, design: .default))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.softInk)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 42)
      .background {
        if isActive {
          ZStack {
            Capsule().fill(GainsColor.lime)
            Capsule()
              .fill(
                LinearGradient(
                  colors: [Color.white.opacity(0.24), .clear],
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
          .compositingGroup()
          .shadow(color: GainsColor.lime.opacity(0.175), radius: 10)
          .shadow(color: GainsColor.lime.opacity(0.09), radius: 22)
          .matchedGeometryEffect(id: "nutritionSwitchPill", in: switchNamespace)
        }
      }
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Calorie Tracker Main View

struct CalorienTrackerView: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.scenePhase) private var scenePhase
  // Day-One-Window — synchron zu HomeView. Solange der User Onboarding < 24h
  // hinter sich hat UND noch keine Mahlzeit geloggt hat, blenden wir einen
  // Welcome-Banner über den Kalorien-Ring, der die drei Capture-Pfade
  // (Foto / Suche / Barcode) erklärt. Sobald die erste Mahlzeit drin ist,
  // verschwindet der Banner automatisch.
  @AppStorage(GainsKey.onboardingCompletedAt) private var onboardingCompletedAt: Double = 0
  @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
  @State private var showsFoodSearch = false
  @State private var pendingMealType: RecipeMealType = .breakfast
  @State private var expandedSections: Set<RecipeMealType> = [.breakfast, .lunch, .dinner, .snack, .shake]
  @State private var showsGoalPicker = false
  @State private var showsNutritionWizard = false
  // 2026-05-03 Intuitivitäts-Sweep P0 E: Quick-Editor für Kcal/Protein-Ziel
  // ohne den 9-Step-Wizard erneut durchlaufen zu müssen.
  @State private var showsQuickGoalEdit = false
  @State private var showsPhotoRecognition = false
  // N2-Fix (2026-05-01): Wenn FoodSearchSheet geschlossen wird und davor
  // signalisiert hat „bitte Photo öffnen", triggern wir es hier nach
  // dem Dismiss — verhindert Sheet-Stacking.
  @State private var showsBarcodeScanner = false
  @State private var pendingAfterFoodSearch: (() -> Void)? = nil
  // Welle 3 (2026-05-03): Speed-Hebel — Quick-Add-Sheet (kcal/Makros in 5s)
  // und Mahlzeit-Picker für Long-Press-Move auf Food-Rows.
  @State private var showsQuickAdd = false
  @State private var quickAddInitialMeal: RecipeMealType = .snack
  // 2026-05-03 Intuitivitäts-Sweep P1-22: Eintrag nachträglich anpassen.
  // `adjustingEntry != nil` triggert das Adjust-Sheet, das mit einem
  // Faktor-Slider Macros + kcal proportional skaliert.
  @State private var adjustingEntry: NutritionEntry? = nil
  // Pulse-Refresh: minütlicher Tick, damit die Coach-Brief-Variants
  // (z. B. „Mittag fehlt") tageszeitabhängig automatisch wechseln.
  // 2026-05-14 Audit-Step 3: Lifecycle-gebundene Pulse-Clock (siehe `.task`
  // unten). `pulseTimer` wurde entfernt — der dauerlaufende autoconnect-
  // Subscriber war ein klassischer Energy-Drain im Hintergrund.
  @State private var pulseClock: Date = Date()
  // P2-Fix (2026-05-01): Wenn der User aktiv über die Chevrons das Datum
  // ändert, soll der Tracker NICHT bei Mitternacht/App-Resume zurück auf
  // „heute" springen — sonst geht seine Auswahl verloren. `userPickedDate`
  // wird in beiden Datums-Buttons gesetzt und in `resetToToday` gecleart.
  @State private var userPickedDate = false
  // Performance (2026-05-31): Memoisierter Tages-Snapshot. Vorher lief
  // `daySnapshot` als computed Property pro Body-Render 5–6× komplett durch
  // `store.nutritionEntries` (Scan + Sort), weil jede @ViewBuilder-Split-
  // Property es erneut las. Jetzt wird einmalig gerechnet und nur bei echtem
  // Datums- oder Eintrags-Wechsel invalidiert (siehe `.onChange` im Body).
  // `nil` = noch nicht/neu zu berechnen — der Getter fällt dann auf eine
  // frische Berechnung zurück, daher kein Flash beim ersten Render.
  @State private var snapshotCache: DaySnapshot? = nil

  private var isToday: Bool {
    Calendar.current.isDateInToday(selectedDate)
  }

  /// Kombiniertes Tages-Snapshot für `selectedDate`.
  /// Ein einziger O(n)-Pass liefert Macro-Summen UND sortierte Einträge,
  /// damit weder `dayTotals` noch `entriesForDay` separat iterieren.
  private struct DaySnapshot {
    let dayStart: Date
    let revision: Int
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    /// Alle Einträge dieses Tages, neueste zuerst.
    let entries: [NutritionEntry]

    func matches(dayStart: Date, revision: Int) -> Bool {
      self.dayStart == dayStart && self.revision == revision
    }
  }

  /// Einmaliger Pass durch `store.nutritionEntries` pro Body-Render.
  /// Vorher: `dayTotals` (je einmal pro caloriesForDay / protein / carbs / fat)
  /// + `entriesForDay` = bis zu 5 Walks. Jetzt: genau 1 Walk.
  // Liefert den gecachten Snapshot; ist der Cache leer (erster Render bzw.
  // direkt nach einer Invalidierung), wird einmalig frisch gerechnet. So ist
  // der Wert immer korrekt — auch bevor `.onChange`/`.onAppear` den Cache
  // gefüllt hat.
  private var daySnapshot: DaySnapshot {
    let dayStart = Calendar.current.startOfDay(for: selectedDate)
    let revision = store.nutritionEntriesRevision
    if let cached = snapshotCache, cached.matches(dayStart: dayStart, revision: revision) {
      return cached
    }
    return computeDaySnapshot(dayStart: dayStart, revision: revision)
  }

  private func computeDaySnapshot(
    dayStart: Date? = nil,
    revision: Int? = nil
  ) -> DaySnapshot {
    let calendar = Calendar.current
    let resolvedDayStart = dayStart ?? calendar.startOfDay(for: selectedDate)
    let resolvedRevision = revision ?? store.nutritionEntriesRevision
    var calories = 0
    var protein  = 0
    var carbs    = 0
    var fat      = 0
    var matching: [NutritionEntry] = []
    for entry in store.nutritionEntries
    where calendar.isDate(entry.loggedAt, inSameDayAs: resolvedDayStart) {
      calories += entry.calories
      protein  += entry.protein
      carbs    += entry.carbs
      fat      += entry.fat
      matching.append(entry)
    }
    // Sortieren in-place nach loggedAt absteigend (neueste oben).
    matching.sort { $0.loggedAt > $1.loggedAt }
    return DaySnapshot(dayStart: resolvedDayStart, revision: resolvedRevision,
                       calories: calories, protein: protein,
                       carbs: carbs, fat: fat, entries: matching)
  }

  // Forwarders — Call-Sites im Body unverändert.
  private var entriesForDay: [NutritionEntry] { daySnapshot.entries }
  private var caloriesForDay: Int { daySnapshot.calories }
  private var proteinForDay:  Int { daySnapshot.protein }
  private var carbsForDay:    Int { daySnapshot.carbs }
  private var fatForDay:      Int { daySnapshot.fat }

  private func nutritionEntries(for date: Date) -> [NutritionEntry] {
    // Wird nur noch für andere Daten (Date-Navigation) aufgerufen.
    // Für `selectedDate` liefert `entriesForDay` das Ergebnis aus `daySnapshot`.
    store.nutritionEntries
      .filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: date) }
      .sorted { $0.loggedAt > $1.loggedAt }
  }

  private func entries(for mealType: RecipeMealType) -> [NutritionEntry] {
    entriesForDay.filter { $0.mealType == mealType }
  }

  // Day-One-Banner: sichtbar solange der User noch keine Mahlzeit geloggt
  // hat. Erklärt die drei Capture-Pfade auf einen Blick + eindeutiges CTA.
  //
  // 2026-05-15 (Audit-Loop 12): 24h-Cap entfernt — analog zum Gym-/Run-Fix.
  // Wer abends onboardet und am nächsten Morgen die App öffnet, würde
  // sonst die Tour verpassen, ohne je eine Mahlzeit geloggt zu haben.
  // Konsistent mit `isInGymDayOneWindow` und `isInRunDayOneWindow`.
  private var isInNutritionDayOneWindow: Bool {
    guard onboardingCompletedAt > 0 else { return false }
    if !store.nutritionEntries.isEmpty { return false }
    return true
  }

  var body: some View {
    // 2026-05-29 Crash-Fix (EXC_BAD_ACCESS code=2, Stack-Overflow):
    // Vorher war der gesamte ScrollView-Content + 5 mealSection-Calls +
    // 6 .sheet-Modifier inline im body. SwiftUI hat dafür eine
    // gigantische Generic-Type-Kette generiert (TupleView × ModifiedContent
    // × Sheet × …), deren rekursive Type-Substitution den 1 MB Main-Thread-
    // Stack zum Überlaufen brachte (sichtbar als swift::SubstGenericParam…
    // im Crash-Trace). Lösung: Body in einzelne @ViewBuilder-Properties
    // splitten — jeder Property-Aufruf bricht die Substitutions-Kette an
    // einer sauberen Naht und gibt dem Compiler eine fresh Type-Context.
    ScrollView(showsIndicators: false) {
      trackerScrollContent
    }
    .sheet(
      isPresented: $showsFoodSearch,
      onDismiss: {
        // N2-Fix: Pending-Action erst nach Sheet-Dismiss ausführen, damit
        // SwiftUI nicht zwei Sheets gleichzeitig animiert.
        if let action = pendingAfterFoodSearch {
          pendingAfterFoodSearch = nil
          action()
        }
      }
    ) {
      FoodSearchSheet(
        mealType: $pendingMealType,
        selectedDate: selectedDate,
        onRequestPhotoRecognition: {
          pendingAfterFoodSearch = { showsPhotoRecognition = true }
          showsFoodSearch = false
        },
        onRequestBarcodeScan: {
          pendingAfterFoodSearch = { showsBarcodeScanner = true }
          showsFoodSearch = false
        }
      )
      .environmentObject(store)
    }
    .sheet(isPresented: $showsGoalPicker) {
      GoalPickerSheet()
        .environmentObject(store)
    }
    .sheet(isPresented: $showsNutritionWizard) {
      NutritionGoalWizardSheet(existingProfile: store.nutritionProfile)
        .environmentObject(store)
    }
    .sheet(isPresented: $showsQuickGoalEdit) {
      NutritionQuickGoalSheet().environmentObject(store)
    }
    .sheet(isPresented: $showsPhotoRecognition) {
      FoodPhotoRecognitionSheet(mealType: pendingMealType, selectedDate: selectedDate, onLog: {})
        .environmentObject(store)
    }
    .sheet(isPresented: $showsBarcodeScanner) {
      BarcodeScannerSheet(mealType: pendingMealType, selectedDate: selectedDate, onLog: {})
        .environmentObject(store)
    }
    .sheet(isPresented: $showsQuickAdd) {
      QuickAddNutritionSheet(initialMealType: quickAddInitialMeal, selectedDate: selectedDate)
        .environmentObject(store)
    }
    .sheet(item: $adjustingEntry) { entry in
      AdjustNutritionEntrySheet(entry: entry)
        .environmentObject(store)
    }
    // 2026-05-14 Audit-Step 3: Pulse-Tick an View-Lifecycle gebunden —
    // statt `Timer.publish().autoconnect()` läuft die Aktualisierung jetzt
    // nur, solange der Nutrition-Tab im Vordergrund ist. Spart Akku und
    // verhindert Body-Refreshes für Inhalt, den niemand sieht.
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: 60_000_000_000)
        if !Task.isCancelled { pulseClock = Date() }
      }
    }
    // P2-Fix (2026-05-01): Sobald die App in den Vordergrund kehrt und der
    // User vorher implizit auf „heute" stand, prüfen wir, ob inzwischen ein
    // Tageswechsel passiert ist (App lief über Mitternacht). In dem Fall
    // springt `selectedDate` automatisch auf den neuen Tag, damit Logging
    // nicht versehentlich auf den Vortag landet.
    .onChange(of: scenePhase) { _, newPhase in
      guard newPhase == .active, !userPickedDate else { return }
      let cal = Calendar.current
      let todayStart = cal.startOfDay(for: Date())
      if !cal.isDate(selectedDate, inSameDayAs: todayStart) {
        selectedDate = todayStart
      }
    }
    // 2026-05-16 (Fertiger-Audit P0-5): nach jedem neuen Log räumt diese
    // Task das Highlight nach 1,6 s wieder ab. `task(id:)` wird automatisch
    // neu gestartet, sobald die ID wechselt — auch bei mehrfachem schnellem
    // Loggen bleibt jeweils nur der letzte Eintrag visuell hervorgehoben.
    .task(id: store.lastLoggedNutritionEntryID) {
      guard store.lastLoggedNutritionEntryID != nil else { return }
      try? await Task.sleep(nanoseconds: 1_600_000_000)
      if !Task.isCancelled {
        withAnimation(.easeOut(duration: 0.5)) {
          store.lastLoggedNutritionEntryID = nil
        }
      }
    }
    // 2026-05-16 (Fertiger-Audit P0-5): Success-Haptik beim ersten Sichten
    // einer neuen Log-ID. Greift unabhängig vom Logging-Pfad (Suche, KI-Foto,
    // Barcode, Recipe-Quick-Track, QuickAdd, Adjust).
    .onChange(of: store.lastLoggedNutritionEntryID) { _, newValue in
      if newValue != nil {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      }
    }
    // Performance (2026-05-31): daySnapshot-Cache füllen/invalidieren. Nur bei
    // echtem Datums- oder Eintrags-Wechsel neu rechnen — nicht bei jedem der
    // 5–6 Body-Reads pro Render. Wichtig: invalidiert über die Store-Revision
    // statt über `.onChange(of: [NutritionEntry])`, damit SwiftUI nicht bei
    // jeder Historien-Mutation die komplette Liste vergleichen muss.
    .onAppear { snapshotCache = computeDaySnapshot() }
    .onChange(of: selectedDate) { _, _ in snapshotCache = computeDaySnapshot() }
    .onChange(of: store.nutritionEntriesRevision) { _, _ in snapshotCache = computeDaySnapshot() }
  }

  // MARK: - Body-Split (Crash-Fix 2026-05-29)
  //
  // Folgende drei Properties zerlegen den vorher inline-Body in drei
  // separat typgeprüfte Stücke. Damit löst sich der Stack-Overflow im
  // SwiftUI-Type-Checker, der vorher beim Tab-Open zu EXC_BAD_ACCESS
  // (code=2) am Main-Thread-Stack-Boundary geführt hat. Jede Property
  // schneidet die Generic-Substitution-Kette an einer sauberen Naht.

  // Alle drei Splits → AnyView, damit der Type des Body-Trees klein bleibt
  // und die rekursive Generic-Substitution beim Tab-Open nicht den
  // Main-Thread-Stack overrun.
  private var trackerScrollContent: AnyView {
    AnyView(
      VStack(spacing: 0) {
        dateNavigationRow
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.m)
          .padding(.bottom, GainsSpacing.s)

        headerBannerOrPulse

        calorieRingCard
          .padding(.horizontal, GainsSpacing.l)
          .padding(.bottom, GainsSpacing.m)

        if isToday && showsRecentsStrip {
          recentsStrip
            .padding(.bottom, GainsSpacing.m)
        }

        mealSectionsBlock

        if isToday && !entriesForDay.isEmpty {
          daySummaryFooter
            .padding(.horizontal, GainsSpacing.l)
            .padding(.bottom, GainsSpacing.xl)
        } else {
          Spacer(minLength: 24)
        }
      }
    )
  }

  private var headerBannerOrPulse: AnyView {
    if isInNutritionDayOneWindow && isToday {
      return AnyView(
        dayOneNutritionBanner
          .padding(.horizontal, GainsSpacing.l)
          .padding(.bottom, GainsSpacing.m)
      )
    } else if isToday, let pulse = currentNutritionPulse {
      return AnyView(
        nutritionPulseLine(pulse)
          .padding(.horizontal, GainsSpacing.l)
          .padding(.bottom, GainsSpacing.s)
      )
    } else {
      return AnyView(EmptyView())
    }
  }

  /// Meal sections — Einträge einmalig nach Typ gruppieren statt
  /// 5× entries(for:) → entriesForDay → daySnapshot aufzurufen.
  private var mealSectionsBlock: AnyView {
    let grouped = Dictionary(grouping: entriesForDay, by: \.mealType)
    return AnyView(
      VStack(spacing: GainsSpacing.tight) {
        mealSection(.breakfast, title: "Frühstück",   emoji: "🌅",  entries: grouped[.breakfast] ?? [])
        mealSection(.lunch,     title: "Mittagessen", emoji: "🍽️", entries: grouped[.lunch]     ?? [])
        mealSection(.dinner,    title: "Abendessen",  emoji: "🌙",  entries: grouped[.dinner]    ?? [])
        mealSection(.snack,     title: "Snacks",      emoji: "🍎",  entries: grouped[.snack]     ?? [])
        mealSection(.shake,     title: "Shake",       emoji: "🥤",  entries: grouped[.shake]     ?? [])
      }
      .padding(.horizontal, GainsSpacing.l)
      .padding(.bottom, GainsSpacing.m)
    )
  }

  // MARK: Date Navigation

  private var dateNavigationRow: AnyView {
    // 2026-05-14 (Polish-Loop 84): Pfeil-Buttons als Glas-Pillen.
    // 2026-05-29 Crash-Fix: AnyView-erased, damit der Body-Type des
    // umgebenden trackerScrollContent kompakt bleibt.
    AnyView(
      HStack {
      Button {
        withAnimation(.spring(response: 0.3)) {
          selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
          userPickedDate = true
        }
      } label: {
        dateNavArrow(systemName: "chevron.left", enabled: true)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Vorheriger Tag")

      Spacer()

      VStack(spacing: 2) {
        Text(isToday ? "Heute" : dateLabel(selectedDate))
          .font(GainsFont.title(17))
          .foregroundStyle(GainsColor.ink)
        if isToday {
          Text(dateLabel(selectedDate))
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrow)
            .foregroundStyle(GainsColor.softInk)
        }
      }

      Spacer()

      Button {
        withAnimation(.spring(response: 0.3)) {
          let cal = Calendar.current
          let tomorrow = cal.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
          let todayStart = cal.startOfDay(for: Date())
          if tomorrow <= todayStart {
            selectedDate = tomorrow
            userPickedDate = !cal.isDate(tomorrow, inSameDayAs: todayStart)
          }
        }
      } label: {
        dateNavArrow(systemName: "chevron.right", enabled: !isToday)
      }
      .buttonStyle(.plain)
      .disabled(isToday)
      .accessibilityLabel("Nächster Tag")
      }
    )
  }

  /// Wiederverwendbarer Pfeil-Button für die Datum-Navigation.
  private func dateNavArrow(systemName: String, enabled: Bool) -> some View {
    Image(systemName: systemName)
      .font(.system(size: 13, weight: .heavy))
      .foregroundStyle(enabled ? GainsColor.softInk : GainsColor.mutedInk.opacity(0.5))
      .frame(width: 36, height: 36)
      .background(
        ZStack {
          Circle().fill(GainsColor.elevated)
          Circle()
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
        Circle().strokeBorder(
          LinearGradient(
            colors: [GainsColor.border.opacity(0.85), GainsColor.border.opacity(0.35)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 0.8
        )
      )
      .clipShape(Circle())
      .opacity(enabled ? 1 : 0.6)
  }

  // MARK: - Day-One Nutrition Banner
  //
  // Welcome-Banner für die ersten 24h nach Onboarding, solange noch keine
  // Mahlzeit geloggt ist. Erklärt die drei Capture-Pfade (Suche / Foto /
  // Barcode) — der häufigste Stolperstein bei Anfängern ist nicht „wo ist
  // der Logger", sondern „welcher der drei Wege ist der beste für mich".
  // Großes CTA „Erste Mahlzeit loggen" führt direkt in die Suche.

  private var dayOneNutritionBanner: AnyView {
    AnyView(_dayOneNutritionBanner)
  }

  private var _dayOneNutritionBanner: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(spacing: GainsSpacing.xsPlus) {
        Image(systemName: "sparkles")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        Text("DEIN ERSTER LOG")
          .gainsEyebrow(GainsColor.lime, size: 12, tracking: 1.4)
      }

      Text("Drei Wege — du wählst, was schneller geht.")
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
        .fixedSize(horizontal: false, vertical: true)

      VStack(spacing: GainsSpacing.xsPlus) {
        dayOnePathRow(
          icon: "magnifyingglass",
          title: "Suche",
          detail: "Tippe einen Lebensmittelnamen — gängige Produkte sind drin."
        )
        dayOnePathRow(
          icon: "camera.fill",
          title: "Foto",
          detail: "Mach ein Bild vom Teller — KI schätzt Portion und Makros."
        )
        dayOnePathRow(
          icon: "barcode.viewfinder",
          title: "Barcode",
          detail: "Verpacktes Produkt? EAN scannen, fertig."
        )
      }

      Button {
        pendingMealType = currentMealTypeForTime()
        showsFoodSearch = true
      } label: {
        HStack(spacing: GainsSpacing.xsPlus) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 14, weight: .bold))
          Text("Erste Mahlzeit loggen")
            .font(GainsFont.label(13))
            .tracking(GainsTracking.eyebrowTight)
          Spacer(minLength: 0)
          Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .heavy))
        }
        .foregroundStyle(GainsColor.onLime)
        .padding(.horizontal, GainsSpacing.m)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(
          // 2026-05-14 (Polish-Loop 120): Day-One-CTA mit Inner-Light
          // + Bottom-Dim — wie GainsPrimaryButton.
          ZStack {
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .fill(GainsColor.lime)
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
        )
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        .compositingGroup()
        .shadow(color: GainsColor.lime.opacity(0.16), radius: 14)
      }
      .buttonStyle(.plain)
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      // 2026-05-14 (Polish-Loop 120): Day-One-Banner mit Lime-Glow-
      // Komposition statt flachem Diagonal-Gradient.
      ZStack {
        GainsColor.card
        RadialGradient(
          colors: [GainsColor.lime.opacity(0.20), GainsColor.lime.opacity(0.05), .clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 280
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
            colors: [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.12)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.accent
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
    .shadow(color: GainsColor.lime.opacity(0.08), radius: 14)
  }

  private func dayOnePathRow(icon: String, title: String, detail: String) -> some View {
    HStack(spacing: GainsSpacing.s) {
      // 2026-05-14 (Polish-Loop 120): Icon-Plate mit Radial-Glow +
      // Edge-Gradient.
      ZStack {
        Circle().fill(GainsColor.lime.opacity(0.10))
        Circle()
          .fill(
            RadialGradient(
              colors: [GainsColor.lime.opacity(0.30), .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 32
            )
          )
          .blendMode(.plusLighter)
        Circle()
          .strokeBorder(
            LinearGradient(
              colors: [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.12)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 0.6
          )
        Image(systemName: icon)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .shadow(color: GainsColor.lime.opacity(0.225), radius: 3)
      }
      .frame(width: 32, height: 32)
      .compositingGroup()
      .shadow(color: GainsColor.lime.opacity(0.09), radius: 4)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(GainsFont.title(13))
          .foregroundStyle(GainsColor.ink)
        Text(detail)
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
  }

  /// Heuristik: empfiehlt für Day-One-Erstes-Loggen den passenden Meal-Type
  /// nach Tageszeit, damit der User nicht aktiv wählen muss.
  private func currentMealTypeForTime() -> RecipeMealType {
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 5..<10:  return .breakfast
    case 10..<15: return .lunch
    case 15..<18: return .snack
    case 18..<23: return .dinner
    default:      return .snack
    }
  }

  // MARK: Calorie Ring Card

  private var calorieRingCard: AnyView {
    AnyView(_calorieRingCard)
  }

  private var _calorieRingCard: some View {
    // Single-pass über nutritionEntries — verhindert separate daySnapshot-
    // Traversals für proteinForDay/carbsForDay/fatForDay/caloriesForDay.
    let snap = daySnapshot
    return VStack(spacing: 0) {
      // Goal + Wizard buttons
      VStack(spacing: GainsSpacing.tight) {

        // Pill-Zeile: Ziel-Picker + kompaktes "Anpassen" wenn Profil vorhanden
        HStack(spacing: GainsSpacing.xsPlus) {
          Button {
            showsGoalPicker = true
          } label: {
            HStack(spacing: GainsSpacing.xs) {
              Image(systemName: store.nutritionGoal.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GainsColor.moss)
                .shadow(color: GainsColor.moss.opacity(0.45), radius: 3)
              Text(store.nutritionGoalHeadline)
                .font(GainsFont.label(11))
                .foregroundStyle(GainsColor.ink)
              Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(GainsColor.softInk)
            }
            .padding(.horizontal, GainsSpacing.s)
            .frame(height: 30)
            .background(
              // 2026-05-14 (Polish-Loop 81): Goal-Pill mit Glas-Look —
              // ruhig, aber konsistent zur App-Glow-Sprache.
              ZStack {
                Capsule().fill(GainsColor.elevated)
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
                  colors: [GainsColor.border.opacity(0.85), GainsColor.border.opacity(0.35)],
                  startPoint: .top,
                  endPoint: .bottom
                ),
                lineWidth: 1
              )
            )
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)

          if store.nutritionProfile != nil {
            // P0 E: Tap = Quick-Edit (Kcal/Protein-Slider, sofort wirksam).
            // Long-Press = Profil neu berechnen (kompletter Wizard).
            Button {
              showsQuickGoalEdit = true
            } label: {
              // Polish-Loop 160 (2026-05-14): Chevron-Affordance, damit
              // die Pille als CTA gelesen wird und nicht als Status-Tag.
              HStack(spacing: GainsSpacing.xs) {
                // 2026-05-29 (A18): zurück auf moss. Der Chip sitzt jetzt auf
                // hellem Frosted-Glass; moss (#6E8B2C) liest sich dort sauber,
                // lime wäre auf Hell zu kontrastarm.
                Image(systemName: "slider.horizontal.3")
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundStyle(GainsColor.moss)
                  .shadow(color: GainsColor.lime.opacity(0.225), radius: 3)
                Text("Ziel anpassen")
                  .font(GainsFont.label(11))
                  .foregroundStyle(GainsColor.moss)
                Image(systemName: "chevron.right")
                  .font(.system(size: 10, weight: .bold))
                  .foregroundStyle(GainsColor.moss.opacity(0.75))
              }
              .padding(.horizontal, GainsSpacing.s)
              .frame(height: 30)
              .background(
                // 2026-05-14 (Polish-Loop 126): Goal-Anpassen-Pille
                // mit Glas-Look + Radial-Akzent.
                ZStack {
                  Capsule().fill(GainsColor.lime.opacity(0.10))
                  Capsule()
                    .fill(
                      RadialGradient(
                        colors: [GainsColor.lime.opacity(0.20), .clear],
                        center: .leading,
                        startRadius: 0,
                        endRadius: 80
                      )
                    )
                    .blendMode(.screen)
                }
              )
              .clipShape(Capsule())
              .overlay(
                Capsule().strokeBorder(
                  LinearGradient(
                    colors: [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                  ),
                  lineWidth: 1
                )
              )
              .compositingGroup()
              .shadow(color: GainsColor.lime.opacity(0.09), radius: 6)
            }
            .buttonStyle(.plain)
            .contextMenu {
              Button {
                showsNutritionWizard = true
              } label: {
                Label("Profil neu berechnen", systemImage: "function")
              }
            }
          }

          Spacer()
        }

        // Prominenter "Berechnen"-CTA – nur solange noch kein Profil berechnet wurde
        if store.nutritionProfile == nil {
          Button {
            showsNutritionWizard = true
          } label: {
            HStack(spacing: GainsSpacing.m) {
              // 2026-05-14 (Polish-Loop 127): Icon-Plate mit Inner-
              // Light + Dim für „echte" Plastizität.
              ZStack {
                RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                  .fill(GainsColor.moss.opacity(0.25))
                RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                  .fill(
                    LinearGradient(
                      colors: [Color.white.opacity(0.12), .clear],
                      startPoint: .top,
                      endPoint: .center
                    )
                  )
                  .blendMode(.plusLighter)
                Image(systemName: "function")
                  .font(.system(size: 20, weight: .bold))
                  .foregroundStyle(GainsColor.onLime)
              }
              .frame(width: 46, height: 46)

              VStack(alignment: .leading, spacing: 2) {
                Text("Kalorienbedarf berechnen")
                  .font(GainsFont.label(15))
                  .foregroundStyle(GainsColor.onLime)
                Text("Mifflin-St Jeor + Aktivitätsfaktor")
                  .font(GainsFont.label(10))
                  .foregroundStyle(GainsColor.onLime.opacity(0.75))
              }
              Spacer()
              Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(GainsColor.onLime.opacity(0.75))
            }
            .padding(.horizontal, GainsSpacing.m)
            .frame(height: 64)
            .background(
              ZStack {
                RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
                  .fill(GainsColor.lime)
                RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
                  .fill(
                    LinearGradient(
                      colors: [Color.white.opacity(0.22), .clear],
                      startPoint: .top,
                      endPoint: .center
                    )
                  )
                  .blendMode(.plusLighter)
                RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
                  .fill(
                    LinearGradient(
                      colors: [.clear, Color.black.opacity(0.16)],
                      startPoint: .center,
                      endPoint: .bottom
                    )
                  )
              }
            )
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
            .compositingGroup()
            .shadow(color: GainsColor.lime.opacity(0.16), radius: 14)
            .shadow(color: GainsColor.lime.opacity(0.08), radius: 26)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, GainsSpacing.l)
      .padding(.top, GainsSpacing.m)
      .padding(.bottom, GainsSpacing.l)

      // Ring + macros layout
      HStack(alignment: .center, spacing: GainsSpacing.xl) {
        // Calorie Ring
        calorieRing(kcal: snap.calories)
          .frame(width: 170, height: 170)

        // Macro breakdown
        VStack(alignment: .leading, spacing: GainsSpacing.m) {
          macroRow(
            label: "Protein",
            current: snap.protein,
            target: store.nutritionTargetProtein,
            unit: "g",
            color: GainsColor.lime
          )
          macroRow(
            label: "Kohlenh.",
            current: snap.carbs,
            target: store.nutritionTargetCarbs,
            unit: "g",
            color: GainsColor.accentCool
          )
          macroRow(
            label: "Fett",
            current: snap.fat,
            target: store.nutritionTargetFat,
            unit: "g",
            color: GainsColor.macroFat
          )
        }
        .frame(maxWidth: .infinity)
      }
      .padding(.horizontal, GainsSpacing.l)
      .padding(.bottom, GainsSpacing.l)

      // Polish-Loop 158 (2026-05-14): Hairline-Gradient-Divider statt
      // hartem 1pt-Rectangle — bridged Ring-Bereich und Summary-Strip
      // weicher.
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
        .padding(.horizontal, GainsSpacing.l)

      // Polish-Loop 159 (2026-05-14): Summary-Pills sitzen jetzt in einem
      // einheitlichen Container mit dezenter Surface — wirkt als
      // KPI-Strip statt drei lose Pills mit Spacern dazwischen.
      HStack(spacing: 0) {
        summaryPill(label: "Gegessen", value: "\(snap.calories) kcal", color: GainsColor.lime)
          .frame(maxWidth: .infinity)
        summaryStripDivider()
        summaryPill(label: "Ziel", value: "\(store.nutritionTargetCalories) kcal", color: GainsColor.mutedInk)
          .frame(maxWidth: .infinity)
        summaryStripDivider()
        let burned = isToday ? Double(store.healthSnapshot?.activeEnergyToday ?? 0) : 0
        summaryPill(label: "Verbrannt", value: "\(Int(burned)) kcal", color: GainsColor.macroFat)
          .frame(maxWidth: .infinity)
      }
      .padding(.vertical, GainsSpacing.s)
      .padding(.horizontal, GainsSpacing.m)
      .background(
        // 2026-05-16 (Polish-Loop): Summary-Strip war ein scharf-eckiges
        // Rechteck in einer Hero-runden Karte — wirkte wie ein Fremdkörper.
        // Jetzt mit GainsRadius.standard abgerundet, plus Hairline-Border
        // damit der Strip als eigenes KPI-Element lesbar bleibt.
        // 2026-05-29 (A18): adaptiver ink-Inset (gleiches Muster wie der
        // GainsHeroCard-Metrik-Strip). Auf hellem Frosted ein dezent dunkler
        // KPI-Streifen, im Dark-Mode ein dezent hellerer — beides aus `ink`.
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .fill(GainsColor.ink.opacity(0.04))
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .fill(
              LinearGradient(
                colors: [
                  GainsColor.ink.opacity(0.03),
                  Color.clear
                ],
                startPoint: .top,
                endPoint: .center
              )
            )
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(GainsColor.ink.opacity(0.08), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .padding(.horizontal, GainsSpacing.l)
      .padding(.top, GainsSpacing.s)
      .padding(.bottom, GainsSpacing.m)
    }
    // 2026-05-14 (Polish-Loop 78): Hero-Card im Ernährungs-Tab — Ember-Akzent.
    // 2026-05-29 (A18 „Mehr Glas, freundlicher"): adaptive Frosted-Glass via
    // gainsHeroGlass statt dunkler Bühne — hell & milchig im Light-Mode,
    // dunkel im Dark-Mode, mit lebendigem Ember-Glow (Ernährungs-Identität).
    // Helper kapselt Background + Edge + Akzent-Rahmen + Shadow.
    .gainsHeroGlass(accent: GainsColor.ember)
  }

  private func calorieRing(kcal: Int) -> some View {
    let progress = min(CGFloat(kcal) / CGFloat(max(store.nutritionTargetCalories, 1)), 1.0)
    let remaining = max(store.nutritionTargetCalories - kcal, 0)
    let isOver = kcal > store.nutritionTargetCalories
    let ringColor: Color = isOver ? GainsColor.ember : GainsColor.lime

    return ZStack {
      // 2026-05-14 (Polish-Loop 78): Ring mit dreifacher Tiefe.
      //   1) Innerer Akzent-Glow als atmender Background
      //   2) Track als sehr dezenter Hairline-Kreis
      //   3) Progress mit Triple-Shadow (sharp + soft halo + atmospheric)

      // 1) Inner Background-Glow
      Circle()
        .fill(
          RadialGradient(
            colors: [ringColor.opacity(0.16), ringColor.opacity(0.02), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 90
          )
        )
        .blendMode(.plusLighter)

      // 2) Track
      Circle()
        .stroke(GainsColor.border.opacity(0.55), lineWidth: 12)

      // 3) Progress
      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          AngularGradient(
            colors: [ringColor.opacity(0.55), ringColor, ringColor.opacity(0.85)],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
          ),
          style: StrokeStyle(lineWidth: 12, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .shadow(color: ringColor.opacity(0.55), radius: 6)
        .shadow(color: ringColor.opacity(0.22), radius: 14)
        .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)

      // Center: Hero-Numerik + Sub-Caption.
      VStack(spacing: 0) {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
          Text("\(kcal)")
            .font(.system(size: 36, weight: .semibold, design: .rounded))
            .monospacedDigit()
            // 2026-05-29 (A18): zurück auf adaptives ink — Card ist jetzt
            // helles Frosted-Glass im Light-Mode.
            .foregroundStyle(isOver ? GainsColor.ember : GainsColor.ink)
            .shadow(color: ringColor.opacity(0.22), radius: 6)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.5), value: kcal)
        }
        Text("/ \(store.nutritionTargetCalories) kcal")
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .foregroundStyle(GainsColor.softInk)
          .padding(.top, -2)
        Text(isOver ? "+\(kcal - store.nutritionTargetCalories) drüber" : "\(remaining) übrig")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(isOver ? GainsColor.ember : GainsColor.softInk)
          .padding(.top, 4)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.5), value: remaining)
      }
    }
    .compositingGroup()
  }

  private func macroRow(label: String, current: Int, target: Int, unit: String, color: Color) -> some View {
    // 2026-05-14 (Polish-Loop 79): Moderne 3-Zeilen-Macro-Row mit
    // Mono-Werten, Gradient-Progress + Glow auf der Fill-Capsule.
    let safeTarget = max(target, 1)
    let progress = min(Double(current) / Double(safeTarget), 1.0)
    return VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 0) {
        Text(label.uppercased())
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(color.opacity(0.85))
          .frame(width: 80, alignment: .leading)
        Spacer()
        HStack(alignment: .firstTextBaseline, spacing: 1) {
          Text("\(current)")
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            // 2026-05-29 (A18): zurück auf adaptive Tokens — helles Frosted-Glass.
            .foregroundStyle(GainsColor.ink)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.4), value: current)
          Text("/\(target)")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.softInk)
          Text(unit)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(GainsColor.mutedInk)
            .padding(.leading, 1)
        }
      }

      // Polish-Loop 157 (2026-05-14): Macro-Bar als Telemetrie-Balken
      // (Track + Border + Gradient + plusLighter Inner-Light + Glow) —
      // 5pt statt 4pt, damit es nicht wie ein Skeleton-Loader aussieht.
      //
      // 2026-05-29 Crash-Hardening: GeometryReader innerhalb einer
      // HStack mit fixed-frame Sibling-View kann beim ersten Layout-Pass
      // `.nan` als size liefern. `NaN * progress = NaN`, `max(NaN, 5) = NaN`
      // (IEEE-754), und `.frame(width: NaN)` triggert auf iOS 17+ einen
      // SIGABRT „CoreAnimation: invalid bounds". Daher: width sanitisieren.
      GeometryReader { geo in
        let rawWidth: CGFloat = geo.size.width.isFinite ? geo.size.width : 0
        let fillWidth: CGFloat = max(rawWidth * CGFloat(progress), 5)
        ZStack(alignment: .leading) {
          // 2026-05-29 (A18): adaptiver ink-Inset statt weiß — auf hellem
          // Frosted ist Weiß unsichtbar; ink (#0B0E13 Light / #FAFAFA Dark)
          // gibt in beiden Modi eine dezent erkennbare leere Spur.
          Capsule()
            .fill(GainsColor.ink.opacity(0.06))
          Capsule()
            .strokeBorder(GainsColor.ink.opacity(0.10), lineWidth: GainsBorder.hairline)
          Capsule()
            .fill(
              LinearGradient(
                colors: [color.opacity(0.85), color],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .overlay(
              Capsule()
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
            .frame(width: fillWidth)
            .shadow(color: color.opacity(0.32), radius: 4, x: 1, y: 0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
        .compositingGroup()
      }
      .frame(height: 5)
    }
  }

  private func summaryPill(label: String, value: String, color: Color) -> some View {
    // Polish-Loop 159 (2026-05-14): Summary-Pill als Cell in einem
    // einheitlichen KPI-Strip. Wert mit minimumScaleFactor damit
    // „1247 kcal" auch in der mittleren Spalte nicht abgeschnitten wird.
    VStack(spacing: GainsSpacing.xs) {
      HStack(spacing: 4) {
        Circle()
          .fill(color)
          .frame(width: 4, height: 4)
          .shadow(color: color.opacity(0.55), radius: 2)
        Text(label.uppercased())
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          // 2026-05-29 (A18): zurück auf adaptives mutedInk.
          .foregroundStyle(GainsColor.mutedInk)
      }
      Text(value)
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .contentTransition(.numericText())
    }
  }

  /// Senkrechter Hairline-Trenner zwischen den drei Summary-Cells.
  private func summaryStripDivider() -> some View {
    Rectangle()
      .fill(GainsColor.border.opacity(0.40))
      .frame(width: 0.6, height: 28)
  }

  // MARK: Meal Section
  //
  // Welle 3 Cleaner-Pass (2026-05-03): Header dezenter (kcal-Pill auf
  // hairline-Border, Subline kürzer), Empty-State eine schlanke Zeile
  // statt großer Plus-Icon, Action-Bar nur „Hinzufügen | KI-Foto" mit
  // klar getrennten Pfaden. Food-Rows bekommen Long-Press-Power-Menu
  // (Wieder loggen / Duplizieren / In Mahlzeit verschieben / Löschen).

  // 2026-05-29 Crash-Fix Round 3 (AnyView-Type-Erasure):
  // `some View` ist NUR an der API-Grenze opaque — der Compiler löst
  // innerhalb der gleichen Datei den vollen Underlying-Type auf. Damit
  // war meine Split-Strategie aus Round 2 wirkungslos: jede Helper-Funktion
  // hatte intern weiterhin den vollen Type. Erst `AnyView` löscht den Typ
  // wirklich zur Laufzeit — die Box ist fixed-size und blockiert die
  // rekursive Generic-Substitution an JEDER Naht.
  //
  // Trade-off: AnyView verliert SwiftUI-Identity (winzige Animations-
  // Glitches möglich), aber das ist der Preis dafür, dass die App nicht
  // crasht. Erst sobald wir wissen, an welcher minimalen Stelle der
  // Trigger sitzt, können wir AnyViews wieder gezielt rausnehmen.
  private func mealSection(
    _ mealType: RecipeMealType,
    title: String,
    emoji: String,
    entries sectionEntries: [NutritionEntry]
  ) -> AnyView {
    let sectionCalories = sectionEntries.reduce(0) { $0 + $1.calories }
    let isExpanded = expandedSections.contains(mealType)

    return AnyView(
      VStack(spacing: 0) {
        mealSectionHeader(
          mealType: mealType,
          title: title,
          emoji: emoji,
          sectionEntries: sectionEntries,
          sectionCalories: sectionCalories,
          isExpanded: isExpanded
        )

        if isExpanded {
          mealSectionExpanded(mealType: mealType, sectionEntries: sectionEntries)
        }
      }
      .gainsCardStyle(GainsColor.card)
    )
  }

  // MARK: - mealSection-Splits (alle AnyView-erased)

  private func mealSectionHeader(
    mealType: RecipeMealType,
    title: String,
    emoji: String,
    sectionEntries: [NutritionEntry],
    sectionCalories: Int,
    isExpanded: Bool
  ) -> AnyView {
    AnyView(_mealSectionHeader(
      mealType: mealType,
      title: title,
      emoji: emoji,
      sectionEntries: sectionEntries,
      sectionCalories: sectionCalories,
      isExpanded: isExpanded
    ))
  }

  private func _mealSectionHeader(
    mealType: RecipeMealType,
    title: String,
    emoji: String,
    sectionEntries: [NutritionEntry],
    sectionCalories: Int,
    isExpanded: Bool
  ) -> some View {
    Button {
      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        if isExpanded {
          expandedSections.remove(mealType)
        } else {
          expandedSections.insert(mealType)
        }
      }
    } label: {
      HStack(spacing: GainsSpacing.s) {
        mealEmojiPlate(emoji: emoji)
        mealHeaderTitleColumn(title: title, sectionEntries: sectionEntries)
        Spacer()
        if sectionCalories > 0 {
          mealCaloriesPill(sectionCalories: sectionCalories)
        }
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(.horizontal, GainsSpacing.m)
      .padding(.vertical, GainsSpacing.m)
    }
    .buttonStyle(.plain)
  }

  /// 2026-05-14 (Polish-Loop 82): Meal-Emoji-Plate mit Glas + Inner-Light
  /// statt flachem Elevated-Block.
  /// 2026-05-29 Polish: AnyView wieder raus — Leaf-Helper, lebt im
  /// `_mealSectionHeader`-Type-Kontext, AnyView wäre nur Heap-Overhead.
  private func mealEmojiPlate(emoji: String) -> some View {
    Text(emoji)
      .font(.system(size: 20))
      .frame(width: 40, height: 40)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(GainsColor.elevated)
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
          .strokeBorder(GainsColor.border.opacity(0.55), lineWidth: 0.6)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private func mealHeaderTitleColumn(title: String, sectionEntries: [NutritionEntry]) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(GainsFont.title(15))
        .foregroundStyle(GainsColor.ink)
      Text(mealSubline(for: sectionEntries))
        .font(GainsFont.label(11))
        .foregroundStyle(GainsColor.softInk)
    }
  }

  private func mealCaloriesPill(sectionCalories: Int) -> some View {
    HStack(spacing: GainsSpacing.xxs) {
      Text("\(sectionCalories)")
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .foregroundStyle(GainsColor.ink)
      Text("kcal")
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(GainsColor.mutedInk)
    }
    .padding(.horizontal, GainsSpacing.tight)
    .padding(.vertical, GainsSpacing.xxs)
    .background(GainsColor.elevated)
    .overlay(
      Capsule().strokeBorder(
        LinearGradient(
          colors: [GainsColor.ember.opacity(0.32), GainsColor.border.opacity(0.45)],
          startPoint: .top,
          endPoint: .bottom
        ),
        lineWidth: 0.6
      )
    )
    .clipShape(Capsule())
  }

  private func mealSectionExpanded(
    mealType: RecipeMealType,
    sectionEntries: [NutritionEntry]
  ) -> AnyView {
    AnyView(
      VStack(spacing: 0) {
        Rectangle()
          .fill(GainsColor.border.opacity(0.5))
          .frame(height: 1)
          .padding(.horizontal, GainsSpacing.m)

        if sectionEntries.isEmpty {
          mealEmptyHint
        } else {
          ForEach(sectionEntries) { entry in
            foodEntryRow(entry)
          }
        }

        mealActionBar(mealType: mealType)
      }
    )
  }

  /// 2026-05-14 (Polish-Loop 125): Empty-Line mit Lime-Plus + einladendem
  /// Mikrotext.
  private var mealEmptyHint: some View {
    HStack(spacing: GainsSpacing.tight) {
      ZStack {
        Circle()
          .fill(GainsColor.lime.opacity(0.10))
          .frame(width: 22, height: 22)
        Image(systemName: "plus")
          .font(.system(size: 10, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
          .shadow(color: GainsColor.lime.opacity(0.275), radius: 3)
      }
      Text("Noch nichts geloggt — was hast du gegessen?")
        .font(GainsFont.label(12))
        .foregroundStyle(GainsColor.softInk)
      Spacer()
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.m)
  }

  /// Action-Bar: Suche | KI-Foto | Schnell.
  private func mealActionBar(mealType: RecipeMealType) -> some View {
    HStack(spacing: 0) {
      Button {
        pendingMealType = mealType
        showsFoodSearch = true
      } label: {
        actionBarLabel(icon: "plus", text: "Hinzufügen", tint: GainsColor.moss)
      }
      .buttonStyle(.plain)

      Rectangle()
        .fill(GainsColor.border.opacity(0.5))
        .frame(width: 1)

      Button {
        pendingMealType = mealType
        showsPhotoRecognition = true
      } label: {
        actionBarLabel(icon: "camera.viewfinder", text: "KI-Foto", tint: GainsColor.lime)
      }
      .buttonStyle(.plain)

      Rectangle()
        .fill(GainsColor.border.opacity(0.5))
        .frame(width: 1)

      Button {
        quickAddInitialMeal = mealType
        showsQuickAdd = true
      } label: {
        actionBarLabel(icon: "bolt.fill", text: "Schnell", tint: GainsColor.lime)
      }
      .buttonStyle(.plain)
    }
  }

  private func mealSubline(for sectionEntries: [NutritionEntry]) -> String {
    if sectionEntries.isEmpty { return "Noch nichts geloggt" }
    let count = sectionEntries.count
    let proteinSum = sectionEntries.reduce(0) { $0 + $1.protein }
    if proteinSum > 0 {
      return "\(count) \(count == 1 ? "Eintrag" : "Einträge") · \(proteinSum) g Protein"
    }
    return "\(count) \(count == 1 ? "Eintrag" : "Einträge")"
  }

  private func actionBarLabel(icon: String, text: String, tint: Color) -> some View {
    // 2026-05-14 (Polish-Loop 118): Action-Bar-Label.
    HStack(spacing: GainsSpacing.xs) {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(tint)
        .shadow(color: tint.opacity(0.45), radius: 3)
      Text(text)
        .font(GainsFont.label(12))
        .foregroundStyle(tint)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, GainsSpacing.s)
    .background(
      ZStack {
        tint.opacity(0.06)
        LinearGradient(
          colors: [GainsColor.glassInnerLight, .clear],
          startPoint: .top,
          endPoint: .center
        )
      }
    )
  }

  @ViewBuilder
  private func foodEntryRow(_ entry: NutritionEntry) -> some View {
    // 2026-05-14 (Polish-Loop 83): Food-Entry-Row modernisiert.
    // 2026-05-29 Polish: AnyView wieder raus — Hot-Path im ForEach.
    // AnyView wäre 1 Heap-Box pro Eintrag × bis zu 50 Einträge pro Tag =
    // spürbarer Scroll-Lag. Da foodEntryRow innerhalb von
    // `mealSectionExpanded` (AnyView) lebt, ist der Type-Kontext eh
    // schon erased — der innere `some View` läuft kostenlos.
      HStack(spacing: GainsSpacing.s) {
      VStack(alignment: .leading, spacing: 4) {
        Text(entry.title)
          .font(GainsFont.body)
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        HStack(spacing: GainsSpacing.xs) {
          macroChip("P · \(entry.protein)", color: GainsColor.lime)
          macroChip("K · \(entry.carbs)", color: GainsColor.accentCool)
          macroChip("F · \(entry.fat)", color: GainsColor.macroFat)
        }
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 1) {
        Text("\(entry.calories)")
          .font(.system(size: 17, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)
          .shadow(color: GainsColor.ember.opacity(0.06), radius: 3)
        Text("kcal")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.mutedInk)
      }

      Menu {
        foodEntryActions(entry)
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 30, height: 30)
          .background(GainsColor.elevated)
          .overlay(
            Circle().strokeBorder(GainsColor.border.opacity(0.6), lineWidth: 0.6)
          )
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Mehr Optionen")
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .background(
      // 2026-05-16 (Fertiger-Audit P0-5): Letzte gerade geloggte Row bekommt
      // einen kurzen Lime-Glow-Pulse — der User sieht sofort, *welcher*
      // Eintrag eben hinzugefügt wurde. Auto-Clear via `.task(id:)` weiter
      // unten in der Section.
      ZStack {
        GainsColor.card
        if store.lastLoggedNutritionEntryID == entry.id {
          LinearGradient(
            colors: [GainsColor.lime.opacity(0.18), GainsColor.lime.opacity(0.02)],
            startPoint: .leading,
            endPoint: .trailing
          )
          .transition(.opacity)
        }
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(
          GainsColor.lime.opacity(store.lastLoggedNutritionEntryID == entry.id ? 0.55 : 0),
          lineWidth: 1
        )
        .padding(.horizontal, GainsSpacing.xxs)
    )
    .contextMenu {
      foodEntryActions(entry)
    }

    Rectangle()
      .fill(GainsColor.border.opacity(0.35))
      .frame(height: 0.5)
      .padding(.horizontal, GainsSpacing.m)
  }

  // Welle 3: Aktionen für ⋯-Menu UND Long-Press-Context-Menu auf einer
  // NutritionEntry-Row. Reihenfolge: häufigster Tap zuerst, destructive
  // unten. Einheitlich, damit Discoverability gegeben ist (wer das ⋯
  // einmal benutzt hat, weiß auch was Long-Press kann).
  @ViewBuilder
  fileprivate func foodEntryActions(_ entry: NutritionEntry) -> some View {
    Button {
      store.repeatNutritionEntry(entry, in: entry.mealType, on: Date())
      expandedSections.insert(entry.mealType)
    } label: {
      Label("Wieder loggen (heute)", systemImage: "arrow.uturn.backward")
    }

    Button {
      store.duplicateNutritionEntry(entry.id)
    } label: {
      Label("Duplizieren", systemImage: "doc.on.doc")
    }

    // 2026-05-03 Intuitivitäts-Sweep P1-22: „Anpassen" statt Löschen+Neu.
    // Öffnet ein kompaktes Sheet mit Slider für Portion + sofort sichtbare
    // Macro-Vorschau. Häufiger Pfad: „Ich hab versehentlich 200 g
    // eingegeben, war aber nur 100 g."
    Button {
      adjustingEntry = entry
    } label: {
      Label("Portion anpassen…", systemImage: "slider.horizontal.3")
    }

    Menu {
      ForEach(RecipeMealType.allCases.filter { $0 != entry.mealType }, id: \.self) { meal in
        Button {
          store.moveNutritionEntry(entry.id, to: meal)
          expandedSections.insert(meal)
        } label: {
          Label(meal.title, systemImage: meal.systemImage)
        }
      }
    } label: {
      Label("Verschieben in…", systemImage: "arrow.left.arrow.right")
    }

    Divider()

    Button(role: .destructive) {
      withAnimation { store.removeNutritionEntry(entry.id) }
    } label: {
      Label("Löschen", systemImage: "trash")
    }
  }

  private func macroChip(_ text: String, color: Color) -> some View {
    // 2026-05-14 (Polish-Loop 83): Macro-Chip jetzt mit Mono-Schrift +
    // Hairline-Edge in Akzentfarbe — liest sich konsistent zur App-
    // Mono-Sprache.
    Text(text)
      .font(.system(size: 10, weight: .medium, design: .monospaced))
      .tracking(0.4)
      .foregroundStyle(color)
      .padding(.horizontal, GainsSpacing.xsPlus)
      .padding(.vertical, 2)
      .background(color.opacity(0.10))
      .overlay(
        Capsule().strokeBorder(color.opacity(0.32), lineWidth: 0.6)
      )
      .clipShape(Capsule())
  }

  // MARK: Helpers

  private func dateLabel(_ date: Date) -> String {
    NutritionFormatters.weekdayDayMonthDE.string(from: date)
  }

  // MARK: - Welle 3: Coach-Pulse (2026-05-03)

  fileprivate enum NutritionPulseAccent { case lime, ember, cool, soft }

  fileprivate struct NutritionPulse {
    let eyebrow: String
    let headline: String
    let detail: String?
    let icon: String
    let accent: NutritionPulseAccent
  }

  fileprivate var currentNutritionPulse: NutritionPulse? {
    _ = pulseClock
    let hour = Calendar.current.component(.hour, from: Date())
    let kcalToday = store.nutritionCaloriesToday
    let kcalTarget = max(1, store.nutritionTargetCalories)
    let proteinToday = store.nutritionProteinToday
    let proteinTarget = max(1, store.nutritionTargetProtein)
    let proteinRemaining = max(proteinTarget - proteinToday, 0)
    let kcalShare = Double(kcalToday) / Double(kcalTarget)
    let proteinShare = Double(proteinToday) / Double(proteinTarget)
    let streak = store.nutritionStreakDays
    // Single-pass — entriesForDay wird 4× aufgerufen (lunchEntries + 3× isEmpty).
    let todayEntries = entriesForDay

    let lunchEntries = todayEntries.filter { $0.mealType == .lunch }.count
    if hour >= 13 && hour < 16, lunchEntries == 0, !todayEntries.isEmpty {
      return NutritionPulse(
        eyebrow: "MITTAG OFFEN",
        headline: "Mittag fehlt heute noch.",
        detail: "Recents oder Schnell-Eintrag — 30 Sekunden.",
        icon: "fork.knife",
        accent: .lime
      )
    }
    if hour >= 18, proteinShare < 0.7, proteinRemaining > 20 {
      return NutritionPulse(
        eyebrow: "PROTEIN OFFEN",
        headline: "Noch \(proteinRemaining) g Protein bis zum Ziel.",
        detail: "Quark, Skyr oder ein Shake reichen.",
        icon: "figure.strengthtraining.traditional",
        accent: .lime
      )
    }
    if hour >= 20, kcalShare < 0.6 {
      return NutritionPulse(
        eyebrow: "KCAL UNTER ZIEL",
        headline: "Heute \(kcalToday) kcal — \(kcalTarget - kcalToday) offen.",
        detail: "Wenig zu essen kann morgen kosten.",
        icon: "flame.fill",
        accent: .ember
      )
    }
    if kcalShare >= 1.1 {
      let over = kcalToday - kcalTarget
      return NutritionPulse(
        eyebrow: "KCAL ÜBER ZIEL",
        headline: "\(over) kcal über dem Tagesziel.",
        detail: "Morgen wieder im Rahmen — kein Drama.",
        icon: "exclamationmark.triangle.fill",
        accent: .ember
      )
    }
    if streak >= 3 {
      return NutritionPulse(
        eyebrow: "STREAK · \(streak) TAGE",
        headline: streakHeadline(for: streak),
        detail: streakDetail(for: streak),
        icon: "flame.fill",
        accent: .cool
      )
    }
    if !todayEntries.isEmpty, kcalShare >= 0.6, proteinShare >= 0.6 {
      return NutritionPulse(
        eyebrow: "TAG LÄUFT",
        headline: "Sauber im Rahmen.",
        detail: "\(kcalToday) kcal · \(proteinToday) g Protein bisher.",
        icon: "checkmark.seal.fill",
        accent: .soft
      )
    }
    if hour < 11, todayEntries.isEmpty {
      return NutritionPulse(
        eyebrow: "TAG STARTET",
        headline: "Frühstück fehlt — Recents oder Schnell.",
        detail: "Ein Eintrag reicht, um Streak zu sichern.",
        icon: "sun.max.fill",
        accent: .lime
      )
    }
    return nil
  }

  fileprivate func streakHeadline(for days: Int) -> String {
    switch days {
    case 3...6:   return "\(days) Tage am Stück geloggt."
    case 7...13:  return "Eine Woche — sauber durch."
    case 14...29: return "Über zwei Wochen Konstanz."
    default:      return "\(days) Tage in Folge."
    }
  }

  fileprivate func streakDetail(for days: Int) -> String {
    if days >= 30 { return "Disziplin auf Top-Niveau." }
    if days >= 14 { return "Heutiger Eintrag schützt die Streak." }
    return "Ein Eintrag heute hält sie am Leben."
  }

  fileprivate func nutritionPulseLine(_ pulse: NutritionPulse) -> AnyView {
    AnyView(_nutritionPulseLine(pulse))
  }

  fileprivate func _nutritionPulseLine(_ pulse: NutritionPulse) -> some View {
    let accentColor: Color = {
      switch pulse.accent {
      case .lime:  return GainsColor.lime
      case .ember: return GainsColor.ember
      case .cool:  return GainsColor.accentCool
      case .soft:  return GainsColor.softInk
      }
    }()

    return HStack(spacing: GainsSpacing.s) {
      // 2026-05-14 (Polish-Loop 119): Pulse-Line Icon-Plate mit echtem
      // Radial-Glow + Edge-Gradient — passt zur App-Glow-Sprache.
      ZStack {
        Circle().fill(accentColor.opacity(0.10))
        Circle()
          .fill(
            RadialGradient(
              colors: [accentColor.opacity(0.30), .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 36
            )
          )
          .blendMode(.plusLighter)
        Circle()
          .strokeBorder(
            LinearGradient(
              colors: [accentColor.opacity(0.55), accentColor.opacity(0.12)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 0.8
          )
        Image(systemName: pulse.icon)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(accentColor)
          .shadow(color: accentColor.opacity(0.45), radius: 4)
      }
      .frame(width: 36, height: 36)
      .compositingGroup()
      .shadow(color: accentColor.opacity(0.22), radius: 6)

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text(pulse.eyebrow)
          .gainsEyebrow(accentColor, size: 10, tracking: 1.4)
        Text(pulse.headline)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        if let detail = pulse.detail {
          Text(detail)
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .background(
      ZStack {
        GainsColor.card
        RadialGradient(
          colors: [accentColor.opacity(0.10), .clear],
          center: .leading,
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
            colors: [accentColor.opacity(0.32), GainsColor.border.opacity(0.45)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
    .shadow(color: accentColor.opacity(0.10), radius: 10)
  }

  // MARK: - Welle 3: Recents-Strip + Quick-Add (2026-05-03)

  fileprivate var showsRecentsStrip: Bool {
    let hasEntries = !entriesForDay.isEmpty  // single daySnapshot call
    if isInNutritionDayOneWindow && !hasEntries { return false }
    return !store.recentNutritionFoods.isEmpty || hasEntries
  }

  fileprivate var recentsStrip: AnyView {
    AnyView(_recentsStrip)
  }

  fileprivate var _recentsStrip: some View {
    let recents = store.recentNutritionFoods

    return VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      HStack(spacing: GainsSpacing.xsPlus) {
        Image(systemName: "bolt.fill")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        Text("SCHNELL LOGGEN")
          .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.4)
        Spacer()
        if !recents.isEmpty {
          Text("\(recents.count) zuletzt")
            .font(GainsFont.label(10))
            .foregroundStyle(GainsColor.mutedInk)
        }
      }
      .padding(.horizontal, GainsSpacing.l)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.tight) {
          quickAddRecentCard
          ForEach(recents) { entry in
            recentFoodCard(entry)
          }
        }
        .padding(.horizontal, GainsSpacing.l)
      }
    }
  }

  fileprivate var quickAddRecentCard: some View {
    Button {
      quickAddInitialMeal = currentMealTypeForTime()
      showsQuickAdd = true
    } label: {
      VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
        HStack(spacing: 0) {
          ZStack {
            Circle()
              .fill(GainsColor.lime.opacity(0.18))
              .frame(width: 28, height: 28)
            Image(systemName: "bolt.fill")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(GainsColor.lime)
          }
          Spacer()
        }
        Spacer(minLength: 0)
        VStack(alignment: .leading, spacing: 2) {
          Text("Schnell-Eintrag")
            .font(GainsFont.label(12))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Text("kcal in 5s")
            .font(GainsFont.label(10))
            .foregroundStyle(GainsColor.softInk)
        }
      }
      .padding(GainsSpacing.s)
      .frame(width: 124, height: 96, alignment: .topLeading)
      .background(
        LinearGradient(
          colors: [GainsColor.lime.opacity(0.08), GainsColor.card],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.accent)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  fileprivate func recentFoodCard(_ entry: NutritionEntry) -> some View {
    Button {
      let target = currentMealTypeForTime()
      withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        store.repeatNutritionEntry(entry, in: target, on: selectedDate)
        expandedSections.insert(target)
      }
    } label: {
      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        HStack(spacing: 0) {
          // 2026-05-14 (Polish-Loop 117): Meal-Icon-Plate mit Glas-
          // Look + leichtem Inner-Light, Plus-Icon mit Lime-Glow.
          ZStack {
            RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
              .fill(GainsColor.elevated)
            RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
              .fill(
                LinearGradient(
                  colors: [GainsColor.glassInnerLight, .clear],
                  startPoint: .top,
                  endPoint: .center
                )
              )
            Image(systemName: entry.mealType.systemImage)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(width: 26, height: 26)
          Spacer()
          Image(systemName: "plus")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(GainsColor.lime)
            .shadow(color: GainsColor.lime.opacity(0.275), radius: 3)
        }
        Spacer(minLength: 0)
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.title)
            .font(GainsFont.label(12))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          HStack(spacing: GainsSpacing.xxs) {
            Text("\(entry.calories)")
              .font(.system(size: 11, weight: .semibold, design: .monospaced))
              .foregroundStyle(GainsColor.ink)
            Text("kcal")
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.mutedInk)
            if entry.protein > 0 {
              Text("·")
                .font(.system(size: 10))
                .foregroundStyle(GainsColor.mutedInk)
              Text("\(entry.protein)g")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(GainsColor.lime)
              Text("P")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(GainsColor.mutedInk)
            }
          }
        }
      }
      .padding(GainsSpacing.s)
      .frame(width: 152, height: 96, alignment: .topLeading)
      .background(
        ZStack {
          GainsColor.card
          RadialGradient(
            colors: [GainsColor.lime.opacity(0.06), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 140
          )
          .blendMode(.screen)
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [GainsColor.lime.opacity(0.22), GainsColor.border.opacity(0.45)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.hairline
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .compositingGroup()
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button {
        let target = currentMealTypeForTime()
        store.repeatNutritionEntry(entry, in: target, on: selectedDate)
        expandedSections.insert(target)
      } label: {
        Label("Wieder loggen", systemImage: "arrow.uturn.backward")
      }
      Menu {
        ForEach(RecipeMealType.allCases, id: \.self) { meal in
          Button {
            store.repeatNutritionEntry(entry, in: meal, on: selectedDate)
            expandedSections.insert(meal)
          } label: {
            Label(meal.title, systemImage: meal.systemImage)
          }
        }
      } label: {
        Label("In Mahlzeit loggen…", systemImage: "fork.knife")
      }
    }
  }

  // MARK: - Welle 3: Day-Summary-Footer (2026-05-03)

  fileprivate var daySummaryFooter: AnyView {
    AnyView(_daySummaryFooter)
  }

  fileprivate var _daySummaryFooter: some View {
    let weeklyCalories = store.dailyCalories(lastDays: 7)
    let proteinRate = store.proteinHitRate(lastDays: 7)
    let streak = store.nutritionStreakDays

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["TAGESBILANZ", "DEINE WOCHE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      HStack(alignment: .top, spacing: GainsSpacing.tight) {
        summaryStatTile(
          eyebrow: "STREAK",
          value: "\(streak)",
          unit: streak == 1 ? "Tag" : "Tage",
          icon: "flame.fill",
          accent: streak >= 3 ? GainsColor.lime : GainsColor.softInk
        )
        summaryWeekSparklineTile(weeklyCalories: weeklyCalories)
        summaryStatTile(
          eyebrow: "PROTEIN",
          value: "\(Int((proteinRate * 100).rounded()))",
          unit: "% der Tage",
          icon: "checkmark.seal.fill",
          accent: proteinRate >= 0.6 ? GainsColor.lime : GainsColor.softInk
        )
      }
    }
    .padding(GainsSpacing.m)
    .background(
      // 2026-05-14 (Polish-Loop 85): daySummaryFooter mit Glas-Look +
      // dezentem Lime-Akzent-Glow im Background.
      ZStack {
        GainsColor.card
        RadialGradient(
          colors: [GainsColor.lime.opacity(0.08), .clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 220
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
            colors: [GainsColor.lime.opacity(0.22), GainsColor.border.opacity(0.45)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
  }

  fileprivate func summaryStatTile(
    eyebrow: String,
    value: String,
    unit: String,
    icon: String,
    accent: Color
  ) -> some View {
    // 2026-05-14 (Polish-Loop 121): SummaryStatTile mit Akzent-Glow im
    // Background + Icon-Glow + Mono-Hero-Numerik.
    VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: icon)
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(accent)
          .shadow(color: accent.opacity(0.45), radius: 3)
        Text(eyebrow)
          .gainsEyebrow(accent.opacity(0.85), size: 9, tracking: 1.3)
      }
      Text(value)
        .font(.system(size: 22, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(GainsColor.ink)
        .shadow(color: accent.opacity(0.18), radius: 4)
        .contentTransition(.numericText())
      Text(unit)
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(GainsColor.mutedInk)
        .lineLimit(1)
    }
    .padding(.horizontal, GainsSpacing.s)
    .padding(.vertical, GainsSpacing.tight)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      ZStack {
        GainsColor.elevated
        RadialGradient(
          colors: [accent.opacity(0.10), .clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 120
        )
        .blendMode(.screen)
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [accent.opacity(0.22), GainsColor.border.opacity(0.45)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
  }

  fileprivate func summaryWeekSparklineTile(weeklyCalories: [Int]) -> some View {
    let maxValue = max(weeklyCalories.max() ?? 1, 1)
    let target = max(store.nutritionTargetCalories, 1)
    let ceiling = max(maxValue, target)
    let symbols = Calendar.current.shortStandaloneWeekdaySymbols
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    return VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: "chart.bar.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        Text("KCAL · 7 TAGE")
          .gainsEyebrow(GainsColor.softInk, size: 9, tracking: 1.3)
      }

      HStack(alignment: .bottom, spacing: GainsSpacing.xxs) {
        ForEach(Array(weeklyCalories.enumerated()), id: \.offset) { index, kcal in
          let dayOffset = weeklyCalories.count - 1 - index
          let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
          let weekdayIdx = (calendar.component(.weekday, from: date) - 1 + 7) % 7
          // 2026-05-29 Crash-Hardening: Defensive Index-Prüfung. Bei manchen
          // Locale-/Calendar-Overrides (z.B. Hijri/Islamic) liefert
          // `shortStandaloneWeekdaySymbols` weniger als 7 Einträge — der
          // direkte Subscript war ein Crash-Kandidat (SIGABRT / Array OOB).
          let label: String = symbols.indices.contains(weekdayIdx)
            ? String(symbols[weekdayIdx].prefix(2))
            : "—"
          // 2026-05-29 Crash-Hardening: `ceiling` darf nicht 0 sein.
          // Division durch 0 → +Inf, multipliziert mit 38 bleibt +Inf,
          // .frame(height: +Inf) ist eine SwiftUI/Metal-Bombe.
          let safeCeiling: Double = max(Double(ceiling), 1)
          let rawHeight: Double = (Double(kcal) / safeCeiling) * 38
          let height: CGFloat = CGFloat(max(4, rawHeight.isFinite ? rawHeight : 4))
          let isOver = kcal > target
          let isTodayBar = dayOffset == 0

          VStack(spacing: GainsSpacing.xxs) {
            // 2026-05-14 (Polish-Loop 122): Sparkline-Bars mit Gradient
            // + Glow, today-Bar zusätzlich mit Top-Highlight.
            let barColor: Color = kcal == 0
              ? GainsColor.border.opacity(0.4)
              : (isOver ? GainsColor.ember : GainsColor.lime)
            RoundedRectangle(cornerRadius: 3)
              .fill(
                LinearGradient(
                  colors: kcal == 0
                    ? [barColor, barColor]
                    : [barColor.opacity(0.85), barColor],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .frame(height: height)
              .shadow(color: kcal == 0 ? .clear : barColor.opacity(0.45), radius: 3)
            Text(label)
              .font(.system(size: 8, weight: isTodayBar ? .bold : .medium))
              .foregroundStyle(isTodayBar ? GainsColor.ink : GainsColor.mutedInk)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 50)
    }
    .padding(.horizontal, GainsSpacing.s)
    .padding(.vertical, GainsSpacing.tight)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      ZStack {
        GainsColor.elevated
        RadialGradient(
          colors: [GainsColor.lime.opacity(0.08), .clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 120
        )
        .blendMode(.screen)
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [GainsColor.lime.opacity(0.22), GainsColor.border.opacity(0.45)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
  }
}

// MARK: - Quick-Add Nutrition Sheet (Welle 3 — 2026-05-03)
//
// Mini-Sheet für „kcal in 5 Sekunden" — wenn der User die Lebensmittel-Suche
// nicht aufmachen will (z. B. unbekanntes Restaurant-Gericht, schätzt Werte).
// Nur kcal sind Pflicht, Makros optional. Mahlzeit kommt vorausgewählt aus
// der Tageszeit-Heuristik, kann aber im Sheet überschrieben werden.

struct QuickAddNutritionSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  let initialMealType: RecipeMealType
  let selectedDate: Date

  @State private var title: String = ""
  @State private var caloriesText: String = ""
  @State private var proteinText: String = ""
  @State private var carbsText: String = ""
  @State private var fatText: String = ""
  @State private var mealType: RecipeMealType = .snack

  private var caloriesValue: Int {
    Int(caloriesText.trimmingCharacters(in: .whitespaces)) ?? 0
  }
  private var canSave: Bool { caloriesValue > 0 }

  var body: some View {
    NavigationStack {
      ZStack {
        GainsAppBackground()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: GainsSpacing.l) {
            heroPreview
            mealPicker
            macroFields
            Spacer(minLength: 12)
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.s)
          .padding(.bottom, GainsSpacing.xl)
        }
      }
      .navigationTitle("Schnell-Eintrag")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            store.quickAddNutrition(
              calories: caloriesValue,
              protein: Int(proteinText) ?? 0,
              carbs: Int(carbsText) ?? 0,
              fat: Int(fatText) ?? 0,
              mealType: mealType,
              title: title,
              on: selectedDate
            )
            dismiss()
          } label: {
            Text("Loggen")
              .font(GainsFont.label(14))
              .foregroundStyle(canSave ? GainsColor.lime : GainsColor.mutedInk)
          }
          .disabled(!canSave)
        }
      }
      .onAppear { mealType = initialMealType }
    }
    .presentationDetents([.medium, .large])
  }

  private var heroPreview: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Text("KCAL")
        .gainsEyebrow(GainsColor.lime, size: 11, tracking: 1.4)

      HStack(alignment: .firstTextBaseline, spacing: GainsSpacing.xs) {
        TextField("0", text: $caloriesText)
          .keyboardType(.numberPad)
          .font(.system(size: 44, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: 140, alignment: .leading)
        Text("kcal")
          .font(GainsFont.label(13))
          .foregroundStyle(GainsColor.softInk)
        Spacer()
      }

      TextField("Titel (optional)", text: $title)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.ink)
        .padding(.horizontal, GainsSpacing.s)
        .frame(height: 40)
        .background(GainsColor.elevated)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle(GainsColor.card)
  }

  private var mealPicker: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text("MAHLZEIT")
        .gainsEyebrow(GainsColor.softInk, size: 11, tracking: 1.4)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.xsPlus) {
          ForEach(RecipeMealType.allCases, id: \.self) { type in
            Button {
              withAnimation(.spring(response: 0.25)) { mealType = type }
            } label: {
              HStack(spacing: GainsSpacing.xs) {
                Image(systemName: type.systemImage)
                  .font(.system(size: 11, weight: .semibold))
                Text(type.title)
                  .font(GainsFont.label(12))
              }
              .foregroundStyle(mealType == type ? GainsColor.onLime : GainsColor.softInk)
              .padding(.horizontal, GainsSpacing.m)
              .padding(.vertical, GainsSpacing.xsPlus)
              .background(mealType == type ? GainsColor.lime : GainsColor.elevated)
              .clipShape(Capsule())
              .overlay(
                Capsule().stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
              )
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var macroFields: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text("MAKROS · OPTIONAL")
        .gainsEyebrow(GainsColor.softInk, size: 11, tracking: 1.4)
      HStack(spacing: GainsSpacing.xsPlus) {
        macroField("Protein", text: $proteinText, color: GainsColor.lime)
        macroField("Kohlenh.", text: $carbsText, color: GainsColor.accentCool)
        macroField("Fett", text: $fatText, color: GainsColor.macroFat)
      }
    }
  }

  // Polish-Loop 199 (2026-05-14): Macro-Field mit Akzent-Dot + Mono-
  // Eingabe + Glas-Komposition + Hairline-Gradient. Reflektiert
  // KPI-Strip-Sprache aus dem Nutrition-Tracker.
  private func macroField(_ label: String, text: Binding<String>, color: Color) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
      HStack(spacing: 4) {
        Circle()
          .fill(color)
          .frame(width: 4, height: 4)
          .shadow(color: color.opacity(0.55), radius: 2)
        Text(label.uppercased())
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
      }
      HStack(spacing: GainsSpacing.xxs) {
        TextField("0", text: text)
          .keyboardType(.numberPad)
          .font(.system(size: 16, weight: .semibold, design: .monospaced))
          .foregroundStyle(GainsColor.ink)
          .multilineTextAlignment(.leading)
        Text("g")
          .font(GainsFont.label(11))
          .foregroundStyle(GainsColor.mutedInk)
      }
      .padding(.horizontal, GainsSpacing.s)
      .padding(.vertical, GainsSpacing.tight)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(GainsColor.elevated)
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
              colors: [color.opacity(0.35), color.opacity(0.10)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.hairline
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      .compositingGroup()
    }
  }
}

// MARK: - Adjust Nutrition Entry Sheet
//
// 2026-05-03 Intuitivitäts-Sweep P1-22: Eintrag nachträglich anpassen statt
// löschen+neu eintragen. Slider skaliert alle Macros + kcal proportional —
// häufigster Use-Case („hab versehentlich 200g eingegeben, war aber 100g")
// ist damit ein 2-Tap-Flow.

private struct AdjustNutritionEntrySheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  let entry: NutritionEntry

  @State private var factor: Double = 1.0

  private var scaledCalories: Int { max(0, Int((Double(entry.calories) * factor).rounded())) }
  private var scaledProtein: Int { max(0, Int((Double(entry.protein) * factor).rounded())) }
  private var scaledCarbs: Int { max(0, Int((Double(entry.carbs) * factor).rounded())) }
  private var scaledFat: Int { max(0, Int((Double(entry.fat) * factor).rounded())) }
  private var percentLabel: String { "\(Int((factor * 100).rounded())) %" }

  var body: some View {
    NavigationStack {
      ZStack {
        GainsAppBackground()
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: GainsSpacing.l) {
            header
            preview
            sliderCard
            presetRow
            Spacer(minLength: 12)
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.s)
          .padding(.bottom, GainsSpacing.xl)
        }
      }
      .navigationTitle("Portion anpassen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            store.updateNutritionEntry(
              entry.id,
              calories: scaledCalories,
              protein: scaledProtein,
              carbs: scaledCarbs,
              fat: scaledFat
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
          } label: {
            Text("Anwenden")
              .font(GainsFont.label(13))
              .tracking(1.4)
          }
          .disabled(abs(factor - 1.0) < 0.01)
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      Text(entry.title)
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
      Text("Schiebe den Regler, um die Portion proportional zu skalieren.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var preview: some View {
    VStack(spacing: GainsSpacing.s) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("\(scaledCalories)")
          .font(.system(size: 42, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.lime)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.4), value: scaledCalories)
        Text("kcal")
          .font(GainsFont.label(12))
          .foregroundStyle(GainsColor.mutedInk)
      }
      HStack(spacing: GainsSpacing.l) {
        macroPill(label: "P", value: scaledProtein, color: GainsColor.lime)
        macroPill(label: "K", value: scaledCarbs, color: GainsColor.accentCool)
        macroPill(label: "F", value: scaledFat, color: GainsColor.macroFat)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, GainsSpacing.l)
    .gainsCardStyle(GainsColor.card)
  }

  private func macroPill(label: String, value: Int, color: Color) -> some View {
    HStack(spacing: 4) {
      Text(label)
        .font(GainsFont.label(11))
        .foregroundStyle(color)
      Text("\(value)g")
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(GainsColor.ink)
        .contentTransition(.numericText())
    }
  }

  // Polish-Loop 195 (2026-05-14): Quantity-Slider-Card mit Glas-
  // Komposition + Hairline-Gradient + plusLighter Inner-Light.
  private var sliderCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack {
        Text("FAKTOR")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.mutedInk)
        Spacer()
        Text(percentLabel)
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundStyle(GainsColor.ink)
          .contentTransition(.numericText())
      }
      Slider(value: $factor, in: 0.25...3.0, step: 0.05)
        .tint(GainsColor.lime)
    }
    .padding(GainsSpacing.m)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(GainsColor.elevated)
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
            colors: [GainsColor.border.opacity(0.60), GainsColor.border.opacity(0.25)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
  }

  // Polish-Loop 196 (2026-05-14): Preset-Row mit Inner-Light + Bottom-
  // Dim + Lime-Glow auf aktiver Preset-Pille.
  private var presetRow: some View {
    HStack(spacing: GainsSpacing.tight) {
      ForEach([0.5, 0.75, 1.0, 1.5, 2.0], id: \.self) { value in
        let isActive = abs(factor - value) < 0.01
        Button {
          withAnimation(.spring(response: 0.3)) { factor = value }
          UISelectionFeedbackGenerator().selectionChanged()
        } label: {
          Text("\(Int(value * 100))%")
            .font(GainsFont.label(11))
            .tracking(1.0)
            .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.softInk)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
              ZStack {
                RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
                  .fill(isActive ? GainsColor.lime : GainsColor.elevated)
                if isActive {
                  RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
                    .fill(
                      LinearGradient(
                        colors: [Color.white.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .center
                      )
                    )
                    .blendMode(.plusLighter)
                  RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
                    .fill(
                      LinearGradient(
                        colors: [.clear, Color.black.opacity(0.14)],
                        startPoint: .center,
                        endPoint: .bottom
                      )
                    )
                }
              }
            )
            .overlay(
              RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
                .strokeBorder(
                  isActive ? Color.clear : GainsColor.border.opacity(0.40),
                  lineWidth: GainsBorder.hairline
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous))
            .compositingGroup()
            .shadow(color: isActive ? GainsColor.lime.opacity(0.30) : .clear, radius: 5)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

// MARK: - Goal Picker Sheet

private struct GoalPickerSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        VStack(alignment: .leading, spacing: 0) {
          VStack(alignment: .leading, spacing: GainsSpacing.xs) {
            Text("Ernährungsziel")
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)
            Text("Wähle dein Ziel — die Kalorie- und Makroziele passen sich automatisch an.")
              .font(GainsFont.body(14))
              .foregroundStyle(GainsColor.softInk)
          }
          .padding(.horizontal, GainsSpacing.xl)
          .padding(.top, GainsSpacing.xl)
          .padding(.bottom, GainsSpacing.l)

          VStack(spacing: GainsSpacing.s) {
            ForEach(NutritionGoal.allCases, id: \.self) { goal in
              goalCard(goal)
            }
          }
          .padding(.horizontal, GainsSpacing.l)

          Spacer()
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Fertig") { dismiss() }
            .font(GainsFont.label(14))
            .foregroundStyle(GainsColor.lime)
        }
      }
    }
    .presentationDetents([.medium])
  }

  private func goalCard(_ goal: NutritionGoal) -> some View {
    let isSelected = store.nutritionGoal == goal
    return Button {
      withAnimation(.spring(response: 0.3)) {
        store.setNutritionGoal(goal)
      }
    } label: {
      // Polish-Loop 178 (2026-05-14): Goal-Card mit Icon-Halo + Inner-
      // Light auf selected + LinearGradient-Border + Lime-Glow.
      HStack(spacing: GainsSpacing.m) {
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(isSelected ? GainsColor.lime.opacity(0.20) : GainsColor.elevated)
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(
              LinearGradient(
                colors: [Color.white.opacity(isSelected ? 0.14 : 0.06), .clear],
                startPoint: .top,
                endPoint: .center
              )
            )
            .blendMode(.plusLighter)
          Image(systemName: goal.systemImage)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.softInk)
            .shadow(color: isSelected ? GainsColor.lime.opacity(0.45) : .clear, radius: 3)
        }
        .frame(width: 48, height: 48)
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .strokeBorder(
              isSelected ? GainsColor.lime.opacity(0.40) : GainsColor.border.opacity(0.35),
              lineWidth: GainsBorder.hairline
            )
        )

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(goal.title)
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
          Text(goal.detail)
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 22))
            .foregroundStyle(GainsColor.lime)
            .shadow(color: GainsColor.lime.opacity(0.225), radius: 4)
        }
      }
      .padding(GainsSpacing.m)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .fill(isSelected ? GainsColor.lime.opacity(0.08) : GainsColor.card)
          if isSelected {
            RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
              .fill(
                RadialGradient(
                  colors: [GainsColor.lime.opacity(0.10), .clear],
                  center: .topLeading,
                  startRadius: 0,
                  endRadius: 180
                )
              )
              .blendMode(.plusLighter)
          }
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: isSelected
                ? [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.18)]
                : [GainsColor.border.opacity(0.55), GainsColor.border.opacity(0.30)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: isSelected ? GainsBorder.accent : GainsBorder.hairline
          )
      )
      .compositingGroup()
      .shadow(color: isSelected ? GainsColor.lime.opacity(0.18) : .clear, radius: 10)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Nutrition Quick Goal Sheet
//
// 2026-05-03 Intuitivitäts-Sweep P0 E: Schnell-Anpassung der Tagesziele
// ohne den 9-Step-Wizard. User mit „2000 → 1900 kcal"-Wunsch zog sich
// vorher durch Alter/Geschlecht/Aktivität — jetzt Slider, Preview und
// Anwenden in einem Sheet.

private struct NutritionQuickGoalSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  @State private var surplus: Double = 0
  @State private var goal: NutritionGoal = .maintain
  @State private var didLoad = false

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()
        ScrollView {
          VStack(alignment: .leading, spacing: GainsSpacing.l) {
            VStack(alignment: .leading, spacing: GainsSpacing.xs) {
              Text("ZIEL ANPASSEN")
                .gainsEyebrow(GainsColor.moss, size: 11, tracking: 1.6)
              Text("Schnell-Adjustment ohne Profil neu zu berechnen.")
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }

            previewCard

            goalPicker

            surplusSlider

            Text("Tipp: Long-Press auf 'Ziel anpassen' öffnet die volle Profil-Berechnung (Alter/Größe/Aktivität).")
              .font(GainsFont.body(11))
              .foregroundStyle(GainsColor.mutedInk)
              .padding(.top, GainsSpacing.xs)
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.l)
          .padding(.bottom, GainsSpacing.xl)
        }
      }
      .navigationTitle("Ziel anpassen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Anwenden") {
            applyChanges()
            dismiss()
          }
          .foregroundStyle(GainsColor.lime)
          .fontWeight(.semibold)
        }
      }
    }
    .onAppear {
      guard !didLoad else { return }
      didLoad = true
      goal = store.nutritionGoal
      surplus = Double(store.nutritionProfile?.surplusKcal ?? 0)
    }
    .presentationDetents([.medium, .large])
  }

  private var previewCard: some View {
    let projected = projectedTargets()
    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Text("VORSCHAU")
        .gainsEyebrow(GainsColor.lime, size: 10, tracking: 1.6)
      HStack(alignment: .lastTextBaseline, spacing: GainsSpacing.xsPlus) {
        Text("\(projected.calories)")
          .font(.system(size: 36, weight: .heavy, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        Text("kcal")
          .font(GainsFont.label(13))
          .foregroundStyle(GainsColor.softInk)
      }
      HStack(spacing: GainsSpacing.m) {
        macroBadge("Protein", value: "\(projected.protein) g")
        macroBadge("Kohlenh.", value: "\(projected.carbs) g")
        macroBadge("Fett", value: "\(projected.fat) g")
      }
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle(GainsColor.card)
  }

  private func macroBadge(_ label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label.uppercased())
        .font(GainsFont.label(9))
        .tracking(GainsTracking.eyebrowTight)
        .foregroundStyle(GainsColor.mutedInk)
      Text(value)
        .font(GainsFont.label(13))
        .foregroundStyle(GainsColor.ink)
    }
  }

  private var goalPicker: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Text("MODUS")
        .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.6)
      HStack(spacing: GainsSpacing.xs) {
        ForEach(NutritionGoal.allCases, id: \.self) { g in
          Button { goal = g } label: {
            Text(g.title)
              .font(GainsFont.label(12))
              .foregroundStyle(goal == g ? GainsColor.onLime : GainsColor.softInk)
              .padding(.horizontal, GainsSpacing.s)
              .frame(height: 36)
              .frame(maxWidth: .infinity)
              .background(goal == g ? GainsColor.lime : GainsColor.card)
              .clipShape(Capsule())
              .overlay(
                Capsule().stroke(
                  goal == g ? Color.clear : GainsColor.border.opacity(0.5),
                  lineWidth: GainsBorder.hairline
                )
              )
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var surplusSlider: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      HStack {
        Text("KCAL ANPASSUNG")
          .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.6)
        Spacer()
        Text(surplusLabel)
          .font(GainsFont.label(12))
          .foregroundStyle(GainsColor.ink)
      }
      Slider(value: $surplus, in: -1000...1000, step: 50)
        .tint(GainsColor.lime)
      HStack {
        Text("−1000")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.mutedInk)
        Spacer()
        Text("+1000")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.mutedInk)
      }
    }
  }

  private var surplusLabel: String {
    let intVal = Int(surplus.rounded())
    if intVal > 0 { return "+\(intVal) kcal · Surplus" }
    if intVal < 0 { return "\(intVal) kcal · Defizit" }
    return "0 kcal · Erhaltung"
  }

  /// Berechnet die voraussichtlichen Targets — entweder aus dem aktuellen
  /// `nutritionProfile` (mit angepasstem `surplusKcal` und neuem `goal`)
  /// oder aus dem Default-Goal-Mapping wenn noch kein Profil existiert.
  private func projectedTargets() -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
    if var profile = store.nutritionProfile {
      profile.surplusKcal = Int(surplus.rounded())
      profile.goal = goal
      return (profile.targetCalories, profile.targetProteinG, profile.targetCarbsG, profile.targetFatG)
    }
    // Fallback: nur Goal-basiertes Default
    let defaults = defaultsForGoal(goal)
    return defaults
  }

  private func defaultsForGoal(_ goal: NutritionGoal) -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
    switch goal {
    case .muscleGain: return (2850, 200, 310, 85)
    case .fatLoss:    return (2150, 190, 190, 65)
    case .maintain:   return (2450, 175, 250, 75)
    }
  }

  private func applyChanges() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    if var profile = store.nutritionProfile {
      profile.surplusKcal = Int(surplus.rounded())
      profile.goal = goal
      store.setNutritionProfile(profile)
    } else {
      // Kein Profil → nur Goal anpassen (Defaults greifen).
      store.setNutritionGoal(goal)
    }
  }
}

// MARK: - Food Search Sheet

struct FoodSearchSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss
  @Binding var mealType: RecipeMealType
  let selectedDate: Date
  // N2-Fix (2026-05-01): Statt Photo-/Barcode-Sheet INNERHALB von
  // FoodSearchSheet zu öffnen (Sheet auf Sheet → Stacking, Swipe-down
  // schließt beide), reicht FoodSearchSheet die Anfrage über diese
  // Callbacks an den Parent weiter. Der Parent dismissed FoodSearch und
  // öffnet anschließend das Foto-/Barcode-Sheet auf eigener Ebene.
  var onRequestPhotoRecognition: (() -> Void)? = nil
  var onRequestBarcodeScan: (() -> Void)? = nil

  @State private var searchText = ""
  @State private var selectedCategory: FoodCategory?
  @State private var selectedFood: FoodItem?
  @State private var showsAddSheet = false
  @State private var showsBarcodeScanner = false
  @State private var showsPhotoRecognition = false

  private var filteredFoods: [FoodItem] {
    let all = FoodItem.database
    let byCategory = selectedCategory == nil ? all : all.filter { $0.category == selectedCategory }
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      return byCategory
    }
    // Suche tokenweise — z. B. "barilla spaghetti" oder "ja mozzarella" findet beide Treffer.
    let tokens = trimmed
      .split(whereSeparator: { $0.isWhitespace })
      .map(String.init)
    return byCategory.filter { food in
      tokens.allSatisfy { food.matches($0) }
    }
  }

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        VStack(spacing: 0) {
          // Meal type picker
          mealTypePicker
            .padding(.top, GainsSpacing.xxs)
            .padding(.bottom, GainsSpacing.xsPlus)

          // Quick-scan buttons
          // N2-Fix (2026-05-01): Wenn der Parent Callbacks gesetzt hat,
          // wird FoodSearchSheet zuerst dismissed und der Parent
          // präsentiert das Ziel-Sheet. So entsteht kein Sheet-Stack.
          HStack(spacing: GainsSpacing.tight) {
            scanActionButton(
              icon: "barcode.viewfinder",
              label: "Barcode scannen",
              color: GainsColor.accentCool
            ) {
              selectedFood = nil
              if let onRequestBarcodeScan {
                dismiss()
                onRequestBarcodeScan()
              } else {
                showsPhotoRecognition = false
                showsBarcodeScanner = true
              }
            }

            scanActionButton(
              icon: "camera.viewfinder",
              label: "KI-Fotoerkennung",
              color: GainsColor.lime
            ) {
              selectedFood = nil
              if let onRequestPhotoRecognition {
                dismiss()
                onRequestPhotoRecognition()
              } else {
                showsBarcodeScanner = false
                showsPhotoRecognition = true
              }
            }
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.bottom, GainsSpacing.s)

          // Search bar
          searchBar
            .padding(.horizontal, GainsSpacing.l)
            .padding(.bottom, GainsSpacing.s)

          // Category chips
          categoryChips
            .padding(.bottom, GainsSpacing.xsPlus)

          foodList
        }
      }
      .navigationTitle("Lebensmittel suchen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
      }
      .sheet(item: $selectedFood) { food in
        FoodAddSheet(
          food: food,
          mealType: $mealType,
          selectedDate: selectedDate,
          onLog: { dismiss() }
        )
        .environmentObject(store)
      }
      .sheet(isPresented: $showsBarcodeScanner) {
        BarcodeScannerSheet(mealType: mealType, selectedDate: selectedDate, onLog: { dismiss() })
          .environmentObject(store)
      }
      .sheet(isPresented: $showsPhotoRecognition) {
        FoodPhotoRecognitionSheet(mealType: mealType, selectedDate: selectedDate, onLog: { dismiss() })
          .environmentObject(store)
      }
    }
  }

  private var foodList: some View {
    let foods = filteredFoods
    return ScrollView(showsIndicators: false) {
      LazyVStack(spacing: 0) {
        ForEach(foods) { food in
          foodRow(food)
        }

        if foods.isEmpty {
          emptySearchState
            .padding(.top, 60)
        }

        // Manual entry option
        manualEntryFooter
          .padding(.top, GainsSpacing.m)
          .padding(.bottom, GainsSpacing.xl)
      }
      .padding(.horizontal, GainsSpacing.l)
    }
  }

  private var mealTypePicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: GainsSpacing.xsPlus) {
        ForEach(RecipeMealType.allCases, id: \.self) { type in
          Button {
            withAnimation(.spring(response: 0.25)) {
              mealType = type
            }
          } label: {
            Text(type.title)
              .font(GainsFont.label(12))
              .foregroundStyle(mealType == type ? GainsColor.onLime : GainsColor.softInk)
              .padding(.horizontal, GainsSpacing.m)
              .padding(.vertical, GainsSpacing.xsPlus)
              .background(mealType == type ? GainsColor.lime : GainsColor.elevated)
              .clipShape(Capsule())
              .overlay(Capsule().stroke(GainsColor.border.opacity(0.5), lineWidth: 1))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, GainsSpacing.l)
    }
  }

  // Polish-Loop 175 (2026-05-14): FoodSearchSheet Search-Bar mit Glas-
  // Komposition + Hairline-Gradient — analog zum bereits polierten
  // GymWorkoutsTab Search-Bar.
  private var searchBar: some View {
    HStack(spacing: GainsSpacing.tight) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(GainsColor.mutedInk)

      TextField("Lebensmittel suchen…", text: $searchText)
        .font(GainsFont.body(15))
        .foregroundStyle(GainsColor.ink)
        .autocorrectionDisabled()

      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(GainsColor.mutedInk)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, GainsSpacing.m)
    .frame(height: 44)
    .background(
      ZStack {
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(GainsColor.glassUndertone)
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(.ultraThinMaterial)
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .fill(GainsColor.elevated.opacity(0.55))
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
            colors: [GainsColor.border.opacity(0.80), GainsColor.border.opacity(0.30)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
  }

  private var categoryChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: GainsSpacing.xsPlus) {
        categoryChip(nil, label: "Alle")
        ForEach(FoodCategory.allCases) { cat in
          categoryChip(cat, label: cat.title)
        }
      }
      .padding(.horizontal, GainsSpacing.l)
    }
  }

  // Polish-Loop 174 (2026-05-14): Scan-Action-Button mit Icon-Halo +
  // plusLighter Inner-Light + Hairline-Gradient + Akzent-Glow statt
  // flacher 0.08-Opacity-Wash. Premium-Affordance für Barcode/KI-Foto.
  private func scanActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: GainsSpacing.xsPlus) {
        ZStack {
          Circle().fill(color.opacity(0.18))
          Circle()
            .fill(
              LinearGradient(
                colors: [Color.white.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .center
              )
            )
            .blendMode(.plusLighter)
          Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.45), radius: 3)
        }
        .frame(width: 26, height: 26)
        .overlay(
          Circle().strokeBorder(color.opacity(0.40), lineWidth: GainsBorder.hairline)
        )
        Text(label)
          .font(GainsFont.label(13))
          .foregroundStyle(GainsColor.ink)
        Spacer()
      }
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 44)
      .frame(maxWidth: .infinity)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(color.opacity(0.10))
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
              colors: [color.opacity(0.50), color.opacity(0.15)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.hairline
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      .compositingGroup()
      .shadow(color: color.opacity(0.15), radius: 6)
    }
    .buttonStyle(.plain)
  }

  private func categoryChip(_ category: FoodCategory?, label: String) -> some View {
    let isSelected = selectedCategory == category
    // Polish-Loop 176 (2026-05-14): Category-Chip mit plusLighter Inner-
    // Light + Lime-Glow auf selektierter Pille.
    return Button {
      withAnimation(.spring(response: 0.25)) {
        selectedCategory = category
      }
    } label: {
      Text(label)
        .font(GainsFont.label(11))
        .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.mutedInk)
        .padding(.horizontal, GainsSpacing.s)
        .padding(.vertical, GainsSpacing.xs)
        .background(
          ZStack {
            Capsule().fill(isSelected ? GainsColor.lime.opacity(0.18) : GainsColor.card)
            if isSelected {
              Capsule()
                .fill(
                  LinearGradient(
                    colors: [GainsColor.glassInnerLight, .clear],
                    startPoint: .top,
                    endPoint: .center
                  )
                )
            }
          }
        )
        .clipShape(Capsule())
        .overlay(
          Capsule().strokeBorder(
            isSelected ? GainsColor.lime.opacity(0.45) : GainsColor.border.opacity(0.40),
            lineWidth: GainsBorder.hairline
          )
        )
        .compositingGroup()
        .shadow(color: isSelected ? GainsColor.lime.opacity(0.20) : .clear, radius: 5)
    }
    .buttonStyle(.plain)
  }

  // Polish-Loop 177 (2026-05-14): Emoji-Tile mit Inner-Light statt
  // flachem GainsColor.elevated — gibt jeder Food-Row visuelle Tiefe.
  @ViewBuilder
  private func foodRow(_ food: FoodItem) -> some View {
    Button {
      selectedFood = food
    } label: {
      HStack(spacing: GainsSpacing.m) {
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(GainsColor.elevated)
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .fill(
              LinearGradient(
                colors: [GainsColor.glassInnerLight, .clear],
                startPoint: .top,
                endPoint: .center
              )
            )
          Text(food.emoji)
            .font(.system(size: 26))
        }
        .frame(width: 46, height: 46)
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .strokeBorder(GainsColor.border.opacity(0.40), lineWidth: GainsBorder.hairline)
        )
        .compositingGroup()

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          HStack(spacing: GainsSpacing.xs) {
            Text(food.name)
              .font(GainsFont.label(14))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            if let brand = food.brand, !brand.isEmpty {
              Text(brand)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(GainsColor.moss)
                .padding(.horizontal, GainsSpacing.xs)
                .padding(.vertical, 2)
                .background(GainsColor.lime.opacity(0.18))
                .clipShape(Capsule())
                .lineLimit(1)
            }
          }
          HStack(spacing: GainsSpacing.xsPlus) {
            Text("\(food.caloriesPer100g) kcal")
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(GainsColor.softInk)
            Text("pro 100g")
              .font(GainsFont.label(10))
              .foregroundStyle(GainsColor.mutedInk)
            Spacer()
            Text("P \(Int(food.proteinPer100g))g")
              .font(GainsFont.label(10))
              .foregroundStyle(GainsColor.lime)
            Text("K \(Int(food.carbsPer100g))g")
              .font(GainsFont.label(10))
              .foregroundStyle(GainsColor.accentCool)
            Text("F \(Int(food.fatPer100g))g")
              .font(GainsFont.label(10))
              .foregroundStyle(GainsColor.macroFat)
          }
        }

        Image(systemName: "plus.circle.fill")
          .font(.system(size: 24))
          .foregroundStyle(GainsColor.lime)
      }
      .padding(.vertical, GainsSpacing.s)
    }
    .buttonStyle(.plain)

    Rectangle()
      .fill(GainsColor.border.opacity(0.4))
      .frame(height: 1)
  }

  private var emptySearchState: some View {
    VStack(spacing: GainsSpacing.s) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 36, weight: .light))
        .foregroundStyle(GainsColor.border)
      Text("Kein Ergebnis für '\(searchText)'")
        .font(GainsFont.label(14))
        .foregroundStyle(GainsColor.mutedInk)
        .multilineTextAlignment(.center)
    }
  }

  private var manualEntryFooter: some View {
    NavigationLink {
      ManualFoodEntryView(defaultMealType: mealType, onLog: { dismiss() })
        .environmentObject(store)
    } label: {
      HStack(spacing: GainsSpacing.tight) {
        Image(systemName: "pencil.circle.fill")
          .font(.system(size: 20))
          .foregroundStyle(GainsColor.softInk)
        Text("Eigene Mahlzeit manuell eingeben")
          .font(GainsFont.label(13))
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(GainsColor.mutedInk)
      }
      .padding(GainsSpacing.m)
      .background(GainsColor.elevated)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Food Add Sheet

struct FoodAddSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  let food: FoodItem
  @Binding var mealType: RecipeMealType
  let selectedDate: Date
  let onLog: () -> Void

  @State private var grams: Double = 100
  @State private var gramsText: String = "100"
  @FocusState private var gramsFocused: Bool

  private var nutrition: (calories: Int, protein: Int, carbs: Int, fat: Int) {
    food.nutrition(for: grams)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(spacing: GainsSpacing.l) {

            // Food header
            HStack(spacing: GainsSpacing.m) {
              Text(food.emoji)
                .font(.system(size: 40))
                .frame(width: 72, height: 72)
                .background(GainsColor.elevated)
                .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))

              VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
                Text(food.name)
                  .font(GainsFont.title(20))
                  .foregroundStyle(GainsColor.ink)
                if let brand = food.brand, !brand.isEmpty {
                  Text(brand)
                    .font(GainsFont.label(11))
                    .foregroundStyle(GainsColor.moss)
                    .padding(.horizontal, GainsSpacing.tight)
                    .padding(.vertical, GainsSpacing.xxs)
                    .background(GainsColor.lime.opacity(0.18))
                    .clipShape(Capsule())
                }
                Text(food.category.title)
                  .font(GainsFont.label(11))
                  .foregroundStyle(GainsColor.mutedInk)
                  .padding(.horizontal, GainsSpacing.tight)
                  .padding(.vertical, GainsSpacing.xxs)
                  .background(GainsColor.elevated)
                  .clipShape(Capsule())
              }
              Spacer()
            }
            .padding(GainsSpacing.l)
            .gainsCardStyle(GainsColor.card)

            // Gram input
            VStack(alignment: .leading, spacing: GainsSpacing.m) {
              Text("Menge")
                .font(GainsFont.label(13))
                .foregroundStyle(GainsColor.softInk)

              // Slider
              VStack(spacing: GainsSpacing.tight) {
                HStack {
                  Text("10g")
                    .font(GainsFont.label(10))
                    .foregroundStyle(GainsColor.mutedInk)
                  Spacer()
                  Text("500g")
                    .font(GainsFont.label(10))
                    .foregroundStyle(GainsColor.mutedInk)
                }

                Slider(value: $grams, in: 10...500, step: 5) { _ in
                  gramsText = "\(Int(grams))"
                }
                .accentColor(GainsColor.lime)
                .onChange(of: grams) { _, new in
                  gramsText = "\(Int(new))"
                }
              }

              // Manual gram input
              HStack {
                TextField("Gramm", text: $gramsText)
                  .keyboardType(.numberPad)
                  .focused($gramsFocused)
                  .font(.system(size: 28, weight: .bold, design: .rounded))
                  .foregroundStyle(GainsColor.ink)
                  .multilineTextAlignment(.center)
                  .frame(width: 90)
                  .onChange(of: gramsText) { _, new in
                    if let val = Double(new), val >= 1, val <= 2000 {
                      grams = val
                    }
                  }

                Text("g")
                  .font(GainsFont.title(22))
                  .foregroundStyle(GainsColor.mutedInk)
              }
              .frame(maxWidth: .infinity)

              // Quick amounts
              HStack(spacing: GainsSpacing.tight) {
                ForEach([50, 100, 150, 200, 300], id: \.self) { amount in
                  Button {
                    withAnimation(.spring(response: 0.3)) {
                      grams = Double(amount)
                      gramsText = "\(amount)"
                    }
                  } label: {
                    Text("\(amount)g")
                      .font(GainsFont.label(12))
                      .foregroundStyle(Int(grams) == amount ? GainsColor.moss : GainsColor.softInk)
                      .padding(.horizontal, GainsSpacing.s)
                      .padding(.vertical, GainsSpacing.xsPlus)
                      .background(Int(grams) == amount ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
                      .clipShape(Capsule())
                      .overlay(Capsule().stroke(Int(grams) == amount ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.4), lineWidth: 1))
                  }
                  .buttonStyle(.plain)
                }
              }
            }
            .padding(GainsSpacing.l)
            .gainsCardStyle(GainsColor.card)

            // Nutrition preview
            nutritionPreview

            // Meal type picker
            mealTypePicker

            // Log button
            Button {
              let n = nutrition
              let logName: String = {
                if let brand = food.brand, !brand.isEmpty {
                  return "\(brand) \(food.name)"
                }
                return food.name
              }()
              store.logNutritionEntry(
                title: "\(food.emoji) \(logName) (\(Int(grams))g)",
                mealType: mealType,
                calories: n.calories,
                protein: n.protein,
                carbs: n.carbs,
                fat: n.fat,
                on: selectedDate
              )
              dismiss()
              onLog()
            } label: {
              HStack {
                Image(systemName: "checkmark")
                  .font(.system(size: 15, weight: .bold))
                Text("Eintragen — \(nutrition.calories) kcal")
                  .font(GainsFont.label(16))
              }
              .foregroundStyle(GainsColor.ink)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .gainsGlassCTA()
            }
            .buttonStyle(.plain)
          }
          .padding(GainsSpacing.l)
          .padding(.bottom, GainsSpacing.tight)
        }
      }
      .navigationTitle(food.name)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Zurück") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
        ToolbarItem(placement: .keyboard) {
          Button("Fertig") { gramsFocused = false }
        }
      }
    }
    .presentationDetents([.large])
  }

  private var nutritionPreview: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      Text("Nährwerte für \(Int(grams))g")
        .font(GainsFont.label(13))
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: 0) {
        nutritionCell(value: "\(nutrition.calories)", unit: "kcal", label: "Kalorien", color: GainsColor.ink)
        Divider().frame(height: 40)
        nutritionCell(value: "\(nutrition.protein)g", unit: "", label: "Protein", color: GainsColor.lime)
        Divider().frame(height: 40)
        nutritionCell(value: "\(nutrition.carbs)g", unit: "", label: "Kohlenhydr.", color: GainsColor.accentCool)
        Divider().frame(height: 40)
        nutritionCell(value: "\(nutrition.fat)g", unit: "", label: "Fett", color: GainsColor.macroFat)
      }
      .animation(.spring(response: 0.4), value: Int(grams))
    }
    .padding(GainsSpacing.l)
    .gainsCardStyle(GainsColor.card)
  }

  private func nutritionCell(value: String, unit: String, label: String, color: Color) -> some View {
    VStack(spacing: GainsSpacing.xxs) {
      Text(value)
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundStyle(color)
        .contentTransition(.numericText())
      Text(label)
        .font(GainsFont.label(10))
        .foregroundStyle(GainsColor.mutedInk)
    }
    .frame(maxWidth: .infinity)
  }

  private var mealTypePicker: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Text("Mahlzeit")
        .font(GainsFont.label(13))
        .foregroundStyle(GainsColor.softInk)

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: GainsSpacing.tight) {
        ForEach(RecipeMealType.allCases, id: \.self) { type in
          Button {
            withAnimation(.spring(response: 0.25)) {
              mealType = type
            }
          } label: {
            Text(type.title)
              .font(GainsFont.label(13))
              .foregroundStyle(mealType == type ? GainsColor.moss : GainsColor.softInk)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .background(mealType == type ? GainsColor.lime.opacity(0.15) : GainsColor.elevated)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
              .overlay(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous).stroke(mealType == type ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.4), lineWidth: 1))
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(GainsSpacing.l)
    .gainsCardStyle(GainsColor.card)
  }
}

// MARK: - Nutrition Goal Wizard

struct NutritionGoalWizardSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  let existingProfile: NutritionProfile?

  // Wizard state – pre-filled wenn bereits ein Profil vorhanden
  @State private var step = 0
  @State private var sex: BiologicalSex
  @State private var age: Int
  @State private var heightCm: Int
  @State private var weightKg: Int
  @State private var activityLevel: ActivityLevel
  @State private var goal: NutritionGoal
  @State private var goingForward = true
  @State private var hasBodyFat: Bool
  @State private var bodyFatInt: Int   // Körperfettanteil in % (5–45)
  @State private var surplusKcal: Int  // Kcal-Überschuss (+) oder -Defizit (−)

  private let totalSteps = 8 // 0…8, step 8 = Zusammenfassung

  init(existingProfile: NutritionProfile?) {
    self.existingProfile = existingProfile
    _sex           = State(initialValue: existingProfile?.sex           ?? .male)
    _age           = State(initialValue: existingProfile?.age           ?? 25)
    _heightCm      = State(initialValue: existingProfile?.heightCm      ?? 178)
    _weightKg      = State(initialValue: existingProfile?.weightKg      ?? 80)
    _activityLevel = State(initialValue: existingProfile?.activityLevel ?? .moderate)
    _goal          = State(initialValue: existingProfile?.goal          ?? .maintain)
    _hasBodyFat    = State(initialValue: existingProfile?.bodyFatPercent != nil)
    _bodyFatInt    = State(initialValue: Int(existingProfile?.bodyFatPercent ?? 15.0))
    let defaultSurplus: Int
    switch existingProfile?.goal ?? .maintain {
    case .muscleGain: defaultSurplus = 200
    case .fatLoss:    defaultSurplus = -400
    case .maintain:   defaultSurplus = 0
    }
    _surplusKcal   = State(initialValue: existingProfile?.surplusKcal ?? defaultSurplus)
  }

  private var profile: NutritionProfile {
    NutritionProfile(
      sex: sex, age: age, heightCm: heightCm, weightKg: weightKg,
      bodyFatPercent: hasBodyFat ? Double(bodyFatInt) : nil,
      activityLevel: activityLevel, goal: goal,
      surplusKcal: surplusKcal
    )
  }

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        VStack(spacing: 0) {
          // Progress bar
          progressBar
            .padding(.horizontal, GainsSpacing.xl)
            .padding(.top, GainsSpacing.s)
            .padding(.bottom, GainsSpacing.xsPlus)

          // Step label
          Text("Schritt \(min(step + 1, totalSteps + 1)) von \(totalSteps + 1)")
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.mutedInk)
            .padding(.bottom, GainsSpacing.l)

          // Content
          ZStack {
            Group {
              switch step {
              case 0: sexStep
              case 1: ageStep
              case 2: heightStep
              case 3: weightStep
              case 4: bodyFatStep
              case 5: activityStep
              case 6: goalStep
              case 7: intensityStep
              default: summaryStep
              }
            }
            .transition(
              .asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                removal:   .move(edge: goingForward ? .leading  : .trailing).combined(with: .opacity)
              )
            )
            .id(step)
          }
          .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

          // Navigation
          navigationButtons
            .padding(.horizontal, GainsSpacing.xl)
            .padding(.top, GainsSpacing.m)
            .padding(.bottom, GainsSpacing.xl)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(stepTitle)
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
        if existingProfile != nil {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Zurücksetzen") {
              store.clearNutritionProfile()
              dismiss()
            }
            .foregroundStyle(GainsColor.ember)
            .font(GainsFont.label(13))
          }
        }
      }
    }
    .presentationDetents([.large])
  }

  // MARK: Progress Bar

  private var progressBar: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(GainsColor.border.opacity(0.4)).frame(height: 4)
        Capsule()
          .fill(GainsColor.lime)
          .frame(width: geo.size.width * (Double(step + 1) / Double(totalSteps + 1)), height: 4)
          .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
      }
    }
    .frame(height: 4)
  }

  private var stepTitle: String {
    switch step {
    case 0: return "Geschlecht"
    case 1: return "Alter"
    case 2: return "Körpergröße"
    case 3: return "Körpergewicht"
    case 4: return "Körperfettanteil"
    case 5: return "Aktivitätslevel"
    case 6: return "Dein Ziel"
    case 7: return "Intensität"
    default: return "Dein persönlicher Plan"
    }
  }

  // MARK: Step 0 – Geschlecht

  private var sexStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Was ist dein biologisches Geschlecht?",
        subtitle: "Wird für die genaue Berechnung deines Grundumsatzes (BMR) benötigt."
      )
      HStack(spacing: GainsSpacing.m) {
        ForEach(BiologicalSex.allCases, id: \.self) { s in
          sexCard(s)
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      Spacer()
    }
  }

  private func sexCard(_ s: BiologicalSex) -> some View {
    let isSelected = sex == s
    return Button {
      withAnimation(.spring(response: 0.3)) { sex = s }
    } label: {
      VStack(spacing: GainsSpacing.m) {
        Text(s.emoji)
          .font(.system(size: 52))
        Text(s.title)
          .font(GainsFont.label(17))
          .foregroundStyle(GainsColor.ink)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, GainsSpacing.xl)
      .background(isSelected ? GainsColor.lime.opacity(0.1) : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(isSelected ? GainsColor.lime.opacity(0.7) : GainsColor.border.opacity(0.5), lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: Step 1 – Alter

  private var ageStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Wie alt bist du?",
        subtitle: "Dein Grundumsatz nimmt mit dem Alter leicht ab."
      )
      pickerBlock(value: $age, range: 15...80, unit: "Jahre")
      Spacer()
    }
  }

  // MARK: Step 2 – Körpergröße

  private var heightStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Wie groß bist du?",
        subtitle: "Körpergröße beeinflusst deinen Grundumsatz direkt (Mifflin-St Jeor)."
      )
      pickerBlock(value: $heightCm, range: 140...220, unit: "cm")
      Spacer()
    }
  }

  // MARK: Step 3 – Körpergewicht

  private var weightStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Wie viel wiegst du?",
        subtitle: "Aktuelles Körpergewicht – am besten morgens nüchtern gemessen."
      )
      pickerBlock(value: $weightKg, range: 40...200, unit: "kg")
      Spacer()
    }
  }

  // MARK: Step 4 – Körperfettanteil (optional)

  private var bodyFatStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Kennst du deinen Körperfettanteil?",
        subtitle: "Optional: Gains berechnet dann deinen Grundumsatz nach Katch-McArdle (1975) – präziser für Athleten als Mifflin-St Jeor."
      )

      VStack(spacing: GainsSpacing.s) {
        Button {
          withAnimation(.spring(response: 0.3)) { hasBodyFat.toggle() }
        } label: {
          HStack(spacing: GainsSpacing.m) {
            Image(systemName: hasBodyFat ? "checkmark.circle.fill" : "circle")
              .font(.system(size: 22))
              .foregroundStyle(hasBodyFat ? GainsColor.lime : GainsColor.mutedInk)
            VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
              Text("Ja, ich kenne meinen KFA")
                .font(GainsFont.label(15))
                .foregroundStyle(GainsColor.ink)
              Text("Aktiviert die Katch-McArdle-Berechnung")
                .font(GainsFont.label(11))
                .foregroundStyle(GainsColor.softInk)
            }
            Spacer()
          }
          .padding(GainsSpacing.m)
          .background(hasBodyFat ? GainsColor.lime.opacity(0.06) : GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
              .stroke(hasBodyFat ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.5), lineWidth: 1.2)
          )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, GainsSpacing.xl)

        if hasBodyFat {
          pickerBlock(value: $bodyFatInt, range: 5...45, unit: "%")
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }

      if !hasBodyFat {
        Text("Kein Problem – Mifflin-St Jeor ist für die meisten Menschen sehr genau.")
          .font(GainsFont.label(12))
          .foregroundStyle(GainsColor.mutedInk)
          .multilineTextAlignment(.center)
          .padding(.horizontal, GainsSpacing.xl)
      }

      Spacer()
    }
  }

  // MARK: Step 5 – Aktivitätslevel

  private var activityStep: some View {
    VStack(spacing: GainsSpacing.l) {
      wizardHeader(
        title: "Wie aktiv bist du im Alltag?",
        subtitle: "Dieser Faktor multipliziert deinen Grundumsatz – sei möglichst ehrlich."
      )
      ScrollView(showsIndicators: false) {
        VStack(spacing: GainsSpacing.tight) {
          ForEach(ActivityLevel.allCases, id: \.self) { level in
            activityCard(level)
          }
        }
        .padding(.horizontal, GainsSpacing.xl)
        .padding(.bottom, GainsSpacing.xsPlus)
      }
    }
  }

  private func activityCard(_ level: ActivityLevel) -> some View {
    let isSelected = activityLevel == level
    return Button {
      withAnimation(.spring(response: 0.3)) { activityLevel = level }
    } label: {
      HStack(spacing: GainsSpacing.m) {
        Image(systemName: level.systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.softInk)
          .frame(width: 44, height: 44)
          .background(isSelected ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(level.title)
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
          Text(level.detail)
            .font(GainsFont.label(12))
            .foregroundStyle(GainsColor.softInk)
        }
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(GainsColor.lime)
        }
      }
      .padding(GainsSpacing.m)
      .background(isSelected ? GainsColor.lime.opacity(0.06) : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(isSelected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.5), lineWidth: 1.2)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: Step 6 – Ziel

  private var goalStep: some View {
    VStack(spacing: GainsSpacing.l) {
      wizardHeader(
        title: "Was ist dein Ziel?",
        subtitle: "Bestimmt den Kalorienüberschuss oder das -defizit."
      )
      VStack(spacing: GainsSpacing.tight) {
        ForEach(NutritionGoal.allCases, id: \.self) { g in
          goalCard(g)
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      Spacer()
    }
  }

  private func goalCard(_ g: NutritionGoal) -> some View {
    let isSelected = goal == g
    return Button {
      withAnimation(.spring(response: 0.3)) {
        goal = g
        // Standard-Intensität setzen, wenn Richtung wechselt
        switch g {
        case .muscleGain: if surplusKcal <= 0  { surplusKcal = 200  }
        case .fatLoss:    if surplusKcal >= 0  { surplusKcal = -400 }
        case .maintain:   surplusKcal = 0
        }
      }
    } label: {
      HStack(spacing: GainsSpacing.m) {
        Image(systemName: g.systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.softInk)
          .frame(width: 44, height: 44)
          .background(isSelected ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(g.title)
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
          Text(g.detail)
            .font(GainsFont.label(12))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(GainsColor.lime)
        }
      }
      .padding(GainsSpacing.m)
      .background(isSelected ? GainsColor.lime.opacity(0.06) : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(isSelected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.5), lineWidth: 1.2)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: Step 7 – Intensität (Surplus / Defizit-Stärke)

  private struct IntensityOption: Identifiable {
    let id = UUID()
    let label: String
    let subtitle: String
    let tag: String
    let kcal: Int
    let weeklyChange: String
  }

  private var intensityOptions: [IntensityOption] {
    switch goal {
    case .muscleGain:
      return [
        IntensityOption(label: "Lean Bulk",       subtitle: "Schoenfeld & Aragon (2018): minimiert Fettansatz",   tag: "+200 kcal", kcal:  200, weeklyChange: "≈ +0.2 kg/Woche"),
        IntensityOption(label: "Moderater Bulk",  subtitle: "Klassische Empfehlung – gutes Verhältnis",           tag: "+350 kcal", kcal:  350, weeklyChange: "≈ +0.3 kg/Woche"),
        IntensityOption(label: "Aggressiver Bulk",subtitle: "Schneller Aufbau, aber mehr Fettgewinn",             tag: "+500 kcal", kcal:  500, weeklyChange: "≈ +0.5 kg/Woche"),
      ]
    case .fatLoss:
      return [
        IntensityOption(label: "Sanfter Cut",      subtitle: "Sehr muskelschonend – ideal bei niedrigem KFA",     tag: "−200 kcal", kcal: -200, weeklyChange: "≈ −0.2 kg/Woche"),
        IntensityOption(label: "Moderater Cut",    subtitle: "Helms et al. (2014): 0.5–1 % KG/Woche optimal",    tag: "−400 kcal", kcal: -400, weeklyChange: "≈ −0.4 kg/Woche"),
        IntensityOption(label: "Aggressiver Cut",  subtitle: "Erhöhtes Risiko für Muskelabbau beachten",          tag: "−600 kcal", kcal: -600, weeklyChange: "≈ −0.6 kg/Woche"),
      ]
    case .maintain:
      return []
    }
  }

  private var intensityStep: some View {
    VStack(spacing: GainsSpacing.l) {
      wizardHeader(
        title: goal == .muscleGain ? "Wie schnell willst du aufbauen?" : "Wie aggressiv willst du abnehmen?",
        subtitle: goal == .muscleGain
          ? "Mehr Überschuss = schnelleres Muskelwachstum, aber auch mehr Fettzunahme."
          : "Größeres Defizit = schnellerer Fettverlust, aber erhöhtes Muskelabbaurisiko."
      )
      ScrollView(showsIndicators: false) {
        VStack(spacing: GainsSpacing.tight) {
          ForEach(intensityOptions) { option in
            intensityCard(option)
          }
        }
        .padding(.horizontal, GainsSpacing.xl)
        .padding(.bottom, GainsSpacing.xsPlus)
      }
    }
  }

  private func intensityCard(_ option: IntensityOption) -> some View {
    let isSelected = surplusKcal == option.kcal
    return Button {
      withAnimation(.spring(response: 0.3)) { surplusKcal = option.kcal }
    } label: {
      HStack(spacing: GainsSpacing.m) {
        Text(option.tag)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.softInk)
          .padding(.horizontal, GainsSpacing.tight)
          .padding(.vertical, GainsSpacing.xs)
          .background(isSelected ? GainsColor.lime : GainsColor.elevated)
          .clipShape(Capsule())
          .frame(minWidth: 82, alignment: .center)

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(option.label)
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
          Text(option.subtitle)
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
          Text(option.weeklyChange)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.mutedInk)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(GainsColor.lime)
        }
      }
      .padding(GainsSpacing.m)
      .background(isSelected ? GainsColor.lime.opacity(0.06) : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(isSelected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.5), lineWidth: 1.2)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: Step 8 – Zusammenfassung

  private var summaryStep: some View {
    let p = profile
    return ScrollView(showsIndicators: false) {
      VStack(spacing: GainsSpacing.m) {
        wizardHeader(
          title: "Dein persönlicher Plan",
          subtitle: "Berechnet nach \(p.formulaUsed) und ISSN-Richtlinien (2022)."
        )

        // BMR / TDEE Card
        VStack(spacing: GainsSpacing.s) {
          summaryRow(
            label: "Grundumsatz (BMR)",
            value: "\(Int(p.bmr.rounded())) kcal",
            color: GainsColor.softInk
          )
          Divider().background(GainsColor.border)
          summaryRow(
            label: "Gesamtumsatz (TDEE)",
            value: "\(Int(p.tdee.rounded())) kcal",
            color: GainsColor.softInk
          )
          Divider().background(GainsColor.border)
          HStack {
            VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
              Text("Zielkalorien")
                .font(GainsFont.label(14))
                .foregroundStyle(GainsColor.softInk)
              Text(goalAdjustmentLabel)
                .font(GainsFont.label(10))
                .foregroundStyle(GainsColor.mutedInk)
            }
            Spacer()
            Text("\(p.targetCalories) kcal")
              .font(.system(size: 22, weight: .bold, design: .rounded))
              .foregroundStyle(GainsColor.lime)
          }

          if surplusKcal != 0 {
            Divider().background(GainsColor.border)
            HStack {
              VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
                Text("Erwartete Veränderung/Woche")
                  .font(GainsFont.label(13))
                  .foregroundStyle(GainsColor.softInk)
                Text("Hall et al. (2012): ~7700 kcal = 1 kg")
                  .font(GainsFont.label(10))
                  .foregroundStyle(GainsColor.mutedInk)
              }
              Spacer()
              let change = p.weeklyWeightChangeKg
              Text(String(format: "%+.2f kg", change))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(change > 0 ? GainsColor.lime : GainsColor.accentCool)
            }
          }

          if let bf = p.bodyFatPercent {
            Divider().background(GainsColor.border)
            let leanMass = Double(p.weightKg) * (1.0 - bf / 100.0)
            summaryRow(label: "Körperfettanteil (KFA)", value: String(format: "%.0f %%", bf), color: GainsColor.softInk)
            summaryRow(label: "Lean Mass (berechnet)", value: String(format: "%.1f kg", leanMass), color: GainsColor.softInk)
          }
        }
        .padding(GainsSpacing.l)
        .gainsCardStyle(GainsColor.card)
        .padding(.horizontal, GainsSpacing.xl)

        // Makro Card
        VStack(spacing: GainsSpacing.s) {
          Text("Tagesziel Makros")
            .font(GainsFont.label(13))
            .foregroundStyle(GainsColor.softInk)
            .frame(maxWidth: .infinity, alignment: .leading)

          HStack(spacing: 0) {
            summaryMacroCell("\(p.targetProteinG)g", label: "Protein",      color: GainsColor.lime)
            Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
            summaryMacroCell("\(p.targetCarbsG)g",   label: "Kohlenhydr.", color: GainsColor.accentCool)
            Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
            summaryMacroCell("\(p.targetFatG)g",     label: "Fett",         color: GainsColor.macroFat)
          }
        }
        .padding(GainsSpacing.l)
        .gainsCardStyle(GainsColor.card)
        .padding(.horizontal, GainsSpacing.xl)

        // Profil-Zusammenfassung
        VStack(spacing: GainsSpacing.xsPlus) {
          profileSummaryChip("\(sex.title) · \(age) Jahre")
          profileSummaryChip("\(heightCm) cm · \(weightKg) kg\(hasBodyFat ? " · \(bodyFatInt) % KFA" : "")")
          profileSummaryChip(activityLevel.title)
          profileSummaryChip(p.formulaUsed)
        }
        .padding(.horizontal, GainsSpacing.xl)

        Text(p.bodyFatPercent != nil
          ? "Quellen: Katch & McArdle (1975) · Helms et al. (2014) IJSNEM · ISSN (2022)"
          : "Quellen: Mifflin et al. (1990) AJCN · Helms et al. (2014) IJSNEM · ISSN (2022)")
          .font(.system(size: 10))
          .foregroundStyle(GainsColor.mutedInk)
          .multilineTextAlignment(.center)
          .padding(.horizontal, GainsSpacing.xl)

        Spacer(minLength: 8)
      }
    }
  }

  private func summaryRow(label: String, value: String, color: Color) -> some View {
    HStack {
      Text(label).font(GainsFont.label(13)).foregroundStyle(GainsColor.softInk)
      Spacer()
      Text(value).font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(color)
    }
  }

  private func summaryMacroCell(_ value: String, label: String, color: Color) -> some View {
    VStack(spacing: GainsSpacing.xxs) {
      Text(value)
        .font(.system(size: 17, weight: .bold, design: .rounded))
        .foregroundStyle(color)
      Text(label)
        .font(GainsFont.label(10))
        .foregroundStyle(GainsColor.mutedInk)
    }
    .frame(maxWidth: .infinity)
  }

  private func profileSummaryChip(_ text: String) -> some View {
    Text(text)
      .font(GainsFont.label(12))
      .foregroundStyle(GainsColor.softInk)
      .padding(.horizontal, GainsSpacing.m)
      .padding(.vertical, GainsSpacing.xsPlus)
      .background(GainsColor.elevated)
      .clipShape(Capsule())
  }

  private var goalAdjustmentLabel: String {
    if surplusKcal > 0 {
      return "+\(surplusKcal) kcal Überschuss"
    } else if surplusKcal < 0 {
      return "\(surplusKcal) kcal Defizit"
    } else {
      return "Keine Anpassung (Erhaltung)"
    }
  }

  // MARK: Picker Helper

  private func pickerBlock(value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
    VStack(spacing: GainsSpacing.xxs) {
      Text("\(value.wrappedValue) \(unit)")
        .font(.system(size: 56, weight: .bold, design: .rounded))
        .foregroundStyle(GainsColor.lime)
        .contentTransition(.numericText())
        .animation(.spring(response: 0.3), value: value.wrappedValue)

      Picker("", selection: value) {
        ForEach(range, id: \.self) { val in
          Text("\(val)").tag(val)
        }
      }
      .pickerStyle(.wheel)
      .frame(height: 160)
      .clipped()
      .padding(.horizontal, GainsSpacing.xl)
    }
  }

  // MARK: Step Header

  private func wizardHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text(title)
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
      Text(subtitle)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, GainsSpacing.xl)
  }

  // MARK: Navigation Buttons

  private var navigationButtons: some View {
    HStack(spacing: GainsSpacing.s) {
      if step > 0 {
        Button {
          goingForward = false
          withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            // Beim Rückwärtsnavigieren vom Summary den Intensitäts-Schritt für "Maintain" überspringen
            step = (step == totalSteps && goal == .maintain) ? step - 2 : step - 1
          }
        } label: {
          HStack(spacing: GainsSpacing.xs) {
            Image(systemName: "chevron.left")
            Text("Zurück")
          }
          .font(GainsFont.label(15))
          .foregroundStyle(GainsColor.softInk)
          .frame(height: 54)
          .frame(maxWidth: .infinity)
          .background(GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        }
        .buttonStyle(.plain)
      }

      Button {
        if step == totalSteps {
          store.setNutritionProfile(profile)
          dismiss()
        } else if step == 6 && goal == .maintain {
          // "Maintain" braucht keinen Intensitäts-Schritt – direkt zur Zusammenfassung
          surplusKcal = 0
          goingForward = true
          withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = totalSteps }
        } else {
          goingForward = true
          withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step += 1 }
        }
      } label: {
        HStack(spacing: GainsSpacing.xs) {
          Text(step == totalSteps ? "Ziele übernehmen" : "Weiter")
          Image(systemName: step == totalSteps ? "checkmark" : "chevron.right")
        }
        .font(GainsFont.label(15))
        .foregroundStyle(GainsColor.ink)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .gainsGlassCTA()
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - Manual Food Entry View

struct ManualFoodEntryView: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  let defaultMealType: RecipeMealType
  let onLog: () -> Void

  @State private var title: String = ""
  @State private var mealType: RecipeMealType
  @State private var caloriesText = ""
  @State private var proteinText = ""
  @State private var carbsText = ""
  @State private var fatText = ""
  @FocusState private var focusedField: Field?

  enum Field: Hashable { case title, calories, protein, carbs, fat }

  init(defaultMealType: RecipeMealType, onLog: @escaping () -> Void) {
    self.defaultMealType = defaultMealType
    self.onLog = onLog
    self._mealType = State(initialValue: defaultMealType)
  }

  private var canLog: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    (Int(caloriesText) ?? 0) > 0
  }

  var body: some View {
    ZStack {
      GainsColor.background.ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(spacing: GainsSpacing.m) {
          // Title
          fieldBlock(title: "Name der Mahlzeit") {
            TextField("z. B. Hähnchen mit Reis", text: $title)
              .focused($focusedField, equals: .title)
              .font(GainsFont.body(16))
              .foregroundStyle(GainsColor.ink)
              .padding(.horizontal, GainsSpacing.m)
              .frame(height: 50)
              .background(GainsColor.elevated)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          }

          // Calories (required)
          fieldBlock(title: "Kalorien (kcal) *") {
            numericField("z.B. 450", text: $caloriesText, focus: .calories)
          }

          // Macros
          HStack(spacing: GainsSpacing.s) {
            fieldBlock(title: "Protein (g)") {
              numericField("0", text: $proteinText, focus: .protein)
            }
            fieldBlock(title: "Kohlenhydrate (g)") {
              numericField("0", text: $carbsText, focus: .carbs)
            }
            fieldBlock(title: "Fett (g)") {
              numericField("0", text: $fatText, focus: .fat)
            }
          }

          // Meal type
          VStack(alignment: .leading, spacing: GainsSpacing.tight) {
            Text("Mahlzeit")
              .font(GainsFont.label(12))
              .foregroundStyle(GainsColor.softInk)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: GainsSpacing.xsPlus) {
              ForEach(RecipeMealType.allCases, id: \.self) { type in
                Button {
                  withAnimation { mealType = type }
                } label: {
                  Text(type.title)
                    .font(GainsFont.label(12))
                    .foregroundStyle(mealType == type ? GainsColor.moss : GainsColor.softInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(mealType == type ? GainsColor.lime.opacity(0.15) : GainsColor.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous).stroke(mealType == type ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
              }
            }
          }

          // Log button
          Button {
            store.logNutritionEntry(
              title: title,
              mealType: mealType,
              calories: Int(caloriesText) ?? 0,
              protein: Int(proteinText) ?? 0,
              carbs: Int(carbsText) ?? 0,
              fat: Int(fatText) ?? 0,
              on: selectedDate
            )
            dismiss()
            onLog()
          } label: {
            HStack {
              Image(systemName: "plus.circle.fill")
                .font(.system(size: 16))
              Text("Mahlzeit eintragen")
                .font(GainsFont.label(16))
            }
            .foregroundStyle(canLog ? GainsColor.onLime : GainsColor.mutedInk)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canLog ? GainsColor.lime : GainsColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(!canLog)
          .animation(.spring(response: 0.3), value: canLog)
        }
        .padding(GainsSpacing.l)
        .padding(.bottom, GainsSpacing.l)
      }
    }
    .navigationTitle("Manuell eingeben")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .keyboard) {
        Button("Fertig") { focusedField = nil }
      }
    }
  }

  @ViewBuilder
  private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      Text(title)
        .font(GainsFont.label(12))
        .foregroundStyle(GainsColor.softInk)
      content()
    }
  }

  private func numericField(_ placeholder: String, text: Binding<String>, focus: Field) -> some View {
    TextField(placeholder, text: text)
      .focused($focusedField, equals: focus)
      .keyboardType(.numberPad)
      .font(GainsFont.body(16))
      .foregroundStyle(GainsColor.ink)
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 50)
      .background(GainsColor.elevated)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous).stroke(GainsColor.border.opacity(0.5), lineWidth: 1))
  }
}
