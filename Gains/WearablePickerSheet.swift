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
          VStack(alignment: .leading, spacing: 24) {
            statusCard
            if ble.isConnected, let device = ble.connectedDevice {
              connectedCard(device)
            }
            deviceList
            supportedBrandsSection
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 36)
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
    }
  }

  // MARK: - Status Card

  private var statusCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        // Puls-Animation
        ZStack {
          Circle()
            .fill(stateColor.opacity(0.15))
            .frame(width: 48, height: 48)
          if ble.scanState.isActive {
            Circle()
              .fill(stateColor.opacity(0.08))
              .frame(width: 48, height: 48)
              .scaleEffect(1.4)
              .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: ble.scanState.isActive)
          }
          Image(systemName: stateIcon)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(stateColor)
        }

        VStack(alignment: .leading, spacing: 4) {
          Text(ble.scanState.label)
            .font(GainsFont.title(17))
            .foregroundStyle(GainsColor.ink)

          Text(stateSubtitle)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }

        Spacer()
      }

      // Scan / Stop Button
      Button {
        if ble.isConnected {
          ble.disconnect()
        } else if case .scanning = ble.scanState {
          ble.stopScanning()
        } else {
          ble.startScanning()
        }
      } label: {
        Text(primaryButtonLabel)
          .font(GainsFont.label(12))
          .tracking(1.8)
          .foregroundStyle(ble.isConnected ? GainsColor.ember : GainsColor.onLime)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(ble.isConnected ? GainsColor.ember.opacity(0.14) : GainsColor.lime)
          .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
              .stroke(ble.isConnected ? GainsColor.ember.opacity(0.4) : .clear, lineWidth: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(18)
    .gainsCardStyle()
  }

  // MARK: - Connected Card

  private func connectedCard(_ device: BLEDevice) -> some View {
    HStack(spacing: 14) {
      ZStack {
        Circle()
          .fill(GainsColor.lime.opacity(0.18))
          .frame(width: 44, height: 44)
        Image(systemName: "heart.fill")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(device.name)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        if let bpm = ble.liveHeartRate {
          Text("\(bpm) bpm · Live")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.lime)
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
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(GainsColor.lime)
        .clipShape(Capsule())
    }
    .padding(16)
    .gainsCardStyle(GainsColor.lime.opacity(0.12))
  }

  // MARK: - Device List

  private var deviceList: some View {
    VStack(alignment: .leading, spacing: 12) {
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
                .padding(.horizontal, 14)
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
  }

  private var emptyDevicesView: some View {
    VStack(spacing: 12) {
      Image(systemName: case_scanning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
        .font(.system(size: 28, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)

      Text(case_scanning ? "Suche nach Geräten in der Nähe …" : "Starte die Suche, um Geräte zu finden.")
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(28)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
  }

  private func deviceRow(_ device: BLEDevice) -> some View {
    let isConnected = ble.connectedDevice?.id == device.id
    let brand = BLEHeartRateManager.brandLabel(for: device.name)

    return HStack(spacing: 12) {
      // Gerätesymbol
      ZStack {
        Circle()
          .fill(isConnected ? GainsColor.lime.opacity(0.18) : GainsColor.elevated)
          .frame(width: 36, height: 36)
        Image(systemName: deviceIcon(for: device.name))
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(isConnected ? GainsColor.lime : GainsColor.softInk)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(device.name)
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.ink)

        HStack(spacing: 6) {
          if let brand {
            Text(brand)
              .font(GainsFont.label(10))
              .tracking(1.2)
              .foregroundStyle(GainsColor.moss)
          }
          rssiDots(device.rssi)
        }
      }

      Spacer()

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
          .background(isConnected ? GainsColor.ember.opacity(0.12) : GainsColor.elevated)
          .overlay(
            Capsule()
              .stroke(isConnected ? GainsColor.ember.opacity(0.4) : GainsColor.border.opacity(0.6), lineWidth: 1)
          )
          .clipShape(Capsule())
      }
      .buttonStyle(.plain)
      .disabled(ble.scanState.isActive)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  // MARK: - Supported Brands

  private var supportedBrandsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
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
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
        brandRow(
          icon: "g.circle.fill",
          name: "Garmin",
          models: "HRM-Pro, HRM-Dual, HRM-Pro Plus",
          color: Color(hex: "A8C53A"),
          note: "Bluetooth LE HR-Profil"
        )
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
        brandRow(
          icon: "w.circle.fill",
          name: "Wahoo",
          models: "TICKR, TICKR FIT, TICKR X",
          color: Color(hex: "2563EB"),
          note: "Bluetooth LE HR-Profil"
        )
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
        brandRow(
          icon: "checkerboard.rectangle",
          name: "Alle anderen HR-Sensoren",
          models: "Suunto, CooSpo, Magene u.v.m.",
          color: GainsColor.softInk,
          note: "Standard BLE 0x180D"
        )
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
        whoopRow
        Divider().overlay(GainsColor.border.opacity(0.5)).padding(.horizontal, 14)
        appleWatchRow
      }
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(GainsColor.border.opacity(0.65), lineWidth: 1)
      )
    }
  }

  private func brandRow(icon: String, name: String, models: String, color: Color, note: String) -> some View {
    HStack(spacing: 12) {
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
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private var whoopRow: some View {
    HStack(spacing: 12) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
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
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private var appleWatchRow: some View {
    HStack(spacing: 12) {
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
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  // MARK: - Helpers

  private var stateColor: Color {
    switch ble.scanState {
    case .connected:            return GainsColor.lime
    case .scanning:             return Color.blue
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
