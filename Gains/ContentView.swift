import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var navigation: AppNavigationStore
  @EnvironmentObject private var store: GainsStore

  var body: some View {
    ZStack {
      GainsAppBackground()

      TabView(selection: $navigation.selectedTab) {
        HomeView(viewModel: .mock)
          .tag(AppTab.home)
          .tabItem {
            Label(AppTab.home.title, systemImage: "sparkles")
          }

        WorkoutHubView(viewModel: .mock)
          .tag(AppTab.workout)
          .tabItem {
            Label(AppTab.workout.title, systemImage: "dumbbell.fill")
          }

        RecipesView(viewModel: .mock)
          .tag(AppTab.recipes)
          .tabItem {
            Label(AppTab.recipes.title, systemImage: "fork.knife")
          }

        ProgressView(viewModel: .mock)
          .tag(AppTab.progress)
          .tabItem {
            Label(AppTab.progress.title, systemImage: "heart.text.square.fill")
          }

        CommunityView(viewModel: .mock)
          .tag(AppTab.community)
          .tabItem {
            Label(AppTab.community.title, systemImage: "person.3.fill")
          }
      }

      VStack {
        Spacer()

        Button {
          navigation.presentCapture(kind: suggestedCaptureKind)
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(GainsColor.onLime)
            .frame(width: 54, height: 54)
            .background(GainsColor.lime)
            .overlay {
              Circle()
                .stroke(GainsColor.card, lineWidth: 5)
            }
            .overlay {
              Circle()
                .stroke(GainsColor.lime.opacity(0.45), lineWidth: 1)
            }
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture öffnen")
        .padding(.bottom, 42)
      }
      .allowsHitTesting(true)
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

  private var suggestedCaptureKind: CaptureKind {
    switch navigation.selectedTab {
    case .home:
      let lastRunDate = store.latestCompletedRun?.finishedAt ?? Date.distantPast
      let lastWorkoutDate = store.latestCompletedWorkout?.finishedAt ?? Date.distantPast
      return lastRunDate > lastWorkoutDate ? .run : .workout
    case .workout:
      return .workout
    case .recipes:
      return .meal
    case .progress:
      return .progress
    case .community:
      return .workout
    }
  }
}
