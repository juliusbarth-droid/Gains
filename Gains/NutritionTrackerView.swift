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

  enum NutritionTab: String, CaseIterable {
    case tracker = "Tracker"
    case recipes = "Rezepte"
  }

  var body: some View {
    NavigationStack {
      ZStack(alignment: .top) {
        GainsAppBackground()

        VStack(spacing: 0) {
          // Sub-tab picker
          nutritionTabBar

          // Content
          Group {
            if selectedTab == .tracker {
              CalorienTrackerView()
                .environmentObject(store)
                .environmentObject(navigation)
            } else {
              RecipesView()
                .environmentObject(store)
                .environmentObject(navigation)
            }
          }
        }
      }
    }
  }

  private var nutritionTabBar: some View {
    HStack(spacing: 0) {
      ForEach(NutritionTab.allCases, id: \.self) { tab in
        Button {
          // Modern SwiftUI: .animation(_:value:) am Container statt
          // withAnimation um den State-Setter — präziser, weil nur
          // selectedTab-getriggerte Renders animieren, und nicht
          // versehentlich andere State-Änderungen mitziehen.
          selectedTab = tab
        } label: {
          VStack(spacing: 0) {
            Text(tab.rawValue)
              .font(GainsFont.label(13))
              .foregroundStyle(selectedTab == tab ? GainsColor.ink : GainsColor.mutedInk)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)

            Rectangle()
              .fill(selectedTab == tab ? GainsColor.lime : Color.clear)
              .frame(height: 2)
              .clipShape(Capsule())
          }
        }
        .buttonStyle(.plain)
      }
    }
    .background(GainsColor.card.opacity(0.95))
    .overlay(
      Rectangle()
        .fill(GainsColor.border.opacity(0.5))
        .frame(height: 1),
      alignment: .bottom
    )
    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedTab)
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
  // Pulse-Refresh: minütlicher Tick, damit die Coach-Brief-Variants
  // (z. B. „Mittag fehlt") tageszeitabhängig automatisch wechseln.
  @State private var pulseClock: Date = Date()
  private let pulseTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
  // P2-Fix (2026-05-01): Wenn der User aktiv über die Chevrons das Datum
  // ändert, soll der Tracker NICHT bei Mitternacht/App-Resume zurück auf
  // „heute" springen — sonst geht seine Auswahl verloren. `userPickedDate`
  // wird in beiden Datums-Buttons gesetzt und in `resetToToday` gecleart.
  @State private var userPickedDate = false

  private var isToday: Bool {
    Calendar.current.isDateInToday(selectedDate)
  }

  /// Macro-Totals für `selectedDate`. Single-Pass über `nutritionEntries`
  /// statt 4× separater `reduce`-Calls pro Body-Render.
  private struct DayTotals {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    static let zero = DayTotals(calories: 0, protein: 0, carbs: 0, fat: 0)
  }

  /// Filtert + summiert in EINEM Walk durch `store.nutritionEntries`.
  /// Vorher wurden 4× separat gefiltert + sortiert + reduziert (also
  /// 5 Walks pro Body-Render); jetzt 1 Walk für die Macros + 1 Walk
  /// für `entriesForDay` (das die Sortierung für die Liste braucht).
  private var dayTotals: DayTotals {
    var calories = 0
    var protein = 0
    var carbs = 0
    var fat = 0
    let calendar = Calendar.current
    for entry in store.nutritionEntries
    where calendar.isDate(entry.loggedAt, inSameDayAs: selectedDate) {
      calories += entry.calories
      protein += entry.protein
      carbs += entry.carbs
      fat += entry.fat
    }
    return DayTotals(calories: calories, protein: protein, carbs: carbs, fat: fat)
  }

  private var entriesForDay: [NutritionEntry] {
    nutritionEntries(for: selectedDate)
  }

  // Forwarders auf dayTotals — Call-Sites bleiben identisch.
  private var caloriesForDay: Int { dayTotals.calories }
  private var proteinForDay: Int { dayTotals.protein }
  private var carbsForDay: Int { dayTotals.carbs }
  private var fatForDay: Int { dayTotals.fat }

  private func nutritionEntries(for date: Date) -> [NutritionEntry] {
    store.nutritionEntries
      .filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: date) }
      .sorted { $0.loggedAt > $1.loggedAt }
  }

  private func entries(for mealType: RecipeMealType) -> [NutritionEntry] {
    entriesForDay.filter { $0.mealType == mealType }
  }

  // Day-One-Banner: nur sichtbar in den ersten 24h nach Onboarding und
  // solange der User noch keine Mahlzeit für „heute" geloggt hat. Erklärt
  // die drei Capture-Pfade auf einen Blick und liefert ein eindeutiges CTA.
  private var isInNutritionDayOneWindow: Bool {
    guard onboardingCompletedAt > 0 else { return false }
    let completedAt = Date(timeIntervalSince1970: onboardingCompletedAt)
    let hoursSince = Date().timeIntervalSince(completedAt) / 3600
    guard hoursSince >= 0, hoursSince < 24 else { return false }
    if !store.nutritionEntries.isEmpty { return false }
    return true
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 0) {
        // Date navigation
        dateNavigationRow
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 12)

        if isInNutritionDayOneWindow && isToday {
          dayOneNutritionBanner
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        } else if isToday, let pulse = currentNutritionPulse {
          // Welle 3 (2026-05-03): Coach-Brief-Mini direkt über dem Ring —
          // kontextsensitive Pulse-Zeile, die Tageszeit, Protein-Lücke,
          // Streak und Mahlzeit-Status spiegelt. Schließt sich mit dem
          // Day-One-Banner gegenseitig aus, damit nur eine emotionale
          // Stimme spricht.
          nutritionPulseLine(pulse)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }

        // Calorie ring + macros
        calorieRingCard
          .padding(.horizontal, 20)
          .padding(.bottom, 16)

        // Welle 3 (2026-05-03): Recents-Strip — die letzten unique
        // gelogged en Lebensmittel als horizontale Cards. Tap = direkt
        // loggen in die Tageszeit-passende Mahlzeit. Letzte Card ist
        // immer das Quick-Add-CTA. Nur sichtbar an „heute" und wenn
        // mindestens 1 historisches Lebensmittel da ist (sonst zeigt
        // der Strip nur das Quick-Add — siehe `showsRecentsStrip`).
        if isToday && showsRecentsStrip {
          recentsStrip
            .padding(.bottom, 16)
        }

        // Meal sections
        VStack(spacing: 10) {
          mealSection(.breakfast, title: "Frühstück",   emoji: "🌅")
          mealSection(.lunch,     title: "Mittagessen", emoji: "🍽️")
          mealSection(.dinner,    title: "Abendessen",  emoji: "🌙")
          mealSection(.snack,     title: "Snacks",      emoji: "🍎")
          mealSection(.shake,     title: "Shake",       emoji: "🥤")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)

        // Welle 3 (2026-05-03): Day-Summary-Footer — emotionaler Abschluss
        // unter den Meal-Sections. Zeigt Streak, Wochen-Sparkline kcal und
        // Protein-Hit-Rate. Nur an „heute" und nur wenn ≥1 Eintrag heute.
        if isToday && !entriesForDay.isEmpty {
          daySummaryFooter
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        } else {
          Spacer(minLength: 24)
        }
      }
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
    .onReceive(pulseTimer) { _ in
      pulseClock = Date()
    }
    // P2-Fix (2026-05-01): Sobald die App in den Vordergrund kehrt und der
    // User vorher implizit auf „heute" stand, prüfen wir, ob inzwischen ein
    // Tageswechsel passiert ist (App lief über Mitternacht). In dem Fall
    // springt `selectedDate` automatisch auf den neuen Tag, damit Logging
    // nicht versehentlich auf den Vortag landet.
    .onChange(of: scenePhase) { _, newPhase in
      guard newPhase == .active, !userPickedDate else { return }
      let todayStart = Calendar.current.startOfDay(for: Date())
      if !Calendar.current.isDate(selectedDate, inSameDayAs: todayStart) {
        selectedDate = todayStart
      }
    }
  }

  // MARK: Date Navigation

  private var dateNavigationRow: some View {
    HStack {
      Button {
        withAnimation(.spring(response: 0.3)) {
          selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
          userPickedDate = true
        }
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 36, height: 36)
          .background(GainsColor.elevated)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)

      Spacer()

      VStack(spacing: 2) {
        Text(isToday ? "Heute" : dateLabel(selectedDate))
          .font(GainsFont.title(17))
          .foregroundStyle(GainsColor.ink)
        if isToday {
          Text(dateLabel(selectedDate))
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.mutedInk)
        }
      }

      Spacer()

      Button {
        withAnimation(.spring(response: 0.3)) {
          let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
          let todayStart = Calendar.current.startOfDay(for: Date())
          if tomorrow <= todayStart {
            selectedDate = tomorrow
            // Wenn der User wieder auf „heute" zurück navigiert, ist sein
            // Override aufgehoben — der Auto-Refresh über Mitternacht darf
            // wieder greifen.
            userPickedDate = !Calendar.current.isDate(tomorrow, inSameDayAs: todayStart)
          }
        }
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(isToday ? GainsColor.border : GainsColor.softInk)
          .frame(width: 36, height: 36)
          .background(GainsColor.elevated)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .disabled(isToday)
    }
  }

  // MARK: - Day-One Nutrition Banner
  //
  // Welcome-Banner für die ersten 24h nach Onboarding, solange noch keine
  // Mahlzeit geloggt ist. Erklärt die drei Capture-Pfade (Suche / Foto /
  // Barcode) — der häufigste Stolperstein bei Anfängern ist nicht „wo ist
  // der Logger", sondern „welcher der drei Wege ist der beste für mich".
  // Großes CTA „Erste Mahlzeit loggen" führt direkt in die Suche.

  private var dayOneNutritionBanner: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 8) {
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

      VStack(spacing: 8) {
        dayOnePathRow(
          icon: "magnifyingglass",
          title: "Suche",
          detail: "Tippe einen Lebensmittelnamen — wir kennen 100k+ Produkte."
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
        HStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 14, weight: .bold))
          Text("Erste Mahlzeit loggen")
            .font(GainsFont.label(13))
            .tracking(1.2)
          Spacer(minLength: 0)
          Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .heavy))
        }
        .foregroundStyle(GainsColor.onLime)
        .padding(.horizontal, 16)
        .frame(height: 48)
        .frame(maxWidth: .infinity)
        .background(GainsColor.lime)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [GainsColor.lime.opacity(0.08), GainsColor.card],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.32), lineWidth: GainsBorder.accent)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private func dayOnePathRow(icon: String, title: String, detail: String) -> some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(GainsColor.lime.opacity(0.14))
          .frame(width: 32, height: 32)
        Image(systemName: icon)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
      }
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

  private var calorieRingCard: some View {
    VStack(spacing: 0) {
      // Goal + Wizard buttons
      VStack(spacing: 10) {

        // Pill-Zeile: Ziel-Picker + kompaktes "Anpassen" wenn Profil vorhanden
        HStack(spacing: 8) {
          Button {
            showsGoalPicker = true
          } label: {
            HStack(spacing: 6) {
              Image(systemName: store.nutritionGoal.systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GainsColor.moss)
              Text(store.nutritionGoalHeadline)
                .font(GainsFont.label(11))
                .foregroundStyle(GainsColor.softInk)
              Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(GainsColor.mutedInk)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(GainsColor.elevated)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(GainsColor.border.opacity(0.6), lineWidth: 1))
          }
          .buttonStyle(.plain)

          if store.nutritionProfile != nil {
            Button {
              showsNutritionWizard = true
            } label: {
              HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundStyle(GainsColor.moss)
                Text("Anpassen")
                  .font(GainsFont.label(11))
                  .foregroundStyle(GainsColor.moss)
              }
              .padding(.horizontal, 12)
              .frame(height: 30)
              .background(GainsColor.lime.opacity(0.12))
              .clipShape(Capsule())
              .overlay(Capsule().stroke(GainsColor.lime.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
          }

          Spacer()
        }

        // Prominenter "Berechnen"-CTA – nur solange noch kein Profil berechnet wurde
        if store.nutritionProfile == nil {
          Button {
            showsNutritionWizard = true
          } label: {
            HStack(spacing: 14) {
              ZStack {
                RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                  .fill(GainsColor.moss.opacity(0.25))
                  .frame(width: 46, height: 46)
                Image(systemName: "function")
                  .font(.system(size: 20, weight: .bold))
                  .foregroundStyle(GainsColor.onLime)
              }
              VStack(alignment: .leading, spacing: 2) {
                Text("Kalorienbedarf berechnen")
                  .font(GainsFont.label(15))
                  .foregroundStyle(GainsColor.onLime)
                Text("Mifflin-St Jeor · ISSN 2022 · personalisiert")
                  .font(GainsFont.label(10))
                  .foregroundStyle(GainsColor.onLime.opacity(0.75))
              }
              Spacer()
              Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(GainsColor.onLime.opacity(0.75))
            }
            .padding(.horizontal, 16)
            .frame(height: 64)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 20)

      // Ring + macros layout
      HStack(alignment: .center, spacing: 24) {
        // Calorie Ring
        calorieRing
          .frame(width: 170, height: 170)

        // Macro breakdown
        VStack(alignment: .leading, spacing: 14) {
          macroRow(
            label: "Protein",
            current: proteinForDay,
            target: store.nutritionTargetProtein,
            unit: "g",
            color: GainsColor.lime
          )
          macroRow(
            label: "Kohlenh.",
            current: carbsForDay,
            target: store.nutritionTargetCarbs,
            unit: "g",
            color: Color(hex: "5BC4F5")
          )
          macroRow(
            label: "Fett",
            current: fatForDay,
            target: store.nutritionTargetFat,
            unit: "g",
            color: Color(hex: "FF8A4A")
          )
        }
        .frame(maxWidth: .infinity)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)

      // Summary row
      Rectangle()
        .fill(GainsColor.border.opacity(0.5))
        .frame(height: 1)
        .padding(.horizontal, 20)

      HStack {
        summaryPill(label: "Gegessen", value: "\(caloriesForDay) kcal", color: GainsColor.lime)
        Spacer()
        summaryPill(label: "Ziel", value: "\(store.nutritionTargetCalories) kcal", color: GainsColor.mutedInk)
        Spacer()
        let burned = isToday ? Double(store.healthSnapshot?.activeEnergyToday ?? 0) : 0
        summaryPill(label: "Verbrannt", value: "\(Int(burned)) kcal", color: Color(hex: "FF8A4A"))
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
    }
    .gainsCardStyle(GainsColor.card)
  }

  private var calorieRing: some View {
    let progress = min(CGFloat(caloriesForDay) / CGFloat(max(store.nutritionTargetCalories, 1)), 1.0)
    let remaining = max(store.nutritionTargetCalories - caloriesForDay, 0)
    let isOver = caloriesForDay > store.nutritionTargetCalories
    let ringColor: Color = isOver ? GainsColor.ember : GainsColor.lime

    return ZStack {
      // Background ring
      Circle()
        .stroke(GainsColor.border.opacity(0.5), lineWidth: 14)

      // Progress ring
      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          AngularGradient(
            colors: [ringColor.opacity(0.7), ringColor],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
          ),
          style: StrokeStyle(lineWidth: 14, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.spring(response: 0.8, dampingFraction: 0.75), value: progress)

      // Center text
      VStack(spacing: 2) {
        Text("\(remaining)")
          .font(.system(size: 28, weight: .bold, design: .rounded))
          .foregroundStyle(isOver ? GainsColor.ember : GainsColor.ink)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.5), value: remaining)

        Text("kcal")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.mutedInk)

        Text(isOver ? "überschritten" : "verbleibend")
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(isOver ? GainsColor.ember : GainsColor.softInk)
          .multilineTextAlignment(.center)
          .lineLimit(1)
      }
    }
  }

  private func macroRow(label: String, current: Int, target: Int, unit: String, color: Color) -> some View {
    let progress = min(Double(current) / Double(max(target, 1)), 1.0)
    return VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 0) {
        Text(label)
          .font(GainsFont.label(11))
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 64, alignment: .leading)
        Spacer()
        Text("\(current)")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.4), value: current)
        Text(" / \(target)\(unit)")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.mutedInk)
      }

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.border.opacity(0.4))
            .frame(height: 5)
          Capsule()
            .fill(color)
            .frame(width: geo.size.width * progress, height: 5)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
      }
      .frame(height: 5)
    }
  }

  private func summaryPill(label: String, value: String, color: Color) -> some View {
    VStack(spacing: 3) {
      Text(value)
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(color)
        .contentTransition(.numericText())
      Text(label)
        .font(GainsFont.label(10))
        .foregroundStyle(GainsColor.mutedInk)
    }
  }

  // MARK: Meal Section
  //
  // Welle 3 Cleaner-Pass (2026-05-03): Header dezenter (kcal-Pill auf
  // hairline-Border, Subline kürzer), Empty-State eine schlanke Zeile
  // statt großer Plus-Icon, Action-Bar nur „Hinzufügen | KI-Foto" mit
  // klar getrennten Pfaden. Food-Rows bekommen Long-Press-Power-Menu
  // (Wieder loggen / Duplizieren / In Mahlzeit verschieben / Löschen).

  private func mealSection(_ mealType: RecipeMealType, title: String, emoji: String) -> some View {
    let sectionEntries = entries(for: mealType)
    let sectionCalories = sectionEntries.reduce(0) { $0 + $1.calories }
    let isExpanded = expandedSections.contains(mealType)

    return VStack(spacing: 0) {
      // Header
      Button {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
          if isExpanded {
            expandedSections.remove(mealType)
          } else {
            expandedSections.insert(mealType)
          }
        }
      } label: {
        HStack(spacing: 12) {
          Text(emoji)
            .font(.system(size: 20))
            .frame(width: 40, height: 40)
            .background(GainsColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(GainsFont.label(14))
              .foregroundStyle(GainsColor.ink)
            Text(mealSubline(for: sectionEntries))
              .font(GainsFont.label(11))
              .foregroundStyle(GainsColor.mutedInk)
          }

          Spacer()

          if sectionCalories > 0 {
            Text("\(sectionCalories) kcal")
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .foregroundStyle(GainsColor.softInk)
              .padding(.horizontal, 10)
              .padding(.vertical, 4)
              .background(GainsColor.elevated)
              .overlay(
                Capsule().stroke(GainsColor.border.opacity(0.5), lineWidth: GainsBorder.hairline)
              )
              .clipShape(Capsule())
          }

          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(GainsColor.mutedInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
      }
      .buttonStyle(.plain)

      if isExpanded {
        VStack(spacing: 0) {
          Rectangle()
            .fill(GainsColor.border.opacity(0.5))
            .frame(height: 1)
            .padding(.horizontal, 16)

          if sectionEntries.isEmpty {
            HStack(spacing: 10) {
              Image(systemName: "plus.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GainsColor.mutedInk)
              Text("Noch nichts geloggt — füg etwas hinzu.")
                .font(GainsFont.label(12))
                .foregroundStyle(GainsColor.mutedInk)
              Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
          } else {
            ForEach(sectionEntries) { entry in
              foodEntryRow(entry)
            }
          }

          // Action-Bar: Suche | KI-Foto | Schnell
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
      }
    }
    .gainsCardStyle(GainsColor.card)
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
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(tint)
      Text(text)
        .font(GainsFont.label(12))
        .foregroundStyle(tint)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(GainsColor.lime.opacity(0.06))
  }

  @ViewBuilder
  private func foodEntryRow(_ entry: NutritionEntry) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        Text(entry.title)
          .font(GainsFont.label(14))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        HStack(spacing: 8) {
          macroChip("P: \(entry.protein)g", color: GainsColor.lime)
          macroChip("K: \(entry.carbs)g", color: Color(hex: "5BC4F5"))
          macroChip("F: \(entry.fat)g", color: Color(hex: "FF8A4A"))
        }
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text("\(entry.calories)")
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        Text("kcal")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.mutedInk)
      }

      // Welle 3: explizites ⋯-Menu als sichtbare Affordance — Long-Press
      // tut DASSELBE (siehe .contextMenu unten), aber Tap auf das Icon
      // ist diskoverbarer für User, die die Long-Press-Geste nicht kennen.
      Menu {
        foodEntryActions(entry)
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 30, height: 30)
          .background(GainsColor.elevated)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(Rectangle())
    .background(GainsColor.card)
    .contextMenu {
      // Long-Press → identisches Power-Menu wie der ⋯-Button. Beide Pfade
      // teilen `foodEntryActions(_:)`, damit die Aktionsliste konsistent
      // bleibt.
      foodEntryActions(entry)
    }

    Rectangle()
      .fill(GainsColor.border.opacity(0.4))
      .frame(height: 1)
      .padding(.horizontal, 16)
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
    Text(text)
      .font(.system(size: 10, weight: .medium))
      .foregroundStyle(color)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color.opacity(0.1))
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

    let lunchEntries = entries(for: .lunch).count
    if hour >= 13 && hour < 16, lunchEntries == 0, !entriesForDay.isEmpty {
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
    if !entriesForDay.isEmpty, kcalShare >= 0.6, proteinShare >= 0.6 {
      return NutritionPulse(
        eyebrow: "TAG LÄUFT",
        headline: "Sauber im Rahmen.",
        detail: "\(kcalToday) kcal · \(proteinToday) g Protein bisher.",
        icon: "checkmark.seal.fill",
        accent: .soft
      )
    }
    if hour < 11, entriesForDay.isEmpty {
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

  fileprivate func nutritionPulseLine(_ pulse: NutritionPulse) -> some View {
    let accentColor: Color = {
      switch pulse.accent {
      case .lime:  return GainsColor.lime
      case .ember: return GainsColor.ember
      case .cool:  return Color(hex: "5BC4F5")
      case .soft:  return GainsColor.softInk
      }
    }()

    return HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(accentColor.opacity(0.14))
          .frame(width: 36, height: 36)
        Image(systemName: pulse.icon)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(accentColor)
      }

      VStack(alignment: .leading, spacing: 3) {
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
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.border.opacity(0.5), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  // MARK: - Welle 3: Recents-Strip + Quick-Add (2026-05-03)

  fileprivate var showsRecentsStrip: Bool {
    if isInNutritionDayOneWindow && entriesForDay.isEmpty { return false }
    return !store.recentNutritionFoods.isEmpty || !entriesForDay.isEmpty
  }

  fileprivate var recentsStrip: some View {
    let recents = store.recentNutritionFoods

    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
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
      .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          quickAddRecentCard
          ForEach(recents) { entry in
            recentFoodCard(entry)
          }
        }
        .padding(.horizontal, 20)
      }
    }
  }

  fileprivate var quickAddRecentCard: some View {
    Button {
      quickAddInitialMeal = currentMealTypeForTime()
      showsQuickAdd = true
    } label: {
      VStack(alignment: .leading, spacing: 8) {
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
      .padding(12)
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
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 0) {
          Image(systemName: entry.mealType.systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
            .frame(width: 26, height: 26)
            .background(GainsColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          Spacer()
          Image(systemName: "plus")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(GainsColor.lime)
        }
        Spacer(minLength: 0)
        VStack(alignment: .leading, spacing: 2) {
          Text(entry.title)
            .font(GainsFont.label(12))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
          HStack(spacing: 6) {
            Text("\(entry.calories) kcal")
              .font(.system(size: 10, weight: .semibold, design: .rounded))
              .foregroundStyle(GainsColor.softInk)
            if entry.protein > 0 {
              Text("· \(entry.protein)g P")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(GainsColor.mutedInk)
            }
          }
        }
      }
      .padding(12)
      .frame(width: 144, height: 96, alignment: .topLeading)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(GainsColor.border.opacity(0.5), lineWidth: GainsBorder.hairline)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
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

  fileprivate var daySummaryFooter: some View {
    let weeklyCalories = store.dailyCalories(lastDays: 7)
    let proteinRate = store.proteinHitRate(lastDays: 7)
    let streak = store.nutritionStreakDays

    return VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TAGESBILANZ", "DEINE WOCHE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      HStack(alignment: .top, spacing: 10) {
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
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.border.opacity(0.5), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  fileprivate func summaryStatTile(
    eyebrow: String,
    value: String,
    unit: String,
    icon: String,
    accent: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(accent)
        Text(eyebrow)
          .gainsEyebrow(GainsColor.softInk, size: 9, tracking: 1.3)
      }
      Text(value)
        .font(.system(size: 22, weight: .bold, design: .rounded))
        .foregroundStyle(GainsColor.ink)
        .contentTransition(.numericText())
      Text(unit)
        .font(GainsFont.label(10))
        .foregroundStyle(GainsColor.mutedInk)
        .lineLimit(1)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  fileprivate func summaryWeekSparklineTile(weeklyCalories: [Int]) -> some View {
    let maxValue = max(weeklyCalories.max() ?? 1, 1)
    let target = max(store.nutritionTargetCalories, 1)
    let ceiling = max(maxValue, target)
    let symbols = Calendar.current.shortStandaloneWeekdaySymbols
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    return VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 6) {
        Image(systemName: "chart.bar.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        Text("KCAL · 7 TAGE")
          .gainsEyebrow(GainsColor.softInk, size: 9, tracking: 1.3)
      }

      HStack(alignment: .bottom, spacing: 4) {
        ForEach(Array(weeklyCalories.enumerated()), id: \.offset) { index, kcal in
          let dayOffset = weeklyCalories.count - 1 - index
          let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
          let weekdayIdx = (calendar.component(.weekday, from: date) - 1 + 7) % 7
          let label = String(symbols[weekdayIdx].prefix(2))
          let height: CGFloat = max(4, CGFloat(kcal) / CGFloat(ceiling) * 38)
          let isOver = kcal > target
          let isTodayBar = dayOffset == 0

          VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3)
              .fill(
                kcal == 0
                  ? GainsColor.border.opacity(0.4)
                  : (isOver ? GainsColor.ember : GainsColor.lime)
              )
              .frame(height: height)
            Text(label)
              .font(.system(size: 8, weight: isTodayBar ? .bold : .medium))
              .foregroundStyle(isTodayBar ? GainsColor.ink : GainsColor.mutedInk)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .frame(height: 50)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
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
          VStack(alignment: .leading, spacing: 18) {
            heroPreview
            mealPicker
            macroFields
            Spacer(minLength: 12)
          }
          .padding(.horizontal, 20)
          .padding(.top, 12)
          .padding(.bottom, 24)
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
    VStack(alignment: .leading, spacing: 12) {
      Text("KCAL")
        .gainsEyebrow(GainsColor.lime, size: 11, tracking: 1.4)

      HStack(alignment: .firstTextBaseline, spacing: 6) {
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
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(GainsColor.elevated)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .padding(GainsSpacing.m)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.border.opacity(0.5), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private var mealPicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("MAHLZEIT")
        .gainsEyebrow(GainsColor.softInk, size: 11, tracking: 1.4)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(RecipeMealType.allCases, id: \.self) { type in
            Button {
              withAnimation(.spring(response: 0.25)) { mealType = type }
            } label: {
              HStack(spacing: 6) {
                Image(systemName: type.systemImage)
                  .font(.system(size: 11, weight: .semibold))
                Text(type.title)
                  .font(GainsFont.label(12))
              }
              .foregroundStyle(mealType == type ? GainsColor.onLime : GainsColor.softInk)
              .padding(.horizontal, 14)
              .padding(.vertical, 9)
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
    VStack(alignment: .leading, spacing: 8) {
      Text("MAKROS · OPTIONAL")
        .gainsEyebrow(GainsColor.softInk, size: 11, tracking: 1.4)
      HStack(spacing: 8) {
        macroField("Protein", text: $proteinText, color: GainsColor.lime)
        macroField("Kohlenh.", text: $carbsText, color: Color(hex: "5BC4F5"))
        macroField("Fett", text: $fatText, color: Color(hex: "FF8A4A"))
      }
    }
  }

  private func macroField(_ label: String, text: Binding<String>, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(GainsFont.label(10))
        .foregroundStyle(GainsColor.softInk)
      HStack(spacing: 4) {
        TextField("0", text: text)
          .keyboardType(.numberPad)
          .font(.system(size: 16, weight: .semibold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .multilineTextAlignment(.leading)
        Text("g")
          .font(GainsFont.label(11))
          .foregroundStyle(GainsColor.mutedInk)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(GainsColor.elevated)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(color.opacity(0.25), lineWidth: GainsBorder.hairline)
      )
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
          VStack(alignment: .leading, spacing: 6) {
            Text("Ernährungsziel")
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)
            Text("Wähle dein Ziel — die Kalorie- und Makroziele passen sich automatisch an.")
              .font(GainsFont.body(14))
              .foregroundStyle(GainsColor.softInk)
          }
          .padding(.horizontal, 24)
          .padding(.top, 24)
          .padding(.bottom, 20)

          VStack(spacing: 12) {
            ForEach(NutritionGoal.allCases, id: \.self) { goal in
              goalCard(goal)
            }
          }
          .padding(.horizontal, 20)

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
      HStack(spacing: 16) {
        Image(systemName: goal.systemImage)
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.softInk)
          .frame(width: 48, height: 48)
          .background(isSelected ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

        VStack(alignment: .leading, spacing: 3) {
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
        }
      }
      // A13 (Cleaner-Pass): cornerRadius 18→16, lineWidth 1.2→0.8 (accent)
      // bzw. 0.6 (hairline) — Selektions-Card liest sich konsistent zu den
      // restlichen Cards der App.
      .padding(GainsSpacing.m)
      .background(isSelected ? GainsColor.lime.opacity(0.06) : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .strokeBorder(
            isSelected ? GainsColor.lime.opacity(0.40) : GainsColor.border.opacity(0.5),
            lineWidth: isSelected ? GainsBorder.accent : GainsBorder.hairline
          )
      )
    }
    .buttonStyle(.plain)
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
            .padding(.top, 4)
            .padding(.bottom, 8)

          // Quick-scan buttons
          // N2-Fix (2026-05-01): Wenn der Parent Callbacks gesetzt hat,
          // wird FoodSearchSheet zuerst dismissed und der Parent
          // präsentiert das Ziel-Sheet. So entsteht kein Sheet-Stack.
          HStack(spacing: 10) {
            scanActionButton(
              icon: "barcode.viewfinder",
              label: "Barcode scannen",
              color: Color(hex: "5BC4F5")
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
          .padding(.horizontal, 20)
          .padding(.bottom, 12)

          // Search bar
          searchBar
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

          // Category chips
          categoryChips
            .padding(.bottom, 8)

          // Food list
          ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
              ForEach(filteredFoods) { food in
                foodRow(food)
              }

              if filteredFoods.isEmpty {
                emptySearchState
                  .padding(.top, 60)
              }

              // Manual entry option
              manualEntryFooter
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
          }
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

  private var mealTypePicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(RecipeMealType.allCases, id: \.self) { type in
          Button {
            withAnimation(.spring(response: 0.25)) {
              mealType = type
            }
          } label: {
            Text(type.title)
              .font(GainsFont.label(12))
              .foregroundStyle(mealType == type ? GainsColor.onLime : GainsColor.softInk)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(mealType == type ? GainsColor.lime : GainsColor.elevated)
              .clipShape(Capsule())
              .overlay(Capsule().stroke(GainsColor.border.opacity(0.5), lineWidth: 1))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 20)
    }
  }

  private var searchBar: some View {
    HStack(spacing: 10) {
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
    .padding(.horizontal, 14)
    .frame(height: 44)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous).stroke(GainsColor.border.opacity(0.6), lineWidth: 1))
  }

  private var categoryChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        categoryChip(nil, label: "Alle")
        ForEach(FoodCategory.allCases) { cat in
          categoryChip(cat, label: cat.title)
        }
      }
      .padding(.horizontal, 20)
    }
  }

  private func scanActionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(color)
        Text(label)
          .font(GainsFont.label(13))
          .foregroundStyle(GainsColor.ink)
        Spacer()
      }
      .padding(.horizontal, 14)
      .frame(height: 42)
      .frame(maxWidth: .infinity)
      .background(color.opacity(0.08))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(color.opacity(0.25), lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

  private func categoryChip(_ category: FoodCategory?, label: String) -> some View {
    let isSelected = selectedCategory == category
    return Button {
      withAnimation(.spring(response: 0.25)) {
        selectedCategory = category
      }
    } label: {
      Text(label)
        .font(GainsFont.label(11))
        .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.mutedInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? GainsColor.lime.opacity(0.18) : GainsColor.card)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(isSelected ? GainsColor.lime.opacity(0.4) : GainsColor.border.opacity(0.4), lineWidth: 1))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func foodRow(_ food: FoodItem) -> some View {
    Button {
      selectedFood = food
    } label: {
      HStack(spacing: 14) {
        Text(food.emoji)
          .font(.system(size: 26))
          .frame(width: 46, height: 46)
          .background(GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(food.name)
              .font(GainsFont.label(14))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            if let brand = food.brand, !brand.isEmpty {
              Text(brand)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(GainsColor.moss)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(GainsColor.lime.opacity(0.18))
                .clipShape(Capsule())
                .lineLimit(1)
            }
          }
          HStack(spacing: 8) {
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
              .foregroundStyle(Color(hex: "5BC4F5"))
            Text("F \(Int(food.fatPer100g))g")
              .font(GainsFont.label(10))
              .foregroundStyle(Color(hex: "FF8A4A"))
          }
        }

        Image(systemName: "plus.circle.fill")
          .font(.system(size: 24))
          .foregroundStyle(GainsColor.lime)
      }
      .padding(.vertical, 12)
    }
    .buttonStyle(.plain)

    Rectangle()
      .fill(GainsColor.border.opacity(0.4))
      .frame(height: 1)
  }

  private var emptySearchState: some View {
    VStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 36, weight: .light))
        .foregroundStyle(GainsColor.border)
      Text("Kein Ergebnis für \"\(searchText)\"")
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
      HStack(spacing: 10) {
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
      .padding(16)
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
          VStack(spacing: 20) {

            // Food header
            HStack(spacing: 16) {
              Text(food.emoji)
                .font(.system(size: 40))
                .frame(width: 72, height: 72)
                .background(GainsColor.elevated)
                .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))

              VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                  .font(GainsFont.title(20))
                  .foregroundStyle(GainsColor.ink)
                if let brand = food.brand, !brand.isEmpty {
                  Text(brand)
                    .font(GainsFont.label(11))
                    .foregroundStyle(GainsColor.moss)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(GainsColor.lime.opacity(0.18))
                    .clipShape(Capsule())
                }
                Text(food.category.title)
                  .font(GainsFont.label(11))
                  .foregroundStyle(GainsColor.mutedInk)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 4)
                  .background(GainsColor.elevated)
                  .clipShape(Capsule())
              }
              Spacer()
            }
            .padding(20)
            .gainsCardStyle(GainsColor.card)

            // Gram input
            VStack(alignment: .leading, spacing: 14) {
              Text("Menge")
                .font(GainsFont.label(13))
                .foregroundStyle(GainsColor.softInk)

              // Slider
              VStack(spacing: 10) {
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
              HStack(spacing: 10) {
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
                      .padding(.horizontal, 12)
                      .padding(.vertical, 8)
                      .background(Int(grams) == amount ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
                      .clipShape(Capsule())
                      .overlay(Capsule().stroke(Int(grams) == amount ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.4), lineWidth: 1))
                  }
                  .buttonStyle(.plain)
                }
              }
            }
            .padding(20)
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
                fat: n.fat
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
              .foregroundStyle(GainsColor.onLime)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(GainsColor.lime)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
            }
            .buttonStyle(.plain)
          }
          .padding(20)
          .padding(.bottom, 10)
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
    VStack(alignment: .leading, spacing: 14) {
      Text("Nährwerte für \(Int(grams))g")
        .font(GainsFont.label(13))
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: 0) {
        nutritionCell(value: "\(nutrition.calories)", unit: "kcal", label: "Kalorien", color: GainsColor.ink)
        Divider().frame(height: 40)
        nutritionCell(value: "\(nutrition.protein)g", unit: "", label: "Protein", color: GainsColor.lime)
        Divider().frame(height: 40)
        nutritionCell(value: "\(nutrition.carbs)g", unit: "", label: "Kohlenhydr.", color: Color(hex: "5BC4F5"))
        Divider().frame(height: 40)
        nutritionCell(value: "\(nutrition.fat)g", unit: "", label: "Fett", color: Color(hex: "FF8A4A"))
      }
      .animation(.spring(response: 0.4), value: Int(grams))
    }
    .padding(20)
    .gainsCardStyle(GainsColor.card)
  }

  private func nutritionCell(value: String, unit: String, label: String, color: Color) -> some View {
    VStack(spacing: 4) {
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
    VStack(alignment: .leading, spacing: 12) {
      Text("Mahlzeit")
        .font(GainsFont.label(13))
        .foregroundStyle(GainsColor.softInk)

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
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
    .padding(20)
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
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)

          // Step label
          Text("Schritt \(min(step + 1, totalSteps + 1)) von \(totalSteps + 1)")
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.mutedInk)
            .padding(.bottom, 20)

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
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 30)
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
        if let _ = existingProfile {
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
    VStack(spacing: 24) {
      wizardHeader(
        title: "Was ist dein biologisches Geschlecht?",
        subtitle: "Wird für die genaue Berechnung deines Grundumsatzes (BMR) benötigt."
      )
      HStack(spacing: 16) {
        ForEach(BiologicalSex.allCases, id: \.self) { s in
          sexCard(s)
        }
      }
      .padding(.horizontal, 24)
      Spacer()
    }
  }

  private func sexCard(_ s: BiologicalSex) -> some View {
    let isSelected = sex == s
    return Button {
      withAnimation(.spring(response: 0.3)) { sex = s }
    } label: {
      VStack(spacing: 16) {
        Text(s.emoji)
          .font(.system(size: 52))
        Text(s.title)
          .font(GainsFont.label(17))
          .foregroundStyle(GainsColor.ink)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 36)
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
    VStack(spacing: 24) {
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
    VStack(spacing: 24) {
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
    VStack(spacing: 24) {
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
    VStack(spacing: 24) {
      wizardHeader(
        title: "Kennst du deinen Körperfettanteil?",
        subtitle: "Optional: Gains berechnet dann deinen Grundumsatz nach Katch-McArdle (1975) – präziser für Athleten als Mifflin-St Jeor."
      )

      VStack(spacing: 12) {
        Button {
          withAnimation(.spring(response: 0.3)) { hasBodyFat.toggle() }
        } label: {
          HStack(spacing: 14) {
            Image(systemName: hasBodyFat ? "checkmark.circle.fill" : "circle")
              .font(.system(size: 22))
              .foregroundStyle(hasBodyFat ? GainsColor.lime : GainsColor.mutedInk)
            VStack(alignment: .leading, spacing: 3) {
              Text("Ja, ich kenne meinen KFA")
                .font(GainsFont.label(15))
                .foregroundStyle(GainsColor.ink)
              Text("Aktiviert die Katch-McArdle-Berechnung")
                .font(GainsFont.label(11))
                .foregroundStyle(GainsColor.softInk)
            }
            Spacer()
          }
          .padding(16)
          .background(hasBodyFat ? GainsColor.lime.opacity(0.06) : GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
              .stroke(hasBodyFat ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.5), lineWidth: 1.2)
          )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)

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
          .padding(.horizontal, 32)
      }

      Spacer()
    }
  }

  // MARK: Step 5 – Aktivitätslevel

  private var activityStep: some View {
    VStack(spacing: 20) {
      wizardHeader(
        title: "Wie aktiv bist du im Alltag?",
        subtitle: "Dieser Faktor multipliziert deinen Grundumsatz – sei möglichst ehrlich."
      )
      ScrollView(showsIndicators: false) {
        VStack(spacing: 10) {
          ForEach(ActivityLevel.allCases, id: \.self) { level in
            activityCard(level)
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
      }
    }
  }

  private func activityCard(_ level: ActivityLevel) -> some View {
    let isSelected = activityLevel == level
    return Button {
      withAnimation(.spring(response: 0.3)) { activityLevel = level }
    } label: {
      HStack(spacing: 14) {
        Image(systemName: level.systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.softInk)
          .frame(width: 44, height: 44)
          .background(isSelected ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        VStack(alignment: .leading, spacing: 3) {
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
      .padding(14)
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
    VStack(spacing: 20) {
      wizardHeader(
        title: "Was ist dein Ziel?",
        subtitle: "Bestimmt den Kalorienüberschuss oder das -defizit."
      )
      VStack(spacing: 10) {
        ForEach(NutritionGoal.allCases, id: \.self) { g in
          goalCard(g)
        }
      }
      .padding(.horizontal, 24)
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
      HStack(spacing: 14) {
        Image(systemName: g.systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.softInk)
          .frame(width: 44, height: 44)
          .background(isSelected ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        VStack(alignment: .leading, spacing: 3) {
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
      .padding(14)
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
    VStack(spacing: 20) {
      wizardHeader(
        title: goal == .muscleGain ? "Wie schnell willst du aufbauen?" : "Wie aggressiv willst du abnehmen?",
        subtitle: goal == .muscleGain
          ? "Mehr Überschuss = schnelleres Muskelwachstum, aber auch mehr Fettzunahme."
          : "Größeres Defizit = schnellerer Fettverlust, aber erhöhtes Muskelabbaurisiko."
      )
      ScrollView(showsIndicators: false) {
        VStack(spacing: 10) {
          ForEach(intensityOptions) { option in
            intensityCard(option)
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
      }
    }
  }

  private func intensityCard(_ option: IntensityOption) -> some View {
    let isSelected = surplusKcal == option.kcal
    return Button {
      withAnimation(.spring(response: 0.3)) { surplusKcal = option.kcal }
    } label: {
      HStack(spacing: 14) {
        Text(option.tag)
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.softInk)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(isSelected ? GainsColor.lime : GainsColor.elevated)
          .clipShape(Capsule())
          .frame(minWidth: 82, alignment: .center)

        VStack(alignment: .leading, spacing: 3) {
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
      .padding(14)
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
      VStack(spacing: 16) {
        wizardHeader(
          title: "Dein persönlicher Plan",
          subtitle: "Berechnet nach \(p.formulaUsed) und ISSN-Richtlinien (2022)."
        )

        // BMR / TDEE Card
        VStack(spacing: 12) {
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
            VStack(alignment: .leading, spacing: 3) {
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
              VStack(alignment: .leading, spacing: 3) {
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
                .foregroundStyle(change > 0 ? GainsColor.lime : Color(hex: "5BC4F5"))
            }
          }

          if let bf = p.bodyFatPercent {
            Divider().background(GainsColor.border)
            let leanMass = Double(p.weightKg) * (1.0 - bf / 100.0)
            summaryRow(label: "Körperfettanteil (KFA)", value: String(format: "%.0f %%", bf), color: GainsColor.softInk)
            summaryRow(label: "Lean Mass (berechnet)", value: String(format: "%.1f kg", leanMass), color: GainsColor.softInk)
          }
        }
        .padding(18)
        .gainsCardStyle(GainsColor.card)
        .padding(.horizontal, 24)

        // Makro Card
        VStack(spacing: 12) {
          Text("Tagesziel Makros")
            .font(GainsFont.label(13))
            .foregroundStyle(GainsColor.softInk)
            .frame(maxWidth: .infinity, alignment: .leading)

          HStack(spacing: 0) {
            summaryMacroCell("\(p.targetProteinG)g", label: "Protein",      color: GainsColor.lime)
            Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
            summaryMacroCell("\(p.targetCarbsG)g",   label: "Kohlenhydr.", color: Color(hex: "5BC4F5"))
            Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
            summaryMacroCell("\(p.targetFatG)g",     label: "Fett",         color: Color(hex: "FF8A4A"))
          }
        }
        .padding(18)
        .gainsCardStyle(GainsColor.card)
        .padding(.horizontal, 24)

        // Profil-Zusammenfassung
        VStack(spacing: 8) {
          profileSummaryChip("\(sex.title) · \(age) Jahre")
          profileSummaryChip("\(heightCm) cm · \(weightKg) kg\(hasBodyFat ? " · \(bodyFatInt) % KFA" : "")")
          profileSummaryChip(activityLevel.title)
          profileSummaryChip(p.formulaUsed)
        }
        .padding(.horizontal, 24)

        Text(p.bodyFatPercent != nil
          ? "Quellen: Katch & McArdle (1975) · Helms et al. (2014) IJSNEM · ISSN (2022)"
          : "Quellen: Mifflin et al. (1990) AJCN · Helms et al. (2014) IJSNEM · ISSN (2022)")
          .font(.system(size: 10))
          .foregroundStyle(GainsColor.mutedInk)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)

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
    VStack(spacing: 4) {
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
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
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
    VStack(spacing: 4) {
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
      .padding(.horizontal, 24)
    }
  }

  // MARK: Step Header

  private func wizardHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
      Text(subtitle)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 24)
  }

  // MARK: Navigation Buttons

  private var navigationButtons: some View {
    HStack(spacing: 12) {
      if step > 0 {
        Button {
          goingForward = false
          withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            // Beim Rückwärtsnavigieren vom Summary den Intensitäts-Schritt für "Maintain" überspringen
            step = (step == totalSteps && goal == .maintain) ? step - 2 : step - 1
          }
        } label: {
          HStack(spacing: 6) {
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
        HStack(spacing: 6) {
          Text(step == totalSteps ? "Ziele übernehmen" : "Weiter")
          Image(systemName: step == totalSteps ? "checkmark" : "chevron.right")
        }
        .font(GainsFont.label(15))
        .foregroundStyle(GainsColor.onLime)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .background(GainsColor.lime)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
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
        VStack(spacing: 16) {
          // Title
          fieldBlock(title: "Name der Mahlzeit") {
            TextField("z. B. Hähnchen mit Reis", text: $title)
              .focused($focusedField, equals: .title)
              .font(GainsFont.body(16))
              .foregroundStyle(GainsColor.ink)
              .padding(.horizontal, 16)
              .frame(height: 50)
              .background(GainsColor.elevated)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          }

          // Calories (required)
          fieldBlock(title: "Kalorien (kcal) *") {
            numericField("z.B. 450", text: $caloriesText, focus: .calories)
          }

          // Macros
          HStack(spacing: 12) {
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
          VStack(alignment: .leading, spacing: 10) {
            Text("Mahlzeit")
              .font(GainsFont.label(12))
              .foregroundStyle(GainsColor.softInk)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
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
              fat: Int(fatText) ?? 0
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
        .padding(20)
        .padding(.bottom, 20)
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
    VStack(alignment: .leading, spacing: 6) {
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
      .padding(.horizontal, 14)
      .frame(height: 50)
      .background(GainsColor.elevated)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous).stroke(GainsColor.border.opacity(0.5), lineWidth: 1))
  }
}
