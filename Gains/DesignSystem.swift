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
  // A8: Re-Design "Minimal Tech / HUD-Dark".
  // - App ist jetzt Dark-Only (siehe `GainsApp.preferredColorScheme(.dark)`),
  //   die `lightHex`-Werte spiegeln deshalb bewusst die Dark-Werte: falls
  //   das System doch mal Light forciert (z.B. UIKit-Hostings im Sheet),
  //   bricht die Optik nicht auseinander.
  // - Palette: tiefes, leicht kühles Anthrazit als Untergrund, Hairline-
  //   Borders, elektrisches Lime + Cyan-Akzent für Status/Glow.
  static let background = Color(lightHex: "060809", darkHex: "060809")
  static let card = Color(lightHex: "0E1217", darkHex: "0E1217")
  static let elevated = Color(lightHex: "151B22", darkHex: "151B22")
  static let ink = Color(lightHex: "E8F1F7", darkHex: "E8F1F7")
  static let softInk = Color(lightHex: "9BA8B4", darkHex: "9BA8B4")
  static let mutedInk = Color(lightHex: "6A7480", darkHex: "6A7480")
  // Hairline-Border: präzise, kühl, sehr zurückgenommen — Hierarchie kommt
  // jetzt vor allem aus Glow/Akzent statt aus dicken Outlines.
  static let border = Color(lightHex: "1F2730", darkHex: "1F2730")
  // Elektrisches Lime — etwas grüner und gesättigter als vorher.
  static let lime = Color(lightHex: "C7EA45", darkHex: "C7EA45")
  static let moss = Color(lightHex: "8AAA42", darkHex: "8AAA42")
  static let signalDeep = Color(lightHex: "9DBE4A", darkHex: "9DBE4A")
  static let onLime = Color(lightHex: "081005", darkHex: "081005")
  static let onLimeSecondary = Color(lightHex: "1A2208", darkHex: "1A2208")
  static let ember = Color(lightHex: "FF6A4A", darkHex: "FF6A4A")
  static let emberGlow = Color(lightHex: "FFB094", darkHex: "FFB094")
  static let onEmber = Color(lightHex: "190503", darkHex: "190503")
  static let onEmberSecondary = Color(lightHex: "3A1109", darkHex: "3A1109")
  // Eine Stufe tiefer als Background — für versenkte Surfaces (z.B. Track-
  // Hintergrund einer Progress-Bar, Card-Innenflächen).
  static let surfaceDeep = Color(lightHex: "030506", darkHex: "030506")

  /// Dunkle CTA-Fläche — wird für Icon-Kreise und Hero-Card-Hintergründe
  /// verwendet, die sich klar vom Card-Untergrund absetzen sollen.
  static let ctaSurface = Color(lightHex: "10161D", darkHex: "10161D")

  /// Leicht erhöhte Variante von ctaSurface — für Chips und Pills.
  static let ctaRaised = Color(lightHex: "1A2129", darkHex: "1A2129")

  // MARK: Foregrounds AUF dunklen CTA-Surfaces
  //
  // Wichtig: vor dem A8-Redesign hat Code historisch `GainsColor.card` als
  // *Foreground* auf einer CTA-Surface benutzt — im Light-Mode war card eine
  // cremefarbene Light-Color, im Dark-Mode dunkel (also dort schon kaputt,
  // nur niemandem aufgefallen). Im Dark-Only-Re-Design ist card komplett
  // schwarz und Text wird unsichtbar.
  //
  // Die folgenden Tokens sind die *richtige* Adresse für Foregrounds auf
  // CTA-Hero-Cards. Werte spiegeln die hellen Ink-Tokens, sind aber semantisch
  // klar getrennt — wer eine Hero-Card baut, sollte explizit `onCtaSurface`
  // greifen statt sich auf die globalen Ink-Tokens zu verlassen.
  static let onCtaSurface = ink                    // Primärtext auf CTA-Surface
  static let onCtaSurfaceSecondary = softInk       // Subtitle / Metrik-Werte
  static let onCtaSurfaceMuted = mutedInk          // Eyebrow-Sekundärteile, Caption

  /// Kühler Cyan-Akzent für „in Bearbeitung / informativ"-Zustände und
  /// HUD-Highlights (Scan, Verbindungssuche, Sync). Spiegelt im neuen
  /// Look das HUD-Vokabular und ist bewusst kein zweites Lime.
  static let accentCool = Color(lightHex: "5BD4F0", darkHex: "5BD4F0")

  /// Glow-Token: leicht transparente Variante des Lime — für weiche
  /// Halo-Effekte hinter aktiven Elementen und Hero-Komponenten. Wird
  /// als Schatten/Background-Layer benutzt, nicht als Vordergrundfarbe.
  static let limeGlow = Color(red: 0.78, green: 0.92, blue: 0.27, opacity: 0.35)

  /// Glow-Token: kühler Pendant zu `limeGlow` — z.B. für Scan-Status,
  /// In-Progress-Markierungen und HUD-Akzente.
  static let coolGlow = Color(red: 0.36, green: 0.83, blue: 0.94, opacity: 0.30)

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
    self.init(
      uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
          ? UIColor(Color(hex: darkHex))
          : UIColor(Color(hex: lightHex))
      }
    )
  }
}

extension View {
  /// A8: Card-Style "Minimal Tech".
  /// - Hairline-Border (0.5pt) statt klobiger 1pt-Linie
  /// - Subtiler Inner-Highlight oben (verkauft die Tiefe ohne Glow zu erzwingen)
  /// - Kühlerer Drop-Shadow, knapper unter der Card
  func gainsCardStyle(_ background: Color = GainsColor.card) -> some View {
    let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
    return self
      .background(background)
      .clipShape(shape)
      .overlay(
        shape
          .strokeBorder(
            LinearGradient(
              colors: [
                GainsColor.border.opacity(0.95),
                GainsColor.border.opacity(0.55)
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 0.6
          )
      )
      .overlay(
        shape
          .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
          .blendMode(.plusLighter)
          .padding(0.5)
      )
      .shadow(color: Color.black.opacity(0.55), radius: 18, x: 0, y: 8)
  }

  /// A8: Interaktive Card — Akzent-Border ist jetzt ein Lime-Stop-Gradient
  /// (oben hell, unten ausgeblendet) plus weicher Glow. Wirkt wie eine
  /// HUD-Markierung statt wie ein dicker Outline-Rahmen.
  func gainsInteractiveCardStyle(
    _ background: Color = GainsColor.card, accent: Color = GainsColor.lime
  ) -> some View {
    let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
    return self
      .background(background)
      .clipShape(shape)
      .overlay(
        shape
          .strokeBorder(
            LinearGradient(
              colors: [accent.opacity(0.85), accent.opacity(0.18)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 0.9
          )
      )
      .shadow(color: accent.opacity(0.18), radius: 16, x: 0, y: 0)
      .shadow(color: Color.black.opacity(0.55), radius: 18, x: 0, y: 8)
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
  // A8: HUD-Background.
  // - Pure-Dark Basis
  // - Sanfter Lime-Halo oben links + Cyan-Halo unten rechts (als Radial-
  //   Gradients ganz dezent, nicht aufdringlich)
  // - Sehr feines vertikales Hairline-Grid darüber, sub-pixel-Opacity —
  //   verkauft die "Technik"-Anmutung, ohne dass der Background unruhig wird.
  // - Sanfte Vignette nach außen
  var body: some View {
    GeometryReader { proxy in
      ZStack {
        GainsColor.background
          .ignoresSafeArea()

        // Lime-Glow oben-links
        RadialGradient(
          colors: [
            GainsColor.lime.opacity(0.07),
            GainsColor.lime.opacity(0.0)
          ],
          center: .init(x: 0.18, y: 0.10),
          startRadius: 4,
          endRadius: max(proxy.size.width, 480)
        )
        .blendMode(.plusLighter)
        .ignoresSafeArea()

        // Cyan-Glow unten-rechts
        RadialGradient(
          colors: [
            GainsColor.accentCool.opacity(0.05),
            GainsColor.accentCool.opacity(0.0)
          ],
          center: .init(x: 0.85, y: 0.92),
          startRadius: 4,
          endRadius: max(proxy.size.width, 520)
        )
        .blendMode(.plusLighter)
        .ignoresSafeArea()

        // Sehr dezentes vertikales Grid
        HUDGrid()
          .opacity(0.35)
          .ignoresSafeArea()

        // Vignette
        RadialGradient(
          colors: [
            Color.black.opacity(0.0),
            Color.black.opacity(0.55)
          ],
          center: .center,
          startRadius: 200,
          endRadius: max(proxy.size.width, proxy.size.height)
        )
        .blendMode(.multiply)
        .ignoresSafeArea()
      }
      .allowsHitTesting(false)
    }
    .ignoresSafeArea()
  }
}

/// Sehr feines vertikales Grid-Pattern — wird hinter den App-Inhalten als
/// HUD-Layer eingeblendet. Die Linien sind absichtlich nahe der Sichtbarkeits-
/// schwelle, damit sie Tiefe vermitteln statt zu lärmen.
private struct HUDGrid: View {
  var spacing: CGFloat = 28

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
            with: .color(Color.white.opacity(0.025)),
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
            with: .color(Color.white.opacity(0.018)),
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
    .padding(16)
    .background(GainsColor.card)
    .overlay(hairlineBorder(cornerRadius: 16))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)
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
    .padding(.vertical, 36)
    .padding(.horizontal, 20)
    .background(GainsColor.card)
    .overlay(hairlineBorder(cornerRadius: 20))
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .shadow(color: Color.black.opacity(0.5), radius: 18, x: 0, y: 8)
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
    .background(GainsColor.card)
    .overlay(hairlineBorder(cornerRadius: 14))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 4)
  }

  /// HUD-Icon-Halo: gefüllter Kern, dünner Lime-Ring, optionaler weicher Glow.
  private func haloIcon(_ name: String, size: CGFloat, iconSize: CGFloat, glow: Bool = false)
    -> some View
  {
    ZStack {
      Circle()
        .fill(GainsColor.lime.opacity(0.10))
      Circle()
        .strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: 0.8)
      Image(systemName: name)
        .font(.system(size: iconSize, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
    }
    .frame(width: size, height: size)
    .shadow(color: GainsColor.lime.opacity(glow ? 0.35 : 0.0), radius: glow ? 14 : 0)
  }

  private func hairlineBorder(cornerRadius: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .strokeBorder(
        LinearGradient(
          colors: [
            GainsColor.border.opacity(0.95),
            GainsColor.border.opacity(0.45)
          ],
          startPoint: .top,
          endPoint: .bottom
        ),
        lineWidth: 0.6
      )
  }

  private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Text(label)
          .gainsEyebrow(GainsColor.onLime, tracking: GainsTracking.eyebrowWide)
        Image(systemName: "arrow.right")
          .font(.system(size: 11, weight: .heavy))
      }
      .foregroundStyle(GainsColor.onLime)
      .padding(.horizontal, 16)
      .frame(height: 38)
      .background(GainsColor.lime)
      .clipShape(Capsule())
      .shadow(color: GainsColor.lime.opacity(0.35), radius: 12, x: 0, y: 0)
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
// Drei Varianten:
//   - `.card`     — Standard auf hellem Card-Hintergrund.
//   - `.subdued`  — auf einem Background-Tone (z.B. innerhalb einer Card).
//   - `.onDark`   — für Hero-/CTA-Surfaces mit dunklem Hintergrund.

struct GainsMetricTile: View {
  enum Style {
    case card
    case subdued
    case onDark
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
    .padding(12)
    .background(background)
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(GainsColor.border.opacity(borderOpacity), lineWidth: 0.6)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var labelColor: Color {
    switch style {
    case .card, .subdued: return GainsColor.softInk
    case .onDark:         return GainsColor.onCtaSurface.opacity(0.55)
    }
  }
  private var valueColor: Color {
    switch style {
    case .card, .subdued: return GainsColor.ink
    case .onDark:         return GainsColor.card
    }
  }
  private var unitColor: Color {
    switch style {
    case .card, .subdued: return GainsColor.softInk
    case .onDark:         return GainsColor.card.opacity(0.7)
    }
  }
  private var background: Color {
    switch style {
    case .card:    return GainsColor.card
    case .subdued: return GainsColor.surfaceDeep.opacity(0.7)
    case .onDark:  return Color.white.opacity(0.04)
    }
  }
  private var borderOpacity: Double {
    switch style {
    case .card:    return 0.85
    case .subdued: return 0.55
    case .onDark:  return 0.25
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

struct GainsWordmark: View {
  let size: CGFloat

  init(size: CGFloat = 24) {
    self.size = size
  }

  var body: some View {
    HStack(spacing: 0) {
      Text("gains")
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(GainsColor.ink)
        .tracking(size <= 20 ? -0.4 : -0.8)

      // A8: Lime-Punkt bekommt einen weichen Glow — der Wordmark wirkt damit
      // im Header wie das aktive Element eines HUDs.
      Text(".")
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .tracking(size <= 20 ? -0.4 : -0.8)
        .shadow(color: GainsColor.lime.opacity(0.55), radius: size * 0.25, x: 0, y: 0)
    }
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
          .shadow(color: GainsColor.lime.opacity(0.55), radius: size * 0.18, x: 0, y: 0)

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

  var body: some View {
    ZStack {
      Circle()
        .fill(color.opacity(0.35))
        .frame(width: haloSize, height: haloSize)
        .scaleEffect(animating ? 1.0 : 0.55)
        .opacity(animating ? 0.0 : 0.9)
      Circle()
        .fill(color)
        .frame(width: coreSize, height: coreSize)
        .shadow(color: color.opacity(0.7), radius: 5)
    }
    .frame(width: haloSize, height: haloSize)
    .onAppear {
      withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
        animating = true
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
    .background(GainsColor.card.opacity(0.6))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [
              accent.opacity(0.35),
              GainsColor.border.opacity(0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 0.7
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(color: accent.opacity(0.10), radius: 18, x: 0, y: 0)
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
    HStack(spacing: 6) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 10, weight: .bold))
      }
      Text(label)
        .gainsEyebrow(accent)
    }
    .foregroundStyle(accent)
    .padding(.horizontal, 12)
    .frame(height: 26)
    .background(accent.opacity(0.10))
    .overlay(
      Capsule().strokeBorder(accent.opacity(0.5), lineWidth: 0.6)
    )
    .clipShape(Capsule())
    .shadow(color: accent.opacity(0.35), radius: 10, x: 0, y: 0)
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
          .font(GainsFont.display(28))
          .foregroundStyle(GainsColor.onCtaSurface)
          .lineLimit(2)
          .minimumScaleFactor(0.78)

        if let subtitle, !subtitle.isEmpty {
          // Hero-Subtitle nutzt die kanonische Body-Rolle (15pt + lineSpacing 3),
          // mit der Foreground-Variante für CTA-Surfaces.
          Text(subtitle)
            .gainsBody(GainsColor.onCtaSurfaceSecondary)
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
    .padding(20)
    .background(heroSurface)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(heroBorder)
    .overlay(topHalo, alignment: .top)
    .shadow(color: Color.black.opacity(0.55), radius: 22, x: 0, y: 10)
  }

  // MARK: - Bestandteile

  private var slashEyebrow: some View {
    HStack(spacing: 4) {
      ForEach(Array(eyebrow.enumerated()), id: \.offset) { index, part in
        Text(part)
          .gainsEyebrow(
            index == 0 ? GainsColor.lime : GainsColor.onCtaSurfaceMuted
          )
        if index < eyebrow.count - 1 {
          Text("/")
            .gainsEyebrow(GainsColor.lime)
        }
      }
    }
  }

  private var metricsStrip: some View {
    HStack(spacing: 0) {
      ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
        // Spacing 5 → 7: schafft eine sichtbarere Stufe Label → Value.
        VStack(spacing: 7) {
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
    .background(Color.white.opacity(0.04))
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.6)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var heroSurface: some View {
    GainsColor.ctaSurface
  }

  private var heroBorder: some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
      .strokeBorder(
        LinearGradient(
          colors: [
            GainsColor.lime.opacity(0.55),
            GainsColor.lime.opacity(0.08)
          ],
          startPoint: .top,
          endPoint: .bottom
        ),
        lineWidth: 0.9
      )
  }

  /// Subtiler Lime-Halo am oberen Rand — verkauft die Hero-Card als
  /// „aktive Bühne" ohne aufdringlich zu glühen.
  private var topHalo: some View {
    LinearGradient(
      colors: [
        GainsColor.lime.opacity(0.18),
        GainsColor.lime.opacity(0.0)
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .frame(height: 80)
    .blendMode(.plusLighter)
    .allowsHitTesting(false)
    .clipShape(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
    )
  }
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

  /// Treibt den langsam atmenden Halo. Wird im `onAppear` gestartet und
  /// läuft so lange der Button sichtbar ist — autoreverse + repeatForever.
  @State private var breathing: Bool = false

  var body: some View {
    Button(action: action) {
      buttonContent
    }
    .buttonStyle(HeroPrimaryCTAButtonStyle())
    .onAppear {
      // Langsame Atmung (~2,4 s pro Halbzyklus). Bewusst nicht aggressiv,
      // damit die App nicht „zappelt" — sieht eher aus wie Standby-LED.
      withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
        breathing = true
      }
    }
  }

  private var buttonContent: some View {
    ZStack {
      // 1. Atmender Halo hinter der Pille (sitzt unten in der ZStack-
      //    Reihenfolge, damit er von der Pille überdeckt wird und nur
      //    aussen rausragt). Skaliert leicht in der Animation.
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(GainsColor.lime)
        .opacity(breathing ? 0.32 : 0.18)
        .blur(radius: breathing ? 22 : 14)
        .scaleEffect(x: breathing ? 1.02 : 0.97, y: breathing ? 1.10 : 0.95)
        .padding(-2)

      // 2. Hauptpille mit Lime-Gradient
      HStack(spacing: 12) {
        iconPlate
        Text(title)
          .gainsEyebrow(GainsColor.onLime, size: 13, tracking: GainsTracking.eyebrowTight)
          .lineLimit(1)
          .minimumScaleFactor(0.85)
        Spacer(minLength: 0)
        forwardChevronBubble
      }
      .padding(.leading, 6)
      .padding(.trailing, 8)
      .frame(height: 56)
      .frame(maxWidth: .infinity)
      .background(limeGradientFill)
      .overlay(topInnerHighlight)
      .overlay(insetStroke)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .shadow(color: GainsColor.lime.opacity(0.42), radius: 18, x: 0, y: 6)
      .shadow(color: Color.black.opacity(0.45), radius: 10, x: 0, y: 4)
    }
  }

  // ── Subviews ────────────────────────────────────────────────────────

  /// Dunkle Plate mit Lime-Ring, in der das Start-Icon sitzt. Erzeugt den
  /// optischen Eindruck eines „Power-Buttons".
  @ViewBuilder
  private var iconPlate: some View {
    if let icon {
      ZStack {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
          .fill(GainsColor.onLime)
        RoundedRectangle(cornerRadius: 13, style: .continuous)
          .strokeBorder(GainsColor.lime.opacity(0.55), lineWidth: 0.8)

        Image(systemName: icon)
          .font(.system(size: 17, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
          .shadow(color: GainsColor.lime.opacity(0.65), radius: 6)
      }
      .frame(width: 44, height: 44)
    } else {
      Color.clear.frame(width: 8, height: 44)
    }
  }

  /// Pfeil-Capsule rechts. Trägt die „nach vorne starten"-Bedeutung,
  /// liest sich nicht mehr wie ein passives Listen-Disclosure.
  private var forwardChevronBubble: some View {
    ZStack {
      Capsule()
        .fill(GainsColor.onLime.opacity(0.92))
      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .heavy))
        .foregroundStyle(GainsColor.lime)
    }
    .frame(width: 36, height: 32)
  }

  /// Vertikaler Lime-Gradient. Oben heller (Highlight), unten gesättigter
  /// (Mass). Bewusst minimal, damit es nach Material wirkt und nicht nach
  /// 2010er Glossy-Button.
  private var limeGradientFill: some View {
    LinearGradient(
      colors: [
        GainsColor.lime,
        GainsColor.lime.opacity(0.92),
        GainsColor.signalDeep
      ],
      startPoint: .top,
      endPoint: .bottom
    )
  }

  /// Schmaler Highlight-Bogen am oberen Rand — fängt das „Licht" ein
  /// und macht die Pille plastisch ohne Schatten zu falsifizieren.
  private var topInnerHighlight: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .strokeBorder(
        LinearGradient(
          colors: [
            Color.white.opacity(0.55),
            Color.white.opacity(0.05)
          ],
          startPoint: .top,
          endPoint: .center
        ),
        lineWidth: 1
      )
      .blendMode(.plusLighter)
      .allowsHitTesting(false)
  }

  /// Feiner Inset-Stroke in onLime-Tönung — definiert die Pille zur
  /// dunklen Hero-Surface hin und verhindert „schwimmende" Kanten.
  private var insetStroke: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .strokeBorder(GainsColor.onLime.opacity(0.18), lineWidth: 0.8)
  }
}

/// Press-State für `HeroPrimaryCTAButton`. Skaliert leicht und drückt
/// den Halo zusammen — gibt dem Tap echtes haptisches Feedback.
private struct HeroPrimaryCTAButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .brightness(configuration.isPressed ? -0.04 : 0)
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
    Text(label)
      .gainsEyebrow(foreground, tracking: GainsTracking.eyebrowWide)
      .padding(.horizontal, 12)
      .frame(height: 26)
      .background(background)
      .overlay(
        Capsule().strokeBorder(borderColor, lineWidth: 0.6)
      )
      .clipShape(Capsule())
      .shadow(color: glowColor, radius: tone == .live ? 12 : 0)
  }

  private var foreground: Color {
    switch tone {
    case .live, .plan: return GainsColor.onLime
    case .rest:        return GainsColor.onCtaSurfaceSecondary
    case .flex:        return GainsColor.onCtaSurface
    }
  }
  private var background: Color {
    switch tone {
    case .live, .plan: return GainsColor.lime
    case .rest:        return Color.white.opacity(0.06)
    case .flex:        return GainsColor.accentCool.opacity(0.18)
    }
  }
  private var borderColor: Color {
    switch tone {
    case .live, .plan: return GainsColor.lime.opacity(0.5)
    case .rest:        return Color.white.opacity(0.18)
    case .flex:        return GainsColor.accentCool.opacity(0.4)
    }
  }
  private var glowColor: Color {
    tone == .live ? GainsColor.lime.opacity(0.6) : .clear
  }
}
