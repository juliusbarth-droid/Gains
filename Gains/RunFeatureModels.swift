import CoreLocation
import Foundation

// MARK: - RunFeatureModels
//
// Models für die Strava-Erweiterung des Lauf-Bereichs:
//
//  • SavedRoute              – Routen, die der Nutzer gespeichert hat (z.B. nach
//                              einem aufgezeichneten Lauf oder als Vorschlag)
//  • RouteSurface            – Untergrund-Klassifikation einer Route
//  • RouteHeatmapTile        – Aggregierter Punkt für die Heatmap aller Läufe
//  • RunSegment              – Persönliches Segment auf einer Strecke, gegen
//                              das jeder Lauf automatisch verglichen wird
//  • RunSegmentEffort        – Eine Bestleistung/Effort für ein Segment
//  • StructuredRunWorkout    – Strukturiertes Workout (Intervall/Tempo/Fartlek)
//  • RunWorkoutStep          – Ein Schritt innerhalb eines Workouts
//  • RunWorkoutStepKind      – Art des Schritts (Warm-up, Work, Recovery, …)
//  • RunWorkoutStepTarget    – Ziel des Schritts (Distanz oder Dauer)
//  • ActiveStructuredWorkout – Laufzeit-State während ein Workout gerade läuft
//
// Alle Codable-Conformances stehen in `GainsPersistence.swift` direkt neben
// den anderen Lauf-Codables — so bleibt das Persistenz-Schema an einer Stelle.

// MARK: - Routes

enum RouteSurface: String, Codable, CaseIterable {
  case mixed
  case road
  case trail
  case track
  case treadmill

  var title: String {
    switch self {
    case .mixed:     return "Gemischt"
    case .road:      return "Straße"
    case .trail:     return "Trail"
    case .track:     return "Bahn"
    case .treadmill: return "Laufband"
    }
  }

  var systemImage: String {
    switch self {
    case .mixed:     return "shuffle"
    case .road:      return "road.lanes"
    case .trail:     return "leaf.fill"
    case .track:     return "circle.dashed"
    case .treadmill: return "figure.run.treadmill"
    }
  }
}

struct SavedRoute: Identifiable, Hashable {
  let id: UUID
  var title: String
  var note: String
  var distanceKm: Double
  var elevationGain: Int
  var surface: RouteSurface
  var createdAt: Date
  var coordinates: [CLLocationCoordinate2D]
  /// Wie oft der Nutzer diese Route bereits gelaufen ist (über Run-History
  /// gematcht). Wird im Store on-the-fly berechnet, hier nur als Cache.
  var timesRun: Int

  /// Soft-Match-Toleranz (Distanz in Metern), unter der zwei Routen-Anfangspunkte
  /// als "gleich" gelten. Für `timesRun`-Zählung in der Persistenz.
  static let matchToleranceMeters: Double = 120

  init(
    id: UUID = UUID(),
    title: String,
    note: String = "",
    distanceKm: Double,
    elevationGain: Int = 0,
    surface: RouteSurface = .mixed,
    createdAt: Date = Date(),
    coordinates: [CLLocationCoordinate2D],
    timesRun: Int = 0
  ) {
    self.id = id
    self.title = title
    self.note = note
    self.distanceKm = distanceKm
    self.elevationGain = elevationGain
    self.surface = surface
    self.createdAt = createdAt
    self.coordinates = coordinates
    self.timesRun = timesRun
  }

  static func == (lhs: SavedRoute, rhs: SavedRoute) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Aggregat-Punkt für die Heatmap. Punkte werden auf einer Hashing-basierten
/// Gitterzelle gerundet, damit häufig durchlaufene Bereiche an Intensität
/// gewinnen.
struct RouteHeatmapTile: Identifiable, Hashable {
  let id: UUID
  let coordinate: CLLocationCoordinate2D
  let intensity: Double // 0…1

  init(coordinate: CLLocationCoordinate2D, intensity: Double) {
    self.id = UUID()
    self.coordinate = coordinate
    self.intensity = intensity
  }

  static func == (lhs: RouteHeatmapTile, rhs: RouteHeatmapTile) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Segments

struct RunSegment: Identifiable, Hashable {
  let id: UUID
  var title: String
  var note: String
  /// Polyline-Punkte des Segments (Start … Ziel). Mind. 2.
  var coordinates: [CLLocationCoordinate2D]
  var distanceKm: Double
  var elevationGain: Int
  var createdAt: Date
  /// Wenn true → Segment wurde aus einem fertigen Lauf abgeleitet. Sonst manuell.
  var isAutoCreated: Bool

  init(
    id: UUID = UUID(),
    title: String,
    note: String = "",
    coordinates: [CLLocationCoordinate2D],
    distanceKm: Double,
    elevationGain: Int = 0,
    createdAt: Date = Date(),
    isAutoCreated: Bool = false
  ) {
    self.id = id
    self.title = title
    self.note = note
    self.coordinates = coordinates
    self.distanceKm = distanceKm
    self.elevationGain = elevationGain
    self.createdAt = createdAt
    self.isAutoCreated = isAutoCreated
  }

  static func == (lhs: RunSegment, rhs: RunSegment) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Eine Bestleistung/Effort für ein Segment. Wird automatisch beim Speichern
/// eines Laufs erzeugt, wenn der Lauf das Segment passiert.
struct RunSegmentEffort: Identifiable, Hashable, Codable {
  let id: UUID
  let segmentID: UUID
  let runID: UUID
  let achievedAt: Date
  let durationSeconds: Int
  let averageHeartRate: Int
  let paceSeconds: Int

  init(
    id: UUID = UUID(),
    segmentID: UUID,
    runID: UUID,
    achievedAt: Date,
    durationSeconds: Int,
    averageHeartRate: Int,
    paceSeconds: Int
  ) {
    self.id = id
    self.segmentID = segmentID
    self.runID = runID
    self.achievedAt = achievedAt
    self.durationSeconds = durationSeconds
    self.averageHeartRate = averageHeartRate
    self.paceSeconds = paceSeconds
  }
}

// MARK: - Structured Workouts

enum RunWorkoutStepKind: String, Codable, CaseIterable {
  case warmup
  case work
  case recovery
  case cooldown
  case free

  var title: String {
    switch self {
    case .warmup:   return "Warm-up"
    case .work:     return "Intervall"
    case .recovery: return "Trab-Pause"
    case .cooldown: return "Cool-down"
    case .free:     return "Frei"
    }
  }

  var systemImage: String {
    switch self {
    case .warmup:   return "thermometer.sun"
    case .work:     return "bolt.fill"
    case .recovery: return "leaf"
    case .cooldown: return "snowflake"
    case .free:     return "figure.run"
    }
  }

  /// Empfohlene HF-Zone für die jeweilige Phase.
  var defaultZone: HRZone {
    switch self {
    case .warmup:   return .zone2
    case .work:     return .zone4
    case .recovery: return .zone1
    case .cooldown: return .zone1
    case .free:     return .zone2
    }
  }
}

enum RunWorkoutStepTarget: Hashable, Codable {
  case distance(km: Double)
  case duration(seconds: Int)

  var displayLabel: String {
    switch self {
    case .distance(let km):
      if km >= 1 {
        return String(format: "%.2f km", km).replacingOccurrences(of: ".00", with: "")
      }
      return "\(Int(km * 1000)) m"
    case .duration(let seconds):
      let m = seconds / 60
      let s = seconds % 60
      if m == 0 { return "\(s) s" }
      if s == 0 { return "\(m) min" }
      return String(format: "%d:%02d min", m, s)
    }
  }

  /// Theoretische Soll-Dauer, gegeben eine Pace in Sek/km.
  func estimatedSeconds(paceSecondsPerKm: Int) -> Int {
    switch self {
    case .distance(let km):
      return paceSecondsPerKm > 0 ? Int(Double(paceSecondsPerKm) * km) : 0
    case .duration(let seconds):
      return seconds
    }
  }

  /// Theoretische Soll-Distanz, gegeben eine Pace in Sek/km.
  func estimatedDistanceKm(paceSecondsPerKm: Int) -> Double {
    switch self {
    case .distance(let km): return km
    case .duration(let seconds):
      return paceSecondsPerKm > 0 ? Double(seconds) / Double(paceSecondsPerKm) : 0
    }
  }
}

struct RunWorkoutStep: Identifiable, Hashable, Codable {
  let id: UUID
  var kind: RunWorkoutStepKind
  var target: RunWorkoutStepTarget
  /// Empfohlene Pace in Sekunden/km (0 = keine Vorgabe).
  var targetPaceSeconds: Int
  /// Wie oft dieser Schritt wiederholt wird (z.B. 8× 400 m → repeats=8 nur auf
  /// dem Work-Step; Recovery-Step direkt danach hat dann meist auch repeats=1
  /// und wird durch die Gruppen-Struktur darüber wiederholt).
  var repeats: Int

  init(
    id: UUID = UUID(),
    kind: RunWorkoutStepKind,
    target: RunWorkoutStepTarget,
    targetPaceSeconds: Int = 0,
    repeats: Int = 1
  ) {
    self.id = id
    self.kind = kind
    self.target = target
    self.targetPaceSeconds = targetPaceSeconds
    self.repeats = repeats
  }
}

struct StructuredRunWorkout: Identifiable, Hashable, Codable {
  let id: UUID
  var title: String
  var summary: String
  var systemImage: String
  /// Die Schritte als Sequenz. Wiederholungen einer Gruppe (z.B. 8× 400/200)
  /// werden über `RunWorkoutStep.repeats` ausgedrückt: ein Work-Step und ein
  /// Recovery-Step direkt darunter, beide mit `repeats = 8`, werden vom
  /// Runner abwechselnd 8-fach abgefahren.
  var steps: [RunWorkoutStep]
  /// Builtin-Workouts dürfen nicht gelöscht werden.
  var isBuiltin: Bool

  init(
    id: UUID = UUID(),
    title: String,
    summary: String,
    systemImage: String = "bolt.heart",
    steps: [RunWorkoutStep],
    isBuiltin: Bool = false
  ) {
    self.id = id
    self.title = title
    self.summary = summary
    self.systemImage = systemImage
    self.steps = steps
    self.isBuiltin = isBuiltin
  }

  /// Aufgelöste Schrittliste (mit Wiederholungen flachgeklopft) — der Runner
  /// arbeitet diese Liste linear ab.
  var expandedSteps: [RunWorkoutStep] {
    var result: [RunWorkoutStep] = []
    var index = 0
    while index < steps.count {
      let step = steps[index]
      let repeats = max(step.repeats, 1)
      if repeats == 1 {
        result.append(step)
        index += 1
        continue
      }
      // Gruppe: wenn der nächste Schritt dieselbe `repeats`-Anzahl hat,
      // werden Step+Next zusammen wiederholt (typisches Intervall+Recovery-Pattern).
      let isPaired = (index + 1 < steps.count) && steps[index + 1].repeats == repeats
      if isPaired {
        let next = steps[index + 1]
        for _ in 0..<repeats {
          var work = step
          work.repeats = 1
          var rec = next
          rec.repeats = 1
          result.append(work)
          result.append(rec)
        }
        index += 2
      } else {
        for _ in 0..<repeats {
          var copy = step
          copy.repeats = 1
          result.append(copy)
        }
        index += 1
      }
    }
    return result
  }

  /// Gesamt-Schätzung für die Dauer (Min) und Distanz (km) — beruht auf den
  /// Pace-Vorgaben der Schritte. Frei-Schritte ohne Pace zählen nicht in die
  /// Distanz mit ein.
  var estimatedDurationMinutes: Int {
    let secs = expandedSteps.reduce(0) { acc, step in
      acc + step.target.estimatedSeconds(paceSecondsPerKm: step.targetPaceSeconds)
    }
    return max(secs / 60, 0)
  }

  var estimatedDistanceKm: Double {
    expandedSteps.reduce(0) { acc, step in
      acc + step.target.estimatedDistanceKm(paceSecondsPerKm: step.targetPaceSeconds)
    }
  }
}

// MARK: - Active Structured Workout (Runtime)

/// Live-State, während ein strukturiertes Workout läuft. Wird vom
/// `RunTrackerView` gehalten und bei jedem Tick gegen den Tracker aktualisiert.
struct ActiveStructuredWorkout: Identifiable {
  let id: UUID
  let workoutID: UUID
  let workoutTitle: String
  let steps: [RunWorkoutStep]
  /// Index des aktuell aktiven Schrittes in `steps`.
  var currentStepIndex: Int
  /// Distanz in km, die der Lauf hatte, als der aktuelle Schritt gestartet wurde.
  var stepStartDistanceKm: Double
  /// Sekunden seit Lauf-Start, als der aktuelle Schritt gestartet wurde.
  var stepStartElapsedSeconds: Int

  init(
    workout: StructuredRunWorkout,
    startDistanceKm: Double = 0,
    startElapsedSeconds: Int = 0
  ) {
    self.id = UUID()
    self.workoutID = workout.id
    self.workoutTitle = workout.title
    self.steps = workout.expandedSteps
    self.currentStepIndex = 0
    self.stepStartDistanceKm = startDistanceKm
    self.stepStartElapsedSeconds = startElapsedSeconds
  }

  var currentStep: RunWorkoutStep? {
    guard steps.indices.contains(currentStepIndex) else { return nil }
    return steps[currentStepIndex]
  }

  var nextStep: RunWorkoutStep? {
    let next = currentStepIndex + 1
    guard steps.indices.contains(next) else { return nil }
    return steps[next]
  }

  var isFinished: Bool { currentStepIndex >= steps.count }

  /// Fortschritt 0…1 für den aktuellen Schritt — basierend auf Distanz oder Zeit.
  func currentStepProgress(distanceKm: Double, elapsedSeconds: Int) -> Double {
    guard let step = currentStep else { return 1 }
    switch step.target {
    case .distance(let km):
      guard km > 0 else { return 0 }
      let delta = max(distanceKm - stepStartDistanceKm, 0)
      return min(delta / km, 1)
    case .duration(let seconds):
      guard seconds > 0 else { return 0 }
      let delta = max(elapsedSeconds - stepStartElapsedSeconds, 0)
      return min(Double(delta) / Double(seconds), 1)
    }
  }

  /// Liefert die verbleibende Distanz/Zeit-Beschriftung des aktuellen Schrittes.
  func remainingLabel(distanceKm: Double, elapsedSeconds: Int) -> String {
    guard let step = currentStep else { return "Fertig" }
    switch step.target {
    case .distance(let km):
      let remaining = max(km - (distanceKm - stepStartDistanceKm), 0)
      if remaining < 0.05 { return "Fertig" }
      if remaining < 1 { return "\(Int((remaining * 1000).rounded())) m" }
      return String(format: "%.2f km", remaining)
    case .duration(let seconds):
      let remaining = max(seconds - (elapsedSeconds - stepStartElapsedSeconds), 0)
      let m = remaining / 60
      let s = remaining % 60
      return String(format: "%d:%02d", m, s)
    }
  }
}

// MARK: - Builtin Workout Library

extension StructuredRunWorkout {
  /// Vorgefertigte Strava-Style-Workouts. Werden beim ersten App-Start in den
  /// Store geseedet und können vom Nutzer kopiert / erweitert werden.
  static let builtinLibrary: [StructuredRunWorkout] = [
    // 5 × 1000 m @ 10K-Pace
    StructuredRunWorkout(
      id: UUID(uuidString: "A1A1A1A1-0000-0000-0000-000000000001")!,
      title: "5 × 1000 m",
      summary: "Klassisches VO₂max-Intervall: 5 × 1 km schnell, 400 m Trab.",
      systemImage: "bolt.circle.fill",
      steps: [
        RunWorkoutStep(kind: .warmup,   target: .distance(km: 1.5), targetPaceSeconds: 6 * 60 + 0),
        RunWorkoutStep(kind: .work,     target: .distance(km: 1.0), targetPaceSeconds: 4 * 60 + 30, repeats: 5),
        RunWorkoutStep(kind: .recovery, target: .distance(km: 0.4), targetPaceSeconds: 7 * 60 + 0,  repeats: 5),
        RunWorkoutStep(kind: .cooldown, target: .distance(km: 1.0), targetPaceSeconds: 6 * 60 + 30),
      ],
      isBuiltin: true
    ),
    // Tempolauf
    StructuredRunWorkout(
      id: UUID(uuidString: "A1A1A1A1-0000-0000-0000-000000000002")!,
      title: "Tempolauf 6 km",
      summary: "Stetes, schwellennahes Tempo — das Pferd der Marathon-Vorbereitung.",
      systemImage: "bolt.heart.fill",
      steps: [
        RunWorkoutStep(kind: .warmup,   target: .distance(km: 1.5), targetPaceSeconds: 6 * 60 + 10),
        RunWorkoutStep(kind: .work,     target: .distance(km: 6.0), targetPaceSeconds: 4 * 60 + 50),
        RunWorkoutStep(kind: .cooldown, target: .distance(km: 1.0), targetPaceSeconds: 6 * 60 + 30),
      ],
      isBuiltin: true
    ),
    // 400er-Pyramide
    StructuredRunWorkout(
      id: UUID(uuidString: "A1A1A1A1-0000-0000-0000-000000000003")!,
      title: "Pyramide 400/800/1200",
      summary: "Klassische Pyramide für Tempohärte: 400 / 800 / 1200 / 800 / 400.",
      systemImage: "triangle.fill",
      steps: [
        RunWorkoutStep(kind: .warmup,   target: .distance(km: 1.5), targetPaceSeconds: 6 * 60 + 10),
        RunWorkoutStep(kind: .work,     target: .distance(km: 0.4), targetPaceSeconds: 4 * 60 + 0),
        RunWorkoutStep(kind: .recovery, target: .duration(seconds: 90), targetPaceSeconds: 0),
        RunWorkoutStep(kind: .work,     target: .distance(km: 0.8), targetPaceSeconds: 4 * 60 + 15),
        RunWorkoutStep(kind: .recovery, target: .duration(seconds: 120), targetPaceSeconds: 0),
        RunWorkoutStep(kind: .work,     target: .distance(km: 1.2), targetPaceSeconds: 4 * 60 + 25),
        RunWorkoutStep(kind: .recovery, target: .duration(seconds: 180), targetPaceSeconds: 0),
        RunWorkoutStep(kind: .work,     target: .distance(km: 0.8), targetPaceSeconds: 4 * 60 + 15),
        RunWorkoutStep(kind: .recovery, target: .duration(seconds: 120), targetPaceSeconds: 0),
        RunWorkoutStep(kind: .work,     target: .distance(km: 0.4), targetPaceSeconds: 4 * 60 + 0),
        RunWorkoutStep(kind: .cooldown, target: .distance(km: 1.0), targetPaceSeconds: 6 * 60 + 30),
      ],
      isBuiltin: true
    ),
    // Fartlek
    StructuredRunWorkout(
      id: UUID(uuidString: "A1A1A1A1-0000-0000-0000-000000000004")!,
      title: "Fartlek 8 × 1 min",
      summary: "Spielerischer Wechsel — 8 × 1 min schnell, 1 min Trab.",
      systemImage: "wind",
      steps: [
        RunWorkoutStep(kind: .warmup,   target: .duration(seconds: 10 * 60), targetPaceSeconds: 6 * 60 + 0),
        RunWorkoutStep(kind: .work,     target: .duration(seconds: 60),      targetPaceSeconds: 4 * 60 + 20, repeats: 8),
        RunWorkoutStep(kind: .recovery, target: .duration(seconds: 60),      targetPaceSeconds: 6 * 60 + 30, repeats: 8),
        RunWorkoutStep(kind: .cooldown, target: .duration(seconds: 8 * 60),  targetPaceSeconds: 6 * 60 + 30),
      ],
      isBuiltin: true
    ),
    // Long Run
    StructuredRunWorkout(
      id: UUID(uuidString: "A1A1A1A1-0000-0000-0000-000000000005")!,
      title: "Long Run 18 km",
      summary: "Lockerer, langer Lauf für Grundlagenausdauer.",
      systemImage: "map.fill",
      steps: [
        RunWorkoutStep(kind: .warmup,  target: .distance(km: 2.0),  targetPaceSeconds: 6 * 60 + 30),
        RunWorkoutStep(kind: .free,    target: .distance(km: 14.0), targetPaceSeconds: 5 * 60 + 50),
        RunWorkoutStep(kind: .cooldown,target: .distance(km: 2.0),  targetPaceSeconds: 6 * 60 + 30),
      ],
      isBuiltin: true
    ),
    // Easy Recovery
    StructuredRunWorkout(
      id: UUID(uuidString: "A1A1A1A1-0000-0000-0000-000000000006")!,
      title: "Recovery 30 min",
      summary: "Lockerer Regenerationslauf in Zone 1–2.",
      systemImage: "heart.circle.fill",
      steps: [
        RunWorkoutStep(kind: .free, target: .duration(seconds: 30 * 60), targetPaceSeconds: 6 * 60 + 50),
      ],
      isBuiltin: true
    ),
  ]
}

// MARK: - Geo-Helfer (intern)
//
// Werden vom Store für Heatmap-Aggregation und Segment-Matching genutzt.
// Bewusst nicht öffentlich — sind ein Implementations-Detail.

enum RunGeoMath {
  /// Haversine-Distanz in Metern. Robust genug für die kleinen Distanzen
  /// (wenige hundert Meter bis ~50 km).
  static func distanceMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
    let earthRadius = 6_371_000.0
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let dLat = (b.latitude - a.latitude) * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180

    let h = sin(dLat / 2) * sin(dLat / 2)
      + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    let c = 2 * atan2(sqrt(h), sqrt(1 - h))
    return earthRadius * c
  }

  /// Rundet eine Koordinate auf ein Heatmap-Gitter mit ca. 30 m Kantenlänge.
  /// Hash-Schlüssel = "lat-bucket|lon-bucket".
  static func heatmapKey(for coord: CLLocationCoordinate2D, gridMeters: Double = 30) -> String {
    // 1° Latitude ≈ 111 km. 30 m → ~0.00027°.
    let latStep = gridMeters / 111_000
    let lonStep = gridMeters / (111_000 * max(cos(coord.latitude * .pi / 180), 0.01))
    let latBucket = Int((coord.latitude / latStep).rounded())
    let lonBucket = Int((coord.longitude / lonStep).rounded())
    return "\(latBucket)|\(lonBucket)"
  }

  /// Mittelpunkt einer Bucket-ID — invers zu `heatmapKey(for:)`.
  static func coordinate(forKey key: String, gridMeters: Double = 30) -> CLLocationCoordinate2D? {
    let parts = key.split(separator: "|")
    guard parts.count == 2,
          let latBucket = Double(parts[0]),
          let lonBucket = Double(parts[1])
    else { return nil }
    let latStep = gridMeters / 111_000
    // Ohne tatsächliche Ausgangs-Latitude können wir den lonStep nur grob nachbilden.
    let lat = latBucket * latStep
    let lonStep = gridMeters / (111_000 * max(cos(lat * .pi / 180), 0.01))
    return CLLocationCoordinate2D(latitude: lat, longitude: lonBucket * lonStep)
  }

  /// Kürzester Abstand (Meter) eines Punkts zu einem Polylinien-Segment.
  /// Verwendet eine einfache Projektion, die für unsere Größenordnungen
  /// (≤ ein paar hundert Meter) ausreichend genau ist.
  static func pointToSegmentMeters(
    point: CLLocationCoordinate2D,
    segmentStart: CLLocationCoordinate2D,
    segmentEnd: CLLocationCoordinate2D
  ) -> Double {
    let toMeters: (CLLocationCoordinate2D, CLLocationCoordinate2D) -> (Double, Double) = { a, b in
      let dx = (b.longitude - a.longitude) * 111_000 * cos(a.latitude * .pi / 180)
      let dy = (b.latitude  - a.latitude)  * 111_000
      return (dx, dy)
    }
    let (sx, sy) = toMeters(segmentStart, point)
    let (ex, ey) = toMeters(segmentStart, segmentEnd)
    let lenSq = ex * ex + ey * ey
    if lenSq < 1e-6 {
      return distanceMeters(point, segmentStart)
    }
    let t = max(0, min(1, (sx * ex + sy * ey) / lenSq))
    let projX = ex * t
    let projY = ey * t
    let dx = sx - projX
    let dy = sy - projY
    return sqrt(dx * dx + dy * dy)
  }

  /// Liefert die kumulative Distanz eines Polylinien-Segments in Metern.
  static func polylineLengthMeters(_ coords: [CLLocationCoordinate2D]) -> Double {
    guard coords.count > 1 else { return 0 }
    var total: Double = 0
    for i in 1..<coords.count {
      total += distanceMeters(coords[i - 1], coords[i])
    }
    return total
  }
}
