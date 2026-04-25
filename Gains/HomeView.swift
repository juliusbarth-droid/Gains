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
  @State private var isShowingProgress = false
  @State private var showsTodayDetails = false
  @State private var showsWeeklyInsights = false
  @State private var showsCheckInRituals = false
  @State private var showsWeekRhythm = false
  @State private var arrangingPlan: WorkoutPlan?

  var body: some View {
    ZStack {
      GainsAppBackground()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 22) {
          topBar
          titleBlock
          quickStartRow
          todaySection
          collapsibleSection(
            title: "Check-in Rituale",
            subtitle: "Tagesroutinen und kleine Haken nur dann öffnen, wenn du sie wirklich abarbeiten willst",
            isExpanded: $showsCheckInRituals,
            content: { checkInRitualsSection }
          )
          collapsibleSection(
            title: "Wochenrhythmus",
            subtitle: "Streak, Sessions und Wochenkalender gesammelt statt dauerhaft im Fokus",
            isExpanded: $showsWeekRhythm,
            content: { weekRhythmSection }
          )
          collapsibleSection(
            title: "Details für heute",
            subtitle: "Ernährung, Body-Snapshot und weitere Statuskarten nur bei Bedarf",
            isExpanded: $showsTodayDetails,
            content: { todayDetailStack }
          )
          collapsibleSection(
            title: "Insights und Extras",
            subtitle: "Wochen-KPIs, Coach-Kontext und Community bleiben gesammelt unten",
            isExpanded: $showsWeeklyInsights,
            content: {
              VStack(alignment: .leading, spacing: 18) {
                insightsSectionContent
                supportSectionContent
              }
            }
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
            isShowingWorkoutChooser = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
              presentArrange(for: plan)
            }
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
          presentArrange(for: workout)
        }
      }
      .environmentObject(store)
    }
    .sheet(item: $arrangingPlan) { plan in
      WorkoutArrangeView(
        plan: plan,
        onStart: {
          arrangingPlan = nil
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowingWorkoutTracker = true
          }
        },
        onCancel: {
          store.discardWorkout()
          arrangingPlan = nil
        }
      )
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
    VStack(alignment: .leading, spacing: 14) {
      sectionHeader(
        eyebrow: "TODAY / PLAN",
        title: "Was heute zählt",
        subtitle: primaryTodaySummary
      )
      focusStatusRow
      todayWorkoutCard
      secondaryActionRow
      workoutStatusCard
      latestLogCard
    }
  }

  private var topBar: some View {
    HStack(alignment: .center) {
      GainsWordmark(size: 34)

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
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          SlashLabel(
            parts: [currentDateParts.day, currentDateParts.date, currentDateParts.week],
            primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

          Text("Los geht's, \(viewModel.userName).")
            .font(GainsFont.display(34))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.74)

          Text(todayGreetingLine)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }

        Spacer()

        Circle()
          .fill(GainsColor.lime.opacity(0.18))
          .frame(width: 44, height: 44)
          .overlay(
            Image(systemName: "sun.max.fill")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(GainsColor.moss)
          )
      }

      HStack(spacing: 10) {
        titleBlockChip(
          title: "Heute",
          value: store.todayPlannedWorkout?.split ?? store.todayPlannedDay.title
        )
        titleBlockChip(
          title: "Woche",
          value: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Sessions"
        )
      }
    }
    .padding(18)
    .gainsInteractiveCardStyle(GainsColor.card, accent: GainsColor.lime)
  }

  private var todayGreetingLine: String {
    switch store.todayPlannedDay.status {
    case .planned:
      return "Heute steht \(store.todayPlannedWorkout?.title ?? store.currentWorkoutPreview.title) im Fokus."
    case .rest:
      return "Heute ist bewusst leichter geplant. Recovery, Schritte und Rhythmus reichen."
    case .flexible:
      return "Heute bleibt offen. Du kannst Training, Mobility oder einen lockeren Run sinnvoll einbauen."
    }
  }

  private func titleBlockChip(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .frame(height: 50)
    .background(GainsColor.background.opacity(0.82))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var quickStartRow: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Circle()
          .fill(GainsColor.lime)
          .frame(width: 6, height: 6)

        Text("JETZT STARTEN")
          .font(GainsFont.label(10))
          .tracking(2.2)
          .foregroundStyle(GainsColor.softInk)

        Spacer()

        Text("Tippen, läuft sofort")
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(GainsColor.mutedInk)
      }

      HStack(spacing: 12) {
        quickStartCard(
          eyebrow: "KRAFT",
          title: store.activeWorkout == nil ? "Workout" : "Live",
          metric: store.activeWorkout == nil
            ? quickWorkoutPreviewLabel
            : "\(store.activeWorkout?.completedSets ?? 0)/\(store.activeWorkout?.totalSets ?? 0) Sätze",
          icon: "dumbbell.fill",
          isActive: store.activeWorkout != nil,
          tint: .lime,
          action: startFreeWorkout
        )

        quickStartCard(
          eyebrow: "CARDIO",
          title: store.activeRun == nil ? "Lauf" : "Live",
          metric: store.activeRun == nil
            ? "GPS · Outdoor"
            : String(
              format: "%.1f km · %02d:%02d",
              store.activeRun?.distanceKm ?? 0,
              (store.activeRun?.durationMinutes ?? 0) / 60,
              (store.activeRun?.durationMinutes ?? 0) % 60
            ),
          icon: "figure.run",
          isActive: store.activeRun != nil,
          tint: .ember,
          action: startQuickRun
        )
      }
    }
  }

  private var quickWorkoutPreviewLabel: String {
    let plan = store.todayPlannedWorkout ?? store.currentWorkoutPreview
    return "\(plan.exercises.count) Übungen · \(plan.estimatedDurationMinutes) min"
  }

  private enum QuickStartTint {
    case lime
    case ember
  }

  private func quickStartCard(
    eyebrow: String,
    title: String,
    metric: String,
    icon: String,
    isActive: Bool,
    tint: QuickStartTint,
    action: @escaping () -> Void
  ) -> some View {
    let gradient: LinearGradient = {
      switch tint {
      case .lime:
        return LinearGradient(
          colors: [GainsColor.lime, GainsColor.lime.opacity(0.82)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      case .ember:
        return LinearGradient(
          colors: [GainsColor.ember, GainsColor.ember.opacity(0.78)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    }()

    let foreground: Color = {
      switch tint {
      case .lime: return GainsColor.onLime
      case .ember: return GainsColor.onEmber
      }
    }()

    let secondary: Color = {
      switch tint {
      case .lime: return GainsColor.onLimeSecondary
      case .ember: return GainsColor.onEmberSecondary
      }
    }()

    let chipFill: Color = {
      switch tint {
      case .lime: return GainsColor.onLime.opacity(0.10)
      case .ember: return GainsColor.onEmber.opacity(0.12)
      }
    }()

    let glowColor: Color = {
      switch tint {
      case .lime: return GainsColor.lime.opacity(0.45)
      case .ember: return GainsColor.ember.opacity(0.45)
      }
    }()

    return Button(action: action) {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .center, spacing: 10) {
          Image(systemName: icon)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: 40, height: 40)
            .background(Circle().fill(chipFill))

          Spacer()

          if isActive {
            HStack(spacing: 6) {
              Circle()
                .fill(foreground)
                .frame(width: 6, height: 6)
              Text("LIVE")
                .font(GainsFont.label(9))
                .tracking(1.6)
                .foregroundStyle(foreground)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(chipFill)
            .clipShape(Capsule())
          } else {
            Image(systemName: "play.fill")
              .font(.system(size: 10, weight: .heavy))
              .foregroundStyle(foreground)
              .frame(width: 24, height: 24)
              .background(Circle().fill(chipFill))
          }
        }

        VStack(alignment: .leading, spacing: 4) {
          Text(eyebrow)
            .font(GainsFont.label(9))
            .tracking(2.2)
            .foregroundStyle(secondary)

          Text(title)
            .font(GainsFont.display(30))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }

        HStack(spacing: 6) {
          Text(metric)
            .font(GainsFont.body(12))
            .foregroundStyle(secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)

          Spacer(minLength: 0)

          Image(systemName: "arrow.up.right")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(foreground)
        }
      }
      .padding(18)
      .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
      .background(gradient)
      .overlay(alignment: .topTrailing) {
        Circle()
          .fill(glowColor.opacity(0.55))
          .frame(width: 98, height: 98)
          .blur(radius: 42)
          .offset(x: 28, y: -28)
          .allowsHitTesting(false)
      }
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(foreground.opacity(0.10), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
      .shadow(color: glowColor.opacity(0.18), radius: 12, x: 0, y: 8)
    }
    .buttonStyle(.plain)
  }

  private func startFreeWorkout() {
    if store.activeWorkout != nil {
      isShowingWorkoutTracker = true
      return
    }

    store.startQuickWorkout()
    isShowingWorkoutTracker = true
  }

  private func startQuickRun() {
    if store.activeRun == nil {
      store.startQuickRun()
    }
    isShowingRunTracker = true
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

    return Button(action: startOrResumeWorkout) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top, spacing: 14) {
          VStack(alignment: .leading, spacing: 8) {
            Text("PRIMARY ACTION")
              .font(GainsFont.label(10))
              .tracking(1.8)
              .foregroundStyle(GainsColor.softInk)

            Text(plan.title.uppercased())
              .font(GainsFont.display(28))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(2)
              .minimumScaleFactor(0.82)
          }

          Spacer()

          Text(store.activeWorkout == nil ? "START" : "LIVE")
            .font(GainsFont.label(10))
            .tracking(1.5)
            .foregroundStyle(GainsColor.onLime)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(GainsColor.lime)
            .clipShape(Capsule())
        }

        SlashLabel(
          parts: [
            "\(plan.exercises.count) ÜBUNGEN",
            "\(plan.estimatedDurationMinutes) MIN",
            plan.focus.uppercased(),
          ],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )

        HStack(spacing: 8) {
          ForEach(Array(plan.exercises.prefix(3).enumerated()), id: \.offset) { _, exercise in
            Text(exercise.name)
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(1)
              .minimumScaleFactor(0.75)
              .padding(.horizontal, 10)
              .frame(height: 30)
              .background(GainsColor.background.opacity(0.78))
              .clipShape(Capsule())
          }
        }

        HStack(spacing: 12) {
          Image(systemName: "play.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(GainsColor.onLime)
            .frame(width: 34, height: 34)
            .background(GainsColor.lime)
            .clipShape(Circle())

          Text(store.activeWorkout == nil ? "Workout starten" : "Workout weiter tracken")
            .font(GainsFont.label(12))
            .tracking(1.3)
            .foregroundStyle(GainsColor.ink)

          Spacer()

          Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(12)
        .background(GainsColor.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .padding(18)
      .gainsInteractiveCardStyle(GainsColor.card, accent: GainsColor.lime)
    }
    .buttonStyle(.plain)
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
            .tracking(2)
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
            .tracking(2)
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

  private var supportSectionContent: some View {
    HStack(alignment: .top, spacing: 12) {
      Button {
        showsTodayDetails = true
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

          Text("Heute öffnen")
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
        navigation.presentCapture(kind: .progress)
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

  private var weekRhythmSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionHeader(
        eyebrow: "WEEK / RHYTHM",
        title: "Wochenrhythmus",
        subtitle: "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Sessions erledigt · Streak \(store.streakDays) Tage"
      )

      weekStrip
    }
  }

  private var secondaryActionRow: some View {
    HStack(spacing: 10) {
      todayQuickButton(
        title: store.activeRun == nil ? "Run" : "Run live",
        subtitle: store.activeRun == nil ? "Starten" : "Fortsetzen",
        icon: "figure.run",
        action: {
          navigation.openTraining(workspace: .laufen)
          startOrResumeRun()
        }
      )

      todayQuickButton(
        title: "Fuel",
        subtitle: "Meal loggen",
        icon: "fork.knife",
        action: {
          navigation.presentCapture(kind: .meal)
        }
      )

      todayQuickButton(
        title: "Body",
        subtitle: "Check-in",
        icon: "heart.text.square.fill",
        action: {
          navigation.selectedTab = .progress
        }
      )
    }
  }

  private var focusStatusRow: some View {
    HStack(spacing: 10) {
      Button {
        navigation.openTraining(workspace: .kraft)
      } label: {
        compactMetric(
          title: "Train",
          value: store.todayPlannedWorkout?.title ?? "Flex Day",
          subtitle: "Workout heute"
        )
      }
      .buttonStyle(.plain)

      Button {
        navigation.selectedTab = .recipes
      } label: {
        compactMetric(
          title: "Fuel",
          value: "\(store.nutritionProteinToday) g",
          subtitle: "Protein heute"
        )
      }
      .buttonStyle(.plain)

      Button {
        navigation.selectedTab = .progress
      } label: {
        compactMetric(
          title: "Move",
          value: moveValue,
          subtitle: "Schritte"
        )
      }
      .buttonStyle(.plain)
    }
  }

  private func sectionHeader(eyebrow: String, title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      SlashLabel(
        parts: eyebrow.components(separatedBy: " / "),
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      Text(title)
        .font(GainsFont.title(24))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)

      Text(subtitle)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
  }

  private func todayQuickButton(
    title: String,
    subtitle: String,
    icon: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 9) {
        Image(systemName: icon)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 34, height: 34)
          .background(GainsColor.ink)
          .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

        Text(title)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        Text(subtitle)
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(1)
          .minimumScaleFactor(0.82)
      }
      .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
      .padding(13)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(GainsColor.border.opacity(0.75), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var checkInRitualsSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("CHECK-IN RITUALE")
          .font(GainsFont.label(10))
          .tracking(2)
          .foregroundStyle(GainsColor.softInk)

        Spacer()

        Text("\(store.completedCoachCheckInIDs.count)/\(CoachViewModel.mock.checkIns.count)")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.lime)
      }

      VStack(spacing: 8) {
        ForEach(CoachViewModel.mock.checkIns.prefix(4)) { item in
          Button {
            store.toggleCoachCheckIn(item.id)
          } label: {
            HStack(spacing: 12) {
              Image(systemName: store.completedCoachCheckInIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                  store.completedCoachCheckInIDs.contains(item.id) ? GainsColor.lime : GainsColor.softInk
                )

              VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                  .font(GainsFont.title(16))
                  .foregroundStyle(GainsColor.ink)
                  .lineLimit(1)

                Text(item.detail)
                  .font(GainsFont.body(12))
                  .foregroundStyle(GainsColor.softInk)
                  .lineLimit(1)
              }

              Spacer()
            }
            .padding(12)
            .background(GainsColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(16)
    .gainsCardStyle(GainsColor.elevated)
  }

  private var latestLogCard: some View {
    Button {
      navigation.presentCapture(kind: latestLogKind)
    } label: {
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: latestLogKind.systemImage)
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 42, height: 42)
          .background(GainsColor.ink)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        VStack(alignment: .leading, spacing: 5) {
          Text("LATEST LOG")
            .font(GainsFont.label(9))
            .tracking(1.8)
            .foregroundStyle(GainsColor.softInk)

          Text(latestLogTitle)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)

          Text("Tippen zum Capturen oder Teilen")
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }

        Spacer()

        GainsDisclosureIndicator()
      }
      .padding(16)
      .gainsCardStyle()
    }
    .buttonStyle(.plain)
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

  private var primaryTodaySummary: String {
    let plan = store.todayPlannedWorkout ?? store.currentWorkoutPreview
    let proteinOpen = max(store.nutritionTargetProtein - store.nutritionProteinToday, 0)
    return "\(plan.title) ist der Anker. Danach \(proteinOpen)g Protein offen halten und Bewegung sauber abschliessen."
  }

  private var moveValue: String {
    if let snapshot = store.healthSnapshot {
      return "\(snapshot.stepsToday)"
    }

    return store.connectedTrackerIDs.isEmpty ? "--" : "8.4k"
  }

  private var latestLogKind: CaptureKind {
    let runDate = store.latestCompletedRun?.finishedAt ?? Date.distantPast
    let workoutDate = store.latestCompletedWorkout?.finishedAt ?? Date.distantPast
    return runDate > workoutDate ? .run : .workout
  }

  private var latestLogTitle: String {
    switch latestLogKind {
    case .run:
      return store.latestCompletedRun?.title ?? "Noch kein Lauf geloggt"
    case .workout:
      return store.lastCompletedWorkout?.title ?? store.currentWorkoutPreview.title
    case .progress:
      return "Progress Update"
    case .meal:
      return "Meal Log"
    }
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

  private func presentArrange(for plan: WorkoutPlan) {
    if store.activeWorkout == nil {
      store.startWorkout(from: plan)
    }
    arrangingPlan = plan
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
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let plannedWorkout: WorkoutPlan?
  let customWorkouts: [WorkoutPlan]
  let onSelectWorkout: (WorkoutPlan) -> Void
  let onCreateWorkout: () -> Void

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 20) {
        headline

        createBanner
        manualCreateButton

        if let plannedWorkout {
          section(title: "HEUTE GEPLANT", accent: true) {
            workoutRow(plannedWorkout, isPrimary: true)
          }
        }

        section(title: "MEINE TRAININGS") {
          if customWorkouts.isEmpty {
            emptyCustomCard
          } else {
            VStack(spacing: 10) {
              ForEach(customWorkouts) { workout in
                workoutRow(workout)
              }
            }
          }
        }

        section(title: "VORGEFERTIGT") {
          VStack(spacing: 10) {
            ForEach(store.templateWorkoutPlans.prefix(6)) { workout in
              workoutRow(workout)
            }
          }
        }
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(GainsColor.ink)
        }
      }
      ToolbarItem(placement: .principal) {
        Text("STRENGTH TRAINER")
          .font(GainsFont.label(11))
          .tracking(2.2)
          .foregroundStyle(GainsColor.ink)
      }
    }
  }

  private var headline: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Workout starten")
        .font(GainsFont.display(30))
        .foregroundStyle(GainsColor.ink)

      Text("Such dir ein Training aus oder stell dir schnell ein neues zusammen.")
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
  }

  private var createBanner: some View {
    Button(action: onCreateWorkout) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 10) {
          Circle()
            .fill(GainsColor.lime)
            .frame(width: 6, height: 6)
          Text("GAINS COACH")
            .font(GainsFont.label(10))
            .tracking(2.2)
            .foregroundStyle(GainsColor.lime)
        }

        Text("Neues Workout planen")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.card)

        Text(
          "Übung für Übung zusammenstellen – inklusive Sätze, Reps und Gewicht als Zielwert."
        )
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.card.opacity(0.78))
        .lineLimit(3)

        HStack(spacing: 8) {
          Text("Los geht's")
            .font(GainsFont.label(11))
            .tracking(1.6)
            .foregroundStyle(GainsColor.lime)
          Image(systemName: "arrow.right")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(GainsColor.lime)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(GainsColor.ink)

          LinearGradient(
            colors: [GainsColor.lime.opacity(0.22), GainsColor.lime.opacity(0.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: 24, style: .continuous)
          .stroke(GainsColor.lime.opacity(0.35), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var manualCreateButton: some View {
    Button(action: onCreateWorkout) {
      HStack(spacing: 10) {
        Image(systemName: "plus")
          .font(.system(size: 13, weight: .bold))
        Text("MANUELL ERSTELLEN")
          .font(GainsFont.label(11))
          .tracking(2)
      }
      .foregroundStyle(GainsColor.ink)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(GainsColor.border.opacity(0.6), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func section<Content: View>(
    title: String,
    accent: Bool = false,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Circle()
          .fill(accent ? GainsColor.lime : GainsColor.softInk.opacity(0.45))
          .frame(width: 5, height: 5)
        Text(title)
          .font(GainsFont.label(10))
          .tracking(2.2)
          .foregroundStyle(accent ? GainsColor.lime : GainsColor.softInk)
        Rectangle()
          .fill(GainsColor.border.opacity(0.4))
          .frame(height: 1)
          .padding(.leading, 4)
      }
      content()
    }
  }

  private var emptyCustomCard: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Noch keine eigenen Trainings")
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
      Text("Erstelle dein erstes Workout mit dem Button oben.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func workoutRow(_ workout: WorkoutPlan, isPrimary: Bool = false) -> some View {
    Button {
      onSelectWorkout(workout)
    } label: {
      HStack(spacing: 14) {
        Image(systemName: isPrimary ? "flame.fill" : "dumbbell.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(isPrimary ? GainsColor.onLime : GainsColor.lime)
          .frame(width: 44, height: 44)
          .background(
            Circle()
              .fill(isPrimary ? GainsColor.lime : GainsColor.lime.opacity(0.14))
          )

        VStack(alignment: .leading, spacing: 4) {
          Text(workout.title.uppercased())
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)

          Text("\(workout.exercises.count) Übungen · \(workout.estimatedDurationMinutes) min")
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(GainsColor.softInk.opacity(0.7))
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(
            isPrimary ? GainsColor.lime.opacity(0.6) : GainsColor.border.opacity(0.4),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
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
          .tracking(2)
          .foregroundStyle(index == 0 ? primaryColor : secondaryColor)

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

private struct WorkoutArrangeView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let plan: WorkoutPlan
  let onStart: () -> Void
  let onCancel: () -> Void

  @State private var isShowingExercisePicker = false

  var body: some View {
    NavigationStack {
      ZStack {
        GainsAppBackground()

        if let workout = store.activeWorkout {
          VStack(spacing: 0) {
            headline(for: workout)
              .padding(.horizontal, 20)
              .padding(.top, 8)
              .padding(.bottom, 12)

            List {
              Section {
                ForEach(workout.exercises) { exercise in
                  exerciseRow(exercise, in: workout)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                }
                .onMove { source, destination in
                  store.reorderActiveExercises(from: source, to: destination)
                }
                .onDelete { indexSet in
                  for index in indexSet {
                    if let id = store.activeWorkout?.exercises[safe: index]?.id {
                      store.removeActiveExercise(id: id)
                    }
                  }
                }
              } header: {
                sectionLabel
                  .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                  .listRowBackground(Color.clear)
              }

              Section {
                Button {
                  isShowingExercisePicker = true
                } label: {
                  addExerciseRow
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 24, trailing: 20))
              }

              Section {
                Color.clear.frame(height: 110)
                  .listRowBackground(Color.clear)
                  .listRowSeparator(.hidden)
                  .listRowInsets(EdgeInsets())
              }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
          }

          VStack {
            Spacer()
            startCTA(for: workout)
              .padding(.horizontal, 20)
              .padding(.bottom, 18)
          }
        } else {
          VStack(spacing: 12) {
            SwiftUI.ProgressView()
            Text("Workout wird vorbereitet ...")
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.softInk)
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            onCancel()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 30, height: 30)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
        }
        ToolbarItem(placement: .principal) {
          Text("TRAINING ANPASSEN")
            .font(GainsFont.label(11))
            .tracking(2.2)
            .foregroundStyle(GainsColor.ink)
        }
      }
      .sheet(isPresented: $isShowingExercisePicker) {
        ExercisePickerSheet { item in
          store.appendActiveExercise(from: item)
          isShowingExercisePicker = false
        }
        .environmentObject(store)
      }
    }
  }

  private func headline(for workout: WorkoutSession) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(workout.title)
        .font(GainsFont.display(28))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)
        .minimumScaleFactor(0.78)

      HStack(spacing: 8) {
        metaPill(icon: "list.bullet", text: "\(workout.exercises.count) Übungen")
        metaPill(icon: "repeat", text: "\(workout.totalSets) Sätze")
        metaPill(icon: "clock", text: "\(plan.estimatedDurationMinutes) min")
      }

      Text("Reihenfolge ändern, Übungen entfernen oder hinzufügen – dann starten.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
        .padding(.top, 2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func metaPill(icon: String, text: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(GainsColor.moss)
      Text(text)
        .font(GainsFont.label(10))
        .tracking(1.2)
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background(GainsColor.lime.opacity(0.18))
    .clipShape(Capsule())
  }

  private var sectionLabel: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(GainsColor.lime)
        .frame(width: 5, height: 5)
      Text("ÜBUNGEN")
        .font(GainsFont.label(10))
        .tracking(2.2)
        .foregroundStyle(GainsColor.softInk)
      Rectangle()
        .fill(GainsColor.border.opacity(0.4))
        .frame(height: 1)
    }
  }

  private func exerciseRow(_ exercise: TrackedExercise, in workout: WorkoutSession) -> some View {
    let index = workout.exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0

    return HStack(spacing: 12) {
      Text(String(format: "%02d", index + 1))
        .font(GainsFont.label(11))
        .tracking(1.4)
        .foregroundStyle(GainsColor.moss)
        .frame(width: 32, height: 32)
        .background(GainsColor.lime.opacity(0.22))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text(exercise.name)
          .font(GainsFont.title(17))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)

        Text(
          "\(exercise.targetMuscle.uppercased()) · \(exercise.sets.count) Sätze"
        )
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
      }

      Spacer()

      Image(systemName: "line.3.horizontal")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.softInk.opacity(0.7))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private var addExerciseRow: some View {
    HStack(spacing: 12) {
      Image(systemName: "plus")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 32, height: 32)
        .background(GainsColor.ink)
        .clipShape(Circle())

      Text("ÜBUNG HINZUFÜGEN")
        .font(GainsFont.label(11))
        .tracking(1.8)
        .foregroundStyle(GainsColor.ink)

      Spacer()

      Image(systemName: "chevron.right")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 14)
    .background(GainsColor.card.opacity(0.6))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        .foregroundStyle(GainsColor.lime.opacity(0.55))
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func startCTA(for workout: WorkoutSession) -> some View {
    Button {
      onStart()
    } label: {
      HStack(spacing: 12) {
        Image(systemName: "play.fill")
          .font(.system(size: 13, weight: .heavy))
          .foregroundStyle(GainsColor.lime)

        Text("TRAINING STARTEN")
          .font(GainsFont.label(13))
          .tracking(2)
          .foregroundStyle(GainsColor.lime)

        Spacer()

        Text("\(workout.exercises.count) ÜBUNGEN")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.lime.opacity(0.7))
      }
      .padding(.horizontal, 22)
      .frame(height: 64)
      .background(GainsColor.ink)
      .overlay(
        RoundedRectangle(cornerRadius: 22, style: .continuous)
          .stroke(GainsColor.lime.opacity(0.55), lineWidth: 1.4)
      )
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .shadow(color: GainsColor.lime.opacity(0.18), radius: 18, x: 0, y: 10)
      .opacity(workout.exercises.isEmpty ? 0.45 : 1)
    }
    .buttonStyle(.plain)
    .disabled(workout.exercises.isEmpty)
  }
}

private struct ExercisePickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let onSelect: (ExerciseLibraryItem) -> Void

  @State private var searchText = ""

  private var filteredExercises: [ExerciseLibraryItem] {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return store.exerciseLibrary }
    return store.exerciseLibrary.filter {
      $0.name.localizedCaseInsensitiveContains(trimmed)
        || $0.primaryMuscle.localizedCaseInsensitiveContains(trimmed)
        || $0.equipment.localizedCaseInsensitiveContains(trimmed)
    }
  }

  var body: some View {
    NavigationStack {
      GainsScreen {
        VStack(alignment: .leading, spacing: 14) {
          searchField

          if filteredExercises.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Text("Keine Übung gefunden")
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)
              Text("Versuch einen anderen Suchbegriff oder eine Muskelgruppe.")
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .gainsCardStyle()
          } else {
            VStack(spacing: 10) {
              ForEach(filteredExercises) { item in
                Button {
                  onSelect(item)
                } label: {
                  exerciseRow(item)
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 30, height: 30)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
        }
        ToolbarItem(placement: .principal) {
          Text("ÜBUNG WÄHLEN")
            .font(GainsFont.label(11))
            .tracking(2.2)
            .foregroundStyle(GainsColor.ink)
        }
      }
    }
  }

  private var searchField: some View {
    HStack(spacing: 10) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)

      TextField("Suche nach Übung oder Muskelgruppe", text: $searchText)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.ink)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)

      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 14)
    .frame(height: 46)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func exerciseRow(_ item: ExerciseLibraryItem) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "dumbbell.fill")
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 38, height: 38)
        .background(GainsColor.ink)
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 4) {
        Text(item.name)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)

        Text("\(item.primaryMuscle.uppercased()) · \(item.equipment)")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(1)
      }

      Spacer()

      Text("\(item.defaultSets)×\(item.defaultReps)")
        .font(GainsFont.label(10))
        .tracking(1.2)
        .foregroundStyle(GainsColor.moss)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(GainsColor.lime.opacity(0.22))
        .clipShape(Capsule())

      Image(systemName: "plus")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(GainsColor.ink)
        .frame(width: 28, height: 28)
        .background(GainsColor.lime)
        .clipShape(Circle())
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
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
        .tracking(2)
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
