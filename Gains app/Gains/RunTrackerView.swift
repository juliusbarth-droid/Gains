import CoreLocation
import MapKit
import SwiftUI

struct RunTrackerView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  @StateObject private var gpsTracker = RunLocationTracker()

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        if let run = store.activeRun {
          VStack(spacing: 0) {
            liveHeader(run)
            routeSection
            bottomDashboard(run)
          }
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

        ToolbarItem(placement: .topBarTrailing) {
          if store.activeRun != nil {
            Button("Beenden") {
              finishRunAndDismiss()
            }
            .foregroundStyle(GainsColor.lime)
            .fontWeight(.semibold)
          }
        }
      }
    }
    .onAppear {
      if store.activeRun != nil {
        gpsTracker.requestAuthorization()
        synchronizeTrackerState()
      }
    }
    .onReceive(gpsTracker.$trackedDistanceKm) { _ in syncStoreWithTracker() }
    .onReceive(gpsTracker.$durationMinutes) { _ in syncStoreWithTracker() }
    .onReceive(gpsTracker.$elevationGain) { _ in syncStoreWithTracker() }
    .onReceive(gpsTracker.$splits) { _ in syncStoreWithTracker() }
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
      VStack(alignment: .leading, spacing: 18) {
        SlashLabel(
          parts: ["RUNNING", "BEREIT"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        Text("Bereit für deinen Lauf")
          .font(GainsFont.title(34))
          .foregroundStyle(GainsColor.ink)

        Text(
          "Öffne deine Live-Map, Pace, Herzfrequenz und Distanz erst dann, wenn du wirklich starten willst."
        )
        .font(GainsFont.body(15))
        .foregroundStyle(GainsColor.softInk)

        HStack(spacing: 10) {
          previewMetric(title: "Letzter Lauf", value: previewRunTitle, subtitle: previewRunSubtitle)
          previewMetric(title: "Ø Pace", value: previewPaceValue, subtitle: "letzte 7 Tage")
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
      .padding(.bottom, 16)
      .background(
        LinearGradient(
          colors: [GainsColor.card, GainsColor.background],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )

      Map(position: .constant(gpsTracker.cameraPosition)) {
        if let coordinate = gpsTracker.currentCoordinate {
          Annotation("Aktuell", coordinate: coordinate) {
            Circle()
              .fill(GainsColor.lime)
              .frame(width: 16, height: 16)
              .overlay {
                Circle()
                  .stroke(GainsColor.ink, lineWidth: 3)
              }
          }
        }
      }
      .overlay(alignment: .topTrailing) {
        Text(gpsTracker.canStartTracking ? "Position bereit" : "Live-Map Vorschau")
          .font(GainsFont.label(9))
          .tracking(1.4)
          .foregroundStyle(GainsColor.ink)
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(GainsColor.card.opacity(0.92))
          .clipShape(Capsule())
          .padding(14)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      VStack(spacing: 12) {
        Button {
          startRunNow()
        } label: {
          Text("Lauf starten")
            .font(GainsFont.label(13))
            .tracking(1.8)
            .foregroundStyle(GainsColor.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)

        Text("Der Lauf startet erst nach deinem Tap hier.")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(18)
      .background(GainsColor.card)
    }
  }

  private func liveHeader(_ run: ActiveRunSession) -> some View {
    VStack(spacing: 18) {
      HStack {
        Text(gpsTracker.isUsingGPS ? "GPS LIVE" : "RUN LIVE")
          .font(GainsFont.label(10))
          .tracking(2)
          .foregroundStyle(GainsColor.ink.opacity(0.82))
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(GainsColor.lime.opacity(0.24))
          .clipShape(Capsule())

        Spacer()

        Text(run.isPaused ? "Pausiert" : "Aktiv")
          .font(GainsFont.label(10))
          .tracking(2)
          .foregroundStyle(GainsColor.ink.opacity(0.72))
      }

      Text(formattedRunTime)
        .font(.system(size: 44, weight: .black, design: .rounded))
        .foregroundStyle(GainsColor.ink)

      HStack(spacing: 18) {
        headerMetric(
          title: "Distanz", value: String(format: "%.2f km", displayedDistance(for: run)))
        headerMetric(title: "Pace", value: runPaceLabel(displayedPace(for: run)))
        headerMetric(title: "HF", value: "\(run.currentHeartRate)")
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 18)
    .padding(.bottom, 20)
    .background(
      LinearGradient(
        colors: [GainsColor.card, GainsColor.background],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }

  private func headerMetric(title: String, value: String) -> some View {
    VStack(spacing: 6) {
      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)

      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity)
  }

  private var routeSection: some View {
    Map(position: .constant(gpsTracker.cameraPosition)) {
      if !displayedRouteCoordinates.isEmpty {
        MapPolyline(coordinates: displayedRouteCoordinates)
          .stroke(GainsColor.lime, lineWidth: 5)
      }

      if let currentCoordinate = displayedRouteCoordinates.last ?? gpsTracker.currentCoordinate {
        Annotation("Aktuell", coordinate: currentCoordinate) {
          Circle()
            .fill(GainsColor.lime)
            .frame(width: 16, height: 16)
            .overlay {
              Circle()
                .stroke(GainsColor.ink, lineWidth: 3)
            }
        }
      }
    }
    .overlay(alignment: .topTrailing) {
      if !gpsTracker.isUsingGPS {
        Text(gpsTracker.canStartTracking ? "GPS läuft automatisch mit" : "Live-Modus aktiv")
          .font(GainsFont.label(9))
          .tracking(1.4)
          .foregroundStyle(GainsColor.ink)
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(GainsColor.card.opacity(0.92))
          .clipShape(Capsule())
          .padding(14)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func bottomDashboard(_ run: ActiveRunSession) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        bottomMetric(
          title: "DISTANZ", value: String(format: "%.2f", displayedDistance(for: run)), unit: "km")
        bottomMetric(title: "PACE", value: runPaceLabel(displayedPace(for: run)), unit: "")
        bottomMetric(title: "DAUER", value: formattedRunTime, unit: "")
      }
      .frame(height: 96)

      Divider()
        .overlay(GainsColor.border.opacity(0.45))

      HStack(spacing: 12) {
        dashboardButton(title: run.isPaused ? "FORTSETZEN" : "PAUSE") {
          togglePause(run)
        }

        dashboardButton(title: "STOPP", highlighted: true) {
          finishRunAndDismiss()
        }
      }
      .padding(.horizontal, 18)
      .padding(.top, 14)
      .padding(.bottom, 16)

      if !displayedSplits(for: run).isEmpty {
        splitsStrip(run)
          .padding(.horizontal, 18)
          .padding(.bottom, 14)
      }
    }
    .background(GainsColor.card)
  }

  private func bottomMetric(title: String, value: String, unit: String) -> some View {
    VStack(spacing: 8) {
      Text(title)
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 26, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.7)

        if !unit.isEmpty {
          Text(unit)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func dashboardButton(
    title: String, highlighted: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Text(title)
        .font(GainsFont.label(12))
        .tracking(1.8)
        .foregroundStyle(highlighted ? GainsColor.ink : GainsColor.card)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(highlighted ? GainsColor.lime : GainsColor.ink)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func splitsStrip(_ run: ActiveRunSession) -> some View {
    let splits = displayedSplits(for: run).suffix(3)

    return VStack(alignment: .leading, spacing: 10) {
      Text("LETZTE SPLITS")
        .font(GainsFont.label(10))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      HStack(spacing: 10) {
        ForEach(Array(splits), id: \.id) { split in
          VStack(alignment: .leading, spacing: 4) {
            Text("KM \(split.index)")
              .font(GainsFont.label(9))
              .tracking(1.6)
              .foregroundStyle(GainsColor.softInk)

            Text(runPaceLabel(split.paceSeconds))
              .font(GainsFont.title(16))
              .foregroundStyle(GainsColor.ink)

            Text("\(split.averageHeartRate) bpm")
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(GainsColor.background.opacity(0.9))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
      }
    }
  }

  private func previewMetric(title: String, value: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.title(18))
        .foregroundStyle(GainsColor.ink)

      Text(subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .gainsCardStyle()
  }

  private var previewRunTitle: String {
    store.latestCompletedRun?.title ?? "Noch kein Lauf"
  }

  private var previewRunSubtitle: String {
    if let run = store.latestCompletedRun {
      return "\(String(format: "%.1f", run.distanceKm)) km · \(run.routeName)"
    }
    return "Tippe auf Start für deinen ersten Lauf"
  }

  private var previewPaceValue: String {
    let pace = store.averageRunPaceSeconds
    return pace > 0 ? runPaceLabel(pace) : "--:-- /km"
  }

  private var formattedRunTime: String {
    let totalSeconds = displayedDurationSeconds
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
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
      generateAutomaticSplits(currentHeartRate: 140)
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
      generateAutomaticSplits(currentHeartRate: 140)
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
