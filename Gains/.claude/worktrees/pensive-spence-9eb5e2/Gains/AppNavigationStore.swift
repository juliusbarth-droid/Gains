import SwiftUI

/// Zentraler Navigations-State für die Tab-Bar und die globalen Sheets
/// (Capture, Gym-Sub-Tab-Sprünge). Hält nichts, was nur lokal in einer
/// einzigen View interessiert — solche States bleiben in der jeweiligen View.
///
/// H2-Fix (2026-05-01): Tab-Wechsel und Sheet-Präsentation müssen atomar
/// sein, sonst kann ein offenes Capture-Sheet über einem frisch
/// gewechselten Tab hängen bleiben (Race-Condition zwischen TabView-
/// Animation und sheet(item:)). Alle Tab-Wechsel laufen jetzt durch
/// `dismissOverlays()` und `goToTab(_:)`, die sauber in einer Transaktion
/// State setzen. `presentCapture` rendert auf dem AKTUELLEN Tab, weil das
/// User-erwartet ist (Home → Mahlzeit-Capture → Foto auf Home-Background).
final class AppNavigationStore: ObservableObject {
  @Published var selectedTab: AppTab = .home
  @Published var pendingCaptureKind: CaptureKind?
  @Published var pendingGymTab: GymTab?

  /// Setzt alle globalen Sheet-/Sub-Tab-States zurück. Wird vor jedem
  /// Tab-Wechsel aufgerufen, damit kein altes Overlay (Capture-Sheet,
  /// Gym-Sub-Tab-Sprung) auf dem Ziel-Tab landet.
  private func dismissOverlays() {
    if pendingCaptureKind != nil { pendingCaptureKind = nil }
    if pendingGymTab != nil { pendingGymTab = nil }
  }

  /// Wechselt in den Trainings-Tab. `kraft` öffnet das Gym, `laufen` den
  /// Lauf-Hub. Default ist Kraft, weil der Home-Screen primär ins Gym
  /// verlinkt.
  func openTraining(workspace: AppWorkoutWorkspace = .kraft) {
    dismissOverlays()
    switch workspace {
    case .laufen:
      selectedTab = .run
    case .kraft:
      selectedTab = .gym
    }
  }

  /// Springt direkt in den PLAN-Sub-Tab des Gym-Bereichs.
  func openPlanner() {
    dismissOverlays()
    pendingGymTab = .plan
    selectedTab = .gym
  }

  /// Wechselt in den Ernährungs-Tab — wird vom Home-Screen aus über die
  /// Tap-Zone der Nutrition-Card aufgerufen.
  func openNutrition() {
    dismissOverlays()
    selectedTab = .nutrition
  }

  /// Öffnet das globale Capture-Sheet mit dem gewünschten Inhaltstyp.
  /// Räumt vorher alte Overlay-/Sub-Tab-Reste weg, rendert aber weiterhin
  /// auf dem aktuellen Tab.
  func presentCapture(kind: CaptureKind = .workout) {
    dismissOverlays()
    pendingCaptureKind = kind
  }

  /// Reagiert auf Tab-Wechsel, die der User selbst über die TabBar auslöst
  /// (nicht über die Helper). Räumt Overlay-/Sub-Tab-Reste weg, lässt aber
  /// einen absichtlich gesetzten Gym-Sub-Tab-Sprung nur dann in Ruhe, wenn
  /// der User tatsächlich in den Gym-Tab wechselt.
  func handleManualTabChange(to newTab: AppTab) {
    if pendingGymTab != nil, newTab == .gym {
      return
    }
    dismissOverlays()
  }

  // openCommunity() entfernt (2026-05-01 Phase 4): Der Community-Tab ist
  // aus der TabBar genommen; ein Helper, der „Community öffnen" verspricht
  // aber stillschweigend auf Home redirectet, war funktional irreführend.
  // Sobald Phase B Community reaktiviert (`AppTab.community` zurück in der
  // TabBar), kommt hier ein echter Helper rein, der `selectedTab = .community`
  // setzt.
}
