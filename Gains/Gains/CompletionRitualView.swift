import SwiftUI

// MARK: - CompletionRitualView (Brand-Loop 5, 2026-05-14)
//
// 3-Sekunden-Ritual nach einem abgeschlossenen Workout. Laut Master Design
// Prompt:
//
//   • Streak-Numerik animiert um +1 hoch
//   • EIN Quiet-Pride-Stat („47 Sessions diesen Quartal")
//   • EIN Success-Haptik-Tick — kein Konfetti, kein Feuerwerk
//   • Auto-Return nach 3 s zurück zur Home
//
// Wird von ContentView als `.fullScreenCover(item: $store.pendingCompletionRitual)`
// montiert (tab-agnostisch). Beim Auto-Dismiss wird `pendingCompletionRitual = nil` gesetzt.

struct CompletionRitualView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let summary: CompletedWorkoutSummary

  /// Animated Streak-Value, der von oldStreak → newStreak hochzählt.
  @State private var displayedStreak: Int = 0
  /// Opacity-Stufen für die Reveal-Choreografie.
  @State private var headlineOpacity: Double = 0
  @State private var streakOpacity: Double = 0
  @State private var statOpacity: Double = 0
  @State private var glowIntensity: Double = 0

  /// Berechnet aus der Workout-History den Quiet-Pride-Stat — bewusst eine
  /// einzelne, kalibrierte Aussage statt einer Stat-Wolke.
  private var prideStat: String {
    let calendar = Calendar.current
    let now = Date()
    // Anzahl Sessions im aktuellen Quartal.
    let comps = calendar.dateComponents([.year, .month], from: now)
    let month = (comps.month ?? 1)
    let quarterMonth = ((month - 1) / 3) * 3 + 1
    var startComps = DateComponents()
    startComps.year = comps.year
    startComps.month = quarterMonth
    startComps.day = 1
    let quarterStart = calendar.date(from: startComps) ?? now
    let count = store.workoutHistory.filter { $0.finishedAt >= quarterStart }.count
    if count <= 1 {
      // Beim ersten Workout des Quartals: noch keine „47 Sessions"-Aussage —
      // stattdessen ein ruhiger Anker.
      return "Erstes Workout in diesem Quartal."
    }
    return "\(count) Sessions in diesem Quartal."
  }

  var body: some View {
    let pride = prideStat  // O(n) filter — compute once, reuse in Text + a11y
    return ZStack {
      GainsColor.background.ignoresSafeArea()

      // 2026-05-14 (Polish-Loop 15): Drei gestapelte Radial-Glows + ein
      // subtiler Top-Light-Sweep. Ergebnis: das Ritual fühlt sich an
      // wie eine kurz beleuchtete Bühne, nicht wie ein flacher Screen.
      //
      // - Primary-Glow zentriert hinter der Streak-Numerik
      // - Off-axis Counter-Glow oben-leading (kleiner Radius)
      // - Off-axis Counter-Glow unten-trailing (kleiner Radius)
      // - Top-Light-Sweep (warmer Weiß-Reflex an der oberen Kante)
      RadialGradient(
        colors: [
          GainsColor.lime.opacity(glowIntensity * 0.40),
          GainsColor.lime.opacity(glowIntensity * 0.10),
          GainsColor.lime.opacity(0)
        ],
        center: .center,
        startRadius: 0,
        endRadius: 360
      )
      .ignoresSafeArea()
      .allowsHitTesting(false)

      RadialGradient(
        colors: [GainsColor.lime.opacity(glowIntensity * 0.18), .clear],
        center: .init(x: 0.18, y: 0.16),
        startRadius: 0,
        endRadius: 240
      )
      .ignoresSafeArea()
      .allowsHitTesting(false)
      .blendMode(.plusLighter)

      RadialGradient(
        colors: [GainsColor.lime.opacity(glowIntensity * 0.14), .clear],
        center: .init(x: 0.82, y: 0.86),
        startRadius: 0,
        endRadius: 220
      )
      .ignoresSafeArea()
      .allowsHitTesting(false)
      .blendMode(.plusLighter)

      LinearGradient(
        colors: [Color.white.opacity(glowIntensity * 0.05), Color.clear],
        startPoint: .top,
        endPoint: .center
      )
      .ignoresSafeArea()
      .allowsHitTesting(false)
      .blendMode(.plusLighter)

      VStack(spacing: GainsSpacing.l) {
        Text("STREAK")
          .font(GainsFont.eyebrow)
          .tracking(GainsTracking.eyebrow)
          .foregroundStyle(GainsColor.softInk)
          .opacity(headlineOpacity)

        Text("\(displayedStreak)")
          .gainsHeroDisplay(GainsColor.lime, size: .megaHero)
          .opacity(streakOpacity)
          .scaleEffect(streakOpacity)

        VStack(spacing: GainsSpacing.xs) {
          Text(summary.title)
            .font(GainsFont.title)
            .foregroundStyle(GainsColor.ink)
          Text(pride)
            .font(GainsFont.caption)
            .foregroundStyle(GainsColor.softInk)
        }
        .multilineTextAlignment(.center)
        .opacity(statOpacity)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(GainsSpacing.l)
    }
    .preferredColorScheme(.dark)
    .task {
      await runRitual()
    }
    .onTapGesture {
      // Master-Prompt: keine „Are-you-sure"-Confirmations für low-stakes
      // Aktionen. Tap überall = überspringen.
      dismissRitual()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Workout abgeschlossen. Streak \(store.streakDays) Tage. \(pride)")
  }

  // MARK: - Ritual-Choreografie

  /// Drei-Sekunden-Reveal:
  ///   t=0.00s — Background-Glow startet
  ///   t=0.20s — „STREAK"-Eyebrow blendet ein
  ///   t=0.40s — Streak-Numerik blendet ein (zählt sich gleich hoch)
  ///   t=1.00s — Quiet-Pride-Stat blendet ein, Success-Haptik
  ///   t=3.00s — Auto-Dismiss
  private func runRitual() async {
    // Streak-Anfang berechnen: aktueller Wert minus 1 (das neue Workout
    // hat ihn gerade hochgesetzt). Bei Streak 1 starten wir bei 0 → 1.
    let target = store.streakDays
    displayedStreak = max(0, target - 1)

    withAnimation(.easeOut(duration: 0.6)) {
      glowIntensity = 1.0
    }
    try? await Task.sleep(nanoseconds: 200_000_000)
    guard !Task.isCancelled else { return }
    withAnimation(.easeOut(duration: 0.25)) { headlineOpacity = 1 }

    try? await Task.sleep(nanoseconds: 200_000_000)
    guard !Task.isCancelled else { return }
    withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
      streakOpacity = 1
    }

    // Streak-Counter incrementieren — letzte Stufe per Spring, damit das
    // „+1" spürbar ist.
    try? await Task.sleep(nanoseconds: 250_000_000)
    guard !Task.isCancelled else { return }
    if target > displayedStreak {
      withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
        displayedStreak = target
      }
      // Success-Haptik exakt zum Increment.
      UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    try? await Task.sleep(nanoseconds: 350_000_000)
    guard !Task.isCancelled else { return }
    withAnimation(.easeOut(duration: 0.32)) { statOpacity = 1 }

    // Auto-Dismiss bei 3 s gesamt
    try? await Task.sleep(nanoseconds: 1_900_000_000)
    guard !Task.isCancelled else { return }
    dismissRitual()
  }

  private func dismissRitual() {
    store.pendingCompletionRitual = nil
  }
}
