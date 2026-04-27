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
  static let background = Color(lightHex: "EAE7E1", darkHex: "0E1011")
  static let card = Color(lightHex: "F7F4EE", darkHex: "151718")
  static let elevated = Color(lightHex: "F0ECE5", darkHex: "1B1E20")
  static let ink = Color(lightHex: "171717", darkHex: "F3F1EA")
  // A4: Sekundärtext nochmal etwas dunkler im Light-Mode — verbessert die
  // Lesbarkeit auf cremefarbener Card-Fläche spürbar (Kontrast 11.7:1 statt 10.2:1).
  static let softInk = Color(lightHex: "2E2E2E", darkHex: "D3CFC5")
  // mutedInk ebenfalls leicht dunkler für lange Body-Passagen.
  static let mutedInk = Color(lightHex: "4F4F4F", darkHex: "ADA89E")
  // Karten-Kanten leicht stärker -> bessere Trennung zum Background
  static let border = Color(lightHex: "B8B2A6", darkHex: "353A3D")
  static let lime = Color(lightHex: "D4E85C", darkHex: "C2DC47")
  static let moss = Color(lightHex: "4A5220", darkHex: "6F8440")
  static let signalDeep = Color(lightHex: "4A5220", darkHex: "879F4B")
  static let onLime = Color(lightHex: "171A10", darkHex: "15180F")
  static let onLimeSecondary = Color(lightHex: "39411B", darkHex: "2E3517")
  static let ember = Color(lightHex: "E8543C", darkHex: "FF6A4A")
  static let emberGlow = Color(lightHex: "F0A88F", darkHex: "FFB094")
  static let onEmber = Color(lightHex: "2A0E07", darkHex: "190503")
  static let onEmberSecondary = Color(lightHex: "551D10", darkHex: "3A1109")
  static let surfaceDeep = Color(lightHex: "DFDCD4", darkHex: "0A0C0D")

  /// Bleibt in beiden Color-Schemes bewusst dunkel — für CTA-Buttons, Icon-Kreise
  /// und Hero-Card-Hintergründe, die ihren dunklen Kontrast nicht invertieren sollen.
  static let ctaSurface = Color(lightHex: "171717", darkHex: "1E2327")

  /// Leicht erhöhte Variante von ctaSurface — für Chips und Pills auf dunklem Untergrund.
  static let ctaRaised = Color(lightHex: "262626", darkHex: "282E34")
}

enum GainsFont {
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

  /// Tracked Uppercase-Eyebrow — moderates Tracking statt 2.0+,
  /// damit die Buchstaben nicht zerfallen.
  /// A4: Floor 13pt, damit Eyebrow-Text mit 1.4–2.0pt Tracking nicht zerfällt.
  static func eyebrow(_ size: CGFloat = 13) -> Font {
    .system(size: max(size, 13), weight: .semibold)
  }

  /// Kleine Caption-Texte mit etwas mehr Gewicht für Lesbarkeit.
  static func caption(_ size: CGFloat = 13) -> Font {
    .system(size: max(size, 13), weight: .medium)
  }
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
  func gainsCardStyle(_ background: Color = GainsColor.card) -> some View {
    self
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(GainsColor.border.opacity(0.9), lineWidth: 1)
      )
      // Etwas kräftigerer Schatten für klarere Hierarchie zum Background
      .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 4)
  }

  func gainsInteractiveCardStyle(
    _ background: Color = GainsColor.card, accent: Color = GainsColor.lime
  ) -> some View {
    self
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(accent.opacity(0.6), lineWidth: 1.2)
      )
      .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 4)
  }

  /// Tracked Uppercase-Eyebrow mit moderatem Tracking — bevorzugte Schablone
  /// für neue Section-Labels statt manueller `.font().tracking(2.x)`-Kombi.
  /// A4: Default-Größe 13pt (Floor in `GainsFont.eyebrow`), Tracking auf 1.2
  /// reduziert — Buchstaben bleiben verbunden lesbar.
  func gainsEyebrow(
    _ color: Color = GainsColor.softInk,
    size: CGFloat = 13,
    tracking: CGFloat = 1.2
  ) -> some View {
    self
      .font(GainsFont.eyebrow(size))
      .tracking(tracking)
      .textCase(.uppercase)
      .foregroundStyle(color)
  }

  /// A4: Body-Fließtext mit dezent erweiterter Zeilenhöhe für lange Passagen.
  /// Verwende es bei mehrzeiligen Erklärungen / Beschreibungen, nicht bei
  /// einzeiligen Labels.
  func gainsBodyText(
    _ color: Color = GainsColor.softInk,
    size: CGFloat = 17
  ) -> some View {
    self
      .font(GainsFont.body(size))
      .foregroundStyle(color)
      .lineSpacing(2)
  }
}

struct GainsAppBackground: View {
  var body: some View {
    ZStack {
      GainsColor.background
        .ignoresSafeArea()
    }
    .allowsHitTesting(false)
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

  private var inlineLayout: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 36, height: 36)
          .background(Circle().fill(GainsColor.lime.opacity(0.14)))
      }
      Text(title)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
      Text(message)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .fixedSize(horizontal: false, vertical: true)
      if let actionLabel, let action {
        actionButton(actionLabel, action: action)
          .padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var prominentLayout: some View {
    VStack(spacing: 14) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 28, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 64, height: 64)
          .background(Circle().fill(GainsColor.lime.opacity(0.12)))
      }
      VStack(spacing: 6) {
        Text(title)
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)
          .multilineTextAlignment(.center)
        Text(message)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
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
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func cardLayout(_ resolvedIcon: String?) -> some View {
    HStack(alignment: .top, spacing: 14) {
      if let resolvedIcon {
        Image(systemName: resolvedIcon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 40, height: 40)
          .background(Circle().fill(GainsColor.lime.opacity(0.14)))
      }
      VStack(alignment: .leading, spacing: 6) {
        Text(title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        Text(message)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
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
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func actionButton(_ label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Text(label.uppercased())
          .font(GainsFont.label(11))
          .tracking(1.6)
        Image(systemName: "arrow.right")
          .font(.system(size: 11, weight: .heavy))
      }
      .foregroundStyle(GainsColor.onLime)
      .padding(.horizontal, 16)
      .frame(height: 38)
      .background(GainsColor.lime)
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }
}

struct GainsDisclosureIndicator: View {
  let accent: Color

  init(accent: Color = GainsColor.moss) {
    self.accent = accent
  }

  var body: some View {
    Image(systemName: "chevron.right")
      .font(.system(size: 11, weight: .bold))
      .foregroundStyle(accent)
      .frame(width: 28, height: 28)
      .background(accent.opacity(0.12))
      .clipShape(Circle())
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

      Text(".")
        .font(.system(size: size, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .tracking(size <= 20 ? -0.4 : -0.8)
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
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
          .fill(GainsColor.card)
          .frame(width: size, height: size)

        Circle()
          .stroke(GainsColor.border, lineWidth: size * 0.05)
          .frame(width: size * 0.7, height: size * 0.7)

        Circle()
          .trim(from: 0.04, to: 0.62)
          .stroke(GainsColor.lime, style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round))
          .frame(width: size * 0.7, height: size * 0.7)
          .rotationEffect(.degrees(-38))

        Text("G")
          .font(.system(size: size * 0.38, weight: .semibold))
          .foregroundStyle(GainsColor.ink)
      }

      GainsWordmark(size: size * 0.24)
    }
  }
}
