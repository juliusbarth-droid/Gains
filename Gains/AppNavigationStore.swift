import SwiftUI

/// Zentraler Navigations-State für die Tab-Bar und die globalen Sheets
/// (Capture, Gym-Sub-Tab-Sprünge). Hält nichts, was nur lokal in einer
/// einzigen View interessiert — solche States bleiben in der jeweiligen View.
final class AppNavigationStore: ObservableObject {
  @Published var selectedTab: AppTab = .home
  @Published var pendingCaptureKind: CaptureKind?
  @Published var pendingGymTab: GymTab?

  /// Wechselt in den Trainings-Tab. `kraft` öffnet das Gym, `laufen` den
  /// Lauf-Hub. Default ist Kraft, weil der Home-Screen primär ins Gym
  /// verlinkt.
  func openTraining(workspace: AppWorkoutWorkspace = .kraft) {
    switch workspace {
    case .laufen:
      selectedTab = .run
    case .kraft:
      selectedTab = .gym
    }
  }

  /// Springt direkt in den PLAN-Sub-Tab des Gym-Bereichs.
  func openPlanner() {
    pendingGymTab = .plan
    selectedTab = .gym
  }

  /// Öffnet das globale Capture-Sheet mit dem gewünschten Inhaltstyp.
  func presentCapture(kind: CaptureKind = .workout) {
    pendingCaptureKind = kind
  }

  /// Öffnet Community vorerst nicht mehr über einen eigenen Tab, sondern
  /// fällt auf Home zurück, damit Navigation nie auf einen versteckten
  /// Zielzustand zeigt.
  func openCommunity() {
    selectedTab = .home
  }
}
