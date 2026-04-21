import SwiftUI

final class AppNavigationStore: ObservableObject {
  @Published var selectedTab: AppTab = .home
  @Published var preferredWorkoutWorkspace: AppWorkoutWorkspace = .kraft

  func openTraining(workspace: AppWorkoutWorkspace = .kraft) {
    preferredWorkoutWorkspace = workspace
    selectedTab = .workout
  }
}
