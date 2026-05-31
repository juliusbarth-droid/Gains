import SwiftUI
import UIKit

struct ContentView: View {
  @EnvironmentObject private var navigation: AppNavigationStore
  @EnvironmentObject private var store: GainsStore
  // 2026-05-14 (Audit-Loop 5): Globaler Error-Presenter. Wird hier auf der
  // Root-View instanziiert, damit Banner ÜBER allen Sheets/Tabs liegt.
  @StateObject private var errorPresenter = GainsErrorPresenter.shared
  // Fix 2026-05-16: ScenePhase beobachten um beim App-Backgrounding
  // einen sofortigen Force-Save auszulösen — der Standard-Debounce (0.8s)
  // kann durch OS-Termination abgeschnitten werden, bevor er feuert.
  @Environment(\.scenePhase) private var scenePhase

  init() {
    // 2026-05-14 (Design-Loop 1): Tab-Bar als echte Glass-Surface.
    //
    // 2026-05-29 (Light-Mode-Pass v3): Tab-Bar ist jetzt vollständig adaptiv.
    // Vorher: `systemUltraThinMaterialDark` war im Light-Mode ein schwarzes
    // Panel auf weißem Hintergrund — der stärkste Mode-Clash der ganzen App.
    // Jetzt:
    //   • UITraitCollection-aware Blur: Dark → systemUltraThinMaterialDark,
    //     Light → systemUltraThinMaterial. Lässt den Background korrekt
    //     durchscheinen.
    //   • Background-Tint adaptive via card-Token (light: #ECEFF5, dark:
    //     #0A0A0A) — dezente Tönung, die zur jeweiligen App-Bühne passt.
    //   • .toolbarColorScheme(.dark) entfernt — Icons/Labels nutzen die
    //     system-adaptive Farbe. Selected-Lime bleibt explizit gesetzt.
    let appearance = UITabBarAppearance()
    appearance.configureWithTransparentBackground()
    // Adaptive Blur: Dark = dunkles Material, Light = helles Material
    appearance.backgroundEffect = UIBlurEffect(
      style: UITraitCollection.current.userInterfaceStyle == .dark
        ? .systemUltraThinMaterialDark
        : .systemUltraThinMaterial
    )
    appearance.backgroundColor = UIColor(GainsColor.card).withAlphaComponent(0.55)
    // 2026-05-14 (Polish-Loop 10): Lime-Hairline am oberen TabBar-Rand
    // ist die einzige permanente Brand-Touch in der App-Chrome. Vorher
    // 0.18 — zu dezent für die neue Glow-Sprache. Jetzt 0.28 plus
    // leichter Lift in der Farbe selbst, damit der Saum als „LightLine"
    // gelesen wird statt als toter Rahmen.
    appearance.shadowColor = UIColor(GainsColor.lime).withAlphaComponent(0.28)

    let itemAppearance = UITabBarItemAppearance()
    itemAppearance.normal.iconColor = UIColor(GainsColor.softInk)
    itemAppearance.normal.titleTextAttributes = [
      .foregroundColor: UIColor(GainsColor.softInk),
      .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
      .kern: 0.6
    ]
    itemAppearance.selected.iconColor = UIColor(GainsColor.lime)
    itemAppearance.selected.titleTextAttributes = [
      .foregroundColor: UIColor(GainsColor.lime),
      .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .heavy),
      .kern: 0.8
    ]
    appearance.stackedLayoutAppearance = itemAppearance
    appearance.inlineLayoutAppearance = itemAppearance
    appearance.compactInlineLayoutAppearance = itemAppearance

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
  }

  var body: some View {
    ZStack(alignment: .top) {
      GainsAppBackground()

      TabView(selection: $navigation.selectedTab) {
        HomeView()
          .tag(AppTab.home)
          .tabItem {
            Label(AppTab.home.title, systemImage: "sparkles")
          }

        GymView()
          .tag(AppTab.gym)
          .tabItem {
            Label(AppTab.gym.title, systemImage: "dumbbell.fill")
          }

        WorkoutHubView()
          .tag(AppTab.run)
          .tabItem {
            Label(AppTab.run.title, systemImage: "figure.run")
          }

        NutritionTrackerView()
          .tag(AppTab.nutrition)
          .tabItem {
            Label(AppTab.nutrition.title, systemImage: "fork.knife")
          }

        // Fortschritt-Tab entfernt: Fortschritt ist jetzt nur noch über
        // den Home-Screen erreichbar (aufklappbarer Bereich), damit der
        // Tab-Bar fokussierter bleibt und Details nur auf Klick erscheinen.
        //
        // Community lebt bewusst NICHT in der Tab-Bar (Stand 2026-05-30):
        // Statt eines 5. Tabs ist der Community-Hub über einen Einstieg auf
        // dem Home-Screen erreichbar (`navigation.openCommunity()`) und wird
        // weiter unten als globaler `.fullScreenCover` (CommunityHubView)
        // präsentiert. Hält die Tab-Bar auf 4 fokussierte Tabs.
      }

      // 2026-05-14 (Audit-Loop 5): Error-Banner-Overlay-Layer. Liegt
      // visuell über dem Tab-Content, aber unter modalen Sheets — was
      // gewünscht ist, weil Sheets ihren eigenen Banner brauchen könnten.
      GainsErrorBanner(presenter: errorPresenter)
        .environmentObject(errorPresenter)
    }
    // 2026-05-15: Completion-Ritual global — feuert egal aus welchem Tab
    // der Workout beendet wird (Gym-Tab und Home-Tab). Trigger bleibt
    // `store.pendingCompletionRitual`; CompletionRitualView setzt es zurück.
    .fullScreenCover(item: $store.pendingCompletionRitual) { summary in
      CompletionRitualView(summary: summary)
        .environmentObject(store)
    }
    .tint(GainsColor.lime)
    .environmentObject(errorPresenter)
    // Design-Loop 1 (2026-05-14): Material statt opaker Card-Background —
    // die Tab-Bar wirkt jetzt wie ein über die App schwebendes HUD-Element
    // mit dezenter Vibrancy.
    .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    .toolbarBackground(.visible, for: .tabBar)
    // 2026-05-29 (Light-Mode-Pass v3): .toolbarColorScheme(.dark) entfernt.
    // Im Light-Mode erzwang das weiße Icons auf schwarzer Leiste — falsch.
    // Icons und Labels nutzen jetzt system-adaptive Farben; Selected-Lime
    // ist weiterhin explizit via UITabBarItemAppearance gesetzt.
    .sheet(
      item: Binding(
        get: { navigation.pendingCaptureKind },
        set: { navigation.pendingCaptureKind = $0 }
      )
    ) { kind in
      NavigationStack {
        CaptureSheet(initialKind: kind)
          .environmentObject(store)
          .environmentObject(navigation)
      }
      .presentationDetents([.large])
    }
    // Globale Fullscreen-Wochenplan-Sheet — wird von ProgressView,
    // ProfileView und allen Coach-Brief-CTAs via AppNavigationStore
    // getriggert. Präsentiert über dem aktuellen Tab, ohne Tab-Wechsel.
    .fullScreenCover(
      isPresented: Binding(
        get: { navigation.showsWeekPlanFullscreen },
        set: { navigation.showsWeekPlanFullscreen = $0 }
      )
    ) {
      WeekPlanFullscreenView()
        .environmentObject(store)
        .environmentObject(navigation)
    }
    // Community-Hub global präsentiert (Einstieg über Home). Liegt — wie der
    // Wochenplan — über dem aktuellen Tab, ohne Tab-Wechsel. Die Tab-Bar
    // bleibt bei 4 Tabs.
    .fullScreenCover(
      isPresented: Binding(
        get: { navigation.showsCommunity },
        set: { navigation.showsCommunity = $0 }
      )
    ) {
      CommunityHubView()
        .environmentObject(store)
        .environmentObject(navigation)
    }
    // H2-Fix (2026-05-01): Wenn der User manuell die Tab-Bar wechselt
    // (z. B. von Home auf Gym), schließen wir ein evtl. offenes Capture-
    // Sheet, damit es nicht über einem fremden Tab schwebt. Programm-
    // gesteuerte Tab-Wechsel räumen bereits in AppNavigationStore auf;
    // dieser onChange ist die Defensive-Linie für TabBar-Taps.
    .onChange(of: navigation.selectedTab) { _, _ in
      if navigation.pendingCaptureKind != nil {
        navigation.pendingCaptureKind = nil
      }
    }
    // Fix 2026-05-16: Force-Save beim Backgrounding. Der debounced
    // scheduleSave() (0.8s) riskiert Datenverlust, wenn iOS die App
    // im Hintergrund terminiert bevor der Timer gefeuert hat.
    // `.inactive` deckt sowohl Background als auch App-Switcher ab.
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .background {
        store.scheduleSave(force: true)
      }
    }
  }

}
