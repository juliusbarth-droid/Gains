# Gains – Debug-Session vom 27. April 2026

**Scope**: Vollständiger statischer Audit über 37 Swift-Dateien (~32.300 Zeilen).
**Toolchain**: Keine Swift-Compiler im Sandbox verfügbar — Pattern- und
Diff-basierte Analyse, kein echter `xcodebuild`. Logische Fehler und
Refactor-Diffs wurden manuell durchgegangen.

## Zusammenfassung

| Severity | Anzahl | Direkt gefixt |
|---|---|---|
| Critical (Crash/Akku/Datenkorruption) | 3 | ✅ 3 |
| High (Logik-Fehler im UX-Pfad) | 1 | ✅ 1 |
| Medium (Stilistisch/Speicher) | 3 | ✅ 1 (Force-Unwrap, weak self) |
| Low (Cosmetic / Lokalisierung) | 4 | ❌ 0 (dokumentiert) |

---

## Critical-Fixes (alle direkt im Code gefixt)

### 1. `RunLocationTracker.init()` startet GPS sofort nach View-Konstruktion

**Datei**: `Gains/RunTrackerView.swift` (Zeile ~1151)
**Symptom**: `manager.startUpdatingLocation()` lief schon im Pre-Run-Setup-Bildschirm. GPS lief permanent → Akku-Drain. Außerdem fütterte es den Delegate, was Folge-Bug #2 erst akut machte.
**Fix**: Aufruf aus `init()` entfernt — Updates startet jetzt explizit `beginTracking(from:)` (Zeile 1207) bzw. `resumeTracking()` (1239).

### 2. `locationManager(_:didUpdateLocations:)` ignoriert `isUsingGPS`-Flag

**Datei**: `Gains/RunTrackerView.swift` (Zeile ~1294)
**Symptom**: GPS-Updates wurden auch verarbeitet, wenn der User im Setup steckte. `trackedDistanceKm`, `routeCoordinates` und Splits liefen pre-tracking voll. `prepareTrackingState` setzte das zwar zurück, aber das Verhalten war fragil — und der Akku ist trotzdem leer.
**Fix**: `guard isUsingGPS else { return }` direkt am Anfang des Delegate-Callbacks.

### 3. `Weekday.referenceDate` liefert für Sonntag falschen Tag (DE-Locale)

**Datei**: `Gains/GymSharedComponents.swift` (Zeile 8 ff.)
**Symptom**: Naive Variante `self.rawValue - todayWeekday`. Sonntag hat `rawValue = 1`, Wochentage 2–7. An jedem Tag außer Sonntag selbst gab die Funktion **den vorigen Sonntag** zurück. Der Wochenstreifen im HEUTE-Tab zeigte deshalb für die Sonntags-Zelle ein falsches Completion-Häkchen (gegen vergangene Woche statt aktueller).
**Fix**: Mo-basierten Offset (0–6) für `self` und `today` berechnen, dann `diff = offset_self − offset_today`. Math durchgerechnet (Python-Verifikation), liefert für Sonntag-auf-Samstag jetzt korrekt +1, für Sonntag-auf-Mittwoch +4 etc.

---

## High-Severity Fix (gefixt)

### 4. `applyWizardSettings` überschreibt user-gesetzte Tagespräferenzen

**Datei**: `Gains/GainsStore.swift` (Zeile ~2187, in `applyWizardSettings`)
**Symptom**: Beim Drücken von "Plan übernehmen" am Ende des Wizards wurden alle 7 Wochentage auf `.flexible` gesetzt. Workflow:
1. User öffnet PLAN-Tab, markiert Mo/Di/Mi als Training, So als Frei.
2. User öffnet den Wizard, ändert nur Recovery-Kapazität.
3. User drückt "Plan übernehmen" → seine Tagspräferenzen sind **gelöscht**.

Der Wizard fragt diese Präferenzen nicht ab, hat sie aber zerstört.

**Fix**: Default-Setup auf `.flexible` läuft jetzt nur, wenn der User noch *gar keine* Präferenz hinterlegt hat (Erstkonfiguration nach Onboarding). Bestehende Tagspräferenzen bleiben unangetastet.

---

## Medium

### 5. `requestContactsAccess` capture-Issue

**Datei**: `Gains/GainsStore.swift` (Zeile ~2605)
**Symptom**: Closure capturete `self` strong. GainsStore lebt zwar app-lifetime, aber als Pattern bricht es out-of-band.
**Fix**: `[weak self]` + `guard let self else { return }`.

### 6. Force-Unwrap in `weeklyWorkoutSchedule`

**Datei**: `Gains/GainsStore.swift` (Zeile ~356)
**Symptom**: `template != nil ? "...\(template!.…)" : kind.title` — funktional safe (geguarded), aber durch `!` ein Crash-Magnet, falls jemand das Ternary umbaut.
**Fix**: Auf `guard let template else { return kind.title }`-Closure umgestellt — diff zeigt, dass das auch passiert ist (vermutlich Editor-Auto-Fix beim Speichern, aber jetzt drin).

### 7. `deleteWorkout` mutiert Dictionary während Iteration über `.keys`

**Datei**: `Gains/GainsStore.swift` (Zeile ~2024)
**Status**: NICHT gefixt — Swift-Wert-Semantik macht das in der Praxis safe, aber Pattern ist fragil.
**Empfehlung** (für späteren Cleanup):
```swift
for (weekday, planID) in plannerSettings.dayAssignments where planID == plan.id {
  plannerSettings.dayAssignments[weekday] = nil
}
```

---

## Low / Dokumentiert (nicht gefixt)

### 8. `finishRun` schluckt 0-km-Läufe still

**Datei**: `Gains/GainsStore.swift` (Zeile ~1966)
**Symptom**: `guard … run.distanceKm > 0 else { return }`. Wenn GPS gar nichts erfasst hat (Tunnel, Indoor, Permission-Problem), drückt der User "Speichern" und es passiert sichtbar nichts. Kein Toast, kein Hinweis. Der Lauf ist weg.
**Empfehlung**: Entweder mit 0 km speichern (Walking-Eintrag) oder im UI bevor der Stop-Sheet auftaucht prüfen und User informieren.

### 9. Wochenvolumen-Trend rechnet rolling 7-Tage statt Kalenderwoche

**Dateien**: `Gains/GymTodayTab.swift::weeklyVolumeTrend`, `Gains/GymStatsTab.swift::weeklyVolumeTrend`
**Symptom**: `now − 7d`, `now − 14d` etc. → "diese Woche" am Freitag enthält letztes Sa–Fr, nicht Mo–Fr. Vergleich mit "Vorwoche" semantisch verwirrend.
**Empfehlung**: Auf `Calendar.dateComponents([.yearForWeekOfYear, .weekOfYear])` umstellen.

### 10. `weeklyVolumeTrend` ist in zwei Tabs dupliziert

**Dateien**: `GymTodayTab.swift` und `GymStatsTab.swift` haben identische private `weeklyVolumeTrend`-Computeds.
**Empfehlung**: Auf `GainsStore` extrahieren — passt zum Muster der anderen Aggregat-Computeds dort.

### 11. Keine Accessibility-Annotationen, keine Lokalisierung

**Symptom**: 0 Treffer für `accessibilityLabel`/`accessibilityHint` im gesamten Code. Image-only Buttons (⋯-Menüs, X-Schließen, Lap-Buttons in RunTracker) haben keine VoiceOver-Texte. Keine `Localizable.strings`/`*.xcstrings` — App ist hardcoded Deutsch.
**Empfehlung**: Vor App-Store-Release mind. die hot-path-Buttons (Tracker, Sheets, Tab-Picker) mit `.accessibilityLabel(...)` ausstatten. Lokalisierung ist OK wenn Deutschland-only Strategie.

---

## Verifikation

| Fix | Verifiziert? | Wie |
|---|---|---|
| #1 `init` ohne start | ✅ | `grep -n startUpdatingLocation` zeigt nur 2 Treffer (`beginTracking`, `resumeTracking`) |
| #2 Delegate-Gate | ✅ | `grep -n 'guard isUsingGPS'` zeigt korrekten Guard auf Zeile 1294 |
| #3 referenceDate | ✅ | Python-Simulation aller 7×7 Tag/Heute-Kombinationen, alle Diffs ∈ [-6,+6] |
| #4 Wizard | ✅ | Diff-Review: `hasAnyPreference`-Guard sitzt vor dem Reset-Loop |
| #5 weak self | ✅ | Diff-Review |
| #6 Force-Unwrap | ✅ | Datei direkt re-gelesen, Pattern weg |

**Was nicht verifiziert wurde (kein Compiler in der Sandbox)**:
- Echter `swift build` / Xcode-Build wurde nicht ausgeführt. Die Fixes sind syntaktisch nach Swift-Regeln korrekt, aber bitte einmal lokal `xcodebuild` laufen lassen, bevor du die Änderungen pusht.
- Runtime-Verhalten der GPS-Tracker-Phasen (Setup → Countdown → Live) wurde nicht durchgespielt — die Phase-Kette ist neu in deinem uncommitteten Diff und sollte mind. einmal manuell auf Sim/Device durchgegangen werden.

---

## Empfohlener Commit-Plan

Vor `git commit` der gesamten uncommitteten Arbeit:

1. **Bug-Fix-Commit** (klein, einfach reviewbar): nur die 5 Fix-Dateien
   `GymSharedComponents.swift`, `GainsStore.swift` (Wizard + weak self),
   `RunTrackerView.swift` (init + delegate guard).
   → Subject: `Fix critical bugs: GPS pre-tracking drain, wizard wipes day prefs, Sun referenceDate`

2. **Refactor-Commit**: der Rest der Gym-Tab-Trennung und neue
   Models/Persistence-Felder als separater logischer Commit.

So bleibt der Bug-Fix bei Bedarf isoliert revertierbar.
