import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var navigation: AppNavigationStore
  @EnvironmentObject private var store: GainsStore

  var body: some View {
    ZStack {
      GainsAppBackground()

      TabView(selection: $navigation.selectedTab) {
        HomeView()
          .tag(AppTab.home)
          .tabItem {
            Label(AppTab.home.title, systemImage: "sparkles")
          }

        GymView()
          .tag(AppTab.gym)
          .tabItem {
            Label(AppTab.gym.title, systemImage: "dumbbell.fill")
          }

        WorkoutHubView()
          .tag(AppTab.run)
          .onAppear {
            navigation.preferredWorkoutWorkspace = .laufen
          }
          .tabItem {
            Label(AppTab.run.title, systemImage: "figure.run")
          }

        NutritionTrackerView()
          .tag(AppTab.recipes)
          .tabItem {
            Label(AppTab.recipes.title, systemImage: "fork.knife")
          }

        ProgressView()
          .tag(AppTab.progress)
          .tabItem {
            Label(AppTab.progress.title, systemImage: "heart.text.square.fill")
          }

        CommunityView(viewModel: CommunityViewModel.mock)
          .tag(AppTab.community)
          .tabItem {
            Label(AppTab.community.title, systemImage: "person.2.wave.2.fill")
          }
      }

    }
    .tint(GainsColor.lime)
    .toolbarBackground(GainsColor.card.opacity(0.94), for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
    .sheet(
      item: Binding(
        get: { navigation.pendingCaptureKind },
        set: { navigation.pendingCaptureKind = $0 }
      )
    ) { kind in
      NavigationStack {
        CaptureSheet(initialKind: kind)
          .environmentObject(store)
          .environmentObject(navigation)
      }
      .presentationDetents([.large])
    }
  }

}
