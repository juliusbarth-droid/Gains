import Foundation
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Apple Foundation Models Client für Food-Erkennung
//
// 2026-04-29: Apple hat seit iOS 26 das `FoundationModels`-Framework, das
// auf Geräten mit Apple Intelligence (iPhone 15 Pro+, alle 16er, M-iPads)
// einen 3B-Parameter Multimodal-Modell on-device anbietet — KOSTENLOS,
// kein API-Key, kein Netzwerk, kein Setup.
//
// Wir nutzen das hier mit:
//   - strukturiertem Output via `@Generable` (entspricht Gemini's
//     responseSchema)
//   - Bild-Input via `Prompt`-Builder
//   - kurzem Prompt der mehrere Lebensmittel + Gramm-Schätzung verlangt
//
// Verfügbarkeitsprüfung läuft über `SystemLanguageModel.default.isAvailable`
// — das gibt `false` zurück auf älteren Geräten oder wenn der User Apple
// Intelligence nicht aktiviert hat. Dann fallen wir auf den lokalen
// Apple-Vision-Pfad zurück.
//
// Wichtig: Das Framework ist erst ab iOS 26 verfügbar. Auf iOS 17–25
// kompiliert die Datei dank `#if canImport(FoundationModels)` trotzdem,
// aber `isAvailable` liefert immer false.

enum AppleFoundationModelsClient {

  // MARK: - Verfügbarkeit

  /// True nur, wenn iOS 26+, FoundationModels-Framework vorhanden UND der
  /// System-LM auf dem Gerät bereit ist (Apple Intelligence aktiv,
  /// Modell heruntergeladen).
  ///
  /// 2026-05-01: Aktuell hart auf `false` gepinnt — der `Image`-Typ aus
  /// FoundationModels war in einer früheren Beta verfügbar, ist aber im
  /// gerade installierten SDK weg/umbenannt (Compile-Fehler „Cannot find
  /// type 'Image' in"). Bis Apple die finale Image-Input-API stabilisiert,
  /// fällt die App auf den Apple-Vision-Saliency-Fallback zurück.
  /// Sobald der korrekte Typ feststeht, hier wieder zur normalen
  /// Verfügbarkeitsprüfung zurückkehren und `runAnalysis` reaktivieren.
  static var isAvailable: Bool {
    return false
  }

  // MARK: - Generable Struct (entspricht dem Gemini-responseSchema)

  #if canImport(FoundationModels)
  @available(iOS 26.0, *)
  @Generable
  struct DetectedFoods {
    @Guide(description: "Liste der auf dem Foto erkannten Lebensmittel, max. 6 Einträge. Leer wenn kein Essen zu sehen ist.")
    let foods: [DetectedFood]
  }

  @available(iOS 26.0, *)
  @Generable
  struct DetectedFood {
    @Guide(description: "Deutscher, kurzer Name wie auf einer Speisekarte. Beispiele: 'Hähnchenbrust', 'Basmati-Reis (gekocht)', 'Brokkoli', 'Vollkornnudeln (gekocht)', 'Spiegelei', 'Pizza Margherita', 'Currywurst mit Pommes'. KEIN Mischname für getrennte Komponenten ('Hähnchen mit Reis' wäre falsch — das sind 2 Einträge).")
    let name: String

    @Guide(description: "Genau EIN passendes Emoji. Beispiele: 🍗 Hähnchen, 🥩 Rind, 🍚 Reis, 🥦 Brokkoli, 🥑 Avocado, 🍝 Pasta, 🍕 Pizza, 🥚 Ei, 🐟 Fisch, 🥗 Salat, 🍞 Brot, 🍎 Apfel.")
    let emoji: String

    @Guide(description: "Visuell geschätzte Portionsmenge auf dem Foto in Gramm zubereitet. Konservativ schätzen: Hähnchenbrustfilet ≈ 150g, Faust gekochter Reis ≈ 150g, mittlerer Apfel ≈ 180g, Pizza-Stück ≈ 130g, Brötchen ≈ 60g, Esslöffel Soße ≈ 15g. Bereich: 10–1500g.")
    let estimatedGrams: Int

    @Guide(description: "Typische Kalorien pro 100g des zubereiteten Lebensmittels nach BLS/USDA-Standard. Beispiel-Referenzwerte: Hähnchenbrust 165, Reis gekocht 130, Brokkoli 34, Pasta gekocht 124, Pizza 270, Apfel 52.")
    let caloriesPer100g: Int

    @Guide(description: "Protein in Gramm pro 100g (BLS/USDA). Beispiel: Hähnchenbrust 31, Reis gekocht 2.7, Brokkoli 2.8, Quark mager 12.")
    let proteinPer100g: Double

    @Guide(description: "Kohlenhydrate in Gramm pro 100g (BLS/USDA). Beispiel: Reis gekocht 28, Pasta gekocht 24, Apfel 14, Hähnchenbrust 0.")
    let carbsPer100g: Double

    @Guide(description: "Fett in Gramm pro 100g (BLS/USDA). Beispiel: Hähnchenbrust 3.6, Avocado 15, Olivenöl 100, Reis 0.3.")
    let fatPer100g: Double

    @Guide(description: "Confidence zwischen 0.0 und 1.0. 0.85+ für klar erkennbare Klassiker, 0.5–0.7 für plausible Mischteller, unter 0.5 für unsichere Vermutungen.")
    let confidence: Double
  }
  #endif

  // MARK: - Fehler

  enum AnalyzerError: Error, LocalizedError {
    case unavailable
    case invalidImage
    case modelError(String)

    var errorDescription: String? {
      switch self {
      case .unavailable:
        return "Apple Foundation Models nicht verfügbar (iOS 26 + Apple Intelligence erforderlich)."
      case .invalidImage:
        return "Bild konnte nicht verarbeitet werden."
      case .modelError(let msg):
        return "On-Device-Modell-Fehler: \(msg)"
      }
    }
  }

  // MARK: - Öffentliches API

  /// Analysiert ein Foto on-device. Wirft, wenn Apple Intelligence nicht
  /// verfügbar ist oder das Modell scheitert.
  static func analyze(image: UIImage,
                      mealHint: String? = nil) async throws -> [RecognizedFoodSuggestion] {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      return try await runAnalysis(image: image, mealHint: mealHint)
    } else {
      throw AnalyzerError.unavailable
    }
    #else
    throw AnalyzerError.unavailable
    #endif
  }

  #if canImport(FoundationModels)
  @available(iOS 26.0, *)
  private static func runAnalysis(image: UIImage,
                                   mealHint: String?) async throws -> [RecognizedFoodSuggestion] {
    guard isAvailable else { throw AnalyzerError.unavailable }
    _ = image
    _ = mealHint
    throw AnalyzerError.unavailable
  }
  #endif
}

// MARK: - UIImage Downscaler (zusätzlich zur JPEG-Variante)

extension UIImage {
  /// Liefert eine herunterskalierte Kopie des Bildes — analog zu
  /// `downsampledJPEG`, aber als `UIImage` statt JPEG-Daten, weil
  /// FoundationModels mit `UIImage` direkt arbeitet.
  func downsampledUIImage(maxPixelSize: CGFloat) -> UIImage? {
    let originalSize = self.size
    let scale = self.scale
    let maxSide = max(originalSize.width, originalSize.height) * scale

    guard maxSide > maxPixelSize else { return self }

    let factor = maxPixelSize / maxSide
    let newSize = CGSize(width: originalSize.width * factor,
                         height: originalSize.height * factor)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
      self.draw(in: CGRect(origin: .zero, size: newSize))
    }
  }
}
