import Foundation

// MARK: - ActiveWorkoutPersister
//
// 2026-05-14 (Audit-Loop 1): Persistenz-Layer für den laufenden Workout.
//
// Hintergrund:
//   `GainsStore.activeWorkout` lebt bisher nur im RAM. Wenn der User die App
//   während einer Session schließt oder die App in den Hintergrund geht und
//   später vom OS terminiert wird, verliert er seine Sätze. Für ein
//   Fitness-Tool ist das inakzeptabel — gerade beim letzten Satz hängt der
//   User oft >2 Min im Background (Apple Music, Timer-Notification etc.).
//
// Lösung:
//   1. Diese Klasse hält ein einfaches DTO (Codable-Mirror der WorkoutSession-
//      Hierarchie) und serialisiert sie in UserDefaults.
//   2. `GainsStore` (Audit-Loop 2) hookt sich in `didSet` von `activeWorkout`
//      ein und ruft `save(_:)` debounced auf.
//   3. Beim Cold-Start lädt `GainsStore.init()` aus dem Persister einen
//      etwaigen pending-Workout und exposed ihn als `recoverableWorkout` —
//      die Home-View zeigt einen „Fortsetzen / Verwerfen"-Banner (Loop 3).
//
// Trade-offs:
//   - Wir benutzen UserDefaults statt FileSystem/CoreData. Größe ist klein
//     (<5KB), Frequenz mittel (~10 Writes/Min während einer Session). Das ist
//     vertretbar; OS optimiert UserDefaults intern.
//   - Wir speichern auch die Pause-Timer-Daten (`restTimerEndsAt`,
//     `restDuration`). Sobald die Pause abgelaufen ist, ist der Endzeitpunkt
//     in der Vergangenheit — `WorkoutTrackerView.task(id:)` cleart ihn beim
//     Wiederöffnen geräuschlos.

struct PersistedTrackedSet: Codable {
  let id: UUID
  let order: Int
  let reps: Int
  let weight: Double
  let isCompleted: Bool

  init(_ source: TrackedSet) {
    self.id = source.id
    self.order = source.order
    self.reps = source.reps
    self.weight = source.weight
    self.isCompleted = source.isCompleted
  }
}

struct PersistedTrackedExercise: Codable {
  let id: UUID
  let name: String
  let targetMuscle: String
  let sets: [PersistedTrackedSet]

  init(_ source: TrackedExercise) {
    self.id = source.id
    self.name = source.name
    self.targetMuscle = source.targetMuscle
    self.sets = source.sets.map(PersistedTrackedSet.init)
  }
}

struct PersistedWorkoutSession: Codable {
  let id: UUID
  let title: String
  let focus: String
  let startedAt: Date
  let exercises: [PersistedTrackedExercise]
  // Pause-Timer-Kontext, damit ein laufender Satzwechsel beim Restore
  // konsistent fortgesetzt wird.
  let restTimerEndsAt: Date?
  let restDuration: Int
  // ISO-Timestamp des letzten Writes — wird im Recovery-Banner als
  // „letzter Stand vor X Min" angezeigt.
  let savedAt: Date

  init(
    workout: WorkoutSession,
    restTimerEndsAt: Date?,
    restDuration: Int
  ) {
    self.id = workout.id
    self.title = workout.title
    self.focus = workout.focus
    self.startedAt = workout.startedAt
    self.exercises = workout.exercises.map(PersistedTrackedExercise.init)
    self.restTimerEndsAt = restTimerEndsAt
    self.restDuration = restDuration
    self.savedAt = Date()
  }
}

/// Singleton, der die Persistenz transparent kapselt. Wird von
/// `GainsStore.init()` zum Laden und von `activeWorkout`-Mutations zum
/// Speichern angesprochen.
final class ActiveWorkoutPersister {
  static let shared = ActiveWorkoutPersister()

  private let key = "gains.activeWorkout.v1"
  private let defaults: UserDefaults
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  // Debounce-Task — verhindert, dass jeder einzelne ±1-Tap auf
  // Reps/Weight einen Write triggert. State wird nach 350 ms geflusht.
  private var pendingSaveTask: Task<Void, Never>?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
    self.decoder = JSONDecoder()
    self.decoder.dateDecodingStrategy = .iso8601
  }

  deinit {
    // Verhindert, dass ein gependeter Save-Task nach dem Deallocate noch
    // versucht auf `self` zuzugreifen (auch mit [weak self] eine sauberere
    // Ressourcen-Freigabe).
    pendingSaveTask?.cancel()
  }

  /// Debounced Save — wird vom Store bei jeder `activeWorkout`-Mutation
  /// aufgerufen. Mehrere schnelle Aufrufe innerhalb von 350 ms werden zu
  /// genau einem Write zusammengefasst.
  func scheduleSave(_ snapshot: PersistedWorkoutSession) {
    pendingSaveTask?.cancel()
    pendingSaveTask = Task { [weak self] in
      try? await Task.sleep(nanoseconds: 350_000_000)
      guard !Task.isCancelled, let self else { return }
      self.flush(snapshot)
    }
  }

  /// Sofortiger Save (z.B. beim Backgrounding via SceneDelegate).
  func flush(_ snapshot: PersistedWorkoutSession) {
    guard let data = try? encoder.encode(snapshot) else { return }
    defaults.set(data, forKey: key)
  }

  /// Lädt einen evtl. gespeicherten Workout. `nil`, wenn keiner da ist.
  func load() -> PersistedWorkoutSession? {
    guard let data = defaults.data(forKey: key) else { return nil }
    return try? decoder.decode(PersistedWorkoutSession.self, from: data)
  }

  /// Wird aufgerufen, wenn der User „Verwerfen" tippt ODER der Workout
  /// regulär abgeschlossen wird.
  func clear() {
    pendingSaveTask?.cancel()
    defaults.removeObject(forKey: key)
  }
}

// MARK: - Restore-Mapping

extension PersistedWorkoutSession {
  /// Rekonstruiert eine `WorkoutSession` aus dem Snapshot. Wichtig:
  /// `WorkoutSession.id` ist mit `let id = UUID()` definiert, lässt sich also
  /// nicht direkt überschreiben — der wiederhergestellte Workout bekommt
  /// also eine neue ID. Das ist für die Tracker-Mechanik unkritisch, weil
  /// die ID nur lokal als View-Identity benutzt wird.
  func toSession() -> WorkoutSession {
    var session = WorkoutSession(title: title, focus: focus, startedAt: startedAt, exercises: [])
    session.exercises = exercises.map { ex in
      // Auch hier: neue UUIDs für ex/sets, da `let id = UUID()`.
      // Für die Recovery ist Identitäts-Stabilität nicht nötig — die
      // Sätze sind dieselben, der User trackt weiter.
      let restoredSets = ex.sets.map { set in
        TrackedSet(
          order: set.order,
          reps: set.reps,
          weight: set.weight,
          isCompleted: set.isCompleted
        )
      }
      return TrackedExercise(
        name: ex.name,
        targetMuscle: ex.targetMuscle,
        sets: restoredSets
      )
    }
    return session
  }
}
