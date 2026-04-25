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

        HStack {
          Spacer()

          Button {
            navigation.presentCapture(kind: suggestedCaptureKind)
          } label: {
            HStack(spacing: 10) {
              Image(systemName: suggestedCaptureKind.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GainsColor.onLime)
                .frame(width: 34, height: 34)
                .background(GainsColor.onLime.opacity(0.12))
                .clipShape(Circle())

              VStack(alignment: .leading, spacing: 2) {
                Text("Schnell erfassen")
                  .font(GainsFont.label(10))
                  .tracking(1.2)
                  .foregroundStyle(GainsColor.onLimeSecondary)

                Text(captureCTA)
                  .font(GainsFont.title(15))
                  .foregroundStyle(GainsColor.onLime)
                  .lineLimit(1)
              }

              Image(systemName: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(GainsColor.onLime)
            }
            .padding(.horizontal, 14)
            .frame(height: 58)
            .background(GainsColor.lime)
            .overlay(
              RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GainsColor.card.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: GainsColor.lime.opacity(0.14), radius: 12, x: 0, y: 8)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(captureCTA) erfassen")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 22)
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

  private var captureCTA: String {
    switch suggestedCaptureKind {
    case .workout:
      return "Workout"
    case .run:
      return "Lauf"
    case .progress:
      return "Fortschritt"
    case .meal:
      return "Mahlzeit"
    }
  }
}
