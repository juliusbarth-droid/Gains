import Foundation

// MARK: - Food Database
//
// 2026-05-03: Aus Models.swift extrahiert (Quick-Win-Sweep „Optimiere die
// app"). FoodCategory + FoodItem + die statische `FoodItem.database`-Liste
// (>200 Lebensmittel mit Kalorien/Makros pro 100g) sind komplett
// self-contained — keine fileprivate-Helfer, keine Cross-Domain-References.
// Models.swift ist damit von 4493 auf ~4015 Zeilen geschrumpft.

enum FoodCategory: String, CaseIterable, Identifiable {
  case protein
  case carbs
  case dairy
  case fruit
  case vegetable
  case fat
  case other

  var id: String { rawValue }

  var title: String {
    switch self {
    case .protein: return "Protein"
    case .carbs: return "Kohlenhydrate"
    case .dairy: return "Milchprodukte"
    case .fruit: return "Obst"
    case .vegetable: return "Gemüse"
    case .fat: return "Fette & Nüsse"
    case .other: return "Sonstiges"
    }
  }

  var systemImage: String {
    switch self {
    case .protein: return "fork.knife"
    case .carbs: return "circle.grid.2x2"
    case .dairy: return "drop.fill"
    case .fruit: return "leaf"
    case .vegetable: return "leaf.fill"
    case .fat: return "circle.fill"
    case .other: return "square.fill"
    }
  }
}

struct FoodItem: Identifiable {
  let id: UUID
  let name: String
  let brand: String?
  let emoji: String
  let caloriesPer100g: Int
  let proteinPer100g: Double
  let carbsPer100g: Double
  let fatPer100g: Double
  let category: FoodCategory

  init(
    name: String, brand: String? = nil, emoji: String, caloriesPer100g: Int,
    proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double,
    category: FoodCategory
  ) {
    self.id = UUID()
    self.name = name
    self.brand = brand
    self.emoji = emoji
    self.caloriesPer100g = caloriesPer100g
    self.proteinPer100g = proteinPer100g
    self.carbsPer100g = carbsPer100g
    self.fatPer100g = fatPer100g
    self.category = category
  }

  /// Voller Name inkl. Marke, z. B. „Barilla — Spaghetti n.5".
  var displayName: String {
    if let brand = brand, !brand.isEmpty {
      return "\(brand) — \(name)"
    }
    return name
  }

  /// Wahrheitswert ob ein Suchstring in Name oder Marke vorkommt.
  func matches(_ query: String) -> Bool {
    if name.localizedCaseInsensitiveContains(query) { return true }
    if let brand = brand, brand.localizedCaseInsensitiveContains(query) { return true }
    return false
  }

  func nutrition(for grams: Double) -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
    let f = grams / 100.0
    return (
      calories: Int((Double(caloriesPer100g) * f).rounded()),
      protein: Int((proteinPer100g * f).rounded()),
      carbs: Int((carbsPer100g * f).rounded()),
      fat: Int((fatPer100g * f).rounded())
    )
  }

  static let database: [FoodItem] = [
    // ===== PROTEIN — Geflügel =====
    FoodItem(name: "Hähnchenbrust", emoji: "🍗", caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6, category: .protein),
    FoodItem(name: "Hähnchenschenkel (mit Haut)", emoji: "🍗", caloriesPer100g: 211, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 15, category: .protein),
    FoodItem(name: "Hähnchen-Innenfilet", emoji: "🍗", caloriesPer100g: 110, proteinPer100g: 23, carbsPer100g: 0, fatPer100g: 1.5, category: .protein),
    FoodItem(name: "Putenbrust", emoji: "🍗", caloriesPer100g: 157, proteinPer100g: 30, carbsPer100g: 0, fatPer100g: 3.5, category: .protein),
    FoodItem(name: "Putenschnitzel", emoji: "🍗", caloriesPer100g: 105, proteinPer100g: 24, carbsPer100g: 0, fatPer100g: 1.0, category: .protein),
    FoodItem(name: "Entenbrust (mit Haut)", emoji: "🦆", caloriesPer100g: 337, proteinPer100g: 19, carbsPer100g: 0, fatPer100g: 28, category: .protein),

    // ===== PROTEIN — Rind =====
    FoodItem(name: "Rinderfilet", emoji: "🥩", caloriesPer100g: 158, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 7.5, category: .protein),
    FoodItem(name: "Rumpsteak", emoji: "🥩", caloriesPer100g: 188, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 9.0, category: .protein),
    FoodItem(name: "Rinderhackfleisch (mager, 5% Fett)", emoji: "🥩", caloriesPer100g: 137, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 5.0, category: .protein),
    FoodItem(name: "Rinderhackfleisch (15% Fett)", emoji: "🥩", caloriesPer100g: 215, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 12, category: .protein),
    FoodItem(name: "Tatar (mager)", emoji: "🥩", caloriesPer100g: 130, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 5.0, category: .protein),

    // ===== PROTEIN — Schwein =====
    FoodItem(name: "Schweinefilet", emoji: "🥩", caloriesPer100g: 110, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 2.0, category: .protein),
    FoodItem(name: "Schweineschnitzel", emoji: "🥩", caloriesPer100g: 145, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 5.0, category: .protein),
    FoodItem(name: "Schweinekotelett", emoji: "🥩", caloriesPer100g: 247, proteinPer100g: 23, carbsPer100g: 0, fatPer100g: 17, category: .protein),
    FoodItem(name: "Gemischtes Hack (Rind/Schwein)", emoji: "🥩", caloriesPer100g: 250, proteinPer100g: 19, carbsPer100g: 0, fatPer100g: 19, category: .protein),
    FoodItem(name: "Lammkotelett", emoji: "🥩", caloriesPer100g: 294, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 21, category: .protein),

    // ===== PROTEIN — Wurst & Aufschnitt =====
    FoodItem(name: "Putenbrust-Aufschnitt", emoji: "🥓", caloriesPer100g: 105, proteinPer100g: 21, carbsPer100g: 0.5, fatPer100g: 2.0, category: .protein),
    FoodItem(name: "Hähnchenbrust-Aufschnitt", emoji: "🥓", caloriesPer100g: 100, proteinPer100g: 22, carbsPer100g: 0.5, fatPer100g: 1.5, category: .protein),
    FoodItem(name: "Kochschinken", emoji: "🥓", caloriesPer100g: 117, proteinPer100g: 21, carbsPer100g: 0.7, fatPer100g: 3.5, category: .protein),
    FoodItem(name: "Serrano-Schinken", emoji: "🥓", caloriesPer100g: 241, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 13, category: .protein),
    FoodItem(name: "Salami", emoji: "🥓", caloriesPer100g: 378, proteinPer100g: 19, carbsPer100g: 1.0, fatPer100g: 33, category: .protein),
    FoodItem(name: "Bratwurst", emoji: "🌭", caloriesPer100g: 310, proteinPer100g: 13, carbsPer100g: 1.0, fatPer100g: 28, category: .protein),
    FoodItem(name: "Wiener Würstchen", emoji: "🌭", caloriesPer100g: 290, proteinPer100g: 13, carbsPer100g: 0.5, fatPer100g: 27, category: .protein),
    FoodItem(name: "Leberwurst", emoji: "🥓", caloriesPer100g: 326, proteinPer100g: 12, carbsPer100g: 1.0, fatPer100g: 30, category: .protein),
    FoodItem(name: "Mühlen-Schinken Spicker", brand: "Rügenwalder Mühle", emoji: "🥓", caloriesPer100g: 110, proteinPer100g: 21, carbsPer100g: 0.6, fatPer100g: 2.5, category: .protein),
    FoodItem(name: "Vegane Mühlen-Frikadellen", brand: "Rügenwalder Mühle", emoji: "🥩", caloriesPer100g: 199, proteinPer100g: 17, carbsPer100g: 6.0, fatPer100g: 11, category: .protein),

    // ===== PROTEIN — Fisch & Meeresfrüchte =====
    FoodItem(name: "Lachs (frisch)", emoji: "🐟", caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13, category: .protein),
    FoodItem(name: "Lachs (geräuchert)", emoji: "🐟", caloriesPer100g: 167, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 7.0, category: .protein),
    FoodItem(name: "Thunfisch (Dose, in Wasser)", emoji: "🐟", caloriesPer100g: 116, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 1.0, category: .protein),
    FoodItem(name: "Thunfisch (Dose, in Öl)", emoji: "🐟", caloriesPer100g: 198, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 11, category: .protein),
    FoodItem(name: "Forelle", emoji: "🐟", caloriesPer100g: 119, proteinPer100g: 21, carbsPer100g: 0, fatPer100g: 4.0, category: .protein),
    FoodItem(name: "Kabeljau", emoji: "🐟", caloriesPer100g: 82, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 0.7, category: .protein),
    FoodItem(name: "Seelachs (Filet)", emoji: "🐟", caloriesPer100g: 81, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 0.9, category: .protein),
    FoodItem(name: "Hering (in Tomatensauce)", emoji: "🐟", caloriesPer100g: 180, proteinPer100g: 14, carbsPer100g: 4.0, fatPer100g: 12, category: .protein),
    FoodItem(name: "Makrele (geräuchert)", emoji: "🐟", caloriesPer100g: 261, proteinPer100g: 21, carbsPer100g: 0, fatPer100g: 20, category: .protein),
    FoodItem(name: "Garnelen (gekocht)", emoji: "🦐", caloriesPer100g: 99, proteinPer100g: 24, carbsPer100g: 0, fatPer100g: 0.3, category: .protein),
    FoodItem(name: "Schlemmer-Filet Bordelaise", brand: "Iglo", emoji: "🐟", caloriesPer100g: 154, proteinPer100g: 12, carbsPer100g: 6.5, fatPer100g: 8.5, category: .protein),
    FoodItem(name: "Fischstäbchen", brand: "Iglo", emoji: "🐟", caloriesPer100g: 195, proteinPer100g: 12, carbsPer100g: 16, fatPer100g: 9.0, category: .protein),

    // ===== PROTEIN — Eier & Pflanzlich =====
    FoodItem(name: "Eier (1 Stück = 60g)", emoji: "🥚", caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11, category: .protein),
    FoodItem(name: "Eiweiß (Eiklar)", emoji: "🥚", caloriesPer100g: 52, proteinPer100g: 11, carbsPer100g: 0.7, fatPer100g: 0.2, category: .protein),
    FoodItem(name: "Tofu (natur)", emoji: "🧊", caloriesPer100g: 76, proteinPer100g: 8, carbsPer100g: 2.0, fatPer100g: 4.0, category: .protein),
    FoodItem(name: "Tofu (geräuchert)", emoji: "🧊", caloriesPer100g: 138, proteinPer100g: 16, carbsPer100g: 1.0, fatPer100g: 8.0, category: .protein),
    FoodItem(name: "Tempeh", emoji: "🧊", caloriesPer100g: 192, proteinPer100g: 19, carbsPer100g: 9.0, fatPer100g: 11, category: .protein),
    FoodItem(name: "Seitan", emoji: "🧊", caloriesPer100g: 141, proteinPer100g: 25, carbsPer100g: 7.0, fatPer100g: 1.5, category: .protein),
    FoodItem(name: "Kichererbsen (gekocht)", emoji: "🫘", caloriesPer100g: 164, proteinPer100g: 9, carbsPer100g: 27, fatPer100g: 2.6, category: .protein),
    FoodItem(name: "Linsen rot (gekocht)", emoji: "🫘", caloriesPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4, category: .protein),
    FoodItem(name: "Linsen braun (gekocht)", emoji: "🫘", caloriesPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4, category: .protein),
    FoodItem(name: "Kidneybohnen (Dose, abgetropft)", emoji: "🫘", caloriesPer100g: 127, proteinPer100g: 8.7, carbsPer100g: 22, fatPer100g: 0.5, category: .protein),
    FoodItem(name: "Schwarze Bohnen (gekocht)", emoji: "🫘", caloriesPer100g: 132, proteinPer100g: 8.9, carbsPer100g: 24, fatPer100g: 0.5, category: .protein),
    FoodItem(name: "Weiße Bohnen (gekocht)", emoji: "🫘", caloriesPer100g: 139, proteinPer100g: 9.7, carbsPer100g: 25, fatPer100g: 0.4, category: .protein),
    FoodItem(name: "Erbsen (tk)", emoji: "🫛", caloriesPer100g: 81, proteinPer100g: 5.0, carbsPer100g: 14, fatPer100g: 0.4, category: .protein),

    // ===== PROTEIN — Supplements =====
    FoodItem(name: "Whey Protein (Pulver)", emoji: "💪", caloriesPer100g: 380, proteinPer100g: 74, carbsPer100g: 8.0, fatPer100g: 5.0, category: .protein),
    FoodItem(name: "Casein (Pulver)", emoji: "💪", caloriesPer100g: 360, proteinPer100g: 80, carbsPer100g: 4.0, fatPer100g: 2.0, category: .protein),
    FoodItem(name: "Veganes Proteinpulver", emoji: "💪", caloriesPer100g: 370, proteinPer100g: 70, carbsPer100g: 8.0, fatPer100g: 6.0, category: .protein),
    FoodItem(name: "100% Whey Gold Standard (Vanille)", brand: "Optimum Nutrition", emoji: "💪", caloriesPer100g: 393, proteinPer100g: 80, carbsPer100g: 7.0, fatPer100g: 4.0, category: .protein),

    // ===== DAIRY — Milch =====
    FoodItem(name: "Vollmilch 3,5%", emoji: "🥛", caloriesPer100g: 65, proteinPer100g: 3.4, carbsPer100g: 4.8, fatPer100g: 3.6, category: .dairy),
    FoodItem(name: "Fettarme Milch 1,5%", emoji: "🥛", caloriesPer100g: 47, proteinPer100g: 3.5, carbsPer100g: 4.8, fatPer100g: 1.5, category: .dairy),
    FoodItem(name: "Magermilch 0,1%", emoji: "🥛", caloriesPer100g: 35, proteinPer100g: 3.5, carbsPer100g: 4.9, fatPer100g: 0.1, category: .dairy),
    FoodItem(name: "Hafermilch (ungesüßt)", emoji: "🥛", caloriesPer100g: 45, proteinPer100g: 1.0, carbsPer100g: 7.0, fatPer100g: 1.5, category: .dairy),
    FoodItem(name: "Hafer Drink Barista", brand: "Oatly", emoji: "🥛", caloriesPer100g: 60, proteinPer100g: 1.0, carbsPer100g: 7.0, fatPer100g: 3.0, category: .dairy),
    FoodItem(name: "Sojamilch (ungesüßt)", emoji: "🥛", caloriesPer100g: 33, proteinPer100g: 3.3, carbsPer100g: 0.2, fatPer100g: 1.8, category: .dairy),
    FoodItem(name: "Mandelmilch (ungesüßt)", emoji: "🥛", caloriesPer100g: 13, proteinPer100g: 0.4, carbsPer100g: 0.3, fatPer100g: 1.1, category: .dairy),
    FoodItem(name: "Sahne (Schlagsahne 30%)", emoji: "🥛", caloriesPer100g: 292, proteinPer100g: 2.4, carbsPer100g: 3.3, fatPer100g: 30, category: .dairy),
    FoodItem(name: "Crème fraîche (30%)", emoji: "🥛", caloriesPer100g: 299, proteinPer100g: 2.4, carbsPer100g: 2.5, fatPer100g: 30, category: .dairy),
    FoodItem(name: "Saure Sahne (10%)", emoji: "🥛", caloriesPer100g: 116, proteinPer100g: 2.9, carbsPer100g: 3.4, fatPer100g: 10, category: .dairy),
    FoodItem(name: "Buttermilch", emoji: "🥛", caloriesPer100g: 36, proteinPer100g: 3.4, carbsPer100g: 4.0, fatPer100g: 0.5, category: .dairy),

    // ===== DAIRY — Joghurt & Quark =====
    FoodItem(name: "Naturjoghurt (1,5%)", emoji: "🫙", caloriesPer100g: 47, proteinPer100g: 3.8, carbsPer100g: 4.7, fatPer100g: 1.5, category: .dairy),
    FoodItem(name: "Naturjoghurt (3,5%)", emoji: "🫙", caloriesPer100g: 61, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.5, category: .dairy),
    FoodItem(name: "Griechischer Joghurt 10%", emoji: "🫙", caloriesPer100g: 134, proteinPer100g: 6.6, carbsPer100g: 4.0, fatPer100g: 10, category: .dairy),
    FoodItem(name: "Griechischer Joghurt 0,2%", emoji: "🫙", caloriesPer100g: 57, proteinPer100g: 9.0, carbsPer100g: 4.0, fatPer100g: 0.2, category: .dairy),
    FoodItem(name: "Skyr (natur)", emoji: "🫙", caloriesPer100g: 64, proteinPer100g: 11, carbsPer100g: 4.0, fatPer100g: 0.2, category: .dairy),
    FoodItem(name: "Magerquark", emoji: "🥛", caloriesPer100g: 67, proteinPer100g: 12, carbsPer100g: 4.0, fatPer100g: 0.3, category: .dairy),
    FoodItem(name: "Speisequark 20%", emoji: "🥛", caloriesPer100g: 109, proteinPer100g: 12, carbsPer100g: 3.0, fatPer100g: 5.1, category: .dairy),
    FoodItem(name: "Speisequark 40%", emoji: "🥛", caloriesPer100g: 161, proteinPer100g: 11, carbsPer100g: 2.7, fatPer100g: 11, category: .dairy),
    FoodItem(name: "Joghurt mit der Ecke (Schoko-Crispies)", brand: "Müller", emoji: "🫙", caloriesPer100g: 138, proteinPer100g: 3.5, carbsPer100g: 17, fatPer100g: 6.0, category: .dairy),
    FoodItem(name: "Müllermilch (Schoko)", brand: "Müller", emoji: "🥛", caloriesPer100g: 88, proteinPer100g: 3.4, carbsPer100g: 13, fatPer100g: 1.8, category: .dairy),
    FoodItem(name: "Activia Naturjoghurt", brand: "Danone", emoji: "🫙", caloriesPer100g: 60, proteinPer100g: 4.0, carbsPer100g: 5.0, fatPer100g: 2.8, category: .dairy),
    FoodItem(name: "Skyr (natur)", brand: "Arla", emoji: "🫙", caloriesPer100g: 63, proteinPer100g: 11, carbsPer100g: 4.0, fatPer100g: 0.2, category: .dairy),
    FoodItem(name: "Skyr (Vanille)", brand: "Arla", emoji: "🫙", caloriesPer100g: 75, proteinPer100g: 9.5, carbsPer100g: 8.0, fatPer100g: 0.2, category: .dairy),
    FoodItem(name: "High Protein Pudding (Vanille)", brand: "Ehrmann", emoji: "🫙", caloriesPer100g: 73, proteinPer100g: 12, carbsPer100g: 5.0, fatPer100g: 0.5, category: .dairy),
    FoodItem(name: "High Protein Drink (Schoko)", brand: "Müller", emoji: "🥤", caloriesPer100g: 60, proteinPer100g: 10, carbsPer100g: 3.5, fatPer100g: 0.7, category: .dairy),
    FoodItem(name: "Almighurt (Erdbeere)", brand: "Ehrmann", emoji: "🫙", caloriesPer100g: 102, proteinPer100g: 2.9, carbsPer100g: 14, fatPer100g: 3.4, category: .dairy),
    FoodItem(name: "Soja-Joghurt natur", brand: "Alpro", emoji: "🫙", caloriesPer100g: 51, proteinPer100g: 4.0, carbsPer100g: 2.5, fatPer100g: 2.3, category: .dairy),
    FoodItem(name: "Magerquark", brand: "Ja!", emoji: "🥛", caloriesPer100g: 67, proteinPer100g: 12, carbsPer100g: 4.0, fatPer100g: 0.3, category: .dairy),
    FoodItem(name: "Naturjoghurt 3,5%", brand: "Ja!", emoji: "🫙", caloriesPer100g: 61, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.5, category: .dairy),
    FoodItem(name: "Vollmilch 3,5%", brand: "Ja!", emoji: "🥛", caloriesPer100g: 65, proteinPer100g: 3.4, carbsPer100g: 4.8, fatPer100g: 3.6, category: .dairy),

    // ===== DAIRY — Käse =====
    FoodItem(name: "Mozzarella", emoji: "🧀", caloriesPer100g: 280, proteinPer100g: 19, carbsPer100g: 2.2, fatPer100g: 22, category: .dairy),
    FoodItem(name: "Mozzarella light", emoji: "🧀", caloriesPer100g: 191, proteinPer100g: 20, carbsPer100g: 1.5, fatPer100g: 12, category: .dairy),
    FoodItem(name: "Feta", emoji: "🧀", caloriesPer100g: 264, proteinPer100g: 14, carbsPer100g: 4.1, fatPer100g: 21, category: .dairy),
    FoodItem(name: "Hirtenkäse (Schafskäse)", emoji: "🧀", caloriesPer100g: 264, proteinPer100g: 14, carbsPer100g: 4.0, fatPer100g: 21, category: .dairy),
    FoodItem(name: "Gouda jung (48% F.i.Tr.)", emoji: "🧀", caloriesPer100g: 356, proteinPer100g: 25, carbsPer100g: 0.3, fatPer100g: 28, category: .dairy),
    FoodItem(name: "Edamer", emoji: "🧀", caloriesPer100g: 334, proteinPer100g: 25, carbsPer100g: 0.4, fatPer100g: 26, category: .dairy),
    FoodItem(name: "Emmentaler", emoji: "🧀", caloriesPer100g: 380, proteinPer100g: 28, carbsPer100g: 0.4, fatPer100g: 29, category: .dairy),
    FoodItem(name: "Parmesan", emoji: "🧀", caloriesPer100g: 392, proteinPer100g: 36, carbsPer100g: 3.2, fatPer100g: 26, category: .dairy),
    FoodItem(name: "Cheddar", emoji: "🧀", caloriesPer100g: 410, proteinPer100g: 25, carbsPer100g: 1.3, fatPer100g: 34, category: .dairy),
    FoodItem(name: "Camembert (45%)", emoji: "🧀", caloriesPer100g: 290, proteinPer100g: 21, carbsPer100g: 0.4, fatPer100g: 23, category: .dairy),
    FoodItem(name: "Brie", emoji: "🧀", caloriesPer100g: 329, proteinPer100g: 21, carbsPer100g: 0.5, fatPer100g: 27, category: .dairy),
    FoodItem(name: "Frischkäse Doppelrahm", emoji: "🧀", caloriesPer100g: 317, proteinPer100g: 6.0, carbsPer100g: 3.0, fatPer100g: 31, category: .dairy),
    FoodItem(name: "Frischkäse light", emoji: "🧀", caloriesPer100g: 116, proteinPer100g: 12, carbsPer100g: 3.5, fatPer100g: 6.0, category: .dairy),
    FoodItem(name: "Hüttenkäse", emoji: "🧀", caloriesPer100g: 98, proteinPer100g: 11, carbsPer100g: 3.0, fatPer100g: 4.3, category: .dairy),
    FoodItem(name: "Halloumi", emoji: "🧀", caloriesPer100g: 321, proteinPer100g: 22, carbsPer100g: 2.2, fatPer100g: 25, category: .dairy),
    FoodItem(name: "Ziegenkäse (weich)", emoji: "🧀", caloriesPer100g: 268, proteinPer100g: 18, carbsPer100g: 0.9, fatPer100g: 21, category: .dairy),
    FoodItem(name: "Mozzarella di Bufala Campana", brand: "Galbani", emoji: "🧀", caloriesPer100g: 288, proteinPer100g: 17, carbsPer100g: 0.7, fatPer100g: 24, category: .dairy),
    FoodItem(name: "Mozzarella Classica", brand: "Galbani", emoji: "🧀", caloriesPer100g: 254, proteinPer100g: 18, carbsPer100g: 1.5, fatPer100g: 20, category: .dairy),
    FoodItem(name: "Mozzarella", brand: "Ja!", emoji: "🧀", caloriesPer100g: 246, proteinPer100g: 18, carbsPer100g: 1.5, fatPer100g: 19, category: .dairy),
    FoodItem(name: "Feta", brand: "Ja!", emoji: "🧀", caloriesPer100g: 247, proteinPer100g: 16, carbsPer100g: 1.0, fatPer100g: 20, category: .dairy),
    FoodItem(name: "Gouda", brand: "Ja!", emoji: "🧀", caloriesPer100g: 348, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 27, category: .dairy),
    FoodItem(name: "Frischkäse Klassik", brand: "Philadelphia", emoji: "🧀", caloriesPer100g: 253, proteinPer100g: 6.0, carbsPer100g: 4.0, fatPer100g: 24, category: .dairy),

    // ===== CARBS — Reis & Getreide =====
    FoodItem(name: "Basmati-Reis (gekocht)", emoji: "🍚", caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, category: .carbs),
    FoodItem(name: "Basmati-Reis (roh)", emoji: "🍚", caloriesPer100g: 351, proteinPer100g: 7.1, carbsPer100g: 78, fatPer100g: 0.7, category: .carbs),
    FoodItem(name: "Jasmin-Reis (gekocht)", emoji: "🍚", caloriesPer100g: 129, proteinPer100g: 2.9, carbsPer100g: 28, fatPer100g: 0.2, category: .carbs),
    FoodItem(name: "Vollkornreis (gekocht)", emoji: "🍚", caloriesPer100g: 123, proteinPer100g: 2.6, carbsPer100g: 25, fatPer100g: 1.0, category: .carbs),
    FoodItem(name: "Risotto-Reis (Arborio, roh)", emoji: "🍚", caloriesPer100g: 350, proteinPer100g: 7.0, carbsPer100g: 78, fatPer100g: 0.6, category: .carbs),
    FoodItem(name: "Wildreis (gekocht)", emoji: "🍚", caloriesPer100g: 101, proteinPer100g: 4.0, carbsPer100g: 21, fatPer100g: 0.3, category: .carbs),
    FoodItem(name: "Milchreis (zubereitet)", emoji: "🍚", caloriesPer100g: 122, proteinPer100g: 3.0, carbsPer100g: 21, fatPer100g: 2.5, category: .carbs),
    FoodItem(name: "Quinoa (gekocht)", emoji: "🌿", caloriesPer100g: 120, proteinPer100g: 4.4, carbsPer100g: 22, fatPer100g: 1.9, category: .carbs),
    FoodItem(name: "Couscous (gekocht)", emoji: "🌾", caloriesPer100g: 112, proteinPer100g: 3.8, carbsPer100g: 23, fatPer100g: 0.2, category: .carbs),
    FoodItem(name: "Bulgur (gekocht)", emoji: "🌾", caloriesPer100g: 83, proteinPer100g: 3.1, carbsPer100g: 19, fatPer100g: 0.2, category: .carbs),
    FoodItem(name: "Polenta (gekocht)", emoji: "🌽", caloriesPer100g: 70, proteinPer100g: 2.0, carbsPer100g: 15, fatPer100g: 0.5, category: .carbs),
    FoodItem(name: "Reiswaffeln", emoji: "🍘", caloriesPer100g: 387, proteinPer100g: 8.0, carbsPer100g: 82, fatPer100g: 3.0, category: .carbs),

    // ===== CARBS — Pasta =====
    FoodItem(name: "Spaghetti (gekocht)", emoji: "🍝", caloriesPer100g: 158, proteinPer100g: 5.8, carbsPer100g: 31, fatPer100g: 0.9, category: .carbs),
    FoodItem(name: "Vollkornnudeln (gekocht)", emoji: "🍝", caloriesPer100g: 124, proteinPer100g: 5.0, carbsPer100g: 24, fatPer100g: 1.0, category: .carbs),
    FoodItem(name: "Penne (roh)", emoji: "🍝", caloriesPer100g: 358, proteinPer100g: 13, carbsPer100g: 71, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Linsennudeln (rot, roh)", emoji: "🍝", caloriesPer100g: 348, proteinPer100g: 25, carbsPer100g: 49, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Reisnudeln (gekocht)", emoji: "🍜", caloriesPer100g: 109, proteinPer100g: 1.8, carbsPer100g: 24, fatPer100g: 0.2, category: .carbs),
    FoodItem(name: "Glasnudeln (gekocht)", emoji: "🍜", caloriesPer100g: 86, proteinPer100g: 0.1, carbsPer100g: 21, fatPer100g: 0.1, category: .carbs),
    FoodItem(name: "Gnocchi", emoji: "🥟", caloriesPer100g: 158, proteinPer100g: 4.0, carbsPer100g: 33, fatPer100g: 1.0, category: .carbs),
    FoodItem(name: "Ramen-Nudeln (Instant, zubereitet)", emoji: "🍜", caloriesPer100g: 188, proteinPer100g: 4.5, carbsPer100g: 27, fatPer100g: 7.0, category: .carbs),
    FoodItem(name: "Spaghetti n.5 (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 359, proteinPer100g: 13, carbsPer100g: 72, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Penne Rigate n.73 (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 359, proteinPer100g: 13, carbsPer100g: 72, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Fusilli n.98 (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 359, proteinPer100g: 13, carbsPer100g: 72, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Tagliatelle all'uovo (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 366, proteinPer100g: 14, carbsPer100g: 67, fatPer100g: 4.5, category: .carbs),
    FoodItem(name: "Vollkorn-Spaghetti (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 339, proteinPer100g: 13, carbsPer100g: 64, fatPer100g: 2.5, category: .carbs),
    FoodItem(name: "Lasagne (Platten, roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 357, proteinPer100g: 14, carbsPer100g: 71, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti (roh)", brand: "Buitoni", emoji: "🍝", caloriesPer100g: 359, proteinPer100g: 12, carbsPer100g: 73, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti (roh)", brand: "De Cecco", emoji: "🍝", caloriesPer100g: 353, proteinPer100g: 13, carbsPer100g: 71, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti (roh)", brand: "Combino (Lidl)", emoji: "🍝", caloriesPer100g: 358, proteinPer100g: 12, carbsPer100g: 72, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti (roh)", brand: "Ja!", emoji: "🍝", caloriesPer100g: 358, proteinPer100g: 12, carbsPer100g: 72, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Penne (roh)", brand: "Ja!", emoji: "🍝", caloriesPer100g: 358, proteinPer100g: 12, carbsPer100g: 72, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti Hartweizen (roh)", brand: "Birkel", emoji: "🍝", caloriesPer100g: 354, proteinPer100g: 13, carbsPer100g: 70, fatPer100g: 1.5, category: .carbs),

    // ===== CARBS — Brot & Backwaren =====
    FoodItem(name: "Vollkornbrot", emoji: "🍞", caloriesPer100g: 247, proteinPer100g: 9.0, carbsPer100g: 41, fatPer100g: 3.0, category: .carbs),
    FoodItem(name: "Roggenbrot", emoji: "🍞", caloriesPer100g: 220, proteinPer100g: 7.0, carbsPer100g: 45, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Pumpernickel", emoji: "🍞", caloriesPer100g: 187, proteinPer100g: 6.0, carbsPer100g: 36, fatPer100g: 1.0, category: .carbs),
    FoodItem(name: "Toastbrot weiß", emoji: "🍞", caloriesPer100g: 270, proteinPer100g: 8.5, carbsPer100g: 50, fatPer100g: 3.5, category: .carbs),
    FoodItem(name: "Vollkorntoast", emoji: "🍞", caloriesPer100g: 245, proteinPer100g: 9.5, carbsPer100g: 40, fatPer100g: 4.0, category: .carbs),
    FoodItem(name: "Brötchen (Weizen)", emoji: "🥖", caloriesPer100g: 274, proteinPer100g: 9.0, carbsPer100g: 53, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Croissant", emoji: "🥐", caloriesPer100g: 406, proteinPer100g: 8.2, carbsPer100g: 46, fatPer100g: 21, category: .carbs),
    FoodItem(name: "Bagel", emoji: "🥯", caloriesPer100g: 257, proteinPer100g: 10, carbsPer100g: 51, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Pita-Brot", emoji: "🥙", caloriesPer100g: 275, proteinPer100g: 9.0, carbsPer100g: 55, fatPer100g: 1.2, category: .carbs),
    FoodItem(name: "Tortilla Wrap (Weizen)", emoji: "🌯", caloriesPer100g: 312, proteinPer100g: 8.0, carbsPer100g: 50, fatPer100g: 8.5, category: .carbs),
    FoodItem(name: "Knäckebrot (Roggen)", emoji: "🍞", caloriesPer100g: 364, proteinPer100g: 11, carbsPer100g: 71, fatPer100g: 1.7, category: .carbs),
    FoodItem(name: "Mestemacher Vollkornbrot", brand: "Mestemacher", emoji: "🍞", caloriesPer100g: 198, proteinPer100g: 7.0, carbsPer100g: 35, fatPer100g: 2.5, category: .carbs),
    FoodItem(name: "Toast Klassisch", brand: "Golden Toast", emoji: "🍞", caloriesPer100g: 263, proteinPer100g: 8.6, carbsPer100g: 47, fatPer100g: 4.0, category: .carbs),
    FoodItem(name: "Vollkorn-Toast", brand: "Harry", emoji: "🍞", caloriesPer100g: 247, proteinPer100g: 9.5, carbsPer100g: 40, fatPer100g: 4.5, category: .carbs),

    // ===== CARBS — Müsli & Cerealien =====
    FoodItem(name: "Haferflocken (Vollkorn)", emoji: "🌾", caloriesPer100g: 372, proteinPer100g: 14, carbsPer100g: 59, fatPer100g: 7.0, category: .carbs),
    FoodItem(name: "Müsli (ungesüßt)", emoji: "🥣", caloriesPer100g: 360, proteinPer100g: 10, carbsPer100g: 65, fatPer100g: 6.0, category: .carbs),
    FoodItem(name: "Granola (Honig-Nuss)", emoji: "🥣", caloriesPer100g: 471, proteinPer100g: 11, carbsPer100g: 60, fatPer100g: 21, category: .carbs),
    FoodItem(name: "Cornflakes (ungesüßt)", emoji: "🥣", caloriesPer100g: 357, proteinPer100g: 7.5, carbsPer100g: 84, fatPer100g: 0.9, category: .carbs),
    FoodItem(name: "Cornflakes Original", brand: "Kellogg's", emoji: "🥣", caloriesPer100g: 378, proteinPer100g: 7.0, carbsPer100g: 84, fatPer100g: 0.9, category: .carbs),
    FoodItem(name: "Special K Original", brand: "Kellogg's", emoji: "🥣", caloriesPer100g: 376, proteinPer100g: 16, carbsPer100g: 75, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Frosties", brand: "Kellogg's", emoji: "🥣", caloriesPer100g: 376, proteinPer100g: 5.0, carbsPer100g: 87, fatPer100g: 0.6, category: .carbs),
    FoodItem(name: "Choco Krispies", brand: "Kellogg's", emoji: "🥣", caloriesPer100g: 388, proteinPer100g: 4.8, carbsPer100g: 86, fatPer100g: 2.5, category: .carbs),
    FoodItem(name: "Knusper Schoko & Keks", brand: "Kölln", emoji: "🥣", caloriesPer100g: 444, proteinPer100g: 7.5, carbsPer100g: 67, fatPer100g: 15, category: .carbs),
    FoodItem(name: "Müsli Schoko & Keks", brand: "Kölln", emoji: "🥣", caloriesPer100g: 442, proteinPer100g: 7.5, carbsPer100g: 67, fatPer100g: 15, category: .carbs),
    FoodItem(name: "Haferflocken Zarte", brand: "Kölln", emoji: "🌾", caloriesPer100g: 369, proteinPer100g: 13, carbsPer100g: 59, fatPer100g: 7.0, category: .carbs),
    FoodItem(name: "Vitalis Knuspermüsli Schoko", brand: "Dr. Oetker", emoji: "🥣", caloriesPer100g: 451, proteinPer100g: 7.5, carbsPer100g: 65, fatPer100g: 17, category: .carbs),

    // ===== CARBS — Kartoffel & Beilagen =====
    FoodItem(name: "Kartoffeln (gekocht)", emoji: "🥔", caloriesPer100g: 86, proteinPer100g: 2.0, carbsPer100g: 20, fatPer100g: 0.1, category: .carbs),
    FoodItem(name: "Süßkartoffel (gekocht)", emoji: "🍠", caloriesPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1, category: .carbs),
    FoodItem(name: "Bratkartoffeln (mit Öl)", emoji: "🥔", caloriesPer100g: 168, proteinPer100g: 2.5, carbsPer100g: 21, fatPer100g: 8.0, category: .carbs),
    FoodItem(name: "Pommes Frites (frittiert)", emoji: "🍟", caloriesPer100g: 312, proteinPer100g: 3.4, carbsPer100g: 41, fatPer100g: 15, category: .carbs),
    FoodItem(name: "Pommes Frites (Backofen)", emoji: "🍟", caloriesPer100g: 175, proteinPer100g: 3.0, carbsPer100g: 27, fatPer100g: 6.0, category: .carbs),
    FoodItem(name: "Kroketten", emoji: "🍟", caloriesPer100g: 220, proteinPer100g: 3.5, carbsPer100g: 25, fatPer100g: 12, category: .carbs),
    FoodItem(name: "Kartoffelpüree (zubereitet)", emoji: "🥔", caloriesPer100g: 88, proteinPer100g: 2.0, carbsPer100g: 14, fatPer100g: 3.0, category: .carbs),

    // ===== FRUIT =====
    FoodItem(name: "Banane", emoji: "🍌", caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Apfel", emoji: "🍎", caloriesPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Birne", emoji: "🍐", caloriesPer100g: 57, proteinPer100g: 0.4, carbsPer100g: 15, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Orange", emoji: "🍊", caloriesPer100g: 47, proteinPer100g: 0.9, carbsPer100g: 12, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Mandarine / Clementine", emoji: "🍊", caloriesPer100g: 53, proteinPer100g: 0.8, carbsPer100g: 13, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Zitrone", emoji: "🍋", caloriesPer100g: 29, proteinPer100g: 1.1, carbsPer100g: 9.0, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Grapefruit", emoji: "🍊", caloriesPer100g: 42, proteinPer100g: 0.8, carbsPer100g: 11, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Erdbeeren", emoji: "🍓", caloriesPer100g: 32, proteinPer100g: 0.7, carbsPer100g: 8.0, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Himbeeren", emoji: "🍓", caloriesPer100g: 52, proteinPer100g: 1.2, carbsPer100g: 12, fatPer100g: 0.7, category: .fruit),
    FoodItem(name: "Heidelbeeren", emoji: "🫐", caloriesPer100g: 57, proteinPer100g: 0.7, carbsPer100g: 14, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Brombeeren", emoji: "🫐", caloriesPer100g: 43, proteinPer100g: 1.4, carbsPer100g: 10, fatPer100g: 0.5, category: .fruit),
    FoodItem(name: "Johannisbeeren (rot)", emoji: "🍒", caloriesPer100g: 56, proteinPer100g: 1.4, carbsPer100g: 14, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Kirschen (süß)", emoji: "🍒", caloriesPer100g: 63, proteinPer100g: 1.1, carbsPer100g: 16, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Pflaumen", emoji: "🍑", caloriesPer100g: 46, proteinPer100g: 0.7, carbsPer100g: 11, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Pfirsich", emoji: "🍑", caloriesPer100g: 39, proteinPer100g: 0.9, carbsPer100g: 10, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Nektarine", emoji: "🍑", caloriesPer100g: 44, proteinPer100g: 1.1, carbsPer100g: 11, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Aprikose", emoji: "🍑", caloriesPer100g: 48, proteinPer100g: 1.4, carbsPer100g: 11, fatPer100g: 0.4, category: .fruit),
    FoodItem(name: "Ananas (frisch)", emoji: "🍍", caloriesPer100g: 50, proteinPer100g: 0.5, carbsPer100g: 13, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Mango", emoji: "🥭", caloriesPer100g: 60, proteinPer100g: 0.8, carbsPer100g: 15, fatPer100g: 0.4, category: .fruit),
    FoodItem(name: "Papaya", emoji: "🥭", caloriesPer100g: 43, proteinPer100g: 0.5, carbsPer100g: 11, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Wassermelone", emoji: "🍉", caloriesPer100g: 30, proteinPer100g: 0.6, carbsPer100g: 8.0, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Honigmelone", emoji: "🍈", caloriesPer100g: 36, proteinPer100g: 0.5, carbsPer100g: 9.0, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Kiwi", emoji: "🥝", caloriesPer100g: 61, proteinPer100g: 1.1, carbsPer100g: 15, fatPer100g: 0.5, category: .fruit),
    FoodItem(name: "Trauben (hell)", emoji: "🍇", caloriesPer100g: 69, proteinPer100g: 0.6, carbsPer100g: 18, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Granatapfel (Kerne)", emoji: "🌰", caloriesPer100g: 83, proteinPer100g: 1.7, carbsPer100g: 19, fatPer100g: 1.2, category: .fruit),
    FoodItem(name: "Datteln (getrocknet)", emoji: "🌴", caloriesPer100g: 282, proteinPer100g: 2.5, carbsPer100g: 75, fatPer100g: 0.4, category: .fruit),
    FoodItem(name: "Rosinen", emoji: "🍇", caloriesPer100g: 299, proteinPer100g: 3.1, carbsPer100g: 79, fatPer100g: 0.5, category: .fruit),
    FoodItem(name: "Trockenpflaumen", emoji: "🍑", caloriesPer100g: 240, proteinPer100g: 2.2, carbsPer100g: 64, fatPer100g: 0.4, category: .fruit),

    // ===== VEGETABLE — Kohl & Salat =====
    FoodItem(name: "Brokkoli", emoji: "🥦", caloriesPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 7.0, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Blumenkohl", emoji: "🥦", caloriesPer100g: 25, proteinPer100g: 1.9, carbsPer100g: 5.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Romanesco", emoji: "🥦", caloriesPer100g: 29, proteinPer100g: 2.5, carbsPer100g: 5.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Spinat (frisch)", emoji: "🥬", caloriesPer100g: 23, proteinPer100g: 2.9, carbsPer100g: 3.6, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Grünkohl", emoji: "🥬", caloriesPer100g: 49, proteinPer100g: 4.3, carbsPer100g: 9.0, fatPer100g: 0.9, category: .vegetable),
    FoodItem(name: "Weißkohl", emoji: "🥬", caloriesPer100g: 25, proteinPer100g: 1.3, carbsPer100g: 6.0, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Rotkohl", emoji: "🥬", caloriesPer100g: 31, proteinPer100g: 1.4, carbsPer100g: 7.0, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Sauerkraut", emoji: "🥬", caloriesPer100g: 19, proteinPer100g: 0.9, carbsPer100g: 4.3, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Pak Choi", emoji: "🥬", caloriesPer100g: 13, proteinPer100g: 1.5, carbsPer100g: 2.2, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Rucola", emoji: "🥬", caloriesPer100g: 25, proteinPer100g: 2.6, carbsPer100g: 3.7, fatPer100g: 0.7, category: .vegetable),
    FoodItem(name: "Eisbergsalat", emoji: "🥗", caloriesPer100g: 14, proteinPer100g: 0.9, carbsPer100g: 3.0, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Feldsalat", emoji: "🥗", caloriesPer100g: 14, proteinPer100g: 1.8, carbsPer100g: 0.7, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Kopfsalat", emoji: "🥗", caloriesPer100g: 13, proteinPer100g: 1.4, carbsPer100g: 1.1, fatPer100g: 0.2, category: .vegetable),

    // ===== VEGETABLE — Tomaten & Paprika =====
    FoodItem(name: "Tomaten (frisch)", emoji: "🍅", caloriesPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Cherrytomaten", emoji: "🍅", caloriesPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Tomaten (passiert)", emoji: "🍅", caloriesPer100g: 32, proteinPer100g: 1.4, carbsPer100g: 6.0, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Tomaten (gehackt, Dose)", emoji: "🍅", caloriesPer100g: 32, proteinPer100g: 1.5, carbsPer100g: 5.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Tomatenmark (3-fach konzentriert)", emoji: "🍅", caloriesPer100g: 95, proteinPer100g: 4.8, carbsPer100g: 16, fatPer100g: 0.6, category: .vegetable),
    FoodItem(name: "Paprika rot", emoji: "🫑", caloriesPer100g: 31, proteinPer100g: 1.0, carbsPer100g: 7.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Paprika gelb", emoji: "🫑", caloriesPer100g: 27, proteinPer100g: 1.0, carbsPer100g: 6.3, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Paprika grün", emoji: "🫑", caloriesPer100g: 20, proteinPer100g: 0.9, carbsPer100g: 4.6, fatPer100g: 0.2, category: .vegetable),

    // ===== VEGETABLE — Diverse =====
    FoodItem(name: "Gurke", emoji: "🥒", caloriesPer100g: 15, proteinPer100g: 0.7, carbsPer100g: 3.6, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Zucchini", emoji: "🥒", caloriesPer100g: 17, proteinPer100g: 1.2, carbsPer100g: 3.1, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Aubergine", emoji: "🍆", caloriesPer100g: 25, proteinPer100g: 1.0, carbsPer100g: 6.0, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Champignons (frisch)", emoji: "🍄", caloriesPer100g: 22, proteinPer100g: 3.1, carbsPer100g: 3.3, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Kräuterseitlinge", emoji: "🍄", caloriesPer100g: 33, proteinPer100g: 3.3, carbsPer100g: 6.0, fatPer100g: 0.5, category: .vegetable),
    FoodItem(name: "Zwiebel", emoji: "🧅", caloriesPer100g: 40, proteinPer100g: 1.1, carbsPer100g: 9.3, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Lauch", emoji: "🥬", caloriesPer100g: 31, proteinPer100g: 1.5, carbsPer100g: 7.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Knoblauch", emoji: "🧄", caloriesPer100g: 149, proteinPer100g: 6.4, carbsPer100g: 33, fatPer100g: 0.5, category: .vegetable),
    FoodItem(name: "Frühlingszwiebel", emoji: "🧅", caloriesPer100g: 32, proteinPer100g: 1.8, carbsPer100g: 7.0, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Karotten", emoji: "🥕", caloriesPer100g: 41, proteinPer100g: 0.9, carbsPer100g: 10, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Sellerie (Knolle)", emoji: "🥬", caloriesPer100g: 21, proteinPer100g: 1.5, carbsPer100g: 2.3, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Kohlrabi", emoji: "🥬", caloriesPer100g: 27, proteinPer100g: 1.7, carbsPer100g: 6.2, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Rote Bete (vorgekocht)", emoji: "🥬", caloriesPer100g: 43, proteinPer100g: 1.6, carbsPer100g: 9.6, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Pastinaken", emoji: "🥕", caloriesPer100g: 75, proteinPer100g: 1.2, carbsPer100g: 18, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Hokkaido-Kürbis", emoji: "🎃", caloriesPer100g: 63, proteinPer100g: 1.7, carbsPer100g: 12, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Spargel weiß", emoji: "🌱", caloriesPer100g: 18, proteinPer100g: 1.9, carbsPer100g: 1.7, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Spargel grün", emoji: "🌱", caloriesPer100g: 22, proteinPer100g: 2.4, carbsPer100g: 2.1, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Mais (Dose, abgetropft)", emoji: "🌽", caloriesPer100g: 86, proteinPer100g: 3.3, carbsPer100g: 16, fatPer100g: 1.4, category: .vegetable),
    FoodItem(name: "Grüne Bohnen (tk)", emoji: "🫛", caloriesPer100g: 31, proteinPer100g: 1.8, carbsPer100g: 7.0, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Rahm-Spinat", brand: "Iglo", emoji: "🥬", caloriesPer100g: 78, proteinPer100g: 3.5, carbsPer100g: 4.0, fatPer100g: 5.0, category: .vegetable),
    FoodItem(name: "Erbsen (tk)", brand: "Iglo", emoji: "🫛", caloriesPer100g: 69, proteinPer100g: 5.4, carbsPer100g: 8.5, fatPer100g: 0.7, category: .vegetable),
    FoodItem(name: "Wok-Gemüse Asia-Mix (tk)", brand: "Iglo", emoji: "🥦", caloriesPer100g: 35, proteinPer100g: 2.0, carbsPer100g: 5.0, fatPer100g: 0.5, category: .vegetable),
    FoodItem(name: "Mais (Dose)", brand: "Bonduelle", emoji: "🌽", caloriesPer100g: 86, proteinPer100g: 3.0, carbsPer100g: 15, fatPer100g: 1.5, category: .vegetable),

    // ===== FAT — Öle, Butter, Avocado =====
    FoodItem(name: "Avocado", emoji: "🥑", caloriesPer100g: 160, proteinPer100g: 2.0, carbsPer100g: 9.0, fatPer100g: 15, category: .fat),
    FoodItem(name: "Olivenöl (extra vergine)", emoji: "🫒", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Rapsöl", emoji: "🫗", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Sonnenblumenöl", emoji: "🫗", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Kokosöl", emoji: "🥥", caloriesPer100g: 862, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Leinöl", emoji: "🫗", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Sesamöl", emoji: "🫗", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Butter", emoji: "🧈", caloriesPer100g: 717, proteinPer100g: 0.9, carbsPer100g: 0.7, fatPer100g: 81, category: .fat),
    FoodItem(name: "Margarine", emoji: "🧈", caloriesPer100g: 720, proteinPer100g: 0.2, carbsPer100g: 0.4, fatPer100g: 80, category: .fat),
    FoodItem(name: "Lätta Halbfettmargarine", brand: "Lätta", emoji: "🧈", caloriesPer100g: 357, proteinPer100g: 0.4, carbsPer100g: 0.5, fatPer100g: 39, category: .fat),
    FoodItem(name: "Irische Butter", brand: "Kerrygold", emoji: "🧈", caloriesPer100g: 745, proteinPer100g: 0.7, carbsPer100g: 0.6, fatPer100g: 82, category: .fat),

    // ===== FAT — Nüsse & Samen =====
    FoodItem(name: "Mandeln", emoji: "🌰", caloriesPer100g: 579, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 50, category: .fat),
    FoodItem(name: "Walnüsse", emoji: "🌰", caloriesPer100g: 654, proteinPer100g: 15, carbsPer100g: 14, fatPer100g: 65, category: .fat),
    FoodItem(name: "Cashews", emoji: "🌰", caloriesPer100g: 553, proteinPer100g: 18, carbsPer100g: 30, fatPer100g: 44, category: .fat),
    FoodItem(name: "Haselnüsse", emoji: "🌰", caloriesPer100g: 628, proteinPer100g: 15, carbsPer100g: 17, fatPer100g: 61, category: .fat),
    FoodItem(name: "Pistazien (geschält)", emoji: "🌰", caloriesPer100g: 562, proteinPer100g: 20, carbsPer100g: 28, fatPer100g: 45, category: .fat),
    FoodItem(name: "Paranüsse", emoji: "🌰", caloriesPer100g: 656, proteinPer100g: 14, carbsPer100g: 12, fatPer100g: 66, category: .fat),
    FoodItem(name: "Macadamia-Nüsse", emoji: "🌰", caloriesPer100g: 718, proteinPer100g: 8.0, carbsPer100g: 14, fatPer100g: 76, category: .fat),
    FoodItem(name: "Pekannüsse", emoji: "🌰", caloriesPer100g: 691, proteinPer100g: 9.2, carbsPer100g: 14, fatPer100g: 72, category: .fat),
    FoodItem(name: "Pinienkerne", emoji: "🌰", caloriesPer100g: 673, proteinPer100g: 14, carbsPer100g: 13, fatPer100g: 68, category: .fat),
    FoodItem(name: "Erdnüsse (geröstet, ungesalzen)", emoji: "🥜", caloriesPer100g: 599, proteinPer100g: 26, carbsPer100g: 16, fatPer100g: 49, category: .fat),
    FoodItem(name: "Sonnenblumenkerne", emoji: "🌻", caloriesPer100g: 584, proteinPer100g: 21, carbsPer100g: 20, fatPer100g: 51, category: .fat),
    FoodItem(name: "Kürbiskerne", emoji: "🎃", caloriesPer100g: 559, proteinPer100g: 30, carbsPer100g: 11, fatPer100g: 49, category: .fat),
    FoodItem(name: "Sesam", emoji: "🌰", caloriesPer100g: 573, proteinPer100g: 18, carbsPer100g: 23, fatPer100g: 50, category: .fat),
    FoodItem(name: "Leinsamen (geschrotet)", emoji: "🌾", caloriesPer100g: 534, proteinPer100g: 18, carbsPer100g: 29, fatPer100g: 42, category: .fat),
    FoodItem(name: "Chiasamen", emoji: "🌾", caloriesPer100g: 486, proteinPer100g: 17, carbsPer100g: 42, fatPer100g: 31, category: .fat),
    FoodItem(name: "Erdnussbutter (creamy)", emoji: "🥜", caloriesPer100g: 588, proteinPer100g: 25, carbsPer100g: 20, fatPer100g: 50, category: .fat),
    FoodItem(name: "Mandelmus", emoji: "🌰", caloriesPer100g: 614, proteinPer100g: 21, carbsPer100g: 19, fatPer100g: 56, category: .fat),
    FoodItem(name: "Tahini (Sesammus)", emoji: "🌰", caloriesPer100g: 595, proteinPer100g: 17, carbsPer100g: 21, fatPer100g: 54, category: .fat),

    // ===== OTHER — Schokolade & Süßes =====
    FoodItem(name: "Dunkle Schokolade (85%)", emoji: "🍫", caloriesPer100g: 600, proteinPer100g: 8, carbsPer100g: 24, fatPer100g: 43, category: .other),
    FoodItem(name: "Vollmilchschokolade", emoji: "🍫", caloriesPer100g: 535, proteinPer100g: 7.7, carbsPer100g: 59, fatPer100g: 30, category: .other),
    FoodItem(name: "Alpenmilch Schokolade", brand: "Milka", emoji: "🍫", caloriesPer100g: 534, proteinPer100g: 6.6, carbsPer100g: 58, fatPer100g: 30, category: .other),
    FoodItem(name: "Milka Oreo", brand: "Milka", emoji: "🍫", caloriesPer100g: 525, proteinPer100g: 5.6, carbsPer100g: 60, fatPer100g: 28, category: .other),
    FoodItem(name: "Excellence 70% Cacao", brand: "Lindt", emoji: "🍫", caloriesPer100g: 569, proteinPer100g: 9.3, carbsPer100g: 34, fatPer100g: 41, category: .other),
    FoodItem(name: "Excellence 85% Cacao", brand: "Lindt", emoji: "🍫", caloriesPer100g: 580, proteinPer100g: 11, carbsPer100g: 22, fatPer100g: 46, category: .other),
    FoodItem(name: "Vollmilch", brand: "Ritter Sport", emoji: "🍫", caloriesPer100g: 560, proteinPer100g: 7.0, carbsPer100g: 53, fatPer100g: 34, category: .other),
    FoodItem(name: "Knusperflakes", brand: "Ritter Sport", emoji: "🍫", caloriesPer100g: 545, proteinPer100g: 6.5, carbsPer100g: 56, fatPer100g: 32, category: .other),
    FoodItem(name: "Marzipan", brand: "Ritter Sport", emoji: "🍫", caloriesPer100g: 470, proteinPer100g: 8.5, carbsPer100g: 51, fatPer100g: 26, category: .other),
    FoodItem(name: "Bueno", brand: "Kinder", emoji: "🍫", caloriesPer100g: 569, proteinPer100g: 8.7, carbsPer100g: 50, fatPer100g: 36, category: .other),
    FoodItem(name: "Schokolade Riegel", brand: "Kinder", emoji: "🍫", caloriesPer100g: 562, proteinPer100g: 8.0, carbsPer100g: 53, fatPer100g: 34, category: .other),
    FoodItem(name: "Snickers", brand: "Mars", emoji: "🍫", caloriesPer100g: 488, proteinPer100g: 8.5, carbsPer100g: 55, fatPer100g: 24, category: .other),
    FoodItem(name: "Mars", brand: "Mars", emoji: "🍫", caloriesPer100g: 449, proteinPer100g: 4.0, carbsPer100g: 70, fatPer100g: 16, category: .other),
    FoodItem(name: "Twix", brand: "Mars", emoji: "🍫", caloriesPer100g: 491, proteinPer100g: 4.7, carbsPer100g: 64, fatPer100g: 24, category: .other),
    FoodItem(name: "Bounty", brand: "Mars", emoji: "🍫", caloriesPer100g: 481, proteinPer100g: 4.0, carbsPer100g: 58, fatPer100g: 26, category: .other),
    FoodItem(name: "Goldbären", brand: "Haribo", emoji: "🐻", caloriesPer100g: 343, proteinPer100g: 6.9, carbsPer100g: 77, fatPer100g: 0.5, category: .other),
    FoodItem(name: "Color-Rado", brand: "Haribo", emoji: "🍬", caloriesPer100g: 351, proteinPer100g: 5.5, carbsPer100g: 78, fatPer100g: 1.0, category: .other),
    FoodItem(name: "M&M's Peanut", brand: "Mars", emoji: "🍬", caloriesPer100g: 535, proteinPer100g: 9.4, carbsPer100g: 56, fatPer100g: 30, category: .other),
    FoodItem(name: "Nutella", brand: "Ferrero", emoji: "🍫", caloriesPer100g: 539, proteinPer100g: 6.3, carbsPer100g: 57, fatPer100g: 31, category: .other),
    FoodItem(name: "Honig (Blütenhonig)", emoji: "🍯", caloriesPer100g: 304, proteinPer100g: 0.3, carbsPer100g: 82, fatPer100g: 0, category: .other),
    FoodItem(name: "Marmelade Erdbeere", emoji: "🫙", caloriesPer100g: 240, proteinPer100g: 0.4, carbsPer100g: 60, fatPer100g: 0.1, category: .other),
    FoodItem(name: "Kristallzucker", emoji: "🍬", caloriesPer100g: 400, proteinPer100g: 0, carbsPer100g: 100, fatPer100g: 0, category: .other),

    // ===== OTHER — Snacks =====
    FoodItem(name: "Salzstangen", emoji: "🥨", caloriesPer100g: 379, proteinPer100g: 11, carbsPer100g: 79, fatPer100g: 1.5, category: .other),
    FoodItem(name: "Chipsfrisch ungarisch", brand: "funny-frisch", emoji: "🍟", caloriesPer100g: 533, proteinPer100g: 6.0, carbsPer100g: 51, fatPer100g: 33, category: .other),
    FoodItem(name: "Chips Paprika", brand: "Lay's", emoji: "🍟", caloriesPer100g: 525, proteinPer100g: 6.0, carbsPer100g: 53, fatPer100g: 31, category: .other),
    FoodItem(name: "Pringles Original", brand: "Pringles", emoji: "🍟", caloriesPer100g: 536, proteinPer100g: 4.0, carbsPer100g: 50, fatPer100g: 35, category: .other),
    FoodItem(name: "Butterkeks", brand: "Leibniz", emoji: "🍪", caloriesPer100g: 432, proteinPer100g: 7.0, carbsPer100g: 73, fatPer100g: 12, category: .other),
    FoodItem(name: "Oreo Original", brand: "Oreo", emoji: "🍪", caloriesPer100g: 480, proteinPer100g: 5.0, carbsPer100g: 70, fatPer100g: 20, category: .other),
    FoodItem(name: "Müsliriegel Schoko", brand: "Corny", emoji: "🍫", caloriesPer100g: 419, proteinPer100g: 6.0, carbsPer100g: 70, fatPer100g: 12, category: .other),
    FoodItem(name: "Magnum Classic (1 Stück = 79g)", brand: "Magnum", emoji: "🍦", caloriesPer100g: 282, proteinPer100g: 3.7, carbsPer100g: 28, fatPer100g: 17, category: .other),
    FoodItem(name: "Cookie Dough", brand: "Ben & Jerry's", emoji: "🍨", caloriesPer100g: 264, proteinPer100g: 4.0, carbsPer100g: 33, fatPer100g: 13, category: .other),

    // ===== OTHER — Fertiggerichte & Sonstiges =====
    FoodItem(name: "Pizza Margherita (Backofen)", emoji: "🍕", caloriesPer100g: 252, proteinPer100g: 11, carbsPer100g: 30, fatPer100g: 9.0, category: .other),
    FoodItem(name: "Pizza Salami (Backofen)", emoji: "🍕", caloriesPer100g: 285, proteinPer100g: 12, carbsPer100g: 28, fatPer100g: 14, category: .other),
    FoodItem(name: "Ristorante Pizza Funghi", brand: "Dr. Oetker", emoji: "🍕", caloriesPer100g: 230, proteinPer100g: 9.0, carbsPer100g: 27, fatPer100g: 9.5, category: .other),
    FoodItem(name: "Steinofen-Pizza Salami", brand: "Wagner", emoji: "🍕", caloriesPer100g: 264, proteinPer100g: 11, carbsPer100g: 30, fatPer100g: 11, category: .other),
    FoodItem(name: "5-Minuten Terrine Spaghetti", brand: "Maggi", emoji: "🍜", caloriesPer100g: 380, proteinPer100g: 12, carbsPer100g: 65, fatPer100g: 8.0, category: .other),
    FoodItem(name: "Eintopf Linseneintopf", brand: "Erasco", emoji: "🥣", caloriesPer100g: 70, proteinPer100g: 4.0, carbsPer100g: 9.0, fatPer100g: 2.0, category: .other),
    FoodItem(name: "Hummus", emoji: "🫙", caloriesPer100g: 177, proteinPer100g: 8, carbsPer100g: 14, fatPer100g: 10, category: .other),
    FoodItem(name: "Tomaten-Pesto Genovese", brand: "Barilla", emoji: "🫙", caloriesPer100g: 597, proteinPer100g: 6.5, carbsPer100g: 5.0, fatPer100g: 60, category: .other),
    FoodItem(name: "Pastasauce Napoletana", brand: "Barilla", emoji: "🫙", caloriesPer100g: 56, proteinPer100g: 1.7, carbsPer100g: 8.0, fatPer100g: 1.8, category: .other),
    FoodItem(name: "Tomatenketchup", brand: "Heinz", emoji: "🍅", caloriesPer100g: 102, proteinPer100g: 1.2, carbsPer100g: 23, fatPer100g: 0.1, category: .other),
    FoodItem(name: "Sojasauce", brand: "Kikkoman", emoji: "🫙", caloriesPer100g: 78, proteinPer100g: 11, carbsPer100g: 8.0, fatPer100g: 0, category: .other),
    FoodItem(name: "Mayonnaise (80% Fett)", brand: "Hellmann's", emoji: "🥚", caloriesPer100g: 717, proteinPer100g: 1.0, carbsPer100g: 1.5, fatPer100g: 78, category: .other),
    FoodItem(name: "Senf mittelscharf", emoji: "🫙", caloriesPer100g: 92, proteinPer100g: 6.0, carbsPer100g: 5.0, fatPer100g: 5.0, category: .other),

    // ===== OTHER — Getränke =====
    FoodItem(name: "Wasser (still)", emoji: "💧", caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, category: .other),
    FoodItem(name: "Kaffee (schwarz)", emoji: "☕", caloriesPer100g: 2, proteinPer100g: 0.3, carbsPer100g: 0, fatPer100g: 0, category: .other),
    FoodItem(name: "Espresso", emoji: "☕", caloriesPer100g: 9, proteinPer100g: 0.1, carbsPer100g: 1.7, fatPer100g: 0.2, category: .other),
    FoodItem(name: "Cappuccino (Vollmilch)", emoji: "☕", caloriesPer100g: 37, proteinPer100g: 1.9, carbsPer100g: 2.7, fatPer100g: 2.0, category: .other),
    FoodItem(name: "Cola Original", brand: "Coca-Cola", emoji: "🥤", caloriesPer100g: 42, proteinPer100g: 0, carbsPer100g: 11, fatPer100g: 0, category: .other),
    FoodItem(name: "Cola Zero", brand: "Coca-Cola", emoji: "🥤", caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, category: .other),
    FoodItem(name: "Sprite", brand: "Sprite", emoji: "🥤", caloriesPer100g: 38, proteinPer100g: 0, carbsPer100g: 9.5, fatPer100g: 0, category: .other),
    FoodItem(name: "Fanta Orange", brand: "Fanta", emoji: "🥤", caloriesPer100g: 41, proteinPer100g: 0, carbsPer100g: 10, fatPer100g: 0, category: .other),
    FoodItem(name: "Apfelschorle", emoji: "🧃", caloriesPer100g: 24, proteinPer100g: 0.1, carbsPer100g: 5.5, fatPer100g: 0, category: .other),
    FoodItem(name: "Orangensaft", emoji: "🧃", caloriesPer100g: 45, proteinPer100g: 0.7, carbsPer100g: 10, fatPer100g: 0.2, category: .other),
    FoodItem(name: "Pils (5%)", emoji: "🍺", caloriesPer100g: 43, proteinPer100g: 0.5, carbsPer100g: 3.6, fatPer100g: 0, category: .other),
    FoodItem(name: "Weißbier (5,4%)", emoji: "🍺", caloriesPer100g: 48, proteinPer100g: 0.6, carbsPer100g: 3.8, fatPer100g: 0, category: .other),
    FoodItem(name: "Rotwein (12%)", emoji: "🍷", caloriesPer100g: 85, proteinPer100g: 0.1, carbsPer100g: 2.6, fatPer100g: 0, category: .other),
    FoodItem(name: "Weißwein (12%)", emoji: "🍷", caloriesPer100g: 82, proteinPer100g: 0.1, carbsPer100g: 2.6, fatPer100g: 0, category: .other),

    // ===== OTHER — Riegel & Shakes =====
    FoodItem(name: "Proteinriegel (generisch)", emoji: "🍫", caloriesPer100g: 350, proteinPer100g: 28, carbsPer100g: 30, fatPer100g: 10, category: .other),
    FoodItem(name: "Proteinshake (fertig)", emoji: "🥤", caloriesPer100g: 40, proteinPer100g: 6, carbsPer100g: 3.0, fatPer100g: 0.5, category: .other),
  ]
}
