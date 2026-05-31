import SwiftUI

// MARK: - Weekday Reference Date
//
// Liefert das tatsächliche Datum eines Wochentags relativ zu „heute" — wird
// von der Wochenstreifen-Komponente genutzt, um Completion-Markierungen
// gegen `workoutHistory` abzugleichen.
//
// Bug-Fix: Die naive Variante `self.rawValue - todayWeekday` lieferte für
// Sonntag (rawValue=1) bei einem Wochentag-Heute (z.B. Mi=4) immer den
// Sonntag der **Vor**woche zurück (diff=-3). In der DE-Locale (Woche Mo–So)
// muss Sonntag aber als letzter Tag DERSELBEN Woche behandelt werden.
extension Weekday {
  var referenceDate: Date {
    let calendar = Calendar.current
    let today = Date()
    // 0 = Mo, 1 = Di, …, 6 = So — App zeigt die Woche immer Mo–So.
    let mondayBasedOffsetForSelf: Int = {
      switch self {
      case .monday: return 0
      case .tuesday: return 1
      case .wednesday: return 2
      case .thursday: return 3
      case .friday: return 4
      case .saturday: return 5
      case .sunday: return 6
      }
    }()
    let todayWeekday = calendar.component(.weekday, from: today)  // 1=Sun, 2=Mon, …, 7=Sat
    // Anzahl Tage, die heute hinter Mo liegt (0…6).
    let mondayBasedOffsetForToday = (todayWeekday + 5) % 7
    let diff = mondayBasedOffsetForSelf - mondayBasedOffsetForToday
    return calendar.date(byAdding: .day, value: diff, to: today) ?? today
  }
}

// MARK: - GymWeekStrip
//
// Geteilte Wochenstreifen-Komponente — Mo–So Punkte mit Status (Training,
// Run, Rest, Flex) und Completion-Häkchen aus `workoutHistory`.
// Ersetzt die Inline-`weekDayCell` aus dem alten GymView.
struct GymWeekStrip: View {
  @EnvironmentObject private var store: GainsStore

  var body: some View {
    HStack(spacing: GainsSpacing.xs) {
      ForEach(store.weeklyWorkoutSchedule) { day in
        cell(day)
      }
    }
  }

  private func cell(_ day: WorkoutDayPlan) -> some View {
    let isCompleted = store.workoutHistory.contains {
      Calendar.current.isDate($0.finishedAt, inSameDayAs: day.weekday.referenceDate)
    }
    let isRun = day.runTemplate != nil

    return VStack(spacing: GainsSpacing.xs) {
      ZStack {
        Circle()
          .fill(background(day, isCompleted: isCompleted))
          .frame(width: 34, height: 34)

        if isCompleted {
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(GainsColor.onLime)
        } else if isRun {
          Image(systemName: "figure.run")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(foreground(day))
        } else {
          Text(day.dayLabel)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(foreground(day))
        }
      }

      Text(day.weekday.shortLabel)
        .font(GainsFont.label(8))
        .tracking(0.8)
        .foregroundStyle(day.isToday ? GainsColor.ink : GainsColor.softInk)
        .fontWeight(day.isToday ? .semibold : .regular)
    }
    .frame(maxWidth: .infinity)
  }

  private func background(_ day: WorkoutDayPlan, isCompleted: Bool) -> Color {
    if isCompleted { return GainsColor.lime }
    let isRun = day.runTemplate != nil
    switch day.status {
    case .planned:
      if isRun {
        return day.isToday ? GainsColor.moss.opacity(0.55) : GainsColor.moss.opacity(0.22)
      }
      return day.isToday ? GainsColor.lime.opacity(0.55) : GainsColor.lime.opacity(0.18)
    case .rest:     return GainsColor.background.opacity(0.7)
    case .flexible: return GainsColor.card
    }
  }

  private func foreground(_ day: WorkoutDayPlan) -> Color {
    switch day.status {
    case .planned:  return day.isToday ? GainsColor.moss : GainsColor.ink
    case .rest:     return GainsColor.softInk.opacity(0.6)
    case .flexible: return GainsColor.softInk
    }
  }
}

// MARK: - GymVolumeBar
//
// Volumen-Bar pro Muskelgruppe mit MEV/MAV/MRV-Schwellenmarkern
// (Renaissance-Periodization-Modell, Israetel 2020).
// Ersetzt die simple `muscleDistributionRow` aus dem alten GymView und
// macht die Schwellen sichtbar — nicht nur als Farbe, sondern als Tick-Linien.
struct GymVolumeBar: View {
  let muscle: String
  let sets: Int
  let landmarks: VolumeLandmarks
  let scaleMaxSets: Int

  private var status: Status {
    if sets >= landmarks.mrv { return .overMRV }
    if sets >= landmarks.mev { return .inRange }
    return .belowMEV
  }

  private enum Status { case belowMEV, inRange, overMRV }

  private var barColor: Color {
    switch status {
    case .belowMEV: return GainsColor.lime.opacity(0.45)
    case .inRange:  return GainsColor.lime
    case .overMRV:  return GainsColor.ember.opacity(0.7)
    }
  }

  private var statusLabel: String {
    switch status {
    case .belowMEV: return "Unter MEV"
    case .inRange:  return "Im Zielbereich"
    case .overMRV:  return "Über MRV"
    }
  }

  private var statusColor: Color {
    switch status {
    case .belowMEV: return GainsColor.softInk
    case .inRange:  return GainsColor.moss
    case .overMRV:  return GainsColor.ember
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      HStack(alignment: .firstTextBaseline) {
        Text(muscle.uppercased())
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(GainsColor.ink)
        Spacer(minLength: 8)
        Text("\(sets) Sätze")
          .font(GainsFont.label(10))
          .tracking(1.0)
          .foregroundStyle(statusColor)
        Text("·")
          .font(GainsFont.label(9))
          .foregroundStyle(GainsColor.softInk)
        Text(statusLabel)
          .font(GainsFont.label(9))
          .tracking(1.0)
          .foregroundStyle(statusColor)
      }
      GeometryReader { geo in
        let width = geo.size.width
        let scale = max(landmarks.mrv + 4, scaleMaxSets)
        let fillRatio = min(Double(sets) / Double(max(scale, 1)), 1.0)
        let mevRatio  = Double(landmarks.mev) / Double(scale)
        let mavRatio  = Double(landmarks.mav) / Double(scale)
        let mrvRatio  = Double(landmarks.mrv) / Double(scale)

        ZStack(alignment: .leading) {
          Capsule()
            .fill(GainsColor.background.opacity(0.7))

          // Sweet-Spot-Zone (zwischen MEV und MRV) als zarte Lime-Hervorhebung.
          Rectangle()
            .fill(GainsColor.lime.opacity(0.10))
            .frame(width: max((mrvRatio - mevRatio) * width, 0))
            .offset(x: mevRatio * width)
            .clipShape(Capsule())

          Capsule()
            .fill(barColor)
            .frame(width: max(width * fillRatio, sets > 0 ? 4 : 0))

          tickMarker(at: mevRatio, width: width, color: GainsColor.moss.opacity(0.85))
          tickMarker(at: mavRatio, width: width, color: GainsColor.moss.opacity(0.55))
          tickMarker(at: mrvRatio, width: width, color: GainsColor.ember.opacity(0.85))
        }
      }
      .frame(height: 10)

      HStack(spacing: GainsSpacing.s) {
        landmarkLabel("MEV", value: landmarks.mev, color: GainsColor.moss.opacity(0.85))
        landmarkLabel("MAV", value: landmarks.mav, color: GainsColor.moss.opacity(0.6))
        landmarkLabel("MRV", value: landmarks.mrv, color: GainsColor.ember.opacity(0.9))
        Spacer(minLength: 0)
      }
    }
  }

  private func tickMarker(at ratio: Double, width: CGFloat, color: Color) -> some View {
    Rectangle()
      .fill(color)
      .frame(width: 2, height: 14)
      .offset(x: max(min(width * ratio, width) - 1, 0), y: -2)
  }

  private func landmarkLabel(_ label: String, value: Int, color: Color) -> some View {
    HStack(spacing: GainsSpacing.xxs) {
      Rectangle()
        .fill(color)
        .frame(width: 2, height: 8)
      Text("\(label) \(value)")
        .font(GainsFont.label(9))
        .tracking(0.6)
        .foregroundStyle(GainsColor.softInk)
    }
  }
}

// MARK: - GymMuscleDoseEntry
//
// Hilfstyp für die heutige Muskel-Dosis (HEUTE-Tab) und Wochenverteilung
// (PLAN/STATS-Tab). Zentralisiert die Aggregation der Sätze pro Muskelgruppe.
struct GymMuscleDoseEntry: Identifiable {
  let muscle: String
  let sets: Int
  var id: String { muscle }
}

extension Array where Element == GymMuscleDoseEntry {
  static func from(plan: WorkoutPlan) -> [GymMuscleDoseEntry] {
    var counts: [String: Int] = [:]
    for ex in plan.exercises {
      counts[ex.targetMuscle, default: 0] += ex.sets.count
    }
    return counts
      .map { GymMuscleDoseEntry(muscle: $0.key, sets: $0.value) }
      .sorted { $0.sets > $1.sets }
  }

  static func fromWeeklySchedule(_ schedule: [WorkoutDayPlan]) -> [GymMuscleDoseEntry] {
    var counts: [String: Int] = [:]
    for day in schedule where day.status == .planned {
      if let plan = day.workoutPlan {
        for ex in plan.exercises {
          counts[ex.targetMuscle, default: 0] += ex.sets.count
        }
      }
    }
    return counts
      .map { GymMuscleDoseEntry(muscle: $0.key, sets: $0.value) }
      .sorted { $0.sets > $1.sets }
  }
}

// MARK: - GymWorkoutSourceBadge

struct GymWorkoutSourceBadge: View {
  let source: WorkoutPlanSource

  var body: some View {
    Text(source.title.uppercased())
      .font(GainsFont.label(9))
      .tracking(1.6)
      .foregroundStyle(source == .custom ? GainsColor.moss : GainsColor.softInk)
      .padding(.horizontal, GainsSpacing.tight)
      .frame(height: 22)
      .background(source == .custom ? GainsColor.lime.opacity(0.32) : GainsColor.background.opacity(0.85))
      .clipShape(Capsule())
  }
}

