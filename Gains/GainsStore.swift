import Contacts
import CoreLocation
import Foundation
import UIKit  // 2026-05-03: UIImage / UIGraphicsImageRenderer für Avatar-Resize.

// MARK: - Cached Formatters
// Static-Instanzen, damit Computed-Properties (z. B. `weekRangeLabel`,
// `selectedCalendarHeadline`) in Hot-Paths kein DateFormatter pro Aufruf
// allokieren. Alle Aufrufe erfolgen auf MainActor (ObservableObject).
fileprivate enum StoreFormatters {
  static let dayMonthDE: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "dd. MMM"
    return f
  }()

  static let weekdayDayMonthDE: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "EEEE, dd. MMMM"
    return f
  }()

  static let timeHHmmDE: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "HH:mm"
    return f
  }()

  static let monthDayEN: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "MMM dd"
    return f
  }()
}

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
  /// 2026-05-01 P1-3: Pause-Timer-Endpunkt im Store statt View-State, damit
  /// er View-Resets übersteht (Tab-Switch, Sheet-Dismiss, Memory-Pressure-
  /// driven View-Recreation). View-State (`@State`) wird beim Drop des
  /// View-Subtrees verworfen — der Store-Singleton überlebt das.
  @Published var activeRestTimerEndsAt: Date?
  /// Aktuell eingestellte Pausen-Dauer in Sekunden (Default 150s = 2:30).
  @Published var activeRestDuration: Int = 150
  @Published var lastCompletedWorkout: CompletedWorkoutSummary?
  // A1: Frische Installation startet leer — Mock-Historien sind nur noch im
  // DEBUG-Demo-Modus erreichbar (siehe `loadDemoData()` unten).
  @Published var workoutHistory: [CompletedWorkoutSummary] = []
  @Published var runHistory: [CompletedRunSummary] = []
  // Strava-Erweiterung: Routen, Segmente, strukturierte Workouts.
  @Published var savedRoutes: [SavedRoute] = []
  @Published var runSegments: [RunSegment] = []
  /// Effort-Liste pro Segment (segmentID → Efforts, neuste zuerst).
  @Published var runSegmentEfforts: [UUID: [RunSegmentEffort]] = [:]
  @Published var structuredRunWorkouts: [StructuredRunWorkout] = StructuredRunWorkout.builtinLibrary
  /// Aktiv laufendes strukturiertes Workout (nil, wenn kein Workout läuft).
  @Published var activeStructuredWorkout: ActiveStructuredWorkout? = nil
  /// Aktiver Ziel-Trainingsplan (Distanz × Pace × Datum → Phasen-Plan).
  /// Nil, wenn der Nutzer keinen Plan gesetzt hat. Persistiert via
  /// `PersistenceKey.runGoalPlan`.
  @Published var runGoalPlan: RunGoalPlan? = nil
  @Published var savedWorkoutPlans: [WorkoutPlan] = WorkoutPlan.starterTemplates
  @Published var plannerSettings: WorkoutPlannerSettings = .default
  @Published var completedCoachCheckInIDs: Set<UUID> = []
  @Published var joinedChallenge = false
  @Published var likedPostIDs: Set<UUID> = []
  @Published var commentedPostIDs: Set<UUID> = []
  @Published var sharedPostIDs: Set<UUID> = []
  /// Gelikte Forum-Threads des aktuellen Nutzers — verhindert Mehrfach-Likes.
  @Published var likedThreadIDs: Set<UUID> = []
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
  /// Aus `userName` abgeleiteter Handle für Community-Posts. Ersetzt den
  /// früheren Hardcode-Wert „@julius.gains" durch einen nutzerabhängigen String.
  var userHandle: String {
    let base = userName
      .lowercased()
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: ".")
    return "@\(base.isEmpty ? "gains.user" : base)"
  }
  /// Profil-Bild als komprimierter JPEG-Blob. nil = Initial-Letter-Avatar.
  /// Wird in den UserDefaults persistiert (Re-Design 2026-05-03 — Profil
  /// kann jetzt Foto + Namen editieren). HomeView-Greeting + ProfileView
  /// observieren beide diese Property; nach `setUserAvatar` rendern beide
  /// das neue Bild ohne Restart.
  @Published var userAvatarData: Data? = nil
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

  // MARK: - Computed-Property-Caches
  // plannedSessionKinds wird von weeklyWorkoutSchedule UND nextFourWeeksSchedule
  // aufgerufen — beide werden häufig im selben Render-Pass ausgewertet.
  // Cache mit plannerSettings + dayPreferences als Invalidierungs-Key.
  // Invalidierung erfolgt über invalidatePlannerCache() an allen Mutationspunkten.
  private var _cachedPlannedSessionKinds: [Weekday: PlannedSessionKind]? = nil

  /// Cache invalidieren — muss nach jeder plannerSettings-Mutation aufgerufen werden.
  func invalidatePlannerCache() {
    _cachedPlannedSessionKinds = nil
  }

  // MARK: - Save-Debounce
  // saveAll() wird an ~78 Stellen aufgerufen. Ohne Debounce führt jede
  // einzelne Settings-Änderung (z. B. 5 Planner-Toggles hintereinander)
  // zu 5 vollständigen JSON-Encode + UserDefaults-Write-Zyklen.
  // Mit einem 0.8s-DispatchWorkItem-Debounce werden Bursts zu einem einzigen
  // Schreib-Vorgang zusammengefasst; der sofortige saveAll(completion:)-Pfad
  // (Onboarding-Finish, finishWorkout) bleibt über den force-Parameter erhalten.
  private var _pendingSaveWork: DispatchWorkItem?

  /// Debounced persistieren. `force: true` schreibt sofort (kein Delay).
  func scheduleSave(force: Bool = false) {
    _pendingSaveWork?.cancel()
    if force {
      scheduleSave()
      return
    }
    let work = DispatchWorkItem { [weak self] in self?.saveAll() }
    _pendingSaveWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
  }
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
    // 2026-05-03: Avatar laden (Profil-Re-Design). Defensiv — beschädigte
    // Blobs einfach ignorieren statt die App beim Start zu blockieren.
    if let data = ud.data(forKey: PersistenceKey.userAvatarData), !data.isEmpty {
      userAvatarData = data
    }
    // A5: Historien lenient laden — einzelne korrupte Einträge dürfen nicht
    // die ganze Liste verwerfen.
    if let history = ud.decodedLoadLenient(CompletedWorkoutSummary.self, forKey: PersistenceKey.workoutHistory) {
      workoutHistory = history
    }
    if let runs = ud.decodedLoadLenient(CompletedRunSummary.self, forKey: PersistenceKey.runHistory) {
      runHistory = runs
    }
    // Strava-Erweiterung: Routen / Segmente / strukturierte Workouts laden.
    if let routes = ud.decodedLoadLenient(SavedRoute.self, forKey: PersistenceKey.savedRoutes) {
      savedRoutes = routes
    }
    if let segments = ud.decodedLoadLenient(RunSegment.self, forKey: PersistenceKey.runSegments) {
      runSegments = segments
    }
    // A5: Lenient laden — ein einzelner korrupter Eintrag darf nicht das ganze
    // Dictionary wegwerfen. Analog zu decodedLoadLenient für Arrays.
    if let efforts = ud.decodedLoadLenientUUIDDictionary(RunSegmentEffort.self, forKey: PersistenceKey.runSegmentEfforts) {
      runSegmentEfforts = efforts
    }
    if let workouts = ud.decodedLoadLenient(StructuredRunWorkout.self, forKey: PersistenceKey.structuredRunWorkouts) {
      // Builtin-Workouts immer auffrischen — Custom-Workouts behalten.
      let custom = workouts.filter { !$0.isBuiltin }
      structuredRunWorkouts = StructuredRunWorkout.builtinLibrary + custom
    }
    // Goal-Plan (optional) — wenn der Nutzer noch keinen Plan gesetzt hat,
    // bleibt das Property nil; der UI-Block zeigt dann den Empty-State.
    if let plan = ud.decodedLoad(RunGoalPlan.self, forKey: PersistenceKey.runGoalPlan) {
      runGoalPlan = plan
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
    // Coach-Check-in-IDs: persistieren damit der Nutzer nach App-Neustart
    // dieselben Check-ins nicht nochmal bestätigen muss.
    if let ids = ud.decodedLoad([UUID].self, forKey: PersistenceKey.completedCoachCheckInIDs) {
      completedCoachCheckInIDs = Set(ids)
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
    if let ids = ud.decodedLoad([UUID].self, forKey: PersistenceKey.likedThreadIDs) {
      likedThreadIDs = Set(ids)
    }
    if let ids = ud.decodedLoad([UUID].self, forKey: PersistenceKey.likedPostIDs) {
      likedPostIDs = Set(ids)
    }
    if let ids = ud.decodedLoad([UUID].self, forKey: PersistenceKey.commentedPostIDs) {
      commentedPostIDs = Set(ids)
    }
    if let ids = ud.decodedLoad([UUID].self, forKey: PersistenceKey.sharedPostIDs) {
      sharedPostIDs = Set(ids)
    }
    if let rawMode = ud.string(forKey: PersistenceKey.appearanceMode),
       let mode = GainsAppearanceMode(rawValue: rawMode) {
      appearanceMode = mode
    }
  }

  /// Speichert alle Daten asynchron auf einem Utility-Thread.
  ///
  /// Wenn ein Pfad sicherstellen muss, dass die Daten geschrieben sind bevor
  /// er weitermacht (z.B. Onboarding-Finish, das danach `hasCompletedOnboarding`
  /// auf true setzt — siehe P0-5 Race), ruft er stattdessen `saveAll { … }`
  /// und führt den Folgeschritt erst im Completion-Block aus.
  func saveAll(completion: (() -> Void)? = nil) {
    // Alle aktuellen Werte auf dem Main-Thread snapshotten (Value-Types → sichere Kopien),
    // dann JSON-Enkodierung und UserDefaults-Schreibzugriff auf einem Utility-Background-
    // Thread erledigen. Verhindert Main-Thread-Jank bei großen Historien (viele Läufe,
    // Nutrition-Logs, Routen).
    let ud = UserDefaults.standard
    let _userName              = self.userName
    let _userAvatarData        = self.userAvatarData
    let _workoutHistory        = self.workoutHistory
    let _runHistory            = self.runHistory
    let _savedRoutes           = self.savedRoutes
    let _runSegments           = self.runSegments
    let _runSegmentEfforts     = self.runSegmentEfforts
    let _customRunWorkouts     = self.structuredRunWorkouts.filter { !$0.isBuiltin }
    let _runGoalPlan           = self.runGoalPlan
    let _savedWorkoutPlans     = self.savedWorkoutPlans
    let _plannerSettings       = self.plannerSettings
    let _weightTrend           = self.weightTrend
    let _connectedTrackerIDs         = Array(self.connectedTrackerIDs)
    let _favoriteRecipeIDs           = Array(self.favoriteRecipeIDs)
    let _completedCoachCheckInIDs    = Array(self.completedCoachCheckInIDs)
    let _completedDates              = Array(self.completedCalendarDates)
    let _nutritionEntries      = self.nutritionEntries
    let _nutritionGoal         = self.nutritionGoal
    let _nutritionProfile      = self.nutritionProfile
    let _waistMeasurement      = self.waistMeasurement
    let _bodyFatChange         = self.bodyFatChange
    let _proteinProgress       = self.proteinProgress
    let _streakDays            = self.streakDays
    let _recordDays            = self.recordDays
    let _vitalSyncCount        = self.vitalSyncCount
    let _notificationsEnabled  = self.notificationsEnabled
    let _healthAutoSync        = self.healthAutoSyncEnabled
    let _studyCoaching         = self.studyBasedCoachingEnabled
    let _joinedChallenge       = self.joinedChallenge
    let _appearanceMode        = self.appearanceMode.rawValue
    let _socialSharing         = self.socialSharingSettings
    let _forumThreads          = self.forumThreads
    let _likedThreadIDs        = Array(self.likedThreadIDs)
    let _meetups               = self.meetups
    let _joinedMeetupIDs       = Array(self.joinedMeetupIDs)
    let _likedPostIDs          = Array(self.likedPostIDs)
    let _commentedPostIDs      = Array(self.commentedPostIDs)
    let _sharedPostIDs         = Array(self.sharedPostIDs)

    DispatchQueue.global(qos: .utility).async {
      ud.set(_userName, forKey: PersistenceKey.userName)
      // 2026-05-03: Avatar — nil ⇒ Key entfernen, sonst rohe Data-Bytes.
      // UserDefaults toleriert ein paar hundert KB ohne Performance-Hit.
      if let data = _userAvatarData, !data.isEmpty {
        ud.set(data, forKey: PersistenceKey.userAvatarData)
      } else {
        ud.removeObject(forKey: PersistenceKey.userAvatarData)
      }
      ud.encodedSave(_workoutHistory,      forKey: PersistenceKey.workoutHistory)
      ud.encodedSave(_runHistory,          forKey: PersistenceKey.runHistory)
      // Strava-Erweiterung: Routen / Segmente / strukturierte Workouts.
      ud.encodedSave(_savedRoutes,         forKey: PersistenceKey.savedRoutes)
      ud.encodedSave(_runSegments,         forKey: PersistenceKey.runSegments)
      ud.encodedSave(_runSegmentEfforts,   forKey: PersistenceKey.runSegmentEfforts)
      // Nur Custom-Workouts persistieren — Builtins werden bei jedem Start neu geladen.
      ud.encodedSave(_customRunWorkouts,   forKey: PersistenceKey.structuredRunWorkouts)
      // Goal-Plan: nur schreiben wenn gesetzt, sonst Key explizit löschen, damit
      // ein "Plan beenden"-Klick nach App-Restart wirklich kein Plan mehr da ist.
      if let plan = _runGoalPlan {
        ud.encodedSave(plan,               forKey: PersistenceKey.runGoalPlan)
      } else {
        ud.removeObject(forKey: PersistenceKey.runGoalPlan)
      }
      ud.encodedSave(_savedWorkoutPlans,   forKey: PersistenceKey.savedWorkoutPlans)
      ud.encodedSave(_plannerSettings,     forKey: PersistenceKey.plannerSettings)
      ud.encodedSave(_weightTrend,         forKey: PersistenceKey.weightTrend)
      ud.encodedSave(_connectedTrackerIDs,      forKey: PersistenceKey.connectedTrackerIDs)
      ud.encodedSave(_favoriteRecipeIDs,        forKey: PersistenceKey.favoriteRecipeIDs)
      ud.encodedSave(_completedCoachCheckInIDs, forKey: PersistenceKey.completedCoachCheckInIDs)
      ud.encodedSave(_completedDates,           forKey: PersistenceKey.completedDates)
      ud.encodedSave(_nutritionEntries,    forKey: PersistenceKey.nutritionEntries)
      ud.encodedSave(_nutritionGoal,       forKey: PersistenceKey.nutritionGoal)
      if let profile = _nutritionProfile { ud.encodedSave(profile, forKey: PersistenceKey.nutritionProfile) }
      ud.set(_waistMeasurement,            forKey: PersistenceKey.waistMeasurement)
      ud.set(_bodyFatChange,               forKey: PersistenceKey.bodyFatChange)
      ud.set(_proteinProgress,             forKey: PersistenceKey.proteinProgress)
      ud.set(_streakDays,                  forKey: PersistenceKey.streakDays)
      ud.set(_recordDays,                  forKey: PersistenceKey.recordDays)
      ud.set(_vitalSyncCount,              forKey: PersistenceKey.vitalSyncCount)
      ud.set(_notificationsEnabled,        forKey: PersistenceKey.notificationsEnabled)
      ud.set(_healthAutoSync,              forKey: PersistenceKey.healthAutoSync)
      ud.set(_studyCoaching,              forKey: PersistenceKey.studyCoaching)
      ud.set(_joinedChallenge,             forKey: PersistenceKey.joinedChallenge)
      ud.set(_appearanceMode,              forKey: PersistenceKey.appearanceMode)
      ud.encodedSave(_socialSharing,       forKey: PersistenceKey.socialSharingSettings)
      ud.encodedSave(_forumThreads,        forKey: PersistenceKey.forumThreads)
      ud.encodedSave(_likedThreadIDs,      forKey: PersistenceKey.likedThreadIDs)
      ud.encodedSave(_meetups,             forKey: PersistenceKey.meetups)
      ud.encodedSave(_joinedMeetupIDs,     forKey: PersistenceKey.joinedMeetupIDs)
      ud.encodedSave(_likedPostIDs,        forKey: PersistenceKey.likedPostIDs)
      ud.encodedSave(_commentedPostIDs,    forKey: PersistenceKey.commentedPostIDs)
      ud.encodedSave(_sharedPostIDs,       forKey: PersistenceKey.sharedPostIDs)

      // Completion auf den Main-Thread zurückspielen, damit Caller mit
      // UI-State arbeiten können (z.B. Onboarding-Finish setzt danach erst
      // `hasCompletedOnboarding = true`, siehe P0-5).
      if let completion {
        DispatchQueue.main.async { completion() }
      }
    }
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
      PersistenceKey.userName, PersistenceKey.userAvatarData,
      PersistenceKey.workoutHistory, PersistenceKey.runHistory,
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
      PersistenceKey.forumThreads, PersistenceKey.likedThreadIDs,
      PersistenceKey.meetups, PersistenceKey.joinedMeetupIDs,
      PersistenceKey.likedPostIDs, PersistenceKey.commentedPostIDs, PersistenceKey.sharedPostIDs,
      PersistenceKey.savedRoutes, PersistenceKey.runSegments,
      PersistenceKey.runSegmentEfforts, PersistenceKey.structuredRunWorkouts,
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
          let focus: String = {
            guard let template else { return kind.title }
            return "\(Int(template.targetDistanceKm)) km · \(template.targetPaceLabel)"
          }()

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

  /// Letzte abgeschlossene Cardio-Session, nach Modalität gefiltert. Für
  /// modality-aware Headlines im Hero (Lauf/Rad/Indoor).
  func latestCompletedCardio(modality: CardioModality) -> CompletedRunSummary? {
    runHistory.first { $0.modality == modality }
  }

  // MARK: - Cardio-Stats — Lauf vs. Rad
  //
  // 2026-05-03 (Audit-Fix P0-1): Vorher mischten alle Hero-Metriken Lauf- und
  // Rad-Sessions in einen Topf — Ø PACE wurde durch Bike-Pace verfälscht,
  // 5K/10K-PRs wurden durch kurze Radtouren überschrieben, Pace-Zonen
  // (Easy/Moderat/Tempo/Hart) erhielten Bike-Werte. Wir trennen jetzt
  // Run-only- und Cardio-Total-Aggregate sauber.

  /// Run-only Slice der `runHistory` (kein Bike).
  private var runOnlyHistory: [CompletedRunSummary] {
    runHistory.filter { $0.modality == .run }
  }

  /// Bike-only Slice der `runHistory` (Outdoor + Indoor).
  private var bikeOnlyHistory: [CompletedRunSummary] {
    runHistory.filter { $0.modality.isCycling }
  }

  /// Letzte 7 Tage, run-only.
  private var recentRunOnlyHistory: [CompletedRunSummary] {
    let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
    return runOnlyHistory.filter { $0.finishedAt >= cutoff }
  }

  /// Letzte 7 Tage, bike-only.
  private var recentBikeHistory: [CompletedRunSummary] {
    let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date.distantPast
    return bikeOnlyHistory.filter { $0.finishedAt >= cutoff }
  }

  // ----- Wochen-Aggregate (gemischt = Cardio-Total, run-only für Pace) -----

  /// Cardio-Wochen-Distanz: Lauf + Rad zusammen. Wird im Hero-Tile „7 TAGE"
  /// und im Wochen-Chart als Gesamt-Cardio-Volumen gerendert.
  var weeklyRunDistanceKm: Double {
    recentRunHistory.reduce(0) { $0 + $1.distanceKm }
  }

  /// Reine Lauf-km der letzten 7 Tage. Für separate Run-Statistiken.
  var weeklyRunOnlyDistanceKm: Double {
    recentRunOnlyHistory.reduce(0) { $0 + $1.distanceKm }
  }

  /// Reine Rad-km der letzten 7 Tage.
  var weeklyBikeDistanceKm: Double {
    recentBikeHistory.reduce(0) { $0 + $1.distanceKm }
  }

  /// Anzahl Lauf-Sessions in den letzten 7 Tagen.
  var weeklyRunOnlyCountThisWeek: Int {
    recentRunOnlyHistory.count
  }

  /// Anzahl Bike-Sessions in den letzten 7 Tagen.
  var bikeOnlyCountThisWeek: Int {
    recentBikeHistory.count
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

  /// Ø Pace (Sek./km) der letzten 7 Tage — **nur Lauf**. Bike-Sessions würden
  /// den Mittelwert sonst Richtung Sprint verzerren (25 km/h ≈ 144 s/km vs.
  /// ein Lauf bei ~300 s/km).
  var averageRunPaceSeconds: Int {
    guard !recentRunOnlyHistory.isEmpty else { return 0 }
    let totalDistance = recentRunOnlyHistory.reduce(0) { $0 + $1.distanceKm }
    let totalSeconds = recentRunOnlyHistory.reduce(0) { $0 + ($1.durationMinutes * 60) }
    guard totalDistance > 0 else { return 0 }
    return Int(Double(totalSeconds) / totalDistance)
  }

  /// Ø Geschwindigkeit (km/h) der letzten 7 Tage — **nur Rad**. Wird im Hero
  /// gerendert, wenn die zuletzt genutzte Modalität Bike ist.
  var averageBikeSpeedKmh: Double {
    guard !recentBikeHistory.isEmpty else { return 0 }
    let totalDistance = recentBikeHistory.reduce(0) { $0 + $1.distanceKm }
    let totalSeconds = recentBikeHistory.reduce(0) { $0 + ($1.durationMinutes * 60) }
    guard totalSeconds > 0 else { return 0 }
    return totalDistance / (Double(totalSeconds) / 3600.0)
  }

  /// Beste Lauf-Pace aller Zeit — Bike-Sessions werden ausgeschlossen.
  var bestRunPaceSeconds: Int {
    runOnlyHistory.map(\.averagePaceSeconds).min() ?? 0
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
      runOnlyHistory
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

    if let longestRun = runOnlyHistory.max(by: { $0.distanceKm < $1.distanceKm }) {
      personalBests.append(
        RunPersonalBest(
          title: "Längster Lauf",
          value: String(format: "%.1f km", longestRun.distanceKm),
          context: longestRun.routeName
        )
      )
    }

    // Höhenmeter darf weiter aus allen Outdoor-Sessions kommen — Lauf wie
    // Radtour. Indoor-Sessions ignorieren wir, weil dort kein GPS läuft.
    let outdoorSessions = runHistory.filter { !$0.modality.isIndoor }
    if let highestElevation = outdoorSessions.max(by: { $0.elevationGain < $1.elevationGain }) {
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

  /// Bike-spezifische PRs (Schnellste Tour, Längste Strecke, max. km/h).
  /// Wird im STATS-Tab als zweites Grid gerendert, sobald Bike-Sessions
  /// vorhanden sind.
  var bikePersonalBests: [RunPersonalBest] {
    var bests: [RunPersonalBest] = []

    if let fastest = bikeOnlyHistory
      .filter({ $0.distanceKm >= 5 && $0.averagePaceSeconds > 0 })
      .min(by: { $0.averagePaceSeconds < $1.averagePaceSeconds })
    {
      let kmh = 3600.0 / Double(fastest.averagePaceSeconds)
      bests.append(
        RunPersonalBest(
          title: "Schnellste Tour",
          value: String(format: "%.1f km/h", kmh),
          context: fastest.routeName
        )
      )
    }

    if let longest = bikeOnlyHistory.max(by: { $0.distanceKm < $1.distanceKm }) {
      bests.append(
        RunPersonalBest(
          title: "Längste Tour",
          value: String(format: "%.1f km", longest.distanceKm),
          context: longest.routeName
        )
      )
    }

    return bests
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

  /// Distribution of runs across pace zones — **nur Lauf**. Easy/Moderat/
  /// Tempo/Hart sind Run-Pace-Konzepte; Bike-Pace gehört nicht in diese
  /// Klassifikation.
  var paceZones: [PaceZoneEntry] {
    let paces = runOnlyHistory.compactMap { $0.averagePaceSeconds > 0 ? $0.averagePaceSeconds : nil }
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

  /// Best finish times for standard distances (5K, 10K, Half, Marathon).
  /// **Nur Lauf** — eine 5-km-Radtour soll nicht die schnellste 5K-Laufzeit
  /// überschreiben.
  var distancePRs: [RunPersonalBest] {
    let targets: [(title: String, minKm: Double, exactKm: Double)] = [
      ("5K",           4.8,  5.0),
      ("10K",          9.5, 10.0),
      ("Halbmarathon", 20.5, 21.1),
      ("Marathon",     41.0, 42.2),
    ]
    return targets.compactMap { target in
      let eligible = runOnlyHistory.filter { $0.distanceKm >= target.minKm }
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

  // MARK: - Bike-/Modality-Aggregate (für modus-bewussten STATS-Tab)
  //
  // 2026-05-03 (Cardio-Optim Welle 4): STATS-Tab im Cardio-Hub reagiert auf
  // den Modus-Toggle. Lauf-Modus zeigt run-only Aggregate (`yearlyRunDistanceKm`),
  // Rad-Modus zeigt diese parallel — selbe Code-Pfade, andere Slice der
  // History.

  /// Bike-Distanz pro Tag in den letzten 7 Tagen (oldest → today). Pendant zu
  /// `weeklyRunsByDay`, aber gefiltert auf Bike-Sessions.
  var weeklyBikeByDay: [DailyRunDistance] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let symbols = calendar.shortWeekdaySymbols
    return (0..<7).reversed().map { daysAgo -> DailyRunDistance in
      let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
      let km = bikeOnlyHistory
        .filter { calendar.isDate($0.finishedAt, inSameDayAs: date) }
        .reduce(0.0) { $0 + $1.distanceKm }
      let weekdayIndex = calendar.component(.weekday, from: date) - 1
      let label = String(symbols[weekdayIndex].prefix(2))
      return DailyRunDistance(dayLabel: label, km: km, isToday: daysAgo == 0)
    }
  }

  /// Run-only Pendant zu `weeklyRunsByDay` (welches eigentlich „Cardio total"
  /// ist, da auf `runHistory` und nicht auf `runOnlyHistory` filtert). Wird
  /// im STATS-Tab im Run-Modus genutzt.
  var weeklyRunOnlyByDay: [DailyRunDistance] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let symbols = calendar.shortWeekdaySymbols
    return (0..<7).reversed().map { daysAgo -> DailyRunDistance in
      let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
      let km = runOnlyHistory
        .filter { calendar.isDate($0.finishedAt, inSameDayAs: date) }
        .reduce(0.0) { $0 + $1.distanceKm }
      let weekdayIndex = calendar.component(.weekday, from: date) - 1
      let label = String(symbols[weekdayIndex].prefix(2))
      return DailyRunDistance(dayLabel: label, km: km, isToday: daysAgo == 0)
    }
  }

  /// YTD Bike-Distanz (km).
  var yearlyBikeDistanceKm: Double {
    let startOfYear = Calendar.current.date(
      from: Calendar.current.dateComponents([.year], from: Date())) ?? Date.distantPast
    return bikeOnlyHistory.filter { $0.finishedAt >= startOfYear }.reduce(0) { $0 + $1.distanceKm }
  }

  /// YTD Bike-Anzahl.
  var yearlyBikeCount: Int {
    let startOfYear = Calendar.current.date(
      from: Calendar.current.dateComponents([.year], from: Date())) ?? Date.distantPast
    return bikeOnlyHistory.filter { $0.finishedAt >= startOfYear }.count
  }

  /// YTD Bike-Zeit auf dem Rad (Minuten).
  var yearlyBikeDurationMinutes: Int {
    let startOfYear = Calendar.current.date(
      from: Calendar.current.dateComponents([.year], from: Date())) ?? Date.distantPast
    return bikeOnlyHistory.filter { $0.finishedAt >= startOfYear }.reduce(0) { $0 + $1.durationMinutes }
  }

  /// YTD Bike-Höhenmeter (nur Outdoor-Bike — Indoor hat kein GPS).
  var yearlyBikeElevationGain: Int {
    let startOfYear = Calendar.current.date(
      from: Calendar.current.dateComponents([.year], from: Date())) ?? Date.distantPast
    return bikeOnlyHistory
      .filter { $0.finishedAt >= startOfYear && !$0.modality.isIndoor }
      .reduce(0) { $0 + $1.elevationGain }
  }

  /// Speed-Verteilung für Rad-Sessions — Bike-Pendant zu `paceZones`.
  /// Buckets in km/h, damit Nutzer ein Bauchgefühl für ihre Touren bekommen.
  var bikeSpeedZones: [PaceZoneEntry] {
    let speeds: [Double] = bikeOnlyHistory.compactMap { entry in
      guard entry.averagePaceSeconds > 0 else { return nil }
      return 3600.0 / Double(entry.averagePaceSeconds)
    }
    guard !speeds.isEmpty else { return [] }
    let total = Double(speeds.count)
    let buckets: [(String, String, Double)] = [
      ("Recovery", "<18 km/h",   Double(speeds.filter { $0 < 18 }.count) / total),
      ("Endurance","18–24 km/h", Double(speeds.filter { $0 >= 18 && $0 < 24 }.count) / total),
      ("Tempo",    "24–30 km/h", Double(speeds.filter { $0 >= 24 && $0 < 30 }.count) / total),
      ("Hart",     ">30 km/h",   Double(speeds.filter { $0 >= 30 }.count) / total),
    ]
    return buckets.filter { $0.2 > 0 }.map { PaceZoneEntry(label: $0.0, description: $0.1, fraction: $0.2) }
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

  /// Alle Makros für heute in einem einzigen Array-Pass — verhindert
  /// dass `nutritionCaloriesToday` / `…ProteinToday` / … das Array je
  /// 4× unabhängig filtern + sortieren (O(n log n) × 4 pro Render-Pass).
  private var todayMacroTotals: (calories: Int, protein: Int, carbs: Int, fat: Int) {
    let start = Calendar.current.startOfDay(for: Date())
    return nutritionEntries
      .filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: start) }
      .reduce(into: (calories: 0, protein: 0, carbs: 0, fat: 0)) { acc, e in
        acc.calories += e.calories
        acc.protein  += e.protein
        acc.carbs    += e.carbs
        acc.fat      += e.fat
      }
  }

  var nutritionCaloriesToday: Int { todayMacroTotals.calories }
  var nutritionProteinToday:  Int { todayMacroTotals.protein  }
  var nutritionCarbsToday:    Int { todayMacroTotals.carbs    }
  var nutritionFatToday:      Int { todayMacroTotals.fat      }

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
    scheduleSave()
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
    scheduleSave()
  }

  func setNutritionGoal(_ goal: NutritionGoal) {
    nutritionGoal = goal
    nutritionProfile?.goal = goal
    lastProgressEvent =
      "Ernährungsziel aktualisiert: \(goal.title). Deine Tagesziele wurden angepasst."
    scheduleSave()
  }

  func setNutritionProfile(_ profile: NutritionProfile) {
    nutritionProfile = profile
    nutritionGoal = profile.goal
    lastProgressEvent =
      "Ernährungsziele personalisiert: \(profile.targetCalories) kcal · \(profile.targetProteinG)g Protein berechnet."
    scheduleSave()
  }

  func clearNutritionProfile() {
    nutritionProfile = nil
    lastProgressEvent = "Ernährungsprofil zurückgesetzt. Standardziele werden verwendet."
    scheduleSave()
  }

  func removeNutritionEntry(_ id: UUID) {
    nutritionEntries.removeAll { $0.id == id }
    lastProgressEvent = "Ein Ernährungseintrag wurde entfernt."
    scheduleSave()
  }

  // MARK: - Nutrition Power-Actions (Welle 3 — 2026-05-03)

  /// Loggt einen bestehenden Eintrag erneut (selbe Werte, jetzt als neue
  /// Mahlzeit). Wird vom Recents-Strip und vom Long-Press-Menu „Wieder loggen"
  /// auf einer Food-Row genutzt.
  func repeatNutritionEntry(
    _ entry: NutritionEntry,
    in mealType: RecipeMealType? = nil,
    on date: Date? = nil
  ) {
    let targetMeal = mealType ?? entry.mealType
    let targetDate = mergedStamp(for: date ?? Date())
    let copy = NutritionEntry(
      id: UUID(),
      title: entry.title,
      mealType: targetMeal,
      loggedAt: targetDate,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fat: entry.fat
    )
    nutritionEntries.insert(copy, at: 0)
    proteinProgress = min(260, rounded(proteinProgress + Double(max(0, entry.protein))))
    lastProgressEvent = "Wieder geloggt: \(entry.title)."
    scheduleSave()
  }

  /// Verschiebt einen Eintrag in eine andere Mahlzeit-Sektion (gleicher Tag).
  /// NutritionEntry hat let-Felder — also löschen und mit identischer ID wäre
  /// nicht möglich. Wir entfernen + fügen mit neuer ID neu ein, behalten aber
  /// `loggedAt` damit die Reihenfolge stabil bleibt.
  func moveNutritionEntry(_ id: UUID, to mealType: RecipeMealType) {
    guard let entry = nutritionEntries.first(where: { $0.id == id }) else { return }
    if entry.mealType == mealType { return }
    let updated = NutritionEntry(
      id: UUID(),
      title: entry.title,
      mealType: mealType,
      loggedAt: entry.loggedAt,
      calories: entry.calories,
      protein: entry.protein,
      carbs: entry.carbs,
      fat: entry.fat
    )
    nutritionEntries.removeAll { $0.id == id }
    nutritionEntries.insert(updated, at: 0)
    lastProgressEvent = "\(entry.title) in \(mealType.title) verschoben."
    scheduleSave()
  }

  /// Dupliziert einen bestehenden Eintrag — selbe Mahlzeit, neue ID, jetzt
  /// als Logging-Zeitpunkt. Praktisch für „nochmal das gleiche".
  func duplicateNutritionEntry(_ id: UUID) {
    guard let entry = nutritionEntries.first(where: { $0.id == id }) else { return }
    repeatNutritionEntry(entry, in: entry.mealType)
  }

  /// 2026-05-03 Intuitivitäts-Sweep P1-22: Eintrag nachträglich anpassen.
  /// Statt löschen+neu eintragen scaled der User die Werte direkt — gibt
  /// neue absolute Werte vor. Protein-Tageshochzähler wird dabei korrekt
  /// nach Delta nachgezogen (negative Werte werden gefloored auf 0).
  func updateNutritionEntry(
    _ id: UUID,
    calories: Int? = nil,
    protein: Int? = nil,
    carbs: Int? = nil,
    fat: Int? = nil
  ) {
    guard let idx = nutritionEntries.firstIndex(where: { $0.id == id }) else { return }
    let old = nutritionEntries[idx]
    let newProtein = max(0, protein ?? old.protein)
    let updated = NutritionEntry(
      id: old.id,
      title: old.title,
      mealType: old.mealType,
      loggedAt: old.loggedAt,
      calories: max(0, calories ?? old.calories),
      protein: newProtein,
      carbs: max(0, carbs ?? old.carbs),
      fat: max(0, fat ?? old.fat)
    )
    nutritionEntries[idx] = updated
    // Nur den Tageshochzähler nachziehen, wenn der Eintrag wirklich heute
    // geloggt war — sonst verfälschen wir den Live-Counter.
    if Calendar.current.isDateInToday(old.loggedAt) {
      let delta = newProtein - old.protein
      proteinProgress = max(0, min(260, rounded(proteinProgress + Double(delta))))
    }
    lastProgressEvent = "\(updated.title) angepasst."
    scheduleSave()
  }

  /// Schnell-Eintrag mit nur kcal (+ optional Makros). Mahlzeit kommt aus
  /// dem Quick-Add-Sheet, Titel default „Schnell-Eintrag".
  func quickAddNutrition(
    calories: Int,
    protein: Int = 0,
    carbs: Int = 0,
    fat: Int = 0,
    mealType: RecipeMealType,
    title: String = "Schnell-Eintrag",
    on date: Date = Date()
  ) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedTitle = trimmed.isEmpty ? "Schnell-Eintrag" : trimmed
    let entry = NutritionEntry(
      id: UUID(),
      title: resolvedTitle,
      mealType: mealType,
      loggedAt: mergedStamp(for: date),
      calories: max(0, calories),
      protein: max(0, protein),
      carbs: max(0, carbs),
      fat: max(0, fat)
    )
    nutritionEntries.insert(entry, at: 0)
    proteinProgress = min(260, rounded(proteinProgress + Double(max(0, protein))))
    lastProgressEvent = "Schnell-Eintrag erfasst: \(resolvedTitle)."
    scheduleSave()
  }

  /// Wenn der User in einen anderen Tag loggt, soll der Zeitstempel den
  /// Tageswechsel respektieren — wir setzen die UHRZEIT des angegebenen
  /// Datums auf „jetzt", damit chronologische Sortierung innerhalb des Tags
  /// stabil bleibt.
  private func mergedStamp(for date: Date) -> Date {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return Date() }
    let now = Date()
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
    components.hour = timeComponents.hour
    components.minute = timeComponents.minute
    components.second = timeComponents.second
    return calendar.date(from: components) ?? date
  }

  // MARK: - Nutrition Streak & Charts (Welle 3 — 2026-05-03)

  /// Aufeinanderfolgende Tage rückwärts ab heute mit ≥1 Logging-Eintrag.
  var nutritionStreakDays: Int {
    let calendar = Calendar.current
    var streak = 0
    var daysBack = 0
    while true {
      let date = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
      let startOfDay = calendar.startOfDay(for: date)
      let hasEntry = nutritionEntries.contains {
        calendar.isDate($0.loggedAt, inSameDayAs: startOfDay)
      }
      if hasEntry {
        streak += 1
        daysBack += 1
      } else {
        break
      }
    }
    return streak
  }

  /// Tagesarrays kcal — N Tage rückwärts (oldest → today).
  func dailyCalories(lastDays days: Int) -> [Int] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return (0..<max(1, days)).reversed().map { offset -> Int in
      let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
      return nutritionEntries
        .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
        .reduce(0) { $0 + $1.calories }
    }
  }

  /// Anteil der letzten N Tage (incl. heute), an denen das Protein-Ziel
  /// erreicht wurde (mind. 90 % des Tagesziels).
  func proteinHitRate(lastDays days: Int) -> Double {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let total = max(1, days)
    let target = max(1, nutritionTargetProtein)
    var hits = 0
    for offset in 0..<total {
      let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
      let proteinForDay = nutritionEntries
        .filter { calendar.isDate($0.loggedAt, inSameDayAs: day) }
        .reduce(0) { $0 + $1.protein }
      if Double(proteinForDay) >= Double(target) * 0.9 {
        hits += 1
      }
    }
    return Double(hits) / Double(total)
  }

  /// Letzte unique Lebensmittel der vergangenen 14 Tage (ohne Heute,
  /// damit der Recents-Strip nicht den eben getätigten Log nochmal anbietet).
  /// Dedupliziert anhand des normalisierten Titels — neuester Log gewinnt.
  var recentNutritionFoods: [NutritionEntry] {
    let calendar = Calendar.current
    let now = Date()
    let cutoff = calendar.date(byAdding: .day, value: -14, to: now) ?? now
    let todayStart = calendar.startOfDay(for: now)

    var seen: Set<String> = []
    var result: [NutritionEntry] = []
    for entry in nutritionEntries.sorted(by: { $0.loggedAt > $1.loggedAt }) {
      if entry.loggedAt < cutoff { break }
      if entry.loggedAt >= todayStart { continue }
      let key = entry.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
      if key.isEmpty { continue }
      if seen.contains(key) { continue }
      seen.insert(key)
      result.append(entry)
      if result.count >= 12 { break }
    }
    return result
  }

  /// Headline-String für den Cardio-Hero. 2026-05-03 (P1-6): Modality-aware
  /// — Bike-Sessions zeigen km/h statt Pace, Latest-Cardio nutzt das richtige
  /// Verb (Lauf/Tour/Heimtrainer) und der Empty-State spricht nicht mehr nur
  /// von „Lauf".
  var runningHeadline: String {
    if let activeRun {
      let distance = String(format: "%.1f", activeRun.distanceKm)
      if activeRun.modality.isCycling {
        let kmh = activeRun.averagePaceSeconds > 0
          ? String(format: "%.1f km/h", 3600.0 / Double(activeRun.averagePaceSeconds))
          : "--,- km/h"
        return "Live: \(distance) km · \(kmh)"
      }
      return "Live: \(distance) km · \(formattedPace(secondsPerKilometer: activeRun.averagePaceSeconds))"
    }

    if let latestCompletedRun {
      let distance = String(format: "%.1f", latestCompletedRun.distanceKm)
      switch latestCompletedRun.modality {
      case .run:
        return "Letzter Lauf: \(latestCompletedRun.title) über \(distance) km"
      case .bikeOutdoor:
        return "Letzte Tour: \(latestCompletedRun.title) über \(distance) km"
      case .bikeIndoor:
        return "Heimtrainer: \(latestCompletedRun.title) — \(distance) km"
      }
    }

    return "Starte deine erste Cardio-Session"
  }

  var runningDescription: String {
    if let activeRun {
      if activeRun.modality.isCycling {
        return
          "Distanz, Geschwindigkeit und Puls laufen live. Du kannst die Tour direkt steuern oder beenden."
      }
      return
        "Deine Pace, Herzfrequenz und Distanz laufen gerade live mit. Du kannst den Lauf direkt tracken oder abschließen."
    }

    if weeklyRunCount > 0 {
      return
        "\(weeklyRunCount) Sessions und \(String(format: "%.1f", weeklyRunDistanceKm)) km in den letzten 7 Tagen — Lauf und Rad zusammen."
    }

    return
      "Wähle Lauf, Rad oder Heimtrainer — Gains tracked Pace/Geschwindigkeit, Distanz und Splits automatisch."
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
    scheduledPlannerDays.filter { plannerSettings.dayAssignments[$0] != nil }.count
  }

  var plannerSummaryHeadline: String {
    let plannedSessions = scheduledPlannerDays.count

    if plannedSessions == 0 {
      return "Plane jetzt deine erste Trainingswoche"
    }

    return "\(plannedSessions) Tage · Priorität \(plannerSettings.trainingFocus.title)"
  }

  var plannerSummaryDescription: String {
    plannerPrimaryRecommendation.detail
  }

  var plannerPrimaryRecommendation: PlannerRecommendation {
    plannerRecommendations.first
      ?? PlannerRecommendation(
        title: "Plan offen", detail: "Lege zuerst Trainingstage fest und wähle dann deinen Fokus.", weekdays: [])
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
    if let ownPost = communityPosts.first(where: { $0.handle == userHandle }) {
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
    let f = StoreFormatters.dayMonthDE
    return "\(f.string(from: start)) – \(f.string(from: end))"
  }

  var selectedCalendarHeadline: String {
    StoreFormatters.weekdayDayMonthDE.string(from: selectedCalendarDate).capitalized
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

  /// Wiederholt das zuletzt absolvierte Workout — sucht im savedWorkoutPlans
  /// nach demselben Titel, fällt sonst auf das letzte gespeicherte Plan-Match
  /// zurück. Kein-op, wenn schon ein Workout aktiv oder noch keine Historie da.
  /// Returns true wenn ein Workout gestartet wurde.
  @discardableResult
  func repeatLastWorkout() -> Bool {
    guard activeWorkout == nil, let last = workoutHistory.first else { return false }
    let plan = savedWorkoutPlans.first(where: { $0.title == last.title })
      ?? currentWorkoutPreview
    activeWorkout = WorkoutSession.fromPlan(plan)
    return true
  }

  func discardWorkout() {
    activeWorkout = nil
    // P1-3: Pause-Timer-State mit dem Workout zusammen wegwerfen, sonst
    // wirkt er beim nächsten Workout-Start fehlerhaft fort.
    activeRestTimerEndsAt = nil
  }

  func startRun(from template: RunTemplate) {
    guard activeRun == nil else { return }
    activeRun = ActiveRunSession.fromTemplate(template)
  }

  /// Quick-Run ohne Template — bewusst frei, damit der User im Pre-Run-Setup
  /// Intensität / Ziel / Audio-Cues selbst wählt. Optional kann eine
  /// Cardio-Modalität mitgegeben werden (Lauf / Outdoor-Rad / Indoor-Rad).
  func startQuickRun(modality: CardioModality = .run) {
    guard activeRun == nil else { return }
    activeRun = ActiveRunSession.freshQuickRun(modality: modality)
  }

  /// Setzt die Cardio-Modalität (Lauf/Rad outdoor/Rad indoor) auf einem
  /// bereits aktiven Run-Setup. Wird vom PreRunSetupView genutzt, damit der
  /// Wechsel im Picker auch nach `startQuickRun()` greift.
  func setRunModality(_ modality: CardioModality) {
    guard var run = activeRun else { return }
    run.modality = modality
    // Auto-Pause für Indoor abschalten — Heimtrainer steht ohnehin still.
    if modality.isIndoor { run.autoPauseEnabled = false }
    activeRun = run
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
      targetMode: run.distanceKm > 0 ? .distance : .free,
      targetPaceSeconds: run.averagePaceSeconds,
      intensity: run.intensity,
      distanceKm: 0,
      durationMinutes: 0,
      elevationGain: 0,
      currentHeartRate: max(run.averageHeartRate - 8, 120),
      isPaused: false,
      autoPauseEnabled: true,
      audioCuesEnabled: true,
      routeCoordinates: [],
      splits: [],
      hrZoneSecondsBuckets: [0, 0, 0, 0, 0],
      modality: run.modality
    )
  }

  func discardRun() {
    activeRun = nil
  }

  /// Verwirft einen aktiven Lauf ohne ihn in die History zu speichern (Stop-Flow).
  func discardActiveRun() {
    guard activeRun != nil else { return }
    activeRun = nil
    // 2026-05-01: Wenn ein strukturiertes Workout am Lauf hing (Intervalle /
    // Phasen), muss es ebenfalls verworfen werden — sonst lädt der nächste
    // Run-Start die alten Steps wieder, was Tester verwirrt. Root Cause der
    // letzten „release: clear stop sheet state on run close"-Patches.
    activeStructuredWorkout = nil
    lastProgressEvent = "Lauf verworfen — keine Änderung in der History."
  }

  // MARK: – Pre-Run Setup

  func setRunIntensity(_ intensity: RunIntensity) {
    activeRun?.intensity = intensity
  }

  /// Setzt den Ziel-Modus (Distanz/Zeit/Pace/Frei) inkl. zugehöriger Werte.
  func setRunTarget(mode: RunTargetMode, distanceKm: Double = 0, durationMinutes: Int = 0, paceSeconds: Int = 0) {
    guard var run = activeRun else { return }
    run.targetMode = mode
    switch mode {
    case .free:
      break
    case .distance:
      run = ActiveRunSession(
        id: run.id, title: run.title, routeName: run.routeName, startedAt: run.startedAt,
        targetDistanceKm: max(distanceKm, 0), targetDurationMinutes: run.targetDurationMinutes,
        targetPaceLabel: run.targetPaceLabel, targetMode: .distance,
        targetPaceSeconds: run.targetPaceSeconds, intensity: run.intensity,
        distanceKm: run.distanceKm, durationMinutes: run.durationMinutes,
        elevationGain: run.elevationGain, currentHeartRate: run.currentHeartRate,
        isPaused: run.isPaused, autoPauseEnabled: run.autoPauseEnabled,
        audioCuesEnabled: run.audioCuesEnabled, routeCoordinates: run.routeCoordinates,
        splits: run.splits, hrZoneSecondsBuckets: run.hrZoneSecondsBuckets,
        modality: run.modality
      )
    case .duration:
      run = ActiveRunSession(
        id: run.id, title: run.title, routeName: run.routeName, startedAt: run.startedAt,
        targetDistanceKm: run.targetDistanceKm, targetDurationMinutes: max(durationMinutes, 0),
        targetPaceLabel: run.targetPaceLabel, targetMode: .duration,
        targetPaceSeconds: run.targetPaceSeconds, intensity: run.intensity,
        distanceKm: run.distanceKm, durationMinutes: run.durationMinutes,
        elevationGain: run.elevationGain, currentHeartRate: run.currentHeartRate,
        isPaused: run.isPaused, autoPauseEnabled: run.autoPauseEnabled,
        audioCuesEnabled: run.audioCuesEnabled, routeCoordinates: run.routeCoordinates,
        splits: run.splits, hrZoneSecondsBuckets: run.hrZoneSecondsBuckets,
        modality: run.modality
      )
    case .pace:
      run.targetPaceSeconds = max(paceSeconds, 0)
    }
    activeRun = run
  }

  func setAutoPause(_ enabled: Bool) {
    activeRun?.autoPauseEnabled = enabled
  }

  func setAudioCues(_ enabled: Bool) {
    activeRun?.audioCuesEnabled = enabled
  }

  // MARK: – Manueller Lap

  /// Fügt einen vom Nutzer ausgelösten Lap an die Splits an. Distanz/Zeit
  /// werden vom Tracker übergeben (seit dem letzten Lap-Anker).
  func addManualLap(distanceKm: Double, durationSeconds: Int, heartRate: Int) {
    guard activeRun != nil, distanceKm > 0 else { return }
    let split = RunSplit(
      id: UUID(),
      index: (activeRun?.splits.count ?? 0) + 1,
      distanceKm: rounded(distanceKm),
      durationMinutes: max(Int((Double(durationSeconds) / 60).rounded()), 1),
      averageHeartRate: max(heartRate, 0),
      isManualLap: true
    )
    activeRun?.splits.append(split)
  }

  // MARK: – HF-Zonen-Tracking

  /// Maximale Herzfrequenz aus dem Profil (Tanaka 2001: 208 − 0,7 × Alter).
  /// Fallback 190 bpm, falls kein Profil hinterlegt ist.
  var estimatedMaxHeartRate: Int {
    if let age = nutritionProfile?.age, age > 0 {
      return Int((208.0 - 0.7 * Double(age)).rounded())
    }
    return 190
  }

  /// Erhöht das HF-Zonen-Bucket des aktiven Laufs um 1 Sekunde.
  /// Vom Live-Screen einmal pro Sekunde aufrufen, solange nicht pausiert.
  func tickRunHeartRateZone(currentBpm: Int) {
    guard activeRun != nil, currentBpm > 0 else { return }
    guard let zone = HRZone.zone(for: currentBpm, maxHR: estimatedMaxHeartRate) else { return }
    let idx = zone.rawValue - 1
    var buckets = activeRun?.hrZoneSecondsBuckets ?? [0, 0, 0, 0, 0]
    if buckets.count < 5 { buckets = [0, 0, 0, 0, 0] }
    buckets[idx] += 1
    activeRun?.hrZoneSecondsBuckets = buckets
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

  /// Beendet den aktiven Lauf und speichert ihn als CompletedRunSummary.
  /// Optional können beim Speichern Name, Notiz und Empfinden überschrieben werden.
  func finishRun(
    customTitle: String? = nil,
    note: String = "",
    feel: RunFeel? = nil
  ) {
    // Bug-Fix: vorher wurde der Lauf still verworfen, sobald die GPS-Distanz
    // 0 km war — z. B. weil der Nutzer Indoor lief, GPS keinen Fix hatte
    // oder die Berechtigung erst nach dem Lauf-Start erteilt wurde. Jetzt
    // wird er auch ohne Distanz gespeichert, solange mindestens eine Minute
    // gelaufen wurde — der Nutzer behält seinen Lauf in der Historie.
    guard let run = activeRun, run.distanceKm > 0 || run.durationMinutes >= 1 else { return }

    let trimmedTitle = customTitle?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .nilIfEmpty ?? run.title

    let avgHR: Int = {
      // Wenn Splits HF-Daten haben, daraus den Schnitt bilden — sonst Live-HF.
      let hrSplits = run.splits.filter { $0.averageHeartRate > 0 }
      guard !hrSplits.isEmpty else { return run.currentHeartRate }
      let total = hrSplits.reduce(0) { $0 + $1.averageHeartRate }
      return Int(Double(total) / Double(hrSplits.count))
    }()

    let summary = CompletedRunSummary(
      id: UUID(),
      title: trimmedTitle,
      routeName: run.routeName,
      finishedAt: Date(),
      distanceKm: run.distanceKm,
      durationMinutes: run.durationMinutes,
      elevationGain: run.elevationGain,
      averageHeartRate: avgHR,
      routeCoordinates: run.routeCoordinates,
      splits: run.splits,
      intensity: run.intensity,
      feel: feel,
      note: note.trimmingCharacters(in: .whitespacesAndNewlines),
      hrZoneSecondsBuckets: run.hrZoneSecondsBuckets,
      modality: run.modality
    )

    registerCompletedDay(summary.finishedAt)
    applyRunProgress(from: summary)
    runHistory.insert(summary, at: 0)
    let runStartedAt = run.startedAt
    activeRun = nil
    // Strava-Erweiterung: strukturiertes Workout (falls aktiv) freigeben und
    // Segment-Auto-Matching + Route-Usage-Recount auslösen.
    activeStructuredWorkout = nil
    matchSegments(against: summary)
    recountRouteUsage()
    lastProgressEvent =
      "Lauf gespeichert: \(String(format: "%.1f", summary.distanceKm)) km mit \(formattedPace(secondsPerKilometer: summary.averagePaceSeconds))."

    // Apple Health: Lauf bzw. Rad-Session inklusive Distanz und (bei Outdoor)
    // GPS-Route nach HKWorkoutRoute schreiben — sonst doppeltes Tracking
    // gegenüber Strava / Apple-Workout. Indoor-Bike → ohne Route.
    HealthKitManager.shared.saveRunWorkout(
      title: trimmedTitle,
      start: runStartedAt,
      end: summary.finishedAt,
      distanceKm: summary.distanceKm,
      routeCoordinates: summary.modality.isIndoor ? [] : summary.routeCoordinates,
      isCycling: summary.modality.isCycling
    )

    if socialSharingSettings.autoShareRuns {
      shareLatestRun()
    }

    NotificationsManager.shared.refreshSchedule(for: self)

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
    scheduleSave()
    return workout
  }

  func deleteWorkout(_ plan: WorkoutPlan) {
    savedWorkoutPlans.removeAll(where: { $0.id == plan.id })
    // Remove day assignments that referenced this workout
    for weekday in plannerSettings.dayAssignments.keys {
      if plannerSettings.dayAssignments[weekday] == plan.id {
        plannerSettings.dayAssignments[weekday] = nil
        if plannerSettings.isManualPlan {
          plannerSettings.manualSessionKinds[weekday] = nil
        }
      }
    }
    alignSessionTargetToAvailableDays()
    scheduleSave()
  }

  /// Dupliziert einen bestehenden Workout-Plan als neuen `.custom`-Eintrag
  /// (mit „(Kopie)" im Titel). Quick-Action im WORKOUTS-Tab — Vorlagen lassen
  /// sich so als Basis für eigene Pläne übernehmen, ohne sie nachzubauen.
  @discardableResult
  func duplicateWorkout(_ plan: WorkoutPlan) -> WorkoutPlan {
    let copy = WorkoutPlan(
      id: UUID(),
      source: .custom,
      title: "\(plan.title) (Kopie)",
      focus: plan.focus,
      split: plan.split,
      estimatedDurationMinutes: plan.estimatedDurationMinutes,
      exercises: plan.exercises.map { template in
        WorkoutExerciseTemplate(
          name: template.name,
          targetMuscle: template.targetMuscle,
          sets: template.sets.map { set in
            WorkoutSetTemplate(reps: set.reps, suggestedWeight: set.suggestedWeight)
          }
        )
      }
    )
    savedWorkoutPlans.insert(copy, at: 0)
    scheduleSave()
    return copy
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
    scheduleSave()
    return preserved
  }

  func updateSessionsPerWeek(_ value: Int) {
    let desiredDays = min(max(value, 1), 7)
    rebalancePlannerAvailability(for: desiredDays)
    plannerSettings.sessionsPerWeek = normalizedSessionsPerWeek(desiredDays)
    invalidatePlannerCache()
    scheduleSave()
  }

  func setPlannerGoal(_ goal: WorkoutPlanningGoal) {
    plannerSettings.goal = goal
    invalidatePlannerCache()
    scheduleSave()
  }

  func setTrainingFocus(_ focus: WorkoutTrainingFocus) {
    plannerSettings.trainingFocus = focus
    invalidatePlannerCache()
    scheduleSave()
  }

  func setPreferredSessionLength(_ duration: Int) {
    plannerSettings.preferredSessionLength = duration
    invalidatePlannerCache()
    scheduleSave()
  }

  // MARK: - Studienbasierte Planner-Setter

  func setTrainingExperience(_ value: TrainingExperience) {
    plannerSettings.experience = value
    invalidatePlannerCache()
    scheduleSave()
  }

  func setGymEquipment(_ value: GymEquipment) {
    plannerSettings.equipment = value
    invalidatePlannerCache()
    scheduleSave()
  }

  func setSplitPreference(_ value: SplitPreference) {
    plannerSettings.splitPreference = value
    invalidatePlannerCache()
    scheduleSave()
  }

  func setRecoveryCapacity(_ value: RecoveryCapacity) {
    plannerSettings.recoveryCapacity = value
    invalidatePlannerCache()
    scheduleSave()
  }

  func toggleMusclePriority(_ muscle: MuscleGroup) {
    if plannerSettings.prioritizedMuscles.contains(muscle) {
      plannerSettings.prioritizedMuscles.remove(muscle)
    } else {
      plannerSettings.prioritizedMuscles.insert(muscle)
    }
    invalidatePlannerCache()
    scheduleSave()
  }

  func toggleLimitation(_ limitation: WorkoutLimitation) {
    if plannerSettings.limitations.contains(limitation) {
      plannerSettings.limitations.remove(limitation)
    } else {
      plannerSettings.limitations.insert(limitation)
    }
    invalidatePlannerCache()
    scheduleSave()
  }

  func setRunningGoal(_ goal: RunningGoal) {
    plannerSettings.runningGoal = goal
    // Wenn der User explizit ein Lauf-Ziel setzt, schlagen wir den passenden km-Wert vor,
    // sofern er noch beim Default ist oder darunterliegt.
    if plannerSettings.weeklyKilometerTarget < goal.defaultWeeklyKilometers {
      plannerSettings.weeklyKilometerTarget = goal.defaultWeeklyKilometers
    }
    invalidatePlannerCache()
    scheduleSave()
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
    // Bug-Fix: Wir setzen die Tagespräferenzen NICHT mehr blind auf .flexible
    // — der PLAN-Tab erlaubt dem Nutzer, jeden Tag explizit als
    // Training/Frei/Flex zu markieren, und der Wizard fragt das nicht ab.
    // Vorher hat „Plan übernehmen" diese Einteilung komplett überschrieben.
    // Nur wenn der Nutzer noch nie Tagespräferenzen gesetzt hat (z.B. erstes
    // Mal Wizard nach Onboarding), füllen wir mit .flexible vor, damit die
    // Engine etwas zu verteilen hat.
    let hasAnyPreference = Weekday.allCases.contains { plannerSettings.dayPreferences[$0] != nil }
    if !hasAnyPreference {
      for day in Weekday.allCases {
        plannerSettings.dayPreferences[day] = .flexible
      }
    }
    invalidatePlannerCache()
    scheduleSave()
  }

  func setRunIntensityModel(_ model: RunIntensityModel) {
    plannerSettings.runIntensityModel = model
    invalidatePlannerCache()
    scheduleSave()
  }

  func setWeeklyKilometerTarget(_ km: Int) {
    plannerSettings.weeklyKilometerTarget = max(0, min(150, km))
    invalidatePlannerCache()
    scheduleSave()
  }

  /// Setzt die Day-Preference direkt (wird vom überarbeiteten PLAN-Tab
  /// genutzt, wo Training/Frei/Flex als drei sichtbare Buttons gewählt werden,
  /// statt dem alten verdeckten Tap-Cycle).
  func setDayPreference(_ preference: WorkoutDayPreference, for weekday: Weekday) {
    plannerSettings.dayPreferences[weekday] = preference

    // Bei manuellem Plan halten wir die Manual-Map konsistent: ein Tag, der
    // auf Frei wechselt, verliert seinen Session-Kind-Eintrag; ein Tag, der
    // ohne Kind auf Training/Flex gehoben wird, fällt auf .strength zurück
    // (häufigster Default), damit der Tag in der UI nicht leer wirkt.
    if plannerSettings.isManualPlan {
      switch preference {
      case .rest:
        plannerSettings.manualSessionKinds[weekday] = nil
      case .training, .flexible:
        if plannerSettings.manualSessionKinds[weekday] == nil {
          plannerSettings.manualSessionKinds[weekday] = .strength
        }
      }
    }

    alignSessionTargetToAvailableDays()
    invalidatePlannerCache()
    scheduleSave()
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

    // Wer im manuellen Plan ein Workout zuweist, will für diesen Tag
    // klar Krafttraining — ggf. überschriebene Lauf-Markierung wird ersetzt.
    if plannerSettings.isManualPlan {
      plannerSettings.manualSessionKinds[weekday] = .strength
    }

    alignSessionTargetToAvailableDays()
    invalidatePlannerCache()
    scheduleSave()
  }

  func clearAssignedWorkout(for weekday: Weekday) {
    plannerSettings.dayAssignments[weekday] = nil
    alignSessionTargetToAvailableDays()
    invalidatePlannerCache()
    scheduleSave()
  }

  // MARK: - Plan-Done-Helpers
  //
  // 2026-05-03: Mit der Wochen-Überarbeitung soll jeder geplante Tag
  // auf einen Blick zeigen, ob er „erledigt" ist — sowohl im PLAN-Tab als
  // auch in der Home-Heute-Card und der Mini-Wochenleiste. Statt einen
  // separaten `Set<Date>` einzuführen, leiten wir den Done-Status aus den
  // bereits vorhandenen `workoutHistory` und `runHistory` ab. Vorher gab es
  // diesen Check nur inline in `nextFourWeeksSchedule` — und dort _ohne_
  // Lauf-History, sodass abgeschlossene Läufe nie als ✓ markiert wurden.

  /// Wurde an `date` (Tagesgranularität) bereits ein Krafttraining ODER
  /// ein Lauf abgeschlossen? Dient als zentrale Done-Quelle für alle
  /// Plan-/Wochen-/Home-UI-Bausteine.
  func isPlannedSessionCompleted(on date: Date) -> Bool {
    let cal = Calendar.current
    if workoutHistory.contains(where: { cal.isDate($0.finishedAt, inSameDayAs: date) }) {
      return true
    }
    if runHistory.contains(where: { cal.isDate($0.finishedAt, inSameDayAs: date) }) {
      return true
    }
    return false
  }

  /// Convenience: Done-Check für einen Wochentag in der aktuellen Woche
  /// (Montag = Wochenstart). Kürzt den Aufruf auf der UI-Seite ab.
  func isPlannedSessionCompletedToday(for weekday: Weekday) -> Bool {
    var cal = Calendar(identifier: .iso8601)
    cal.firstWeekday = 2
    let today = Date()
    guard
      let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)),
      let date = cal.date(byAdding: .day, value: weekday.mondayOffset, to: weekStart)
    else {
      return false
    }
    return isPlannedSessionCompleted(on: date)
  }

  /// Tauscht zwei Wochentage komplett: Tagespräferenz, Workout-Zuweisung
  /// und manuelles SessionKind. Genutzt vom WeekdayDetailSheet, damit der
  /// Nutzer „heute Push, morgen Pull" mit einem Tap umkehren kann, ohne
  /// erst beide Tage einzeln neu zu konfigurieren.
  func swapDayAssignments(_ a: Weekday, _ b: Weekday) {
    guard a != b else { return }

    let prefA = plannerSettings.dayPreferences[a]
    let prefB = plannerSettings.dayPreferences[b]
    plannerSettings.dayPreferences[a] = prefB
    plannerSettings.dayPreferences[b] = prefA

    let assignA = plannerSettings.dayAssignments[a]
    let assignB = plannerSettings.dayAssignments[b]
    plannerSettings.dayAssignments[a] = assignB
    plannerSettings.dayAssignments[b] = assignA

    if plannerSettings.isManualPlan {
      let kindA = plannerSettings.manualSessionKinds[a]
      let kindB = plannerSettings.manualSessionKinds[b]
      plannerSettings.manualSessionKinds[a] = kindB
      plannerSettings.manualSessionKinds[b] = kindA
    }

    alignSessionTargetToAvailableDays()
    invalidatePlannerCache()
    scheduleSave()
  }

  // MARK: - Manueller Wochenplan
  //
  // Speichert eine vom Nutzer selbst zusammengestellte Wochenstruktur.
  // `entries` enthält pro Trainingstag die Session-Art (.strength oder ein
  // Run-Kind). Tage ohne Eintrag werden als Ruhetage eingetragen.
  // `assignments` mappt Krafttage auf konkrete WorkoutPlan-IDs.

  func applyManualPlan(
    entries: [Weekday: PlannedSessionKind],
    assignments: [Weekday: UUID]
  ) {
    // Tagespräferenzen aus den Einträgen ableiten — alles nicht-Trainings-
    // tag zählt als Frei. Vermeidet, dass alte .flexible-Einträge die
    // Auto-Verteilung der Engine wieder triggern, falls der Nutzer den
    // manuellen Modus später deaktiviert.
    var newPrefs: [Weekday: WorkoutDayPreference] = [:]
    for day in Weekday.allCases {
      newPrefs[day] = entries[day] != nil ? .training : .rest
    }
    plannerSettings.dayPreferences = newPrefs

    // Assignments übernehmen — aber nur für Tage, die tatsächlich Krafttage
    // sind. Lauftage haben keine Workout-Bindung.
    var cleanedAssignments: [Weekday: UUID] = [:]
    for (day, planID) in assignments where entries[day] == .strength {
      cleanedAssignments[day] = planID
    }
    plannerSettings.dayAssignments = cleanedAssignments

    plannerSettings.manualSessionKinds = entries
    plannerSettings.isManualPlan = true
    plannerSettings.sessionsPerWeek = entries.count

    // Trainingsfokus aus dem Mix ableiten — beeinflusst Header-Texte und
    // Empfehlungs-Karten, lässt die manuelle Verteilung selbst aber unberührt.
    let strengthCount = entries.values.filter { $0 == .strength }.count
    let runCount = entries.values.filter { $0.isRun }.count
    if runCount == 0 {
      plannerSettings.trainingFocus = .strength
    } else if strengthCount == 0 {
      plannerSettings.trainingFocus = .cardio
    } else {
      plannerSettings.trainingFocus = .hybrid
    }

    invalidatePlannerCache()
    scheduleSave()
  }

  /// Hebt den manuellen Plan auf — die Engine übernimmt wieder die
  /// Auto-Verteilung anhand der Wizard-Settings. Tagespräferenzen bleiben
  /// erhalten, weil der Nutzer sonst von vorn anfangen müsste.
  func clearManualPlan() {
    plannerSettings.isManualPlan = false
    plannerSettings.manualSessionKinds = [:]
    invalidatePlannerCache()
    scheduleSave()
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
    // 2026-05-01: Schutz gegen leere Geister-Workouts in der History.
    // Wenn der Nutzer „WORKOUT BEENDEN" tippt ohne einen Satz abgeschlossen
    // zu haben (z.B. Tracker versehentlich geöffnet), landet sonst ein
    // 0-Sätze-/0-Volumen-Eintrag in `workoutHistory` und verfälscht Streak,
    // Wochenring und Stats. In dem Fall sauber verwerfen statt loggen.
    guard workout.completedSets > 0 else {
      discardWorkout()
      return
    }
    let workoutStartedAt = workout.startedAt
    let workoutFinishedAt = Date()

    let summary = CompletedWorkoutSummary(
      title: workout.title,
      finishedAt: workoutFinishedAt,
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
    // P1-3: Pause-Timer beim Workout-Ende clearen, damit er beim nächsten
    // Start nicht aus Versehen weiterläuft.
    activeRestTimerEndsAt = nil

    // Apple Health: Workout zurückschreiben, damit Gains-Aktivitäten in der
    // iOS-Health-App und in den Aktivitäts-Ringen auftauchen. Schlägt still
    // fehl, wenn das Schreibrecht nicht erteilt wurde.
    HealthKitManager.shared.saveStrengthWorkout(
      title: workout.title,
      start: workoutStartedAt,
      end: workoutFinishedAt
    )

    // Auto-Share, falls in den Social-Settings aktiviert
    if socialSharingSettings.autoShareWorkouts {
      shareLatestWorkout()
    }
    detectAndShareNewPRs(from: summary)

    NotificationsManager.shared.refreshSchedule(for: self)

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

  /// Optimierungs-Sweep 2026-05-03: Entfernt einen einzelnen Satz aus einer
  /// Übung. Genutzt vom Set-Context-Menu im WorkoutTrackerView. Lässt
  /// mindestens einen Satz stehen, damit die Übungs-Karte nicht leer wird,
  /// und nummeriert die verbleibenden Sätze neu durch.
  func removeSet(exerciseID: UUID, setID: UUID) {
    guard let exerciseIndex = activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseID })
    else { return }
    let sets = activeWorkout?.exercises[exerciseIndex].sets ?? []
    guard sets.count > 1, sets.contains(where: { $0.id == setID }) else { return }
    activeWorkout?.exercises[exerciseIndex].sets.removeAll { $0.id == setID }
    // Order neu vergeben, damit die UI die Sätze als 1..n anzeigt.
    if var renumbered = activeWorkout?.exercises[exerciseIndex].sets {
      for index in renumbered.indices {
        renumbered[index].order = index + 1
      }
      activeWorkout?.exercises[exerciseIndex].sets = renumbered
    }
  }

  /// Optimierungs-Sweep 2026-05-03: Dupliziert einen einzelnen Satz als
  /// neuen, OFFENEN Satz hinter dem Original. Anders als `repeatLastSet`
  /// (das einen abgeschlossenen Satz anhängt) erzeugt dies einen neuen
  /// Satz, den der User noch tracken muss — perfekt für Drop-Sätze.
  @discardableResult
  func duplicateSet(exerciseID: UUID, setID: UUID) -> Bool {
    guard let exerciseIndex = activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseID })
    else { return false }
    let sets = activeWorkout?.exercises[exerciseIndex].sets ?? []
    guard let sourceIndex = sets.firstIndex(where: { $0.id == setID }) else { return false }
    let source = sets[sourceIndex]
    let newSet = TrackedSet(
      order: source.order + 1,
      reps: source.reps,
      weight: source.weight,
      isCompleted: false
    )
    activeWorkout?.exercises[exerciseIndex].sets.insert(newSet, at: sourceIndex + 1)
    // Order neu vergeben, damit Folge-Sätze ihre Nummer behalten.
    if var renumbered = activeWorkout?.exercises[exerciseIndex].sets {
      for index in renumbered.indices {
        renumbered[index].order = index + 1
      }
      activeWorkout?.exercises[exerciseIndex].sets = renumbered
    }
    return true
  }

  /// G4-Fix (2026-05-01): „Letzten Satz wiederholen" — kopiert Gewicht/Reps
  /// vom vorherigen completed Set und legt einen NEU completeden Satz an.
  /// Wenn kein vorheriger Satz vorhanden ist (sollte nicht passieren, da
  /// `startWorkout` immer mindestens einen Set erzeugt), wird die Funktion
  /// stillschweigend übersprungen. Returns: true, wenn der Satz angelegt
  /// wurde — der Caller kann dann z. B. den Pause-Timer starten.
  @discardableResult
  func repeatLastSet(for exerciseID: UUID) -> Bool {
    guard let exerciseIndex = activeWorkout?.exercises.firstIndex(where: { $0.id == exerciseID })
    else { return false }
    let existingSets = activeWorkout?.exercises[exerciseIndex].sets ?? []
    // Bevorzugt der letzte abgeschlossene Satz; wenn keiner abgeschlossen
    // ist, der schlicht letzte. So wirkt der Knopf konsistent: er
    // wiederholt das, was zuletzt zählte.
    let reference = existingSets.last(where: { $0.isCompleted }) ?? existingSets.last
    guard let ref = reference else { return false }
    let newOrder = (existingSets.last?.order ?? 0) + 1
    let newSet = TrackedSet(
      order: newOrder,
      reps: ref.reps,
      weight: ref.weight,
      isCompleted: true
    )
    activeWorkout?.exercises[exerciseIndex].sets.append(newSet)
    return true
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
    scheduleSave()
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
        author: userName,
        handle: userHandle,
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
        author: userName,
        handle: userHandle,
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
        author: userName,
        handle: userHandle,
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
    scheduleSave()
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
    scheduleSave()
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
    contactStore.requestAccess(for: .contacts) { [weak self] granted, _ in
      DispatchQueue.main.async {
        guard let self else { return }
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
    scheduleSave()
  }

  func setAutoShareRuns(_ enabled: Bool) {
    socialSharingSettings.autoShareRuns = enabled
    scheduleSave()
  }

  func setAutoSharePersonalRecords(_ enabled: Bool) {
    socialSharingSettings.autoSharePersonalRecords = enabled
    scheduleSave()
  }

  func setShareLocationWithRuns(_ enabled: Bool) {
    socialSharingSettings.shareLocationWithRuns = enabled
    scheduleSave()
  }

  func setSharingVisibility(_ visibility: SharingVisibility) {
    socialSharingSettings.visibility = visibility
    scheduleSave()
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
      handle: userHandle,
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

  // MARK: - Profil (2026-05-03)
  //
  // Hilfsmethoden, die von der neuen ProfileView aufgerufen werden um den
  // angezeigten Namen oder das Avatar-Bild zu ändern. Beide setzen die
  // @Published-Eigenschaft (UI-Update) und persistieren danach asynchron
  // via saveAll() — der Caller muss sich nicht um Speicherung kümmern.

  /// Setzt den Anzeigenamen. Leerzeichen werden getrimmt; ein leerer
  /// Name fällt auf den unbenutzten Initial-Zustand zurück (Greeting
  /// rendert dann ohne Komma + Name, Avatar zeigt „·").
  func setUserName(_ newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed != userName else { return }
    userName = trimmed
    scheduleSave()
  }

  /// Speichert ein neu gewähltes Profilbild. Komprimiert auf max. 512×512
  /// (kürzere Kante) als JPEG-Quality 0.7 — ~50-150 KB pro Bild, liegt
  /// problemlos in den UserDefaults und ist schnell zu deserialisieren.
  /// `nil` setzt zurück auf den Initial-Letter-Avatar.
  func setUserAvatar(_ image: UIImage?) {
    guard let image else {
      userAvatarData = nil
      scheduleSave()
      return
    }
    let target: CGFloat = 512
    let aspect = image.size.width / max(image.size.height, 1)
    let newSize: CGSize
    if image.size.width <= target && image.size.height <= target {
      newSize = image.size
    } else if aspect >= 1 {
      newSize = CGSize(width: target, height: target / aspect)
    } else {
      newSize = CGSize(width: target * aspect, height: target)
    }
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let resized = renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    userAvatarData = resized.jpegData(compressionQuality: 0.7)
    scheduleSave()
  }

  /// Convenience: gibt das gespeicherte Profilbild als UIImage zurück
  /// (oder nil, wenn keins gesetzt ist).
  var userAvatarImage: UIImage? {
    guard let data = userAvatarData, !data.isEmpty else { return nil }
    return UIImage(data: data)
  }

  func toggleNotificationsEnabled() {
    notificationsEnabled.toggle()
    scheduleSave()

    // Wenn der Toggle gerade auf `on` gewandert ist und der Nutzer noch
    // keine Permission erteilt hat, jetzt das System-Prompt anstoßen.
    // Anschließend in jedem Fall die Schedule neu aufbauen — Manager
    // canceled selbst, falls Permission fehlt oder Toggle aus ist.
    if notificationsEnabled {
      NotificationsManager.shared.requestAuthorization { [weak self] _ in
        guard let self else { return }
        NotificationsManager.shared.refreshSchedule(for: self)
      }
    } else {
      NotificationsManager.shared.refreshSchedule(for: self)
    }
  }

  func toggleHealthAutoSyncEnabled() {
    healthAutoSyncEnabled.toggle()
    scheduleSave()
  }

  func toggleStudyBasedCoachingEnabled() {
    studyBasedCoachingEnabled.toggle()
    scheduleSave()
  }

  func cycleAppearanceMode() {
    let allModes = GainsAppearanceMode.allCases
    guard let currentIndex = allModes.firstIndex(of: appearanceMode) else {
      appearanceMode = .system
      return
    }

    let nextIndex = (currentIndex + 1) % allModes.count
    appearanceMode = allModes[nextIndex]
    scheduleSave()
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
    scheduleSave()
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
    scheduleSave()
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
    scheduleSave()
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
    StoreFormatters.timeHHmmDE.string(from: date)
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
    StoreFormatters.monthDayEN.string(from: date).uppercased()
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
  /// Gecacht — invalidatePlannerCache() nach plannerSettings-Mutationen aufrufen.
  var plannedSessionKinds: [Weekday: PlannedSessionKind] {
    if let cached = _cachedPlannedSessionKinds { return cached }
    let result = _computePlannedSessionKinds()
    _cachedPlannedSessionKinds = result
    return result
  }

  private func _computePlannedSessionKinds() -> [Weekday: PlannedSessionKind] {
    // Manueller Plan überschreibt die Auto-Verteilung der Engine. Wir geben
    // nur Einträge zurück, deren Tag auch tatsächlich als Trainingstag
    // angelegt ist (Day-Pref != .rest), damit Run-Templates konsistent
    // bleiben und kein Geist-Lauf an einem Ruhetag erscheint.
    if plannerSettings.isManualPlan {
      var manual: [Weekday: PlannedSessionKind] = [:]
      for (day, kind) in plannerSettings.manualSessionKinds {
        if dayPreference(for: day) != .rest {
          manual[day] = kind
        }
      }
      return manual
    }

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

  // MARK: - Gym: Set-History (Drilldown im STATS-Tab)

  /// Liefert die chronologisch absteigende Historie einer Übung (neueste zuerst)
  /// über alle abgeschlossenen Workouts hinweg. Zeigt Top-Gewicht, Sätze,
  /// Reps und Volumen pro Session — Datengrundlage für das Drilldown-Sheet.
  func setHistory(forExerciseNamed name: String) -> [ExerciseHistoryEntry] {
    workoutHistory
      .compactMap { workout -> ExerciseHistoryEntry? in
        guard let perf = workout.exercises.first(where: { $0.name == name })
        else { return nil }
        return ExerciseHistoryEntry(
          date: workout.finishedAt,
          workoutTitle: workout.title,
          topWeight: perf.topWeight,
          completedSets: perf.completedSets,
          totalReps: perf.totalReps,
          totalVolume: perf.totalVolume
        )
      }
      .sorted(by: { $0.date > $1.date })
  }

  /// Liste aller Übungsnamen, die jemals absolviert wurden — für die
  /// Sortierung und Anzeige in der Stärke-Übersicht.
  var allTrackedExerciseNames: [String] {
    Array(Set(workoutHistory.flatMap { $0.exercises.map(\.name) })).sorted()
  }

  // MARK: - Gym: 4-Wochen-Plan-Vorschau

  /// Liefert die kommenden 4 Wochen ab Wochenanfang der laufenden Woche.
  /// Pro Tag wird Status (planned/rest/flexible), Titel und Lauf-Template
  /// abgeleitet — für die Vorschau im PLAN-Tab.
  var nextFourWeeksSchedule: [GymPlanPreviewWeek] {
    let calendar = Calendar.current
    let today = normalizedDate(Date())
    let weekday = calendar.component(.weekday, from: today)
    // .firstWeekday ist meist 1 (Sonntag, US) oder 2 (Montag, DE) —
    // wir richten manuell auf Montag aus, weil die App das so anzeigt.
    let daysFromMonday = (weekday + 5) % 7
    guard let mondayThisWeek = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)
    else { return [] }

    let plannedDays = Set(scheduledPlannerDays)
    let runKindByDay = plannedSessionKinds

    // R3: isPlannedSessionCompleted(on:) würde 28× (4×7) über workoutHistory+runHistory
    // iterieren. Einmalig Set<Date> aus normalisierten Tagen vorbauen → O(1) Lookup.
    let completedDaySet: Set<Date> = {
      let cal = Calendar.current
      var days = Set<Date>()
      for w in workoutHistory { days.insert(cal.startOfDay(for: w.finishedAt)) }
      for r in runHistory     { days.insert(cal.startOfDay(for: r.finishedAt)) }
      return days
    }()

    return (0..<4).map { weekIndex -> GymPlanPreviewWeek in
      let label: String
      switch weekIndex {
      case 0: label = "Diese Woche"
      case 1: label = "Nächste Woche"
      default: label = "in \(weekIndex) Wochen"
      }

      let days: [GymPlanPreviewDay] = (0..<7).map { offset in
        let date = calendar.date(byAdding: .day, value: 7 * weekIndex + offset, to: mondayThisWeek)
          ?? today
        // 0 = Montag, ..., 6 = Sonntag → in den App-Weekday-Enum mappen.
        let weekdayEnum: Weekday = {
          switch offset {
          case 0: return .monday
          case 1: return .tuesday
          case 2: return .wednesday
          case 3: return .thursday
          case 4: return .friday
          case 5: return .saturday
          default: return .sunday
          }
        }()

        let pref = dayPreference(for: weekdayEnum)
        let isPlannedTraining = plannedDays.contains(weekdayEnum)
        let runKind = runKindByDay[weekdayEnum]

        let status: WorkoutDayStatus
        let title: String
        var runTemplate: RunTemplate?

        if isPlannedTraining {
          status = .planned
          if let kind = runKind, kind.isRun {
            let template = RunTemplate.template(for: kind)
            runTemplate = template
            title = template?.title ?? kind.title
          } else if let assigned = assignedWorkoutPlan(for: weekdayEnum) {
            title = assigned.title
          } else {
            title = "Training"
          }
        } else if pref == .rest {
          status = .rest
          title = "Frei"
        } else {
          status = .flexible
          title = "Flex"
        }

        // R3: Batch-Lookup über vorbereitetes completedDaySet statt 28× History-Scan.
        let isCompleted = completedDaySet.contains(calendar.startOfDay(for: date))
        let isToday = calendar.isDate(date, inSameDayAs: today)

        return GymPlanPreviewDay(
          date: date,
          weekday: weekdayEnum,
          status: status,
          title: title,
          isToday: isToday,
          isCompleted: isCompleted,
          runTemplate: runTemplate
        )
      }

      return GymPlanPreviewWeek(weekIndex: weekIndex, label: label, days: days)
    }
  }

  // MARK: - Gym: MEV/MAV/MRV-Schwellen

  /// Volumen-Landmarks (Renaissance-Periodization-Modell), abgeleitet aus
  /// dem aktuellen `weeklySetsPerMuscleGroupRange` der Engine.
  var weeklyVolumeLandmarks: VolumeLandmarks {
    VolumeLandmarks.from(range: weeklySetsPerMuscleGroupRange)
  }

}
