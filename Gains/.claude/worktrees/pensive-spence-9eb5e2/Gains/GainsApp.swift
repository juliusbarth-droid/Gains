import SwiftUI

@main
struct GainsApp: App {
  @StateObject private var store = GainsStore()
  @StateObject private var navigation = AppNavigationStore()
  @AppStorage(GainsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

  // Singleton früh initialisieren, damit CoreBluetooth beim App-Start bereit ist.
  // Der eigentliche Scan startet erst, wenn der Nutzer auf "Suche starten" tippt.
  private let ble = BLEHeartRateManager.shared

  init() {
    // A7: MetricKit-Subscriber registrieren — erfasst Crashes/Hangs ab jetzt.
    // Apple sendet die Reports asynchron (≈ 1× pro Tag).
    MetricKitObserver.shared.register()
  }

  // Notifications nach App-Start einmal neu aufstellen, sobald der Store
  // geladen ist. Das stellt sicher, dass nach Update / Re-Install die
  // Reminder wieder im System eingetragen sind. Nutzt den existierenden
  // notificationsEnabled-Flag — wenn er aus ist, cancelt der Manager.
  private func bootstrapNotifications() {
    NotificationsManager.shared.refreshSchedule(for: store)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .environmentObject(navigation)
        // A8: App ist Dark-Only. Der GainsAppearanceMode-State bleibt im
        // Store erhalten (Migration / Settings-Zukunft), wird hier aber
        // hartverdrahtet überschrieben — der ProfileView-Picker ist weg.
        .preferredColorScheme(.dark)
        .task { bootstrapNotifications() }
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
