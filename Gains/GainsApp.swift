import SwiftUI

@main
struct GainsApp: App {
  @StateObject private var store = GainsStore()
  @StateObject private var navigation AppNavigationStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(store)
        .environmentObject(navigation)
        .preferredColorScheme(store.appearanceMode.preferredColorScheme)
    }
  }
}
