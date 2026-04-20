import SwiftUI

struct ProfileView: View {
  @EnvironmentObject private var store: GainsStore

  var body: some View {
    ZStack {
      GainsColor.background.ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 22) {
          header
          statsRow
          accountSection
          trackerSection
          goalsSection
          settingsSection
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 28)
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 16) {
      Circle()
        .fill(GainsColor.ink)
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

  private var accountSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["ACCOUNT", "ÜBERSICHT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 10) {
          accountStatCard(
            title: "Tracker", value: "\(store.connectedTrackerCount)", subtitle: "verbunden")
          accountStatCard(
            title: "Runs", value: "\(store.runHistory.count)", subtitle: "gespeichert")
          accountStatCard(title: "Streak", value: "\(store.streakDays)", subtitle: "Tage")
        }
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  // MARK: - Stats

  private var statsRow: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["DEINE", "STATS"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
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

  private var trackerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["TRACKER", "VERBINDEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      HStack {
        Text("Apple Health")
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)

        Spacer()

        Text(store.healthConnectionTitle)
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(store.hasConnectedAppleHealth ? GainsColor.ink : GainsColor.softInk)
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(store.hasConnectedAppleHealth ? GainsColor.lime : GainsColor.card)
          .clipShape(Capsule())
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)

      VStack(alignment: .leading, spacing: 12) {
        Text(store.appleHealthDescription)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(2)

        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10
        ) {
          ForEach(store.appleHealthHighlights.prefix(4)) { stat in
            VStack(alignment: .leading, spacing: 8) {
              Text(stat.title.uppercased())
                .font(GainsFont.label(9))
                .tracking(1.8)
                .foregroundStyle(GainsColor.softInk)

              Text(stat.value)
                .font(GainsFont.title(16))
                .foregroundStyle(GainsColor.ink)

              Text(stat.subtitle)
                .font(GainsFont.body(11))
                .foregroundStyle(GainsColor.softInk)
                .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .padding(12)
            .background(GainsColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 16)
      .gainsCardStyle()

      HStack {
        Text("WHOOP")
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)

        Spacer()

        Text(store.whoopConnectionTitle)
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(store.hasConnectedWhoop ? GainsColor.ink : GainsColor.softInk)
          .padding(.horizontal, 10)
          .frame(height: 28)
          .background(store.hasConnectedWhoop ? GainsColor.lime : GainsColor.card)
          .clipShape(Capsule())
      }
      .padding(16)
      .gainsCardStyle()

      ForEach(store.trackerOptions) { tracker in
        Button {
          store.toggleTrackerConnection(tracker.id)
        } label: {
          HStack(spacing: 12) {
            Circle()
              .fill(Color(hex: tracker.accentHex))
              .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
              Text(tracker.name)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)

              Text(tracker.source)
                .font(GainsFont.body(13))
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()

            Text(buttonTitle(for: tracker))
              .font(GainsFont.label(10))
              .tracking(1.4)
              .foregroundStyle(
                store.isTrackerConnected(tracker.id) ? GainsColor.ink : GainsColor.lime
              )
              .frame(width: 104, height: 36)
              .background(store.isTrackerConnected(tracker.id) ? GainsColor.lime : GainsColor.ink)
              .clipShape(Capsule())
          }
          .padding(16)
          .gainsCardStyle()
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Goals

  private var goalsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["ZIELE", "EINSTELLUNGEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

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
        parts: ["APP", "OPTIONEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(spacing: 1) {
        Button {
          store.toggleNotificationsEnabled()
        } label: {
          settingsRow(
            icon: "bell", title: "Benachrichtigungen",
            value: store.notificationsEnabled ? "Ein" : "Aus")
        }
        .buttonStyle(.plain)
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
        Button {
          store.toggleHealthAutoSyncEnabled()
        } label: {
          settingsRow(
            icon: "arrow.trianglehead.2.clockwise", title: "Auto-Sync",
            value: store.healthAutoSyncEnabled ? "Aktiv" : "Pausiert")
        }
        .buttonStyle(.plain)
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
        Button {
          store.toggleStudyBasedCoachingEnabled()
        } label: {
          settingsRow(
            icon: "book.pages", title: "Studienbasierte Empfehlungen",
            value: store.studyBasedCoachingEnabled ? "Aktiv" : "Aus")
        }
        .buttonStyle(.plain)
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
        Button {
          store.cycleAppearanceMode()
        } label: {
          settingsRow(
            icon: "circle.lefthalf.filled", title: "Darstellung", value: store.appearanceMode.title)
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

  private func accountStatCard(title: String, value: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)

      Text(subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .gainsCardStyle()
  }

  private func buttonTitle(for tracker: TrackerDevice) -> String {
    if tracker.source == "HealthKit" {
      return store.isTrackerConnected(tracker.id) ? "Sync" : "Health"
    }
    if tracker.source == "WHOOP OAuth" {
      return store.isTrackerConnected(tracker.id) ? "Sync" : "WHOOP"
    }
    return store.isTrackerConnected(tracker.id) ? "Verbunden" : "Verbinden"
  }
}
