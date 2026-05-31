import SwiftUI
import UIKit

enum GainsAppearanceMode: String, CaseIterable, Codable {
  case system
  case light
  case dark

  var title: String {
    switch self {
    case .system:
      return "System"
    case .light:
      return "Hell"
    case .dark:
      return "Dunkel"
    }
  }

  var preferredColorScheme: ColorScheme? {
    switch self {
    case .system:
      return nil
    case .light:
      return .light
    case .dark:
      return .dark
    }
  }
}

enum GainsColor {
  // 2026-05-14 (Brand-Loop 1): True-Black-Base + Signal-Green im Dark-Mode.
  // 2026-05-29 (Light-Mode-Pass v2): Pure-White-Glas mit Glow.
  //
  // Light-Mode-Philosophie (v2 — User-Direktive):
  // - Background ist reinweiß `#FFFFFF` mit einem warmen Lichtkegel
  //   oben-mitte als Glow. Nicht cream, nicht beige — wie ein gut
  //   ausgeleuchteter Showroom.
  // - Cards bekommen eine *visible* Cool-Off-White-Tönung (`#ECEFF5`),
  //   damit sie sich vom weißen BG abheben. Plus starke Glass-Edges
  //   (oben hell, unten dunkler) + Inner-Light-Pool oben-leading +
  //   sichtbarer Drop-Shadow → die Kacheln lesen sich wie echtes Glas.
  // - Lime auf `#94BD1F` — energisches Olivgrün mit Punch auf Weiß.
  // - Ink-Stufen #0B0E13 / #5C6371 / #9095A0 sind kühl-neutral (nicht
  //   warm-braun) — passt zur kühlen Cool-White-Glas-Optik.
  // - CTA-Surfaces bleiben dunkel — Hero-Cards behalten ihren Punch.
  static let background = Color(lightHex: "FFFFFF", darkHex: "000000")
  // 2026-05-29 (Light-Mode-Pass v3): card #ECEFF5 → #F2F5FC — heller,
  // weniger saturiertes Blau-Grau. Tiles wirkten auf Pure-White zu dunkel;
  // #F2F5FC behält die Cool-Glass-Identität bei und ist deutlich leichter.
  // elevated und surfaceDeep entsprechend nach oben verschoben.
  static let card = Color(lightHex: "F2F5FC", darkHex: "0A0A0A")
  static let elevated = Color(lightHex: "F7F9FD", darkHex: "141414")
  static let ink = Color(lightHex: "0B0E13", darkHex: "FAFAFA")
  static let softInk = Color(lightHex: "5C6371", darkHex: "A1A1A1")
  // 2026-05-29 (Light-Mode-Pass — Loop 1): mutedInk light #9095A0 → #6E7582.
  // Altes Wert: Kontrast auf #FFFFFF = ~2.9:1 (WCAG fail, sichtbar schwaches
  // Grau). Neuer Wert: Kontrast ~4.5:1 — besteht AA für normale Textgröße.
  static let mutedInk = Color(lightHex: "6E7582", darkHex: "525252")
  // Hairline-Border: sichtbarer Cool-Gray-Hairline im Light-Mode (#D6DAE2),
  // dunkler Neutral (#1C1C1C) im Dark-Mode.
  static let border = Color(lightHex: "D6DAE2", darkHex: "1C1C1C")
  // Lime: energisches Olivgrün (#94BD1F) im Light-Mode mit AA-Kontrast
  // auf Weiß, klassisches Signal-Green im Dark-Mode (#C7EA45).
  static let lime = Color(lightHex: "94BD1F", darkHex: "C7EA45")
  static let moss = Color(lightHex: "6E8B2C", darkHex: "8AAA42")
  static let signalDeep = Color(lightHex: "7A9B30", darkHex: "9DBE4A")
  static let onLime = Color(lightHex: "081005", darkHex: "081005")
  static let onLimeSecondary = Color(lightHex: "1A2208", darkHex: "1A2208")
  // Ember: kräftiges Coral (#E55A3C) im Light-Mode.
  static let ember = Color(lightHex: "E55A3C", darkHex: "FF6A4A")
  static let emberGlow = Color(lightHex: "F08F75", darkHex: "FFB094")
  static let onEmber = Color(lightHex: "190503", darkHex: "190503")
  static let onEmberSecondary = Color(lightHex: "3A1109", darkHex: "3A1109")
  // 2026-05-31 (Design-Optim): Makro-Farbsystem vervollständigt. Fett war als
  // einziges Makro hartcodiert (`Color(hex: "FF8A4A")` an 12 Stellen), während
  // Protein = `lime` und Kohlenhydrate = `accentCool` schon Tokens waren. Dieses
  // warme Amber ist bewusst eigenständig vom `ember`-Coral (#E55A3C), das
  // semantisch „über Budget / Warnung" kodiert — sonst würden Fett-Werte optisch
  // mit Warn-Zuständen verschmelzen. Wird auch für „verbrannte" Energie genutzt
  // (warme Energiefarbe). Identischer Hex in beiden Modi: liest auf Weiß wie auf
  // True-Black sauber, daher keine Modus-Spaltung nötig.
  static let macroFat = Color(lightHex: "FF8A4A", darkHex: "FF8A4A")
  // SurfaceDeep: eine Stufe versenkte Surface — Light-Mode `#E2E5EC`,
  // Dark-Mode weiterhin true black.
  // 2026-05-29: surfaceDeep ebenfalls aufgehellt (E2E5EC → EAEDF5),
  // da subdued GainsStatTiles (surfaceDeep.0.7) sonst als einzige
  // Tiles dunkler als card wirken.
  static let surfaceDeep = Color(lightHex: "EAEDF5", darkHex: "000000")

  /// CTA-Fläche — bleibt in beiden Modi dunkel, damit Hero-Cards und
  /// Icon-Tiles ihren Punch behalten. Light-Mode: warmer Anthrazit
  /// (#1F2329), Dark-Mode: #1C1C1C.
  static let ctaSurface = Color(lightHex: "1F2329", darkHex: "1C1C1C")

  /// Eine Stufe heller als ctaSurface — Chips/Pills auf CTA-Surface.
  static let ctaRaised = Color(lightHex: "2A2E34", darkHex: "262626")

  /// 2026-05-31 (Dark-Accent-Pass): Dedizierte Onyx-Akzentfläche für die
  /// *vereinzelten* bewussten Dunkel-Anker im sonst hellen Light-Mode-UI
  /// (Pulse-HUD, Featured-KPI, Spotlight-Tile). Bewusst sparsam einsetzen —
  /// ein, max. zwei pro Screen, sonst kippt der freundliche Glas-Look.
  /// Light-Mode: warmer Anthrazit (#1F2329, wie ctaSurface). Dark-Mode: eine
  /// Stufe angehoben (#262626) damit der Akzent auf True-Black als eigene
  /// Ebene liest statt mit dem Hintergrund zu verschmelzen.
  static let onyxAccent = Color(lightHex: "1F2329", darkHex: "262626")

  // MARK: Foregrounds AUF dunklen CTA-Surfaces
  //
  // Diese Tokens sind die richtige Adresse für Text/Icons auf einer
  // CTA-Hero-Card. Weil ctaSurface in BEIDEN Modi dunkel ist, sind diese
  // Werte explizit hell (statt sich an `ink` zu hängen — sonst würde im
  // Light-Mode dunkles Ink auf dunklem CTA-Hintergrund unsichtbar).
  static let onCtaSurface = Color(lightHex: "FAFAFA", darkHex: "FAFAFA")
  static let onCtaSurfaceSecondary = Color(lightHex: "B0B4B9", darkHex: "A1A1A1")
  static let onCtaSurfaceMuted = Color(lightHex: "70757A", darkHex: "525252")

  /// Kühler Akzent für „in Bearbeitung / informativ"-Zustände und
  /// HUD-Highlights (Scan, Verbindungssuche, Sync). Spiegelt im neuen
  /// Look das HUD-Vokabular und ist bewusst kein zweites Lime.
  ///
  /// 2026-05-14 (v3): Auf User-Wunsch nochmals weg vom Blau gezogen —
  /// jetzt Sage-Teal `#7AA89A`. Sitzt in der grünen Brand-Familie
  /// (zwischen Lime und Moss), liest sich nicht mehr als „Blau", bleibt
  /// aber kühl genug um Carbs/Info-States visuell von Protein (Lime)
  /// und Fett (Ember) abzugrenzen.
  /// Vorher: `#5BD4F0` (Sky-Cyan, zu elektrisch) → `#6FA0DC`
  /// (Periwinkle, immer noch zu blau).
  static let accentCool = Color(lightHex: "7AA89A", darkHex: "7AA89A")

  /// Glow-Token: leicht transparente Variante des Lime — für weiche
  /// Halo-Effekte hinter aktiven Elementen und Hero-Komponenten. Wird
  /// als Schatten/Background-Layer benutzt, nicht als Vordergrundfarbe.
  ///
  /// A13 (Cleaner-Pass): Opacity von 0.35 auf 0.22 reduziert. Lime-Glows
  /// waren in dunkler Umgebung der konstant lauteste Layer — jetzt eher
  /// subtiler Schein, der Aktivität signalisiert ohne Aufmerksamkeit zu fordern.
  static let limeGlow = Color(red: 0.78, green: 0.92, blue: 0.27, opacity: 0.12)

  /// Glow-Token: kühler Pendant zu `limeGlow` — z.B. für Scan-Status,
  /// In-Progress-Markierungen und HUD-Akzente.
  ///
  /// A13 (Cleaner-Pass): Opacity von 0.30 auf 0.18 reduziert (analog zu limeGlow).
  static let coolGlow = Color(red: 0.36, green: 0.83, blue: 0.94, opacity: 0.10)

  // MARK: Heart-Rate-Zonen
  //
  // HUD-tauglicher Lauf der Zonen: Cyan → Lime → Gold → Amber → Ember.
  // Werte sind zwischen Light/Dark gespiegelt, weil die App Dark-Only
  // läuft.
  static let zone1 = Color(lightHex: "5BD4F0", darkHex: "5BD4F0")  // Z1 · Regeneration (Cyan)
  static let zone2 = lime                                          // Z2 · Grundlage (Lime)
  static let zone3 = Color(lightHex: "E0C24A", darkHex: "E0C24A")  // Z3 · Tempo (Gold)
  static let zone4 = Color(lightHex: "FF9A4A", darkHex: "FF9A4A")  // Z4 · Schwelle (Amber)
  static let zone5 = ember                                          // Z5 · VO₂max (Ember)
}

extension HRZone {
  /// Design-System-Farbe der Zone — ersetzt die hartcodierten SwiftUI-Farben,
  /// die früher in RunTrackerView/RunDetailSheet dupliziert waren.
  /// `active` dimmt die Farbe ab, wenn die Zone gerade nicht „aktiv“ ist
  /// (z.B. inaktive Stelle einer Zonen-Verteilung).
  func color(active: Bool = true) -> Color {
    let base: Color
    switch self {
    case .zone1: base = GainsColor.zone1
    case .zone2: base = GainsColor.zone2
    case .zone3: base = GainsColor.zone3
    case .zone4: base = GainsColor.zone4
    case .zone5: base = GainsColor.zone5
    }
    return active ? base : base.opacity(0.35)
  }
}

enum GainsFont {

  // MARK: - Kanonische Type-Ramp (B1)
  //
  // Sechs feste Stufen ohne stille Floor-Logik. Neuer Code sollte diese
  // Tokens (oder besser: die Text-Rollen-Modifier `.gainsTitle`, `.gainsBody`,
  // `.gainsCaption`, `.gainsEyebrow`) benutzen statt der parametrisierten
  // Helper unten — letztere bleiben für die schrittweise Migration kompatibel.
  //
  //   Stufe       Größe   Gewicht       Verwendung
  //   --------    -----   --------      ------------------------------------
  //   display     28pt    semibold      Hero-Title, Wochenziel-Ring, KPI-Star
  //   title       22pt    semibold      Section-Headline, Card-Title
  //   headline    17pt    semibold      Sub-Title innerhalb einer Card
  //   body        15pt    regular       Fließtext, Subtitle, Beschreibung
  //   caption     13pt    medium        Sekundärtext, Meta, Listen-Detail
  //   eyebrow     11pt    semibold mono Uppercase-HUD-Label
  //
  // Numerik (mono) hat eine eigene 3-Stufen-Skala:
  //   metricLarge 28pt    semibold mono Großer KPI-Wert (Tracker, Hero)
  //   metric      20pt    semibold mono Standard-KPI in Tiles und Strips
  //   metricSmall 16pt    semibold mono Inline-Wert in Listen / Pills

  static let display      = Font.system(size: 28, weight: .semibold)
  static let title        = Font.system(size: 22, weight: .semibold)
  static let headline     = Font.system(size: 17, weight: .semibold)
  static let body         = Font.system(size: 15, weight: .regular)
  static let caption      = Font.system(size: 13, weight: .medium)
  static let eyebrow      = Font.system(size: 11, weight: .semibold, design: .monospaced)

  static let metricLarge  = Font.system(size: 28, weight: .semibold, design: .monospaced)
  static let metric       = Font.system(size: 20, weight: .semibold, design: .monospaced)
  static let metricSmall  = Font.system(size: 16, weight: .semibold, design: .monospaced)

  // MARK: - Hero-Display (Brand-Loop 3, 2026-05-14)
  //
  // Drei Stufen für massive Display-Zahlen. Heavy-Variante rückgängig
  // (User-Direktive 2026-05-14) — zurück auf .semibold. Tracking
  // (−0.04em) bleibt erhalten, die Stufen wirken weiterhin groß, aber
  // typografisch ruhig.
  static let megaHero     = Font.system(size: 120, weight: .semibold, design: .default)
  static let hero         = Font.system(size: 96,  weight: .semibold, design: .default)
  static let subHero      = Font.system(size: 72,  weight: .semibold, design: .default)

  // MARK: - Legacy parametrisierte Helper
  //
  // Bewusst beibehalten: bestehender Code ruft sie 800+ mal auf, und die
  // Floor-Logik ist Teil der heutigen Optik. Neue Stellen sollten stattdessen
  // die kanonischen Tokens oder die Text-Rollen-Modifier benutzen.

  static func display(_ size: CGFloat) -> Font {
    .system(size: max(size, 24), weight: .semibold)
  }

  static func title(_ size: CGFloat = 24) -> Font {
    // Floor von 21 -> 22 für klar lesbare Überschriften
    .system(size: max(size, 22), weight: .semibold)
  }

  /// A4: Default jetzt 17pt (Apple-HIG-Standard für Body), Floor bleibt 16pt
  /// damit explizit kleinere Aufrufe wie `body(13)` nicht überraschend wachsen.
  static func body(_ size: CGFloat = 17) -> Font {
    .system(size: max(size, 16), weight: .regular)
  }

  static func label(_ size: CGFloat = 12) -> Font {
    // Floor von 12 -> 13: getrackte Uppercase-Labels werden so deutlich besser lesbar
    .system(size: max(size, 13), weight: .medium)
  }

  /// A8: Tracked Uppercase-Eyebrow ist jetzt monospaced — passt zum
  /// HUD/Minimal-Tech-Vokabular und gibt Section-Labels einen klaren
  /// Kontrast zur proportionalen Body-/Title-Schrift.
  static func eyebrow(_ size: CGFloat = 13) -> Font {
    .system(size: max(size, 13), weight: .semibold, design: .monospaced)
  }

  /// Kleine Caption-Texte mit etwas mehr Gewicht für Lesbarkeit.
  static func caption(_ size: CGFloat = 13) -> Font {
    .system(size: max(size, 13), weight: .medium)
  }

  /// A8: Monospaced Numeric-Display — z.B. für KPIs/HUD-Werte. Vorhandene
  /// Tiles können das selektiv übernehmen, Bestand bleibt unangetastet.
  static func metricMono(_ size: CGFloat = 22) -> Font {
    .system(size: max(size, 16), weight: .semibold, design: .monospaced)
  }
}

// MARK: - Tracking-Konstanten (B1)
//
// Zentralisiert die Letter-Spacing-Werte für uppercase HUD-Labels. Vorher
// waren über die App 1.2 / 1.4 / 1.5 / 1.6 / 1.8 / 2.2 unsystematisch verteilt.
// Alle neuen Stellen benutzen `GainsTracking.eyebrow` als Default; die beiden
// Varianten bleiben für eng/weit gespreizte Sondersituationen.
enum GainsTracking {
  /// Default für die meisten getrackten Eyebrows (1.6).
  static let eyebrow: CGFloat = 1.6
  /// Engere Variante — innerhalb von Pills, schmalen Chips, Status-Badges.
  static let eyebrowTight: CGFloat = 1.2
  /// Weitere Variante — auf Hero-Surfaces für besonders prägnante HUD-Labels.
  static let eyebrowWide: CGFloat = 1.8
}

// MARK: - Layout-Tokens (A13 — Cleaner-Pass)
//
// Vor diesem Pass wurden CornerRadius / Spacing / Border-Width über die App
// freihand verteilt — 8/12/13/14/16/18/20/22/24 für Cards, 4/6/8/10/12/14/16/18
// für Stack-Spacing, 0.5/0.6/0.7/0.8/0.9/1.0/1.4 für Borders. Das Ergebnis war
// ein subtil "lautes" UI: jede Kachel hatte eine eigene Geometrie.
//
// Die Tokens unten sind das Vokabular für neuen Code; bestehender Code wird
// schrittweise migriert. Wer eine Card baut, soll genau eine Stufe wählen
// statt einen freien Wert.

enum GainsRadius {
  /// 8 — sehr kleine Chips, Status-Pills, Inline-Badges (A15-Erweiterung).
  static let tiny: CGFloat = 8
  /// 12 — kleine Pills, Mini-Tiles, Inline-Capsules, Sub-Karten.
  static let small: CGFloat = 12
  /// 16 — Standard-Card-Radius (gainsCardStyle nutzt diesen Wert).
  /// Vorher: 20 — die App wirkte dadurch knubbelig statt iOS-modern.
  static let standard: CGFloat = 16
  /// 22 — Hero-/Featured-Cards (eine Stufe größer als Standard, aber nicht
  /// so monumental wie 24).
  static let hero: CGFloat = 22
}

enum GainsSpacing {
  /// 4 — sehr eng (Inline-Eyebrows, sub-pixel-Korrekturen).
  static let xxs: CGFloat = 4
  /// 6 — kompakt (Eyebrow → Wert, Icon → Label).
  static let xs: CGFloat = 6
  /// 8 — eng (kleine Pill-Inhalte, Icon-Text-Pairs).
  static let xsPlus: CGFloat = 8
  /// 10 — „tight pair" (zwei zusammengehörige Bausteine, z. B. Greeting +
  /// Coach-Brief auf dem Home: enger als zwischen Sektionen, aber luftiger
  /// als ein Eyebrow-Spacing). Vorher als Magic-Number `10` an >190 Stellen
  /// verstreut.
  static let tight: CGFloat = 10
  /// 12 — Standard-Inhalts-Spacing innerhalb einer Card.
  static let s: CGFloat = 12
  /// 16 — Sektionen innerhalb einer Card, Card-Innenpadding.
  static let m: CGFloat = 16
  /// 20 — Spacing zwischen großen Bausteinen (Hero → Cockpit).
  static let l: CGFloat = 20
  /// 24 — Outer-Container-Spacing, Sektion-zu-Sektion.
  static let xl: CGFloat = 24
}

enum GainsBorder {
  /// 0.6 — Hairline (Standard für nicht-akzentuierte Cards).
  static let hairline: CGFloat = 0.6
  /// 0.8 — Akzent-Hairline für interaktive Karten / Lime-Borders.
  static let accent: CGFloat = 0.8
  /// 1.0 — Bold (nur für starke Akzent-CTAs wie der Start-Button).
  static let bold: CGFloat = 1.0
}

// MARK: - Text-Rollen-Modifier (B2)
//
// Diese Modifier setzen Font + Farbe + LineSpacing + Tracking als ein Paket.
// Sie sind die kanonische API für Text-Hierarchie; sie verheiraten die Type-
// Ramp mit der Farbtoken-Hierarchie (`ink`, `softInk`, `mutedInk`):
//
//   Rolle      Default-Farbe   LineSpacing   Hinweis
//   --------   -------------   -----------   ----------------------------
//   title      ink             0             Section-Header
//   headline   ink             0             Sub-Header in Cards
//   body       ink             3             Default für Fließtext
//   caption    softInk         2             Sekundärer Lesetext
//   eyebrow    softInk         0 (tracking)  HUD-Label, uppercase, mono
//
// Beispiel:
//   Text("Heute").gainsTitle()
//   Text("Beschreibung über mehrere Zeilen").gainsBody(secondary: true)
//   Text("STATUS").gainsEyebrow(.lime)
extension View {
  /// Title-Rolle: 22pt semibold, Default-Farbe `ink`.
  func gainsTitle(_ color: Color = GainsColor.ink) -> some View {
    self.font(GainsFont.title).foregroundStyle(color)
  }

  /// 2026-05-14 (Brand-Loop 3): Hero-Display für die emotionalen Zahlen
  /// der App (Streak, Wochenziel). Drei Größenstufen, alle mit:
  ///   • Tabular Figures via `.monospacedDigit()`
  ///   • Tracking −0.04em
  ///   • Default-Foreground `ink` (Streak nutzt z. B. `lime`)
  func gainsHeroDisplay(
    _ color: Color = GainsColor.ink,
    size: GainsHeroSize = .hero
  ) -> some View {
    let font: Font
    let pt: CGFloat
    switch size {
    case .megaHero:
      font = GainsFont.megaHero
      pt = 120
    case .hero:
      font = GainsFont.hero
      pt = 96
    case .subHero:
      font = GainsFont.subHero
      pt = 72
    }
    return self
      .font(font)
      .monospacedDigit()
      .tracking(-pt * 0.04)
      .foregroundStyle(color)
  }

  /// Headline-Rolle: 17pt semibold, Default-Farbe `ink`. Für Sub-Überschriften
  /// innerhalb einer Card oder Section.
  func gainsHeadline(_ color: Color = GainsColor.ink) -> some View {
    self.font(GainsFont.headline).foregroundStyle(color)
  }

  /// Body-Rolle: 15pt regular mit Zeilenabstand 3pt für mehrzeilige Passagen.
  /// Mit `secondary: true` wird auf `softInk` gewechselt (z.B. für Subtitle
  /// oder erklärende Beschreibungen).
  func gainsBody(_ color: Color = GainsColor.ink, secondary: Bool = false) -> some View {
    self
      .font(GainsFont.body)
      .foregroundStyle(secondary ? GainsColor.softInk : color)
      .lineSpacing(3)
  }

  /// Caption-Rolle: 13pt medium, Zeilenabstand 2pt, Default-Farbe `softInk`.
  /// Für sekundären Lesetext, Meta-Angaben, kleine Detail-Listen.
  func gainsCaption(_ color: Color = GainsColor.softInk) -> some View {
    self
      .font(GainsFont.caption)
      .foregroundStyle(color)
      .lineSpacing(2)
  }

  /// Numerik-Rolle (Standard 20pt mono semibold). Für KPI-Werte, Timer,
  /// HUD-Anzeigen. Mit `style: .large` auf 28pt, `.small` auf 16pt.
  func gainsMetric(
    _ color: Color = GainsColor.ink,
    size: GainsMetricSize = .standard
  ) -> some View {
    let font: Font
    switch size {
    case .large:    font = GainsFont.metricLarge
    case .standard: font = GainsFont.metric
    case .small:    font = GainsFont.metricSmall
    }
    return self
      .font(font)
      .foregroundStyle(color)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
  }
}

enum GainsMetricSize {
  case large      // 28pt — Hero-KPI
  case standard   // 20pt — MetricTile, KPIStrip
  case small      // 16pt — Inline-Wert
}

/// 2026-05-14 (Brand-Loop 3): Drei Stufen Hero-Display.
enum GainsHeroSize {
  case megaHero   // 120pt — Streak-Zentrum
  case hero       //  96pt — Workout-Finish, Wochenziel
  case subHero    //  72pt — Sub-Sektion-Hero
}

extension Color {
  init(hex: String) {
    let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: sanitized).scanHexInt64(&value)

    let red = Double((value >> 16) & 0xFF) / 255
    let green = Double((value >> 8) & 0xFF) / 255
    let blue = Double(value & 0xFF) / 255

    self.init(red: red, green: green, blue: blue)
  }

  init(lightHex: String, darkHex: String) {
    // Stabilität (2026-05-31): Die beiden UIColors werden EAGER außerhalb des
    // Trait-Providers aufgelöst. Vorher wurde `UIColor(Color(hex:))` INNERHALB
    // der Closure ausgewertet — beim Schatten-Rendern (.shadow) fragt SwiftUI
    // diesen Provider in einem Rasterisierungs-Kontext OHNE gültige SwiftUI-
    // Umgebung ab, was zu EXC_BAD_ACCESS (Crash auf dem Home-Screen) führte.
    // Jetzt enthält die Closure nur noch die Auswahl zwischen zwei fertigen
    // UIColor-Instanzen.
    let lightUI = UIColor(Color(hex: lightHex))
    let darkUI = UIColor(Color(hex: darkHex))
    self.init(
      uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? darkUI : lightUI
      }
    )
  }

  /// 2026-05-29 (Light-Mode-Pass): Dynamic-Color-Variante, die nicht nur
  /// Hex-Werte sondern beliebige `Color`-Instanzen (inkl. Opacity) zwischen
  /// Light/Dark switcht. Wird vor allem für die Glass-Edge-/Inner-Light-
  /// Tokens gebraucht, die `Color.white.opacity(...)` nutzen.
  init(light: Color, dark: Color) {
    // Stabilität (2026-05-31): siehe init(lightHex:darkHex:) — UIColor einmalig
    // eager auflösen statt bei jedem Trait-Query in der Closure. Sonst crasht
    // das Schatten-Rendering (gainsDepthShadow → shadowCardKey/-HeroKey) mit
    // EXC_BAD_ACCESS, weil der Provider während der Rasterisierung ohne SwiftUI-
    // Environment eine SwiftUI-Color → UIColor-Konvertierung ausführen müsste.
    let lightUI = UIColor(light)
    let darkUI = UIColor(dark)
    self.init(
      uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark ? darkUI : lightUI
      }
    )
  }
}

// MARK: - Adaptive Shadow-Tokens (Light-Mode-Pass)
//
// Schwarz-Schatten mit 0.28 Opacity sehen auf Cream-Hintergrund deutlich
// schwerer aus als auf True-Black. Diese Tokens skalieren die Tiefen-Stufen
// für den Light-Mode runter, damit der „Glas"-Eindruck nicht in Asphalt-
// Schatten erstickt.
extension GainsColor {
  // 2026-05-29 v2: Light-Mode Schatten leicht angehoben — Glas auf
  // pure-Weiß braucht spürbare Drop-Shadows, damit Karten *float* statt
  // wie aufgemalt zu wirken. Dark-Mode-Werte 1:1 wie vorher.
  static let shadowRest        = Color(light: Color.black.opacity(0.08), dark: Color.black.opacity(0.22))
  static let shadowCardAmbient = Color(light: Color.black.opacity(0.10), dark: Color.black.opacity(0.28))
  static let shadowCardKey     = Color(light: Color.black.opacity(0.13), dark: Color.black.opacity(0.35))
  static let shadowHeroAmbient = Color(light: Color.black.opacity(0.12), dark: Color.black.opacity(0.34))
  static let shadowHeroKey     = Color(light: Color.black.opacity(0.16), dark: Color.black.opacity(0.42))
  static let shadowFloatAmbient = Color(light: Color.black.opacity(0.14), dark: Color.black.opacity(0.38))
  static let shadowFloatKey    = Color(light: Color.black.opacity(0.20), dark: Color.black.opacity(0.48))
}

extension View {
  /// A17 (Liquid Glass): Card-Style mit Material-Backdrop, Edge-Highlight
  /// und 2-Layer-Tiefenschatten. Drop-in-Ersatz für die A8-Card.
  ///
  /// - Material `.regularMaterial` als Glas-Backdrop (statt fester
  ///   `card`-Farbe). Der `background`-Parameter bleibt für Bestand
  ///   kompatibel und wird als optionaler Tint *unter* dem Material
  ///   genutzt — ist es der Default `GainsColor.card`, gibt's keinen
  ///   Tint, das Material kontrolliert die Optik.
  /// - Top-Edge-Highlight (1pt Gradient 14% → 2% Weiß): die Lichtkante.
  /// - Inner-Light-Pool oben-leading: subtiler Linear-Gradient, 4% Weiß.
  /// - 2-Layer-Schatten (Ambient + Key) für echte Tiefe.
  func gainsCardStyle(_ background: Color = GainsColor.card) -> some View {
    // A17: Übergebene Farbe wird als dezenter Glas-Tint angewendet —
    // sorgt für konsistenten dunklen Karten-Look unabhängig vom
    // Hintergrund. 0.45-Opacity hält das Material sichtbar genug.
    //
    // 2026-05-14 (Polish-Loop 43): compositingGroup() vor dem
    // gainsDepthShadow im glassSurface — verhindert App-weit Scroll-
    // Drift bei verschachtelten Material/Gradient-Layern. Ein einzelner
    // Punkt für ALLE Cards in der App.
    // 2026-05-29 (Light-Mode-Pass v3): Tint-Opacity 0.45 → 0.28.
    // Mit dem neuen helleren card-Token (#F2F5FC) und glassUndertone (0.40)
    // war 0.45 zu stark — die Tile-Farbe dominierte das Material. 0.28
    // lässt das Material mehr durchscheinen und wirkt leichter/heller.
    return self
      .compositingGroup()
      .gainsGlassSurface(
        corner: GainsRadius.standard,
        material: .regular,
        tint: background.opacity(0.22),
        depth: .card
      )
  }

  /// A17 (Liquid Glass): Interaktive Card mit Akzent-Glas-Edge und
  /// dezentem Signal-Glow. Im Vergleich zur Standard-Card:
  /// - Edge-Stroke ist ein zweistufiger Akzent-Gradient (oben hell,
  ///   unten transparent), statt der neutralen Weiß-Lichtkante
  /// - Zusätzlicher Akzent-Halo unter der Card (10pt, opacity 0.16)
  func gainsInteractiveCardStyle(
    _ background: Color = GainsColor.card, accent: Color = GainsColor.signal
  ) -> some View {
    let shape = RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
    // A17: 0.45-Glas-Tint aus der Background-Farbe + 6% Akzent
    // damit die "interaktive" Card sichtbar zur Standard-Card aufschließt.
    let tint: Color = background.opacity(0.45)
    return self
      .background {
        ZStack {
          shape.fill(GainsColor.glassUndertone)
          shape.fill(.regularMaterial)
          shape.fill(tint)
          shape.fill(accent.opacity(0.06))
          // 2026-05-29 (Light-Mode-Pass v3): .plusLighter entfernt,
          // konsistent mit gainsGlassSurface.
          shape
            .fill(
              LinearGradient(
                colors: [GainsColor.glassInnerLight, .clear],
                startPoint: .topLeading,
                endPoint: .center
              )
            )
          // Specular-Hotspot — konsistent mit gainsGlassSurface.
          shape
            .fill(
              RadialGradient(
                colors: [GainsColor.glassSpecular, .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 130
              )
            )
        }
      }
      .overlay {
        shape
          .stroke(
            LinearGradient(
              colors: [
                accent.opacity(0.55),
                accent.opacity(0.10)
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: GainsBorder.accent
          )
      }
      .clipShape(shape)
      .shadow(color: accent.opacity(0.16), radius: 12, x: 0, y: 0)
      .gainsDepthShadow(.card)
  }

  /// 2026-05-31 (Dark-Accent-Pass): Bewusster dunkler Akzent für *vereinzelte*
  /// Spotlight-Flächen im hellen UI — ein satter Onyx-Block, der den Blick
  /// gezielt ankert (Pulse-HUD, Featured-KPI, Spotlight-Tile). Gegenstück zur
  /// hellen Frosted-Glass-Card: dieselbe implizite Lichtquelle oben-leading,
  /// nur als dunkle Bühne statt als Milchglas.
  ///
  /// Sparsam einsetzen (ein, max. zwei pro Screen). Vordergrund-Text auf dieser
  /// Fläche immer über die `onCtaSurface*`-Tokens setzen — `ink`/`softInk` sind
  /// im Light-Mode dunkel und würden auf dem Onyx verschwinden.
  func gainsOnyxAccent(
    corner: CGFloat = GainsRadius.standard,
    accent: Color = GainsColor.signal
  ) -> some View {
    let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
    return self
      .background {
        ZStack {
          shape.fill(GainsColor.onyxAccent)
          // Top-Sheen — implizite Lichtquelle oben (wie bei den Glas-Cards,
          // nur dezenter; eine dunkle Fläche braucht weniger Highlight).
          shape.fill(
            LinearGradient(
              colors: [Color.white.opacity(0.06), .clear],
              startPoint: .top,
              endPoint: .center
            )
          )
          // Akzent-Halo oben-leading — derselbe HUD-Glow wie auf den hellen
          // Tiles, hält die dunkle Fläche im Brand-Vokabular statt sie als
          // Fremdkörper wirken zu lassen.
          RadialGradient(
            colors: [accent.opacity(0.16), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 170
          )
        }
      }
      .overlay(
        shape.strokeBorder(
          LinearGradient(
            colors: [Color.white.opacity(0.12), Color.white.opacity(0.03)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
      )
      .clipShape(shape)
      .compositingGroup()
      .gainsDepthShadow(.card)
  }

  /// Eyebrow-Modifier — kanonische Form für getrackte uppercase HUD-Labels.
  ///
  /// Ohne Argumente: 11pt mono semibold, Tracking 1.6, Farbe `softInk` —
  /// das ist die kanonische Eyebrow-Stufe und die empfohlene Default-Form.
  /// Mit explizitem `size:` wird der parametrisierte Helper benutzt (mit
  /// Floor bei 13pt, für Bestand). Mit explizitem `tracking:` lässt sich
  /// für eng/weit gespreizte Sondersituationen abweichen — sonst die
  /// `GainsTracking.*`-Konstanten benutzen, nicht freie Werte.
  func gainsEyebrow(
    _ color: Color = GainsColor.softInk,
    size: CGFloat? = nil,
    tracking: CGFloat = GainsTracking.eyebrow
  ) -> some View {
    let resolvedFont: Font = size.map { GainsFont.eyebrow($0) } ?? GainsFont.eyebrow
    return self
      .font(resolvedFont)
      .tracking(tracking)
      .textCase(.uppercase)
      .foregroundStyle(color)
  }
}

struct GainsAppBackground: View {
  // A17 (Liquid): Schicht-Background mit impliziter Lichtquelle.
  // 2026-05-29 (Light-Mode-Pass): zwei eigenständige Kompositionen statt
  // nur Farbtoken-Swap — der Light-Mode bekommt eine sanfte Cream-Bühne
  // mit warmem Lichtfeld oben, der Dark-Mode behält die HUD-Vignette.

  @Environment(\.colorScheme) private var colorScheme

  // 2026-05-29 Crash-Fix Round 3: AnyView statt _ConditionalContent.
  // Der reguläre if/else mit zwei `some View`-Bodies erzeugt
  // `_ConditionalContent<LightBody, DarkBody>` — beide Children sind
  // gigantische ZStack<TupleView<…>>-Typen. Dieser Conditional-Wrapper
  // wird in jedem Screen mitgeschleppt, der GainsAppBackground() nutzt
  // (12 Screens), und treibt die Type-Kette des umgebenden Bodies hoch.
  // AnyView löscht die statischen Children-Typen → der Wrapper kollabiert
  // zur kompakten Konstante. Runtime-Cost: eine Indirektion, vernachlässigbar.
  var body: some View {
    if colorScheme == .light {
      AnyView(lightBody)
    } else {
      AnyView(darkBody)
    }
  }

  // MARK: - Light-Mode-Bühne (v3 — cool-neutral)
  //
  // 2026-05-29 (Light-Mode-Pass v3): Hintergrund-Farbtemperatur korrigiert.
  //
  // Problem v2: warmer Glow rgb(1.0, 0.96, 0.86) bei 0.55 Opacity = gelb-
  // crème. Die Cards sind cool-blau (#ECEFF5). Warmer Hintergrund + kühle
  // Cards = Farbtemperatur-Clash, App wirkte optisch unruhig.
  //
  // v3-Philosophie:
  // - Hintergrund ist cool-neutral (leicht blaustichig) statt warm-gelb —
  //   passt zur Glass-Card-Undertone-Familie (#ECEFF5).
  // - Glow-Intensität von 0.55 auf 0.28 — sichtbar ohne zu dominieren.
  // - Lime-Pool bleibt, aber 0.18 → 0.12 (Brand-Hauch, kein Farbfeld).
  // - Sage-Pool bleibt als kühler Anker.
  private var lightBody: some View {
    ZStack {
      // 1) Reinweißer Grund
      Color.white
        .ignoresSafeArea()

      // 2) Cool-neutraler Lichtkegel oben-mitte.
      //    Leicht blaustichiges Weiß — selbe Temperaturfamilie wie #ECEFF5.
      //    Gibt dem Screen Tiefe ohne Farbkonflikt mit den Glass-Cards.
      RadialGradient(
        colors: [
          Color(red: 0.92, green: 0.95, blue: 1.00).opacity(0.28),
          Color(red: 0.92, green: 0.95, blue: 1.00).opacity(0.08),
          Color.clear
        ],
        center: .init(x: 0.5, y: -0.10),
        startRadius: 8,
        endRadius: 720
      )
      .ignoresSafeArea()

      // 3) Lime-Pool oben-rechts — Brand-Hauch, nicht Farbfeld.
      RadialGradient(
        colors: [
          GainsColor.lime.opacity(0.12),
          GainsColor.lime.opacity(0.03),
          GainsColor.lime.opacity(0.0)
        ],
        center: .init(x: 0.88, y: 0.05),
        startRadius: 4,
        endRadius: 460
      )
      .ignoresSafeArea()

      // 4) Sage-Pool unten-links als kühler Anker.
      RadialGradient(
        colors: [
          GainsColor.accentCool.opacity(0.10),
          GainsColor.accentCool.opacity(0.02),
          GainsColor.accentCool.opacity(0.0)
        ],
        center: .init(x: 0.10, y: 0.94),
        startRadius: 4,
        endRadius: 520
      )
      .ignoresSafeArea()
    }
    .drawingGroup()
    .allowsHitTesting(false)
    .ignoresSafeArea()
  }

  // MARK: - Dark-Mode-Bühne (Original A17)
  //
  // Unverändert übernommen aus dem alten body() — die Komposition ist
  // präzise auf True-Black abgestimmt und hat sich bewährt.
  private var darkBody: some View {
    // 2026-05-14 (Polish-Loop 23): GeometryReader als root entfernt.
    // SwiftUI's GeometryReader hat eine bekannte Eigenheit — er sized
    // sich selbst nach unten/rechts auf maximum, propagiert die Größe
    // aber nicht sauber an Parents zurück. In einem ZStack mit einer
    // ScrollView nebendran führt das während Scroll zu winzigen
    // Layout-Reflows („Elemente verschieben sich komisch", User-
    // Bugreport 2026-05-14). Statt Geo benutzen wir feste Sizing-
    // Werte für die Radial-Gradienten — die exakte Größe macht
    // optisch keinen Unterschied, weil die Gradienten weit über den
    // sichtbaren Bereich hinausreichen sollen.
    // drawingGroup: alle 5 Gradient-Layer + HUDGrid werden einmal zu einer
    // GPU-Textur gebacken. `.plusLighter`-BlendModes erzwingen sonst einen
    // Off-Screen-Pass pro Layer bei jedem Redraw (z.B. während Scroll).
    // Da der Hintergrund statisch ist, amortisiert sich das Rasterisieren
    // sofort: ein einziger Blit beim Compositing statt 5 BlendMode-Passes.
    ZStack {
        // 2026-05-14 (Polish-Loop 5): App-Background neu kalibriert für
        // true-black-Basis.
        //
        // - Basis ist jetzt true black; minimaler Lift am oberen Rand
        //   liefert die „Bühne" ohne den alten kühlen Cast (RGB 0.014
        //   blau-anthrazit war neben unseren neuen #1C1C1C-Surfaces leicht
        //   inkonsistent — sah aus wie zwei Schwarz-Varianten).
        // - Light-Source-Hue gleich; Intensität +50%, damit sie auf
        //   #000000 sichtbar bleibt.
        // - Lime-Glow auf 0.10 hoch; Center leicht nach rechts oben,
        //   damit Coach-Brief (oben-links) nicht in eine Quelle läuft,
        //   die genauso aussieht wie sein eigener Hero-Glow.
        // - Cyan-Pool bleibt — gibt der App ihre einzige kühle Dimension.

        // 1) Basis: true black mit leichtem Top-Lift
        LinearGradient(
          colors: [
            Color(red: 0.024, green: 0.024, blue: 0.024),
            Color(red: 0.000, green: 0.000, blue: 0.000)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .ignoresSafeArea()

        // 2) Implizite Lichtquelle oben-mitte (warmes Weiß).
        //    Fester Radius statt proxy.size.height — siehe Polish-Loop 23.
        RadialGradient(
          colors: [
            Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.105),
            Color(red: 1.0, green: 0.96, blue: 0.88).opacity(0.025),
            Color.clear
          ],
          center: .init(x: 0.5, y: -0.05),
          startRadius: 4,
          endRadius: 560
        )
        .blendMode(.plusLighter)
        .ignoresSafeArea()

        // 3) Lime-Glow oben-trailing — schiebt die App-Identität an
        //    eine andere Stelle als der Coach-Brief (oben-leading).
        RadialGradient(
          colors: [
            GainsColor.signal.opacity(0.10),
            GainsColor.signal.opacity(0.0)
          ],
          center: .init(x: 0.82, y: 0.10),
          startRadius: 4,
          endRadius: 520
        )
        .blendMode(.plusLighter)
        .ignoresSafeArea()

        // 4) Cyan-Pool unten-leading — kühler Gegenpol, gibt Tiefe.
        RadialGradient(
          colors: [
            GainsColor.accentCool.opacity(0.055),
            GainsColor.accentCool.opacity(0.0)
          ],
          center: .init(x: 0.15, y: 0.92),
          startRadius: 4,
          endRadius: 560
        )
        .blendMode(.plusLighter)
        .ignoresSafeArea()

        // 2026-05-14 (Polish-Loop 21): HUDGrid weiter zurück auf 0.09.
        // Neben den neuen App-weiten Glows wirken die Hairline-Cells
        // sonst wie ein Konkurrenz-Pattern — jetzt sind sie nur noch
        // ein impliziter Anker, kein sichtbares Muster.
        HUDGrid()
          .opacity(0.09)
          .ignoresSafeArea()

        // 6) Vignette außen — fester Radius statt proxy.size.
        RadialGradient(
          colors: [
            Color.black.opacity(0.0),
            Color.black.opacity(0.42)
          ],
          center: .center,
          startRadius: 260,
          endRadius: 820
        )
        .blendMode(.multiply)
        .ignoresSafeArea()
    }
    .drawingGroup()
    .allowsHitTesting(false)
    .ignoresSafeArea()
  }
}

/// Sehr feines vertikales Grid-Pattern — wird hinter den App-Inhalten als
/// HUD-Layer eingeblendet. Die Linien sind absichtlich nahe der Sichtbarkeits-
/// schwelle, damit sie Tiefe vermitteln statt zu lärmen.
///
/// 2026-05-29 (Light-Mode-Pass): `lineColor` parametrisiert, damit der
/// Light-Mode-Background dunkle Hairlines auf Cream rendern kann.
private struct HUDGrid: View {
  var spacing: CGFloat = 28
  var lineColor: Color = Color.white.opacity(0.025)

  var body: some View {
    GeometryReader { proxy in
      Canvas { context, size in
        let columns = Int(size.width / spacing) + 2
        for column in 0..<columns {
          let x = CGFloat(column) * spacing
          var path = Path()
          path.move(to: CGPoint(x: x, y: 0))
          path.addLine(to: CGPoint(x: x, y: size.height))
          context.stroke(
            path,
            with: .color(lineColor),
            lineWidth: 0.5
          )
        }
        let rows = Int(size.height / spacing) + 2
        for row in 0..<rows {
          let y = CGFloat(row) * spacing
          var path = Path()
          path.move(to: CGPoint(x: 0, y: y))
          path.addLine(to: CGPoint(x: size.width, y: y))
          context.stroke(
            path,
            with: .color(lineColor.opacity(0.7)),
            lineWidth: 0.5
          )
        }
      }
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }
}

// MARK: - EmptyStateView
//
// Einheitlicher Baustein für leere Listen, Historien und Surfaces.
// Ersetzt die Ad-hoc-Pattern in HomeView, GymView, WorkoutHubView,
// ProgressView, RecipesView und NutritionTrackerView.
//
// Drei Varianten:
//   - `inline`     — kompakte Card (Standard, für kleine Sektionen)
//   - `prominent`  — großer zentraler Empty-State mit Icon-Kreis
//   - `card(icon:)` — Card mit kleinem Icon links, kompakt

struct EmptyStateView: View {
  enum Style {
    case inline
    case prominent
    case card(icon: String?)
  }

  let style: Style
  let title: String
  let message: String
  let icon: String?
  let actionLabel: String?
  let action: (() -> Void)?

  init(
    style: Style = .inline,
    title: String,
    message: String,
    icon: String? = nil,
    actionLabel: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.style = style
    self.title = title
    self.message = message
    self.icon = icon
    self.actionLabel = actionLabel
    self.action = action
  }

  var body: some View {
    switch style {
    case .inline:    inlineLayout
    case .prominent: prominentLayout
    case .card(let cardIcon): cardLayout(cardIcon ?? icon)
    }
  }

  // A8: Empty-States bekommen das gleiche HUD-Vokabular wie die Cards —
  // Hairline-Border-Gradient, Lime-Halo hinter dem Icon, monospaced Eyebrow
  // im Action-Button. Die Icon-Kreise lesen sich dadurch wie HUD-Marker
  // statt wie generische Tinten-Badges.

  private var inlineLayout: some View {
    // Spacing 10 → 12: schafft etwas mehr Atem zwischen Icon, Titel und Body.
    VStack(alignment: .leading, spacing: 12) {
      if let icon {
        haloIcon(icon, size: 36, iconSize: 18)
      }
      Text(title)
        .gainsHeadline()
      Text(message)
        .gainsBody(secondary: true)
        .fixedSize(horizontal: false, vertical: true)
      if let actionLabel, let action {
        actionButton(actionLabel, action: action)
          .padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(GainsSpacing.m)
    // 2026-05-31 (Glass-Sharpen-Pass): flacher card-Background + Hairline +
    // Shadow → zentrale Glas-Surface. Empty-States sitzen jetzt im selben
    // Glas wie die übrigen Cards (Material + Specular + 3-Stufen-Edge).
    .gainsGlassSurface(corner: GainsRadius.standard, depth: .card)
  }

  private var prominentLayout: some View {
    // Spacing 14 → 16: prominent Empty-State soll luftiger wirken.
    VStack(spacing: 16) {
      if let icon {
        haloIcon(icon, size: 64, iconSize: 28, glow: true)
      }
      // Title→Message-Spacing 6 → 8: bessere Trennung der Hierarchie.
      VStack(spacing: 8) {
        Text(title)
          .gainsTitle()
          .multilineTextAlignment(.center)
        Text(message)
          .gainsBody(secondary: true)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 12)
      if let actionLabel, let action {
        actionButton(actionLabel, action: action)
          .padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
    .padding(.horizontal, GainsSpacing.l)
    // 2026-05-31 (Glass-Sharpen-Pass): zentrale Hero-Glas-Surface statt
    // flachem card-Background.
    .gainsGlassSurface(corner: GainsRadius.hero, material: .thick, depth: .hero)
  }

  private func cardLayout(_ resolvedIcon: String?) -> some View {
    HStack(alignment: .top, spacing: 14) {
      if let resolvedIcon {
        haloIcon(resolvedIcon, size: 40, iconSize: 16)
      }
      // Spacing 6 → 8: konsistent zur prominentLayout-Hierarchie.
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .gainsHeadline()
        Text(message)
          .gainsBody(secondary: true)
          .fixedSize(horizontal: false, vertical: true)
        if let actionLabel, let action {
          actionButton(actionLabel, action: action)
            .padding(.top, 4)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    // 2026-05-31 (Glass-Sharpen-Pass): kompakte Glas-Surface statt flachem
    // card-Background.
    .gainsGlassSurface(corner: GainsRadius.small, material: .thin, depth: .rest)
  }

  /// HUD-Icon-Halo: gefüllter Kern, dünner Lime-Ring, optionaler weicher Glow.
  /// 2026-05-14 (Design-Loop 10): Dual-Layer-Halo (Material + Gradient) +
  /// dezenter Pulse für die `glow`-Variante. Empty-States wirken jetzt
  /// nicht „leer und kalt", sondern lebendig — als ob die App bereit
  /// wäre, gleich Inhalt zu zeigen.
  private func haloIcon(_ name: String, size: CGFloat, iconSize: CGFloat, glow: Bool = false)
    -> some View
  {
    // 2026-05-29 (Glass-Redesign): Aura + Lime-Glow-Schatten entfernt.
    // Das Icon sitzt jetzt in einem ruhigen Glas-Chip mit feinem Lime-Ring —
    // Lime nur als Akzent an Ring + Symbol, kein Leuchten.
    ZStack {
      Circle().fill(.ultraThinMaterial)
      Circle().fill(GainsColor.lime.opacity(0.10))
      Circle()
        .strokeBorder(GainsColor.lime.opacity(0.35), lineWidth: GainsBorder.hairline)
      Image(systemName: name)
        .font(.system(size: iconSize, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
    }
    .frame(width: size, height: size)
  }

  private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
    // 2026-05-29 (Glass-Redesign): gefüllte Lime-Capsule → Glas/Outline.
    // Lime lebt nur noch in Text, Icon und einer feinen Hairline — kein
    // Fill, kein Glow. `moss` (dunkleres Grün) hält den Text auf hellem
    // Glas gut lesbar.
    Button(action: action) {
      HStack(spacing: GainsSpacing.xs) {
        Text(label)
          .gainsEyebrow(GainsColor.moss, tracking: GainsTracking.eyebrowWide)
        Image(systemName: "arrow.right")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(GainsColor.moss)
      }
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 38)
      .background(.ultraThinMaterial, in: Capsule())
      .overlay(
        Capsule().strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.accent)
      )
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - GainsMetricTile
//
// Einheitliche Kennzahlen-Kachel — ersetzt die fünf Ad-hoc-Implementierungen
// (`evidenceTile`, `cockpitTile`, `summaryMetricTile`, `statsTile`,
// `planMetricCell`), die historisch in GymView/HomeView entstanden sind.
//
// Varianten:
//   - `.card`     — Standard auf hellem Card-Hintergrund.
//   - `.subdued`  — auf einem Background-Tone (z.B. innerhalb einer Card).
//   - `.onDark`   — für Hero-/CTA-Surfaces mit dunklem Hintergrund.
//   - `.onyx`     — bewusster dunkler Kennzahlen-Anker (Onyx-HUD) im sonst
//                   hellen Light-Mode-UI. Eigener Onyx-Background + Brand-Halo +
//                   helle Hairline. App-Regel: helles Glas = Inhalt, Onyx = KPIs.

struct GainsMetricTile: View {
  enum Style {
    case card
    case subdued
    case onDark
    case onyx
  }

  let label: String
  let value: String
  let unit: String
  let style: Style

  init(label: String, value: String, unit: String, style: Style = .card) {
    self.label = label
    self.value = value
    self.unit = unit
    self.style = style
  }

  var body: some View {
    // Vertikales Spacing 4 → 6: Label/Value/Unit lesen sich als drei klare
    // Stufen, nicht mehr als ein gedrungener Block.
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .gainsEyebrow(labelColor, tracking: GainsTracking.eyebrowWide)
      // A8: Werte sind monospaced — KPIs lesen sich dadurch wie HUD-Anzeigen
      // statt wie Fließtext und Zahlen springen beim Live-Update nicht mehr
      // in der Breite.
      Text(value)
        .gainsMetric(valueColor, size: .standard)
      Text(unit)
        .gainsCaption(unitColor)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(GainsSpacing.s)
    .background(
      // 2026-05-14 (Polish-Loop 70): Tile-Background mit dezentem
      // Inner-Light-Sweep — passt ins Glow-Vokabular der App.
      // 2026-05-31 (Glass-Sharpen-Pass): zusätzlich der enge Specular-
      // Hotspot — Tiles tragen jetzt denselben Light-Catch wie die Cards
      // und lesen sich als aus demselben Glas geschnitten.
      ZStack {
        background
        if style == .card || style == .subdued {
          LinearGradient(
            colors: [GainsColor.glassInnerLight, Color.clear],
            startPoint: .topLeading,
            endPoint: .center
          )
          RadialGradient(
            colors: [GainsColor.glassSpecular, Color.clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 90
          )
        } else if style == .onyx {
          // Onyx-HUD: dezenter Top-Sheen + Brand-Halo oben-leading, damit das
          // Kennzahlen-Feld wie ein beleuchtetes Cockpit-Display liest —
          // dasselbe Vokabular wie der Pulse-Strip auf Home.
          LinearGradient(
            colors: [Color.white.opacity(0.06), Color.clear],
            startPoint: .top,
            endPoint: .center
          )
          RadialGradient(
            colors: [GainsColor.signal.opacity(0.14), Color.clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 150
          )
        }
      }
    )
    .overlay(
      // 2026-05-31 (Glass-Sharpen-Pass): gerichtete Rim-Kante (oben heller →
      // unten gedimmt) statt flacher Border — konsistent mit der Glas-Edge
      // der Cards, ohne den Kontrast dichter KPI-Grids anzutasten. Auf Onyx
      // liefert `borderColor` eine weiße Bruchkante statt der Cool-Gray-Border.
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [
              borderColor.opacity(borderOpacity),
              borderColor.opacity(borderOpacity * 0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    .compositingGroup()
  }

  private var labelColor: Color {
    switch style {
    case .card, .subdued: return GainsColor.softInk
    case .onDark:         return GainsColor.onCtaSurface.opacity(0.55)
    case .onyx:           return GainsColor.onCtaSurfaceMuted
    }
  }
  private var valueColor: Color {
    switch style {
    case .card, .subdued: return GainsColor.ink
    case .onDark:         return GainsColor.card
    case .onyx:           return GainsColor.onCtaSurface
    }
  }
  private var unitColor: Color {
    switch style {
    case .card, .subdued: return GainsColor.softInk
    case .onDark:         return GainsColor.card.opacity(0.7)
    case .onyx:           return GainsColor.onCtaSurfaceSecondary
    }
  }
  private var background: Color {
    switch style {
    case .card:    return GainsColor.card
    case .subdued: return GainsColor.surfaceDeep.opacity(0.7)
    case .onDark:  return Color.white.opacity(0.04)
    case .onyx:    return GainsColor.onyxAccent
    }
  }
  private var borderColor: Color {
    switch style {
    case .card, .subdued, .onDark: return GainsColor.border
    case .onyx:                    return .white
    }
  }
  private var borderOpacity: Double {
    switch style {
    case .card:    return 0.85
    case .subdued: return 0.55
    case .onDark:  return 0.25
    case .onyx:    return 0.14
    }
  }
}

struct GainsDisclosureIndicator: View {
  let accent: Color

  init(accent: Color = GainsColor.lime) {
    self.accent = accent
  }

  var body: some View {
    Image(systemName: "chevron.right")
      .font(.system(size: 11, weight: .bold))
      .foregroundStyle(accent)
      .frame(width: 28, height: 28)
      .background(
        Circle()
          .fill(accent.opacity(0.10))
      )
      .overlay(
        Circle()
          .strokeBorder(accent.opacity(0.45), lineWidth: 0.6)
      )
  }
}

// 2026-05-14 (Brand-Loop 2): Lowercase „gains." Wordmark.
//
// Master Design Prompt:
//   • lowercase `gains.` mit Period in Signal Green
//   • Inter Variable / weight 700 — auf iOS nutzen wir SF Pro `.heavy`
//     als nächstes Pendant
//   • tracking −0.04em (umgerechnet in Punkte am Aufrufer)
//
// `foreground` und `period` sind seit 2026-05-14 parametrisierbar
// (Default: ink / lime), damit die Mark auch z. B. dunkel auf einem
// Light-Background eingesetzt werden kann.
struct GainsWordmark: View {
  let size: CGFloat
  let foreground: Color
  let period: Color

  init(
    size: CGFloat = 24,
    foreground: Color = GainsColor.ink,
    period: Color = GainsColor.lime
  ) {
    self.size = size
    self.foreground = foreground
    self.period = period
  }

  var body: some View {
    // Heavy-Weight rückgängig (User-Direktive 2026-05-14) — zurück auf
    // .semibold mit tightem Tracking. Der Punkt behält seinen weichen
    // Lime-Glow als einzigen Akzent.
    HStack(spacing: 0) {
      Text("gains")
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(foreground)
        .tracking(size <= 20 ? -0.4 : -0.8)

      Text(".")
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(period)
        .tracking(size <= 20 ? -0.4 : -0.8)
        .shadow(color: period.opacity(0.15), radius: size * 0.10, x: 0, y: 0)
    }
    .accessibilityLabel("gains")
  }
}

struct GainsStackedLogo: View {
  let size: CGFloat

  init(size: CGFloat = 44) {
    self.size = size
  }

  var body: some View {
    VStack(spacing: 8) {
      ZStack {
        // Innere CTA-Surface, leicht erhöht
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
          .fill(GainsColor.ctaSurface)
          .frame(width: size, height: size)

        // Hairline-Border-Gradient als Dose-Outline
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [
                GainsColor.lime.opacity(0.6),
                GainsColor.lime.opacity(0.05)
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: max(0.6, size * 0.02)
          )
          .frame(width: size, height: size)

        // Statischer Stroke-Track
        Circle()
          .stroke(GainsColor.border, lineWidth: size * 0.04)
          .frame(width: size * 0.7, height: size * 0.7)

        // Lime-Progress-Bogen mit Glow
        Circle()
          .trim(from: 0.04, to: 0.62)
          .stroke(
            GainsColor.lime,
            style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round)
          )
          .frame(width: size * 0.7, height: size * 0.7)
          .rotationEffect(.degrees(-38))
          .shadow(color: GainsColor.lime.opacity(0.275), radius: size * 0.18, x: 0, y: 0)

        Text("G")
          .font(.system(size: size * 0.38, weight: .semibold))
          .foregroundStyle(GainsColor.ink)
      }

      GainsWordmark(size: size * 0.24)
    }
  }
}

// MARK: - PulsingDot
//
// A8: Animierter Lime-Punkt — visuelles Live-Signal.
// Zwei konzentrische Kreise, der äußere skaliert/fadet im 1.6s-Zyklus,
// der innere bleibt stabil. Wird genutzt für „WORKOUT LÄUFT", LIVE-Badges,
// laufende Captures und allgemeine Activity-Indikatoren.

struct PulsingDot: View {
  let color: Color
  let coreSize: CGFloat
  let haloSize: CGFloat

  init(
    color: Color = GainsColor.lime,
    coreSize: CGFloat = 7,
    haloSize: CGFloat = 18
  ) {
    self.color = color
    self.coreSize = coreSize
    self.haloSize = haloSize
  }

  @State private var animating = false

  // 2026-05-14 (Polish-Loop 6): Zwei-Halo-Pulse statt eines einzelnen
  // Rings. Der innere Halo öffnet sich schneller (1.4s) und dimmt
  // direkt, der äußere langsamer (2.2s) — die Schichten überlappen sich
  // und der Dot wirkt „eingebettet in Licht" statt nur „mit einem Echo".
  @State private var coreBreath = false

  var body: some View {
    ZStack {
      // Äußerer Halo — langsamer, weiter
      Circle()
        .fill(color.opacity(0.22))
        .frame(width: haloSize, height: haloSize)
        .scaleEffect(animating ? 1.1 : 0.5)
        .opacity(animating ? 0.0 : 0.85)
      // Innerer Halo — schneller, enger
      Circle()
        .fill(color.opacity(0.40))
        .frame(width: haloSize * 0.7, height: haloSize * 0.7)
        .scaleEffect(animating ? 1.0 : 0.55)
        .opacity(animating ? 0.0 : 0.95)
      // Core mit sanfter Eigen-Atmung (verändert nur die Glow-Intensität,
      // nicht die Sichtbarkeit — der Dot bleibt immer da)
      Circle()
        .fill(color)
        .frame(width: coreSize, height: coreSize)
        .shadow(color: color.opacity(coreBreath ? 0.85 : 0.55), radius: coreBreath ? 6 : 4)
    }
    .frame(width: haloSize, height: haloSize)
    // drawingGroup: rasterisiert alle drei Kreise zu einer GPU-Textur.
    // Continuous-Animations (scaleEffect / opacity / shadow) werden damit
    // als GPU-Compositing statt als SwiftUI-Neuzeichnen ausgeführt.
    // Besonders effektiv, weil PulsingDot bis zu 6× gleichzeitig läuft.
    .drawingGroup()
    .onAppear {
      withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
        animating = true
      }
      withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
        coreBreath = true
      }
    }
  }
}

// MARK: - GainsKPIStrip
//
// A8: Horizontale HUD-Statuszeile — kompaktes Trio aus Mono-Werten mit
// Hairline-Separatoren. Eingesetzt für die globalen Live-KPIs auf dem
// Home-Screen (Streak / Sessions / Volumen).

struct GainsKPIStripItem: Identifiable {
  let id = UUID()
  let label: String
  let value: String
  let icon: String?

  init(label: String, value: String, icon: String? = nil) {
    self.label = label
    self.value = value
    self.icon = icon
  }
}

struct GainsKPIStrip: View {
  let items: [GainsKPIStripItem]
  let accent: Color

  init(items: [GainsKPIStripItem], accent: Color = GainsColor.lime) {
    self.items = items
    self.accent = accent
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
        // Spacing 6 → 8: konsistent zur Eyebrow → Metric-Stufung in MetricTile.
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 5) {
            if let icon = item.icon {
              Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
            }
            Text(item.label)
              .gainsEyebrow(GainsColor.mutedInk)
          }
          Text(item.value)
            .gainsMetric(GainsColor.ink, size: .small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)

        if index < items.count - 1 {
          Rectangle()
            .fill(GainsColor.border.opacity(0.7))
            .frame(width: 0.6)
            .padding(.vertical, 10)
        }
      }
    }
    .background(
      // 2026-05-14 (Polish-Loop 37): KPI-Strip jetzt mit Glass-Layer
      // statt flacher Card-Opacity, plus winzigem Top-Light-Sweep.
      ZStack {
        GainsColor.card.opacity(0.5)
        // 2026-05-29 (Light-Mode-Pass v2 → Loop 2): adaptiv via `glassInnerLight`.
        // .plusLighter entfernt — glassInnerLight.light=0.18, auf ~white-Material
        // würde plusLighter (0.18 + ~0.95) = clipped white erzeugen. Normales
        // Alpha-Compositing reicht für den dezenten Top-Sheen.
        LinearGradient(
          colors: [GainsColor.glassInnerLight, .clear],
          startPoint: .topLeading,
          endPoint: .center
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [
              accent.opacity(0.28),
              GainsColor.border.opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .compositingGroup()
    .shadow(color: accent.opacity(0.06), radius: 10, x: 0, y: 0)
  }
}

// MARK: - GainsGlowChip
//
// A8: Pille mit dezentem Lime-Glow — für Status-Tags („GPS LIVE",
// „BLE VERBUNDEN", „PLAN AKTIV"). Mehr Akzent als ein normaler Capsule-Chip,
// weniger laut als ein voller Lime-Button.

struct GainsGlowChip: View {
  let label: String
  let icon: String?
  let accent: Color

  init(_ label: String, icon: String? = nil, accent: Color = GainsColor.lime) {
    self.label = label
    self.icon = icon
    self.accent = accent
  }

  var body: some View {
    // A13 (Cleaner-Pass): Border-Opacity 0.5 → 0.4, Glow 0.35 → 0.18, Radius
    // 10 → 8. Status-Chip bleibt erkennbar als „Live/Aktiv", konkurriert
    // aber nicht mehr mit Hero-Buttons um Aufmerksamkeit.
    HStack(spacing: GainsSpacing.xs) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 10, weight: .bold))
      }
      Text(label)
        .gainsEyebrow(accent)
    }
    .foregroundStyle(accent)
    .padding(.horizontal, GainsSpacing.s)
    .frame(height: 26)
    .background(
      // 2026-05-14 (Polish-Loop 38): GlowChip mit Glas + Radial-
      // Akzent — passt visuell zum Halo-Icon-System.
      ZStack {
        Capsule().fill(accent.opacity(0.10))
        Capsule()
          .fill(
            RadialGradient(
              colors: [accent.opacity(0.22), .clear],
              center: .leading,
              startRadius: 0,
              endRadius: 80
            )
          )
          .blendMode(.screen)
      }
    )
    .overlay(
      Capsule()
        .strokeBorder(
          LinearGradient(
            colors: [accent.opacity(0.65), accent.opacity(0.18)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.hairline
        )
    )
    .clipShape(Capsule())
    .compositingGroup()
    .shadow(color: accent.opacity(0.22), radius: 8, x: 0, y: 0)
  }
}

// MARK: - GainsHeroCard
//
// A8: Wiederverwendbarer Baustein für *große Kacheln* (Hero-Cards).
//
// Designstrategie für große Kacheln:
//
// 1. SURFACE — `ctaSurface` (eine Stufe heller als App-Background, deutlich
//    dunkler als normale Cards) macht die Hero-Card als „Bühne" lesbar.
//    Corner-Radius 24 (eine Stufe größer als die normale `gainsCardStyle`-Card),
//    damit Hero-Cards visuell als wichtigere Hierarchie-Stufe gelesen werden.
//
// 2. AKZENT — Top-Halo + Lime-Border-Gradient (oben hell, unten transparent).
//    Eine Hero-Card hat IMMER eine Lime-Markierung; sie ist die primäre
//    Aktion eines Tabs. Subtile, nicht-störende HUD-Optik.
//
// 3. INHALTS-ARCHITEKTUR — feste Vertikalfolge:
//      a) Eyebrow-Row (SlashLabel links, Status-Badge rechts)
//      b) Title (display) + optional Subtitle (body softInk)
//      c) Primary-CTA (Lime-Pill, full-width, 52pt — die EINE Hauptaktion)
//      d) Optional Metrik-Strip (3 Zellen, Mono-Numerik, Hairline-Divider)
//
// 4. FOREGROUND-PALETTE — auf der Hero-Surface gilt:
//      - Title:      `onCtaSurface` (= ink)
//      - Subtitle:   `onCtaSurfaceSecondary`
//      - Eyebrow:    Primary = lime, Secondary = `onCtaSurfaceMuted`
//      - Metric Lab: `onCtaSurfaceMuted`
//      - Metric Val: `onCtaSurface`
//
// 5. SUBLAYER — der Metrik-Strip sitzt auf einer dezenten weißen Tint-Fläche
//    (Color.white.opacity(0.04)) statt auf `card` — letzteres würde im neuen
//    Dark-Only-System mit dem Surface verschmelzen.
//
// Eingesetzt für: GymTodayTab, langfristig auch HomeView Today, RunHub Hero,
// Recipe-Featured-Card.

/// Eine Metrik-Zelle für die `GainsHeroCard.metrics`-Reihe.
struct GainsHeroMetric: Identifiable {
  let id = UUID()
  let label: String
  let value: String

  init(_ label: String, _ value: String) {
    self.label = label
    self.value = value
  }
}

/// Wiederverwendbarer Hero-Baustein. Alle Slots außer Title sind optional;
/// der CTA wird über einen Closure übergeben, damit die Hero-Card kein
/// Wissen über App-Routing braucht.
struct GainsHeroCard<TrailingBadge: View, Footer: View>: View {
  let eyebrow: [String]
  let title: String
  let subtitle: String?
  let primaryCtaTitle: String?
  let primaryCtaIcon: String?
  let primaryCtaAction: (() -> Void)?
  let metrics: [GainsHeroMetric]
  @ViewBuilder let trailingBadge: () -> TrailingBadge
  @ViewBuilder let footer: () -> Footer

  init(
    eyebrow: [String],
    title: String,
    subtitle: String? = nil,
    primaryCtaTitle: String? = nil,
    primaryCtaIcon: String? = "play.fill",
    primaryCtaAction: (() -> Void)? = nil,
    metrics: [GainsHeroMetric] = [],
    @ViewBuilder trailingBadge: @escaping () -> TrailingBadge = { EmptyView() },
    @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
  ) {
    self.eyebrow = eyebrow
    self.title = title
    self.subtitle = subtitle
    self.primaryCtaTitle = primaryCtaTitle
    self.primaryCtaIcon = primaryCtaIcon
    self.primaryCtaAction = primaryCtaAction
    self.metrics = metrics
    self.trailingBadge = trailingBadge
    self.footer = footer
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      // 1. Eyebrow-Row
      HStack(alignment: .center) {
        if !eyebrow.isEmpty {
          slashEyebrow
        }
        Spacer(minLength: 8)
        trailingBadge()
      }

      // 2. Title + Subtitle — Title→Subtitle-Spacing 6 → 8 für klarere Stufe.
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          // 2026-05-29 (A18): onCtaSurface → ink. Frosted-Glass ist adaptiv,
          // also adaptive Schrift (dunkel auf Hell / hell auf Dunkel).
          .font(GainsFont.display(28))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
          .minimumScaleFactor(0.78)

        if let subtitle, !subtitle.isEmpty {
          // Hero-Subtitle nutzt die kanonische Body-Rolle (15pt + lineSpacing 3).
          Text(subtitle)
            .gainsBody(GainsColor.softInk)
            .lineLimit(2)
        }
      }

      // 3. Primary CTA
      //
      // A10 (Hero-CTA-Polish): Vorher war der Start-Button eine flache
      // Lime-Pille mit Icon links und Chevron rechts. Im Lauf der App ist
      // genau diese Pille die *Hauptaktion* (Training starten / Lauf
      // starten), also bekommt sie jetzt ein eigenes, dynamischeres
      // Vokabular — Lime-Gradient, Icon-Plate, atmender Halo, Press-State.
      // Die Logik wandert in `HeroPrimaryCTAButton`, damit dieselbe Pille
      // auch von Live-Bannern angezogen werden kann.
      if let primaryCtaTitle, let primaryCtaAction {
        HeroPrimaryCTAButton(
          title: primaryCtaTitle,
          icon: primaryCtaIcon,
          action: primaryCtaAction
        )
      }

      // 4. Metrik-Strip (optional)
      if !metrics.isEmpty {
        metricsStrip
      }

      // 5. Footer-Slot
      footer()
    }
    .padding(GainsSpacing.l)
    // 2026-05-29 (A18 „Mehr Glas, freundlicher"): War eine immer-dunkle
    // Bühne (heroSurface/heroBorder/topHalo + gainsHeroShadow). Jetzt
    // adaptive Frosted-Glass via gainsHeroGlass — hell & milchig im
    // Light-Mode, dunkel im Dark-Mode, mit lebendigem Signal-Glow. Der
    // Helper kapselt Background + Edge + Akzent-Rahmen + Shadow.
    .gainsHeroGlass(accent: GainsColor.signal)
  }

  // MARK: - Bestandteile

  private var slashEyebrow: some View {
    HStack(spacing: 4) {
      ForEach(Array(eyebrow.enumerated()), id: \.offset) { index, part in
        Text(part)
          // 2026-05-29 (A18): Akzent-Eyebrow lime → moss (auf Hell lesbar;
          // lime/signal wäre auf hellem Frosted zu kontrastarm). Rest mutedInk.
          .gainsEyebrow(
            index == 0 ? GainsColor.moss : GainsColor.mutedInk
          )
        if index < eyebrow.count - 1 {
          Text("/")
            .gainsEyebrow(GainsColor.moss)
        }
      }
    }
  }

  private var metricsStrip: some View {
    HStack(spacing: 0) {
      ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
        // Spacing 5 → 7: schafft eine sichtbarere Stufe Label → Value.
        VStack(spacing: 7) {
          // 2026-05-31 (Onyx-Readout): Die Hero-Kennzahlen sitzen jetzt auf
          // einem dunklen Onyx-Ablesefeld — App-Regel „Onyx = Kennzahlen".
          // Hebt die Werte aus der hellen Hero-Card wie ein eingelassenes
          // Cockpit-Display, konsistent mit dem Pulse-Strip auf Home.
          Text(metric.label)
            .gainsEyebrow(GainsColor.onCtaSurfaceMuted)
          Text(metric.value)
            .gainsMetric(GainsColor.onCtaSurface, size: .small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)

        if index < metrics.count - 1 {
          Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 26)
        }
      }
    }
    .background(
      // Onyx-Ablesefeld: Onyx-Boden + dezenter Top-Sheen + Brand-Halo. Bewusst
      // OHNE Depth-Shadow — die Bande soll eingelassen wirken, nicht schweben.
      ZStack {
        GainsColor.onyxAccent
        LinearGradient(
          colors: [Color.white.opacity(0.05), Color.clear],
          startPoint: .top,
          endPoint: .center
        )
        RadialGradient(
          colors: [GainsColor.signal.opacity(0.12), Color.clear],
          center: .topLeading,
          startRadius: 0,
          endRadius: 180
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(Color.white.opacity(0.10), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  // 2026-05-29 (A18): heroSurface / heroBorder / topHalo entfernt — die
  // gesamte Oberfläche (Frosted-Glass + Edge + Akzent-Rahmen + Glow + Shadow)
  // liefert jetzt der zentrale `gainsHeroGlass(accent:)`-Helper.
}

// MARK: - HeroPrimaryCTAButton
//
// A10: Premium-Variante des Lime-Start-Buttons. Wird in `GainsHeroCard`
// für „Training starten" / „Lauf starten" verwendet, kann aber auch als
// eigenständiger CTA in Live-Bannern eingesetzt werden — daher `internal`.
//
// Designentscheidungen (kurz):
//   • Lime-Gradient (oben hell → unten satt-grün) statt Flat-Fill — der
//     Knopf wirkt geprägt statt aufgemalt.
//   • Onyx-Plate für das Icon links (44×44 mit Lime-Innenring) — macht
//     den Button zum Knopf, nicht zur „Zeile mit Symbol".
//   • Atmender Halo-Layer hinter der Pille (slow, subtil) signalisiert
//     „bereit zu starten" ohne Disco. Im Press-State zieht er sich
//     zusammen.
//   • Inner-Highlight am oberen Rand + Hairline-Stroke schaffen Tiefe.
//   • Pfeil rechts sitzt in einer eigenen, dunklen Capsule — wirkt wie
//     eine Forward-Affordance, nicht wie ein Listen-Disclosure.
struct HeroPrimaryCTAButton: View {
  let title: String
  let icon: String?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      buttonContent
    }
    .buttonStyle(HeroPrimaryCTAButtonStyle())
  }

  // 2026-05-29 (Glass-Redesign): Der große Lime-Fill-CTA wird zum ruhigen
  // Glas-Button. Kein gefüllter Lime-Gradient, kein atmender Halo, keine
  // Lime-Glow-Schatten mehr — stattdessen dieselbe Glas-Komposition wie die
  // Cards (Undertone + Material + Inner-Light + Glas-Edge) plus eine feine
  // Lime-Akzent-Hairline. Lime bleibt Signalfarbe an Icon, Rahmen und
  // Chevron — als Akzent, nicht als Fläche.
  private var buttonContent: some View {
    let shape = RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
    return HStack(spacing: GainsSpacing.s) {
      if let icon {
        ZStack {
          Circle().fill(GainsColor.lime.opacity(0.12))
          Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
        }
        .frame(width: 38, height: 38)
        .overlay(
          Circle().strokeBorder(GainsColor.lime.opacity(0.40), lineWidth: GainsBorder.hairline)
        )
      }
      Text(title)
        .gainsEyebrow(GainsColor.ink, size: 13, tracking: GainsTracking.eyebrowTight)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 32, height: 32)
        .background(Circle().fill(GainsColor.lime.opacity(0.10)))
    }
    .padding(.leading, GainsSpacing.xs)
    .padding(.trailing, GainsSpacing.s)
    .frame(height: 56)
    .frame(maxWidth: .infinity)
    .background {
      ZStack {
        shape.fill(GainsColor.glassUndertone)
        shape.fill(.regularMaterial)
        shape.fill(GainsColor.lime.opacity(0.06))
        shape.fill(
          LinearGradient(
            colors: [GainsColor.glassInnerLight, .clear],
            startPoint: .topLeading,
            endPoint: .center
          )
        )
      }
    }
    .overlay {
      // Glas-Edge-Highlight (Lichtbrechung oben hell → unten dunkel).
      shape.stroke(
        LinearGradient(
          colors: [GainsColor.glassEdgeTop, GainsColor.glassEdgeBottom],
          startPoint: .top,
          endPoint: .bottom
        ),
        lineWidth: 0.8
      )
    }
    .overlay {
      // Lime-Akzent-Hairline — markiert die Primär-Aktion ohne Fill/Glow.
      shape.strokeBorder(
        LinearGradient(
          colors: [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.14)],
          startPoint: .top,
          endPoint: .bottom
        ),
        lineWidth: GainsBorder.accent
      )
    }
    .clipShape(shape)
    .compositingGroup()
    .gainsDepthShadow(.card)
  }
}

/// Press-State für `HeroPrimaryCTAButton`. Skaliert leicht und drückt
/// den Halo zusammen — gibt dem Tap echtes haptisches Feedback.
///
/// A12 (Anti-Blend): Da der Ruhezustand jetzt deutlich gedimmt ist, wurde
/// der Press-Sprung minimal verstärkt (Scale 0.97 → 0.96, Brightness
/// -0.04 → -0.06), damit der Tap weiterhin spürbar quittiert wird.
private struct HeroPrimaryCTAButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
      .brightness(configuration.isPressed ? -0.06 : 0)
      .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
  }
}

/// Pill-Status-Badge für die Hero-Card (LIVE / PLAN / REST / FLEX).
/// Verwendet `onCtaSurface`-Tokens auf der dunklen Surface und ist visuell
/// abgestimmt auf den Lime-Akzent der Hero.
struct GainsHeroStatusBadge: View {
  enum Tone {
    case live
    case plan
    case rest
    case flex
  }

  let label: String
  let tone: Tone

  var body: some View {
    // Polish-Loop 171 (2026-05-14): GainsHeroStatusBadge mit plusLighter-
    // Inner-Light und Live-Pulse-Dot. War vorher flach mit einem 8pt-Glow
    // — jetzt mit Tiefe, sodass „LIVE" tatsächlich pulst.
    HStack(spacing: GainsSpacing.xxs) {
      if tone == .live {
        Circle()
          .fill(foreground)
          .frame(width: 5, height: 5)
          .shadow(color: foreground.opacity(0.55), radius: 2)
      }
      Text(label)
        .gainsEyebrow(foreground, tracking: GainsTracking.eyebrowWide)
    }
    .padding(.horizontal, GainsSpacing.s)
    .frame(height: 26)
    .background(
      ZStack {
        Capsule().fill(background)
        // 2026-05-29 (Loop 10): .plusLighter entfernt.
        // .live/.plan (Lime-Hintergrund): plusLighter auf Lime = zu helles
        //   Spitze — normale Compositing mit 0.22 reicht für den Capsule-Glanz.
        // .rest (border-grau): plusLighter auf hellem Grau = Blow-out → entfernt.
        // .flex (accentCool): low-opacity, kein Problem aber konsistent halten.
        Capsule()
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(tone == .live || tone == .plan ? 0.22 : 0.06),
                Color.white.opacity(0.00)
              ],
              startPoint: .top,
              endPoint: .center
            )
          )
      }
    )
    .overlay(
      Capsule().strokeBorder(borderColor, lineWidth: GainsBorder.hairline)
    )
    .clipShape(Capsule())
    .compositingGroup()
    .shadow(color: glowColor, radius: tone == .live ? 10 : (tone == .plan ? 4 : 0))
  }

  private var foreground: Color {
    switch tone {
    case .live, .plan: return GainsColor.onLime
    // 2026-05-29 (Loop 8 follow-up): onCtaSurfaceSecondary (#B0B4B9) war zu
    // wenig Kontrast auf dem neuen border.opacity(0.14)-Hintergrund im Light-
    // Mode. softInk (#5C6371 light / #A1A1A1 dark) besteht AA auf beiden Modi.
    case .rest:        return GainsColor.softInk
    case .flex:        return GainsColor.onCtaSurface
    }
  }
  private var background: Color {
    switch tone {
    case .live, .plan: return GainsColor.lime
    // 2026-05-29 (Loop 8): white.opacity(0.06) = unsichtbar auf light
    // surfaces. Adaptive Variante: border.opacity(0.14) = sichtbarer
    // Grau-Chip in Light-Mode, bleibt dezent in Dark-Mode.
    case .rest:        return GainsColor.border.opacity(0.14)
    case .flex:        return GainsColor.accentCool.opacity(0.18)
    }
  }
  private var borderColor: Color {
    switch tone {
    case .live, .plan: return GainsColor.lime.opacity(0.5)
    // white.opacity(0.18) = unsichtbar in Light-Mode. border.opacity(0.5)
    // ergibt einen sichtbaren Hairline-Chip-Rand in beiden Modi.
    case .rest:        return GainsColor.border.opacity(0.50)
    case .flex:        return GainsColor.accentCool.opacity(0.4)
    }
  }
  private var glowColor: Color {
    tone == .live ? GainsColor.lime.opacity(0.32) : .clear
  }
}

// MARK: - Shadow / Motion / Control-Tokens (A15 — Polish-Pass)
//
// Vor diesem Pass waren Shadow-Opacities (0.10/0.18/0.22/0.28/0.32/0.36/0.38/
// 0.40/0.45/0.55/0.6/0.7) und -Radien (4/6/8/10/12/14/16/18/22) freihand über
// die App verteilt. `GainsShadow` ist das Vokabular für Card-Tiefe; alle
// Cards/Hero-Surfaces sollten ausschließlich diese Presets benutzen.
//
// `GainsMotion` zentralisiert Animations-Werte; `GainsControl` deckt Button-
// und Touch-Target-Höhen ab (HIG-konform, 44pt-Min).

// 2026-05-29 (Light-Mode-Pass v3): GainsShadow auf adaptive Tokens umgestellt.
// Vorher: alle Shadows hardcoded black.opacity(0.38-0.40) — auf Weiß wirkten
// das Tintenkleckse. Jetzt: shadowCardKey/shadowHeroKey-Tokens, die im
// Light-Mode deutlich zurückgenommene Werte haben (0.10-0.16).
enum GainsShadow {
  /// Standard-Card-Shadow (gainsCardStyle).
  static func card<V: View>(_ view: V) -> some View {
    view
      .shadow(color: GainsColor.shadowCardAmbient, radius: 22, x: 0, y: 2)
      .shadow(color: GainsColor.shadowCardKey,     radius: 6,  x: 0, y: 4)
  }
  /// Lift-Shadow für interaktive Cards, die etwas mehr Tiefe brauchen.
  static func lift<V: View>(_ view: V) -> some View {
    view
      .shadow(color: GainsColor.shadowHeroAmbient, radius: 28, x: 0, y: 3)
      .shadow(color: GainsColor.shadowHeroKey,     radius: 8,  x: 0, y: 6)
  }
  /// Hero-Shadow für Spotlight-Cards (Coach-Brief, Tracker-Hero).
  static func hero<V: View>(_ view: V) -> some View {
    view
      .shadow(color: GainsColor.shadowHeroAmbient, radius: 30, x: 0, y: 4)
      .shadow(color: GainsColor.shadowHeroKey,     radius: 10, x: 0, y: 8)
  }
  /// Soft-Shadow für Empty-States, Pulse-Tiles, kleine Modale.
  static func soft<V: View>(_ view: V) -> some View {
    view.shadow(color: GainsColor.shadowRest, radius: 10, x: 0, y: 2)
  }
  /// Akzent-Glow (Lime/Cyan/Ember) — max-Opacity laut A13 = 0.20.
  static func accentGlow<V: View>(_ view: V, color: Color, radius: CGFloat = 10)
    -> some View
  {
    view.shadow(color: color.opacity(0.18), radius: radius, x: 0, y: 0)
  }
}

extension View {
  /// Card-Shadow-Modifier.
  func gainsCardShadow() -> some View {
    self
      .shadow(color: GainsColor.shadowCardAmbient, radius: 22, x: 0, y: 2)
      .shadow(color: GainsColor.shadowCardKey,     radius: 6,  x: 0, y: 4)
  }
  /// Lift-Shadow-Modifier — interaktive Cards.
  func gainsLiftShadow() -> some View {
    self
      .shadow(color: GainsColor.shadowHeroAmbient, radius: 28, x: 0, y: 3)
      .shadow(color: GainsColor.shadowHeroKey,     radius: 8,  x: 0, y: 6)
  }
  /// Hero-Shadow-Modifier — Spotlight-Cards.
  func gainsHeroShadow() -> some View {
    self
      .shadow(color: GainsColor.shadowHeroAmbient, radius: 30, x: 0, y: 4)
      .shadow(color: GainsColor.shadowHeroKey,     radius: 10, x: 0, y: 8)
  }
  /// Soft-Shadow-Modifier — leichte Surfaces.
  func gainsSoftShadow() -> some View {
    self.shadow(color: GainsColor.shadowRest, radius: 10, x: 0, y: 2)
  }
  /// Akzent-Glow — Lime/Cyan/Ember-Halo um eine Surface (max 0.20 Opacity).
  func gainsAccentGlow(_ color: Color, radius: CGFloat = 10) -> some View {
    self.shadow(color: color.opacity(0.18), radius: radius, x: 0, y: 0)
  }
}

enum GainsMotion {
  /// Schnelle UI-Reaktion (Tap-Feedback, Tile-Highlight): 0.18s
  static let quick: Double = 0.18
  /// Standard-Übergang (Card-Wechsel, Tab-Switch): 0.30s
  static let standard: Double = 0.30
  /// Langsamer Gestalt-Wechsel (Sheet-Push, Hero-Morph): 0.45s
  static let calm: Double = 0.45
  /// Spring-Default für interaktive Elemente (Tap-Down/Up).
  static let spring: Animation = .spring(response: 0.35, dampingFraction: 0.78)
  /// Sanfte Easing-Kurve für Layout-Übergänge.
  static let ease: Animation = .easeInOut(duration: standard)
}

enum GainsControl {
  /// 32 — sehr kleine inline Chips, Filter-Pillen.
  static let chipHeight: CGFloat = 32
  /// 38 — sekundäre Pill-Buttons (z.B. Empty-State-Action).
  static let pillHeight: CGFloat = 38
  /// 44 — HIG-Min Touch-Target. Default für jeden Tap-Bereich.
  static let touchMin: CGFloat = 44
  /// 52 — Primary-CTA in Sheets/Forms.
  static let ctaHeight: CGFloat = 52
  /// 60 — Hero-CTA (Tracker, Lauf-Start).
  static let heroCtaHeight: CGFloat = 60
}

// MARK: - GainsSectionHeader (A15)
//
// Einheitlicher Section-Header für alle Tabs/Sheets. Vor A15 hatten Gym-Tabs,
// Profile, Progress, NutritionTracker jeweils eigene Lösungen für „Eyebrow
// + Title + Action rechts". Dieser Baustein konsolidiert sie.

struct GainsSectionHeader<Trailing: View>: View {
  let eyebrow: String?
  let title: String
  let subtitle: String?
  let accent: Color
  let trailing: Trailing

  init(
    eyebrow: String? = nil,
    title: String,
    subtitle: String? = nil,
    accent: Color = GainsColor.lime,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) {
    self.eyebrow = eyebrow
    self.title = title
    self.subtitle = subtitle
    self.accent = accent
    self.trailing = trailing()
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: GainsSpacing.s) {
      // Design-Loop 5 (2026-05-14): Accent-Bar links neben dem Eyebrow
      // verleiht jeder Sektion einen kleinen visuellen Anker, ohne den
      // Header laut werden zu lassen. Bei `accent == .clear` wird die Bar
      // unsichtbar — Bestandscode bleibt also kompatibel.
      if accent != .clear {
        // 2026-05-14 (Polish-Loop 16): Accent-Bar bekommt jetzt einen
        // dezenten Halo-Glow, sodass der vertikale Strich nicht mehr
        // wie ein toter UI-Marker wirkt, sondern wie eine winzige
        // Lichtquelle, die mit der Section verschmilzt.
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
          .fill(
            LinearGradient(
              colors: [accent, accent.opacity(0.18)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 3, height: subtitle != nil ? 38 : 28)
          .padding(.top, eyebrow != nil ? 2 : 0)
          .shadow(color: accent.opacity(0.50), radius: 4, x: 0, y: 0)
      }

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        if let eyebrow {
          Text(eyebrow).gainsEyebrow(accent.opacity(0.85))
        }
        Text(title)
          .font(GainsFont.title)
          .foregroundStyle(GainsColor.ink)
        if let subtitle {
          Text(subtitle)
            .gainsCaption()
            .padding(.top, 2)
        }
      }
      Spacer(minLength: GainsSpacing.s)
      trailing
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - GainsListRow (A15)
//
// Standardisierte Listen-Zeile — Icon-Halo + Title + Subtitle + Trailing-Wert
// + optionaler Chevron. Ersetzt 30+ Varianten in Profile/Progress/Settings/
// Plan-Sheets.

// Press-State für ListRows: leichter Background-Wash bei Druck —
// weniger Scale als bei Buttons, weil Rows in eine Liste eingebettet sind
// und ein Scale die Nachbarn visuell drücken würde.
private struct GainsListRowPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        configuration.isPressed
          ? GainsColor.lime.opacity(0.06)
          : Color.clear
      )
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

struct GainsListRow<Trailing: View>: View {
  let icon: String?
  let iconColor: Color
  let title: String
  let subtitle: String?
  let trailing: Trailing
  let chevron: Bool
  let action: (() -> Void)?

  init(
    icon: String? = nil,
    iconColor: Color = GainsColor.lime,
    title: String,
    subtitle: String? = nil,
    chevron: Bool = false,
    action: (() -> Void)? = nil,
    @ViewBuilder trailing: () -> Trailing = { EmptyView() }
  ) {
    self.icon = icon
    self.iconColor = iconColor
    self.title = title
    self.subtitle = subtitle
    self.trailing = trailing()
    self.chevron = chevron
    self.action = action
  }

  var body: some View {
    Group {
      if let action {
        // Design-Loop 4 (2026-05-14): Press-State auch für ListRows,
        // damit Tap-Feedback zwischen Buttons und Rows konsistent ist.
        // Vorher `.buttonStyle(.plain)` → kein sichtbarer Druck-State.
        Button(action: action) { content }
          .buttonStyle(GainsListRowPressStyle())
      } else {
        content
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    HStack(spacing: GainsSpacing.s) {
      if let icon {
        // 2026-05-14 (Polish-Loop 9): Icon-Halo bekommt jetzt einen
        // echten radial Glow im Background statt nur eines diagonalen
        // Tints, plus einen schwachen Doppel-Shadow (sharp + soft).
        // Das Plättchen leuchtet jetzt aktiv, statt nur farbig zu wirken.
        let haloShape = RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        ZStack {
          haloShape.fill(iconColor.opacity(0.10))
          // 2026-05-29 (Loop 5): Akzent-Radial-Glow oben-leading.
          // .plusLighter entfernt — auf Light-Glass-Cards (regularMaterial +
          // #F2F5FC Tint) würde accent.0.32 via plusLighter zu einem harten
          // hellen Fleck clippen. .screen oder normales Compositing reichen.
          haloShape
            .fill(
              RadialGradient(
                colors: [iconColor.opacity(0.32), iconColor.opacity(0.0)],
                center: .topLeading,
                startRadius: 0,
                endRadius: 36
              )
            )
            .blendMode(.screen)
          haloShape
            .strokeBorder(
              LinearGradient(
                colors: [iconColor.opacity(0.60), iconColor.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: GainsBorder.hairline
            )
          Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(iconColor)
            .shadow(color: iconColor.opacity(0.45), radius: 4)
        }
        .frame(width: 36, height: 36)
        .shadow(color: iconColor.opacity(0.22), radius: 8, x: 0, y: 0)
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
        if let subtitle {
          Text(subtitle)
            .gainsCaption()
            .lineLimit(2)
        }
      }
      Spacer(minLength: GainsSpacing.xs)
      trailing
      if chevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(GainsColor.mutedInk)
      }
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
    .frame(minHeight: GainsControl.touchMin)
    .contentShape(Rectangle())
  }
}

// MARK: - GainsPrimaryButton & GainsSecondaryButton (A15)
//
// Konsistente CTA-Hierarchie. Vor A15 hatten Sheets/Forms eigene Button-
// Styles mit unterschiedlichen Heights/Radien/Akzenten.

// MARK: - GainsPressableButtonStyle (2026-05-14, Design-Loop 3)
//
// Spürbarer, aber dezenter Press-State für Primary/Secondary-Buttons.
// Vorher hingen alle ButtonViews an `.buttonStyle(.plain)`, was zwar die
// System-Press-Animation deaktiviert, dafür aber gar nichts zurückgibt.
// Das wirkte unbeweglich. Mit diesem Style spürt der User Druck:
//   • leichter Scale-In (0.97) — wie eine echte Taste
//   • leichter Brightness-Dimm
//   • Spring-Animation für die Rückkehr
private struct GainsPressableButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .brightness(configuration.isPressed ? -0.05 : 0)
      .animation(
        .interactiveSpring(response: 0.22, dampingFraction: 0.78, blendDuration: 0.18),
        value: configuration.isPressed
      )
  }
}

struct GainsPrimaryButton: View {
  enum Tone {
    case lime
    case cool
    case ember
    case neutral

    var background: Color {
      switch self {
      case .lime:    return GainsColor.lime
      case .cool:    return GainsColor.accentCool
      case .ember:   return GainsColor.ember
      case .neutral: return GainsColor.ctaRaised
      }
    }
    var foreground: Color {
      switch self {
      case .lime:    return GainsColor.onLime
      case .cool:    return GainsColor.onCtaSurface
      case .ember:   return GainsColor.onEmber
      case .neutral: return GainsColor.ink
      }
    }
    var glow: Color {
      switch self {
      case .lime:    return GainsColor.lime
      case .cool:    return GainsColor.accentCool
      case .ember:   return GainsColor.ember
      case .neutral: return .clear
      }
    }

    /// 2026-05-29 (Glass-Redesign): Akzentfarbe für Hairline + Icon des
    /// glasigen Primär-Buttons. Neutral nutzt den ruhigen Border-Token.
    var accentColor: Color {
      switch self {
      case .lime:    return GainsColor.lime
      case .cool:    return GainsColor.accentCool
      case .ember:   return GainsColor.ember
      case .neutral: return GainsColor.border
      }
    }
  }

  let title: String
  let icon: String?
  let tone: Tone
  let isEnabled: Bool
  let action: () -> Void

  init(
    _ title: String,
    icon: String? = nil,
    tone: Tone = .lime,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.icon = icon
    self.tone = tone
    self.isEnabled = isEnabled
    self.action = action
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
    let accent = tone.accentColor
    let iconColor: Color = tone == .neutral ? GainsColor.ink : accent
    return Button(action: action) {
      HStack(spacing: GainsSpacing.xs) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isEnabled ? iconColor : GainsColor.mutedInk)
        }
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .tracking(0.2)
          .foregroundStyle(isEnabled ? GainsColor.ink : GainsColor.mutedInk)
      }
      .frame(maxWidth: .infinity)
      .frame(height: GainsControl.ctaHeight)
      .background {
        // 2026-05-29 (Glass-Redesign): gefüllte Lime-Pille → Glas-Button.
        // Dieselbe Komposition wie die Cards; der Ton lebt nur noch in der
        // Akzent-Hairline + Icon, nicht als Fläche. Kein Glow mehr.
        ZStack {
          shape.fill(GainsColor.glassUndertone)
          shape.fill(.regularMaterial)
          if isEnabled && tone != .neutral {
            shape.fill(accent.opacity(0.07))
          }
          shape.fill(
            LinearGradient(
              colors: [GainsColor.glassInnerLight, .clear],
              startPoint: .topLeading,
              endPoint: .center
            )
          )
        }
      }
      .overlay {
        // Glas-Edge-Highlight.
        shape.stroke(
          LinearGradient(
            colors: [GainsColor.glassEdgeTop, GainsColor.glassEdgeBottom],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 0.8
        )
      }
      .overlay {
        // Akzent-Hairline statt Fill — die einzige Farbe am Button.
        shape.strokeBorder(
          LinearGradient(
            colors: [
              accent.opacity(isEnabled ? 0.55 : 0.18),
              accent.opacity(isEnabled ? 0.14 : 0.06)
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.accent
        )
      }
      .clipShape(shape)
      .compositingGroup()
      .gainsDepthShadow(.card)
    }
    .buttonStyle(GainsPressableButtonStyle())
    .disabled(!isEnabled)
  }
}

struct GainsSecondaryButton: View {
  let title: String
  let icon: String?
  let action: () -> Void

  init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
    self.title = title
    self.icon = icon
    self.action = action
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
    return Button(action: action) {
      HStack(spacing: GainsSpacing.xs) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
        }
        Text(title)
          .font(.system(size: 15, weight: .medium))
      }
      .foregroundStyle(GainsColor.ink)
      .frame(maxWidth: .infinity)
      .frame(height: GainsControl.touchMin)
      .background {
        ZStack {
          // A17 (Liquid): Sekundär-Button ist jetzt eine echte
          // Ultra-Thin-Material-Pille — schwebt frei statt flat.
          shape.fill(.ultraThinMaterial)
          // 2026-05-29 (Loop 3): .plusLighter entfernt. SecondaryButton sitzt
          // auf ultraThinMaterial (~weiß in Light-Mode) — plusLighter würde
          // white.0.18 + ~0.95 > 1.0 → geblowtes Eck.
          shape
            .fill(
              LinearGradient(
                colors: [GainsColor.glassInnerLight, .clear],
                startPoint: .topLeading,
                endPoint: .center
              )
            )
        }
      }
      .overlay {
        shape
          .stroke(
            LinearGradient(
              colors: [
                GainsColor.glassEdgeTop,
                GainsColor.glassEdgeBottom
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 0.8
          )
      }
      .clipShape(shape)
      .gainsDepthShadow(.rest)
    }
    .buttonStyle(GainsPressableButtonStyle())
  }
}

// MARK: - GainsLiveTile (A15)
//
// Live-Tracker-Tile (Workout/Run): kompakte Wert-Kachel mit Eyebrow, großem
// Mono-Wert, Detail-Caption und Akzent-Status. Ersetzt die freihändigen
// Pace/Distance/HF-Tiles in WorkoutTrackerView und RunTrackerView.

struct GainsLiveTile: View {
  let eyebrow: String
  let value: String
  let unit: String?
  let detail: String?
  let icon: String?
  let accent: Color
  let isPrimary: Bool

  init(
    eyebrow: String,
    value: String,
    unit: String? = nil,
    detail: String? = nil,
    icon: String? = nil,
    accent: Color = GainsColor.lime,
    isPrimary: Bool = false
  ) {
    self.eyebrow = eyebrow
    self.value = value
    self.unit = unit
    self.detail = detail
    self.icon = icon
    self.accent = accent
    self.isPrimary = isPrimary
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
    return VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      HStack(spacing: GainsSpacing.xxs) {
        if let icon {
          Image(systemName: icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(accent.opacity(0.92))
        }
        Text(eyebrow).gainsEyebrow(accent.opacity(0.92))
      }
      HStack(alignment: .lastTextBaseline, spacing: 4) {
        // A17 (Liquid): Wert in SF Pro Rounded für die Tracker-Numerik —
        // gibt großen Zahlen optischen Charakter, ohne unmonospaced
        // zu wirken (numericDigit hält die Spalten ruhig).
        Text(value)
          .font(.system(
            size: isPrimary ? 32 : 22,
            weight: .semibold,
            design: .rounded
          ))
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        if let unit {
          Text(unit)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(GainsColor.softInk)
            .padding(.bottom, 2)
        }
      }
      if let detail {
        Text(detail)
          .gainsCaption()
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(GainsSpacing.s)
    .background {
      // 2026-05-14 (Polish-Loop 7): Primary-LiveTile bekommt jetzt
      // einen echten Akzent-Radial-Glow im Background statt nur einer
      // flachen 8%-Tönung. Die Tile wirkt dadurch wie ein angeschlossenes
      // Live-Element, kein passives Display.
      ZStack {
        shape.fill(GainsColor.glassUndertone)
        shape.fill(.regularMaterial)
        if isPrimary {
          shape.fill(accent.opacity(0.06))
          RadialGradient(
            colors: [accent.opacity(0.18), .clear],
            center: .topLeading,
            startRadius: 0,
            endRadius: 140
          )
          .blendMode(.screen)
          .clipShape(shape)
        }
        // 2026-05-29 (Loop 4): .plusLighter entfernt. LiveTile liegt auf
        // regularMaterial (~weiß in Light-Mode) — plusLighter bläst das
        // Inner-Light-Eck aus. Normal compositing mit 0.18 reicht.
        shape
          .fill(
            LinearGradient(
              colors: [GainsColor.glassInnerLight, .clear],
              startPoint: .topLeading,
              endPoint: .center
            )
          )
      }
    }
    .overlay {
      shape
        .stroke(
          LinearGradient(
            colors: isPrimary
              ? [accent.opacity(0.60), accent.opacity(0.08)]
              : [GainsColor.glassEdgeTop, GainsColor.glassEdgeBottom],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: isPrimary ? GainsBorder.accent : 0.8
        )
    }
    .clipShape(shape)
    // Primary-Tiles haben jetzt zwei gestapelte Shadows: einen weichen
    // Akzent-Halo + einen Ambient-Schatten für räumliche Verankerung.
    .shadow(color: isPrimary ? accent.opacity(0.24) : .clear, radius: 18, x: 0, y: 0)
    .gainsDepthShadow(.card)
  }
}

// MARK: - GainsSegmentedPicker (A15)
//
// Token-konformer Segment-Switcher (z.B. Modality im Kardio-Tab, Tracker/
// Rezepte in Nutrition). Ersetzt die freihändigen HStack-Pill-Reihen.

struct GainsSegmentedPickerOption<Value: Hashable>: Identifiable {
  let id: Value
  let label: String
  let icon: String?
}

struct GainsSegmentedPicker<Value: Hashable>: View {
  @Binding var selection: Value
  let options: [GainsSegmentedPickerOption<Value>]
  let accent: Color

  init(
    selection: Binding<Value>,
    options: [GainsSegmentedPickerOption<Value>],
    accent: Color = GainsColor.lime
  ) {
    self._selection = selection
    self.options = options
    self.accent = accent
  }

  var body: some View {
    let outerShape = RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
    return HStack(spacing: GainsSpacing.xxs) {
      ForEach(options) { option in
        let isActive = option.id == selection
        Button {
          withAnimation(GainsMotion.spring) {
            selection = option.id
          }
        } label: {
          HStack(spacing: GainsSpacing.xxs) {
            if let icon = option.icon {
              Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            }
            Text(option.label)
              .font(.system(size: 13, weight: .semibold))
          }
          .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.softInk)
          .frame(maxWidth: .infinity)
          .frame(height: 36)
          .background {
            // 2026-05-14 (Polish-Loop 20): Aktive Pille — drei
            // gestapelte Effekte:
            //   1. Solid-Accent-Fill
            //   2. Inner-Light-Gradient oben (Glaswölbung)
            //   3. Inner-Shadow unten (gibt Tiefe nach innen)
            // + doppelter Outer-Shadow (Halo + Ambient) für das
            //   konsistente Glow-Vokabular.
            if isActive {
              ZStack {
                RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                  .fill(accent)
                RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                  .fill(
                    LinearGradient(
                      colors: [Color.white.opacity(0.28), Color.clear],
                      startPoint: .top,
                      endPoint: .center
                    )
                  )
                  .blendMode(.plusLighter)
                RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                  .fill(
                    LinearGradient(
                      colors: [Color.clear, Color.black.opacity(0.18)],
                      startPoint: .center,
                      endPoint: .bottom
                    )
                  )
              }
              .shadow(color: accent.opacity(0.40), radius: 12)
              .shadow(color: accent.opacity(0.18), radius: 24)
            }
          }
        }
        .buttonStyle(.plain)
      }
    }
    .padding(GainsSpacing.xxs)
    .background {
      ZStack {
        outerShape.fill(GainsColor.glassUndertone)
        outerShape.fill(.ultraThinMaterial)
      }
    }
    .overlay {
      outerShape
        .stroke(
          LinearGradient(
            colors: [
              GainsColor.glassEdgeTop,
              GainsColor.glassEdgeBottom
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 0.8
        )
    }
    .clipShape(outerShape)
    .gainsDepthShadow(.rest)
  }
}

// MARK: - GainsFormField (A15)
//
// Einheitliches Form-Field-Pattern für Settings/Onboarding/Plan-Builder.
// Eyebrow-Label oben, Control unten, optionaler Helper-Text.

struct GainsFormField<Control: View>: View {
  let label: String
  let helper: String?
  let control: Control

  init(
    label: String,
    helper: String? = nil,
    @ViewBuilder control: () -> Control
  ) {
    self.label = label
    self.helper = helper
    self.control = control()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      HStack(spacing: GainsSpacing.xxs) {
        // 2026-05-14 (Design-Loop 8): Mini-Lime-Dot vor dem Eyebrow
        // hebt Form-Felder als „bearbeitbar" hervor und erzeugt eine
        // konsistente Form-Sprache zwischen Onboarding/Plan/Settings.
        Circle()
          .fill(GainsColor.lime)
          .frame(width: 4, height: 4)
          .shadow(color: GainsColor.lime.opacity(0.25), radius: 3)
        Text(label).gainsEyebrow()
      }
      control
      if let helper {
        Text(helper).gainsCaption()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - GainsTextFieldStyle (2026-05-14, Design-Loop 8)
//
// Konsistenter Look für alle freistehenden TextFields. Statt überall
// händisch `.padding(...).background(...).overlay(...)` zu wiederholen,
// kann jedes TextField mit `.gainsTextFieldStyle()` veredelt werden:
//   • Ultra-Thin-Material-Background
//   • Hairline-Border mit Glas-Edge
//   • Focus-Ring in Lime, sobald das Feld fokussiert ist
//
// Verwendung: TextField("…", text: $x).gainsTextFieldStyle()
extension View {
  func gainsTextFieldStyle(isFocused: Bool = false) -> some View {
    let shape = RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
    return self
      .font(GainsFont.body)
      .foregroundStyle(GainsColor.ink)
      .padding(.horizontal, GainsSpacing.m)
      .padding(.vertical, GainsSpacing.s)
      .background(
        ZStack {
          shape.fill(GainsColor.glassUndertone)
          shape.fill(.ultraThinMaterial)
        }
      )
      .overlay(
        shape.stroke(
          isFocused ? GainsColor.lime.opacity(0.55) : GainsColor.border.opacity(0.6),
          lineWidth: isFocused ? 1.4 : 1
        )
      )
      .clipShape(shape)
      .shadow(
        color: isFocused ? GainsColor.lime.opacity(0.22) : .clear,
        radius: 10,
        x: 0,
        y: 0
      )
  }
}

// MARK: - GainsDivider (A15)
//
// Konsistenter Hairline-Divider in Cards/Listen.
struct GainsDivider: View {
  var indent: CGFloat = 0
  var body: some View {
    Rectangle()
      .fill(GainsColor.border.opacity(0.5))
      .frame(height: 0.6)
      .padding(.leading, indent)
  }
}

// MARK: - Card-Container (A15)
//
// Standard-Card-Wrapper mit Padding + Style + Shadow. Ersetzt das
// `.padding(16).background(...).clipShape(...)`-Boilerplate.

extension View {
  /// Standard-Card-Container: 16pt-Padding + gainsCardStyle().
  func gainsCard(_ background: Color = GainsColor.card) -> some View {
    self
      .padding(GainsSpacing.m)
      .gainsCardStyle(background)
  }
  /// Kompakte Card (A17 Liquid): 12pt-Padding + small Radius + Glass-Surface.
  func gainsCompactCard(_ background: Color = GainsColor.card) -> some View {
    return self
      .padding(GainsSpacing.s)
      .gainsGlassSurface(
        corner: GainsRadius.small,
        material: .thin,
        tint: background.opacity(0.35),
        depth: .rest
      )
  }
}
