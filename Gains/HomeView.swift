import SwiftUI

struct HomeView: View {
  @EnvironmentObject private var navigation: AppNavigationStore
  @EnvironmentObject private var store: GainsStore
  @State private var isShowingWorkoutChooser = false
  @State private var isShowingWorkoutBuilder = false
  @State private var isShowingWorkoutTracker = false
  @State private var isShowingRunTracker = false
  @State private var isShowingProfile = false
  @State private var isShowingProgress = false
  @State private var arrangingPlan: WorkoutPlan?

  // A6: Sheet-Choreografie über `onDismiss` statt `asyncAfter`.
  // Wenn ein Sheet beim Schließen ein anderes Sheet öffnen soll, parken wir
  // die Folge-Aktion hier und führen sie im `onDismiss`-Callback des
  // jeweiligen Sheets aus — so wartet SwiftUI deterministisch auf das Ende
  // der Dismiss-Animation.
  @State private var pendingAfterChooser: (() -> Void)? = nil
  @State private var pendingAfterBuilder: (() -> Void)? = nil
  @State private var pendingAfterArrange: (() -> Void)? = nil

  var body: some View {
    ZStack {
      GainsAppBackground()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 36) {
          topBar
          editorialHero
          if store.activeWorkout != nil {
            activeWorkoutLine
          }
          quickStartSection
          weekSection
          quickLinks
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 120)
      }
    }
    .sheet(
      isPresented: $isShowingWorkoutChooser,
      onDismiss: { runPending(&pendingAfterChooser) }
    ) {
      NavigationStack {
        WorkoutTrackerEntryView(
          onSelectWorkout: { plan in
            pendingAfterChooser = { presentArrange(for: plan) }
            isShowingWorkoutChooser = false
          },
          onCreateWorkout: {
            pendingAfterChooser = { isShowingWorkoutBuilder = true }
            isShowingWorkoutChooser = false
          }
        )
        .environmentObject(store)
      }
    }
    .sheet(
      isPresented: $isShowingWorkoutBuilder,
      onDismiss: { runPending(&pendingAfterBuilder) }
    ) {
      WorkoutBuilderView { workout in
        pendingAfterBuilder = { presentArrange(for: workout) }
        isShowingWorkoutBuilder = false
      }
      .environmentObject(store)
    }
    .sheet(
      item: $arrangingPlan,
      onDismiss: { runPending(&pendingAfterArrange) }
    ) { plan in
      WorkoutArrangeView(
        plan: plan,
        onStart: {
          pendingAfterArrange = { isShowingWorkoutTracker = true }
          arrangingPlan = nil
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
        ProgressView()
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

  // MARK: - Editorial Hero (Date + Greeting)

  private var editorialHero: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(spacing: 8) {
        Circle()
          .fill(GainsColor.lime)
          .frame(width: 5, height: 5)
        Text("\(currentDateParts.day) · \(currentDateParts.date) · \(currentDateParts.week)")
          .gainsEyebrow(GainsColor.softInk, size: 12, tracking: 1.4)
      }

      Text(store.userName.isEmpty ? "Los geht's." : "Los geht's,\n\(store.userName).")
        .font(GainsFont.display(46))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(3)
        .minimumScaleFactor(0.6)
        .lineSpacing(-4)
        .fixedSize(horizontal: false, vertical: true)

      Text(todayGreetingLine)
        .font(GainsFont.body(16))
        .foregroundStyle(GainsColor.softInk)
        .lineSpacing(2)
        .lineLimit(3)
        .padding(.trailing, 12)
    }
  }

  // MARK: - Active Workout Line (minimal)

  private var activeWorkoutLine: some View {
    Button {
      isShowingWorkoutTracker = true
    } label: {
      HStack(spacing: 12) {
        Circle()
          .fill(GainsColor.lime)
          .frame(width: 7, height: 7)
        Text("WORKOUT LÄUFT")
          .gainsEyebrow(GainsColor.ink, size: 12, tracking: 1.4)
        Text("·")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.mutedInk)
        Text(
          "\(store.activeWorkout?.completedSets ?? 0)/\(store.activeWorkout?.totalSets ?? 0) Sätze"
        )
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)

        Spacer(minLength: 0)

        Text("Weiter")
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(GainsColor.moss)
        Image(systemName: "arrow.right")
          .font(.system(size: 11, weight: .heavy))
          .foregroundStyle(GainsColor.moss)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(GainsColor.lime.opacity(0.16))
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Week Section (simplified, editorial)

  private var weekSection: some View {
    VStack(alignment: .leading, spacing: 18) {
      sectionHeading(
        "WOCHE",
        trailing:
          "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) SESSIONS · STREAK \(store.streakDays) TAGE"
      )

      HStack(spacing: 4) {
        ForEach(store.homeWeekDays) { day in
          Button {
            store.selectCalendarDay(day.date)
          } label: {
            VStack(spacing: 8) {
              Text(day.shortLabel)
                .font(GainsFont.label(9))
                .tracking(1.6)
                .foregroundStyle(GainsColor.mutedInk)

              ZStack {
                weekDayShape(for: day)
                if isSelectedCalendarDay(day) {
                  Circle()
                    .stroke(GainsColor.moss, lineWidth: 1.5)
                    .padding(-3)
                }
                Text("\(day.dayNumber)")
                  .font(GainsFont.title(17))
                  .foregroundStyle(weekDayTextColor(for: day))
              }
              .frame(width: 36, height: 36)

              Circle()
                .fill(weekDayDotColor(for: day))
                .frame(width: 4, height: 4)
                .opacity(weekDayDotColor(for: day) == .clear ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
          }
          .buttonStyle(.plain)
        }
      }

      if store.selectedCalendarDay != nil {
        VStack(alignment: .leading, spacing: 6) {
          Text(store.selectedCalendarHeadline)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)

          Text(store.selectedCalendarDescription)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)

          if store.canToggleSelectedCalendarDate {
            Button {
              store.toggleSelectedCalendarDayCompletion()
            } label: {
              HStack(spacing: 6) {
                Text(
                  store.selectedCalendarDayIsCompleted
                    ? "Als offen markieren" : "Als erledigt markieren"
                )
                .font(GainsFont.label(11))
                .tracking(1.4)
                .foregroundStyle(GainsColor.lime)

                Image(systemName: "arrow.right")
                  .font(.system(size: 10, weight: .heavy))
                  .foregroundStyle(GainsColor.lime)
              }
              .padding(.top, 4)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.top, 4)
      }
    }
  }

  @ViewBuilder
  private func weekDayShape(for day: DayProgress) -> some View {
    switch day.status {
    case .today:
      Circle().fill(GainsColor.lime)
    case .completed:
      Circle().fill(GainsColor.ctaSurface)
    case .planned:
      Circle().strokeBorder(GainsColor.lime, lineWidth: 1.4)
    case .flexible:
      Circle()
        .strokeBorder(
          GainsColor.lime.opacity(0.7),
          style: StrokeStyle(lineWidth: 1, dash: [3, 3])
        )
    case .rest:
      Circle().strokeBorder(GainsColor.border.opacity(0.55), lineWidth: 1)
    }
  }

  private func weekDayTextColor(for day: DayProgress) -> Color {
    switch day.status {
    case .today: return GainsColor.onLime
    case .completed: return GainsColor.card
    case .rest: return GainsColor.mutedInk
    default: return GainsColor.ink
    }
  }

  private func weekDayDotColor(for day: DayProgress) -> Color {
    if isSelectedCalendarDay(day) { return GainsColor.moss }
    return indicatorColor(for: day)
  }

  // MARK: - Quick Links (Coach / Community / Fortschritt)

  private var quickLinks: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeading("MEHR")

      VStack(spacing: 0) {
        quickLinkRow(
          label: "Coach",
          value: store.coachHeadline
        ) {
          navigation.openTraining(workspace: .kraft)
        }
        quickLinkRow(
          label: "Community",
          value: store.communityHighlightHeadline
        ) {
          navigation.presentCapture(kind: .progress)
        }
        quickLinkRow(
          label: "Fortschritt",
          value:
            "\(store.weeklySessionsCompleted)/\(store.weeklyGoalCount) Sessions · +\(store.personalRecordCount) PRs",
          isLast: true
        ) {
          isShowingProgress = true
        }
      }
    }
  }

  private func quickLinkRow(
    label: String,
    value: String,
    isLast: Bool = false,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 0) {
        HStack(alignment: .center, spacing: 14) {
          Text(label.uppercased())
            .font(GainsFont.label(10))
            .tracking(2.2)
            .foregroundStyle(GainsColor.softInk)
            .frame(width: 96, alignment: .leading)

          Text(value)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
            .truncationMode(.tail)

          Spacer(minLength: 0)

          Image(systemName: "arrow.up.right")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(.vertical, 16)

        if !isLast {
          Rectangle()
            .fill(GainsColor.border.opacity(0.45))
            .frame(height: 1)
        }
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Top Bar

  private var topBar: some View {
    HStack(alignment: .center) {
      GainsWordmark(size: 30)

      Spacer()

      Button {
        isShowingProfile = true
      } label: {
        Text(store.userName.isEmpty ? "·" : String(store.userName.prefix(1)).uppercased())
          .font(GainsFont.label(13))
          .foregroundStyle(GainsColor.ink)
          .frame(width: 38, height: 38)
          .background(
            Circle().stroke(GainsColor.border.opacity(0.55), lineWidth: 1)
          )
      }
      .buttonStyle(.plain)
    }
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

  // MARK: - Quick Start (editorial rows)

  private var quickStartSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      sectionHeading("JETZT STARTEN")

      VStack(spacing: 0) {
        editorialStartRow(
          eyebrow: "KRAFT",
          title: store.activeWorkout == nil ? "Workout" : "Live",
          metric: store.activeWorkout == nil
            ? quickWorkoutPreviewLabel
            : "\(store.activeWorkout?.completedSets ?? 0)/\(store.activeWorkout?.totalSets ?? 0) Sätze",
          accent: GainsColor.lime,
          isActive: store.activeWorkout != nil,
          isLast: false,
          action: startFreeWorkout
        )

        editorialStartRow(
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
          accent: GainsColor.ember,
          isActive: store.activeRun != nil,
          isLast: true,
          action: startQuickRun
        )
      }
    }
  }

  private var quickWorkoutPreviewLabel: String {
    let plan = store.todayPlannedWorkout ?? store.currentWorkoutPreview
    return "\(plan.exercises.count) Übungen · \(plan.estimatedDurationMinutes) min"
  }

  private func editorialStartRow(
    eyebrow: String,
    title: String,
    metric: String,
    accent: Color,
    isActive: Bool,
    isLast: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 0) {
        HStack(alignment: .center, spacing: 16) {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              Circle()
                .fill(accent)
                .frame(width: 5, height: 5)
              Text(eyebrow)
                .gainsEyebrow(GainsColor.softInk, size: 12, tracking: 1.4)

              if isActive {
                Text("LIVE")
                  .font(GainsFont.label(9))
                  .tracking(1.6)
                  .foregroundStyle(accent)
                  .padding(.horizontal, 7)
                  .frame(height: 18)
                  .background(accent.opacity(0.16))
                  .clipShape(Capsule())
              }
            }

            Text(title)
              .font(GainsFont.display(32))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
              .minimumScaleFactor(0.7)

            Text(metric)
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(1)
              .truncationMode(.tail)
          }

          Spacer(minLength: 0)

          Image(systemName: "arrow.up.right")
            .font(.system(size: 14, weight: .heavy))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 46, height: 46)
            .overlay(
              Circle().stroke(GainsColor.border.opacity(0.55), lineWidth: 1)
            )
        }
        .padding(.vertical, 18)

        if !isLast {
          Rectangle()
            .fill(GainsColor.border.opacity(0.45))
            .frame(height: 1)
        }
      }
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

  // MARK: - Section Heading (editorial)

  private func sectionHeading(_ title: String, trailing: String? = nil) -> some View {
    HStack(spacing: 8) {
      Circle()
        .fill(GainsColor.lime)
        .frame(width: 5, height: 5)
      Text(title)
        .gainsEyebrow(GainsColor.ink, size: 12, tracking: 1.4)

      if let trailing {
        Text("/")
          .gainsEyebrow(GainsColor.lime, size: 12, tracking: 1.2)
        Text(trailing)
          .gainsEyebrow(GainsColor.softInk, size: 12, tracking: 1.2)
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
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

  /// A6: Führt eine geparkte Folge-Aktion aus dem `onDismiss`-Callback aus
  /// und löscht den Slot. Verhindert, dass eine Aktion versehentlich
  /// mehrfach feuert, wenn ein Sheet aus anderen Gründen wieder geschlossen wird.
  private func runPending(_ slot: inout (() -> Void)?) {
    guard let action = slot else { return }
    slot = nil
    action()
  }

  private func isSelectedCalendarDay(_ day: DayProgress) -> Bool {
    Calendar.current.isDate(store.selectedCalendarDate, inSameDayAs: day.date)
  }

  private func indicatorColor(for day: DayProgress) -> Color {
    switch day.status {
    case .today:
      return GainsColor.ctaSurface
    case .planned, .completed:
      return GainsColor.lime
    case .flexible:
      return GainsColor.softInk
    default:
      return .clear
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

// Cleanup: `WorkoutStartSheet` wurde durch `WorkoutTrackerEntryView` ersetzt
// (Whoop-Style 3-Tab-Layout) und ist deshalb komplett entfernt worden.

struct SlashLabel: View {
  let parts: [String]
  let primaryColor: Color
  let secondaryColor: Color

  // A4: Reduziertes Tracking (2.0 → 1.3) — Buchstaben bleiben verbunden
  // lesbar bei den überall verwendeten 13pt (Floor von `GainsFont.label`).
  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
        Text(part)
          .font(GainsFont.label(10))
          .tracking(1.3)
          .foregroundStyle(index == 0 ? primaryColor : secondaryColor)

        if index < parts.count - 1 {
          Text("/")
            .font(GainsFont.label(10))
            .tracking(1.3)
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
        .background(GainsColor.ctaSurface)
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
      .background(GainsColor.ctaSurface)
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
        .background(GainsColor.ctaSurface)
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
        .foregroundStyle(GainsColor.onLime)
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
