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
  // 2026-05-03 Cleanup: Vor diesem Pass nahm RecipesView ein
  // `viewModel: RecipesViewModel` an, das nirgends gelesen wurde — alle
  // Daten kommen aus `store.recipes` / `store.favoriteRecipeIDs`. Der
  // Parameter wurde von NutritionTrackerView mit `.mock` befüllt, was
  // den Eindruck erweckte, der Tab zeige Mock-Daten. War tot, jetzt raus.

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
    // 2026-05-14 (Polish-Loop 134): Layout-Sweep
    //   • Section-Spacing reduziert (xl → l), damit die Cards näher
    //     aneinander stehen und der Tab nicht „zerfasert" wirkt
    //   • SearchBar bekommt etwas mehr Abstand vor Tag-Browser (eigenes
    //     spacing-Element), damit der Bereichswechsel sichtbar wird
    // Body-Level Single-Pass Caching — statt bis zu 8× separate O(n)-Filter:
    //   • filteredRecipes (4× in headerStats+filteredListSection)
    //   • tagBrowserSection (1× per Tag → 4×)
    //   • tagSection (1× per Tag → 3×)
    // Jetzt: 1× filteredRecipes (bei Filtermode) + 1× tagByRecipe (kein Filtermode).
    let showFilters = hasAnyFilter || !searchText.isEmpty
    let filt: [Recipe] = showFilters ? filteredRecipes : []

    // [RecipeTag: [Recipe]] — einmaliger Durchlauf, nur wenn kein Filtermode.
    var tagGrouped: [RecipeTag: [Recipe]] = [:]
    if !showFilters {
      for recipe in store.recipes {
        for tag in recipe.tags { tagGrouped[tag, default: []].append(recipe) }
      }
    }

    return GainsScreen {
      VStack(alignment: .leading, spacing: GainsSpacing.l) {
        screenHeader(
          eyebrow: "FUEL / REZEPTE",
          title: "Rezepte & Inspiration",
          subtitle: "Mealprep, Airfryer, Schnell-Rezepte – für jedes Ziel das passende Meal."
        )

        if showFilters {
          headerStatsFor(filt)
        }
        searchBar

        if !hasAnyFilter {
          tagBrowserSectionFrom(tagGrouped)
            .padding(.top, GainsSpacing.xs)
        }

        if showFilters {
          goalFilterChips
          sortChips
        }
        activeFiltersSection

        if showFilters {
          filteredListSectionFor(filt)
        } else {
          featuredSection
          tagSectionFrom(tagGrouped, tag: .mealprep)
          tagSectionFrom(tagGrouped, tag: .airfryer)
          tagSectionFrom(tagGrouped, tag: .quick)
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

  private func headerStatsFor(_ filt: [Recipe]) -> some View {
    HStack(spacing: GainsSpacing.tight) {
      headerStatCard(value: "\(store.recipes.count)", label: "Rezepte")
      headerStatCard(value: "\(store.favoriteRecipeIDs.count)", label: "Favoriten")
      headerStatCard(value: "\(filt.count)", label: "Treffer")
    }
  }

  private func headerStatCard(value: String, label: String) -> some View {
    // 2026-05-14 (Polish-Loop 129): Header-Stat-Card mit Glow-Akzent +
    // Mono-Hero-Numerik.
    VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      Text(value)
        .font(.system(size: 24, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(GainsColor.ink)
        .shadow(color: GainsColor.lime.opacity(0.09), radius: 4)
      Text(label.uppercased())
        .font(GainsFont.eyebrow)
        .tracking(GainsTracking.eyebrowWide)
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // MARK: - Search

  private var searchBar: some View {
    // 2026-05-14 (Polish-Loop 123): Search-Bar mit Glas + dezentem
    // Akzent-Glow wenn Filter aktiv sind.
    let hasFilters = activeFilterCount > 0
    return HStack(spacing: GainsSpacing.s) {
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
        ZStack {
          if hasFilters && searchText.isEmpty {
            Circle()
              .fill(GainsColor.lime.opacity(0.16))
              .frame(width: 26, height: 26)
          }
          Image(
            systemName: searchText.isEmpty ? "slider.horizontal.3" : "xmark.circle.fill"
          )
          .foregroundStyle(
            hasFilters && searchText.isEmpty ? GainsColor.lime : GainsColor.softInk
          )
          .shadow(
            color: hasFilters && searchText.isEmpty ? GainsColor.lime.opacity(0.45) : .clear,
            radius: 3
          )
        }
      }
      .buttonStyle(.plain)
      .accessibilityLabel(searchText.isEmpty ? "Filter öffnen" : "Suche leeren")
    }
    .padding(.horizontal, GainsSpacing.m)
    .frame(height: 54)
    .background(
      ZStack {
        GainsColor.glassUndertone
        Rectangle().fill(.ultraThinMaterial)
        GainsColor.card.opacity(0.55)
        if hasFilters {
          RadialGradient(
            colors: [GainsColor.lime.opacity(0.10), .clear],
            center: .trailing,
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
            colors: hasFilters
              ? [GainsColor.lime.opacity(0.45), GainsColor.lime.opacity(0.12)]
              : [GainsColor.border.opacity(0.85), GainsColor.border.opacity(0.35)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
    .shadow(color: hasFilters ? GainsColor.lime.opacity(0.10) : .clear, radius: 8)
  }

  // MARK: - Tag Browser

  private func tagBrowserSectionFrom(_ grouped: [RecipeTag: [Recipe]]) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["BROWSE", "KATEGORIEN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: GainsSpacing.tight), GridItem(.flexible(), spacing: GainsSpacing.tight)],
        spacing: GainsSpacing.tight
      ) {
        tagBrowserCard(.mealprep, accent: Color(hex: "C3B3FF"), count: grouped[.mealprep]?.count ?? 0)
        tagBrowserCard(.airfryer, accent: Color(hex: "E3B96C"), count: grouped[.airfryer]?.count ?? 0)
        tagBrowserCard(.quick,    accent: GainsColor.lime,      count: grouped[.quick]?.count    ?? 0)
        tagBrowserCard(.budget,   accent: Color(hex: "9FD3B0"), count: grouped[.budget]?.count   ?? 0)
      }
    }
  }

  private func tagBrowserCard(_ tag: RecipeTag, accent: Color, count: Int) -> some View {
    let count = count
    return Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
        selectedTag = tag
      }
    } label: {
      VStack(alignment: .leading, spacing: GainsSpacing.tight) {
        HStack {
          // 2026-05-14 (Polish-Loop 130): Icon-Plate mit Radial-Glow
          // + Hairline-Border, Count als Mono.
          ZStack {
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .fill(accent.opacity(0.14))
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .fill(
                RadialGradient(
                  colors: [accent.opacity(0.32), .clear],
                  center: .topLeading,
                  startRadius: 0,
                  endRadius: 40
                )
              )
              .blendMode(.plusLighter)
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .strokeBorder(
                LinearGradient(
                  colors: [accent.opacity(0.55), accent.opacity(0.12)],
                  startPoint: .top,
                  endPoint: .bottom
                ),
                lineWidth: 0.6
              )
            Image(systemName: tag.systemImage)
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(accent)
              .shadow(color: accent.opacity(0.45), radius: 4)
          }
          .frame(width: 36, height: 36)
          .compositingGroup()
          .shadow(color: accent.opacity(0.22), radius: 6)

          Spacer()

          HStack(spacing: GainsSpacing.xxs) {
            Text("\(count)")
              .font(.system(size: 13, weight: .semibold, design: .monospaced))
              .foregroundStyle(GainsColor.ink)
            Text("Rezepte".uppercased())
              .font(GainsFont.eyebrow)
              .tracking(GainsTracking.eyebrowTight)
              .foregroundStyle(GainsColor.mutedInk)
          }
        }

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          // 2026-05-14 (Polish-Loop 131): tightere Typografie —
          // Title bekommt mehr Präsenz (semibold default), Subtitle
          // bleibt zurückhaltend und kompakt.
          Text(tag.title)
            .font(.system(size: 18, weight: .semibold))
            .tracking(-0.2)
            .foregroundStyle(GainsColor.ink)
          Text(tag.subtitle)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(GainsColor.softInk)
            .lineSpacing(2)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(GainsSpacing.m)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
  }

  // MARK: - Goal Chips

  private var goalFilterChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: GainsSpacing.tight) {
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
      HStack(spacing: GainsSpacing.xsPlus) {
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
              .tracking(GainsTracking.eyebrowTight)
              // 2026-05-31 (Design-Optim): aktiver Chip-Text moss → onLime.
              // moss-auf-lime hatte schwachen Kontrast; onLime (near-black) ist
              // die kanonische „Text-auf-Lime"-Farbe (GainsSegmentedPicker, alle
              // NEU-Badges) und liest auf der Lime-Fläche deutlich klarer.
              .foregroundStyle(sortOrder == order ? GainsColor.onLime : GainsColor.softInk)
              .padding(.horizontal, GainsSpacing.m)
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
        HStack(spacing: GainsSpacing.tight) {
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
              .padding(.horizontal, GainsSpacing.m)
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
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["TOP", "FÜR DICH"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.s) {
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

  private func tagSectionFrom(_ grouped: [RecipeTag: [Recipe]], tag: RecipeTag) -> some View {
    let recipes = Array((grouped[tag] ?? []).prefix(4))
    return Group {
      if !recipes.isEmpty {
        VStack(alignment: .leading, spacing: GainsSpacing.s) {
          HStack(spacing: GainsSpacing.tight) {
            // 2026-05-14 (Polish-Loop 132): Tag-Section Header mit
            // Icon-Halo (Glow + Edge-Gradient) + Mono-Wertepille.
            ZStack {
              Circle().fill(GainsColor.lime.opacity(0.10))
              Circle()
                .fill(
                  RadialGradient(
                    colors: [GainsColor.lime.opacity(0.28), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 28
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
              Image(systemName: tag.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GainsColor.lime)
                .shadow(color: GainsColor.lime.opacity(0.225), radius: 3)
            }
            .frame(width: 28, height: 28)
            .compositingGroup()
            .shadow(color: GainsColor.lime.opacity(0.09), radius: 4)

            VStack(alignment: .leading, spacing: 2) {
              Text(tag.title.uppercased())
                .font(GainsFont.eyebrow)
                .tracking(GainsTracking.eyebrowWide)
                .foregroundStyle(GainsColor.ink)
              Text(tag.subtitle)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(GainsColor.softInk)
                .lineLimit(1)
            }

            Spacer()

            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedTag = tag
              }
            } label: {
              HStack(spacing: 4) {
                Text("Alle")
                  .font(GainsFont.eyebrow)
                  .tracking(GainsTracking.eyebrowTight)
                Text("\(grouped[tag]?.count ?? 0)")
                  .font(.system(size: 11, weight: .semibold, design: .monospaced))
              }
              .foregroundStyle(GainsColor.onLime)
              .padding(.horizontal, GainsSpacing.s)
              .frame(height: 30)
              .background(
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
                        colors: [.clear, Color.black.opacity(0.14)],
                        startPoint: .center,
                        endPoint: .bottom
                      )
                    )
                }
              )
              .clipShape(Capsule())
              .compositingGroup()
              .shadow(color: GainsColor.lime.opacity(0.14), radius: 8)
            }
            .buttonStyle(.plain)
          }

          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GainsSpacing.s) {
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
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack {
        SlashLabel(
          parts: ["ALLE", "REZEPTE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(store.recipes.count)")
          .font(GainsFont.label(10))
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
      }

      // Perf (2026-05-31): LazyVStack — Rezeptzeilen (mit AsyncImage) erst
      // beim Scrollen dekodieren/bauen; die Liste wächst mit der Nutzung.
      LazyVStack(spacing: GainsSpacing.tight) {
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

  private func filteredListSectionFor(_ filt: [Recipe]) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack {
        SlashLabel(
          parts: filterEyebrowParts,
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(filt.count)")
          .font(GainsFont.label(10))
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
      }

      if filt.isEmpty {
        emptyState
      } else {
        LazyVStack(spacing: GainsSpacing.tight) {
          ForEach(filt) { recipe in
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

  // MARK: - Filter Chips

  private func filterChip(
    title: String,
    icon: String? = nil,
    isSelected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    // 2026-05-14 (Polish-Loop 133): Filter-Chip mit konsistenter
    // Switch-Sprache: aktiv = Lime-Inner-Light + Glow, inaktiv = Glas
    // mit Hairline.
    Button(action: action) {
      HStack(spacing: GainsSpacing.xs) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
        }
        Text(title)
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
      }
      .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.softInk)
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 36)
      .background(
        ZStack {
          if isSelected {
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
                  colors: [.clear, Color.black.opacity(0.14)],
                  startPoint: .center,
                  endPoint: .bottom
                )
              )
          } else {
            Capsule().fill(GainsColor.glassUndertone)
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(GainsColor.card.opacity(0.55))
          }
        }
      )
      .overlay(
        Capsule().strokeBorder(
          isSelected
            ? Color.clear
            : GainsColor.border.opacity(0.6),
          lineWidth: 1
        )
      )
      .clipShape(Capsule())
      .compositingGroup()
      .shadow(color: isSelected ? GainsColor.lime.opacity(0.28) : .clear, radius: 8)
    }
    .buttonStyle(.plain)
  }

  private func activeFilterChip(_ title: String) -> some View {
    // 2026-05-14 (Polish-Loop 133): Active-Filter-Display (read-only)
    // — sieht aus wie ein aktiver Chip mit reduzierter Intensität.
    Text(title)
      .font(GainsFont.eyebrow)
      .tracking(GainsTracking.eyebrowTight)
      .foregroundStyle(GainsColor.moss)
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 32)
      .background(
        ZStack {
          Capsule().fill(GainsColor.lime.opacity(0.18))
          Capsule()
            .fill(
              RadialGradient(
                colors: [GainsColor.lime.opacity(0.12), .clear],
                center: .leading,
                startRadius: 0,
                endRadius: 80
              )
            )
            .blendMode(.screen)
        }
      )
      .overlay(
        Capsule().strokeBorder(GainsColor.lime.opacity(0.32), lineWidth: 0.6)
      )
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
    if !favorites.isEmpty { return Array(favorites.prefix(4)) }
    return Array(store.recipes.sorted { $0.protein > $1.protein }.prefix(4))
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
  @State private var trackFeedbackToken = UUID()

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      ZStack(alignment: .topTrailing) {
        AsyncImage(url: URL(string: recipe.imageURL)) { phase in
          switch phase {
          case .success(let image): image.resizable().scaledToFill()
          default: fallbackArtwork
          }
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))

        LinearGradient(
          colors: [Color.clear, GainsColor.ink.opacity(0.7)],
          startPoint: .center, endPoint: .bottom
        )
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))

        // 2026-05-14 (Polish-Loop 135): Tag-Badge mit Inner-Light +
        // Bottom-Dim wie Primary-Pille.
        if let primaryTag = recipe.tags.first {
          HStack(spacing: GainsSpacing.xxs) {
            Image(systemName: primaryTag.systemImage).font(.system(size: 10, weight: .bold))
            Text(primaryTag.title.uppercased())
              .font(GainsFont.eyebrow)
              .tracking(GainsTracking.eyebrowTight)
          }
          .foregroundStyle(GainsColor.onLime)
          .padding(.horizontal, GainsSpacing.xsPlus)
          .frame(height: 22)
          .background(
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
            }
          )
          .clipShape(Capsule())
          .compositingGroup()
          .shadow(color: GainsColor.lime.opacity(0.16), radius: 6)
          .padding(GainsSpacing.tight)
        }

        // Category label (bottom-left) + Quick-Track button (bottom-right)
        HStack {
          Text(recipe.category.uppercased())
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.9))
            .shadow(color: Color.black.opacity(0.6), radius: 3)
          Spacer()
          // Quick-Track button mit Inner-Light + Glow
          Button {
            store.logRecipe(recipe)
            // 2026-05-15 (Audit-Loop 9): asyncAfter → Task. Identisches
            // Token-Pattern, aber die Task wird beim View-Teardown von
            // SwiftUI gecancelt; auf Geräten mit sehr schneller Multi-Tap-
            // Trace konnte sonst eine zweite Action den Token überschreiben
            // bevor die erste invalidiert war.
            let token = UUID()
            trackFeedbackToken = token
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { didTrack = true }
            Task { @MainActor in
              try? await Task.sleep(nanoseconds: 1_600_000_000)
              guard trackFeedbackToken == token else { return }
              withAnimation { didTrack = false }
            }
          } label: {
            ZStack {
              Circle().fill(didTrack ? GainsColor.lime : GainsColor.ink.opacity(0.7))
              if didTrack {
                Circle()
                  .fill(
                    LinearGradient(
                      colors: [Color.white.opacity(0.22), .clear],
                      startPoint: .top,
                      endPoint: .center
                    )
                  )
                  .blendMode(.plusLighter)
              }
              Image(systemName: didTrack ? "checkmark" : "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(didTrack ? GainsColor.moss : GainsColor.lime)
                .shadow(color: GainsColor.lime.opacity(didTrack ? 0 : 0.55), radius: 3)
            }
            .frame(width: 30, height: 30)
            .compositingGroup()
            .shadow(color: didTrack ? GainsColor.lime.opacity(0.32) : .clear, radius: 6)
            .scaleEffect(didTrack ? 1.15 : 1.0)
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, GainsSpacing.tight)
        .padding(.bottom, GainsSpacing.tight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .frame(height: 130)
      }

      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        // 2026-05-14 (Polish-Loop 131): Title leicht heavier + tighter
        // Tracking, damit Rezept-Cards typografisch konsistent zu den
        // Tag-Browser-Cards lesen.
        Text(recipe.title)
          .font(.system(size: 17, weight: .semibold))
          .tracking(-0.2)
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        // 2026-05-14 (Polish-Loop 87): Featured-Card Meta jetzt im
        // Mono-KPI-Stil — drei Werte mit kleinem Akzent-Dot.
        HStack(spacing: GainsSpacing.s) {
          recipeMetaPill(label: "KCAL", value: "\(recipe.calories)", accent: GainsColor.ember)
          recipeMetaPill(label: "PROT", value: "\(recipe.protein)g", accent: GainsColor.lime)
          recipeMetaPill(label: "ZEIT", value: "\(recipe.prepMinutes)m", accent: GainsColor.softInk)
        }
        .padding(.top, 2)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  private var fallbackArtwork: some View {
    RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
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

  /// 2026-05-14 (Polish-Loop 87): Meta-Pill für FeaturedRecipeCard —
  /// kleiner Akzent-Dot + Eyebrow + Mono-Wert. Wiederverwendbares
  /// KPI-Strip-Item-Pattern.
  private func recipeMetaPill(label: String, value: String, accent: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: GainsSpacing.xxs) {
        Circle()
          .fill(accent)
          .frame(width: 4, height: 4)
          .shadow(color: accent.opacity(0.55), radius: 2)
        Text(label)
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.mutedInk)
      }
      Text(value)
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(GainsColor.ink)
    }
  }
}

// MARK: - Compact Recipe Row

private struct CompactRecipeRow: View {
  @EnvironmentObject private var store: GainsStore
  let recipe: Recipe

  var body: some View {
    HStack(spacing: GainsSpacing.m) {
      AsyncImage(url: URL(string: recipe.imageURL)) { phase in
        switch phase {
        case .success(let image): image.resizable().scaledToFill()
        default: fallback
        }
      }
      .frame(width: 72, height: 72)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))

      VStack(alignment: .leading, spacing: 4) {
        // 2026-05-14 (Polish-Loop 131): tighteres tracking + konsis-
        // tente Hierarchie zu FeaturedRecipeCard.
        Text(recipe.title)
          .font(.system(size: 15, weight: .semibold))
          .tracking(-0.2)
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
          .multilineTextAlignment(.leading)

        // 2026-05-14 (Polish-Loop 86): Meta-Line jetzt mono mit
        // separaten Akzent-Werten — liest sich wie ein KPI-Strip.
        HStack(spacing: GainsSpacing.xs) {
          HStack(spacing: 2) {
            Text("\(recipe.calories)")
              .font(.system(size: 11, weight: .semibold, design: .monospaced))
              .foregroundStyle(GainsColor.ink)
            Text("kcal")
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.mutedInk)
          }
          Text("·").font(.system(size: 10)).foregroundStyle(GainsColor.mutedInk)
          HStack(spacing: 2) {
            Text("\(recipe.protein)g")
              .font(.system(size: 11, weight: .semibold, design: .monospaced))
              .foregroundStyle(GainsColor.lime)
            Text("P")
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.mutedInk)
          }
          Text("·").font(.system(size: 10)).foregroundStyle(GainsColor.mutedInk)
          HStack(spacing: 2) {
            Text("\(recipe.prepMinutes)")
              .font(.system(size: 11, weight: .semibold, design: .monospaced))
              .foregroundStyle(GainsColor.softInk)
            Text("min")
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(GainsColor.mutedInk)
          }
        }

        if let tag = recipe.tags.first {
          HStack(spacing: GainsSpacing.xxs) {
            Image(systemName: tag.systemImage).font(.system(size: 10, weight: .bold))
            Text(tag.title.uppercased()).font(GainsFont.eyebrow).tracking(GainsTracking.eyebrowTight)
          }
          .foregroundStyle(GainsColor.moss)
          .padding(.horizontal, GainsSpacing.xsPlus)
          .frame(height: 20)
          .background(
            ZStack {
              Capsule().fill(GainsColor.lime.opacity(0.18))
              Capsule()
                .fill(
                  LinearGradient(
                    colors: [GainsColor.lime.opacity(0.10), .clear],
                    startPoint: .top,
                    endPoint: .center
                  )
                )
                .blendMode(.plusLighter)
            }
          )
          .overlay(
            Capsule().strokeBorder(GainsColor.lime.opacity(0.32), lineWidth: 0.6)
          )
          .clipShape(Capsule())
        }
      }

      Spacer()

      let isFav = store.favoriteRecipeIDs.contains(recipe.id)
      Image(systemName: isFav ? "bookmark.fill" : "chevron.right")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(isFav ? GainsColor.lime : GainsColor.softInk)
        .shadow(color: isFav ? GainsColor.lime.opacity(0.45) : .clear, radius: 3)
    }
    .padding(GainsSpacing.s)
    .gainsCardStyle()
  }

  private var fallback: some View {
    RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
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
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
        screenHeader(
          eyebrow: "REZEPTE / FILTER",
          title: "Rezepte filtern",
          subtitle: "Stelle Meals nach Stil, Zeitpunkt, Dauer und Kalorien passend zusammen."
        )

        filterGroup(title: "Ernährungsstil") {
          VStack(spacing: GainsSpacing.tight) {
            ForEach(RecipeDietaryStyle.allCases.filter { $0 != .all }, id: \.self) { style in
              filterRow(title: style.title, icon: style.systemImage, isSelected: selectedDietaryStyle == style) {
                selectedDietaryStyle = selectedDietaryStyle == style ? .all : style
              }
            }
          }
        }

        filterGroup(title: "Mahlzeittyp") {
          VStack(spacing: GainsSpacing.tight) {
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

        HStack(spacing: GainsSpacing.s) {
          Button {
            onReset()
          } label: {
            Text("Zurücksetzen")
              .font(GainsFont.label(11))
              .tracking(1.4)
              .foregroundStyle(GainsColor.ink)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .gainsGlassCTA(accent: GainsColor.lime)
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
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
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
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Text(title)
        .font(GainsFont.label(11))
        .tracking(GainsTracking.eyebrowWide)
        .foregroundStyle(GainsColor.softInk)
      content()
    }
  }

  private func filterRow(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: GainsSpacing.s) {
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
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 56)
      .background(isSelected ? GainsColor.lime.opacity(0.25) : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func sliderSection(
    title: String, valueText: String, value: Binding<Double>,
    range: ClosedRange<Double>, step: Double
  ) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Text(title)
        .font(GainsFont.label(11))
        .tracking(GainsTracking.eyebrowWide)
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
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      recipeArtwork

      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: GainsSpacing.xs) {
          HStack(spacing: GainsSpacing.xsPlus) {
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
              HStack(spacing: GainsSpacing.xs) {
                ForEach(recipe.tags) { tag in
                  HStack(spacing: GainsSpacing.xxs) {
                    Image(systemName: tag.systemImage).font(.system(size: 10, weight: .bold))
                    Text(tag.title.uppercased()).font(GainsFont.label(9)).tracking(GainsTracking.eyebrowTight)
                  }
                  .foregroundStyle(GainsColor.softInk)
                  .padding(.horizontal, GainsSpacing.xsPlus)
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

      HStack(spacing: GainsSpacing.tight) {
        recipeStat("\(recipe.calories)", "kcal")
        recipeStat("\(recipe.protein)g", "Protein")
        recipeStat("\(recipe.carbs)g", "Carbs")
        recipeStat("\(recipe.fat)g", "Fett")
      }

      HStack(spacing: GainsSpacing.m) {
        Label("\(recipe.prepMinutes) Min", systemImage: "clock")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        Label("\(recipe.servings) Portion\(recipe.servings == 1 ? "" : "en")", systemImage: "person.2")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(GainsSpacing.l)
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
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))

      LinearGradient(colors: [Color.clear, GainsColor.ink.opacity(0.72)], startPoint: .center, endPoint: .bottom)
        .frame(height: 164)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))

      Text(recipe.category)
        .font(GainsFont.label(9))
        .tracking(GainsTracking.eyebrowWide)
        .foregroundStyle(GainsColor.onCtaSurface.opacity(0.86))
        .padding(GainsSpacing.m)
    }
  }

  private func recipeStat(_ value: String, _ label: String) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
      Text(value).font(GainsFont.title(17)).foregroundStyle(GainsColor.ink)
      Text(label).font(GainsFont.label(9)).tracking(GainsTracking.eyebrowWide).foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(GainsSpacing.tight)
    .background(GainsColor.background.opacity(0.8))
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private func recipeBadge(_ text: String, background: Color, foreground: Color) -> some View {
    Text(text)
      .font(GainsFont.label(9))
      .tracking(1.7)
      .foregroundStyle(foreground)
      .padding(.horizontal, GainsSpacing.tight)
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
    RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
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
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
        detailArtwork

        VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
          // Badges
          HStack(spacing: GainsSpacing.xsPlus) {
            detailBadge(recipe.category.uppercased())
            detailBadge(recipe.goal.title.uppercased(), highlighted: true)
            detailBadge(recipe.dietaryStyle.title.uppercased())
          }

          if !recipe.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: GainsSpacing.xs) {
                ForEach(recipe.tags) { tag in
                  HStack(spacing: GainsSpacing.xxs) {
                    Image(systemName: tag.systemImage).font(.system(size: 10, weight: .bold))
                    Text(tag.title.uppercased()).font(GainsFont.label(9)).tracking(1.4)
                  }
                  .foregroundStyle(GainsColor.moss)
                  .padding(.horizontal, GainsSpacing.tight)
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
          HStack(spacing: GainsSpacing.m) {
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
                  .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
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
                  .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
              }
              .buttonStyle(.plain)

              Text("Port.")
                .font(GainsFont.label(10))
                .foregroundStyle(GainsColor.softInk)
                .padding(.leading, GainsSpacing.xs)
            }
          }
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        }

        // Makro-Karte (skaliert mit Portionen)
        macroCard

        // Zutaten
        VStack(alignment: .leading, spacing: GainsSpacing.s) {
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
                  .padding(.horizontal, GainsSpacing.tight)
                  .frame(height: 24)
                  .background(GainsColor.elevated)
                  .clipShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }

          VStack(spacing: GainsSpacing.xsPlus) {
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
                HStack(spacing: GainsSpacing.s) {
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
                .padding(GainsSpacing.m)
                .background(
                  checkedIngredients.contains(index)
                    ? GainsColor.elevated
                    : GainsColor.card
                )
                .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
                .overlay(
                  RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
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
        VStack(alignment: .leading, spacing: GainsSpacing.s) {
          SlashLabel(
            parts: ["SCHRITTE", "KOCHEN"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )

          ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
            HStack(alignment: .top, spacing: GainsSpacing.s) {
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
            .padding(GainsSpacing.m)
            .gainsCardStyle()
          }
        }

        // Aktions-Buttons
        HStack(spacing: GainsSpacing.s) {
          Button {
            store.toggleFavoriteRecipe(recipe.id)
          } label: {
            HStack(spacing: GainsSpacing.xsPlus) {
              Image(systemName: store.favoriteRecipeIDs.contains(recipe.id) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15, weight: .semibold))
              Text(store.favoriteRecipeIDs.contains(recipe.id) ? "Gespeichert" : "Merken")
                .font(GainsFont.label(12))
                .tracking(GainsTracking.eyebrowTight)
            }
            .foregroundStyle(
              store.favoriteRecipeIDs.contains(recipe.id) ? accentTextColor(recipe.goal) : GainsColor.lime
            )
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(GainsColor.ctaSurface)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          }
          .buttonStyle(.plain)

          Button {
            store.logRecipe(recipe)
          } label: {
            HStack(spacing: GainsSpacing.xsPlus) {
              Image(systemName: "plus.circle.fill")
                .font(.system(size: 15, weight: .semibold))
              Text("Tracken")
                .font(GainsFont.label(12))
                .tracking(GainsTracking.eyebrowTight)
            }
            .foregroundStyle(GainsColor.moss)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: Makro-Karte

  private var macroCard: some View {
    VStack(spacing: GainsSpacing.m) {
      HStack(spacing: 0) {
        macroCell(value: "\(scaledCalories)", unit: "kcal", label: "Kalorien", color: GainsColor.ink)
        Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
        macroCell(value: "\(scaledProtein)g", unit: "", label: "Protein", color: GainsColor.lime)
        Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
        macroCell(value: "\(scaledCarbs)g", unit: "", label: "Carbs", color: GainsColor.accentCool)
        Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
        macroCell(value: "\(scaledFat)g", unit: "", label: "Fett", color: GainsColor.macroFat)
      }
      .animation(.spring(response: 0.4), value: scaledServings)

      if scaledServings != recipe.servings {
        Text("Hochgerechnet für \(scaledServings) Portion\(scaledServings == 1 ? "" : "en") (Originalrezept: \(recipe.servings))")
          .font(GainsFont.label(9))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.mutedInk)
          .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // Polish-Loop 193 (2026-05-14): Macro-Cell in Recipe-Detail mit Akzent-
  // Dot + Mono-Wert + Glow-Schatten — passt zu Nutrition Summary-KPI-Strip.
  private func macroCell(value: String, unit: String, label: String, color: Color) -> some View {
    VStack(spacing: GainsSpacing.xs) {
      HStack(spacing: 4) {
        Circle()
          .fill(color)
          .frame(width: 4, height: 4)
          .shadow(color: color.opacity(0.55), radius: 2)
        Text(label.uppercased())
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.mutedInk)
      }
      Text(value)
        .font(.system(size: 16, weight: .semibold, design: .monospaced))
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .contentTransition(.numericText())
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
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))

      LinearGradient(colors: [Color.clear, GainsColor.ink.opacity(0.72)], startPoint: .center, endPoint: .bottom)
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))

      Text(recipe.category)
        .font(GainsFont.label(10))
        .tracking(2)
        .foregroundStyle(GainsColor.onCtaSurface.opacity(0.86))
        .padding(GainsSpacing.l)
    }
  }

  private func fallbackArtwork(height: CGFloat, fontSize: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
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
      .tracking(GainsTracking.eyebrowWide)
      .foregroundStyle(highlighted ? accentTextColor(recipe.goal) : GainsColor.softInk)
      .padding(.horizontal, GainsSpacing.tight)
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
