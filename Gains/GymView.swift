import SwiftUI

// MARK: - GymTab
//
// Vier Tabs des Gym-Bereichs. Jeder Tab ist in eine eigene SwiftUI-View
// extrahiert (`GymTodayTab`, `GymWorkoutsTab`, `GymPlanTab`, `GymStatsTab`),
// damit dieses File schlank bleibt und die Tabs unabhängig wachsen können.

enum GymTab: String, CaseIterable {
  case heute    = "HEUTE"
  case workouts = "WORKOUTS"
  case plan     = "PLAN"
  case stats    = "STATS"
}

// MARK: - GymView
//
// Schlanke Hülle: Header + Tab-Picker + delegierte Subview-Tabs. Sheets, die
// von mehreren Tabs gemeinsam genutzt werden (Workout-Tracker, Workout-
// Builder, Plan-Wizard, Übungs-Historie), bleiben hier zentralisiert
// — die Sub-Tabs erhalten Bindings.

struct GymView: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore

  @State private var selectedTab: GymTab = .heute
  @State private var isShowingWorkoutTracker = false
  @State private var isShowingWorkoutBuilder = false
  @State private var showsPlanWizard = false
  @State private var showsCustomPlanBuilder = false
  @State private var workoutToEdit: WorkoutPlan? = nil
  @State private var historyExerciseRef: ExerciseHistoryRef? = nil

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 20) {
        screenHeader(
          eyebrow: "GYM / KRAFT",
          title: gymHeaderTitle
        )

        tabPicker

        switch selectedTab {
        case .heute:
          GymTodayTab(
            selectedTab: $selectedTab,
            isShowingWorkoutTracker: $isShowingWorkoutTracker,
            isShowingWorkoutBuilder: $isShowingWorkoutBuilder,
            showsPlanWizard: $showsPlanWizard
          )
        case .workouts:
          GymWorkoutsTab(
            isShowingWorkoutBuilder: $isShowingWorkoutBuilder,
            isShowingWorkoutTracker: $isShowingWorkoutTracker,
            workoutToEdit: $workoutToEdit
          )
        case .plan:
          GymPlanTab(
            showsPlanWizard: $showsPlanWizard,
            showsCustomPlanBuilder: $showsCustomPlanBuilder
          )
        case .stats:
          GymStatsTab(
            historyExerciseName: Binding(
              get: { historyExerciseRef?.name },
              set: { historyExerciseRef = $0.map { ExerciseHistoryRef(name: $0) } }
            )
          )
        }
      }
    }
    .onAppear { applyPendingNavigation() }
    .onChange(of: navigation.pendingGymTab) { _, _ in applyPendingNavigation() }
    .sheet(isPresented: $isShowingWorkoutTracker) {
      WorkoutTrackerView()
        .environmentObject(store)
    }
    .sheet(isPresented: $isShowingWorkoutBuilder) {
      WorkoutBuilderView()
        .environmentObject(store)
    }
    .sheet(item: $workoutToEdit) { plan in
      WorkoutBuilderView(editingPlan: plan)
        .environmentObject(store)
    }
    .sheet(isPresented: $showsPlanWizard) {
      GymPlanWizardSheet(settings: store.plannerSettings)
        .environmentObject(store)
    }
    .sheet(isPresented: $showsCustomPlanBuilder) {
      CustomPlanBuilderSheet()
        .environmentObject(store)
    }
    .sheet(item: $historyExerciseRef) { ref in
      NavigationStack {
        GymExerciseHistorySheet(exerciseName: ref.name)
          .environmentObject(store)
      }
      .presentationDetents([.large])
    }
  }

  // MARK: - Header

  private var gymHeaderTitle: String {
    if let activeWorkout = store.activeWorkout {
      return activeWorkout.title.uppercased()
    }

    let day = store.todayPlannedDay
    switch day.status {
    case .planned:
      if let workout = day.workoutPlan {
        return workout.title.uppercased()
      }
      return "KRAFT HEUTE"
    case .rest:
      return "Freier Tag"
    case .flexible:
      return "Flex Day"
    }
  }

  // MARK: - Tab Picker

  private var tabPicker: some View {
    // Vorher waren die vier Tabs nur durch ihren Hintergrund (lime für aktiv,
    // sonst transparent auf gleicher card-Farbe) getrennt — die inaktiven Tabs
    // sind dadurch optisch verschmolzen und der Container hatte keinen Rand
    // gegenüber dem Bildschirmhintergrund. Hier:
    //   • feiner Container-Stroke setzt den Picker als ein Element ab,
    //   • Hairline-Trenner zwischen Tabs grenzen die Slots klar ab,
    //   • Trenner blenden aus, sobald sie an die aktive Pille grenzen,
    //   • reduziertes Tracking (1.6 → 1.3) verhindert, dass „WORKOUTS" auf
    //     schmalen Geräten an die Pillen-Kante stößt,
    //   • etwas mehr Höhe (38 → 42) für ein komfortableres Tap-Target.
    HStack(spacing: 0) {
      ForEach(Array(GymTab.allCases.enumerated()), id: \.element) { index, tab in
        let isActive = selectedTab == tab
        let isNextActive =
          index < GymTab.allCases.count - 1
          && selectedTab == GymTab.allCases[index + 1]
        let showsTrailingDivider =
          index < GymTab.allCases.count - 1 && !isActive && !isNextActive

        Button {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            selectedTab = tab
          }
        } label: {
          Text(tab.rawValue)
            .font(GainsFont.label(10))
            .tracking(1.3)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.softInk)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .padding(.horizontal, 4)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive ? GainsColor.lime : Color.clear)
            )
            .overlay(alignment: .trailing) {
              if showsTrailingDivider {
                Rectangle()
                  .fill(GainsColor.border.opacity(0.45))
                  .frame(width: 1, height: 20)
                  // Trenner sitzt visuell zwischen den Tabs (Hälfte des
                  // Trenners ragt in den nächsten Slot — bei spacing 0 ergibt
                  // das eine saubere Mittellinie).
                  .offset(x: 0.5)
                  .transition(.opacity)
              }
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.rawValue.capitalized)
        .accessibilityAddTraits(isActive ? .isSelected : [])
      }
    }
    .padding(4)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  // MARK: - Navigation

  private func applyPendingNavigation() {
    if let pending = navigation.pendingGymTab {
      selectedTab = pending
      navigation.pendingGymTab = nil
    }
  }
}

// MARK: - ExerciseHistoryRef
//
// Identifiable-Wrapper, damit `.sheet(item:)` mit dem optionalen
// String-Übungsnamen aus dem STATS-Tab funktioniert.
struct ExerciseHistoryRef: Identifiable {
  let name: String
  var id: String { name }
}
