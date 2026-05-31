import SwiftUI

// MARK: - Gains Liquid Design Language (A17, 2026-05-14)
//
// "Liquid Glass / Depth" — die A17-Generation der Gains-Optik.
// Aufsatz auf das bestehende A8/A13/A15/A16-System; baut KEINE
// neuen Tokens, die andere überschreiben, sondern erweitert.
//
// Konzept:
//
// 1. Implizite Lichtquelle oben-leading. Alle Oberflächen reagieren
//    darauf: heller Edge-Highlight oben (1pt 14% Weiß) und ein
//    extrem subtiler Inner-Light-Pool (Linear-Gradient, oben-leading,
//    4% Weiß → transparent). Das erzeugt den "Glass catching light"-Look.
//
// 2. Material-Backdrops. Statt fester `card`-Farbe verwenden wir jetzt
//    iOS-Material (`.ultraThinMaterial`, `.regularMaterial`, …) auf
//    einem Dark-Tint-Layer. Das gibt Tiefe und einen leichten "Frost"-
//    Effekt, der modernes iOS auszeichnet.
//
// 3. Signal-Lime. Lime ist ein Signal, kein Dekor. Nur aktive Aktion,
//    Live-State und Primary-CTAs tragen Lime. Alles andere bleibt
//    monochrom ink/softInk.
//
// 4. Hero-Numerik. Pause-Timer, Set-Counter, Pace, Distance: 56–80pt
//    SF Pro Rounded, monospaced digits, gerichtetes Inner-Glow.
//
// 5. Tiefen-Schatten als 2-Layer (ambient + key) statt einem
//    Pauschal-Drop.
//
// Bestehende API bleibt 100% kompatibel: `gainsCardStyle()` etc.
// delegieren intern auf die neuen Liquid-Helper. Damit profitieren
// alle 300+ Call-Sites in einem Schritt vom neuen Look.

// MARK: - Liquid-Tokens

extension GainsColor {
  /// Signal-Lime — Brand-Signal.
  /// Light-Mode: energisches Olivgrün `#9DCC1F` (knallt auf Pure-White).
  /// Dark-Mode: klassisches Elektro-Lime `#D6F540`.
  static let signal = Color(lightHex: "9DCC1F", darkHex: "D6F540")
  /// Signal-Lime auf gedimmter Idle-Stufe (Pulse-Halo, Ambient-Glow).
  static let signalDim = Color(red: 0.84, green: 0.96, blue: 0.25, opacity: 0.55)

  // MARK: Glass-Edges (v2 — echter Glas-Look)
  //
  // 2026-05-29 (Light-Mode-Pass v2): Glas auf Pure-White-Background
  // braucht alle vier Schichten in ihrer kräftigsten Variante, sonst
  // verschwindet die Kachel im Hintergrund:
  //
  // 1) glassUndertone — sichtbarer Cool-Gray-Tint UNTER dem Material.
  //    Das ist der „Glaskörper" selbst; ohne diesen Layer ist eine Kachel
  //    auf Weiß unsichtbar. Dunkel-Mode bleibt schwarzer Wash.
  //
  // 2) Edge-Top — kräftige weiße Lichtkante oben. Markiert die obere
  //    Bruchkante des Glas-Quaders.
  //
  // 3) Edge-Bottom — sichtbarer dunkler Saum unten. Markiert die untere
  //    Bruchkante (kein Stroke, sondern Lichtbrechung).
  //
  // 4) Inner-Light — heller Sheen-Pool oben-leading. Das ist das
  //    spiegelnde Highlight, das echtes Glas hat.

  static let glassEdgeTop    = Color(
    light: Color.white.opacity(0.95),
    dark:  Color.white.opacity(0.22)
  )
  /// 2026-05-31 (Glass-Sharpen-Pass): Mittlerer Edge-Stop für eine
  /// 3-stufige Rim-Kante (hell oben → neutral Mitte → dunkel unten). Eine
  /// 2-Stop-Kante liest sich als Outline; erst der neutrale Mittelstop lässt
  /// den Rand wie eine *gebrochene Glaskante* wirken statt wie ein Strich.
  static let glassEdgeMid    = Color(
    light: Color.white.opacity(0.16),
    dark:  Color.white.opacity(0.05)
  )
  static let glassEdgeBottom = Color(
    light: Color.black.opacity(0.12),
    dark:  Color.black.opacity(0.16)
  )

  /// 2026-05-31 (Glass-Sharpen-Pass): Fokussiertes Specular-Highlight —
  /// der kleine, helle „Light-Catch" oben-leading, den echtes Glas an der
  /// oberen Bruchkante hat. Anders als der breite `glassInnerLight`-Pool ist
  /// das ein enger, hellerer Punkt (kleiner Radius), der dem Glas Brillanz
  /// gibt. Bewusst moderat gehalten: auf hellem Card-Boden (#F2F5FC, 0.95
  /// Luminanz) addiert 0.14 + InnerLight 0.18 ≈ 0.97 — noch unter dem Clip.
  static let glassSpecular   = Color(
    light: Color.white.opacity(0.14),
    dark:  Color.white.opacity(0.11)
  )

  /// Inner-Light-Pool — oben-leading Sheen, der das Spiegeln von echtem
  /// Glas nachahmt.
  ///
  /// 2026-05-29 (Light-Mode-Pass v3): Light-Mode von 0.65 auf 0.18 reduziert.
  /// Mit .plusLighter addierte 0.65 auf einem #ECEFF5-Card-Background (0.937
  /// Luminanz) zu 1.0 → hartes weißes Blow-out-Eck. Bei 0.18 und normalem
  /// Alpha-Compositing (kein .plusLighter mehr) entsteht ein dezenter Sheen
  /// ohne zu clippen. Dark-Mode bleibt unverändert bei 0.045.
  static let glassInnerLight = Color(
    light: Color.white.opacity(0.18),
    dark:  Color.white.opacity(0.045)
  )

  /// Glaskörper-Undertone — die sichtbare Cool-Tönung UNTER dem Material.
  ///
  /// 2026-05-29 (Light-Mode-Pass v3): Opacity von 0.78 auf 0.40 reduziert.
  /// Problem: 0.78 einer saturierten Blau-Komponente `(0.918, 0.937, 0.973)`
  /// auf Pure-White ergab ein kräftiges #EEF2F9 als Boden — zusammen mit
  /// .regularMaterial und card-Tint wirkten Tiles schwer blau-grau. Bei 0.40
  /// bleibt die Cool-Glass-Identität subtil erhalten ohne zu dominieren.
  /// Dark-Mode: unverändert black.opacity(0.32).
  static let glassUndertone = Color(
    light: Color(red: 0.918, green: 0.937, blue: 0.973).opacity(0.34),
    dark:  Color.black.opacity(0.32)
  )
}

// MARK: - Material-Stufen

enum GainsMaterial {
  /// Sehr leicht — Sub-Surfaces, Pills, Chips (drücken aus: "leicht
  /// erhöht, kaum vom Hintergrund getrennt").
  case thin
  /// Standard — Cards, ListRows, Tiles.
  case regular
  /// Dick — Hero-Surfaces, Sheets, Bottom-CTA (drücken aus: "klar
  /// gehoben, eigene Ebene").
  case thick

  var material: Material {
    switch self {
    case .thin:    return .ultraThinMaterial
    case .regular: return .regularMaterial
    case .thick:   return .thickMaterial
    }
  }
}

// MARK: - Depth-Shadow-Stack

enum GainsDepth {
  /// Idle-Surface — Ambient-Schatten + minimale Key.
  case rest
  /// Card-Surface — Standard-Karten.
  case card
  /// Hero-Surface — Tracker, CTA, Sheets.
  case hero
  /// Float-Surface — schwebende Layer (FAB, Modal-CTA).
  case float
}

extension View {
  /// Zwei-Layer-Schatten (Ambient + Key), der den Liquid-Glass-Look
  /// definiert. Anders als der A13-Single-Shadow kommt hier Tiefe
  /// aus zwei Quellen: ein weicher Ambient-Wash (breit, leicht) +
  /// ein definierter Key-Light-Schatten (kompakt, dunkler).
  ///
  /// 2026-05-31 (Crash-Fix): Schatten laufen jetzt über einen ViewModifier,
  /// der den Light/Dark-Switch via @Environment(\.colorScheme) macht und
  /// statische `Color.black.opacity(...)`-Werte an `.shadow` gibt. Die
  /// `Color(light:dark:)`-Shadow-Tokens bauen einen dynamischen UIColor-
  /// Provider — dessen CGColor-Auflösung crashte beim Rastern der
  /// compositingGroup (gainsCardStyle) mit EXC_BAD_ACCESS direkt in
  /// gainsDepthShadow. Opacity-Werte sind 1:1 identisch zu den Tokens.
  func gainsDepthShadow(_ level: GainsDepth = .card) -> some View {
    modifier(GainsDepthShadowModifier(level: level))
  }
}

private struct GainsDepthShadowModifier: ViewModifier {
  let level: GainsDepth
  @Environment(\.colorScheme) private var scheme

  func body(content: Content) -> some View {
    let dark = scheme == .dark
    switch level {
    case .rest:
      content
        .shadow(color: .black.opacity(dark ? 0.22 : 0.08), radius: 10, x: 0, y: 2)
    case .card:
      content
        .shadow(color: .black.opacity(dark ? 0.28 : 0.10), radius: 22, x: 0, y: 2)
        .shadow(color: .black.opacity(dark ? 0.35 : 0.13), radius: 6,  x: 0, y: 4)
    case .hero:
      content
        .shadow(color: .black.opacity(dark ? 0.34 : 0.12), radius: 30, x: 0, y: 4)
        .shadow(color: .black.opacity(dark ? 0.42 : 0.16), radius: 10, x: 0, y: 8)
    case .float:
      content
        .shadow(color: .black.opacity(dark ? 0.38 : 0.14), radius: 36, x: 0, y: 6)
        .shadow(color: .black.opacity(dark ? 0.48 : 0.20), radius: 14, x: 0, y: 12)
    }
  }
}

// MARK: - Glass-Surface

extension View {
  /// Premium-Glass-Oberfläche — Material + Undertone + Edge-Highlight +
  /// Inner-Light-Pool + Depth-Shadow.
  ///
  /// Drop-in-Ersatz für `.background(GainsColor.card).clipShape(...)` —
  /// das verwendet jetzt `gainsCardStyle()` intern. Eigenständige Aufrufe
  /// nur für Sonderflächen, die einen anderen Radius/Material brauchen.
  ///
  /// - Parameters:
  ///   - corner: Eckenradius (default `GainsRadius.standard`).
  ///   - material: Glas-Dicke (default `.regular`).
  ///   - tint: Optionaler Akzent-Tint, der dem Undertone beigemischt wird
  ///           (z.B. `GainsColor.signal.opacity(0.06)` für aktive Surfaces).
  ///   - depth: Schattenstufe (default `.card`).
  func gainsGlassSurface(
    corner: CGFloat = GainsRadius.standard,
    material: GainsMaterial = .regular,
    tint: Color = .clear,
    depth: GainsDepth = .card
  ) -> some View {
    let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
    return self
      .background {
        ZStack {
          // 1) Undertone: dunkler Wash, damit Schrift auch über
          //    hellen Hintergründen lesbar bleibt.
          shape.fill(GainsColor.glassUndertone)
          // 2) Material-Backdrop — der eigentliche Frost-Effekt.
          shape.fill(material.material)
          // 3) Optionaler Akzent-Tint.
          if tint != .clear {
            shape.fill(tint)
          }
          // 4) Inner-Light-Pool: oben-leading Sheen, fades out.
          //    2026-05-29 (Light-Mode-Pass v3): .plusLighter entfernt.
          //    Auf Dark-Backgrounds: 0.045 Weiß normal composited = subtiler
          //    Glow. Auf Light-Backgrounds: 0.18 Weiß normal = dezenter Sheen
          //    ohne Blow-out (mit .plusLighter wäre 0.18 + 0.937 > 1.0).
          shape
            .fill(
              LinearGradient(
                colors: [GainsColor.glassInnerLight, .clear],
                startPoint: .topLeading,
                endPoint: .center
              )
            )
          // 4b) Specular-Hotspot: enger, hellerer Light-Catch oben-leading.
          //     Gibt dem Glas Brillanz statt nur einer Aufhellung.
          shape
            .fill(
              RadialGradient(
                colors: [GainsColor.glassSpecular, .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 130
              )
            )
        }
      }
      .overlay {
        // 5) Edge-Highlight: 3-stufiger Rim (hell oben → neutral → dunkel
        //    unten). Verkauft die Lichtbrechung an der Glaskante.
        shape
          .stroke(
            LinearGradient(
              colors: [
                GainsColor.glassEdgeTop,
                GainsColor.glassEdgeMid,
                GainsColor.glassEdgeBottom
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 0.9
          )
      }
      .clipShape(shape)
      .gainsDepthShadow(depth)
  }

  /// 2026-05-29 (Glass-Redesign): Glas/Outline-CTA-Fläche für bespoke
  /// Buttons, die nicht `GainsPrimaryButton` nutzen. Ersetzt das alte
  /// `.background(GainsColor.lime).clipShape(...)`-Pattern: glasiger
  /// Hintergrund (Undertone + Material + Inner-Light) + feine Akzent-
  /// Hairline statt farbigem Fill. Kein Glow.
  ///
  /// Das Label sollte auf `GainsColor.ink` stehen — die Farbe lebt nur in
  /// der Hairline (und ggf. einem Leading-Icon), nicht in der Fläche.
  func gainsGlassCTA(
    corner: CGFloat = GainsRadius.standard,
    accent: Color = GainsColor.lime,
    isEnabled: Bool = true
  ) -> some View {
    let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
    return self
      .background {
        ZStack {
          shape.fill(GainsColor.glassUndertone)
          shape.fill(.regularMaterial)
          if isEnabled { shape.fill(accent.opacity(0.06)) }
          shape.fill(
            LinearGradient(
              colors: [GainsColor.glassInnerLight, .clear],
              startPoint: .topLeading,
              endPoint: .center
            )
          )
          shape.fill(
            RadialGradient(
              colors: [GainsColor.glassSpecular, .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 130
            )
          )
        }
      }
      .overlay {
        shape.stroke(
          LinearGradient(
            colors: [
              GainsColor.glassEdgeTop,
              GainsColor.glassEdgeMid,
              GainsColor.glassEdgeBottom
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 0.9
        )
      }
      .overlay {
        shape.strokeBorder(
          LinearGradient(
            colors: [
              accent.opacity(isEnabled ? 0.55 : 0.18),
              accent.opacity(0.14)
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.accent
        )
      }
      .clipShape(shape)
      .compositingGroup()
      .gainsDepthShadow(.card)
  }
}

// MARK: - Adaptive Frosted-Hero-Glass (A18, 2026-05-29)

extension View {
  /// „Mehr Glas, freundlicher" — die A18-Hero-Oberfläche.
  ///
  /// Eine adaptive Frosted-Glass-Bühne für die vier großen Kacheln
  /// (Coach-Brief, Kalorientracker, Gym-Hero, Kardio-Hero). Anders als die
  /// frühere immer-dunkle `ctaSurface`-Bühne ist diese Fläche adaptiv:
  ///   • Light-Mode: helle, milchige Frosted-Glass-Kachel — `.regularMaterial`
  ///     lässt den Creme-Hintergrund durchscheinen, wirkt luftig & freundlich.
  ///   • Dark-Mode: dunkle Glas-Bühne aus denselben Tokens.
  ///
  /// Ein lebendiger Akzent-Glow (normal blend, damit er auf HELL und DUNKEL
  /// wirkt — `.screen` täte auf Hell nichts) tönt das Glas freundlich-farbig,
  /// ohne die Lesbarkeit der adaptiven `ink`-Schrift zu kosten.
  ///
  /// WICHTIG: Text auf dieser Fläche nutzt die ADAPTIVEN Tokens
  /// (`ink` / `softInk` / `mutedInk`, Akzent-Grün = `moss`), NICHT die
  /// `onCtaSurface`-Familie — die wäre im Light-Mode falsch herum.
  ///
  /// Ersetzt pro Card den kompletten
  /// `.background(…).overlay(border).clipShape(…).shadow(…)`-Block.
  func gainsHeroGlass(
    accent: Color,
    corner: CGFloat = GainsRadius.hero,
    material: GainsMaterial = .regular,
    depth: GainsDepth = .hero
  ) -> some View {
    let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
    return self
      .background {
        ZStack {
          // 1) Glaskörper-Undertone (adaptiv) — Boden unter dem Frost.
          shape.fill(GainsColor.glassUndertone)
          // 2) Material — der eigentliche Frost-/Durchscheineffekt.
          shape.fill(material.material)
          // 3) Lebendiger Akzent-Glow oben-leading. Normal blend, damit die
          //    Glasfläche in BEIDEN Modi farbig & freundlich getönt wird.
          shape.fill(
            RadialGradient(
              colors: [accent.opacity(0.15), accent.opacity(0.04), .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 340
            )
          )
          // 4) Zweiter, leiser Glow unten-trailing — gibt Tiefe & Leben.
          shape.fill(
            RadialGradient(
              colors: [accent.opacity(0.06), .clear],
              center: .bottomTrailing,
              startRadius: 0,
              endRadius: 280
            )
          )
          // 5) Inner-Light-Pool oben-leading — der Glas-Sheen (adaptiv, kein
          //    Blow-out: glassInnerLight ist im Light-Mode bewusst gedrosselt).
          shape.fill(
            LinearGradient(
              colors: [GainsColor.glassInnerLight, .clear],
              startPoint: .topLeading,
              endPoint: .center
            )
          )
          // 5b) Specular-Hotspot — enger Light-Catch oben-leading für Brillanz.
          shape.fill(
            RadialGradient(
              colors: [GainsColor.glassSpecular, .clear],
              center: .topLeading,
              startRadius: 0,
              endRadius: 170
            )
          )
        }
      }
      .overlay {
        // 6) Glas-Edge-Highlight (3-stufiger Rim: hell → neutral → dunkel) —
        //    Lichtbrechung an der oberen und unteren Bruchkante.
        shape.stroke(
          LinearGradient(
            colors: [
              GainsColor.glassEdgeTop,
              GainsColor.glassEdgeMid,
              GainsColor.glassEdgeBottom
            ],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 0.9
        )
      }
      .overlay {
        // 7) Dezenter Akzent-Rahmen — markiert die Card als „aktive Fläche".
        shape.strokeBorder(
          LinearGradient(
            colors: [accent.opacity(0.32), accent.opacity(0.08)],
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: GainsBorder.accent
        )
      }
      .clipShape(shape)
      .compositingGroup()
      // 8) Lebendiger Akzent-Halo + neutraler Tiefen-Schatten.
      .shadow(color: accent.opacity(0.10), radius: 16, x: 0, y: 0)
      .gainsDepthShadow(depth)
  }
}

// MARK: - Top-Light (implizite Lichtquelle)

extension View {
  /// Subtile Lichtquelle am oberen Rand einer Surface — als zusätzlicher
  /// Overlay-Layer, der die Glass-Optik vom Tab-Strip / Header-Bereich
  /// nach unten "abstrahlen" lässt. Wird intern von `GainsAppBackground`
  /// genutzt, kann aber auch lokal auf Sheets gelegt werden.
  func gainsTopLight(intensity: CGFloat = 0.10) -> some View {
    self.overlay(alignment: .top) {
      LinearGradient(
        colors: [
          Color.white.opacity(intensity),
          Color.white.opacity(intensity * 0.4),
          Color.white.opacity(0)
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 240)
      .blendMode(.plusLighter)
      .allowsHitTesting(false)
      .ignoresSafeArea(edges: .top)
    }
  }
}

// MARK: - Signal-Pulse (atmender Live-Indikator)

/// Sanft pulsierender Dot — wird überall dort eingesetzt, wo "Live"
/// signalisiert wird (Workout aktiv, Lauf aktiv, BPM-Feed). Ersetzt
/// das ältere `PulsingDot` durch eine ruhigere Atmungs-Animation
/// und einen Halo-Glow, der zur Liquid-Optik passt.
struct GainsSignalDot: View {
  let active: Bool
  let color: Color
  let size: CGFloat

  init(active: Bool = true, color: Color = GainsColor.signal, size: CGFloat = 8) {
    self.active = active
    self.color = color
    self.size = size
  }

  @State private var breath: CGFloat = 0

  var body: some View {
    ZStack {
      if active {
        Circle()
          .fill(color.opacity(0.35))
          .frame(width: size * 2.4, height: size * 2.4)
          .scaleEffect(0.6 + breath * 0.6)
          .opacity(0.35 + breath * 0.45)
          .blur(radius: 4)
      }
      Circle()
        .fill(active ? color : GainsColor.mutedInk)
        .frame(width: size, height: size)
        .overlay(
          Circle()
            .stroke(Color.white.opacity(active ? 0.45 : 0.10), lineWidth: 0.6)
        )
    }
    .frame(width: size * 2.4, height: size * 2.4)
    // drawingGroup: Halo + Core als eine GPU-Textur — verhindert,
    // dass jeder Breath-Tick die Blur-Berechnung neu auslöst.
    .drawingGroup()
    .onAppear {
      guard active else { return }
      withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
        breath = 1
      }
    }
  }
}

// MARK: - Hero-Numerik

/// Riesige Display-Numerik mit optionaler Einheit, optionalem
/// Eyebrow-Label und subtilem Glow.
///
/// Verwendung:
///   GainsHeroNumeric("1:42", unit: "Pause", eyebrow: "Erholung")
///   GainsHeroNumeric("128", unit: "kg")
///
/// Variante `style: .massive` für Tracker-Hero (80pt), `style: .display`
/// für Hub-Hero (56pt), `style: .glance` für Tile-Hero (40pt).
struct GainsHeroNumeric: View {
  enum Style {
    case glance     // 40pt — Tile-Hero
    case display    // 56pt — Hub-Hero
    case massive    // 80pt — Tracker-Hero

    var size: CGFloat {
      switch self {
      case .glance:  return 40
      case .display: return 56
      case .massive: return 80
      }
    }
    var unitSize: CGFloat {
      switch self {
      case .glance:  return 12
      case .display: return 14
      case .massive: return 18
      }
    }
  }

  let value: String
  let unit: String?
  let eyebrow: String?
  let accent: Color
  let style: Style
  let glow: Bool

  init(
    _ value: String,
    unit: String? = nil,
    eyebrow: String? = nil,
    accent: Color = GainsColor.ink,
    style: Style = .display,
    glow: Bool = false
  ) {
    self.value = value
    self.unit = unit
    self.eyebrow = eyebrow
    self.accent = accent
    self.style = style
    self.glow = glow
  }

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
      if let eyebrow {
        Text(eyebrow).gainsEyebrow(accent.opacity(0.78))
      }
      HStack(alignment: .lastTextBaseline, spacing: 6) {
        Text(value)
          .font(.system(size: style.size, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(accent)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .shadow(color: glow ? accent.opacity(0.35) : .clear, radius: glow ? 14 : 0)
        if let unit {
          Text(unit)
            .font(.system(size: style.unitSize, weight: .semibold, design: .monospaced))
            .tracking(GainsTracking.eyebrowTight)
            .textCase(.uppercase)
            .foregroundStyle(GainsColor.softInk)
            .padding(.bottom, style.size * 0.18)
        }
      }
    }
  }
}

// MARK: - Glass-Chip (Liquid-Variante des bisherigen GainsGlowChip)

/// Kleine, schwebende Glass-Pille — z.B. für "LIVE", "PAUSE", "+15s".
/// Ersetzt nicht den bestehenden `GainsGlowChip`, sondern bietet eine
/// modernere Alternative für neue Stellen.
struct GainsGlassChip: View {
  let label: String
  let icon: String?
  let accent: Color
  let isProminent: Bool

  init(_ label: String, icon: String? = nil, accent: Color = GainsColor.signal, isProminent: Bool = false) {
    self.label = label
    self.icon = icon
    self.accent = accent
    self.isProminent = isProminent
  }

  var body: some View {
    HStack(spacing: 4) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: 10, weight: .bold))
      }
      Text(label)
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .tracking(GainsTracking.eyebrowTight)
        .textCase(.uppercase)
    }
    .foregroundStyle(isProminent ? GainsColor.onLime : accent)
    .padding(.horizontal, GainsSpacing.xs)
    .padding(.vertical, 4)
    .background {
      Capsule()
        .fill(
          isProminent
            ? AnyShapeStyle(accent)
            : AnyShapeStyle(.ultraThinMaterial)
        )
    }
    .overlay {
      Capsule()
        .stroke(
          isProminent
            ? Color.white.opacity(0.18)
            : accent.opacity(0.42),
          lineWidth: 0.8
        )
    }
    .shadow(color: isProminent ? accent.opacity(0.28) : .clear, radius: 8, x: 0, y: 0)
  }
}

// MARK: - Liquid-Background

/// Premium-Background für Tracker/Hero-Screens. Anders als
/// `GainsAppBackground` (App-Standard) hat das Liquid-Background
/// einen markanten Top-Light-Cone, der das Hero-Element bewusst
/// in Szene setzt. Wird selektiv eingesetzt, nicht überall.
struct GainsLiquidBackground: View {
  let accent: Color

  init(accent: Color = GainsColor.signal) {
    self.accent = accent
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        // 1) Tief-Schwarz-Basis mit minimalem vertikalem Gradient.
        LinearGradient(
          colors: [
            Color(red: 0.02, green: 0.025, blue: 0.03),
            Color(red: 0.012, green: 0.015, blue: 0.02)
          ],
          startPoint: .top,
          endPoint: .bottom
        )
        .ignoresSafeArea()

        // 2) Großer Akzent-Lichtkegel oben-mitte — die "Bühne".
        RadialGradient(
          colors: [
            accent.opacity(0.16),
            accent.opacity(0.06),
            accent.opacity(0)
          ],
          center: .init(x: 0.5, y: -0.05),
          startRadius: 4,
          endRadius: proxy.size.height * 0.85
        )
        .blendMode(.plusLighter)
        .ignoresSafeArea()

        // 3) Sehr weiches warmes Inner-Light oben-leading.
        RadialGradient(
          colors: [
            Color(red: 1, green: 0.96, blue: 0.86).opacity(0.05),
            Color.clear
          ],
          center: .init(x: 0.15, y: 0.05),
          startRadius: 4,
          endRadius: max(proxy.size.width, 480) * 0.9
        )
        .blendMode(.plusLighter)
        .ignoresSafeArea()

        // 4) Cool-Tone-Pool unten — gibt der Komposition Tiefe.
        RadialGradient(
          colors: [
            GainsColor.accentCool.opacity(0.06),
            Color.clear
          ],
          center: .init(x: 0.85, y: 1.0),
          startRadius: 4,
          endRadius: proxy.size.height * 0.7
        )
        .blendMode(.plusLighter)
        .ignoresSafeArea()

        // 5) Vignette außen.
        RadialGradient(
          colors: [
            Color.black.opacity(0),
            Color.black.opacity(0.55)
          ],
          center: .center,
          startRadius: 200,
          endRadius: max(proxy.size.width, proxy.size.height)
        )
        .blendMode(.multiply)
        .ignoresSafeArea()
      }
      .allowsHitTesting(false)
    }
    .ignoresSafeArea()
  }
}

// MARK: - Numeric-Marquee (rolling odometer)

/// Numerischer Wechsel mit kurzem Slide-up-Effekt — fühlt sich an wie
/// ein analoger Zähler, der weiterspringt. Wird in Tracker-Zählern
/// und Set-Counts verwendet.
struct GainsRollingNumber: View {
  let value: String
  let font: Font
  let color: Color

  init(_ value: String, font: Font = GainsFont.metric, color: Color = GainsColor.ink) {
    self.value = value
    self.font = font
    self.color = color
  }

  var body: some View {
    Text(value)
      .font(font)
      .monospacedDigit()
      .foregroundStyle(color)
      .contentTransition(.numericText())
      .animation(GainsMotion.spring, value: value)
  }
}
