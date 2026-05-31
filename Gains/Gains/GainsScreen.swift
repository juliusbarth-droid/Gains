import SwiftUI

struct GainsScreen<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    ZStack {
      GainsAppBackground()

      ScrollView(showsIndicators: false) {
        content
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.l)
          .padding(.bottom, GainsSpacing.xl)
      }
      // Scroll-Performance: kein Bounce wenn Inhalt kleiner als Viewport.
      .scrollBounceBehavior(.basedOnSize)
    }
  }
}

private struct ScreenHeaderView: View {
  let eyebrow: String
  let title: String
  let subtitle: String
  @State private var showsInfo = false

  var body: some View {
    // 2026-05-14 (Polish-Loop 111): screenHeader auf neuen Stil
    //   • Wordmark links + Live-Dot mit Lime-Glow als Brand-Anker
    //   • Info-Pille mit Glas-Background + Hairline-Gradient
    //   • Hero-Title bekommt einen sehr dezenten Lime-Shadow für Tiefe
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      HStack(alignment: .top, spacing: GainsSpacing.s) {
        GainsWordmark(size: 18)
        Circle()
          .fill(GainsColor.lime)
          .frame(width: 4, height: 4)
          .shadow(color: GainsColor.lime.opacity(0.275), radius: 2)
        Spacer()

        if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Button {
            showsInfo.toggle()
          } label: {
            HStack(spacing: GainsSpacing.xs) {
              Image(systemName: showsInfo ? "xmark.circle.fill" : "info.circle")
                .font(.system(size: 13, weight: .semibold))
              Text(showsInfo ? "Schließen" : "Info")
                .gainsCaption(showsInfo ? GainsColor.moss : GainsColor.softInk)
            }
            .foregroundStyle(showsInfo ? GainsColor.moss : GainsColor.softInk)
            .padding(.horizontal, GainsSpacing.tight)
            .frame(height: 32)
            .background(
              ZStack {
                Capsule().fill(showsInfo ? GainsColor.lime.opacity(0.16) : GainsColor.elevated.opacity(0.88))
                Capsule()
                  .fill(
                    LinearGradient(
                      colors: [GainsColor.glassInnerLight, .clear],
                      startPoint: .top,
                      endPoint: .center
                    )
                  )
              }
            )
            .overlay(
              Capsule().strokeBorder(
                LinearGradient(
                  colors: showsInfo
                    ? [GainsColor.lime.opacity(0.55), GainsColor.lime.opacity(0.15)]
                    : [GainsColor.border.opacity(0.85), GainsColor.border.opacity(0.35)],
                  startPoint: .top,
                  endPoint: .bottom
                ),
                lineWidth: 1
              )
            )
            .clipShape(Capsule())
            .compositingGroup()
            .shadow(color: showsInfo ? GainsColor.lime.opacity(0.18) : .clear, radius: 6)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(showsInfo ? "Info schließen" : "Info anzeigen")
        }
      }

      SlashLabel(
        parts: eyebrow.components(separatedBy: " / "), primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      // Hero-Title 30pt — eine Stufe größer als das normale `title`-Token,
      // weil dies die identitätsstiftende Überschrift eines Tabs ist.
      Text(title)
        .font(GainsFont.title(30))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)
        .shadow(color: GainsColor.lime.opacity(0.05), radius: 8)

      if showsInfo, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        HStack(alignment: .top, spacing: GainsSpacing.tight) {
          Image(systemName: "info.circle.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(GainsColor.lime)

          Text(subtitle)
            .gainsBody(secondary: true)
            .lineLimit(2)

          Spacer()

          Button {
            showsInfo = false
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 12, weight: .bold))
              .foregroundStyle(GainsColor.softInk)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Info schließen")
        }
        .padding(GainsSpacing.m)
        .gainsCardStyle(GainsColor.elevated)
      }
    }
  }
}

@ViewBuilder
func screenHeader(eyebrow: String, title: String, subtitle: String = "") -> some View {
  ScreenHeaderView(eyebrow: eyebrow, title: title, subtitle: subtitle)
}
