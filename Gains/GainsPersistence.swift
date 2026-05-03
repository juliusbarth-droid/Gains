import CoreLocation
import Foundation

// MARK: - Persistence Keys
//
// Zentrale Konstanten für UserDefaults / @AppStorage Keys. Vorher waren die
// String-Literale in 5+ Files dupliziert ("gains_onboardingCompletedAt",
// "gains_hasCompletedOnboarding") — Tippfehler hätten den Onboarding-Flow
// stillschweigend gebrochen.
//
// **Wichtig**: Bei `@AppStorage` MUSS der Key als String-Literal übergeben
// werden (Property-Wrapper akzeptiert kein static let). Daher sind die Werte
// hier nur als Source-of-Truth dokumentiert; Call-Sites schreiben den Wert
// per `@AppStorage(GainsKey.onboardingCompletedAt)` mit `static let` als
// computed-konstantem String.
enum GainsKey {
  /// Bool — schaltet zwischen OnboardingView und ContentView.
  static let hasCompletedOnboarding = "gains_hasCompletedOnboarding"
  /// Double (timestamp) — `Date().timeIntervalSince1970` beim Onboarding-
  /// Abschluss. Steuert den 24h-„Day-One"-Banner in Home/Gym/Lauf/Nutrition.
  static let onboardingCompletedAt = "gains_onboardingCompletedAt"
  /// Bool — Waitlist-Marker für die Community-Coming-Soon-Card.
  static let communityWaitlist = "gains_communityWaitlist"
}

// MARK: - Enum Codable Conformances

extension BiologicalSex: Codable {}
extension ActivityLevel: Codable {}
extension NutritionGoal: Codable {}
extension RecipeMealType: Codable {}
extension WorkoutDayPreference: Codable {}
extension WorkoutPlanningGoal: Codable {}
extension WorkoutTrainingFocus: Codable {}
extension Weekday: Codable {}
extension TrainingExperience: Codable {}
extension GymEquipment: Codable {}
extension SplitPreference: Codable {}
extension RecoveryCapacity: Codable {}
extension MuscleGroup: Codable {}
extension WorkoutLimitation: Codable {}
extension RunningGoal: Codable {}
extension RunIntensityModel: Codable {}
extension PlannedSessionKind: Codable {}

extension WorkoutPlanSource: Codable {
  private enum RawValue: String, Codable {
    case template, custom
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .template: try container.encode(RawValue.template)
    case .custom:   try container.encode(RawValue.custom)
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let raw = try container.decode(RawValue.self)
    switch raw {
    case .template: self = .template
    case .custom:   self = .custom
    }
  }
}

// MARK: - Struct Codable Conformances

extension WeightTrendPoint: Codable {
  // id wird nicht kodiert – UUID wird beim Laden neu erzeugt (kein Problem, da nicht referenziert)
  enum CodingKeys: String, CodingKey { case label, value }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      label: try c.decode(String.self, forKey: .label),
      value: try c.decode(Double.self, forKey: .value)
    )
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(label, forKey: .label)
    try c.encode(value, forKey: .value)
  }
}

extension NutritionEntry: Codable {
  enum CodingKeys: String, CodingKey {
    case id, title, mealType, loggedAt, calories, protein, carbs, fat
  }

  // A5: Defensiv decodieren — id/title/loggedAt sind Pflicht, Makros fallen
  // auf 0 zurück wenn künftige Versionen Felder umbenennen.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id       = try c.decode(UUID.self, forKey: .id)
    title    = try c.decode(String.self, forKey: .title)
    mealType = try c.decodeIfPresent(RecipeMealType.self, forKey: .mealType) ?? .snack
    loggedAt = try c.decode(Date.self, forKey: .loggedAt)
    calories = try c.decodeIfPresent(Int.self, forKey: .calories) ?? 0
    protein  = try c.decodeIfPresent(Int.self, forKey: .protein) ?? 0
    carbs    = try c.decodeIfPresent(Int.self, forKey: .carbs) ?? 0
    fat      = try c.decodeIfPresent(Int.self, forKey: .fat) ?? 0
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id,       forKey: .id)
    try c.encode(title,    forKey: .title)
    try c.encode(mealType, forKey: .mealType)
    try c.encode(loggedAt, forKey: .loggedAt)
    try c.encode(calories, forKey: .calories)
    try c.encode(protein,  forKey: .protein)
    try c.encode(carbs,    forKey: .carbs)
    try c.encode(fat,      forKey: .fat)
  }
}

extension NutritionProfile: Codable {
  enum CodingKeys: String, CodingKey {
    case sex, age, heightCm, weightKg, bodyFatPercent, activityLevel, goal, surplusKcal
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    sex            = try c.decode(BiologicalSex.self,   forKey: .sex)
    age            = try c.decode(Int.self,             forKey: .age)
    heightCm       = try c.decode(Int.self,             forKey: .heightCm)
    weightKg       = try c.decode(Int.self,             forKey: .weightKg)
    bodyFatPercent = try c.decodeIfPresent(Double.self, forKey: .bodyFatPercent)
    activityLevel  = try c.decode(ActivityLevel.self,   forKey: .activityLevel)
    goal           = try c.decode(NutritionGoal.self,   forKey: .goal)
    surplusKcal    = try c.decode(Int.self,             forKey: .surplusKcal)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(sex,           forKey: .sex)
    try c.encode(age,           forKey: .age)
    try c.encode(heightCm,      forKey: .heightCm)
    try c.encode(weightKg,      forKey: .weightKg)
    try c.encodeIfPresent(bodyFatPercent, forKey: .bodyFatPercent)
    try c.encode(activityLevel, forKey: .activityLevel)
    try c.encode(goal,          forKey: .goal)
    try c.encode(surplusKcal,   forKey: .surplusKcal)
  }
}

extension WorkoutSetTemplate: Codable {
  enum CodingKeys: String, CodingKey { case reps, suggestedWeight }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    reps            = try c.decode(Int.self,    forKey: .reps)
    suggestedWeight = try c.decode(Double.self, forKey: .suggestedWeight)
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(reps,            forKey: .reps)
    try c.encode(suggestedWeight, forKey: .suggestedWeight)
  }
}

extension WorkoutExerciseTemplate: Codable {
  // id nicht kodiert – wird beim Laden neu erzeugt
  enum CodingKeys: String, CodingKey { case name, targetMuscle, sets }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      name:         try c.decode(String.self,               forKey: .name),
      targetMuscle: try c.decode(String.self,               forKey: .targetMuscle),
      sets:         try c.decode([WorkoutSetTemplate].self, forKey: .sets)
    )
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name,         forKey: .name)
    try c.encode(targetMuscle, forKey: .targetMuscle)
    try c.encode(sets,          forKey: .sets)
  }
}

extension WorkoutPlan: Codable {
  enum CodingKeys: String, CodingKey {
    case id, source, title, focus, split, estimatedDurationMinutes, exercises
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id:                       try c.decode(UUID.self,                      forKey: .id),
      source:                   try c.decode(WorkoutPlanSource.self,         forKey: .source),
      title:                    try c.decode(String.self,                    forKey: .title),
      focus:                    try c.decode(String.self,                    forKey: .focus),
      split:                    try c.decode(String.self,                    forKey: .split),
      estimatedDurationMinutes: try c.decode(Int.self,                      forKey: .estimatedDurationMinutes),
      exercises:                try c.decode([WorkoutExerciseTemplate].self, forKey: .exercises)
    )
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id,                       forKey: .id)
    try c.encode(source,                   forKey: .source)
    try c.encode(title,                    forKey: .title)
    try c.encode(focus,                    forKey: .focus)
    try c.encode(split,                    forKey: .split)
    try c.encode(estimatedDurationMinutes, forKey: .estimatedDurationMinutes)
    try c.encode(exercises,                forKey: .exercises)
  }
}

extension WorkoutPlannerSettings: Codable {
  // [Weekday: X] → als [String: String] kodieren (rawValue als Schlüssel)
  enum CodingKeys: String, CodingKey {
    case sessionsPerWeek, preferredSessionLength, goal, trainingFocus
    case dayPreferences, dayAssignments
    case experience, equipment, splitPreference, recoveryCapacity
    case prioritizedMuscles, limitations
    case runningGoal, runIntensityModel, weeklyKilometerTarget
    case isManualPlan, manualSessionKinds
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(sessionsPerWeek,        forKey: .sessionsPerWeek)
    try c.encode(preferredSessionLength, forKey: .preferredSessionLength)
    try c.encode(goal,                   forKey: .goal)
    try c.encode(trainingFocus,          forKey: .trainingFocus)

    // [Weekday: WorkoutDayPreference] → [String: String]
    let prefs = Dictionary(uniqueKeysWithValues: dayPreferences.map {
      (String($0.key.rawValue), $0.value.rawValue)
    })
    try c.encode(prefs, forKey: .dayPreferences)

    // [Weekday: UUID] → [String: String]
    let assigns = Dictionary(uniqueKeysWithValues: dayAssignments.map {
      (String($0.key.rawValue), $0.value.uuidString)
    })
    try c.encode(assigns, forKey: .dayAssignments)

    try c.encode(experience,            forKey: .experience)
    try c.encode(equipment,              forKey: .equipment)
    try c.encode(splitPreference,        forKey: .splitPreference)
    try c.encode(recoveryCapacity,       forKey: .recoveryCapacity)
    try c.encode(Array(prioritizedMuscles).map(\.rawValue), forKey: .prioritizedMuscles)
    try c.encode(Array(limitations).map(\.rawValue),        forKey: .limitations)
    try c.encode(runningGoal,            forKey: .runningGoal)
    try c.encode(runIntensityModel,      forKey: .runIntensityModel)
    try c.encode(weeklyKilometerTarget,  forKey: .weeklyKilometerTarget)

    try c.encode(isManualPlan, forKey: .isManualPlan)
    // [Weekday: PlannedSessionKind] → [String: String] (rawValues als Keys)
    let manual = Dictionary(uniqueKeysWithValues: manualSessionKinds.map {
      (String($0.key.rawValue), $0.value.rawValue)
    })
    try c.encode(manual, forKey: .manualSessionKinds)
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    sessionsPerWeek        = try c.decode(Int.self,                    forKey: .sessionsPerWeek)
    preferredSessionLength = try c.decode(Int.self,                    forKey: .preferredSessionLength)
    goal                   = try c.decode(WorkoutPlanningGoal.self,    forKey: .goal)
    trainingFocus          = try c.decode(WorkoutTrainingFocus.self,   forKey: .trainingFocus)

    let rawPrefs = try c.decode([String: String].self, forKey: .dayPreferences)
    dayPreferences = Dictionary(uniqueKeysWithValues: rawPrefs.compactMap { key, val -> (Weekday, WorkoutDayPreference)? in
      guard let raw = Int(key), let day = Weekday(rawValue: raw),
            let pref = WorkoutDayPreference(rawValue: val) else { return nil }
      return (day, pref)
    })

    let rawAssigns = try c.decode([String: String].self, forKey: .dayAssignments)
    dayAssignments = Dictionary(uniqueKeysWithValues: rawAssigns.compactMap { key, val -> (Weekday, UUID)? in
      guard let raw = Int(key), let day = Weekday(rawValue: raw),
            let uuid = UUID(uuidString: val) else { return nil }
      return (day, uuid)
    })

    // Migration: Wenn ein älterer Datensatz die Felder noch nicht kennt,
    // werden Defaults aus WorkoutPlannerSettings.default übernommen.
    let defaults = WorkoutPlannerSettings.default
    experience       = try c.decodeIfPresent(TrainingExperience.self,  forKey: .experience)        ?? defaults.experience
    equipment        = try c.decodeIfPresent(GymEquipment.self,        forKey: .equipment)         ?? defaults.equipment
    splitPreference  = try c.decodeIfPresent(SplitPreference.self,     forKey: .splitPreference)   ?? defaults.splitPreference
    recoveryCapacity = try c.decodeIfPresent(RecoveryCapacity.self,    forKey: .recoveryCapacity)  ?? defaults.recoveryCapacity

    let rawPriorities = try c.decodeIfPresent([String].self, forKey: .prioritizedMuscles) ?? []
    prioritizedMuscles = Set(rawPriorities.compactMap(MuscleGroup.init(rawValue:)))

    let rawLimits = try c.decodeIfPresent([String].self, forKey: .limitations) ?? []
    limitations = Set(rawLimits.compactMap(WorkoutLimitation.init(rawValue:)))

    runningGoal           = try c.decodeIfPresent(RunningGoal.self,        forKey: .runningGoal)           ?? defaults.runningGoal
    runIntensityModel     = try c.decodeIfPresent(RunIntensityModel.self,  forKey: .runIntensityModel)     ?? defaults.runIntensityModel
    weeklyKilometerTarget = try c.decodeIfPresent(Int.self,                forKey: .weeklyKilometerTarget) ?? defaults.weeklyKilometerTarget

    // Migration für manuellen Plan: ältere Datensätze haben die Felder
    // noch nicht — Defaults greifen, der Wizard-Flow bleibt aktiv.
    isManualPlan = try c.decodeIfPresent(Bool.self, forKey: .isManualPlan) ?? defaults.isManualPlan
    let rawManual = try c.decodeIfPresent([String: String].self, forKey: .manualSessionKinds) ?? [:]
    manualSessionKinds = Dictionary(uniqueKeysWithValues: rawManual.compactMap { key, val -> (Weekday, PlannedSessionKind)? in
      guard let raw = Int(key), let day = Weekday(rawValue: raw),
            let kind = PlannedSessionKind(rawValue: val) else { return nil }
      return (day, kind)
    })
  }
}

extension CompletedExercisePerformance: Codable {
  // id nicht kodiert – wird beim Laden neu erzeugt
  enum CodingKeys: String, CodingKey {
    case name, completedSets, totalReps, topWeight, totalVolume
  }

  // A5: Nur `name` ist Pflicht — alle Zahlen-Felder fallen auf 0 zurück, falls
  // ein künftiges Schema Felder umbenennt oder älteres Format nicht alle Werte hatte.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      name:          try c.decode(String.self, forKey: .name),
      completedSets: try c.decodeIfPresent(Int.self,    forKey: .completedSets) ?? 0,
      totalReps:     try c.decodeIfPresent(Int.self,    forKey: .totalReps)     ?? 0,
      topWeight:     try c.decodeIfPresent(Double.self, forKey: .topWeight)     ?? 0,
      totalVolume:   try c.decodeIfPresent(Double.self, forKey: .totalVolume)   ?? 0
    )
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(name,          forKey: .name)
    try c.encode(completedSets, forKey: .completedSets)
    try c.encode(totalReps,     forKey: .totalReps)
    try c.encode(topWeight,     forKey: .topWeight)
    try c.encode(totalVolume,   forKey: .totalVolume)
  }
}

extension CompletedWorkoutSummary: Codable {
  // id nicht kodiert – CompletedWorkoutSummary.init() erzeugt automatisch eine neue UUID
  enum CodingKeys: String, CodingKey {
    case title, finishedAt, completedSets, totalSets, volume, exercises
  }

  // A5: title/finishedAt sind Pflicht, alle Aggregat-Werte und exercises
  // fallen auf 0 / leer zurück.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      title:         try c.decode(String.self,                                 forKey: .title),
      finishedAt:    try c.decode(Date.self,                                   forKey: .finishedAt),
      completedSets: try c.decodeIfPresent(Int.self,                           forKey: .completedSets) ?? 0,
      totalSets:     try c.decodeIfPresent(Int.self,                           forKey: .totalSets)     ?? 0,
      volume:        try c.decodeIfPresent(Double.self,                        forKey: .volume)        ?? 0,
      exercises:     try c.decodeIfPresent([CompletedExercisePerformance].self, forKey: .exercises)    ?? []
    )
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(title,         forKey: .title)
    try c.encode(finishedAt,    forKey: .finishedAt)
    try c.encode(completedSets, forKey: .completedSets)
    try c.encode(totalSets,     forKey: .totalSets)
    try c.encode(volume,        forKey: .volume)
    try c.encode(exercises,     forKey: .exercises)
  }
}

extension RunSplit: Codable {
  enum CodingKeys: String, CodingKey {
    case id, index, distanceKm, durationMinutes, averageHeartRate, isManualLap
  }

  // A5: id/index Pflicht, Messwerte fallen auf 0 zurück.
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id               = try c.decode(UUID.self,                forKey: .id)
    index            = try c.decode(Int.self,                 forKey: .index)
    distanceKm       = try c.decodeIfPresent(Double.self,     forKey: .distanceKm)       ?? 0
    durationMinutes  = try c.decodeIfPresent(Int.self,        forKey: .durationMinutes)  ?? 0
    averageHeartRate = try c.decodeIfPresent(Int.self,        forKey: .averageHeartRate) ?? 0
    isManualLap      = try c.decodeIfPresent(Bool.self,       forKey: .isManualLap)      ?? false
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id,               forKey: .id)
    try c.encode(index,            forKey: .index)
    try c.encode(distanceKm,       forKey: .distanceKm)
    try c.encode(durationMinutes,  forKey: .durationMinutes)
    try c.encode(averageHeartRate, forKey: .averageHeartRate)
    if isManualLap {
      try c.encode(isManualLap,    forKey: .isManualLap)
    }
  }
}

// CLLocationCoordinate2D als [lat, lon] enkodieren
private struct CodableCoordinate: Codable {
  let latitude: Double
  let longitude: Double
}

extension CompletedRunSummary: Codable {
  enum CodingKeys: String, CodingKey {
    case id, title, routeName, finishedAt, distanceKm, durationMinutes
    case elevationGain, averageHeartRate, routeCoordinates, splits
    case intensity, feel, note, hrZoneSecondsBuckets, modality
  }

  // A5: id/title/finishedAt Pflicht; routeName, Messwerte und Routen-Coords
  // sind tolerant — alte Records ohne Strecke laden weiter.
  init(from decoder: Decoder) throws {
    let c    = try decoder.container(keyedBy: CodingKeys.self)
    let coords = try c.decodeIfPresent([CodableCoordinate].self, forKey: .routeCoordinates) ?? []
    let intensityRaw = try c.decodeIfPresent(String.self,        forKey: .intensity)
    let feelRaw      = try c.decodeIfPresent(Int.self,           forKey: .feel)
    let modalityRaw  = try c.decodeIfPresent(String.self,        forKey: .modality)
    self.init(
      id:               try c.decode(UUID.self,                       forKey: .id),
      title:            try c.decode(String.self,                     forKey: .title),
      routeName:        try c.decodeIfPresent(String.self,            forKey: .routeName)        ?? "",
      finishedAt:       try c.decode(Date.self,                       forKey: .finishedAt),
      distanceKm:       try c.decodeIfPresent(Double.self,            forKey: .distanceKm)       ?? 0,
      durationMinutes:  try c.decodeIfPresent(Int.self,               forKey: .durationMinutes)  ?? 0,
      elevationGain:    try c.decodeIfPresent(Int.self,               forKey: .elevationGain)    ?? 0,
      averageHeartRate: try c.decodeIfPresent(Int.self,               forKey: .averageHeartRate) ?? 0,
      routeCoordinates: coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
      splits:           try c.decodeIfPresent([RunSplit].self,        forKey: .splits)           ?? [],
      intensity:        intensityRaw.flatMap { RunIntensity(rawValue: $0) } ?? .free,
      feel:             feelRaw.flatMap { RunFeel(rawValue: $0) },
      note:             try c.decodeIfPresent(String.self,            forKey: .note)             ?? "",
      hrZoneSecondsBuckets: try c.decodeIfPresent([Int].self,         forKey: .hrZoneSecondsBuckets) ?? [0,0,0,0,0],
      modality:         CardioModality.decode(legacyRaw: modalityRaw)
    )
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id,               forKey: .id)
    try c.encode(title,            forKey: .title)
    try c.encode(routeName,        forKey: .routeName)
    try c.encode(finishedAt,       forKey: .finishedAt)
    try c.encode(distanceKm,       forKey: .distanceKm)
    try c.encode(durationMinutes,  forKey: .durationMinutes)
    try c.encode(elevationGain,    forKey: .elevationGain)
    try c.encode(averageHeartRate, forKey: .averageHeartRate)
    let coords = routeCoordinates.map { CodableCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
    try c.encode(coords,           forKey: .routeCoordinates)
    try c.encode(splits,           forKey: .splits)
    try c.encode(intensity.rawValue, forKey: .intensity)
    if let feel { try c.encode(feel.rawValue, forKey: .feel) }
    if !note.isEmpty { try c.encode(note,    forKey: .note) }
    if hrZoneSecondsBuckets.contains(where: { $0 > 0 }) {
      try c.encode(hrZoneSecondsBuckets, forKey: .hrZoneSecondsBuckets)
    }
    if modality != .run { try c.encode(modality.rawValue, forKey: .modality) }
  }
}

// MARK: - SavedRoute Codable

extension SavedRoute: Codable {
  enum CodingKeys: String, CodingKey {
    case id, title, note, distanceKm, elevationGain, surface, createdAt, coordinates, timesRun
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let coords = try c.decodeIfPresent([CodableCoordinate].self, forKey: .coordinates) ?? []
    self.init(
      id:            try c.decode(UUID.self,                      forKey: .id),
      title:         try c.decodeIfPresent(String.self,           forKey: .title)         ?? "Route",
      note:          try c.decodeIfPresent(String.self,           forKey: .note)          ?? "",
      distanceKm:    try c.decodeIfPresent(Double.self,           forKey: .distanceKm)    ?? 0,
      elevationGain: try c.decodeIfPresent(Int.self,              forKey: .elevationGain) ?? 0,
      surface:       try c.decodeIfPresent(RouteSurface.self,     forKey: .surface)       ?? .mixed,
      createdAt:     try c.decodeIfPresent(Date.self,             forKey: .createdAt)     ?? Date(),
      coordinates:   coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
      timesRun:      try c.decodeIfPresent(Int.self,              forKey: .timesRun)      ?? 0
    )
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id,            forKey: .id)
    try c.encode(title,         forKey: .title)
    try c.encode(note,          forKey: .note)
    try c.encode(distanceKm,    forKey: .distanceKm)
    try c.encode(elevationGain, forKey: .elevationGain)
    try c.encode(surface,       forKey: .surface)
    try c.encode(createdAt,     forKey: .createdAt)
    let coords = coordinates.map { CodableCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
    try c.encode(coords,        forKey: .coordinates)
    try c.encode(timesRun,      forKey: .timesRun)
  }
}

// MARK: - RunSegment Codable

extension RunSegment: Codable {
  enum CodingKeys: String, CodingKey {
    case id, title, note, coordinates, distanceKm, elevationGain, createdAt, isAutoCreated
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let coords = try c.decodeIfPresent([CodableCoordinate].self, forKey: .coordinates) ?? []
    self.init(
      id:            try c.decode(UUID.self,             forKey: .id),
      title:         try c.decodeIfPresent(String.self,  forKey: .title)         ?? "Segment",
      note:          try c.decodeIfPresent(String.self,  forKey: .note)          ?? "",
      coordinates:   coords.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) },
      distanceKm:    try c.decodeIfPresent(Double.self,  forKey: .distanceKm)    ?? 0,
      elevationGain: try c.decodeIfPresent(Int.self,     forKey: .elevationGain) ?? 0,
      createdAt:     try c.decodeIfPresent(Date.self,    forKey: .createdAt)     ?? Date(),
      isAutoCreated: try c.decodeIfPresent(Bool.self,    forKey: .isAutoCreated) ?? false
    )
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id,            forKey: .id)
    try c.encode(title,         forKey: .title)
    try c.encode(note,          forKey: .note)
    let coords = coordinates.map { CodableCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
    try c.encode(coords,        forKey: .coordinates)
    try c.encode(distanceKm,    forKey: .distanceKm)
    try c.encode(elevationGain, forKey: .elevationGain)
    try c.encode(createdAt,     forKey: .createdAt)
    try c.encode(isAutoCreated, forKey: .isAutoCreated)
  }
}

// MARK: - Persistence Keys

enum PersistenceKey {
  static let userName             = "gains_userName"
  // 2026-05-03: Profil-Bild als JPEG-komprimierte Data-Blobs in den
  // UserDefaults — klein genug (~50-150 KB nach 0.7-Quality-JPEG bei
  // 512×512), kein extra Files-API-Pfad nötig, und der Avatar ist sofort
  // verfügbar wenn HomeView den Greeting-Header rendert.
  static let userAvatarData       = "gains_userAvatarData"
  static let workoutHistory       = "gains_workoutHistory"
  static let runHistory           = "gains_runHistory"
  static let savedWorkoutPlans    = "gains_savedWorkoutPlans"
  static let plannerSettings      = "gains_plannerSettings"
  static let weightTrend          = "gains_weightTrend"
  static let waistMeasurement     = "gains_waistMeasurement"
  static let bodyFatChange        = "gains_bodyFatChange"
  static let proteinProgress      = "gains_proteinProgress"
  static let streakDays           = "gains_streakDays"
  static let recordDays           = "gains_recordDays"
  static let vitalSyncCount       = "gains_vitalSyncCount"
  static let completedDates       = "gains_completedDates"
  static let nutritionEntries     = "gains_nutritionEntries"
  static let nutritionGoal        = "gains_nutritionGoal"
  static let nutritionProfile     = "gains_nutritionProfile"
  static let connectedTrackerIDs        = "gains_connectedTrackerIDs"
  static let favoriteRecipeIDs          = "gains_favoriteRecipeIDs"
  /// Coach Check-in IDs die der Nutzer bereits bestätigt hat — damit der
  /// Coach sie nach App-Neustart nicht nochmal anzeigt.
  static let completedCoachCheckInIDs   = "gains_completedCoachCheckInIDs"
  static let notificationsEnabled = "gains_notificationsEnabled"
  static let healthAutoSync       = "gains_healthAutoSync"
  static let studyCoaching        = "gains_studyCoaching"
  static let appearanceMode       = "gains_appearanceMode"
  static let joinedChallenge      = "gains_joinedChallenge"
  static let socialSharingSettings = "gains_socialSharingSettings"
  static let forumThreads         = "gains_forumThreads"
  static let likedThreadIDs       = "gains_likedThreadIDs"
  static let meetups              = "gains_meetups"
  static let joinedMeetupIDs      = "gains_joinedMeetupIDs"
  static let likedPostIDs         = "gains_likedPostIDs"
  static let commentedPostIDs     = "gains_commentedPostIDs"
  static let sharedPostIDs        = "gains_sharedPostIDs"
  // Strava-Erweiterung: Routen, Segmente, strukturierte Workouts
  static let savedRoutes          = "gains_savedRoutes"
  static let runSegments          = "gains_runSegments"
  static let runSegmentEfforts    = "gains_runSegmentEfforts"
  static let structuredRunWorkouts = "gains_structuredRunWorkouts"
  /// Goal-Trainingsplan (Distanz × Pace × Datum → Wochen-Sessions).
  /// Optional — nicht jeder Nutzer setzt ein Ziel.
  static let runGoalPlan          = "gains_runGoalPlan"
  /// A5: Schema-Version, mit der die persistierten Daten geschrieben wurden.
  /// Wird beim App-Start gegen `PersistenceMigrator.currentVersion` geprüft.
  static let schemaVersion        = "gains_schemaVersion"
}

// MARK: - Persistence Migrator
//
// Hält die aktuelle Schema-Version und führt Migrationen von älteren
// Versionen aus. Wird in `GainsStore.init()` vor `loadPersistedData()`
// aufgerufen.
//
// Bumping the version:
//   - Erhöhe `currentVersion` um 1.
//   - Ergänze einen `case` in `migrate(from:to:in:)` mit der konkreten
//     Transformation (z.B. neuen Schlüssel mit Default-Wert füllen,
//     Schlüssel umbenennen, Datenstruktur aktualisieren).
//   - Bestehende Codable-Inits sollten neue Felder mit `decodeIfPresent`
//     plus Default lesen, dann ist die Migration im Idealfall ein No-op.

enum PersistenceMigrator {
  /// Aktuelle Schema-Version.
  /// v1 — Initial-Version (kein expliziter Versionskey gespeichert).
  /// v2 — Defensive Codable-Inits für CompletedWorkout/Run/NutritionEntry,
  ///      `decodedLoadLenient` toleriert einzelne korrupte Array-Elemente.
  static let currentVersion = 2

  /// Liest die gespeicherte Version, führt ggf. Migrationen durch und
  /// schreibt anschließend die aktuelle Version zurück.
  static func runIfNeeded(in defaults: UserDefaults = .standard) {
    let stored = defaults.object(forKey: PersistenceKey.schemaVersion) as? Int ?? 1
    guard stored < currentVersion else {
      // Version ist aktuell oder neuer (z.B. nach Downgrade) — nichts tun.
      return
    }
    var version = stored
    while version < currentVersion {
      migrate(from: version, to: version + 1, in: defaults)
      version += 1
    }
    defaults.set(currentVersion, forKey: PersistenceKey.schemaVersion)
  }

  private static func migrate(from: Int, to: Int, in defaults: UserDefaults) {
    switch (from, to) {
    case (1, 2):
      // Keine harten Schema-Brüche zwischen v1 und v2 — die defensiven
      // Codable-Inits decodieren ältere Datensätze weiter. Falls einzelne
      // Records zu alt/korrupt sind, fängt sie `decodedLoadLenient` einzeln ab.
      break
    default:
      // Unbekannter Migrationspfad — bewusst still, wir halten an dem was wir haben.
      break
    }
  }
}

// MARK: - String Helpers

extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

// MARK: - UserDefaults Helpers

extension UserDefaults {
  func encodedSave<T: Encodable>(_ value: T, forKey key: String) {
    guard let data = try? JSONEncoder().encode(value) else {
      #if DEBUG
      print("[GainsPersistence] ⚠️ Encoding fehlgeschlagen für Key '\(key)' (\(T.self)) — Daten werden nicht gespeichert.")
      #endif
      return
    }
    set(data, forKey: key)
  }

  func decodedLoad<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
    guard let data = data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }

  /// A5: Decodiert ein [UUID: [T]]-Dictionary tolerant — korrupte Values werden
  /// übersprungen statt das ganze Dictionary zu verwerfen. Gibt nil zurück, wenn
  /// unter dem Key kein JSON-Objekt liegt.
  ///
  /// Verwendet statt `decodedLoad([UUID: [T]].self, forKey:)` für Dictionaries
  /// (z.B. runSegmentEfforts), bei denen ein einzelner kaputter Wert nicht alle
  /// anderen Einträge mitreißen darf.
  func decodedLoadLenientUUIDDictionary<T: Decodable>(_ elementType: T.Type, forKey key: String) -> [UUID: [T]]? {
    guard let data = data(forKey: key) else { return nil }
    let decoder = JSONDecoder()
    // Schneller Pfad: alles kompatibel → direkt decodieren.
    if let result = try? decoder.decode([String: [T]].self, from: data) {
      let mapped = result.compactMap { k, v -> (UUID, [T])? in
        guard let uuid = UUID(uuidString: k) else { return nil }
        return (uuid, v)
      }
      return mapped.isEmpty ? nil : Dictionary(uniqueKeysWithValues: mapped)
    }
    // Fallback: Key für Key decodieren — korrupte Values einzeln überspringen.
    guard let raw = try? JSONSerialization.jsonObject(with: data),
          let dict = raw as? [String: Any] else { return nil }
    var result: [UUID: [T]] = [:]
    for (k, v) in dict {
      guard let uuid = UUID(uuidString: k),
            let valueData = try? JSONSerialization.data(withJSONObject: v),
            let elements = try? decoder.decode([T].self, from: valueData) else { continue }
      result[uuid] = elements
    }
    return result.isEmpty ? nil : result
  }

  /// A5: Decodiert ein Array tolerant — wenn einzelne Elemente nicht decodierbar
  /// sind (z.B. nach Schema-Änderung), werden sie übersprungen statt das ganze
  /// Array zu verwerfen. Gibt nil zurück, wenn unter dem Key kein JSON-Array steht.
  ///
  /// Verwende statt `decodedLoad([T].self, forKey:)` für persistente Historien
  /// (Workouts, Runs, Nutrition-Logs), wo ein einzelner kaputter Eintrag nicht
  /// die ganze Liste mitreißen darf.
  func decodedLoadLenient<T: Decodable>(_ elementType: T.Type, forKey key: String) -> [T]? {
    guard let data = data(forKey: key) else { return nil }
    let decoder = JSONDecoder()
    // Erst den schnellen Pfad versuchen — moderne JSONs decodieren komplett.
    if let result = try? decoder.decode([T].self, from: data) {
      return result
    }
    // Fallback: Element-für-Element via raw JSON-Array.
    guard let raw = try? JSONSerialization.jsonObject(with: data, options: []),
          let array = raw as? [Any] else {
      return nil
    }
    return array.compactMap { element -> T? in
      guard let elementData = try? JSONSerialization.data(withJSONObject: element, options: [])
      else { return nil }
      return try? decoder.decode(T.self, from: elementData)
    }
  }
}
