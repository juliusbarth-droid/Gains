import Foundation
import UserNotifications

/// Lokale Notifications für Gains.
///
/// Zwei Slots, beide täglich wiederkehrend:
///   • 18:00 — „Bereit fürs Training?" (motivierender Reminder)
///   • 21:00 — „Streak halten?" (letzte Chance, etwas zu loggen)
///
/// Die Manager-Methoden sind no-ops, wenn der Nutzer Notifications nicht
/// erlaubt hat oder den App-internen Toggle (`GainsStore.notificationsEnabled`)
/// ausgeschaltet hat — `refreshSchedule(for:)` cancelt dann alles.
///
/// Push-/Server-Notifications sind nicht enthalten und gehören zu Phase B.
final class NotificationsManager {
  static let shared = NotificationsManager()
  private init() {}

  enum Identifier {
    static let dailyWorkoutPrompt = "gains.notifications.dailyWorkoutPrompt"
    static let streakSave         = "gains.notifications.streakSave"

    static let all: [String] = [dailyWorkoutPrompt, streakSave]
  }

  private let center = UNUserNotificationCenter.current()

  // MARK: - Authorization

  /// Fragt den System-Prompt für lokale Notifications an. Liefert auf dem
  /// Main-Thread, ob der Nutzer zugestimmt hat. Mehrfach-Aufrufe sind sicher
  /// — iOS zeigt das Prompt nur beim ersten Mal.
  func requestAuthorization(completion: @escaping (Bool) -> Void) {
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      DispatchQueue.main.async { completion(granted) }
    }
  }

  /// Liest den aktuellen System-Status, ohne ihn zu ändern.
  func currentAuthorization(completion: @escaping (UNAuthorizationStatus) -> Void) {
    center.getNotificationSettings { settings in
      DispatchQueue.main.async { completion(settings.authorizationStatus) }
    }
  }

  // MARK: - Scheduling

  /// Setzt die Reminder neu auf, basierend auf dem aktuellen Store-Zustand.
  /// Wird beim App-Start, nach dem Onboarding-Permission-Tap, nach einem
  /// Toggle in den Settings und nach jedem `finishWorkout` / `finishRun`
  /// aufgerufen. Robust gegen Mehrfach-Aufrufe — vorhandene Requests werden
  /// vorher entfernt, sodass keine Duplikate entstehen.
  func refreshSchedule(for store: GainsStore) {
    let enabled = store.notificationsEnabled

    center.getNotificationSettings { [weak self] settings in
      guard let self else { return }
      let authorized =
        settings.authorizationStatus == .authorized
        || settings.authorizationStatus == .provisional

      // Toggle aus oder Permission verweigert → alles canceln.
      guard enabled, authorized else {
        self.center.removePendingNotificationRequests(withIdentifiers: Identifier.all)
        return
      }

      self.scheduleDailyWorkoutPrompt()
      self.scheduleStreakSave()
    }
  }

  /// Cancelt alle von uns registrierten Requests. Wird genutzt, wenn der
  /// Nutzer die Notifications komplett deaktiviert.
  func cancelAll() {
    center.removePendingNotificationRequests(withIdentifiers: Identifier.all)
    center.removeDeliveredNotifications(withIdentifiers: Identifier.all)
  }

  // MARK: - Private

  private func scheduleDailyWorkoutPrompt() {
    let content = UNMutableNotificationContent()
    content.title = "Bereit fürs Training?"
    content.body  = "Auch ein kurzer Slot zählt. Tipp Gains an und leg los."
    content.sound = .default

    schedule(
      identifier: Identifier.dailyWorkoutPrompt,
      content: content,
      hour: 18,
      minute: 0
    )
  }

  private func scheduleStreakSave() {
    let content = UNMutableNotificationContent()
    content.title = "Streak halten?"
    content.body  = "Letzte Chance heute — Workout, Lauf oder Mahlzeit eintragen."
    content.sound = .default

    schedule(
      identifier: Identifier.streakSave,
      content: content,
      hour: 21,
      minute: 0
    )
  }

  private func schedule(
    identifier: String,
    content: UNNotificationContent,
    hour: Int,
    minute: Int
  ) {
    // Vorhandenen Request mit gleicher ID immer erst entfernen — sonst
    // ignoriert iOS den neuen `add`-Aufruf still.
    center.removePendingNotificationRequests(withIdentifiers: [identifier])

    var components = DateComponents()
    components.hour = hour
    components.minute = minute
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

    let request = UNNotificationRequest(
      identifier: identifier,
      content: content,
      trigger: trigger
    )
    center.add(request, withCompletionHandler: nil)
  }
}
