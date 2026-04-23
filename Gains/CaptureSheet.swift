import SwiftUI

private enum MealCaptureSurface: String, CaseIterable, Identifiable {
  case recipes
  case manual

  var id: Self { self }

  var title: String {
    switch self {
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
  @State private var selectedMealSurface: MealCaptureSurface = .recipes
  @State private var recipeSearchText = ""
  @State private var selectedRecipeGoal: RecipeGoal?
  @State private var selectedRecipe: Recipe?
  @State private var mealTitle = ""
  @State private var mealType: RecipeMealType = .lunchDinner
  @State private var calories = ""
  @State private var protein = ""
  @State private var carbs = ""
  @State private var fat = ""

  init(initialKind: CaptureKind) {
    _selectedKind = State(initialValue: initialKind)
  }

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        screenHeader(
          eyebrow: "CAPTURE / GLOBAL",
          title: "Alles an einer Stelle",
          subtitle:
            "Workout, Lauf, Progress und Meal Log laufen ueber denselben Capture-Flow."
        )

        kindPicker
        autofillCard
        selectedContent
      }
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
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(CaptureKind.allCases) { kind in
          Button {
            selectedKind = kind
          } label: {
            HStack(spacing: 8) {
              Image(systemName: kind.systemImage)
                .font(.system(size: 13, weight: .semibold))

              Text(kind.title)
                .font(GainsFont.label(10))
                .tracking(1.4)
            }
            .foregroundStyle(selectedKind == kind ? GainsColor.onLime : GainsColor.softInk)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(selectedKind == kind ? GainsColor.lime : GainsColor.card)
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.vertical, 2)
    }
  }

  private var autofillCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["AUTO", "FILL"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.card.opacity(0.72))

      Text(autofillTitle)
        .font(GainsFont.title(26))
        .foregroundStyle(GainsColor.card)
        .lineLimit(2)

      Text(autofillSubtitle)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.card.opacity(0.78))
        .lineLimit(3)
    }
    .padding(20)
    .background(GainsColor.ink)
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
  }

  @ViewBuilder
  private var selectedContent: some View {
    switch selectedKind {
    case .workout:
      publishCard(
        title: store.lastCompletedWorkout?.title ?? store.currentWorkoutPreview.title,
        metrics: workoutMetrics,
        actionTitle: selectedKind.actionTitle
      ) {
        store.shareLatestWorkout()
        navigation.selectedTab = .community
        dismiss()
      }
    case .run:
      publishCard(
        title: store.latestCompletedRun?.title ?? "Cardio-Check-in",
        metrics: runMetrics,
        actionTitle: selectedKind.actionTitle
      ) {
        store.shareLatestRun()
        navigation.selectedTab = .community
        dismiss()
      }
    case .progress:
      publishCard(
        title: "Progress Update",
        metrics: [
          ("Gewicht", String(format: "%.1f kg", store.currentWeight)),
          ("Taille", String(format: "%.1f cm", store.waistMeasurement)),
          ("Risiko", "-\(store.currentCardioRiskImprovement)%"),
        ],
        actionTitle: selectedKind.actionTitle
      ) {
        store.shareProgressUpdate()
        navigation.selectedTab = .community
        dismiss()
      }
    case .meal:
      mealLogger
    }
  }

  private var mealLogger: some View {
    VStack(alignment: .leading, spacing: 16) {
      Picker("Meal Capture", selection: $selectedMealSurface) {
        ForEach(MealCaptureSurface.allCases) { surface in
          Text(surface.title).tag(surface)
        }
      }
      .pickerStyle(.segmented)
      .tint(GainsColor.lime)

      if selectedMealSurface == .recipes {
        recipeChooser
      }

      fieldBlock(title: "Name") {
        TextField("Zum Beispiel Chicken Rice Bowl", text: $mealTitle)
          .textInputAutocapitalization(.words)
          .padding(.horizontal, 16)
          .frame(height: 54)
          .gainsCardStyle()
      }

      fieldBlock(title: "Mahlzeit") {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(RecipeMealType.allCases, id: \.self) { currentType in
              Button {
                mealType = currentType
              } label: {
                Text(currentType.shortTitle)
                  .font(GainsFont.label(10))
                  .tracking(1.4)
                  .foregroundStyle(mealType == currentType ? GainsColor.onLime : GainsColor.softInk)
                  .padding(.horizontal, 14)
                  .frame(height: 36)
                  .background(mealType == currentType ? GainsColor.lime : GainsColor.card)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
        }
      }

      HStack(spacing: 10) {
        numberField(title: "kcal", text: $calories)
        numberField(title: "Protein", text: $protein)
      }

      HStack(spacing: 10) {
        numberField(title: "Carbs", text: $carbs)
        numberField(title: "Fett", text: $fat)
      }

      Button {
        store.logNutritionEntry(
          title: mealTitle,
          mealType: mealType,
          calories: Int(calories) ?? 0,
          protein: Int(protein) ?? 0,
          carbs: Int(carbs) ?? 0,
          fat: Int(fat) ?? 0
        )
        navigation.selectedTab = .recipes
        dismiss()
      } label: {
        Text(selectedKind.actionTitle)
          .font(GainsFont.label(12))
          .tracking(1.4)
          .foregroundStyle(GainsColor.onLime)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .background(GainsColor.lime)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      .opacity(mealTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
    }
  }

  private var recipeChooser: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
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
        }
      }
      .padding(.horizontal, 16)
      .frame(height: 50)
      .background(GainsColor.background.opacity(0.82))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
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

      VStack(spacing: 10) {
        ForEach(filteredRecipes.prefix(5)) { recipe in
          Button {
            fillMeal(from: recipe)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: recipe.placeholderSymbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(selectedRecipe?.id == recipe.id ? GainsColor.onLime : GainsColor.lime)
                .frame(width: 36, height: 36)
                .background(selectedRecipe?.id == recipe.id ? GainsColor.lime : GainsColor.ink)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

              VStack(alignment: .leading, spacing: 4) {
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
            .padding(12)
            .background(
              selectedRecipe?.id == recipe.id ? GainsColor.lime.opacity(0.16) : GainsColor.card
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(16)
    .gainsCardStyle(GainsColor.elevated)
  }

  private func publishCard(
    title: String,
    metrics: [(String, String)],
    actionTitle: String,
    action: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(title)
        .font(GainsFont.title(24))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)

      HStack(spacing: 10) {
        ForEach(metrics, id: \.0) { metric in
          VStack(alignment: .leading, spacing: 6) {
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
          .padding(12)
          .background(GainsColor.background.opacity(0.82))
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
      }

      Button(action: action) {
        Text(actionTitle)
          .font(GainsFont.label(12))
          .tracking(1.4)
          .foregroundStyle(GainsColor.onLime)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .background(GainsColor.lime)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func fieldBlock<Content: View>(title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 10) {
      Text(title.uppercased())
        .font(GainsFont.label(10))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      content()
    }
  }

  private func numberField(title: String, text: Binding<String>) -> some View {
    fieldBlock(title: title) {
      TextField("0", text: text)
        .keyboardType(.numberPad)
        .padding(.horizontal, 16)
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
        .padding(.horizontal, 14)
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
      return store.lastCompletedWorkout?.title ?? "\(store.currentWorkoutPreview.title) geplant"
    case .run:
      return store.latestCompletedRun?.title ?? "Letzten Lauf vorbereiten"
    case .progress:
      return String(format: "%.1f kg / %.1f cm", store.currentWeight, store.waistMeasurement)
    case .meal:
      return store.nutritionGoal.shortTitle
    }
  }

  private var autofillSubtitle: String {
    switch selectedKind {
    case .workout:
      return "Nutzt dein letztes beendetes Workout oder die heutige Session als Vorschlag."
    case .run:
      return "Distanz, Pace und Herzfrequenz kommen aus deinem letzten gespeicherten Lauf."
    case .progress:
      return "Gewicht, Taille und Health-Fortschritt werden als Update vorbereitet."
    case .meal:
      return "Freier Meal-Log mit Zielmodus, Kalorien und Makros."
    }
  }

  private var workoutMetrics: [(String, String)] {
    if let workout = store.lastCompletedWorkout {
      return [
        ("Volumen", "\(Int(workout.volume / 1000)) t"),
        ("Sätze", "\(workout.completedSets)"),
        ("Dauer", "\(store.plannerSettings.preferredSessionLength) Min"),
      ]
    }

    let plan = store.currentWorkoutPreview
    return [
      ("Übungen", "\(plan.exercises.count)"),
      ("Dauer", "\(store.plannerSettings.preferredSessionLength) Min"),
      ("Fokus", plan.focus),
    ]
  }

  private var runMetrics: [(String, String)] {
    guard let run = store.latestCompletedRun else {
      return [("Distanz", "5.0 km"), ("Pace", "5:35"), ("HF", "152")]
    }

    return [
      ("Distanz", String(format: "%.1f km", run.distanceKm)),
      ("Pace", paceLabel(run.averagePaceSeconds)),
      ("HF", "\(run.averageHeartRate)"),
    ]
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:--" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}
