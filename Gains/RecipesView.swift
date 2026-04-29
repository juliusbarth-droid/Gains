import SwiftUI

// MARK: - Sort Order

enum RecipeSortOrder: String, CaseIterable {
  case standard = "Standard"
  case protein  = "Protein ↑"
  case calories = "Kalorien ↓"
  case prep     = "Schnellste"
}

// MARK: - RecipesView

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
  @State private var sortOrder: RecipeSortOrder = .standard

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 24) {
        screenHeader(
          eyebrow: "FUEL / REZEPTE",
          title: "Rezepte & Inspiration",
          subtitle: "Mealprep, Airfryer, Schnell-Rezepte – für jedes Ziel das passende Meal."
        )

        if hasAnyFilter || !searchText.isEmpty {
          headerStats
        }
        searchBar

        if !hasAnyFilter {
          tagBrowserSection
        }

        goalFilterChips
        if hasAnyFilter || !searchText.isEmpty {
          sortChips
        }
        activeFiltersSection

        if hasAnyFilter || !searchText.isEmpty {
          filteredListSection
        } else {
          featuredSection
          tagSection(.mealprep)
          tagSection(.airfryer)
          tagSection(.quick)
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

  // MARK: - Header Stats

  private var headerStats: some View {
    HStack(spacing: 10) {
      headerStatCard(value: "\(store.recipes.count)", label: "Rezepte")
      headerStatCard(value: "\(store.favoriteRecipeIDs.count)", label: "Favoriten")
      headerStatCard(value: "\(filteredRecipes.count)", label: "Treffer")
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
          systemName: searchText.isEmpty ? "slider.horizontal.3" : "xmark.circle.fill"
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

  // MARK: - Tag Browser

  private var tagBrowserSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["BROWSE", "KATEGORIEN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
        spacing: 10
      ) {
        tagBrowserCard(.mealprep, accent: Color(hex: "C3B3FF"))
        tagBrowserCard(.airfryer, accent: Color(hex: "E3B96C"))
        tagBrowserCard(.quick,    accent: GainsColor.lime)
        tagBrowserCard(.budget,   accent: Color(hex: "9FD3B0"))
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
        filterChip(
          title: "Alle",
          isSelected: selectedGoal == nil && !showsFavoritesOnly && selectedTag == nil
        ) {
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
          filterChip(title: tag.title, icon: tag.systemImage, isSelected: selectedTag == tag) {
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

  // MARK: - Sort Chips

  private var sortChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        Image(systemName: "arrow.up.arrow.down")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
          .padding(.leading, 2)

        ForEach(RecipeSortOrder.allCases, id: \.self) { order in
          Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
              sortOrder = order
            }
          } label: {
            Text(order.rawValue)
              .font(GainsFont.label(10))
              .tracking(1.2)
              .foregroundStyle(sortOrder == order ? GainsColor.moss : GainsColor.softInk)
              .padding(.horizontal, 14)
              .frame(height: 32)
              .background(sortOrder == order ? GainsColor.lime : GainsColor.card)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
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

          Button { resetAllFilters() } label: {
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

  // MARK: - Tag-Sektion

  private func tagSection(_ tag: RecipeTag) -> some View {
    let recipes = Array(store.recipes.filter { $0.tags.contains(tag) }.prefix(4))
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

  // MARK: - Alle Rezepte

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
        ForEach(sortedRecipes(store.recipes)) { recipe in
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
    if let selectedTag   { return [selectedTag.title.uppercased(), "REZEPTE"] }
    if let selectedGoal  { return [selectedGoal.title.uppercased(), "REZEPTE"] }
    if showsFavoritesOnly { return ["FAVORITEN", "REZEPTE"] }
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
      .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.softInk)
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
    selectedGoal != nil || selectedTag != nil || showsFavoritesOnly || activeFilterCount > 0
  }

  private var filteredRecipes: [Recipe] {
    let base = store.recipes.filter { recipe in
      let matchesGoal     = selectedGoal == nil || recipe.goal == selectedGoal
      let matchesTag      = selectedTag.map { recipe.tags.contains($0) } ?? true
      let matchesFavs     = !showsFavoritesOnly || store.favoriteRecipeIDs.contains(recipe.id)
      let matchesDiet     = selectedDietaryStyle == .all || recipe.dietaryStyle == selectedDietaryStyle
      let matchesMealType = selectedMealType == nil || recipe.mealType == selectedMealType
      let search          = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
      let matchesSearch   = search.isEmpty
        || recipe.title.localizedCaseInsensitiveContains(search)
        || recipe.category.localizedCaseInsensitiveContains(search)
        || recipe.goal.title.localizedCaseInsensitiveContains(search)
        || recipe.tags.contains { $0.title.localizedCaseInsensitiveContains(search) }
        || recipe.ingredients.joined(separator: " ").localizedCaseInsensitiveContains(search)
      let matchesPrep     = Double(recipe.prepMinutes) <= maxPrepMinutes
      let matchesCal      = Double(recipe.calories) <= maxCalories
      return matchesGoal && matchesTag && matchesSearch && matchesFavs
        && matchesDiet && matchesMealType && matchesPrep && matchesCal
    }
    return sortedRecipes(base)
  }

  private func sortedRecipes(_ recipes: [Recipe]) -> [Recipe] {
    switch sortOrder {
    case .standard:  return recipes
    case .protein:   return recipes.sorted { $0.protein > $1.protein }
    case .calories:  return recipes.sorted { $0.calories < $1.calories }
    case .prep:      return recipes.sorted { $0.prepMinutes < $1.prepMinutes }
    }
  }

  private var featuredRecipes: [Recipe] {
    let favorites = store.recipes.filter { store.favoriteRecipeIDs.contains($0.id) }
    if !favorites.isEmpty { return Array(favorites.prefix(6)) }
    return Array(store.recipes.sorted { $0.protein > $1.protein }.prefix(6))
  }

  private var activeFilterCount: Int {
    [selectedDietaryStyle != .all, selectedMealType != nil, maxPrepMinutes < 180, maxCalories < 1600]
      .filter { $0 }.count
  }

  private func resetAllFilters() {
    selectedGoal         = nil
    selectedTag          = nil
    selectedDietaryStyle = .all
    selectedMealType     = nil
    showsFavoritesOnly   = false
    searchText           = ""
    maxPrepMinutes       = 180
    maxCalories          = 1600
  }
}

// MARK: - Featured Recipe Card

private struct FeaturedRecipeCard: View {
  @EnvironmentObject private var store: GainsStore
  let recipe: Recipe
  @State private var didTrack = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      ZStack(alignment: .topTrailing) {
        AsyncImage(url: URL(string: recipe.imageURL)) { phase in
          switch phase {
          case .success(let image): image.resizable().scaledToFill()
          default: fallbackArtwork
          }
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        LinearGradient(
          colors: [Color.clear, GainsColor.ink.opacity(0.7)],
          startPoint: .center, endPoint: .bottom
        )
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

        // Tag badge (top-right)
        if let primaryTag = recipe.tags.first {
          HStack(spacing: 4) {
            Image(systemName: primaryTag.systemImage).font(.system(size: 9, weight: .bold))
            Text(primaryTag.title.uppercased()).font(GainsFont.label(9)).tracking(1.2)
          }
          .foregroundStyle(GainsColor.moss)
          .padding(.horizontal, 8)
          .frame(height: 22)
          .background(GainsColor.lime)
          .clipShape(Capsule())
          .padding(10)
        }

        // Category label (bottom-left) + Quick-Track button (bottom-right)
        HStack {
          Text(recipe.category.uppercased())
            .font(GainsFont.label(9))
            .tracking(1.6)
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.9))
          Spacer()
          // Quick-Track button
          Button {
            store.logRecipe(recipe)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { didTrack = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
              withAnimation { didTrack = false }
            }
          } label: {
            Image(systemName: didTrack ? "checkmark" : "plus")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(didTrack ? GainsColor.moss : GainsColor.lime)
              .frame(width: 28, height: 28)
              .background(didTrack ? GainsColor.lime : GainsColor.ink.opacity(0.7))
              .clipShape(Circle())
              .scaleEffect(didTrack ? 1.15 : 1.0)
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
          Image(systemName: "clock").font(.system(size: 10, weight: .semibold))
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
      .fill(LinearGradient(
        colors: [GainsColor.lime.opacity(0.6), GainsColor.ctaSurface],
        startPoint: .topLeading, endPoint: .bottomTrailing
      ))
      .frame(height: 130)
      .overlay {
        Image(systemName: recipe.placeholderSymbol)
          .font(.system(size: 38, weight: .medium))
          .foregroundStyle(GainsColor.onCtaSurface)
      }
  }
}

// MARK: - Compact Recipe Row

private struct CompactRecipeRow: View {
  @EnvironmentObject private var store: GainsStore
  let recipe: Recipe

  var body: some View {
    HStack(spacing: 14) {
      AsyncImage(url: URL(string: recipe.imageURL)) { phase in
        switch phase {
        case .success(let image): image.resizable().scaledToFill()
        default: fallback
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
            Image(systemName: tag.systemImage).font(.system(size: 9, weight: .bold))
            Text(tag.title.uppercased()).font(GainsFont.label(8)).tracking(1.2)
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
      .fill(LinearGradient(
        colors: [GainsColor.lime.opacity(0.4), GainsColor.ctaSurface],
        startPoint: .topLeading, endPoint: .bottomTrailing
      ))
      .frame(width: 72, height: 72)
      .overlay {
        Image(systemName: recipe.placeholderSymbol)
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(GainsColor.onCtaSurface)
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
              filterRow(title: style.title, icon: style.systemImage, isSelected: selectedDietaryStyle == style) {
                selectedDietaryStyle = selectedDietaryStyle == style ? .all : style
              }
            }
          }
        }

        filterGroup(title: "Mahlzeittyp") {
          VStack(spacing: 10) {
            ForEach(RecipeMealType.allCases, id: \.self) { mealType in
              filterRow(title: mealType.title, icon: mealType.systemImage, isSelected: selectedMealType == mealType) {
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

// MARK: - Rezept-Card (große Karte)

private struct RecipeCard: View {
  @EnvironmentObject private var store: GainsStore
  let recipe: Recipe

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      recipeArtwork

      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            recipeBadge(recipe.category.uppercased(),
              background: GainsColor.background.opacity(0.82),
              foreground: GainsColor.softInk)
            recipeBadge(recipe.goal.title.uppercased(),
              background: accentColor(recipe.goal).opacity(0.24),
              foreground: accentTextColor(recipe.goal))
            recipeBadge(recipe.dietaryStyle.title.uppercased(),
              background: GainsColor.lime.opacity(0.18),
              foreground: GainsColor.moss)
          }

          if !recipe.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 6) {
                ForEach(recipe.tags) { tag in
                  HStack(spacing: 4) {
                    Image(systemName: tag.systemImage).font(.system(size: 9, weight: .bold))
                    Text(tag.title.uppercased()).font(GainsFont.label(9)).tracking(1.2)
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
          Image(systemName: store.favoriteRecipeIDs.contains(recipe.id) ? "bookmark.fill" : "bookmark")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(store.favoriteRecipeIDs.contains(recipe.id)
              ? accentTextColor(recipe.goal) : GainsColor.softInk)
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
        case .success(let image): image.resizable().scaledToFill()
        default: fallbackArtwork(height: 164, fontSize: 54)
        }
      }
      .frame(height: 164)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

      LinearGradient(colors: [Color.clear, GainsColor.ink.opacity(0.72)], startPoint: .center, endPoint: .bottom)
        .frame(height: 164)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

      Text(recipe.category)
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.onCtaSurface.opacity(0.86))
        .padding(14)
    }
  }

  private func recipeStat(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(value).font(GainsFont.title(17)).foregroundStyle(GainsColor.ink)
      Text(label).font(GainsFont.label(9)).tracking(1.8).foregroundStyle(GainsColor.softInk)
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
    case .abnehmen:    return Color(hex: "9FD3B0")
    case .zunehmen:    return Color(hex: "E3B96C")
    }
  }

  private func accentTextColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein: return GainsColor.moss
    case .abnehmen:    return Color(hex: "2E6242")
    case .zunehmen:    return Color(hex: "6D4516")
    }
  }

  private func fallbackArtwork(height: CGFloat, fontSize: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
      .fill(LinearGradient(
        colors: [accentColor(recipe.goal), GainsColor.ctaSurface],
        startPoint: .topLeading, endPoint: .bottomTrailing
      ))
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
          .foregroundStyle(GainsColor.onCtaSurface)
      }
  }
}

// MARK: - Rezept-Detail

struct RecipeDetailView: View {
  @EnvironmentObject private var store: GainsStore
  let recipe: Recipe

  @State private var scaledServings: Int
  @State private var checkedIngredients: Set<Int> = []

  init(recipe: Recipe) {
    self.recipe = recipe
    _scaledServings = State(initialValue: recipe.servings)
  }

  // Skalierungsfaktor – alle Nährwerte werden proportional angepasst
  private var scale: Double { Double(scaledServings) / Double(max(recipe.servings, 1)) }
  private var scaledCalories: Int { Int((Double(recipe.calories) * scale).rounded()) }
  private var scaledProtein:  Int { Int((Double(recipe.protein)  * scale).rounded()) }
  private var scaledCarbs:    Int { Int((Double(recipe.carbs)    * scale).rounded()) }
  private var scaledFat:      Int { Int((Double(recipe.fat)      * scale).rounded()) }

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        detailArtwork

        VStack(alignment: .leading, spacing: 8) {
          // Badges
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
                    Image(systemName: tag.systemImage).font(.system(size: 10, weight: .bold))
                    Text(tag.title.uppercased()).font(GainsFont.label(9)).tracking(1.4)
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

          // Zeit & Portionen-Zeile
          HStack(spacing: 14) {
            Label("\(recipe.prepMinutes) Min", systemImage: "clock")
            Spacer()
            // Portionen-Stepper
            HStack(spacing: 0) {
              Button {
                withAnimation(.spring(response: 0.3)) {
                  if scaledServings > 1 { scaledServings -= 1 }
                }
              } label: {
                Image(systemName: "minus")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundStyle(scaledServings > 1 ? GainsColor.ink : GainsColor.mutedInk)
                  .frame(width: 32, height: 32)
                  .background(GainsColor.elevated)
                  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
              }
              .buttonStyle(.plain)
              .disabled(scaledServings <= 1)

              Text("\(scaledServings)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(GainsColor.ink)
                .frame(minWidth: 36)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: scaledServings)

              Button {
                withAnimation(.spring(response: 0.3)) { scaledServings += 1 }
              } label: {
                Image(systemName: "plus")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundStyle(GainsColor.ink)
                  .frame(width: 32, height: 32)
                  .background(GainsColor.elevated)
                  .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
              }
              .buttonStyle(.plain)

              Text("Port.")
                .font(GainsFont.label(10))
                .foregroundStyle(GainsColor.softInk)
                .padding(.leading, 6)
            }
          }
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        }

        // Makro-Karte (skaliert mit Portionen)
        macroCard

        // Zutaten
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            SlashLabel(
              parts: ["ZUTATEN", "EINKAUF"],
              primaryColor: GainsColor.lime,
              secondaryColor: GainsColor.softInk
            )
            Spacer()
            if !checkedIngredients.isEmpty {
              Button {
                withAnimation(.spring(response: 0.3)) { checkedIngredients.removeAll() }
              } label: {
                Text("Reset")
                  .font(GainsFont.label(9))
                  .tracking(1.4)
                  .foregroundStyle(GainsColor.softInk)
                  .padding(.horizontal, 10)
                  .frame(height: 24)
                  .background(GainsColor.elevated)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }

          VStack(spacing: 8) {
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
              Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                  if checkedIngredients.contains(index) {
                    checkedIngredients.remove(index)
                  } else {
                    checkedIngredients.insert(index)
                  }
                }
              } label: {
                HStack(spacing: 12) {
                  ZStack {
                    Circle()
                      .fill(checkedIngredients.contains(index) ? GainsColor.lime : GainsColor.lime.opacity(0.2))
                      .frame(width: 20, height: 20)
                    if checkedIngredients.contains(index) {
                      Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(GainsColor.moss)
                    }
                  }

                  Text(ingredient)
                    .font(GainsFont.body())
                    .foregroundStyle(
                      checkedIngredients.contains(index) ? GainsColor.softInk : GainsColor.ink
                    )
                    .strikethrough(checkedIngredients.contains(index), color: GainsColor.softInk)

                  Spacer()
                }
                .padding(14)
                .background(
                  checkedIngredients.contains(index)
                    ? GainsColor.elevated
                    : GainsColor.card
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                  RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                      checkedIngredients.contains(index)
                        ? GainsColor.lime.opacity(0.3)
                        : GainsColor.border.opacity(0.0),
                      lineWidth: 1
                    )
                )
              }
              .buttonStyle(.plain)
              .animation(.spring(response: 0.3), value: checkedIngredients.contains(index))
            }
          }
        }

        // Schritte
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

        // Aktions-Buttons
        HStack(spacing: 12) {
          Button {
            store.toggleFavoriteRecipe(recipe.id)
          } label: {
            HStack(spacing: 8) {
              Image(systemName: store.favoriteRecipeIDs.contains(recipe.id) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15, weight: .semibold))
              Text(store.favoriteRecipeIDs.contains(recipe.id) ? "Gespeichert" : "Merken")
                .font(GainsFont.label(12))
                .tracking(1.2)
            }
            .foregroundStyle(
              store.favoriteRecipeIDs.contains(recipe.id) ? accentTextColor(recipe.goal) : GainsColor.lime
            )
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(GainsColor.ctaSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)

          Button {
            store.logRecipe(recipe)
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "plus.circle.fill")
                .font(.system(size: 15, weight: .semibold))
              Text("Tracken")
                .font(GainsFont.label(12))
                .tracking(1.2)
            }
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
  }

  // MARK: Makro-Karte

  private var macroCard: some View {
    VStack(spacing: 14) {
      HStack(spacing: 0) {
        macroCell(value: "\(scaledCalories)", unit: "kcal", label: "Kalorien", color: GainsColor.ink)
        Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
        macroCell(value: "\(scaledProtein)g", unit: "", label: "Protein", color: GainsColor.lime)
        Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
        macroCell(value: "\(scaledCarbs)g", unit: "", label: "Carbs", color: Color(hex: "5BC4F5"))
        Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
        macroCell(value: "\(scaledFat)g", unit: "", label: "Fett", color: Color(hex: "FF8A4A"))
      }
      .animation(.spring(response: 0.4), value: scaledServings)

      if scaledServings != recipe.servings {
        Text("Hochgerechnet für \(scaledServings) Portion\(scaledServings == 1 ? "" : "en") (Originalrezept: \(recipe.servings))")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.mutedInk)
          .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  private func macroCell(value: String, unit: String, label: String, color: Color) -> some View {
    VStack(spacing: 4) {
      Text(value)
        .font(.system(size: 18, weight: .bold, design: .rounded))
        .foregroundStyle(color)
        .contentTransition(.numericText())
      Text(label)
        .font(GainsFont.label(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.mutedInk)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: Detail Artwork

  private var detailArtwork: some View {
    ZStack(alignment: .bottomLeading) {
      AsyncImage(url: URL(string: recipe.imageURL)) { phase in
        switch phase {
        case .success(let image): image.resizable().scaledToFill()
        default: fallbackArtwork(height: 240, fontSize: 76)
        }
      }
      .frame(height: 240)
      .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

      LinearGradient(colors: [Color.clear, GainsColor.ink.opacity(0.72)], startPoint: .center, endPoint: .bottom)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

      Text(recipe.category)
        .font(GainsFont.label(10))
        .tracking(2)
        .foregroundStyle(GainsColor.onCtaSurface.opacity(0.86))
        .padding(18)
    }
  }

  private func fallbackArtwork(height: CGFloat, fontSize: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
      .fill(LinearGradient(
        colors: [accentColor(recipe.goal), GainsColor.ctaSurface],
        startPoint: .topLeading, endPoint: .bottomTrailing
      ))
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
          .foregroundStyle(GainsColor.onCtaSurface)
      }
  }

  private func detailBadge(_ text: String, highlighted: Bool = false) -> some View {
    Text(text)
      .font(GainsFont.label(9))
      .tracking(1.8)
      .foregroundStyle(highlighted ? accentTextColor(recipe.goal) : GainsColor.softInk)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(highlighted ? accentColor(recipe.goal).opacity(0.24) : GainsColor.background.opacity(0.8))
      .clipShape(Capsule())
  }

  private func accentColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein: return GainsColor.lime
    case .abnehmen:    return Color(hex: "9FD3B0")
    case .zunehmen:    return Color(hex: "E3B96C")
    }
  }

  private func accentTextColor(_ goal: RecipeGoal) -> Color {
    switch goal {
    case .highProtein: return GainsColor.moss
    case .abnehmen:    return Color(hex: "2E6242")
    case .zunehmen:    return Color(hex: "6D4516")
    }
  }
}
