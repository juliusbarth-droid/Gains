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
            HStack(spacing: 12) {
              ZStack {
                Circle()
                  .fill(GainsColor.onLime.opacity(0.16))
                  .frame(width: 38, height: 38)

                Image(systemName: suggestedCaptureKind.systemImage)
                  .font(.system(size: 15, weight: .semibold))
                  .foregroundStyle(GainsColor.onLime)
              }

              VStack(alignment: .leading, spacing: 3) {
                Text("Schnell erfassen")
                  .font(GainsFont.label(10))
                  .tracking(1.4)
                  .foregroundStyle(GainsColor.onLimeSecondary)

                Text(captureCTA)
                  .font(GainsFont.title(16))
                  .foregroundStyle(GainsColor.onLime)
                  .lineLimit(1)
              }

              Spacer(minLength: 8)

              ZStack {
                Circle()
                  .fill(GainsColor.card.opacity(0.22))
                  .frame(width: 30, height: 30)

                Image(systemName: "plus")
                  .font(.system(size: 12, weight: .bold))
                  .foregroundStyle(GainsColor.onLime)
              }
            }
            .padding(.horizontal, 16)
            .frame(width: 188, height: 62)
            .background(
              LinearGradient(
                colors: [GainsColor.lime, GainsColor.lime.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .overlay(alignment: .topTrailing) {
              Circle()
                .fill(GainsColor.card.opacity(0.18))
                .frame(width: 52, height: 52)
                .blur(radius: 10)
                .offset(x: 8, y: -8)
            }
            .overlay(
              RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(GainsColor.card.opacity(0.55), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: GainsColor.lime.opacity(0.16), radius: 14, x: 0, y: 10)
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
