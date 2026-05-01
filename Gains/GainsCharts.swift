import SwiftUI

// MARK: - GainsSparklineBar
//
// B5 (Charts-Re-Design 2026-05-01): Wiederverwendbare Bar-Sparkline mit
// HUD-Vokabular. Ersetzt die vier Ad-hoc-Implementierungen in ProgressView,
// GymStatsTab und Co. — alle hatten flache `RoundedRectangle.fill(lime)`-
// Bars, gleichen Latest-Highlight, kein Min/Max-Marker, keine Average-Linie.
//
// Features:
//   • Vertikaler Lime/Cyan/Ember-Gradient pro Bar (oben kräftig, unten 35%)
//   • Letzter Bar mit Halo-Glow + Highlight-Rim
//   • Optionale Durchschnittslinie (gestrichelt, sehr dezent)
//   • Trend-Indikator oben rechts (↗ / ↘ / →)
//   • Min/Max-Marker als kleine Dots auf den extremen Bars (opt-in)
//   • Konsistente Höhe (default 56pt) — Cards haben keine springenden Layouts
//
// Verwendung:
//   GainsSparklineBar(values: volumes, accent: .lime)
//   GainsSparklineBar(values: volumes, accent: .ember, height: 48,
//                     showsAverage: false, showsTrend: false)

struct GainsSparklineBar: View {
  let values: [Double]
  let accent: Color
  let height: CGFloat
  let showsAverage: Bool
  let showsExtremes: Bool
  let showsTrend: Bool

  init(
    values: [Double],
    accent: Color = GainsColor.lime,
    height: CGFloat = 56,
    showsAverage: Bool = true,
    showsExtremes: Bool = true,
    showsTrend: Bool = true
  ) {
    self.values = values
    self.accent = accent
    self.height = height
    self.showsAverage = showsAverage
    self.showsExtremes = showsExtremes
    self.showsTrend = showsTrend
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      bars
      if showsTrend, let trend = trendIndicator {
        trend
          .padding(.top, 0)
          .padding(.trailing, 0)
      }
    }
  }

  private var bars: some View {
    let maxValue = max(values.max() ?? 1, 0.01)
    let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    let avgFraction = CGFloat(avg / maxValue)
    let minIdx = values.indices.min(by: { values[$0] < values[$1] })
    let maxIdx = values.indices.max(by: { values[$0] < values[$1] })

    return GeometryReader { proxy in
      ZStack(alignment: .bottomLeading) {
        // Average-Line als Hintergrund-Strich (gestrichelt, sehr leise)
        if showsAverage && values.count >= 3 {
          let avgY = proxy.size.height * (1 - avgFraction)
          Path { path in
            path.move(to: CGPoint(x: 0, y: avgY))
            path.addLine(to: CGPoint(x: proxy.size.width, y: avgY))
          }
          .stroke(
            GainsColor.softInk.opacity(0.28),
            style: StrokeStyle(lineWidth: 0.6, dash: [3, 3])
          )
        }

        // Bars
        HStack(alignment: .bottom, spacing: 6) {
          ForEach(Array(values.enumerated()), id: \.offset) { index, value in
            barCell(
              value: value,
              maxValue: maxValue,
              isLatest: index == values.count - 1,
              isMin: showsExtremes && index == minIdx && index != values.count - 1,
              isMax: showsExtremes && index == maxIdx && index != values.count - 1,
              fullHeight: proxy.size.height
            )
          }
        }
      }
    }
    .frame(height: height)
  }

  private func barCell(
    value: Double,
    maxValue: Double,
    isLatest: Bool,
    isMin: Bool,
    isMax: Bool,
    fullHeight: CGFloat
  ) -> some View {
    let fraction = CGFloat(value / maxValue)
    let barHeight = max(fullHeight * fraction, 6)

    return ZStack(alignment: .top) {
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        ZStack(alignment: .top) {
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(barFill(isLatest: isLatest))
            .overlay(
              // Top-Highlight nur auf dem aktuellen Bar — gibt ihm Plastizität
              RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(
                  isLatest ? Color.white.opacity(0.35) : Color.clear,
                  lineWidth: 0.6
                )
            )
            .frame(height: barHeight)
            .shadow(
              color: isLatest ? accent.opacity(0.45) : .clear,
              radius: isLatest ? 6 : 0,
              x: 0, y: 0
            )

          // Min/Max-Marker als kleiner Dot direkt über dem Bar
          if isMax {
            extremeDot(color: accent.opacity(0.65))
              .offset(y: -8)
          } else if isMin {
            extremeDot(color: GainsColor.softInk.opacity(0.55))
              .offset(y: -8)
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func extremeDot(color: Color) -> some View {
    Circle()
      .fill(color)
      .frame(width: 4, height: 4)
      .overlay(Circle().stroke(GainsColor.background, lineWidth: 0.8))
  }

  private func barFill(isLatest: Bool) -> LinearGradient {
    if isLatest {
      return LinearGradient(
        colors: [
          accent,
          accent.opacity(0.75)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    } else {
      return LinearGradient(
        colors: [
          accent.opacity(0.45),
          accent.opacity(0.18)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
  }

  // ── Trend-Indikator ────────────────────────────────────────────────

  private var trendIndicator: AnyView? {
    guard showsTrend, values.count >= 2 else { return nil }
    let firstHalf = values.prefix(values.count / 2)
    let secondHalf = values.suffix(values.count - values.count / 2)
    guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return nil }
    let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
    let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
    let span = max(values.max() ?? 1, 0.01)
    let delta = (secondAvg - firstAvg) / span

    let icon: String
    let color: Color
    if delta > 0.05 {
      icon = "arrow.up.right"
      color = accent
    } else if delta < -0.05 {
      icon = "arrow.down.right"
      color = GainsColor.softInk
    } else {
      icon = "arrow.right"
      color = GainsColor.softInk
    }

    return AnyView(
      Image(systemName: icon)
        .font(.system(size: 9, weight: .heavy))
        .foregroundStyle(color)
        .frame(width: 18, height: 18)
        .background(color.opacity(0.14))
        .clipShape(Circle())
    )
  }
}

// MARK: - GainsSparklineLine
//
// B5: Linien-Sparkline mit Gradient-Fill darunter, Average-Linie, Min/Max-
// Markern und Trend-Indikator. Wird vor allem für Gewichtsverläufe genutzt.

struct GainsSparklineLine: View {
  /// Punkt auf der Linie. `value` ist die Y-Achse, `id` muss innerhalb der
  /// Reihe eindeutig sein (UUID, Date.timeIntervalSince… o.ä.).
  struct Point: Identifiable {
    let id: AnyHashable
    let value: Double

    init(id: AnyHashable, value: Double) {
      self.id = id
      self.value = value
    }
  }

  let points: [Point]
  let accent: Color
  let height: CGFloat
  let showsAverage: Bool
  let showsExtremes: Bool

  init(
    points: [Point],
    accent: Color = GainsColor.accentCool,
    height: CGFloat = 60,
    showsAverage: Bool = true,
    showsExtremes: Bool = true
  ) {
    self.points = points
    self.accent = accent
    self.height = height
    self.showsAverage = showsAverage
    self.showsExtremes = showsExtremes
  }

  var body: some View {
    GeometryReader { proxy in
      let w = proxy.size.width
      let h = proxy.size.height
      let values = points.map(\.value)
      let maxValue = values.max() ?? 1
      let minValue = values.min() ?? 0
      let span = max(maxValue - minValue, 0.1)
      let stepX = points.count > 1 ? w / CGFloat(points.count - 1) : w
      let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)

      ZStack(alignment: .topLeading) {
        // 1. Gradient-Fill unter der Linie
        Path { path in
          guard !points.isEmpty else { return }
          for (i, p) in points.enumerated() {
            let x = CGFloat(i) * stepX
            let y = h - CGFloat((p.value - minValue) / span) * (h - 12) - 6
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else      { path.addLine(to: CGPoint(x: x, y: y)) }
          }
          path.addLine(to: CGPoint(x: CGFloat(points.count - 1) * stepX, y: h))
          path.addLine(to: CGPoint(x: 0, y: h))
          path.closeSubpath()
        }
        .fill(LinearGradient(
          colors: [accent.opacity(0.32), accent.opacity(0.02)],
          startPoint: .top,
          endPoint: .bottom
        ))

        // 2. Durchschnittslinie (gestrichelt)
        if showsAverage && points.count >= 3 {
          let avgY = h - CGFloat((avg - minValue) / span) * (h - 12) - 6
          Path { path in
            path.move(to: CGPoint(x: 0, y: avgY))
            path.addLine(to: CGPoint(x: w, y: avgY))
          }
          .stroke(
            GainsColor.softInk.opacity(0.28),
            style: StrokeStyle(lineWidth: 0.6, dash: [3, 3])
          )
        }

        // 3. Linie selbst
        Path { path in
          for (i, p) in points.enumerated() {
            let x = CGFloat(i) * stepX
            let y = h - CGFloat((p.value - minValue) / span) * (h - 12) - 6
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else      { path.addLine(to: CGPoint(x: x, y: y)) }
          }
        }
        .stroke(
          accent,
          style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        )
        .shadow(color: accent.opacity(0.4), radius: 4, x: 0, y: 0)

        // 4. Min/Max-Marker
        if showsExtremes && points.count >= 3 {
          if let minIdx = values.indices.min(by: { values[$0] < values[$1] }) {
            extremeMarker(
              at: minIdx,
              value: values[minIdx],
              minValue: minValue,
              span: span,
              stepX: stepX,
              h: h,
              isMin: true
            )
          }
          if let maxIdx = values.indices.max(by: { values[$0] < values[$1] }),
             maxIdx != values.indices.last {
            extremeMarker(
              at: maxIdx,
              value: values[maxIdx],
              minValue: minValue,
              span: span,
              stepX: stepX,
              h: h,
              isMin: false
            )
          }
        }

        // 5. Latest-Punkt als prominenter Highlight
        if let last = points.last {
          let lastIdx = points.count - 1
          let x = CGFloat(lastIdx) * stepX
          let y = h - CGFloat((last.value - minValue) / span) * (h - 12) - 6
          ZStack {
            Circle()
              .fill(accent.opacity(0.25))
              .frame(width: 16, height: 16)
            Circle()
              .fill(accent)
              .frame(width: 8, height: 8)
              .overlay(Circle().stroke(GainsColor.card, lineWidth: 2))
              .shadow(color: accent.opacity(0.6), radius: 4)
          }
          .position(x: x, y: y)
        }
      }
    }
    .frame(height: height)
  }

  @ViewBuilder
  private func extremeMarker(
    at index: Int,
    value: Double,
    minValue: Double,
    span: Double,
    stepX: CGFloat,
    h: CGFloat,
    isMin: Bool
  ) -> some View {
    let x = CGFloat(index) * stepX
    let y = h - CGFloat((value - minValue) / span) * (h - 12) - 6
    Circle()
      .fill(GainsColor.background)
      .frame(width: 6, height: 6)
      .overlay(
        Circle().stroke(
          isMin ? GainsColor.softInk.opacity(0.7) : accent.opacity(0.85),
          lineWidth: 1.2
        )
      )
      .position(x: x, y: y)
  }
}
