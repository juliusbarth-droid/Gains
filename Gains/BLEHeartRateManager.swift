import CoreBluetooth
import Foundation

// MARK: - Models

struct BLEDevice: Identifiable, Equatable {
  let id: UUID       // CBPeripheral.identifier
  let name: String
  var rssi: Int      // aktualisiert beim Scan

  static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool { lhs.id == rhs.id }
}

enum BLEScanState: Equatable {
  case bluetoothUnavailable
  case idle
  case scanning
  case connecting
  case connected
  case failed(String)

  var label: String {
    switch self {
    case .bluetoothUnavailable: return "Bluetooth nicht verfügbar"
    case .idle:                 return "Bereit"
    case .scanning:             return "Suche läuft …"
    case .connecting:           return "Verbinde …"
    case .connected:            return "Verbunden"
    case .failed(let msg):      return msg
    }
  }

  var isActive: Bool {
    if case .scanning = self { return true }
    if case .connecting = self { return true }
    return false
  }
}

// MARK: - Manager

/// Verwaltet die BLE-Verbindung zu Standard-Heart-Rate-Profil-Geräten (Service 0x180D).
/// Unterstützt: Polar H9/H10, Garmin HRM-Pro/Dual, Wahoo TICKR/TICKR FIT und alle anderen
/// Geräte, die den Standard-Bluetooth-Herzfrequenzdienst implementieren.
final class BLEHeartRateManager: NSObject, ObservableObject {
  static let shared = BLEHeartRateManager()

  // MARK: Published state

  @Published private(set) var scanState: BLEScanState = .idle
  @Published private(set) var discoveredDevices: [BLEDevice] = []
  @Published private(set) var connectedDevice: BLEDevice? = nil
  @Published private(set) var liveHeartRate: Int? = nil

  // MARK: Private

  private var central: CBCentralManager!
  private var activePeripheral: CBPeripheral?

  /// Standard BLE Heart Rate Service UUID
  private let hrServiceUUID = CBUUID(string: "180D")
  /// Heart Rate Measurement Characteristic UUID
  private let hrMeasurementUUID = CBUUID(string: "2A37")

  private override init() {
    super.init()
    // Initialisierung ohne sofortigen Scan – wartet auf Bluetooth-Bereitschaft
    central = CBCentralManager(delegate: self, queue: .main, options: [
      CBCentralManagerOptionShowPowerAlertKey: true
    ])
  }

  // MARK: - Public API

  var isConnected: Bool {
    if case .connected = scanState { return true }
    return false
  }

  func startScanning() {
    guard central.state == .poweredOn else {
      if central.state == .poweredOff || central.state == .unauthorized {
        scanState = .bluetoothUnavailable
      }
      return
    }

    discoveredDevices = []
    scanState = .scanning
    central.scanForPeripherals(
      withServices: [hrServiceUUID],
      options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
    )
  }

  func stopScanning() {
    central.stopScan()
    if case .scanning = scanState {
      scanState = .idle
    }
  }

  func connect(to device: BLEDevice) {
    guard
      let peripheral = discoveredDevices.first(where: { $0.id == device.id }),
      let cbPeripheral = central.retrievePeripherals(withIdentifiers: [peripheral.id]).first
    else { return }

    stopScanning()
    scanState = .connecting
    activePeripheral = cbPeripheral
    cbPeripheral.delegate = self
    central.connect(cbPeripheral, options: nil)
  }

  func disconnect() {
    guard let peripheral = activePeripheral else { return }
    central.cancelPeripheralConnection(peripheral)
  }

  // MARK: - Internal helpers

  private func parseHeartRate(from data: Data) -> Int? {
    guard data.count >= 2 else { return nil }
    let flags = data[0]
    // Bit 0: 0 = HF als UInt8, 1 = HF als UInt16
    if flags & 0x01 == 0 {
      return Int(data[1])
    } else {
      guard data.count >= 3 else { return nil }
      return Int(UInt16(data[1]) | UInt16(data[2]) << 8)
    }
  }

  /// Gibt ein lesbares Marken-Label zurück, wenn der Name einem bekannten Gerät entspricht.
  static func brandLabel(for name: String) -> String? {
    let n = name.lowercased()
    if n.contains("polar")  { return "Polar" }
    if n.contains("wahoo")  { return "Wahoo" }
    if n.contains("garmin") { return "Garmin" }
    if n.contains("tickr")  { return "Wahoo" }
    if n.contains("h10") || n.contains("h9") { return "Polar" }
    if n.contains("hrm")    { return "Garmin" }
    if n.contains("coospo") { return "CooSpo" }
    if n.contains("magene") { return "Magene" }
    if n.contains("suunto") { return "Suunto" }
    return nil
  }
}

// MARK: - CBCentralManagerDelegate

extension BLEHeartRateManager: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .poweredOn:
      if case .scanning = scanState { startScanning() }
    case .poweredOff, .unauthorized, .unsupported:
      scanState = .bluetoothUnavailable
      connectedDevice = nil
      liveHeartRate = nil
    default:
      break
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let name = peripheral.name
      ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
      ?? "Unbekanntes Gerät"
    let device = BLEDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue)

    if let index = discoveredDevices.firstIndex(where: { $0.id == device.id }) {
      discoveredDevices[index] = device   // RSSI aktualisieren
    } else {
      discoveredDevices.append(device)
      discoveredDevices.sort { $0.rssi > $1.rssi }  // Stärkstes Signal zuerst
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    scanState = .connected
    connectedDevice = discoveredDevices.first(where: { $0.id == peripheral.identifier })
    peripheral.discoverServices([hrServiceUUID])
  }

  func centralManager(
    _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?
  ) {
    scanState = .failed(error?.localizedDescription ?? "Verbindung fehlgeschlagen")
    activePeripheral = nil
    connectedDevice = nil
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    if activePeripheral?.identifier == peripheral.identifier {
      activePeripheral = nil
      connectedDevice = nil
      liveHeartRate = nil
      scanState = .idle
    }
  }
}

// MARK: - CBPeripheralDelegate

extension BLEHeartRateManager: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let service = peripheral.services?.first(where: { $0.uuid == hrServiceUUID }) else {
      return
    }
    peripheral.discoverCharacteristics([hrMeasurementUUID], for: service)
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    guard
      let characteristic = service.characteristics?.first(where: {
        $0.uuid == hrMeasurementUUID
      })
    else { return }

    // Notifications aktivieren → kontinuierliche HF-Updates
    peripheral.setNotifyValue(true, for: characteristic)
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didUpdateValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    guard characteristic.uuid == hrMeasurementUUID,
      let data = characteristic.value,
      let bpm = parseHeartRate(from: data)
    else { return }

    liveHeartRate = bpm

    // Auch in HealthKitManager spiegeln, damit RunTracker + WorkoutTracker
    // denselben Publisher nutzen können (BLE hat Prio).
    HealthKitManager.shared.setExternalHeartRate(bpm)
  }
}
