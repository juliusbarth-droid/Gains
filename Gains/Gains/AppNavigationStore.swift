import SwiftUI

/// Zentraler Navigations-State für die Tab-Bar und die globalen Sheets
/// (Capture, Gym-Sub-Tab-Sprünge). Hält nichts, was nur lokal in einer
/// einzigen View interessiert — solche States bleiben in der jeweiligen View.
///
/// H2-Fix (2026-05-01): Tab-Wechsel und Sheet-Präsentation müssen atomar
/// sein, sonst kann ein offenes Capture-Sheet über einem frisch
/// gewechselten Tab hängen bleiben (Race-Condition zwischen TabView-
/// Animation und sheet(item:)). Alle Tab-Wechsel laufen jetzt durch
/// `dismissOverlays()` und `goToTab(_:)`, die sauber in einer Transaktion
/// State setzen. `presentCapture` rendert auf dem AKTUELLEN Tab, weil das
/// User-erwartet ist (Home → Mahlzeit-Capture → Foto auf Home-Background).
final class AppNavigationStore: ObservableObject {
  @Published var selectedTab: AppTab = .home
  @Published var pendingCaptureKind: CaptureKind?
  @Published var pendingGymTab: GymTab?
  /// Globaler Trigger für die Fullscreen-Wochenplan-Sheet. Wird von
  /// ContentView beobachtet und als `.fullScreenCover` präsentiert —
  /// funktioniert damit aus jedem Kontext (ProgressView, ProfileView, …)
  /// ohne lokale State-Weitergabe.
  @Published var showsWeekPlanFullscreen = false
  /// Globaler Trigger für den Community-Hub. Wird von ContentView als
  /// `.fullScreenCover` präsentiert. Der Hub lebt bewusst NICHT in der
  /// Tab-Bar (Einstieg über Home), damit die 4-Tab-Fokussierung bleibt.
  @Published var showsCommunity = false

  /// Setzt alle globalen Sheet-/Sub-Tab-States zurück. Wird vor jedem
  /// Tab-Wechsel aufgerufen, damit kein altes Overlay (Capture-Sheet,
  /// Gym-Sub-Tab-Sprung) auf dem Ziel-Tab landet.
  private func dismissOverlays() {
    if pendingCaptureKind != nil { pendingCaptureKind = nil }
    if pendingGymTab != nil { pendingGymTab = nil }
  }

  /// Wechselt in den Trainings-Tab. `kraft` öffnet das Gym, `laufen` den
  /// Lauf-Hub. Default ist Kraft, weil der Home-Screen primär ins Gym
  /// verlinkt.
  func openTraining(workspace: AppWorkoutWorkspace = .kraft) {
    dismissOverlays()
    switch workspace {
    case .laufen:
      selectedTab = .run
    case .kraft:
      selectedTab = .gym
    }
  }

  /// Öffnet die Fullscreen-Wochenplan-Sheet (global via ContentView).
  /// Ersetzt den alten Tab-Switch-Ansatz — der User bleibt im Kontext
  /// und bekommt den Plan direkt als Overlay, kein Tab-Sprung.
  func openWeekPlanFullscreen() {
    if pendingCaptureKind != nil { pendingCaptureKind = nil }
    showsWeekPlanFullscreen = true
  }

  /// Springt direkt in den PLAN-Sub-Tab des Gym-Bereichs.
  /// Wird nur noch intern (GymView-Kontext) genutzt. Für alle anderen
  /// Kontexte → `openWeekPlanFullscreen()`.
  func openPlanner() {
    if pendingCaptureKind != nil { pendingCaptureKind = nil }
    pendingGymTab = .plan
    selectedTab = .gym
  }

  /// Wechselt zurück zum Home-Tab und räumt alle offenen Overlays auf.
  /// Wird z. B. nach dem Teilen eines Workout/Progress-Cards genutzt.
  func openHome() {
    dismissOverlays()
    selectedTab = .home
  }

  /// Wechselt in den Ernährungs-Tab — wird vom Home-Screen aus über die
  /// Tap-Zone der Nutrition-Card aufgerufen.
  func openNutrition() {
    dismissOverlays()
    selectedTab = .nutrition
  }

  /// Öffnet das globale Capture-Sheet mit dem gewünschten Inhaltstyp.
  /// Setzt zuerst `pendingGymTab` zurück, damit kein verwaister Sub-Tab-
  /// Sprung im Hintergrund mitschwingt.
  func presentCapture(kind: CaptureKind = .workout) {
    if pendingGymTab != nil { pendingGymTab = nil }
    pendingCaptureKind = kind
  }

  /// Reagiert auf Tab-Wechsel, die der User selbst über die TabBar auslöst
  /// (nicht über die Helper). Schließt das Capture-Sheet, damit es nicht
  /// auf einem fremden Tab erscheint.
  func handleManualTabChange(to newTab: AppTab) {
    if newTab != selectedTab {
      dismissOverlays()
    }
  }

  /// Öffnet den Community-Hub als globalen Fullscreen-Overlay (Einstieg über
  /// Home). 2026-05-30: ersetzt den 2026-05-01 entfernten Tab-Helper — der
  /// Hub ist jetzt eine eigene Surface über dem aktuellen Tab, kein Tab-Sprung.
  func openCommunity() {
    if pendingCaptureKind != nil { pendingCaptureKind = nil }
    showsCommunity = true
  }
}
