import SwiftUI

// MARK: - MuscleMapView
//
// Anatomisches Körpermodell (Vorder- + Rückansicht). Jede Muskelgruppe ist
// in ihre einzelnen Bäuche/Köpfe aufgeteilt (gleiche Farbe pro Gruppe, aber
// sichtbar getrennt) und wird über eine Intensität 0…1 eingefärbt
// (Ruhe → kräftig Lime). Über `overloaded` (> MRV) schaltet eine Region auf
// Ember. Eine zarte Licht-Wölbung gibt jedem Bauch 3D-Plastik.
//
// Geometrie im normierten 200×460-Raum (8-Kopf-Proportionen). Konturen sind
// centripetal-Catmull-Rom-geglättet (kein Überschwingen). Farben laufen über
// GainsColor-Tokens → automatisch hell/dunkel.

// MARK: - Region-Definition

enum BodyMuscleRegion: String, CaseIterable, Identifiable, Hashable {
  case chest, shoulders, biceps, triceps, forearms, abs
  case lats, traps, lowerBack, glutes, quads, hamstrings, calves

  var id: String { rawValue }

  var title: String {
    switch self {
    case .chest:      return "Brust"
    case .shoulders:  return "Schultern"
    case .biceps:     return "Bizeps"
    case .triceps:    return "Trizeps"
    case .forearms:   return "Unterarme"
    case .abs:        return "Bauch"
    case .lats:       return "Latissimus"
    case .traps:      return "Trapez"
    case .lowerBack:  return "Unt. Rücken"
    case .glutes:     return "Gesäß"
    case .quads:      return "Quadrizeps"
    case .hamstrings: return "Beinbeuger"
    case .calves:     return "Waden"
    }
  }

  var sortOrder: Int {
    switch self {
    case .chest:      return 0
    case .shoulders:  return 1
    case .traps:      return 2
    case .lats:       return 3
    case .biceps:     return 4
    case .triceps:    return 5
    case .forearms:   return 6
    case .abs:        return 7
    case .lowerBack:  return 8
    case .glutes:     return 9
    case .quads:      return 10
    case .hamstrings: return 11
    case .calves:     return 12
    }
  }
}

// MARK: - String → Region Mapping

enum MuscleRegionMap {

  static func regions(for raw: String) -> [BodyMuscleRegion] {
    let s = raw.lowercased()
    var result: Set<BodyMuscleRegion> = []

    if s.contains("brust") && !s.contains("brustwirbel") { result.insert(.chest) }
    if s.contains("schulter") || s.contains("delt") || s.contains("rotatoren") {
      result.insert(.shoulders)
    }
    if (s.contains("bizeps") && !s.contains("beinbizeps")) || s.contains("brachial") {
      result.insert(.biceps)
    }
    if s.contains("trizeps") { result.insert(.triceps) }
    if s.contains("unterarm") { result.insert(.forearms) }
    if s.contains("arme") && !s.contains("unterarm") {
      result.insert(.biceps); result.insert(.triceps)
    }
    if s.contains("latissimus") { result.insert(.lats) }
    if s.contains("rücken") {
      if s.contains("unter") { result.insert(.lowerBack) } else { result.insert(.lats) }
    }
    if s.contains("trapez") { result.insert(.traps) }
    if s.contains("wirbel") || s.contains("hüfte") { result.insert(.lowerBack) }
    if s.contains("bauch") || s.contains("core") || s.contains("anti-rotation")
      || s.contains("hüftbeuger") {
      result.insert(.abs)
    }
    if s.contains("glutes") || s.contains("gesäß") { result.insert(.glutes) }
    if s.contains("quadrizeps") || s.contains("innenseite") { result.insert(.quads) }
    if s.contains("beinbizeps") { result.insert(.hamstrings) }
    if s.contains("waden") || s.contains("schollen") { result.insert(.calves) }
    if s.contains("beine") { result.insert(.quads); result.insert(.hamstrings) }

    return result.sorted { $0.sortOrder < $1.sortOrder }
  }

  struct Assignment {
    let primary: [BodyMuscleRegion]
    let secondary: [BodyMuscleRegion]
  }

  static func lookup(library: [ExerciseLibraryItem]) -> [String: Assignment] {
    var table: [String: Assignment] = [:]
    for item in library {
      let primary = regions(for: item.primaryMuscle)
      let secondarySet = Set(item.secondaryMuscles.flatMap { regions(for: $0) })
        .subtracting(primary)
      table[item.name.lowercased()] = Assignment(
        primary: primary,
        secondary: secondarySet.sorted { $0.sortOrder < $1.sortOrder }
      )
    }
    return table
  }
}

// MARK: - Aggregation aus der Workout-History

enum MuscleTraining {

  struct Snapshot {
    var weightedSets: [BodyMuscleRegion: Double]
    var sessions: [BodyMuscleRegion: Int]
    var weeks: Double

    var isEmpty: Bool { weightedSets.isEmpty }

    func weeklySets(_ region: BodyMuscleRegion) -> Double {
      (weightedSets[region] ?? 0) / max(weeks, 0.1)
    }
    func weeklyFrequency(_ region: BodyMuscleRegion) -> Double {
      Double(sessions[region] ?? 0) / max(weeks, 0.1)
    }
  }

  static func snapshot(
    history: [CompletedWorkoutSummary],
    library: [ExerciseLibraryItem],
    weeks: Double
  ) -> Snapshot {
    let lut = MuscleRegionMap.lookup(library: library)
    var sets: [BodyMuscleRegion: Double] = [:]
    var sessions: [BodyMuscleRegion: Int] = [:]

    for workout in history {
      var workoutRegions: Set<BodyMuscleRegion> = []
      for ex in workout.exercises where ex.completedSets > 0 {
        let assignment = lut[ex.name.lowercased()]
          ?? MuscleRegionMap.Assignment(
            primary: MuscleRegionMap.regions(for: ex.name),
            secondary: []
          )
        let n = Double(ex.completedSets)
        for r in assignment.primary {
          sets[r, default: 0] += n
          workoutRegions.insert(r)
        }
        for r in assignment.secondary where !assignment.primary.contains(r) {
          sets[r, default: 0] += n * 0.5
          workoutRegions.insert(r)
        }
      }
      for r in workoutRegions { sessions[r, default: 0] += 1 }
    }

    return Snapshot(weightedSets: sets, sessions: sessions, weeks: max(weeks, 0.1))
  }
}

// MARK: - Vektor-Helfer + Geometrie (normierter 200×460-Raum)

private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
private func mirrorX(_ poly: [CGPoint]) -> [CGPoint] { poly.map { CGPoint(x: 200 - $0.x, y: $0.y) } }
private func lm(_ p: [CGPoint]) -> [[CGPoint]] { [p, mirrorX(p)] }

private func vsub(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
private func vadd(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
private func vmul(_ a: CGPoint, _ s: CGFloat) -> CGPoint { CGPoint(x: a.x * s, y: a.y * s) }
private func vdist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { max(hypot(a.x - b.x, a.y - b.y), 0.0001) }

enum MuscleGeometry {
  static let designW: CGFloat = 200
  static let designH: CGFloat = 460

  private static func scaled(_ p: CGPoint, in rect: CGRect) -> CGPoint {
    let s = min(rect.width / designW, rect.height / designH)
    let ox = rect.midX - (designW / 2) * s
    let oy = rect.minY + (rect.height - designH * s) / 2
    return CGPoint(x: ox + p.x * s, y: oy + p.y * s)
  }

  /// Zentroid-Inset (Verkleinern Richtung Mitte) → Spalt zwischen Bäuchen.
  static func inset(_ poly: [CGPoint], _ f: CGFloat, _ dy: CGFloat = 0) -> [CGPoint] {
    let cx = poly.reduce(0) { $0 + $1.x } / CGFloat(poly.count)
    let cy = poly.reduce(0) { $0 + $1.y } / CGFloat(poly.count)
    return poly.map { CGPoint(x: cx + ($0.x - cx) * f, y: cy + ($0.y - cy) * f + dy) }
  }

  /// Geschlossener centripetal-Catmull-Rom-Spline (alpha = 0.5) → organisch.
  private static func smoothClosed(_ pts: [CGPoint], in rect: CGRect) -> Path {
    let p = pts.map { scaled($0, in: rect) }
    let n = p.count
    var path = Path()
    guard n >= 3 else {
      if let f = p.first { path.move(to: f); p.dropFirst().forEach { path.addLine(to: $0) }; path.closeSubpath() }
      return path
    }
    path.move(to: p[0])
    for i in 0..<n {
      let p0 = p[(i - 1 + n) % n], p1 = p[i], p2 = p[(i + 1) % n], p3 = p[(i + 2) % n]
      let t1 = sqrt(vdist(p0, p1))
      let t2 = t1 + sqrt(vdist(p1, p2))
      let t3 = t2 + sqrt(vdist(p2, p3))
      let m1 = vadd(vsub(vmul(vsub(p1, p0), 1 / t1), vmul(vsub(p2, p0), 1 / t2)), vmul(vsub(p2, p1), 1 / (t2 - t1)))
      let m2 = vadd(vsub(vmul(vsub(p2, p1), 1 / (t2 - t1)), vmul(vsub(p3, p1), 1 / (t3 - t1))), vmul(vsub(p3, p2), 1 / (t3 - t2)))
      let seg = t2 - t1
      path.addCurve(to: p2, control1: vadd(p1, vmul(m1, seg / 3)), control2: vsub(p2, vmul(m2, seg / 3)))
    }
    path.closeSubpath()
    return path
  }

  /// Offener centripetal-Spline für Detail-Furchen.
  private static func smoothOpen(_ pts: [CGPoint], in rect: CGRect) -> Path {
    let p = pts.map { scaled($0, in: rect) }
    var path = Path()
    guard p.count >= 2 else { return path }
    if p.count == 2 { path.move(to: p[0]); path.addLine(to: p[1]); return path }
    path.move(to: p[0])
    for i in 0..<(p.count - 1) {
      let p0 = i == 0 ? p[0] : p[i - 1]
      let p1 = p[i], p2 = p[i + 1]
      let p3 = (i + 2 < p.count) ? p[i + 2] : p[p.count - 1]
      let t1 = sqrt(vdist(p0, p1))
      let t2 = t1 + sqrt(vdist(p1, p2))
      let t3 = t2 + sqrt(vdist(p2, p3))
      let m1 = vadd(vsub(vmul(vsub(p1, p0), 1 / t1), vmul(vsub(p2, p0), 1 / t2)), vmul(vsub(p2, p1), 1 / (t2 - t1)))
      let m2 = vadd(vsub(vmul(vsub(p2, p1), 1 / (t2 - t1)), vmul(vsub(p3, p1), 1 / (t3 - t1))), vmul(vsub(p3, p2), 1 / (t3 - t2)))
      let seg = t2 - t1
      path.addCurve(to: p2, control1: vadd(p1, vmul(m1, seg / 3)), control2: vsub(p2, vmul(m2, seg / 3)))
    }
    return path
  }

  static func filledPath(_ polys: [[CGPoint]], in rect: CGRect) -> Path {
    var path = Path()
    for poly in polys { path.addPath(smoothClosed(poly, in: rect)) }
    return path
  }

  static func strokePath(_ lines: [[CGPoint]], in rect: CGRect) -> Path {
    var path = Path()
    for line in lines { path.addPath(smoothOpen(line, in: rect)) }
    return path
  }

  // MARK: Silhouette (durchgehende Kontur, Kopf→Hand→Achsel→Rumpf→Bein→Fuß)

  static let silhouette: [[CGPoint]] = {
    let left = [
      P(100,6), P(86,9), P(78,28), P(81,48), P(90,60), P(86,70), P(73,82), P(58,90),
      P(45,108), P(43,140), P(42,200), P(40,252), P(38,276), P(43,289), P(50,283), P(52,256),
      P(55,205), P(58,150), P(60,118), P(67,107), P(74,128), P(68,200), P(64,238), P(60,275),
      P(62,318), P(67,352), P(60,388), P(64,424), P(62,442), P(66,455), P(92,453), P(94,438),
      P(90,422), P(93,386), P(94,352), P(96,300), P(97,266), P(100,270),
    ]
    let rightReversed = Array(left[1..<(left.count - 1)].reversed()).map { CGPoint(x: 200 - $0.x, y: $0.y) }
    return [left + rightReversed]
  }()

  // MARK: Muskel-Bäuche pro Region

  static func bellies(for region: BodyMuscleRegion, front: Bool) -> [[CGPoint]] {
    if front {
      switch region {
      case .chest:
        return lm([P(97,86),P(80,88),P(71,97),P(80,106),P(97,102)])
             + lm([P(97,105),P(77,107),P(66,118),P(75,134),P(91,140),P(97,128)])
      case .shoulders:
        return lm([P(67,90),P(59,92),P(57,107),P(65,114),P(70,103)])
             + lm([P(57,92),P(47,97),P(44,114),P(50,126),P(59,121),P(60,104)])
      case .biceps:
        return lm([P(54,122),P(47,128),P(45,154),P(49,178),P(53,176),P(55,148)])
             + lm([P(55,124),P(60,128),P(60,154),P(57,178),P(54,178),P(54,150)])
             + lm([P(49,174),P(45,182),P(47,196),P(53,194),P(53,178)])
      case .forearms:
        return lm([P(54,190),P(46,196),P(44,214),P(50,222),P(55,210),P(56,196)])
             + lm([P(50,220),P(44,226),P(43,250),P(50,257),P(53,238),P(52,222)])
      case .abs:
        return lm([P(88,150),P(99,150),P(99,165),P(88,165)])
             + lm([P(88,168),P(99,168),P(99,183),P(87,183)])
             + lm([P(87,186),P(99,186),P(99,201),P(86,201)])
             + lm([P(89,204),P(99,204),P(98,224),P(90,232)])
             + lm([P(85,160),P(77,170),P(76,200),P(84,222),P(86,196)])
      case .quads:
        return lm([P(84,278),P(77,282),P(75,330),P(81,360),P(87,356),P(87,300)])
             + lm([P(74,280),P(63,288),P(60,322),P(66,350),P(75,342),P(76,300)])
             + lm([P(87,312),P(95,318),P(96,346),P(88,370),P(84,356),P(86,330)])
      default:
        return []
      }
    } else {
      switch region {
      case .shoulders:
        return lm([P(57,92),P(47,97),P(44,114),P(50,126),P(59,121),P(60,104)])
             + lm([P(60,106),P(66,110),P(67,124),P(60,130),P(56,120)])
      case .triceps:
        return lm([P(56,122),P(60,128),P(59,158),P(56,182),P(53,180),P(54,150)])
             + lm([P(54,124),P(47,130),P(45,158),P(49,180),P(54,178),P(55,150)])
             + lm([P(50,176),P(46,186),P(48,197),P(54,195),P(54,180)])
      case .forearms:
        return lm([P(54,190),P(46,196),P(44,214),P(50,222),P(55,210),P(56,196)])
             + lm([P(50,220),P(44,226),P(43,250),P(50,257),P(53,238),P(52,222)])
      case .lats:
        return lm([P(86,110),P(66,116),P(61,142),P(70,174),P(86,194),P(91,150),P(90,122)])
             + lm([P(85,107),P(73,111),P(71,123),P(81,125),P(87,118)])
      case .traps:
        return [[P(100,103),P(117,121),P(108,151),P(100,171),P(92,151),P(83,121)]]
             + lm([P(98,68),P(82,77),P(63,93),P(80,105),P(98,97)])
      case .lowerBack:
        return lm([P(90,200),P(98,200),P(97,228),P(93,250),P(89,228)])
      case .glutes:
        return lm([P(98,252),P(72,258),P(62,283),P(68,308),P(85,317),P(98,310)])
             + lm([P(71,256),P(62,267),P(61,283),P(71,285),P(74,268)])
      case .hamstrings:
        return lm([P(82,322),P(66,326),P(61,357),P(67,388),P(79,393),P(83,358)])
             + lm([P(84,322),P(95,327),P(96,361),P(88,392),P(82,388),P(83,357)])
      case .calves:
        return lm([P(86,394),P(95,399),P(96,425),P(88,445),P(82,430),P(84,408)])
             + lm([P(84,394),P(73,398),P(68,419),P(75,437),P(84,428),P(85,410)])
             + lm([P(76,433),P(87,436),P(86,450),P(77,447)])
      default:
        return []
      }
    }
  }

  /// Etwas größerer Spalt bei den Bauch-Blöcken (Sixpack), sonst dezent.
  static func insetFactor(for region: BodyMuscleRegion) -> CGFloat {
    region == .abs ? 0.82 : 0.92
  }

  static func detailStrokes(front: Bool) -> [[CGPoint]] {
    if front {
      return [[P(100,86), P(100,146)], [P(100,150), P(100,232)]]
    }
    return [[P(100,68), P(100,254)], [P(100,256), P(100,316)]]
  }
}

// MARK: - Shapes

private struct SilhouetteShape: Shape {
  func path(in rect: CGRect) -> Path { MuscleGeometry.filledPath(MuscleGeometry.silhouette, in: rect) }
}

private struct PolysShape: Shape {
  let polys: [[CGPoint]]
  func path(in rect: CGRect) -> Path { MuscleGeometry.filledPath(polys, in: rect) }
}

private struct DetailShape: Shape {
  let front: Bool
  func path(in rect: CGRect) -> Path {
    MuscleGeometry.strokePath(MuscleGeometry.detailStrokes(front: front), in: rect)
  }
}

// MARK: - Einzelne Figur (Vorne ODER Hinten)

private struct BodyFigure: View {
  let front: Bool
  let intensities: [BodyMuscleRegion: Double]
  let overloaded: Set<BodyMuscleRegion>

  var body: some View {
    ZStack {
      SilhouetteShape().fill(GainsColor.mutedInk.opacity(0.14))
      SilhouetteShape().stroke(GainsColor.border.opacity(0.55), lineWidth: GainsBorder.hairline)

      ForEach(visibleRegions, id: \.self) { region in
        let level = max(0, min(intensities[region] ?? 0, 1))
        let isOver = overloaded.contains(region)
        let f = MuscleGeometry.insetFactor(for: region)
        ForEach(Array(MuscleGeometry.bellies(for: region, front: front).enumerated()), id: \.offset) { _, belly in
          let base = MuscleGeometry.inset(belly, f)
          // Ruhe-Tonus
          PolysShape(polys: [base]).fill(GainsColor.mutedInk.opacity(0.20))
          // Heat
          PolysShape(polys: [base]).fill((isOver ? GainsColor.ember : GainsColor.lime).opacity(heatOpacity(level)))
          // Licht-Wölbung (3D)
          PolysShape(polys: [MuscleGeometry.inset(base, 0.58, -2)]).fill(Color.white.opacity(level > 0 ? 0.16 : 0.05))
          // Kontur
          PolysShape(polys: [base]).stroke(GainsColor.border.opacity(0.4), lineWidth: GainsBorder.hairline)
        }
      }

      DetailShape(front: front)
        .stroke(GainsColor.softInk.opacity(0.26), style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }
    .aspectRatio(MuscleGeometry.designW / MuscleGeometry.designH, contentMode: .fit)
  }

  private var visibleRegions: [BodyMuscleRegion] {
    BodyMuscleRegion.allCases
      .filter { !MuscleGeometry.bellies(for: $0, front: front).isEmpty }
      .sorted { $0.sortOrder < $1.sortOrder }
  }

  private func heatOpacity(_ level: Double) -> Double {
    level <= 0 ? 0 : 0.30 + 0.55 * level
  }
}

// MARK: - Öffentliche Komponente

struct MuscleMapView: View {
  let intensities: [BodyMuscleRegion: Double]
  var overloaded: Set<BodyMuscleRegion> = []
  var figureHeight: CGFloat = 210

  var body: some View {
    HStack(alignment: .top, spacing: GainsSpacing.l) {
      figureColumn(front: true, caption: "VORNE")
      figureColumn(front: false, caption: "HINTEN")
    }
    .frame(maxWidth: .infinity)
  }

  private func figureColumn(front: Bool, caption: String) -> some View {
    VStack(spacing: GainsSpacing.xs) {
      BodyFigure(front: front, intensities: intensities, overloaded: overloaded)
        .frame(height: figureHeight)
      Text(caption)
        .font(GainsFont.label(9))
        .tracking(GainsTracking.eyebrow)
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity)
  }
}
