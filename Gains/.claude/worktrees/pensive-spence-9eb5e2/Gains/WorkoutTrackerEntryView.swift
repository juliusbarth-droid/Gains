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
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
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
        Text("KRAFT-TRAINER")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
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
          VStack(spacing: GainsSpacing.xsPlus) {
            Text(segment.rawValue)
              .font(GainsFont.eyebrow)
              .tracking(GainsTracking.eyebrow)
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
    .padding(.bottom, GainsSpacing.xxs)
  }

  // MARK: - FORTSCHRITT

  /// Limit für die History-Liste — eine Konstante statt zweier verteilter
  /// Magic-Number-Stellen, sodass „prefix" und „count - X" immer synchron
  /// bleiben.
  private static let progressHistoryLimit = 15

  @ViewBuilder
  private var progressTab: some View {
    let history = store.workoutHistory
    if history.isEmpty {
      EmptyStateView(
        style: .prominent,
        title: "Noch kein Workout abgeschlossen",
        message: "Sobald du dein erstes Training durchgezogen hast, siehst du hier deine Historie mit Volumen und Sätzen.",
        icon: "chart.line.uptrend.xyaxis"
      )
    } else {
      let limit = Self.progressHistoryLimit
      let recent = history.prefix(limit)
      let hiddenCount = max(history.count - limit, 0)
      VStack(alignment: .leading, spacing: GainsSpacing.m) {
        Text("LETZTE WORKOUTS")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
          .foregroundStyle(GainsColor.softInk)

        VStack(spacing: GainsSpacing.tight) {
          ForEach(recent) { workout in
            historyCard(workout)
          }
        }

        if hiddenCount > 0 {
          Text("\(hiddenCount) ältere Workouts ausgeblendet")
            .font(GainsFont.caption)
            .foregroundStyle(GainsColor.mutedInk)
            .frame(maxWidth: .infinity)
            .padding(.top, GainsSpacing.xsPlus)
        }
      }
    }
  }

  private func historyCard(_ workout: CompletedWorkoutSummary) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      HStack {
        Text(workout.title.uppercased())
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        Spacer()
        Text(workout.finishedAt.formatted(date: .abbreviated, time: .omitted))
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(spacing: GainsSpacing.m) {
        statTile(label: "SÄTZE", value: "\(workout.completedSets)/\(workout.totalSets)")
        statTile(label: "VOLUMEN", value: "\(Int(workout.volume)) kg")
        statTile(label: "ÜBUNGEN", value: "\(workout.exercises.count)")
      }
    }
    .padding(GainsSpacing.m)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private func statTile(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(GainsFont.eyebrow)
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.metricSmall)
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - MEINE TRAININGS

  @ViewBuilder
  private var meineTrainingsTab: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.l) {
      // 2026-05-03 Cleanup: Vorher gab es hier zwei CTAs — einen großen
      // „GAINS COACH"-Banner und einen kleinen „MANUELL ERSTELLEN"-Button.
      // Beide riefen `onCreateWorkout` und öffneten denselben manuellen
      // Builder. Der Banner versprach eine KI-Generierung, die es im Code
      // nicht gibt. Konsolidiert in einen ehrlichen Builder-CTA.
      builderCTA

      if let plannedWorkout = store.todayPlannedWorkout {
        section(title: "HEUTE GEPLANT", accent: true) {
          workoutRow(plannedWorkout, isPrimary: true)
        }
      }

      let custom = store.customWorkoutPlans
      if !custom.isEmpty {
        section(title: "MEINE TRAININGS") {
          VStack(spacing: GainsSpacing.tight) {
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

  private var builderCTA: some View {
    Button(action: onCreateWorkout) {
      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        HStack(spacing: GainsSpacing.xsPlus) {
          Image(systemName: "plus.rectangle.on.rectangle")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(GainsColor.lime)
          Text("WORKOUT BUILDER")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.lime)
        }

        Text("Eigenes Workout zusammenstellen")
          .font(GainsFont.title)
          .foregroundStyle(GainsColor.onCtaSurface)
          .multilineTextAlignment(.leading)

        Text("Du entscheidest selbst: \(ExerciseLibraryItem.fullCatalog.count) Übungen, freie Reihenfolge, Sätze und Reps direkt am Tile anpassbar.")
          .font(GainsFont.body)
          .foregroundStyle(GainsColor.onCtaSurface.opacity(0.78))
          .multilineTextAlignment(.leading)
          .lineLimit(3)

        HStack(spacing: GainsSpacing.xs) {
          Text("LOS GEHT'S")
            .font(GainsFont.eyebrow)
            .tracking(GainsTracking.eyebrowWide)
            .foregroundStyle(GainsColor.lime)
          Image(systemName: "arrow.right")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(GainsColor.lime)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(GainsSpacing.l)
      .background(
        ZStack {
          RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
            .fill(GainsColor.ctaSurface)
          LinearGradient(
            colors: [GainsColor.lime.opacity(0.22), GainsColor.lime.opacity(0.0)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
          .stroke(GainsColor.lime.opacity(0.35), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Eigenes Workout zusammenstellen")
  }

  // MARK: - GAINS-TRAINING

  private var gainsTrainingTab: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      Text("VORGEFERTIGTE PLÄNE")
        .font(GainsFont.eyebrow)
        .tracking(GainsTracking.eyebrowWide)
        .foregroundStyle(GainsColor.softInk)

      Text("Bewährte Trainingspläne nach Muskelgruppen und Splits.")
        .font(GainsFont.body)
        .foregroundStyle(GainsColor.softInk)
        .padding(.bottom, GainsSpacing.xxs)

      VStack(spacing: GainsSpacing.tight) {
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
      HStack(spacing: GainsSpacing.m) {
        Image(systemName: isPrimary ? "flame.fill" : "dumbbell.fill")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(isPrimary ? GainsColor.onLime : GainsColor.lime)
          .frame(width: 44, height: 44)
          .background(
            Circle()
              .fill(isPrimary ? GainsColor.lime : GainsColor.lime.opacity(0.14))
          )

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(workout.title.uppercased())
            .font(GainsFont.headline)
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Text("\(workout.exercises.count) Übungen · \(workout.estimatedDurationMinutes) min")
            .font(GainsFont.caption)
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(GainsColor.softInk.opacity(0.7))
      }
      .padding(.horizontal, GainsSpacing.m)
      .padding(.vertical, GainsSpacing.s)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(
            isPrimary ? GainsColor.lime.opacity(0.6) : GainsColor.border.opacity(0.4),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func section<Content: View>(
    title: String,
    accent: Bool = false,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack(spacing: GainsSpacing.xsPlus) {
        Circle()
          .fill(accent ? GainsColor.lime : GainsColor.softInk.opacity(0.45))
          .frame(width: 5, height: 5)
        Text(title)
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrowWide)
          .foregroundStyle(accent ? GainsColor.lime : GainsColor.softInk)
        Rectangle()
          .fill(GainsColor.border.opacity(0.4))
          .frame(height: 1)
          .padding(.leading, GainsSpacing.xxs)
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
      VStack(alignment: .leading, spacing: GainsSpacing.l) {
        // Search
        HStack(spacing: GainsSpacing.tight) {
          Image(systemName: "magnifyingglass")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
          TextField("Übung, Muskel oder Equipment suchen", text: $searchText)
            .font(GainsFont.body(14))
            .foregroundStyle(GainsColor.ink)
            .submitLabel(.search)
        }
        .padding(.horizontal, GainsSpacing.m)
        .padding(.vertical, GainsSpacing.s)
        .background(GainsColor.card)
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .stroke(GainsColor.border.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

        // Category filter
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: GainsSpacing.xsPlus) {
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

        VStack(spacing: GainsSpacing.xsPlus) {
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
        .padding(.horizontal, GainsSpacing.m)
        .padding(.vertical, GainsSpacing.xsPlus)
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
    HStack(spacing: GainsSpacing.s) {
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
        HStack(spacing: GainsSpacing.xs) {
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
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.tight)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }
}

// MARK: - ExerciseDetailSheet

struct ExerciseDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  let exercise: ExerciseLibraryItem

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
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
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      HStack(spacing: GainsSpacing.xsPlus) {
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

      HStack(spacing: GainsSpacing.xs) {
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
      .padding(.horizontal, GainsSpacing.xsPlus)
      .padding(.vertical, GainsSpacing.xxs)
      .background(color.opacity(0.14))
      .clipShape(Capsule())
  }

  @ViewBuilder
  private var videoSection: some View {
    // 2026-05-03 Cleanup: Vorher rendern wir hier eine Platzhalter-Card
    // („Video-Demo folgt"), wenn keine `videoURL` gesetzt war — und genau
    // das ist aktuell für ALLE Übungen der Fall. Effekt: jeder Detail-Sheet
    // bewarb ein Feature, das es im Code nicht gibt. Solange wir keine
    // echten Demo-Videos einpflegen, zeigen wir hier einfach gar nichts;
    // sobald `videoURL` für eine Übung gesetzt ist, springt der VideoPlayer
    // an. Anleitung + Tipps weiter unten reichen, um die Bewegung zu
    // verstehen.
    if let url = exercise.videoURL {
      VideoPlayer(player: AVPlayer(url: url))
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
  }

  private var muscleSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      sectionHeader(title: "BEANSPRUCHTE MUSKELN", icon: "figure.strengthtraining.traditional")

      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
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
    HStack(alignment: .firstTextBaseline, spacing: GainsSpacing.s) {
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
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.tight)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.3), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private var instructionSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      sectionHeader(title: "ANLEITUNG", icon: "list.number")

      VStack(alignment: .leading, spacing: GainsSpacing.tight) {
        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
          HStack(alignment: .top, spacing: GainsSpacing.s) {
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
      .padding(GainsSpacing.m)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
  }

  private func listSection(title: String, icon: String, items: [String], color: Color) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      sectionHeader(title: title, icon: icon)

      VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
          HStack(alignment: .top, spacing: GainsSpacing.tight) {
            Circle()
              .fill(color)
              .frame(width: 5, height: 5)
              .padding(.top, GainsSpacing.xsPlus)
            Text(item)
              .font(GainsFont.body(14))
              .foregroundStyle(GainsColor.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .padding(GainsSpacing.m)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
  }

  private var defaultSection: some View {
    HStack(spacing: GainsSpacing.tight) {
      defaultTile(label: "SÄTZE", value: "\(exercise.defaultSets)")
      defaultTile(label: "REPS", value: "\(exercise.defaultReps)")
      if exercise.suggestedWeight > 0 {
        defaultTile(label: "GEWICHT", value: "\(Int(exercise.suggestedWeight)) kg")
      }
    }
  }

  private func defaultTile(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
      Text(label)
        .font(GainsFont.label(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(GainsSpacing.s)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.3), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private func sectionHeader(title: String, icon: String) -> some View {
    HStack(spacing: GainsSpacing.xsPlus) {
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
