import CoreLocation
import Combine
import Foundation
import HealthKit

struct HealthSnapshot {
  var stepsToday: Int
  var activeEnergyToday: Int
  var exerciseMinutesToday: Int
  var distanceWalkingRunningKmToday: Double
  var sleepHoursLastNight: Double?
  var currentHeartRate: Double?
  var restingHeartRate: Double?
  var heartRateVariability: Double?
  var vo2Max: Double?
  var bodyMassKg: Double?
  var lastSyncDate: Date
}

final class HealthKitManager: ObservableObject {
  static let shared = HealthKitManager()

  private let healthStore = HKHealthStore()

  /// Zuletzt empfangene Echtzeit-Herzfrequenz (bpm). Nil solange kein Wert vorliegt.
  @Published private(set) var liveHeartRate: Int? = nil

  private var heartRateQuery: HKQuery?

  private init() {}

  var isAvailable: Bool {
    HKHealthStore.isHealthDataAvailable()
  }

  func requestAuthorization(completion: @escaping (Bool, String?) -> Void) {
    guard isAvailable else {
      completion(false, "HealthKit ist auf diesem Gerät nicht verfügbar.")
      return
    }

    guard
      let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
      let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
      let exerciseTimeType = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
      let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
      let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
      let restingHeartRateType = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
      let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
      let vo2MaxType = HKObjectType.quantityType(forIdentifier: .vo2Max),
      let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass),
      let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
    else {
      completion(false, "Einige Health-Datentypen konnten nicht geladen werden.")
      return
    }

    let readTypes: Set<HKObjectType> = [
      stepType,
      activeEnergyType,
      exerciseTimeType,
      distanceType,
      heartRateType,
      restingHeartRateType,
      hrvType,
      vo2MaxType,
      bodyMassType,
      sleepType,
      HKObjectType.workoutType(),
    ]

    // Schreibrechte: Workouts (Kraft + Lauf) sowie die zugehörigen
    // Energie-/Distanz-Samples. Damit landen Gains-Aktivitäten in Apple
    // Health und werden nicht mehr doppelt erfasst.
    let writeTypes: Set<HKSampleType> = [
      HKObjectType.workoutType(),
      activeEnergyType,
      distanceType,
    ]

    healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
      DispatchQueue.main.async {
        completion(success, error?.localizedDescription)
      }
    }
  }

  // MARK: - Workout Write

  /// Liefert true, wenn der Nutzer mindestens das Workout-Schreibrecht erteilt hat.
  /// Apple macht den Lese-Status absichtlich opak — den Schreib-Status dürfen wir abfragen.
  var canWriteWorkouts: Bool {
    guard isAvailable else { return false }
    return healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
  }

  /// Speichert ein Krafttraining als HKWorkout in Apple Health.
  /// `totalEnergyKcal` ist optional — wenn die App keine Schätzung hat, einfach 0 übergeben.
  func saveStrengthWorkout(
    title: String,
    start: Date,
    end: Date,
    totalEnergyKcal: Double = 0
  ) {
    guard canWriteWorkouts else { return }

    let builder = HKWorkoutBuilder(
      healthStore: healthStore,
      configuration: workoutConfiguration(activity: .traditionalStrengthTraining),
      device: .local()
    )
    var metadata: [String: Any] = [HKMetadataKeyWorkoutBrandName: "Gains"]
    if !title.isEmpty {
      metadata["GainsWorkoutTitle"] = title
    }

    builder.beginCollection(withStart: start) { success, _ in
      guard success else { return }

      var samples: [HKSample] = []
      if totalEnergyKcal > 0,
         let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: totalEnergyKcal)
        samples.append(HKQuantitySample(type: type, quantity: quantity, start: start, end: end))
      }

      let finalize: () -> Void = {
        builder.addMetadata(metadata) { _, _ in
          builder.endCollection(withEnd: end) { ended, _ in
            guard ended else { return }
            builder.finishWorkout { _, _ in }
          }
        }
      }

      if samples.isEmpty {
        finalize()
      } else {
        builder.add(samples) { _, _ in finalize() }
      }
    }
  }

  /// Speichert einen Lauf als HKWorkout inklusive Distanz, optionaler Energie
  /// und — wenn vorhanden — der GPS-Route. Die Route wird als `HKWorkoutRoute`
  /// an das Workout gehängt, damit sie in der iOS-Health-App sichtbar wird.
  func saveRunWorkout(
    title: String,
    start: Date,
    end: Date,
    distanceKm: Double,
    totalEnergyKcal: Double = 0,
    routeCoordinates: [CLLocationCoordinate2D] = []
  ) {
    guard canWriteWorkouts else { return }

    let builder = HKWorkoutBuilder(
      healthStore: healthStore,
      configuration: workoutConfiguration(activity: .running),
      device: .local()
    )
    var metadata: [String: Any] = [HKMetadataKeyWorkoutBrandName: "Gains"]
    if !title.isEmpty {
      metadata["GainsWorkoutTitle"] = title
    }

    builder.beginCollection(withStart: start) { [weak self] success, _ in
      guard success, let self else { return }

      var samples: [HKSample] = []
      if distanceKm > 0,
         let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
        let quantity = HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: distanceKm)
        samples.append(
          HKQuantitySample(type: distanceType, quantity: quantity, start: start, end: end))
      }
      if totalEnergyKcal > 0,
         let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: totalEnergyKcal)
        samples.append(HKQuantitySample(type: energyType, quantity: quantity, start: start, end: end))
      }

      let finalizeWorkout: (HKWorkout?) -> Void = { workout in
        guard let workout, !routeCoordinates.isEmpty else { return }
        self.attachRoute(routeCoordinates, start: start, end: end, to: workout)
      }

      let endAndFinish: () -> Void = {
        builder.addMetadata(metadata) { _, _ in
          builder.endCollection(withEnd: end) { ended, _ in
            guard ended else { return }
            builder.finishWorkout { workout, _ in
              finalizeWorkout(workout)
            }
          }
        }
      }

      if samples.isEmpty {
        endAndFinish()
      } else {
        builder.add(samples) { _, _ in endAndFinish() }
      }
    }
  }

  // MARK: - Route attachment

  private func attachRoute(
    _ coordinates: [CLLocationCoordinate2D],
    start: Date,
    end: Date,
    to workout: HKWorkout
  ) {
    let routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
    let totalSeconds = max(end.timeIntervalSince(start), 1)
    let count = Double(max(coordinates.count, 1))
    let locations = coordinates.enumerated().map { index, coordinate -> CLLocation in
      let progress = count > 1 ? Double(index) / (count - 1) : 0
      let timestamp = start.addingTimeInterval(progress * totalSeconds)
      return CLLocation(
        coordinate: coordinate,
        altitude: 0,
        horizontalAccuracy: 5,
        verticalAccuracy: -1,
        timestamp: timestamp
      )
    }
    guard !locations.isEmpty else { return }

    routeBuilder.insertRouteData(locations) { success, _ in
      guard success else { return }
      routeBuilder.finishRoute(with: workout, metadata: nil) { _, _ in }
    }
  }

  private func workoutConfiguration(activity: HKWorkoutActivityType) -> HKWorkoutConfiguration {
    let config = HKWorkoutConfiguration()
    config.activityType = activity
    config.locationType = activity == .running ? .outdoor : .indoor
    return config
  }

  func loadSnapshot(completion: @escaping (Result<HealthSnapshot, Error>) -> Void) {
    let group = DispatchGroup()

    var stepsToday = 0
    var activeEnergyToday = 0
    var exerciseMinutesToday = 0
    var distanceWalkingRunningKmToday = 0.0
    var sleepHoursLastNight: Double?
    var currentHeartRate: Double?
    var restingHeartRate: Double?
    var heartRateVariability: Double?
    var vo2Max: Double?
    var bodyMassKg: Double?
    var firstError: Error?

    func capture(_ error: Error?) {
      guard firstError == nil, let error else { return }
      firstError = error
    }

    group.enter()
    sumQuantity(.stepCount, unit: HKUnit.count(), start: startOfDay, end: Date()) { result in
      if case .success(let value) = result { stepsToday = Int(value.rounded()) }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.enter()
    sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: startOfDay, end: Date()) {
      result in
      if case .success(let value) = result { activeEnergyToday = Int(value.rounded()) }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.enter()
    sumQuantity(.appleExerciseTime, unit: .minute(), start: startOfDay, end: Date()) { result in
      if case .success(let value) = result { exerciseMinutesToday = Int(value.rounded()) }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.enter()
    sumQuantity(
      .distanceWalkingRunning, unit: .meterUnit(with: .kilo), start: startOfDay, end: Date()
    ) { result in
      if case .success(let value) = result { distanceWalkingRunningKmToday = value }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.enter()
    fetchLatestQuantity(.heartRate, unit: HKUnit.count().unitDivided(by: .minute())) { result in
      if case .success(let value) = result { currentHeartRate = value }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.enter()
    fetchLatestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute())) {
      result in
      if case .success(let value) = result { restingHeartRate = value }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.enter()
    fetchLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) { result in
      if case .success(let value) = result { heartRateVariability = value }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.enter()
    fetchLatestQuantity(.vo2Max, unit: HKUnit(from: "ml/kg*min")) { result in
      if case .success(let value) = result { vo2Max = value }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.enter()
    fetchLatestQuantity(.bodyMass, unit: .gramUnit(with: .kilo)) { result in
      if case .success(let value) = result { bodyMassKg = value }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.enter()
    fetchSleepHours { result in
      if case .success(let value) = result { sleepHoursLastNight = value }
      if case .failure(let error) = result { capture(error) }
      group.leave()
    }

    group.notify(queue: .main) {
      if let firstError {
        completion(.failure(firstError))
        return
      }

      completion(
        .success(
          HealthSnapshot(
            stepsToday: stepsToday,
            activeEnergyToday: activeEnergyToday,
            exerciseMinutesToday: exerciseMinutesToday,
            distanceWalkingRunningKmToday: distanceWalkingRunningKmToday,
            sleepHoursLastNight: sleepHoursLastNight,
            currentHeartRate: currentHeartRate,
            restingHeartRate: restingHeartRate,
            heartRateVariability: heartRateVariability,
            vo2Max: vo2Max,
            bodyMassKg: bodyMassKg,
            lastSyncDate: Date()
          )
        )
      )
    }
  }

  // MARK: - Live Heart Rate Observer

  /// Startet einen dauerhaften HKAnchoredObjectQuery, der neue HF-Samples
  /// direkt in `liveHeartRate` schreibt. Kann mehrfach aufgerufen werden –
  /// ein laufender Observer wird vorher gestoppt.
  func startHeartRateObserver() {
    guard isAvailable else { return }
    guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

    stopHeartRateObserver()

    // Nur Samples der letzten 60 Sekunden beim ersten Fetch berücksichtigen.
    let recentStart = Date().addingTimeInterval(-60)
    let predicate = HKQuery.predicateForSamples(withStart: recentStart, end: nil)

    let query = HKAnchoredObjectQuery(
      type: heartRateType,
      predicate: predicate,
      anchor: nil,
      limit: HKObjectQueryNoLimit
    ) { [weak self] _, samples, _, _, _ in
      self?.processHeartRateSamples(samples)
    }

    query.updateHandler = { [weak self] _, samples, _, _, _ in
      self?.processHeartRateSamples(samples)
    }

    healthStore.execute(query)
    heartRateQuery = query
  }

  /// Stoppt den laufenden HF-Observer.
  func stopHeartRateObserver() {
    guard let query = heartRateQuery else { return }
    healthStore.stop(query)
    heartRateQuery = nil
  }

  private func processHeartRateSamples(_ samples: [HKSample]?) {
    // Wenn ein BLE-Gerät verbunden ist, ignorieren wir HealthKit-Samples –
    // BLE liefert eine niedrigere Latenz und höhere Genauigkeit.
    guard !BLEHeartRateManager.shared.isConnected else { return }
    guard let sample = (samples as? [HKQuantitySample])?.last else { return }
    let unit = HKUnit.count().unitDivided(by: .minute())
    let bpm = Int(sample.quantity.doubleValue(for: unit).rounded())
    DispatchQueue.main.async { [weak self] in
      self?.liveHeartRate = bpm
    }
  }

  /// Wird vom BLEHeartRateManager aufgerufen, um einen direkt gemessenen Wert zu setzen.
  /// BLE-Werte haben immer Vorrang vor HealthKit-Samples.
  func setExternalHeartRate(_ bpm: Int) {
    DispatchQueue.main.async { [weak self] in
      self?.liveHeartRate = bpm
    }
  }

  // MARK: - Helpers

  private var startOfDay: Date {
    Calendar.current.startOfDay(for: Date())
  }

  private func sumQuantity(
    _ identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    start: Date,
    end: Date,
    completion: @escaping (Result<Double, Error>) -> Void
  ) {
    guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
      completion(.success(0))
      return
    }

    let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
    let query = HKStatisticsQuery(
      quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum
    ) { _, statistics, error in
      if let error {
        completion(.failure(error))
        return
      }

      let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
      completion(.success(value))
    }
    healthStore.execute(query)
  }

  private func fetchLatestQuantity(
    _ identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    completion: @escaping (Result<Double?, Error>) -> Void
  ) {
    guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
      completion(.success(nil))
      return
    }

    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let query = HKSampleQuery(
      sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]
    ) { _, samples, error in
      if let error {
        completion(.failure(error))
        return
      }

      let quantitySample = samples?.first as? HKQuantitySample
      completion(.success(quantitySample?.quantity.doubleValue(for: unit)))
    }
    healthStore.execute(query)
  }

  private func fetchSleepHours(completion: @escaping (Result<Double?, Error>) -> Void) {
    guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
      completion(.success(nil))
      return
    }

    let start = Calendar.current.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
    let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
    let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

    let query = HKSampleQuery(
      sampleType: sleepType, predicate: predicate, limit: 20, sortDescriptors: [sortDescriptor]
    ) { _, samples, error in
      if let error {
        completion(.failure(error))
        return
      }

      let sleepSamples = (samples as? [HKCategorySample] ?? []).filter {
        if #available(iOS 16.0, *) {
          return $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            || $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
            || $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue
            || $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        } else {
          return $0.value == HKCategoryValueSleepAnalysis.asleep.rawValue
        }
      }

      let totalSeconds = sleepSamples.reduce(0.0) { partial, sample in
        partial + sample.endDate.timeIntervalSince(sample.startDate)
      }
      let hours = totalSeconds > 0 ? totalSeconds / 3600 : nil
      completion(.success(hours))
    }
    healthStore.execute(query)
  }
}
