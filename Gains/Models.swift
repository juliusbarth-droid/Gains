import CoreLocation
import Foundation

enum AppTab: Hashable {
  case home
  case workout
  case recipes
  case progress
  case community

  var title: String {
    switch self {
    case .home:
      return "Today"
    case .workout:
      return "Train"
    case .recipes:
      return "Fuel"
    case .progress:
      return "Body"
    case .community:
      return "Crew"
    }
  }
}

enum CaptureKind: String, CaseIterable, Identifiable {
  case workout
  case run
  case progress
  case meal

  var id: Self { self }

  var title: String {
    switch self {
    case .workout:
      return "Workout"
    case .run:
      return "Lauf"
    case .progress:
      return "Progress"
    case .meal:
      return "Meal"
    }
  }

  var actionTitle: String {
    switch self {
    case .workout:
      return "Workout posten"
    case .run:
      return "Lauf posten"
    case .progress:
      return "Progress teilen"
    case .meal:
      return "Meal loggen"
    }
  }

  var systemImage: String {
    switch self {
    case .workout:
      return "dumbbell.fill"
    case .run:
      return "figure.run"
    case .progress:
      return "chart.line.uptrend.xyaxis"
    case .meal:
      return "fork.knife"
    }
  }
}

enum AppWorkoutWorkspace: String, Hashable {
  case kraft
  case laufen
  case fortschritt
}

struct EvidenceSource: Identifiable {
  let id = UUID()
  let title: String
  let context: String
  let link: String
}

struct TrainingRecommendation: Identifiable {
  let id = UUID()
  let title: String
  let scenario: String
  let recommendation: String
  let sources: [EvidenceSource]
}

struct HomeViewModel {
  let userName: String
  let streakDays: Int
  let recordDays: Int
  let weekSessions: Int
  let weeklyGoal: Int
  let trainingVolumeTons: Double
  let personalRecords: Int
  let workoutTitle: String
  let workoutFocus: String
  let exercises: Int
  let durationMinutes: Int
  let coachHeadline: String
  let coachDescription: String
  let socialHeadline: String
  let socialDescription: String
  let cardioRiskImprovement: Int
  let bodyFatChange: Double
  let bloodPanelStatus: String
  let weekDays: [DayProgress]
  let workoutPlan: WorkoutPlan
}

struct DayProgress: Identifiable {
  enum Status {
    case completed
    case planned
    case flexible
    case rest
    case today
  }

  let date: Date
  let shortLabel: String
  let dayNumber: Int
  let status: Status

  var id: Date { date }
}

struct CoachViewModel {
  let coachName: String
  let focus: String
  let nutritionAdherence: Int
  let recoveryScore: Int
  let stepGoal: Int
  let hydrationGoalLiters: Double
  let sleepTargetHours: Double
  let recommendations: [String]
  let checkIns: [CoachCheckIn]
}

struct ProgressViewModel {
  let startWeight: Double
  let currentWeight: Double
  let waistChange: Double
  let cardioRiskImprovement: Int
  let bloodPanelSummary: [HealthMetric]
  let milestones: [ProgressMilestone]
  let weeklyTrend: [WeightTrendPoint]
  let goals: [ProgressGoal]
  let trackerOptions: [TrackerDevice]
  let vitalReadings: [VitalReading]
}

struct CommunityViewModel {
  let headline: String
  let challengeTitle: String
  let challengeParticipants: Int
  let challengeBenefits: [String]
  let composerPrompts: [CommunityComposerAction]
  let posts: [CommunityPost]
}

struct RecipesViewModel {
  let headline: String
  let subtitle: String
  let recipes: [Recipe]
}

struct HealthMetric: Identifiable {
  let id = UUID()
  let title: String
  let value: String
  let trend: String
}

struct ProgressMilestone: Identifiable {
  let id = UUID()
  let title: String
  let detail: String
  let dateLabel: String
}

struct CommunityPost: Identifiable {
  let id: UUID
  let author: String
  let handle: String
  let type: CommunityPostType
  let title: String
  let detail: String
  let timeAgo: String
  let placeholderSymbol: String
  let highlightMetrics: [CommunityMetric]
  let reactions: Int
  let comments: Int
  let shares: Int
}

enum CommunityPostType: String, CaseIterable {
  case all
  case workout
  case run
  case progress

  var title: String {
    switch self {
    case .all:
      return "Alle"
    case .workout:
      return "Workouts"
    case .run:
      return "Läufe"
    case .progress:
      return "Progress"
    }
  }
}

struct CommunityComposerAction: Identifiable {
  let id = UUID()
  let title: String
  let type: CommunityPostType
  let systemImage: String
}

struct CommunityMetric: Identifiable {
  let id = UUID()
  let label: String
  let value: String
}

struct CommunityContact: Identifiable {
  let id: String
  let displayName: String
  let subtitle: String
  let initials: String
}

struct CoachCheckIn: Identifiable {
  let id: UUID
  let title: String
  let detail: String
}

struct WeightTrendPoint: Identifiable {
  let id = UUID()
  let label: String
  let value: Double
}

struct ProgressGoal: Identifiable {
  let id = UUID()
  let title: String
  let current: Double
  let target: Double
  let unit: String
}

struct PerformanceProgressStat: Identifiable {
  let id = UUID()
  let title: String
  let value: String
  let subtitle: String
}

struct ExerciseStrengthProgress: Identifiable {
  let id = UUID()
  let exerciseName: String
  let currentValue: String
  let deltaLabel: String
  let subtitle: String
}

struct HealthPresentationStat: Identifiable {
  let id = UUID()
  let title: String
  let value: String
  let subtitle: String
}

struct Recipe: Identifiable {
  let id: UUID
  let title: String
  let category: String
  let goal: RecipeGoal
  let dietaryStyle: RecipeDietaryStyle
  let mealType: RecipeMealType
  let imageURL: String
  let placeholderSymbol: String
  let prepMinutes: Int
  let calories: Int
  let protein: Int
  let carbs: Int
  let fat: Int
  let ingredients: [String]
  let steps: [String]
}

struct NutritionEntry: Identifiable {
  let id: UUID
  let title: String
  let mealType: RecipeMealType
  let loggedAt: Date
  let calories: Int
  let protein: Int
  let carbs: Int
  let fat: Int
}

enum RecipeGoal: String, CaseIterable {
  case highProtein
  case abnehmen
  case zunehmen

  var title: String {
    switch self {
    case .highProtein:
      return "High Protein"
    case .abnehmen:
      return "Abnehmen"
    case .zunehmen:
      return "Zunehmen"
    }
  }
}

enum NutritionGoal: String, CaseIterable {
  case muscleGain
  case fatLoss
  case maintain

  var title: String {
    switch self {
    case .muscleGain:
      return "Muskelaufbau"
    case .fatLoss:
      return "Abnehmen"
    case .maintain:
      return "Halten"
    }
  }

  var shortTitle: String {
    switch self {
    case .muscleGain:
      return "Aufbauen"
    case .fatLoss:
      return "Abnehmen"
    case .maintain:
      return "Halten"
    }
  }

  var detail: String {
    switch self {
    case .muscleGain:
      return "Leichter Kalorienüberschuss und hohes Protein."
    case .fatLoss:
      return "Kaloriendefizit mit Fokus auf Sättigung und Protein."
    case .maintain:
      return "Gewicht halten und ausgewogen tracken."
    }
  }

  var systemImage: String {
    switch self {
    case .muscleGain:
      return "figure.strengthtraining.traditional"
    case .fatLoss:
      return "figure.run"
    case .maintain:
      return "equal.circle"
    }
  }
}

enum RecipeDietaryStyle: String, CaseIterable {
  case all
  case omnivore
  case vegetarian
  case vegan

  var title: String {
    switch self {
    case .all:
      return "Alle"
    case .omnivore:
      return "Alles"
    case .vegetarian:
      return "Vegetarisch"
    case .vegan:
      return "Vegan"
    }
  }

  var systemImage: String {
    switch self {
    case .all:
      return "line.3.horizontal.decrease.circle"
    case .omnivore:
      return "fork.knife"
    case .vegetarian:
      return "leaf"
    case .vegan:
      return "leaf.fill"
    }
  }
}

enum RecipeMealType: String, CaseIterable {
  case breakfast
  case lunchDinner
  case snack
  case dessert
  case shake

  var title: String {
    switch self {
    case .breakfast:
      return "Frühstück"
    case .lunchDinner:
      return "Mittag- / Abendessen"
    case .snack:
      return "Snacks"
    case .dessert:
      return "Dessert"
    case .shake:
      return "Shake"
    }
  }

  var systemImage: String {
    switch self {
    case .breakfast:
      return "sun.max.fill"
    case .lunchDinner:
      return "fork.knife"
    case .snack:
      return "takeoutbag.and.cup.and.straw.fill"
    case .dessert:
      return "birthday.cake.fill"
    case .shake:
      return "cup.and.saucer.fill"
    }
  }

  var shortTitle: String {
    switch self {
    case .breakfast:
      return "Frühstück"
    case .lunchDinner:
      return "Lunch / Dinner"
    case .snack:
      return "Snack"
    case .dessert:
      return "Dessert"
    case .shake:
      return "Shake"
    }
  }
}

struct WorkoutHubViewModel {
  let headline: String
  let subtitle: String
  let todayPlan: WorkoutPlan
  let weeklySchedule: [WorkoutDayPlan]
}

enum Weekday: Int, CaseIterable, Identifiable {
  case monday = 2
  case tuesday = 3
  case wednesday = 4
  case thursday = 5
  case friday = 6
  case saturday = 7
  case sunday = 1

  var id: Int { rawValue }

  var shortLabel: String {
    switch self {
    case .monday: return "MO"
    case .tuesday: return "DI"
    case .wednesday: return "MI"
    case .thursday: return "DO"
    case .friday: return "FR"
    case .saturday: return "SA"
    case .sunday: return "SO"
    }
  }

  var title: String {
    switch self {
    case .monday: return "Montag"
    case .tuesday: return "Dienstag"
    case .wednesday: return "Mittwoch"
    case .thursday: return "Donnerstag"
    case .friday: return "Freitag"
    case .saturday: return "Samstag"
    case .sunday: return "Sonntag"
    }
  }

  static var today: Weekday {
    let calendarWeekday = Calendar.current.component(.weekday, from: Date())
    return Weekday(rawValue: calendarWeekday) ?? .monday
  }
}

enum WorkoutDayPreference: String, CaseIterable {
  case training
  case rest
  case flexible

  var title: String {
    switch self {
    case .training:
      return "Training"
    case .rest:
      return "Frei"
    case .flexible:
      return "Flexibel"
    }
  }
}

enum WorkoutPlanningGoal: String, CaseIterable {
  case muscleGain
  case fatLoss
  case performance

  var title: String {
    switch self {
    case .muscleGain:
      return "Muskelaufbau"
    case .fatLoss:
      return "Abnehmen"
    case .performance:
      return "Leistung"
    }
  }
}

enum WorkoutTrainingFocus: String, CaseIterable {
  case strength
  case cardio
  case hybrid

  var title: String {
    switch self {
    case .strength:
      return "Krafttraining"
    case .cardio:
      return "Cardio Athlet"
    case .hybrid:
      return "Hybrid Athlet"
    }
  }

  var shortTitle: String {
    switch self {
    case .strength:
      return "Kraft"
    case .cardio:
      return "Cardio"
    case .hybrid:
      return "Hybrid"
    }
  }

  var detail: String {
    switch self {
    case .strength:
      return "Priorisiert Muskelaufbau, Kraftwerte und klare Gym-Splits."
    case .cardio:
      return "Priorisiert Laufen, Ausdauer und Herz-Kreislauf-Leistung."
    case .hybrid:
      return "Verbindet Kraft und Ausdauer in einem ausgewogenen Wochenplan."
    }
  }
}

struct WorkoutPlannerSettings {
  var sessionsPerWeek: Int
  var preferredSessionLength: Int
  var goal: WorkoutPlanningGoal
  var trainingFocus: WorkoutTrainingFocus
  var dayPreferences: [Weekday: WorkoutDayPreference]
  var dayAssignments: [Weekday: UUID]

  static let `default` = WorkoutPlannerSettings(
    sessionsPerWeek: 4,
    preferredSessionLength: 60,
    goal: .muscleGain,
    trainingFocus: .hybrid,
    dayPreferences: [
      .monday: .training,
      .tuesday: .rest,
      .wednesday: .training,
      .thursday: .flexible,
      .friday: .training,
      .saturday: .training,
      .sunday: .rest,
    ],
    dayAssignments: [:]
  )
}

enum WorkoutDayStatus {
  case planned
  case rest
  case flexible
}

struct WorkoutDayPlan: Identifiable {
  let id = UUID()
  let weekday: Weekday
  let dayLabel: String
  let title: String
  let focus: String
  let isToday: Bool
  let status: WorkoutDayStatus
  let workoutPlan: WorkoutPlan?
}

struct PlannerRecommendation: Identifiable {
  let id = UUID()
  let title: String
  let detail: String
  let weekdays: [Weekday]
}

struct TrackerDevice: Identifiable {
  let id: UUID
  let name: String
  let source: String
  let accentHex: String
}

struct VitalReading: Identifiable {
  let id = UUID()
  let title: String
  let value: String
  let context: String
}

enum WorkoutPlanSource: Equatable {
  case template
  case custom

  var title: String {
    switch self {
    case .template:
      return "Vorgefertigt"
    case .custom:
      return "Eigen"
    }
  }
}

struct WorkoutPlan: Identifiable {
  let id: UUID
  let source: WorkoutPlanSource
  let title: String
  let focus: String
  let split: String
  let estimatedDurationMinutes: Int
  let exercises: [WorkoutExerciseTemplate]

  init(
    id: UUID = UUID(),
    source: WorkoutPlanSource = .template,
    title: String,
    focus: String,
    split: String,
    estimatedDurationMinutes: Int,
    exercises: [WorkoutExerciseTemplate]
  ) {
    self.id = id
    self.source = source
    self.title = title
    self.focus = focus
    self.split = split
    self.estimatedDurationMinutes = estimatedDurationMinutes
    self.exercises = exercises
  }
}

struct WorkoutExerciseTemplate: Identifiable {
  let id = UUID()
  let name: String
  let targetMuscle: String
  let sets: [WorkoutSetTemplate]
}

struct WorkoutSetTemplate {
  let reps: Int
  let suggestedWeight: Double
}

struct ExerciseLibraryItem: Identifiable, Hashable {
  let id = UUID()
  let name: String
  let primaryMuscle: String
  let equipment: String
  let defaultSets: Int
  let defaultReps: Int
  let suggestedWeight: Double
}

struct WorkoutSession: Identifiable {
  let id = UUID()
  let title: String
  let focus: String
  let startedAt: Date
  var exercises: [TrackedExercise]

  var totalSets: Int {
    exercises.reduce(0) { $0 + $1.sets.count }
  }

  var completedSets: Int {
    exercises.reduce(0) { partial, exercise in
      partial + exercise.sets.filter(\.isCompleted).count
    }
  }

  var totalVolume: Double {
    exercises.reduce(0) { partial, exercise in
      partial + exercise.sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
  }
}

struct TrackedExercise: Identifiable {
  let id = UUID()
  let name: String
  let targetMuscle: String
  var sets: [TrackedSet]
}

struct TrackedSet: Identifiable {
  let id = UUID()
  let order: Int
  var reps: Int
  var weight: Double
  var isCompleted: Bool
}

struct CompletedWorkoutSummary: Identifiable {
  let id = UUID()
  let title: String
  let finishedAt: Date
  let completedSets: Int
  let totalSets: Int
  let volume: Double
  let exercises: [CompletedExercisePerformance]

  init(
    title: String,
    finishedAt: Date,
    completedSets: Int,
    totalSets: Int,
    volume: Double,
    exercises: [CompletedExercisePerformance] = []
  ) {
    self.title = title
    self.finishedAt = finishedAt
    self.completedSets = completedSets
    self.totalSets = totalSets
    self.volume = volume
    self.exercises = exercises
  }
}

struct CompletedExercisePerformance: Identifiable {
  let id = UUID()
  let name: String
  let completedSets: Int
  let totalReps: Int
  let topWeight: Double
  let totalVolume: Double
}

struct RunTemplate: Identifiable {
  let id: UUID
  let title: String
  let subtitle: String
  let routeName: String
  let targetDistanceKm: Double
  let targetDurationMinutes: Int
  let targetPaceLabel: String
  let systemImage: String
}

struct RunSplit: Identifiable {
  let id: UUID
  let index: Int
  let distanceKm: Double
  let durationMinutes: Int
  let averageHeartRate: Int

  var paceSeconds: Int {
    guard distanceKm > 0 else { return 0 }
    return Int((Double(durationMinutes) * 60) / distanceKm)
  }
}

struct ActiveRunSession: Identifiable {
  let id: UUID
  let title: String
  let routeName: String
  let startedAt: Date
  let targetDistanceKm: Double
  let targetDurationMinutes: Int
  let targetPaceLabel: String
  var distanceKm: Double
  var durationMinutes: Int
  var elevationGain: Int
  var currentHeartRate: Int
  var isPaused: Bool
  var routeCoordinates: [CLLocationCoordinate2D]
  var splits: [RunSplit]

  var averagePaceSeconds: Int {
    guard distanceKm > 0 else { return 0 }
    return Int((Double(durationMinutes) * 60) / distanceKm)
  }
}

struct CompletedRunSummary: Identifiable {
  let id: UUID
  let title: String
  let routeName: String
  let finishedAt: Date
  let distanceKm: Double
  let durationMinutes: Int
  let elevationGain: Int
  let averageHeartRate: Int
  let routeCoordinates: [CLLocationCoordinate2D]
  let splits: [RunSplit]

  var averagePaceSeconds: Int {
    guard distanceKm > 0 else { return 0 }
    return Int((Double(durationMinutes) * 60) / distanceKm)
  }
}

struct RunPersonalBest: Identifiable {
  let id = UUID()
  let title: String
  let value: String
  let context: String
}

extension WorkoutSession {
  static func fromPlan(_ plan: WorkoutPlan) -> WorkoutSession {
    WorkoutSession(
      title: plan.title,
      focus: plan.focus,
      startedAt: Date(),
      exercises: plan.exercises.map { exercise in
        TrackedExercise(
          name: exercise.name,
          targetMuscle: exercise.targetMuscle,
          sets: exercise.sets.enumerated().map { index, set in
            TrackedSet(
              order: index + 1,
              reps: set.reps,
              weight: set.suggestedWeight,
              isCompleted: false
            )
          }
        )
      }
    )
  }
}

extension RunTemplate {
  static let stravaInspiredTemplates: [RunTemplate] = [
    RunTemplate(
      id: UUID(uuidString: "51515151-5151-5151-5151-515151515151")!,
      title: "Easy 5K",
      subtitle: "Lockerer Dauerlauf für Grundlagenausdauer",
      routeName: "Stadtpark Loop",
      targetDistanceKm: 5.0,
      targetDurationMinutes: 29,
      targetPaceLabel: "5:48 /km",
      systemImage: "figure.run"
    ),
    RunTemplate(
      id: UUID(uuidString: "52525252-5252-5252-5252-525252525252")!,
      title: "Tempo 8K",
      subtitle: "Strava-artiger Pace-Fokus für deinen Wochenreiz",
      routeName: "River Side Out & Back",
      targetDistanceKm: 8.0,
      targetDurationMinutes: 38,
      targetPaceLabel: "4:45 /km",
      systemImage: "bolt.heart.fill"
    ),
    RunTemplate(
      id: UUID(uuidString: "53535353-5353-5353-5353-535353535353")!,
      title: "Long Run 12K",
      subtitle: "Ausdauerblock mit ruhigem Puls und etwas Höhenmetern",
      routeName: "Forest Hills Route",
      targetDistanceKm: 12.0,
      targetDurationMinutes: 68,
      targetPaceLabel: "5:40 /km",
      systemImage: "map.fill"
    ),
    RunTemplate(
      id: UUID(uuidString: "54545454-5454-5454-5454-545454545454")!,
      title: "Recovery Run",
      subtitle: "Kurz, locker und sauber für den nächsten Trainingstag",
      routeName: "Canal Recovery Loop",
      targetDistanceKm: 4.2,
      targetDurationMinutes: 26,
      targetPaceLabel: "6:10 /km",
      systemImage: "heart.circle.fill"
    ),
  ]
}

extension ActiveRunSession {
  static func fromTemplate(_ template: RunTemplate) -> ActiveRunSession {
    ActiveRunSession(
      id: UUID(),
      title: template.title,
      routeName: template.routeName,
      startedAt: Date(),
      targetDistanceKm: template.targetDistanceKm,
      targetDurationMinutes: template.targetDurationMinutes,
      targetPaceLabel: template.targetPaceLabel,
      distanceKm: 0,
      durationMinutes: 0,
      elevationGain: 0,
      currentHeartRate: 136,
      isPaused: false,
      routeCoordinates: [],
      splits: []
    )
  }
}

extension CompletedRunSummary {
  static let mockHistory: [CompletedRunSummary] = [
    CompletedRunSummary(
      id: UUID(uuidString: "61616161-6161-6161-6161-616161616161")!,
      title: "Morning 10K",
      routeName: "River Side Out & Back",
      finishedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
      distanceKm: 10.2,
      durationMinutes: 49,
      elevationGain: 84,
      averageHeartRate: 148,
      routeCoordinates: [],
      splits: [
        RunSplit(id: UUID(), index: 1, distanceKm: 1.0, durationMinutes: 5, averageHeartRate: 143),
        RunSplit(id: UUID(), index: 2, distanceKm: 1.0, durationMinutes: 5, averageHeartRate: 146),
        RunSplit(id: UUID(), index: 3, distanceKm: 1.0, durationMinutes: 4, averageHeartRate: 149),
      ]
    ),
    CompletedRunSummary(
      id: UUID(uuidString: "62626262-6262-6262-6262-626262626262")!,
      title: "Easy 5K",
      routeName: "Stadtpark Loop",
      finishedAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
      distanceKm: 5.0,
      durationMinutes: 28,
      elevationGain: 32,
      averageHeartRate: 142,
      routeCoordinates: [],
      splits: [
        RunSplit(id: UUID(), index: 1, distanceKm: 1.0, durationMinutes: 6, averageHeartRate: 139),
        RunSplit(id: UUID(), index: 2, distanceKm: 1.0, durationMinutes: 5, averageHeartRate: 141),
      ]
    ),
    CompletedRunSummary(
      id: UUID(uuidString: "63636363-6363-6363-6363-636363636363")!,
      title: "Long Run",
      routeName: "Forest Hills Route",
      finishedAt: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
      distanceKm: 13.4,
      durationMinutes: 76,
      elevationGain: 168,
      averageHeartRate: 151,
      routeCoordinates: [],
      splits: [
        RunSplit(id: UUID(), index: 1, distanceKm: 2.0, durationMinutes: 12, averageHeartRate: 145),
        RunSplit(id: UUID(), index: 2, distanceKm: 2.0, durationMinutes: 11, averageHeartRate: 149),
        RunSplit(id: UUID(), index: 3, distanceKm: 2.0, durationMinutes: 11, averageHeartRate: 152),
      ]
    ),
  ]
}

extension CompletedWorkoutSummary {
  static let mockHistory: [CompletedWorkoutSummary] = [
    CompletedWorkoutSummary(
      title: "Push",
      finishedAt: Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date(),
      completedSets: 16,
      totalSets: 16,
      volume: 4380,
      exercises: [
        CompletedExercisePerformance(
          name: "Bankdrücken", completedSets: 4, totalReps: 32, topWeight: 72.5, totalVolume: 2320),
        CompletedExercisePerformance(
          name: "Schrägbank Kurzhantel", completedSets: 3, totalReps: 30, topWeight: 26,
          totalVolume: 1560),
        CompletedExercisePerformance(
          name: "Trizeps Pushdown", completedSets: 3, totalReps: 36, topWeight: 34,
          totalVolume: 1224),
      ]
    ),
    CompletedWorkoutSummary(
      title: "Upper A",
      finishedAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
      completedSets: 18,
      totalSets: 18,
      volume: 5025,
      exercises: [
        CompletedExercisePerformance(
          name: "Bankdrücken", completedSets: 4, totalReps: 30, topWeight: 77.5, totalVolume: 2480),
        CompletedExercisePerformance(
          name: "Klimmzüge", completedSets: 4, totalReps: 28, topWeight: 0, totalVolume: 0),
        CompletedExercisePerformance(
          name: "Rudern sitzend", completedSets: 4, totalReps: 40, topWeight: 60, totalVolume: 2400),
      ]
    ),
    CompletedWorkoutSummary(
      title: "Push",
      finishedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
      completedSets: 17,
      totalSets: 17,
      volume: 5480,
      exercises: [
        CompletedExercisePerformance(
          name: "Bankdrücken", completedSets: 4, totalReps: 29, topWeight: 82.5, totalVolume: 2645),
        CompletedExercisePerformance(
          name: "Schrägbank Kurzhantel", completedSets: 3, totalReps: 30, topWeight: 28,
          totalVolume: 1680),
        CompletedExercisePerformance(
          name: "Trizeps Pushdown", completedSets: 3, totalReps: 36, topWeight: 38,
          totalVolume: 1368),
      ]
    ),
  ]
}

extension ExerciseLibraryItem {
  static let commonGymExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Bankdrücken", primaryMuscle: "Brust", equipment: "Langhantel", defaultSets: 4,
      defaultReps: 8, suggestedWeight: 60),
    ExerciseLibraryItem(
      name: "Schrägbank Kurzhantel", primaryMuscle: "Brust", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 10, suggestedWeight: 24),
    ExerciseLibraryItem(
      name: "Kabelzug Flys", primaryMuscle: "Brust", equipment: "Kabelzug", defaultSets: 3,
      defaultReps: 12, suggestedWeight: 18),
    ExerciseLibraryItem(
      name: "Schulterdrücken", primaryMuscle: "Schulter", equipment: "Kurzhantel", defaultSets: 4,
      defaultReps: 8, suggestedWeight: 22),
    ExerciseLibraryItem(
      name: "Seitheben", primaryMuscle: "Schulter", equipment: "Kurzhantel", defaultSets: 3,
      defaultReps: 15, suggestedWeight: 10),
    ExerciseLibraryItem(
      name: "Face Pulls", primaryMuscle: "Schulter", equipment: "Kabelzug", defaultSets: 3,
      defaultReps: 15, suggestedWeight: 25),
    ExerciseLibraryItem(
      name: "Klimmzüge", primaryMuscle: "Rücken", equipment: "Körpergewicht", defaultSets: 4,
      defaultReps: 8, suggestedWeight: 0),
    ExerciseLibraryItem(
      name: "Latzug", primaryMuscle: "Rücken", equipment: "Maschine", defaultSets: 4,
      defaultReps: 10, suggestedWeight: 55),
    ExerciseLibraryItem(
      name: "Rudern sitzend", primaryMuscle: "Rücken", equipment: "Kabelzug", defaultSets: 4,
      defaultReps: 10, suggestedWeight: 55),
    ExerciseLibraryItem(
      name: "Langhantelrudern", primaryMuscle: "Rücken", equipment: "Langhantel", defaultSets: 4,
      defaultReps: 8, suggestedWeight: 60),
    ExerciseLibraryItem(
      name: "Bizepscurls", primaryMuscle: "Bizeps", equipment: "Kurzhantel", defaultSets: 3,
      defaultReps: 12, suggestedWeight: 14),
    ExerciseLibraryItem(
      name: "Hammercurls", primaryMuscle: "Bizeps", equipment: "Kurzhantel", defaultSets: 3,
      defaultReps: 12, suggestedWeight: 16),
    ExerciseLibraryItem(
      name: "Trizeps Pushdown", primaryMuscle: "Trizeps", equipment: "Kabelzug", defaultSets: 3,
      defaultReps: 12, suggestedWeight: 32),
    ExerciseLibraryItem(
      name: "French Press", primaryMuscle: "Trizeps", equipment: "SZ-Stange", defaultSets: 3,
      defaultReps: 10, suggestedWeight: 25),
    ExerciseLibraryItem(
      name: "Dips", primaryMuscle: "Trizeps", equipment: "Körpergewicht", defaultSets: 3,
      defaultReps: 10, suggestedWeight: 0),
    ExerciseLibraryItem(
      name: "Kniebeugen", primaryMuscle: "Beine", equipment: "Langhantel", defaultSets: 4,
      defaultReps: 6, suggestedWeight: 80),
    ExerciseLibraryItem(
      name: "Beinpresse", primaryMuscle: "Beine", equipment: "Maschine", defaultSets: 4,
      defaultReps: 10, suggestedWeight: 140),
    ExerciseLibraryItem(
      name: "Rumänisches Kreuzheben", primaryMuscle: "Beine", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 8, suggestedWeight: 90),
    ExerciseLibraryItem(
      name: "Beinstrecker", primaryMuscle: "Beine", equipment: "Maschine", defaultSets: 3,
      defaultReps: 12, suggestedWeight: 55),
    ExerciseLibraryItem(
      name: "Beinbeuger", primaryMuscle: "Beine", equipment: "Maschine", defaultSets: 3,
      defaultReps: 12, suggestedWeight: 45),
    ExerciseLibraryItem(
      name: "Hip Thrust", primaryMuscle: "Glutes", equipment: "Langhantel", defaultSets: 4,
      defaultReps: 10, suggestedWeight: 90),
    ExerciseLibraryItem(
      name: "Wadenheben", primaryMuscle: "Waden", equipment: "Maschine", defaultSets: 4,
      defaultReps: 15, suggestedWeight: 60),
  ]
}

extension WorkoutPlan {
  static let starterTemplates: [WorkoutPlan] = [
    WorkoutPlan(
      title: "Upper A",
      focus: "Brust / Rücken",
      split: "Upper",
      estimatedDurationMinutes: 62,
      exercises: [
        templateExercise(named: "Bankdrücken"),
        templateExercise(named: "Klimmzüge"),
        templateExercise(named: "Schulterdrücken"),
        templateExercise(named: "Rudern sitzend"),
        templateExercise(named: "Bizepscurls"),
        templateExercise(named: "Trizeps Pushdown"),
      ]
    ),
    WorkoutPlan(
      title: "Lower A",
      focus: "Beine / Glutes",
      split: "Lower",
      estimatedDurationMinutes: 64,
      exercises: [
        templateExercise(named: "Kniebeugen"),
        templateExercise(named: "Rumänisches Kreuzheben"),
        templateExercise(named: "Beinpresse"),
        templateExercise(named: "Beinbeuger"),
        templateExercise(named: "Wadenheben"),
      ]
    ),
    WorkoutPlan(
      title: "Push",
      focus: "Brust / Schulter",
      split: "Push",
      estimatedDurationMinutes: 54,
      exercises: [
        templateExercise(named: "Bankdrücken"),
        templateExercise(named: "Schrägbank Kurzhantel"),
        templateExercise(named: "Seitheben"),
        templateExercise(named: "Trizeps Pushdown"),
        templateExercise(named: "Dips"),
      ]
    ),
    WorkoutPlan(
      title: "Pull",
      focus: "Rücken / Bizeps",
      split: "Pull",
      estimatedDurationMinutes: 56,
      exercises: [
        templateExercise(named: "Latzug"),
        templateExercise(named: "Langhantelrudern"),
        templateExercise(named: "Rudern sitzend"),
        templateExercise(named: "Face Pulls"),
        templateExercise(named: "Hammercurls"),
      ]
    ),
    WorkoutPlan(
      title: "Beine",
      focus: "Quads / Glutes",
      split: "Beine",
      estimatedDurationMinutes: 60,
      exercises: [
        templateExercise(named: "Kniebeugen"),
        templateExercise(named: "Beinpresse"),
        templateExercise(named: "Beinstrecker"),
        templateExercise(named: "Beinbeuger"),
        templateExercise(named: "Wadenheben"),
      ]
    ),
  ]

  static func custom(title: String, split: String, exercises: [ExerciseLibraryItem]) -> WorkoutPlan
  {
    let uniqueMuscles = exercises.reduce(into: [String]()) { partial, exercise in
      if !partial.contains(exercise.primaryMuscle) {
        partial.append(exercise.primaryMuscle)
      }
    }

    let focus = uniqueMuscles.prefix(2).joined(separator: " / ")

    return WorkoutPlan(
      source: .custom,
      title: title,
      focus: focus.isEmpty ? split : focus,
      split: split,
      estimatedDurationMinutes: max(35, exercises.count * 12),
      exercises: exercises.map { exercise in
        WorkoutExerciseTemplate(
          name: exercise.name,
          targetMuscle: exercise.primaryMuscle,
          sets: Array(
            repeating: WorkoutSetTemplate(
              reps: exercise.defaultReps, suggestedWeight: exercise.suggestedWeight),
            count: exercise.defaultSets
          )
        )
      }
    )
  }

  private static func templateExercise(named name: String) -> WorkoutExerciseTemplate {
    let exercise =
      ExerciseLibraryItem.commonGymExercises.first(where: { $0.name == name })
      ?? ExerciseLibraryItem.commonGymExercises[0]

    return WorkoutExerciseTemplate(
      name: exercise.name,
      targetMuscle: exercise.primaryMuscle,
      sets: Array(
        repeating: WorkoutSetTemplate(
          reps: exercise.defaultReps, suggestedWeight: exercise.suggestedWeight),
        count: exercise.defaultSets
      )
    )
  }
}

extension HomeViewModel {
  static let mock = HomeViewModel(
    userName: "Julius",
    streakDays: 17,
    recordDays: 23,
    weekSessions: 4,
    weeklyGoal: 5,
    trainingVolumeTons: 12.4,
    personalRecords: 2,
    workoutTitle: "Push Day",
    workoutFocus: "Brust",
    exercises: 5,
    durationMinutes: 45,
    coachHeadline: "Coach sagt: Progression stimmt",
    coachDescription:
      "Heute schwer bei der ersten Druckübung, danach sauberes Volumen. Meal-Plan bleibt leicht im Defizit.",
    socialHeadline: "Community feiert -3.8 kg in 8 Wochen",
    socialDescription:
      "Teile Vorher-Nachher-Meilensteine und sieh direkt, wie sich dein kardiovaskuläres Risiko verbessert.",
    cardioRiskImprovement: 18,
    bodyFatChange: -3.2,
    bloodPanelStatus: "LDL stabil, Entzündungsmarker verbessert",
    weekDays: [
      DayProgress(date: Date(), shortLabel: "MO", dayNumber: 14, status: .completed),
      DayProgress(date: Date(), shortLabel: "DI", dayNumber: 15, status: .completed),
      DayProgress(date: Date(), shortLabel: "MI", dayNumber: 16, status: .rest),
      DayProgress(date: Date(), shortLabel: "DO", dayNumber: 17, status: .completed),
      DayProgress(date: Date(), shortLabel: "FR", dayNumber: 18, status: .completed),
      DayProgress(date: Date(), shortLabel: "SA", dayNumber: 19, status: .today),
      DayProgress(date: Date(), shortLabel: "SO", dayNumber: 20, status: .rest),
    ],
    workoutPlan: WorkoutPlan(
      title: "Push Day",
      focus: "Brust",
      split: "Push",
      estimatedDurationMinutes: 45,
      exercises: [
        WorkoutExerciseTemplate(
          name: "Bankdrücken",
          targetMuscle: "Brust",
          sets: [
            WorkoutSetTemplate(reps: 8, suggestedWeight: 80),
            WorkoutSetTemplate(reps: 8, suggestedWeight: 80),
            WorkoutSetTemplate(reps: 6, suggestedWeight: 82.5),
          ]
        ),
        WorkoutExerciseTemplate(
          name: "Schrägbank Kurzhantel",
          targetMuscle: "Brust",
          sets: [
            WorkoutSetTemplate(reps: 10, suggestedWeight: 30),
            WorkoutSetTemplate(reps: 10, suggestedWeight: 30),
            WorkoutSetTemplate(reps: 8, suggestedWeight: 32.5),
          ]
        ),
        WorkoutExerciseTemplate(
          name: "Seitheben",
          targetMuscle: "Schulter",
          sets: [
            WorkoutSetTemplate(reps: 15, suggestedWeight: 10),
            WorkoutSetTemplate(reps: 15, suggestedWeight: 10),
            WorkoutSetTemplate(reps: 12, suggestedWeight: 12),
          ]
        ),
        WorkoutExerciseTemplate(
          name: "Trizeps Pushdown",
          targetMuscle: "Trizeps",
          sets: [
            WorkoutSetTemplate(reps: 12, suggestedWeight: 32),
            WorkoutSetTemplate(reps: 12, suggestedWeight: 32),
            WorkoutSetTemplate(reps: 10, suggestedWeight: 36),
          ]
        ),
        WorkoutExerciseTemplate(
          name: "Dips",
          targetMuscle: "Brust",
          sets: [
            WorkoutSetTemplate(reps: 10, suggestedWeight: 0),
            WorkoutSetTemplate(reps: 9, suggestedWeight: 0),
          ]
        ),
      ]
    )
  )
}

extension CoachViewModel {
  static let mock = CoachViewModel(
    coachName: "Ava",
    focus: "Cut sauber halten und Push-Day progressiv laden",
    nutritionAdherence: 86,
    recoveryScore: 79,
    stepGoal: 10000,
    hydrationGoalLiters: 3.5,
    sleepTargetHours: 8,
    recommendations: [
      "Erste Druckübung heute mit 1 schwerem Top-Set und 2 Backoff-Sets.",
      "Protein bei 190 g halten, Carbs vor dem Training leicht erhöhen.",
      "Heute 8.000 Schritte locker vollmachen statt extra Cardio zu erzwingen.",
    ],
    checkIns: [
      CoachCheckIn(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "Meal Prep",
        detail: "Alle Hauptmahlzeiten für heute vorbereitet"),
      CoachCheckIn(
        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, title: "Hydration",
        detail: "Mindestens 3.5 Liter über den Tag verteilt"),
      CoachCheckIn(
        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, title: "Steps",
        detail: "10k Schritte für Defizit und Recovery"),
      CoachCheckIn(
        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, title: "Sleep",
        detail: "8 Stunden Schlaf vor dem nächsten Training"),
    ]
  )
}

extension ProgressViewModel {
  static let mock = ProgressViewModel(
    startWeight: 98.4,
    currentWeight: 94.6,
    waistChange: -5.4,
    cardioRiskImprovement: 18,
    bloodPanelSummary: [
      HealthMetric(title: "LDL", value: "112", trend: "-9%"),
      HealthMetric(title: "HbA1c", value: "5.2", trend: "-0.3"),
      HealthMetric(title: "CRP", value: "1.1", trend: "-22%"),
    ],
    milestones: [
      ProgressMilestone(
        title: "Erstes -3 kg Ziel erreicht", detail: "Abnahme sauber ohne Kraftverlust",
        dateLabel: "APR 02"),
      ProgressMilestone(
        title: "Cardio-Risiko verbessert", detail: "Geschätzter Score deutlich gesunken",
        dateLabel: "APR 11"),
      ProgressMilestone(
        title: "Blutbild Check-in", detail: "Marker entwickeln sich in die richtige Richtung",
        dateLabel: "APR 18"),
    ],
    weeklyTrend: [
      WeightTrendPoint(label: "MO", value: 95.7),
      WeightTrendPoint(label: "DI", value: 95.4),
      WeightTrendPoint(label: "MI", value: 95.3),
      WeightTrendPoint(label: "DO", value: 95.0),
      WeightTrendPoint(label: "FR", value: 94.9),
      WeightTrendPoint(label: "SA", value: 94.8),
      WeightTrendPoint(label: "SO", value: 94.6),
    ],
    goals: [
      ProgressGoal(title: "Körpergewicht", current: 94.6, target: 90.0, unit: "kg"),
      ProgressGoal(title: "Taillenumfang", current: 91.0, target: 86.0, unit: "cm"),
      ProgressGoal(title: "Protein-Ziel", current: 178.0, target: 190.0, unit: "g"),
    ],
    trackerOptions: [
      TrackerDevice(
        id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!, name: "Apple Watch",
        source: "HealthKit", accentHex: "D4E85C"),
      TrackerDevice(
        id: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!, name: "WHOOP",
        source: "WHOOP OAuth", accentHex: "F4F3EE"),
      TrackerDevice(
        id: UUID(uuidString: "13131313-1313-1313-1313-131313131313")!, name: "Garmin",
        source: "Connect", accentHex: "A8C53A"),
      TrackerDevice(
        id: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!, name: "Oura",
        source: "Readiness", accentHex: "4A5220"),
    ],
    vitalReadings: [
      VitalReading(title: "Ruhepuls", value: "54 bpm", context: "heute früh"),
      VitalReading(title: "HRV", value: "71 ms", context: "Recovery gut"),
      VitalReading(title: "Schlaf", value: "7h 46m", context: "letzte Nacht"),
      VitalReading(title: "VO2max", value: "46.2", context: "Cardio-Level"),
    ]
  )
}

extension CommunityViewModel {
  static let mock = CommunityViewModel(
    headline: "Mehr als ein Tracker: Fortschritt, Wissen und Anerkennung an einem Ort.",
    challengeTitle: "Spring Cut / 30 Tage Consistency",
    challengeParticipants: 1842,
    challengeBenefits: [
      "Tägliche Ranking-Impulse",
      "Vorher-Nachher Meilensteine",
      "Health-Impact für echten Fortschritt",
    ],
    composerPrompts: [
      CommunityComposerAction(
        title: "Workout posten", type: .workout, systemImage: "dumbbell.fill"),
      CommunityComposerAction(title: "Lauf teilen", type: .run, systemImage: "figure.run"),
      CommunityComposerAction(
        title: "Progress Update", type: .progress, systemImage: "chart.line.uptrend.xyaxis"),
    ],
    posts: [
      CommunityPost(
        id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
        author: "Mila",
        handle: "@mila.cuts",
        type: .progress,
        title: "-6.1 kg und trotzdem PR im RDL",
        detail:
          "Die App zeigt mir endlich, dass mein Risiko sinkt und nicht nur mein Gewicht. Heute außerdem neuer Rekord im Romanian Deadlift.",
        timeAgo: "vor 38 Min",
        placeholderSymbol: "figure.mixed.cardio",
        highlightMetrics: [
          CommunityMetric(label: "Gewicht", value: "-6.1 kg"),
          CommunityMetric(label: "RDL", value: "110 kg"),
          CommunityMetric(label: "KF", value: "-3.4%"),
        ],
        reactions: 241,
        comments: 18,
        shares: 7
      ),
      CommunityPost(
        id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
        author: "Noah",
        handle: "@noah.runlift",
        type: .run,
        title: "Morning 10K mit neuem Pace-PR",
        detail:
          "Zone-2 geplant, am Ende trotzdem stark gefühlt. Genau die Art Cardio, die man im Cut halten kann.",
        timeAgo: "vor 1 Std",
        placeholderSymbol: "figure.run",
        highlightMetrics: [
          CommunityMetric(label: "Distanz", value: "10.2 km"),
          CommunityMetric(label: "Pace", value: "4:48"),
          CommunityMetric(label: "HF", value: "148 bpm"),
        ],
        reactions: 187,
        comments: 12,
        shares: 5
      ),
      CommunityPost(
        id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
        author: "Leonie",
        handle: "@leonie.gains",
        type: .workout,
        title: "Push Day komplett geloggt",
        detail:
          "Heute nur sauber Volumen gesammelt. Drei Druckübungen, Schulter-Fokus und Trizeps bis ans Ende durchgezogen.",
        timeAgo: "vor 2 Std",
        placeholderSymbol: "dumbbell.fill",
        highlightMetrics: [
          CommunityMetric(label: "Volumen", value: "12.8 t"),
          CommunityMetric(label: "Sets", value: "17"),
          CommunityMetric(label: "Dauer", value: "52 Min"),
        ],
        reactions: 128,
        comments: 9,
        shares: 4
      ),
      CommunityPost(
        id: UUID(uuidString: "dededede-dede-dede-dede-dededededede")!,
        author: "Sami",
        handle: "@sami.bulkphase",
        type: .progress,
        title: "+2.4 kg Lean Bulk in 5 Wochen",
        detail:
          "Gewicht hoch, Kraft hoch und Verdauung bleibt entspannt. Genau so soll die Aufbauphase laufen.",
        timeAgo: "vor 5 Std",
        placeholderSymbol: "chart.line.uptrend.xyaxis",
        highlightMetrics: [
          CommunityMetric(label: "Gewicht", value: "+2.4 kg"),
          CommunityMetric(label: "Bench", value: "+7.5 kg"),
          CommunityMetric(label: "Kalorien", value: "3250"),
        ],
        reactions: 96,
        comments: 6,
        shares: 3
      ),
    ]
  )
}

extension RecipesViewModel {
  static let mock = RecipesViewModel(
    headline: "Rezepte für deinen Cut und Muscle-Build",
    subtitle: "Jedes Rezept zeigt dir direkt Kalorien, Makros und eine einfache Zubereitung.",
    recipes: [
      Recipe(
        id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
        title: "High Protein Chicken Bowl",
        category: "Lunch",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .lunchDinner,
        imageURL:
          "https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "flame.fill",
        prepMinutes: 20,
        calories: 612,
        protein: 54,
        carbs: 48,
        fat: 18,
        ingredients: [
          "180 g Hähnchenbrust",
          "150 g Jasminreis gekocht",
          "120 g Gurke",
          "100 g Edamame",
          "80 g Joghurt-Sauce light",
          "1 TL Sesam",
        ],
        steps: [
          "Hähnchen würzen und in der Pfanne goldbraun anbraten.",
          "Reis, Gurke und Edamame in eine Bowl geben.",
          "Hähnchen aufschneiden, Sauce darübergeben und mit Sesam finishen.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
        title: "Overnight Oats Gains",
        category: "Breakfast",
        goal: .abnehmen,
        dietaryStyle: .vegetarian,
        mealType: .breakfast,
        imageURL:
          "https://images.unsplash.com/photo-1517673400267-0251440c45dc?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "moon.stars.fill",
        prepMinutes: 8,
        calories: 458,
        protein: 39,
        carbs: 42,
        fat: 14,
        ingredients: [
          "60 g Haferflocken",
          "200 g Skyr",
          "30 g Whey Vanille",
          "100 g Beeren",
          "10 g Chiasamen",
          "150 ml Mandelmilch",
        ],
        steps: [
          "Alle Zutaten außer Beeren verrühren.",
          "Über Nacht kalt stellen.",
          "Vor dem Essen mit Beeren toppen.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
        title: "Pasta Beef Performance",
        category: "Dinner",
        goal: .zunehmen,
        dietaryStyle: .omnivore,
        mealType: .lunchDinner,
        imageURL:
          "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "bolt.fill",
        prepMinutes: 25,
        calories: 735,
        protein: 51,
        carbs: 69,
        fat: 26,
        ingredients: [
          "170 g Rinderhack 5%",
          "90 g Pasta trocken",
          "200 g Passata",
          "50 g Parmesan light",
          "1 Knoblauchzehe",
          "Basilikum, Salz, Pfeffer",
        ],
        steps: [
          "Pasta kochen und parallel das Hack mit Knoblauch anbraten.",
          "Passata dazugeben und kurz einkochen lassen.",
          "Mit Pasta mischen und Parmesan darübergeben.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "abababab-abab-abab-abab-abababababab")!,
        title: "Turkey Wrap Lean Cut",
        category: "Snack",
        goal: .abnehmen,
        dietaryStyle: .omnivore,
        mealType: .snack,
        imageURL:
          "https://images.unsplash.com/photo-1521390188846-e2a3a97453a0?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "leaf.fill",
        prepMinutes: 10,
        calories: 389,
        protein: 36,
        carbs: 28,
        fat: 11,
        ingredients: [
          "1 High-Protein Wrap",
          "140 g Putenbrust",
          "40 g Hummus light",
          "Tomate und Salat",
          "Gewürze nach Wahl",
        ],
        steps: [
          "Wrap kurz erwärmen und mit Hummus bestreichen.",
          "Putenbrust und Gemüse darauf verteilen.",
          "Fest einrollen und halbieren.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "cdcdcdcd-cdcd-cdcd-cdcd-cdcdcdcdcdcd")!,
        title: "Mass Shake Deluxe",
        category: "Shake",
        goal: .zunehmen,
        dietaryStyle: .vegetarian,
        mealType: .shake,
        imageURL:
          "https://images.unsplash.com/photo-1572490122747-3968b75cc699?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "drop.fill",
        prepMinutes: 5,
        calories: 812,
        protein: 47,
        carbs: 84,
        fat: 28,
        ingredients: [
          "400 ml Milch",
          "80 g Haferflocken",
          "40 g Whey",
          "1 Banane",
          "30 g Erdnussmus",
        ],
        steps: [
          "Alle Zutaten in den Mixer geben.",
          "30 Sekunden cremig mixen.",
          "Direkt nach dem Training trinken.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        title: "Skyr Berry Pancakes",
        category: "Breakfast",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .breakfast,
        imageURL:
          "https://images.unsplash.com/photo-1528207776546-365bb710ee93?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "sun.max.fill",
        prepMinutes: 15,
        calories: 524,
        protein: 43,
        carbs: 52,
        fat: 14,
        ingredients: [
          "200 g Skyr",
          "2 Eier",
          "60 g Hafermehl",
          "30 g Whey",
          "100 g Beeren",
          "Etwas Backpulver",
        ],
        steps: [
          "Skyr, Eier, Hafermehl und Whey zu einem Teig verrühren.",
          "Pancakes portionsweise in einer beschichteten Pfanne ausbacken.",
          "Mit Beeren servieren.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "66666666-7777-8888-9999-aaaaaaaaaaaa")!,
        title: "Salmon Rice Recovery",
        category: "Dinner",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .lunchDinner,
        imageURL:
          "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "fish.fill",
        prepMinutes: 22,
        calories: 648,
        protein: 46,
        carbs: 51,
        fat: 26,
        ingredients: [
          "170 g Lachsfilet",
          "160 g Basmatireis gekocht",
          "120 g Brokkoli",
          "1 TL Olivenöl",
          "Zitrone",
          "Salz und Pfeffer",
        ],
        steps: [
          "Lachs würzen und im Ofen oder in der Pfanne garen.",
          "Reis und Brokkoli parallel zubereiten.",
          "Alles zusammen mit Zitronensaft anrichten.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff")!,
        title: "Tofu Peanut Noodles",
        category: "Lunch",
        goal: .zunehmen,
        dietaryStyle: .vegan,
        mealType: .lunchDinner,
        imageURL:
          "https://images.unsplash.com/photo-1617093727343-374698b1b08d?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "takeoutbag.and.cup.and.straw.fill",
        prepMinutes: 18,
        calories: 702,
        protein: 34,
        carbs: 74,
        fat: 29,
        ingredients: [
          "180 g Tofu",
          "90 g Udon-Nudeln",
          "25 g Erdnussmus",
          "Sojasauce",
          "Karotte",
          "Frühlingszwiebeln",
        ],
        steps: [
          "Tofu knusprig anbraten.",
          "Nudeln kochen und mit Erdnussmus und Sojasauce mischen.",
          "Mit Gemüse und Tofu toppen.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "12341234-5678-90ab-cdef-1234567890ab")!,
        title: "Egg Avocado Toast Cut",
        category: "Breakfast",
        goal: .abnehmen,
        dietaryStyle: .vegetarian,
        mealType: .breakfast,
        imageURL:
          "https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "avocado.fill",
        prepMinutes: 9,
        calories: 372,
        protein: 24,
        carbs: 26,
        fat: 18,
        ingredients: [
          "2 Scheiben Vollkorntoast",
          "2 Eier",
          "70 g Avocado",
          "Chiliflocken",
          "Zitronensaft",
        ],
        steps: [
          "Toast rösten und Avocado mit Zitrone zerdrücken.",
          "Eier nach Wunsch braten oder pochieren.",
          "Alles auf dem Toast anrichten.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "fedcfedc-ba98-7654-3210-fedcba987654")!,
        title: "Greek Yogurt Protein Bowl",
        category: "Snack",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .snack,
        imageURL:
          "https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "heart.fill",
        prepMinutes: 6,
        calories: 331,
        protein: 32,
        carbs: 24,
        fat: 9,
        ingredients: [
          "250 g griechischer Joghurt light",
          "20 g Whey Vanille",
          "1 Kiwi",
          "80 g Beeren",
          "10 g Granola",
        ],
        steps: [
          "Joghurt mit Whey glatt rühren.",
          "Obst schneiden und darauf verteilen.",
          "Mit etwas Granola toppen.",
        ]
      ),
      Recipe(
        id: UUID(uuidString: "0a0b0c0d-1e1f-2021-2223-242526272829")!,
        title: "Chicken Pesto Sandwich Bulk",
        category: "Lunch",
        goal: .zunehmen,
        dietaryStyle: .omnivore,
        mealType: .lunchDinner,
        imageURL:
          "https://images.unsplash.com/photo-1539252554453-80ab65ce3586?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "bag.fill",
        prepMinutes: 12,
        calories: 689,
        protein: 45,
        carbs: 58,
        fat: 29,
        ingredients: [
          "160 g Hähnchenbrust",
          "1 Ciabatta",
          "25 g Pesto",
          "Tomate",
          "Rucola",
          "20 g Mozzarella",
        ],
        steps: [
          "Hähnchen anbraten und in Scheiben schneiden.",
          "Ciabatta aufschneiden und mit Pesto bestreichen.",
          "Mit Hähnchen, Mozzarella, Tomate und Rucola belegen.",
        ]
      ),
    ]
  )
}

extension WorkoutHubViewModel {
  static let mock = WorkoutHubViewModel(
    headline: "Dein Training an einem Ort",
    subtitle:
      "Plane deine Woche, tracke Workouts und Läufe und behalte Volumen, Pace und Split im Blick.",
    todayPlan: HomeViewModel.mock.workoutPlan,
    weeklySchedule: [
      WorkoutDayPlan(
        weekday: .monday, dayLabel: "MO", title: "Upper Strength", focus: "Brust / Rücken",
        isToday: false, status: .planned, workoutPlan: WorkoutPlan.starterTemplates[0]),
      WorkoutDayPlan(
        weekday: .tuesday, dayLabel: "DI", title: "Frei", focus: "Spaziergang / Mobility",
        isToday: false, status: .rest, workoutPlan: nil),
      WorkoutDayPlan(
        weekday: .wednesday, dayLabel: "MI", title: "Lower Body", focus: "Quads / Glutes",
        isToday: false, status: .planned, workoutPlan: WorkoutPlan.starterTemplates[1]),
      WorkoutDayPlan(
        weekday: .thursday, dayLabel: "DO", title: "Flexibel", focus: "Optional Cardio / Core",
        isToday: false, status: .flexible, workoutPlan: nil),
      WorkoutDayPlan(
        weekday: .friday, dayLabel: "FR", title: "Pull Day", focus: "Rücken / Bizeps",
        isToday: false, status: .planned, workoutPlan: WorkoutPlan.starterTemplates[3]),
      WorkoutDayPlan(
        weekday: .saturday, dayLabel: "SA", title: "Push Day", focus: "Brust / Schulter",
        isToday: true, status: .planned, workoutPlan: WorkoutPlan.starterTemplates[2]),
      WorkoutDayPlan(
        weekday: .sunday, dayLabel: "SO", title: "Frei", focus: "Recovery", isToday: false,
        status: .rest, workoutPlan: nil),
    ]
  )
}
