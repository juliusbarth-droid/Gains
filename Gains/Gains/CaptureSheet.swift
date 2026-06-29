import PhotosUI
import SwiftUI

private enum MealCaptureSurface: String, CaseIterable, Identifiable {
  case photo
  case recipes
  case manual

  var id: Self { self }

  var title: String {
    switch self {
    case .photo:
      return "Foto"
    case .recipes:
      return "Rezept wählen"
    case .manual:
      return "Frei eingeben"
    }
  }
}

struct CaptureSheet: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore
  @Environment(\.dismiss) private var dismiss

  @State private var selectedKind: CaptureKind
  @State private var selectedMealSurface: MealCaptureSurface = .photo
  @State private var isShowingRunTracker = false
  @State private var isShowingWorkoutTracker = false
  @State private var recipeSearchText = ""
  @State private var isLogged = false
  @State private var selectedRecipeGoal: RecipeGoal?
  @State private var selectedRecipe: Recipe?
  @State private var mealPhotoItem: PhotosPickerItem?
  @State private var hasSelectedMealPhoto = false
  @State private var mealTitle = ""
  @State private var mealType: RecipeMealType = .lunch
  @State private var calories = ""
  @State private var protein = ""
  @State private var carbs = ""
  @State private var fat = ""

  init(initialKind: CaptureKind) {
    _selectedKind = State(initialValue: initialKind)
  }

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
        screenHeader(
          eyebrow: "CAPTURE / GLOBAL",
          title: "Alles an einer Stelle",
          subtitle:
            "Workout, Lauf, Progress und Meal Log laufen über denselben Capture-Flow."
        )

        kindPicker
        autofillCard
        selectedContent
      }
    }
    .sheet(isPresented: $isShowingRunTracker) {
      RunTrackerView()
        .environmentObject(store)
    }
    .fullScreenCover(isPresented: $isShowingWorkoutTracker) {
      WorkoutTrackerView()
        .environmentObject(store)
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Fertig") {
          dismiss()
        }
        .foregroundStyle(GainsColor.ink)
      }
    }
  }

  private var filteredRecipes: [Recipe] {
    store.recipes.filter { recipe in
      let matchesGoal = selectedRecipeGoal == nil || recipe.goal == selectedRecipeGoal
      let search = recipeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
      let matchesSearch =
        search.isEmpty
        || recipe.title.localizedCaseInsensitiveContains(search)
        || recipe.category.localizedCaseInsensitiveContains(search)
        || recipe.ingredients.joined(separator: " ").localizedCaseInsensitiveContains(search)
      return matchesGoal && matchesSearch
    }
  }

  private var kindPicker: some View {
    // 2026-05-14 (Polish-Loop 93): Kind-Picker im Glow-Pill-Stil —
    // aktive Pille mit Lime-Inner-Light + Glow, inaktive als Glas.
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: GainsSpacing.tight) {
        ForEach(CaptureKind.allCases) { kind in
          let isActive = selectedKind == kind
          Button {
            selectedKind = kind
          } label: {
            HStack(spacing: GainsSpacing.xsPlus) {
              Image(systemName: kind.systemImage)
                .font(.system(size: 13, weight: .semibold))

              Text(kind.title)
                .font(GainsFont.eyebrow)
                .tracking(GainsTracking.eyebrowTight)
            }
            .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.softInk)
            .padding(.horizontal, GainsSpacing.m)
            .frame(height: 38)
            .background(
              ZStack {
                Capsule().fill(isActive ? GainsColor.lime : GainsColor.card)
                if isActive {
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
              }
            )
            .overlay(
              Capsule().strokeBorder(
                isActive ? GainsColor.lime.opacity(0.0) : GainsColor.border.opacity(0.6),
                lineWidth: isActive ? 0 : 1
              )
            )
            .clipShape(Capsule())
            .compositingGroup()
            .shadow(color: isActive ? GainsColor.lime.opacity(0.32) : .clear, radius: 10)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.vertical, 2)
    }
  }

  private var autofillCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["AUTO", "FILL"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.onCtaSurface.opacity(0.72))

      Text(autofillTitle)
        .font(GainsFont.title(26))
        .foregroundStyle(GainsColor.onCtaSurface)
        .lineLimit(2)

      Text(autofillSubtitle)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.onCtaSurface.opacity(0.78))
        .lineLimit(3)
    }
    .padding(GainsSpacing.l)
    .background(GainsColor.ctaSurface)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
  }

  @ViewBuilder
  private var selectedContent: some View {
    switch selectedKind {
    case .workout:
      publishCard(
        title: autofillTitle,
        metrics: workoutMetrics,
        actionTitle: workoutActionTitle,
        isActionEnabled: canShareWorkout
      ) {
        store.shareLatestWorkout()
        if store.activeWorkout != nil {
          isShowingWorkoutTracker = true
        } else if store.activeRun != nil {
          isShowingRunTracker = true
        } else {
          dismiss()
          navigation.openHome()
        }
      }
    case .run:
      publishCard(
        title: autofillTitle,
        metrics: runMetrics,
        actionTitle: runActionTitle,
        isActionEnabled: canShareRun
      ) {
        store.shareLatestRun()
        if store.activeWorkout != nil {
          isShowingWorkoutTracker = true
        } else if store.activeRun != nil {
          isShowingRunTracker = true
        } else {
          dismiss()
          navigation.openTraining(workspace: .laufen)
        }
      }
    case .progress:
      publishCard(
        title: autofillTitle,
        metrics: [
          ("Gewicht", String(format: "%.1f kg", store.currentWeight)),
          ("Taille", String(format: "%.1f cm", store.waistMeasurement)),
          ("Risiko", "-\(store.currentCardioRiskImprovement)%"),
        ],
        actionTitle: selectedKind.actionTitle,
        isActionEnabled: true
      ) {
        store.shareProgressUpdate()
        // Fortschritt-Tab existiert nicht mehr — Home zeigt den
        // aufklappbaren Fortschritts-Bereich.
        dismiss()
        navigation.openHome()
      }
    case .meal:
      mealLogger
    }
  }

  private var mealLogger: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      Picker("Meal Capture", selection: $selectedMealSurface) {
        ForEach(MealCaptureSurface.allCases) { surface in
          Text(surface.title).tag(surface)
        }
      }
      .pickerStyle(.segmented)
      .tint(GainsColor.lime)

      if selectedMealSurface == .photo {
        photoMealCapture
      }

      if selectedMealSurface == .recipes {
        recipeChooser
      }

      fieldBlock(title: "Name") {
        TextField("z. B. Mittagessen", text: $mealTitle)
          .textInputAutocapitalization(.words)
          .padding(.horizontal, GainsSpacing.m)
          .frame(height: 54)
          .gainsCardStyle()
      }

      fieldBlock(title: "Mahlzeit") {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: GainsSpacing.tight) {
            ForEach(RecipeMealType.allCases, id: \.self) { currentType in
              Button {
                mealType = currentType
              } label: {
                Text(currentType.shortTitle)
                  .font(GainsFont.label(10))
                  .tracking(1.4)
                  .foregroundStyle(mealType == currentType ? GainsColor.onLime : GainsColor.softInk)
                  .padding(.horizontal, GainsSpacing.m)
                  .frame(height: 36)
                  .background(mealType == currentType ? GainsColor.lime : GainsColor.card)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
        }
      }

      HStack(spacing: GainsSpacing.tight) {
        numberField(title: "kcal", text: $calories)
        numberField(title: "Protein", text: $protein)
      }

      HStack(spacing: GainsSpacing.tight) {
        numberField(title: "Carbs", text: $carbs)
        numberField(title: "Fett", text: $fat)
      }

      Button {
        guard !isLogged else { return }
        isLogged = true
        store.logNutritionEntry(
          title: mealTitle,
          mealType: mealType,
          calories: Int(calories) ?? 0,
          protein: Int(protein) ?? 0,
          carbs: Int(carbs) ?? 0,
          fat: Int(fat) ?? 0
        )
        navigation.openNutrition()
        dismiss()
      } label: {
        Text(selectedKind.actionTitle)
          .font(GainsFont.label(12))
          .tracking(1.4)
          .foregroundStyle(GainsColor.ink)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .gainsGlassCTA()
      }
      .buttonStyle(.plain)
      .disabled(mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (selectedMealSurface == .photo && !hasSelectedMealPhoto))
      .opacity(mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (selectedMealSurface == .photo && !hasSelectedMealPhoto) ? 0.5 : 1)
    }
  }

  private var photoMealCapture: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      fieldBlock(title: "Meal-Foto") {
        VStack(alignment: .leading, spacing: GainsSpacing.s) {
          PhotosPicker(selection: $mealPhotoItem, matching: .images) {
            HStack(spacing: GainsSpacing.tight) {
              Image(systemName: hasSelectedMealPhoto ? "photo.fill" : "camera.fill")
                .font(.system(size: 14, weight: .semibold))
              Text(hasSelectedMealPhoto ? "Foto wechseln" : "Essensfoto wählen")
                .font(GainsFont.label(11))
                .tracking(GainsTracking.eyebrowTight)
              Spacer()
            }
            .foregroundStyle(GainsColor.ink)
            .padding(.horizontal, GainsSpacing.m)
            .frame(height: 52)
            .gainsCardStyle(GainsColor.elevated)
          }
          .buttonStyle(.plain)

          Text(hasSelectedMealPhoto ? "Foto ausgewählt. Trage jetzt Kalorien und Makros direkt darunter ein." : "Wähle ein Foto von deinem Essen, dann kannst du die Kalorien sofort aus dem Bild heraus loggen.")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(3)

          HStack(spacing: GainsSpacing.xsPlus) {
            quickMacroPreset(title: "Snack", calories: 250, protein: 15, carbs: 22, fat: 8)
            quickMacroPreset(title: "Meal",  calories: 550, protein: 35, carbs: 50, fat: 15)
            quickMacroPreset(title: "Groß",  calories: 850, protein: 45, carbs: 90, fat: 28)
          }
        }
      }
    }
    .onChange(of: mealPhotoItem) { _, newItem in
      hasSelectedMealPhoto = newItem != nil
      if mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, newItem != nil {
        mealTitle = "Foto-Meal"
      }
    }
  }

  private func quickMacroPreset(title: String, calories: Int, protein: Int, carbs: Int, fat: Int) -> some View {
    Button {
      if mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        mealTitle = title == "Meal" ? "Foto-Meal" : "Foto-Meal \(title)"
      }
      self.calories = "\(calories)"
      self.protein = "\(protein)"
      self.carbs    = "\(carbs)"
      self.fat      = "\(fat)"
    } label: {
      Text(title)
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrowTight)
        .foregroundStyle(GainsColor.onLime)
        .padding(.horizontal, GainsSpacing.s)
        .frame(height: 34)
        .background(GainsColor.lime)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private var recipeChooser: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(spacing: GainsSpacing.s) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(GainsColor.softInk)

        TextField("Rezept suchen", text: $recipeSearchText)
          .textInputAutocapitalization(.words)

        if !recipeSearchText.isEmpty {
          Button {
            recipeSearchText = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(GainsColor.softInk)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Suche leeren")
        }
      }
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 50)
      .background(GainsColor.background.opacity(0.82))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.tight) {
          filterChip(title: "Alle", isSelected: selectedRecipeGoal == nil) {
            selectedRecipeGoal = nil
          }

          ForEach(RecipeGoal.allCases, id: \.self) { goal in
            filterChip(title: goal.title, isSelected: selectedRecipeGoal == goal) {
              selectedRecipeGoal = goal
            }
          }
        }
      }

      VStack(spacing: GainsSpacing.tight) {
        ForEach(filteredRecipes.prefix(5)) { recipe in
          Button {
            fillMeal(from: recipe)
          } label: {
            HStack(spacing: GainsSpacing.s) {
              Image(systemName: recipe.placeholderSymbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(selectedRecipe?.id == recipe.id ? GainsColor.onLime : GainsColor.lime)
                .frame(width: 36, height: 36)
                .background(selectedRecipe?.id == recipe.id ? GainsColor.lime : GainsColor.ctaSurface)
                .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

              VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
                Text(recipe.title)
                  .font(GainsFont.title(16))
                  .foregroundStyle(GainsColor.ink)
                  .lineLimit(1)

                Text("\(recipe.calories) kcal · \(recipe.protein)g Protein · \(recipe.prepMinutes) Min")
                  .font(GainsFont.body(12))
                  .foregroundStyle(GainsColor.softInk)
                  .lineLimit(1)
              }

              Spacer()

              if selectedRecipe?.id == recipe.id {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundStyle(GainsColor.lime)
              }
            }
            .padding(GainsSpacing.s)
            .background(
              selectedRecipe?.id == recipe.id ? GainsColor.lime.opacity(0.16) : GainsColor.card
            )
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle(GainsColor.elevated)
  }

  private var canShareWorkout: Bool {
    store.lastCompletedWorkout != nil || store.todayPlannedWorkout != nil
  }

  private var canShareRun: Bool {
    store.latestCompletedRun != nil
      || store.todayPlannedDay.runTemplate != nil
      || store.todayPlannedDay.sessionKind?.isRun == true
  }

  private var workoutActionTitle: String {
    if store.lastCompletedWorkout != nil {
      return "Workout teilen"
    }
    if store.todayPlannedWorkout != nil {
      return "Workout vorbereiten"
    }
    return "Workout nicht verfügbar"
  }

  private var runActionTitle: String {
    if store.latestCompletedRun != nil {
      return "Lauf teilen"
    }
    if store.todayPlannedDay.runTemplate != nil || store.todayPlannedDay.sessionKind?.isRun == true {
      return "Run vorbereiten"
    }
    return "Run nicht verfügbar"
  }

  private func publishCard(
    title: String,
    metrics: [(String, String)],
    actionTitle: String,
    isActionEnabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    let actionHint: String = {
      if isActionEnabled {
        return "Öffnet den nächsten Schritt für diesen Beitrag."
      }
      return "Nicht verfügbar, solange keine passende Einheit oder kein passender Verlauf vorliegt."
    }()

    return VStack(alignment: .leading, spacing: GainsSpacing.m) {
      Text(title)
        .font(GainsFont.title(24))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)

      HStack(spacing: GainsSpacing.tight) {
        ForEach(metrics, id: \.0) { metric in
          VStack(alignment: .leading, spacing: GainsSpacing.xs) {
            Text(metric.0.uppercased())
              .font(GainsFont.label(9))
              .tracking(1.7)
              .foregroundStyle(GainsColor.softInk)

            Text(metric.1)
              .font(GainsFont.title(17))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
              .minimumScaleFactor(0.75)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(GainsSpacing.s)
          .background(GainsColor.background.opacity(0.82))
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        }
      }

      Button(action: action) {
        Text(actionTitle)
          .font(GainsFont.label(12))
          .tracking(1.4)
          .foregroundStyle(GainsColor.ink)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .gainsGlassCTA()
      }
      .buttonStyle(.plain)
      .accessibilityHint(actionHint)
      .disabled(!isActionEnabled)
      .opacity(isActionEnabled ? 1 : 0.5)
    }
    .padding(GainsSpacing.l)
    .gainsCardStyle()
  }

  private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      Text(title.uppercased())
        .font(GainsFont.label(10))
        .tracking(GainsTracking.eyebrowWide)
        .foregroundStyle(GainsColor.softInk)

      content()
    }
  }

  private func numberField(title: String, text: Binding<String>) -> some View {
    fieldBlock(title: title) {
      TextField("0", text: text)
        .keyboardType(.numberPad)
        .padding(.horizontal, GainsSpacing.m)
        .frame(height: 54)
        .gainsCardStyle()
    }
    .frame(maxWidth: .infinity)
  }

  private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Text(title)
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.softInk)
        .padding(.horizontal, GainsSpacing.m)
        .frame(height: 34)
        .background(isSelected ? GainsColor.lime : GainsColor.card)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private func fillMeal(from recipe: Recipe) {
    selectedRecipe = recipe
    selectedMealSurface = .manual
    mealTitle = recipe.title
    mealType = recipe.mealType
    calories = "\(recipe.calories)"
    protein = "\(recipe.protein)"
    carbs = "\(recipe.carbs)"
    fat = "\(recipe.fat)"
  }

  private var autofillTitle: String {
    switch selectedKind {
    case .workout:
      return store.lastCompletedWorkout?.title ?? store.todayPlannedWorkout?.title ?? "Workout nicht verfügbar"
    case .run:
      if let latestRun = store.latestCompletedRun {
        return latestRun.title
      }
      if let plannedRun = store.todayPlannedDay.runTemplate {
        return plannedRun.title
      }
      if store.todayPlannedDay.sessionKind?.isRun == true {
        return "Run vorbereiten"
      }
      return "Run nicht verfügbar"
    case .progress:
      return String(format: "%.1f kg / %.1f cm", store.currentWeight, store.waistMeasurement)
    case .meal:
      return store.nutritionGoal.shortTitle
    }
  }

  private var autofillSubtitle: String {
    switch selectedKind {
    case .workout:
      if store.lastCompletedWorkout != nil {
        return "Nutzt dein letztes beendetes Workout als Vorschlag."
      }
      if store.todayPlannedWorkout != nil {
        return "Nutzt dein heutiges geplantes Workout als Vorschlag."
      }
      return "Aktuell ist kein konkretes Workout verfügbar."
    case .run:
      if store.latestCompletedRun != nil {
        return "Distanz, Pace und Herzfrequenz kommen aus deinem letzten gespeicherten Lauf."
      }
      if store.todayPlannedDay.runTemplate != nil || store.todayPlannedDay.sessionKind?.isRun == true {
        return "Nutzt deinen heutigen geplanten Run als Vorschlag."
      }
      return "Aktuell ist kein konkreter Run verfügbar."
    case .progress:
      return "Gewicht, Taille und Health-Fortschritt werden als Update vorbereitet."
    case .meal:
      return "Freier Meal-Log mit Zielmodus, Kalorien und Makros."
    }
  }

  private var workoutMetrics: [(String, String)] {
    if let workout = store.lastCompletedWorkout {
      return [
        ("Volumen", "\(String(format: "%.1f t", workout.volume / 1000))"),
        ("Sätze", "\(workout.completedSets)"),
        ("Übungen", "\(workout.exercises.count)"),
      ]
    }

    if let plan = store.todayPlannedWorkout {
      return [
        ("Übungen", "\(plan.exercises.count)"),
        ("Dauer", "\(plan.estimatedDurationMinutes) Min"),
        ("Fokus", plan.focus),
      ]
    }

    return [
      ("Status", "Kein Workout"),
      ("Heute", "Nicht geplant"),
      ("Aktion", "Nicht verfügbar"),
    ]
  }

  private var runMetrics: [(String, String)] {
    if let run = store.latestCompletedRun {
      return [
        ("Distanz", String(format: "%.1f km", run.distanceKm)),
        ("Pace", "\(paceLabel(run.averagePaceSeconds))/km"),
        ("HF", "\(run.averageHeartRate) bpm"),
      ]
    }

    if let plannedRun = store.todayPlannedDay.runTemplate {
      return [
        ("Distanz", String(format: "%.1f km", plannedRun.targetDistanceKm)),
        ("Dauer", "\(plannedRun.targetDurationMinutes) Min"),
        ("Pace", plannedRun.targetPaceLabel),
      ]
    }

    return [
      ("Status", "Kein Run"),
      ("Heute", "Nicht geplant"),
      ("Aktion", "Nicht verfügbar"),
    ]
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:--" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
