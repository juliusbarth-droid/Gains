import SwiftUI

final class AppNavigationStore: ObservableObject {
  @Published var selectedTab: AppTab = .home
  @Published var preferredWorkoutWorkspace: AppWorkoutWorkspace = .kraft
  @Published var pendingCaptureKind: CaptureKind?
  @Published var pendingGymTab: GymTab?

  func openTraining(workspace: AppWorkoutWorkspace = .kraft) {
    preferredWorkoutWorkspace = workspace
    switch workspace {
    case .laufen:
      selectedTab = .run
    case .fortschritt:
      // Eine vereinheitlichte Wochenplanung lebt im Gym-Tab → PLAN-Sub-Tab
      pendingGymTab = .plan
      selectedTab = .gym
    case .kraft:
      selectedTab = .gym
    }
  }

  func openPlanner() {
    pendingGymTab = .plan
    selectedTab = .gym
  }

  func presentCapture(kind: CaptureKind = .workout) {
    pendingCaptureKind = kind
  }
}
