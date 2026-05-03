import CoreLocation
import Foundation

enum AppTab: Hashable {
  case home
  case gym
  case run
  case nutrition
  case community

  // Hinweis: `.progress` wurde entfernt — Fortschritt lebt jetzt als
  // aufklappbarer Bereich auf dem Home-Screen, nicht mehr als eigener Tab.

  var title: String {
    switch self {
    case .home:
      return "Home"
    case .gym:
      return "Gym"
    case .run:
      return "Kardio"
    case .nutrition:
      return "Ernährung"
    case .community:
      return "Community"
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
  // `.fortschritt` wurde entfernt — der Fortschritt-Workspace existiert
  // nicht mehr; Fortschritt ist jetzt eine Sektion auf dem Home-Screen.
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

// MARK: - Social / Privacy

struct SocialSharingSettings: Codable, Equatable {
  var autoShareWorkouts: Bool
  var autoShareRuns: Bool
  var autoSharePersonalRecords: Bool
  var shareLocationWithRuns: Bool
  var visibility: SharingVisibility

  static let `default` = SocialSharingSettings(
    autoShareWorkouts: false,
    autoShareRuns: false,
    autoSharePersonalRecords: true,
    shareLocationWithRuns: false,
    visibility: .friends
  )
}

enum SharingVisibility: String, Codable, CaseIterable, Identifiable {
  case onlyMe
  case friends
  case publicFeed

  var id: String { rawValue }

  var title: String {
    switch self {
    case .onlyMe: return "Nur ich"
    case .friends: return "Kontakte"
    case .publicFeed: return "Öffentlich"
    }
  }

  var systemImage: String {
    switch self {
    case .onlyMe: return "lock.fill"
    case .friends: return "person.2.fill"
    case .publicFeed: return "globe"
    }
  }
}

// MARK: - Forum

enum ForumCategory: String, CaseIterable, Codable, Identifiable {
  case general
  case localSports
  case nutrition
  case gyms
  case meetups

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: return "Allgemein"
    case .localSports: return "Lokale Sportangebote"
    case .nutrition: return "Ernährung"
    case .gyms: return "Gyms"
    case .meetups: return "Treff dich"
    }
  }

  var subtitle: String {
    switch self {
    case .general: return "Austausch über alles rund ums Training"
    case .localSports: return "Vereine, Kurse, Events in deiner Nähe"
    case .nutrition: return "Rezepte, Supplements, Diät-Strategien"
    case .gyms: return "Empfehlungen, Tagespässe, Equipment"
    case .meetups: return "Verabredungen für Workouts und Läufe"
    }
  }

  var systemImage: String {
    switch self {
    case .general: return "bubble.left.and.bubble.right.fill"
    case .localSports: return "mappin.and.ellipse"
    case .nutrition: return "leaf.fill"
    case .gyms: return "building.2.fill"
    case .meetups: return "person.3.fill"
    }
  }
}

struct ForumThread: Identifiable, Codable {
  let id: UUID
  var category: ForumCategory
  var title: String
  var body: String
  var author: String
  var handle: String
  var createdAt: Date
  var location: String?
  var replies: [ForumReply]
  var likeCount: Int
}

struct ForumReply: Identifiable, Codable {
  let id: UUID
  var author: String
  var handle: String
  var body: String
  var createdAt: Date
}

// MARK: - Meetups

enum MeetupSport: String, CaseIterable, Codable, Identifiable {
  case run
  case gym
  case yoga
  case cycling
  case calisthenics
  case other

  var id: String { rawValue }

  var title: String {
    switch self {
    case .run: return "Lauftreff"
    case .gym: return "Gym Session"
    case .yoga: return "Yoga / Mobility"
    case .cycling: return "Radausfahrt"
    case .calisthenics: return "Calisthenics"
    case .other: return "Sonstiges"
    }
  }

  var systemImage: String {
    switch self {
    case .run: return "figure.run"
    case .gym: return "dumbbell.fill"
    case .yoga: return "figure.yoga"
    case .cycling: return "bicycle"
    case .calisthenics: return "figure.strengthtraining.functional"
    case .other: return "sparkles"
    }
  }
}

struct Meetup: Identifiable, Codable {
  let id: UUID
  var sport: MeetupSport
  var title: String
  var locationName: String
  var startsAt: Date
  var pace: String?
  var hostHandle: String
  var hostName: String
  var notes: String
  var maxParticipants: Int
  var participantHandles: [String]
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
  let tags: [RecipeTag]
  let servings: Int

  init(
    id: UUID,
    title: String,
    category: String,
    goal: RecipeGoal,
    dietaryStyle: RecipeDietaryStyle,
    mealType: RecipeMealType,
    imageURL: String,
    placeholderSymbol: String,
    prepMinutes: Int,
    calories: Int,
    protein: Int,
    carbs: Int,
    fat: Int,
    ingredients: [String],
    steps: [String],
    tags: [RecipeTag] = [],
    servings: Int = 1
  ) {
    self.id = id
    self.title = title
    self.category = category
    self.goal = goal
    self.dietaryStyle = dietaryStyle
    self.mealType = mealType
    self.imageURL = imageURL
    self.placeholderSymbol = placeholderSymbol
    self.prepMinutes = prepMinutes
    self.calories = calories
    self.protein = protein
    self.carbs = carbs
    self.fat = fat
    self.ingredients = ingredients
    self.steps = steps
    self.tags = tags
    self.servings = servings
  }
}

enum RecipeTag: String, CaseIterable, Identifiable {
  case mealprep
  case airfryer
  case quick
  case budget
  case batchcook
  case lowCarb
  case postWorkout
  case noCook
  case oneOnePan

  var id: String { rawValue }

  var title: String {
    switch self {
    case .mealprep:    return "Mealprep"
    case .airfryer:    return "Airfryer"
    case .quick:       return "Schnell"
    case .budget:      return "Budget"
    case .batchcook:   return "Batchcook"
    case .lowCarb:     return "Low Carb"
    case .postWorkout: return "Post Workout"
    case .noCook:      return "No Cook"
    case .oneOnePan:   return "One Pan"
    }
  }

  var systemImage: String {
    switch self {
    case .mealprep:    return "shippingbox.fill"
    case .airfryer:    return "wind"
    case .quick:       return "bolt.fill"
    case .budget:      return "eurosign.circle.fill"
    case .batchcook:   return "square.stack.3d.up.fill"
    case .lowCarb:     return "leaf.circle.fill"
    case .postWorkout: return "figure.strengthtraining.traditional"
    case .noCook:      return "snowflake"
    case .oneOnePan:   return "frying.pan.fill"
    }
  }

  var subtitle: String {
    switch self {
    case .mealprep:    return "Vorkochen für die Woche"
    case .airfryer:    return "Knusprig ohne Fett"
    case .quick:       return "Unter 15 Minuten"
    case .budget:      return "Günstig & nahrhaft"
    case .batchcook:   return "Große Portion auf einmal"
    case .lowCarb:     return "Wenig Kohlenhydrate"
    case .postWorkout: return "Recovery Boost"
    case .noCook:      return "Ohne Herd"
    case .oneOnePan:   return "Eine Pfanne, fertig"
    }
  }
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

// MARK: - Nutrition Profile (Wizard)

enum BiologicalSex: String, CaseIterable {
  case male
  case female

  var title: String {
    switch self {
    case .male: return "Männlich"
    case .female: return "Weiblich"
    }
  }

  var emoji: String {
    switch self {
    case .male: return "♂"
    case .female: return "♀"
    }
  }
}

enum ActivityLevel: String, CaseIterable {
  case sedentary
  case light
  case moderate
  case active
  case veryActive

  var title: String {
    switch self {
    case .sedentary: return "Wenig aktiv"
    case .light: return "Leicht aktiv"
    case .moderate: return "Mäßig aktiv"
    case .active: return "Aktiv"
    case .veryActive: return "Sehr aktiv"
    }
  }

  var detail: String {
    switch self {
    case .sedentary: return "Bürojob, kaum Bewegung im Alltag"
    case .light: return "1–2× Sport pro Woche"
    case .moderate: return "3–4× Sport pro Woche"
    case .active: return "5–6× intensives Training"
    case .veryActive: return "Profisport oder körperliche Arbeit"
    }
  }

  var systemImage: String {
    switch self {
    case .sedentary: return "sofa.fill"
    case .light: return "figure.walk"
    case .moderate: return "figure.run"
    case .active: return "figure.strengthtraining.traditional"
    case .veryActive: return "bolt.fill"
    }
  }

  /// TDEE-Multiplikator nach Mifflin-St Jeor
  var multiplier: Double {
    switch self {
    case .sedentary: return 1.2
    case .light: return 1.375
    case .moderate: return 1.55
    case .active: return 1.725
    case .veryActive: return 1.9
    }
  }
}

struct NutritionProfile {
  var sex: BiologicalSex
  var age: Int                    // Jahre
  var heightCm: Int               // cm
  var weightKg: Int               // kg
  var bodyFatPercent: Double?     // Optional – aktiviert Katch-McArdle (1975)
  var activityLevel: ActivityLevel
  var goal: NutritionGoal
  var surplusKcal: Int            // Kcal-Überschuss (+) oder -Defizit (−) pro Tag

  // MARK: Grundumsatz (BMR)
  // Katch-McArdle (1975) wenn Körperfettanteil bekannt → präziser bei Athleten
  // Mifflin-St Jeor (1990) AJCN als Fallback
  var bmr: Double {
    if let bf = bodyFatPercent {
      let leanMassKg = Double(weightKg) * (1.0 - bf / 100.0)
      return 370.0 + 21.6 * leanMassKg  // Katch-McArdle (1975)
    }
    let base = 10.0 * Double(weightKg) + 6.25 * Double(heightCm) - 5.0 * Double(age)
    switch sex {
    case .male:   return base + 5.0
    case .female: return base - 161.0
    }
  }

  // MARK: Gesamtumsatz (TDEE) = BMR × Aktivitätsfaktor
  var tdee: Double { bmr * activityLevel.multiplier }

  // MARK: Zielkalorien = TDEE + individuell gewähltes Surplus / Defizit
  // Quelle: Hall et al. (2012) – Energiebilanzmodell
  var targetCalories: Int {
    max(1200, Int((tdee + Double(surplusKcal)).rounded()))
  }

  // MARK: Protein – lean-mass-basiert wenn KFA bekannt, sonst Gesamtkörpergewicht
  // Quellen: Morton et al. (2018) BJSM · Helms et al. (2014) IJSNEM · ISSN (2022)
  var targetProteinG: Int {
    if let bf = bodyFatPercent {
      // Lean-Mass-Ansatz (Helms 2014): bis 3.1 g/kg Lean Mass beim aggressiven Cut
      let leanMassKg = Double(weightKg) * (1.0 - bf / 100.0)
      let factor: Double
      switch goal {
      case .fatLoss:
        factor = surplusKcal < -450 ? 3.1 : 2.6  // aggressiver Cut → mehr Protein zum Muskelerhalt
      case .muscleGain:
        factor = 2.2   // Morton et al. 2018: 1.6–2.2 g/kg optimal
      case .maintain:
        factor = 2.0
      }
      return max(100, Int((leanMassKg * factor).rounded()))
    }
    // Gesamtkörpergewicht-Ansatz
    let factor: Double
    switch goal {
    case .muscleGain: factor = 2.0   // ISSN 2022: 1.4–2.0 g/kg
    case .fatLoss:    factor = 2.4   // Erhöhtes Protein beim Cut (Helms 2014)
    case .maintain:   factor = 1.8
    }
    return max(100, Int((Double(weightKg) * factor).rounded()))
  }

  // MARK: Fett: 25% der Zielkalorien (min. 0.7 g/kg KG)
  // Quelle: ISSN Position Stand (2017)
  var targetFatG: Int {
    let fromPercent = Int((Double(targetCalories) * 0.25 / 9.0).rounded())
    let minFat = Int((Double(weightKg) * 0.7).rounded())
    return max(minFat, fromPercent)
  }

  // MARK: Kohlenhydrate: verbleibende Kalorien nach Protein + Fett
  var targetCarbsG: Int {
    let proteinCals = targetProteinG * 4
    let fatCals     = targetFatG * 9
    let carbCals    = max(0, targetCalories - proteinCals - fatCals)
    return Int((Double(carbCals) / 4.0).rounded())
  }

  // MARK: Erwartete Gewichtsveränderung pro Woche
  // ~7700 kcal ≈ 1 kg Körpermasse (Hall et al., 2012)
  var weeklyWeightChangeKg: Double {
    Double(surplusKcal) * 7.0 / 7700.0
  }

  // MARK: Verwendete BMR-Formel
  var formulaUsed: String {
    bodyFatPercent != nil ? "Katch-McArdle (1975)" : "Mifflin-St Jeor (1990)"
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
  case lunch
  case dinner
  case snack
  case dessert
  case shake

  var title: String {
    switch self {
    case .breakfast: return "Frühstück"
    case .lunch:     return "Mittagessen"
    case .dinner:    return "Abendessen"
    case .snack:     return "Snacks"
    case .dessert:   return "Dessert"
    case .shake:     return "Shake"
    }
  }

  var systemImage: String {
    switch self {
    case .breakfast: return "sun.max.fill"
    case .lunch:     return "fork.knife"
    case .dinner:    return "moon.stars.fill"
    case .snack:     return "takeoutbag.and.cup.and.straw.fill"
    case .dessert:   return "birthday.cake.fill"
    case .shake:     return "cup.and.saucer.fill"
    }
  }

  var shortTitle: String {
    switch self {
    case .breakfast: return "Frühstück"
    case .lunch:     return "Mittagessen"
    case .dinner:    return "Abendessen"
    case .snack:     return "Snack"
    case .dessert:   return "Dessert"
    case .shake:     return "Shake"
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

  /// Offset in Tagen ab Montag (Mo=0, So=6). Wird an mehreren Stellen für
  /// die Wochenausrichtung benötigt (PlanTab, Store-Helpers, Home-
  /// Wochenleiste). Vorher dupliziert in `GymPlanTab.offsetFromMonday(for:)` —
  /// als zentrale Property bleibt die Wochen-Konvention konsistent.
  var mondayOffset: Int {
    switch self {
    case .monday:    return 0
    case .tuesday:   return 1
    case .wednesday: return 2
    case .thursday:  return 3
    case .friday:    return 4
    case .saturday:  return 5
    case .sunday:    return 6
    }
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

// MARK: - Evidence-based Planner Inputs

/// Trainingsalter / Erfahrungslevel.
/// Beeinflusst Volumen, RIR-Range und Frequenz (Schoenfeld et al. 2017, Helms 2018).
enum TrainingExperience: String, CaseIterable {
  case beginner       // < 12 Monate strukturiertes Training
  case intermediate   // 1 – 3 Jahre
  case advanced       // > 3 Jahre

  var title: String {
    switch self {
    case .beginner:     return "Anfänger"
    case .intermediate: return "Fortgeschritten"
    case .advanced:     return "Profi"
    }
  }

  var detail: String {
    switch self {
    case .beginner:
      return "Niedrige Volumenschwelle, klare Grundübungen, Fokus auf Technik."
    case .intermediate:
      return "Moderates Volumen, Periodisierung lohnt, Frequenz ≥ 2 / Muskel."
    case .advanced:
      return "Hohes Volumen, Spezialisierung & RIR-Steuerung machen Unterschied."
    }
  }
}

/// Verfügbare Ausstattung – limitiert sinnvolle Splits & Übungspool.
enum GymEquipment: String, CaseIterable {
  case fullGym
  case homeGymBarbell
  case dumbbellsOnly
  case bodyweight

  var title: String {
    switch self {
    case .fullGym:         return "Volles Studio"
    case .homeGymBarbell:  return "Home Rack"
    case .dumbbellsOnly:   return "Kurzhanteln"
    case .bodyweight:      return "Bodyweight"
    }
  }

  var detail: String {
    switch self {
    case .fullGym:
      return "Maschinen + Freihantel: alle Splits sind machbar."
    case .homeGymBarbell:
      return "Langhantel + Rack: kraftorientierte Splits funktionieren gut."
    case .dumbbellsOnly:
      return "Kurzhanteln & Bank: Ganzkörper / Upper-Lower bevorzugt."
    case .bodyweight:
      return "Eigengewicht & Bänder: Frequenz hochhalten, Volumen über Sätze."
    }
  }
}

/// Bevorzugte Trainings-Aufteilung. `auto` lässt die Engine entscheiden.
enum SplitPreference: String, CaseIterable {
  case auto
  case fullBody
  case upperLower
  case pushPullLegs
  case broSplit

  var title: String {
    switch self {
    case .auto:          return "Automatisch"
    case .fullBody:      return "Ganzkörper"
    case .upperLower:    return "Upper / Lower"
    case .pushPullLegs:  return "Push / Pull / Legs"
    case .broSplit:      return "Bro-Split"
    }
  }
}

/// Erholungskapazität – fließt als Volumen-Modifier ein.
enum RecoveryCapacity: String, CaseIterable {
  case low
  case medium
  case high

  var title: String {
    switch self {
    case .low:    return "Eingeschränkt"
    case .medium: return "Solide"
    case .high:   return "Stark"
    }
  }

  var detail: String {
    switch self {
    case .low:
      return "Wenig Schlaf oder hoher Stress – Volumen wird gedrosselt."
    case .medium:
      return "Normaler Alltag – Standardvolumen passt."
    case .high:
      return "Guter Schlaf, niedriger Stress – höheres Volumen ist tragbar."
    }
  }

  var volumeMultiplier: Double {
    switch self {
    case .low:    return 0.8
    case .medium: return 1.0
    case .high:   return 1.1
    }
  }
}

/// Hauptmuskelgruppen für Volumen-Verteilung & Priorisierung.
enum MuscleGroup: String, CaseIterable, Identifiable {
  case chest, back, shoulders, arms, legs, core

  var id: String { rawValue }

  var title: String {
    switch self {
    case .chest:     return "Brust"
    case .back:      return "Rücken"
    case .shoulders: return "Schultern"
    case .arms:      return "Arme"
    case .legs:      return "Beine"
    case .core:      return "Core"
    }
  }
}

/// Verletzungen / Einschränkungen, die Übungs- und Split-Wahl beeinflussen.
enum WorkoutLimitation: String, CaseIterable, Identifiable {
  case knee, shoulder, lowerBack, wrist, elbow

  var id: String { rawValue }

  var title: String {
    switch self {
    case .knee:      return "Knie"
    case .shoulder:  return "Schulter"
    case .lowerBack: return "Unterer Rücken"
    case .wrist:     return "Handgelenk"
    case .elbow:     return "Ellenbogen"
    }
  }

  var hint: String {
    switch self {
    case .knee:
      return "Tiefe Kniebeugen / Sprünge werden ersetzt durch Hüft-dominante Optionen."
    case .shoulder:
      return "Overhead-Press wird neutralisiert (Landmine, neutrale Griffe)."
    case .lowerBack:
      return "Konventionelles Kreuzheben → Hex-Bar / Maschinen Hinge."
    case .wrist:
      return "Bevorzugt Kabel / Maschinen statt freier Hantel-Curls."
    case .elbow:
      return "Trizeps-Skullcrusher → Cable Push-Down, Bizeps neutral.``"
    }
  }
}

/// Wettkampf-/Ausdauerziel beeinflusst Wochen-Kilometer und Verteilung.
enum RunningGoal: String, CaseIterable {
  case general
  case fiveK
  case tenK
  case halfMarathon
  case marathon

  var title: String {
    switch self {
    case .general:      return "Allgemein"
    case .fiveK:        return "5K"
    case .tenK:         return "10K"
    case .halfMarathon: return "Halbmarathon"
    case .marathon:     return "Marathon"
    }
  }

  /// Empfohlenes Wochenkilometer-Ziel als Startwert.
  var defaultWeeklyKilometers: Int {
    switch self {
    case .general:      return 15
    case .fiveK:        return 25
    case .tenK:         return 35
    case .halfMarathon: return 50
    case .marathon:     return 65
    }
  }
}

/// Verteilungsmodell der Cardio-Intensitäten (Seiler 2010, Stöggl & Sperlich 2014).
enum RunIntensityModel: String, CaseIterable {
  case polarized80_20   // 80 % low / 20 % high — Goldstandard für Ausdauer
  case pyramidal        // viel low, etwas threshold, wenig high
  case threshold        // Tempo-fokussiert
  case minimalist       // wenig Volumen, hohe Intensität (Zeitmangel)

  var title: String {
    switch self {
    case .polarized80_20: return "Polarisiert 80/20"
    case .pyramidal:      return "Pyramidal"
    case .threshold:      return "Threshold"
    case .minimalist:     return "Minimalist"
    }
  }

  var detail: String {
    switch self {
    case .polarized80_20:
      return "80 % easy + 20 % hart. Studien zeigen besten VO₂max-Zuwachs (Seiler)."
    case .pyramidal:
      return "Locker dominiert, ergänzt durch Tempo & wenige Intervalle."
    case .threshold:
      return "Fokus auf Tempodauerläufe – effizient für 5–10 K Spezifität."
    case .minimalist:
      return "Wenige Einheiten, dafür hochintensiv (HIIT-Studien Tabata, Gibala)."
    }
  }
}

/// Konkrete Session-Art, die ein Tag bekommt – nutzbar für Hybrid-Pläne.
enum PlannedSessionKind: String {
  case strength
  case easyRun
  case tempoRun
  case intervalRun
  case longRun
  case recoveryRun
  case mobility

  var title: String {
    switch self {
    case .strength:     return "Krafttraining"
    case .easyRun:      return "Easy Run"
    case .tempoRun:     return "Tempo Run"
    case .intervalRun:  return "Intervalle"
    case .longRun:      return "Long Run"
    case .recoveryRun:  return "Recovery Run"
    case .mobility:     return "Mobility"
    }
  }

  var shortLabel: String {
    switch self {
    case .strength:     return "KRAFT"
    case .easyRun:      return "EASY"
    case .tempoRun:     return "TEMPO"
    case .intervalRun:  return "INTERVAL"
    case .longRun:      return "LONG"
    case .recoveryRun:  return "RECOVERY"
    case .mobility:     return "MOBILITY"
    }
  }

  var isRun: Bool {
    switch self {
    case .easyRun, .tempoRun, .intervalRun, .longRun, .recoveryRun: return true
    default: return false
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

  // Studien-basierte Rahmenbedingungen
  var experience: TrainingExperience
  var equipment: GymEquipment
  var splitPreference: SplitPreference
  var recoveryCapacity: RecoveryCapacity
  var prioritizedMuscles: Set<MuscleGroup>
  var limitations: Set<WorkoutLimitation>

  // Lauf-Bereich
  var runningGoal: RunningGoal
  var runIntensityModel: RunIntensityModel
  var weeklyKilometerTarget: Int

  // ── Manueller Plan ────────────────────────────────────────────────
  // Wenn `isManualPlan == true` setzt der Nutzer pro Wochentag selbst,
  // ob/welche Session läuft. Die Auto-Verteilung der Engine wird dann
  // durch `manualSessionKinds` ersetzt. Krafttage erkennt man an
  // `manualSessionKinds[day] == .strength`, Lauftage an einem Run-Kind,
  // Pausen daran, dass kein Eintrag existiert (Day-Pref steht dann auf
  // .rest). Standardmäßig aus, damit Wizard-Flow unverändert bleibt.
  var isManualPlan: Bool
  var manualSessionKinds: [Weekday: PlannedSessionKind]

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
    dayAssignments: [:],
    experience: .intermediate,
    equipment: .fullGym,
    splitPreference: .auto,
    recoveryCapacity: .medium,
    prioritizedMuscles: [],
    limitations: [],
    runningGoal: .general,
    runIntensityModel: .polarized80_20,
    weeklyKilometerTarget: 20,
    isManualPlan: false,
    manualSessionKinds: [:]
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
  // NEU – wenn der Tag als Lauf-/Hybrid-Session geplant ist:
  let sessionKind: PlannedSessionKind?
  let runTemplate: RunTemplate?

  init(
    weekday: Weekday,
    dayLabel: String,
    title: String,
    focus: String,
    isToday: Bool,
    status: WorkoutDayStatus,
    workoutPlan: WorkoutPlan?,
    sessionKind: PlannedSessionKind? = nil,
    runTemplate: RunTemplate? = nil
  ) {
    self.weekday = weekday
    self.dayLabel = dayLabel
    self.title = title
    self.focus = focus
    self.isToday = isToday
    self.status = status
    self.workoutPlan = workoutPlan
    self.sessionKind = sessionKind
    self.runTemplate = runTemplate
  }
}

struct PlannerRecommendation: Identifiable {
  let id = UUID()
  let title: String
  let detail: String
  let weekdays: [Weekday]

  // Studien-basierte Empfehlungswerte (optional, nur wenn Engine sie kennt)
  var setsPerMuscleGroupRange: ClosedRange<Int>? = nil
  var frequencyPerMuscleGroup: Int? = nil
  var repRange: ClosedRange<Int>? = nil
  var rirRange: ClosedRange<Int>? = nil
  var restSecondsCompound: Int? = nil
  var restSecondsIsolation: Int? = nil
  var weeklyKilometerTarget: Int? = nil
  var evidenceNote: String? = nil

  init(
    title: String,
    detail: String,
    weekdays: [Weekday],
    setsPerMuscleGroupRange: ClosedRange<Int>? = nil,
    frequencyPerMuscleGroup: Int? = nil,
    repRange: ClosedRange<Int>? = nil,
    rirRange: ClosedRange<Int>? = nil,
    restSecondsCompound: Int? = nil,
    restSecondsIsolation: Int? = nil,
    weeklyKilometerTarget: Int? = nil,
    evidenceNote: String? = nil
  ) {
    self.title = title
    self.detail = detail
    self.weekdays = weekdays
    self.setsPerMuscleGroupRange = setsPerMuscleGroupRange
    self.frequencyPerMuscleGroup = frequencyPerMuscleGroup
    self.repRange = repRange
    self.rirRange = rirRange
    self.restSecondsCompound = restSecondsCompound
    self.restSecondsIsolation = restSecondsIsolation
    self.weeklyKilometerTarget = weeklyKilometerTarget
    self.evidenceNote = evidenceNote
  }
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

// MARK: - Gym Erweiterungen (4-Wochen-Vorschau & Set-History)

/// Eintrag in der 4-Wochen-Vorschau (Gym → PLAN-Tab).
/// Repräsentiert einen einzelnen Tag mit Kontext für die Anzeige im Streifen.
struct GymPlanPreviewDay: Identifiable {
  let id = UUID()
  let date: Date
  let weekday: Weekday
  let status: WorkoutDayStatus
  let title: String
  let isToday: Bool
  let isCompleted: Bool
  let runTemplate: RunTemplate?
}

/// Eine Woche der Vorschau, gruppiert für Anzeige als horizontaler Streifen.
struct GymPlanPreviewWeek: Identifiable {
  let id = UUID()
  let weekIndex: Int  // 0 = aktuelle Woche, 1 = nächste, ...
  let label: String   // "Diese Woche", "Nächste", "in 2 Wo."
  let days: [GymPlanPreviewDay]
}

/// Historie pro Übung über alle absolvierten Workouts hinweg.
/// Genutzt vom Set-History Drilldown im STATS-Tab.
struct ExerciseHistoryEntry: Identifiable {
  let id = UUID()
  let date: Date
  let workoutTitle: String
  let topWeight: Double
  let completedSets: Int
  let totalReps: Int
  let totalVolume: Double
}

/// Volumen-Schwellen je Muskel im Sinne des Renaissance-Periodization-Modells.
/// (Mike Israetel 2020 — MV / MEV / MAV / MRV).
struct VolumeLandmarks {
  let mev: Int   // Minimum Effective Volume — ab hier beginnt Wachstum
  let mav: Int   // Maximum Adaptive Volume — Sweet Spot Mitte
  let mrv: Int   // Maximum Recoverable Volume — darüber Recovery-Defizit

  /// Pragmatische Werte basierend auf RP-Empfehlungen, geclampt
  /// auf das Volumen-Range-Profil der Engine.
  static func from(range: ClosedRange<Int>) -> VolumeLandmarks {
    let mev = range.lowerBound
    let mav = (range.lowerBound + range.upperBound) / 2
    let mrv = max(range.upperBound + 4, Int(Double(range.upperBound) * 1.25))
    return VolumeLandmarks(mev: mev, mav: mav, mrv: mrv)
  }
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

enum ExerciseCategory: String, CaseIterable, Hashable {
  case chest      = "Brust"
  case back       = "Rücken"
  case legs       = "Beine"
  case glutes     = "Glutes"
  case shoulders  = "Schulter"
  case biceps     = "Bizeps"
  case triceps    = "Trizeps"
  case core       = "Core"
  case fullBody   = "Ganzkörper"
  case cardio     = "Cardio"
  case mobility   = "Mobility"

  var sortOrder: Int {
    switch self {
    case .chest:     return 0
    case .back:      return 1
    case .shoulders: return 2
    case .biceps:    return 3
    case .triceps:   return 4
    case .legs:      return 5
    case .glutes:    return 6
    case .core:      return 7
    case .fullBody:  return 8
    case .cardio:    return 9
    case .mobility:  return 10
    }
  }

  var systemImage: String {
    switch self {
    case .chest:     return "figure.strengthtraining.traditional"
    case .back:      return "figure.cooldown"
    case .legs:      return "figure.run"
    case .glutes:    return "figure.flexibility"
    case .shoulders: return "figure.boxing"
    case .biceps:    return "figure.arms.open"
    case .triceps:   return "figure.arms.open"
    case .core:      return "figure.core.training"
    case .fullBody:  return "figure.mixed.cardio"
    case .cardio:    return "heart.fill"
    case .mobility:  return "figure.yoga"
    }
  }
}

enum ExerciseDifficulty: String, CaseIterable, Hashable {
  case beginner     = "Anfänger"
  case intermediate = "Fortgeschritten"
  case advanced     = "Profi"
}

struct ExerciseLibraryItem: Identifiable, Hashable {
  let id = UUID()
  let name: String
  let primaryMuscle: String
  let equipment: String
  let defaultSets: Int
  let defaultReps: Int
  let suggestedWeight: Double

  // Metadaten für die Übungs-Bibliothek (Whoop-Style Detail-Sheet)
  let category: ExerciseCategory
  let secondaryMuscles: [String]
  let instructions: [String]
  let tips: [String]
  let commonMistakes: [String]
  let videoURL: URL?
  let difficulty: ExerciseDifficulty

  init(
    name: String,
    primaryMuscle: String,
    equipment: String,
    defaultSets: Int,
    defaultReps: Int,
    suggestedWeight: Double,
    category: ExerciseCategory = .fullBody,
    secondaryMuscles: [String] = [],
    instructions: [String] = [],
    tips: [String] = [],
    commonMistakes: [String] = [],
    videoURL: URL? = nil,
    difficulty: ExerciseDifficulty = .intermediate
  ) {
    self.name = name
    self.primaryMuscle = primaryMuscle
    self.equipment = equipment
    self.defaultSets = defaultSets
    self.defaultReps = defaultReps
    self.suggestedWeight = suggestedWeight
    self.category = category
    self.secondaryMuscles = secondaryMuscles
    self.instructions = instructions
    self.tips = tips
    self.commonMistakes = commonMistakes
    self.videoURL = videoURL
    self.difficulty = difficulty
  }
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
  // order ist var (statt let), damit removeSet/duplicateSet die Sätze
  // nach Insert/Delete neu durchnummerieren können (Optimierungs-Sweep
  // 2026-05-03). Der Initializer verlangt order weiterhin explizit.
  var order: Int
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

/// Cardio-Modalität eines Lauf-/Rad-Slots. Ermöglicht es, den Run-Tracker
/// für Bike-Sessions wiederzuverwenden, ohne die History zu vermischen —
/// `WeekdayDetailSheet` und der Wochen-Plan unterscheiden Lauf- vs. Rad-Tag
/// über dieses Feld.
/// Cardio-Modalität — Lauf, Outdoor-Rad (mit GPS) oder Indoor-Rad (Heimtrainer/
/// Spinning, ohne GPS, Distanz manuell oder per BLE-Sensor). Das Feld wird
/// bei `ActiveRunSession`, `CompletedRunSummary` und `RunTemplate` gepflegt
/// und steuert UI-Labels (km/h vs. min/km), GPS-Aktivierung und Speed-
/// Validierungsgrenzen im Tracker.
enum CardioModality: String, Codable, CaseIterable {
  case run
  case bikeOutdoor
  case bikeIndoor

  /// Tolerant Decoder: alter Persistenz-Wert `"bike"` (Pre-Indoor-Erweiterung)
  /// wird auf `.bikeOutdoor` gemappt, damit History-Records aus früheren
  /// Builds weiter laden. Unbekannte Werte fallen auf `.run` zurück.
  static func decode(legacyRaw raw: String?) -> CardioModality {
    guard let raw else { return .run }
    if let exact = CardioModality(rawValue: raw) { return exact }
    if raw == "bike" { return .bikeOutdoor }
    return .run
  }

  var displayName: String {
    switch self {
    case .run:         return "Lauf"
    case .bikeOutdoor: return "Rad"
    case .bikeIndoor:  return "Rad Indoor"
    }
  }

  var shortLabel: String {
    switch self {
    case .run:         return "LAUF"
    case .bikeOutdoor: return "RAD"
    case .bikeIndoor:  return "INDOOR"
    }
  }

  var systemImage: String {
    switch self {
    case .run:         return "figure.run"
    case .bikeOutdoor: return "figure.outdoor.cycle"
    case .bikeIndoor:  return "figure.indoor.cycle"
    }
  }

  /// True für beide Rad-Modi.
  var isCycling: Bool {
    switch self {
    case .bikeOutdoor, .bikeIndoor: return true
    case .run: return false
    }
  }

  /// Stationär (kein GPS, keine Map, kein Höhenmesser).
  var isIndoor: Bool { self == .bikeIndoor }

  /// True, wenn echte GPS-Tracking-Distanz erwartet wird.
  var requiresGPS: Bool {
    switch self {
    case .run, .bikeOutdoor: return true
    case .bikeIndoor:        return false
    }
  }

  /// Maximal plausible Bewegungsgeschwindigkeit (m/s) für die Speed-
  /// Validation im GPS-Tracker. Indoor-Wert wird nicht genutzt, ist aber
  /// gesetzt damit Switches komplett bleiben.
  var maxPlausibleSpeed: Double {
    switch self {
    case .run:         return 10
    case .bikeOutdoor: return 25
    case .bikeIndoor:  return 25
    }
  }

  /// Pace-/Geschwindigkeits-Einheit für die Live-Anzeige.
  /// Lauf misst min/km, Rad misst km/h.
  var paceUnitLabel: String {
    switch self {
    case .run:                       return "/km"
    case .bikeOutdoor, .bikeIndoor:  return "km/h"
    }
  }

  /// Default-Titel für den Quick-Run/-Ride ohne Template.
  var freshTitle: String {
    switch self {
    case .run:         return "Freier Lauf"
    case .bikeOutdoor: return "Freie Fahrt"
    case .bikeIndoor:  return "Indoor Bike"
    }
  }

  /// Default-Routenname für den Quick-Run/-Ride ohne Template.
  var freshRouteName: String {
    switch self {
    case .run:         return "Freie Strecke"
    case .bikeOutdoor: return "Freie Strecke"
    case .bikeIndoor:  return "Heimtrainer"
    }
  }

  /// MET-Wert für die Kalorien-Schätzung im Indoor-Modus
  /// (mittlere Intensität — Anwender kann das später feiner justieren).
  var defaultMET: Double {
    switch self {
    case .run:         return 9.8   // ~6 min/km
    case .bikeOutdoor: return 8.0   // moderates Tempo
    case .bikeIndoor:  return 7.0   // Heimtrainer mittel
    }
  }
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
  /// Optional — wenn `nil`, wird der Slot wie ein klassischer Lauf
  /// behandelt (Default für ältere Templates ohne explizite Modalität).
  let modality: CardioModality?

  init(
    id: UUID = UUID(),
    title: String,
    subtitle: String,
    routeName: String,
    targetDistanceKm: Double,
    targetDurationMinutes: Int,
    targetPaceLabel: String,
    systemImage: String,
    modality: CardioModality? = .run
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.routeName = routeName
    self.targetDistanceKm = targetDistanceKm
    self.targetDurationMinutes = targetDurationMinutes
    self.targetPaceLabel = targetPaceLabel
    self.systemImage = systemImage
    self.modality = modality
  }
}

/// Intensität einer Lauf-Einheit. Steuert Pace/HF-Erwartung und Audio-Cues.
enum RunIntensity: String, CaseIterable, Codable {
  case easy
  case tempo
  case interval
  case long
  case recovery
  case free

  var title: String {
    switch self {
    case .easy:     return "Easy"
    case .tempo:    return "Tempo"
    case .interval: return "Intervalle"
    case .long:     return "Long Run"
    case .recovery: return "Recovery"
    case .free:     return "Frei"
    }
  }

  var shortLabel: String {
    switch self {
    case .easy:     return "EASY"
    case .tempo:    return "TEMPO"
    case .interval: return "INTERVAL"
    case .long:     return "LONG"
    case .recovery: return "RECOVERY"
    case .free:     return "FREI"
    }
  }

  var systemImage: String {
    switch self {
    case .easy:     return "figure.run"
    case .tempo:    return "bolt.heart.fill"
    case .interval: return "bolt.circle.fill"
    case .long:     return "map.fill"
    case .recovery: return "heart.circle.fill"
    case .free:     return "figure.run.circle"
    }
  }

  /// Empfohlener HF-Zonen-Bereich (1–5) für die Einheit.
  var targetZoneRange: ClosedRange<Int> {
    switch self {
    case .recovery: return 1...1
    case .easy:     return 2...2
    case .long:     return 2...3
    case .tempo:    return 3...4
    case .interval: return 4...5
    case .free:     return 1...5
    }
  }
}

/// Welches Ziel verfolgt der Lauf?
enum RunTargetMode: String, Codable, CaseIterable {
  case free       // kein Ziel
  case distance   // Ziel-Distanz in km
  case duration   // Ziel-Dauer in Minuten
  case pace       // Ziel-Pace in Sekunden/km

  var title: String {
    switch self {
    case .free:     return "Frei"
    case .distance: return "Distanz"
    case .duration: return "Dauer"
    case .pace:     return "Pace"
    }
  }
}

/// Subjektives Empfinden nach dem Lauf (1 = leicht, 5 = brutal).
enum RunFeel: Int, Codable, CaseIterable {
  case veryEasy = 1
  case easy = 2
  case okay = 3
  case hard = 4
  case veryHard = 5

  var title: String {
    switch self {
    case .veryEasy: return "Sehr leicht"
    case .easy:     return "Leicht"
    case .okay:     return "Okay"
    case .hard:     return "Hart"
    case .veryHard: return "Sehr hart"
    }
  }

  var emojiSymbol: String {
    switch self {
    case .veryEasy: return "face.smiling"
    case .easy:     return "face.smiling.inverse"
    case .okay:     return "minus.circle"
    case .hard:     return "flame"
    case .veryHard: return "flame.fill"
    }
  }
}

/// Herzfrequenz-Zonen 1–5 nach Karvonen-Stil (% der maximalen HF).
enum HRZone: Int, CaseIterable, Codable {
  case zone1 = 1
  case zone2 = 2
  case zone3 = 3
  case zone4 = 4
  case zone5 = 5

  var title: String {
    switch self {
    case .zone1: return "Z1 · Regeneration"
    case .zone2: return "Z2 · Grundlage"
    case .zone3: return "Z3 · Tempo"
    case .zone4: return "Z4 · Schwelle"
    case .zone5: return "Z5 · VO₂max"
    }
  }

  var shortLabel: String { "Z\(rawValue)" }

  /// Untere/obere Prozent-Grenze als Anteil der maximalen HF.
  var fractionRange: ClosedRange<Double> {
    switch self {
    case .zone1: return 0.50...0.60
    case .zone2: return 0.60...0.70
    case .zone3: return 0.70...0.80
    case .zone4: return 0.80...0.90
    case .zone5: return 0.90...1.00
    }
  }

  /// Zone für eine konkrete Herzfrequenz bei gegebener maximaler HF.
  static func zone(for bpm: Int, maxHR: Int) -> HRZone? {
    guard bpm > 0, maxHR > 0 else { return nil }
    let fraction = Double(bpm) / Double(maxHR)
    switch fraction {
    case ..<0.60:  return .zone1
    case ..<0.70:  return .zone2
    case ..<0.80:  return .zone3
    case ..<0.90:  return .zone4
    default:       return .zone5
    }
  }
}

struct RunSplit: Identifiable {
  let id: UUID
  let index: Int
  let distanceKm: Double
  let durationMinutes: Int
  let averageHeartRate: Int
  /// True, wenn der Split durch einen manuellen Lap (Button) entstanden ist.
  var isManualLap: Bool = false

  var paceSeconds: Int {
    guard distanceKm > 0 else { return 0 }
    return Int((Double(durationMinutes) * 60) / distanceKm)
  }

  /// Genauere Pace inkl. Sekundenanteil — durationSeconds optional übergeben.
  func paceSeconds(durationSeconds: Int) -> Int {
    guard distanceKm > 0, durationSeconds > 0 else { return paceSeconds }
    return Int(Double(durationSeconds) / distanceKm)
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
  var targetMode: RunTargetMode = .free
  var targetPaceSeconds: Int = 0
  var intensity: RunIntensity = .free
  var distanceKm: Double
  var durationMinutes: Int
  var elevationGain: Int
  var currentHeartRate: Int
  var isPaused: Bool
  var autoPauseEnabled: Bool = true
  var audioCuesEnabled: Bool = true
  var routeCoordinates: [CLLocationCoordinate2D]
  var splits: [RunSplit]
  /// HF-Zonen-Verteilung in Sekunden je Zone (1–5). Index 0 = Zone 1.
  var hrZoneSecondsBuckets: [Int] = [0, 0, 0, 0, 0]
  /// Cardio-Modalität (Lauf/Rad). Wird beim Start aus `RunTemplate.modality`
  /// bzw. dem Pre-Run-Setup gesetzt und vom GPS-Tracker zur Plausibilitäts-
  /// Validation der Geschwindigkeit benötigt (Lauf max ~10 m/s, Rad ~25 m/s).
  /// Default `.run` deckt den Bestandsfall (Quick-Run, Wiederhole-Lauf) ab.
  var modality: CardioModality = .run

  var averagePaceSeconds: Int {
    guard distanceKm > 0 else { return 0 }
    return Int((Double(durationMinutes) * 60) / distanceKm)
  }

  /// Fortschritt 0–1 in Bezug auf den gewählten Zielmodus.
  func progressFraction(elapsedSeconds: Int) -> Double {
    switch targetMode {
    case .free:
      return 0
    case .distance:
      guard targetDistanceKm > 0 else { return 0 }
      return min(distanceKm / targetDistanceKm, 1)
    case .duration:
      guard targetDurationMinutes > 0 else { return 0 }
      let elapsedMin = Double(elapsedSeconds) / 60.0
      return min(elapsedMin / Double(targetDurationMinutes), 1)
    case .pace:
      guard targetPaceSeconds > 0, distanceKm > 0 else { return 0 }
      // 1.0 = exakt im Plan, kleiner = schneller, größer = langsamer
      let actualPace = Double(elapsedSeconds) / distanceKm
      return min(Double(targetPaceSeconds) / max(actualPace, 1), 1)
    }
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
  var intensity: RunIntensity = .free
  var feel: RunFeel? = nil
  var note: String = ""
  /// HF-Zonen-Verteilung in Sekunden, Index 0 = Zone 1.
  var hrZoneSecondsBuckets: [Int] = [0, 0, 0, 0, 0]
  /// Cardio-Modalität, mit der die Session aufgezeichnet wurde. Wichtig für
  /// die Wiederholung („gleichen Lauf nochmal") und das Filtern in Statistik
  /// und Cardio-Hub. Default `.run` deckt persistierte Datensätze aus der
  /// Zeit vor dem Bike-Modus ab.
  var modality: CardioModality = .run

  var averagePaceSeconds: Int {
    guard distanceKm > 0 else { return 0 }
    return Int((Double(durationMinutes) * 60) / distanceKm)
  }

  /// Anteil je Zone (0–1). Falls keine Daten vorhanden, alle 0.
  var hrZoneFractions: [Double] {
    let total = max(hrZoneSecondsBuckets.reduce(0, +), 1)
    return hrZoneSecondsBuckets.map { Double($0) / Double(total) }
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
    RunTemplate(
      id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
      title: "VO₂max Intervalle",
      subtitle: "5 × 1000 m am Schwellenpuls + 90 s Trab (HIIT-Reiz)",
      routeName: "Track / Riverside Loop",
      targetDistanceKm: 7.5,
      targetDurationMinutes: 38,
      targetPaceLabel: "4:00 /km (Intervall)",
      systemImage: "bolt.circle.fill"
    ),
    // 2026-05-03 (P1-7): Drei Bike-Templates parallel zu den fünf Lauf-
    // Vorlagen. Werden im Hub als `MODUS RAD`-Badge gerendert, wenn
    // entweder ein Bike-Modus aktiv ist oder die Session-Engine sie für
    // den Default-Modus filtert.
    RunTemplate(
      id: UUID(uuidString: "61616161-6161-6161-6161-616161616161")!,
      title: "Endurance-Tour 30 km",
      subtitle: "Lockere Outdoor-Runde — Grundlage Aerob (Z2)",
      routeName: "Stadtrand / Feldweg",
      targetDistanceKm: 30.0,
      targetDurationMinutes: 75,
      targetPaceLabel: "24 km/h (Z2)",
      systemImage: "figure.outdoor.cycle",
      modality: .bikeOutdoor
    ),
    RunTemplate(
      id: UUID(uuidString: "62626262-6262-6262-6262-626262626262")!,
      title: "Sweet-Spot 60 min",
      subtitle: "Heimtrainer · 4 × 10 min knapp unter Schwelle, 5 min Pause",
      routeName: "Indoor Bike",
      targetDistanceKm: 25.0,
      targetDurationMinutes: 60,
      targetPaceLabel: "26 km/h (Sweet Spot)",
      systemImage: "figure.indoor.cycle",
      modality: .bikeIndoor
    ),
    RunTemplate(
      id: UUID(uuidString: "63636363-6363-6363-6363-636363636363")!,
      title: "Recovery Spin 20 min",
      subtitle: "Sehr lockere Regeneration nach hartem Training",
      routeName: "Indoor Bike / Flacher Loop",
      targetDistanceKm: 7.0,
      targetDurationMinutes: 20,
      targetPaceLabel: "20 km/h (Z1)",
      systemImage: "heart.circle.fill",
      modality: .bikeOutdoor
    ),
  ]

  /// Mappt eine geplante Session-Art auf eine sinnvolle Lauf-Vorlage.
  static func template(for kind: PlannedSessionKind) -> RunTemplate? {
    switch kind {
    case .easyRun:
      return stravaInspiredTemplates.first { $0.title == "Easy 5K" }
    case .tempoRun:
      return stravaInspiredTemplates.first { $0.title == "Tempo 8K" }
    case .intervalRun:
      return stravaInspiredTemplates.first { $0.title == "VO₂max Intervalle" }
    case .longRun:
      return stravaInspiredTemplates.first { $0.title == "Long Run 12K" }
    case .recoveryRun:
      return stravaInspiredTemplates.first { $0.title == "Recovery Run" }
    case .strength, .mobility:
      return nil
    }
  }
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
      targetMode: template.targetDistanceKm > 0 ? .distance : .free,
      targetPaceSeconds: template.targetPaceSecondsDerived,
      intensity: template.intensityDerived,
      distanceKm: 0,
      durationMinutes: 0,
      elevationGain: 0,
      currentHeartRate: 136,
      isPaused: false,
      autoPauseEnabled: true,
      audioCuesEnabled: true,
      routeCoordinates: [],
      splits: [],
      hrZoneSecondsBuckets: [0, 0, 0, 0, 0],
      modality: template.modality ?? .run
    )
  }

  /// Frischer Quick-Run ohne Template — der Nutzer wählt im Pre-Run-Setup, was sein Ziel ist.
  static func freshQuickRun(modality: CardioModality = .run) -> ActiveRunSession {
    ActiveRunSession(
      id: UUID(),
      title: modality.freshTitle,
      routeName: modality.freshRouteName,
      startedAt: Date(),
      targetDistanceKm: 0,
      targetDurationMinutes: 0,
      targetPaceLabel: "",
      targetMode: .free,
      targetPaceSeconds: 0,
      intensity: .free,
      distanceKm: 0,
      durationMinutes: 0,
      elevationGain: 0,
      currentHeartRate: 0,
      isPaused: false,
      // Indoor: Auto-Pause macht keinen Sinn (Heimtrainer steht ja immer still).
      autoPauseEnabled: !modality.isIndoor,
      audioCuesEnabled: true,
      routeCoordinates: [],
      splits: [],
      hrZoneSecondsBuckets: [0, 0, 0, 0, 0],
      modality: modality
    )
  }
}

extension RunTemplate {
  /// Versuche, aus dem `targetPaceLabel` eine Sekundenzahl pro km abzuleiten ("4:45 /km").
  var targetPaceSecondsDerived: Int {
    let trimmed = targetPaceLabel
      .components(separatedBy: " ")
      .first ?? targetPaceLabel
    let parts = trimmed.split(separator: ":")
    guard parts.count == 2,
          let m = Int(parts[0]),
          let s = Int(parts[1]) else { return 0 }
    return m * 60 + s
  }

  /// Heuristische Zuordnung Template → Intensität.
  var intensityDerived: RunIntensity {
    let t = title.lowercased()
    if t.contains("interval") || t.contains("vo") { return .interval }
    if t.contains("tempo")    { return .tempo }
    if t.contains("long")     { return .long }
    if t.contains("recovery") { return .recovery }
    if t.contains("easy")     { return .easy }
    return .free
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

// HINWEIS: Die vollständige Übungsbibliothek liegt in `ExerciseCatalog.swift`
// (kategorisiert, mit Anleitungen, Sekundärmuskeln, Tipps und häufigen Fehlern).
extension ExerciseLibraryItem {
  /// Bestehender Alias für Aufrufer in `GainsStore` etc. — verweist auf den
  /// vollständigen Katalog. Sortiert nach Kategorie + Name für stabile Anzeige.
  static let commonGymExercises: [ExerciseLibraryItem] = ExerciseLibraryItem.fullCatalog
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
        templateExercise(named: "Schulterdrücken Kurzhantel"),
        templateExercise(named: "Rudern sitzend Kabel"),
        templateExercise(named: "Langhantel Curls"),
        templateExercise(named: "Trizeps Pushdown (Seil)"),
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
        templateExercise(named: "Beinpresse 45°"),
        templateExercise(named: "Beinbeuger sitzend"),
        templateExercise(named: "Wadenheben stehend"),
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
        templateExercise(named: "Seitheben Kurzhantel"),
        templateExercise(named: "Trizeps Pushdown (Seil)"),
        templateExercise(named: "Trizeps Dips"),
      ]
    ),
    WorkoutPlan(
      title: "Pull",
      focus: "Rücken / Bizeps",
      split: "Pull",
      estimatedDurationMinutes: 56,
      exercises: [
        templateExercise(named: "Latzug breit"),
        templateExercise(named: "Langhantelrudern"),
        templateExercise(named: "Rudern sitzend Kabel"),
        templateExercise(named: "Face Pulls"),
        templateExercise(named: "Hammer Curls"),
      ]
    ),
    WorkoutPlan(
      title: "Beine",
      focus: "Quads / Glutes",
      split: "Beine",
      estimatedDurationMinutes: 60,
      exercises: [
        templateExercise(named: "Kniebeugen"),
        templateExercise(named: "Beinpresse 45°"),
        templateExercise(named: "Beinstrecker"),
        templateExercise(named: "Beinbeuger sitzend"),
        templateExercise(named: "Wadenheben stehend"),
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

extension ForumThread {
  static let mockThreads: [ForumThread] = [
    ForumThread(
      id: UUID(uuidString: "f0000001-0000-0000-0000-000000000001")!,
      category: .gyms,
      title: "Bestes Gym in Berlin Mitte mit freier Hantelfläche?",
      body:
        "Suche ein Studio mit ordentlichen Powerracks, idealerweise nicht zu voll am Abend. Tagespass wäre super.",
      author: "Mila",
      handle: "@mila.cuts",
      createdAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()) ?? Date(),
      location: "Berlin",
      replies: [
        ForumReply(
          id: UUID(),
          author: "Noah",
          handle: "@noah.runlift",
          body:
            "Gym80 in der Friedrichstraße läuft super. Drei Powerracks, ab 21 Uhr ist es fast leer.",
          createdAt: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date()
        ),
        ForumReply(
          id: UUID(),
          author: "Leonie",
          handle: "@leonie.gains",
          body: "Plus 1 für Gym80. Es gibt auch Tagespässe für 18 €.",
          createdAt: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date()
        ),
      ],
      likeCount: 12
    ),
    ForumThread(
      id: UUID(uuidString: "f0000002-0000-0000-0000-000000000002")!,
      category: .nutrition,
      title: "Quark vs. Skyr im Cut – was nehmt ihr?",
      body:
        "Ich vergleiche die beiden gerade und Skyr scheint mehr Protein zu haben, aber Quark ist günstiger. Ernährungstechnisch ein Wash?",
      author: "Sami",
      handle: "@sami.bulkphase",
      createdAt: Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date(),
      location: nil,
      replies: [
        ForumReply(
          id: UUID(),
          author: "Mila",
          handle: "@mila.cuts",
          body:
            "Ich nehme Magerquark zur Basis und mische 100 g Skyr für die Konsistenz. Beste Mischung beim Cut.",
          createdAt: Calendar.current.date(byAdding: .hour, value: -7, to: Date()) ?? Date()
        )
      ],
      likeCount: 8
    ),
    ForumThread(
      id: UUID(uuidString: "f0000003-0000-0000-0000-000000000003")!,
      category: .localSports,
      title: "Lauftreff Tempelhofer Feld Mittwochs?",
      body:
        "Gibt es hier jemanden, der Mittwochs gegen 19 Uhr beim öffentlichen Lauftreff dabei ist? Wäre cool, gemeinsam zu starten.",
      author: "Noah",
      handle: "@noah.runlift",
      createdAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
      location: "Berlin",
      replies: [],
      likeCount: 5
    ),
  ]
}

extension Meetup {
  static let mockMeetups: [Meetup] = [
    Meetup(
      id: UUID(uuidString: "11111111-2222-3333-4444-555555555551")!,
      sport: .run,
      title: "Easy 8K am Tempelhofer Feld",
      locationName: "Tempelhofer Feld, Eingang Oderstraße",
      startsAt: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
      pace: "5:30 /km",
      hostHandle: "@noah.runlift",
      hostName: "Noah",
      notes:
        "Lockere Zone-2-Runde, gerne auch Anfänger. Wir starten pünktlich am Haupteingang.",
      maxParticipants: 8,
      participantHandles: ["@noah.runlift", "@mila.cuts"]
    ),
    Meetup(
      id: UUID(uuidString: "11111111-2222-3333-4444-555555555552")!,
      sport: .gym,
      title: "Push Session im Gym80",
      locationName: "Gym80, Friedrichstraße 14",
      startsAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
      pace: nil,
      hostHandle: "@leonie.gains",
      hostName: "Leonie",
      notes: "Schulter, Brust, Trizeps. Plan teilen wir vor Ort, ca. 75 Minuten.",
      maxParticipants: 4,
      participantHandles: ["@leonie.gains"]
    ),
    Meetup(
      id: UUID(uuidString: "11111111-2222-3333-4444-555555555553")!,
      sport: .cycling,
      title: "Sonntagsrunde Wannsee Loop",
      locationName: "Hauptbahnhof, Bike-Treffpunkt",
      startsAt: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
      pace: "28 km/h Schnitt",
      hostHandle: "@sami.bulkphase",
      hostName: "Sami",
      notes: "60 km flach, kurze Pause am Wannsee. Helm und Trinkflasche mitbringen.",
      maxParticipants: 6,
      participantHandles: ["@sami.bulkphase"]
    ),
  ]
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
        mealType: .lunch,
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
        ],
        tags: [.postWorkout, .quick],
        servings: 1
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
        ],
        tags: [.mealprep, .noCook, .quick, .budget],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
        title: "Pasta Beef Performance",
        category: "Dinner",
        goal: .zunehmen,
        dietaryStyle: .omnivore,
        mealType: .lunch,
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
        ],
        tags: [.batchcook, .oneOnePan, .budget],
        servings: 2
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
        ],
        tags: [.quick, .lowCarb, .noCook],
        servings: 1
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
        ],
        tags: [.postWorkout, .quick, .noCook],
        servings: 1
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
        ],
        tags: [.quick, .postWorkout],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "66666666-7777-8888-9999-aaaaaaaaaaaa")!,
        title: "Salmon Rice Recovery",
        category: "Dinner",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .lunch,
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
        ],
        tags: [.postWorkout, .mealprep],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "bbbbbbbb-cccc-dddd-eeee-ffffffffffff")!,
        title: "Tofu Peanut Noodles",
        category: "Lunch",
        goal: .zunehmen,
        dietaryStyle: .vegan,
        mealType: .lunch,
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
        ],
        tags: [.oneOnePan, .budget],
        servings: 1
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
        ],
        tags: [.quick, .budget],
        servings: 1
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
        ],
        tags: [.noCook, .quick, .postWorkout],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "0a0b0c0d-1e1f-2021-2223-242526272829")!,
        title: "Chicken Pesto Sandwich Bulk",
        category: "Lunch",
        goal: .zunehmen,
        dietaryStyle: .omnivore,
        mealType: .lunch,
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
        ],
        tags: [.quick, .postWorkout],
        servings: 1
      ),

      // MARK: - Mealprep Boxes (für mehrere Tage)

      Recipe(
        id: UUID(uuidString: "10000001-0000-0000-0000-000000000001")!,
        title: "Mealprep Hähnchen-Reis Boxes",
        category: "Mealprep",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "shippingbox.fill",
        prepMinutes: 45,
        calories: 565,
        protein: 52,
        carbs: 58,
        fat: 12,
        ingredients: [
          "800 g Hähnchenbrust",
          "320 g Basmatireis trocken",
          "500 g Brokkoli",
          "300 g Cherrytomaten",
          "3 EL Olivenöl",
          "Paprika, Knoblauch, Salz, Pfeffer",
        ],
        steps: [
          "Reis nach Packung kochen, parallel Brokkoli dämpfen.",
          "Hähnchen würzen, im Ofen bei 190°C 22 Min backen.",
          "Hähnchen in Streifen schneiden.",
          "Auf 4 Mealprep-Boxen verteilen, im Kühlschrank 4 Tage haltbar.",
        ],
        tags: [.mealprep, .batchcook, .postWorkout, .budget],
        servings: 4
      ),
      Recipe(
        id: UUID(uuidString: "10000001-0000-0000-0000-000000000002")!,
        title: "Mealprep Beef Chili Bowls",
        category: "Mealprep",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .dinner,
        imageURL:
          "https://images.unsplash.com/photo-1604329760661-e71dc83f8f26?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "flame.fill",
        prepMinutes: 35,
        calories: 498,
        protein: 41,
        carbs: 44,
        fat: 16,
        ingredients: [
          "750 g Rinderhack 5%",
          "2 Dosen Kidneybohnen (à 240 g abgetropft)",
          "2 Dosen gehackte Tomaten",
          "2 Paprika",
          "2 Zwiebeln",
          "Chili, Kreuzkümmel, Paprika, Salz",
        ],
        steps: [
          "Zwiebeln und Paprika würfeln und anbraten.",
          "Hack zugeben und krümelig braten.",
          "Tomaten, Bohnen und Gewürze einrühren, 20 Min köcheln.",
          "In 5 Boxen portionieren, hält im Kühlschrank 4 Tage oder 2 Monate eingefroren.",
        ],
        tags: [.mealprep, .batchcook, .oneOnePan, .budget],
        servings: 5
      ),
      Recipe(
        id: UUID(uuidString: "10000001-0000-0000-0000-000000000003")!,
        title: "Mealprep Curry Chicken Quinoa",
        category: "Mealprep",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1455619452474-d2be8b1e70cd?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "leaf.fill",
        prepMinutes: 40,
        calories: 534,
        protein: 46,
        carbs: 52,
        fat: 14,
        ingredients: [
          "600 g Hähnchenbrust",
          "240 g Quinoa trocken",
          "400 ml Kokosmilch light",
          "2 EL gelbe Currypaste",
          "300 g Süßkartoffel",
          "200 g Spinat",
        ],
        steps: [
          "Quinoa in 480 ml Wasser 12 Min köcheln.",
          "Hähnchen würfeln, mit Currypaste anbraten.",
          "Süßkartoffel, Kokosmilch zugeben, 15 Min köcheln, dann Spinat.",
          "In 4 Boxen mit Quinoa schichten.",
        ],
        tags: [.mealprep, .batchcook, .postWorkout],
        servings: 4
      ),
      Recipe(
        id: UUID(uuidString: "10000001-0000-0000-0000-000000000004")!,
        title: "Mealprep Tofu Quinoa Boxes",
        category: "Mealprep",
        goal: .abnehmen,
        dietaryStyle: .vegan,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "leaf.circle.fill",
        prepMinutes: 35,
        calories: 442,
        protein: 28,
        carbs: 48,
        fat: 14,
        ingredients: [
          "500 g Tofu natur",
          "200 g Quinoa trocken",
          "400 g Süßkartoffel",
          "300 g Rotkohl",
          "Sojasauce, Sesamöl, Knoblauch",
          "1 Zitrone",
        ],
        steps: [
          "Tofu pressen, würfeln und mit Sojasauce marinieren.",
          "Süßkartoffel würfeln, im Ofen 25 Min bei 200°C rösten.",
          "Tofu in der Pfanne knusprig braten.",
          "Quinoa kochen, alles in 4 Boxen schichten.",
        ],
        tags: [.mealprep, .batchcook, .budget],
        servings: 4
      ),
      Recipe(
        id: UUID(uuidString: "10000001-0000-0000-0000-000000000005")!,
        title: "Mealprep Linsen-Dal",
        category: "Mealprep",
        goal: .abnehmen,
        dietaryStyle: .vegan,
        mealType: .dinner,
        imageURL:
          "https://images.unsplash.com/photo-1626501122466-05c2b66bafb0?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "drop.fill",
        prepMinutes: 30,
        calories: 412,
        protein: 24,
        carbs: 58,
        fat: 8,
        ingredients: [
          "400 g rote Linsen",
          "1 Dose gehackte Tomaten",
          "400 ml Kokosmilch light",
          "2 Zwiebeln",
          "1 Stück Ingwer",
          "Curry, Kurkuma, Garam Masala",
        ],
        steps: [
          "Zwiebeln und Ingwer fein würfeln und anbraten.",
          "Gewürze zugeben, kurz mitrösten.",
          "Linsen, Tomaten und Kokosmilch + 600 ml Wasser zugeben, 20 Min köcheln.",
          "In 5 Boxen portionieren. Schmeckt am nächsten Tag besser.",
        ],
        tags: [.mealprep, .batchcook, .budget, .oneOnePan],
        servings: 5
      ),
      Recipe(
        id: UUID(uuidString: "10000001-0000-0000-0000-000000000006")!,
        title: "Mealprep Egg Muffins",
        category: "Mealprep",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .breakfast,
        imageURL:
          "https://images.unsplash.com/photo-1639024471283-03518883512d?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "circle.grid.3x3.fill",
        prepMinutes: 25,
        calories: 168,
        protein: 16,
        carbs: 4,
        fat: 10,
        ingredients: [
          "8 Eier",
          "100 g Feta",
          "150 g Spinat",
          "100 g Cherrytomaten",
          "Salz, Pfeffer",
          "Etwas Olivenöl",
        ],
        steps: [
          "Backofen auf 180°C vorheizen, Muffinform leicht ölen.",
          "Eier verquirlen, würzen.",
          "Spinat, Tomaten, Feta in 8 Mulden verteilen.",
          "Eimasse darübergeben, 18 Min backen. 4 Tage haltbar.",
        ],
        tags: [.mealprep, .lowCarb, .quick],
        servings: 8
      ),

      // MARK: - Airfryer Rezepte

      Recipe(
        id: UUID(uuidString: "20000002-0000-0000-0000-000000000001")!,
        title: "Airfryer Chicken Wings",
        category: "Airfryer",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .dinner,
        imageURL:
          "https://images.unsplash.com/photo-1624374053855-39a5a1a41402?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "wind",
        prepMinutes: 25,
        calories: 421,
        protein: 38,
        carbs: 6,
        fat: 26,
        ingredients: [
          "600 g Chicken Wings",
          "1 EL Paprika edelsüß",
          "1 TL Knoblauchpulver",
          "1 TL Salz",
          "1 TL geräucherte Paprika",
          "2 EL BBQ-Sauce light",
        ],
        steps: [
          "Wings trocken tupfen und mit allen Gewürzen massieren.",
          "Airfryer auf 200°C vorheizen.",
          "Wings 22 Min knusprig garen, einmal wenden.",
          "Mit BBQ-Sauce kurz bestreichen und 2 Min nachgaren.",
        ],
        tags: [.airfryer, .lowCarb, .postWorkout],
        servings: 2
      ),
      Recipe(
        id: UUID(uuidString: "20000002-0000-0000-0000-000000000002")!,
        title: "Airfryer Süßkartoffel Pommes",
        category: "Airfryer",
        goal: .abnehmen,
        dietaryStyle: .vegan,
        mealType: .snack,
        imageURL:
          "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "bolt.fill",
        prepMinutes: 22,
        calories: 248,
        protein: 4,
        carbs: 42,
        fat: 7,
        ingredients: [
          "400 g Süßkartoffel",
          "1 EL Olivenöl",
          "1 TL Paprika",
          "1/2 TL Salz",
          "Pfeffer",
        ],
        steps: [
          "Süßkartoffeln in dünne Sticks schneiden.",
          "Mit Öl und Gewürzen vermengen.",
          "Airfryer auf 200°C vorheizen, 18 Min garen.",
          "Nach 9 Min einmal schütteln.",
        ],
        tags: [.airfryer, .quick, .budget],
        servings: 2
      ),
      Recipe(
        id: UUID(uuidString: "20000002-0000-0000-0000-000000000003")!,
        title: "Airfryer Lachsfilet",
        category: "Airfryer",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .dinner,
        imageURL:
          "https://images.unsplash.com/photo-1485921325833-c519f76c4927?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "fish.fill",
        prepMinutes: 12,
        calories: 312,
        protein: 34,
        carbs: 1,
        fat: 19,
        ingredients: [
          "180 g Lachsfilet",
          "1 TL Olivenöl",
          "1/2 Zitrone",
          "Salz, Pfeffer",
          "Dill oder Petersilie",
        ],
        steps: [
          "Lachs trocken tupfen, mit Öl, Salz und Pfeffer würzen.",
          "Airfryer auf 180°C vorheizen.",
          "Lachs Hautseite oben 9 Min garen.",
          "Mit Zitrone und Kräutern servieren.",
        ],
        tags: [.airfryer, .quick, .lowCarb, .postWorkout],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "20000002-0000-0000-0000-000000000004")!,
        title: "Airfryer Halloumi Sticks",
        category: "Airfryer",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .snack,
        imageURL:
          "https://images.unsplash.com/photo-1626078299034-94d6c8f47fcc?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "square.grid.2x2.fill",
        prepMinutes: 12,
        calories: 286,
        protein: 22,
        carbs: 4,
        fat: 21,
        ingredients: [
          "200 g Halloumi",
          "1 TL Olivenöl",
          "1 TL Paprika edelsüß",
          "Honig oder Agavendicksaft (optional)",
          "Pfeffer",
        ],
        steps: [
          "Halloumi in fingerdicke Sticks schneiden.",
          "Mit Öl und Paprika vermengen.",
          "Airfryer auf 200°C, 8 Min knusprig garen.",
          "Mit Honig oder Pfeffer servieren.",
        ],
        tags: [.airfryer, .quick, .lowCarb],
        servings: 2
      ),
      Recipe(
        id: UUID(uuidString: "20000002-0000-0000-0000-000000000005")!,
        title: "Airfryer Garlic Shrimps",
        category: "Airfryer",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .dinner,
        imageURL:
          "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "drop.fill",
        prepMinutes: 10,
        calories: 224,
        protein: 31,
        carbs: 3,
        fat: 9,
        ingredients: [
          "250 g Garnelen geschält",
          "2 Knoblauchzehen gehackt",
          "1 EL Olivenöl",
          "1 TL Chiliflocken",
          "Petersilie, Zitrone",
        ],
        steps: [
          "Garnelen mit Knoblauch, Öl und Chili vermengen.",
          "Airfryer auf 200°C vorheizen.",
          "Garnelen 6–7 Min garen, einmal schütteln.",
          "Mit Petersilie und Zitrone servieren.",
        ],
        tags: [.airfryer, .quick, .lowCarb, .postWorkout],
        servings: 2
      ),
      Recipe(
        id: UUID(uuidString: "20000002-0000-0000-0000-000000000006")!,
        title: "Airfryer Crispy Tofu",
        category: "Airfryer",
        goal: .highProtein,
        dietaryStyle: .vegan,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1546549032-9571cd6b27df?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "cube.fill",
        prepMinutes: 22,
        calories: 248,
        protein: 24,
        carbs: 12,
        fat: 12,
        ingredients: [
          "300 g Tofu fest",
          "2 EL Sojasauce",
          "1 EL Maisstärke",
          "1 TL Sesamöl",
          "1 TL Paprika",
        ],
        steps: [
          "Tofu pressen, würfeln, mit Sojasauce marinieren.",
          "Mit Maisstärke und Gewürzen vermengen.",
          "Airfryer auf 200°C, 15 Min knusprig garen.",
          "Nach der Hälfte einmal schütteln.",
        ],
        tags: [.airfryer, .quick, .lowCarb],
        servings: 2
      ),
      Recipe(
        id: UUID(uuidString: "20000002-0000-0000-0000-000000000007")!,
        title: "Airfryer Knusperbrokkoli",
        category: "Airfryer",
        goal: .abnehmen,
        dietaryStyle: .vegan,
        mealType: .snack,
        imageURL:
          "https://images.unsplash.com/photo-1583663848850-46af132dc08e?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "leaf.fill",
        prepMinutes: 14,
        calories: 142,
        protein: 7,
        carbs: 14,
        fat: 7,
        ingredients: [
          "400 g Brokkoli",
          "1 EL Olivenöl",
          "1 TL Knoblauchpulver",
          "Salz, Pfeffer",
          "1 EL Hefeflocken",
        ],
        steps: [
          "Brokkoli in Röschen teilen.",
          "Mit Öl, Knoblauch und Salz vermengen.",
          "Airfryer auf 200°C, 11 Min knusprig garen.",
          "Mit Hefeflocken bestreuen.",
        ],
        tags: [.airfryer, .lowCarb, .quick, .budget],
        servings: 2
      ),
      Recipe(
        id: UUID(uuidString: "20000002-0000-0000-0000-000000000008")!,
        title: "Airfryer Chicken Nuggets High Protein",
        category: "Airfryer",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "circle.hexagonpath.fill",
        prepMinutes: 20,
        calories: 384,
        protein: 48,
        carbs: 18,
        fat: 12,
        ingredients: [
          "300 g Hähnchenbrust",
          "40 g Cornflakes ungesüßt",
          "1 Ei",
          "20 g Whey Natur",
          "Paprika, Knoblauch, Salz",
        ],
        steps: [
          "Hähnchen in Nuggets schneiden.",
          "Cornflakes mit Whey und Gewürzen mörsern.",
          "Nuggets durch Ei und Cornflakes-Mix wenden.",
          "Airfryer 12 Min bei 200°C, einmal wenden.",
        ],
        tags: [.airfryer, .postWorkout],
        servings: 2
      ),

      // MARK: - Schnelle Klassiker & Bonus

      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000001")!,
        title: "Protein Pizza Wrap",
        category: "Lunch",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "circle.fill",
        prepMinutes: 12,
        calories: 442,
        protein: 38,
        carbs: 36,
        fat: 16,
        ingredients: [
          "1 High-Protein Wrap",
          "60 g Tomatensauce",
          "100 g Light-Mozzarella",
          "60 g Hüttenkäse",
          "Basilikum, Oregano",
        ],
        steps: [
          "Wrap mit Sauce bestreichen.",
          "Hüttenkäse und Mozzarella darauf verteilen.",
          "Im Backofen oder Airfryer 8 Min bei 200°C knusprig backen.",
          "Mit Basilikum servieren.",
        ],
        tags: [.airfryer, .quick, .postWorkout],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000002")!,
        title: "High Protein Cottage Bowl",
        category: "Snack",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .snack,
        imageURL:
          "https://images.unsplash.com/photo-1565895405127-481853366cf8?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "bowl.fill",
        prepMinutes: 5,
        calories: 286,
        protein: 34,
        carbs: 14,
        fat: 9,
        ingredients: [
          "250 g Hüttenkäse",
          "100 g Cherrytomaten",
          "1/2 Avocado",
          "Pfeffer, Salz",
          "Frische Kräuter",
        ],
        steps: [
          "Hüttenkäse in eine Schale geben.",
          "Tomaten halbieren, Avocado würfeln.",
          "Würzen und mit Kräutern toppen.",
        ],
        tags: [.noCook, .quick, .lowCarb, .budget],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000003")!,
        title: "One Pan Garlic Beef Bowl",
        category: "Dinner",
        goal: .zunehmen,
        dietaryStyle: .omnivore,
        mealType: .dinner,
        imageURL:
          "https://images.unsplash.com/photo-1600891964092-4316c288032e?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "frying.pan.fill",
        prepMinutes: 18,
        calories: 612,
        protein: 44,
        carbs: 52,
        fat: 24,
        ingredients: [
          "200 g Rinderhack 10%",
          "180 g Reis gekocht",
          "2 Knoblauchzehen",
          "Sojasauce, Sesamöl",
          "150 g Pak Choi",
          "1 Frühlingszwiebel",
        ],
        steps: [
          "Hack mit Knoblauch in der Pfanne anbraten.",
          "Sojasauce und Sesamöl zugeben.",
          "Pak Choi kurz mitbraten.",
          "Über Reis anrichten, mit Frühlingszwiebel toppen.",
        ],
        tags: [.oneOnePan, .quick, .postWorkout],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000004")!,
        title: "Quark Power Pancakes Bulk",
        category: "Breakfast",
        goal: .zunehmen,
        dietaryStyle: .vegetarian,
        mealType: .breakfast,
        imageURL:
          "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "sun.max.fill",
        prepMinutes: 18,
        calories: 638,
        protein: 48,
        carbs: 72,
        fat: 16,
        ingredients: [
          "250 g Magerquark",
          "3 Eier",
          "100 g Haferflocken",
          "30 g Whey",
          "1 Banane",
          "30 g Erdnussmus",
        ],
        steps: [
          "Alle Zutaten außer Erdnussmus zu einem Teig pürieren.",
          "Pancakes portionsweise ausbacken.",
          "Mit Erdnussmus und Banane toppen.",
        ],
        tags: [.postWorkout, .quick],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000005")!,
        title: "Veggie Burrito Bowl",
        category: "Lunch",
        goal: .abnehmen,
        dietaryStyle: .vegan,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1543353071-873f17a7a088?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "leaf.circle.fill",
        prepMinutes: 15,
        calories: 468,
        protein: 22,
        carbs: 64,
        fat: 12,
        ingredients: [
          "150 g schwarze Bohnen aus der Dose",
          "120 g Reis gekocht",
          "1 Avocado",
          "100 g Mais",
          "Salsa, Limette",
          "Frischer Koriander",
        ],
        steps: [
          "Bohnen kurz mit Gewürzen erwärmen.",
          "Reis, Mais, Avocado und Bohnen in eine Bowl schichten.",
          "Mit Salsa, Limette und Koriander toppen.",
        ],
        tags: [.quick, .budget, .noCook],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000006")!,
        title: "Chia Pudding Vanille",
        category: "Breakfast",
        goal: .abnehmen,
        dietaryStyle: .vegan,
        mealType: .breakfast,
        imageURL:
          "https://images.unsplash.com/photo-1542691457-cbe4df041eb2?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "drop.circle.fill",
        prepMinutes: 5,
        calories: 312,
        protein: 18,
        carbs: 34,
        fat: 12,
        ingredients: [
          "30 g Chiasamen",
          "300 ml Mandelmilch",
          "20 g Vegan Protein Vanille",
          "1 TL Ahornsirup",
          "100 g Beeren",
        ],
        steps: [
          "Chiasamen mit Milch und Protein verrühren.",
          "Mind. 4 h oder über Nacht quellen lassen.",
          "Mit Beeren und Ahornsirup servieren.",
        ],
        tags: [.mealprep, .noCook, .quick],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000007")!,
        title: "Sheet Pan Chicken Veggies",
        category: "Dinner",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .dinner,
        imageURL:
          "https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "rectangle.fill",
        prepMinutes: 35,
        calories: 482,
        protein: 44,
        carbs: 32,
        fat: 18,
        ingredients: [
          "2 Hähnchenbrust à 180 g",
          "300 g Süßkartoffel",
          "1 Zucchini",
          "1 Paprika",
          "2 EL Olivenöl",
          "Italienische Kräuter, Knoblauch",
        ],
        steps: [
          "Gemüse und Hähnchen würfeln, mit Öl und Gewürzen marinieren.",
          "Auf Backblech verteilen.",
          "Im Ofen bei 200°C 25 Min backen.",
          "Direkt aus dem Ofen servieren oder als Mealprep.",
        ],
        tags: [.mealprep, .oneOnePan, .postWorkout, .lowCarb],
        servings: 2
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000008")!,
        title: "Pre-Workout Banana Toast",
        category: "Snack",
        goal: .zunehmen,
        dietaryStyle: .vegetarian,
        mealType: .snack,
        imageURL:
          "https://images.unsplash.com/photo-1588137378633-dea1336ce1e2?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "bolt.heart.fill",
        prepMinutes: 4,
        calories: 342,
        protein: 14,
        carbs: 48,
        fat: 12,
        ingredients: [
          "2 Scheiben Vollkorntoast",
          "1 Banane",
          "20 g Erdnussmus",
          "1 TL Honig",
          "Zimt",
        ],
        steps: [
          "Toast rösten und mit Erdnussmus bestreichen.",
          "Banane in Scheiben darauf verteilen.",
          "Mit Honig und Zimt finishen.",
        ],
        tags: [.quick, .noCook, .budget, .postWorkout],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000009")!,
        title: "Tuna White Bean Bowl",
        category: "Lunch",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "fish.fill",
        prepMinutes: 8,
        calories: 396,
        protein: 42,
        carbs: 36,
        fat: 8,
        ingredients: [
          "1 Dose Thunfisch im Wasser",
          "240 g weiße Bohnen aus der Dose",
          "100 g Cherrytomaten",
          "1/2 rote Zwiebel",
          "Zitronensaft, Olivenöl",
          "Petersilie",
        ],
        steps: [
          "Bohnen abspülen und in eine Schüssel geben.",
          "Thunfisch, Tomaten und Zwiebel zugeben.",
          "Mit Zitrone, Öl und Kräutern abschmecken.",
        ],
        tags: [.noCook, .quick, .budget, .lowCarb],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000010")!,
        title: "Skyr Protein Bowl To Go",
        category: "Breakfast",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .breakfast,
        imageURL:
          "https://images.unsplash.com/photo-1515003197210-e0cd71810b5f?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "bowl.fill",
        prepMinutes: 4,
        calories: 418,
        protein: 43,
        carbs: 39,
        fat: 9,
        ingredients: [
          "300 g Skyr",
          "30 g Vanille-Whey",
          "40 g Haferflocken",
          "100 g Beeren",
          "10 g Nussmus",
        ],
        steps: [
          "Skyr und Whey glatt verrühren.",
          "Haferflocken und Beeren unterheben.",
          "Mit etwas Nussmus toppen und direkt essen oder mitnehmen.",
        ],
        tags: [.quick, .noCook, .mealprep, .budget],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000011")!,
        title: "Chicken Couscous Mealprep",
        category: "Lunch",
        goal: .highProtein,
        dietaryStyle: .omnivore,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "shippingbox.fill",
        prepMinutes: 15,
        calories: 534,
        protein: 49,
        carbs: 47,
        fat: 15,
        ingredients: [
          "180 g Hähnchenbrust",
          "70 g Couscous",
          "150 g Gurke und Tomate",
          "80 g Joghurt light",
          "Zitronensaft, Salz, Pfeffer",
        ],
        steps: [
          "Hähnchen würzen und in der Pfanne anbraten.",
          "Couscous mit heißem Wasser quellen lassen.",
          "Alles mit Gemüse und Joghurt-Dressing in eine Box geben.",
        ],
        tags: [.mealprep, .quick, .budget, .postWorkout],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000012")!,
        title: "Egg Fried Rice Express",
        category: "Dinner",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .dinner,
        imageURL:
          "https://images.unsplash.com/photo-1603133872878-684f208fb84b?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "frying.pan.fill",
        prepMinutes: 12,
        calories: 562,
        protein: 33,
        carbs: 61,
        fat: 19,
        ingredients: [
          "250 g gekochter Reis",
          "3 Eier",
          "150 g Eiklar",
          "120 g Erbsen",
          "Sojasauce, Frühlingszwiebel",
        ],
        steps: [
          "Eier und Eiklar in der Pfanne stocken lassen.",
          "Reis und Erbsen zugeben und heiß anbraten.",
          "Mit Sojasauce und Frühlingszwiebel abschmecken.",
        ],
        tags: [.quick, .oneOnePan, .budget, .postWorkout],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000013")!,
        title: "Cottage Cheese Kartoffel Bowl",
        category: "Lunch",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .lunch,
        imageURL:
          "https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "leaf.fill",
        prepMinutes: 14,
        calories: 486,
        protein: 38,
        carbs: 49,
        fat: 14,
        ingredients: [
          "250 g Kartoffeln",
          "200 g körniger Frischkäse",
          "2 Eier",
          "100 g Gurke",
          "Schnittlauch, Salz, Pfeffer",
        ],
        steps: [
          "Kartoffeln in der Mikrowelle oder im Topf garen.",
          "Eier hart kochen und halbieren.",
          "Alles mit Gurke und körnigem Frischkäse in einer Bowl anrichten.",
        ],
        tags: [.quick, .budget, .mealprep, .postWorkout],
        servings: 1
      ),
      Recipe(
        id: UUID(uuidString: "30000003-0000-0000-0000-000000000014")!,
        title: "Protein Porridge Banane",
        category: "Breakfast",
        goal: .highProtein,
        dietaryStyle: .vegetarian,
        mealType: .breakfast,
        imageURL:
          "https://images.unsplash.com/photo-1517673400267-0251440c45dc?auto=format&fit=crop&w=1200&q=80",
        placeholderSymbol: "sun.max.fill",
        prepMinutes: 7,
        calories: 437,
        protein: 35,
        carbs: 53,
        fat: 9,
        ingredients: [
          "60 g Haferflocken",
          "250 ml Milch",
          "30 g Whey",
          "1 Banane",
          "Zimt",
        ],
        steps: [
          "Haferflocken mit Milch 3 bis 4 Minuten aufkochen.",
          "Kurz abkühlen lassen und Whey einrühren.",
          "Mit Banane und Zimt servieren.",
        ],
        tags: [.quick, .budget, .postWorkout, .mealprep],
        servings: 1
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
