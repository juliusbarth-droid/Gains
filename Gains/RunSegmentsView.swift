import CoreLocation
import MapKit
import SwiftUI

// MARK: - RunSegmentsTab
//
// "Segmente"-Tab im Lauf-Hub. Persönliche Segmente (Streckenstücke), gegen die
// jeder Lauf automatisch antritt. Bestleistung + alle Efforts sichtbar.

struct RunSegmentsTab: View {
  @EnvironmentObject private var store: GainsStore
  @Binding var presentedSegment: RunSegment?
  let onCreateFromRun: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      header

      if store.runSegments.isEmpty {
        emptyCard
      } else {
        VStack(spacing: 12) {
          ForEach(store.runSegments) { segment in
            Button {
              presentedSegment = segment
            } label: {
              segmentCard(segment)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öffnet Segmentdetails mit Bestzeit und Versuchen")
          }
        }
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["DEINE", "SEGMENTE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        if !store.runSegments.isEmpty, !store.runHistory.isEmpty {
          Button {
            onCreateFromRun()
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
              Text("Neu")
                .font(GainsFont.label(9))
                .tracking(1.0)
            }
            .foregroundStyle(GainsColor.onLime)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(GainsColor.lime)
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
      Text("Definierte Streckenstücke. Jeder neue Lauf wird automatisch verglichen — Bestzeit blinkt grün.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
  }

  private var emptyCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      EmptyStateView(
        style: .card(icon: "flag.checkered"),
        title: "Noch keine Segmente",
        message: "Markiere ein Streckenstück aus einem fertigen Lauf — z.B. der Anstieg oder eine Stadtrunde."
      )

      Button {
        onCreateFromRun()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "plus.circle.fill")
            .font(.system(size: 14, weight: .semibold))
          Text("Aus Lauf erstellen")
            .font(GainsFont.label(11))
            .tracking(1.2)
        }
        .foregroundStyle(GainsColor.onLime)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .background(GainsColor.lime)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(store.runHistory.isEmpty)
      .opacity(store.runHistory.isEmpty ? 0.4 : 1)
    }
  }

  // MARK: Segment-Card

  private func segmentCard(_ segment: RunSegment) -> some View {
    let efforts = store.efforts(for: segment.id)
    let best = efforts.first
    let attempts = efforts.count

    return VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topTrailing) {
        if segment.coordinates.count > 1 {
          Map(position: .constant(.region(segmentRegion(segment)))) {
            MapPolyline(coordinates: segment.coordinates)
              .stroke(GainsColor.ember, lineWidth: 4)
            if let start = segment.coordinates.first {
              Annotation("", coordinate: start) {
                Image(systemName: "flag.fill")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundStyle(.white)
                  .frame(width: 22, height: 22)
                  .background(GainsColor.ember)
                  .clipShape(Circle())
              }
            }
            if let end = segment.coordinates.last {
              Annotation("", coordinate: end) {
                Image(systemName: "flag.checkered")
                  .font(.system(size: 11, weight: .bold))
                  .foregroundStyle(.white)
                  .frame(width: 22, height: 22)
                  .background(GainsColor.moss)
                  .clipShape(Circle())
              }
            }
          }
          .frame(height: 130)
          .disabled(true)
        } else {
          Color(.tertiarySystemBackground).frame(height: 130)
        }

        if best != nil {
          HStack(spacing: 4) {
            Image(systemName: "trophy.fill")
              .font(.system(size: 9, weight: .bold))
            Text("PR")
              .font(GainsFont.label(8))
              .tracking(1.4)
          }
          .foregroundStyle(GainsColor.onLime)
          .padding(.horizontal, 8)
          .frame(height: 22)
          .background(GainsColor.lime)
          .clipShape(Capsule())
          .padding(10)
        }
      }

      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(segment.title)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Text("\(String(format: "%.2f", segment.distanceKm)) km · +\(segment.elevationGain) m")
            .font(GainsFont.label(9))
            .tracking(1.0)
            .foregroundStyle(GainsColor.softInk)
        }

        HStack(spacing: 0) {
          segmentStat(
            label: "BESTZEIT",
            value: best.map { format(duration: $0.durationSeconds) } ?? "—",
            unit: ""
          )
          Rectangle()
            .fill(GainsColor.border.opacity(0.4))
            .frame(width: 1, height: 28)
          segmentStat(
            label: "PACE",
            value: best.map { paceLabel($0.paceSeconds) } ?? "—",
            unit: ""
          )
          Rectangle()
            .fill(GainsColor.border.opacity(0.4))
            .frame(width: 1, height: 28)
          segmentStat(label: "VERSUCHE", value: "\(attempts)", unit: "×")
        }
      }
      .padding(14)
    }
    .gainsCardStyle()
  }

  private func segmentStat(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 2) {
      Text(label)
        .font(GainsFont.label(8))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
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
    guard seconds > 0 else { return "—" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  private func format(duration seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
  }

  private func segmentRegion(_ segment: RunSegment) -> MKCoordinateRegion {
    let fallback = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
      span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    // Stabilitäts-Hardening: Force-unwraps auf .min()/.max() entfernt.
    guard !segment.coordinates.isEmpty else { return fallback }
    let lats = segment.coordinates.map(\.latitude)
    let lons = segment.coordinates.map(\.longitude)
    guard
      let minLat = lats.min(), let maxLat = lats.max(),
      let minLon = lons.min(), let maxLon = lons.max()
    else { return fallback }
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
      ),
      span: MKCoordinateSpan(
        latitudeDelta: max((maxLat - minLat) * 1.5, 0.003),
        longitudeDelta: max((maxLon - minLon) * 1.5, 0.003)
      )
    )
  }
}

// MARK: - RunSegmentDetailSheet

struct RunSegmentDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore
  let segment: RunSegment

  @State private var isConfirmingDelete = false

  private var efforts: [RunSegmentEffort] {
    store.efforts(for: segment.id)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          mapHeader

          VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
              Text(segment.title)
                .font(GainsFont.title(26))
                .foregroundStyle(GainsColor.ink)
              if !segment.note.isEmpty {
                Text(segment.note)
                  .font(GainsFont.body(13))
                  .foregroundStyle(GainsColor.softInk)
              }
            }

            statsBlock

            leaderboardSection
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
          Button(role: .destructive) {
            isConfirmingDelete = true
          } label: {
            Image(systemName: "trash")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
        }
      }
      .confirmationDialog(
        "Segment löschen?",
        isPresented: $isConfirmingDelete,
        titleVisibility: .visible
      ) {
        Button("Löschen", role: .destructive) {
          store.deleteSegment(segment.id)
          dismiss()
        }
        Button("Abbrechen", role: .cancel) {}
      }
    }
  }

  private var mapHeader: some View {
    Group {
      if segment.coordinates.count > 1 {
        Map(position: .constant(.region(region))) {
          MapPolyline(coordinates: segment.coordinates)
            .stroke(GainsColor.ember, lineWidth: 5)
          if let start = segment.coordinates.first {
            Annotation("", coordinate: start) {
              Image(systemName: "flag.fill")
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(GainsColor.ember)
                .clipShape(Circle())
            }
          }
          if let end = segment.coordinates.last {
            Annotation("", coordinate: end) {
              Image(systemName: "flag.checkered")
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(GainsColor.moss)
                .clipShape(Circle())
            }
          }
        }
        .frame(height: 240)
      } else {
        Color(.tertiarySystemBackground).frame(height: 240)
      }
    }
  }

  private var statsBlock: some View {
    HStack(spacing: 0) {
      sheetStat(label: "DISTANZ", value: String(format: "%.2f", segment.distanceKm), unit: "km")
      Rectangle().fill(GainsColor.border.opacity(0.4)).frame(width: 1, height: 36)
      sheetStat(label: "HÖHE", value: "+\(segment.elevationGain)", unit: "m")
      Rectangle().fill(GainsColor.border.opacity(0.4)).frame(width: 1, height: 36)
      sheetStat(label: "VERSUCHE", value: "\(efforts.count)", unit: "×")
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 12)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
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

  private var leaderboardSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      SlashLabel(
        parts: ["DEINE", "BESTLEISTUNGEN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      if efforts.isEmpty {
        Text("Noch keine Versuche aufgezeichnet — sobald du das Segment durchläufst, taucht hier deine Zeit auf.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      } else {
        VStack(spacing: 0) {
          ForEach(Array(efforts.enumerated()), id: \.element.id) { idx, effort in
            effortRow(rank: idx + 1, effort: effort, isFirst: idx == 0, isLast: idx == efforts.count - 1)
            if idx < efforts.count - 1 {
              Divider().background(GainsColor.border.opacity(0.4)).padding(.leading, 50)
            }
          }
        }
        .background(GainsColor.card)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      }
    }
  }

  private func effortRow(rank: Int, effort: RunSegmentEffort, isFirst: Bool, isLast: Bool) -> some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(isFirst ? GainsColor.lime : GainsColor.elevated)
          .frame(width: 32, height: 32)
        if isFirst {
          Image(systemName: "trophy.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(GainsColor.onLime)
        } else {
          Text("\(rank)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(GainsColor.ink)
        }
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(format(duration: effort.durationSeconds))
          .font(.system(size: 17, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        Text(effort.achievedAt.formatted(date: .abbreviated, time: .shortened))
          .font(GainsFont.label(9))
          .tracking(0.6)
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(paceLabel(effort.paceSeconds))
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
        Text(effort.averageHeartRate > 0 ? "\(effort.averageHeartRate) bpm" : "—")
          .font(GainsFont.label(9))
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .padding(12)
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "—" }
    return String(format: "%d:%02d /km", seconds / 60, seconds % 60)
  }

  private func format(duration seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 {
      return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%d:%02d", m, s)
  }

  private var region: MKCoordinateRegion {
    let fallback = MKCoordinateRegion(
      center: CLLocationCoordinate2D(latitude: 48.1351, longitude: 11.5820),
      span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    guard !segment.coordinates.isEmpty else { return fallback }
    let lats = segment.coordinates.map(\.latitude)
    let lons = segment.coordinates.map(\.longitude)
    guard
      let minLat = lats.min(), let maxLat = lats.max(),
      let minLon = lons.min(), let maxLon = lons.max()
    else { return fallback }
    return MKCoordinateRegion(
      center: CLLocationCoordinate2D(
        latitude: (minLat + maxLat) / 2,
        longitude: (minLon + maxLon) / 2
      ),
      span: MKCoordinateSpan(
        latitudeDelta: max((maxLat - minLat) * 1.5, 0.003),
        longitudeDelta: max((maxLon - minLon) * 1.5, 0.003)
      )
    )
  }
}

// MARK: - SegmentCreatorSheet
//
// Sheet zum Anlegen eines Segments aus einem fertigen Lauf. Der Nutzer wählt
// Anfangs- und End-Kilometer, gibt einen Namen ein.

struct SegmentCreatorSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let runs: [CompletedRunSummary]

  @State private var selectedRunID: UUID? = nil
  @State private var startKm: Double = 0
  @State private var endKm: Double = 1
  @State private var title: String = ""

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          Text("Wähle einen Lauf und ziehe Start/Ziel auf den Kilometern, die du als Segment markieren willst.")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)

          runPicker

          if let run = selectedRun {
            rangePicker(maxKm: run.distanceKm)

            VStack(alignment: .leading, spacing: 8) {
              Text("NAME")
                .font(GainsFont.label(10))
                .tracking(1.4)
                .foregroundStyle(GainsColor.softInk)
              TextField("z.B. Westpark-Anstieg", text: $title)
                .padding(12)
                .background(GainsColor.card)
                .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
            }
          } else {
            EmptyStateView(
              style: .inline,
              title: "Noch kein Lauf gewählt",
              message: "Wähle oben einen Lauf, um den Bereich für das Segment einzustellen.",
              icon: "figure.run"
            )
          }
        }
        .padding(20)
      }
      .background(GainsColor.background.ignoresSafeArea())
      .navigationTitle("Neues Segment")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
      }
      .safeAreaInset(edge: .bottom) {
        Button {
          createSegment()
        } label: {
          Text("Segment speichern")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(canSave ? GainsColor.onLime : GainsColor.softInk)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(canSave ? GainsColor.lime : GainsColor.card)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(GainsColor.background)
      }
    }
  }

  private var selectedRun: CompletedRunSummary? {
    guard let id = selectedRunID else { return nil }
    return runs.first(where: { $0.id == id })
  }

  private var canSave: Bool {
    selectedRun != nil && endKm > startKm + 0.05
      && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var runPicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("LAUF")
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(runs) { run in
            Button {
              selectedRunID = run.id
              startKm = 0
              endKm = max(min(run.distanceKm * 0.5, 2), 0.5)
              if title.isEmpty { title = "\(run.routeName) Stretch" }
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(run.title)
                  .font(GainsFont.label(11))
                  .tracking(0.8)
                  .foregroundStyle(selectedRunID == run.id ? GainsColor.onLime : GainsColor.ink)
                Text(String(format: "%.2f km", run.distanceKm))
                  .font(GainsFont.label(9))
                  .foregroundStyle(selectedRunID == run.id ? GainsColor.onLimeSecondary : GainsColor.softInk)
              }
              .padding(.horizontal, 12)
              .padding(.vertical, 8)
              .background(selectedRunID == run.id ? GainsColor.lime : GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private func rangePicker(maxKm: Double) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("ABSCHNITT")
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)

      HStack {
        Text("Start").font(GainsFont.body(13))
        Spacer()
        Text(String(format: "%.2f km", startKm))
          .font(.system(size: 14, weight: .bold, design: .rounded))
      }
      .foregroundStyle(GainsColor.ink)

      Slider(value: $startKm, in: 0...max(maxKm - 0.1, 0.1)) { _ in
        if endKm <= startKm + 0.05 { endKm = min(startKm + 0.5, maxKm) }
      }
      .tint(GainsColor.lime)

      HStack {
        Text("Ziel").font(GainsFont.body(13))
        Spacer()
        Text(String(format: "%.2f km", endKm))
          .font(.system(size: 14, weight: .bold, design: .rounded))
      }
      .foregroundStyle(GainsColor.ink)

      Slider(value: $endKm, in: max(startKm + 0.1, 0.1)...max(maxKm, 0.2))
        .tint(GainsColor.lime)

      Text("Länge: \(String(format: "%.2f", max(endKm - startKm, 0))) km")
        .font(GainsFont.label(10))
        .tracking(1.0)
        .foregroundStyle(GainsColor.moss)
    }
    .padding(14)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private func createSegment() {
    guard let run = selectedRun else { return }
    _ = store.createSegment(
      fromRun: run,
      title: title,
      fromKilometer: startKm,
      toKilometer: endKm
    )
    dismiss()
  }
}
