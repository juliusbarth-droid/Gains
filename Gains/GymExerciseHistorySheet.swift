import SwiftUI

// MARK: - GymExerciseHistorySheet
//
// Drilldown-Sheet aus dem STATS-Tab. Zeigt für eine konkrete Übung
// (Tap auf eine Stärke-Progress-Card) die komplette Historie:
//   • Aktuelle PR (Top-Gewicht jemals).
//   • Trend-Chart (Top-Gewicht über die letzten 8 Sessions).
//   • Liste aller Sessions in chronologischer Reihenfolge mit
//     Datum, Sätze, Reps, Volumen.
//
// Datenquelle: `store.setHistory(forExerciseNamed:)`.

struct GymExerciseHistorySheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let exerciseName: String

  private var entries: [ExerciseHistoryEntry] {
    store.setHistory(forExerciseNamed: exerciseName)
  }

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        screenHeader(
          eyebrow: "ÜBUNG / VERLAUF",
          title: exerciseName,
          subtitle: "Top-Gewicht, Volumen und Sätze pro Session — chronologisch absteigend."
        )

        if entries.isEmpty {
          EmptyStateView(
            style: .inline,
            title: "Noch keine Daten",
            message: "Sobald du diese Übung in einem absolvierten Workout hast, taucht sie hier auf.",
            icon: "tray"
          )
        } else {
          summaryCard
          trendChart
          historyList
        }
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Fertig") { dismiss() }
          .foregroundStyle(GainsColor.lime)
      }
    }
  }

  // MARK: - Summary

  private var summaryCard: some View {
    let topPR = entries.map(\.topWeight).max() ?? 0
    let totalSessions = entries.count
    let totalVolume = entries.reduce(0) { $0 + $1.totalVolume } / 1000

    return LazyVGrid(
      columns: [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
      ],
      spacing: 10
    ) {
      GainsMetricTile(
        label: "TOP PR",
        value: String(format: "%.1f kg", topPR),
        unit: "Bestes Set",
        style: .card
      )
      GainsMetricTile(
        label: "SESSIONS",
        value: "\(totalSessions)",
        unit: "absolviert",
        style: .card
      )
      GainsMetricTile(
        label: "VOLUMEN",
        value: String(format: "%.1f t", totalVolume),
        unit: "lifetime",
        style: .card
      )
    }
  }

  // MARK: - Trend-Chart

  private var trendChart: some View {
    // Bis zu 8 letzte Sessions in chronologischer Reihenfolge (älteste links).
    let recent = Array(entries.prefix(8)).reversed()
    let values = Array(recent.map(\.topWeight))
    let maxVal = max(values.max() ?? 1, 1)

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        SlashLabel(
          parts: ["GEWICHT", "TREND"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
        Spacer()
        Text("Letzte \(values.count) Sessions")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      HStack(alignment: .bottom, spacing: 6) {
        ForEach(Array(values.enumerated()), id: \.offset) { idx, val in
          let isCurrent = idx == values.count - 1
          VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
              RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(GainsColor.background.opacity(0.6))
                .frame(height: 110)
              RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isCurrent ? GainsColor.lime : GainsColor.lime.opacity(0.4))
                .frame(height: max(110 * (val / maxVal), 4))
            }
            Text(String(format: "%.0f", val))
              .font(GainsFont.label(9))
              .tracking(0.4)
              .foregroundStyle(isCurrent ? GainsColor.moss : GainsColor.softInk)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
          .frame(maxWidth: .infinity)
        }
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  // MARK: - Sessions-Liste

  private var historyList: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["ALLE", "SESSIONS"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(spacing: 10) {
        ForEach(entries) { entry in
          historyRow(entry)
        }
      }
    }
  }

  private func historyRow(_ entry: ExerciseHistoryEntry) -> some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text(entry.date.formatted(date: .abbreviated, time: .omitted).uppercased())
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
        Text(entry.workoutTitle)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        Text("\(entry.completedSets) Sätze · \(entry.totalReps) Reps · \(Int(entry.totalVolume)) kg Volumen")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(2)
      }

      Spacer(minLength: 0)

      VStack(alignment: .trailing, spacing: 2) {
        Text(String(format: "%.1f", entry.topWeight))
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)
        Text("kg Top")
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .padding(14)
    .gainsCardStyle()
  }
}
