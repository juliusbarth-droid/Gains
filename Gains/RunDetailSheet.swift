import CoreLocation
import MapKit
import SwiftUI

// MARK: - RunDetailSheet
// Strava-style post-run summary sheet opened by tapping an activity card.

struct RunDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  let run: CompletedRunSummary
  let onRunAgain: () -> Void

  @State private var showsSaveRouteAlert = false
  @State private var routeNameDraft: String = ""
  @State private var savedRouteFlash: Bool = false

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 0) {
          mapSection
          statsBlock
          // Route-Aktionen: speichern als wiederverwendbare Route.
          if !run.routeCoordinates.isEmpty {
            routeActionsBlock
              .padding(.horizontal, 20)
              .padding(.bottom, 20)
          }
          if !run.note.isEmpty || run.feel != nil || run.intensity != .free {
            feelAndNoteSection
          }
          if !run.splits.isEmpty {
            splitsSection
            paceChartSection
          }
          if run.hrZoneSecondsBuckets.contains(where: { $0 > 0 }) {
            hrZonesSection
          }
          achievementsSection
        }
      }
      .background(GainsColor.background.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button {
            onRunAgain()
          } label: {
            HStack(spacing: 5) {
              Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .semibold))
              Text("Erneut")
                .font(GainsFont.label(10))
                .tracking(1.0)
            }
            .foregroundStyle(GainsColor.onLime)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(GainsColor.lime)
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
      .alert("Route speichern", isPresented: $showsSaveRouteAlert) {
        TextField("Routenname", text: $routeNameDraft)
        Button("Speichern") {
          let title = routeNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
          let final = title.isEmpty ? run.routeName : title
          if store.saveRoute(from: run, title: final) != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
              savedRouteFlash = true
            }
          }
        }
        Button("Abbrechen", role: .cancel) {}
      } message: {
        Text("Du findest die Route danach im Tab „Routen“ – inkl. Heatmap und Verlinkung zu deinen Läufen.")
      }
    }
  }

  // MARK: - Route-Actions

  private var routeActionsBlock: some View {
    VStack(alignment: .leading, spacing: 10) {
      sectionHeader("ROUTE")

      Button {
        if savedRouteFlash {
          // Schon gespeichert — kein zweiter Save.
          return
        }
        routeNameDraft = run.routeName.isEmpty ? run.title : run.routeName
        showsSaveRouteAlert = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: savedRouteFlash ? "checkmark.circle.fill" : "map.fill")
            .font(.system(size: 14, weight: .semibold))
          Text(savedRouteFlash ? "Route gespeichert" : "Route speichern")
            .font(GainsFont.label(11))
            .tracking(1.2)
          Spacer()
          if !savedRouteFlash {
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(GainsColor.softInk)
          }
        }
        .foregroundStyle(savedRouteFlash ? GainsColor.moss : GainsColor.ink)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(savedRouteFlash ? GainsColor.lime.opacity(0.18) : GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Map

  private var mapSection: some View {
    ZStack(alignment: .bottomLeading) {
      if run.routeCoordinates.isEmpty {
        // Kein Route-Track aufgezeichnet — wir zeigen einen dezenten
        // Design-System-Platzhalter statt einer fest auf München zentrierten
        // Map (vermeidet sowohl die hartcodierten Koordinaten als auch das
        // unnötige Laden von Map-Tiles, die ohnehin überlagert werden).
        ZStack {
          GainsColor.elevated
          VStack(spacing: 8) {
            Image(systemName: "map")
              .font(.system(size: 26, weight: .semibold))
              .foregroundStyle(GainsColor.softInk)
            Text("Route nicht aufgezeichnet")
              .font(GainsFont.label(10))
              .tracking(1.2)
              .foregroundStyle(GainsColor.softInk)
          }
        }
        .frame(height: 240)
      } else {
        Map(position: .constant(.region(regionForRoute(run.routeCoordinates)))) {
          MapPolyline(coordinates: run.routeCoordinates)
            .stroke(GainsColor.lime, lineWidth: 5)
          if let start = run.routeCoordinates.first {
            Annotation("", coordinate: start) {
              Circle()
                .fill(Color.white)
                .frame(width: 12, height: 12)
                .overlay(Circle().stroke(GainsColor.lime, lineWidth: 3))
            }
          }
          if let end = run.routeCoordinates.last {
            Annotation("", coordinate: end) {
              Circle()
                .fill(GainsColor.lime)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
            }
          }
        }
        .frame(height: 240)
      }

      // Overlay: run title + date
      VStack(alignment: .leading, spacing: 2) {
        Text(run.finishedAt.formatted(date: .complete, time: .omitted))
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(.white.opacity(0.75))
        Text(run.title)
          .font(GainsFont.title(22))
          .foregroundStyle(.white)
      }
      .padding(16)
      .background(
        LinearGradient(
          colors: [Color.black.opacity(0.6), Color.clear],
          startPoint: .bottom,
          endPoint: .top
        )
      )
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Stats block

  private var statsBlock: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(run.routeName)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.moss)

      // Primary: distance huge
      HStack(alignment: .lastTextBaseline, spacing: 6) {
        Text(String(format: "%.2f", run.distanceKm))
          .font(.system(size: 56, weight: .black, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        Text("km")
          .font(GainsFont.title(20))
          .foregroundStyle(GainsColor.softInk)
          .padding(.bottom, 6)
      }

      // Secondary stats: 2×2 grid
      VStack(spacing: 1) {
        HStack(spacing: 1) {
          detailStatCell(label: "PACE", value: paceLabel(run.averagePaceSeconds), unit: "/km")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(GainsColor.card)
          detailStatCell(label: "DAUER", value: formattedDuration(run.durationMinutes), unit: "")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(GainsColor.card)
        }
        HStack(spacing: 1) {
          detailStatCell(label: "HÖHENMETER", value: "+\(run.elevationGain)", unit: "m")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(GainsColor.card)
          detailStatCell(label: "HF Ø", value: run.averageHeartRate > 0 ? "\(run.averageHeartRate)" : "–", unit: run.averageHeartRate > 0 ? "bpm" : "")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(GainsColor.card)
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(GainsColor.border.opacity(0.25), lineWidth: 1)
      )
    }
    .padding(20)
  }

  // MARK: - Splits

  private var splitsSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionHeader("KILOMETER-SPLITS")

      VStack(spacing: 0) {
        // Table header
        HStack {
          Text("KM").frame(width: 36, alignment: .leading)
          Spacer()
          Text("PACE").frame(width: 80, alignment: .trailing)
          Text("DAUER").frame(width: 64, alignment: .trailing)
          Text("HF").frame(width: 48, alignment: .trailing)
        }
        .font(GainsFont.label(8))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GainsColor.background)

        let fastestPace = run.splits.map(\.paceSeconds).filter { $0 > 0 }.min() ?? 0

        ForEach(Array(run.splits.enumerated()), id: \.element.id) { idx, split in
          let isFastest = split.paceSeconds == fastestPace && fastestPace > 0

          HStack {
            Text("\(split.index)")
              .font(.system(size: 15, weight: .bold, design: .rounded))
              .foregroundStyle(isFastest ? GainsColor.lime : GainsColor.ink)
              .frame(width: 36, alignment: .leading)

            // Inline pace bar
            GeometryReader { geo in
              let allPaces = run.splits.map(\.paceSeconds).filter { $0 > 0 }
              let maxPace = allPaces.max() ?? 1
              let minPace = allPaces.min() ?? 1
              let range = max(Double(maxPace - minPace), 1)
              let fraction = split.paceSeconds > 0
                ? 1.0 - (Double(split.paceSeconds - minPace) / range) * 0.7
                : 0.15
              HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                  .fill(isFastest ? GainsColor.lime : GainsColor.lime.opacity(0.35 + fraction * 0.45))
                  .frame(width: geo.size.width * fraction, height: 6)
                Spacer(minLength: 0)
              }
            }
            .frame(height: 6)

            Text(paceLabel(split.paceSeconds))
              .font(.system(size: 14, weight: .semibold, design: .rounded))
              .foregroundStyle(isFastest ? GainsColor.moss : GainsColor.ink)
              .frame(width: 80, alignment: .trailing)

            Text(formattedDuration(split.durationMinutes))
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.softInk)
              .frame(width: 64, alignment: .trailing)

            Text("\(split.averageHeartRate)")
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.softInk)
              .frame(width: 48, alignment: .trailing)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
          .background(idx % 2 == 0 ? GainsColor.card : GainsColor.elevated.opacity(0.5))
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
      )
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 20)
  }

  // MARK: - Pace Chart

  private var paceChartSection: some View {
    guard !run.splits.isEmpty else { return AnyView(EmptyView()) }
    let splits = run.splits
    let paces = splits.map(\.paceSeconds).filter { $0 > 0 }
    let minPace = paces.min() ?? 1
    let maxPace = max(paces.max() ?? 1, minPace + 10)

    return AnyView(
      VStack(alignment: .leading, spacing: 14) {
        sectionHeader("PACE-VERLAUF")

        VStack(spacing: 10) {
          // Chart
          HStack(alignment: .bottom, spacing: 4) {
            ForEach(splits, id: \.id) { split in
              let pace = split.paceSeconds
              let fraction: Double = pace > 0
                ? 1.0 - (Double(pace - minPace) / Double(maxPace - minPace)) * 0.75
                : 0.1
              let isFastest = pace == minPace && pace > 0

              VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                  .fill(isFastest ? GainsColor.lime : GainsColor.lime.opacity(0.4 + fraction * 0.45))
                  .frame(height: max(fraction * 80, 8))

                Text("\(split.index)")
                  .font(GainsFont.label(8))
                  .foregroundStyle(GainsColor.softInk)
              }
              .frame(maxWidth: .infinity)
            }
          }
          .frame(height: 96, alignment: .bottom)

          HStack {
            Label(paceLabel(minPace), systemImage: "bolt.fill")
              .font(GainsFont.label(9))
              .foregroundStyle(GainsColor.lime)
              .tracking(0.8)
            Spacer()
            Label(paceLabel(maxPace), systemImage: "tortoise.fill")
              .font(GainsFont.label(9))
              .foregroundStyle(GainsColor.softInk)
              .tracking(0.8)
          }
        }
        .padding(16)
        .background(GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 20)
    )
  }

  // MARK: - Feel & Note

  private var feelAndNoteSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionHeader("EINORDNUNG")

      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 10) {
          if run.intensity != .free {
            metaChip(symbol: run.intensity.systemImage, label: run.intensity.title)
          }
          if let feel = run.feel {
            metaChip(symbol: feel.emojiSymbol, label: feel.title)
          }
          Spacer(minLength: 0)
        }

        if !run.note.isEmpty {
          Text(run.note)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .padding(14)
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 20)
  }

  private func metaChip(symbol: String, label: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
      Text(label)
        .font(GainsFont.label(10))
        .tracking(1.2)
        .foregroundStyle(GainsColor.ink)
    }
    .padding(.horizontal, 10)
    .frame(height: 28)
    .background(GainsColor.background.opacity(0.6))
    .clipShape(Capsule())
  }

  // MARK: - HR-Zonen-Verteilung

  private var hrZonesSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      sectionHeader("HF-ZONEN")

      VStack(alignment: .leading, spacing: 10) {
        // Stacked Bar
        GeometryReader { geo in
          HStack(spacing: 1) {
            ForEach(Array(HRZone.allCases.enumerated()), id: \.element) { idx, zone in
              let fraction = run.hrZoneFractions[safe: idx] ?? 0
              Rectangle()
                .fill(zone.color())
                .frame(width: max(geo.size.width * fraction, fraction > 0 ? 4 : 0), height: 12)
            }
          }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

        // Legende
        VStack(spacing: 6) {
          ForEach(Array(HRZone.allCases.enumerated()), id: \.element) { idx, zone in
            let secs = run.hrZoneSecondsBuckets[safe: idx] ?? 0
            HStack(spacing: 8) {
              Circle().fill(zone.color()).frame(width: 8, height: 8)
              Text(zone.title)
                .font(GainsFont.body(12))
                .foregroundStyle(GainsColor.ink)
              Spacer()
              Text(formatZoneDuration(secs))
                .font(GainsFont.body(12))
                .foregroundStyle(GainsColor.softInk)
                .monospacedDigit()
            }
          }
        }
      }
      .padding(14)
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 20)
  }

  private func formatZoneDuration(_ seconds: Int) -> String {
    guard seconds > 0 else { return "—" }
    let m = seconds / 60
    let s = seconds % 60
    if m == 0 { return "\(s)s" }
    return String(format: "%d:%02d", m, s)
  }

  // MARK: - Achievements

  private var achievementsSection: some View {
    let prs = personalBests()
    guard !prs.isEmpty else { return AnyView(EmptyView()) }

    return AnyView(
      VStack(alignment: .leading, spacing: 14) {
        sectionHeader("BESTLEISTUNGEN")

        HStack(spacing: 10) {
          ForEach(prs, id: \.0) { (label, value) in
            VStack(alignment: .leading, spacing: 6) {
              HStack(spacing: 4) {
                Image(systemName: "trophy.fill")
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundStyle(GainsColor.lime)
                Text(label)
                  .font(GainsFont.label(8))
                  .tracking(1.2)
                  .foregroundStyle(GainsColor.softInk)
              }
              Text(value)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(GainsColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
    )
  }

  // MARK: - Helpers

  private func sectionHeader(_ text: String) -> some View {
    Text(text)
      .font(GainsFont.label(10))
      .tracking(2.0)
      .foregroundStyle(GainsColor.softInk)
  }

  private func detailStatCell(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.label(7))
        .tracking(1.2)
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 17, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        if !unit.isEmpty {
          Text(unit)
            .font(GainsFont.body(10))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:--" }
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
  }

  private func formattedDuration(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    return h > 0 ? "\(h)h \(String(format: "%02d", m))m" : "\(m) min"
  }

  private func regionForRoute(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
    // Defensiver Fallback: ein generisches Welt-Fenster statt einer hartcodierten
    // Stadtmitte — falls die Funktion (entgegen dem aktuellen Aufrufpfad) doch
    // einmal mit einer leeren Coordinate-Liste aufgerufen wird.
    let lats = coordinates.map(\.latitude)
    let lons = coordinates.map(\.longitude)
    guard
      let minLat = lats.min(),
      let maxLat = lats.max(),
      let minLon = lons.min(),
      let maxLon = lons.max()
    else {
      return MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
      )
    }
    let center = CLLocationCoordinate2D(
      latitude: (minLat + maxLat) / 2,
      longitude: (minLon + maxLon) / 2
    )
    let span = MKCoordinateSpan(
      latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
      longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
    )
    return MKCoordinateRegion(center: center, span: span)
  }

  private func personalBests() -> [(String, String)] {
    var prs: [(String, String)] = []

    // Vergleichsbasis: alle bisherigen Läufe AUSSER diesem.
    let history = store.runHistory.filter { $0.id != run.id }

    // Längster Lauf?
    if run.distanceKm > 0 {
      let prevLongest = history.map(\.distanceKm).max() ?? 0
      if run.distanceKm >= prevLongest, !history.isEmpty {
        prs.append(("LÄNGSTER LAUF", String(format: "%.2f km", run.distanceKm)))
      } else if history.isEmpty, run.distanceKm >= 5 {
        prs.append(("LÄNGSTER LAUF", String(format: "%.2f km", run.distanceKm)))
      }
    }

    // Schnellste Pace ≥ 5 km — vergleicht nur mit Läufen ≥ 5 km
    if run.distanceKm >= 5, run.averagePaceSeconds > 0 {
      let prevBestPace5K = history
        .filter { $0.distanceKm >= 5 }
        .map(\.averagePaceSeconds)
        .filter { $0 > 0 }
        .min() ?? Int.max
      if run.averagePaceSeconds <= prevBestPace5K {
        prs.append(("BESTE PACE 5K+", paceLabel(run.averagePaceSeconds) + " /km"))
      }
    }

    // Höhenmeter-Bestwert
    if run.elevationGain > 100 {
      let prevBestElev = history.map(\.elevationGain).max() ?? 0
      if run.elevationGain >= prevBestElev {
        prs.append(("HÖHEN-PR", "\(run.elevationGain) m"))
      }
    }

    return prs
  }
}

// MARK: - Safe Array Subscript

private extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
