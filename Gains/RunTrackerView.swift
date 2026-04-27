import CoreLocation
import MapKit
import SwiftUI

struct RunTrackerView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  @StateObject private var gpsTracker = RunLocationTracker()
  @ObservedObject private var healthKit = HealthKitManager.shared

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        if let run = store.activeRun {
          liveScreen(run)
        } else {
          startScreen
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Schließen") {
            stopTracking()
            dismiss()
          }
          .foregroundStyle(GainsColor.ink)
        }
      }
    }
    .onAppear {
      if store.activeRun != nil {
        gpsTracker.requestAuthorization()
        synchronizeTrackerState()
      }
      HealthKitManager.shared.startHeartRateObserver()
    }
    .onDisappear {
      HealthKitManager.shared.stopHeartRateObserver()
    }
    .onReceive(gpsTracker.$trackedDistanceKm) { _ in syncStoreWithTracker() }
    .onReceive(gpsTracker.$durationMinutes) { _ in syncStoreWithTracker() }
    .onReceive(gpsTracker.$elevationGain) { _ in syncStoreWithTracker() }
    .onReceive(gpsTracker.$splits) { _ in syncStoreWithTracker() }
    .onReceive(healthKit.$liveHeartRate) { bpm in
      guard let bpm else { return }
      gpsTracker.currentHeartRate = bpm
      if store.activeRun != nil {
        store.updateRunHeartRateLive(bpm)
      }
    }
    .onChange(of: store.activeRun?.id) { _, _ in
      if store.activeRun != nil {
        gpsTracker.requestAuthorization()
      }
      synchronizeTrackerState()
    }
    .onChange(of: gpsTracker.authorizationStatus) { _, _ in
      synchronizeTrackerState()
    }
  }

  private var startScreen: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 12) {
        Text("LAUF")
          .gainsEyebrow(GainsColor.softInk, size: 12, tracking: 2.4)

        Text("Bereit?")
          .font(.system(size: 38, weight: .semibold))
          .foregroundStyle(GainsColor.ink)

        Text(startSummaryLine)
          .font(GainsFont.body(15))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.top, 12)
      .padding(.bottom, 18)

      Map(position: .constant(gpsTracker.cameraPosition)) {
        if let coordinate = gpsTracker.currentCoordinate {
          Annotation("Aktuell", coordinate: coordinate) {
            currentLocationMarker
          }
        }
      }
      .overlay(alignment: .bottomLeading) {
        gpsStatusChip
          .padding(16)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      Button {
        startRunNow()
      } label: {
        Text("Lauf starten")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(GainsColor.onLime)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(GainsColor.lime)
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 20)
    }
  }

  private var currentLocationMarker: some View {
    Circle()
      .fill(GainsColor.lime)
      .frame(width: 16, height: 16)
      .overlay { Circle().stroke(GainsColor.ink, lineWidth: 3) }
  }

  private var gpsStatusChip: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(gpsTracker.canStartTracking ? GainsColor.lime : GainsColor.softInk)
        .frame(width: 6, height: 6)
      Text(gpsTracker.canStartTracking ? "GPS BEREIT" : "GPS VORSCHAU")
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.ink)
    }
    .padding(.horizontal, 10)
    .frame(height: 26)
    .background(GainsColor.card.opacity(0.95))
    .clipShape(Capsule())
  }

  private var startSummaryLine: String {
    var parts: [String] = []
    if let run = store.latestCompletedRun {
      parts.append("Zuletzt: \(String(format: "%.1f", run.distanceKm)) km · \(run.routeName)")
    }
    let pace = store.averageRunPaceSeconds
    if pace > 0 {
      parts.append("Ø \(runPaceLabel(pace))")
    }
    return parts.isEmpty ? "Tippe auf Start für deinen ersten Lauf." : parts.joined(separator: "  ·  ")
  }

  private func liveScreen(_ run: ActiveRunSession) -> some View {
    VStack(spacing: 0) {
      VStack(spacing: 14) {
        liveStatusRow(run)

        Text(formattedRunTime)
          .font(.system(size: 56, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(GainsColor.ink)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 24)
      .padding(.top, 8)
      .padding(.bottom, 18)

      routeSection

      VStack(spacing: 16) {
        liveMetricsRow(run)
        liveControls(run)

        if !displayedSplits(for: run).isEmpty {
          splitsStrip(run)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 18)
      .background(GainsColor.card)
    }
  }

  private func liveStatusRow(_ run: ActiveRunSession) -> some View {
    HStack(spacing: 8) {
      Circle()
        .fill(run.isPaused ? GainsColor.softInk : GainsColor.lime)
        .frame(width: 8, height: 8)

      Text(run.isPaused ? "PAUSIERT" : (gpsTracker.isUsingGPS ? "GPS LIVE" : "LIVE"))
        .font(GainsFont.label(11))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)

      Spacer()
    }
  }

  private var routeSection: some View {
    Map(position: .constant(gpsTracker.cameraPosition)) {
      if !displayedRouteCoordinates.isEmpty {
        MapPolyline(coordinates: displayedRouteCoordinates)
          .stroke(GainsColor.lime, lineWidth: 5)
      }

      if let currentCoordinate = displayedRouteCoordinates.last ?? gpsTracker.currentCoordinate {
        Annotation("Aktuell", coordinate: currentCoordinate) {
          currentLocationMarker
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func liveMetricsRow(_ run: ActiveRunSession) -> some View {
    HStack(spacing: 0) {
      liveMetric(
        title: "DISTANZ",
        value: String(format: "%.2f", displayedDistance(for: run)),
        unit: "km"
      )
      metricSeparator
      liveMetric(
        title: "PACE",
        value: paceCompact(displayedPace(for: run)),
        unit: "/km"
      )
      metricSeparator
      liveMetric(
        title: "HF",
        value: run.currentHeartRate > 0 ? "\(run.currentHeartRate)" : "–",
        unit: "bpm"
      )
      metricSeparator
      liveMetric(
        title: "ELEV",
        value: "+\(displayedElevation)",
        unit: "m"
      )
    }
  }

  private var metricSeparator: some View {
    Rectangle()
      .fill(GainsColor.border.opacity(0.3))
      .frame(width: 1, height: 28)
  }

  private func liveMetric(title: String, value: String, unit: String) -> some View {
    VStack(spacing: 6) {
      Text(title)
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 20, weight: .semibold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.6)

        Text(unit)
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func liveControls(_ run: ActiveRunSession) -> some View {
    HStack(spacing: 10) {
      Button {
        togglePause(run)
      } label: {
        Text(run.isPaused ? "Fortsetzen" : "Pause")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(GainsColor.ink)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)

      Button {
        finishRunAndDismiss()
      } label: {
        Text("Stopp")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(GainsColor.onLime)
          .frame(maxWidth: .infinity)
          .frame(height: 50)
          .background(GainsColor.lime)
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  private func splitsStrip(_ run: ActiveRunSession) -> some View {
    let splits = displayedSplits(for: run).suffix(3)

    return VStack(alignment: .leading, spacing: 8) {
      Text("LETZTE SPLITS")
        .font(GainsFont.label(10))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: 8) {
        ForEach(Array(splits), id: \.id) { split in
          VStack(alignment: .leading, spacing: 2) {
            Text("KM \(split.index)")
              .font(GainsFont.label(9))
              .tracking(1.4)
              .foregroundStyle(GainsColor.softInk)

            Text(paceCompact(split.paceSeconds))
              .font(.system(size: 16, weight: .semibold, design: .rounded))
              .foregroundStyle(GainsColor.ink)

            Text("\(split.averageHeartRate) bpm")
              .font(GainsFont.body(11))
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(GainsColor.background.opacity(0.9))
          .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
      }
    }
  }

  private func paceCompact(_ seconds: Int) -> String {
    guard seconds > 0 else { return "–" }
    let minutes = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", minutes, s)
  }

  private var formattedRunTime: String {
    let totalSeconds = displayedDurationSeconds
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
  }

  private var displayedElevation: Int {
    gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback
      ? gpsTracker.elevationGain
      : (store.activeRun?.elevationGain ?? 0)
  }

  private var displayedDurationSeconds: Int {
    if gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback {
      return gpsTracker.elapsedSeconds
    }

    return (store.activeRun?.durationMinutes ?? 0) * 60
  }

  private func displayedDistance(for run: ActiveRunSession) -> Double {
    gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback
      ? gpsTracker.trackedDistanceKm : run.distanceKm
  }

  private func displayedPace(for run: ActiveRunSession) -> Int {
    let distance = displayedDistance(for: run)
    guard distance > 0 else { return 0 }
    return Int(Double(displayedDurationSeconds) / distance)
  }

  private func displayedSplits(for run: ActiveRunSession) -> [RunSplit] {
    gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback ? gpsTracker.splits : run.splits
  }

  private var displayedRouteCoordinates: [CLLocationCoordinate2D] {
    if gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback {
      return gpsTracker.routeCoordinates
    }

    return store.activeRun?.routeCoordinates ?? []
  }

  private func startRunNow() {
    if store.activeRun == nil {
      store.startQuickRun()
    }
    gpsTracker.requestAuthorization()
    synchronizeTrackerState()
  }

  private func synchronizeTrackerState() {
    guard let run = store.activeRun else {
      stopTracking()
      return
    }

    guard !run.isPaused else { return }

    if gpsTracker.canStartTracking {
      gpsTracker.beginTracking(from: run)
    } else if gpsTracker.canRequestPermission {
      gpsTracker.requestAuthorization()
    } else {
      gpsTracker.beginFallbackTracking(from: run)
    }
  }

  private func syncStoreWithTracker() {
    guard gpsTracker.isUsingGPS || gpsTracker.isTrackingFallback else { return }
    store.syncActiveRunGPS(
      distanceKm: gpsTracker.trackedDistanceKm,
      durationMinutes: gpsTracker.durationMinutes,
      elevationGain: gpsTracker.elevationGain,
      routeCoordinates: gpsTracker.routeCoordinates,
      splits: gpsTracker.splits
    )
  }

  private func togglePause(_ run: ActiveRunSession) {
    store.toggleRunPause()
    if run.isPaused {
      gpsTracker.resumeTracking()
    } else {
      gpsTracker.pauseTracking()
    }
  }

  private func stopTracking() {
    gpsTracker.stopTracking()
  }

  private func finishRunAndDismiss() {
    if store.activeRun != nil {
      syncStoreWithTracker()
    }
    stopTracking()
    store.finishRun()
    dismiss()
  }

  private func runPaceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:-- /km" }
    let minutes = seconds / 60
    let seconds = seconds % 60
    return String(format: "%d:%02d /km", minutes, seconds)
  }
}

final class RunLocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
  @Published var authorizationStatus: CLAuthorizationStatus
  @Published var routeCoordinates: [CLLocationCoordinate2D] = []
  @Published var trackedDistanceKm: Double = 0
  @Published var elevationGain: Int = 0
  @Published var durationMinutes: Int = 0
  @Published var elapsedSeconds: Int = 0
  @Published var splits: [RunSplit] = []
  @Published var isUsingGPS = false
  @Published var isTrackingFallback = false

  /// Wird vom View aus HealthKit befüllt und für Split-Durchschnitte genutzt.
  var currentHeartRate: Int = 0

  private let manager = CLLocationManager()
  private var lastLocation: CLLocation?
  private var timer: Timer?
  private var startReferenceDate: Date?
  private var pauseDate: Date?
  private var pausedDuration: TimeInterval = 0
  private var splitAnchorDistance: Double = 0
  private var splitAnchorDuration: Int = 0
  private var fallbackPaceSeconds = 381

  override init() {
    authorizationStatus = manager.authorizationStatus
    super.init()
    manager.delegate = self
    manager.activityType = .fitness
    manager.desiredAccuracy = kCLLocationAccuracyBest
    manager.distanceFilter = 5
    manager.allowsBackgroundLocationUpdates = false
    manager.pausesLocationUpdatesAutomatically = false
    manager.startUpdatingLocation()
  }

  var canRequestPermission: Bool {
    authorizationStatus == .notDetermined
  }

  var canStartTracking: Bool {
    authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
  }

  var currentCoordinate: CLLocationCoordinate2D? {
    manager.location?.coordinate
  }

  var cameraPosition: MapCameraPosition {
    if let last = routeCoordinates.last {
      return .region(
        MKCoordinateRegion(
          center: last,
          span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
      )
    }

    if let coordinate = currentCoordinate {
      return .region(
        MKCoordinateRegion(
          center: coordinate,
          span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
      )
    }

    return .region(
      MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
      )
    )
  }

  func requestAuthorization() {
    manager.requestWhenInUseAuthorization()
  }

  func beginTracking(from run: ActiveRunSession) {
    guard canStartTracking else { return }
    guard !isUsingGPS else { return }

    prepareTrackingState(from: run)
    isUsingGPS = true
    isTrackingFallback = false
    manager.startUpdatingLocation()
    startTimer()
  }

  func beginFallbackTracking(from run: ActiveRunSession) {
    guard !isUsingGPS else { return }
    guard !isTrackingFallback else { return }

    prepareTrackingState(from: run)
    isTrackingFallback = true
    fallbackPaceSeconds = max(run.averagePaceSeconds, 330)
    startTimer()
  }

  func pauseTracking() {
    guard isUsingGPS || isTrackingFallback else { return }
    pauseDate = Date()
    manager.stopUpdatingLocation()
    stopTimer()
  }

  func resumeTracking() {
    guard isUsingGPS || isTrackingFallback else { return }

    if let pauseDate {
      pausedDuration += Date().timeIntervalSince(pauseDate)
      self.pauseDate = nil
    }

    if isUsingGPS {
      manager.startUpdatingLocation()
    }

    startTimer()
  }

  func stopTracking() {
    isUsingGPS = false
    isTrackingFallback = false
    manager.stopUpdatingLocation()
    stopTimer()
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    authorizationStatus = manager.authorizationStatus
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    for location in locations where location.horizontalAccuracy > 0 {
      updateDuration()

      if let lastLocation {
        let delta = location.distance(from: lastLocation)
        if delta >= 3, delta <= 250 {
          trackedDistanceKm += delta / 1000

          let elevationDelta = location.altitude - lastLocation.altitude
          if elevationDelta > 0 {
            elevationGain += Int(elevationDelta.rounded())
          }
        }
      }

      lastLocation = location
      routeCoordinates.append(location.coordinate)
      generateAutomaticSplits(currentHeartRate: currentHeartRate > 0 ? currentHeartRate : 140)
    }
  }

  private func prepareTrackingState(from run: ActiveRunSession) {
    trackedDistanceKm = run.distanceKm
    elevationGain = run.elevationGain
    durationMinutes = run.durationMinutes
    elapsedSeconds = run.durationMinutes * 60
    routeCoordinates = run.routeCoordinates
    splits = run.splits
    splitAnchorDistance = run.distanceKm
    splitAnchorDuration = run.durationMinutes
    lastLocation = nil
    pausedDuration = 0
    pauseDate = nil
    startReferenceDate = Date().addingTimeInterval(-TimeInterval(run.durationMinutes * 60))
  }

  private func startTimer() {
    guard timer == nil else { return }

    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      self?.updateDuration()
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  private func updateDuration() {
    guard let startReferenceDate else { return }
    let effectiveElapsed = Date().timeIntervalSince(startReferenceDate) - pausedDuration
    elapsedSeconds = max(Int(effectiveElapsed), elapsedSeconds)
    durationMinutes = max(Int(effectiveElapsed / 60), durationMinutes)

    if isTrackingFallback {
      trackedDistanceKm = max(
        trackedDistanceKm, Double(elapsedSeconds) / Double(fallbackPaceSeconds))
      generateAutomaticSplits(currentHeartRate: currentHeartRate > 0 ? currentHeartRate : 140)
    }
  }

  private func generateAutomaticSplits(currentHeartRate: Int) {
    while trackedDistanceKm - splitAnchorDistance >= 1.0 {
      let splitDuration = max(durationMinutes - splitAnchorDuration, 1)

      splits.append(
        RunSplit(
          id: UUID(),
          index: splits.count + 1,
          distanceKm: 1.0,
          durationMinutes: splitDuration,
          averageHeartRate: currentHeartRate
        )
      )

      splitAnchorDistance += 1.0
      splitAnchorDuration = durationMinutes
    }
  }
}
