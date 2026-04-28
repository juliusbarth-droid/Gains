import CoreLocation
import Foundation

// MARK: - GainsStore+RunFeatures
//
// Strava-Erweiterung des Lauf-Bereichs:
//
//   • Routes-CRUD + Heatmap-Aggregation
//   • Segments-CRUD, Segment-Matching gegen fertige Läufe, Effort-Statistik
//   • Strukturierte Workouts (Custom-CRUD + Builtin-Bibliothek)
//   • Active Structured Workout: Start, Step-Advance, Stop
//
// Liegt bewusst in einer eigenen Datei, damit die zentrale `GainsStore.swift`
// nicht weiter wächst und wir das Feature isoliert testen können.

extension GainsStore {

  // MARK: - Routes

  /// Speichert eine Route — entweder direkt mit Koordinaten/Distanz, oder aus
  /// einem fertigen Lauf (siehe `saveRoute(from:title:)`).
  @discardableResult
  func saveRoute(
    title: String,
    note: String = "",
    coordinates: [CLLocationCoordinate2D],
    distanceKm: Double,
    elevationGain: Int = 0,
    surface: RouteSurface = .mixed
  ) -> SavedRoute? {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !coordinates.isEmpty, distanceKm > 0 else { return nil }

    let route = SavedRoute(
      title: trimmed,
      note: note.trimmingCharacters(in: .whitespacesAndNewlines),
      distanceKm: distanceKm,
      elevationGain: elevationGain,
      surface: surface,
      createdAt: Date(),
      coordinates: coordinates,
      timesRun: 1
    )
    savedRoutes.insert(route, at: 0)
    saveAll()
    return route
  }

  /// Convenience: speichert die Route, die zu einem gerade fertigen Lauf
  /// gehört. Hat der Lauf < 0,5 km oder keine Koordinaten, gibt nil zurück.
  @discardableResult
  func saveRoute(from run: CompletedRunSummary, title: String? = nil) -> SavedRoute? {
    guard run.routeCoordinates.count > 2, run.distanceKm >= 0.5 else { return nil }
    let chosenTitle = (title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
      ?? run.routeName.nilIfEmpty
      ?? run.title
    return saveRoute(
      title: chosenTitle,
      note: "Aus „\(run.title)“ am \(run.finishedAt.formatted(date: .abbreviated, time: .omitted))",
      coordinates: run.routeCoordinates,
      distanceKm: run.distanceKm,
      elevationGain: run.elevationGain,
      surface: .mixed
    )
  }

  func renameRoute(_ id: UUID, to title: String) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let index = savedRoutes.firstIndex(where: { $0.id == id }) else { return }
    savedRoutes[index].title = trimmed
    saveAll()
  }

  func deleteRoute(_ id: UUID) {
    savedRoutes.removeAll(where: { $0.id == id })
    saveAll()
  }

  /// Wie oft wurde eine Route gelaufen? Wird über simple Heuristik berechnet:
  /// Start- und Endpunkt müssen innerhalb der Toleranz liegen UND die Distanz
  /// muss in einem ±10%-Fenster der Route liegen.
  func timesRouteRun(_ route: SavedRoute) -> Int {
    guard let start = route.coordinates.first,
          let end = route.coordinates.last else { return 0 }
    let lower = route.distanceKm * 0.85
    let upper = route.distanceKm * 1.15
    return runHistory.reduce(0) { acc, run in
      guard run.distanceKm >= lower, run.distanceKm <= upper,
            let runStart = run.routeCoordinates.first,
            let runEnd = run.routeCoordinates.last else { return acc }
      let dStart = RunGeoMath.distanceMeters(runStart, start)
      let dEnd   = RunGeoMath.distanceMeters(runEnd, end)
      let inTolerance = dStart <= SavedRoute.matchToleranceMeters
                     && dEnd   <= SavedRoute.matchToleranceMeters
      return acc + (inTolerance ? 1 : 0)
    }
  }

  /// Aktualisiert das `timesRun`-Feld aller Routen anhand der aktuellen
  /// Lauf-Historie. Wird nach `finishRun(...)` aufgerufen.
  func recountRouteUsage() {
    var changed = false
    for index in savedRoutes.indices {
      let count = timesRouteRun(savedRoutes[index])
      if savedRoutes[index].timesRun != count {
        savedRoutes[index].timesRun = count
        changed = true
      }
    }
    if changed { saveAll() }
  }

  // MARK: - Heatmap

  /// Heatmap-Punkte aus allen aufgezeichneten Läufen + gespeicherten Routen.
  /// Wir zählen Häufigkeit pro Gitterzelle und mappen auf eine Intensität 0…1.
  var routeHeatmapTiles: [RouteHeatmapTile] {
    var counts: [String: (CLLocationCoordinate2D, Int)] = [:]
    let pointStreams: [[CLLocationCoordinate2D]] =
      runHistory.map(\.routeCoordinates) + savedRoutes.map(\.coordinates)
    for stream in pointStreams {
      // Sample alle ~30 m, sonst werden Cluster zu dicht.
      var lastAdded: CLLocationCoordinate2D? = nil
      for coord in stream {
        if let prev = lastAdded, RunGeoMath.distanceMeters(prev, coord) < 25 { continue }
        let key = RunGeoMath.heatmapKey(for: coord)
        if let existing = counts[key] {
          counts[key] = (existing.0, existing.1 + 1)
        } else {
          counts[key] = (coord, 1)
        }
        lastAdded = coord
      }
    }
    let maxCount = counts.values.map(\.1).max() ?? 1
    return counts.map { _, value in
      let intensity = min(Double(value.1) / Double(maxCount), 1)
      return RouteHeatmapTile(coordinate: value.0, intensity: intensity)
    }
  }

  // MARK: - Segments

  @discardableResult
  func saveSegment(
    title: String,
    note: String = "",
    coordinates: [CLLocationCoordinate2D],
    distanceKm: Double,
    elevationGain: Int = 0,
    isAutoCreated: Bool = false
  ) -> RunSegment? {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, coordinates.count >= 2, distanceKm > 0 else { return nil }
    let segment = RunSegment(
      title: trimmed,
      note: note,
      coordinates: coordinates,
      distanceKm: distanceKm,
      elevationGain: elevationGain,
      isAutoCreated: isAutoCreated
    )
    runSegments.insert(segment, at: 0)
    runSegmentEfforts[segment.id] = []
    // Direkt nach Anlage gegen die History matchen — älteren Effort gleich erfassen.
    matchSegmentAgainstHistory(segment)
    saveAll()
    return segment
  }

  func renameSegment(_ id: UUID, to title: String) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let index = runSegments.firstIndex(where: { $0.id == id }) else { return }
    runSegments[index].title = trimmed
    saveAll()
  }

  func deleteSegment(_ id: UUID) {
    runSegments.removeAll(where: { $0.id == id })
    runSegmentEfforts[id] = nil
    saveAll()
  }

  /// Sortierte Effort-Liste (schnellster zuerst) für ein Segment.
  func efforts(for segmentID: UUID) -> [RunSegmentEffort] {
    let raw = runSegmentEfforts[segmentID] ?? []
    return raw.sorted { $0.durationSeconds < $1.durationSeconds }
  }

  /// Bester Effort für ein Segment (kann nil sein).
  func bestEffort(for segmentID: UUID) -> RunSegmentEffort? {
    efforts(for: segmentID).first
  }

  /// Versucht, einen abgelaufenen Lauf gegen alle bestehenden Segmente zu
  /// matchen. Findet einen Match, wenn die Lauf-Polylinie das Segment
  /// (innerhalb von ~25 m Toleranz) komplett enthält.
  func matchSegments(against run: CompletedRunSummary) {
    guard !runSegments.isEmpty, run.routeCoordinates.count > 2 else { return }
    var changed = false
    for segment in runSegments {
      if let effort = effort(in: run, on: segment) {
        var current = runSegmentEfforts[segment.id] ?? []
        // Doppelte Efforts (gleicher RunID) vermeiden.
        if !current.contains(where: { $0.runID == effort.runID }) {
          current.insert(effort, at: 0)
          runSegmentEfforts[segment.id] = current
          changed = true
        }
      }
    }
    if changed { saveAll() }
  }

  /// Wie `matchSegments(against:)`, aber für ein einzelnes Segment gegen die
  /// gesamte Run-History. Beim Anlegen eines neuen Segments aufgerufen.
  private func matchSegmentAgainstHistory(_ segment: RunSegment) {
    var efforts: [RunSegmentEffort] = []
    for run in runHistory {
      if let effort = effort(in: run, on: segment) {
        efforts.append(effort)
      }
    }
    if !efforts.isEmpty {
      let existing = runSegmentEfforts[segment.id] ?? []
      let merged = (existing + efforts.filter { e in !existing.contains(where: { $0.runID == e.runID }) })
      runSegmentEfforts[segment.id] = merged
    }
  }

  /// Liefert einen Effort, falls der Lauf das Segment vollständig enthält.
  /// Heuristik:
  ///   1. Finde den Punkt im Lauf, der dem Segment-Start am nächsten liegt
  ///      (Distanz < 25 m).
  ///   2. Ab diesem Punkt: scanne weiter, bis der Punkt-zu-Polyline-Abstand
  ///      des Segments durchgehend < 30 m bleibt UND das Segment-Ende
  ///      erreicht ist (< 25 m vom letzten Segment-Punkt).
  ///   3. Aus Start-/End-Index die anteilige Dauer + HF ableiten.
  private func effort(in run: CompletedRunSummary, on segment: RunSegment) -> RunSegmentEffort? {
    let runCoords = run.routeCoordinates
    guard runCoords.count > 2,
          segment.coordinates.count >= 2,
          let segStart = segment.coordinates.first,
          let segEnd = segment.coordinates.last else { return nil }

    let approachTolerance: Double = 30   // m
    let strayTolerance: Double = 60      // m — wir sind großzügig, GPS rauscht

    // 1. Startpunkt im Lauf finden.
    guard let startIdx = runCoords.indices.min(by: { i, j in
      RunGeoMath.distanceMeters(runCoords[i], segStart) < RunGeoMath.distanceMeters(runCoords[j], segStart)
    }), RunGeoMath.distanceMeters(runCoords[startIdx], segStart) <= approachTolerance else {
      return nil
    }

    // 2. Vom Start aus folgen, bis Segment-Ende erreicht.
    var endIdx: Int = startIdx
    for i in (startIdx + 1)..<runCoords.count {
      // Stray-Check: Punkt darf nicht zu weit von Segment-Linie weglaufen.
      let strayDistance = minimumDistance(from: runCoords[i], toPolyline: segment.coordinates)
      if strayDistance > strayTolerance {
        break
      }
      endIdx = i
      if RunGeoMath.distanceMeters(runCoords[i], segEnd) <= approachTolerance {
        break
      }
    }

    // Hat der Lauf das Segment-Ende tatsächlich erreicht?
    guard RunGeoMath.distanceMeters(runCoords[endIdx], segEnd) <= approachTolerance else {
      return nil
    }

    // 3. Anteilige Dauer/HF errechnen.
    let totalCoords = runCoords.count
    guard totalCoords > 1, run.durationMinutes > 0 else { return nil }

    let totalSeconds = run.durationMinutes * 60
    let secondsPerCoord = Double(totalSeconds) / Double(totalCoords)
    let durationSeconds = Int(Double(endIdx - startIdx) * secondsPerCoord)
    guard durationSeconds > 0 else { return nil }

    // HF: durchschnitt der Splits — oder Fallback auf Run-Average.
    let hr = run.averageHeartRate

    let paceSeconds: Int = {
      guard segment.distanceKm > 0 else { return 0 }
      return Int(Double(durationSeconds) / segment.distanceKm)
    }()

    return RunSegmentEffort(
      segmentID: segment.id,
      runID: run.id,
      achievedAt: run.finishedAt,
      durationSeconds: durationSeconds,
      averageHeartRate: hr,
      paceSeconds: paceSeconds
    )
  }

  /// Minimaler Punkt-zu-Polyline-Abstand. Für Stray-Detection beim Match.
  private func minimumDistance(
    from point: CLLocationCoordinate2D,
    toPolyline polyline: [CLLocationCoordinate2D]
  ) -> Double {
    guard polyline.count > 1 else {
      if let only = polyline.first {
        return RunGeoMath.distanceMeters(point, only)
      }
      return .infinity
    }
    var best: Double = .infinity
    for i in 1..<polyline.count {
      let d = RunGeoMath.pointToSegmentMeters(
        point: point, segmentStart: polyline[i - 1], segmentEnd: polyline[i]
      )
      if d < best { best = d }
    }
    return best
  }

  /// Convenience: erzeugt aus einem Lauf-Stück (Distanz a..b) automatisch ein
  /// Segment. Wird vom Lauf-Detail-Sheet aufgerufen.
  @discardableResult
  func createSegment(
    fromRun run: CompletedRunSummary,
    title: String,
    fromKilometer startKm: Double,
    toKilometer endKm: Double
  ) -> RunSegment? {
    guard startKm < endKm, run.routeCoordinates.count > 2 else { return nil }

    let coords = run.routeCoordinates
    var cumulative: [Double] = [0]
    for i in 1..<coords.count {
      cumulative.append(cumulative[i - 1] + RunGeoMath.distanceMeters(coords[i - 1], coords[i]) / 1000)
    }
    guard let startIndex = cumulative.firstIndex(where: { $0 >= startKm }),
          let endIndex   = cumulative.firstIndex(where: { $0 >= endKm }),
          startIndex < endIndex else { return nil }

    let slice = Array(coords[startIndex...endIndex])
    let segmentDistance = cumulative[endIndex] - cumulative[startIndex]
    return saveSegment(
      title: title,
      note: "Aus „\(run.title)“",
      coordinates: slice,
      distanceKm: segmentDistance,
      elevationGain: 0,
      isAutoCreated: true
    )
  }

  // MARK: - Structured Workouts (CRUD)

  @discardableResult
  func saveStructuredWorkout(
    title: String,
    summary: String = "",
    systemImage: String = "bolt.heart",
    steps: [RunWorkoutStep]
  ) -> StructuredRunWorkout? {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !steps.isEmpty else { return nil }
    let workout = StructuredRunWorkout(
      title: trimmed,
      summary: summary,
      systemImage: systemImage,
      steps: steps,
      isBuiltin: false
    )
    structuredRunWorkouts.append(workout)
    saveAll()
    return workout
  }

  func deleteStructuredWorkout(_ id: UUID) {
    guard let index = structuredRunWorkouts.firstIndex(where: { $0.id == id }) else { return }
    // Builtins bleiben unangetastet.
    if structuredRunWorkouts[index].isBuiltin { return }
    structuredRunWorkouts.remove(at: index)
    saveAll()
  }

  /// Reine Lese-Sicht: Builtins zuerst, dann Custom.
  var structuredWorkoutsSorted: [StructuredRunWorkout] {
    let builtin = structuredRunWorkouts.filter { $0.isBuiltin }
    let custom  = structuredRunWorkouts.filter { !$0.isBuiltin }
    return builtin + custom
  }

  // MARK: - Active Structured Workout (Runtime)

  /// Startet einen Lauf inkl. strukturiertem Workout. Setzt sowohl `activeRun`
  /// als auch `activeStructuredWorkout`, damit der Tracker den Step-Status
  /// abfragen kann.
  func startStructuredWorkout(_ workout: StructuredRunWorkout) {
    if activeRun == nil {
      activeRun = ActiveRunSession(
        id: UUID(),
        title: workout.title,
        routeName: "Workout",
        startedAt: Date(),
        targetDistanceKm: workout.estimatedDistanceKm,
        targetDurationMinutes: workout.estimatedDurationMinutes,
        targetPaceLabel: "",
        targetMode: workout.estimatedDistanceKm > 0 ? .distance : .duration,
        targetPaceSeconds: 0,
        intensity: .interval,
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
    activeStructuredWorkout = ActiveStructuredWorkout(workout: workout)
  }

  /// Aktualisiert den aktuellen Step-State anhand der Live-Tracker-Daten.
  /// Gibt `true` zurück, wenn ein Step-Wechsel stattgefunden hat — der
  /// `RunTrackerView` kann das als Audio-Cue auslösen.
  @discardableResult
  func tickStructuredWorkout(distanceKm: Double, elapsedSeconds: Int) -> Bool {
    guard var active = activeStructuredWorkout else { return false }
    guard let step = active.currentStep else {
      activeStructuredWorkout = active
      return false
    }

    let progress = active.currentStepProgress(distanceKm: distanceKm, elapsedSeconds: elapsedSeconds)
    if progress >= 1 {
      // Schritt ist fertig — auf den nächsten wechseln.
      active.currentStepIndex += 1
      active.stepStartDistanceKm = distanceKm
      active.stepStartElapsedSeconds = elapsedSeconds
      activeStructuredWorkout = active
      _ = step // markiert benutzt
      return true
    }
    activeStructuredWorkout = active
    return false
  }

  /// Beendet das strukturierte Workout, ohne den Lauf zu beenden — der Nutzer
  /// kann frei weiterlaufen.
  func endStructuredWorkout() {
    activeStructuredWorkout = nil
  }
}
