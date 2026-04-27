import SwiftUI
import AVKit

// MARK: - WorkoutTrackerEntryView
//
// Whoop-inspirierter Einstiegs-Screen für den Workout-Tracker.
// Drei Segment-Tabs: FORTSCHRITT / MEINE TRAININGS / GAINS-TRAINING.
// Wird modal aus HomeView (Quick-Start) geöffnet und ersetzt das alte
// `WorkoutStartSheet`.

enum WorkoutEntrySegment: String, CaseIterable, Identifiable {
  case fortschritt    = "FORTSCHRITT"
  case meineTrainings = "MEINE TRAININGS"
  case gainsTraining  = "GAINS-TRAINING"

  var id: Self { self }
}

struct WorkoutTrackerEntryView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let onSelectWorkout: (WorkoutPlan) -> Void
  let onCreateWorkout: () -> Void

  @State private var selectedSegment: WorkoutEntrySegment = .meineTrainings
  @State private var browsingExercise: ExerciseLibraryItem? = nil
  @State private var showsExerciseLibrary = false

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        segmentPicker

        Group {
          switch selectedSegment {
          case .fortschritt:    progressTab
          case .meineTrainings: meineTrainingsTab
          case .gainsTraining:  gainsTrainingTab
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
        Text("STRENGTH-TRAINER")
          .font(GainsFont.label(11))
          .tracking(2.2)
          .foregroundStyle(GainsColor.ink)
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          showsExerciseLibrary = true
        } label: {
          Image(systemName: "books.vertical.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.ink)
        }
      }
    }
    .sheet(item: $browsingExercise) { exercise in
      NavigationStack {
        ExerciseDetailSheet(exercise: exercise)
      }
      .presentationDetents([.large])
    }
    .sheet(isPresented: $showsExerciseLibrary) {
      NavigationStack {
        ExerciseLibraryBrowser()
      }
      .presentationDetents([.large])
    }
  }

  // MARK: - Segment Picker

  private var segmentPicker: some View {
    HStack(spacing: 0) {
      ForEach(WorkoutEntrySegment.allCases) { segment in
        Button {
          withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            selectedSegment = segment
          }
        } label: {
          VStack(spacing: 8) {
            Text(segment.rawValue)
              .font(GainsFont.label(10))
              .tracking(1.5)
              .foregroundStyle(selectedSegment == segment ? GainsColor.ink : GainsColor.softInk.opacity(0.7))
              .multilineTextAlignment(.center)
              .lineLimit(1)
              .minimumScaleFactor(0.8)

            Rectangle()
              .fill(selectedSegment == segment ? GainsColor.lime : Color.clear)
              .frame(height: 2)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.bottom, 4)
  }

  // MARK: - FORTSCHRITT

  @ViewBuilder
  private var progressTab: some View {
    if store.workoutHistory.isEmpty {
      EmptyStateView(
        style: .prominent,
        title: "Noch kein Workout abgeschlossen",
        message: "Sobald du dein erstes Training durchgezogen hast, siehst du hier deine Historie mit Volumen und Sätzen.",
        icon: "chart.line.uptrend.xyaxis"
      )
    } else {
      VStack(alignment: .leading, spacing: 14) {
        Text("LETZTE WORKOUTS")
          .font(GainsFont.label(10))
          .tracking(2.0)
          .foregroundStyle(GainsColor.softInk)

        VStack(spacing: 10) {
          ForEach(store.workoutHistory.prefix(15)) { workout in
            historyCard(workout)
          }
        }

        if store.workoutHistory.count > 15 {
          Text("\(store.workoutHistory.count - 15) ältere Workouts ausgeblendet")
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.mutedInk)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
      }
    }
  }

  private func historyCard(_ workout: CompletedWorkoutSummary) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(workout.title.uppercased())
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        Spacer()
        Text(workout.finishedAt.formatted(date: .abbreviated, time: .omitted))
          .font(GainsFont.label(10))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(spacing: 16) {
        statTile(label: "SÄTZE", value: "\(workout.completedSets)/\(workout.totalSets)")
        statTile(label: "VOLUMEN", value: "\(Int(workout.volume)) kg")
        statTile(label: "ÜBUNGEN", value: "\(workout.exercises.count)")
      }
    }
    .padding(14)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func statTile(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(GainsFont.label(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(15))
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - MEINE TRAININGS

  @ViewBuilder
  private var meineTrainingsTab: some View {
    VStack(alignment: .leading, spacing: 18) {
      aiBanner
      manualCreateButton

      if let plannedWorkout = store.todayPlannedWorkout {
        section(title: "HEUTE GEPLANT", accent: true) {
          workoutRow(plannedWorkout, isPrimary: true)
        }
      }

      let custom = store.customWorkoutPlans
      if !custom.isEmpty {
        section(title: "MEINE TRAININGS") {
          VStack(spacing: 10) {
            ForEach(custom) { workout in
              workoutRow(workout)
            }
          }
        }
      } else {
        section(title: "MEINE TRAININGS") {
          emptyCustomCard
        }
      }
    }
  }

  private var aiBanner: some View {
    Button(action: onCreateWorkout) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: "sparkles")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(GainsColor.lime)
          Text("GAINS COACH")
            .font(GainsFont.label(10))
            .tracking(2.0)
            .foregroundStyle(GainsColor.lime)
        }

        Text("Workout für dich zusammenstellen")
          .font(GainsFont.title(20))
          .foregroundStyle(GainsColor.card)
          .multilineTextAlignment(.leading)

        Text("Wähle aus über \(ExerciseLibraryItem.fullCatalog.count) Übungen, sortiert nach Muskelgruppe und Equipment.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.card.opacity(0.78))
          .multilineTextAlignment(.leading)
          .lineLimit(3)

        HStack(spacing: 6) {
          Text("LOS GEHT'S")
            .font(GainsFont.label(10))
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
            .fill(GainsColor.ctaSurface)
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
          .tracking(2.0)
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

  // MARK: - GAINS-TRAINING

  private var gainsTrainingTab: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("VORGEFERTIGTE PLÄNE")
        .font(GainsFont.label(10))
        .tracking(2.0)
        .foregroundStyle(GainsColor.softInk)

      Text("Bewährte Trainingspläne nach Muskelgruppen und Splits.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .padding(.bottom, 4)

      VStack(spacing: 10) {
        ForEach(store.templateWorkoutPlans) { workout in
          workoutRow(workout)
        }
      }
    }
  }

  // MARK: - Shared Row

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
    EmptyStateView(
      style: .inline,
      title: "Noch keine eigenen Trainings",
      message: "Erstelle dein erstes Workout über den Button oben — du kannst aus über \(ExerciseLibraryItem.fullCatalog.count) Übungen wählen.",
      icon: "dumbbell"
    )
  }
}

// MARK: - Exercise Library Browser

struct ExerciseLibraryBrowser: View {
  @Environment(\.dismiss) private var dismiss
  @State private var searchText: String = ""
  @State private var selectedCategory: ExerciseCategory? = nil
  @State private var detailExercise: ExerciseLibraryItem? = nil

  private var filteredExercises: [ExerciseLibraryItem] {
    let base: [ExerciseLibraryItem]
    if let category = selectedCategory {
      base = ExerciseLibraryItem.library(for: category)
    } else {
      base = ExerciseLibraryItem.fullCatalog
    }
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if query.isEmpty { return base }
    return base.filter {
      $0.name.lowercased().contains(query)
        || $0.primaryMuscle.lowercased().contains(query)
        || $0.equipment.lowercased().contains(query)
    }
  }

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 18) {
        // Search
        HStack(spacing: 10) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
          TextField("Übung, Muskel oder Equipment suchen", text: $searchText)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
            .submitLabel(.search)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(GainsColor.card)
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(GainsColor.border.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        // Category filter
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            categoryChip(label: "Alle", category: nil)
            ForEach(ExerciseCategory.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { cat in
              categoryChip(label: cat.rawValue, category: cat)
            }
          }
          .padding(.vertical, 2)
        }

        // List
        Text("\(filteredExercises.count) ÜBUNGEN")
          .font(GainsFont.label(10))
          .tracking(2.0)
          .foregroundStyle(GainsColor.softInk)

        VStack(spacing: 8) {
          ForEach(filteredExercises) { exercise in
            Button {
              detailExercise = exercise
            } label: {
              libraryRow(exercise)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
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
        Text("ÜBUNGSBIBLIOTHEK")
          .font(GainsFont.label(11))
          .tracking(2.2)
          .foregroundStyle(GainsColor.ink)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $detailExercise) { exercise in
      NavigationStack {
        ExerciseDetailSheet(exercise: exercise)
      }
      .presentationDetents([.large])
    }
  }

  private func categoryChip(label: String, category: ExerciseCategory?) -> some View {
    let isSelected = category == selectedCategory
    return Button {
      withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
        selectedCategory = category
      }
    } label: {
      Text(label.uppercased())
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.softInk)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? GainsColor.lime : GainsColor.card)
        .overlay(
          Capsule()
            .stroke(isSelected ? Color.clear : GainsColor.border.opacity(0.5), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private func libraryRow(_ exercise: ExerciseLibraryItem) -> some View {
    HStack(spacing: 12) {
      Image(systemName: exercise.category.systemImage)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 40, height: 40)
        .background(Circle().fill(GainsColor.lime.opacity(0.12)))

      VStack(alignment: .leading, spacing: 3) {
        Text(exercise.name)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        HStack(spacing: 6) {
          Text(exercise.primaryMuscle)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
          Text("·")
            .foregroundStyle(GainsColor.softInk)
          Text(exercise.equipment)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
        }
      }

      Spacer()

      Image(systemName: "info.circle")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

// MARK: - ExerciseDetailSheet

struct ExerciseDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  let exercise: ExerciseLibraryItem

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        // Hero
        heroSection

        // Video / Placeholder
        videoSection

        // Muscles
        if !exercise.secondaryMuscles.isEmpty || !exercise.primaryMuscle.isEmpty {
          muscleSection
        }

        // Instructions
        if !exercise.instructions.isEmpty {
          instructionSection
        }

        // Tips
        if !exercise.tips.isEmpty {
          listSection(title: "TIPPS", icon: "lightbulb.fill", items: exercise.tips, color: GainsColor.lime)
        }

        // Common mistakes
        if !exercise.commonMistakes.isEmpty {
          listSection(title: "HÄUFIGE FEHLER", icon: "exclamationmark.triangle.fill", items: exercise.commonMistakes, color: GainsColor.ember)
        }

        // Defaults
        defaultSection
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Fertig") {
          dismiss()
        }
        .foregroundStyle(GainsColor.ink)
      }
    }
    .navigationBarTitleDisplayMode(.inline)
  }

  private var heroSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: exercise.category.systemImage)
          .font(.system(size: 12, weight: .heavy))
          .foregroundStyle(GainsColor.lime)
        Text(exercise.category.rawValue.uppercased())
          .font(GainsFont.label(10))
          .tracking(2.0)
          .foregroundStyle(GainsColor.lime)
        Spacer()
        difficultyBadge
      }

      Text(exercise.name)
        .font(GainsFont.display(28))
        .foregroundStyle(GainsColor.ink)

      HStack(spacing: 6) {
        Text(exercise.primaryMuscle)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
        Text("·")
          .foregroundStyle(GainsColor.softInk)
        Text(exercise.equipment)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
      }
    }
  }

  private var difficultyBadge: some View {
    let color: Color = {
      switch exercise.difficulty {
      case .beginner:     return GainsColor.moss
      case .intermediate: return GainsColor.lime
      case .advanced:     return GainsColor.ember
      }
    }()
    return Text(exercise.difficulty.rawValue.uppercased())
      .font(GainsFont.label(9))
      .tracking(1.4)
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color.opacity(0.14))
      .clipShape(Capsule())
  }

  @ViewBuilder
  private var videoSection: some View {
    if let url = exercise.videoURL {
      VideoPlayer(player: AVPlayer(url: url))
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    } else {
      VStack(spacing: 8) {
        Image(systemName: "play.rectangle.on.rectangle")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
        Text("Video-Demo folgt")
          .font(GainsFont.label(10))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
        Text("In einem späteren Update zeigt Gains hier eine Animation der Bewegung.")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.mutedInk)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 160)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
  }

  private var muscleSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader(title: "BEANSPRUCHTE MUSKELN", icon: "figure.strengthtraining.traditional")

      VStack(alignment: .leading, spacing: 6) {
        muscleRow(label: "Primär", value: exercise.primaryMuscle, isPrimary: true)
        if !exercise.secondaryMuscles.isEmpty {
          muscleRow(
            label: "Sekundär",
            value: exercise.secondaryMuscles.joined(separator: ", "),
            isPrimary: false
          )
        }
      }
    }
  }

  private func muscleRow(label: String, value: String, isPrimary: Bool) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(label.uppercased())
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
        .frame(width: 70, alignment: .leading)
      Text(value)
        .font(GainsFont.body(14))
        .foregroundStyle(isPrimary ? GainsColor.ink : GainsColor.softInk)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(GainsColor.border.opacity(0.3), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var instructionSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader(title: "ANLEITUNG", icon: "list.number")

      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
          HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
              .font(GainsFont.title(14))
              .foregroundStyle(GainsColor.onLime)
              .frame(width: 24, height: 24)
              .background(Circle().fill(GainsColor.lime))
            Text(step)
              .font(GainsFont.body(14))
              .foregroundStyle(GainsColor.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .padding(14)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }

  private func listSection(title: String, icon: String, items: [String], color: Color) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader(title: title, icon: icon)

      VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
          HStack(alignment: .top, spacing: 10) {
            Circle()
              .fill(color)
              .frame(width: 5, height: 5)
              .padding(.top, 7)
            Text(item)
              .font(GainsFont.body(14))
              .foregroundStyle(GainsColor.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .padding(14)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
  }

  private var defaultSection: some View {
    HStack(spacing: 10) {
      defaultTile(label: "SÄTZE", value: "\(exercise.defaultSets)")
      defaultTile(label: "REPS", value: "\(exercise.defaultReps)")
      if exercise.suggestedWeight > 0 {
        defaultTile(label: "GEWICHT", value: "\(Int(exercise.suggestedWeight)) kg")
      }
    }
  }

  private func defaultTile(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(GainsFont.label(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(GainsColor.border.opacity(0.3), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private func sectionHeader(title: String, icon: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 11, weight: .heavy))
        .foregroundStyle(GainsColor.lime)
      Text(title)
        .font(GainsFont.label(10))
        .tracking(2.0)
        .foregroundStyle(GainsColor.softInk)
      Rectangle()
        .fill(GainsColor.border.opacity(0.4))
        .frame(height: 1)
    }
  }
}
