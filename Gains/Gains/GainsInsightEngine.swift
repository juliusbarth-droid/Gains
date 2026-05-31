import Foundation

// MARK: - GainsInsightEngine (Brand-Loop 11, 2026-05-14)
//
// „Variable reward on open" laut Master Design Prompt: jeder App-Start
// präsentiert EINEN frischen, personalisierten Datenpunkt. Beispiele:
// „Du hast 3.2× mehr trainiert als letzten März", „Dein konstantester
// Tag ist Dienstag", „Diese Woche dein neues Volumen-Rekord".
//
// Zwei Garantien gegen Frustration:
//   1. Keine Wiederholung innerhalb einer Woche (Persistierter Cache der
//      zuletzt 7 Insight-IDs in UserDefaults).
//   2. Fail-soft: wenn nicht genug Daten für eine Aussage vorliegen,
//      liefert die Engine `nil` zurück — die Home-View blendet die Karte
//      dann komplett aus statt eine fade „Komm wieder!"-Phrase zu zeigen.

struct GainsInsight: Identifiable, Equatable {
  let id: String   // stabile Identität fürs Dedup
  let headline: String
  let detail: String?
}

enum GainsInsightEngine {

  private static let recentCacheKey = "gains.insights.recent.v1"
  private static let weeklyCount = 7

  /// Liefert eine frische Insight oder `nil`. Cached die ID, damit sie
  /// in der nächsten Woche nicht wiederkehrt.
  @MainActor
  static func dailyInsight(store: GainsStore, now: Date = Date()) -> GainsInsight? {
    let candidates = generateCandidates(store: store, now: now)
    let recent = Set(loadRecent())
    let fresh = candidates.first(where: { !recent.contains($0.id) })
    let pick = fresh ?? candidates.first
    if let pick {
      persistRecent(adding: pick.id)
    }
    return pick
  }

  // MARK: - Kandidaten-Generator

  private static func generateCandidates(store: GainsStore, now: Date) -> [GainsInsight] {
    var out: [GainsInsight] = []
    let cal = Calendar.current

    // 1) Vergleich gleicher Monat im Vorjahr.
    if let comparison = sameMonthLastYear(history: store.workoutHistory, now: now, cal: cal) {
      out.append(comparison)
    }

    // 2) Konstantester Wochentag.
    if let day = mostConsistentWeekday(history: store.workoutHistory, cal: cal) {
      out.append(day)
    }

    // 3) Streak-Insight.
    if store.streakDays >= 3 {
      out.append(
        GainsInsight(
          id: "streak.\(store.streakDays)",
          headline: "Streak so lang wie nie?",
          detail: "\(store.streakDays) Tage in Folge. Halte die Linie."
        )
      )
    }

    // 4) Trainingsalter (rough estimate).
    if let firstWorkout = store.workoutHistory.last?.finishedAt {
      let days = Int(now.timeIntervalSince(firstWorkout) / 86_400)
      if days >= 30 {
        out.append(
          GainsInsight(
            id: "trainingAge.\(days / 30)",
            headline: trainingAgeHeadline(days: days),
            detail: nil
          )
        )
      }
    }

    // 5) Wochen-Volumen vs. Vormonat.
    if let volume = weekVsLastMonth(history: store.workoutHistory, now: now, cal: cal) {
      out.append(volume)
    }

    return out
  }

  // MARK: - Insight-Heuristiken

  private static func sameMonthLastYear(
    history: [CompletedWorkoutSummary],
    now: Date,
    cal: Calendar
  ) -> GainsInsight? {
    let thisMonth = cal.component(.month, from: now)
    let thisYear  = cal.component(.year, from: now)
    let lastYear  = thisYear - 1
    // Single-pass: beide Zähler in einem Durchlauf, statt 2 × filter.
    var thisMonthCount = 0, lastYearCount = 0
    for w in history {
      let comps = cal.dateComponents([.month, .year], from: w.finishedAt)
      guard comps.month == thisMonth else { continue }
      if comps.year == thisYear  { thisMonthCount += 1 }
      if comps.year == lastYear  { lastYearCount  += 1 }
    }
    guard lastYearCount > 0, thisMonthCount > lastYearCount else { return nil }
    let ratio = Double(thisMonthCount) / Double(lastYearCount)
    let formatted = String(format: "%.1f×", ratio)
    let monthName = monthLabel(for: thisMonth)
    return GainsInsight(
      id: "yearComparison.\(thisYear).\(thisMonth)",
      headline: "\(formatted) mehr Sessions als im \(monthName) letztes Jahr.",
      detail: "\(thisMonthCount) Sessions diesen Monat vs. \(lastYearCount) damals."
    )
  }

  private static func mostConsistentWeekday(
    history: [CompletedWorkoutSummary],
    cal: Calendar
  ) -> GainsInsight? {
    guard history.count >= 8 else { return nil }
    var counts: [Int: Int] = [:]
    for entry in history.prefix(60) {
      let wd = cal.component(.weekday, from: entry.finishedAt)
      counts[wd, default: 0] += 1
    }
    guard let (wd, count) = counts.max(by: { $0.value < $1.value }), count >= 3 else {
      return nil
    }
    let label = weekdayLabel(for: wd)
    return GainsInsight(
      id: "consistentWeekday.\(wd)",
      headline: "Dein konstantester Tag ist \(label).",
      detail: "\(count) Sessions in den letzten 60 Trainings."
    )
  }

  private static func weekVsLastMonth(
    history: [CompletedWorkoutSummary],
    now: Date,
    cal: Calendar
  ) -> GainsInsight? {
    let weekStart  = cal.date(byAdding: .day, value:  -7, to: now) ?? now
    let monthStart = cal.date(byAdding: .day, value: -30, to: now) ?? now
    // Single-pass: beiden Buckets in einem Durchlauf befüllen, statt
    // 2 × filter+reduce (O(2n) → O(n)).
    var lastWeekVolume = 0.0, prevThreeWeeksVolume = 0.0
    for w in history {
      let d = w.finishedAt
      if d >= weekStart                           { lastWeekVolume         += w.volume }
      else if d >= monthStart && d < weekStart    { prevThreeWeeksVolume   += w.volume }
      else if d < monthStart                      { break } // history newest-first
    }
    let lastMonthVolume = prevThreeWeeksVolume / 3.0  // 3 Wochen Vergleich
    guard lastMonthVolume > 0, lastWeekVolume > lastMonthVolume * 1.1 else { return nil }
    let pct = Int(((lastWeekVolume / lastMonthVolume) - 1) * 100)
    return GainsInsight(
      id: "weekVolumeUp.\(Int(now.timeIntervalSince1970 / 86_400))",
      headline: "Diese Woche \(pct)% mehr Volumen als zuletzt.",
      detail: nil
    )
  }

  private static func trainingAgeHeadline(days: Int) -> String {
    if days >= 730 { return "Du trainierst seit \(days / 365)+ Jahren mit gains." }
    if days >= 365 { return "Ein Jahr gains. ist durch." }
    let months = days / 30
    return "\(months) Monate gains. — Konstanz zahlt sich aus."
  }

  // MARK: - Recent-Cache

  private static func loadRecent() -> [String] {
    UserDefaults.standard.stringArray(forKey: recentCacheKey) ?? []
  }

  private static func persistRecent(adding id: String) {
    var current = loadRecent()
    current.removeAll { $0 == id }
    current.insert(id, at: 0)
    let trimmed = Array(current.prefix(weeklyCount))
    UserDefaults.standard.set(trimmed, forKey: recentCacheKey)
  }

  // MARK: - Lokalisierung

  private static func monthLabel(for month: Int) -> String {
    let names = ["Januar", "Februar", "März", "April", "Mai", "Juni",
                 "Juli", "August", "September", "Oktober", "November", "Dezember"]
    guard (1...12).contains(month) else { return "" }
    return names[month - 1]
  }

  private static func weekdayLabel(for weekday: Int) -> String {
    let names = ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]
    guard (1...7).contains(weekday) else { return "" }
    return names[weekday - 1]
  }
}
