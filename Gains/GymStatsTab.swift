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
    VStack(alignment: .leading, spacing: GainsSpacing.xl) {
      if store.exerciseStrengthProgress.isEmpty && store.workoutHistory.isEmpty {
        EmptyStateView(
          style: .inline,
          title: "Noch keine Daten",
          message: "Absolviere dein erstes Training, um Fortschritt und Verlauf zu sehen.",
          icon: "chart.bar"
        )
      } else {
        timeRangeFilter
        summaryHeader
        if !store.workoutHistory.isEmpty {
          volumeTrendSection
        }
        muscleDistributionSection
        prSection
        if !store.exerciseStrengthProgress.isEmpty {
          strengthProgressSection
        }
        if !filteredHistory.isEmpty {
          historySection
        }
      }
    }
  }

  // MARK: - Zeitraum-Filter
  //
  // A9: Pill-Stil identisch zu `GymWorkoutsTab.filterRow`. Vorher hatte das
  // overlay einen `RoundedRectangle(16)`-Stroke trotz `clipShape(Capsule())`
  // — die Border-Form stimmte nicht mit der visuellen Pille überein.

  private var timeRangeFilter: some View {
    HStack(spacing: GainsSpacing.xsPlus) {
      ForEach(TimeRange.allCases) { range in
        Button {
          withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            timeRange = range
          }
        } label: {
          Text(range.rawValue)
            .font(GainsFont.eyebrow(10))
            .tracking(1.4)
            .foregroundStyle(timeRange == range ? GainsColor.onLime : GainsColor.softInk)
            .padding(.horizontal, GainsSpacing.s)
            .frame(height: 32)
            .background(timeRange == range ? GainsColor.lime : GainsColor.card)
            .overlay(
              Capsule().strokeBorder(
                timeRange == range ? Color.clear : GainsColor.border.opacity(0.6),
                lineWidth: 1
              )
            )
            .clipShape(Capsule())
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

  private var summaryHeader: some View {
    let trainings = filteredHistory.count
    let totalVolume = filteredHistory.reduce(0) { $0 + $1.volume } / 1000
    let totalSets = filteredHistory.reduce(0) { $0 + $1.completedSets }

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
        style: .card
      )
      GainsMetricTile(
        label: "VOLUMEN",
        value: String(format: "%.1f t", totalVolume),
        unit: timeRange == .all ? "lifetime" : "im Zeitraum",
        style: .card
      )
      GainsMetricTile(
        label: "SÄTZE",
        value: "\(totalSets)",
        unit: "absolviert",
        style: .card
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
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(alignment: .bottom, spacing: GainsSpacing.xsPlus) {
        ForEach(Array(values.enumerated()), id: \.offset) { idx, val in
          let isCurrent = idx == values.count - 1
          VStack(spacing: GainsSpacing.xs) {
            ZStack(alignment: .bottom) {
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(GainsColor.background.opacity(0.6))
                .frame(height: 96)
              RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isCurrent ? GainsColor.lime : GainsColor.lime.opacity(0.4))
                .frame(height: max(96 * (val / maxVal), 4))
            }
            Text(String(format: "%.1f", val / 1000))
              .font(GainsFont.label(9))
              .tracking(0.6)
              .foregroundStyle(GainsColor.softInk)
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
            parts: ["MUSKEL", "VERTEILUNG"],
            primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk
          )
          Spacer()
          Text("Geplante Sätze · Wo.")
            .font(GainsFont.label(9))
            .tracking(1.2)
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
  private var prSection: some View {
    let records = personalRecords()

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
        ZStack {
          Circle()
            .fill(record.isFresh ? GainsColor.lime : GainsColor.background.opacity(0.85))
            .frame(width: 36, height: 36)
          Image(systemName: record.isFresh ? "trophy.fill" : "trophy")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(record.isFresh ? GainsColor.onLime : GainsColor.moss)
        }

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: GainsSpacing.xs) {
            Text(record.exerciseName)
              .font(GainsFont.title(15))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            if record.isFresh {
              Text("NEU")
                .font(GainsFont.label(8))
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
  private func personalRecords() -> [PersonalRecord] {
    let history = filteredHistory
    var bestPerExercise: [String: PersonalRecord] = [:]
    let latestFinishedAt = store.workoutHistory.first?.finishedAt

    for workout in history {
      for exercise in workout.exercises where exercise.topWeight > 0 {
        let existing = bestPerExercise[exercise.name]
        if existing == nil || exercise.topWeight > (existing?.topWeight ?? 0) {
          let isFresh = latestFinishedAt.map {
            Calendar.current.isDate(workout.finishedAt, inSameDayAs: $0)
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

  private var historySection: some View {
    let history = filteredHistory
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
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      VStack(spacing: GainsSpacing.tight) {
        ForEach(visible) { workout in
          historyCard(workout)
        }
      }

      if history.count > 4 {
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
              .tracking(1.2)
            Image(systemName: showsAllHistory ? "chevron.up" : "chevron.down")
              .font(.system(size: 10, weight: .semibold))
          }
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity)
          .frame(height: 42)
          .background(GainsColor.background.opacity(0.8))
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
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
            .tracking(1.2)
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

      ZStack {
        Circle()
          .stroke(GainsColor.lime.opacity(0.2), lineWidth: 3)
          .frame(width: 38, height: 38)
        let fraction = workout.totalSets > 0
          ? min(Double(workout.completedSets) / Double(workout.totalSets), 1.0)
          : 0
        Circle()
          .trim(from: 0, to: fraction)
          .stroke(GainsColor.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round))
          .frame(width: 38, height: 38)
          .rotationEffect(.degrees(-90))
        Text("\(Int(fraction * 100))%")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.moss)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // MARK: - Volumen-Trend Daten

  private var weeklyVolumeTrend: [Double] {
    let calendar = Calendar.current
    let now = Date()
    return (0..<6).reversed().map { weeksAgo in
      let upper = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: now) ?? now
      let lower = calendar.date(byAdding: .day, value: -7 * (weeksAgo + 1), to: now) ?? now
      return store.workoutHistory
        .filter { $0.finishedAt >= lower && $0.finishedAt < upper }
        .reduce(0) { $0 + $1.volume }
    }
  }
}
