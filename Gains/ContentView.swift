import SwiftUI
import UIKit

struct ContentView: View {
  @EnvironmentObject private var navigation: AppNavigationStore
  @EnvironmentObject private var store: GainsStore

  init() {
    // A8: Tab-Bar-Appearance global konfigurieren — kompromisslos dark,
    // mit Hairline-Top-Border in Lime-Tönung, damit der TabBar-Bereich wie
    // ein HUD-Footer wirkt.
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(GainsColor.card).withAlphaComponent(0.92)
    appearance.shadowColor = UIColor(GainsColor.lime).withAlphaComponent(0.35)

    let itemAppearance = UITabBarItemAppearance()
    itemAppearance.normal.iconColor = UIColor(GainsColor.softInk)
    itemAppearance.normal.titleTextAttributes = [
      .foregroundColor: UIColor(GainsColor.softInk),
      .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
    ]
    itemAppearance.selected.iconColor = UIColor(GainsColor.lime)
    itemAppearance.selected.titleTextAttributes = [
      .foregroundColor: UIColor(GainsColor.lime),
      .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .semibold)
    ]
    appearance.stackedLayoutAppearance = itemAppearance
    appearance.inlineLayoutAppearance = itemAppearance
    appearance.compactInlineLayoutAppearance = itemAppearance

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
  }

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
          .tabItem {
            Label(AppTab.run.title, systemImage: "figure.run")
          }

        NutritionTrackerView()
          .tag(AppTab.nutrition)
          .tabItem {
            Label(AppTab.nutrition.title, systemImage: "fork.knife")
          }

        // Fortschritt-Tab entfernt: Fortschritt ist jetzt nur noch über
        // den Home-Screen erreichbar (aufklappbarer Bereich), damit der
        // Tab-Bar fokussierter bleibt und Details nur auf Klick erscheinen.

        CommunityView(viewModel: CommunityViewModel.mock)
          .tag(AppTab.community)
          .tabItem {
            Label(AppTab.community.title, systemImage: "person.2.wave.2.fill")
          }
      }

    }
    .tint(GainsColor.lime)
    .toolbarBackground(GainsColor.card.opacity(0.92), for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
    .toolbarColorScheme(.dark, for: .tabBar)
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
