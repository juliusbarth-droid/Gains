import SwiftUI

// MARK: - GainsSheetHeader
//
// B5 (Sheet-Re-Design 2026-05-01): Einheitlicher Sheet-Header. Bislang baut
// jedes Sheet (CaptureSheet, ProfileView, WaterDetailSheet, FoodPhoto-
// RecognitionView, RunDetailSheet, GymExerciseHistorySheet, …) seinen Header
// ad-hoc — manche mit Toolbar, manche mit eigener HStack, manche mit
// `screenHeader(...)`. Das Resultat: drei verschiedene Höhen, drei
// verschiedene Close-Button-Styles, kein einheitlicher Drag-Indicator-Look.
//
// `GainsSheetHeader` bündelt das auf:
//   • Eyebrow (HUD-Slash-Label, optional)
//   • Title (28pt, ink)
//   • Subtitle (15pt, softInk, optional)
//   • Close-Button rechts (X in dezenter Capsule)
//   • Optional Trailing-Action-Button (z.B. „Speichern", „Teilen")
//   • Optional Akzent-Farbe für Eyebrow + Trailing-Action
//
// Verwendung in einem Sheet:
//
//   var body: some View {
//     ZStack {
//       GainsAppBackground()
//       VStack(spacing: 0) {
//         GainsSheetHeader(
//           eyebrow: ["WATER", "TODAY"],
//           title: "Wasser-Tracker",
//           subtitle: "Tippe auf das Glas oder die Quick-Buttons.",
//           onClose: { dismiss() }
//         )
//         ScrollView { ... }
//       }
//     }
//   }
//
// Variante mit Trailing-Action:
//
//   GainsSheetHeader(
//     eyebrow: ["MAHLZEIT", "FOTO"],
//     title: "Mahlzeit fotografieren",
//     trailingAction: .init(label: "Speichern", action: save),
//     onClose: { dismiss() }
//   )

struct GainsSheetHeader: View {
  let eyebrow: [String]
  let title: String
  let subtitle: String?
  let accent: Color
  let trailingAction: TrailingAction?
  let onClose: (() -> Void)?

  struct TrailingAction {
    let label: String
    let icon: String?
    let action: () -> Void

    init(label: String, icon: String? = nil, action: @escaping () -> Void) {
      self.label = label
      self.icon = icon
      self.action = action
    }
  }

  init(
    eyebrow: [String] = [],
    title: String,
    subtitle: String? = nil,
    accent: Color = GainsColor.lime,
    trailingAction: TrailingAction? = nil,
    onClose: (() -> Void)? = nil
  ) {
    self.eyebrow = eyebrow
    self.title = title
    self.subtitle = subtitle
    self.accent = accent
    self.trailingAction = trailingAction
    self.onClose = onClose
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Top-Row: Eyebrow links, Trailing/Close rechts
      HStack(alignment: .center) {
        if !eyebrow.isEmpty {
          slashEyebrow
        }
        Spacer()
        HStack(spacing: 8) {
          if let trailingAction {
            trailingActionButton(trailingAction)
          }
          if let onClose {
            closeButton(onClose)
          }
        }
      }

      // Title
      Text(title)
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)
        .minimumScaleFactor(0.78)

      // Subtitle
      if let subtitle, !subtitle.isEmpty {
        Text(subtitle)
          .gainsBody(secondary: true)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 14)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var slashEyebrow: some View {
    HStack(spacing: 4) {
      ForEach(Array(eyebrow.enumerated()), id: \.offset) { index, part in
        Text(part)
          .gainsEyebrow(
            index == 0 ? accent : GainsColor.softInk
          )
        if index < eyebrow.count - 1 {
          Text("/")
            .gainsEyebrow(accent)
        }
      }
    }
  }

  private func trailingActionButton(_ action: TrailingAction) -> some View {
    Button(action: action.action) {
      HStack(spacing: 6) {
        if let icon = action.icon {
          Image(systemName: icon)
            .font(.system(size: 11, weight: .heavy))
        }
        Text(action.label)
          .gainsEyebrow(accent, tracking: GainsTracking.eyebrowTight)
      }
      .foregroundStyle(accent)
      .padding(.horizontal, 12)
      .frame(height: 32)
      .background(accent.opacity(0.12))
      .overlay(
        Capsule().strokeBorder(accent.opacity(0.4), lineWidth: 0.6)
      )
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private func closeButton(_ action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: "xmark")
        .font(.system(size: 12, weight: .heavy))
        .foregroundStyle(GainsColor.softInk)
        .frame(width: 32, height: 32)
        .background(GainsColor.card)
        .overlay(
          Circle().strokeBorder(GainsColor.border.opacity(0.7), lineWidth: 0.6)
        )
        .clipShape(Circle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - GainsSheet-Modifier
//
// B5: Bündelt die typischen Sheet-Settings (Hintergrund, Drag-Indicator)
// in einem View-Modifier. Wird auf den Sheet-Wurzel-View angewendet:
//
//   .gainsSheet(detents: [.medium, .large])
//
// Setzt:
//   • `presentationBackground` auf den App-Background (verhindert das
//     systemeigene helle Sheet-Material, das im Dark-Mode kontrastlos wirkt)
//   • `presentationDragIndicator(.visible)` — sichtbares Grabber-Pattern
//   • `presentationDetents` (default: nur `.large`)
//   • `presentationCornerRadius(28)` für gleiche Rundung wie Hero-Cards

extension View {
  /// Standardisiert die Sheet-Präsentation: Drag-Indicator sichtbar, Detents,
  /// Background-Color einheitlich, Corner-Radius auf 28pt.
  func gainsSheet(
    detents: Set<PresentationDetent> = [.large],
    cornerRadius: CGFloat = 28
  ) -> some View {
    self
      .presentationDetents(detents)
      .presentationDragIndicator(.visible)
      .presentationBackground(GainsColor.background)
      .presentationCornerRadius(cornerRadius)
  }
}
