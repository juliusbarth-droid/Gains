import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var navigation: AppNavigationStore

  var body: some View {
    ZStack {
      GainsAppBackground()

      TabView(selection: $navigation.selectedTab) {
        HomeView(viewModel: .mock)
          .tag(AppTab.home)
          .tabItem {
            Label("Home", systemImage: "house.fill")
          }

        WorkoutHubView(viewModel: .mock)
          .tag(AppTab.workout)
          .tabItem {
            Label("Training", systemImage: "dumbbell.fill")
          }

        RecipesView(viewModel: .mock)
          .tag(AppTab.recipes)
          .tabItem {
            Label("Ernährung", systemImage: "fork.knife")
          }

        ProgressView(viewModel: .mock)
          .tag(AppTab.progress)
          .tabItem {
            Label("Fortschritt", systemImage: "chart.line.uptrend.xyaxis")
          }

        CommunityView(viewModel: .mock)
          .tag(AppTab.community)
          .tabItem {
            Label("Community", systemImage: "person.3.fill")
          }
      }
    }
    .tint(GainsColor.lime)
    .toolbarBackground(GainsColor.card.opacity(0.94), for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
  }
}
