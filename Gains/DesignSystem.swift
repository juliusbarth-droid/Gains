import SwiftUI
import UIKit

enum GainsAppearanceMode: String, CaseIterable {
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
  static let background = Color(lightHex: "E8E6E0", darkHex: "0B0C0C")
  static let card = Color(lightHex: "F4F2EC", darkHex: "17191A")
  static let elevated = Color(lightHex: "ECE9E2", darkHex: "202325")
  static let ink = Color(lightHex: "1A1A1A", darkHex: "F4F3EE")
  static let softInk = Color(lightHex: "4E4E4E", darkHex: "C9C6BC")
  static let mutedInk = Color(lightHex: "767676", darkHex: "A19D93")
  static let border = Color(lightHex: "BBB8B0", darkHex: "3B3E40")
  static let lime = Color(lightHex: "D4E85C", darkHex: "C2DC47")
  static let moss = Color(lightHex: "4A5220", darkHex: "6F8440")
  static let signalDeep = Color(lightHex: "4A5220", darkHex: "879F4B")
  static let onLime = Color(lightHex: "171A10", darkHex: "15180F")
  static let onLimeSecondary = Color(lightHex: "39411B", darkHex: "2E3517")
}

enum GainsFont {
  static func display(_ size: CGFloat) -> Font {
    .system(size: size, weight: .semibold)
  }

  static func title(_ size: CGFloat = 24) -> Font {
    .system(size: max(size, 21), weight: .semibold)
  }

  static func body(_ size: CGFloat = 15) -> Font {
    .system(size: max(size, 16), weight: .regular)
  }

  static func label(_ size: CGFloat = 11) -> Font {
    .system(size: max(size, 11.5), weight: .medium)
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
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(0.045),
                Color.clear,
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(GainsColor.border.opacity(0.95), lineWidth: 1)
      )
      .shadow(color: Color.black.opacity(0.08), radius: 14, y: 8)
  }

  func gainsInteractiveCardStyle(
    _ background: Color = GainsColor.card, accent: Color = GainsColor.lime
  ) -> some View {
    self
      .background(background)
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(0.06),
                Color.clear,
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(accent.opacity(0.72), lineWidth: 1.2)
      )
      .shadow(color: Color.black.opacity(0.18), radius: 18, y: 10)
  }
}

struct GainsAppBackground: View {
  var body: some View {
    ZStack {
      GainsColor.background
        .ignoresSafeArea()

      LinearGradient(
        colors: [
          GainsColor.background,
          GainsColor.background,
          GainsColor.card.opacity(0.24),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      Circle()
        .fill(GainsColor.lime.opacity(0.08))
        .frame(width: 280, height: 280)
        .blur(radius: 70)
        .offset(x: 140, y: -250)

      Circle()
        .fill(GainsColor.elevated.opacity(0.7))
        .frame(width: 340, height: 340)
        .blur(radius: 90)
        .offset(x: -160, y: -320)

      Circle()
        .fill(GainsColor.card.opacity(0.55))
        .frame(width: 260, height: 260)
        .blur(radius: 80)
        .offset(x: 170, y: 420)
    }
    .allowsHitTesting(false)
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
