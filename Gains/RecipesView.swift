import SwiftUI

struct RecipesView: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore
  let viewModel: RecipesViewModel

  // Suche & Filter
  @State private var searchText = ""
  @State private var selectedGoal: RecipeGoal?
  @State private var selectedTag: RecipeTag?
  @State private var selectedDietaryStyle: RecipeDietaryStyle = .all
  @State private var selectedMealType: RecipeMealType?
  @State private var maxPrepMinutes = 180.0
  @State private var maxCalories = 1600.0
  @State private var showsFavoritesOnly = false
  @State private var showsFilterSheet = false

  var body: some View {
    NavigationStack {
      GainsScreen {
        VStack(alignment: .leading, spacing: 24) {
          screenHeader(
            eyebrow: "FUEL / REZEPTE",
            title: "Rezepte & Inspiration",
            subtitle: "Mealprep, Airfryer, Schnell-Rezepte – für jedes Ziel das passende Meal."
          )

          headerStats
          searchBar

          if !hasAnyFilter {
            tagBrowserSection
          }

          goalFilterChips
          activeFiltersSection

          if hasAnyFilter || !searchText.isEmpty {
            // Flache Suchergebnisliste
            filteredListSection
          } else {
            // Kuratierter Discovery-Modus
            featuredSection
            tagSection(.mealprep)
            tagSection(.airfryer)
            tagSection(.quick)
            allRecipesSection
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
    }
  }

  // MARK: - Header Stats

  private var headerStats: some View {
    HStack(spacing: 10) {
      headerStatCard(
        value: "\(store.recipes.count)",
        label: "Rezepte"
      )
      headerStatCard(
        value: "\(store.favoriteRecipeIDs.count)",
        label: "Favoriten"
      )
      headerStatCard(
        value: "\(filteredRecipes.count)",
        label: "Treffer"
      )
    }
  }

  private func headerStatCard(value: String, label: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(value)
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
      Text(label.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .gainsCardStyle()
  }

  // MARK: - Search

  private var searchBar: some View {
    HStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(GainsColor.softInk)

      TextField("Rezepte, Zutaten, Kategorien", text: $searchText)
        .textInputAutocapitalization(.words)

      Button {
        if !searchText.isEmpty {
          searchText = ""
        } else {
          showsFilterSheet = true
        }
      } label: {
        Image(
          systemName: searchText.isEmpty
            ? "slider.horizontal.3"
            : "xmark.circle.fill"
        )
        .foregroundStyle(
          activeFilterCount > 0 && searchText.isEmpty ? GainsColor.lime : GainsColor.softInk
        )
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, 16)
    .frame(height: 54)
    .gainsCardStyle()
  }

  // MARK: - Tag Browser (große Kategorie-Karten)

  private var tagBrowserSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["BROWSE", "KATEGORIEN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: 10),
          GridItem(.flexible(), spacing: 10),
        ],
        spacing: 10
      ) {
        tagBrowserCard(.mealprep, accent: Color(hex: "C3B3FF"))
        tagBrowserCard(.airfryer, accent: Color(hex: "E3B96C"))
        tagBrowserCard(.quick, accent: GainsColor.lime)
        tagBrowserCard(.budget, accent: Color(hex: "9FD3B0"))
      }
    }
  }

  private func tagBrowserCard(_ tag: RecipeTag, accent: Color) -> some View {
    let count = store.recipes.filter { $0.tags.contains(tag) }.count
    return Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
        selectedTag = tag
      }
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack {
          Image(systemName: tag.systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(accent)
            .frame(width: 36, height: 36)
            .background(accent.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

          Spacer()

          Text("\(count)")
            .font(GainsFont.label(10))
            .tracking(1.4)
            .foregroundStyle(GainsColor.softInk)
        }

        VStack(alignment: .leading, spacing: 2) {
          Text(tag.title)
            .font(GainsFont.title(17))
            .foregroundStyle(GainsColor.ink)
          Text(tag.subtitle)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
  }

  // MARK: - Goal Chips

  private var goalFilterChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        filterChip(title: "Alle", isSelected: selectedGoal == nil && !showsFavoritesOnly && selectedTag == nil) {
          selectedGoal = nil
          showsFavoritesOnly = false
          selectedTag = nil
        }

        ForEach(RecipeGoal.allCases, id: \.self) { goal in
          filterChip(title: goal.title, isSelected: selectedGoal == goal) {
            selectedGoal = selectedGoal == goal ? nil : goal
          }
        }

        ForEach(RecipeTag.allCases) { tag in
          filterChip(
            title: tag.title,
            icon: tag.systemImage,
            isSelected: selectedTag == tag
          ) {
            selectedTag = selectedTag == tag ? nil : tag
          }
        }

        filterChip(title: "Favoriten", icon: "bookmark.fill", isSelected: showsFavoritesOnly) {
          showsFavoritesOnly.toggle()
        }
      }
      .padding(.vertical, 2)
    }
  }

  // MARK: - Active Filters

  @ViewBuilder
  private var activeFiltersSection: some View {
    if activeFilterCount > 0 {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          if selectedDietaryStyle != .all {
            activeFilterChip(selectedDietaryStyle.title)
          }
          if let selectedMealType {
            activeFilterChip(selectedMealType.title)
          }
          if maxPrepMinutes < 180 {
            activeFilterChip("Bis \(Int(maxPrepMinutes)) Min")
          }
          if maxCalories < 1600 {
            activeFilterChip("Bis \(Int(maxCalories)) kcal")
          }

          Button {
            resetAllFilters()
          } label: {
            Text("Zurücksetzen")
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(GainsColor.softInk)
              .padding(.horizontal, 14)
              .frame(height: 34)
              .background(GainsColor.card)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
      }
    }
  }

  // MARK: - Featured

  private var featuredSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TOP", "FÜR DICH"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(featuredRecipes) { recipe in
            NavigationLink {
              RecipeDetailView(recipe: recipe)
                .environmentObject(store)
            } label: {
              FeaturedRecipeCard(recipe: recipe)
                .environmentObject(store)
                .frame(width: 240)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 2)
      }
    }
  }

  // MARK: - Tag-Sektion (horizontal Scroll)

  private func tagSection(_ tag: RecipeTag) -> some View {
    let recipes = store.recipes.filter { $0.tags.contains(tag) }
    return Group {
      if !recipes.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 10) {
            Image(systemName: tag.systemImage)
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(GainsColor.lime)
              .frame(width: 28, height: 28)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
              Text(tag.title.uppercased())
                .font(GainsFont.label(11))
                .tracking(2)
                .foregroundStyle(GainsColor.ink)
              Text(tag.subtitle)
                .font(GainsFont.body(12))
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()

            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedTag = tag
              }
            } label: {
              Text("Alle \(recipes.count)")
                .font(GainsFont.label(10))
                .tracking(1.4)
                .foregroundStyle(GainsColor.moss)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(GainsColor.lime)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(recipes) { recipe in
                NavigationLink {
                  RecipeDetailView(recipe: recipe)
                    .environmentObject(store)
                } label: {
                  FeaturedRecipeCard(recipe: recipe)
                    .environmentObject(store)
                    .frame(width: 240)
                }
                .buttonStyle(.plain)
              }
            }
            .padding(.vertical, 2)
          }
        }
      }
    }
  }

  // MARK: - Alle Rezepte (kompakte vertikale Liste)

  private var allRecipesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SlashLabel(
          parts: ["ALLE", "REZEPTE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(store.recipes.count)")
          .font(GainsFont.label(10))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
      }

      VStack(spacing: 10) {
        ForEach(store.recipes) { recipe in
          NavigationLink {
            RecipeDetailView(recipe: recipe)
              .environmentObject(store)
          } label: {
            CompactRecipeRow(recipe: recipe)
              .environmentObject(store)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: - Suchergebnis-Liste

  private var filteredListSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        SlashLabel(
          parts: filterEyebrowParts,
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(filteredRecipes.count)")
          .font(GainsFont.label(10))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
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

  private var filterEyebrowParts: [String] {
    if let selectedTag {
      return [selectedTag.title.uppercased(), "REZEPTE"]
    }
    if let selectedGoal {
      return [selectedGoal.title.uppercased(), "REZEPTE"]
    }
    if showsFavoritesOnly {
      return ["FAVORITEN", "REZEPTE"]
    }
    return ["TREFFER", "REZEPTE"]
  }

  private var emptyState: some View {
    EmptyStateView(
      style: .inline,
      title: "Keine Rezepte gefunden",
      message: "Passe die Suche oder Filter an, um passende Meals zu sehen.",
      icon: "magnifyingglass",
      actionLabel: "Filter zurücksetzen",
      action: { resetAllFilters() }
    )
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

  // MARK: - Filter Chips

  private func filterChip(
    title: String,
    icon: String? = nil,
    isSelected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
        }
        Text(title)
          .font(GainsFont.label(10))
          .tracking(1.5)
      }
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

  // MARK: - Computed

  private var hasAnyFilter: Bool {
    selectedGoal != nil
      || selectedTag != nil
      || showsFavoritesOnly
      || activeFilterCount > 0
  }

  private var filteredRecipes: [Recipe] {
    store.recipes.filter { recipe in
      let matchesGoal = selectedGoal == nil || recipe.goal == selectedGoal
      let matchesTag = selectedTag == nil || recipe.tags.contains(selectedTag!)
      let matchesFavorites = !showsFavoritesOnly || store.favoriteRecipeIDs.contains(recipe.id)
      let matchesDietaryStyle = selectedDietaryStyle == .all || recipe.dietaryStyle == selectedDietaryStyle
      let matchesMealType = selectedMealType == nil || recipe.mealType == selectedMealType
      let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
      let matchesSearch =
        search.isEmpty
        || recipe.title.localizedCaseInsensitiveContains(search)
        || recipe.category.localizedCaseInsensitiveContains(search)
        || recipe.goal.title.localizedCaseInsensitiveContains(search)
        || recipe.tags.contains { $0.title.localizedCaseInsensitiveContains(search) }
        || recipe.ingredients.joined(separator: " ").localizedCaseInsensitiveContains(search)
      let matchesPrep = Double(recipe.prepMinutes) <= maxPrepMinutes
      let matchesCalories = Double(recipe.calories) <= maxCalories
      return matchesGoal && matchesTag && matchesSearch && matchesFavorites
        && matchesDietaryStyle && matchesMealType && matchesPrep && matchesCalories
    }
  }

  private var featuredRecipes: [Recipe] {
    let favorites = store.recipes.filter { store.favoriteRecipeIDs.contains($0.id) }
    if !favorites.isEmpty {
      return Array(favorites.prefix(6))
    }
    return Array(
      store.recipes
        .sorted { $0.protein > $1.protein }
        .prefix(6)
    )
  }

  private var activeFilterCount: Int {
    [
      selectedDietaryStyle != .all,
      selectedMealType != nil,
      maxPrepMinutes < 180,
      maxCalories < 1600,
    ]
    .filter { $0 }
    .count
  }

  private func resetAllFilters() {
    selectedGoal = nil
    selectedTag = nil
    selectedDietaryStyle = .all
    selectedMealType = nil
    showsFavoritesOnly = false
    searchText = ""
    maxPrepMinutes = 180
    maxCalories = 1600
  }
}

// MARK: - Featured Recipe Card

private struct FeaturedRecipeCard: View {
  @EnvironmentObject private var store: GainsStore
  let recipe: Recipe

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ZStack(alignment: .topTrailing) {
        AsyncImage(url: URL(string: recipe.imageURL)) { phase in
          switch phase {
          case .success(let image):
            image.resizable().scaledToFill()
          default:
            fallbackArtwork
          }
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        LinearGradient(
          colors: [Color.clear, GainsColor.ink.opacity(0.7)],
          startPoint: .center,
          endPoint: .bottom
        )
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        if let primaryTag = recipe.tags.first {
          HStack(spacing: 4) {
            Image(systemName: primaryTag.systemImage)
              .font(.system(size: 9, weight: .bold))
            Text(primaryTag.title.uppercased())
              .font(GainsFont.label(9))
              .tracking(1.2)
          }
          .foregroundStyle(GainsColor.moss)
          .padding(.horizontal, 8)
          .frame(height: 22)
          .background(GainsColor.lime)
          .clipShape(Capsule())
          .padding(10)
        }

        VStack(alignment: .leading) {
          Spacer()
          Text(recipe.category.uppercased())
            .font(GainsFont.label(9))
            .tracking(1.6)
            .foregroundStyle(GainsColor.card.opacity(0.9))
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 130)
      }

      VStack(alignment: .leading, spacing: 6) {
        Text(recipe.title)
          .font(GainsFont.title(17))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        HStack(spacing: 8) {
          Label("\(recipe.calories) kcal", systemImage: "flame")
            .labelStyle(.titleOnly)
          Text("·")
          Label("\(recipe.protein)g Protein", systemImage: "p.circle")
            .labelStyle(.titleOnly)
        }
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)

        HStack(spacing: 6) {
          Image(systemName: "clock")
            .font(.system(size: 10, weight: .semibold))
          Text("\(recipe.prepMinutes) Min · \(recipe.servings) Portion\(recipe.servings == 1 ? "" : "en")")
            .font(GainsFont.body(11))
        }
        .foregroundStyle(GainsColor.softInk)
      }
    }
    .padding(14)
    .gainsCardStyle()
  }

  private var fallbackArtwork: some View {
    RoundedRectangle(cornerRadius: 20, style: .continuous)
      .fill(
        LinearGradient(
          colors: [GainsColor.lime.opacity(0.6), GainsColor.ctaSurface],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .frame(height: 130)
      .overlay {
        Image(systemName: recipe.placeholderSymbol)
          .font(.system(size: 38, weight: .medium))
          .foregroundStyle(GainsColor.card)
      }
  }
}

// MARK: - Compact Recipe Row (für „Alle Rezepte"-Liste)

private struct CompactRecipeRow: View {
  @EnvironmentObject private var store: GainsStore
  let recipe: Recipe

  var body: some View {
    HStack(spacing: 14) {
      AsyncImage(url: URL(string: recipe.imageURL)) { phase in
        switch phase {
        case .success(let image):
          image.resizable().scaledToFill()
        default:
          fallback
        }
      }
      .frame(width: 72, height: 72)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        Text(recipe.title)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        Text("\(recipe.calories) kcal · \(recipe.protein)g Protein · \(recipe.prepMinutes) Min")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)

        if let tag = recipe.tags.first {
          HStack(spacing: 4) {
            Image(systemName: tag.systemImage)
              .font(.system(size: 9, weight: .bold))
            Text(tag.title.uppercased())
              .font(GainsFont.label(8))
              .tracking(1.2)
          }
          .foregroundStyle(GainsColor.moss)
          .padding(.horizontal, 7)
          .frame(height: 20)
          .background(GainsColor.lime.opacity(0.25))
          .clipShape(Capsule())
        }
      }

      Spacer()

      Image(systemName: store.favoriteRecipeIDs.contains(recipe.id) ? "bookmark.fill" : "chevron.right")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(
          store.favoriteRecipeIDs.contains(recipe.id) ? GainsColor.lime : GainsColor.softInk
        )
    }
    .padding(12)
    .gainsCardStyle()
  }

  private var fallback: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .fill(
        LinearGradient(
          colors: [GainsColor.lime.opacity(0.4), GainsColor.ctaSurface],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .frame(width: 72, height: 72)
      .overlay {
        Image(systemName: recipe.placeholderSymbol)
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(GainsColor.card)
      }
  }
}

// MARK: - Rezept-Filter Sheet

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
          subtitle: "Stelle Meals nach Stil, Zeitpunkt, Dauer und Kalorien passend zusammen."
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

        filterGroup(title: "Mahlzeittyp") {
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
          valueText: "0 Min – \(Int(maxPrepMinutes)) Min",
          value: $maxPrepMinutes,
          range: 10...180,
          step: 5
        )

        sliderSection(
          title: "Kalorienbereich",
          valueText: "0 kcal – \(Int(maxCalories)) kcal",
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
        Button("Fertig") { dismiss() }
          .foregroundStyle(GainsColor.ink)
      }
    }
  }

  private func filterGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(GainsFont.label(11))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)
      content()
    }
  }

  private func filterRow(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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
    title: String, valueText: String, value: Binding<Double>,
    range: ClosedRange<Double>, step: Double
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

// MARK: - Rezept-Card (große Karte für gefilterte Liste)

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
              recipe.category.uppercased(),
              background: GainsColor.background.opacity(0.82),
              foreground: GainsColor.softInk
            )
            recipeBadge(
              recipe.goal.title.uppercased(),
              background: accentColor(recipe.goal).opacity(0.24),
              foreground: accentTextColor(recipe.goal)
            )
            recipeBadge(
              recipe.dietaryStyle.title.uppercased(),
              background: GainsColor.lime.opacity(0.18),
              foreground: GainsColor.moss
            )
          }

          if !recipe.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 6) {
                ForEach(recipe.tags) { tag in
                  HStack(spacing: 4) {
                    Image(systemName: tag.systemImage)
                      .font(.system(size: 9, weight: .bold))
                    Text(tag.title.uppercased())
                      .font(GainsFont.label(9))
                      .tracking(1.2)
                  }
                  .foregroundStyle(GainsColor.softInk)
                  .padding(.horizontal, 8)
                  .frame(height: 22)
                  .background(GainsColor.background.opacity(0.7))
                  .clipShape(Capsule())
                }
              }
            }
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

      HStack(spacing: 14) {
        Label("\(recipe.prepMinutes) Min", systemImage: "clock")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        Label("\(recipe.servings) Portion\(recipe.servings == 1 ? "" : "en")", systemImage: "person.2")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }
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
          image.resizable().scaledToFill()
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
    case .highProtein: return GainsColor.lime
    case .abnehmen: return Color(hex: "9FD3B0")
    case .zunehmen: return Color(hex: "E3B96C")
    }
  }

  private func accentTextColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein: return GainsColor.moss
    case .abnehmen: return Color(hex: "2E6242")
    case .zunehmen: return Color(hex: "6D4516")
    }
  }

  private func fallbackArtwork(height: CGFloat, fontSize: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
      .fill(
        LinearGradient(
          colors: [accentColor(recipe.goal), GainsColor.ctaSurface],
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

// MARK: - Rezept-Detail

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

          if !recipe.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 6) {
                ForEach(recipe.tags) { tag in
                  HStack(spacing: 4) {
                    Image(systemName: tag.systemImage)
                      .font(.system(size: 10, weight: .bold))
                    Text(tag.title.uppercased())
                      .font(GainsFont.label(9))
                      .tracking(1.4)
                  }
                  .foregroundStyle(GainsColor.moss)
                  .padding(.horizontal, 10)
                  .frame(height: 26)
                  .background(GainsColor.lime.opacity(0.25))
                  .clipShape(Capsule())
                }
              }
            }
          }

          Text(recipe.title)
            .font(GainsFont.title(30))
            .foregroundStyle(GainsColor.ink)

          Text("\(recipe.calories) kcal · \(recipe.protein)g Protein · \(recipe.carbs)g Carbs · \(recipe.fat)g Fett")
            .font(GainsFont.body())
            .foregroundStyle(GainsColor.softInk)

          HStack(spacing: 14) {
            Label("\(recipe.prepMinutes) Min", systemImage: "clock")
            Label("\(recipe.servings) Portion\(recipe.servings == 1 ? "" : "en")", systemImage: "person.2")
          }
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        }

        VStack(alignment: .leading, spacing: 12) {
          SlashLabel(
            parts: ["ZUTATEN", "EINKAUF"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )

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
            parts: ["SCHRITTE", "KOCHEN"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )

          ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top, spacing: 12) {
              Text("\(index + 1)")
                .font(GainsFont.label(10))
                .tracking(2)
                .foregroundStyle(GainsColor.lime)
                .frame(width: 22, height: 22)
                .background(GainsColor.ctaSurface)
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
          .background(GainsColor.ctaSurface)
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
          image.resizable().scaledToFill()
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
          colors: [accentColor(recipe.goal), GainsColor.ctaSurface],
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
        highlighted
          ? accentColor(recipe.goal).opacity(0.24)
          : GainsColor.background.opacity(0.8)
      )
      .clipShape(Capsule())
  }

  private func accentColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein: return GainsColor.lime
    case .abnehmen: return Color(hex: "9FD3B0")
    case .zunehmen: return Color(hex: "E3B96C")
    }
  }

  private func accentTextColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein: return GainsColor.moss
    case .abnehmen: return Color(hex: "2E6242")
    case .zunehmen: return Color(hex: "6D4516")
    }
  }
}
