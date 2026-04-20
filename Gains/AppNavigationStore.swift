import SwiftUI

final class AppNavigationStore: ObservableObject {
  @Published var selectedTab: AppTab = .home

  func openTraining() {
    selectedTab = .workout
  }
}
