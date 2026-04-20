import SwiftUI

struct RecipesView: View {
  @EnvironmentObject private var store: GainsStore
  let viewModel: RecipesViewModel
  @State private var searchText = ""
  @State private var ingredientText = ""
  @State private var selectedGoal: RecipeGoal?
  @State private var selectedDietaryStyle: RecipeDietaryStyle = .all
  @State private var selectedMealType: RecipeMealType?
  @State private var maxPrepMinutes = 180.0
  @State private var maxCalories = 1600.0
  @State private var showsFavoritesOnly = false
  @State private var showsFilterSheet = false
  @State private var showsIngredientFilter = false
  @State private var showsDiscoveryTools = false
  @State private var showsManualEntrySheet = false
  @State private var pendingMealType: RecipeMealType = .breakfast

  var body: some View {
    NavigationStack {
      GainsScreen {
        VStack(alignment: .leading, spacing: 22) {
          screenHeader(
            eyebrow: "ERNÄHRUNG / TRACKER",
            title: "Essen tracken",
            subtitle: "Dein Tagesziel zuerst, Rezepte und Suche direkt darunter."
          )

          nutritionGoalSection
          nutritionOverviewSection
          mealTrackerSection
          nutritionActionsSection
          discoveryEntryCard

          if showsDiscoveryTools || activeFilterCount > 0
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          {
            recipesListIntro
            featuredRecipesSection
            goalFocusSection
            searchSection
            summarySection
            activeFiltersSection
            categorySection

            if (showsDiscoveryTools && showsIngredientFilter)
              || !ingredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
              ingredientSection
            }

            if filteredRecipes.isEmpty {
              emptyState
            } else {
              ForEach(filteredRecipes) { recipe in
                recipeTrackingCard(recipe)
              }
            }
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $showsFilterSheet) {
        NavigationStack {
          RecipeFilterSheet(
            selectedDietaryStyle: $selectedDietaryStyle,
            selectedMealType: $selectedMealType,
            maxPrepMinutes: $maxPrepMinutes,
            maxCalories: $maxCalories,
            onReset: resetAllFilters
          )
        }
        .presentationDetents([.large])
      }
      .sheet(isPresented: $showsManualEntrySheet) {
        NavigationStack {
          NutritionEntrySheet(defaultMealType: pendingMealType)
            .environmentObject(store)
        }
        .presentationDetents([.large])
      }
    }
  }

  private var featuredRecipes: [Recipe] {
    Array(filteredRecipes.prefix(3))
  }

  private var filteredRecipes: [Recipe] {
    store.recipes.filter { recipe in
      let matchesGoal = selectedGoal == nil || recipe.goal == selectedGoal
      let matchesFavorites = !showsFavoritesOnly || store.favoriteRecipeIDs.contains(recipe.id)
      let matchesDietaryStyle =
        selectedDietaryStyle == .all || recipe.dietaryStyle == selectedDietaryStyle
      let matchesMealType = selectedMealType == nil || recipe.mealType == selectedMealType
      let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
      let ingredientSearch = ingredientText.trimmingCharacters(in: .whitespacesAndNewlines)
      let matchesSearch =
        search.isEmpty
        || recipe.title.localizedCaseInsensitiveContains(search)
        || recipe.category.localizedCaseInsensitiveContains(search)
        || recipe.goal.title.localizedCaseInsensitiveContains(search)
        || recipe.ingredients.joined(separator: " ").localizedCaseInsensitiveContains(search)
      let matchesIngredients =
        ingredientSearch.isEmpty
        || recipe.ingredients.joined(separator: " ").localizedCaseInsensitiveContains(
          ingredientSearch)
      let matchesPrep = Double(recipe.prepMinutes) <= maxPrepMinutes
      let matchesCalories = Double(recipe.calories) <= maxCalories
      return matchesGoal && matchesSearch && matchesFavorites && matchesIngredients
        && matchesDietaryStyle && matchesMealType && matchesPrep && matchesCalories
    }
  }

  private var featuredRecipesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TRACKEN", "MIT REZEPTEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if featuredRecipes.isEmpty {
        emptyState
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(featuredRecipes) { recipe in
              NavigationLink {
                RecipeDetailView(recipe: recipe)
                  .environmentObject(store)
              } label: {
                featuredRecipeCard(recipe)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.vertical, 2)
        }
      }
    }
  }

  private var nutritionOverviewSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["HEUTE", "IM BLICK"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Tagesbedarf")
            .font(GainsFont.title(28))
            .foregroundStyle(GainsColor.ink)

          Text(store.nutritionGoalHeadline)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
        }

        VStack(spacing: 12) {
          primaryNutritionCard
          secondaryNeedCard
        }

        VStack(alignment: .leading, spacing: 10) {
          Text("Makros heute")
            .font(GainsFont.label(10))
            .tracking(1.8)
            .foregroundStyle(GainsColor.softInk)

          LazyVGrid(
            columns: [
              GridItem(.flexible(), spacing: 10),
              GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
          ) {
            macroProgressCard(
              title: "Protein",
              current: store.nutritionProteinToday,
              target: store.nutritionTargetProtein,
              accent: Color(hex: "9FD3B0"),
              unit: "g"
            )
            macroProgressCard(
              title: "Carbs",
              current: store.nutritionCarbsToday,
              target: store.nutritionTargetCarbs,
              accent: Color(hex: "E3B96C"),
              unit: "g"
            )
            macroProgressCard(
              title: "Fett",
              current: store.nutritionFatToday,
              target: store.nutritionTargetFat,
              accent: Color(hex: "C3B3FF"),
              unit: "g"
            )
          }
        }
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var nutritionGoalSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["ZIEL", "WÄHLEN"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      Text("Ernährungsziel")
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)

      VStack(spacing: 10) {
        ForEach(NutritionGoal.allCases, id: \.self) { goal in
          Button {
            store.setNutritionGoal(goal)
          } label: {
            HStack(alignment: .top, spacing: 14) {
              Image(systemName: goal.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(store.nutritionGoal == goal ? GainsColor.moss : GainsColor.lime)
                .frame(width: 28, height: 28)

              VStack(alignment: .leading, spacing: 6) {
                Text(goal.title)
                  .font(GainsFont.title(18))
                  .foregroundStyle(GainsColor.ink)

                Text(goal.detail)
                  .font(GainsFont.body(13))
                  .foregroundStyle(GainsColor.softInk)
                  .lineLimit(3)
              }

              Spacer()

              if store.nutritionGoal == goal {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundStyle(GainsColor.lime)
              }
            }
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .padding(16)
            .background(
              store.nutritionGoal == goal ? GainsColor.lime.opacity(0.16) : GainsColor.elevated
            )
            .overlay {
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                  store.nutritionGoal == goal ? GainsColor.lime : GainsColor.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var primaryNutritionCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("KALORIEN")
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("\(store.nutritionCaloriesToday)")
          .font(GainsFont.title(34))
          .foregroundStyle(GainsColor.ink)

        Text("/ \(store.nutritionTargetCalories)")
          .font(GainsFont.body(15))
          .foregroundStyle(GainsColor.softInk)
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.background.opacity(0.85))

          Capsule()
            .fill(GainsColor.lime)
            .frame(
              width: proxy.size.width
                * progressValue(
                  current: store.nutritionCaloriesToday, target: store.nutritionTargetCalories))
        }
      }
      .frame(height: 8)

      Text(store.nutritionProgressHeadline)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
        .lineSpacing(2)
    }
    .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
    .padding(16)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  private var secondaryNeedCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("NOCH OFFEN")
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text("\(max(store.nutritionTargetCalories - store.nutritionCaloriesToday, 0)) kcal")
        .font(GainsFont.title(24))
        .foregroundStyle(GainsColor.ink)

      Text("\(max(store.nutritionTargetProtein - store.nutritionProteinToday, 0))g Protein")
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .lineSpacing(2)

      Spacer()

      Button {
        pendingMealType = .lunchDinner
        showsManualEntrySheet = true
      } label: {
        Text("Jetzt erfassen")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.moss)
          .frame(maxWidth: .infinity)
          .frame(height: 38)
          .background(GainsColor.lime)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
    .padding(16)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
  }

  private var mealTrackerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["MAHLZEITEN", "HEUTE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ForEach(RecipeMealType.allCases, id: \.self) { mealType in
        mealTrackerCard(mealType)
      }
    }
  }

  private var nutritionActionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TOOLS", "OPTIONAL"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(spacing: 10) {
        Button {
          pendingMealType = .breakfast
          showsManualEntrySheet = true
        } label: {
          quickActionCard(
            title: "Mahlzeit hinzufügen",
            subtitle: "Direkt Essen und Makros eintragen",
            symbol: "plus.circle.fill"
          )
        }
        .buttonStyle(.plain)

        Button {
          showsDiscoveryTools = true
        } label: {
          quickActionCard(
            title: "Rezepte durchsuchen",
            subtitle: "Nur wenn du Inspiration brauchst",
            symbol: "fork.knife.circle.fill"
          )
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var goalFocusSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["ZIELE", "AUSWÄHLEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          filterChip(title: "Alle Rezepte", isSelected: selectedGoal == nil) {
            selectedGoal = nil
          }

          ForEach(RecipeGoal.allCases, id: \.self) { goal in
            filterChip(title: goal.title, isSelected: selectedGoal == goal) {
              selectedGoal = goal
            }
          }
        }
        .padding(.vertical, 2)
      }
    }
  }

  private var discoveryEntryCard: some View {
    Button {
      showsDiscoveryTools.toggle()
    } label: {
      HStack(spacing: 14) {
        Text("Rezepte und Filter")
          .font(GainsFont.title(20))
          .foregroundStyle(GainsColor.ink)

        Spacer()

        if showsDiscoveryTools {
          Image(systemName: "chevron.up.circle.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(GainsColor.moss)
        } else {
          GainsDisclosureIndicator()
        }
      }
      .padding(18)
      .gainsInteractiveCardStyle()
    }
    .buttonStyle(.plain)
  }

  private var summarySection: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10)
    {
      Button {
        resetAllFilters()
      } label: {
        recipeSummaryCard(title: "Rezepte", value: "\(store.recipes.count)", subtitle: "verfügbar")
      }
      .buttonStyle(.plain)

      Button {
        showsIngredientFilter.toggle()
      } label: {
        recipeSummaryCard(
          title: "Zutaten", value: ingredientText.isEmpty ? "Aus" : "Aktiv", subtitle: "eingrenzen")
      }
      .buttonStyle(.plain)

      Button {
        showsFilterSheet = true
      } label: {
        recipeSummaryCard(
          title: "Filter", value: "\(activeFilterCount)", subtitle: activeFilterLabel)
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  private var activeFiltersSection: some View {
    if activeFilterCount > 0 {
      VStack(alignment: .leading, spacing: 12) {
        SlashLabel(
          parts: ["FILTER", "AKTIV"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            if let selectedGoal {
              activeFilterChip(selectedGoal.title)
            }

            if selectedDietaryStyle != .all {
              activeFilterChip(selectedDietaryStyle.title)
            }

            if let selectedMealType {
              activeFilterChip(selectedMealType.title)
            }

            if showsFavoritesOnly {
              activeFilterChip("Favoriten")
            }

            if maxPrepMinutes < 180 {
              activeFilterChip("Bis \(Int(maxPrepMinutes)) Min")
            }

            if maxCalories < 1600 {
              activeFilterChip("Bis \(Int(maxCalories)) kcal")
            }

            if !ingredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              activeFilterChip("Zutaten")
            }
          }
          .padding(.vertical, 2)
        }
      }
    }
  }

  private var searchSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Schnell das passende Rezept finden")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)

        HStack(spacing: 12) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(GainsColor.softInk)

          TextField("Nach Rezepten suchen", text: $searchText)
            .textInputAutocapitalization(.words)

          Button {
            if !searchText.isEmpty {
              searchText = ""
            } else {
              showsFilterSheet = true
            }
          } label: {
            Image(systemName: searchText.isEmpty ? "slider.horizontal.3" : "xmark.circle.fill")
              .foregroundStyle(GainsColor.softInk)
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(GainsColor.background.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

        Text("\(filteredRecipes.count) passende Rezepte")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var ingredientSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["INHALTE", "ZUTATEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      HStack(spacing: 12) {
        Image(systemName: "carrot.fill")
          .foregroundStyle(GainsColor.softInk)

        TextField("Nach Zutaten filtern, z. B. Hähnchen oder Reis", text: $ingredientText)
          .textInputAutocapitalization(.words)

        if !ingredientText.isEmpty {
          Button {
            ingredientText = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(GainsColor.softInk)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 16)
      .frame(height: 54)
      .gainsCardStyle()
    }
  }

  private var categorySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["MEHR", "FILTER"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          filterChip(title: "Favoriten", isSelected: showsFavoritesOnly) {
            showsFavoritesOnly.toggle()
          }

          filterChip(title: "Zutaten", isSelected: showsIngredientFilter || !ingredientText.isEmpty)
          {
            showsIngredientFilter.toggle()
          }
        }
        .padding(.vertical, 2)
      }
    }
  }

  private var recipesListIntro: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text("Rezepte zum Tracken")
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)

        Text("\(filteredRecipes.count) passende Meals für deine Ziele")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()
    }
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Keine Rezepte gefunden")
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)

      Text("Passe die Suche oder die Kategorie an, um mehr passende Meals zu sehen.")
        .font(GainsFont.body())
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .gainsCardStyle()
  }

  private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Text(title)
        .font(GainsFont.label(10))
        .tracking(1.5)
        .foregroundStyle(isSelected ? GainsColor.ink : GainsColor.softInk)
        .padding(.horizontal, 16)
        .frame(height: 38)
        .background(isSelected ? GainsColor.lime : GainsColor.card)
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private func activeFilterChip(_ title: String) -> some View {
    Text(title)
      .font(GainsFont.label(10))
      .tracking(1.4)
      .foregroundStyle(GainsColor.moss)
      .padding(.horizontal, 14)
      .frame(height: 34)
      .background(GainsColor.lime.opacity(0.25))
      .clipShape(Capsule())
  }

  private func recipeSummaryCard(title: String, value: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)

      Text(subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .gainsCardStyle()
  }

  private func macroProgressCard(
    title: String, current: Int, target: Int, accent: Color, unit: String
  ) -> some View {
    let progress = progressValue(current: current, target: target)

    return VStack(alignment: .leading, spacing: 10) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text("\(current)\(unit)")
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.background.opacity(0.85))

          Capsule()
            .fill(accent)
            .frame(width: proxy.size.width * progress)
        }
      }
      .frame(height: 6)

      Text("Ziel \(target)\(unit)")
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
  }

  private func mealTrackerCard(_ mealType: RecipeMealType) -> some View {
    let entries = store.nutritionEntries(for: mealType)
    let calories = entries.reduce(0) { $0 + $1.calories }
    let protein = entries.reduce(0) { $0 + $1.protein }

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            Image(systemName: mealType.systemImage)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(GainsColor.lime)

            Text(mealType.shortTitle)
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.ink)
          }

          Text(
            entries.isEmpty
              ? "Noch nichts erfasst"
              : "\(entries.count) Einträge · \(calories) kcal · \(protein)g Protein"
          )
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        }

        Spacer()

        Button {
          pendingMealType = mealType
          showsManualEntrySheet = true
        } label: {
          Text("Hinzufügen")
            .font(GainsFont.label(10))
            .tracking(1.4)
            .foregroundStyle(GainsColor.moss)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(GainsColor.lime)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }

      if entries.isEmpty {
        Text(
          "Füge hier dein \(mealType.shortTitle.lowercased()) hinzu oder logge ein Rezept direkt darunter."
        )
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
      } else {
        ForEach(entries.prefix(3)) { entry in
          HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
              Text(entry.title)
                .font(GainsFont.body(14))
                .foregroundStyle(GainsColor.ink)

              Text(
                "\(entry.calories) kcal · \(entry.protein)g Protein · \(formattedLoggedTime(entry.loggedAt))"
              )
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.softInk)
            }

            Spacer()

            Button {
              store.removeNutritionEntry(entry.id)
            } label: {
              Image(systemName: "minus.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(GainsColor.softInk)
            }
            .buttonStyle(.plain)
          }
          .padding(12)
          .background(GainsColor.background.opacity(0.8))
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
      }
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func quickActionCard(title: String, subtitle: String, symbol: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: symbol)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 42, height: 42)
        .background(GainsColor.background.opacity(0.9))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(GainsFont.title(17))
          .foregroundStyle(GainsColor.ink)

        Text(subtitle)
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
          .lineSpacing(2)
      }

      Spacer()

      GainsDisclosureIndicator()
    }
    .padding(16)
    .gainsInteractiveCardStyle()
  }

  private func recipeTrackingCard(_ recipe: Recipe) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      NavigationLink {
        RecipeDetailView(recipe: recipe)
          .environmentObject(store)
      } label: {
        RecipeCard(recipe: recipe)
          .environmentObject(store)
      }
      .buttonStyle(.plain)

      Button {
        store.logRecipe(recipe)
      } label: {
        HStack {
          Image(systemName: "plus.circle.fill")
            .foregroundStyle(GainsColor.lime)

          Text("Als Mahlzeit tracken")
            .font(GainsFont.label(11))
            .tracking(1.3)
            .foregroundStyle(GainsColor.ink)

          Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .gainsInteractiveCardStyle()
      }
      .buttonStyle(.plain)
    }
  }

  private func featuredRecipeCard(_ recipe: Recipe) -> some View {
    ZStack(alignment: .bottomLeading) {
      AsyncImage(url: URL(string: recipe.imageURL)) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
              LinearGradient(
                colors: [featuredAccentColor(for: recipe.goal), GainsColor.ink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .overlay {
              Image(systemName: recipe.placeholderSymbol)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(GainsColor.card)
            }
        }
      }
      .frame(width: 268, height: 220)
      .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

      LinearGradient(
        colors: [Color.clear, GainsColor.ink.opacity(0.78)],
        startPoint: .center,
        endPoint: .bottom
      )
      .frame(width: 268, height: 220)
      .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

      VStack(alignment: .leading, spacing: 6) {
        Text(recipe.goal.title.uppercased())
          .font(GainsFont.label(9))
          .tracking(1.8)
          .foregroundStyle(GainsColor.card.opacity(0.78))

        Text(recipe.title)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.card)
          .lineLimit(2)

        Text("\(recipe.calories) kcal · \(recipe.protein)g Protein")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.card.opacity(0.82))
      }
      .padding(18)

      VStack {
        HStack {
          Spacer()
          GainsDisclosureIndicator(accent: GainsColor.card)
            .padding(14)
        }
        Spacer()
      }
    }
  }

  private func featuredAccentColor(for goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein:
      return GainsColor.lime
    case .abnehmen:
      return Color(hex: "9FD3B0")
    case .zunehmen:
      return Color(hex: "E3B96C")
    }
  }

  private var activeFilterLabel: String {
    if activeFilterCount == 0 {
      return "keine aktiv"
    }

    if selectedMealType != nil || selectedDietaryStyle != .all {
      return "feiner gesetzt"
    }

    return "aktiv"
  }

  private var activeFilterCount: Int {
    [
      selectedGoal != nil,
      selectedDietaryStyle != .all,
      selectedMealType != nil,
      showsFavoritesOnly,
      maxPrepMinutes < 180,
      maxCalories < 1600,
      !ingredientText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
    ]
    .filter { $0 }
    .count
  }

  private func resetAllFilters() {
    selectedGoal = nil
    selectedDietaryStyle = .all
    selectedMealType = nil
    showsFavoritesOnly = false
    showsIngredientFilter = false
    searchText = ""
    ingredientText = ""
    maxPrepMinutes = 180
    maxCalories = 1600
  }

  private func progressValue(current: Int, target: Int) -> CGFloat {
    guard target > 0 else { return 0 }
    return min(max(CGFloat(current) / CGFloat(target), 0), 1)
  }

  private func formattedLoggedTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }
}

private struct NutritionEntrySheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  @State private var title = ""
  @State private var mealType: RecipeMealType
  @State private var calories = ""
  @State private var protein = ""
  @State private var carbs = ""
  @State private var fat = ""

  init(defaultMealType: RecipeMealType) {
    _mealType = State(initialValue: defaultMealType)
  }

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        screenHeader(
          eyebrow: "ERNÄHRUNG / HINZUFÜGEN",
          title: "Mahlzeit erfassen",
          subtitle: "Tracke dein Essen direkt mit Kalorien und Makros."
        )

        fieldBlock(title: "Name") {
          textField("Zum Beispiel Chicken Rice Bowl", text: $title)
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
                    .foregroundStyle(mealType == currentType ? GainsColor.moss : GainsColor.softInk)
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
          macroField(title: "kcal", text: $calories)
          macroField(title: "Protein", text: $protein)
        }

        HStack(spacing: 10) {
          macroField(title: "Carbs", text: $carbs)
          macroField(title: "Fett", text: $fat)
        }

        Button {
          store.logNutritionEntry(
            title: title,
            mealType: mealType,
            calories: Int(calories) ?? 0,
            protein: Int(protein) ?? 0,
            carbs: Int(carbs) ?? 0,
            fat: Int(fat) ?? 0
          )
          dismiss()
        } label: {
          Text("Mahlzeit speichern")
            .font(GainsFont.label(12))
            .tracking(1.4)
            .foregroundStyle(GainsColor.moss)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Schließen") {
          dismiss()
        }
        .foregroundStyle(GainsColor.ink)
      }
    }
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

  private func textField(_ placeholder: String, text: Binding<String>) -> some View {
    TextField(placeholder, text: text)
      .textInputAutocapitalization(.words)
      .padding(.horizontal, 16)
      .frame(height: 54)
      .gainsCardStyle()
  }

  private func macroField(title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title.uppercased())
        .font(GainsFont.label(10))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      TextField("0", text: text)
        .keyboardType(.numberPad)
        .padding(.horizontal, 16)
        .frame(height: 54)
        .gainsCardStyle()
    }
    .frame(maxWidth: .infinity)
  }
}

private struct RecipeFilterSheet: View {
  @Binding var selectedDietaryStyle: RecipeDietaryStyle
  @Binding var selectedMealType: RecipeMealType?
  @Binding var maxPrepMinutes: Double
  @Binding var maxCalories: Double
  let onReset: () -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        screenHeader(
          eyebrow: "REZEPTE / FILTER",
          title: "Rezepte filtern",
          subtitle: "Stell dir die Meals nach Stil, Zeitpunkt, Dauer und Kalorien passend zusammen."
        )

        filterGroup(title: "Ernährungsstil") {
          VStack(spacing: 10) {
            ForEach(RecipeDietaryStyle.allCases.filter { $0 != .all }, id: \.self) { style in
              filterRow(
                title: style.title,
                icon: style.systemImage,
                isSelected: selectedDietaryStyle == style
              ) {
                selectedDietaryStyle = selectedDietaryStyle == style ? .all : style
              }
            }
          }
        }

        filterGroup(title: "Ernährungszeitpunkt") {
          VStack(spacing: 10) {
            ForEach(RecipeMealType.allCases, id: \.self) { mealType in
              filterRow(
                title: mealType.title,
                icon: mealType.systemImage,
                isSelected: selectedMealType == mealType
              ) {
                selectedMealType = selectedMealType == mealType ? nil : mealType
              }
            }
          }
        }

        sliderSection(
          title: "Kochdauer",
          valueText: "0 Min - \(Int(maxPrepMinutes)) Min",
          value: $maxPrepMinutes,
          range: 10...180,
          step: 5
        )

        sliderSection(
          title: "Kalorienbereich",
          valueText: "0 kcal - \(Int(maxCalories)) kcal",
          value: $maxCalories,
          range: 200...1600,
          step: 50
        )

        HStack(spacing: 12) {
          Button {
            onReset()
          } label: {
            Text("Zurücksetzen")
              .font(GainsFont.label(11))
              .tracking(1.4)
              .foregroundStyle(GainsColor.ink)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background(GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)

          Button {
            dismiss()
          } label: {
            Text("Filter anwenden")
              .font(GainsFont.label(11))
              .tracking(1.4)
              .foregroundStyle(GainsColor.moss)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background(GainsColor.lime)
              .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)
        }
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

  private func filterGroup<Content: View>(title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(GainsFont.label(11))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      content()
    }
  }

  private func filterRow(
    title: String, icon: String, isSelected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.moss : GainsColor.softInk)
          .frame(width: 24)

        Text(title)
          .font(GainsFont.body())
          .foregroundStyle(isSelected ? GainsColor.ink : GainsColor.softInk)

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(GainsColor.lime)
        }
      }
      .padding(.horizontal, 16)
      .frame(height: 56)
      .background(isSelected ? GainsColor.lime.opacity(0.25) : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func sliderSection(
    title: String, valueText: String, value: Binding<Double>, range: ClosedRange<Double>,
    step: Double
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(GainsFont.label(11))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      Text(valueText)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.ink)

      Slider(value: value, in: range, step: step)
        .tint(GainsColor.lime)
    }
  }
}

private struct RecipeCard: View {
  @EnvironmentObject private var store: GainsStore
  let recipe: Recipe

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      recipeArtwork

      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            recipeBadge(
              recipe.category.uppercased(), background: GainsColor.background.opacity(0.82),
              foreground: GainsColor.softInk)
            recipeBadge(
              recipe.goal.title.uppercased(), background: accentColor(recipe.goal).opacity(0.24),
              foreground: accentTextColor(recipe.goal))
            recipeBadge(
              recipe.dietaryStyle.title.uppercased(), background: GainsColor.lime.opacity(0.18),
              foreground: GainsColor.moss)
          }

          Text(recipe.title)
            .font(GainsFont.title(22))
            .foregroundStyle(GainsColor.ink)
        }

        Spacer()

        Button {
          store.toggleFavoriteRecipe(recipe.id)
        } label: {
          Image(
            systemName: store.favoriteRecipeIDs.contains(recipe.id) ? "bookmark.fill" : "bookmark"
          )
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(
            store.favoriteRecipeIDs.contains(recipe.id)
              ? accentTextColor(recipe.goal) : GainsColor.softInk
          )
          .frame(width: 36, height: 36)
          .background(GainsColor.background.opacity(0.9))
          .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }

      HStack(spacing: 10) {
        recipeStat("\(recipe.calories)", "kcal")
        recipeStat("\(recipe.protein)g", "Protein")
        recipeStat("\(recipe.carbs)g", "Carbs")
        recipeStat("\(recipe.fat)g", "Fett")
      }

      Text("\(recipe.prepMinutes) Min Zubereitung")
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .gainsCardStyle()
  }

  private var recipeArtwork: some View {
    ZStack(alignment: .bottomLeading) {
      AsyncImage(url: URL(string: recipe.imageURL)) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          fallbackArtwork(height: 164, fontSize: 54)
        }
      }
      .frame(height: 164)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

      LinearGradient(
        colors: [Color.clear, GainsColor.ink.opacity(0.72)],
        startPoint: .center,
        endPoint: .bottom
      )
      .frame(height: 164)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

      Text(recipe.category)
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.card.opacity(0.86))
        .padding(14)
    }
  }

  private func recipeStat(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(value)
        .font(GainsFont.title(17))
        .foregroundStyle(GainsColor.ink)

      Text(label)
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(10)
    .background(GainsColor.background.opacity(0.8))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func recipeBadge(_ text: String, background: Color, foreground: Color) -> some View {
    Text(text)
      .font(GainsFont.label(9))
      .tracking(1.7)
      .foregroundStyle(foreground)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(background)
      .clipShape(Capsule())
  }

  private func accentColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein:
      return GainsColor.lime
    case .abnehmen:
      return Color(hex: "9FD3B0")
    case .zunehmen:
      return Color(hex: "E3B96C")
    }
  }

  private func accentTextColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein:
      return GainsColor.moss
    case .abnehmen:
      return Color(hex: "2E6242")
    case .zunehmen:
      return Color(hex: "6D4516")
    }
  }

  private func fallbackArtwork(height: CGFloat, fontSize: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
      .fill(
        LinearGradient(
          colors: [accentColor(recipe.goal), GainsColor.ink],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .frame(height: height)
      .overlay(alignment: .topTrailing) {
        Circle()
          .fill(Color.white.opacity(0.08))
          .frame(width: height * 0.55, height: height * 0.55)
          .offset(x: -16, y: 16)
      }
      .overlay {
        Image(systemName: recipe.placeholderSymbol)
          .font(.system(size: fontSize, weight: .medium))
          .foregroundStyle(GainsColor.card)
      }
  }
}

private struct RecipeDetailView: View {
  @EnvironmentObject private var store: GainsStore
  let recipe: Recipe

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        detailArtwork

        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            detailBadge(recipe.category.uppercased())
            detailBadge(recipe.goal.title.uppercased(), highlighted: true)
            detailBadge(recipe.dietaryStyle.title.uppercased())
          }

          Text(recipe.title)
            .font(GainsFont.title(30))
            .foregroundStyle(GainsColor.ink)

          Text(
            "\(recipe.calories) kcal · \(recipe.protein)g Protein · \(recipe.carbs)g Carbs · \(recipe.fat)g Fett"
          )
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.softInk)
        }

        VStack(alignment: .leading, spacing: 12) {
          SlashLabel(
            parts: ["ZUTATEN", "EINKAUF"], primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk)

          ForEach(recipe.ingredients, id: \.self) { ingredient in
            HStack(spacing: 10) {
              Circle()
                .fill(GainsColor.lime)
                .frame(width: 8, height: 8)

              Text(ingredient)
                .font(GainsFont.body())
                .foregroundStyle(GainsColor.ink)

              Spacer()
            }
            .padding(14)
            .gainsCardStyle()
          }
        }

        VStack(alignment: .leading, spacing: 12) {
          SlashLabel(
            parts: ["SCHRITTE", "KOCHEN"], primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk)

          ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top, spacing: 12) {
              Text("\(index + 1)")
                .font(GainsFont.label(10))
                .tracking(2)
                .foregroundStyle(GainsColor.lime)
                .frame(width: 22, height: 22)
                .background(GainsColor.ink)
                .clipShape(Circle())

              Text(step)
                .font(GainsFont.body())
                .foregroundStyle(GainsColor.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .gainsCardStyle()
          }
        }

        Button {
          store.toggleFavoriteRecipe(recipe.id)
        } label: {
          Text(
            store.favoriteRecipeIDs.contains(recipe.id)
              ? "Als Favorit gespeichert" : "Rezept als Favorit speichern"
          )
          .font(GainsFont.label(12))
          .tracking(1.4)
          .foregroundStyle(GainsColor.lime)
          .frame(maxWidth: .infinity)
          .frame(height: 52)
          .background(GainsColor.ink)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)

        Button {
          store.logRecipe(recipe)
        } label: {
          Text("Als Mahlzeit tracken")
            .font(GainsFont.label(12))
            .tracking(1.4)
            .foregroundStyle(GainsColor.moss)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var detailArtwork: some View {
    ZStack(alignment: .bottomLeading) {
      AsyncImage(url: URL(string: recipe.imageURL)) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFill()
        default:
          fallbackArtwork(height: 240, fontSize: 76)
        }
      }
      .frame(height: 240)
      .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

      LinearGradient(
        colors: [Color.clear, GainsColor.ink.opacity(0.72)],
        startPoint: .center,
        endPoint: .bottom
      )
      .frame(height: 240)
      .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

      Text(recipe.category)
        .font(GainsFont.label(10))
        .tracking(2)
        .foregroundStyle(GainsColor.card.opacity(0.86))
        .padding(18)
    }
  }

  private func fallbackArtwork(height: CGFloat, fontSize: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
      .fill(
        LinearGradient(
          colors: [accentColor(recipe.goal), GainsColor.ink],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .frame(height: height)
      .overlay(alignment: .topTrailing) {
        Circle()
          .fill(Color.white.opacity(0.08))
          .frame(width: height * 0.55, height: height * 0.55)
          .offset(x: -16, y: 16)
      }
      .overlay {
        Image(systemName: recipe.placeholderSymbol)
          .font(.system(size: fontSize, weight: .medium))
          .foregroundStyle(GainsColor.card)
      }
  }

  private func detailBadge(_ text: String, highlighted: Bool = false) -> some View {
    Text(text)
      .font(GainsFont.label(9))
      .tracking(1.8)
      .foregroundStyle(highlighted ? accentTextColor(recipe.goal) : GainsColor.softInk)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(
        highlighted ? accentColor(recipe.goal).opacity(0.24) : GainsColor.background.opacity(0.8)
      )
      .clipShape(Capsule())
  }

  private func accentColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein:
      return GainsColor.lime
    case .abnehmen:
      return Color(hex: "9FD3B0")
    case .zunehmen:
      return Color(hex: "E3B96C")
    }
  }

  private func accentTextColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein:
      return GainsColor.moss
    case .abnehmen:
      return Color(hex: "2E6242")
    case .zunehmen:
      return Color(hex: "6D4516")
    }
  }
}
