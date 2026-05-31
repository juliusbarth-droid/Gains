import SwiftUI

/// Sheet zum Scannen und Verbinden von Bluetooth-Herzfrequenz-Sensoren.
/// Unterstützt alle Geräte mit Standard-BLE-Heart-Rate-Profil (0x180D):
/// Polar H9/H10, Garmin HRM-Pro/Dual, Wahoo TICKR/TICKR FIT u.v.m.
struct WearablePickerSheet: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject private var ble = BLEHeartRateManager.shared

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: GainsSpacing.xl) {
            statusCard
            if ble.isConnected, let device = ble.connectedDevice {
              connectedCard(device)
            }
            deviceList
            supportedBrandsSection
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.m)
          .padding(.bottom, GainsSpacing.xl)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("WEARABLES")
            .font(GainsFont.label(11))
            .tracking(2.4)
            .foregroundStyle(GainsColor.ink)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Fertig") { dismiss() }
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.lime)
        }
      }
      .onDisappear {
        // Stabilität/Akku (2026-05-31): Läuft beim Schließen des Sheets noch
        // ein Scan (ohne dass verbunden wurde), würde das Funkmodul sonst
        // unbegrenzt weiterscannen → Dauer-Akku-Drain. Eine bestehende
        // Verbindung bleibt absichtlich erhalten.
        if case .scanning = ble.scanState { ble.stopScanning() }
      }
    }
  }

  // MARK: - Status Card

  private var statusCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(spacing: GainsSpacing.s) {
        // Polish-Loop 200 (2026-05-14): Status-Icon mit Inner-Light +
        // Hairline-Border + Glow auf State-Color. Pulse-Ring auf
        // scanState bleibt erhalten.
        ZStack {
          Circle().fill(stateColor.opacity(0.15))
          Circle()
            .fill(
              LinearGradient(
                colors: [Color.white.opacity(0.18), .clear],
                startPoint: .top,
                endPoint: .center
              )
            )
            .blendMode(.plusLighter)
          if ble.scanState.isActive {
            Circle()
              .fill(stateColor.opacity(0.08))
              .scaleEffect(1.4)
              .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: ble.scanState.isActive)
          }
          Image(systemName: stateIcon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(stateColor)
            .shadow(color: stateColor.opacity(0.55), radius: 4)
        }
        .frame(width: 48, height: 48)
        .overlay(
          Circle().strokeBorder(stateColor.opacity(0.40), lineWidth: GainsBorder.hairline)
        )
        .compositingGroup()
        .shadow(color: stateColor.opacity(0.24), radius: 6, y: 1)

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(ble.scanState.label)
            .font(GainsFont.title(17))
            .foregroundStyle(GainsColor.ink)

          Text(stateSubtitle)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }

        Spacer()
      }

      // Scan / Stop Button — A15: GainsPrimaryButton, tone wechselt zwischen
      // .lime (Verbinden/Suchen) und .ember (Trennen). Touch-Target und
      // Akzent-Glow sind dadurch konsistent zum Rest der App.
      GainsPrimaryButton(
        primaryButtonLabel,
        tone: ble.isConnected ? .ember : .lime
      ) {
        if ble.isConnected {
          ble.disconnect()
        } else if case .scanning = ble.scanState {
          ble.stopScanning()
        } else {
          ble.startScanning()
        }
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // MARK: - Connected Card

  // Polish-Loop 201 (2026-05-14): Connected-Card mit Heart-Icon-Halo +
  // Live-Pulse-Dot + VERBUNDEN-Badge mit Inner-Light + Glow.
  private func connectedCard(_ device: BLEDevice) -> some View {
    HStack(spacing: GainsSpacing.m) {
      ZStack {
        Circle().fill(GainsColor.lime.opacity(0.18))
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.white.opacity(0.20), .clear],
              startPoint: .top,
              endPoint: .center
            )
          )
          .blendMode(.plusLighter)
        Image(systemName: "heart.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .shadow(color: GainsColor.lime.opacity(0.275), radius: 4)
      }
      .frame(width: 44, height: 44)
      .overlay(
        Circle().strokeBorder(GainsColor.lime.opacity(0.45), lineWidth: GainsBorder.hairline)
      )
      .compositingGroup()
      .shadow(color: GainsColor.lime.opacity(0.14), radius: 6, y: 1)

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text(device.name)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        if let bpm = ble.liveHeartRate {
          HStack(spacing: 4) {
            Circle()
              .fill(GainsColor.lime)
              .frame(width: 5, height: 5)
              .shadow(color: GainsColor.lime.opacity(0.275), radius: 2)
            Text("\(bpm) bpm · Live")
              .font(GainsFont.body(13))
              .foregroundStyle(GainsColor.lime)
              .monospacedDigit()
          }
        } else {
          Text("Warte auf Herzfrequenz …")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }
      }

      Spacer()

      Text("VERBUNDEN")
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(GainsColor.onLime)
        .padding(.horizontal, GainsSpacing.tight)
        .frame(height: 28)
        .background(
          ZStack {
            Capsule().fill(GainsColor.lime)
            Capsule()
              .fill(
                LinearGradient(
                  colors: [Color.white.opacity(0.24), .clear],
                  startPoint: .top,
                  endPoint: .center
                )
              )
              .blendMode(.plusLighter)
          }
        )
        .clipShape(Capsule())
        .compositingGroup()
        .shadow(color: GainsColor.lime.opacity(0.16), radius: 6)
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle(GainsColor.lime.opacity(0.12))
  }

  // MARK: - Device List

  private var deviceList: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["GEFUNDENE", "GERÄTE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      if ble.discoveredDevices.isEmpty {
        emptyDevicesView
      } else {
        VStack(spacing: 1) {
          ForEach(Array(ble.discoveredDevices.enumerated()), id: \.element.id) { index, device in
            deviceRow(device)
            if index < ble.discoveredDevices.count - 1 {
              Divider()
                .overlay(GainsColor.border.opacity(0.5))
                .padding(.horizontal, GainsSpacing.m)
            }
          }
        }
        .gainsCardStyle(GainsColor.card)
      }
    }
  }

  private var emptyDevicesView: some View {
    VStack(spacing: GainsSpacing.s) {
      Image(systemName: case_scanning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)

      Text(case_scanning ? "Suche nach Geräten in der Nähe …" : "Starte die Suche, um Geräte zu finden.")
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(GainsSpacing.xl)
    .gainsCardStyle(GainsColor.card)
  }

  private func deviceRow(_ device: BLEDevice) -> some View {
    let isConnected = ble.connectedDevice?.id == device.id
    let brand = BLEHeartRateManager.brandLabel(for: device.name)

    return HStack(spacing: GainsSpacing.s) {
      // Polish-Loop 185 (2026-05-14): Device-Icon mit plusLighter Inner-
      // Light + Hairline + Lime-Glow auf connected.
      ZStack {
        Circle().fill(isConnected ? GainsColor.lime.opacity(0.18) : GainsColor.elevated)
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.white.opacity(isConnected ? 0.18 : 0.06), .clear],
              startPoint: .top,
              endPoint: .center
            )
          )
          .blendMode(.plusLighter)
        Image(systemName: deviceIcon(for: device.name))
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(isConnected ? GainsColor.lime : GainsColor.softInk)
          .shadow(color: isConnected ? GainsColor.lime.opacity(0.45) : .clear, radius: 3)
      }
      .frame(width: 36, height: 36)
      .overlay(
        Circle().strokeBorder(
          isConnected ? GainsColor.lime.opacity(0.45) : GainsColor.border.opacity(0.35),
          lineWidth: GainsBorder.hairline
        )
      )
      .compositingGroup()
      .shadow(color: isConnected ? GainsColor.lime.opacity(0.24) : .clear, radius: 5, y: 1)

      VStack(alignment: .leading, spacing: 2) {
        Text(device.name)
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.ink)

        HStack(spacing: GainsSpacing.xs) {
          if let brand {
            Text(brand)
              .font(GainsFont.label(10))
              .tracking(GainsTracking.eyebrowTight)
              .foregroundStyle(GainsColor.moss)
          }
          rssiDots(device.rssi)
        }
      }

      Spacer()

      // Polish-Loop 186 (2026-05-14): Connect/Disconnect-Pille als Glas-
      // Capsule mit Inner-Light + Tint-Glow auf isConnected (Ember-Glow).
      Button {
        if isConnected {
          ble.disconnect()
        } else {
          ble.connect(to: device)
        }
      } label: {
        Text(isConnected ? "TRENNEN" : "VERBINDEN")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(isConnected ? GainsColor.ember : GainsColor.lime)
          .frame(width: 88, height: 30)
          .background(
            ZStack {
              Capsule().fill(isConnected ? GainsColor.ember.opacity(0.14) : GainsColor.elevated)
              Capsule()
                .fill(
                  LinearGradient(
                    colors: [GainsColor.glassInnerLight, .clear],
                    startPoint: .top,
                    endPoint: .center
                  )
                )
            }
          )
          .overlay(
            Capsule().strokeBorder(
              LinearGradient(
                colors: isConnected
                  ? [GainsColor.ember.opacity(0.55), GainsColor.ember.opacity(0.15)]
                  : [GainsColor.lime.opacity(0.40), GainsColor.lime.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: GainsBorder.hairline
            )
          )
          .clipShape(Capsule())
          .compositingGroup()
          .shadow(color: (isConnected ? GainsColor.ember : GainsColor.lime).opacity(0.20), radius: 5)
      }
      .buttonStyle(.plain)
      .disabled(ble.scanState.isActive)
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
  }

  // MARK: - Supported Brands

  private var supportedBrandsSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["KOMPATIBLE", "GERÄTE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(spacing: 1) {
        brandRow(
          icon: "p.circle.fill",
          name: "Polar",
          models: "H9, H10, Vantage M2, Grit X",
          color: GainsColor.ember,
          note: "Bluetooth LE HR-Profil"
        )
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, GainsSpacing.m)
        brandRow(
          icon: "g.circle.fill",
          name: "Garmin",
          models: "HRM-Pro, HRM-Dual, HRM-Pro Plus",
          color: Color(hex: "A8C53A"),
          note: "Bluetooth LE HR-Profil"
        )
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, GainsSpacing.m)
        brandRow(
          icon: "w.circle.fill",
          name: "Wahoo",
          models: "TICKR, TICKR FIT, TICKR X",
          color: Color(hex: "2563EB"),
          note: "Bluetooth LE HR-Profil"
        )
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, GainsSpacing.m)
        brandRow(
          icon: "checkerboard.rectangle",
          name: "Alle anderen HR-Sensoren",
          models: "Suunto, CooSpo, Magene u.v.m.",
          color: GainsColor.softInk,
          note: "Standard BLE 0x180D"
        )
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, GainsSpacing.m)
        whoopRow
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, GainsSpacing.m)
        appleWatchRow
      }
      .gainsCardStyle(GainsColor.card)
    }
  }

  private func brandRow(icon: String, name: String, models: String, color: Color, note: String) -> some View {
    HStack(spacing: GainsSpacing.s) {
      Image(systemName: icon)
        .font(.system(size: 22))
        .foregroundStyle(color)
        .frame(width: 36)

      VStack(alignment: .leading, spacing: 2) {
        Text(name)
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.ink)
        Text(models)
          .font(GainsFont.label(10))
          .tracking(0.8)
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      Text(note)
        .font(GainsFont.label(9))
        .tracking(0.6)
        .foregroundStyle(GainsColor.mutedInk)
        .multilineTextAlignment(.trailing)
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
  }

  private var whoopRow: some View {
    HStack(spacing: GainsSpacing.s) {
      ZStack {
        RoundedRectangle(cornerRadius: GainsRadius.tiny, style: .continuous)
          .fill(Color(hex: "F4F3EE").opacity(0.9))
          .frame(width: 36, height: 36)
        Text("W")
          .font(.system(size: 16, weight: .black))
          .foregroundStyle(Color(hex: "0A0A0A"))
      }

      VStack(alignment: .leading, spacing: 2) {
        Text("WHOOP")
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.ink)
        Text("Verbinde über Apple Health → WHOOP App")
          .font(GainsFont.label(10))
          .tracking(0.8)
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      Text("via HealthKit")
        .font(GainsFont.label(9))
        .tracking(0.6)
        .foregroundStyle(GainsColor.mutedInk)
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
  }

  private var appleWatchRow: some View {
    HStack(spacing: GainsSpacing.s) {
      Image(systemName: "applewatch")
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(GainsColor.ink)
        .frame(width: 36)

      VStack(alignment: .leading, spacing: 2) {
        Text("Apple Watch")
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.ink)
        Text("Automatisch über Apple Health")
          .font(GainsFont.label(10))
          .tracking(0.8)
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      Text("via HealthKit")
        .font(GainsFont.label(9))
        .tracking(0.6)
        .foregroundStyle(GainsColor.mutedInk)
    }
    .padding(.horizontal, GainsSpacing.m)
    .padding(.vertical, GainsSpacing.s)
  }

  // MARK: - Helpers

  private var stateColor: Color {
    switch ble.scanState {
    case .connected:            return GainsColor.lime
    case .scanning:             return GainsColor.accentCool
    case .connecting:           return GainsColor.ember
    case .failed:               return GainsColor.ember
    case .bluetoothUnavailable: return GainsColor.ember
    case .idle:                 return GainsColor.softInk
    }
  }

  private var stateIcon: String {
    switch ble.scanState {
    case .connected:            return "checkmark.circle.fill"
    case .scanning:             return "antenna.radiowaves.left.and.right"
    case .connecting:           return "arrow.triangle.2.circlepath"
    case .failed:               return "exclamationmark.triangle.fill"
    case .bluetoothUnavailable: return "bluetooth.slash"
    case .idle:                 return "heart.circle"
    }
  }

  private var stateSubtitle: String {
    switch ble.scanState {
    case .bluetoothUnavailable:
      return "Bluetooth aktivieren, um Geräte zu verbinden."
    case .idle:
      return "Starte die Suche, um Herzfrequenz-Sensoren zu finden."
    case .scanning:
      return "Stell sicher, dass dein Sensor aktiv ist."
    case .connecting:
      return "Verbindung wird aufgebaut …"
    case .connected:
      return "Herzfrequenz wird in Echtzeit übertragen."
    case .failed(let msg):
      return msg
    }
  }

  private var primaryButtonLabel: String {
    if ble.isConnected { return "TRENNEN" }
    if case .scanning = ble.scanState { return "SUCHE STOPPEN" }
    return "SUCHE STARTEN"
  }

  private var case_scanning: Bool {
    if case .scanning = ble.scanState { return true }
    return false
  }

  private func deviceIcon(for name: String) -> String {
    let n = name.lowercased()
    if n.contains("polar") || n.contains("h10") || n.contains("h9") {
      return "heart.circle.fill"
    }
    if n.contains("garmin") || n.contains("hrm") {
      return "figure.run.circle.fill"
    }
    if n.contains("wahoo") || n.contains("tickr") {
      return "bolt.heart.fill"
    }
    return "sensor.tag.radiowaves.forward.fill"
  }

  private func rssiDots(_ rssi: Int) -> some View {
    HStack(spacing: 2) {
      ForEach(0..<3) { i in
        RoundedRectangle(cornerRadius: 1)
          .fill(rssiColor(rssi, bar: i))
          .frame(width: 3, height: CGFloat(5 + i * 3))
      }
    }
  }

  private func rssiColor(_ rssi: Int, bar: Int) -> Color {
    // rssi: -50 stark, -80 schwach
    let level: Int = rssi > -55 ? 3 : rssi > -70 ? 2 : 1
    return bar < level ? GainsColor.lime : GainsColor.border.opacity(0.6)
  }
}
