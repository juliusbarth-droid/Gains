import PhotosUI
import SwiftUI
import Vision

// MARK: - Food Photo Recognition Sheet

struct FoodPhotoRecognitionSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  let mealType: RecipeMealType
  let selectedDate: Date
  let onLog: () -> Void

  @State private var photoState: PhotoAnalysisState = .idle
  @State private var pickerItem: PhotosPickerItem?
  @State private var showsCamera = false

  enum PhotoAnalysisState {
    case idle
    case analyzing(UIImage)
    case result(UIImage, [RecognizedFoodSuggestion])
    case error(String)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        switch photoState {
        case .idle:
          idleView
        case .analyzing(let image):
          analyzingView(image: image)
        case .result(let image, let suggestions):
          resultView(image: image, suggestions: suggestions)
        case .error(let msg):
          errorView(msg)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          // 2026-04-29: BETA-Badge neben dem Titel — die KI-Erkennung
          // ist noch in Erprobung (Foundation-Models-Image-API auf iOS 26
          // ist neu, Genauigkeit variiert je nach Foto und Gericht).
          // Honest-Signal an den User damit er weiß, dass Fehler
          // möglich sind und manuelles Korrigieren erwartbar ist.
          HStack(spacing: 6) {
            Text("KI-Fotoerkennung")
              .font(GainsFont.label(15))
              .foregroundStyle(GainsColor.ink)
            Text("BETA")
              .font(.system(size: 9, weight: .bold, design: .rounded))
              .tracking(0.8)
              .foregroundStyle(GainsColor.lime)
              .padding(.horizontal, 5)
              .padding(.vertical, 2)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
              .overlay(Capsule().stroke(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.hairline))
          }
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
        if case .result = photoState {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              withAnimation { photoState = .idle }
            } label: {
              Image(systemName: "arrow.counterclockwise")
                .foregroundStyle(GainsColor.softInk)
            }
          }
        }
      }
      .sheet(isPresented: $showsCamera) {
        CameraImagePicker { image in
          if let image {
            startAnalysis(image: image)
          }
        }
      }
      .onChange(of: pickerItem) { _, newItem in
        Task {
          if let data = try? await newItem?.loadTransferable(type: Data.self),
             let image = UIImage(data: data) {
            startAnalysis(image: image)
          }
        }
      }
    }
    .presentationDetents([.large])
  }

  // MARK: Idle View

  private var idleView: some View {
    VStack(spacing: 32) {
      Spacer()

      VStack(spacing: 16) {
        ZStack {
          Circle()
            .fill(GainsColor.lime.opacity(0.1))
            .frame(width: 100, height: 100)
          Image(systemName: "camera.viewfinder")
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(GainsColor.lime)
        }

        VStack(spacing: 8) {
          HStack(spacing: 8) {
            Text("Mahlzeit fotografieren")
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)
            Text("BETA")
              .font(.system(size: 9, weight: .bold, design: .rounded))
              .tracking(0.8)
              .foregroundStyle(GainsColor.lime)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
              .overlay(Capsule().stroke(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.hairline))
          }
          Text("Die KI erkennt Lebensmittel auf dem Foto\nund schlägt dir die passenden Kalorien vor.")
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
            .multilineTextAlignment(.center)
        }
      }

      VStack(spacing: 12) {
        // Camera
        Button {
          showsCamera = true
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "camera.fill")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(GainsColor.moss)
              .frame(width: 44, height: 44)
              .background(GainsColor.lime.opacity(0.15))
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
              Text("Foto aufnehmen")
                .font(GainsFont.label(15))
                .foregroundStyle(GainsColor.ink)
              Text("Kamera öffnen und Mahlzeit fotografieren")
                .font(GainsFont.label(11))
                .foregroundStyle(GainsColor.mutedInk)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(GainsColor.mutedInk)
          }
          .padding(16)
          .background(GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous).stroke(GainsColor.border.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)

        // Photo library
        PhotosPicker(selection: $pickerItem, matching: .images) {
          HStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(Color(hex: "5BC4F5"))
              .frame(width: 44, height: 44)
              .background(Color(hex: "5BC4F5").opacity(0.12))
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
              Text("Aus Fotobibliothek")
                .font(GainsFont.label(15))
                .foregroundStyle(GainsColor.ink)
              Text("Bestehendes Foto aus der Galerie wählen")
                .font(GainsFont.label(11))
                .foregroundStyle(GainsColor.mutedInk)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(GainsColor.mutedInk)
          }
          .padding(16)
          .background(GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous).stroke(GainsColor.border.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 24)

      // Info-Chip — wechselt das Wording je nach aktivem Pfad und
      // weist transparent auf den BETA-Status hin. Apple Foundation
      // Models hat höchste Prio (on-device, gratis), dann Gemini wenn
      // explizit per Key konfiguriert, sonst Apple-Vision-Fallback.
      VStack(spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: aiInfoChipIcon)
            .font(.system(size: 11))
            .foregroundStyle(aiInfoChipColor)
          Text(aiInfoChipText)
            .font(.system(size: 11))
            .foregroundStyle(GainsColor.mutedInk)
        }
        Text("Beta — Ergebnisse bitte vor dem Loggen prüfen.")
          .font(.system(size: 10))
          .foregroundStyle(GainsColor.mutedInk.opacity(0.8))
      }
      .padding(.horizontal, 24)
      .multilineTextAlignment(.center)

      Spacer()
    }
  }

  // MARK: Analyzing View

  private func analyzingView(image: UIImage) -> some View {
    VStack(spacing: 28) {
      Spacer()

      // Photo preview
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .stroke(GainsColor.lime, lineWidth: 2)
        )
        .shadow(color: GainsColor.lime.opacity(0.3), radius: 16)

      // Analyzing indicator
      VStack(spacing: 16) {
        ScanningDotsView()
        Text("KI analysiert dein Foto…")
          .font(GainsFont.label(16))
          .foregroundStyle(GainsColor.ink)
        Text("Lebensmittel werden erkannt und\nKalorien automatisch berechnet.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .multilineTextAlignment(.center)
      }

      Spacer()
    }
  }

  // MARK: Result View

  private func resultView(image: UIImage, suggestions: [RecognizedFoodSuggestion]) -> some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 20) {
        // Analyzed photo header
        HStack(spacing: 16) {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(GainsColor.lime)
              Text(suggestions.isEmpty ? "Nichts erkannt" : "\(suggestions.count) Lebensmittel erkannt")
                .font(GainsFont.label(14))
                .foregroundStyle(GainsColor.ink)
              Text("BETA")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(GainsColor.lime)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(GainsColor.lime.opacity(0.18))
                .clipShape(Capsule())
            }
            Text("Wähle die passenden aus oder suche manuell. KI-Vorschläge können fehlerhaft sein — Gramm und Werte vor dem Loggen kurz prüfen.")
              .font(GainsFont.label(12))
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(4)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(16)
        .gainsCardStyle(GainsColor.card)

        // AI Suggestions
        if !suggestions.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("KI-Vorschläge")
              .font(GainsFont.label(12))
              .foregroundStyle(GainsColor.mutedInk)
              .padding(.horizontal, 4)

            VStack(spacing: 10) {
              ForEach(suggestions) { suggestion in
                PhotoSuggestionCard(
                  suggestion: suggestion,
                  mealType: mealType,
                  selectedDate: selectedDate,
                  onLog: {
                    dismiss()
                    onLog()
                  }
                )
                .environmentObject(store)
              }
            }
          }
        }

        // Manual search section
        ManualFoodSearchSection(
          mealType: mealType,
          selectedDate: selectedDate,
          onLog: {
            dismiss()
            onLog()
          }
        )
        .environmentObject(store)

        // Erneut scannen
        Button {
          withAnimation { photoState = .idle }
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
            Text("Erneut scannen")
          }
          .font(GainsFont.label(14))
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity).frame(height: 46)
          .background(GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
      }
      .padding(20)
      .padding(.bottom, 10)
    }
  }

  // MARK: Error View

  private func errorView(_ message: String) -> some View {
    VStack(spacing: 24) {
      Spacer()
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(GainsColor.ember)
      Text("Erkennung fehlgeschlagen")
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)
      Text(message)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
      Button { withAnimation { photoState = .idle } } label: {
        Text("Erneut versuchen")
          .font(GainsFont.label(15))
          .foregroundStyle(GainsColor.onLime)
          .frame(width: 200, height: 50)
          .background(GainsColor.lime)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      }
      .buttonStyle(.plain)
      Spacer()
    }
  }

  // MARK: AI Info-Chip Helpers
  //
  // Liefert Icon/Farbe/Text für die kleine Statuszeile unten am Idle-Screen,
  // damit der User weiß welche Engine gerade aktiv wäre. Reihenfolge:
  // Apple Foundation Models (iOS 26 + Apple Intelligence, on-device,
  // gratis) → Gemini (nur wenn Key konfiguriert) → Apple-Vision-Fallback.

  private var aiInfoChipIcon: String {
    if AppleFoundationModelsClient.isAvailable { return "sparkles" }
    if GeminiFoodVisionClient.isAvailable { return "sparkles" }
    return "info.circle"
  }

  private var aiInfoChipColor: Color {
    if AppleFoundationModelsClient.isAvailable || GeminiFoodVisionClient.isAvailable {
      return GainsColor.lime
    }
    return GainsColor.mutedInk
  }

  private var aiInfoChipText: String {
    if AppleFoundationModelsClient.isAvailable {
      return "On-Device-KI erkennt Lebensmittel + schätzt Gramm"
    }
    if GeminiFoodVisionClient.isAvailable {
      return "Cloud-KI erkennt Lebensmittel + schätzt Gramm"
    }
    return "Schnellerkennung — beste Qualität auf iPhone 15 Pro+"
  }

  // MARK: Analysis

  private func startAnalysis(image: UIImage) {
    withAnimation { photoState = .analyzing(image) }
    FoodImageAnalyzer.analyze(image: image, mealHint: mealType.geminiHint) { suggestions in
      withAnimation {
        // Always go to result view — even if empty, user can search manually
        photoState = .result(image, suggestions)
      }
    }
  }
}

// MARK: - Manual Food Search Section

private struct ManualFoodSearchSection: View {
  @EnvironmentObject private var store: GainsStore
  let mealType: RecipeMealType
  let selectedDate: Date
  let onLog: () -> Void

  @State private var searchText = ""
  @State private var isExpanded = true

  private var filteredFoods: [FoodItem] {
    let db = FoodItem.database
    if searchText.isEmpty { return db }
    let q = searchText.lowercased()
    return db.filter { $0.name.lowercased().contains(q) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Header
      Button {
        withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
      } label: {
        HStack {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text("Manuell suchen")
            .font(GainsFont.label(13))
            .foregroundStyle(GainsColor.ink)
          Spacer()
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.mutedInk)
        }
        .padding(.horizontal, 4)
      }
      .buttonStyle(.plain)

      if isExpanded {
        // Search bar
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 14))
            .foregroundStyle(GainsColor.mutedInk)
          TextField("Lebensmittel suchen…", text: $searchText)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
            .autocorrectionDisabled()
          if !searchText.isEmpty {
            Button { searchText = "" } label: {
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

        // Results
        if filteredFoods.isEmpty {
          Text("Kein Lebensmittel gefunden.")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.mutedInk)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
          VStack(spacing: 8) {
            ForEach(filteredFoods) { food in
              ManualFoodRow(
                food: food,
                mealType: mealType,
                selectedDate: selectedDate,
                onLog: onLog
              )
              .environmentObject(store)
            }
          }
        }
      }
    }
    .padding(16)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous).stroke(GainsColor.border.opacity(0.5), lineWidth: 1))
  }
}

// MARK: - Manual Food Row

private struct ManualFoodRow: View {
  @EnvironmentObject private var store: GainsStore
  let food: FoodItem
  let mealType: RecipeMealType
  let selectedDate: Date
  let onLog: () -> Void

  @State private var grams: Int = 100
  @State private var isExpanded = false
  @State private var isLogged = false

  private var calories: Int {
    Int((Double(food.caloriesPer100g) * Double(grams) / 100.0).rounded())
  }

  var body: some View {
    VStack(spacing: 0) {
      // Row header
      Button {
        withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
      } label: {
        HStack(spacing: 12) {
          Text(food.emoji)
            .font(.system(size: 22))
            .frame(width: 38, height: 38)
            .background(GainsColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

          VStack(alignment: .leading, spacing: 2) {
            Text(food.name)
              .font(GainsFont.label(14))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            Text("\(food.caloriesPer100g) kcal · \(Int(food.proteinPer100g))g P · \(Int(food.carbsPer100g))g K · \(Int(food.fatPer100g))g F pro 100g")
              .font(.system(size: 10))
              .foregroundStyle(GainsColor.mutedInk)
          }

          Spacer()

          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.mutedInk)
        }
        .padding(.vertical, 10)
      }
      .buttonStyle(.plain)

      if isExpanded {
        Divider()
          .background(GainsColor.border.opacity(0.5))
          .padding(.vertical, 6)

        HStack(spacing: 14) {
          // Stepper
          Button {
            if grams > 10 { grams = max(10, grams - 10) }
          } label: {
            Image(systemName: "minus")
              .font(.system(size: 13, weight: .bold))
              .frame(width: 32, height: 32)
              .background(GainsColor.elevated)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .foregroundStyle(GainsColor.softInk)

          Text("\(grams) g")
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(GainsColor.ink)
            .frame(minWidth: 54)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3), value: grams)

          Button {
            grams = min(800, grams + 10)
          } label: {
            Image(systemName: "plus")
              .font(.system(size: 13, weight: .bold))
              .frame(width: 32, height: 32)
              .background(GainsColor.elevated)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
          .foregroundStyle(GainsColor.softInk)

          Spacer()

          Text("\(calories) kcal")
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(GainsColor.ink)

          // Log button
          Button {
            guard !isLogged else { return }
            isLogged = true
            let logName: String = {
              if let brand = food.brand, !brand.isEmpty {
                return "\(brand) \(food.name)"
              }
              return food.name
            }()
            store.logNutritionEntry(
              title: "\(food.emoji) \(logName) (\(grams)g)",
              mealType: mealType,
              calories: calories,
              protein: Int((food.proteinPer100g * Double(grams) / 100).rounded()),
              carbs:   Int((food.carbsPer100g   * Double(grams) / 100).rounded()),
              fat:     Int((food.fatPer100g     * Double(grams) / 100).rounded())
            )
            onLog()
          } label: {
            HStack(spacing: 5) {
              Image(systemName: isLogged ? "checkmark" : "plus")
                .font(.system(size: 11, weight: .bold))
              Text(isLogged ? "Geloggt" : "Eintragen")
                .font(GainsFont.label(12))
            }
            .foregroundStyle(isLogged ? GainsColor.moss : GainsColor.onLime)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(isLogged ? GainsColor.lime.opacity(0.2) : GainsColor.lime)
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .animation(.spring(response: 0.3), value: isLogged)
        }
        .padding(.bottom, 6)
      }
    }
  }
}

// MARK: - Photo Suggestion Card

private struct PhotoSuggestionCard: View {
  @EnvironmentObject private var store: GainsStore
  let suggestion: RecognizedFoodSuggestion
  let mealType: RecipeMealType
  let selectedDate: Date
  let onLog: () -> Void

  @State private var grams: Int
  @State private var isLogged = false

  // N3-Fix (2026-05-01): Edit-Flow für KI-Erkennungen.
  // Wenn die KI einen falschen Namen oder falsche Makros liefert, kann
  // der User die Werte direkt hier korrigieren (Name + per-100g) ohne
  // den Foto-Flow zu verwerfen. Gramm-Eingabe bleibt erhalten — das war
  // der häufigste Korrektur-Reibungspunkt im Audit.
  @State private var showsOverride = false
  @State private var editedName: String
  @State private var editedKcal: Int
  @State private var editedProtein: Double
  @State private var editedCarbs: Double
  @State private var editedFat: Double

  init(suggestion: RecognizedFoodSuggestion, mealType: RecipeMealType, selectedDate: Date, onLog: @escaping () -> Void) {
    self.suggestion = suggestion
    self.mealType = mealType
    self.selectedDate = selectedDate
    self.onLog = onLog
    _grams = State(initialValue: suggestion.defaultGrams)
    _editedName = State(initialValue: suggestion.name)
    _editedKcal = State(initialValue: suggestion.caloriesPer100g)
    _editedProtein = State(initialValue: suggestion.proteinPer100g)
    _editedCarbs = State(initialValue: suggestion.carbsPer100g)
    _editedFat = State(initialValue: suggestion.fatPer100g)
  }

  private var displayKcalPer100g: Int { editedKcal }
  private var displayProteinPer100g: Double { editedProtein }
  private var displayCarbsPer100g: Double { editedCarbs }
  private var displayFatPer100g: Double { editedFat }
  private var displayName: String { editedName.isEmpty ? suggestion.name : editedName }

  private var calories: Int {
    Int((Double(displayKcalPer100g) * Double(grams) / 100.0).rounded())
  }

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        Text(suggestion.emoji)
          .font(.system(size: 28))
          .frame(width: 52, height: 52)
          .background(GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(displayName)
              .font(GainsFont.label(15))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            confidenceChip(suggestion.confidence)

            // Edit-Pencil — N3-Fix
            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showsOverride.toggle()
              }
            } label: {
              Image(systemName: showsOverride ? "checkmark.circle.fill" : "pencil")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(showsOverride ? GainsColor.moss : GainsColor.softInk)
                .frame(width: 22, height: 22)
                .background(GainsColor.elevated)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showsOverride ? "Korrektur fertig" : "Erkennung korrigieren")
          }
          HStack(spacing: 8) {
            macroTag("P: \(Int(displayProteinPer100g))g", color: GainsColor.lime)
            macroTag("K: \(Int(displayCarbsPer100g))g", color: Color(hex: "5BC4F5"))
            macroTag("F: \(Int(displayFatPer100g))g", color: Color(hex: "FF8A4A"))
            Text("pro 100g")
              .font(GainsFont.label(10))
              .foregroundStyle(GainsColor.mutedInk)
          }
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text("\(calories)")
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundStyle(GainsColor.ink)
          Text("kcal")
            .font(GainsFont.label(10))
            .foregroundStyle(GainsColor.mutedInk)
        }
      }

      // Override-Editor (N3) — kollabiert standardmäßig.
      if showsOverride {
        VStack(alignment: .leading, spacing: 10) {
          Text("KORRIGIEREN")
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(GainsColor.softInk)
          TextField("Lebensmittel", text: $editedName)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.ink)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(GainsColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          HStack(spacing: 8) {
            overrideField(label: "kcal", value: Binding(
              get: { Double(editedKcal) },
              set: { editedKcal = Int($0.rounded()) }
            ), step: 5, max: 900)
            overrideField(label: "P", value: $editedProtein, step: 1, max: 99)
            overrideField(label: "K", value: $editedCarbs, step: 1, max: 99)
            overrideField(label: "F", value: $editedFat, step: 1, max: 99)
          }
          Text("pro 100g · Werte werden mit deiner Gramm-Eingabe verrechnet.")
            .font(GainsFont.label(10))
            .foregroundStyle(GainsColor.mutedInk)
        }
        .padding(10)
        .background(GainsColor.elevated.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
      }

      // Gram stepper
      HStack(spacing: 14) {
        Button {
          if grams > 10 { grams = max(10, grams - 10) }
        } label: {
          Image(systemName: "minus")
            .font(.system(size: 13, weight: .bold))
            .frame(width: 34, height: 34)
            .background(GainsColor.elevated)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(GainsColor.softInk)

        Text("\(grams) g")
          .font(.system(size: 16, weight: .semibold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .frame(minWidth: 60)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.3), value: grams)

        Button {
          grams = min(800, grams + 10)
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 13, weight: .bold))
            .frame(width: 34, height: 34)
            .background(GainsColor.elevated)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(GainsColor.softInk)

        Spacer()

        // Log button
        Button {
          guard !isLogged else { return }
          isLogged = true
          store.logNutritionEntry(
            title: "\(suggestion.emoji) \(displayName) (\(grams)g)",
            mealType: mealType,
            calories: calories,
            protein: Int((displayProteinPer100g * Double(grams) / 100).rounded()),
            carbs:   Int((displayCarbsPer100g   * Double(grams) / 100).rounded()),
            fat:     Int((displayFatPer100g     * Double(grams) / 100).rounded())
          )
          onLog()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: isLogged ? "checkmark" : "plus")
              .font(.system(size: 12, weight: .bold))
            Text(isLogged ? "Geloggt" : "Eintragen")
              .font(GainsFont.label(13))
          }
          .foregroundStyle(isLogged ? GainsColor.moss : GainsColor.onLime)
          .padding(.horizontal, 14)
          .frame(height: 36)
          .background(isLogged ? GainsColor.lime.opacity(0.2) : GainsColor.lime)
          .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isLogged)
      }
    }
    .padding(14)
    .gainsCardStyle(GainsColor.card)
  }

  /// Kompakter Stepper für die Override-Felder (kcal/P/K/F per 100g).
  private func overrideField(label: String, value: Binding<Double>, step: Double, max: Double) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.label(9))
        .tracking(1.0)
        .foregroundStyle(GainsColor.softInk)
      HStack(spacing: 4) {
        Button {
          value.wrappedValue = Swift.max(0, value.wrappedValue - step)
        } label: {
          Image(systemName: "minus")
            .font(.system(size: 9, weight: .bold))
            .frame(width: 22, height: 22)
            .background(GainsColor.background)
            .clipShape(Circle())
            .foregroundStyle(GainsColor.softInk)
        }
        .buttonStyle(.plain)
        Text("\(Int(value.wrappedValue))")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .frame(minWidth: 26)
        Button {
          value.wrappedValue = Swift.min(max, value.wrappedValue + step)
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 9, weight: .bold))
            .frame(width: 22, height: 22)
            .background(GainsColor.background)
            .clipShape(Circle())
            .foregroundStyle(GainsColor.softInk)
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func confidenceChip(_ confidence: Double) -> some View {
    let pct = Int(confidence * 100)
    let color: Color = confidence > 0.7 ? GainsColor.lime : confidence > 0.4 ? Color(hex: "FF8A4A") : GainsColor.border
    return Text("\(pct)%")
      .font(.system(size: 10, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(color.opacity(0.12))
      .clipShape(Capsule())
  }

  private func macroTag(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: 10, weight: .medium))
      .foregroundStyle(color)
      .padding(.horizontal, 5)
      .padding(.vertical, 2)
      .background(color.opacity(0.1))
      .clipShape(Capsule())
  }
}

// MARK: - Scanning Dots Animation

private struct ScanningDotsView: View {
  @State private var phase = 0
  // Stabilitäts-Fix: Timer-Referenz halten, sonst lief der Timer endlos
  // weiter — auch nach Dismiss der View. Jetzt explizit in `onDisappear`
  // invalidieren, damit kein orphaned Timer den `phase`-State eines
  // bereits verworfenen View-Snapshots mutiert.
  @State private var animationTimer: Timer?

  var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<3, id: \.self) { i in
        Circle()
          .fill(GainsColor.lime)
          .frame(width: 10, height: 10)
          .scaleEffect(phase == i ? 1.4 : 0.8)
          .opacity(phase == i ? 1.0 : 0.4)
          .animation(.easeInOut(duration: 0.4).delay(Double(i) * 0.15), value: phase)
      }
    }
    .onAppear {
      animationTimer?.invalidate()
      animationTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { _ in
        phase = (phase + 1) % 3
      }
    }
    .onDisappear {
      animationTimer?.invalidate()
      animationTimer = nil
    }
  }
}

// MARK: - Camera Image Picker (UIKit wrapper)

struct CameraImagePicker: UIViewControllerRepresentable {
  let onImage: (UIImage?) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
    picker.delegate = context.coordinator
    picker.allowsEditing = false
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let onImage: (UIImage?) -> Void
    init(onImage: @escaping (UIImage?) -> Void) { self.onImage = onImage }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      picker.dismiss(animated: true)
      onImage(info[.originalImage] as? UIImage)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      picker.dismiss(animated: true)
      onImage(nil)
    }
  }
}

// MARK: - Food Recognition Engine

struct RecognizedFoodSuggestion: Identifiable {
  let id = UUID()
  let name: String
  let emoji: String
  let confidence: Double
  let caloriesPer100g: Int
  let proteinPer100g: Double
  let carbsPer100g: Double
  let fatPer100g: Double
  let defaultGrams: Int
}

enum FoodImageAnalyzer {

  /// Drei-Stufen-Pipeline, in dieser Reihenfolge:
  ///   1. Apple Foundation Models (iOS 26 + Apple Intelligence) — on-device,
  ///      gratis, kein Setup. Beste Qualität ohne Netz/Key.
  ///   2. Gemini Vision API — nur wenn ein Key konfiguriert ist (im
  ///      Default-Flow inaktiv, da wir die Key-UI entfernt haben). Bleibt
  ///      als Code drin für späteren hardcoded-Backup-Pfad oder Backend-Proxy.
  ///   3. Apple Vision (`VNClassifyImageRequest`) mit Saliency-Cropping +
  ///      Multi-Region-Pass — der echte Offline-Fallback.
  ///
  /// `mealHint` hilft den LLM-Pfaden beim Frühstück nicht erst Hauptgerichte
  /// zu schlagen; die Apple-Vision-Stufe ignoriert ihn.
  ///
  /// Completion läuft IMMER auf Main, damit Caller direkt UI-State setzen
  /// können ohne weiteres `DispatchQueue.main.async`.
  static func analyze(image: UIImage,
                      mealHint: String? = nil,
                      completion: @escaping ([RecognizedFoodSuggestion]) -> Void) {

    // PRIO 1: Apple Foundation Models (on-device, gratis).
    if AppleFoundationModelsClient.isAvailable {
      Task.detached(priority: .userInitiated) {
        do {
          let suggestions = try await AppleFoundationModelsClient.analyze(image: image, mealHint: mealHint)
          await MainActor.run {
            if suggestions.isEmpty {
              tryGeminiOrLocal(image: image, mealHint: mealHint, completion: completion)
            } else {
              completion(suggestions)
            }
          }
        } catch {
          await MainActor.run {
            tryGeminiOrLocal(image: image, mealHint: mealHint, completion: completion)
          }
        }
      }
      return
    }

    tryGeminiOrLocal(image: image, mealHint: mealHint, completion: completion)
  }

  /// Stufen 2+3: Gemini wenn Key konfiguriert, sonst direkt Apple Vision.
  private static func tryGeminiOrLocal(image: UIImage,
                                        mealHint: String?,
                                        completion: @escaping ([RecognizedFoodSuggestion]) -> Void) {
    if GeminiFoodVisionClient.isAvailable {
      Task.detached(priority: .userInitiated) {
        do {
          let suggestions = try await GeminiFoodVisionClient.analyze(image: image, mealHint: mealHint)
          await MainActor.run {
            if suggestions.isEmpty {
              localAnalyze(image: image, completion: completion)
            } else {
              completion(suggestions)
            }
          }
        } catch {
          await MainActor.run {
            localAnalyze(image: image, completion: completion)
          }
        }
      }
    } else {
      localAnalyze(image: image, completion: completion)
    }
  }

  /// Apple-Vision-Pfad mit Saliency-Cropping + Multi-Region-Pass.
  /// Statt nur das Gesamtbild zu klassifizieren (verwässert durch
  /// Tisch/Hintergrund) crawlen wir hier den salienten Bereich + das
  /// Center-Crop und mergen die Vorschläge nach höchster Confidence.
  /// Letzter Fallback ist die Farbheuristik wenn alles leer bleibt.
  private static func localAnalyze(image: UIImage,
                                    completion: @escaping ([RecognizedFoodSuggestion]) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      let crops = saliencyAndCenterCrops(from: image)
      var bestByName: [String: RecognizedFoodSuggestion] = [:]

      for crop in crops {
        guard let cg = crop.cgImage else { continue }
        let request = VNClassifyImageRequest()
        request.usesCPUOnly = false

        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])

        guard let observations = request.results else { continue }
        let foodObs = observations
          .filter { $0.confidence > 0.05 }
          .prefix(30)

        for obs in foodObs {
          if let suggestion = mapVisionLabel(obs.identifier, confidence: Double(obs.confidence)) {
            // Bei Duplikaten gewinnt der Vorschlag mit höherer Confidence
            // (z. B. wenn Saliency-Crop "chicken" stärker erkennt als
            // das Vollbild).
            if let existing = bestByName[suggestion.name] {
              if suggestion.confidence > existing.confidence {
                bestByName[suggestion.name] = suggestion
              }
            } else {
              bestByName[suggestion.name] = suggestion
            }
          }
        }
      }

      // Top 5 nach Confidence
      var suggestions = Array(bestByName.values)
        .sorted { $0.confidence > $1.confidence }
        .prefix(5)
        .map { $0 }

      // Letzter Notnagel: Farbheuristik damit immer was angezeigt wird
      if suggestions.isEmpty {
        suggestions = smartFallbackAnalysis(image: image)
      }

      DispatchQueue.main.async { completion(suggestions) }
    }
  }

  // MARK: - Saliency & Cropping
  //
  // Apple's `VNGenerateAttentionBasedSaliencyImageRequest` liefert eine
  // Karte der Bereiche, auf die ein Mensch zuerst schauen würde — bei
  // Foodfotos meist exakt der Teller / das Hauptgericht. Wir nutzen
  // den ersten Bounding-Box-Vorschlag als Crop und klassifizieren
  // diesen Ausschnitt zusätzlich zum Gesamtbild + einem Center-Crop.

  private static func saliencyAndCenterCrops(from image: UIImage) -> [UIImage] {
    var result: [UIImage] = [image]

    // Center-Crop: 70% des Bildes mittig — erwischt fast immer den
    // Teller selbst, wenn der User halbwegs zentriert fotografiert hat.
    if let centerCrop = image.centerCropped(toFraction: 0.7) {
      result.append(centerCrop)
    }

    // Saliency-Crop: aufwändiger, aber bei Tellern auf Holztisch /
    // Restaurant-Setting massiv besser als Center-Crop.
    if let cg = image.cgImage {
      let request = VNGenerateAttentionBasedSaliencyImageRequest()
      let handler = VNImageRequestHandler(cgImage: cg, options: [:])
      try? handler.perform([request])

      if let observation = request.results?.first as? VNSaliencyImageObservation,
         let salientObject = observation.salientObjects?.first {
        // boundingBox ist normalisiert (0…1, Vision-Y ist von unten),
        // wir konvertieren zu UIKit-Koordinaten und croppen.
        let bb = salientObject.boundingBox
        let imageSize = CGSize(width: cg.width, height: cg.height)
        let cropRect = CGRect(
          x: bb.origin.x * imageSize.width,
          y: (1 - bb.origin.y - bb.size.height) * imageSize.height,
          width: bb.size.width * imageSize.width,
          height: bb.size.height * imageSize.height
        )
        if let cropped = cg.cropping(to: cropRect) {
          result.append(UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation))
        }
      }
    }

    return result
  }

  // MARK: - Comprehensive Vision label → Gains food mapping
  // Covers all 46 foods in FoodItem.database with many Apple Vision taxonomy variants

  private static func mapVisionLabel(_ label: String, confidence: Double) -> RecognizedFoodSuggestion? {
    let l = label.lowercased()

    // ── Protein ────────────────────────────────────────────────────────────
    if l.contains("chicken") || l.contains("poultry") || l.contains("grilled chicken") || l.contains("roast chicken") {
      return make("Hähnchenbrust", "🍗", 165, 31, 0, 3.6, 150, confidence)
    }
    if l.contains("turkey") || l.contains("turkey breast") {
      return make("Putenbrust", "🍗", 157, 30, 0, 3.5, 150, confidence)
    }
    if l.contains("tuna") || l.contains("thunfisch") {
      return make("Thunfisch (Dose)", "🐟", 116, 26, 0, 1.0, 130, confidence)
    }
    if l.contains("salmon") || l.contains("fish fillet") || l.contains("seafood") {
      return make("Lachs", "🐟", 208, 20, 0, 13, 150, confidence)
    }
    if l.contains("beef") || l.contains("ground beef") || l.contains("hamburger") || l.contains("mince") || l.contains("steak") || l.contains("meat") {
      return make("Rinderhackfleisch (mager)", "🥩", 215, 26, 0, 12, 200, confidence)
    }
    if l.contains("egg") || l.contains("fried egg") || l.contains("scrambled egg") || l.contains("boiled egg") || l.contains("omelette") {
      return make("Eier (1 Stück = 60g)", "🥚", 155, 13, 1.1, 11, 120, confidence)
    }
    if l.contains("tofu") || l.contains("soy") || l.contains("soybean") {
      return make("Tofu (natur)", "🧊", 76, 8, 2.0, 4.0, 150, confidence)
    }
    if l.contains("chickpea") || l.contains("garbanzo") {
      return make("Kichererbsen (gekocht)", "🫘", 164, 9, 27, 2.6, 150, confidence)
    }
    if l.contains("lentil") || l.contains("legume") || l.contains("pulse") {
      return make("Linsen (gekocht)", "🫘", 116, 9, 20, 0.4, 150, confidence)
    }

    // ── Dairy ──────────────────────────────────────────────────────────────
    if l.contains("quark") || l.contains("curd") || l.contains("cottage cheese") || l.contains("ricotta") {
      // prefer Magerquark for plain curd, Hüttenkäse for cottage
      if l.contains("cottage") {
        return make("Hüttenkäse", "🧀", 98, 11, 3.0, 4.3, 150, confidence)
      }
      return make("Magerquark", "🥛", 67, 12, 4.0, 0.3, 200, confidence)
    }
    if l.contains("greek yogurt") || l.contains("greek yoghurt") {
      return make("Griechischer Joghurt", "🫙", 97, 9, 4.0, 5.0, 200, confidence)
    }
    if l.contains("yogurt") || l.contains("yoghurt") {
      return make("Naturjoghurt (3,5%)", "🫙", 61, 3.5, 4.7, 3.5, 200, confidence)
    }
    if l.contains("mozzarella") {
      return make("Mozzarella", "🧀", 280, 19, 2.2, 22, 100, confidence)
    }
    if l.contains("cheese") || l.contains("käse") {
      return make("Mozzarella", "🧀", 280, 19, 2.2, 22, 80, confidence)
    }
    if l.contains("milk") || l.contains("dairy") {
      return make("Vollmilch", "🥛", 61, 3.2, 4.8, 3.3, 200, confidence)
    }

    // ── Carbs ──────────────────────────────────────────────────────────────
    if l.contains("oat") || l.contains("porridge") || l.contains("oatmeal") || l.contains("granola") {
      if l.contains("granola") || l.contains("muesli") || l.contains("müsli") {
        return make("Müsli (ungesüßt)", "🥣", 360, 10, 65, 6.0, 80, confidence)
      }
      return make("Haferflocken", "🌾", 389, 17, 66, 7.0, 80, confidence)
    }
    if l.contains("pasta") || l.contains("noodle") || l.contains("spaghetti") || l.contains("penne") || l.contains("fettuccine") || l.contains("linguine") || l.contains("macaroni") {
      return make("Vollkornnudeln (gekocht)", "🍝", 124, 5.0, 24, 1.0, 200, confidence)
    }
    if l.contains("rice") || l.contains("basmati") || l.contains("jasmine rice") || l.contains("fried rice") {
      return make("Basmati-Reis (gekocht)", "🍚", 130, 2.7, 28, 0.3, 200, confidence)
    }
    if l.contains("sweet potato") || l.contains("yam") {
      return make("Süßkartoffel", "🍠", 86, 1.6, 20, 0.1, 200, confidence)
    }
    if l.contains("potato") || l.contains("kartoffel") || l.contains("chips") || l.contains("french fries") || l.contains("fries") {
      return make("Kartoffeln (gekocht)", "🥔", 86, 2.0, 20, 0.1, 200, confidence)
    }
    if l.contains("bread") || l.contains("toast") || l.contains("loaf") || l.contains("bun") || l.contains("roll") || l.contains("brot") {
      return make("Vollkornbrot", "🍞", 247, 9.0, 41, 3.0, 60, confidence)
    }
    if l.contains("quinoa") {
      return make("Quinoa (gekocht)", "🌿", 120, 4.4, 22, 1.9, 180, confidence)
    }

    // ── Fruit ──────────────────────────────────────────────────────────────
    if l.contains("banana") {
      return make("Banane", "🍌", 89, 1.1, 23, 0.3, 120, confidence)
    }
    if l.contains("apple") || l.contains("apfel") {
      return make("Apfel", "🍎", 52, 0.3, 14, 0.2, 180, confidence)
    }
    if l.contains("blueberr") || l.contains("heidelbeer") {
      return make("Heidelbeeren", "🫐", 57, 0.7, 14, 0.3, 150, confidence)
    }
    if l.contains("orange") || l.contains("mandarin") || l.contains("tangerine") || l.contains("clementine") {
      return make("Orange", "🍊", 47, 0.9, 12, 0.1, 180, confidence)
    }
    if l.contains("strawberr") || l.contains("erdbeere") {
      return make("Erdbeeren", "🍓", 32, 0.7, 8.0, 0.3, 150, confidence)
    }
    if l.contains("mango") {
      return make("Mango", "🥭", 60, 0.8, 15, 0.4, 150, confidence)
    }
    if l.contains("fruit") || l.contains("berry") || l.contains("beere") {
      return make("Heidelbeeren", "🫐", 57, 0.7, 14, 0.3, 150, confidence)
    }

    // ── Vegetables ─────────────────────────────────────────────────────────
    if l.contains("broccoli") || l.contains("brokko") {
      return make("Brokkoli", "🥦", 34, 2.8, 7.0, 0.4, 200, confidence)
    }
    if l.contains("spinach") || l.contains("spinat") || l.contains("leafy green") || l.contains("salad") || l.contains("lettuce") || l.contains("kale") || l.contains("chard") {
      return make("Spinat", "🥬", 23, 2.9, 3.6, 0.4, 100, confidence)
    }
    if l.contains("tomato") || l.contains("tomate") || l.contains("cherry tomato") {
      return make("Tomaten", "🍅", 18, 0.9, 3.9, 0.2, 150, confidence)
    }
    if l.contains("cucumber") || l.contains("gurke") || l.contains("zucchini") || l.contains("courgette") {
      return make("Gurke", "🥒", 15, 0.7, 3.6, 0.1, 150, confidence)
    }
    if l.contains("pepper") || l.contains("paprika") || l.contains("capsicum") || l.contains("bell pepper") {
      return make("Paprika (rot)", "🫑", 31, 1.0, 7.0, 0.3, 150, confidence)
    }
    if l.contains("vegetable") || l.contains("veggie") || l.contains("gemüse") || l.contains("carrot") || l.contains("onion") || l.contains("celery") || l.contains("asparagus") || l.contains("cauliflower") {
      return make("Brokkoli", "🥦", 34, 2.8, 7.0, 0.4, 200, confidence)
    }

    // ── Fats ───────────────────────────────────────────────────────────────
    if l.contains("avocado") {
      return make("Avocado", "🥑", 160, 2.0, 9.0, 15, 100, confidence)
    }
    if l.contains("olive oil") || l.contains("olivenöl") || l.contains("olive") {
      return make("Olivenöl", "🫒", 884, 0, 0, 100, 15, confidence)
    }
    if l.contains("peanut butter") || l.contains("erdnussbutter") || l.contains("peanut") {
      return make("Erdnussbutter", "🥜", 588, 25, 20, 50, 30, confidence)
    }
    if l.contains("almond") || l.contains("mandel") {
      return make("Mandeln", "🌰", 579, 21, 22, 50, 30, confidence)
    }
    if l.contains("walnut") || l.contains("walnuss") || l.contains("pecan") {
      return make("Walnüsse", "🌰", 654, 15, 14, 65, 30, confidence)
    }
    if l.contains("cashew") {
      return make("Cashews", "🌰", 553, 18, 30, 44, 30, confidence)
    }
    if l.contains("nut") || l.contains("nuss") || l.contains("seed") {
      return make("Mandeln", "🌰", 579, 21, 22, 50, 30, confidence)
    }

    // ── Other ──────────────────────────────────────────────────────────────
    if l.contains("chocolate") || l.contains("schokolade") || l.contains("dark chocolate") {
      return make("Dunkle Schokolade (85%)", "🍫", 600, 8, 24, 43, 40, confidence)
    }
    if l.contains("coffee") || l.contains("kaffee") || l.contains("espresso") || l.contains("cappuccino") || l.contains("latte") {
      return make("Kaffee (schwarz)", "☕", 2, 0.3, 0, 0, 240, confidence)
    }
    if l.contains("hummus") || l.contains("dip") {
      return make("Hummus", "🫙", 177, 8, 14, 10, 80, confidence)
    }
    if l.contains("protein bar") || l.contains("energy bar") || l.contains("snack bar") {
      return make("Proteinriegel", "🍫", 350, 28, 30, 10, 60, confidence)
    }
    if l.contains("protein shake") || l.contains("smoothie") || l.contains("shake") {
      return make("Proteinshake (fertig)", "🥤", 40, 6, 3.0, 0.5, 330, confidence)
    }

    return nil
  }

  private static func make(
    _ name: String, _ emoji: String,
    _ kcal: Int, _ p: Double, _ c: Double, _ f: Double,
    _ defaultG: Int,
    _ confidence: Double
  ) -> RecognizedFoodSuggestion {
    RecognizedFoodSuggestion(
      name: name, emoji: emoji,
      confidence: confidence,
      caloriesPer100g: kcal,
      proteinPer100g: p, carbsPer100g: c, fatPer100g: f,
      defaultGrams: defaultG
    )
  }

  // MARK: - Fallback: color/brightness heuristic

  private static func smartFallbackAnalysis(image: UIImage) -> [RecognizedFoodSuggestion] {
    let hue        = extractDominantHue(from: image)
    let brightness = extractBrightness(from: image)

    var suggestions: [RecognizedFoodSuggestion] = []

    if hue > 90 && hue < 160 {
      // Green → vegetables
      suggestions.append(make("Brokkoli",  "🥦", 34,  2.8, 7.0, 0.4, 200, 0.50))
      suggestions.append(make("Spinat",    "🥬", 23,  2.9, 3.6, 0.4, 100, 0.40))
    } else if hue < 40 || hue > 330 {
      // Warm/red → protein
      suggestions.append(make("Hähnchenbrust",          "🍗", 165, 31,  0,   3.6, 150, 0.48))
      suggestions.append(make("Rinderhackfleisch (mager)", "🥩", 215, 26,  0,  12,  200, 0.38))
    } else if hue > 40 && hue < 70 {
      // Yellow → banana or carbs
      suggestions.append(make("Banane",              "🍌", 89,  1.1, 23, 0.3, 120, 0.50))
      suggestions.append(make("Kartoffeln (gekocht)", "🥔", 86,  2.0, 20, 0.1, 200, 0.38))
    } else if brightness > 0.65 {
      // Bright/beige → carbs
      suggestions.append(make("Basmati-Reis (gekocht)",  "🍚", 130, 2.7, 28, 0.3, 200, 0.48))
      suggestions.append(make("Haferflocken",            "🌾", 389, 17,  66, 7.0,  80, 0.38))
    } else {
      // Generic mixed meal
      suggestions.append(make("Hähnchenbrust",          "🍗", 165, 31,  0,   3.6, 150, 0.42))
      suggestions.append(make("Basmati-Reis (gekocht)", "🍚", 130, 2.7, 28,  0.3, 200, 0.36))
      suggestions.append(make("Brokkoli",               "🥦",  34, 2.8,  7,  0.4, 150, 0.32))
    }

    return suggestions
  }

  private static func extractDominantHue(from image: UIImage) -> CGFloat {
    guard let cgImage = image.cgImage else { return 180 }
    let size = CGSize(width: 20, height: 20)
    let renderer = UIGraphicsImageRenderer(size: size)
    let small = renderer.image { _ in
      UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
    }
    var hue: CGFloat = 180, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
    if let color = small.averageColor() {
      color.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
      hue *= 360
    }
    return hue
  }

  private static func extractBrightness(from image: UIImage) -> CGFloat {
    guard let cgImage = image.cgImage else { return 0.5 }
    let size = CGSize(width: 20, height: 20)
    let renderer = UIGraphicsImageRenderer(size: size)
    let small = renderer.image { _ in
      UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
    }
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    small.averageColor()?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return b
  }
}

// MARK: - UIImage average color helper

extension UIImage {

  /// Liefert das mittige Crop des Bildes mit `fraction` (0…1) Kantenlänge —
  /// z. B. 0.7 → das mittlere 70%-Quadrat (relativ zur kleineren Seite).
  /// Wird vom Apple-Vision-Pfad genutzt, um den Teller stärker zu
  /// gewichten als Hintergrund/Tischrand. Liefert nil wenn `cgImage`
  /// fehlt oder das Crop-Rect ungültig wäre.
  func centerCropped(toFraction fraction: CGFloat) -> UIImage? {
    guard let cg = cgImage else { return nil }
    let w = CGFloat(cg.width)
    let h = CGFloat(cg.height)
    let side = min(w, h) * fraction
    let originX = (w - side) / 2
    let originY = (h - side) / 2
    let rect = CGRect(x: originX, y: originY, width: side, height: side)
    guard let cropped = cg.cropping(to: rect) else { return nil }
    return UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
  }

  func averageColor() -> UIColor? {
    guard let cgImage = cgImage else { return nil }
    let width = 1, height = 1
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let context = CGContext(data: nil, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: bitmapInfo.rawValue) else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let data = context.data else { return nil }
    let bytes = data.bindMemory(to: UInt8.self, capacity: 4)
    let r = CGFloat(bytes[0]) / 255
    let g = CGFloat(bytes[1]) / 255
    let b = CGFloat(bytes[2]) / 255
    return UIColor(red: r, green: g, blue: b, alpha: 1)
  }
}
