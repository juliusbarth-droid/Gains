import SwiftUI

// MARK: - GymStatsTab
//
// Aufgewerteter STATS-Tab. Neuerungen vs. der vorherigen Version:
//   • Zeitraum-Filter (Woche / Monat / 3 Monate / Alle) als Pillen oben.
//     Beeinflusst Summary-Header, Personal Records und History — Trend
//     und Muskel-Verteilung bleiben unabhängig (zeigen Verlauf bzw.
//     Wochenplan).
//   • Neue PR-Section: Top-Gewicht pro Übung im gewählten Zeitraum,
//     mit "Neu!"-Badge wenn das PR aus dem letzten Workout stammt.
//   • Volumen-Trend mit Wochenlabel (W-5, W-4, …, „diese") wie zuvor.
//   • Stärke-Progress mit Drilldown bleibt erhalten.
//   • History bleibt mit „Alle anzeigen"-Toggle, gefiltert nach Zeitraum.

struct GymStatsTab: View {
  @EnvironmentObject private var store: GainsStore

  @Binding var historyExerciseName: String?

  @State private var showsAllHistory = false
  @State private var timeRange: TimeRange = .month
  @State private var muscleMapMode: MuscleMapMode = .volume

  /// Was die Einfärbung am Körpermodell abbildet.
  enum MuscleMapMode: String, CaseIterable, Identifiable {
    case volume    = "VOLUMEN"
    case frequency = "FREQUENZ"
    var id: Self { self }
  }

  enum TimeRange: String, CaseIterable, Identifiable {
    case week    = "WOCHE"
    case month   = "MONAT"
    case quarter = "3 MONATE"
    case all     = "ALLE"
    var id: Self { self }

    /// Cutoff-Datum: alles ab diesem Datum zählt zum Zeitraum.
    /// Gibt `nil` zurück bei `.all` — keine Filterung.
    func cutoff(from referenceDate: Date = Date()) -> Date? {
      let calendar = Calendar.current
      switch self {
      case .week:    return calendar.date(byAdding: .day, value: -7, to: referenceDate)
      case .month:   return calendar.date(byAdding: .day, value: -30, to: referenceDate)
      case .quarter: return calendar.date(byAdding: .day, value: -90, to: referenceDate)
      case .all:     return nil
      }
    }
  }

  var body: some View {
    // filteredHistory einmal pro Render berechnen — war 4× O(n)-Filter
    // (body-Guard + summaryHeader + personalRecords + historySection).
    let history = filteredHistory
    return VStack(alignment: .leading, spacing: GainsSpacing.xl) {
      if store.exerciseStrengthProgress.isEmpty && store.workoutHistory.isEmpty {
        EmptyStateView(
          style: .inline,
          title: "Noch keine Trainingsdaten",
          message: "Sobald du dein erstes Workout abschließt, siehst du hier Verlauf, Progress und persönliche Rekorde. Deine geplante Wochenverteilung kannst du schon jetzt unten prüfen.",
          icon: "chart.bar"
        )
      }

      if !store.exerciseStrengthProgress.isEmpty || !store.workoutHistory.isEmpty {
        timeRangeFilter
        summaryHeaderFor(history)
        muscleMapSectionFor(history)
        if !store.workoutHistory.isEmpty {
          volumeTrendSection
        }
        prSectionFor(history)
        if !store.exerciseStrengthProgress.isEmpty {
          strengthProgressSection
        }
        if !history.isEmpty {
          historySectionFor(history)
        }
      }

      muscleDistributionSection
    }
  }

  // MARK: - Zeitraum-Filter
  //
  // A9: Pill-Stil identisch zu `GymWorkoutsTab.filterRow`. Vorher hatte das
  // overlay einen `RoundedRectangle(16)`-Stroke trotz `clipShape(Capsule())`
  // — die Border-Form stimmte nicht mit der visuellen Pille überein.

  private var timeRangeFilter: some View {
    // 2026-05-14 (Polish-Loop 116): Time-Range-Pillen mit Inner-Light
    // + Bottom-Dim auf aktiver Pille + Glow.
    HStack(spacing: GainsSpacing.xsPlus) {
      ForEach(TimeRange.allCases) { range in
        let isActive = timeRange == range
        Button {
          withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            timeRange = range
          }
        } label: {
          Text(range.rawValue)
            .font(GainsFont.eyebrow(10))
            .tracking(1.4)
            .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.softInk)
            .padding(.horizontal, GainsSpacing.s)
            .frame(height: 32)
            .background(
              ZStack {
                Capsule().fill(isActive ? GainsColor.lime : GainsColor.card)
                if isActive {
                  Capsule()
                    .fill(
                      LinearGradient(
                        colors: [Color.white.opacity(0.22), .clear],
                        startPoint: .top,
                        endPoint: .center
                      )
                    )
                    .blendMode(.plusLighter)
                  Capsule()
                    .fill(
                      LinearGradient(
                        colors: [.clear, Color.black.opacity(0.16)],
                        startPoint: .center,
                        endPoint: .bottom
                      )
                    )
                }
              }
            )
            .overlay(
              Capsule().strokeBorder(
                isActive ? Color.clear : GainsColor.border.opacity(0.6),
                lineWidth: 1
              )
            )
            .clipShape(Capsule())
            .compositingGroup()
            .shadow(color: isActive ? GainsColor.lime.opacity(0.30) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
      }
      Spacer()
    }
  }

  /// History-Liste nach aktivem Zeitraum gefiltert.
  private var filteredHistory: [CompletedWorkoutSummary] {
    guard let cutoff = timeRange.cutoff() else { return store.workoutHistory }
    return store.workoutHistory.filter { $0.finishedAt >= cutoff }
  }

  // MARK: - Summary Header

  private func summaryHeaderFor(_ history: [CompletedWorkoutSummary]) -> some View {
    let trainings = history.count
    let totalVolume = history.reduce(0) { $0 + $1.volume } / 1000
    let totalSets = history.reduce(0) { $0 + $1.completedSets }

    return LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: GainsSpacing.tight),
        GridItem(.flexible(), spacing: GainsSpacing.tight),
        GridItem(.flexible(), spacing: GainsSpacing.tight),
      ],
      spacing: GainsSpacing.tight
    ) {
      GainsMetricTile(
        label: "TRAININGS",
        value: "\(trainings)",
        unit: timeRange == .all ? "gesamt" : timeRange.rawValue.lowercased(),
        style: .onyx
      )
      GainsMetricTile(
        label: "VOLUMEN",
        value: String(format: "%.1f t", totalVolume),
        unit: timeRange == .all ? "lifetime" : "im Zeitraum",
        style: .onyx
      )
      GainsMetricTile(
        label: "SÄTZE",
        value: "\(totalSets)",
        unit: "absolviert",
        style: .onyx
      )
    }
  }

  // MARK: - Volumen-Trend (zeitraum-unabhängig — zeigt immer letzte 6 Wo.)

  private var volumeTrendSection: some View {
    let values = weeklyVolumeTrend
    let maxVal = max(values.max() ?? 1, 1)

    return VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["VOLUMEN", "TREND"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("Letzte 6 Wochen")
          .font(GainsFont.label(9))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
      }

      // Polish-Loop 141 (2026-05-14): Volume-Trend-Bars mit Inner-Light auf
      // dem aktiven Slot, Top-Hairline auf dem Track und Glow-Shadow für die
      // aktuelle Woche — gibt dem Chart-Block Cockpit-Tiefe statt nur flacher
      // Rechtecke. Inactive-Bars bekommen einen subtileren Gradient,
      // damit der „diese Woche"-Bar deutlich heraussticht.
      HStack(alignment: .bottom, spacing: GainsSpacing.xsPlus) {
        ForEach(Array(values.enumerated()), id: \.offset) { idx, val in
          let isCurrent = idx == values.count - 1
          VStack(spacing: GainsSpacing.xs) {
            ZStack(alignment: .bottom) {
              // Track
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(GainsColor.background.opacity(0.55))
                .overlay(
                  RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(GainsColor.border.opacity(0.35), lineWidth: GainsBorder.hairline)
                )
                .frame(height: 96)
              // Filling
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                  LinearGradient(
                    colors: isCurrent
                      ? [GainsColor.lime, GainsColor.lime.opacity(0.80)]
                      : [GainsColor.lime.opacity(0.42), GainsColor.lime.opacity(0.28)],
                    startPoint: .top,
                    endPoint: .bottom
                  )
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                      LinearGradient(
                        colors: [
                          Color.white.opacity(isCurrent ? 0.30 : 0.10),
                          Color.white.opacity(0.00)
                        ],
                        startPoint: .top,
                        endPoint: .center
                      )
                    )
                    .blendMode(.plusLighter)
                )
                .frame(height: max(96 * (val / maxVal), 4))
                .shadow(color: isCurrent ? GainsColor.lime.opacity(0.30) : .clear, radius: 6, y: -1)
            }
            .compositingGroup()
            Text(String(format: "%.1f", val / 1000))
              .font(GainsFont.label(9).monospacedDigit())
              .tracking(0.6)
              .foregroundStyle(isCurrent ? GainsColor.ink : GainsColor.softInk)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
            Text(weekLabel(for: idx, total: values.count))
              .font(GainsFont.label(8))
              .tracking(0.6)
              .foregroundStyle(isCurrent ? GainsColor.moss : GainsColor.softInk.opacity(0.7))
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding(.top, GainsSpacing.xxs)

      Text("Werte in t (Tonnen). Engine empfiehlt 4–6-Wochen-Progression MEV → MAV → MRV (Israetel/Helms).")
        .font(GainsFont.body(11))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  /// W-5 / W-4 / … / „diese". Liefert kurze, handliche Achsenlabels.
  private func weekLabel(for index: Int, total: Int) -> String {
    let offset = (total - 1) - index
    return offset == 0 ? "diese" : "W-\(offset)"
  }

  // MARK: - Muskel-Landkarte (tatsächliche History, Körpermodell)
  //
  // Aggregiert die im Zeitraum absolvierten Sätze aus der Workout-History
  // und mappt sie auf Körperregionen (Primär voll, Sekundär ×0.5). Das
  // Körpermodell (Vorne + Hinten) wird per Intensität eingefärbt; per Toggle
  // umschaltbar zwischen Volumen (Sätze/Wo.) und Frequenz (Sessions/Wo.).

  /// Länge des aktiven Zeitraums in Wochen — für die Normierung auf „pro Woche".
  private var weeksInRange: Double {
    switch timeRange {
    case .week:    return 1
    case .month:   return 30.0 / 7.0
    case .quarter: return 90.0 / 7.0
    case .all:
      guard let earliest = store.workoutHistory.last?.finishedAt else { return 1 }
      let days = Calendar.current.dateComponents([.day], from: earliest, to: Date()).day ?? 7
      return max(Double(days) / 7.0, 1)
    }
  }

  /// Intensität 0…1 pro Region + Set der überlasteten Regionen (> MRV).
  private func muscleIntensities(
    _ snapshot: MuscleTraining.Snapshot,
    landmarks: VolumeLandmarks
  ) -> (intensities: [BodyMuscleRegion: Double], overloaded: Set<BodyMuscleRegion>) {
    var intensities: [BodyMuscleRegion: Double] = [:]
    var overloaded: Set<BodyMuscleRegion> = []
    for region in BodyMuscleRegion.allCases {
      switch muscleMapMode {
      case .volume:
        let weekly = snapshot.weeklySets(region)
        guard weekly > 0 else { continue }
        intensities[region] = min(weekly / Double(max(landmarks.mav, 1)), 1)
        if weekly > Double(landmarks.mrv) { overloaded.insert(region) }
      case .frequency:
        let freq = snapshot.weeklyFrequency(region)
        guard freq > 0 else { continue }
        // 2×/Woche gilt als evidenzbasierter Sweet-Spot (Schoenfeld 2016).
        intensities[region] = min(freq / 2.0, 1)
      }
    }
    return (intensities, overloaded)
  }

  @ViewBuilder
  private func muscleMapSectionFor(_ history: [CompletedWorkoutSummary]) -> some View {
    let landmarks = store.weeklyVolumeLandmarks
    let snapshot = MuscleTraining.snapshot(
      history: history,
      library: store.exerciseLibrary,
      weeks: weeksInRange
    )
    let result = muscleIntensities(snapshot, landmarks: landmarks)

    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["MUSKEL", "LANDKARTE"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        muscleModeToggle
      }

      if result.intensities.isEmpty {
        Text("Im gewählten Zeitraum sind noch keine Sätze einzelnen Muskelgruppen zugeordnet. Schließe ein Workout mit Katalog-Übungen ab — dann färbt sich das Modell hier ein.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .fixedSize(horizontal: false, vertical: true)
        MuscleMapView(intensities: [:], overloaded: [])
          .opacity(0.5)
      } else {
        MuscleMapView(intensities: result.intensities, overloaded: result.overloaded)
        muscleColorScale
        muscleLegend(snapshot, overloaded: result.overloaded)
        muscleInsightLine(snapshot)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  /// Segmented-Toggle Volumen ↔ Frequenz.
  private var muscleModeToggle: some View {
    HStack(spacing: GainsSpacing.xxs) {
      ForEach(MuscleMapMode.allCases) { mode in
        let isActive = muscleMapMode == mode
        Button {
          withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            muscleMapMode = mode
          }
        } label: {
          Text(mode.rawValue)
            .font(GainsFont.eyebrow(9))
            .tracking(1.2)
            .foregroundStyle(isActive ? GainsColor.onLime : GainsColor.softInk)
            .padding(.horizontal, GainsSpacing.xsPlus)
            .frame(height: 28)
            .background(
              Capsule().fill(isActive ? GainsColor.lime : GainsColor.card)
            )
            .overlay(
              Capsule().strokeBorder(
                isActive ? Color.clear : GainsColor.border.opacity(0.6),
                lineWidth: GainsBorder.hairline
              )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
    }
  }

  /// Farb-Skala-Legende — erklärt, was die Einfärbung bedeutet.
  private var muscleColorScale: some View {
    let leading = muscleMapMode == .volume ? "wenig" : "selten"
    let trailing = muscleMapMode == .volume ? "optimal" : "oft"
    return HStack(spacing: GainsSpacing.s) {
      Text(leading)
        .font(GainsFont.label(9))
        .foregroundStyle(GainsColor.softInk)
      LinearGradient(
        colors: [GainsColor.lime.opacity(0.28), GainsColor.lime],
        startPoint: .leading,
        endPoint: .trailing
      )
      .frame(height: 6)
      .clipShape(Capsule())
      Text(trailing)
        .font(GainsFont.label(9))
        .foregroundStyle(GainsColor.softInk)
      if muscleMapMode == .volume {
        HStack(spacing: GainsSpacing.xxs) {
          Circle().fill(GainsColor.ember).frame(width: 7, height: 7)
          Text("zu viel")
            .font(GainsFont.label(9))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
  }

  /// Werte-Legende: alle getroffenen Regionen mit ihrem Wert, absteigend.
  private func muscleLegend(
    _ snapshot: MuscleTraining.Snapshot,
    overloaded: Set<BodyMuscleRegion>
  ) -> some View {
    let rows: [(region: BodyMuscleRegion, value: Double, label: String)] =
      BodyMuscleRegion.allCases.compactMap { region in
        switch muscleMapMode {
        case .volume:
          let weekly = snapshot.weeklySets(region)
          guard weekly > 0 else { return nil }
          return (region: region, value: weekly, label: "\(Int(weekly.rounded())) S/Wo")
        case .frequency:
          let freq = snapshot.weeklyFrequency(region)
          guard freq > 0 else { return nil }
          return (region: region, value: freq, label: String(format: "%.1f×/Wo", freq))
        }
      }
      .sorted { $0.value > $1.value }

    return LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: GainsSpacing.tight),
        GridItem(.flexible(), spacing: GainsSpacing.tight),
      ],
      spacing: GainsSpacing.xsPlus
    ) {
      ForEach(rows, id: \.region) { row in
        HStack(spacing: GainsSpacing.xs) {
          Circle()
            .fill(overloaded.contains(row.region) ? GainsColor.ember : GainsColor.lime)
            .frame(width: 8, height: 8)
          Text(row.region.title)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(1)
          Spacer(minLength: 0)
          Text(row.label)
            .font(GainsFont.label(10).monospacedDigit())
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
  }

  /// Eine Zeile: am meisten trainiert vs. vernachlässigt.
  @ViewBuilder
  private func muscleInsightLine(_ snapshot: MuscleTraining.Snapshot) -> some View {
    // „Große" Gruppen, deren Vernachlässigung relevant ist.
    let majors: [BodyMuscleRegion] = [.chest, .lats, .shoulders, .quads, .hamstrings, .glutes, .biceps, .triceps]
    let value: (BodyMuscleRegion) -> Double = { region in
      muscleMapMode == .volume ? snapshot.weeklySets(region) : snapshot.weeklyFrequency(region)
    }
    let top = BodyMuscleRegion.allCases.max { value($0) < value($1) }
    let neglected = majors.min { value($0) < value($1) }

    if let top, value(top) > 0 {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: "flame.fill")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
        Text("Fokus: \(top.title)")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.ink)
        if let neglected, neglected != top, value(neglected) < value(top) {
          Text("·")
            .foregroundStyle(GainsColor.softInk)
          Text("wenig: \(neglected.title)")
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
  }

  // MARK: - Muskel-Verteilung (Wochenplan-basiert, zeitraum-unabhängig)

  @ViewBuilder
  private var muscleDistributionSection: some View {
    let entries: [GymMuscleDoseEntry] = .fromWeeklySchedule(store.weeklyWorkoutSchedule)
    let landmarks = store.weeklyVolumeLandmarks
    let scaleMax = max(entries.map(\.sets).max() ?? landmarks.mrv, landmarks.mrv)

    if !entries.isEmpty {
      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        HStack(alignment: .firstTextBaseline) {
          SlashLabel(
            parts: ["GEPLANT", "VERTEILUNG"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )
          Spacer()
          Text("Geplante Sätze · Wo.")
            .font(GainsFont.label(9))
            .tracking(GainsTracking.eyebrowTight)
            .foregroundStyle(GainsColor.softInk)
        }

        VStack(spacing: GainsSpacing.m) {
          ForEach(entries) { entry in
            GymVolumeBar(
              muscle: entry.muscle,
              sets: entry.sets,
              landmarks: landmarks,
              scaleMaxSets: scaleMax
            )
          }
        }
      }
      .padding(GainsSpacing.m)
      .gainsCardStyle()
    }
  }

  // MARK: - Personal Records (NEU)
  //
  // Pro Übung das höchste `topWeight` aus der gefilterten Historie.
  // Frische PRs (aus dem letzten Workout) bekommen einen "Neu!"-Badge.

  @ViewBuilder
  private func prSectionFor(_ history: [CompletedWorkoutSummary]) -> some View {
    let records = personalRecords(history)

    if !records.isEmpty {
      VStack(alignment: .leading, spacing: GainsSpacing.s) {
        HStack(alignment: .firstTextBaseline) {
          SlashLabel(
            parts: ["PERSONAL", "RECORDS"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )
          Spacer()
          Text("Top-Gewichte · \(timeRange.rawValue)")
            .font(GainsFont.label(9))
            .tracking(1.0)
            .foregroundStyle(GainsColor.softInk)
        }

        VStack(spacing: GainsSpacing.xsPlus) {
          ForEach(records.prefix(5)) { record in
            prRow(record)
          }
        }
      }
      .padding(GainsSpacing.m)
      .gainsCardStyle()
    }
  }

  private func prRow(_ record: PersonalRecord) -> some View {
    Button {
      historyExerciseName = record.exerciseName
    } label: {
      HStack(spacing: GainsSpacing.s) {
        // Polish-Loop 142 (2026-05-14): Trophy-Badge mit Inner-Light +
        // optionalem Lime-Glow auf frischen PRs. Wirkt wie eine geprägte
        // Medaille statt eines flachen Kreises.
        ZStack {
          Circle()
            .fill(record.isFresh ? GainsColor.lime : GainsColor.background.opacity(0.85))
          Circle()
            .fill(
              LinearGradient(
                colors: [
                  Color.white.opacity(record.isFresh ? 0.32 : 0.10),
                  Color.white.opacity(0.00)
                ],
                startPoint: .top,
                endPoint: .center
              )
            )
            .blendMode(.plusLighter)
          Image(systemName: record.isFresh ? "trophy.fill" : "trophy")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(record.isFresh ? GainsColor.onLime : GainsColor.moss)
        }
        .frame(width: 36, height: 36)
        .overlay(
          Circle()
            .strokeBorder(
              record.isFresh ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.45),
              lineWidth: GainsBorder.hairline
            )
        )
        .compositingGroup()
        .shadow(color: record.isFresh ? GainsColor.lime.opacity(0.28) : .clear, radius: 6, y: 2)

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          HStack(spacing: GainsSpacing.xs) {
            Text(record.exerciseName)
              .font(GainsFont.title(15))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            if record.isFresh {
              Text("NEU")
                .font(GainsFont.label(10))
                .tracking(1.4)
                .foregroundStyle(GainsColor.onLime)
                .padding(.horizontal, GainsSpacing.xs)
                .padding(.vertical, 2)
                .background(GainsColor.lime)
                .clipShape(Capsule())
            }
          }
          Text(record.dateLabel)
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }

        Spacer(minLength: 0)

        VStack(alignment: .trailing, spacing: 2) {
          Text(String(format: "%.1f kg", record.topWeight))
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
            .monospacedDigit()
          Text("Top-Gewicht")
            .font(GainsFont.label(8))
            .tracking(1.0)
            .foregroundStyle(GainsColor.softInk)
        }
      }
      .padding(GainsSpacing.s)
      .background(GainsColor.background.opacity(0.5))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  /// Aggregiert pro Übung (Name) das höchste `topWeight` im aktiven Zeitraum
  /// und liefert das Datum, an dem dieses PR gesetzt wurde.
  private func personalRecords(_ history: [CompletedWorkoutSummary]) -> [PersonalRecord] {
    var bestPerExercise: [String: PersonalRecord] = [:]
    let latestFinishedAt = store.workoutHistory.first?.finishedAt
    let cal = Calendar.current

    for workout in history {
      for exercise in workout.exercises where exercise.topWeight > 0 {
        let existing = bestPerExercise[exercise.name]
        if existing == nil || exercise.topWeight > (existing?.topWeight ?? 0) {
          let isFresh = latestFinishedAt.map {
            cal.isDate(workout.finishedAt, inSameDayAs: $0)
          } ?? false
          bestPerExercise[exercise.name] = PersonalRecord(
            exerciseName: exercise.name,
            topWeight: exercise.topWeight,
            achievedAt: workout.finishedAt,
            isFresh: isFresh
          )
        }
      }
    }

    return bestPerExercise.values.sorted { $0.topWeight > $1.topWeight }
  }

  struct PersonalRecord: Identifiable {
    let exerciseName: String
    let topWeight: Double
    let achievedAt: Date
    let isFresh: Bool

    var id: String { exerciseName }

    var dateLabel: String {
      let days = Calendar.current.dateComponents([.day], from: achievedAt, to: Date()).day ?? 0
      switch days {
      case 0:        return "heute"
      case 1:        return "gestern"
      case 2..<7:    return "vor \(days) Tagen"
      case 7..<30:   return "vor \(days / 7) Wo."
      case 30..<365: return "vor \(days / 30) Mon."
      default:       return "vor \(days / 365) J."
      }
    }
  }

  // MARK: - Stärke-Progress (mit Drilldown)

  private var strengthProgressSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["STÄRKE", "FORTSCHRITT"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("Tap = Verlauf")
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: GainsSpacing.tight), GridItem(.flexible(), spacing: GainsSpacing.tight)],
        spacing: GainsSpacing.tight
      ) {
        ForEach(store.exerciseStrengthProgress) { item in
          Button {
            historyExerciseName = item.exerciseName
          } label: {
            VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
              HStack {
                Text(item.exerciseName)
                  .font(GainsFont.label(9))
                  .tracking(1.4)
                  .foregroundStyle(GainsColor.softInk)
                  .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                  .font(.system(size: 10, weight: .bold))
                  .foregroundStyle(GainsColor.moss.opacity(0.7))
              }

              HStack(alignment: .lastTextBaseline, spacing: GainsSpacing.xxs) {
                Text(item.currentValue)
                  .font(GainsFont.title(20))
                  .foregroundStyle(GainsColor.ink)
                Text(item.deltaLabel)
                  .font(GainsFont.label(10))
                  .foregroundStyle(
                    item.deltaLabel.hasPrefix("+") ? GainsColor.lime : GainsColor.softInk
                  )
              }

              Text(item.subtitle)
                .font(GainsFont.body(11))
                .foregroundStyle(GainsColor.softInk)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(GainsSpacing.m)
            .gainsCardStyle()
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: - History (zeitraum-gefiltert)

  private func historySectionFor(_ history: [CompletedWorkoutSummary]) -> some View {
    let visibleCount = showsAllHistory ? history.count : 4
    let visible = Array(history.prefix(visibleCount))

    return VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["VERLAUF", "ZULETZT"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("\(history.count) Workouts · \(timeRange.rawValue)")
          .font(GainsFont.label(9))
          .tracking(GainsTracking.eyebrowTight)
          .foregroundStyle(GainsColor.softInk)
      }

      VStack(spacing: GainsSpacing.tight) {
        ForEach(visible) { workout in
          historyCard(workout)
        }
      }

      if history.count > 4 {
        // Polish-Loop 166 (2026-05-14): History-Toggle als Glas-Pille —
        // identisch zum Library-Toggle (Loop 165). Konsistenz zwischen
        // den Gym-Sub-Tabs.
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
            showsAllHistory.toggle()
          }
        } label: {
          HStack(spacing: GainsSpacing.xs) {
            Text(showsAllHistory
              ? "Weniger anzeigen"
              : "Alle \(history.count) Workouts anzeigen")
              .font(GainsFont.label(10))
              .tracking(GainsTracking.eyebrowTight)
            Image(systemName: showsAllHistory ? "chevron.up" : "chevron.down")
              .font(.system(size: 10, weight: .semibold))
          }
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity)
          .frame(height: 42)
          .background(
            ZStack {
              RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                .fill(GainsColor.glassUndertone)
              RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                .fill(.ultraThinMaterial)
              RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                .fill(GainsColor.background.opacity(0.50))
              RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                .fill(
                  LinearGradient(
                    colors: [GainsColor.glassInnerLight, .clear],
                    startPoint: .top,
                    endPoint: .center
                  )
                )
            }
          )
          .overlay(
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .strokeBorder(
                LinearGradient(
                  colors: [GainsColor.border.opacity(0.55), GainsColor.border.opacity(0.25)],
                  startPoint: .top,
                  endPoint: .bottom
                ),
                lineWidth: GainsBorder.hairline
              )
          )
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          .compositingGroup()
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func historyCard(_ workout: CompletedWorkoutSummary) -> some View {
    HStack(spacing: GainsSpacing.m) {
      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        HStack(spacing: GainsSpacing.xs) {
          Image(systemName: "dumbbell.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text(workout.finishedAt.formatted(date: .abbreviated, time: .omitted).uppercased())
            .font(GainsFont.label(9))
            .tracking(GainsTracking.eyebrowTight)
            .foregroundStyle(GainsColor.softInk)
        }
        Text(workout.title)
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        Text("\(workout.completedSets)/\(workout.totalSets) Sätze · \(Int(workout.volume)) kg Volumen")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer(minLength: 0)

      // Polish-Loop 143 (2026-05-14): Mini-Progress-Ring mit Lime-Gradient
      // statt flachem Stroke, sehr dezenter Glow für die Completion-Quote.
      ZStack {
        Circle()
          .stroke(GainsColor.lime.opacity(0.18), lineWidth: 3)
          .frame(width: 38, height: 38)
        let fraction = workout.totalSets > 0
          ? min(Double(workout.completedSets) / Double(workout.totalSets), 1.0)
          : 0
        Circle()
          .trim(from: 0, to: fraction)
          .stroke(
            AngularGradient(
              colors: [
                GainsColor.lime.opacity(0.85),
                GainsColor.lime,
                GainsColor.lime.opacity(0.85)
              ],
              center: .center
            ),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
          .frame(width: 38, height: 38)
          .rotationEffect(.degrees(-90))
          .shadow(color: GainsColor.lime.opacity(fraction >= 0.99 ? 0.30 : 0.16), radius: 4)
        Text("\(Int(fraction * 100))%")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(fraction >= 0.99 ? GainsColor.lime : GainsColor.moss)
      }
      .compositingGroup()
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // MARK: - Volumen-Trend Daten

  /// Volumen pro Woche für die letzten 6 Wochen.
  /// Single-Pass statt 6× O(n)-Filter: jedes Workout wird einmalig
  /// in den zugehörigen Bucket eingeordnet. O(history) statt O(6·history).
  private var weeklyVolumeTrend: [Double] {
    let calendar = Calendar.current
    let now = Date()
    // Bucket-Grenzen vorberechnen: buckets[i] = (lower, upper) für Woche i.
    // buckets[0] = älteste (vor 6 Wo.), buckets[5] = aktuelle Woche.
    let buckets: [(lower: Date, upper: Date)] = (0..<6).reversed().map { weeksAgo in
      let upper = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: now) ?? now
      let lower = calendar.date(byAdding: .day, value: -7 * (weeksAgo + 1), to: now) ?? now
      return (lower, upper)
    }
    guard let earliest = buckets.first?.lower else { return Array(repeating: 0, count: 6) }
    var volumes = Array(repeating: 0.0, count: 6)
    for workout in store.workoutHistory {
      let date = workout.finishedAt
      guard date >= earliest else { break }  // history ist nach Datum absteigend sortiert
      for (idx, bucket) in buckets.enumerated() {
        if date >= bucket.lower && date < bucket.upper {
          volumes[idx] += workout.volume
          break
        }
      }
    }
    return volumes
  }
}
