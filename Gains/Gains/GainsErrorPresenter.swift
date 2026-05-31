import Combine
import Foundation
import SwiftUI
import UIKit

// MARK: - GainsErrorPresenter
//
// 2026-05-14 (Audit-Loop 4 + 5): Zentrale Error-Surface für die App.
//
// Hintergrund:
//   HealthKit-Permission denied, BLE-Disconnect, Camera-Permission missing,
//   GPS-Signal verloren, AI-Vision-Quota Limit erreicht — diese Fehler waren
//   bisher entweder per System-Alert (laut, blockierend, kein App-Design),
//   per Inline-Hint (versteckt) oder gar nicht kommuniziert worden. Es gab
//   keine konsistente Reaktion.
//
// Lösung:
//   - Ein EnvironmentObject-Service `GainsErrorPresenter`, das überall in der
//     App `present(.healthKitDenied)` / `.bleLost` etc. annehmen kann.
//   - Ein passiver Banner-Layer auf der Root-View (siehe `ContentView`-
//     Mount), der die aktuelle Meldung als animierten Top-Banner zeigt.
//   - Auto-Dismiss nach 5 s, oder manuell per Swipe/Close.
//   - Severity-System: `.info`/`.warning`/`.critical` für visuelle Stufen.

enum GainsErrorSeverity {
  case info
  case success
  case warning
  case critical

  var accent: Color {
    switch self {
    case .info:     return GainsColor.accentCool
    case .success:  return GainsColor.lime
    case .warning:  return GainsColor.ember
    case .critical: return GainsColor.ember
    }
  }

  var icon: String {
    switch self {
    case .info:     return "info.circle.fill"
    case .success:  return "checkmark.circle.fill"
    case .warning:  return "exclamationmark.triangle.fill"
    case .critical: return "xmark.octagon.fill"
    }
  }
}

struct GainsErrorMessage: Identifiable, Equatable {
  let id = UUID()
  let title: String
  let subtitle: String?
  let severity: GainsErrorSeverity
  /// Optional aktivierbarer Action-Button (z.B. „Einstellungen öffnen").
  let actionTitle: String?
  let action: (() -> Void)?

  static func == (lhs: GainsErrorMessage, rhs: GainsErrorMessage) -> Bool {
    lhs.id == rhs.id
  }

  // MARK: - Vordefinierte Konstanten (häufige Fehlerquellen)

  static let healthKitDenied = GainsErrorMessage(
    title: "Apple Health Zugriff verweigert",
    subtitle: "Aktiviere ihn in den iOS-Einstellungen, damit Workouts und HF synchronisiert werden.",
    severity: .warning,
    actionTitle: "Einstellungen",
    action: {
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
    }
  )

  static let bleDisconnected = GainsErrorMessage(
    title: "HF-Sensor getrennt",
    subtitle: "Versuche die Verbindung in den Einstellungen erneut herzustellen.",
    severity: .info,
    actionTitle: nil,
    action: nil
  )

  static let cameraDenied = GainsErrorMessage(
    title: "Kamera-Zugriff verweigert",
    subtitle: "Ohne Kamera kannst du keine Barcodes oder Mahlzeiten erfassen.",
    severity: .warning,
    actionTitle: "Einstellungen",
    action: {
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
    }
  )

  static let locationDenied = GainsErrorMessage(
    title: "Standort-Zugriff verweigert",
    subtitle: "Ohne GPS können Läufe nicht getrackt werden.",
    severity: .warning,
    actionTitle: "Einstellungen",
    action: {
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
    }
  )

  static let gpsLost = GainsErrorMessage(
    title: "GPS-Signal verloren",
    subtitle: "Distanz und Pace werden vorübergehend geschätzt.",
    severity: .info,
    actionTitle: nil,
    action: nil
  )

  static let aiQuotaReached = GainsErrorMessage(
    title: "Foto-KI nicht verfügbar",
    subtitle: "Versuche es später erneut oder gib die Mahlzeit manuell ein.",
    severity: .info,
    actionTitle: nil,
    action: nil
  )

  // MARK: - Success-Confirmations (Fertiger-Audit P0)
  //
  // 2026-05-16: Save-Aktionen (Route, Segment, Meal-Log, Export) liefen vorher
  // still ab — der User sah keinen Beweis, dass die Aktion gegriffen hat.
  // Diese Presets liefern einen kurzen Lime-Banner (auto-dismiss 2.5 s),
  // immer kombiniert mit `UINotificationFeedbackGenerator().notificationOccurred(.success)`
  // an der Call-Site.

  static let routeSaved = GainsErrorMessage(
    title: "Route gespeichert",
    subtitle: "Du findest sie im Tab „Routen“ — inkl. Heatmap und Lauf-Verlinkung.",
    severity: .success,
    actionTitle: nil,
    action: nil
  )

  static let segmentSaved = GainsErrorMessage(
    title: "Segment erstellt",
    subtitle: "Künftige Läufe werden automatisch gegen dieses Segment gematcht.",
    severity: .success,
    actionTitle: nil,
    action: nil
  )

  static let mealLogged = GainsErrorMessage(
    title: "Mahlzeit eingetragen",
    subtitle: nil,
    severity: .success,
    actionTitle: nil,
    action: nil
  )

  static let exportFailed = GainsErrorMessage(
    title: "Export fehlgeschlagen",
    subtitle: "Beim Schreiben der JSON-Datei ist etwas schiefgegangen. Versuche es erneut.",
    severity: .warning,
    actionTitle: nil,
    action: nil
  )

  static let exportReady = GainsErrorMessage(
    title: "Export bereit",
    subtitle: "Wähle ein Ziel im Share-Sheet aus.",
    severity: .success,
    actionTitle: nil,
    action: nil
  )
}

@MainActor
final class GainsErrorPresenter: ObservableObject {
  static let shared = GainsErrorPresenter()

  @Published private(set) var current: GainsErrorMessage?

  private var dismissTask: Task<Void, Never>?

  /// Zeigt eine Meldung. Mehrfache Aufrufe verdrängen die vorherige Meldung
  /// (last-write-wins) — verhindert ein Stapel von Banner-States.
  func present(_ message: GainsErrorMessage, autoDismissAfter seconds: Double = 5.0) {
    dismissTask?.cancel()
    withAnimation(.easeOut(duration: 0.22)) {
      current = message
    }
    let id = message.id
    dismissTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
      guard !Task.isCancelled, let self else { return }
      // Nur dismissen, wenn die aktuelle Meldung immer noch dieselbe ist.
      if self.current?.id == id {
        self.dismiss()
      }
    }
  }

  /// 2026-05-16 (Fertiger-Audit P0): Convenience für Success-Toasts. Feuert
  /// Notification-Haptik und zeigt den Banner für 2,5 s — deutlich kürzer als
  /// der Default für Fehler (5 s), weil Success rein bestätigend ist.
  func presentSuccess(_ message: GainsErrorMessage) {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
    present(message, autoDismissAfter: 2.5)
  }

  /// Manuelles Dismiss (z. B. Banner-Close-Button oder Swipe).
  func dismiss() {
    dismissTask?.cancel()
    withAnimation(.easeIn(duration: 0.18)) {
      current = nil
    }
  }
}

// MARK: - GainsErrorBanner (UI-Komponente)
//
// Wird in `ContentView` als globaler Overlay-Layer eingehängt. Reagiert auf
// `presenter.current` und animiert sich von oben rein/raus.

struct GainsErrorBanner: View {
  @ObservedObject var presenter: GainsErrorPresenter

  var body: some View {
    Group {
      if let message = presenter.current {
        banner(message)
          .padding(.horizontal, GainsSpacing.m)
          .padding(.top, GainsSpacing.s)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .allowsHitTesting(presenter.current != nil)
  }

  @ViewBuilder
  private func banner(_ message: GainsErrorMessage) -> some View {
    HStack(alignment: .top, spacing: GainsSpacing.s) {
      Image(systemName: message.severity.icon)
        .font(.system(size: 17, weight: .heavy))
        .foregroundStyle(message.severity.accent)
        .padding(.top, 2)
      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text(message.title)
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)
        if let subtitle = message.subtitle {
          Text(subtitle)
            .font(GainsFont.caption)
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(3)
        }
        if let action = message.action, let actionTitle = message.actionTitle {
          Button {
            action()
            presenter.dismiss()
          } label: {
            Text(actionTitle.uppercased())
              .font(GainsFont.eyebrow)
              .tracking(GainsTracking.eyebrowTight)
              .foregroundStyle(message.severity.accent)
              .padding(.top, 4)
          }
          .buttonStyle(.plain)
        }
      }
      Spacer(minLength: 0)
      Button {
        presenter.dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 11, weight: .heavy))
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 24, height: 24)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Hinweis schließen")
    }
    .padding(GainsSpacing.s)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      // 2026-05-14 (Polish-Loop 18): Banner-Background bekommt einen
      // zweiseitigen Severity-Akzent-Glow (wie Coach-Brief und Tracker-
      // CommandBar). Der Banner liest sich jetzt eindeutig in der
      // Severity-Farbe statt nur als „Card mit Akzent-Border".
      ZStack {
        GainsColor.glassUndertone
        Rectangle().fill(.ultraThinMaterial)
        RadialGradient(
          colors: [message.severity.accent.opacity(0.22), message.severity.accent.opacity(0.04), .clear],
          center: .leading,
          startRadius: 0,
          endRadius: 220
        )
        .blendMode(.screen)
        RadialGradient(
          colors: [message.severity.accent.opacity(0.10), .clear],
          center: .trailing,
          startRadius: 0,
          endRadius: 160
        )
        .blendMode(.screen)
        LinearGradient(
          colors: [GainsColor.glassInnerLight, Color.clear],
          startPoint: .top,
          endPoint: .center
        )
      }
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(
          LinearGradient(
            colors: [message.severity.accent.opacity(0.55), message.severity.accent.opacity(0.12)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .shadow(color: message.severity.accent.opacity(0.18), radius: 16, x: 0, y: 0)
    .shadow(color: GainsColor.shadowHeroKey, radius: 14, x: 0, y: 8)
    // Swipe nach oben = Dismiss.
    .gesture(
      DragGesture(minimumDistance: 16)
        .onEnded { value in
          if value.translation.height < -24 {
            presenter.dismiss()
          }
        }
    )
  }
}
