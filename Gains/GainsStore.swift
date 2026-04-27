import Contacts
import CoreLocation
import Foundation

final class GainsStore: ObservableObject {
  enum HealthConnectionStatus {
    case unavailable
    case disconnected
    case connecting
    case connected
    case failed(String)

    var title: String {
      switch self {
      case .unavailable: return "Nicht verfügbar"
      case .disconnected: return "Nicht verbunden"
      case .connecting: return "Verbindet"
      case .connected: return "Verbunden"
      case .failed: return "Fehler"
      }
    }
  }

  enum WhoopConnectionStatus {
    case disconnected
    case setupRequired
    case connected
    case failed(String)

    var title: String {
      switch self {
      case .disconnected: return "Nicht verbunden"
      case .setupRequired: return "Setup nötig"
      case .connected: return "Verbunden"
      case .failed: return "Fehler"
      }
    }
  }

  @Published var activeWorkout: WorkoutSession?
  @Published var activeRun: ActiveRunSession?
  @Published var lastCompletedWorkout: CompletedWorkoutSummary?
  // A1: Frische Installation startet leer — Mock-Historien sind nur noch im
  // DEBUG-Demo-Modus erreichbar (siehe `loadDemoData()` unten).
  @Published var workoutHistory: [CompletedWorkoutSummary] = []
  @Published var runHistory: [CompletedRunSummary] = []
  @Published var savedWorkoutPlans: [WorkoutPlan] = WorkoutPlan.starterTemplates
  @Published var plannerSettings: WorkoutPlannerSettings = .default
  @Published var completedCoachCheckInIDs: Set<UUID> = []
  @Published var joinedChallenge = false
  @Published var likedPostIDs: Set<UUID> = []
  @Published var commentedPostIDs: Set<UUID> = []
  @Published var sharedPostIDs: Set<UUID> = []
  @Published var favoriteRecipeIDs: Set<UUID> = []
  @Published var connectedTrackerIDs: Set<UUID> = []
  @Published var healthConnectionStatus: HealthConnectionStatus = .disconnected
  @Published var whoopConnectionStatus: WhoopConnectionStatus = .disconnected
  @Published var healthSnapshot: HealthSnapshot?
  // Community-Daten bleiben in Phase A leer (Tab wird in A1b durch Coming-Soon
  // ersetzt). Mock-Posts sind nur über `loadDemoData()` aktivierbar.
  @Published var communityPosts: [CommunityPost] = []
  @Published var communityContacts: [CommunityContact] = []
  @Published var contactsAccessStatus: CNAuthorizationStatus = CNContactStore.authorizationStatus(
    for: .contacts)
  @Published var socialSharingSettings: SocialSharingSettings = .default
  @Published var forumThreads: [ForumThread] = []
  @Published var meetups: [Meetup] = []
  @Published var joinedMeetupIDs: Set<UUID> = []
  @Published var notificationsEnabled = true
  @Published var healthAutoSyncEnabled = true
  @Published var studyBasedCoachingEnabled = true
  @Published var appearanceMode: GainsAppearanceMode = .dark
  @Published var nutritionGoal: NutritionGoal = .maintain
  @Published var nutritionProfile: NutritionProfile?
  @Published var nutritionEntries: [NutritionEntry] = []
  @Published var weightTrend: [WeightTrendPoint] = []
  @Published var waistMeasurement: Double = 0
  @Published var bodyFatChange: Double = 0
  @Published var proteinProgress: Double = 0
  @Published var userName: String = ""
  @Published var streakDays = 0
  @Published var recordDays = 0
  @Published var vitalSyncCount = 0
  @Published var lastProgressEvent =
    "Dein Progress reagiert hier auf Check-ins, Tracker-Syncs und abgeschlossene Workouts."
  @Published var calendarWeekOffset = 0
  @Published var selectedCalendarDate: Date
  @Published private var completedCalendarDates: Set<Date>

  let exerciseLibrary = ExerciseLibraryItem.commonGymExercises
  let runningTemplates = RunTemplate.stravaInspiredTemplates
  let trackerOptions = ProgressViewModel.mock.trackerOptions
  let recipes = RecipesViewModel.mock.recipes
  let communityComposerActions = CommunityViewModel.mock.composerPrompts

  private let contactStore = CNContactStore()
  private let healthKitManager = HealthKitManager.shared
  // A1: Start-Werte fallen weg — sobald der Nutzer ein Profil/Gewicht
  // eingibt, übernimmt currentWeight die Rolle. Solange das nicht passiert,
  // sind alle progress-bezogenen Berechnungen 0.
  private var startWeight: Double { currentWeight }
  private let startWaist: Double = 0
  private let baseChallengeParticipants = 0
  private let baseMilestones: [ProgressMilestone] = []

  init() {
    let today = Calendar.current.startOfDay(for: Date())
    _selectedCalendarDate = Published(initialValue: today)
    // A1: Keine vor-ausgefüllten "abgeschlossen"-Tage mehr — Streak startet bei 0
    // und baut sich aus echten Workouts auf.
    _completedCalendarDates = Published(initialValue: [])
    // A5: Schema-Migration laufen lassen, bevor wir lesen.
    PersistenceMigrator.runIfNeeded()
    loadPersistedData(today: today)
    lastCompletedWorkout = workoutHistory.first
    recalculateStreak()
  }

  // MARK: - Persistenz

  private func loadPersistedData(today: Date) {
    let ud = UserDefaults.standard

    if let name = ud.string(forKey: PersistenceKey.userName) {
      userName = name
    }
    // A5: Historien lenient laden — einzelne korrupte Einträge dürfen nicht
    // die ganze Liste verwerfen.
    if let history = ud.decodedLoadLenient(CompletedWorkoutSummary.self, forKey: PersistenceKey.workoutHistory) {
      workoutHistory = history
    }
    if let runs = ud.decodedLoadLenient(CompletedRunSummary.self, forKey: PersistenceKey.runHistory) {
      runHistory = runs
    }
    if let plans = ud.decodedLoad([WorkoutPlan].self, forKey: PersistenceKey.savedWorkoutPlans) {
      savedWorkoutPlans = plans
    }
    if let settings = ud.decodedLoad(WorkoutPlannerSettings.self, forKey: PersistenceKey.plannerSettings) {
      plannerSettings = settings
    }
    if let trend = ud.decodedLoad([WeightTrendPoint].self, forKey: PersistenceKey.weightTrend) {
      weightTrend = trend
    }
    if let entries = ud.decodedLoadLenient(NutritionEntry.self, forKey: PersistenceKey.nutritionEntries) {
      // Persistierte Einträge laden — nichts mehr nachseeden.
      nutritionEntries = entries
    } else {
      // A1: Frische Installation startet ohne Beispiel-Mahlzeiten.
      nutritionEntries = []
    }
    if let goal = ud.decodedLoad(NutritionGoal.self, forKey: PersistenceKey.nutritionGoal) {
      nutritionGoal = goal
    }
    if let profile = ud.decodedLoad(NutritionProfile.self, forKey: PersistenceKey.nutritionProfile) {
      nutritionProfile = profile
    }
    if let ids = ud.decodedLoad([UUID].self, forKey: PersistenceKey.connectedTrackerIDs) {
      connectedTrackerIDs = Set(ids)
    }
    if let ids = ud.decodedLoad([UUID].self, forKey: PersistenceKey.favoriteRecipeIDs) {
      favoriteRecipeIDs = Set(ids)
    }
    if let dates = ud.decodedLoad([Date].self, forKey: PersistenceKey.completedDates) {
      _completedCalendarDates = Published(initialValue: Set(dates))
    }
    if ud.object(forKey: PersistenceKey.waistMeasurement) != nil {
      waistMeasurement = ud.double(forKey: PersistenceKey.waistMeasurement)
    }
    if ud.object(forKey: PersistenceKey.bodyFatChange) != nil {
      bodyFatChange = ud.double(forKey: PersistenceKey.bodyFatChange)
    }
    if ud.object(forKey: PersistenceKey.proteinProgress) != nil {
      proteinProgress = ud.double(forKey: PersistenceKey.proteinProgress)
    }
    if ud.object(forKey: PersistenceKey.streakDays) != nil {
      streakDays = ud.integer(forKey: PersistenceKey.streakDays)
    }
    if ud.object(forKey: PersistenceKey.recordDays) != nil {
      recordDays = ud.integer(forKey: PersistenceKey.recordDays)
    }
    if ud.object(forKey: PersistenceKey.vitalSyncCount) != nil {
      vitalSyncCount = ud.integer(forKey: PersistenceKey.vitalSyncCount)
    }
    if ud.object(forKey: PersistenceKey.notificationsEnabled) != nil {
      notificationsEnabled = ud.bool(forKey: PersistenceKey.notificationsEnabled)
    }
    if ud.object(forKey: PersistenceKey.healthAutoSync) != nil {
      healthAutoSyncEnabled = ud.bool(forKey: PersistenceKey.healthAutoSync)
    }
    if ud.object(forKey: PersistenceKey.studyCoaching) != nil {
      studyBasedCoachingEnabled = ud.bool(forKey: PersistenceKey.studyCoaching)
    }
    if ud.object(forKey: PersistenceKey.joinedChallenge) != nil {
      joinedChallenge = ud.bool(forKey: PersistenceKey.joinedChallenge)
    }
    if let settings = ud.decodedLoad(SocialSharingSettings.self, forKey: PersistenceKey.socialSharingSettings) {
      socialSharingSettings = settings
    }
    if let threads = ud.decodedLoad([ForumThread].self, forKey: PersistenceKey.forumThreads) {
      forumThreads = threads
    }
    if let savedMeetups = ud.decodedLoad([Meetup].self, forKey: PersistenceKey.meetups) {
      meetups = savedMeetups
    }
    if let ids = ud.decodedLoad([UUID].self, forKey: PersistenceKey.joinedMeetupIDs) {
      joinedMeetupIDs = Set(ids)
    }
    if let rawMode = ud.string(forKey: PersistenceKey.appearanceMode),
       let mode = GainsAppearanceMode(rawValue: rawMode) {
      appearanceMode = mode
    }
  }

  func saveAll() {
    let ud = UserDefaults.standard
    ud.set(userName, forKey: PersistenceKey.userName)
    ud.encodedSave(workoutHistory,    forKey: PersistenceKey.workoutHistory)
    ud.encodedSave(runHistory,        forKey: PersistenceKey.runHistory)
    ud.encodedSave(savedWorkoutPlans, forKey: PersistenceKey.savedWorkoutPlans)
    ud.encodedSave(plannerSettings,   forKey: PersistenceKey.plannerSettings)
    ud.encodedSave(weightTrend,       forKey: PersistenceKey.weightTrend)
    ud.encodedSave(Array(connectedTrackerIDs), forKey: PersistenceKey.connectedTrackerIDs)
    ud.encodedSave(Array(favoriteRecipeIDs),   forKey: PersistenceKey.favoriteRecipeIDs)
    ud.encodedSave(Array(completedCalendarDates), forKey: PersistenceKey.completedDates)
    ud.encodedSave(nutritionEntries,  forKey: PersistenceKey.nutritionEntries)
    ud.encodedSave(nutritionGoal,     forKey: PersistenceKey.nutritionGoal)
    if let profile = nutritionProfile { ud.encodedSave(profile, forKey: PersistenceKey.nutritionProfile) }
    ud.set(waistMeasurement,          forKey: PersistenceKey.waistMeasurement)
    ud.set(bodyFatChange,             forKey: PersistenceKey.bodyFatChange)
    ud.set(proteinProgress,           forKey: PersistenceKey.proteinProgress)
    ud.set(streakDays,                forKey: PersistenceKey.streakDays)
    ud.set(recordDays,                forKey: PersistenceKey.recordDays)
    ud.set(vitalSyncCount,            forKey: PersistenceKey.vitalSyncCount)
    ud.set(notificationsEnabled,      forKey: PersistenceKey.notificationsEnabled)
    ud.set(healthAutoSyncEnabled,     forKey: PersistenceKey.healthAutoSync)
    ud.set(studyBasedCoachingEnabled, forKey: PersistenceKey.studyCoaching)
    ud.set(joinedChallenge,           forKey: PersistenceKey.joinedChallenge)
    ud.set(appearanceMode.rawValue,   forKey: PersistenceKey.appearanceMode)
    ud.encodedSave(socialSharingSettings, forKey: PersistenceKey.socialSharingSettings)
    ud.encodedSave(forumThreads,      forKey: PersistenceKey.forumThreads)
    ud.encodedSave(meetups,           forKey: PersistenceKey.meetups)
    ud.encodedSave(Array(joinedMeetupIDs), forKey: PersistenceKey.joinedMeetupIDs)
  }

  // MARK: - Demo-Daten (nur DEBUG)
  //
  // Für Screenshots, App-Store-Vorschauen und manuelles QA-Testing.
  // Im Release-Build nicht aufrufbar — die Funktionen existieren dann nicht.

  #if DEBUG
  /// Befüllt den Store mit den ursprünglichen Mock-Inhalten (Workout-Historie,
  /// Lauf-Historie, Community-Posts, Forum, Meetups, Beispiel-Mahlzeiten).
  /// Aufgerufen aus dem Profil-Screen über einen DEBUG-Button.
  func loadDemoData() {
    let today = Calendar.current.startOfDay(for: Date())
    workoutHistory   = CompletedWorkoutSummary.mockHistory
    runHistory       = CompletedRunSummary.mockHistory
    communityPosts   = CommunityViewModel.mock.posts
    forumThreads     = ForumThread.mockThreads
    meetups          = Meetup.mockMeetups
    weightTrend      = ProgressViewModel.mock.weeklyTrend
    bodyFatChange    = HomeViewModel.mock.bodyFatChange
    recordDays       = HomeViewModel.mock.recordDays
    proteinProgress  = 178
    waistMeasurement = 91
    if userName.isEmpty { userName = "Demo" }
    if nutritionEntries.isEmpty {
      nutritionEntries = Self.demoNutritionEntries(for: today)
    }
    completedCalendarDates = Self.demoCompletedDates(relativeTo: today)
    lastCompletedWorkout = workoutHistory.first
    recalculateStreak()
    saveAll()
  }

  /// Setzt alles zurück — alle Persistenz-Keys werden gelöscht und die
  /// Defaults aus den `@Published`-Eigenschaften treten wieder in Kraft
  /// (sprich: leere Listen, Nullwerte). Erfordert App-Neustart, damit die
  /// init() sauber durchläuft.
  func clearAllData() {
    let ud = UserDefaults.standard
    let allKeys: [String] = [
      PersistenceKey.userName, PersistenceKey.workoutHistory, PersistenceKey.runHistory,
      PersistenceKey.savedWorkoutPlans, PersistenceKey.plannerSettings,
      PersistenceKey.weightTrend, PersistenceKey.waistMeasurement,
      PersistenceKey.bodyFatChange, PersistenceKey.proteinProgress,
      PersistenceKey.streakDays, PersistenceKey.recordDays, PersistenceKey.vitalSyncCount,
      PersistenceKey.completedDates, PersistenceKey.nutritionEntries,
      PersistenceKey.nutritionGoal, PersistenceKey.nutritionProfile,
      PersistenceKey.connectedTrackerIDs, PersistenceKey.favoriteRecipeIDs,
      PersistenceKey.notificationsEnabled, PersistenceKey.healthAutoSync,
      PersistenceKey.studyCoaching, PersistenceKey.appearanceMode,
      PersistenceKey.joinedChallenge, PersistenceKey.socialSharingSettings,
      PersistenceKey.forumThreads, PersistenceKey.meetups, PersistenceKey.joinedMeetupIDs,
      // Auch das Onboarding-Flag und die Community-Waitlist zurücksetzen
      "gains_hasCompletedOnboarding", "gains_communityWaitlist",
      // Schema-Version, damit die Migration beim nächsten Start sauber neu läuft.
      PersistenceKey.schemaVersion,
    ]
    for key in allKeys { ud.removeObject(forKey: key) }
  }

  private static func demoNutritionEntries(for today: Date) -> [NutritionEntry] {
    let cal = Calendar.current
    let breakfast = cal.date(bySettingHour: 8, minute: 10, second: 0, of: today) ?? today
    let lunch     = cal.date(bySettingHour: 13, minute: 0, second: 0, of: today) ?? today
    return [
      NutritionEntry(id: UUID(), title: "Overnight Oats Gains", mealType: .breakfast,
                     loggedAt: breakfast, calories: 458, protein: 39, carbs: 42, fat: 14),
      NutritionEntry(id: UUID(), title: "High Protein Chicken Bowl", mealType: .lunch,
                     loggedAt: lunch, calories: 612, protein: 54, carbs: 48, fat: 18),
    ]
  }

  private static func demoCompletedDates(relativeTo today: Date) -> Set<Date> {
    let cal = Calendar.current
    let offsets = [0, -1, -2, -4, -5, -7, -8, -9, -11]
    return Set(offsets.compactMap {
      cal.date(byAdding: .day, value: $0, to: today).map { cal.startOfDay(for: $0) }
    })
  }
  #endif

  var weeklyWorkoutSchedule: [WorkoutDayPlan] {
    let allWorkouts = savedWorkoutPlans.isEmpty ? WorkoutPlan.starterTemplates : savedWorkoutPlans
    var workoutRotationIndex = 0
    let scheduledWorkoutDays = Set(scheduledPlannerDays)
    let kindByDay = plannedSessionKinds

    return Weekday.allCases.map { day in
      let isToday = day == .today

      if scheduledWorkoutDays.contains(day) {
        // Manuelle Zuweisung dominiert weiterhin alles.
        if let assignedWorkout = assignedWorkoutPlan(for: day) {
          return WorkoutDayPlan(
            weekday: day,
            dayLabel: day.shortLabel,
            title: assignedWorkout.title,
            focus: assignedWorkout.focus,
            isToday: isToday,
            status: .planned,
            workoutPlan: assignedWorkout,
            sessionKind: .strength,
            runTemplate: nil
          )
        }

        let kind = kindByDay[day] ?? .strength

        if kind.isRun {
          let template = RunTemplate.template(for: kind)
          let title = template?.title ?? kind.title
          let focus =
            template != nil
            ? "\(Int(template!.targetDistanceKm)) km · \(template!.targetPaceLabel)"
            : kind.title

          return WorkoutDayPlan(
            weekday: day,
            dayLabel: day.shortLabel,
            title: title,
            focus: focus,
            isToday: isToday,
            status: .planned,
            workoutPlan: nil,
            sessionKind: kind,
            runTemplate: template
          )
        }

        // Strength-Tag → bestehende Plan-Rotation.
        let generatedWorkoutPlan = allWorkouts[workoutRotationIndex % allWorkouts.count]
        workoutRotationIndex += 1
        return WorkoutDayPlan(
          weekday: day,
          dayLabel: day.shortLabel,
          title: generatedWorkoutPlan.title,
          focus: generatedWorkoutPlan.focus,
          isToday: isToday,
          status: .planned,
          workoutPlan: generatedWorkoutPlan,
          sessionKind: .strength,
          runTemplate: nil
        )
      }

      if dayPreference(for: day) == .rest {
        return WorkoutDayPlan(
          weekday: day,
          dayLabel: day.shortLabel,
          title: "Frei",
          focus: "Recovery / Spaziergang",
          isToday: isToday,
          status: .rest,
          workoutPlan: nil,
          sessionKind: nil,
          runTemplate: nil
        )
      }

      return WorkoutDayPlan(
        weekday: day,
        dayLabel: day.shortLabel,
        title: "Flexibel",
        focus: "Optional Cardio / Mobility",
        isToday: isToday,
        status: .flexible,
        workoutPlan: nil,
        sessionKind: .mobility,
        runTemplate: nil
      )
    }
  }

  var todayPlannedDay: WorkoutDayPlan {
    weeklyWorkoutSchedule.first(where: { $0.isToday }) ?? weeklyWorkoutSchedule[0]
  }

  var todayPlannedWorkout: WorkoutPlan? {
    todayPlannedDay.workoutPlan
  }

  var currentWorkoutPreview: WorkoutPlan {
    todayPlannedWorkout ?? savedWorkoutPlans.first ?? WorkoutPlan.starterTemplates[0]
  }

  var latestCompletedWorkout: CompletedWorkoutSummary? {
    workoutHistory.first
  }

  var latestCompletedRun: CompletedRunSummary? {
    runHistory.first
  }

  var weeklyRunDistanceKm: Double {
    recentRunHistory.reduce(0) { $0 + $1.distanceKm }
  }

  var weeklyRunDurationMinutes: Int {
    recentRunHistory.reduce(0) { $0 + $1.durationMinutes }
  }

  var weeklyRunCount: Int {
    recentRunHistory.count
  }

  var monthlyRunDistanceKm: Double {
    let calendar = Calendar.current
    let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
    return
      runHistory
      .filter { $0.finishedAt >= cutoff }
      .reduce(0) { $0 + $1.distanceKm }
  }

  var averageRunPaceSeconds: Int {
    guard !recentRunHistory.isEmpty else { return 0 }
    let totalDistance = recentRunHistory.reduce(0) { $0 + $1.distanceKm }
    let totalSeconds = recentRunHistory.reduce(0) { $0 + ($1.durationMinutes * 60) }
    guard totalDistance > 0 else { return 0 }
    return Int(Double(totalSeconds) / totalDistance)
  }

  var bestRunPaceSeconds: Int {
    runHistory.map(\.averagePaceSeconds).min() ?? 0
  }

  var runningGoalProgress: Double {
    guard let activeRun, activeRun.targetDistanceKm > 0 else { return 0 }
    return min(max(activeRun.distanceKm / activeRun.targetDistanceKm, 0), 1)
  }

  var runningGoalHeadline: String {
    guard let activeRun else {
      return "Wähle einen Lauf und Gains zeigt dir hier Ziel und Fortschritt."
    }

    let remainingDistance = max(activeRun.targetDistanceKm - activeRun.distanceKm, 0)
    if remainingDistance == 0 {
      return "Distanzziel erreicht. Jetzt kannst du noch kontrolliert auslaufen."
    }

    return
      "\(String(format: "%.1f", remainingDistance)) km bis zum Ziel auf \(String(format: "%.1f", activeRun.targetDistanceKm)) km."
  }

  var runningGoalDescription: String {
    guard let activeRun else {
      return "Gerade kein aktiver Lauf."
    }

    return
      "Zielzeit \(activeRun.targetDurationMinutes) Min, Ziel-Pace \(activeRun.targetPaceLabel), aktuell \(formattedPace(secondsPerKilometer: activeRun.averagePaceSeconds))."
  }

  var latestRunAchievement: String {
    guard let latestCompletedRun else {
      return "Starte deinen ersten Lauf und sammle direkt persönliche Bestwerte."
    }

    if latestCompletedRun.distanceKm >= 10 {
      return
        "Starker Ausdauerblock: \(String(format: "%.1f", latestCompletedRun.distanceKm)) km zuletzt gespeichert."
    }

    if latestCompletedRun.averagePaceSeconds == bestRunPaceSeconds {
      return "Dein letzter Lauf war zugleich dein schnellster Pace-Wert."
    }

    return
      "Letzter Lauf: \(latestCompletedRun.routeName) mit \(formattedPace(secondsPerKilometer: latestCompletedRun.averagePaceSeconds))."
  }

  var runPersonalBests: [RunPersonalBest] {
    var personalBests: [RunPersonalBest] = []

    if let fastest5K =
      runHistory
      .filter({ $0.distanceKm >= 5 })
      .min(by: { $0.averagePaceSeconds < $1.averagePaceSeconds })
    {
      personalBests.append(
        RunPersonalBest(
          title: "Schnellste 5K",
          value: formattedPace(secondsPerKilometer: fastest5K.averagePaceSeconds),
          context: fastest5K.routeName
        )
      )
    }

    if let longestRun = runHistory.max(by: { $0.distanceKm < $1.distanceKm }) {
      personalBests.append(
        RunPersonalBest(
          title: "Längster Lauf",
          value: String(format: "%.1f km", longestRun.distanceKm),
          context: longestRun.routeName
        )
      )
    }

    if let highestElevation = runHistory.max(by: { $0.elevationGain < $1.elevationGain }) {
      personalBests.append(
        RunPersonalBest(
          title: "Höhenmeter",
          value: "\(highestElevation.elevationGain) m",
          context: highestElevation.routeName
        )
      )
    }

    return personalBests
  }

  // MARK: - Strava-style running stats

  struct DailyRunDistance: Identifiable {
    let id = UUID()
    let dayLabel: String
    let km: Double
    let isToday: Bool
  }

  struct PaceZoneEntry: Identifiable {
    let id = UUID()
    let label: String
    let description: String
    let fraction: Double
  }

  /// Consecutive days (ending today) with at least one run logged
  var runStreak: Int {
    let calendar = Calendar.current
    var streak = 0
    var daysBack = 0
    while true {
      let date = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
      let startOfDay = calendar.startOfDay(for: date)
      let hasRun = runHistory.contains { calendar.isDate($0.finishedAt, inSameDayAs: startOfDay) }
      if hasRun {
        streak += 1
        daysBack += 1
      } else {
        break
      }
    }
    return streak
  }

  /// Daily run distance for the past 7 days (oldest → today)
  var weeklyRunsByDay: [DailyRunDistance] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let symbols = calendar.shortWeekdaySymbols
    return (0..<7).reversed().map { daysAgo -> DailyRunDistance in
      let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
      let km = runHistory
        .filter { calendar.isDate($0.finishedAt, inSameDayAs: date) }
        .reduce(0.0) { $0 + $1.distanceKm }
      let weekdayIndex = calendar.component(.weekday, from: date) - 1
      let label = String(symbols[weekdayIndex].prefix(2))
      return DailyRunDistance(dayLabel: label, km: km, isToday: daysAgo == 0)
    }
  }

  var yearlyRunDistanceKm: Double {
    let startOfYear = Calendar.current.date(
      from: Calendar.current.dateComponents([.year], from: Date())) ?? Date.distantPast
    return runHistory.filter { $0.finishedAt >= startOfYear }.reduce(0) { $0 + $1.distanceKm }
  }

  var yearlyRunCount: Int {
    let startOfYear = Calendar.current.date(
      from: Calendar.current.dateComponents([.year], from: Date())) ?? Date.distantPast
    return runHistory.filter { $0.finishedAt >= startOfYear }.count
  }

  var yearlyElevationGain: Int {
    let startOfYear = Calendar.current.date(
      from: Calendar.current.dateComponents([.year], from: Date())) ?? Date.distantPast
    return runHistory.filter { $0.finishedAt >= startOfYear }.reduce(0) { $0 + $1.elevationGain }
  }

  var yearlyRunDurationMinutes: Int {
    let startOfYear = Calendar.current.date(
      from: Calendar.current.dateComponents([.year], from: Date())) ?? Date.distantPast
    return runHistory.filter { $0.finishedAt >= startOfYear }.reduce(0) { $0 + $1.durationMinutes }
  }

  /// Distribution of runs across pace zones
  var paceZones: [PaceZoneEntry] {
    let paces = runHistory.compactMap { $0.averagePaceSeconds > 0 ? $0.averagePaceSeconds : nil }
    guard !paces.isEmpty else { return [] }
    let total = Double(paces.count)
    let entries: [(String, String, Double)] = [
      ("Easy",    ">7:00 /km",   Double(paces.filter { $0 >= 420 }.count) / total),
      ("Moderat", "5:30–7:00",   Double(paces.filter { $0 >= 330 && $0 < 420 }.count) / total),
      ("Tempo",   "4:30–5:30",   Double(paces.filter { $0 >= 270 && $0 < 330 }.count) / total),
      ("Hart",    "<4:30 /km",   Double(paces.filter { $0 < 270 }.count) / total),
    ]
    return entries.filter { $0.2 > 0 }.map { PaceZoneEntry(label: $0.0, description: $0.1, fraction: $0.2) }
  }

  /// Best finish times for standard distances (5K, 10K, Half, Marathon)
  var distancePRs: [RunPersonalBest] {
    let targets: [(title: String, minKm: Double, exactKm: Double)] = [
      ("5K",           4.8,  5.0),
      ("10K",          9.5, 10.0),
      ("Halbmarathon", 20.5, 21.1),
      ("Marathon",     41.0, 42.2),
    ]
    return targets.compactMap { target in
      let eligible = runHistory.filter { $0.distanceKm >= target.minKm }
      guard let best = eligible.min(by: { a, b in
        let aTime = Double(a.durationMinutes) * (target.exactKm / a.distanceKm)
        let bTime = Double(b.durationMinutes) * (target.exactKm / b.distanceKm)
        return aTime < bTime
      }) else { return nil }
      let estimatedMinutes = Int(Double(best.durationMinutes) * (target.exactKm / best.distanceKm))
      let h = estimatedMinutes / 60
      let m = estimatedMinutes % 60
      let timeString = h > 0 ? "\(h)h \(m)min" : "\(m) min"
      return RunPersonalBest(title: target.title, value: timeString, context: best.routeName)
    }
  }

  var nutritionTargetCalories: Int {
    if let profile = nutritionProfile { return profile.targetCalories }
    switch nutritionGoal {
    case .muscleGain: return 2850
    case .fatLoss:    return 2150
    case .maintain:   return 2450
    }
  }

  var nutritionTargetProtein: Int {
    if let profile = nutritionProfile { return profile.targetProteinG }
    switch nutritionGoal {
    case .muscleGain: return 200
    case .fatLoss:    return 190
    case .maintain:   return 175
    }
  }

  var nutritionTargetCarbs: Int {
    if let profile = nutritionProfile { return profile.targetCarbsG }
    switch nutritionGoal {
    case .muscleGain: return 310
    case .fatLoss:    return 190
    case .maintain:   return 250
    }
  }

  var nutritionTargetFat: Int {
    if let profile = nutritionProfile { return profile.targetFatG }
    switch nutritionGoal {
    case .muscleGain: return 85
    case .fatLoss:    return 65
    case .maintain:   return 75
    }
  }

  var nutritionGoalHeadline: String {
    switch nutritionGoal {
    case .muscleGain:
      return "Ziel: Muskelaufbau"
    case .fatLoss:
      return "Ziel: Abnehmen"
    case .maintain:
      return "Ziel: Gewicht halten"
    }
  }

  var nutritionGoalDescription: String {
    nutritionGoal.detail
  }

  var todayNutritionEntries: [NutritionEntry] {
    let start = Calendar.current.startOfDay(for: Date())
    return
      nutritionEntries
      .filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: start) }
      .sorted(by: { $0.loggedAt > $1.loggedAt })
  }

  var nutritionCaloriesToday: Int {
    todayNutritionEntries.reduce(0) { $0 + $1.calories }
  }

  var nutritionProteinToday: Int {
    todayNutritionEntries.reduce(0) { $0 + $1.protein }
  }

  var nutritionCarbsToday: Int {
    todayNutritionEntries.reduce(0) { $0 + $1.carbs }
  }

  var nutritionFatToday: Int {
    todayNutritionEntries.reduce(0) { $0 + $1.fat }
  }

  var nutritionProgressHeadline: String {
    if todayNutritionEntries.isEmpty {
      return "Tracke deine erste Mahlzeit und baue dir deinen Tag sauber auf."
    }

    if nutritionProteinToday >= nutritionTargetProtein {
      return "Protein-Ziel ist drin. Jetzt nur noch Kalorien und Mahlzeitenstruktur sauber halten."
    }

    return
      "\(nutritionProteinToday) g Protein und \(nutritionCaloriesToday) kcal sind heute bereits erfasst."
  }

  var nutritionProgressDescription: String {
    let remainingCalories = max(nutritionTargetCalories - nutritionCaloriesToday, 0)
    let remainingProtein = max(nutritionTargetProtein - nutritionProteinToday, 0)
    return
      "Noch offen: \(remainingCalories) kcal und \(remainingProtein) g Protein bis zu deinem Tagesziel."
  }

  func nutritionEntries(for mealType: RecipeMealType) -> [NutritionEntry] {
    todayNutritionEntries.filter { $0.mealType == mealType }
  }

  func logRecipe(_ recipe: Recipe) {
    let entry = NutritionEntry(
      id: UUID(),
      title: recipe.title,
      mealType: recipe.mealType,
      loggedAt: Date(),
      calories: recipe.calories,
      protein: recipe.protein,
      carbs: recipe.carbs,
      fat: recipe.fat
    )
    nutritionEntries.insert(entry, at: 0)
    proteinProgress = min(260, rounded(proteinProgress + Double(recipe.protein)))
    lastProgressEvent =
      "Meal erfasst: \(recipe.title) mit \(recipe.calories) kcal und \(recipe.protein) g Protein."
    saveAll()
  }

  func logNutritionEntry(
    title: String, mealType: RecipeMealType, calories: Int, protein: Int, carbs: Int, fat: Int
  ) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return }

    let entry = NutritionEntry(
      id: UUID(),
      title: trimmedTitle,
      mealType: mealType,
      loggedAt: Date(),
      calories: max(0, calories),
      protein: max(0, protein),
      carbs: max(0, carbs),
      fat: max(0, fat)
    )
    nutritionEntries.insert(entry, at: 0)
    proteinProgress = min(260, rounded(proteinProgress + Double(max(0, protein))))
    lastProgressEvent =
      "Eigene Mahlzeit erfasst: \(trimmedTitle) wurde zum Ernährungstracker hinzugefügt."
    saveAll()
  }

  func setNutritionGoal(_ goal: NutritionGoal) {
    nutritionGoal = goal
    nutritionProfile?.goal = goal
    lastProgressEvent =
      "Ernährungsziel aktualisiert: \(goal.title). Deine Tagesziele wurden angepasst."
    saveAll()
  }

  func setNutritionProfile(_ profile: NutritionProfile) {
    nutritionProfile = profile
    nutritionGoal = profile.goal
    lastProgressEvent =
      "Ernährungsziele personalisiert: \(profile.targetCalories) kcal · \(profile.targetProteinG)g Protein berechnet."
    saveAll()
  }

  func clearNutritionProfile() {
    nutritionProfile = nil
    lastProgressEvent = "Ernährungsprofil zurückgesetzt. Standardziele werden verwendet."
    saveAll()
  }

  func removeNutritionEntry(_ id: UUID) {
    nutritionEntries.removeAll { $0.id == id }
    lastProgressEvent = "Ein Ernährungseintrag wurde entfernt."
    saveAll()
  }

  var runningHeadline: String {
    if let activeRun {
      return
        "Live: \(String(format: "%.1f", activeRun.distanceKm)) km · \(formattedPace(secondsPerKilometer: activeRun.averagePaceSeconds))"
    }

    if let latestCompletedRun {
      return
        "Letzter Lauf: \(latestCompletedRun.title) über \(String(format: "%.1f", latestCompletedRun.distanceKm)) km"
    }

    return "Starte deinen ersten Lauf in Gains"
  }

  var runningDescription: String {
    if activeRun != nil {
      return
        "Deine Pace, Herzfrequenz und Distanz laufen gerade live mit. Du kannst den Lauf direkt tracken oder abschließen."
    }

    if weeklyRunCount > 0 {
      return
        "\(weeklyRunCount) Läufe und \(String(format: "%.1f", weeklyRunDistanceKm)) km in den letzten 7 Tagen. Genau dafür ist der Strava-artige Bereich gedacht."
    }

    return
      "Nutze Vorlagen wie Easy 5K, Tempo oder Long Run und teile den Lauf danach direkt in die Community."
  }

  var customWorkoutPlans: [WorkoutPlan] {
    savedWorkoutPlans.filter { $0.source == .custom }
  }

  var templateWorkoutPlans: [WorkoutPlan] {
    savedWorkoutPlans.filter { $0.source == .template }
  }

  var weeklySessionsCompleted: Int {
    recentWorkoutHistory.count
  }

  var weeklyVolumeTons: Double {
    recentWorkoutHistory.reduce(0) { $0 + $1.volume } / 1000
  }

  var weeklyGoalCount: Int {
    plannerSettings.sessionsPerWeek
  }

  var connectedTrackerCount: Int {
    connectedTrackerIDs.count
  }

  var progressPerformanceStats: [PerformanceProgressStat] {
    [
      PerformanceProgressStat(
        title: "Aktuelle Pace",
        value: latestCompletedRun.map { formattedPace(secondsPerKilometer: $0.averagePaceSeconds) }
          ?? "--:-- /km",
        subtitle: runningPaceProgressText
      ),
      PerformanceProgressStat(
        title: "Run-Distanz",
        value: latestCompletedRun.map { String(format: "%.1f km", $0.distanceKm) } ?? "--",
        subtitle: runningDistanceProgressText
      ),
      PerformanceProgressStat(
        title: "Letztes Volumen",
        value: latestCompletedWorkoutVolumeText,
        subtitle: workoutVolumeProgressText
      ),
      PerformanceProgressStat(
        title: "Kraft-Sets",
        value: latestCompletedWorkout.map { "\($0.completedSets)" } ?? "--",
        subtitle: workoutSetProgressText
      ),
    ]
  }

  var exerciseStrengthProgress: [ExerciseStrengthProgress] {
    let grouped = Dictionary(
      grouping: workoutHistory.flatMap { workout in
        workout.exercises.map { (workout.finishedAt, $0) }
      }, by: { $0.1.name })

    return grouped.compactMap { name, entries in
      let sortedEntries = entries.sorted(by: { $0.0 < $1.0 })
      guard let latest = sortedEntries.last?.1 else { return nil }
      guard latest.topWeight > 0 else { return nil }

      let baseline = sortedEntries.first?.1 ?? latest
      let delta = latest.topWeight - baseline.topWeight

      return ExerciseStrengthProgress(
        exerciseName: name,
        currentValue: String(format: "%.1f kg", latest.topWeight),
        deltaLabel: strengthDeltaLabel(delta, baseline: baseline.topWeight),
        subtitle: "\(latest.completedSets) Sätze · \(Int(latest.totalVolume)) kg Volumen"
      )
    }
    .sorted { left, right in
      let leftValue = Double(left.currentValue.replacingOccurrences(of: " kg", with: "")) ?? 0
      let rightValue = Double(right.currentValue.replacingOccurrences(of: " kg", with: "")) ?? 0
      return leftValue > rightValue
    }
    .prefix(4)
    .map { $0 }
  }

  var appleHealthTrackerID: UUID? {
    trackerOptions.first(where: { $0.source == "HealthKit" })?.id
  }

  var whoopTrackerID: UUID? {
    trackerOptions.first(where: { $0.name == "WHOOP" })?.id
  }

  var hasConnectedAppleHealth: Bool {
    guard let appleHealthTrackerID else { return false }
    return connectedTrackerIDs.contains(appleHealthTrackerID)
  }

  var hasConnectedWhoop: Bool {
    guard let whoopTrackerID else { return false }
    return connectedTrackerIDs.contains(whoopTrackerID)
  }

  var healthConnectionTitle: String {
    healthConnectionStatus.title
  }

  var healthConnectionSubtitle: String {
    switch healthConnectionStatus {
    case .unavailable:
      return "HealthKit ist hier nicht verfügbar."
    case .disconnected:
      return "Apple Health kann verbunden werden."
    case .connecting:
      return "Berechtigungen und Daten werden geladen."
    case .connected:
      if let healthSnapshot {
        return "Zuletzt synchronisiert: \(timeLabel(for: healthSnapshot.lastSyncDate))"
      }
      return "Apple Health ist verbunden."
    case .failed(let message):
      return message
    }
  }

  var appleHealthHeadline: String {
    guard let healthSnapshot else {
      return "Apple Health kann Schlaf, Herz, Bewegung und Gewicht direkt in Gains bündeln."
    }

    let sleep = healthSnapshot.sleepHoursLastNight ?? 0
    if sleep >= 8, healthSnapshot.exerciseMinutesToday >= 30 {
      return "Starker Health-Tag mit guter Recovery und sauberer Aktivität."
    }

    if sleep < 6.5 {
      return
        "Dein Schlaf fällt heute etwas ab. Training und Recovery sollten bewusster gesteuert werden."
    }

    if healthSnapshot.stepsToday >= 10000 {
      return "Bewegung sitzt heute. Schritte, Aktivität und Training greifen gut ineinander."
    }

    return "Apple Health gibt dir heute ein klares Bild aus Schlaf, Herzfrequenz und Aktivität."
  }

  var appleHealthDescription: String {
    guard let healthSnapshot else {
      return
        "Verbinde Apple Health, damit Gains deine Vitaldaten automatisch lesbar aufbereiten kann."
    }

    return
      "Zuletzt synchronisiert um \(timeLabel(for: healthSnapshot.lastSyncDate)) · \(healthSnapshot.stepsToday) Schritte · \(healthSnapshot.exerciseMinutesToday) Minuten Training."
  }

  var appleHealthHighlights: [HealthPresentationStat] {
    guard let healthSnapshot else {
      return [
        HealthPresentationStat(title: "Schlaf", value: "--", subtitle: "Nacht fehlt"),
        HealthPresentationStat(title: "Herz", value: "--", subtitle: "HF fehlt"),
        HealthPresentationStat(title: "Aktivität", value: "--", subtitle: "Tag fehlt"),
        HealthPresentationStat(title: "Körper", value: "--", subtitle: "Gewicht fehlt"),
      ]
    }

    let heartValue: String
    if let currentHeartRate = healthSnapshot.currentHeartRate {
      heartValue = "\(Int(currentHeartRate.rounded())) bpm"
    } else if let restingHeartRate = healthSnapshot.restingHeartRate {
      heartValue = "\(Int(restingHeartRate.rounded())) bpm"
    } else {
      heartValue = "--"
    }

    let heartSubtitle: String
    if let restingHeartRate = healthSnapshot.restingHeartRate,
      let hrv = healthSnapshot.heartRateVariability
    {
      heartSubtitle = "RHR \(Int(restingHeartRate.rounded())) · HRV \(Int(hrv.rounded()))"
    } else {
      heartSubtitle = "letzter Pulswert"
    }

    let bodyValue: String
    if let bodyMass = healthSnapshot.bodyMassKg {
      bodyValue = String(format: "%.1f kg", bodyMass)
    } else if let vo2Max = healthSnapshot.vo2Max {
      bodyValue = String(format: "%.1f", vo2Max)
    } else {
      bodyValue = "--"
    }

    let bodySubtitle: String
    if healthSnapshot.bodyMassKg != nil, let vo2Max = healthSnapshot.vo2Max {
      bodySubtitle = "VO2max \(String(format: "%.1f", vo2Max))"
    } else if healthSnapshot.bodyMassKg != nil {
      bodySubtitle = "aktuelles Gewicht"
    } else {
      bodySubtitle = "Leistungswert"
    }

    return [
      HealthPresentationStat(
        title: "Schlaf",
        value: formattedSleepHours(healthSnapshot.sleepHoursLastNight),
        subtitle: "letzte Nacht"
      ),
      HealthPresentationStat(
        title: "Herz",
        value: heartValue,
        subtitle: heartSubtitle
      ),
      HealthPresentationStat(
        title: "Aktivität",
        value: "\(healthSnapshot.exerciseMinutesToday) Min",
        subtitle:
          "\(healthSnapshot.activeEnergyToday) kcal · \(String(format: "%.1f", healthSnapshot.distanceWalkingRunningKmToday)) km"
      ),
      HealthPresentationStat(
        title: "Körper",
        value: bodyValue,
        subtitle: bodySubtitle
      ),
    ]
  }

  var whoopConnectionTitle: String {
    whoopConnectionStatus.title
  }

  var whoopConnectionSubtitle: String {
    switch whoopConnectionStatus {
    case .disconnected:
      return "WHOOP kann über OAuth verbunden werden."
    case .setupRequired:
      return
        "Für WHOOP braucht Gains noch Client-ID, Redirect-URI und einen sicheren Token-Backend-Flow."
    case .connected:
      return "WHOOP ist verbunden und kann Recovery-, Sleep- und Workout-Daten liefern."
    case .failed(let message):
      return message
    }
  }

  var explicitTrainingDays: [Weekday] {
    Weekday.allCases.filter { dayPreference(for: $0) == .training }
  }

  var flexiblePlannerDays: [Weekday] {
    Weekday.allCases.filter { dayPreference(for: $0) == .flexible }
  }

  var availablePlannerDaysCount: Int {
    Weekday.allCases.filter { dayPreference(for: $0) != .rest }.count
  }

  var scheduledPlannerDays: [Weekday] {
    let targetSessions = normalizedSessionsPerWeek(plannerSettings.sessionsPerWeek)
    var scheduledDays = explicitTrainingDays

    if scheduledDays.count < targetSessions {
      for day in flexiblePlannerDays where scheduledDays.count < targetSessions {
        scheduledDays.append(day)
      }
    }

    return scheduledDays
  }

  var autoFilledPlannerDays: [Weekday] {
    scheduledPlannerDays.filter { dayPreference(for: $0) == .flexible }
  }

  var plannerAssignedDaysCount: Int {
    scheduledPlannerDays.filter { assignedWorkoutPlan(for: $0) != nil }.count
  }

  var plannerSummaryHeadline: String {
    let plannedSessions = scheduledPlannerDays.count

    if plannedSessions == 0 {
      return "Aktuell ist keine Trainingseinheit eingeplant."
    }

    return "\(plannedSessions) Tage · Priorität \(plannerSettings.trainingFocus.title)"
  }

  var plannerSummaryDescription: String {
    plannerPrimaryRecommendation.detail
  }

  var plannerPrimaryRecommendation: PlannerRecommendation {
    plannerRecommendations.first
      ?? PlannerRecommendation(
        title: "Plan offen", detail: "Wähle Sessions und Fokus.", weekdays: [])
  }

  var plannerRecommendations: [PlannerRecommendation] {
    let days = scheduledPlannerDays
    guard !days.isEmpty else { return [] }

    switch plannerSettings.trainingFocus {
    case .strength:
      return strengthRecommendations(for: days)
    case .cardio:
      return cardioRecommendations(for: days)
    case .hybrid:
      return hybridRecommendations(for: days)
    }
  }

  var canDecreaseSessionsPerWeek: Bool {
    plannerSettings.sessionsPerWeek > minimumSessionsPerWeek
  }

  var canIncreaseSessionsPerWeek: Bool {
    plannerSettings.sessionsPerWeek < maximumSessionsPerWeek
  }

  var personalRecordCount: Int {
    var runningBest = 0.0
    var personalRecords = 0

    for workout in workoutHistory.sorted(by: { $0.finishedAt < $1.finishedAt })
    where workout.volume > runningBest {
      runningBest = workout.volume
      personalRecords += 1
    }

    return personalRecords
  }

  var trainingDaysCount: Int {
    weeklyWorkoutSchedule.filter { $0.status == .planned }.count
  }

  var restDaysCount: Int {
    weeklyWorkoutSchedule.filter { $0.status == .rest }.count
  }

  var currentWeight: Double {
    if let last = weightTrend.last?.value { return last }
    if let profileWeight = nutritionProfile?.weightKg { return Double(profileWeight) }
    return 0
  }

  var startingWeight: Double {
    startWeight
  }

  var startingWaist: Double {
    startWaist
  }

  var waistChange: Double {
    rounded(startWaist - waistMeasurement)
  }

  var currentCardioRiskImprovement: Int {
    let weightDelta = max(startWeight - currentWeight, 0)
    let activityBonus = Double(weeklySessionsCompleted * 2)
    let trackerBonus = Double(connectedTrackerIDs.count * 3)
    return max(Int((weightDelta * 4.2) + activityBonus + trackerBonus), 0)
  }

  var currentBloodPanelSummary: [HealthMetric] {
    let weightDelta = max(startWeight - currentWeight, 0)
    let ldlValue = max(88, Int(112 - weightDelta * 2.1))
    let hba1cValue = max(4.7, 5.2 - (weightDelta * 0.04))
    let crpValue = max(
      0.6,
      1.1 - (Double(weeklySessionsCompleted) * 0.04) - (Double(connectedTrackerIDs.count) * 0.03))

    return [
      HealthMetric(
        title: "LDL", value: "\(ldlValue)", trend: "-\(max(Int(weightDelta * 2.3), 1))%"),
      HealthMetric(
        title: "HbA1c", value: String(format: "%.1f", hba1cValue),
        trend: String(format: "-%.1f", max(weightDelta * 0.06, 0.1))),
      HealthMetric(
        title: "CRP", value: String(format: "%.1f", crpValue),
        trend: "-\(max(Int(Double(weeklySessionsCompleted) * 6), 8))%"),
    ]
  }

  var currentBloodPanelStatus: String {
    if let healthSnapshot {
      return
        "Schlaf \(formattedSleepHours(healthSnapshot.sleepHoursLastNight)), Aktivität \(healthSnapshot.activeEnergyToday) kcal, Distanz \(String(format: "%.1f", healthSnapshot.distanceWalkingRunningKmToday)) km"
    }

    if connectedTrackerIDs.isEmpty {
      return "Verbinde einen Tracker für laufende Health-Updates"
    }

    if plannerSettings.goal == .fatLoss {
      return "LDL und Entzündungsmarker entwickeln sich in die richtige Richtung"
    }

    if weeklySessionsCompleted >= 3 {
      return "Recovery stabil, Labortrend bleibt trotz Trainingsbelastung sauber"
    }

    return "Mehr Check-ins und verbundene Tracker verbessern die Aussagekraft"
  }

  var currentVitalReadings: [VitalReading] {
    if let healthSnapshot {
      return [
        VitalReading(title: "Schritte", value: "\(healthSnapshot.stepsToday)", context: "heute"),
        VitalReading(
          title: "Herzfrequenz",
          value: formattedOptionalDouble(healthSnapshot.currentHeartRate, suffix: " bpm"),
          context: "zuletzt"),
        VitalReading(
          title: "Schlaf", value: formattedSleepHours(healthSnapshot.sleepHoursLastNight),
          context: "letzte Nacht"),
        VitalReading(
          title: "Ruhepuls",
          value: formattedOptionalDouble(healthSnapshot.restingHeartRate, suffix: " bpm"),
          context: "zuletzt"),
        VitalReading(
          title: "HRV",
          value: formattedOptionalDouble(healthSnapshot.heartRateVariability, suffix: " ms"),
          context: "zuletzt"),
        VitalReading(
          title: "VO2max", value: formattedOptionalDouble(healthSnapshot.vo2Max, suffix: ""),
          context: "zuletzt"),
      ]
    }

    guard !connectedTrackerIDs.isEmpty else {
      return [
        VitalReading(title: "Herzfrequenz", value: "--", context: "WHOOP / Health"),
        VitalReading(title: "Ruhepuls", value: "--", context: "Tracker verbinden"),
        VitalReading(title: "HRV", value: "--", context: "Noch keine Live-Daten"),
        VitalReading(title: "Schlaf", value: "--", context: "Sync ausstehend"),
        VitalReading(title: "VO2max", value: "--", context: "Kommt mit Tracker"),
      ]
    }

    let trainingLoad = Double(weeklySessionsCompleted)
    let syncBonus = Double(vitalSyncCount)
    let heartRate = max(78, 92 - Int(trainingLoad * 3) - connectedTrackerIDs.count)
    let restPulse = max(49, 57 - (connectedTrackerIDs.count * 2) - Int(trainingLoad))
    let hrv = min(84, 66 + Int(trainingLoad * 2) + Int(syncBonus))
    let sleepHours = min(
      8.4,
      7.1 + (Double(completedCoachCheckInIDs.count) * 0.12)
        + (Double(connectedTrackerIDs.count) * 0.08))
    let vo2max = 44.0 + (trainingLoad * 0.35) + (Double(connectedTrackerIDs.count) * 0.4)

    return [
      VitalReading(
        title: "Herzfrequenz", value: "\(heartRate) bpm",
        context: connectedTrackerIDs.count > 1 ? "mehrere Quellen" : "Tracker-Wert"),
      VitalReading(
        title: "Ruhepuls", value: "\(restPulse) bpm",
        context: vitalSyncCount == 0 ? "heute früh" : "gerade synchronisiert"),
      VitalReading(
        title: "HRV", value: "\(hrv) ms",
        context: trainingLoad >= 3 ? "Recovery gut" : "Recovery stabil"),
      VitalReading(
        title: "Schlaf", value: String(format: "%.1fh", sleepHours),
        context: !completedCoachCheckInIDs.isEmpty ? "letzte Nacht" : "geschätzt"),
      VitalReading(
        title: "VO2max", value: String(format: "%.1f", vo2max),
        context: connectedTrackerIDs.count > 1 ? "mehrere Quellen" : "Tracker-Wert"),
    ]
  }

  var currentGoals: [ProgressGoal] {
    [
      ProgressGoal(title: "Körpergewicht", current: currentWeight, target: 90.0, unit: "kg"),
      ProgressGoal(title: "Taillenumfang", current: waistMeasurement, target: 86.0, unit: "cm"),
      ProgressGoal(title: "Protein-Ziel", current: proteinProgress, target: 190.0, unit: "g"),
    ]
  }

  var studyBackedRecommendations: [TrainingRecommendation] {
    guard studyBasedCoachingEnabled else { return [] }

    switch plannerSettings.goal {
    case .muscleGain:
      return [
        TrainingRecommendation(
          title: "Kraft zuerst priorisieren",
          scenario: "Wenn Muskelaufbau dein Hauptziel ist",
          recommendation:
            "Plane 3 bis 4 Krafteinheiten mit progressiver Überlastung und ergänze 1 bis 2 lockere Cardio-Sessions für Herz-Kreislauf-Fitness und Recovery.",
          sources: [
            EvidenceSource(
              title: "Concurrent Strength and Endurance Training",
              context:
                "Sports Medicine, Februar 2024: Concurrent Training ist möglich, aber bei Muskelaufbau sollte Kraft klar priorisiert bleiben.",
              link: "https://pubmed.ncbi.nlm.nih.gov/37847373/"
            ),
            EvidenceSource(
              title: "Proximity to Failure Meta-Regression",
              context:
                "Sports Medicine, September 2024: Für Kraft- und Hypertrophieziele bleiben harte, sauber gesteuerte Kraftsätze zentral.",
              link: "https://pubmed.ncbi.nlm.nih.gov/38970765/"
            ),
          ]
        )
      ]
    case .fatLoss:
      return [
        TrainingRecommendation(
          title: "Kraft plus Cardio kombinieren",
          scenario: "Wenn Abnehmen und Körperkomposition im Fokus stehen",
          recommendation:
            "Nutze 2 bis 3 Krafteinheiten zum Muskelerhalt plus 2 bis 4 Cardio-Einheiten oder hohe Alltagsbewegung. Reines Cardio allein ist meist nicht die beste langfristige Lösung.",
          sources: [
            EvidenceSource(
              title: "WHO Physical Activity Fact Sheet",
              context:
                "WHO, 26. Juni 2024: Erwachsene sollen sowohl Ausdauer als auch muskelstärkende Einheiten einbauen.",
              link: "https://www.who.int/news-room/fact-sheets/detail/physical-activity"
            ),
            EvidenceSource(
              title: "Aerobic Exercise and Weight Loss in Adults",
              context:
                "JAMA Network Open, Dezember 2024: Aerobes Training unterstützt Gewichtsverlust dosisabhängig.",
              link: "https://pubmed.ncbi.nlm.nih.gov/39724371/"
            ),
            EvidenceSource(
              title: "Inflammatory Markers in Overweight or Obese Adults",
              context:
                "Systematic Review, November 2024: Kombinierte Trainingsformen sind für metabolische Marker bei Übergewicht sinnvoll.",
              link: "https://pubmed.ncbi.nlm.nih.gov/39758295/"
            ),
          ]
        )
      ]
    case .performance:
      return [
        TrainingRecommendation(
          title: "Kombi-Ansatz für Leistung und Herz-Kreislauf-System",
          scenario: "Wenn Leistungsfähigkeit und Ausdauer gemeinsam steigen sollen",
          recommendation:
            "Halte 2 bis 3 strukturierte Krafteinheiten und 2 bis 3 Cardio-Einheiten. Wenn Blutdruck, VO2max oder metabolische Marker wichtiger werden, bekommt Kardiotraining mehr Priorität.",
          sources: [
            EvidenceSource(
              title: "Effect of aerobic versus resistance training",
              context:
                "Systematic Review, 2024: Aerobes Training verbessert Cardio-Fitness stärker, Krafttraining schützt stärker Kraft und Körperzusammensetzung.",
              link: "https://pubmed.ncbi.nlm.nih.gov/38878596/"
            ),
            EvidenceSource(
              title: "Exercise Prescription in Individuals with Prehypertension and Hypertension",
              context:
                "Systematic Review and Meta-analysis, März 2024: Bei Blutdruck-Themen ist strukturiertes Ausdauer- oder kombiniertes Training besonders relevant.",
              link: "https://pubmed.ncbi.nlm.nih.gov/39076557/"
            ),
            EvidenceSource(
              title: "Concurrent training in type 2 diabetes",
              context:
                "BMJ Open Diabetes Research & Care, November 2024: Kombinierte Trainingsprogramme zeigen metabolische Vorteile.",
              link: "https://pubmed.ncbi.nlm.nih.gov/39608858/"
            ),
          ]
        )
      ]
    }
  }

  var progressSummaryHeadline: String {
    if let bodyMassKg = healthSnapshot?.bodyMassKg {
      return "Apple Health liefert \(String(format: "%.1f", bodyMassKg)) kg als aktuellen Wert"
    }

    let weightChange = rounded(startWeight - currentWeight)

    if weightChange > 0.2 {
      return "\(String(format: "%.1f", weightChange)) kg Fortschritt seit dem Start"
    }

    if connectedTrackerCount > 0 {
      return "\(connectedTrackerCount) Tracker liefern jetzt Health-Daten in Gains"
    }

    return "Dein Progress startet mit jedem Check-in"
  }

  var progressSummaryDescription: String {
    if let healthSnapshot {
      return
        "\(healthSnapshot.stepsToday) Schritte · \(healthSnapshot.exerciseMinutesToday) Min Training · \(healthSnapshot.activeEnergyToday) kcal aktiv"
    }

    if goalCompletionCount == currentGoals.count {
      return
        "Alle aktiven Ziele sind aktuell erfüllt. Halte den Rhythmus mit weiteren Check-ins und Workouts."
    }

    if connectedTrackerCount == 0 {
      return
        "Verbinde einen Tracker oder logge Check-ins, damit Gewicht, Vitals und Health-Impact sichtbar reagieren."
    }

    return
      "\(goalCompletionCount) von \(currentGoals.count) Zielen liegen aktuell auf Kurs. Jede neue Session und jeder Check-in fließt direkt ein."
  }

  var goalCompletionCount: Int {
    currentGoals.filter { goalProgress(for: $0) >= 1 }.count
  }

  var currentMilestones: [ProgressMilestone] {
    var milestones: [ProgressMilestone] = []

    if let workout = lastCompletedWorkout {
      milestones.append(
        ProgressMilestone(
          title: "\(workout.title) abgeschlossen",
          detail:
            "\(workout.completedSets)/\(workout.totalSets) Sätze und \(Int(workout.volume)) kg Volumen geloggt",
          dateLabel: milestoneLabel(for: workout.finishedAt)
        )
      )
    }

    if !connectedTrackerIDs.isEmpty {
      milestones.append(
        ProgressMilestone(
          title: "\(connectedTrackerIDs.count) Tracker verbunden",
          detail: "Vitaldaten und Recovery-Signale aktualisieren sich jetzt direkt in Gains",
          dateLabel: milestoneLabel(for: Date())
        )
      )
    }

    if joinedChallenge {
      milestones.append(
        ProgressMilestone(
          title: "Community-Challenge aktiv",
          detail: "Deine Progress-Posts und Workout-Updates zählen jetzt in die laufende Challenge",
          dateLabel: milestoneLabel(for: Date())
        )
      )
    }

    milestones.append(contentsOf: baseMilestones)
    return Array(milestones.prefix(4))
  }

  var challengeParticipantsCount: Int {
    baseChallengeParticipants + (joinedChallenge ? 1 : 0)
  }

  var canRequestContactsAccess: Bool {
    contactsAccessStatus == .notDetermined
  }

  var hasContactsAccess: Bool {
    contactsAccessStatus == .authorized
  }

  var contactsStatusTitle: String {
    switch contactsAccessStatus {
    case .authorized:
      return communityContacts.isEmpty
        ? "Noch keine Kontakte gefunden"
        : "\(communityContacts.count) Kontakte für die Community gefunden"
    case .notDetermined:
      return "Kontakte für die Community freigeben"
    case .denied, .restricted:
      return "Kontakte aktuell nicht verfügbar"
    default:
      return "Kontakte werden vorbereitet"
    }
  }

  var contactsStatusDescription: String {
    switch contactsAccessStatus {
    case .authorized:
      return communityContacts.isEmpty
        ? "Sobald passende Kontakte vorhanden sind, zeigt Gains sie dir hier als mögliche Community-Verbindungen."
        : "Diese Kontakte kannst du später für Challenges, Follows oder gemeinsame Aktivitäten nutzen."
    case .notDetermined:
      return
        "Gains kann deine Kontakte lokal lesen und sie im Community-Tab als mögliche Fitness-Kontakte anzeigen."
    case .denied, .restricted:
      return
        "Aktiviere den Kontakte-Zugriff in den iPhone-Einstellungen, wenn du Freunde und bekannte Personen hier sehen möchtest."
    default:
      return "Gains prüft gerade den Zugriff auf deine Kontakte."
    }
  }

  var totalCommunityLikes: Int {
    communityPosts.reduce(0) { $0 + $1.reactions } + likedPostIDs.count
  }

  var totalCommunityComments: Int {
    communityPosts.reduce(0) { $0 + $1.comments } + commentedPostIDs.count
  }

  var totalCommunityShares: Int {
    communityPosts.reduce(0) { $0 + $1.shares } + sharedPostIDs.count
  }

  var communityHighlightHeadline: String {
    if let ownPost = communityPosts.first(where: { $0.handle == "@julius.gains" }) {
      return "Dein letzter Post: \(ownPost.title)"
    }

    if joinedChallenge {
      return "Du bist in der Challenge und siehst \(communityPosts.count) aktuelle Updates"
    }

    return "Community lebt: \(communityPosts.count) Posts im Feed"
  }

  var communityHighlightDescription: String {
    "\(likedPostIDs.count) Likes gesetzt · \(commentedPostIDs.count) Kommentare · \(sharedPostIDs.count) Shares"
  }

  var coachHeadline: String {
    if let activeWorkout {
      return
        "Coach sagt: \(activeWorkout.completedSets) von \(activeWorkout.totalSets) Sätzen sind erledigt"
    }

    if !completedCoachCheckInIDs.isEmpty {
      let count = completedCoachCheckInIDs.count
      return "Coach sagt: \(count) \(count == 1 ? "Tagesziel" : "Tagesziele") abgehakt"
    }

    if let workout = lastCompletedWorkout {
      return "Coach sagt: Letzter Stand — \(workout.title), \(workout.completedSets) Sätze"
    }

    return "Coach sagt: Starte dein erstes Training, dann passe ich mich an dich an"
  }

  var coachDescription: String {
    switch plannerSettings.goal {
    case .fatLoss:
      return
        "Fokus bleibt auf Defizit, Schritten und kontrollierter Trainingsleistung. Jeder Workout-Log fließt direkt in deinen Progress."
    case .muscleGain:
      return
        "Volumen und Proteinziel priorisieren. Deine Workouts und Mahlzeiten treiben jetzt sichtbar den Aufbau voran."
    case .performance:
      return
        "Leistung steht im Mittelpunkt. Halte die Session-Qualität hoch und nutze Tracker-Daten für saubere Recovery."
    }
  }

  var homeWeekDays: [DayProgress] {
    let calendar = Calendar.current
    let weekReference =
      calendar.date(byAdding: .weekOfYear, value: calendarWeekOffset, to: Date()) ?? Date()
    let referenceDate = startOfWeek(for: weekReference)
    let scheduledDays = Set(scheduledPlannerDays)

    return Weekday.allCases.enumerated().map { offset, weekday in
      let dayDate = calendar.date(byAdding: .day, value: offset, to: referenceDate) ?? Date()
      let normalizedDay = normalizedDate(dayDate)
      let isCompleted = completedCalendarDates.contains(normalizedDay)
      let status: DayProgress.Status

      if isCompleted {
        status = .completed
      } else if calendar.isDateInToday(dayDate) {
        status = .today
      } else if scheduledDays.contains(weekday) {
        status = .planned
      } else if dayPreference(for: weekday) == .flexible {
        status = .flexible
      } else {
        status = .rest
      }

      return DayProgress(
        date: normalizedDay,
        shortLabel: weekday.shortLabel,
        dayNumber: calendar.component(.day, from: dayDate),
        status: status
      )
    }
  }

  var selectedCalendarDay: DayProgress? {
    homeWeekDays.first(where: {
      Calendar.current.isDate($0.date, inSameDayAs: selectedCalendarDate)
    })
  }

  var selectedCalendarDayIsCompleted: Bool {
    completedCalendarDates.contains(normalizedDate(selectedCalendarDate))
  }

  var canToggleSelectedCalendarDate: Bool {
    normalizedDate(selectedCalendarDate) <= normalizedDate(Date())
  }

  var calendarWeekTitle: String {
    let start = startOfWeek(
      for: Calendar.current.date(byAdding: .weekOfYear, value: calendarWeekOffset, to: Date())
        ?? Date())
    let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateFormat = "dd. MMM"
    return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
  }

  var selectedCalendarHeadline: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateFormat = "EEEE, dd. MMMM"
    return formatter.string(from: selectedCalendarDate).capitalized
  }

  var selectedCalendarDescription: String {
    if selectedCalendarDayIsCompleted {
      return "Dieser Tag zählt aktuell zu deiner Streak und ist als erledigt markiert."
    }

    if let selectedDay = selectedCalendarDay {
      switch selectedDay.status {
      case .planned:
        let weekday = weekday(for: selectedCalendarDate)
        if let workout = weeklyWorkoutSchedule.first(where: { $0.weekday == weekday })?.workoutPlan
        {
          return "Geplant: \(workout.title)."
        }
        return "Training ist für diesen Tag eingeplant."
      case .flexible:
        return "Flex-Tag für Cardio, Mobility oder Extra-Session."
      case .rest:
        return "Freier Tag laut Trainingsplan."
      case .today:
        return
          "Heute ist noch offen. Du kannst den Tag nach deinem Training oder Check-in als erledigt markieren."
      case .completed:
        return "Dieser Tag zählt aktuell zu deiner Streak und ist als erledigt markiert."
      }
    }

    if Calendar.current.isDateInToday(selectedCalendarDate) {
      return
        "Heute ist noch offen. Du kannst den Tag nach deinem Training oder Check-in als erledigt markieren."
    }

    if normalizedDate(selectedCalendarDate) > normalizedDate(Date()) {
      return
        "Zukünftige Tage kannst du noch nicht abschließen. Nutze sie als Orientierung für deine Woche."
    }

    return
      "Für diesen Tag ist aktuell keine Aktivität markiert. Du kannst ihn bei Bedarf manuell als erledigt setzen."
  }

  func startWorkout(from plan: WorkoutPlan) {
    if activeWorkout == nil {
      activeWorkout = WorkoutSession.fromPlan(plan)
    }
  }

  func startQuickWorkout() {
    guard activeWorkout == nil else { return }
    let plan = todayPlannedWorkout ?? savedWorkoutPlans.first ?? currentWorkoutPreview
    activeWorkout = WorkoutSession.fromPlan(plan)
  }

  func discardWorkout() {
    activeWorkout = nil
  }

  func startRun(from template: RunTemplate) {
    guard activeRun == nil else { return }
    activeRun = ActiveRunSession.fromTemplate(template)
  }

  func startQuickRun() {
    startRun(from: runningTemplates[0])
  }

  func startRunLike(_ run: CompletedRunSummary) {
    guard activeRun == nil else { return }
    activeRun = ActiveRunSession(
      id: UUID(),
      title: run.title,
      routeName: run.routeName,
      startedAt: Date(),
      targetDistanceKm: run.distanceKm,
      targetDurationMinutes: run.durationMinutes,
      targetPaceLabel: formattedPace(secondsPerKilometer: run.averagePaceSeconds),
      distanceKm: 0,
      durationMinutes: 0,
      elevationGain: 0,
      currentHeartRate: max(run.averageHeartRate - 8, 120),
      isPaused: false,
      routeCoordinates: [],
      splits: []
    )
  }

  func discardRun() {
    activeRun = nil
  }

  func toggleRunPause() {
    activeRun?.isPaused.toggle()
  }

  func addRunDistance(_ distance: Double) {
    guard activeRun != nil else { return }
    activeRun?.distanceKm = rounded(max(0, (activeRun?.distanceKm ?? 0) + distance))
  }

  func addRunDuration(_ minutes: Int) {
    guard activeRun != nil else { return }
    activeRun?.durationMinutes = max(0, (activeRun?.durationMinutes ?? 0) + minutes)
  }

  func addRunElevation(_ meters: Int) {
    guard activeRun != nil else { return }
    activeRun?.elevationGain = max(0, (activeRun?.elevationGain ?? 0) + meters)
  }

  func adjustRunHeartRate(by delta: Int) {
    guard activeRun != nil else { return }
    activeRun?.currentHeartRate = min(max((activeRun?.currentHeartRate ?? 140) + delta, 96), 198)
  }

  /// Setzt die aktuelle Herzfrequenz direkt aus einem HealthKit-Live-Wert.
  /// Klemmt auf physiologisch sinnvolle Grenzen (40–220 bpm).
  func updateRunHeartRateLive(_ bpm: Int) {
    guard activeRun != nil else { return }
    activeRun?.currentHeartRate = min(max(bpm, 40), 220)
  }

  /// Setzt die aktuelle Herzfrequenz für das aktive Workout (Live Gym).
  @Published var liveWorkoutHeartRate: Int? = nil

  func syncActiveRunGPS(
    distanceKm: Double, durationMinutes: Int, elevationGain: Int,
    routeCoordinates: [CLLocationCoordinate2D], splits: [RunSplit]
  ) {
    guard activeRun != nil else { return }
    activeRun?.distanceKm = rounded(max(distanceKm, 0))
    activeRun?.durationMinutes = max(durationMinutes, 0)
    activeRun?.elevationGain = max(elevationGain, 0)
    activeRun?.routeCoordinates = routeCoordinates
    activeRun?.splits = splits
  }

  func addRunSplit(
    distance: Double = 0.5, durationMinutes: Int = 3, elevation: Int = 8, heartRate: Int = 0
  ) {
    guard let run = activeRun, !run.isPaused else { return }
    addRunDistance(distance)
    addRunDuration(durationMinutes)
    addRunElevation(elevation)

    if heartRate != 0 {
      adjustRunHeartRate(by: heartRate)
    } else if let currentHeartRate = activeRun?.currentHeartRate {
      activeRun?.currentHeartRate = min(max(currentHeartRate + Int.random(in: -2...3), 108), 182)
    }

    if let updatedRun = activeRun {
      let split = RunSplit(
        id: UUID(),
        index: updatedRun.splits.count + 1,
        distanceKm: distance,
        durationMinutes: durationMinutes,
        averageHeartRate: updatedRun.currentHeartRate
      )
      activeRun?.splits.append(split)
    }
  }

  func finishRun() {
    guard let run = activeRun, run.distanceKm > 0 else { return }

    let summary = CompletedRunSummary(
      id: UUID(),
      title: run.title,
      routeName: run.routeName,
      finishedAt: Date(),
      distanceKm: run.distanceKm,
      durationMinutes: run.durationMinutes,
      elevationGain: run.elevationGain,
      averageHeartRate: run.currentHeartRate,
      routeCoordinates: run.routeCoordinates,
      splits: run.splits
    )

    registerCompletedDay(summary.finishedAt)
    applyRunProgress(from: summary)
    runHistory.insert(summary, at: 0)
    activeRun = nil
    lastProgressEvent =
      "Lauf gespeichert: \(String(format: "%.1f", summary.distanceKm)) km mit \(formattedPace(secondsPerKilometer: summary.averagePaceSeconds))."

    if socialSharingSettings.autoShareRuns {
      shareLatestRun()
    }

    saveAll()
  }

  @discardableResult
  func saveWorkout(named name: String, split: String, exercises: [ExerciseLibraryItem])
    -> WorkoutPlan?
  {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty, !exercises.isEmpty else { return nil }

    let workout = WorkoutPlan.custom(title: trimmedName, split: split, exercises: exercises)
    savedWorkoutPlans.insert(workout, at: 0)
    saveAll()
    return workout
  }

  func deleteWorkout(_ plan: WorkoutPlan) {
    savedWorkoutPlans.removeAll(where: { $0.id == plan.id })
    // Remove day assignments that referenced this workout
    for weekday in plannerSettings.dayAssignments.keys {
      if plannerSettings.dayAssignments[weekday] == plan.id {
        plannerSettings.dayAssignments[weekday] = nil
      }
    }
    saveAll()
  }

  func updateWorkout(
    _ plan: WorkoutPlan, named name: String, split: String, exercises: [ExerciseLibraryItem]
  ) -> WorkoutPlan? {
    guard
      let index = savedWorkoutPlans.firstIndex(where: { $0.id == plan.id }),
      !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !exercises.isEmpty
    else { return nil }
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let updated = WorkoutPlan.custom(title: trimmedName, split: split, exercises: exercises)
    // Preserve the original id so day-assignments stay intact
    let preserved = WorkoutPlan(
      id: plan.id,
      source: .custom,
      title: updated.title,
      focus: updated.focus,
      split: updated.split,
      estimatedDurationMinutes: updated.estimatedDurationMinutes,
      exercises: updated.exercises
    )
    savedWorkoutPlans[index] = preserved
    saveAll()
    return preserved
  }

  func updateSessionsPerWeek(_ value: Int) {
    let desiredDays = min(max(value, 1), 7)
    rebalancePlannerAvailability(for: desiredDays)
    plannerSettings.sessionsPerWeek = normalizedSessionsPerWeek(desiredDays)
    saveAll()
  }

  func setPlannerGoal(_ goal: WorkoutPlanningGoal) {
    plannerSettings.goal = goal
    saveAll()
  }

  func setTrainingFocus(_ focus: WorkoutTrainingFocus) {
    plannerSettings.trainingFocus = focus
    saveAll()
  }

  func setPreferredSessionLength(_ duration: Int) {
    plannerSettings.preferredSessionLength = duration
    saveAll()
  }

  // MARK: - Studienbasierte Planner-Setter

  func setTrainingExperience(_ value: TrainingExperience) {
    plannerSettings.experience = value
    saveAll()
  }

  func setGymEquipment(_ value: GymEquipment) {
    plannerSettings.equipment = value
    saveAll()
  }

  func setSplitPreference(_ value: SplitPreference) {
    plannerSettings.splitPreference = value
    saveAll()
  }

  func setRecoveryCapacity(_ value: RecoveryCapacity) {
    plannerSettings.recoveryCapacity = value
    saveAll()
  }

  func toggleMusclePriority(_ muscle: MuscleGroup) {
    if plannerSettings.prioritizedMuscles.contains(muscle) {
      plannerSettings.prioritizedMuscles.remove(muscle)
    } else {
      plannerSettings.prioritizedMuscles.insert(muscle)
    }
    saveAll()
  }

  func toggleLimitation(_ limitation: WorkoutLimitation) {
    if plannerSettings.limitations.contains(limitation) {
      plannerSettings.limitations.remove(limitation)
    } else {
      plannerSettings.limitations.insert(limitation)
    }
    saveAll()
  }

  func setRunningGoal(_ goal: RunningGoal) {
    plannerSettings.runningGoal = goal
    // Wenn der User explizit ein Lauf-Ziel setzt, schlagen wir den passenden km-Wert vor,
    // sofern er noch beim Default ist oder darunterliegt.
    if plannerSettings.weeklyKilometerTarget < goal.defaultWeeklyKilometers {
      plannerSettings.weeklyKilometerTarget = goal.defaultWeeklyKilometers
    }
    saveAll()
  }

  /// Wendet alle Wizard-Einstellungen auf einmal an und setzt alle Wochentage
  /// auf `.flexible`, damit die Engine die optimale Verteilung übernimmt.
  func applyWizardSettings(
    focus: WorkoutTrainingFocus,
    goal: WorkoutPlanningGoal,
    experience: TrainingExperience,
    equipment: GymEquipment,
    sessionsPerWeek: Int,
    sessionLength: Int,
    recovery: RecoveryCapacity,
    prioritizedMuscles: Set<MuscleGroup>,
    limitations: Set<WorkoutLimitation>,
    runningGoal: RunningGoal
  ) {
    plannerSettings.trainingFocus      = focus
    plannerSettings.goal               = goal
    plannerSettings.experience         = experience
    plannerSettings.equipment          = equipment
    plannerSettings.sessionsPerWeek    = normalizedSessionsPerWeek(sessionsPerWeek)
    plannerSettings.preferredSessionLength = sessionLength
    plannerSettings.recoveryCapacity   = recovery
    plannerSettings.splitPreference    = .auto
    plannerSettings.prioritizedMuscles = prioritizedMuscles
    plannerSettings.limitations        = limitations
    plannerSettings.runningGoal        = runningGoal
    if plannerSettings.weeklyKilometerTarget < runningGoal.defaultWeeklyKilometers {
      plannerSettings.weeklyKilometerTarget = runningGoal.defaultWeeklyKilometers
    }
    // Alle Tage auf flexible setzen – die Engine verteilt automatisch
    for day in Weekday.allCases {
      plannerSettings.dayPreferences[day] = .flexible
    }
    saveAll()
  }

  func setRunIntensityModel(_ model: RunIntensityModel) {
    plannerSettings.runIntensityModel = model
    saveAll()
  }

  func setWeeklyKilometerTarget(_ km: Int) {
    plannerSettings.weeklyKilometerTarget = max(0, min(150, km))
    saveAll()
  }

  func cycleDayPreference(_ weekday: Weekday) {
    switch dayPreference(for: weekday) {
    case .training:
      plannerSettings.dayPreferences[weekday] = .rest
    case .rest:
      plannerSettings.dayPreferences[weekday] = .flexible
    case .flexible:
      plannerSettings.dayPreferences[weekday] = .training
    }

    alignSessionTargetToAvailableDays()
    saveAll()
  }

  func assignedWorkoutPlan(for weekday: Weekday) -> WorkoutPlan? {
    guard let planID = plannerSettings.dayAssignments[weekday] else { return nil }
    return savedWorkoutPlans.first(where: { $0.id == planID })
  }

  func assignWorkout(_ plan: WorkoutPlan, to weekday: Weekday) {
    plannerSettings.dayAssignments[weekday] = plan.id

    if dayPreference(for: weekday) == .rest {
      plannerSettings.dayPreferences[weekday] = .training
    }

    alignSessionTargetToAvailableDays()
    saveAll()
  }

  func clearAssignedWorkout(for weekday: Weekday) {
    plannerSettings.dayAssignments[weekday] = nil
    saveAll()
  }

  func dayPreference(for weekday: Weekday) -> WorkoutDayPreference {
    plannerSettings.dayPreferences[weekday] ?? .flexible
  }

  func isScheduledWorkoutDay(_ weekday: Weekday) -> Bool {
    scheduledPlannerDays.contains(weekday)
  }

  func selectCalendarDay(_ date: Date) {
    selectedCalendarDate = normalizedDate(date)
  }

  func showPreviousCalendarWeek() {
    calendarWeekOffset -= 1
    selectedCalendarDate = startOfWeek(
      for: Calendar.current.date(byAdding: .weekOfYear, value: calendarWeekOffset, to: Date())
        ?? Date())
  }

  func showNextCalendarWeek() {
    calendarWeekOffset += 1
    selectedCalendarDate = startOfWeek(
      for: Calendar.current.date(byAdding: .weekOfYear, value: calendarWeekOffset, to: Date())
        ?? Date())
  }

  func showCurrentCalendarWeek() {
    calendarWeekOffset = 0
    selectedCalendarDate = normalizedDate(Date())
  }

  func toggleSelectedCalendarDayCompletion() {
    guard canToggleSelectedCalendarDate else { return }
    toggleCalendarCompletion(on: selectedCalendarDate)
    saveAll()
  }

  func finishWorkout() {
    guard let workout = activeWorkout else { return }

    let summary = CompletedWorkoutSummary(
      title: workout.title,
      finishedAt: Date(),
      completedSets: workout.completedSets,
      totalSets: workout.totalSets,
      volume: workout.totalVolume,
      exercises: workout.exercises.map { exercise in
        let completedSets = exercise.sets.filter(\.isCompleted)
        let topWeight = completedSets.map(\.weight).max() ?? 0
        let totalReps = completedSets.reduce(0) { $0 + $1.reps }
        let totalVolume = completedSets.reduce(0.0) { $0 + ($1.weight * Double($1.reps)) }

        return CompletedExercisePerformance(
          name: exercise.name,
          completedSets: completedSets.count,
          totalReps: totalReps,
          topWeight: topWeight,
          totalVolume: totalVolume
        )
      }
    )

    registerCompletedDay(summary.finishedAt)
    applyWorkoutProgress(from: summary)

    lastCompletedWorkout = summary
    workoutHistory.insert(summary, at: 0)
    activeWorkout = nil

    // Auto-Share, falls in den Social-Settings aktiviert
    if socialSharingSettings.autoShareWorkouts {
      shareLatestWorkout()
    }
    detectAndShareNewPRs(from: summary)

    saveAll()
  }

  func toggleSet(exerciseID: UUID, setID: UUID) {
    guard let exerciseIndex = activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseID }),
      let setIndex = activeWorkout?.exercises[exerciseIndex].sets.firstIndex(where: {
        $0.id == setID
      })
    else {
      return
    }

    activeWorkout?.exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
  }

  func updateSet(exerciseID: UUID, setID: UUID, reps: Int? = nil, weight: Double? = nil) {
    guard let exerciseIndex = activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseID }),
      let setIndex = activeWorkout?.exercises[exerciseIndex].sets.firstIndex(where: {
        $0.id == setID
      })
    else {
      return
    }

    if let reps {
      activeWorkout?.exercises[exerciseIndex].sets[setIndex].reps = max(0, reps)
    }

    if let weight {
      activeWorkout?.exercises[exerciseIndex].sets[setIndex].weight = max(0, weight)
    }
  }

  func reorderActiveExercises(from source: IndexSet, to destination: Int) {
    activeWorkout?.exercises.move(fromOffsets: source, toOffset: destination)
  }

  func removeActiveExercise(id: UUID) {
    activeWorkout?.exercises.removeAll { $0.id == id }
  }

  func appendActiveExercise(from item: ExerciseLibraryItem) {
    guard activeWorkout != nil else { return }
    let sets: [TrackedSet] = (0..<max(item.defaultSets, 1)).map { index in
      TrackedSet(
        order: index + 1,
        reps: item.defaultReps,
        weight: item.suggestedWeight,
        isCompleted: false
      )
    }
    let tracked = TrackedExercise(name: item.name, targetMuscle: item.primaryMuscle, sets: sets)
    activeWorkout?.exercises.append(tracked)
  }

  func addSet(to exerciseID: UUID) {
    guard let exerciseIndex = activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseID })
    else { return }
    let existingSets = activeWorkout?.exercises[exerciseIndex].sets ?? []
    let reference = existingSets.last
    let newOrder = (existingSets.last?.order ?? 0) + 1
    let newSet = TrackedSet(
      order: newOrder,
      reps: reference?.reps ?? 8,
      weight: reference?.weight ?? 0,
      isCompleted: false
    )
    activeWorkout?.exercises[exerciseIndex].sets.append(newSet)
  }

  func removeLastSet(from exerciseID: UUID) {
    guard let exerciseIndex = activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseID }),
      (activeWorkout?.exercises[exerciseIndex].sets.count ?? 0) > 1
    else { return }
    activeWorkout?.exercises[exerciseIndex].sets.removeLast()
  }

  func toggleCoachCheckIn(_ id: UUID) {
    if completedCoachCheckInIDs.contains(id) {
      completedCoachCheckInIDs.remove(id)
    } else {
      completedCoachCheckInIDs.insert(id)
    }
  }

  func toggleChallengeJoined() {
    joinedChallenge.toggle()
    saveAll()
  }

  func toggleLike(postID: UUID) {
    if likedPostIDs.contains(postID) {
      likedPostIDs.remove(postID)
    } else {
      likedPostIDs.insert(postID)
    }
  }

  func toggleComment(postID: UUID) {
    if commentedPostIDs.contains(postID) {
      commentedPostIDs.remove(postID)
    } else {
      commentedPostIDs.insert(postID)
    }
  }

  func toggleShare(postID: UUID) {
    if sharedPostIDs.contains(postID) {
      sharedPostIDs.remove(postID)
    } else {
      sharedPostIDs.insert(postID)
    }
  }

  func createCommunityPost(from action: CommunityComposerAction) {
    let newPost: CommunityPost

    switch action.type {
    case .workout:
      let workout = lastCompletedWorkout
      let plan = currentWorkoutPreview
      let volumeLabel =
        workout.map { "\(Int($0.volume / 1000)) t" }
        ?? String(format: "%.1f t", Double(plan.exercises.count) * 2.1)

      newPost = CommunityPost(
        id: UUID(),
        author: "Julius",
        handle: "@julius.gains",
        type: .workout,
        title: workout?.title ?? "\(plan.title) eingeplant",
        detail: workout == nil
          ? "Heute mein Workout in Gains geplant und direkt sauber strukturiert."
          : "Session fertig geloggt. Alle Sätze sind drin und das Volumen passt zum Wochenziel.",
        timeAgo: "gerade eben",
        placeholderSymbol: "dumbbell.fill",
        highlightMetrics: [
          CommunityMetric(label: "Volumen", value: volumeLabel),
          CommunityMetric(
            label: "Sätze",
            value: "\(workout?.completedSets ?? plan.exercises.reduce(0) { $0 + $1.sets.count })"),
          CommunityMetric(label: "Dauer", value: "\(plannerSettings.preferredSessionLength) Min"),
        ],
        reactions: 0,
        comments: 0,
        shares: 0
      )
    case .run:
      let latestRun = latestCompletedRun
      newPost = CommunityPost(
        id: UUID(),
        author: "Julius",
        handle: "@julius.gains",
        type: .run,
        title: latestRun?.title ?? "Cardio-Check-in geloggt",
        detail: latestRun == nil
          ? (connectedTrackerIDs.isEmpty
            ? "Noch ohne verbundenen Tracker, aber die Cardio-Session ist für heute eingeplant."
            : "Tracker ist verbunden und die Cardio-Daten fließen direkt in meinen Progress.")
          : "Lauf in Gains gespeichert und direkt mit Pace, Höhenmetern und Herzfrequenz in die Community geteilt.",
        timeAgo: "gerade eben",
        placeholderSymbol: "figure.run",
        highlightMetrics: [
          CommunityMetric(
            label: "Distanz",
            value: latestRun.map { String(format: "%.1f km", $0.distanceKm) }
              ?? (connectedTrackerIDs.isEmpty ? "5.0 km" : "6.4 km")),
          CommunityMetric(
            label: "Pace",
            value: latestRun.map { formattedPace(secondsPerKilometer: $0.averagePaceSeconds) }
              ?? (connectedTrackerIDs.isEmpty ? "5:35 /km" : "5:12 /km")),
          CommunityMetric(
            label: "HF",
            value: latestRun.map { "\($0.averageHeartRate) bpm" }
              ?? (connectedTrackerIDs.isEmpty ? "152 bpm" : "146 bpm")),
        ],
        reactions: 0,
        comments: 0,
        shares: 0
      )
    case .progress:
      newPost = CommunityPost(
        id: UUID(),
        author: "Julius",
        handle: "@julius.gains",
        type: .progress,
        title: "Neues Progress-Update",
        detail:
          "Mein aktueller Check-in zeigt, wie Gewicht, Taille und Risiko-Score sich gemeinsam verbessern.",
        timeAgo: "gerade eben",
        placeholderSymbol: "chart.line.uptrend.xyaxis",
        highlightMetrics: [
          CommunityMetric(label: "Gewicht", value: String(format: "%.1f kg", currentWeight)),
          CommunityMetric(label: "Taille", value: String(format: "%.1f cm", waistMeasurement)),
          CommunityMetric(label: "Risiko", value: "-\(currentCardioRiskImprovement)%"),
        ],
        reactions: 0,
        comments: 0,
        shares: 0
      )
    case .all:
      return
    }

    communityPosts.insert(newPost, at: 0)
  }

  func shareLatestWorkout() {
    createCommunityPost(
      from: CommunityComposerAction(
        title: "Workout teilen",
        type: .workout,
        systemImage: "dumbbell.fill"
      )
    )
  }

  func toggleFavoriteRecipe(_ recipeID: UUID) {
    if favoriteRecipeIDs.contains(recipeID) {
      favoriteRecipeIDs.remove(recipeID)
    } else {
      favoriteRecipeIDs.insert(recipeID)
      proteinProgress = min(220, rounded(proteinProgress + 2))
    }
    saveAll()
  }

  func toggleTrackerConnection(_ trackerID: UUID) {
    if trackerID == appleHealthTrackerID {
      toggleAppleHealthConnection()
      return
    }

    if trackerID == whoopTrackerID {
      toggleWhoopConnection()
      return
    }

    if connectedTrackerIDs.contains(trackerID) {
      connectedTrackerIDs.remove(trackerID)
      lastProgressEvent =
        "Tracker getrennt. Live-Vitals werden für diese Quelle nicht mehr aktualisiert."
    } else {
      connectedTrackerIDs.insert(trackerID)
      syncVitalData()
      lastProgressEvent =
        "Tracker verbunden. Deine Vitaldaten werden jetzt im Progress-Bereich aktualisiert."
    }
    saveAll()
  }

  private func toggleAppleHealthConnection() {
    guard let appleHealthTrackerID else { return }

    if connectedTrackerIDs.contains(appleHealthTrackerID) {
      connectedTrackerIDs.remove(appleHealthTrackerID)
      healthSnapshot = nil
      healthConnectionStatus = .disconnected
      lastProgressEvent = "Apple Health wurde getrennt."
      return
    }

    healthConnectionStatus = .connecting
    healthKitManager.requestAuthorization { [weak self] success, message in
      guard let self else { return }
      if !success {
        self.healthConnectionStatus = .failed(
          message ?? "Apple Health konnte nicht verbunden werden.")
        self.lastProgressEvent = self.healthConnectionSubtitle
        return
      }

      self.connectedTrackerIDs.insert(appleHealthTrackerID)
      self.syncVitalData()
    }
  }

  private func toggleWhoopConnection() {
    guard let whoopTrackerID else { return }

    if connectedTrackerIDs.contains(whoopTrackerID) {
      connectedTrackerIDs.remove(whoopTrackerID)
      whoopConnectionStatus = .disconnected
      lastProgressEvent = "WHOOP wurde getrennt."
      return
    }

    whoopConnectionStatus = .setupRequired
    lastProgressEvent =
      "WHOOP ist in der App vorbereitet. Für die echte Verbindung braucht Gains noch WHOOP OAuth mit sicherem Backend für Client Secret und Token-Refresh."
  }

  func refreshContactsAuthorizationStatus() {
    contactsAccessStatus = CNContactStore.authorizationStatus(for: .contacts)
  }

  func requestContactsAccess() {
    contactStore.requestAccess(for: .contacts) { granted, _ in
      DispatchQueue.main.async {
        self.contactsAccessStatus = CNContactStore.authorizationStatus(for: .contacts)
        if granted {
          self.loadCommunityContacts()
        }
      }
    }
  }

  func loadCommunityContacts() {
    refreshContactsAuthorizationStatus()
    guard hasContactsAccess else { return }

    let keys: [CNKeyDescriptor] = [
      CNContactGivenNameKey as CNKeyDescriptor,
      CNContactFamilyNameKey as CNKeyDescriptor,
      CNContactPhoneNumbersKey as CNKeyDescriptor,
    ]

    let request = CNContactFetchRequest(keysToFetch: keys)
    var loadedContacts: [CommunityContact] = []

    do {
      try contactStore.enumerateContacts(with: request) { contact, _ in
        let fullName = [contact.givenName, contact.familyName]
          .filter { !$0.isEmpty }
          .joined(separator: " ")
        let displayName = fullName.isEmpty ? "Unbekannter Kontakt" : fullName
        let initialsSource = "\(contact.givenName.prefix(1))\(contact.familyName.prefix(1))"
        let initials =
          initialsSource.isEmpty
          ? String(displayName.prefix(1)).uppercased() : initialsSource.uppercased()
        let subtitle =
          contact.phoneNumbers.isEmpty
          ? "Ohne Nummer"
          : "\(contact.phoneNumbers.count) Nummer\(contact.phoneNumbers.count == 1 ? "" : "n")"

        loadedContacts.append(
          CommunityContact(
            id: contact.identifier,
            displayName: displayName,
            subtitle: subtitle,
            initials: initials
          )
        )
      }

      communityContacts = Array(
        loadedContacts.sorted(by: { $0.displayName < $1.displayName }).prefix(12))
    } catch {
      communityContacts = []
    }
  }

  // MARK: - Social Sharing Settings

  func setAutoShareWorkouts(_ enabled: Bool) {
    socialSharingSettings.autoShareWorkouts = enabled
    saveAll()
  }

  func setAutoShareRuns(_ enabled: Bool) {
    socialSharingSettings.autoShareRuns = enabled
    saveAll()
  }

  func setAutoSharePersonalRecords(_ enabled: Bool) {
    socialSharingSettings.autoSharePersonalRecords = enabled
    saveAll()
  }

  func setShareLocationWithRuns(_ enabled: Bool) {
    socialSharingSettings.shareLocationWithRuns = enabled
    saveAll()
  }

  func setSharingVisibility(_ visibility: SharingVisibility) {
    socialSharingSettings.visibility = visibility
    saveAll()
  }

  // MARK: - Forum

  func createForumThread(category: ForumCategory, title: String, body: String, location: String? = nil) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return }

    let thread = ForumThread(
      id: UUID(),
      category: category,
      title: trimmedTitle,
      body: trimmedBody,
      author: userName,
      handle: "@julius.gains",
      createdAt: Date(),
      location: location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      replies: [],
      likeCount: 0
    )
    forumThreads.insert(thread, at: 0)
    saveAll()
  }

  func addReply(to threadID: UUID, body: String) {
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let index = forumThreads.firstIndex(where: { $0.id == threadID }) else { return }
    let reply = ForumReply(
      id: UUID(),
      author: userName,
      handle: "@julius.gains",
      body: trimmed,
      createdAt: Date()
    )
    forumThreads[index].replies.append(reply)
    saveAll()
  }

  func toggleForumLike(threadID: UUID) {
    guard let index = forumThreads.firstIndex(where: { $0.id == threadID }) else { return }
    forumThreads[index].likeCount += 1
    saveAll()
  }

  // MARK: - Meetups

  func createMeetup(
    sport: MeetupSport,
    title: String,
    locationName: String,
    startsAt: Date,
    pace: String?,
    notes: String,
    maxParticipants: Int
  ) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty, !trimmedLocation.isEmpty else { return }

    let meetup = Meetup(
      id: UUID(),
      sport: sport,
      title: trimmedTitle,
      locationName: trimmedLocation,
      startsAt: startsAt,
      pace: pace?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      hostHandle: "@julius.gains",
      hostName: userName,
      notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
      maxParticipants: max(2, maxParticipants),
      participantHandles: ["@julius.gains"]
    )
    meetups.insert(meetup, at: 0)
    joinedMeetupIDs.insert(meetup.id)
    saveAll()
  }

  func toggleMeetupParticipation(meetupID: UUID) {
    guard let index = meetups.firstIndex(where: { $0.id == meetupID }) else { return }
    let ownHandle = "@julius.gains"
    if meetups[index].participantHandles.contains(ownHandle) {
      meetups[index].participantHandles.removeAll { $0 == ownHandle }
      joinedMeetupIDs.remove(meetupID)
    } else if meetups[index].participantHandles.count < meetups[index].maxParticipants {
      meetups[index].participantHandles.append(ownHandle)
      joinedMeetupIDs.insert(meetupID)
    }
    saveAll()
  }

  var upcomingMeetups: [Meetup] {
    meetups
      .filter { $0.startsAt >= Date().addingTimeInterval(-3600) }
      .sorted { $0.startsAt < $1.startsAt }
  }

  func threads(in category: ForumCategory) -> [ForumThread] {
    forumThreads.filter { $0.category == category }
  }

  // MARK: - Personal Records

  func detectAndShareNewPRs(from summary: CompletedWorkoutSummary) {
    guard socialSharingSettings.autoSharePersonalRecords else { return }

    var newRecords: [(exercise: String, weight: Double)] = []
    for exercise in summary.exercises where exercise.topWeight > 0 {
      let priorBest = workoutHistory
        .dropFirst()  // skip the just-inserted summary
        .flatMap { $0.exercises }
        .filter { $0.name == exercise.name }
        .map(\.topWeight)
        .max() ?? 0
      if exercise.topWeight > priorBest {
        newRecords.append((exercise.name, exercise.topWeight))
      }
    }

    guard !newRecords.isEmpty else { return }

    let title = newRecords.count == 1
      ? "Neuer PR: \(newRecords[0].exercise)"
      : "\(newRecords.count) neue Personal Records"
    let detail = newRecords
      .map { "\($0.exercise): \(Int($0.weight)) kg" }
      .joined(separator: " · ")

    let post = CommunityPost(
      id: UUID(),
      author: userName,
      handle: "@julius.gains",
      type: .progress,
      title: title,
      detail: detail,
      timeAgo: "gerade eben",
      placeholderSymbol: "trophy.fill",
      highlightMetrics: newRecords.prefix(3).map {
        CommunityMetric(label: $0.exercise, value: "\(Int($0.weight)) kg")
      },
      reactions: 0,
      comments: 0,
      shares: 0
    )
    communityPosts.insert(post, at: 0)
  }

  func toggleNotificationsEnabled() {
    notificationsEnabled.toggle()
    saveAll()
  }

  func toggleHealthAutoSyncEnabled() {
    healthAutoSyncEnabled.toggle()
    saveAll()
  }

  func toggleStudyBasedCoachingEnabled() {
    studyBasedCoachingEnabled.toggle()
    saveAll()
  }

  func cycleAppearanceMode() {
    let allModes = GainsAppearanceMode.allCases
    guard let currentIndex = allModes.firstIndex(of: appearanceMode) else {
      appearanceMode = .system
      return
    }

    let nextIndex = (currentIndex + 1) % allModes.count
    appearanceMode = allModes[nextIndex]
    saveAll()
  }

  func logWeightCheckIn() {
    registerCompletedDay(Date())
    switch plannerSettings.goal {
    case .fatLoss:
      updateCurrentWeight(by: -0.3)
      bodyFatChange = rounded(bodyFatChange - 0.2)
    case .muscleGain:
      updateCurrentWeight(by: 0.2)
      bodyFatChange = rounded(bodyFatChange + 0.05)
    case .performance:
      updateCurrentWeight(by: -0.1)
      bodyFatChange = rounded(bodyFatChange - 0.05)
    }

    lastProgressEvent =
      "Gewicht aktualisiert: \(String(format: "%.1f", currentWeight)) kg sind jetzt eingetragen."
    saveAll()
  }

  func logWaistCheckIn() {
    registerCompletedDay(Date())
    switch plannerSettings.goal {
    case .fatLoss:
      waistMeasurement = rounded(max(80, waistMeasurement - 0.4))
    case .muscleGain:
      waistMeasurement = rounded(waistMeasurement + 0.1)
    case .performance:
      waistMeasurement = rounded(max(80, waistMeasurement - 0.2))
    }

    lastProgressEvent =
      "Taillenmaß eingetragen: \(String(format: "%.1f", waistMeasurement)) cm im aktuellen Check-in."
    saveAll()
  }

  func syncVitalData() {
    if hasConnectedAppleHealth {
      healthConnectionStatus = .connecting
      healthKitManager.loadSnapshot { [weak self] result in
        guard let self else { return }
        switch result {
        case .success(let snapshot):
          self.registerCompletedDay(Date())
          self.vitalSyncCount += 1
          self.healthSnapshot = snapshot
          self.healthConnectionStatus = .connected

          if let bodyMassKg = snapshot.bodyMassKg {
            self.updateCurrentWeight(to: bodyMassKg)
          }

          self.lastProgressEvent =
            "Apple Health synchronisiert: \(snapshot.stepsToday) Schritte, \(snapshot.activeEnergyToday) kcal, \(snapshot.exerciseMinutesToday) Min Training."
        case .failure(let error):
          self.healthConnectionStatus = .failed(error.localizedDescription)
          self.lastProgressEvent = "Apple Health Sync fehlgeschlagen: \(error.localizedDescription)"
        }
      }
      return
    }

    guard !connectedTrackerIDs.isEmpty else {
      lastProgressEvent =
        "Verbinde zuerst einen Tracker, damit echte Vitaldaten synchronisiert werden können."
      return
    }

    registerCompletedDay(Date())
    vitalSyncCount += 1
    lastProgressEvent =
      "Vitaldaten synchronisiert. Ruhepuls, HRV, Schlaf und VO2max wurden aktualisiert."
  }

  func logProteinCheckIn() {
    registerCompletedDay(Date())
    proteinProgress = min(220, rounded(proteinProgress + 25))
    lastProgressEvent =
      "Protein-Check-in gespeichert: \(Int(proteinProgress)) g sind heute jetzt erfasst."
    saveAll()
  }

  func shareLatestRun() {
    createCommunityPost(
      from: CommunityComposerAction(
        title: "Lauf teilen",
        type: .run,
        systemImage: "figure.run"
      )
    )
    lastProgressEvent =
      latestCompletedRun == nil
      ? "Run-Template geteilt. Speichere einen echten Lauf, um Distanz und Pace mitzuteilen."
      : "Dein letzter Lauf wurde im Community-Feed geteilt."
  }

  func shareProgressUpdate() {
    createCommunityPost(
      from: CommunityComposerAction(
        title: "Progress Update",
        type: .progress,
        systemImage: "chart.line.uptrend.xyaxis"
      )
    )
    lastProgressEvent = "Dein Progress-Update wurde im Community-Feed geteilt."
  }

  func isTrackerConnected(_ trackerID: UUID) -> Bool {
    connectedTrackerIDs.contains(trackerID)
  }

  private var recentWorkoutHistory: [CompletedWorkoutSummary] {
    let calendar = Calendar.current
    let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
    return workoutHistory.filter { $0.finishedAt >= cutoff }
  }

  private var recentRunHistory: [CompletedRunSummary] {
    let calendar = Calendar.current
    let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
    return runHistory.filter { $0.finishedAt >= cutoff }
  }

  private var latestCompletedWorkoutVolumeText: String {
    guard let latestCompletedWorkout else { return "--" }
    return String(format: "%.1f t", latestCompletedWorkout.volume / 1000)
  }

  private var runningPaceProgressText: String {
    guard let latest = latestCompletedRun else {
      return "Sobald du Läufe speicherst, erscheint deine Pace-Entwicklung hier."
    }

    guard let baseline = runHistory.last else {
      return "Letzter Lauf auf \(String(format: "%.1f", latest.distanceKm)) km."
    }

    let delta = baseline.averagePaceSeconds - latest.averagePaceSeconds
    if abs(delta) < 5 {
      return "Pace aktuell stabil gegenüber deinem ersten gespeicherten Lauf."
    }

    return delta > 0
      ? "\(abs(delta)) Sek / km schneller als dein erster Log."
      : "\(abs(delta)) Sek / km langsamer als dein erster Log."
  }

  private var runningDistanceProgressText: String {
    guard let latest = latestCompletedRun else {
      return "Noch keine Laufdaten vorhanden."
    }

    let longestRun = runHistory.map(\.distanceKm).max() ?? latest.distanceKm
    return "Längster Lauf bisher: \(String(format: "%.1f", longestRun)) km."
  }

  private var workoutVolumeProgressText: String {
    guard let latest = latestCompletedWorkout else {
      return "Sobald du Workouts speicherst, erscheint dein Volumen hier."
    }

    guard let baseline = workoutHistory.last else {
      return "Erstes Workout mit \(Int(latest.volume)) kg Volumen."
    }

    let delta = latest.volume - baseline.volume
    if abs(delta) < 50 {
      return "Volumen aktuell stabil gegenüber deinem ersten Log."
    }

    return delta > 0
      ? "+\(Int(delta)) kg gegenüber deinem ersten Log."
      : "\(Int(delta)) kg gegenüber deinem ersten Log."
  }

  private var workoutSetProgressText: String {
    guard let latest = latestCompletedWorkout else {
      return "Noch keine Kraft-Session gespeichert."
    }

    guard let baseline = workoutHistory.last else {
      return "\(latest.completedSets) Sätze im letzten Workout."
    }

    let delta = latest.completedSets - baseline.completedSets
    if delta == 0 {
      return "Satzanzahl stabil gegenüber deinem ersten Log."
    }

    return delta > 0
      ? "+\(delta) Sätze gegenüber deinem ersten Log."
      : "\(delta) Sätze gegenüber deinem ersten Log."
  }

  private func strengthDeltaLabel(_ delta: Double, baseline: Double) -> String {
    guard baseline > 0 else { return "Erster Log" }
    if abs(delta) < 0.5 {
      return "Gewicht stabil"
    }
    return delta > 0
      ? "+\(String(format: "%.1f", delta)) kg" : "\(String(format: "%.1f", delta)) kg"
  }

  private func applyWorkoutProgress(from summary: CompletedWorkoutSummary) {
    let intensity = min(max(summary.volume / 5000, 0.35), 1.35)

    switch plannerSettings.goal {
    case .fatLoss:
      updateCurrentWeight(by: -0.18 * intensity)
      waistMeasurement = rounded(max(80, waistMeasurement - (0.25 * intensity)))
      bodyFatChange = rounded(bodyFatChange - (0.12 * intensity))
      proteinProgress = min(220, rounded(proteinProgress + 3))
    case .muscleGain:
      updateCurrentWeight(by: 0.12 * intensity)
      waistMeasurement = rounded(waistMeasurement + (0.06 * intensity))
      bodyFatChange = rounded(bodyFatChange + (0.04 * intensity))
      proteinProgress = min(220, rounded(proteinProgress + 4))
    case .performance:
      updateCurrentWeight(by: -0.05 * intensity)
      waistMeasurement = rounded(max(80, waistMeasurement - (0.08 * intensity)))
      bodyFatChange = rounded(bodyFatChange - (0.06 * intensity))
      proteinProgress = min(220, rounded(proteinProgress + 3))
    }

    syncVitalData()
  }

  private func updateCurrentWeight(to newWeight: Double) {
    let todayLabel = DateFormatter.localizedString(
      from: Date(), dateStyle: .short, timeStyle: .none)
    if let lastIndex = weightTrend.indices.last {
      weightTrend[lastIndex] = WeightTrendPoint(label: todayLabel, value: rounded(newWeight))
    } else {
      weightTrend = [WeightTrendPoint(label: todayLabel, value: rounded(newWeight))]
    }
  }

  private func formattedSleepHours(_ hours: Double?) -> String {
    guard let hours else { return "--" }
    return String(format: "%.1fh", hours)
  }

  private func formattedOptionalDouble(_ value: Double?, suffix: String) -> String {
    guard let value else { return "--" }
    if suffix.isEmpty {
      return String(format: "%.1f", value)
    }
    return String(format: "%.1f%@", value, suffix)
  }

  private func timeLabel(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "de_DE")
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
  }

  private func applyRunProgress(from summary: CompletedRunSummary) {
    let intensity = min(max(summary.distanceKm / 8, 0.35), 1.3)

    switch plannerSettings.goal {
    case .fatLoss:
      updateCurrentWeight(by: -0.16 * intensity)
      waistMeasurement = rounded(max(80, waistMeasurement - (0.18 * intensity)))
      bodyFatChange = rounded(bodyFatChange - (0.08 * intensity))
    case .muscleGain:
      updateCurrentWeight(by: -0.02 * intensity)
      bodyFatChange = rounded(bodyFatChange - (0.02 * intensity))
    case .performance:
      updateCurrentWeight(by: -0.05 * intensity)
      waistMeasurement = rounded(max(80, waistMeasurement - (0.10 * intensity)))
      bodyFatChange = rounded(bodyFatChange - (0.05 * intensity))
    }

    if !connectedTrackerIDs.isEmpty {
      syncVitalData()
    }
  }

  // A1: `seedNutritionEntries` und `seedCompletedDates` sind als Demo-Funktionen
  // in den DEBUG-Block oben gewandert (`demoNutritionEntries` / `demoCompletedDates`).

  private func updateCurrentWeight(by delta: Double) {
    let newWeight = rounded(currentWeight + delta)
    let todayLabel = Weekday.today.shortLabel

    if let existingIndex = weightTrend.firstIndex(where: { $0.label == todayLabel }) {
      weightTrend[existingIndex] = WeightTrendPoint(label: todayLabel, value: newWeight)
    } else {
      weightTrend.append(WeightTrendPoint(label: todayLabel, value: newWeight))
      weightTrend = Array(weightTrend.suffix(7))
    }
  }

  private func milestoneLabel(for date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "MMM dd"
    return formatter.string(from: date).uppercased()
  }

  private func rounded(_ value: Double) -> Double {
    (value * 10).rounded() / 10
  }

  private func formattedPace(secondsPerKilometer: Int) -> String {
    guard secondsPerKilometer > 0 else { return "--:-- /km" }
    let minutes = secondsPerKilometer / 60
    let seconds = secondsPerKilometer % 60
    return String(format: "%d:%02d /km", minutes, seconds)
  }

  private func goalProgress(for goal: ProgressGoal) -> Double {
    switch goal.title {
    case "Körpergewicht":
      return min(max((startWeight - goal.current) / max(startWeight - goal.target, 0.1), 0), 1)
    case "Taillenumfang":
      return min(max((startWaist - goal.current) / max(startWaist - goal.target, 0.1), 0), 1)
    default:
      return min(goal.current / max(goal.target, 0.1), 1)
    }
  }

  private func weekday(for date: Date) -> Weekday {
    let weekdayValue = Calendar.current.component(.weekday, from: date)
    return Weekday(rawValue: weekdayValue) ?? .monday
  }

  // MARK: - Evidence-based Planner Engine
  //
  // Quellen / Studienlage, die in die Heuristik einfließen:
  //   • Schoenfeld, Ogborn & Krieger (2016/2017) – Frequenz ≥ 2× / Muskel & Volumen-Dosis-Wirkung.
  //   • Helms et al. (2018) – RIR-Steuerung & Periodisierung im Hypertrophy-/Strength-Block.
  //   • Grgic et al. (2018) – Rest-Pausen für Hypertrophie & Maximalkraft.
  //   • Seiler (2010) / Stöggl & Sperlich (2014) – polarisiertes Cardio-Training (80/20).
  //   • Gibala et al. (2012) – HIIT-Adaptionen bei wenig Zeit.

  /// Ein einziger Aufruf liefert die "Hauptempfehlung" mit Studien-Werten,
  /// optional ergänzt um Cardio-Begleitempfehlungen für Hybrid.
  private func strengthRecommendations(for days: [Weekday]) -> [PlannerRecommendation] {
    let strengthDays = days
    return [strengthEvidenceRecommendation(for: strengthDays)]
  }

  private func cardioRecommendations(for days: [Weekday]) -> [PlannerRecommendation] {
    [cardioEvidenceRecommendation(for: days)]
  }

  private func hybridRecommendations(for days: [Weekday]) -> [PlannerRecommendation] {
    let split = hybridSplit(for: days.count)
    let strengthDays = Array(days.prefix(split.strength))
    let cardioDays = Array(days.dropFirst(split.strength))

    var result: [PlannerRecommendation] = []
    if !strengthDays.isEmpty {
      result.append(strengthEvidenceRecommendation(for: strengthDays))
    }
    if !cardioDays.isEmpty {
      result.append(cardioEvidenceRecommendation(for: cardioDays))
    }
    return result
  }

  // MARK: - Wissenschaftliche Stellschrauben

  /// Sätze pro Muskelgruppe pro Woche – Schoenfeld 2017 Meta-Analyse.
  /// Basisrange wird durch Recovery & Priorisierung modifiziert.
  var weeklySetsPerMuscleGroupRange: ClosedRange<Int> {
    let baseRange: ClosedRange<Int>
    switch plannerSettings.experience {
    case .beginner:     baseRange = 8...12
    case .intermediate: baseRange = 12...18
    case .advanced:     baseRange = 16...22
    }

    let multiplier = plannerSettings.recoveryCapacity.volumeMultiplier
    let lower = max(6, Int(round(Double(baseRange.lowerBound) * multiplier)))
    let upper = max(lower + 2, Int(round(Double(baseRange.upperBound) * multiplier)))
    return lower...upper
  }

  /// Empfohlene Frequenz pro Muskelgruppe (Schoenfeld 2016).
  var recommendedFrequencyPerMuscleGroup: Int {
    switch plannerSettings.experience {
    case .beginner:     return 2
    case .intermediate: return 2
    case .advanced:     return 3
    }
  }

  /// Wiederholungs-Range nach Ziel × Erfahrung.
  var recommendedRepRange: ClosedRange<Int> {
    switch plannerSettings.goal {
    case .muscleGain:
      return plannerSettings.experience == .beginner ? 8...12 : 6...12
    case .fatLoss:
      return 8...15
    case .performance:
      return plannerSettings.experience == .beginner ? 5...8 : 3...6
    }
  }

  /// Reps-in-Reserve-Steuerung (Helms 2018).
  var recommendedRIRRange: ClosedRange<Int> {
    switch plannerSettings.goal {
    case .muscleGain:
      return plannerSettings.experience == .advanced ? 0...2 : 1...3
    case .fatLoss:
      return 1...2
    case .performance:
      return 0...2
    }
  }

  /// Pausen nach Goal & Übungstyp – Grgic 2018.
  var recommendedRestSecondsCompound: Int {
    switch plannerSettings.goal {
    case .muscleGain:  return 150
    case .fatLoss:     return 90
    case .performance: return 240
    }
  }

  var recommendedRestSecondsIsolation: Int {
    switch plannerSettings.goal {
    case .muscleGain:  return 90
    case .fatLoss:     return 60
    case .performance: return 120
    }
  }

  /// Rahmenbedingungen für die Strength-Empfehlung.
  private func strengthEvidenceRecommendation(for days: [Weekday]) -> PlannerRecommendation {
    guard !days.isEmpty else {
      return PlannerRecommendation(
        title: "Kraft pausiert", detail: "Aktuell ist kein Krafttag eingeplant.", weekdays: [])
    }

    let split = pickSplitName(for: days.count)
    let setsRange = weeklySetsPerMuscleGroupRange
    let frequency = recommendedFrequencyPerMuscleGroup
    let rir = recommendedRIRRange
    let reps = recommendedRepRange

    let priorityNote: String
    if !plannerSettings.prioritizedMuscles.isEmpty {
      let names = plannerSettings.prioritizedMuscles
        .map(\.title)
        .sorted()
        .joined(separator: ", ")
      priorityNote = " · Priorität \(names) (+30 % Volumen)"
    } else {
      priorityNote = ""
    }

    let detail =
      "\(split) · \(setsRange.lowerBound)–\(setsRange.upperBound) Sätze pro Muskel & Woche · "
      + "\(reps.lowerBound)–\(reps.upperBound) Wiederholungen, RIR \(rir.lowerBound)–\(rir.upperBound)\(priorityNote)."

    let evidence =
      "Schoenfeld 2016/17 (Frequenz ≥ \(frequency)× / Muskel) · Helms 2018 (RIR-Steuerung) · "
      + "Grgic 2018 (Pausen ≈ \(recommendedRestSecondsCompound)s Compound / \(recommendedRestSecondsIsolation)s Isolation)."

    return PlannerRecommendation(
      title: "Kraft · \(split)",
      detail: detail,
      weekdays: days,
      setsPerMuscleGroupRange: setsRange,
      frequencyPerMuscleGroup: frequency,
      repRange: reps,
      rirRange: rir,
      restSecondsCompound: recommendedRestSecondsCompound,
      restSecondsIsolation: recommendedRestSecondsIsolation,
      evidenceNote: evidence
    )
  }

  /// Empfehlung für reine Lauf-Tage – polarisierte / pyramidale Verteilung.
  private func cardioEvidenceRecommendation(for days: [Weekday]) -> PlannerRecommendation {
    guard !days.isEmpty else {
      return PlannerRecommendation(
        title: "Lauf pausiert", detail: "Kein Cardio-Tag in dieser Woche.", weekdays: [])
    }

    let kmTarget = plannerSettings.weeklyKilometerTarget
    let model = plannerSettings.runIntensityModel
    let kinds = runSessionKinds(for: days.count)
    let kindLabels = kinds.map(\.shortLabel).joined(separator: " · ")

    let detail =
      "\(model.title) · \(days.count) Läufe (\(kindLabels)) · "
      + "Wochenziel ≈ \(kmTarget) km. Easy/Long ≤ 75 % HFmax, Tempo 84 – 88 %, Intervalle ≥ 92 %."

    let evidence: String
    switch model {
    case .polarized80_20:
      evidence = "Seiler 2010 & Stöggl/Sperlich 2014 – polarisiertes 80/20 maximiert VO₂max."
    case .pyramidal:
      evidence = "Esteve-Lanao 2017 – pyramidales Modell für submax. Renndistanzen."
    case .threshold:
      evidence = "Billat 2001 – Threshold-Block für 5–10 K Spezifität."
    case .minimalist:
      evidence = "Gibala 2012 – wenige hochintensive HIIT-Einheiten verbessern VO₂max."
    }

    return PlannerRecommendation(
      title: "Lauf · \(model.title)",
      detail: detail,
      weekdays: days,
      weeklyKilometerTarget: kmTarget,
      evidenceNote: evidence
    )
  }

  // MARK: - Split- & Session-Verteilung

  /// Wählt das beste Split-Layout, abhängig von User-Wahl, Frequenz, Erfahrung & Equipment.
  private func pickSplitName(for sessionCount: Int) -> String {
    let preference = plannerSettings.splitPreference
    let equipment = plannerSettings.equipment

    // Equipment-Constraint: Bodyweight & Dumbbells eignen sich für Frequenz-Ganzkörper-Pläne.
    let lightEquipment = (equipment == .bodyweight || equipment == .dumbbellsOnly)

    if preference != .auto {
      return preference.title
    }

    switch sessionCount {
    case ...1: return "Ganzkörper"
    case 2:    return lightEquipment ? "Ganzkörper × 2" : "Upper / Lower"
    case 3:
      if plannerSettings.experience == .beginner || lightEquipment {
        return "Ganzkörper × 3"
      }
      return "Push / Pull / Legs"
    case 4:
      return lightEquipment ? "Ganzkörper × 4" : "Upper / Lower × 2"
    case 5:
      if plannerSettings.experience == .advanced && !lightEquipment {
        return "PPL + Upper / Lower"
      }
      return "Upper / Lower + Ganzkörper"
    case 6:
      return "Push / Pull / Legs × 2"
    default:
      return "High-Frequency"
    }
  }

  /// Verteilung der Lauf-Einheiten gemäß gewähltem Intensitätsmodell.
  func runSessionKinds(for runCount: Int) -> [PlannedSessionKind] {
    guard runCount > 0 else { return [] }
    switch plannerSettings.runIntensityModel {
    case .polarized80_20:
      switch runCount {
      case 1:  return [.easyRun]
      case 2:  return [.easyRun, .tempoRun]
      case 3:  return [.easyRun, .intervalRun, .longRun]
      case 4:  return [.easyRun, .easyRun, .intervalRun, .longRun]
      case 5:  return [.easyRun, .easyRun, .tempoRun, .intervalRun, .longRun]
      default: return Array(repeating: PlannedSessionKind.easyRun, count: runCount - 3)
        + [.tempoRun, .intervalRun, .longRun]
      }
    case .pyramidal:
      switch runCount {
      case 1:  return [.easyRun]
      case 2:  return [.easyRun, .tempoRun]
      case 3:  return [.easyRun, .tempoRun, .longRun]
      case 4:  return [.easyRun, .tempoRun, .easyRun, .longRun]
      default: return Array(repeating: PlannedSessionKind.easyRun, count: runCount - 2)
        + [.tempoRun, .longRun]
      }
    case .threshold:
      switch runCount {
      case 1:  return [.tempoRun]
      case 2:  return [.tempoRun, .longRun]
      case 3:  return [.easyRun, .tempoRun, .longRun]
      default: return Array(repeating: PlannedSessionKind.tempoRun, count: max(1, runCount - 2))
        + [.easyRun, .longRun]
      }
    case .minimalist:
      switch runCount {
      case 1:  return [.intervalRun]
      case 2:  return [.intervalRun, .longRun]
      default: return [.easyRun, .intervalRun, .longRun]
        + Array(repeating: PlannedSessionKind.tempoRun, count: max(0, runCount - 3))
      }
    }
  }

  /// Hybrid-Verteilung – wie viele Tage gehen an Kraft, wie viele an Cardio.
  private func hybridSplit(for total: Int) -> (strength: Int, cardio: Int) {
    switch total {
    case ...1: return (1, 0)
    case 2:    return (1, 1)
    case 3:    return (2, 1)
    case 4:    return (2, 2)
    case 5:    return (3, 2)
    case 6:    return (4, 2)
    default:   return (max(0, total - 2), 2)
    }
  }

  /// Ordnet jedem geplanten Tag eine konkrete Session-Art zu (Kraft / verschiedene Lauftypen).
  /// Wird vom weekly schedule sowie der UI genutzt.
  var plannedSessionKinds: [Weekday: PlannedSessionKind] {
    let days = scheduledPlannerDays
    guard !days.isEmpty else { return [:] }

    var result: [Weekday: PlannedSessionKind] = [:]

    switch plannerSettings.trainingFocus {
    case .strength:
      for d in days { result[d] = .strength }
    case .cardio:
      let kinds = runSessionKinds(for: days.count)
      for (i, d) in days.enumerated() {
        result[d] = i < kinds.count ? kinds[i] : .easyRun
      }
    case .hybrid:
      let split = hybridSplit(for: days.count)
      let runKinds = runSessionKinds(for: split.cardio)
      for (i, d) in days.enumerated() {
        if i < split.strength {
          result[d] = .strength
        } else {
          let runIdx = i - split.strength
          result[d] = runIdx < runKinds.count ? runKinds[runIdx] : .easyRun
        }
      }
    }

    return result
  }

  /// Entscheidet, ob ein Tag eine Lauf-Session ist, und liefert ggf. die Lauf-Vorlage.
  func runTemplate(for weekday: Weekday) -> RunTemplate? {
    guard let kind = plannedSessionKinds[weekday], kind.isRun else { return nil }
    return RunTemplate.template(for: kind)
  }

  private var minimumSessionsPerWeek: Int {
    availablePlannerDaysCount == 0 ? 0 : 1
  }

  private var maximumSessionsPerWeek: Int {
    7
  }

  private func normalizedSessionsPerWeek(_ desired: Int) -> Int {
    let minimum = minimumSessionsPerWeek
    let maximum = maximumSessionsPerWeek

    guard maximum > 0 else {
      return 0
    }

    return min(max(desired, minimum), maximum)
  }

  private func alignSessionTargetToAvailableDays() {
    let availableDays = availablePlannerDaysCount

    guard availableDays > 0 else {
      plannerSettings.sessionsPerWeek = 0
      return
    }

    plannerSettings.sessionsPerWeek = min(max(plannerSettings.sessionsPerWeek, 1), availableDays)
  }

  private func rebalancePlannerAvailability(for desiredDays: Int) {
    let target = min(max(desiredDays, 1), 7)

    while explicitTrainingDays.count > target, let day = explicitTrainingDays.last {
      plannerSettings.dayPreferences[day] = .rest
    }

    while availablePlannerDaysCount > target {
      if let day = flexiblePlannerDays.last {
        plannerSettings.dayPreferences[day] = .rest
      } else if let day = explicitTrainingDays.last, explicitTrainingDays.count > target {
        plannerSettings.dayPreferences[day] = .rest
      } else {
        break
      }
    }

    while availablePlannerDaysCount < target,
      let day = Weekday.allCases.first(where: { dayPreference(for: $0) == .rest })
    {
      plannerSettings.dayPreferences[day] = .flexible
    }
  }

  private func normalizedDate(_ date: Date) -> Date {
    Calendar.current.startOfDay(for: date)
  }

  private func startOfWeek(for date: Date) -> Date {
    Calendar.current.date(
      from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
      ?? normalizedDate(date)
  }

  private func toggleCalendarCompletion(on date: Date) {
    let normalized = normalizedDate(date)

    if completedCalendarDates.contains(normalized) {
      completedCalendarDates.remove(normalized)
    } else {
      completedCalendarDates.insert(normalized)
    }

    recalculateStreak()
  }

  private func registerCompletedDay(_ date: Date) {
    let normalized = normalizedDate(date)
    guard !completedCalendarDates.contains(normalized) else { return }
    completedCalendarDates.insert(normalized)
    recalculateStreak()
  }

  private func recalculateStreak() {
    let sortedDates = completedCalendarDates.sorted()
    guard let latestCompleted = sortedDates.last else {
      streakDays = 0
      return
    }

    let calendar = Calendar.current
    let latestRelevantDate = normalizedDate(Date())
    let dayDifferenceToToday =
      calendar.dateComponents([.day], from: latestCompleted, to: latestRelevantDate).day ?? 0

    if dayDifferenceToToday > 1 {
      streakDays = 0
      return
    }

    var currentDate = latestCompleted
    var streak = 0

    while completedCalendarDates.contains(currentDate) {
      streak += 1
      guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
        break
      }
      currentDate = normalizedDate(previousDate)
    }

    streakDays = streak
    recordDays = max(recordDays, streakDays)
  }

}
