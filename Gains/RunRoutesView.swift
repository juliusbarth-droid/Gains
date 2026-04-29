import CoreLocation
import MapKit
import SwiftUI

// MARK: - RunRoutesTab
//
// "Routen"-Tab im Lauf-Hub. Liefert:
//
//   • Hero: Heatmap aller bisher gelaufenen Strecken
//   • Empty-State, wenn keine Routen gespeichert
//   • Karten-Cards für gespeicherte Routen — klickbar → Detail-Sheet

struct RunRoutesTab: View {
  @EnvironmentObject private var store: GainsStore
  @Binding var presentedRoute: SavedRoute?

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      heatmapSection

      VStack(alignment: .leading, spacing: 10) {
        SlashLabel(
          parts: ["GESPEICHERTE", "ROUTEN"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Text("Routen aus deinen Läufen — wieder ablaufen oder analysieren.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      if store.savedRoutes.isEmpty {
        EmptyStateView(
          style: .card(icon: "map"),
          title: "Noch keine Routen",
          message: "Starte einen GPS-Lauf — du kannst die Strecke beim Speichern als Route übernehmen."
        )
      } else {
        VStack(spacing: 14) {
          ForEach(store.savedRoutes) { route in
            Button {
              presentedRoute = route
            } label: {
              routeCard(route)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öffnet Routendetails mit Karte und Analyse")
          }
        }
      }
    }
  }

  // MARK: Heatmap

  private var heatmapSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["HEATMAP", "DEINE WEGE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(store.routeHeatmapTiles.count) Punkte")
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }

      heatmapMap
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
        )
    }
  }

  @ViewBuilder
  private var heatmapMap: some View {
    let tiles = store.routeHeatmapTiles
    if tiles.isEmpty {
      // Empty-State direkt auf einer Karte.
      Map(position: .constant(.region(
        MKCoordinateRegion(
          center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
          span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
      )))
      .overlay(
        ZStack {
          Color.black.opacity(0.25)
          VStack(spacing: 6) {
            Image(systemName: "map")
              .font(.system(size: 22, weight: .semibold))
              .foregroundStyle(.white.opacity(0.8))
            Text("Heatmap baut sich aus deinen Läufen auf")
              .font(GainsFont.label(10))
              .tracking(1.0)
              .foregroundStyle(.white.opacity(0.85))
              .multilineTextAlignment(.center)
              .padding(.horizontal, 30)
          }
        }
      )
    } else {
      Map(position: .constant(.region(heatmapRegion(tiles)))) {
        ForEach(tiles) { tile in
          Annotation("", coordinate: tile.coordinate) {
            Circle()
              .fill(GainsColor.lime.opacity(0.18 + tile.intensity * 0.65))
              .frame(width: 12 + CGFloat(tile.intensity * 14),
                     height: 12 + CGFloat(tile.intensity * 14))
              .overlay(
                Circle()
                  .stroke(GainsColor.lime, lineWidth: tile.intensity > 0.7 ? 1.5 : 0.5)
              )
          }
        }
      }
      .mapStyle(.standard(elevation: .flat))
    }
  }

  private func heatmapRegion(_ tiles: [RouteHeatmapTile]) -> MKCoordinateRegion {
    let lats = tiles.map(\.coordinate.latitude)
    let lons = tiles.map(\.coordinate.longitude)
    guard let minLat = lats.min(), let maxLat = lats.max(),
          let minLon = lons.min(), let maxLon = lons.max() else {
      return MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
      )
    }
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
      ),
      span: MKCoordinateSpan(
        latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
        longitudeDelta: max((maxLon - minLon) * 1.4, 0.01)
      )
    )
  }

  // MARK: Route-Card

  private func routeCard(_ route: SavedRoute) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // Mini-Map oben.
      ZStack(alignment: .topLeading) {
        if route.coordinates.count > 1 {
          Map(position: .constant(.region(routeRegion(route)))) {
            MapPolyline(coordinates: route.coordinates)
              .stroke(GainsColor.lime, lineWidth: 4)
            if let start = route.coordinates.first {
              Annotation("", coordinate: start) {
                Circle().fill(.white).frame(width: 10, height: 10)
                  .overlay(Circle().stroke(GainsColor.lime, lineWidth: 2))
              }
            }
            if let end = route.coordinates.last {
              Annotation("", coordinate: end) {
                Circle().fill(GainsColor.lime).frame(width: 12, height: 12)
                  .overlay(Circle().stroke(.white, lineWidth: 2))
              }
            }
          }
          .frame(height: 130)
          .disabled(true)
        } else {
          Color(.tertiarySystemBackground).frame(height: 130)
        }

        HStack(spacing: 6) {
          Image(systemName: route.surface.systemImage)
            .font(.system(size: 10, weight: .semibold))
          Text(route.surface.title.uppercased())
            .font(GainsFont.label(9))
            .tracking(1.2)
        }
        .foregroundStyle(GainsColor.onLime)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(GainsColor.lime)
        .clipShape(Capsule())
        .padding(10)
      }

      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text(route.title)
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            Text(route.createdAt.formatted(date: .abbreviated, time: .omitted))
              .font(GainsFont.label(9))
              .tracking(1.0)
              .foregroundStyle(GainsColor.softInk)
          }
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(GainsColor.softInk.opacity(0.5))
        }

        HStack(spacing: 0) {
          routeStat(label: "DISTANZ", value: String(format: "%.2f", route.distanceKm), unit: "km")
          Rectangle()
            .fill(GainsColor.border.opacity(0.4))
            .frame(width: 1, height: 28)
          routeStat(label: "HÖHE", value: "+\(route.elevationGain)", unit: "m")
          Rectangle()
            .fill(GainsColor.border.opacity(0.4))
            .frame(width: 1, height: 28)
          routeStat(label: "GELAUFEN", value: "\(route.timesRun)", unit: "×")
        }
      }
      .padding(14)
    }
    .gainsCardStyle()
    .overlay(
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
  }

  private func routeStat(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 16, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        Text(unit)
          .font(GainsFont.body(10))
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func routeRegion(_ route: SavedRoute) -> MKCoordinateRegion {
    guard !route.coordinates.isEmpty else {
      return MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
      )
    }
    let lats = route.coordinates.map(\.latitude)
    let lons = route.coordinates.map(\.longitude)
    let minLat = lats.min()!
    let maxLat = lats.max()!
    let minLon = lons.min()!
    let maxLon = lons.max()!
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
      ),
      span: MKCoordinateSpan(
        latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
        longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
      )
    )
  }
}

// MARK: - SavedRouteDetailSheet

struct SavedRouteDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  let route: SavedRoute

  @State private var editingTitle: Bool = false
  @State private var draftTitle: String = ""
  @State private var isConfirmingDelete = false

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(spacing: 0) {
          mapHeader

          VStack(alignment: .leading, spacing: 18) {
            statsBlock

            VStack(alignment: .leading, spacing: 10) {
              SlashLabel(
                parts: ["VERWANDTE", "LÄUFE"],
                primaryColor: GainsColor.lime,
                secondaryColor: GainsColor.softInk
              )
              Text("Läufe, deren Start- und Endpunkt zur Route passen.")
                .font(GainsFont.body(12))
                .foregroundStyle(GainsColor.softInk)
            }

            relatedRunsList
          }
          .padding(20)
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
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button {
              draftTitle = route.title
              editingTitle = true
            } label: {
              Label("Umbenennen", systemImage: "pencil")
            }
            Button(role: .destructive) {
              isConfirmingDelete = true
            } label: {
              Label("Löschen", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
        }
      }
      .alert("Route umbenennen", isPresented: $editingTitle) {
        TextField("Name", text: $draftTitle)
        Button("Speichern") { store.renameRoute(route.id, to: draftTitle) }
        Button("Abbrechen", role: .cancel) {}
      }
      .confirmationDialog(
        "Route löschen?",
        isPresented: $isConfirmingDelete,
        titleVisibility: .visible
      ) {
        Button("Löschen", role: .destructive) {
          store.deleteRoute(route.id)
          dismiss()
        }
        Button("Abbrechen", role: .cancel) {}
      } message: {
        Text("Die Route wird unwiderruflich entfernt. Deine Lauf-Historie bleibt erhalten.")
      }
    }
  }

  private var mapHeader: some View {
    Group {
      if route.coordinates.count > 1 {
        Map(position: .constant(.region(routeRegion))) {
          MapPolyline(coordinates: route.coordinates)
            .stroke(GainsColor.lime, lineWidth: 5)
          if let start = route.coordinates.first {
            Annotation("", coordinate: start) {
              Circle().fill(.white).frame(width: 12, height: 12)
                .overlay(Circle().stroke(GainsColor.lime, lineWidth: 3))
            }
          }
          if let end = route.coordinates.last {
            Annotation("", coordinate: end) {
              Circle().fill(GainsColor.lime).frame(width: 14, height: 14)
                .overlay(Circle().stroke(.white, lineWidth: 2))
            }
          }
        }
        .frame(height: 260)
      } else {
        Color(.tertiarySystemBackground).frame(height: 260)
      }
    }
  }

  private var statsBlock: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(route.title)
        .font(GainsFont.title(26))
        .foregroundStyle(GainsColor.ink)
      if !route.note.isEmpty {
        Text(route.note)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(spacing: 0) {
        sheetStat(label: "DISTANZ", value: String(format: "%.2f", route.distanceKm), unit: "km")
        Rectangle()
          .fill(GainsColor.border.opacity(0.4))
          .frame(width: 1, height: 36)
        sheetStat(label: "HÖHE", value: "+\(route.elevationGain)", unit: "m")
        Rectangle()
          .fill(GainsColor.border.opacity(0.4))
          .frame(width: 1, height: 36)
        sheetStat(label: "GELAUFEN", value: "\(route.timesRun)", unit: "×")
      }
      .padding(.vertical, 14)
      .padding(.horizontal, 12)
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
  }

  private func sheetStat(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 18, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        Text(unit)
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var relatedRunsList: some View {
    let related = store.runHistory.filter { run in
      guard let runStart = run.routeCoordinates.first,
            let runEnd = run.routeCoordinates.last,
            let start = route.coordinates.first,
            let end = route.coordinates.last else { return false }
      return RunGeoMath.distanceMeters(runStart, start) < SavedRoute.matchToleranceMeters
        && RunGeoMath.distanceMeters(runEnd, end) < SavedRoute.matchToleranceMeters
    }

    return Group {
      if related.isEmpty {
        Text("Sobald du diese Route wieder läufst, taucht der Lauf hier auf.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      } else {
        VStack(spacing: 10) {
          ForEach(related) { run in
            relatedRunRow(run)
          }
        }
      }
    }
  }

  private func relatedRunRow(_ run: CompletedRunSummary) -> some View {
    HStack(spacing: 12) {
      Image(systemName: "figure.run")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 36, height: 36)
        .background(GainsColor.lime.opacity(0.15))
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(run.title)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        Text(run.finishedAt.formatted(date: .abbreviated, time: .omitted))
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(String(format: "%.2f km", run.distanceKm))
          .font(.system(size: 14, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        Text(paceLabel(run.averagePaceSeconds))
          .font(GainsFont.label(9))
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .padding(14)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "—" }
    return String(format: "%d:%02d /km", seconds / 60, seconds % 60)
  }

  private var routeRegion: MKCoordinateRegion {
    guard !route.coordinates.isEmpty else {
      return MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
      )
    }
    let lats = route.coordinates.map(\.latitude)
    let lons = route.coordinates.map(\.longitude)
    let minLat = lats.min()!
    let maxLat = lats.max()!
    let minLon = lons.min()!
    let maxLon = lons.max()!
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
      ),
      span: MKCoordinateSpan(
        latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
        longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
      )
    )
  }
}
