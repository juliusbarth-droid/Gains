import SwiftUI
import UIKit

// A7: Wrapper-Modell für das Diagnose-Share-Sheet — Identifiable, damit
// `.sheet(item:)` korrekt anspringt.
struct DiagnosticsShareItem: Identifiable {
  let id = UUID()
  let text: String
}

// A7: Wrapper für `UIActivityViewController` — gibt den Diagnose-Text-Report
// als Share-Aktion (Mail/Messages/Files) raus.
struct DiagnosticsShareSheet: UIViewControllerRepresentable {
  let text: String

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [text], applicationActivities: nil)
  }

  func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ProfileView: View {
  @EnvironmentObject private var store: GainsStore
  @ObservedObject private var ble = BLEHeartRateManager.shared
  @ObservedObject private var diagnostics = MetricKitObserver.shared
  @State private var showWearablePicker = false
  @State private var showsResetConfirmation = false
  @State private var diagnosticsShareItem: DiagnosticsShareItem? = nil

  var body: some View {
    ZStack {
      GainsColor.background.ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 22) {
          header
          statsRow
          trackerSection
          goalsSection
          settingsSection
          diagnosticsSection
          #if DEBUG
          debugSection
          #endif
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 28)
      }
    }
    .sheet(item: $diagnosticsShareItem) { item in
      DiagnosticsShareSheet(text: item.text)
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 16) {
      Circle()
        .fill(GainsColor.ctaSurface)
        .frame(width: 64, height: 64)
        .overlay {
          Text(store.userName.isEmpty ? "?" : String(store.userName.prefix(1)).uppercased())
            .font(GainsFont.display(28))
            .foregroundStyle(GainsColor.lime)
        }

      VStack(alignment: .leading, spacing: 6) {
        Text(store.userName)
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)

        SlashLabel(
          parts: ["STREAK", "\(store.streakDays) TAGE", "REKORD \(store.recordDays)"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk
        )
      }

      Spacer()
    }
    .padding(18)
    .gainsCardStyle()
  }

  // MARK: - Stats

  private var statsRow: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["DEINE", "STATS"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      HStack(spacing: 10) {
        StatCard(
          title: "SESSIONS",
          value: "\(store.workoutHistory.count)",
          valueAccent: false,
          subtitle: "Gesamt",
          background: GainsColor.card,
          foreground: GainsColor.ink
        )

        StatCard(
          title: "VOLUMEN",
          value: String(format: "%.1f T", store.weeklyVolumeTons),
          valueAccent: false,
          subtitle: "7 Tage",
          background: GainsColor.card,
          foreground: GainsColor.ink
        )

        StatCard(
          title: "PRs",
          value: "+ \(store.personalRecordCount)",
          valueAccent: false,
          subtitle: "Rekorde",
          background: GainsColor.lime,
          foreground: GainsColor.onLime
        )
      }
    }
  }

  // MARK: - Tracker

  private var trackerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TRACKER", "VERBINDEN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      // ── Bluetooth-Sensor-Zeile (echte BLE-Verbindung) ───────────────
      Button { showWearablePicker = true } label: {
        bleTrackerRow
      }
      .buttonStyle(.plain)
      .sheet(isPresented: $showWearablePicker) {
        WearablePickerSheet()
      }

      // ── HealthKit + App-basierte Tracker ─────────────────────────────
      VStack(spacing: 1) {
        ForEach(Array(store.trackerOptions.enumerated()), id: \.element.id) { index, tracker in
          Button {
            store.toggleTrackerConnection(tracker.id)
          } label: {
            trackerRow(tracker: tracker)
          }
          .buttonStyle(.plain)

          if index < store.trackerOptions.count - 1 {
            Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
          }
        }
      }
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(GainsColor.border.opacity(0.65), lineWidth: 1)
      )
    }
  }

  // Zeile für echte BLE-Geräte (Polar, Garmin, Wahoo …)
  private var bleTrackerRow: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(ble.isConnected ? GainsColor.lime.opacity(0.18) : GainsColor.elevated)
          .frame(width: 36, height: 36)
        Image(systemName: ble.isConnected ? "heart.fill" : "sensor.tag.radiowaves.forward.fill")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(ble.isConnected ? GainsColor.lime : GainsColor.softInk)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(ble.connectedDevice?.name ?? "Bluetooth HR-Sensor")
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.ink)

        if ble.isConnected, let bpm = ble.liveHeartRate {
          Text("\(bpm) bpm · Live")
            .font(GainsFont.label(10))
            .tracking(1.0)
            .foregroundStyle(GainsColor.lime)
        } else {
          Text(ble.isConnected ? "Verbunden · keine HF" : "Polar · Garmin · Wahoo · u.v.m.")
            .font(GainsFont.label(10))
            .tracking(1.0)
            .foregroundStyle(GainsColor.softInk)
        }
      }

      Spacer()

      HStack(spacing: 6) {
        if ble.isConnected {
          Circle()
            .fill(GainsColor.lime)
            .frame(width: 6, height: 6)
        }
        Text(ble.isConnected ? "VERBUNDEN" : "EINRICHTEN")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(ble.isConnected ? GainsColor.onLime : GainsColor.lime)
          .frame(height: 30)
          .padding(.horizontal, 10)
          .background(ble.isConnected ? GainsColor.lime : GainsColor.elevated)
          .clipShape(Capsule())
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(
          ble.isConnected ? GainsColor.lime.opacity(0.4) : GainsColor.border.opacity(0.65),
          lineWidth: 1
        )
    )
  }

  private func trackerRow(tracker: TrackerDevice) -> some View {
    let isConnected = store.isTrackerConnected(tracker.id)
    return HStack(spacing: 12) {
      Circle()
        .fill(Color(hex: tracker.accentHex).opacity(0.18))
        .frame(width: 36, height: 36)
        .overlay {
          Circle()
            .fill(Color(hex: tracker.accentHex))
            .frame(width: 10, height: 10)
        }

      VStack(alignment: .leading, spacing: 2) {
        Text(tracker.name)
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.ink)

        Text(tracker.source)
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      Text(isConnected ? "VERBUNDEN" : "VERBINDEN")
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(isConnected ? GainsColor.ink : GainsColor.lime)
        .frame(width: 96, height: 30)
        .background(isConnected ? GainsColor.lime : GainsColor.elevated)
        .clipShape(Capsule())
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  // MARK: - Goals

  private var goalsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["ZIELE", "EINSTELLUNGEN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(spacing: 1) {
        settingsRow(
          icon: "calendar.badge.checkmark",
          title: "Sessions pro Woche",
          value: "\(store.plannerSettings.sessionsPerWeek)"
        )

        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)

        settingsRow(
          icon: "clock",
          title: "Session-Länge",
          value: "\(store.plannerSettings.preferredSessionLength) Min"
        )

        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)

        settingsRow(
          icon: "target",
          title: "Fokus",
          value: store.plannerSettings.goal.title
        )

        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)

        settingsRow(
          icon: "figure.strengthtraining.traditional",
          title: "Trainingstyp",
          value: store.plannerSettings.trainingFocus.shortTitle
        )
      }
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(GainsColor.border.opacity(0.65), lineWidth: 1)
      )
    }
  }

  // MARK: - Settings

  private var settingsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["APP", "OPTIONEN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(spacing: 1) {
        Button {
          store.toggleNotificationsEnabled()
        } label: {
          settingsRow(
            icon: "bell",
            title: "Benachrichtigungen",
            value: store.notificationsEnabled ? "Ein" : "Aus"
          )
        }
        .buttonStyle(.plain)

        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)

        Button {
          store.toggleHealthAutoSyncEnabled()
        } label: {
          settingsRow(
            icon: "arrow.trianglehead.2.clockwise",
            title: "Auto-Sync",
            value: store.healthAutoSyncEnabled ? "Aktiv" : "Pausiert"
          )
        }
        .buttonStyle(.plain)

        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)

        Button {
          store.toggleStudyBasedCoachingEnabled()
        } label: {
          settingsRow(
            icon: "brain",
            title: "Coach-Empfehlungen",
            value: store.studyBasedCoachingEnabled ? "Aktiv" : "Aus"
          )
        }
        .buttonStyle(.plain)

        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)

        Button {
          store.cycleAppearanceMode()
        } label: {
          settingsRow(
            icon: "circle.lefthalf.filled",
            title: "Darstellung",
            value: store.appearanceMode.title
          )
        }
        .buttonStyle(.plain)

        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)

        settingsRow(icon: "info.circle", title: "Version", value: "1.0")
      }
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(GainsColor.border.opacity(0.65), lineWidth: 1)
      )
    }
  }

  // MARK: - Diagnose (immer sichtbar — auch in TestFlight)

  private var diagnosticsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["DIAGNOSE", "REPORTS"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      Text("Wenn die App abstürzt oder hängt, sammelt iOS automatisch einen Diagnose-Report. Du kannst ihn hier teilen, um uns beim Fehlersuchen zu helfen.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)

      VStack(spacing: 1) {
        Button {
          diagnosticsShareItem = DiagnosticsShareItem(text: diagnostics.exportableText())
        } label: {
          settingsRow(
            icon: "square.and.arrow.up",
            title: "Reports teilen",
            value: diagnostics.diagnosticCount == 0
              ? "Keine"
              : "\(diagnostics.diagnosticCount) gespeichert"
          )
        }
        .buttonStyle(.plain)
        .disabled(diagnostics.diagnosticCount == 0)

        if diagnostics.diagnosticCount > 0 {
          Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
          Button {
            diagnostics.clearStoredEntries()
          } label: {
            settingsRow(
              icon: "xmark.bin",
              title: "Reports löschen",
              value: "Lokal"
            )
          }
          .buttonStyle(.plain)
        }
      }
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(GainsColor.border.opacity(0.65), lineWidth: 1)
      )
    }
  }

  // MARK: - DEBUG

  #if DEBUG
  @AppStorage("gains_hasCompletedOnboarding") private var hasCompletedOnboarding = false

  private var debugSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["DEBUG", "DEMO-DATEN"],
        primaryColor: GainsColor.ember,
        secondaryColor: GainsColor.softInk
      )

      Text("Nur in Entwicklungs-Builds sichtbar — fürs Aufnehmen von Screenshots oder das schnelle Test-Befüllen.")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)

      VStack(spacing: 1) {
        Button {
          store.loadDemoData()
        } label: {
          settingsRow(
            icon: "wand.and.stars",
            title: "Demo-Daten laden",
            value: "Mock"
          )
        }
        .buttonStyle(.plain)

        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)

        Button {
          hasCompletedOnboarding = false
        } label: {
          settingsRow(
            icon: "arrow.uturn.backward.circle",
            title: "Onboarding erneut zeigen",
            value: "Replay"
          )
        }
        .buttonStyle(.plain)

        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)

        Button {
          showsResetConfirmation = true
        } label: {
          settingsRow(
            icon: "trash",
            title: "Alle Daten löschen",
            value: "Reset"
          )
        }
        .buttonStyle(.plain)
      }
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(GainsColor.ember.opacity(0.4), lineWidth: 1)
      )
    }
    .alert("Wirklich alle Daten löschen?",
           isPresented: $showsResetConfirmation) {
      Button("Abbrechen", role: .cancel) {}
      Button("Löschen", role: .destructive) {
        store.clearAllData()
      }
    } message: {
      Text("Alle persistierten Daten werden entfernt. Starte die App danach neu, damit alles sauber initialisiert wird.")
    }
  }
  #endif

  // MARK: - Helpers

  private func settingsRow(icon: String, title: String, value: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(GainsColor.moss)
        .frame(width: 32, height: 32)
        .background(GainsColor.lime.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

      Text(title)
        .font(GainsFont.body())
        .foregroundStyle(GainsColor.ink)

      Spacer()

      Text(value)
        .font(GainsFont.body())
        .foregroundStyle(GainsColor.softInk)

      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(GainsColor.border)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}
