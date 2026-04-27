# Gains — TestFlight-Briefing

Stand: 2026-04-27 · Build 1.0 (2)

Dieses Dokument enthält alles, was du in App Store Connect eintragen musst, plus eine Checkliste für den ersten TestFlight-Upload.

---

## 1. Vor dem Upload — Checkliste

- [ ] **Xcode → Cmd+Shift+K** (Clean Build Folder), damit die neuen Dateien (ExerciseCatalog, WorkoutTrackerEntryView, OnboardingView, MetricKitObserver, PrivacyInfo.xcprivacy) sauber gebündelt werden.
- [ ] **App-Icon vollständig exportieren** — `Gains/AppIconSource.svg` muss als PNG-Set in `Assets.xcassets/AppIcon.appiconset/` liegen. Tool-Optionen: [appiconmaker.co](https://appiconmaker.co), [Bakery (Mac App Store)](https://apps.apple.com/de/app/bakery-icon-designer/id1575220747), oder lokal mit `rsvg-convert` + Skript. Brauchst alle Größen für iPhone (40, 60, 58, 87, 80, 120, 180) und das 1024×1024-Marketing-Icon.
- [ ] **Build & Archive in Xcode** — `Product → Archive`. Bei Bundle-ID `com.julius.gains` mit DEV_TEAM `DUZJZ3867T` automatisch.
- [ ] **Im Organizer: Distribute App → App Store Connect → Upload**. Apple validiert das Privacy-Manifest beim Upload — wenn was fehlt, kommt ein klarer Fehler.
- [ ] **In App Store Connect**: Build erscheint nach 5–15 Minuten Processing. Erst dann kannst du Tester einladen.

---

## 2. App-Beschreibung (TestFlight)

Diese Texte gehen in App Store Connect → TestFlight → App-Information.

### Beta-App-Beschreibung (max 4000 Zeichen)

> Gains ist eine private Fitness-App für Krafttraining, Laufen, Ernährung und Fortschritt — alles in einer App, ohne Quatsch.
>
> **In dieser Beta dabei:**
> - Krafttraining-Tracker mit über 90 Übungen, Anleitungen und Whoop-Style-Workout-Auswahl
> - Lauf-Tracker per GPS mit Pace, Splits, Höhenmeter und Bluetooth-HF-Sensor-Anbindung
> - Ernährungs-Tracking via Suche, Barcode oder KI-Fotoerkennung
> - Apple-Health-Integration für Schritte, Schlaf, VO2max und Recovery
> - Persönliches Onboarding mit Berechnung deiner Kalorien- und Proteinziele
>
> **Noch in Arbeit:**
> - Community-Bereich (Feed, Forum, Meetups) — kommt mit Backend in Phase 2
> - Coach-Empfehlungen werden noch verfeinert
>
> Die App speichert alle Daten lokal auf deinem Gerät. Kein Account, kein Server, keine Werbung.

### Was zu testen ist (Test-Information)

> **Bitte teste:**
> 1. Onboarding (4 Schritte) — fühlt sich der Flow natürlich an? Profil-Daten plausibel?
> 2. Krafttraining starten und beenden — funktioniert der ganze Pfad? Volumen korrekt?
> 3. Lauf starten und beenden — GPS-Genauigkeit, Pace-Anzeige, Splits.
> 4. Ernährung loggen — Suche, Barcode-Scan, Foto-Erkennung.
> 5. Übungs-Bibliothek (Toolbar-Button im Trainer) — alle 90+ Übungen durchsuchbar mit Erklärung.
>
> **Bekannte Einschränkungen:**
> - Community-Tab zeigt absichtlich „Coming Soon".
> - Coach-Empfehlungen sind noch generisch (Backend folgt in Phase 2).
> - Übungs-Detail-Sheets zeigen aktuell noch keine Video-Demos.
>
> **Wenn etwas abstürzt:** Profil → Diagnose → „Reports teilen" und das Ergebnis an mich senden. iOS sammelt die Crash-Reports automatisch.

### Feedback-Email
> julius.barth@outlook.com

---

## 3. Privacy-Manifest — was drin steht

`Gains/PrivacyInfo.xcprivacy` deklariert (Apple Pflicht seit 2024):

**Tracking:** Keines (`NSPrivacyTracking = false`).

**Erfasste Datentypen** (alle nur für App-Funktion, nicht verlinkt mit Identität, kein Tracking):
- Health & Fitness (HealthKit-Lesezugriff)
- Präziser Standort (für Lauf-GPS)
- Kontakte (optional, nur Community-Tab)

**API-Reasons:**
- `CA92.1` — UserDefaults für lokale App-Persistenz
- `35F9.1` — Boot-Time-Zugriff (App-Funktionalität)
- `C617.1` — File-Timestamps (App-Funktionalität)
- `E174.1` — Disk-Space (App-Funktionalität)

Wenn Apple beim Upload zusätzliche Reasons fordert (weil ein Framework etwas nutzt), kommt eine konkrete Fehlermeldung. Dann den entsprechenden API-Eintrag im PrivacyInfo.xcprivacy ergänzen.

---

## 4. App-Privacy-Section in App Store Connect

Beim Veröffentlichen im App Store (Phase B / v1.0) musst du in App Store Connect → App-Privacy ausfüllen. Die Antworten passen zum Privacy-Manifest:

- **Trackt diese App den Nutzer?** Nein.
- **Erfasste Daten:**
  - Health & Fitness — App-Funktionalität, nicht verlinkt mit Identität, kein Tracking
  - Präziser Standort — App-Funktionalität, nicht verlinkt mit Identität, kein Tracking (nur während eines Laufs)
  - Kontakte — App-Funktionalität, nicht verlinkt mit Identität, kein Tracking (nur Community, opt-in)

---

## 5. Die wichtigsten Beta-Tester-Briefing-Punkte

Wenn du Tester einlädst, sag ihnen:

1. **Erstinstallation:** Onboarding läuft beim ersten Start automatisch (4 Schritte).
2. **Profil-Daten:** Werden lokal gespeichert, nicht hochgeladen.
3. **Berechtigungen:** Frag nicht alle gleichzeitig — die System-Prompts kommen erst, wenn du das jeweilige Feature nutzt (Lauf starten → Standort, HF-Sensor verbinden → Bluetooth).
4. **Crashes:** Profil → Diagnose → Reports teilen. iOS sendet die Reports erst nach 24 Stunden, also den Tag drauf nochmal nachschauen.
5. **Nicht testen brauchen wir:** Community-Tab (ist absichtlich noch nicht live).

---

## 6. Was nach dem ersten TestFlight-Build kommen soll

Sobald 2-3 Tester reingeschaut haben, sammle Feedback und entscheide, was als nächstes kommt:

- **Phase B vorbereiten:** Backend-Setup (Supabase / CloudKit) — siehe `Release_Roadmap.md` Abschnitt 4.
- **App-Icon final** falls noch nicht passiert.
- **Localization (EN)** wenn nicht-deutschsprachige Tester dazukommen.
- **Sentry / TelemetryDeck** als Ergänzung zu MetricKit, wenn du anonyme Nutzungs-Stats willst.

---

## 7. Was im Code für die Beta steht

Phase A (komplett):
- Mocks aus dem Live-Pfad entfernt — frische Installation startet leer.
- Community-Tab zeigt ehrliche „Coming Soon"-Surface mit Waitlist-Toggle.
- Vereinheitlichter `EmptyStateView`-Baustein über alle Tabs.
- 4-Schritt-Onboarding mit Profil-Berechnung (BMR, TDEE, Protein-Ziel).
- Lesbarkeits-Pass: Body-Default 17pt, dunklerer softInk, weniger aggressives Tracking auf Section-Header.
- Persistence-Migration mit Versions-Hook und tolerantem Array-Loader.
- Sheet-Choreografie sauber über `onDismiss` statt `asyncAfter`.
- MetricKit-Crash-Reporting + Share-Sheet aus dem Profil.
- Privacy-Manifest und Build-Bump auf (2).

Phase B (nicht in dieser Beta):
- Auth (Sign in with Apple)
- Backend (Posts, Forum, Meetups)
- Echter Coach mit Daten-getriebener Empfehlung
- Push-Notifications

Phase C (App-Store-v1.0):
- XCTest-Suite
- iPad-Layout oder iPhone-only festlegen
- Englische Localization
- Accessibility-Pass (Dynamic Type, VoiceOver)
