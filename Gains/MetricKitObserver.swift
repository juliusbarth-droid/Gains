import Foundation
import MetricKit
import UIKit

// MARK: - MetricKitObserver
//
// A7: Leichtgewichtige Crash- und Hang-Erfassung über Apples MetricKit.
//
// Was das macht:
//  - Registriert sich als `MXMetricManagerSubscriber` beim App-Start.
//  - Sammelt eintreffende Diagnose-Payloads (Crashes, Hangs, CPU-Spikes, Disk-Writes).
//  - Speichert die letzten 10 Reports lokal in UserDefaults (JSON).
//  - Liefert sie via Share-Sheet aus dem Profil-DEBUG-Bereich exportierbar aus.
//
// Eigenschaften:
//  - MetricKit-Reports liefert Apple ca. einmal pro Tag, gebündelt.
//  - In `DEBUG`-Builds kannst du `MXMetricManager.shared.add(...)` testen über
//    Xcode → Debug → Simulate MetricKit Payloads.
//  - Reports enthalten KEINE persönlich identifizierenden Daten — nur
//    Stack-Traces, App-Metriken und System-Versionen.

final class MetricKitObserver: NSObject, MXMetricManagerSubscriber, ObservableObject {
  static let shared = MetricKitObserver()

  /// Anzahl der gespeicherten Diagnose-Reports — getrieben fürs UI.
  @Published private(set) var diagnosticCount: Int = 0

  private let storageKey = "gains_metricKit_diagnostics"
  private let maxStoredReports = 10

  private override init() {
    super.init()
    diagnosticCount = loadStoredEntries().count
  }

  // Wird aus `GainsApp` einmal beim Start aufgerufen.
  func register() {
    MXMetricManager.shared.add(self)
  }

  // MARK: - MXMetricManagerSubscriber

  // Reine Performance-Metriken (Battery, Launch-Time etc.) — sammeln wir
  // aktuell nicht aktiv, könnten aber für späteres Monitoring nützlich sein.
  func didReceive(_ payloads: [MXMetricPayload]) {
    // Bewusst leer — wir konzentrieren uns auf Diagnose-Payloads (Crashes/Hangs).
  }

  // Crashes, Hangs, CPU-Exceptions, Disk-Write-Exceptions.
  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    var existing = loadStoredEntries()
    let newEntries = payloads.flatMap { Self.entries(from: $0) }
    existing.append(contentsOf: newEntries)
    // Auf die letzten N kürzen, damit UserDefaults nicht voll läuft.
    if existing.count > maxStoredReports {
      existing = Array(existing.suffix(maxStoredReports))
    }
    saveEntries(existing)
    DispatchQueue.main.async { [weak self] in
      self?.diagnosticCount = existing.count
    }
  }

  // MARK: - Storage

  func loadStoredEntries() -> [DiagnosticEntry] {
    guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
    return (try? JSONDecoder().decode([DiagnosticEntry].self, from: data)) ?? []
  }

  func clearStoredEntries() {
    UserDefaults.standard.removeObject(forKey: storageKey)
    DispatchQueue.main.async { [weak self] in
      self?.diagnosticCount = 0
    }
  }

  /// Hängt einen aufbereiteten Text-Report an, der z.B. via Mail/Share
  /// rausgegeben werden kann. Format ist plain-text, leicht zu lesen.
  func exportableText() -> String {
    let entries = loadStoredEntries()
    guard !entries.isEmpty else {
      return "Keine MetricKit-Diagnose-Reports gespeichert."
    }
    let formatter = ISO8601DateFormatter()
    var lines: [String] = ["Gains – MetricKit-Diagnose-Export"]
    lines.append("Anzahl Reports: \(entries.count)")
    lines.append("Generiert: \(formatter.string(from: Date()))")
    lines.append("App-Version: \(Self.appVersionString)")
    lines.append("")
    for (index, entry) in entries.enumerated() {
      lines.append("── Report #\(index + 1) — \(entry.kind) ──")
      lines.append("Empfangen: \(formatter.string(from: entry.receivedAt))")
      lines.append("App: \(entry.appVersion) (\(entry.buildVersion))")
      lines.append("OS:  \(entry.osVersion)")
      if !entry.summary.isEmpty {
        lines.append("Detail:")
        lines.append(entry.summary)
      }
      lines.append("")
    }
    return lines.joined(separator: "\n")
  }

  // MARK: - Helpers

  private func saveEntries(_ entries: [DiagnosticEntry]) {
    guard let data = try? JSONEncoder().encode(entries) else { return }
    UserDefaults.standard.set(data, forKey: storageKey)
  }

  private static func entries(from payload: MXDiagnosticPayload) -> [DiagnosticEntry] {
    var results: [DiagnosticEntry] = []
    let received = payload.timeStampEnd
    // App-Version stammt aus dem Bundle der laufenden App (zum Zeitpunkt
    // des Empfangs); Build- und OS-Version liegen pro Diagnose-Objekt
    // in dessen `metaData` (nicht auf dem Payload).
    let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"

    if let crashes = payload.crashDiagnostics {
      for crash in crashes {
        results.append(DiagnosticEntry(
          kind: "Crash",
          receivedAt: received,
          appVersion: appVersion,
          buildVersion: crash.metaData.applicationBuildVersion,
          osVersion: crash.metaData.osVersion,
          summary: Self.summarize(crash)
        ))
      }
    }
    if let hangs = payload.hangDiagnostics {
      for hang in hangs {
        results.append(DiagnosticEntry(
          kind: "Hang",
          receivedAt: received,
          appVersion: appVersion,
          buildVersion: hang.metaData.applicationBuildVersion,
          osVersion: hang.metaData.osVersion,
          summary: Self.summarize(hang)
        ))
      }
    }
    if let cpuExceptions = payload.cpuExceptionDiagnostics {
      for cpu in cpuExceptions {
        results.append(DiagnosticEntry(
          kind: "CPU-Exception",
          receivedAt: received,
          appVersion: appVersion,
          buildVersion: cpu.metaData.applicationBuildVersion,
          osVersion: cpu.metaData.osVersion,
          summary: Self.summarize(cpu)
        ))
      }
    }
    if let diskExceptions = payload.diskWriteExceptionDiagnostics {
      for disk in diskExceptions {
        results.append(DiagnosticEntry(
          kind: "Disk-Write-Exception",
          receivedAt: received,
          appVersion: appVersion,
          buildVersion: disk.metaData.applicationBuildVersion,
          osVersion: disk.metaData.osVersion,
          summary: Self.summarize(disk)
        ))
      }
    }
    return results
  }

  private static func summarize(_ crash: MXCrashDiagnostic) -> String {
    var parts: [String] = []
    if let signal = crash.signal {
      parts.append("Signal: \(signal.intValue)")
    }
    if let exceptionType = crash.exceptionType {
      parts.append("Exception-Type: \(exceptionType.intValue)")
    }
    if let exceptionCode = crash.exceptionCode {
      parts.append("Exception-Code: \(exceptionCode.intValue)")
    }
    if let reason = crash.terminationReason {
      parts.append("Termination: \(reason)")
    }
    parts.append("StackTrace JSON-Größe: \(crash.callStackTree.jsonRepresentation().count) Bytes")
    return parts.joined(separator: "\n")
  }

  private static func summarize(_ hang: MXHangDiagnostic) -> String {
    let duration = hang.hangDuration
    let seconds = duration.converted(to: .seconds).value
    return String(format: "Hang-Dauer: %.2f s", seconds)
  }

  private static func summarize(_ cpu: MXCPUExceptionDiagnostic) -> String {
    let cpuTime = cpu.totalCPUTime.converted(to: .seconds).value
    let sample = cpu.totalSampledTime.converted(to: .seconds).value
    return String(format: "CPU-Time: %.2fs / Sample: %.2fs", cpuTime, sample)
  }

  private static func summarize(_ disk: MXDiskWriteExceptionDiagnostic) -> String {
    let mb = disk.totalWritesCaused.converted(to: .megabytes).value
    return String(format: "Schreibzugriffe: %.1f MB", mb)
  }

  private static var appVersionString: String {
    let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    return "\(v) (\(b))"
  }
}

// MARK: - DiagnosticEntry

struct DiagnosticEntry: Codable, Identifiable {
  var id: UUID = UUID()
  let kind: String
  let receivedAt: Date
  let appVersion: String
  let buildVersion: String
  let osVersion: String
  let summary: String
}
