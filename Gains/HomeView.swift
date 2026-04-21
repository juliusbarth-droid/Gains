import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var navigation: AppNavigationStore
  @EnvironmentObject private var store: GainsStore
  let viewModel: HomeViewModel
  @State private var isShowingWorkoutChooser = false
  @State private var isShowingWorkoutBuilder = false
  @State private var isShowingWorkoutTracker = false
  @State private var isShowingRunTracker = false
  @State private var isShowingProfile = false
  @State private var isShowingCoach = false
  @State private var isShowingProgress = false
  @State private var showsTodayDetails = false
  @State private var showsWeeklyInsights = false
  @State private var showsSupportTools = false
  @State private var showsWeeklyPlan = false
  @State private var showsQuickActions = false

  var body: some View {
    ZStack {
      GainsAppBackground()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 22) {
          topBar
          titleBlock
          collapsibleSection(
            title: "Schnell starten",
            subtitle: "Gym, Run und Mahlzeiten direkt erreichbar, aber nicht dauerhaft so dominant",
            isExpanded: $showsQuickActions,
            content: { quickActionStrip }
          )
          todaySection
          collapsibleSection(
            title: "Wochenplan und Streak",
            subtitle: "Kalender, Routine und Wochenstruktur nur dann aufklappen, wenn du sie brauchst",
            isExpanded: $showsWeeklyPlan,
            content: { plannerSectionContent }
          )
          collapsibleSection(
            title: "Fortschritt im Blick",
            subtitle: "KPIs, Check-ins und Health kompakter halten",
            isExpanded: $showsWeeklyInsights,
            content: { insightsSectionContent }
          )
          collapsibleSection(
            title: "Coach, Community und Extras",
            subtitle: "Wichtige Zusatzfunktionen bleiben da, aber stören den Flow nicht",
            isExpanded: $showsSupportTools,
            content: { supportSectionContent }
          )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 28)
      }
    }
    .sheet(isPresented: $isShowingWorkoutChooser) {
      NavigationStack {
        WorkoutStartSheet(
          plannedWorkout: store.todayPlannedWorkout,
          customWorkouts: store.customWorkoutPlans,
          onSelectWorkout: { plan in
            launchWorkout(plan)
          },
          onCreateWorkout: {
            isShowingWorkoutChooser = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
              isShowingWorkoutBuilder = true
            }
          }
        )
        .environmentObject(store)
      }
    }
    .sheet(isPresented: $isShowingWorkoutBuilder) {
      WorkoutBuilderView { workout in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
          launchWorkout(workout)
        }
      }
      .environmentObject(store)
    }
    .sheet(isPresented: $isShowingWorkoutTracker) {
      WorkoutTrackerView()
        .environmentObject(store)
    }
    .sheet(isPresented: $isShowingRunTracker) {
      RunTrackerView()
        .environmentObject(store)
    }
    .sheet(isPresented: $isShowingProfile) {
      NavigationStack {
        ProfileView()
          .environmentObject(store)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Fertig") {
                isShowingProfile = false
              }
              .foregroundStyle(GainsColor.ink)
            }
          }
      }
    }
    .sheet(isPresented: $isShowingCoach) {
      NavigationStack {
        CoachView(viewModel: .mock)
          .environmentObject(store)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Fertig") { isShowingCoach = false }
                .foregroundStyle(GainsColor.ink)
            }
          }
      }
    }
    .sheet(isPresented: $isShowingProgress) {
      NavigationStack {
        ProgressView(viewModel: .mock)
          .environmentObject(store)
          .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
              Button("Fertig") {
                isShowingProgress = false
              }
              .foregroundStyle(GainsColor.ink)
            }
          }
      }
    }
  }

  private var todaySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("HEUTE", "FOKUS")

      Text("Was ist heute dran?")
        .font(GainsFont.title(24))
        .foregroundStyle(GainsColor.ink)

      focusStatusRow

      HStack(spacing: 10) {
        homeLauncherCard(
          title: "Krafttraining",
          icon: "dumbbell.fill",
          accent: GainsColor.ink,
          action: startOrResumeWorkout,
          footerTitle: store.activeWorkout != nil ? "Aktives Workout" : "Letztes Workout",
          footerText: strengthFooterText,
          emphasis: .primary
        )

        homeLauncherCard(
          title: "Running",
          icon: "figure.run",
          accent: GainsColor.moss,
          action: startOrResumeRun,
          footerTitle: store.activeRun != nil ? "Aktiver Lauf" : "Letzter Lauf",
          footerText: runningFooterText,
          emphasis: .secondary
        )
      }

      Button {
        navigation.openTraining(workspace: .kraft)
      } label: {
        HStack(spacing: 10) {
          Text("Trainingsbereich öffnen")
            .font(GainsFont.label(11))
            .tracking(1.6)
            .foregroundStyle(GainsColor.ink)

          Spacer()

          Image(systemName: showsTodayDetails ? "chevron.up" : "arrow.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GainsColor.ink)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(GainsColor.lime)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)

      todayWorkoutCard
      workoutStatusCard

      if showsTodayDetails {
        todayDetailStack
      }

      Button {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
          showsTodayDetails.toggle()
        }
      } label: {
        Text(showsTodayDetails ? "Weniger anzeigen" : "Mehr für heute anzeigen")
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity)
          .frame(height: 40)
          .background(GainsColor.card)
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(GainsColor.border.opacity(0.8), lineWidth: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  private var topBar: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 12) {
        GainsWordmark(size: 36)

        Text("Let's go, \(viewModel.userName).")
          .font(GainsFont.title(28))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.75)
          .padding(.top, 2)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(GainsColor.elevated.opacity(0.82))
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(GainsColor.border.opacity(0.78), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

      Spacer()

      Button {
        isShowingProfile = true
      } label: {
        Circle()
          .fill(GainsColor.elevated)
          .frame(width: 42, height: 42)
          .overlay(
            Circle()
              .stroke(GainsColor.border.opacity(0.8), lineWidth: 1)
          )
          .overlay {
            Text(String(viewModel.userName.prefix(1)))
              .font(GainsFont.label(14))
              .foregroundStyle(GainsColor.ink)
          }
      }
      .buttonStyle(.plain)
    }
  }

  private var titleBlock: some View {
    VStack(alignment: .leading, spacing: 8) {
      SlashLabel(
        parts: [currentDateParts.day, currentDateParts.date, currentDateParts.week],
        primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(GainsColor.card.opacity(0.78))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(GainsColor.border.opacity(0.75), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    .padding(.top, 2)
  }

  private var streakCard: some View {
    Button {
      store.showCurrentCalendarWeek()
      store.selectCalendarDay(Date())
    } label: {
      VStack(alignment: .leading, spacing: 18) {
        SlashLabel(
          parts: ["STREAK", "ACTIVE", "PUSHING"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.card.opacity(0.72))

        HStack(alignment: .bottom, spacing: 16) {
          Text("\(store.streakDays)")
            .font(GainsFont.display(118))
            .foregroundStyle(GainsColor.card)
            .tracking(-4)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

          VStack(alignment: .leading, spacing: 14) {
            Text("tage in folge")
              .font(GainsFont.label())
              .foregroundStyle(GainsColor.card.opacity(0.8))
              .textCase(.lowercase)

            Divider()
              .overlay(GainsColor.card.opacity(0.18))

            VStack(alignment: .leading, spacing: 6) {
              Text("BIS REKORD")
                .font(GainsFont.label(10))
                .tracking(3)
                .foregroundStyle(GainsColor.card.opacity(0.68))

              Text("+ \(max(store.recordDays - store.streakDays, 0))")
                .font(GainsFont.display(28))
                .foregroundStyle(GainsColor.lime)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.bottom, 18)
        }

        VStack(spacing: 8) {
          GeometryReader { proxy in
            let progress = min(Double(store.streakDays) / Double(max(store.recordDays, 1)), 1)

            ZStack(alignment: .leading) {
              Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(height: 4)

              Capsule()
                .fill(GainsColor.lime)
                .frame(width: proxy.size.width * progress, height: 4)
            }
          }
          .frame(height: 4)

          HStack {
            Text("\(store.streakDays)")
            Spacer()
            Text("\(store.recordDays)")
          }
          .font(GainsFont.label())
          .foregroundStyle(GainsColor.card.opacity(0.75))
        }
      }
      .padding(22)
      .background(GainsColor.ink)
      .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var insightsSectionContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Button {
          isShowingProgress = true
        } label: {
          StatCard(
            title: "WOCHE",
            value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)",
            valueAccent: true,
            subtitle: "Sessions",
            background: GainsColor.card,
            foreground: GainsColor.ink
          )
        }
        .buttonStyle(.plain)

        Button {
          isShowingProgress = true
        } label: {
          StatCard(
            title: "VOLUMEN",
            value: String(format: "%.1f T", store.weeklyVolumeTons),
            valueAccent: false,
            subtitle: "Kilogramm",
            background: GainsColor.card,
            foreground: GainsColor.ink
          )
        }
        .buttonStyle(.plain)

        Button {
          isShowingProgress = true
        } label: {
          StatCard(
            title: "PRs",
            value: "+ \(store.personalRecordCount)",
            valueAccent: false,
            subtitle: "Neue Rekorde",
            background: GainsColor.lime,
            foreground: GainsColor.moss
          )
        }
        .buttonStyle(.plain)
      }

      progressSnapshotCard
      quickCheckInsRow
    }
  }

  private var todayWorkoutCard: some View {
    let plan = store.todayPlannedWorkout ?? store.currentWorkoutPreview

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          Text(plan.title.uppercased())
            .font(GainsFont.display(26))
            .foregroundStyle(GainsColor.ink)

          SlashLabel(
            parts: [
              "\(plan.exercises.count) ÜBUNGEN",
              "\(store.plannerSettings.preferredSessionLength) MIN", plan.focus.uppercased(),
            ],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )
        }

        Spacer()

        VStack(spacing: 10) {
          Button(action: startOrResumeWorkout) {
            Text(store.activeWorkout == nil ? "START →" : "WEITER →")
              .font(GainsFont.label())
              .tracking(1.8)
              .foregroundStyle(GainsColor.lime)
              .frame(width: 104, height: 48)
              .background(GainsColor.ink)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)

          GainsDisclosureIndicator()
        }
      }
      .padding(18)
      .gainsInteractiveCardStyle()
      .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .onTapGesture(perform: startOrResumeWorkout)
    }
  }

  @ViewBuilder
  private var workoutStatusCard: some View {
    if let activeWorkout = store.activeWorkout {
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 12) {
          Text("\(activeWorkout.completedSets)/\(activeWorkout.totalSets) Sätze erledigt")
            .font(GainsFont.title(22))
            .foregroundStyle(GainsColor.ink)

          Text("Volumen aktuell: \(Int(activeWorkout.totalVolume)) kg")
            .font(GainsFont.body())
            .foregroundStyle(GainsColor.softInk)

          Button(action: startOrResumeWorkout) {
            Text("Workout weiter tracken")
              .font(GainsFont.label(12))
              .tracking(1.4)
              .foregroundStyle(GainsColor.lime)
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .background(GainsColor.ink)
              .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          }
          .buttonStyle(.plain)
        }
        .padding(18)
        .gainsCardStyle()
      }
    } else if let lastWorkout = store.lastCompletedWorkout {
      VStack(alignment: .leading, spacing: 12) {
        Button(action: startOrResumeWorkout) {
          VStack(alignment: .leading, spacing: 10) {
            Text(lastWorkout.title)
              .font(GainsFont.title(22))
              .foregroundStyle(GainsColor.ink)

            Text(
              "\(lastWorkout.completedSets)/\(lastWorkout.totalSets) Sets abgeschlossen · \(Int(lastWorkout.volume)) kg Volumen"
            )
            .font(GainsFont.body())
            .foregroundStyle(GainsColor.onLimeSecondary)
          }
          .padding(18)
          .gainsCardStyle(GainsColor.lime.opacity(0.55))
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var progressSnapshotCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 10) {
          Text("KÖRPER")
            .font(GainsFont.label(10))
            .tracking(2.8)
            .foregroundStyle(GainsColor.softInk)

          Text(String(format: "%.1f kg", store.currentWeight))
            .font(GainsFont.display(32))
            .foregroundStyle(GainsColor.ink)

          Text(String(format: "%.1f kg seit Start", store.startingWeight - store.currentWeight))
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 10) {
          GainsDisclosureIndicator()

          Text("HEALTH")
            .font(GainsFont.label(10))
            .tracking(2.8)
            .foregroundStyle(GainsColor.moss)

          Text("-\(store.currentCardioRiskImprovement)%")
            .font(GainsFont.display(32))
            .foregroundStyle(GainsColor.moss)

          Text(store.currentBloodPanelStatus)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.moss.opacity(0.9))
            .multilineTextAlignment(.trailing)
        }
      }

      Divider()
        .overlay(GainsColor.border.opacity(0.6))

      VStack(alignment: .leading, spacing: 8) {
        Text(store.lastProgressEvent)
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)

        Text("\(store.goalCompletionCount) von \(store.currentGoals.count) Zielen erfüllt")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      Button {
        isShowingProgress = true
      } label: {
        Text("Fortschritt öffnen")
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(GainsColor.lime)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(GainsColor.ink)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(18)
    .gainsInteractiveCardStyle()
    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .onTapGesture {
      isShowingProgress = true
    }
  }

  private var quickCheckInsRow: some View {
    HStack(spacing: 10) {
      Button {
        store.logWeightCheckIn()
      } label: {
        quickCheckInButton(title: "Wiegen", icon: "scalemass")
      }
      .buttonStyle(.plain)

      Button {
        store.logWaistCheckIn()
      } label: {
        quickCheckInButton(title: "Taille", icon: "ruler")
      }
      .buttonStyle(.plain)

      Button {
        store.logProteinCheckIn()
      } label: {
        quickCheckInButton(title: "Protein", icon: "fork.knife")
      }
      .buttonStyle(.plain)

      Button {
        store.syncVitalData()
      } label: {
        quickCheckInButton(title: "Vitals", icon: "heart.fill")
      }
      .buttonStyle(.plain)
    }
  }

  private var plannerSectionContent: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionLabel("WOCHE", "PLANEN")

      VStack(alignment: .leading, spacing: 14) {
        streakCard
        weekStrip
      }
    }
  }

  private var supportSectionContent: some View {
    HStack(alignment: .top, spacing: 12) {
      Button {
        isShowingCoach = true
      } label: {
        VStack(alignment: .leading, spacing: 12) {
          Text("COACH")
            .font(GainsFont.label(10))
            .tracking(2.4)
            .foregroundStyle(GainsColor.softInk)

          Text(store.coachHeadline)
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)

          Text(store.coachDescription)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)

          Spacer(minLength: 0)

          Text("Coach öffnen")
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(GainsColor.lime)
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .padding(18)
        .gainsCardStyle()
      }
      .buttonStyle(.plain)

      Button {
        store.shareProgressUpdate()
      } label: {
        VStack(alignment: .leading, spacing: 12) {
          Text("COMMUNITY")
            .font(GainsFont.label(10))
            .tracking(2.4)
            .foregroundStyle(GainsColor.onLimeSecondary)

          Text(store.communityHighlightHeadline)
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.onLime)

          Text(store.communityHighlightDescription)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.onLimeSecondary)

          Spacer(minLength: 0)

          Text("Update teilen")
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(GainsColor.onLime)
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .padding(18)
        .gainsCardStyle(GainsColor.lime.opacity(0.85))
      }
      .buttonStyle(.plain)
    }
  }

  private var focusStatusRow: some View {
    HStack(spacing: 10) {
      compactMetric(title: "Heute", value: store.todayPlannedWorkout?.title ?? "Flex Day", subtitle: "aktueller Fokus")
      compactMetric(title: "Woche", value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount)", subtitle: "Sessions")
      compactMetric(title: "Protein", value: "\(store.nutritionProteinToday) g", subtitle: "heute")
    }
  }

  private var quickActionStrip: some View {
    HStack(spacing: 10) {
      quickActionTile(
        title: store.activeWorkout == nil ? "Gym" : "Workout live",
        subtitle: store.activeWorkout == nil ? "Schnell starten" : "Direkt fortsetzen",
        icon: "dumbbell.fill",
        background: GainsColor.lime.opacity(0.78),
        foreground: GainsColor.moss
      ) {
        navigation.openTraining(workspace: .kraft)
        startOrResumeWorkout()
      }

      quickActionTile(
        title: store.activeRun == nil ? "Run" : "Run live",
        subtitle: store.activeRun == nil ? "Cardio starten" : "Tracker öffnen",
        icon: "figure.run",
        background: GainsColor.card,
        foreground: GainsColor.ink
      ) {
        navigation.openTraining(workspace: .laufen)
        startOrResumeRun()
      }

      quickActionTile(
        title: "Mahlzeit",
        subtitle: "Tracken",
        icon: "fork.knife",
        background: GainsColor.card,
        foreground: GainsColor.ink
      ) {
        navigation.selectedTab = .recipes
      }
    }
  }

  private var todayDetailStack: some View {
    VStack(alignment: .leading, spacing: 12) {
      if !store.nutritionEntries(for: .breakfast).isEmpty
        || !store.nutritionEntries(for: .lunchDinner).isEmpty
        || !store.nutritionEntries(for: .snack).isEmpty
        || !store.nutritionEntries(for: .shake).isEmpty
      {
        nutritionTodayCard
      }

      progressSnapshotCard
    }
  }

  private var nutritionTodayCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("ERNÄHRUNG HEUTE")
          .font(GainsFont.label(10))
          .tracking(2)
          .foregroundStyle(GainsColor.softInk)

        Spacer()

        Button {
          navigation.selectedTab = .recipes
        } label: {
          Text("Öffnen")
            .font(GainsFont.label(10))
            .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
      }

      HStack(spacing: 10) {
        compactMetric(title: "Kalorien", value: "\(store.nutritionCaloriesToday)", subtitle: "heute")
        compactMetric(title: "Protein", value: "\(store.nutritionProteinToday) g", subtitle: "erfasst")
        compactMetric(
          title: "Offen", value: "\(max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)) g",
          subtitle: "bis Ziel"
        )
      }
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func quickCheckInButton(title: String, icon: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(GainsColor.moss)
        .frame(width: 44, height: 44)
        .background(GainsColor.lime.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

      Text(title)
        .font(GainsFont.label(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity)
  }

  private enum HomeLauncherEmphasis {
    case primary
    case secondary
  }

  private func quickActionTile(
    title: String,
    subtitle: String,
    icon: String,
    background: Color,
    foreground: Color,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(foreground)
          .frame(width: 38, height: 38)
          .background(GainsColor.background.opacity(0.6))
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        Text(title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        Text(subtitle)
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
      .padding(14)
      .background(background)
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(GainsColor.border.opacity(0.7), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func compactMetric(title: String, value: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text(subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(GainsColor.background.opacity(0.82))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func homeLauncherCard(
    title: String,
    icon: String,
    accent: Color,
    action: @escaping () -> Void,
    footerTitle: String,
    footerText: String,
    emphasis: HomeLauncherEmphasis = .secondary
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(emphasis == .primary ? GainsColor.lime : accent)
              .frame(width: 40, height: 40)
              .background(
                (emphasis == .primary ? GainsColor.background.opacity(0.18) : accent.opacity(0.14))
              )
              .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
              .font(GainsFont.title(emphasis == .primary ? 22 : 20))
              .foregroundStyle(emphasis == .primary ? GainsColor.card : GainsColor.ink)
          }

          Spacer()

          GainsDisclosureIndicator(
            accent: emphasis == .primary ? GainsColor.card.opacity(0.7) : GainsColor.softInk
          )
        }

        Spacer(minLength: 0)

        VStack(alignment: .leading, spacing: 6) {
          Text(footerTitle.uppercased())
            .font(GainsFont.label(9))
            .tracking(1.8)
            .foregroundStyle(emphasis == .primary ? GainsColor.card.opacity(0.72) : GainsColor.softInk)

          Text(footerText)
            .font(GainsFont.body(13))
            .foregroundStyle(emphasis == .primary ? GainsColor.card.opacity(0.92) : GainsColor.ink)
            .lineLimit(3)
        }
      }
      .frame(maxWidth: .infinity, minHeight: emphasis == .primary ? 188 : 168, alignment: .leading)
      .padding(18)
      .background(emphasis == .primary ? GainsColor.ink : GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(
            emphasis == .primary ? GainsColor.ink : GainsColor.border.opacity(0.75),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func collapsibleSection<Content: View>(
    title: String,
    subtitle: String,
    isExpanded: Binding<Bool>,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Button {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
          isExpanded.wrappedValue.toggle()
        }
      } label: {
        HStack(alignment: .center, spacing: 12) {
          VStack(alignment: .leading, spacing: 6) {
            Text(title)
              .font(GainsFont.title(20))
              .foregroundStyle(GainsColor.ink)

            Text(subtitle)
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(2)
          }

          Spacer()

          Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 34, height: 34)
            .background(GainsColor.card)
            .clipShape(Circle())
        }
        .padding(18)
        .gainsCardStyle()
      }
      .buttonStyle(.plain)

      if isExpanded.wrappedValue {
        content()
      }
    }
  }

  private var weekStrip: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        sectionLabel("KALENDER", store.calendarWeekTitle.uppercased())
        Spacer()

        HStack(spacing: 8) {
          Button {
            store.showPreviousCalendarWeek()
          } label: {
            calendarNavButton(systemImage: "chevron.left")
          }
          .buttonStyle(.plain)

          Button {
            store.showCurrentCalendarWeek()
          } label: {
            Text("Heute")
              .font(GainsFont.label(9))
              .tracking(1.4)
              .foregroundStyle(GainsColor.ink)
              .frame(height: 30)
              .padding(.horizontal, 10)
              .background(GainsColor.background.opacity(0.85))
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)

          Button {
            store.showNextCalendarWeek()
          } label: {
            calendarNavButton(systemImage: "chevron.right")
          }
          .buttonStyle(.plain)
        }
      }

      HStack(spacing: 10) {
        ForEach(store.homeWeekDays) { day in
          Button {
            store.selectCalendarDay(day.date)
          } label: {
            VStack(spacing: 8) {
              Text(day.shortLabel)
                .font(GainsFont.label(10))
                .tracking(2)
                .foregroundStyle(GainsColor.mutedInk)

              ZStack {
                switch day.status {
                case .completed:
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GainsColor.ink)

                case .planned:
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GainsColor.lime.opacity(0.22))
                    .overlay {
                      RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GainsColor.lime, lineWidth: 1)
                    }

                case .flexible:
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GainsColor.elevated)
                    .overlay {
                      RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(GainsColor.lime.opacity(0.7))
                    }

                case .rest:
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(GainsColor.border)

                case .today:
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(GainsColor.lime)
                    .overlay {
                      RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GainsColor.ink, lineWidth: 2)
                    }
                }

                if isSelectedCalendarDay(day) {
                  RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GainsColor.moss, lineWidth: 2)
                    .padding(1)
                }

                Text("\(day.dayNumber)")
                  .font(GainsFont.title(18))
                  .foregroundStyle(
                    day.status == .completed
                      ? GainsColor.card : GainsColor.ink.opacity(day.status == .rest ? 0.55 : 1))
              }
              .frame(width: 42, height: 46)

              Circle()
                .fill(isSelectedCalendarDay(day) ? GainsColor.moss : indicatorColor(for: day))
                .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.plain)
        }
      }
      .padding(16)
      .gainsCardStyle()

      if let selectedDay = store.selectedCalendarDay {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(store.selectedCalendarHeadline)
                .font(GainsFont.title(20))
                .foregroundStyle(GainsColor.ink)

              Text(store.selectedCalendarDescription)
                .font(GainsFont.body(14))
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()
          }

          Button {
            store.toggleSelectedCalendarDayCompletion()
          } label: {
            Text(
              store.selectedCalendarDayIsCompleted
                ? "Als offen markieren" : "Als erledigt markieren"
            )
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(
              store.canToggleSelectedCalendarDate ? GainsColor.lime : GainsColor.softInk
            )
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(store.canToggleSelectedCalendarDate ? GainsColor.ink : GainsColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(!store.canToggleSelectedCalendarDate)
        }
        .padding(16)
        .gainsCardStyle(calendarDetailBackground(for: selectedDay))
      }
    }
  }

  private func sectionLabel(_ left: String, _ right: String) -> some View {
    SlashLabel(
      parts: [left, right], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)
  }

  private func startOrResumeRun() {
    isShowingRunTracker = true
  }

  private func startOrResumeWorkout() {
    if store.activeWorkout != nil {
      isShowingWorkoutTracker = true
    } else {
      isShowingWorkoutChooser = true
    }
  }

  private func launchWorkout(_ plan: WorkoutPlan) {
    store.startWorkout(from: plan)
    isShowingWorkoutChooser = false
    isShowingWorkoutTracker = true
  }

  private var runningFooterText: String {
    if let activeRun = store.activeRun {
      return
        "\(String(format: "%.1f", activeRun.distanceKm)) km · \(activeRun.durationMinutes) Min · live"
    }

    if let lastRun = store.latestCompletedRun {
      return
        "\(lastRun.title) · \(String(format: "%.1f", lastRun.distanceKm)) km · \(runPaceLabel(lastRun.averagePaceSeconds))"
    }

    return "Bereit für deinen ersten GPS-Run"
  }

  private var strengthFooterText: String {
    if let activeWorkout = store.activeWorkout {
      return
        "\(activeWorkout.title) · \(activeWorkout.completedSets)/\(activeWorkout.totalSets) Sätze"
    }

    if let lastWorkout = store.lastCompletedWorkout {
      return
        "\(lastWorkout.title) · \(lastWorkout.completedSets) Sätze · \(Int(lastWorkout.volume)) kg"
    }

    let plan = store.todayPlannedWorkout ?? store.currentWorkoutPreview
    return "\(plan.title) · \(plan.exercises.count) Übungen"
  }

  private func runPaceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:-- /km" }
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%d:%02d /km", minutes, remainingSeconds)
  }

  private func homeLauncherCard(
    title: String,
    icon: String,
    accent: Color,
    action: @escaping () -> Void,
    footerTitle: String,
    footerText: String
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          ZStack {
            Circle()
              .fill(accent.opacity(accent == GainsColor.ink ? 1 : 0.22))
              .frame(width: 42, height: 42)

            Image(systemName: icon)
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(accent == GainsColor.ink ? GainsColor.lime : GainsColor.moss)
          }

          Spacer()

          Image(systemName: "arrow.right.circle.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(accent == GainsColor.ink ? GainsColor.ink : GainsColor.moss)
        }

        Text(title)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)

        Text("Direkt starten")
          .font(GainsFont.label(9))
          .tracking(1.8)
          .foregroundStyle(
            accent == GainsColor.ink ? GainsColor.softInk : GainsColor.onLimeSecondary)

        Divider()
          .overlay(GainsColor.border.opacity(0.55))

        VStack(alignment: .leading, spacing: 6) {
          Text(footerTitle.uppercased())
            .font(GainsFont.label(9))
            .tracking(1.8)
            .foregroundStyle(
              accent == GainsColor.ink ? GainsColor.moss : GainsColor.onLimeSecondary)

          Text(footerText)
            .font(GainsFont.body(13))
            .foregroundStyle(
              accent == GainsColor.ink ? GainsColor.softInk : GainsColor.onLimeSecondary
            )
            .multilineTextAlignment(.leading)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 188, alignment: .leading)
      .padding(18)
      .gainsInteractiveCardStyle(
        accent == GainsColor.ink ? GainsColor.card : GainsColor.lime.opacity(0.28),
        accent: GainsColor.moss)
    }
    .buttonStyle(.plain)
  }

  private func isSelectedCalendarDay(_ day: DayProgress) -> Bool {
    Calendar.current.isDate(store.selectedCalendarDate, inSameDayAs: day.date)
  }

  private func calendarNavButton(systemImage: String) -> some View {
    Image(systemName: systemImage)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(GainsColor.ink)
      .frame(width: 30, height: 30)
      .background(GainsColor.background.opacity(0.85))
      .clipShape(Circle())
  }

  private func indicatorColor(for day: DayProgress) -> Color {
    switch day.status {
    case .today:
      return GainsColor.ink
    case .planned:
      return GainsColor.lime
    case .flexible:
      return GainsColor.softInk
    default:
      return .clear
    }
  }

  private func calendarDetailBackground(for day: DayProgress) -> Color {
    switch day.status {
    case .completed:
      return GainsColor.lime.opacity(0.32)
    case .planned:
      return GainsColor.lime.opacity(0.18)
    case .flexible:
      return GainsColor.elevated
    default:
      return GainsColor.card
    }
  }

  private var currentDateParts: (day: String, date: String, week: String) {
    let now = Date()
    let dayFormatter = DateFormatter()
    dayFormatter.locale = Locale(identifier: "de_DE")
    dayFormatter.dateFormat = "EE"

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "dd MMM"

    let week = Calendar.current.component(.weekOfYear, from: now)
    return (
      dayFormatter.string(from: now).uppercased(),
      dateFormatter.string(from: now).uppercased(),
      "WK \(week)"
    )
  }
}

private struct WorkoutStartSheet: View {
  private enum WorkoutStartSurface: String, CaseIterable, Identifiable {
    case mine
    case planned
    case templates

    var id: Self { self }

    var title: String {
      switch self {
      case .mine:
        return "Meine Trainings"
      case .planned:
        return "Heute"
      case .templates:
        return "Vorgefertigt"
      }
    }
  }

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let plannedWorkout: WorkoutPlan?
  let customWorkouts: [WorkoutPlan]
  let onSelectWorkout: (WorkoutPlan) -> Void
  let onCreateWorkout: () -> Void
  @State private var selectedSurface: WorkoutStartSurface = .mine

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        screenHeader(
          eyebrow: "KRAFTTRAINING / START",
          title: "Strength Hub",
          subtitle:
            "Wähle dein Training, starte etwas Geplantes oder stelle dir direkt ein neues Workout zusammen."
        )

        surfacePicker
        smartCreationCard
        createWorkoutSection
        visibleContent
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Schließen") {
          dismiss()
        }
        .foregroundStyle(GainsColor.ink)
      }
    }
  }

  private var surfacePicker: some View {
    HStack(spacing: 10) {
      ForEach(WorkoutStartSurface.allCases) { surface in
        Button {
          selectedSurface = surface
        } label: {
          Text(surface.title)
            .font(GainsFont.label(10))
            .tracking(1.4)
            .foregroundStyle(selectedSurface == surface ? GainsColor.ink : GainsColor.softInk)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(selectedSurface == surface ? GainsColor.lime : GainsColor.card)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
    }
  }

  @ViewBuilder
  private var visibleContent: some View {
    switch selectedSurface {
    case .mine:
      customWorkoutsSection
    case .planned:
      if let plannedWorkout {
        plannedWorkoutSection(plannedWorkout)
      } else {
        emptyStateCard(
          title: "Heute ist noch nichts fix geplant",
          description:
            "Du kannst direkt eines deiner Trainings starten oder ein neues Workout für heute zusammenstellen."
        )
      }
    case .templates:
      templateWorkoutsSection
    }
  }

  private var smartCreationCard: some View {
    Button(action: onCreateWorkout) {
      VStack(alignment: .leading, spacing: 10) {
        Text("Mit Gains planen")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.card)

        Text(
          "Starte mit einer Idee wie Upper, Pull oder Beine und stelle dein Workout in wenigen Schritten passend für dein Ziel zusammen."
        )
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.card.opacity(0.82))

        Text("Los geht's")
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(GainsColor.lime)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(18)
      .background(
        LinearGradient(
          colors: [GainsColor.elevated, GainsColor.card],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(GainsColor.border.opacity(0.9), lineWidth: 1)
      }
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .overlay(alignment: .topTrailing) {
        GainsDisclosureIndicator(accent: GainsColor.moss)
          .padding(14)
      }
    }
    .buttonStyle(.plain)
  }

  private func plannedWorkoutSection(_ workout: WorkoutPlan) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["HEUTE", "EINGEPLANT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      workoutStartCard(
        title: workout.title,
        subtitle: "\(workout.split) · \(workout.exercises.count) Übungen · \(workout.focus)",
        buttonTitle: "Geplantes Workout starten"
      ) {
        onSelectWorkout(workout)
      }
    }
  }

  private var customWorkoutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["EIGENE", "WORKOUTS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      if customWorkouts.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Noch keine eigenen Workouts")
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)

          Text(
            "Stell dir dein erstes Workout selbst zusammen und starte es danach direkt aus diesem Bereich."
          )
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
        }
        .padding(18)
        .gainsCardStyle()
      } else {
        ForEach(customWorkouts) { workout in
          compactWorkoutRow(workout)
        }
      }
    }
  }

  private var templateWorkoutsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["VORGEFERTIGT", "TRAININGS"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ForEach(store.templateWorkoutPlans.prefix(5)) { workout in
        compactWorkoutRow(workout)
      }
    }
  }

  private var createWorkoutSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["NEU", "ZUSAMMENSTELLEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      Button(action: onCreateWorkout) {
        Text("Manuell erstellen")
          .font(GainsFont.label(11))
          .tracking(1.8)
          .foregroundStyle(GainsColor.ink)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  private func workoutStartCard(
    title: String, subtitle: String, buttonTitle: String, action: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)

      Text(subtitle)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)

      Button(action: action) {
        Text(buttonTitle)
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(GainsColor.lime)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(GainsColor.ink)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func compactWorkoutRow(_ workout: WorkoutPlan) -> some View {
    Button {
      onSelectWorkout(workout)
    } label: {
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(workout.title.uppercased())
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)

          Text("\(workout.split) · \(workout.exercises.count) Übungen")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }

        Spacer()

        GainsDisclosureIndicator()
      }
      .padding(18)
      .gainsInteractiveCardStyle()
    }
    .buttonStyle(.plain)
  }

  private func emptyStateCard(title: String, description: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)

      Text(description)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(18)
    .gainsCardStyle()
  }
}

struct SlashLabel: View {
  let parts: [String]
  let primaryColor: Color
  let secondaryColor: Color

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
        Text(part)
          .font(GainsFont.label(10))
          .tracking(3)
          .foregroundStyle(index == 0 ? secondaryColor : secondaryColor)

        if index < parts.count - 1 {
          Text("/")
            .font(GainsFont.label(10))
            .tracking(2)
            .foregroundStyle(primaryColor)
        }
      }
    }
    .textCase(.uppercase)
  }
}

struct StatCard: View {
  let title: String
  let value: String
  let valueAccent: Bool
  let subtitle: String
  let background: Color
  let foreground: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(GainsFont.label(10))
        .tracking(2.8)
        .foregroundStyle(foreground.opacity(0.7))

      valueView

      Spacer(minLength: 0)

      Text(subtitle)
        .font(GainsFont.body(13))
        .foregroundStyle(foreground.opacity(0.72))
    }
    .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
    .padding(14)
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  @ViewBuilder
  private var valueView: some View {
    if valueAccent, value.contains("/") {
      let components = value.split(separator: "/", omittingEmptySubsequences: false).map(
        String.init)
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        Text(components.first ?? value)
        Text("/")
          .foregroundStyle(GainsColor.lime)
        Text(components.dropFirst().first ?? "")
      }
      .font(GainsFont.display(28))
      .foregroundStyle(foreground)
    } else {
      Text(value)
        .font(GainsFont.display(28))
        .foregroundStyle(foreground)
    }
  }
}
