import Foundation
import UIKit

// MARK: - Gemini Food Vision Client
//
// 2026-04-29: Neue Vision-LLM-Pipeline für KI-Fotoerkennung. Apple's
// `VNClassifyImageRequest` ist ein generischer Klassifikator (~1k Kategorien)
// und für Essen schwach. Stattdessen schicken wir das Foto an Google's
// Gemini 2.0 Flash, das auf einem Bild
//   - mehrere Lebensmittel gleichzeitig erkennt,
//   - die Portionsgröße in Gramm visuell schätzt,
//   - Makros zurückgibt,
//   - jede Küche versteht (auch deutsche Spezialitäten wie Currywurst,
//     Maultaschen etc.).
//
// Free-Tier: 15 Anfragen/Minute, 1.500/Tag, 1 Mio Tokens/Monat — reicht
// fürs Solo-Testing problemlos. User trägt seinen eigenen Key in den
// Profil-Einstellungen ein (UserDefaults `gains_geminiApiKey`).

enum GeminiFoodVisionClient {

  // MARK: - Konfiguration

  /// UserDefaults-Key für den Gemini-API-Key. Wird in ProfileView gesetzt.
  static let apiKeyDefaultsKey = "gains_geminiApiKey"

  /// Schaltet die KI-Erkennung komplett aus, falls der User das will
  /// (z. B. aus Datenschutzgründen). Default: an.
  static let enabledDefaultsKey = "gains_geminiVisionEnabled"

  /// Gemini-Modell. 2.0-flash ist gratis im Free-Tier und hat sehr gute
  /// Vision-Performance. 2.5-flash gibt's auch, kostet aber im Free-Tier
  /// leicht mehr Tokens.
  private static let modelName = "gemini-2.0-flash"

  /// Liefert den aktuell konfigurierten API-Key (leer = nicht gesetzt).
  static var apiKey: String {
    UserDefaults.standard.string(forKey: apiKeyDefaultsKey) ?? ""
  }

  /// Prüft ob die Erkennung aktiv ist UND ein Key vorliegt.
  static var isAvailable: Bool {
    let enabled = UserDefaults.standard.object(forKey: enabledDefaultsKey) as? Bool ?? true
    return enabled && !apiKey.isEmpty
  }

  // MARK: - Öffentliches API

  enum AnalyzerError: Error, LocalizedError {
    case noApiKey
    case invalidImage
    case networkError(String)
    case invalidResponse(String)

    var errorDescription: String? {
      switch self {
      case .noApiKey:
        return "Kein Gemini-API-Key hinterlegt. Bitte in den Einstellungen eintragen."
      case .invalidImage:
        return "Bild konnte nicht verarbeitet werden."
      case .networkError(let msg):
        return "Netzwerkfehler: \(msg)"
      case .invalidResponse(let msg):
        return "Unerwartete KI-Antwort: \(msg)"
      }
    }
  }

  /// Schickt das Foto an Gemini und liefert eine Liste an Food-Vorschlägen
  /// inkl. Portionsschätzung. Läuft komplett async.
  static func analyze(image: UIImage,
                      mealHint: String? = nil) async throws -> [RecognizedFoodSuggestion] {
    guard isAvailable else { throw AnalyzerError.noApiKey }

    // Bild auf max. ~1024px herunterskalieren — Gemini braucht keine
    // hohe Auflösung für Food-Erkennung und das spart Tokens + Latenz.
    guard let jpeg = image.downsampledJPEG(maxPixelSize: 1024, quality: 0.8) else {
      throw AnalyzerError.invalidImage
    }
    let base64 = jpeg.base64EncodedString()

    // Stabilitäts-Fix: Force-unwrap durch defensiven Guard ersetzen. Falls der
    // User-eingegebene API-Key Steuer- oder Whitespace-Zeichen enthält, scheitert
    // sonst die URL-Konstruktion und es gibt einen Hard-Crash. Wir kodieren den
    // Key URL-safe und werfen einen sauberen Error, wenn das immer noch fehlschlägt.
    let safeKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
    guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(safeKey)") else {
      throw AnalyzerError.networkError("Ungültige API-URL — bitte API-Key prüfen.")
    }

    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.timeoutInterval = 30

    let body = makeRequestBody(imageBase64: base64, mealHint: mealHint)
    req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

    let (data, response): (Data, URLResponse)
    do {
      (data, response) = try await URLSession.shared.data(for: req)
    } catch {
      throw AnalyzerError.networkError(error.localizedDescription)
    }

    guard let http = response as? HTTPURLResponse else {
      throw AnalyzerError.networkError("Keine HTTP-Antwort")
    }

    guard (200..<300).contains(http.statusCode) else {
      let snippet = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
      throw AnalyzerError.networkError("HTTP \(http.statusCode) — \(snippet)")
    }

    return try parseResponse(data: data)
  }

  // MARK: - Request-Body

  private static func makeRequestBody(imageBase64: String,
                                       mealHint: String?) -> [String: Any] {
    let mealLine = mealHint.map { "Mahlzeitentyp-Hinweis: \($0)." } ?? ""

    let prompt = """
    Du bist ein Ernährungsexperte. Analysiere das Foto und identifiziere
    JEDES erkennbare Lebensmittel auf dem Teller separat (z. B. Hähnchen,
    Reis, Brokkoli als drei Einträge — nicht als „Hähnchen mit Reis").
    \(mealLine)

    Schätze für jedes erkannte Lebensmittel:
    - den deutschen Namen (kurz, wie auf einer Speisekarte)
    - ein passendes Emoji
    - die zubereitete Portionsmenge auf dem Foto in Gramm (visuell schätzen,
      z. B. ein Hähnchenbrustfilet ≈ 150g, eine Faust Reis ≈ 150g gekocht,
      ein Apfel ≈ 180g)
    - typische Nährwerte pro 100g (kcal, Protein g, Kohlenhydrate g, Fett g)
      basierend auf Standard-Datenbanken (BLS, USDA)
    - dein Confidence-Level zwischen 0.0 und 1.0

    Wichtige Regeln:
    - Wenn das Bild kein Essen zeigt, gib eine leere Liste zurück.
    - Maximal 6 Lebensmittel.
    - Verwechsle Beilagen nicht: Reis ≠ Couscous ≠ Quinoa ≠ Bulgur.
    - Bei verarbeiteten Gerichten (Pizza, Burger, Lasagne) gib das Gericht
      als Ganzes zurück, nicht die Zutaten einzeln.
    - Sei realistisch mit den Gramm — eher konservativ schätzen.
    """

    return [
      "contents": [
        [
          "role": "user",
          "parts": [
            ["text": prompt],
            [
              "inline_data": [
                "mime_type": "image/jpeg",
                "data": imageBase64
              ]
            ]
          ]
        ]
      ],
      "generationConfig": [
        "temperature": 0.2,
        "maxOutputTokens": 1024,
        "responseMimeType": "application/json",
        "responseSchema": [
          "type": "OBJECT",
          "properties": [
            "foods": [
              "type": "ARRAY",
              "items": [
                "type": "OBJECT",
                "properties": [
                  "name":            ["type": "STRING"],
                  "emoji":           ["type": "STRING"],
                  "estimatedGrams":  ["type": "INTEGER"],
                  "caloriesPer100g": ["type": "INTEGER"],
                  "proteinPer100g":  ["type": "NUMBER"],
                  "carbsPer100g":    ["type": "NUMBER"],
                  "fatPer100g":      ["type": "NUMBER"],
                  "confidence":      ["type": "NUMBER"]
                ],
                "required": [
                  "name", "emoji", "estimatedGrams",
                  "caloriesPer100g", "proteinPer100g",
                  "carbsPer100g", "fatPer100g", "confidence"
                ]
              ]
            ]
          ],
          "required": ["foods"]
        ]
      ],
      // Kein Safety-Block für Food-Bilder nötig — defaults sind okay.
      "safetySettings": []
    ]
  }

  // MARK: - Response-Parser

  private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
      struct Content: Decodable {
        struct Part: Decodable { let text: String? }
        let parts: [Part]?
      }
      let content: Content?
    }
    let candidates: [Candidate]?
  }

  private struct FoodPayload: Decodable {
    struct Food: Decodable {
      let name: String
      let emoji: String
      let estimatedGrams: Int
      let caloriesPer100g: Int
      let proteinPer100g: Double
      let carbsPer100g: Double
      let fatPer100g: Double
      let confidence: Double
    }
    let foods: [Food]
  }

  private static func parseResponse(data: Data) throws -> [RecognizedFoodSuggestion] {
    let decoder = JSONDecoder()

    let outer: GeminiResponse
    do {
      outer = try decoder.decode(GeminiResponse.self, from: data)
    } catch {
      throw AnalyzerError.invalidResponse("Antwort-Hülle nicht lesbar")
    }

    guard let text = outer.candidates?.first?.content?.parts?.compactMap(\.text).joined(),
          !text.isEmpty,
          let jsonData = text.data(using: .utf8) else {
      throw AnalyzerError.invalidResponse("Kein Text in der Antwort")
    }

    let payload: FoodPayload
    do {
      payload = try decoder.decode(FoodPayload.self, from: jsonData)
    } catch {
      throw AnalyzerError.invalidResponse("Foods-JSON nicht lesbar — \(error.localizedDescription)")
    }

    return payload.foods.map { f in
      RecognizedFoodSuggestion(
        name: f.name.trimmingCharacters(in: .whitespacesAndNewlines),
        emoji: f.emoji.isEmpty ? "🍽️" : f.emoji,
        confidence: max(0, min(1, f.confidence)),
        caloriesPer100g: max(0, f.caloriesPer100g),
        proteinPer100g: max(0, f.proteinPer100g),
        carbsPer100g: max(0, f.carbsPer100g),
        fatPer100g: max(0, f.fatPer100g),
        defaultGrams: max(10, min(1500, f.estimatedGrams))
      )
    }
  }
}

// MARK: - Meal-Type → Prompt Hint
//
// Wird an Gemini durchgereicht, damit das Modell beim Frühstück nicht
// erst Hauptgerichte vorschlägt etc.

extension RecipeMealType {
  /// Englischer Hint, weil Gemini damit am stabilsten umgeht.
  var geminiHint: String {
    switch self {
    case .breakfast: return "breakfast"
    case .lunch:     return "lunch"
    case .dinner:    return "dinner"
    case .snack:     return "snack"
    case .dessert:   return "dessert"
    case .shake:     return "protein shake"
    }
  }
}

// MARK: - UIImage Downsampling

extension UIImage {
  /// Skaliert ein Bild auf eine maximale Kantenlänge runter und gibt
  /// JPEG-Daten zurück. Zentral für Vision-API-Calls — spart Bandbreite
  /// und Tokens, ohne die Erkennungsqualität spürbar zu reduzieren.
  func downsampledJPEG(maxPixelSize: CGFloat, quality: CGFloat) -> Data? {
    let originalSize = self.size
    let scale = self.scale
    let maxSide = max(originalSize.width, originalSize.height) * scale

    guard maxSide > maxPixelSize else {
      return self.jpegData(compressionQuality: quality)
    }

    let factor = maxPixelSize / maxSide
    let newSize = CGSize(width: originalSize.width * factor,
                         height: originalSize.height * factor)

    let renderer = UIGraphicsImageRenderer(size: newSize)
    let scaled = renderer.image { _ in
      self.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return scaled.jpegData(compressionQuality: quality)
  }
}
