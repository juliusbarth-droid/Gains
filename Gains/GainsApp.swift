import SwiftUI

@main
struct GainsApp: App {
  @StateObject private var store = GainsStore()
  @StateObject private var navigation = AppNavigationStore()
  @AppStorage("gains_hasCompletedOnboarding") private var hasCompletedOnboarding = false

  // Singleton früh initialisieren, damit CoreBluetooth beim App-Start bereit ist.
  // Der eigentliche Scan startet erst, wenn der Nutzer auf "Suche starten" tippt.
  private let ble = BLEHeartRateManager.shared

  init() {
    // A7: MetricKit-Subscriber registrieren — erfasst Crashes/Hangs ab jetzt.
    // Apple sendet die Reports asynchron (≈ 1× pro Tag).
    MetricKitObserver.shared.register()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .environmentObject(navigation)
        .preferredColorScheme(store.appearanceMode.preferredColorScheme)
        .fullScreenCover(isPresented: Binding(
          get: { !hasCompletedOnboarding },
          set: { newValue in hasCompletedOnboarding = !newValue }
        )) {
          OnboardingView()
            .environmentObject(store)
        }
    }
  }
}
