import PhotosUI
import SwiftUI
import UIKit

// MARK: - Diagnose-Share-Wrapper
//
// Identifiable-Wrapper, damit `.sheet(item:)` korrekt anspringt — der reine
// String-Inhalt wäre nicht `Identifiable`.

struct DiagnosticsShareItem: Identifiable {
  let id = UUID()
  let text: String
}

struct DiagnosticsShareSheet: UIViewControllerRepresentable {
  let text: String

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: [text], applicationActivities: nil)
  }

  func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - ProfileView (Re-Design 2026-05-03)
//
// Vor diesem Pass war das Profil ein loser Stapel aus 6+ SlashLabel-Sektionen
// mit Stats-Kacheln (die im Fortschritt schon doppelt da sind), Buttons mit
// Chevron-Pfeilen, die in Wirklichkeit Toggles waren, und einer Header-Card,
// in der weder der Name noch das Avatar editiert werden konnten — der einzige
// Weg den Namen zu ändern war das Onboarding zu replayen.
//
// Die neue Struktur räumt entlang von zwei Linien auf:
// (1) **Profil-Identität** wird Hero-Card am Anfang: editierbares Foto (oder
//     Initial), editierbarer Name, „MITGLIED SEIT"-Eyebrow, dazu drei Pulse-
//     Tiles (Streak / Sessions / PRs) — die Stats-Sektion ist damit obsolet.
// (2) **App-Hub** ist eine Kette aus drei selbsterklärenden Cards:
//     - Plan-Card (Wochenplan-Summary + „Anpassen"-CTA)
//     - Tracker-Card (eine Zeile, öffnet Tracker-Hub-Sheet)
//     - Optionen-Card (echte SwiftUI-Toggles statt Buttons-mit-Chevron)
// Diagnose + DEBUG bleiben als Footer.
//
// Visuell hält sich die Card-Sprache ans A14 Coach-Brief-Vokabular: 22pt Hero-
// Radius, einfacher Akzent-Glow oben links, hairline Border, kein doppelter
// Drop-Shadow. So wirkt das Profil als Teil der Home-Familie, nicht als
// Fremdkörper.

struct ProfileView: View {
  @EnvironmentObject private var store: GainsStore
  @EnvironmentObject private var navigation: AppNavigationStore
  @Environment(\.dismiss) private var dismissProfile
  @ObservedObject private var ble = BLEHeartRateManager.shared
  @ObservedObject private var diagnostics = MetricKitObserver.shared

  // Sheet-/Edit-State
  @State private var showsNameEditor = false
  @State private var showsAvatarOptions = false
  @State private var showsAvatarPicker = false
  @State private var avatarPickerItem: PhotosPickerItem?
  @State private var showsTrackerHub = false
  @State private var showsResetConfirmation = false
  @State private var diagnosticsShareItem: DiagnosticsShareItem? = nil

  var body: some View {
    ZStack {
      GainsAppBackground()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
          heroCard
          pulseStrip
          planCard
          trackerCard
          optionsCard
          diagnosticsCard
          #if DEBUG
          debugCard
          #endif
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 32)
      }
    }
    // Avatar-Picker: PhotosPicker hängt am View, getriggert durch das
    // ConfirmationDialog (Foto wählen / Entfernen / Abbrechen). Das
    // entkoppelt Tap-Source (Avatar-Tile) von Picker-Lifecycle und macht
    // „Entfernen" ohne Picker-Umweg möglich.
    .photosPicker(isPresented: $showsAvatarPicker, selection: $avatarPickerItem, matching: .images)
    .onChange(of: avatarPickerItem) { _, newItem in
      Task { await loadAvatar(from: newItem) }
    }
    .confirmationDialog("Profilbild", isPresented: $showsAvatarOptions, titleVisibility: .visible) {
      Button("Foto auswählen") { showsAvatarPicker = true }
      if store.userAvatarImage != nil {
        Button("Foto entfernen", role: .destructive) {
          store.setUserAvatar(nil)
        }
      }
      Button("Abbrechen", role: .cancel) {}
    }
    .sheet(isPresented: $showsNameEditor) {
      NameEditSheet(currentName: store.userName) { newName in
        store.setUserName(newName)
      }
      .presentationDetents([.height(280)])
      .presentationBackground(GainsColor.background)
    }
    .sheet(isPresented: $showsTrackerHub) {
      WearablePickerSheet()
    }
    .sheet(item: $diagnosticsShareItem) { item in
      DiagnosticsShareSheet(text: item.text)
    }
  }

  // MARK: - Hero (editierbarer Avatar + Name)

  private var heroCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.l) {
      heroHeader
      heroIdentity
    }
    .padding(GainsSpacing.l)
    .background(heroBackground)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
        .strokeBorder(GainsColor.lime.opacity(0.32), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
    .gainsAccentGlow(GainsColor.lime, radius: 14)
    .gainsHeroShadow()
  }

  private var heroBackground: some View {
    ZStack {
      GainsColor.card
      RadialGradient(
        colors: [GainsColor.lime.opacity(0.16), .clear],
        center: .topLeading,
        startRadius: 0,
        endRadius: 240
      )
      .blendMode(.screen)
    }
  }

  private var heroHeader: some View {
    HStack(spacing: 10) {
      PulsingDot(color: GainsColor.lime, coreSize: 6, haloSize: 16)
      Text("PROFIL")
        .gainsEyebrow(GainsColor.lime, size: 11, tracking: 1.6)
      Spacer(minLength: 8)
      Text(memberSinceLine)
        .gainsEyebrow(GainsColor.softInk, size: 10, tracking: 1.4)
        .lineLimit(1)
    }
  }

  private var heroIdentity: some View {
    HStack(alignment: .center, spacing: 18) {
      avatarTile
      VStack(alignment: .leading, spacing: 6) {
        Button {
          showsNameEditor = true
        } label: {
          HStack(spacing: 8) {
            Text(displayName)
              .font(GainsFont.display(28))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
            Image(systemName: "pencil.circle.fill")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(GainsColor.lime.opacity(0.7))
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Name ändern")

        Text(displayName == "Dein Name" ? "Tippe, um deinen Namen festzulegen" : currentTagline)
          .gainsBody(secondary: true)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
  }

  private var avatarTile: some View {
    Button {
      showsAvatarOptions = true
    } label: {
      ZStack(alignment: .bottomTrailing) {
        Group {
          if let image = store.userAvatarImage {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
          } else {
            ZStack {
              GainsColor.ctaSurface
              Text(initialLetter)
                .font(GainsFont.display(34))
                .foregroundStyle(GainsColor.lime)
            }
          }
        }
        .frame(width: 84, height: 84)
        .clipShape(Circle())
        .overlay(
          Circle().stroke(GainsColor.lime.opacity(0.55), lineWidth: 1.2)
        )
        .shadow(color: GainsColor.lime.opacity(0.18), radius: 10, x: 0, y: 4)

        ZStack {
          Circle()
            .fill(GainsColor.lime)
            .frame(width: 28, height: 28)
            .overlay(Circle().stroke(GainsColor.background, lineWidth: 2))
          Image(systemName: "camera.fill")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(GainsColor.onLime)
        }
        .offset(x: 2, y: 2)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Profilbild ändern")
  }

  // MARK: - Pulse Strip (Streak / Sessions / PRs)
  //
  // Ersetzt die ehemalige „DEINE STATS"-Sektion mit drei großen Cards. Die
  // gleiche Mini-Tile-Sprache wie der Home-Pulse-Strip — kompakt, ohne
  // SlashLabel-Überschrift (würde hier nur Lärm machen).

  private var pulseStrip: some View {
    HStack(spacing: 10) {
      profilePulseTile(
        icon: "flame.fill",
        eyebrow: "STREAK",
        value: "\(store.streakDays)",
        detail: store.streakDays == 1 ? "TAG" : "TAGE",
        accent: GainsColor.lime
      )
      profilePulseTile(
        icon: "checkmark.seal.fill",
        eyebrow: "SESSIONS",
        value: "\(store.workoutHistory.count)",
        detail: "GESAMT",
        accent: GainsColor.accentCool
      )
      profilePulseTile(
        icon: "trophy.fill",
        eyebrow: "PRs",
        value: "+\(store.personalRecordCount)",
        detail: "REKORDE",
        accent: GainsColor.ember
      )
    }
  }

  private func profilePulseTile(
    icon: String,
    eyebrow: String,
    value: String,
    detail: String,
    accent: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 11, weight: .heavy))
          .foregroundStyle(accent)
        Text(eyebrow)
          .gainsEyebrow(accent, size: 10, tracking: 1.4)
          .lineLimit(1)
      }
      Text(value)
        .gainsMetric(GainsColor.ink, size: .standard)
      Text(detail)
        .gainsEyebrow(GainsColor.softInk, size: 9, tracking: 1.2)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(GainsColor.border.opacity(0.55), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  // MARK: - Plan-Card

  private var planCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      cardHeader(eyebrow: "PLAN", icon: "calendar.badge.plus", accent: GainsColor.lime)

      VStack(alignment: .leading, spacing: 4) {
        Text("Wochenstruktur")
          .font(GainsFont.title(20))
          .foregroundStyle(GainsColor.ink)
        Text("Trainingstage, Kraft/Lauf/Rad und Sessionlänge — alles im PLAN-Tab.")
          .gainsBody(secondary: true)
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(spacing: 0) {
        planSummaryRow(
          icon: "calendar.badge.checkmark",
          title: "Sessions / Woche",
          value: "\(store.plannerSettings.sessionsPerWeek)"
        )
        planDivider
        planSummaryRow(
          icon: "clock",
          title: "Session-Länge",
          value: "\(store.plannerSettings.preferredSessionLength) Min"
        )
        planDivider
        planSummaryRow(
          icon: "target",
          title: "Fokus",
          value: store.plannerSettings.goal.title
        )
        planDivider
        planSummaryRow(
          icon: "figure.strengthtraining.traditional",
          title: "Trainingstyp",
          value: store.plannerSettings.trainingFocus.shortTitle
        )
      }
      .padding(.vertical, 4)
      .background(GainsColor.ctaSurface.opacity(0.6))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

      Button {
        // Reihenfolge: erst openPlanner (setzt pendingGymTab + selectedTab),
        // dann das Sheet schließen — User sieht keinen leeren Home-Zwischenzustand.
        navigation.openPlanner()
        dismissProfile()
      } label: {
        HStack(spacing: 12) {
          Image(systemName: "slider.horizontal.3")
            .font(.system(size: 13, weight: .heavy))
            .foregroundStyle(GainsColor.lime)
          Text("PLAN ANPASSEN")
            .font(GainsFont.label(13))
            .tracking(1.8)
            .foregroundStyle(GainsColor.ink)
          Spacer(minLength: 0)
          Image(systemName: "arrow.right")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(GainsColor.lime)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(GainsColor.lime.opacity(0.10))
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
            .strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func planSummaryRow(icon: String, title: String, value: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 28, height: 28)
        .background(GainsColor.lime.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous))

      Text(title)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.ink)
      Spacer()
      Text(value)
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  private var planDivider: some View {
    Divider()
      .overlay(GainsColor.border.opacity(0.4))
      .padding(.horizontal, 14)
  }

  // MARK: - Tracker-Card
  //
  // Vor dem Re-Design hat das Profil zwei separate Tracker-UIs gerendert:
  // eine BLE-Zeile + eine 4-Plattform-Liste. Beide sind heute im
  // `TrackerHubSheet` zusammengefasst — die Profil-Card zeigt nur noch eine
  // einzige Status-Zeile mit Connection-Counter.

  private var trackerCard: some View {
    Button {
      showsTrackerHub = true
    } label: {
      VStack(alignment: .leading, spacing: 14) {
        cardHeader(eyebrow: "TRACKER", icon: "antenna.radiowaves.left.and.right", accent: GainsColor.accentCool)

        HStack(alignment: .center, spacing: 14) {
          ZStack {
            Circle()
              .fill(trackerAccent.opacity(0.15))
              .frame(width: 48, height: 48)
            Image(systemName: trackerIcon)
              .font(.system(size: 19, weight: .semibold))
              .foregroundStyle(trackerAccent)
          }

          VStack(alignment: .leading, spacing: 4) {
            Text(trackerHeadline)
              .font(GainsFont.title(18))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            Text(trackerSubline)
              .gainsBody(secondary: true)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)
          }

          Spacer(minLength: 0)

          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(GainsColor.softInk)
        }
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(.plain)
    .gainsCardStyle()
  }

  private var connectedTrackerCount: Int {
    store.connectedTrackerIDs.count + (ble.isConnected ? 1 : 0)
  }

  private var totalTrackerCount: Int {
    store.trackerOptions.count + 1 // BLE-Sensor zählt mit
  }

  private var trackerAccent: Color {
    connectedTrackerCount > 0 ? GainsColor.lime : GainsColor.accentCool
  }

  private var trackerIcon: String {
    if ble.isConnected { return "heart.fill" }
    return connectedTrackerCount > 0 ? "checkmark.circle.fill" : "sensor.tag.radiowaves.forward.fill"
  }

  private var trackerHeadline: String {
    if connectedTrackerCount == 0 { return "Tracker verbinden" }
    return "\(connectedTrackerCount) von \(totalTrackerCount) verbunden"
  }

  private var trackerSubline: String {
    if let bpm = ble.liveHeartRate, ble.isConnected {
      return "Live-HF \(bpm) bpm · Apple Health, WHOOP, Garmin u.v.m."
    }
    if connectedTrackerCount == 0 {
      return "Apple Health, WHOOP, Garmin, Polar — alles in einem Sheet."
    }
    return "Apple Health, WHOOP, Garmin, BLE-Sensoren verwalten."
  }

  // MARK: - Optionen-Card (echte Toggles)

  private var optionsCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      cardHeader(eyebrow: "OPTIONEN", icon: "slider.horizontal.3", accent: GainsColor.softInk)

      VStack(spacing: 0) {
        toggleRow(
          icon: "bell.fill",
          title: "Benachrichtigungen",
          subtitle: "Erinnerungen für Workouts und Coach-Tipps",
          binding: Binding(
            get: { store.notificationsEnabled },
            set: { _ in store.toggleNotificationsEnabled() }
          )
        )
        planDivider
        toggleRow(
          icon: "arrow.trianglehead.2.clockwise",
          title: "Auto-Sync",
          subtitle: "Apple Health & Tracker im Hintergrund abgleichen",
          binding: Binding(
            get: { store.healthAutoSyncEnabled },
            set: { _ in store.toggleHealthAutoSyncEnabled() }
          )
        )
        planDivider
        toggleRow(
          icon: "brain",
          title: "Coach-Empfehlungen",
          subtitle: "Adaptive Tipps aus Studien & Trainingsdaten",
          binding: Binding(
            get: { store.studyBasedCoachingEnabled },
            set: { _ in store.toggleStudyBasedCoachingEnabled() }
          )
        )
        planDivider
        infoRow(icon: "info.circle", title: "Version", value: "1.0")
      }
      .padding(.vertical, 4)
      .background(GainsColor.ctaSurface.opacity(0.6))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func toggleRow(
    icon: String,
    title: String,
    subtitle: String,
    binding: Binding<Bool>
  ) -> some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(binding.wrappedValue ? GainsColor.lime : GainsColor.softInk)
        .frame(width: 32, height: 32)
        .background((binding.wrappedValue ? GainsColor.lime : GainsColor.softInk).opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(GainsFont.body(15))
          .foregroundStyle(GainsColor.ink)
        Text(subtitle)
          .gainsCaption(GainsColor.softInk)
          .lineLimit(2)
      }
      Spacer(minLength: 6)
      Toggle("", isOn: binding)
        .labelsHidden()
        .tint(GainsColor.lime)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  private func infoRow(icon: String, title: String, value: String) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)
        .frame(width: 32, height: 32)
        .background(GainsColor.softInk.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

      Text(title)
        .font(GainsFont.body(15))
        .foregroundStyle(GainsColor.ink)
      Spacer()
      Text(value)
        .font(.system(size: 14, weight: .semibold, design: .monospaced))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  // MARK: - Diagnose

  private var diagnosticsCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      cardHeader(eyebrow: "DIAGNOSE", icon: "stethoscope", accent: GainsColor.softInk)

      Text("Wenn die App abstürzt oder hängt, sammelt iOS einen Diagnose-Report. Du kannst ihn hier teilen, um beim Fehlersuchen zu helfen.")
        .gainsCaption(GainsColor.softInk)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: 10) {
        Button {
          diagnosticsShareItem = DiagnosticsShareItem(text: diagnostics.exportableText())
        } label: {
          diagnosticsButton(
            icon: "square.and.arrow.up",
            title: "REPORTS TEILEN",
            subtitle: diagnostics.diagnosticCount == 0
              ? "Keine"
              : "\(diagnostics.diagnosticCount) gespeichert",
            accent: GainsColor.lime
          )
        }
        .buttonStyle(.plain)
        .disabled(diagnostics.diagnosticCount == 0)
        .opacity(diagnostics.diagnosticCount == 0 ? 0.45 : 1.0)

        if diagnostics.diagnosticCount > 0 {
          Button {
            diagnostics.clearStoredEntries()
          } label: {
            diagnosticsButton(
              icon: "xmark.bin",
              title: "LÖSCHEN",
              subtitle: "Lokal",
              accent: GainsColor.ember
            )
          }
          .buttonStyle(.plain)
        }
      }
    }
    .padding(18)
    .gainsCardStyle()
  }

  private func diagnosticsButton(icon: String, title: String, subtitle: String, accent: Color) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 13, weight: .heavy))
        .foregroundStyle(accent)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(GainsColor.ink)
        Text(subtitle)
          .gainsEyebrow(GainsColor.softInk, size: 9, tracking: 1.2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(GainsColor.ctaSurface.opacity(0.7))
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(accent.opacity(0.3), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  // MARK: - DEBUG

  #if DEBUG
  @AppStorage(GainsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false

  private var debugCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      cardHeader(eyebrow: "DEBUG · DEMO", icon: "wrench.and.screwdriver.fill", accent: GainsColor.ember)

      Text("Nur in Entwicklungs-Builds sichtbar — fürs Aufnehmen von Screenshots oder schnelles Test-Befüllen.")
        .gainsCaption(GainsColor.softInk)

      VStack(spacing: 0) {
        Button {
          store.loadDemoData()
        } label: {
          infoRow(icon: "wand.and.stars", title: "Demo-Daten laden", value: "Mock")
        }
        .buttonStyle(.plain)

        planDivider

        Button {
          hasCompletedOnboarding = false
        } label: {
          infoRow(icon: "arrow.uturn.backward.circle", title: "Onboarding zeigen", value: "Replay")
        }
        .buttonStyle(.plain)

        planDivider

        Button {
          showsResetConfirmation = true
        } label: {
          infoRow(icon: "trash", title: "Alle Daten löschen", value: "Reset")
        }
        .buttonStyle(.plain)
      }
      .padding(.vertical, 4)
      .background(GainsColor.ctaSurface.opacity(0.6))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .padding(18)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .strokeBorder(GainsColor.ember.opacity(0.4), lineWidth: GainsBorder.accent)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    .alert(
      "Wirklich alle Daten löschen?",
      isPresented: $showsResetConfirmation
    ) {
      Button("Abbrechen", role: .cancel) {}
      Button("Löschen", role: .destructive) {
        store.clearAllData()
      }
    } message: {
      Text("Alle persistierten Daten werden entfernt. Starte die App danach neu, damit alles sauber initialisiert wird.")
    }
  }
  #endif

  // MARK: - Card-Header (gemeinsamer Eyebrow + Icon-Kapsel)

  private func cardHeader(eyebrow: String, icon: String, accent: Color) -> some View {
    HStack(spacing: 10) {
      ZStack {
        Circle()
          .fill(accent.opacity(0.16))
          .frame(width: 26, height: 26)
        Image(systemName: icon)
          .font(.system(size: 11, weight: .heavy))
          .foregroundStyle(accent)
      }
      Text(eyebrow)
        .gainsEyebrow(accent, size: 11, tracking: 1.6)
      Spacer(minLength: 0)
    }
  }

  // MARK: - Computed Helpers

  private var displayName: String {
    store.userName.isEmpty ? "Dein Name" : store.userName
  }

  private var initialLetter: String {
    let trimmed = store.userName.trimmingCharacters(in: .whitespaces)
    guard let first = trimmed.first else { return "·" }
    return String(first).uppercased()
  }

  private var memberSinceLine: String {
    // workoutHistory + runHistory sind beide DESC sortiert (neueste zuerst),
    // also liefert `.last` den ältesten Eintrag — perfekter „seit"-Anker.
    let firstWorkout = store.workoutHistory.last?.finishedAt
    let firstRun = store.runHistory.last?.finishedAt
    let earliest: Date?
    switch (firstWorkout, firstRun) {
    case let (w?, r?): earliest = min(w, r)
    case let (w?, nil): earliest = w
    case let (nil, r?): earliest = r
    default: earliest = nil
    }
    if let earliest {
      return "MITGLIED SEIT \(monthYearFormatter.string(from: earliest).uppercased())"
    }
    return "FRISCH AN BORD"
  }

  /// Eine knappe, auf den User zugeschnittene Subline. Variiert mit Streak/
  /// Aktivität — so liest sich das Profil nicht wie ein leeres Account-Form.
  private var currentTagline: String {
    let sessions = store.workoutHistory.count
    let streak = store.streakDays
    if sessions == 0 && streak == 0 {
      return "Bereit für deine erste Session."
    }
    if streak >= 7 {
      return "\(streak) Tage in Folge — du bist im Groove."
    }
    if streak >= 3 {
      return "Streak läuft — \(streak) Tage am Stück."
    }
    if sessions >= 50 {
      return "\(sessions) Sessions im Logbuch."
    }
    if sessions > 0 {
      return "\(sessions) abgeschlossene Sessions bisher."
    }
    return "Lass uns deinen ersten Tag starten."
  }

  private var monthYearFormatter: DateFormatter {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "MMM yyyy"
    return f
  }

  // MARK: - Avatar-Loading

  private func loadAvatar(from item: PhotosPickerItem?) async {
    guard let item else { return }
    do {
      if let data = try await item.loadTransferable(type: Data.self),
         let image = UIImage(data: data) {
        await MainActor.run {
          store.setUserAvatar(image)
          avatarPickerItem = nil
        }
      }
    } catch {
      // Fehler still ignorieren — der User kann's nochmal versuchen.
      await MainActor.run { avatarPickerItem = nil }
    }
  }
}

// MARK: - NameEditSheet
//
// Kleines, fokussiertes Sheet für die Namensänderung. TextField mit Auto-
// Focus, Speichern-Primär-Button + Abbrechen — passt visuell ins Profil-
// Vokabular (Lime-Akzent, Card-Surface).

private struct NameEditSheet: View {
  let currentName: String
  let onSave: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var draft: String = ""
  @FocusState private var nameFocused: Bool

  var body: some View {
    ZStack {
      GainsColor.background.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("DEIN NAME")
            .gainsEyebrow(GainsColor.lime, size: 11, tracking: 1.6)
          Text("Wie sollen wir dich nennen?")
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)
        }

        TextField("z. B. Julius", text: $draft)
          .font(GainsFont.body(17))
          .foregroundStyle(GainsColor.ink)
          .padding(.horizontal, 14)
          .padding(.vertical, 14)
          .background(GainsColor.card)
          .overlay(
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.hairline)
          )
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          .focused($nameFocused)
          .submitLabel(.done)
          .onSubmit(save)
          .textInputAutocapitalization(.words)
          .autocorrectionDisabled(true)

        Spacer(minLength: 0)

        HStack(spacing: 10) {
          Button {
            dismiss()
          } label: {
            Text("Abbrechen")
              .font(GainsFont.label(13))
              .tracking(1.6)
              .foregroundStyle(GainsColor.softInk)
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .background(GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
              .overlay(
                RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                  .strokeBorder(GainsColor.border.opacity(0.6), lineWidth: GainsBorder.hairline)
              )
          }
          .buttonStyle(.plain)

          Button(action: save) {
            Text("SPEICHERN")
              .font(GainsFont.label(13))
              .tracking(1.8)
              .foregroundStyle(GainsColor.onLime)
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .background(GainsColor.lime)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          }
          .buttonStyle(.plain)
          .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
          .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
        }
      }
      .padding(.horizontal, 22)
      .padding(.top, 28)
      .padding(.bottom, 22)
    }
    .onAppear {
      draft = currentName
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        nameFocused = true
      }
    }
  }

  private func save() {
    onSave(draft)
    dismiss()
  }
}
