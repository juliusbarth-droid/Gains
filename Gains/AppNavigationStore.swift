import SwiftUI

final class AppNavigationStore: ObservableObject {
  @Published var selectedTab: AppTab = .home
  @Published var preferredWorkoutWorkspace: AppWorkoutWorkspace = .kraft
  @Published var pendingCaptureKind: CaptureKind?

  func openTraining(workspace: AppWorkoutWorkspace = .kraft) {
    preferredWorkoutWorkspace = workspace
    selectedTab = workspace == .laufen ? .run : .gym
  }

  func presentCapture(kind: CaptureKind = .workout) {
    pendingCaptureKind = kind
  }
}
