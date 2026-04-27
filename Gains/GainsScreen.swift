import SwiftUI

struct GainsScreen<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    ZStack {
      GainsAppBackground()

      ScrollView(showsIndicators: false) {
        content
          .padding(.horizontal, 20)
          .padding(.top, 18)
          .padding(.bottom, 30)
      }
    }
  }
}

private struct ScreenHeaderView: View {
  let eyebrow: String
  let title: String
  let subtitle: String
  @State private var showsInfo = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top) {
        GainsWordmark(size: 18)
        Spacer()

        if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          Button {
            showsInfo.toggle()
          } label: {
            HStack(spacing: 6) {
              Image(systemName: showsInfo ? "xmark.circle.fill" : "info.circle")
                .font(.system(size: 13, weight: .semibold))
              Text(showsInfo ? "Schließen" : "Info")
                .font(GainsFont.label(10))
                .tracking(1.2)
            }
            .foregroundStyle(showsInfo ? GainsColor.moss : GainsColor.softInk)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
              showsInfo ? GainsColor.lime.opacity(0.2) : GainsColor.elevated.opacity(0.88)
            )
            .overlay(
              Capsule()
                .stroke(
                  showsInfo ? GainsColor.lime.opacity(0.35) : GainsColor.border.opacity(0.8),
                  lineWidth: 1)
            )
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }

      SlashLabel(
        parts: eyebrow.components(separatedBy: " / "), primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      Text(title)
        .font(GainsFont.title(30))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)

      if showsInfo, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: "info.circle.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(GainsColor.lime)

          Text(subtitle)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
            .lineSpacing(2)
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
        }
        .padding(14)
        .gainsCardStyle(GainsColor.elevated)
      }
    }
  }
}

@ViewBuilder
func screenHeader(eyebrow: String, title: String, subtitle: String = "") -> some View {
  ScreenHeaderView(eyebrow: eyebrow, title: title, subtitle: subtitle)
}
