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
      return "Laufen"
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
      hrZoneSecondsBuckets: [0, 0, 0, 0, 0]
    )
  }

  /// Frischer Quick-Run ohne Template — der Nutzer wählt im Pre-Run-Setup, was sein Ziel ist.
  static func freshQuickRun() -> ActiveRunSession {
    ActiveRunSession(
      id: UUID(),
      title: "Freier Lauf",
      routeName: "Freie Strecke",
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
      autoPauseEnabled: true,
      audioCuesEnabled: true,
      routeCoordinates: [],
      splits: [],
      hrZoneSecondsBuckets: [0, 0, 0, 0, 0]
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

// MARK: - Food Database

enum FoodCategory: String, CaseIterable, Identifiable {
  case protein
  case carbs
  case dairy
  case fruit
  case vegetable
  case fat
  case other

  var id: String { rawValue }

  var title: String {
    switch self {
    case .protein: return "Protein"
    case .carbs: return "Kohlenhydrate"
    case .dairy: return "Milchprodukte"
    case .fruit: return "Obst"
    case .vegetable: return "Gemüse"
    case .fat: return "Fette & Nüsse"
    case .other: return "Sonstiges"
    }
  }

  var systemImage: String {
    switch self {
    case .protein: return "fork.knife"
    case .carbs: return "circle.grid.2x2"
    case .dairy: return "drop.fill"
    case .fruit: return "leaf"
    case .vegetable: return "leaf.fill"
    case .fat: return "circle.fill"
    case .other: return "square.fill"
    }
  }
}

struct FoodItem: Identifiable {
  let id: UUID
  let name: String
  let brand: String?
  let emoji: String
  let caloriesPer100g: Int
  let proteinPer100g: Double
  let carbsPer100g: Double
  let fatPer100g: Double
  let category: FoodCategory

  init(
    name: String, brand: String? = nil, emoji: String, caloriesPer100g: Int,
    proteinPer100g: Double, carbsPer100g: Double, fatPer100g: Double,
    category: FoodCategory
  ) {
    self.id = UUID()
    self.name = name
    self.brand = brand
    self.emoji = emoji
    self.caloriesPer100g = caloriesPer100g
    self.proteinPer100g = proteinPer100g
    self.carbsPer100g = carbsPer100g
    self.fatPer100g = fatPer100g
    self.category = category
  }

  /// Voller Name inkl. Marke, z. B. „Barilla — Spaghetti n.5".
  var displayName: String {
    if let brand = brand, !brand.isEmpty {
      return "\(brand) — \(name)"
    }
    return name
  }

  /// Wahrheitswert ob ein Suchstring in Name oder Marke vorkommt.
  func matches(_ query: String) -> Bool {
    if name.localizedCaseInsensitiveContains(query) { return true }
    if let brand = brand, brand.localizedCaseInsensitiveContains(query) { return true }
    return false
  }

  func nutrition(for grams: Double) -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
    let f = grams / 100.0
    return (
      calories: Int((Double(caloriesPer100g) * f).rounded()),
      protein: Int((proteinPer100g * f).rounded()),
      carbs: Int((carbsPer100g * f).rounded()),
      fat: Int((fatPer100g * f).rounded())
    )
  }

  static let database: [FoodItem] = [
    // ===== PROTEIN — Geflügel =====
    FoodItem(name: "Hähnchenbrust", emoji: "🍗", caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6, category: .protein),
    FoodItem(name: "Hähnchenschenkel (mit Haut)", emoji: "🍗", caloriesPer100g: 211, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 15, category: .protein),
    FoodItem(name: "Hähnchen-Innenfilet", emoji: "🍗", caloriesPer100g: 110, proteinPer100g: 23, carbsPer100g: 0, fatPer100g: 1.5, category: .protein),
    FoodItem(name: "Putenbrust", emoji: "🍗", caloriesPer100g: 157, proteinPer100g: 30, carbsPer100g: 0, fatPer100g: 3.5, category: .protein),
    FoodItem(name: "Putenschnitzel", emoji: "🍗", caloriesPer100g: 105, proteinPer100g: 24, carbsPer100g: 0, fatPer100g: 1.0, category: .protein),
    FoodItem(name: "Entenbrust (mit Haut)", emoji: "🦆", caloriesPer100g: 337, proteinPer100g: 19, carbsPer100g: 0, fatPer100g: 28, category: .protein),

    // ===== PROTEIN — Rind =====
    FoodItem(name: "Rinderfilet", emoji: "🥩", caloriesPer100g: 158, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 7.5, category: .protein),
    FoodItem(name: "Rumpsteak", emoji: "🥩", caloriesPer100g: 188, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 9.0, category: .protein),
    FoodItem(name: "Rinderhackfleisch (mager, 5% Fett)", emoji: "🥩", caloriesPer100g: 137, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 5.0, category: .protein),
    FoodItem(name: "Rinderhackfleisch (15% Fett)", emoji: "🥩", caloriesPer100g: 215, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 12, category: .protein),
    FoodItem(name: "Tatar (mager)", emoji: "🥩", caloriesPer100g: 130, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 5.0, category: .protein),

    // ===== PROTEIN — Schwein =====
    FoodItem(name: "Schweinefilet", emoji: "🥩", caloriesPer100g: 110, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 2.0, category: .protein),
    FoodItem(name: "Schweineschnitzel", emoji: "🥩", caloriesPer100g: 145, proteinPer100g: 22, carbsPer100g: 0, fatPer100g: 5.0, category: .protein),
    FoodItem(name: "Schweinekotelett", emoji: "🥩", caloriesPer100g: 247, proteinPer100g: 23, carbsPer100g: 0, fatPer100g: 17, category: .protein),
    FoodItem(name: "Gemischtes Hack (Rind/Schwein)", emoji: "🥩", caloriesPer100g: 250, proteinPer100g: 19, carbsPer100g: 0, fatPer100g: 19, category: .protein),
    FoodItem(name: "Lammkotelett", emoji: "🥩", caloriesPer100g: 294, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 21, category: .protein),

    // ===== PROTEIN — Wurst & Aufschnitt =====
    FoodItem(name: "Putenbrust-Aufschnitt", emoji: "🥓", caloriesPer100g: 105, proteinPer100g: 21, carbsPer100g: 0.5, fatPer100g: 2.0, category: .protein),
    FoodItem(name: "Hähnchenbrust-Aufschnitt", emoji: "🥓", caloriesPer100g: 100, proteinPer100g: 22, carbsPer100g: 0.5, fatPer100g: 1.5, category: .protein),
    FoodItem(name: "Kochschinken", emoji: "🥓", caloriesPer100g: 117, proteinPer100g: 21, carbsPer100g: 0.7, fatPer100g: 3.5, category: .protein),
    FoodItem(name: "Serrano-Schinken", emoji: "🥓", caloriesPer100g: 241, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 13, category: .protein),
    FoodItem(name: "Salami", emoji: "🥓", caloriesPer100g: 378, proteinPer100g: 19, carbsPer100g: 1.0, fatPer100g: 33, category: .protein),
    FoodItem(name: "Bratwurst", emoji: "🌭", caloriesPer100g: 310, proteinPer100g: 13, carbsPer100g: 1.0, fatPer100g: 28, category: .protein),
    FoodItem(name: "Wiener Würstchen", emoji: "🌭", caloriesPer100g: 290, proteinPer100g: 13, carbsPer100g: 0.5, fatPer100g: 27, category: .protein),
    FoodItem(name: "Leberwurst", emoji: "🥓", caloriesPer100g: 326, proteinPer100g: 12, carbsPer100g: 1.0, fatPer100g: 30, category: .protein),
    FoodItem(name: "Mühlen-Schinken Spicker", brand: "Rügenwalder Mühle", emoji: "🥓", caloriesPer100g: 110, proteinPer100g: 21, carbsPer100g: 0.6, fatPer100g: 2.5, category: .protein),
    FoodItem(name: "Vegane Mühlen-Frikadellen", brand: "Rügenwalder Mühle", emoji: "🥩", caloriesPer100g: 199, proteinPer100g: 17, carbsPer100g: 6.0, fatPer100g: 11, category: .protein),

    // ===== PROTEIN — Fisch & Meeresfrüchte =====
    FoodItem(name: "Lachs (frisch)", emoji: "🐟", caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13, category: .protein),
    FoodItem(name: "Lachs (geräuchert)", emoji: "🐟", caloriesPer100g: 167, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 7.0, category: .protein),
    FoodItem(name: "Thunfisch (Dose, in Wasser)", emoji: "🐟", caloriesPer100g: 116, proteinPer100g: 26, carbsPer100g: 0, fatPer100g: 1.0, category: .protein),
    FoodItem(name: "Thunfisch (Dose, in Öl)", emoji: "🐟", caloriesPer100g: 198, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 11, category: .protein),
    FoodItem(name: "Forelle", emoji: "🐟", caloriesPer100g: 119, proteinPer100g: 21, carbsPer100g: 0, fatPer100g: 4.0, category: .protein),
    FoodItem(name: "Kabeljau", emoji: "🐟", caloriesPer100g: 82, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 0.7, category: .protein),
    FoodItem(name: "Seelachs (Filet)", emoji: "🐟", caloriesPer100g: 81, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 0.9, category: .protein),
    FoodItem(name: "Hering (in Tomatensauce)", emoji: "🐟", caloriesPer100g: 180, proteinPer100g: 14, carbsPer100g: 4.0, fatPer100g: 12, category: .protein),
    FoodItem(name: "Makrele (geräuchert)", emoji: "🐟", caloriesPer100g: 261, proteinPer100g: 21, carbsPer100g: 0, fatPer100g: 20, category: .protein),
    FoodItem(name: "Garnelen (gekocht)", emoji: "🦐", caloriesPer100g: 99, proteinPer100g: 24, carbsPer100g: 0, fatPer100g: 0.3, category: .protein),
    FoodItem(name: "Schlemmer-Filet Bordelaise", brand: "Iglo", emoji: "🐟", caloriesPer100g: 154, proteinPer100g: 12, carbsPer100g: 6.5, fatPer100g: 8.5, category: .protein),
    FoodItem(name: "Fischstäbchen", brand: "Iglo", emoji: "🐟", caloriesPer100g: 195, proteinPer100g: 12, carbsPer100g: 16, fatPer100g: 9.0, category: .protein),

    // ===== PROTEIN — Eier & Pflanzlich =====
    FoodItem(name: "Eier (1 Stück = 60g)", emoji: "🥚", caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11, category: .protein),
    FoodItem(name: "Eiweiß (Eiklar)", emoji: "🥚", caloriesPer100g: 52, proteinPer100g: 11, carbsPer100g: 0.7, fatPer100g: 0.2, category: .protein),
    FoodItem(name: "Tofu (natur)", emoji: "🧊", caloriesPer100g: 76, proteinPer100g: 8, carbsPer100g: 2.0, fatPer100g: 4.0, category: .protein),
    FoodItem(name: "Tofu (geräuchert)", emoji: "🧊", caloriesPer100g: 138, proteinPer100g: 16, carbsPer100g: 1.0, fatPer100g: 8.0, category: .protein),
    FoodItem(name: "Tempeh", emoji: "🧊", caloriesPer100g: 192, proteinPer100g: 19, carbsPer100g: 9.0, fatPer100g: 11, category: .protein),
    FoodItem(name: "Seitan", emoji: "🧊", caloriesPer100g: 141, proteinPer100g: 25, carbsPer100g: 7.0, fatPer100g: 1.5, category: .protein),
    FoodItem(name: "Kichererbsen (gekocht)", emoji: "🫘", caloriesPer100g: 164, proteinPer100g: 9, carbsPer100g: 27, fatPer100g: 2.6, category: .protein),
    FoodItem(name: "Linsen rot (gekocht)", emoji: "🫘", caloriesPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4, category: .protein),
    FoodItem(name: "Linsen braun (gekocht)", emoji: "🫘", caloriesPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4, category: .protein),
    FoodItem(name: "Kidneybohnen (Dose, abgetropft)", emoji: "🫘", caloriesPer100g: 127, proteinPer100g: 8.7, carbsPer100g: 22, fatPer100g: 0.5, category: .protein),
    FoodItem(name: "Schwarze Bohnen (gekocht)", emoji: "🫘", caloriesPer100g: 132, proteinPer100g: 8.9, carbsPer100g: 24, fatPer100g: 0.5, category: .protein),
    FoodItem(name: "Weiße Bohnen (gekocht)", emoji: "🫘", caloriesPer100g: 139, proteinPer100g: 9.7, carbsPer100g: 25, fatPer100g: 0.4, category: .protein),
    FoodItem(name: "Erbsen (tk)", emoji: "🫛", caloriesPer100g: 81, proteinPer100g: 5.0, carbsPer100g: 14, fatPer100g: 0.4, category: .protein),

    // ===== PROTEIN — Supplements =====
    FoodItem(name: "Whey Protein (Pulver)", emoji: "💪", caloriesPer100g: 380, proteinPer100g: 74, carbsPer100g: 8.0, fatPer100g: 5.0, category: .protein),
    FoodItem(name: "Casein (Pulver)", emoji: "💪", caloriesPer100g: 360, proteinPer100g: 80, carbsPer100g: 4.0, fatPer100g: 2.0, category: .protein),
    FoodItem(name: "Veganes Proteinpulver", emoji: "💪", caloriesPer100g: 370, proteinPer100g: 70, carbsPer100g: 8.0, fatPer100g: 6.0, category: .protein),
    FoodItem(name: "100% Whey Gold Standard (Vanille)", brand: "Optimum Nutrition", emoji: "💪", caloriesPer100g: 393, proteinPer100g: 80, carbsPer100g: 7.0, fatPer100g: 4.0, category: .protein),

    // ===== DAIRY — Milch =====
    FoodItem(name: "Vollmilch 3,5%", emoji: "🥛", caloriesPer100g: 65, proteinPer100g: 3.4, carbsPer100g: 4.8, fatPer100g: 3.6, category: .dairy),
    FoodItem(name: "Fettarme Milch 1,5%", emoji: "🥛", caloriesPer100g: 47, proteinPer100g: 3.5, carbsPer100g: 4.8, fatPer100g: 1.5, category: .dairy),
    FoodItem(name: "Magermilch 0,1%", emoji: "🥛", caloriesPer100g: 35, proteinPer100g: 3.5, carbsPer100g: 4.9, fatPer100g: 0.1, category: .dairy),
    FoodItem(name: "Hafermilch (ungesüßt)", emoji: "🥛", caloriesPer100g: 45, proteinPer100g: 1.0, carbsPer100g: 7.0, fatPer100g: 1.5, category: .dairy),
    FoodItem(name: "Hafer Drink Barista", brand: "Oatly", emoji: "🥛", caloriesPer100g: 60, proteinPer100g: 1.0, carbsPer100g: 7.0, fatPer100g: 3.0, category: .dairy),
    FoodItem(name: "Sojamilch (ungesüßt)", emoji: "🥛", caloriesPer100g: 33, proteinPer100g: 3.3, carbsPer100g: 0.2, fatPer100g: 1.8, category: .dairy),
    FoodItem(name: "Mandelmilch (ungesüßt)", emoji: "🥛", caloriesPer100g: 13, proteinPer100g: 0.4, carbsPer100g: 0.3, fatPer100g: 1.1, category: .dairy),
    FoodItem(name: "Sahne (Schlagsahne 30%)", emoji: "🥛", caloriesPer100g: 292, proteinPer100g: 2.4, carbsPer100g: 3.3, fatPer100g: 30, category: .dairy),
    FoodItem(name: "Crème fraîche (30%)", emoji: "🥛", caloriesPer100g: 299, proteinPer100g: 2.4, carbsPer100g: 2.5, fatPer100g: 30, category: .dairy),
    FoodItem(name: "Saure Sahne (10%)", emoji: "🥛", caloriesPer100g: 116, proteinPer100g: 2.9, carbsPer100g: 3.4, fatPer100g: 10, category: .dairy),
    FoodItem(name: "Buttermilch", emoji: "🥛", caloriesPer100g: 36, proteinPer100g: 3.4, carbsPer100g: 4.0, fatPer100g: 0.5, category: .dairy),

    // ===== DAIRY — Joghurt & Quark =====
    FoodItem(name: "Naturjoghurt (1,5%)", emoji: "🫙", caloriesPer100g: 47, proteinPer100g: 3.8, carbsPer100g: 4.7, fatPer100g: 1.5, category: .dairy),
    FoodItem(name: "Naturjoghurt (3,5%)", emoji: "🫙", caloriesPer100g: 61, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.5, category: .dairy),
    FoodItem(name: "Griechischer Joghurt 10%", emoji: "🫙", caloriesPer100g: 134, proteinPer100g: 6.6, carbsPer100g: 4.0, fatPer100g: 10, category: .dairy),
    FoodItem(name: "Griechischer Joghurt 0,2%", emoji: "🫙", caloriesPer100g: 57, proteinPer100g: 9.0, carbsPer100g: 4.0, fatPer100g: 0.2, category: .dairy),
    FoodItem(name: "Skyr (natur)", emoji: "🫙", caloriesPer100g: 64, proteinPer100g: 11, carbsPer100g: 4.0, fatPer100g: 0.2, category: .dairy),
    FoodItem(name: "Magerquark", emoji: "🥛", caloriesPer100g: 67, proteinPer100g: 12, carbsPer100g: 4.0, fatPer100g: 0.3, category: .dairy),
    FoodItem(name: "Speisequark 20%", emoji: "🥛", caloriesPer100g: 109, proteinPer100g: 12, carbsPer100g: 3.0, fatPer100g: 5.1, category: .dairy),
    FoodItem(name: "Speisequark 40%", emoji: "🥛", caloriesPer100g: 161, proteinPer100g: 11, carbsPer100g: 2.7, fatPer100g: 11, category: .dairy),
    FoodItem(name: "Joghurt mit der Ecke (Schoko-Crispies)", brand: "Müller", emoji: "🫙", caloriesPer100g: 138, proteinPer100g: 3.5, carbsPer100g: 17, fatPer100g: 6.0, category: .dairy),
    FoodItem(name: "Müllermilch (Schoko)", brand: "Müller", emoji: "🥛", caloriesPer100g: 88, proteinPer100g: 3.4, carbsPer100g: 13, fatPer100g: 1.8, category: .dairy),
    FoodItem(name: "Activia Naturjoghurt", brand: "Danone", emoji: "🫙", caloriesPer100g: 60, proteinPer100g: 4.0, carbsPer100g: 5.0, fatPer100g: 2.8, category: .dairy),
    FoodItem(name: "Skyr (natur)", brand: "Arla", emoji: "🫙", caloriesPer100g: 63, proteinPer100g: 11, carbsPer100g: 4.0, fatPer100g: 0.2, category: .dairy),
    FoodItem(name: "Skyr (Vanille)", brand: "Arla", emoji: "🫙", caloriesPer100g: 75, proteinPer100g: 9.5, carbsPer100g: 8.0, fatPer100g: 0.2, category: .dairy),
    FoodItem(name: "High Protein Pudding (Vanille)", brand: "Ehrmann", emoji: "🫙", caloriesPer100g: 73, proteinPer100g: 12, carbsPer100g: 5.0, fatPer100g: 0.5, category: .dairy),
    FoodItem(name: "High Protein Drink (Schoko)", brand: "Müller", emoji: "🥤", caloriesPer100g: 60, proteinPer100g: 10, carbsPer100g: 3.5, fatPer100g: 0.7, category: .dairy),
    FoodItem(name: "Almighurt (Erdbeere)", brand: "Ehrmann", emoji: "🫙", caloriesPer100g: 102, proteinPer100g: 2.9, carbsPer100g: 14, fatPer100g: 3.4, category: .dairy),
    FoodItem(name: "Soja-Joghurt natur", brand: "Alpro", emoji: "🫙", caloriesPer100g: 51, proteinPer100g: 4.0, carbsPer100g: 2.5, fatPer100g: 2.3, category: .dairy),
    FoodItem(name: "Magerquark", brand: "Ja!", emoji: "🥛", caloriesPer100g: 67, proteinPer100g: 12, carbsPer100g: 4.0, fatPer100g: 0.3, category: .dairy),
    FoodItem(name: "Naturjoghurt 3,5%", brand: "Ja!", emoji: "🫙", caloriesPer100g: 61, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.5, category: .dairy),
    FoodItem(name: "Vollmilch 3,5%", brand: "Ja!", emoji: "🥛", caloriesPer100g: 65, proteinPer100g: 3.4, carbsPer100g: 4.8, fatPer100g: 3.6, category: .dairy),

    // ===== DAIRY — Käse =====
    FoodItem(name: "Mozzarella", emoji: "🧀", caloriesPer100g: 280, proteinPer100g: 19, carbsPer100g: 2.2, fatPer100g: 22, category: .dairy),
    FoodItem(name: "Mozzarella light", emoji: "🧀", caloriesPer100g: 191, proteinPer100g: 20, carbsPer100g: 1.5, fatPer100g: 12, category: .dairy),
    FoodItem(name: "Feta", emoji: "🧀", caloriesPer100g: 264, proteinPer100g: 14, carbsPer100g: 4.1, fatPer100g: 21, category: .dairy),
    FoodItem(name: "Hirtenkäse (Schafskäse)", emoji: "🧀", caloriesPer100g: 264, proteinPer100g: 14, carbsPer100g: 4.0, fatPer100g: 21, category: .dairy),
    FoodItem(name: "Gouda jung (48% F.i.Tr.)", emoji: "🧀", caloriesPer100g: 356, proteinPer100g: 25, carbsPer100g: 0.3, fatPer100g: 28, category: .dairy),
    FoodItem(name: "Edamer", emoji: "🧀", caloriesPer100g: 334, proteinPer100g: 25, carbsPer100g: 0.4, fatPer100g: 26, category: .dairy),
    FoodItem(name: "Emmentaler", emoji: "🧀", caloriesPer100g: 380, proteinPer100g: 28, carbsPer100g: 0.4, fatPer100g: 29, category: .dairy),
    FoodItem(name: "Parmesan", emoji: "🧀", caloriesPer100g: 392, proteinPer100g: 36, carbsPer100g: 3.2, fatPer100g: 26, category: .dairy),
    FoodItem(name: "Cheddar", emoji: "🧀", caloriesPer100g: 410, proteinPer100g: 25, carbsPer100g: 1.3, fatPer100g: 34, category: .dairy),
    FoodItem(name: "Camembert (45%)", emoji: "🧀", caloriesPer100g: 290, proteinPer100g: 21, carbsPer100g: 0.4, fatPer100g: 23, category: .dairy),
    FoodItem(name: "Brie", emoji: "🧀", caloriesPer100g: 329, proteinPer100g: 21, carbsPer100g: 0.5, fatPer100g: 27, category: .dairy),
    FoodItem(name: "Frischkäse Doppelrahm", emoji: "🧀", caloriesPer100g: 317, proteinPer100g: 6.0, carbsPer100g: 3.0, fatPer100g: 31, category: .dairy),
    FoodItem(name: "Frischkäse light", emoji: "🧀", caloriesPer100g: 116, proteinPer100g: 12, carbsPer100g: 3.5, fatPer100g: 6.0, category: .dairy),
    FoodItem(name: "Hüttenkäse", emoji: "🧀", caloriesPer100g: 98, proteinPer100g: 11, carbsPer100g: 3.0, fatPer100g: 4.3, category: .dairy),
    FoodItem(name: "Halloumi", emoji: "🧀", caloriesPer100g: 321, proteinPer100g: 22, carbsPer100g: 2.2, fatPer100g: 25, category: .dairy),
    FoodItem(name: "Ziegenkäse (weich)", emoji: "🧀", caloriesPer100g: 268, proteinPer100g: 18, carbsPer100g: 0.9, fatPer100g: 21, category: .dairy),
    FoodItem(name: "Mozzarella di Bufala Campana", brand: "Galbani", emoji: "🧀", caloriesPer100g: 288, proteinPer100g: 17, carbsPer100g: 0.7, fatPer100g: 24, category: .dairy),
    FoodItem(name: "Mozzarella Classica", brand: "Galbani", emoji: "🧀", caloriesPer100g: 254, proteinPer100g: 18, carbsPer100g: 1.5, fatPer100g: 20, category: .dairy),
    FoodItem(name: "Mozzarella", brand: "Ja!", emoji: "🧀", caloriesPer100g: 246, proteinPer100g: 18, carbsPer100g: 1.5, fatPer100g: 19, category: .dairy),
    FoodItem(name: "Feta", brand: "Ja!", emoji: "🧀", caloriesPer100g: 247, proteinPer100g: 16, carbsPer100g: 1.0, fatPer100g: 20, category: .dairy),
    FoodItem(name: "Gouda", brand: "Ja!", emoji: "🧀", caloriesPer100g: 348, proteinPer100g: 25, carbsPer100g: 0, fatPer100g: 27, category: .dairy),
    FoodItem(name: "Frischkäse Klassik", brand: "Philadelphia", emoji: "🧀", caloriesPer100g: 253, proteinPer100g: 6.0, carbsPer100g: 4.0, fatPer100g: 24, category: .dairy),

    // ===== CARBS — Reis & Getreide =====
    FoodItem(name: "Basmati-Reis (gekocht)", emoji: "🍚", caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, category: .carbs),
    FoodItem(name: "Basmati-Reis (roh)", emoji: "🍚", caloriesPer100g: 351, proteinPer100g: 7.1, carbsPer100g: 78, fatPer100g: 0.7, category: .carbs),
    FoodItem(name: "Jasmin-Reis (gekocht)", emoji: "🍚", caloriesPer100g: 129, proteinPer100g: 2.9, carbsPer100g: 28, fatPer100g: 0.2, category: .carbs),
    FoodItem(name: "Vollkornreis (gekocht)", emoji: "🍚", caloriesPer100g: 123, proteinPer100g: 2.6, carbsPer100g: 25, fatPer100g: 1.0, category: .carbs),
    FoodItem(name: "Risotto-Reis (Arborio, roh)", emoji: "🍚", caloriesPer100g: 350, proteinPer100g: 7.0, carbsPer100g: 78, fatPer100g: 0.6, category: .carbs),
    FoodItem(name: "Wildreis (gekocht)", emoji: "🍚", caloriesPer100g: 101, proteinPer100g: 4.0, carbsPer100g: 21, fatPer100g: 0.3, category: .carbs),
    FoodItem(name: "Milchreis (zubereitet)", emoji: "🍚", caloriesPer100g: 122, proteinPer100g: 3.0, carbsPer100g: 21, fatPer100g: 2.5, category: .carbs),
    FoodItem(name: "Quinoa (gekocht)", emoji: "🌿", caloriesPer100g: 120, proteinPer100g: 4.4, carbsPer100g: 22, fatPer100g: 1.9, category: .carbs),
    FoodItem(name: "Couscous (gekocht)", emoji: "🌾", caloriesPer100g: 112, proteinPer100g: 3.8, carbsPer100g: 23, fatPer100g: 0.2, category: .carbs),
    FoodItem(name: "Bulgur (gekocht)", emoji: "🌾", caloriesPer100g: 83, proteinPer100g: 3.1, carbsPer100g: 19, fatPer100g: 0.2, category: .carbs),
    FoodItem(name: "Polenta (gekocht)", emoji: "🌽", caloriesPer100g: 70, proteinPer100g: 2.0, carbsPer100g: 15, fatPer100g: 0.5, category: .carbs),
    FoodItem(name: "Reiswaffeln", emoji: "🍘", caloriesPer100g: 387, proteinPer100g: 8.0, carbsPer100g: 82, fatPer100g: 3.0, category: .carbs),

    // ===== CARBS — Pasta =====
    FoodItem(name: "Spaghetti (gekocht)", emoji: "🍝", caloriesPer100g: 158, proteinPer100g: 5.8, carbsPer100g: 31, fatPer100g: 0.9, category: .carbs),
    FoodItem(name: "Vollkornnudeln (gekocht)", emoji: "🍝", caloriesPer100g: 124, proteinPer100g: 5.0, carbsPer100g: 24, fatPer100g: 1.0, category: .carbs),
    FoodItem(name: "Penne (roh)", emoji: "🍝", caloriesPer100g: 358, proteinPer100g: 13, carbsPer100g: 71, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Linsennudeln (rot, roh)", emoji: "🍝", caloriesPer100g: 348, proteinPer100g: 25, carbsPer100g: 49, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Reisnudeln (gekocht)", emoji: "🍜", caloriesPer100g: 109, proteinPer100g: 1.8, carbsPer100g: 24, fatPer100g: 0.2, category: .carbs),
    FoodItem(name: "Glasnudeln (gekocht)", emoji: "🍜", caloriesPer100g: 86, proteinPer100g: 0.1, carbsPer100g: 21, fatPer100g: 0.1, category: .carbs),
    FoodItem(name: "Gnocchi", emoji: "🥟", caloriesPer100g: 158, proteinPer100g: 4.0, carbsPer100g: 33, fatPer100g: 1.0, category: .carbs),
    FoodItem(name: "Ramen-Nudeln (Instant, zubereitet)", emoji: "🍜", caloriesPer100g: 188, proteinPer100g: 4.5, carbsPer100g: 27, fatPer100g: 7.0, category: .carbs),
    FoodItem(name: "Spaghetti n.5 (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 359, proteinPer100g: 13, carbsPer100g: 72, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Penne Rigate n.73 (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 359, proteinPer100g: 13, carbsPer100g: 72, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Fusilli n.98 (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 359, proteinPer100g: 13, carbsPer100g: 72, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Tagliatelle all'uovo (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 366, proteinPer100g: 14, carbsPer100g: 67, fatPer100g: 4.5, category: .carbs),
    FoodItem(name: "Vollkorn-Spaghetti (roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 339, proteinPer100g: 13, carbsPer100g: 64, fatPer100g: 2.5, category: .carbs),
    FoodItem(name: "Lasagne (Platten, roh)", brand: "Barilla", emoji: "🍝", caloriesPer100g: 357, proteinPer100g: 14, carbsPer100g: 71, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti (roh)", brand: "Buitoni", emoji: "🍝", caloriesPer100g: 359, proteinPer100g: 12, carbsPer100g: 73, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti (roh)", brand: "De Cecco", emoji: "🍝", caloriesPer100g: 353, proteinPer100g: 13, carbsPer100g: 71, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti (roh)", brand: "Combino (Lidl)", emoji: "🍝", caloriesPer100g: 358, proteinPer100g: 12, carbsPer100g: 72, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti (roh)", brand: "Ja!", emoji: "🍝", caloriesPer100g: 358, proteinPer100g: 12, carbsPer100g: 72, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Penne (roh)", brand: "Ja!", emoji: "🍝", caloriesPer100g: 358, proteinPer100g: 12, carbsPer100g: 72, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Spaghetti Hartweizen (roh)", brand: "Birkel", emoji: "🍝", caloriesPer100g: 354, proteinPer100g: 13, carbsPer100g: 70, fatPer100g: 1.5, category: .carbs),

    // ===== CARBS — Brot & Backwaren =====
    FoodItem(name: "Vollkornbrot", emoji: "🍞", caloriesPer100g: 247, proteinPer100g: 9.0, carbsPer100g: 41, fatPer100g: 3.0, category: .carbs),
    FoodItem(name: "Roggenbrot", emoji: "🍞", caloriesPer100g: 220, proteinPer100g: 7.0, carbsPer100g: 45, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Pumpernickel", emoji: "🍞", caloriesPer100g: 187, proteinPer100g: 6.0, carbsPer100g: 36, fatPer100g: 1.0, category: .carbs),
    FoodItem(name: "Toastbrot weiß", emoji: "🍞", caloriesPer100g: 270, proteinPer100g: 8.5, carbsPer100g: 50, fatPer100g: 3.5, category: .carbs),
    FoodItem(name: "Vollkorntoast", emoji: "🍞", caloriesPer100g: 245, proteinPer100g: 9.5, carbsPer100g: 40, fatPer100g: 4.0, category: .carbs),
    FoodItem(name: "Brötchen (Weizen)", emoji: "🥖", caloriesPer100g: 274, proteinPer100g: 9.0, carbsPer100g: 53, fatPer100g: 2.0, category: .carbs),
    FoodItem(name: "Croissant", emoji: "🥐", caloriesPer100g: 406, proteinPer100g: 8.2, carbsPer100g: 46, fatPer100g: 21, category: .carbs),
    FoodItem(name: "Bagel", emoji: "🥯", caloriesPer100g: 257, proteinPer100g: 10, carbsPer100g: 51, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Pita-Brot", emoji: "🥙", caloriesPer100g: 275, proteinPer100g: 9.0, carbsPer100g: 55, fatPer100g: 1.2, category: .carbs),
    FoodItem(name: "Tortilla Wrap (Weizen)", emoji: "🌯", caloriesPer100g: 312, proteinPer100g: 8.0, carbsPer100g: 50, fatPer100g: 8.5, category: .carbs),
    FoodItem(name: "Knäckebrot (Roggen)", emoji: "🍞", caloriesPer100g: 364, proteinPer100g: 11, carbsPer100g: 71, fatPer100g: 1.7, category: .carbs),
    FoodItem(name: "Mestemacher Vollkornbrot", brand: "Mestemacher", emoji: "🍞", caloriesPer100g: 198, proteinPer100g: 7.0, carbsPer100g: 35, fatPer100g: 2.5, category: .carbs),
    FoodItem(name: "Toast Klassisch", brand: "Golden Toast", emoji: "🍞", caloriesPer100g: 263, proteinPer100g: 8.6, carbsPer100g: 47, fatPer100g: 4.0, category: .carbs),
    FoodItem(name: "Vollkorn-Toast", brand: "Harry", emoji: "🍞", caloriesPer100g: 247, proteinPer100g: 9.5, carbsPer100g: 40, fatPer100g: 4.5, category: .carbs),

    // ===== CARBS — Müsli & Cerealien =====
    FoodItem(name: "Haferflocken (Vollkorn)", emoji: "🌾", caloriesPer100g: 372, proteinPer100g: 14, carbsPer100g: 59, fatPer100g: 7.0, category: .carbs),
    FoodItem(name: "Müsli (ungesüßt)", emoji: "🥣", caloriesPer100g: 360, proteinPer100g: 10, carbsPer100g: 65, fatPer100g: 6.0, category: .carbs),
    FoodItem(name: "Granola (Honig-Nuss)", emoji: "🥣", caloriesPer100g: 471, proteinPer100g: 11, carbsPer100g: 60, fatPer100g: 21, category: .carbs),
    FoodItem(name: "Cornflakes (ungesüßt)", emoji: "🥣", caloriesPer100g: 357, proteinPer100g: 7.5, carbsPer100g: 84, fatPer100g: 0.9, category: .carbs),
    FoodItem(name: "Cornflakes Original", brand: "Kellogg's", emoji: "🥣", caloriesPer100g: 378, proteinPer100g: 7.0, carbsPer100g: 84, fatPer100g: 0.9, category: .carbs),
    FoodItem(name: "Special K Original", brand: "Kellogg's", emoji: "🥣", caloriesPer100g: 376, proteinPer100g: 16, carbsPer100g: 75, fatPer100g: 1.5, category: .carbs),
    FoodItem(name: "Frosties", brand: "Kellogg's", emoji: "🥣", caloriesPer100g: 376, proteinPer100g: 5.0, carbsPer100g: 87, fatPer100g: 0.6, category: .carbs),
    FoodItem(name: "Choco Krispies", brand: "Kellogg's", emoji: "🥣", caloriesPer100g: 388, proteinPer100g: 4.8, carbsPer100g: 86, fatPer100g: 2.5, category: .carbs),
    FoodItem(name: "Knusper Schoko & Keks", brand: "Kölln", emoji: "🥣", caloriesPer100g: 444, proteinPer100g: 7.5, carbsPer100g: 67, fatPer100g: 15, category: .carbs),
    FoodItem(name: "Müsli Schoko & Keks", brand: "Kölln", emoji: "🥣", caloriesPer100g: 442, proteinPer100g: 7.5, carbsPer100g: 67, fatPer100g: 15, category: .carbs),
    FoodItem(name: "Haferflocken Zarte", brand: "Kölln", emoji: "🌾", caloriesPer100g: 369, proteinPer100g: 13, carbsPer100g: 59, fatPer100g: 7.0, category: .carbs),
    FoodItem(name: "Vitalis Knuspermüsli Schoko", brand: "Dr. Oetker", emoji: "🥣", caloriesPer100g: 451, proteinPer100g: 7.5, carbsPer100g: 65, fatPer100g: 17, category: .carbs),

    // ===== CARBS — Kartoffel & Beilagen =====
    FoodItem(name: "Kartoffeln (gekocht)", emoji: "🥔", caloriesPer100g: 86, proteinPer100g: 2.0, carbsPer100g: 20, fatPer100g: 0.1, category: .carbs),
    FoodItem(name: "Süßkartoffel (gekocht)", emoji: "🍠", caloriesPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1, category: .carbs),
    FoodItem(name: "Bratkartoffeln (mit Öl)", emoji: "🥔", caloriesPer100g: 168, proteinPer100g: 2.5, carbsPer100g: 21, fatPer100g: 8.0, category: .carbs),
    FoodItem(name: "Pommes Frites (frittiert)", emoji: "🍟", caloriesPer100g: 312, proteinPer100g: 3.4, carbsPer100g: 41, fatPer100g: 15, category: .carbs),
    FoodItem(name: "Pommes Frites (Backofen)", emoji: "🍟", caloriesPer100g: 175, proteinPer100g: 3.0, carbsPer100g: 27, fatPer100g: 6.0, category: .carbs),
    FoodItem(name: "Kroketten", emoji: "🍟", caloriesPer100g: 220, proteinPer100g: 3.5, carbsPer100g: 25, fatPer100g: 12, category: .carbs),
    FoodItem(name: "Kartoffelpüree (zubereitet)", emoji: "🥔", caloriesPer100g: 88, proteinPer100g: 2.0, carbsPer100g: 14, fatPer100g: 3.0, category: .carbs),

    // ===== FRUIT =====
    FoodItem(name: "Banane", emoji: "🍌", caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Apfel", emoji: "🍎", caloriesPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Birne", emoji: "🍐", caloriesPer100g: 57, proteinPer100g: 0.4, carbsPer100g: 15, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Orange", emoji: "🍊", caloriesPer100g: 47, proteinPer100g: 0.9, carbsPer100g: 12, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Mandarine / Clementine", emoji: "🍊", caloriesPer100g: 53, proteinPer100g: 0.8, carbsPer100g: 13, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Zitrone", emoji: "🍋", caloriesPer100g: 29, proteinPer100g: 1.1, carbsPer100g: 9.0, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Grapefruit", emoji: "🍊", caloriesPer100g: 42, proteinPer100g: 0.8, carbsPer100g: 11, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Erdbeeren", emoji: "🍓", caloriesPer100g: 32, proteinPer100g: 0.7, carbsPer100g: 8.0, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Himbeeren", emoji: "🍓", caloriesPer100g: 52, proteinPer100g: 1.2, carbsPer100g: 12, fatPer100g: 0.7, category: .fruit),
    FoodItem(name: "Heidelbeeren", emoji: "🫐", caloriesPer100g: 57, proteinPer100g: 0.7, carbsPer100g: 14, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Brombeeren", emoji: "🫐", caloriesPer100g: 43, proteinPer100g: 1.4, carbsPer100g: 10, fatPer100g: 0.5, category: .fruit),
    FoodItem(name: "Johannisbeeren (rot)", emoji: "🍒", caloriesPer100g: 56, proteinPer100g: 1.4, carbsPer100g: 14, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Kirschen (süß)", emoji: "🍒", caloriesPer100g: 63, proteinPer100g: 1.1, carbsPer100g: 16, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Pflaumen", emoji: "🍑", caloriesPer100g: 46, proteinPer100g: 0.7, carbsPer100g: 11, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Pfirsich", emoji: "🍑", caloriesPer100g: 39, proteinPer100g: 0.9, carbsPer100g: 10, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Nektarine", emoji: "🍑", caloriesPer100g: 44, proteinPer100g: 1.1, carbsPer100g: 11, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Aprikose", emoji: "🍑", caloriesPer100g: 48, proteinPer100g: 1.4, carbsPer100g: 11, fatPer100g: 0.4, category: .fruit),
    FoodItem(name: "Ananas (frisch)", emoji: "🍍", caloriesPer100g: 50, proteinPer100g: 0.5, carbsPer100g: 13, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Mango", emoji: "🥭", caloriesPer100g: 60, proteinPer100g: 0.8, carbsPer100g: 15, fatPer100g: 0.4, category: .fruit),
    FoodItem(name: "Papaya", emoji: "🥭", caloriesPer100g: 43, proteinPer100g: 0.5, carbsPer100g: 11, fatPer100g: 0.3, category: .fruit),
    FoodItem(name: "Wassermelone", emoji: "🍉", caloriesPer100g: 30, proteinPer100g: 0.6, carbsPer100g: 8.0, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Honigmelone", emoji: "🍈", caloriesPer100g: 36, proteinPer100g: 0.5, carbsPer100g: 9.0, fatPer100g: 0.1, category: .fruit),
    FoodItem(name: "Kiwi", emoji: "🥝", caloriesPer100g: 61, proteinPer100g: 1.1, carbsPer100g: 15, fatPer100g: 0.5, category: .fruit),
    FoodItem(name: "Trauben (hell)", emoji: "🍇", caloriesPer100g: 69, proteinPer100g: 0.6, carbsPer100g: 18, fatPer100g: 0.2, category: .fruit),
    FoodItem(name: "Granatapfel (Kerne)", emoji: "🌰", caloriesPer100g: 83, proteinPer100g: 1.7, carbsPer100g: 19, fatPer100g: 1.2, category: .fruit),
    FoodItem(name: "Datteln (getrocknet)", emoji: "🌴", caloriesPer100g: 282, proteinPer100g: 2.5, carbsPer100g: 75, fatPer100g: 0.4, category: .fruit),
    FoodItem(name: "Rosinen", emoji: "🍇", caloriesPer100g: 299, proteinPer100g: 3.1, carbsPer100g: 79, fatPer100g: 0.5, category: .fruit),
    FoodItem(name: "Trockenpflaumen", emoji: "🍑", caloriesPer100g: 240, proteinPer100g: 2.2, carbsPer100g: 64, fatPer100g: 0.4, category: .fruit),

    // ===== VEGETABLE — Kohl & Salat =====
    FoodItem(name: "Brokkoli", emoji: "🥦", caloriesPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 7.0, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Blumenkohl", emoji: "🥦", caloriesPer100g: 25, proteinPer100g: 1.9, carbsPer100g: 5.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Romanesco", emoji: "🥦", caloriesPer100g: 29, proteinPer100g: 2.5, carbsPer100g: 5.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Spinat (frisch)", emoji: "🥬", caloriesPer100g: 23, proteinPer100g: 2.9, carbsPer100g: 3.6, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Grünkohl", emoji: "🥬", caloriesPer100g: 49, proteinPer100g: 4.3, carbsPer100g: 9.0, fatPer100g: 0.9, category: .vegetable),
    FoodItem(name: "Weißkohl", emoji: "🥬", caloriesPer100g: 25, proteinPer100g: 1.3, carbsPer100g: 6.0, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Rotkohl", emoji: "🥬", caloriesPer100g: 31, proteinPer100g: 1.4, carbsPer100g: 7.0, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Sauerkraut", emoji: "🥬", caloriesPer100g: 19, proteinPer100g: 0.9, carbsPer100g: 4.3, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Pak Choi", emoji: "🥬", caloriesPer100g: 13, proteinPer100g: 1.5, carbsPer100g: 2.2, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Rucola", emoji: "🥬", caloriesPer100g: 25, proteinPer100g: 2.6, carbsPer100g: 3.7, fatPer100g: 0.7, category: .vegetable),
    FoodItem(name: "Eisbergsalat", emoji: "🥗", caloriesPer100g: 14, proteinPer100g: 0.9, carbsPer100g: 3.0, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Feldsalat", emoji: "🥗", caloriesPer100g: 14, proteinPer100g: 1.8, carbsPer100g: 0.7, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Kopfsalat", emoji: "🥗", caloriesPer100g: 13, proteinPer100g: 1.4, carbsPer100g: 1.1, fatPer100g: 0.2, category: .vegetable),

    // ===== VEGETABLE — Tomaten & Paprika =====
    FoodItem(name: "Tomaten (frisch)", emoji: "🍅", caloriesPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Cherrytomaten", emoji: "🍅", caloriesPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Tomaten (passiert)", emoji: "🍅", caloriesPer100g: 32, proteinPer100g: 1.4, carbsPer100g: 6.0, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Tomaten (gehackt, Dose)", emoji: "🍅", caloriesPer100g: 32, proteinPer100g: 1.5, carbsPer100g: 5.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Tomatenmark (3-fach konzentriert)", emoji: "🍅", caloriesPer100g: 95, proteinPer100g: 4.8, carbsPer100g: 16, fatPer100g: 0.6, category: .vegetable),
    FoodItem(name: "Paprika rot", emoji: "🫑", caloriesPer100g: 31, proteinPer100g: 1.0, carbsPer100g: 7.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Paprika gelb", emoji: "🫑", caloriesPer100g: 27, proteinPer100g: 1.0, carbsPer100g: 6.3, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Paprika grün", emoji: "🫑", caloriesPer100g: 20, proteinPer100g: 0.9, carbsPer100g: 4.6, fatPer100g: 0.2, category: .vegetable),

    // ===== VEGETABLE — Diverse =====
    FoodItem(name: "Gurke", emoji: "🥒", caloriesPer100g: 15, proteinPer100g: 0.7, carbsPer100g: 3.6, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Zucchini", emoji: "🥒", caloriesPer100g: 17, proteinPer100g: 1.2, carbsPer100g: 3.1, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Aubergine", emoji: "🍆", caloriesPer100g: 25, proteinPer100g: 1.0, carbsPer100g: 6.0, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Champignons (frisch)", emoji: "🍄", caloriesPer100g: 22, proteinPer100g: 3.1, carbsPer100g: 3.3, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Kräuterseitlinge", emoji: "🍄", caloriesPer100g: 33, proteinPer100g: 3.3, carbsPer100g: 6.0, fatPer100g: 0.5, category: .vegetable),
    FoodItem(name: "Zwiebel", emoji: "🧅", caloriesPer100g: 40, proteinPer100g: 1.1, carbsPer100g: 9.3, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Lauch", emoji: "🥬", caloriesPer100g: 31, proteinPer100g: 1.5, carbsPer100g: 7.0, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Knoblauch", emoji: "🧄", caloriesPer100g: 149, proteinPer100g: 6.4, carbsPer100g: 33, fatPer100g: 0.5, category: .vegetable),
    FoodItem(name: "Frühlingszwiebel", emoji: "🧅", caloriesPer100g: 32, proteinPer100g: 1.8, carbsPer100g: 7.0, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Karotten", emoji: "🥕", caloriesPer100g: 41, proteinPer100g: 0.9, carbsPer100g: 10, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Sellerie (Knolle)", emoji: "🥬", caloriesPer100g: 21, proteinPer100g: 1.5, carbsPer100g: 2.3, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Kohlrabi", emoji: "🥬", caloriesPer100g: 27, proteinPer100g: 1.7, carbsPer100g: 6.2, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Rote Bete (vorgekocht)", emoji: "🥬", caloriesPer100g: 43, proteinPer100g: 1.6, carbsPer100g: 9.6, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Pastinaken", emoji: "🥕", caloriesPer100g: 75, proteinPer100g: 1.2, carbsPer100g: 18, fatPer100g: 0.3, category: .vegetable),
    FoodItem(name: "Hokkaido-Kürbis", emoji: "🎃", caloriesPer100g: 63, proteinPer100g: 1.7, carbsPer100g: 12, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Spargel weiß", emoji: "🌱", caloriesPer100g: 18, proteinPer100g: 1.9, carbsPer100g: 1.7, fatPer100g: 0.2, category: .vegetable),
    FoodItem(name: "Spargel grün", emoji: "🌱", caloriesPer100g: 22, proteinPer100g: 2.4, carbsPer100g: 2.1, fatPer100g: 0.4, category: .vegetable),
    FoodItem(name: "Mais (Dose, abgetropft)", emoji: "🌽", caloriesPer100g: 86, proteinPer100g: 3.3, carbsPer100g: 16, fatPer100g: 1.4, category: .vegetable),
    FoodItem(name: "Grüne Bohnen (tk)", emoji: "🫛", caloriesPer100g: 31, proteinPer100g: 1.8, carbsPer100g: 7.0, fatPer100g: 0.1, category: .vegetable),
    FoodItem(name: "Rahm-Spinat", brand: "Iglo", emoji: "🥬", caloriesPer100g: 78, proteinPer100g: 3.5, carbsPer100g: 4.0, fatPer100g: 5.0, category: .vegetable),
    FoodItem(name: "Erbsen (tk)", brand: "Iglo", emoji: "🫛", caloriesPer100g: 69, proteinPer100g: 5.4, carbsPer100g: 8.5, fatPer100g: 0.7, category: .vegetable),
    FoodItem(name: "Wok-Gemüse Asia-Mix (tk)", brand: "Iglo", emoji: "🥦", caloriesPer100g: 35, proteinPer100g: 2.0, carbsPer100g: 5.0, fatPer100g: 0.5, category: .vegetable),
    FoodItem(name: "Mais (Dose)", brand: "Bonduelle", emoji: "🌽", caloriesPer100g: 86, proteinPer100g: 3.0, carbsPer100g: 15, fatPer100g: 1.5, category: .vegetable),

    // ===== FAT — Öle, Butter, Avocado =====
    FoodItem(name: "Avocado", emoji: "🥑", caloriesPer100g: 160, proteinPer100g: 2.0, carbsPer100g: 9.0, fatPer100g: 15, category: .fat),
    FoodItem(name: "Olivenöl (extra vergine)", emoji: "🫒", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Rapsöl", emoji: "🫗", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Sonnenblumenöl", emoji: "🫗", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Kokosöl", emoji: "🥥", caloriesPer100g: 862, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Leinöl", emoji: "🫗", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Sesamöl", emoji: "🫗", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, category: .fat),
    FoodItem(name: "Butter", emoji: "🧈", caloriesPer100g: 717, proteinPer100g: 0.9, carbsPer100g: 0.7, fatPer100g: 81, category: .fat),
    FoodItem(name: "Margarine", emoji: "🧈", caloriesPer100g: 720, proteinPer100g: 0.2, carbsPer100g: 0.4, fatPer100g: 80, category: .fat),
    FoodItem(name: "Lätta Halbfettmargarine", brand: "Lätta", emoji: "🧈", caloriesPer100g: 357, proteinPer100g: 0.4, carbsPer100g: 0.5, fatPer100g: 39, category: .fat),
    FoodItem(name: "Irische Butter", brand: "Kerrygold", emoji: "🧈", caloriesPer100g: 745, proteinPer100g: 0.7, carbsPer100g: 0.6, fatPer100g: 82, category: .fat),

    // ===== FAT — Nüsse & Samen =====
    FoodItem(name: "Mandeln", emoji: "🌰", caloriesPer100g: 579, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 50, category: .fat),
    FoodItem(name: "Walnüsse", emoji: "🌰", caloriesPer100g: 654, proteinPer100g: 15, carbsPer100g: 14, fatPer100g: 65, category: .fat),
    FoodItem(name: "Cashews", emoji: "🌰", caloriesPer100g: 553, proteinPer100g: 18, carbsPer100g: 30, fatPer100g: 44, category: .fat),
    FoodItem(name: "Haselnüsse", emoji: "🌰", caloriesPer100g: 628, proteinPer100g: 15, carbsPer100g: 17, fatPer100g: 61, category: .fat),
    FoodItem(name: "Pistazien (geschält)", emoji: "🌰", caloriesPer100g: 562, proteinPer100g: 20, carbsPer100g: 28, fatPer100g: 45, category: .fat),
    FoodItem(name: "Paranüsse", emoji: "🌰", caloriesPer100g: 656, proteinPer100g: 14, carbsPer100g: 12, fatPer100g: 66, category: .fat),
    FoodItem(name: "Macadamia-Nüsse", emoji: "🌰", caloriesPer100g: 718, proteinPer100g: 8.0, carbsPer100g: 14, fatPer100g: 76, category: .fat),
    FoodItem(name: "Pekannüsse", emoji: "🌰", caloriesPer100g: 691, proteinPer100g: 9.2, carbsPer100g: 14, fatPer100g: 72, category: .fat),
    FoodItem(name: "Pinienkerne", emoji: "🌰", caloriesPer100g: 673, proteinPer100g: 14, carbsPer100g: 13, fatPer100g: 68, category: .fat),
    FoodItem(name: "Erdnüsse (geröstet, ungesalzen)", emoji: "🥜", caloriesPer100g: 599, proteinPer100g: 26, carbsPer100g: 16, fatPer100g: 49, category: .fat),
    FoodItem(name: "Sonnenblumenkerne", emoji: "🌻", caloriesPer100g: 584, proteinPer100g: 21, carbsPer100g: 20, fatPer100g: 51, category: .fat),
    FoodItem(name: "Kürbiskerne", emoji: "🎃", caloriesPer100g: 559, proteinPer100g: 30, carbsPer100g: 11, fatPer100g: 49, category: .fat),
    FoodItem(name: "Sesam", emoji: "🌰", caloriesPer100g: 573, proteinPer100g: 18, carbsPer100g: 23, fatPer100g: 50, category: .fat),
    FoodItem(name: "Leinsamen (geschrotet)", emoji: "🌾", caloriesPer100g: 534, proteinPer100g: 18, carbsPer100g: 29, fatPer100g: 42, category: .fat),
    FoodItem(name: "Chiasamen", emoji: "🌾", caloriesPer100g: 486, proteinPer100g: 17, carbsPer100g: 42, fatPer100g: 31, category: .fat),
    FoodItem(name: "Erdnussbutter (creamy)", emoji: "🥜", caloriesPer100g: 588, proteinPer100g: 25, carbsPer100g: 20, fatPer100g: 50, category: .fat),
    FoodItem(name: "Mandelmus", emoji: "🌰", caloriesPer100g: 614, proteinPer100g: 21, carbsPer100g: 19, fatPer100g: 56, category: .fat),
    FoodItem(name: "Tahini (Sesammus)", emoji: "🌰", caloriesPer100g: 595, proteinPer100g: 17, carbsPer100g: 21, fatPer100g: 54, category: .fat),

    // ===== OTHER — Schokolade & Süßes =====
    FoodItem(name: "Dunkle Schokolade (85%)", emoji: "🍫", caloriesPer100g: 600, proteinPer100g: 8, carbsPer100g: 24, fatPer100g: 43, category: .other),
    FoodItem(name: "Vollmilchschokolade", emoji: "🍫", caloriesPer100g: 535, proteinPer100g: 7.7, carbsPer100g: 59, fatPer100g: 30, category: .other),
    FoodItem(name: "Alpenmilch Schokolade", brand: "Milka", emoji: "🍫", caloriesPer100g: 534, proteinPer100g: 6.6, carbsPer100g: 58, fatPer100g: 30, category: .other),
    FoodItem(name: "Milka Oreo", brand: "Milka", emoji: "🍫", caloriesPer100g: 525, proteinPer100g: 5.6, carbsPer100g: 60, fatPer100g: 28, category: .other),
    FoodItem(name: "Excellence 70% Cacao", brand: "Lindt", emoji: "🍫", caloriesPer100g: 569, proteinPer100g: 9.3, carbsPer100g: 34, fatPer100g: 41, category: .other),
    FoodItem(name: "Excellence 85% Cacao", brand: "Lindt", emoji: "🍫", caloriesPer100g: 580, proteinPer100g: 11, carbsPer100g: 22, fatPer100g: 46, category: .other),
    FoodItem(name: "Vollmilch", brand: "Ritter Sport", emoji: "🍫", caloriesPer100g: 560, proteinPer100g: 7.0, carbsPer100g: 53, fatPer100g: 34, category: .other),
    FoodItem(name: "Knusperflakes", brand: "Ritter Sport", emoji: "🍫", caloriesPer100g: 545, proteinPer100g: 6.5, carbsPer100g: 56, fatPer100g: 32, category: .other),
    FoodItem(name: "Marzipan", brand: "Ritter Sport", emoji: "🍫", caloriesPer100g: 470, proteinPer100g: 8.5, carbsPer100g: 51, fatPer100g: 26, category: .other),
    FoodItem(name: "Bueno", brand: "Kinder", emoji: "🍫", caloriesPer100g: 569, proteinPer100g: 8.7, carbsPer100g: 50, fatPer100g: 36, category: .other),
    FoodItem(name: "Schokolade Riegel", brand: "Kinder", emoji: "🍫", caloriesPer100g: 562, proteinPer100g: 8.0, carbsPer100g: 53, fatPer100g: 34, category: .other),
    FoodItem(name: "Snickers", brand: "Mars", emoji: "🍫", caloriesPer100g: 488, proteinPer100g: 8.5, carbsPer100g: 55, fatPer100g: 24, category: .other),
    FoodItem(name: "Mars", brand: "Mars", emoji: "🍫", caloriesPer100g: 449, proteinPer100g: 4.0, carbsPer100g: 70, fatPer100g: 16, category: .other),
    FoodItem(name: "Twix", brand: "Mars", emoji: "🍫", caloriesPer100g: 491, proteinPer100g: 4.7, carbsPer100g: 64, fatPer100g: 24, category: .other),
    FoodItem(name: "Bounty", brand: "Mars", emoji: "🍫", caloriesPer100g: 481, proteinPer100g: 4.0, carbsPer100g: 58, fatPer100g: 26, category: .other),
    FoodItem(name: "Goldbären", brand: "Haribo", emoji: "🐻", caloriesPer100g: 343, proteinPer100g: 6.9, carbsPer100g: 77, fatPer100g: 0.5, category: .other),
    FoodItem(name: "Color-Rado", brand: "Haribo", emoji: "🍬", caloriesPer100g: 351, proteinPer100g: 5.5, carbsPer100g: 78, fatPer100g: 1.0, category: .other),
    FoodItem(name: "M&M's Peanut", brand: "Mars", emoji: "🍬", caloriesPer100g: 535, proteinPer100g: 9.4, carbsPer100g: 56, fatPer100g: 30, category: .other),
    FoodItem(name: "Nutella", brand: "Ferrero", emoji: "🍫", caloriesPer100g: 539, proteinPer100g: 6.3, carbsPer100g: 57, fatPer100g: 31, category: .other),
    FoodItem(name: "Honig (Blütenhonig)", emoji: "🍯", caloriesPer100g: 304, proteinPer100g: 0.3, carbsPer100g: 82, fatPer100g: 0, category: .other),
    FoodItem(name: "Marmelade Erdbeere", emoji: "🫙", caloriesPer100g: 240, proteinPer100g: 0.4, carbsPer100g: 60, fatPer100g: 0.1, category: .other),
    FoodItem(name: "Kristallzucker", emoji: "🍬", caloriesPer100g: 400, proteinPer100g: 0, carbsPer100g: 100, fatPer100g: 0, category: .other),

    // ===== OTHER — Snacks =====
    FoodItem(name: "Salzstangen", emoji: "🥨", caloriesPer100g: 379, proteinPer100g: 11, carbsPer100g: 79, fatPer100g: 1.5, category: .other),
    FoodItem(name: "Chipsfrisch ungarisch", brand: "funny-frisch", emoji: "🍟", caloriesPer100g: 533, proteinPer100g: 6.0, carbsPer100g: 51, fatPer100g: 33, category: .other),
    FoodItem(name: "Chips Paprika", brand: "Lay's", emoji: "🍟", caloriesPer100g: 525, proteinPer100g: 6.0, carbsPer100g: 53, fatPer100g: 31, category: .other),
    FoodItem(name: "Pringles Original", brand: "Pringles", emoji: "🍟", caloriesPer100g: 536, proteinPer100g: 4.0, carbsPer100g: 50, fatPer100g: 35, category: .other),
    FoodItem(name: "Butterkeks", brand: "Leibniz", emoji: "🍪", caloriesPer100g: 432, proteinPer100g: 7.0, carbsPer100g: 73, fatPer100g: 12, category: .other),
    FoodItem(name: "Oreo Original", brand: "Oreo", emoji: "🍪", caloriesPer100g: 480, proteinPer100g: 5.0, carbsPer100g: 70, fatPer100g: 20, category: .other),
    FoodItem(name: "Müsliriegel Schoko", brand: "Corny", emoji: "🍫", caloriesPer100g: 419, proteinPer100g: 6.0, carbsPer100g: 70, fatPer100g: 12, category: .other),
    FoodItem(name: "Magnum Classic (1 Stück = 79g)", brand: "Magnum", emoji: "🍦", caloriesPer100g: 282, proteinPer100g: 3.7, carbsPer100g: 28, fatPer100g: 17, category: .other),
    FoodItem(name: "Cookie Dough", brand: "Ben & Jerry's", emoji: "🍨", caloriesPer100g: 264, proteinPer100g: 4.0, carbsPer100g: 33, fatPer100g: 13, category: .other),

    // ===== OTHER — Fertiggerichte & Sonstiges =====
    FoodItem(name: "Pizza Margherita (Backofen)", emoji: "🍕", caloriesPer100g: 252, proteinPer100g: 11, carbsPer100g: 30, fatPer100g: 9.0, category: .other),
    FoodItem(name: "Pizza Salami (Backofen)", emoji: "🍕", caloriesPer100g: 285, proteinPer100g: 12, carbsPer100g: 28, fatPer100g: 14, category: .other),
    FoodItem(name: "Ristorante Pizza Funghi", brand: "Dr. Oetker", emoji: "🍕", caloriesPer100g: 230, proteinPer100g: 9.0, carbsPer100g: 27, fatPer100g: 9.5, category: .other),
    FoodItem(name: "Steinofen-Pizza Salami", brand: "Wagner", emoji: "🍕", caloriesPer100g: 264, proteinPer100g: 11, carbsPer100g: 30, fatPer100g: 11, category: .other),
    FoodItem(name: "5-Minuten Terrine Spaghetti", brand: "Maggi", emoji: "🍜", caloriesPer100g: 380, proteinPer100g: 12, carbsPer100g: 65, fatPer100g: 8.0, category: .other),
    FoodItem(name: "Eintopf Linseneintopf", brand: "Erasco", emoji: "🥣", caloriesPer100g: 70, proteinPer100g: 4.0, carbsPer100g: 9.0, fatPer100g: 2.0, category: .other),
    FoodItem(name: "Hummus", emoji: "🫙", caloriesPer100g: 177, proteinPer100g: 8, carbsPer100g: 14, fatPer100g: 10, category: .other),
    FoodItem(name: "Tomaten-Pesto Genovese", brand: "Barilla", emoji: "🫙", caloriesPer100g: 597, proteinPer100g: 6.5, carbsPer100g: 5.0, fatPer100g: 60, category: .other),
    FoodItem(name: "Pastasauce Napoletana", brand: "Barilla", emoji: "🫙", caloriesPer100g: 56, proteinPer100g: 1.7, carbsPer100g: 8.0, fatPer100g: 1.8, category: .other),
    FoodItem(name: "Tomatenketchup", brand: "Heinz", emoji: "🍅", caloriesPer100g: 102, proteinPer100g: 1.2, carbsPer100g: 23, fatPer100g: 0.1, category: .other),
    FoodItem(name: "Sojasauce", brand: "Kikkoman", emoji: "🫙", caloriesPer100g: 78, proteinPer100g: 11, carbsPer100g: 8.0, fatPer100g: 0, category: .other),
    FoodItem(name: "Mayonnaise (80% Fett)", brand: "Hellmann's", emoji: "🥚", caloriesPer100g: 717, proteinPer100g: 1.0, carbsPer100g: 1.5, fatPer100g: 78, category: .other),
    FoodItem(name: "Senf mittelscharf", emoji: "🫙", caloriesPer100g: 92, proteinPer100g: 6.0, carbsPer100g: 5.0, fatPer100g: 5.0, category: .other),

    // ===== OTHER — Getränke =====
    FoodItem(name: "Wasser (still)", emoji: "💧", caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, category: .other),
    FoodItem(name: "Kaffee (schwarz)", emoji: "☕", caloriesPer100g: 2, proteinPer100g: 0.3, carbsPer100g: 0, fatPer100g: 0, category: .other),
    FoodItem(name: "Espresso", emoji: "☕", caloriesPer100g: 9, proteinPer100g: 0.1, carbsPer100g: 1.7, fatPer100g: 0.2, category: .other),
    FoodItem(name: "Cappuccino (Vollmilch)", emoji: "☕", caloriesPer100g: 37, proteinPer100g: 1.9, carbsPer100g: 2.7, fatPer100g: 2.0, category: .other),
    FoodItem(name: "Cola Original", brand: "Coca-Cola", emoji: "🥤", caloriesPer100g: 42, proteinPer100g: 0, carbsPer100g: 11, fatPer100g: 0, category: .other),
    FoodItem(name: "Cola Zero", brand: "Coca-Cola", emoji: "🥤", caloriesPer100g: 0, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, category: .other),
    FoodItem(name: "Sprite", brand: "Sprite", emoji: "🥤", caloriesPer100g: 38, proteinPer100g: 0, carbsPer100g: 9.5, fatPer100g: 0, category: .other),
    FoodItem(name: "Fanta Orange", brand: "Fanta", emoji: "🥤", caloriesPer100g: 41, proteinPer100g: 0, carbsPer100g: 10, fatPer100g: 0, category: .other),
    FoodItem(name: "Apfelschorle", emoji: "🧃", caloriesPer100g: 24, proteinPer100g: 0.1, carbsPer100g: 5.5, fatPer100g: 0, category: .other),
    FoodItem(name: "Orangensaft", emoji: "🧃", caloriesPer100g: 45, proteinPer100g: 0.7, carbsPer100g: 10, fatPer100g: 0.2, category: .other),
    FoodItem(name: "Pils (5%)", emoji: "🍺", caloriesPer100g: 43, proteinPer100g: 0.5, carbsPer100g: 3.6, fatPer100g: 0, category: .other),
    FoodItem(name: "Weißbier (5,4%)", emoji: "🍺", caloriesPer100g: 48, proteinPer100g: 0.6, carbsPer100g: 3.8, fatPer100g: 0, category: .other),
    FoodItem(name: "Rotwein (12%)", emoji: "🍷", caloriesPer100g: 85, proteinPer100g: 0.1, carbsPer100g: 2.6, fatPer100g: 0, category: .other),
    FoodItem(name: "Weißwein (12%)", emoji: "🍷", caloriesPer100g: 82, proteinPer100g: 0.1, carbsPer100g: 2.6, fatPer100g: 0, category: .other),

    // ===== OTHER — Riegel & Shakes =====
    FoodItem(name: "Proteinriegel (generisch)", emoji: "🍫", caloriesPer100g: 350, proteinPer100g: 28, carbsPer100g: 30, fatPer100g: 10, category: .other),
    FoodItem(name: "Proteinshake (fertig)", emoji: "🥤", caloriesPer100g: 40, proteinPer100g: 6, carbsPer100g: 3.0, fatPer100g: 0.5, category: .other),
  ]
}
