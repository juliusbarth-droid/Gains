import Foundation

// MARK: - RunGoalPlanModels
//
// Ziel-basierter Trainingsplaner für Läufe. Der Nutzer setzt ein Ziel
// (Distanz × Ziel-Pace × Datum) — daraus wird ein Wochen-Trainingsplan in
// vier Phasen generiert: Base → Build → Peak → Taper.
//
//  • RunGoalPlan          — Container. Enthält Ziel, Startwerte und die
//                           generierte Session-Liste.
//  • PlannedRunSession    — Eine konkrete Session (Wochenindex, Datum,
//                           Distanz, Pace-Vorgabe, Status).
//  • RunGoalPhase         — Anzeige-Hilfsenum für UI-Badges.
//  • RunGoalPlanGenerator — Reine Funktion: Ziel + Heute → [Sessions].
//
// Bewusst getrennt von `RunFeatureModels.swift`, damit die Strava-Modelle
// nicht weiter wachsen — der Goal-Planner ist ein eigenes Konzept.
//
// Codable-Conformances stehen direkt hier (Goal-Plan ist neu — wir
// brauchen keine Backward-Compat zu pflegen).

// MARK: - RunGoalPhase

enum RunGoalPhase: String, Codable {
  case base
  case build
  case peak
  case taper

  var title: String {
    switch self {
    case .base:  return "Base"
    case .build: return "Build"
    case .peak:  return "Peak"
    case .taper: return "Taper"
    }
  }

  /// Eyebrow-Variante für die UI (oberhalb der Wochen-Karte).
  var eyebrow: String {
    switch self {
    case .base:  return "GRUNDLAGE"
    case .build: return "AUFBAU"
    case .peak:  return "SCHÄRFE"
    case .taper: return "TAPER"
    }
  }
}

// MARK: - PlannedRunSession

/// Eine konkrete, im Plan eingeplante Lauf-Session.
struct PlannedRunSession: Identifiable, Codable, Hashable {
  let id: UUID
  /// 0-basierter Wochen-Index ab Plan-Start.
  var weekIndex: Int
  /// Konkretes Datum (Plan-Start + weekIndex × 7 + dayOffset).
  var date: Date
  /// Phase, zu der diese Session gehört.
  var phase: RunGoalPhase
  /// Art der Session — wir nutzen die bestehende `PlannedSessionKind`.
  var kind: PlannedSessionKind
  /// Soll-Distanz in km.
  var distanceKm: Double
  /// Pace-Vorgabe in Sekunden/km.
  var targetPaceSeconds: Int
  /// Kurze, vom Generator geschriebene Beschreibung („8× 400m @ 4:30").
  var notes: String
  /// Vom Nutzer als erledigt markiert (manuell oder via Auto-Match).
  var isCompleted: Bool
  /// Falls die Session über einen aufgezeichneten Lauf erledigt wurde —
  /// hier landet die `CompletedRunSummary.id`. Auto-Match guckt darüber,
  /// um Doppelzählung zu vermeiden.
  var completedRunID: UUID?

  init(
    id: UUID = UUID(),
    weekIndex: Int,
    date: Date,
    phase: RunGoalPhase,
    kind: PlannedSessionKind,
    distanceKm: Double,
    targetPaceSeconds: Int,
    notes: String = "",
    isCompleted: Bool = false,
    completedRunID: UUID? = nil
  ) {
    self.id = id
    self.weekIndex = weekIndex
    self.date = date
    self.phase = phase
    self.kind = kind
    self.distanceKm = distanceKm
    self.targetPaceSeconds = targetPaceSeconds
    self.notes = notes
    self.isCompleted = isCompleted
    self.completedRunID = completedRunID
  }
}

// MARK: - RunGoalPlan

/// Aktiver Ziel-Plan. Es gibt höchstens einen aktiven — Setzen eines neuen
/// Plans überschreibt den alten.
struct RunGoalPlan: Identifiable, Codable {
  let id: UUID
  /// Optionaler Klartext-Titel („Halbmarathon Berlin"). Wenn leer, wird in
  /// der UI ein generischer Titel aus Distanz gerendert.
  var title: String
  /// Ziel-Distanz in km.
  var targetDistanceKm: Double
  /// Ziel-Pace in Sekunden/km.
  var targetPaceSeconds: Int
  /// Datum bis wann das Ziel erreicht sein soll.
  var targetDate: Date
  /// Plan-Start (Tagesanfang).
  var startedAt: Date
  /// Aktuelles Wochenvolumen, mit dem der Plan kalibriert wurde (km/Woche).
  var weeklyBaseKm: Double
  /// 3 oder 4 Sessions/Woche.
  var sessionsPerWeek: Int
  /// Generierte Session-Liste. Wird zur Plan-Erstellung einmalig befüllt
  /// und danach nur noch im `isCompleted`/`completedRunID`-Feld mutiert.
  var sessions: [PlannedRunSession]

  init(
    id: UUID = UUID(),
    title: String = "",
    targetDistanceKm: Double,
    targetPaceSeconds: Int,
    targetDate: Date,
    startedAt: Date = Date(),
    weeklyBaseKm: Double,
    sessionsPerWeek: Int,
    sessions: [PlannedRunSession]
  ) {
    self.id = id
    self.title = title
    self.targetDistanceKm = targetDistanceKm
    self.targetPaceSeconds = targetPaceSeconds
    self.targetDate = targetDate
    self.startedAt = startedAt
    self.weeklyBaseKm = weeklyBaseKm
    self.sessionsPerWeek = sessionsPerWeek
    self.sessions = sessions
  }

  // Defensive Codable-Init: neue Felder dürfen mit Default geladen werden.
  enum CodingKeys: String, CodingKey {
    case id, title, targetDistanceKm, targetPaceSeconds, targetDate
    case startedAt, weeklyBaseKm, sessionsPerWeek, sessions
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
    title = (try? c.decode(String.self, forKey: .title)) ?? ""
    targetDistanceKm = try c.decode(Double.self, forKey: .targetDistanceKm)
    targetPaceSeconds = try c.decode(Int.self, forKey: .targetPaceSeconds)
    targetDate = try c.decode(Date.self, forKey: .targetDate)
    startedAt = (try? c.decode(Date.self, forKey: .startedAt)) ?? Date()
    weeklyBaseKm = (try? c.decode(Double.self, forKey: .weeklyBaseKm)) ?? 0
    sessionsPerWeek = (try? c.decode(Int.self, forKey: .sessionsPerWeek)) ?? 4
    sessions = (try? c.decode([PlannedRunSession].self, forKey: .sessions)) ?? []
  }

  func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(title, forKey: .title)
    try c.encode(targetDistanceKm, forKey: .targetDistanceKm)
    try c.encode(targetPaceSeconds, forKey: .targetPaceSeconds)
    try c.encode(targetDate, forKey: .targetDate)
    try c.encode(startedAt, forKey: .startedAt)
    try c.encode(weeklyBaseKm, forKey: .weeklyBaseKm)
    try c.encode(sessionsPerWeek, forKey: .sessionsPerWeek)
    try c.encode(sessions, forKey: .sessions)
  }
}

extension RunGoalPlan {
  /// Anzeige-Titel — entweder vom Nutzer gesetzt, oder aus der Distanz abgeleitet.
  var displayTitle: String {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty { return trimmed }
    return RunGoalPlan.suggestedTitle(for: targetDistanceKm)
  }

  /// Heuristischer Titel aus der Ziel-Distanz: 5K / 10K / Halbmarathon /
  /// Marathon / „NN km Lauf".
  static func suggestedTitle(for km: Double) -> String {
    if abs(km - 5) < 0.3   { return "5 km Ziel" }
    if abs(km - 10) < 0.5  { return "10 km Ziel" }
    if abs(km - 21.0975) < 0.6 { return "Halbmarathon" }
    if abs(km - 42.195) < 0.8  { return "Marathon" }
    if km >= 100 { return "Ultra \(Int(km)) km" }
    if km >= 1   { return String(format: "%.0f km Ziel", km) }
    return "Ziel-Lauf"
  }

  /// Gesamt-Anzahl Wochen im Plan.
  var totalWeeks: Int {
    let weeks = sessions.map(\.weekIndex).max().map { $0 + 1 } ?? 0
    return max(weeks, 1)
  }

  /// Aktueller Wochen-Index relativ zum Heutigen Datum (kann auch
  /// `totalWeeks - 1` überschreiten, wenn das Ziel-Datum überschritten ist).
  func currentWeekIndex(now: Date = Date()) -> Int {
    let cal = Calendar(identifier: .gregorian)
    let startDay = cal.startOfDay(for: startedAt)
    let today = cal.startOfDay(for: now)
    let days = cal.dateComponents([.day], from: startDay, to: today).day ?? 0
    let week = max(0, days / 7)
    return min(week, totalWeeks - 1)
  }

  /// Sessions einer Woche, sortiert nach Datum.
  func sessions(inWeek index: Int) -> [PlannedRunSession] {
    sessions
      .filter { $0.weekIndex == index }
      .sorted { $0.date < $1.date }
  }

  /// Nächste fällige Session ab Heute (alphabetisch nach Datum, nicht erledigt).
  func nextSession(now: Date = Date()) -> PlannedRunSession? {
    let cal = Calendar(identifier: .gregorian)
    let today = cal.startOfDay(for: now)
    return sessions
      .filter { !$0.isCompleted && cal.startOfDay(for: $0.date) >= today.addingTimeInterval(-86_400) }
      .sorted { $0.date < $1.date }
      .first
  }

  /// Anzahl erledigter Sessions, gesamt.
  var completedCount: Int { sessions.filter(\.isCompleted).count }

  /// Fortschritt 0…1 — Sessions erledigt / gesamt.
  var completionFraction: Double {
    guard !sessions.isEmpty else { return 0 }
    return Double(completedCount) / Double(sessions.count)
  }

  /// Tage bis zum Ziel (gerundet auf ganze Tage). Negativ → Ziel-Datum
  /// liegt in der Vergangenheit.
  func daysUntilTarget(now: Date = Date()) -> Int {
    let cal = Calendar(identifier: .gregorian)
    let today = cal.startOfDay(for: now)
    let target = cal.startOfDay(for: targetDate)
    return cal.dateComponents([.day], from: today, to: target).day ?? 0
  }
}

// MARK: - RunGoalPlanGenerator
//
// Reine Funktion. Bekommt die Eingaben, liefert eine vollständige
// Session-Liste zurück. Keine Persistenz, keine Side-Effects — bewusst
// als pure Logik, damit man sie testen oder im Setup als Vorschau
// aufrufen kann.
//
// Methodische Grundlage (intern, in der UI nicht ausgewiesen):
//   • Polarisierte Intensitätsverteilung (Seiler ~80/20):
//     pro Woche eine Schwellen-/VO2max-Einheit, sonst Easy + Long Run.
//   • Periodisierung Base → Build → Peak → Taper (Bompa, Pfitzinger):
//     Aerobe Basis, dann Schwelle/Tempo, dann VO2max + Race-Pace,
//     zuletzt Volumenreduktion bei Erhalt der Intensität.
//   • 3:1-Mikrozyklus mit Cutback-Woche (≈ −20 % Volumen) zur Adaptation
//     (Daniels, Hudson). Letzte Wochen sind Taper, kein Cutback in der
//     Peak-/Taper-Phase nötig.
//   • Long Run 20–25 % des Wochenvolumens, bei Marathon hart bei 32 km
//     gedeckelt (Pfitzinger/Lewis); kürzere Ziele wachsen über die Ziel-
//     distanz hinaus, weil Long Run dann eher aerobe Basis bedient.
//   • Pace-Deltas an Daniels'-Trainings-Zonen orientiert:
//        Easy / Long  ≈ Race-Pace + 60–90 s/km (Zone 1–2)
//        Schwelle      ≈ Race-Pace − 0–10 s/km (Zone 3)
//        VO2max-Int.   ≈ Race-Pace − 25–40 s/km (Zone 4)
//        Recovery      ≈ Race-Pace + 90–120 s/km (Zone 1)
//   • Volumenanstieg in Base/Build pro Woche begrenzt (≈ 10-Prozent-
//     Regel, Gabbett-ACWR), damit der Sprung an Belastung moderat bleibt.

enum RunGoalPlanGenerator {

  /// Erzeugt eine vollständige Session-Liste.
  /// `today` wird in den meisten Fällen `Date()` sein — als Parameter, damit
  /// Tests und Vorschau einen festen Startpunkt nutzen können.
  static func generateSessions(
    targetDistanceKm: Double,
    targetPaceSeconds: Int,
    targetDate: Date,
    weeklyBaseKm: Double,
    sessionsPerWeek: Int,
    today: Date = Date()
  ) -> [PlannedRunSession] {
    let cal = Calendar(identifier: .gregorian)
    let startDay = cal.startOfDay(for: today)
    let targetDay = cal.startOfDay(for: targetDate)
    let rawDays = cal.dateComponents([.day], from: startDay, to: targetDay).day ?? 0
    let totalWeeks = max(4, min(24, rawDays / 7))
    let sessionsPerWeek = max(3, min(4, sessionsPerWeek))

    let phases = phaseAssignments(weeks: totalWeeks)
    let cutbackWeeks = cutbackWeekIndices(phases: phases)

    var result: [PlannedRunSession] = []
    for week in 0..<totalWeeks {
      let phase = phases[week]
      let isCutback = cutbackWeeks.contains(week)

      // Long-Run-Distanz nach Wochen-Index.
      let longKm = longRunDistance(
        weekIndex: week,
        totalWeeks: totalWeeks,
        targetKm: targetDistanceKm,
        weeklyBaseKm: weeklyBaseKm,
        phase: phase,
        isCutback: isCutback
      )
      // Schwellen-Volumen (T-Pace, kontinuierlich): 25 % der Zieldistanz,
      // gedeckelt auf 4–10 km. In Cutback-Wochen ~−25 %.
      let tempoBase = clamp(targetDistanceKm * 0.25, lower: 4, upper: 10)
      // VO2max-Intervall-Volumen (Work-Anteil + Trab-Pause), 30 % Ziel,
      // 5–9 km gesamt.
      let intervalBase = clamp(targetDistanceKm * 0.30, lower: 5, upper: 9)
      let cutbackFactor = isCutback ? 0.75 : 1.0

      // Easy-Distanz: ~22 % vom Ziel; Cutback −25 %. Mind. 4, max. 12 km.
      let easyKm = clamp(targetDistanceKm * 0.22 * cutbackFactor, lower: 4, upper: 12)

      // Pace-Vorgaben relativ zur Ziel-Pace.
      let easyPace      = targetPaceSeconds + 75      // Zone 1–2
      let recoveryPace  = targetPaceSeconds + 105     // Zone 1
      // Long-Run-Pace: Base lockerer, Peak näher an Race-Pace.
      let longPace: Int = {
        switch phase {
        case .base:  return targetPaceSeconds + 60
        case .build: return targetPaceSeconds + 45
        case .peak:  return targetPaceSeconds + 25
        case .taper: return targetPaceSeconds + 35
        }
      }()
      let tempoPace     = targetPaceSeconds            // T-Pace ≈ Race-Pace
      let intervalPace  = max(targetPaceSeconds - 30, 180) // I-Pace, untere Decke 3:00 /km

      // Konkrete Daten anhand des Wochen-Layouts.
      let weekStart = cal.date(byAdding: .day, value: week * 7, to: startDay) ?? startDay
      let layout = weekLayout(sessionsPerWeek: sessionsPerWeek)

      // Phasen-spezifische Härte-Wahl der Quality-Session:
      //   Base   → Tempo (Schwelle aufbauen)
      //   Build  → abwechselnd Tempo / Intervall
      //   Peak   → Intervall mit Race-Pace-Anteilen
      //   Taper  → Tempo (kurz, intensiv, kein Volumen-Reiz)
      let speedKind: PlannedSessionKind = {
        switch phase {
        case .base:  return .tempoRun
        case .build: return week.isMultiple(of: 2) ? .tempoRun : .intervalRun
        case .peak:  return .intervalRun
        case .taper: return .tempoRun
        }
      }()
      let speedKm: Double = {
        switch speedKind {
        case .tempoRun:    return tempoBase * (phase == .taper ? 0.7 : 1.0) * cutbackFactor
        case .intervalRun: return intervalBase * cutbackFactor
        default:           return tempoBase
        }
      }()
      let speedPace = speedKind == .tempoRun ? tempoPace : intervalPace
      let speedNotes = qualityNotes(
        kind: speedKind,
        phase: phase,
        targetPaceSeconds: targetPaceSeconds,
        intervalPaceSeconds: intervalPace
      )

      for slot in layout {
        let date = cal.date(byAdding: .day, value: slot.dayOffset, to: weekStart) ?? weekStart
        switch slot.kind {
        case .easy:
          let useRecovery = phase == .taper || isCutback
          result.append(PlannedRunSession(
            weekIndex: week,
            date: date,
            phase: phase,
            kind: useRecovery ? .recoveryRun : .easyRun,
            distanceKm: roundedKm(easyKm),
            targetPaceSeconds: useRecovery ? recoveryPace : easyPace,
            notes: useRecovery
              ? "Locker im Plauderton — Beine wachhalten"
              : "Locker, durchgehend Plauderton-Tempo"
          ))
        case .speed:
          result.append(PlannedRunSession(
            weekIndex: week,
            date: date,
            phase: phase,
            kind: speedKind,
            distanceKm: roundedKm(speedKm),
            targetPaceSeconds: speedPace,
            notes: speedNotes
          ))
        case .long:
          let notes: String
          switch phase {
          case .base:  notes = "Volumen aufbauen, gleichmäßig"
          case .build: notes = "Letzte 4 km flüssig steigern"
          case .peak:  notes = "Letzte 6 – 8 km im Ziel-Tempo"
          case .taper: notes = "Locker, kurz vor dem Ziel-Tag"
          }
          result.append(PlannedRunSession(
            weekIndex: week,
            date: date,
            phase: phase,
            kind: .longRun,
            distanceKm: roundedKm(longKm),
            targetPaceSeconds: longPace,
            notes: notes
          ))
        }
      }
    }
    return result
  }

  // MARK: Phasen-Verteilung

  /// Liefert für jeden Wochen-Index die zugehörige Phase.
  ///
  /// Verteilung (an Pfitzinger / Bompa angelehnt):
  ///   • Taper: 1 Woche bei < 10 Plan-Wochen, sonst 2 Wochen.
  ///   • Peak: ≈ 15 % der Plan-Wochen, mind. 1.
  ///   • Build: ≈ 35 % der Plan-Wochen, mind. 1.
  ///   • Base: Restwochen (mind. 1, sonst greift fallback unten).
  private static func phaseAssignments(weeks: Int) -> [RunGoalPhase] {
    guard weeks > 0 else { return [] }
    var result: [RunGoalPhase] = Array(repeating: .base, count: weeks)
    let taperLen = weeks >= 10 ? 2 : 1
    let peakLen  = max(1, Int(round(Double(weeks) * 0.15)))
    let buildLen = max(1, Int(round(Double(weeks) * 0.30)))

    let taperStart = weeks - taperLen
    let peakStart  = max(0, taperStart - peakLen)
    let buildStart = max(0, peakStart - buildLen)

    for i in 0..<weeks {
      if i >= taperStart      { result[i] = .taper }
      else if i >= peakStart  { result[i] = .peak }
      else if i >= buildStart { result[i] = .build }
      else                    { result[i] = .base }
    }
    return result
  }

  /// Cutback-Wochen — alle drei Build-Wochen eine Reduktionswoche, in
  /// Base ebenso. In Peak/Taper kein zusätzlicher Cutback (Taper ist
  /// selbst die Volumenreduktion).
  private static func cutbackWeekIndices(phases: [RunGoalPhase]) -> Set<Int> {
    var indices: Set<Int> = []
    var streak = 0
    for (idx, phase) in phases.enumerated() {
      switch phase {
      case .base, .build:
        streak += 1
        // Jede 4. Woche im aktiven Block ist Cutback. Erste Woche nicht.
        if streak >= 4 {
          indices.insert(idx)
          streak = 0
        }
      case .peak, .taper:
        streak = 0
      }
    }
    return indices
  }

  // MARK: Long-Run-Distanz

  /// Long-Run-Wachstumskurve.
  ///
  /// Logik:
  ///   • Peak-Long-Run: Marathon (≥ 38 km) → min(32 km, 85 % Ziel).
  ///                    Halbmarathon (≥ 16 km) → 1,15 × Ziel.
  ///                    10K und kürzer       → 1,8 × Ziel, gedeckelt 18 km.
  ///   • Start-Long-Run: max(0,4 × Ziel, 0,55 × Wochenvolumen, 5 km).
  ///   • Linearer Anstieg von Start → Peak über Base+Build, dann Peak-Niveau,
  ///     im Taper deutlich reduziert.
  ///   • Cutback-Woche: −25 % vom regulären Wachstumspunkt.
  private static func longRunDistance(
    weekIndex: Int,
    totalWeeks: Int,
    targetKm: Double,
    weeklyBaseKm: Double,
    phase: RunGoalPhase,
    isCutback: Bool
  ) -> Double {
    let peakLong: Double = {
      if targetKm >= 38       { return min(32, targetKm * 0.85) }   // Marathon-Decke
      if targetKm >= 16       { return targetKm * 1.15 }            // Halbmarathon
      return min(targetKm * 1.8, 18)                                 // 5K / 10K
    }()
    let startLong = max(targetKm * 0.4, min(weeklyBaseKm * 0.55, 9))
    let lastWeek = max(totalWeeks - 1, 1)
    // Peak-Mitte: ein paar Wochen vor Plan-Ende.
    let peakIndex = max(1, totalWeeks - (totalWeeks >= 10 ? 3 : 2))
    let progress = min(Double(weekIndex) / Double(peakIndex), 1.0)
    let scheduled = startLong + (peakLong - startLong) * progress

    let value: Double
    switch phase {
    case .base, .build:
      value = scheduled
    case .peak:
      value = peakLong
    case .taper:
      // Vorletzte Woche moderat (~70 % Ziel), letzte Woche leichter Long Run
      // (~40 %) — Beine fühlen Distanz, ohne Müdigkeit zu erzeugen.
      let isLastWeek = weekIndex == lastWeek
      return isLastWeek ? max(targetKm * 0.4, 6) : max(targetKm * 0.7, 8)
    }
    return isCutback ? value * 0.75 : value
  }

  // MARK: Quality-Session-Notes

  private static func qualityNotes(
    kind: PlannedSessionKind,
    phase: RunGoalPhase,
    targetPaceSeconds: Int,
    intervalPaceSeconds: Int
  ) -> String {
    switch kind {
    case .tempoRun:
      switch phase {
      case .base:  return "20 min Tempo @ \(paceLabel(targetPaceSeconds))"
      case .build: return "2 × 15 min Tempo @ \(paceLabel(targetPaceSeconds)), 3 min Trab"
      case .peak:  return "Cruise: 4 × 8 min @ \(paceLabel(targetPaceSeconds))"
      case .taper: return "Kurzer Tempo-Block, 12 min @ \(paceLabel(targetPaceSeconds))"
      }
    case .intervalRun:
      switch phase {
      case .base, .build:
        return "6 × 800 m @ \(paceLabel(intervalPaceSeconds)) · 2 min Trab"
      case .peak:
        return "5 × 1000 m @ \(paceLabel(intervalPaceSeconds)) · 90 s Trab"
      case .taper:
        return "4 × 400 m @ \(paceLabel(intervalPaceSeconds)) · 200 m Trab"
      }
    default:
      return ""
    }
  }

  // MARK: Wochen-Layout (Tag-Slots)

  private struct WeekSlot {
    let dayOffset: Int   // 0 = Plan-Start-Wochentag, 1 = Tag danach …
    let kind: SlotKind
  }
  private enum SlotKind { case easy, speed, long }

  private static func weekLayout(sessionsPerWeek: Int) -> [WeekSlot] {
    // Wir mappen auf den Wochenrhythmus relativ zum Plan-Start (= heute).
    // 4 Sessions: Tag 0 Easy, Tag 2 Speed, Tag 4 Easy, Tag 6 Long Run.
    // 3 Sessions: Tag 1 Speed, Tag 3 Easy, Tag 6 Long Run.
    // Abstand zwischen harten Einheiten ≥ 48 h (Recovery-Fenster).
    if sessionsPerWeek >= 4 {
      return [
        WeekSlot(dayOffset: 0, kind: .easy),
        WeekSlot(dayOffset: 2, kind: .speed),
        WeekSlot(dayOffset: 4, kind: .easy),
        WeekSlot(dayOffset: 6, kind: .long),
      ]
    } else {
      return [
        WeekSlot(dayOffset: 1, kind: .speed),
        WeekSlot(dayOffset: 3, kind: .easy),
        WeekSlot(dayOffset: 6, kind: .long),
      ]
    }
  }

  // MARK: Helpers

  private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
    min(max(value, lower), upper)
  }

  /// Auf 0,5 km gerundet — passt zur typischen Lauf-Granularität.
  private static func roundedKm(_ km: Double) -> Double {
    let rounded = (km * 2).rounded() / 2
    return max(rounded, 1.0)
  }

  static func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "—" }
    return String(format: "%d:%02d /km", seconds / 60, seconds % 60)
  }
}
