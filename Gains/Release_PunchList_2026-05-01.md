# Gains — Release-Punch-List (verifiziert)

Stand: 2026-05-01 · Build 1.0(2) · für TestFlight-Push

Verifiziert gegen den echten Code, nicht nur Audit-Hypothesen. Was hier steht, ist mit Datei + Zeilennummer belegt. Audit-Behauptungen, die sich beim Verify als falsch herausgestellt haben (z.B. „Timer auf .common pausiert in Background"), sind **rausgeflogen**.

Reihenfolge: P0 zuerst — das blockiert TestFlight oder beschädigt Tester-Daten. P1 = sichtbare Funktionsfehler, vor Tester-Einladung fixen. P2 = Polish, kann auch nach erstem Upload kommen.

---

## P0 — Blocker (vor TestFlight-Upload)

### P0-1 · Drei verwaiste neue Files im Repo

**Files:** `Gains/RunGoalPlanModels.swift`, `Gains/RunGoalPlanView.swift`, `Gains/WeekdayDetailSheet.swift` — alle drei `untracked`, nirgends referenziert (`grep` über das gesamte Repo).

**Was ist:** Du hast offensichtlich an einem Goal-Planer-Feature und einer Wochentag-Detail-Sheet gearbeitet, das ist halb fertig liegengeblieben. `WeekdayDetailSheet.swift:561` versucht `runTemplate?.modality` zu lesen — dieses Feld existiert auf `RunTemplate` (Models.swift:1696–1705) **nicht**. Die Memory von 3 Tagen ago behauptete, `CardioModality` sei als Feld auf `RunTemplate` ausgerollt — das stimmt nicht: das Konzept existiert nur in WeekdayDetailSheet selbst und wäre ein Compile-Fehler, sobald die Datei in den Build kommt.

**Wirkung:** Solange untracked, kein Buildfehler. Aber: drei Files im Working Tree, die bei jedem Commit übersehen werden können. Wenn du das Repo neu klonst, sind sie weg.

**Entscheidung gefragt:**
- (a) **Löschen** — wenn das Goal-Planer-Feature noch nicht TestFlight-relevant ist.
- (b) **Zu Ende bauen** — `CardioModality` enum + `modality: CardioModality?` auf RunTemplate ergänzen, RunGoalPlanView in einen Tab/Sheet einbinden, committen.

Empfehlung: für TestFlight **(a) Löschen**, weil das Feature zusätzliche Komplexität bringt, die du noch nicht testen lassen willst. Du kannst einen Stash anlegen, falls du später dran willst.

---

### P0-2 · Persistence-Versioning fehlt komplett

**Datei:** `GainsPersistence.swift` (über das ganze Repo: kein Match für `persistenceVersion`).

**Was ist:** Der Roadmap-Punkt A5 fordert einen `PersistenceVersion`-Key in UserDefaults. Existiert nicht. Alle Codables decodieren über `PropertyListDecoder`/`JSONDecoder` ohne Versions-Hook und ohne durchgängiges `decodeIfPresent` (Memory sagte schon 2026-04-27: nur `WorkoutPlannerSettings` ist tolerant).

**Wirkung:** Sobald du ein neues Feld zu `CompletedWorkoutSummary`, `CompletedRunSummary` oder `NutritionEntry` hinzufügst, verlieren TestFlight-Tester ihre Historie beim ersten Update. Genau das, was Phase A vermeiden sollte.

**Fix:**
- `gains_persistenceVersion: Int` in UserDefaults.
- In `GainsPersistence.swift` ein `migrateIfNeeded()`, das beim App-Start gerufen wird.
- Kurzfristig: alle `Decodable`-Initializer auf `decodeIfPresent` mit Defaults umstellen. Genug für Beta — strukturierte Migration ist erst Phase C.

Aufwand: ~1h für tolerantes Decoding über alle ~12 Codables. Ich kann das in einem Pass machen, wenn du grünes Licht gibst.

---

### P0-3 · Leere Workouts landen in der Historie

**Datei:** `GainsStore.swift:2458`

```swift
func finishWorkout() {
  guard let workout = activeWorkout else { return }
  // KEIN Guard auf workout.completedSets > 0
  ...
  workoutHistory.insert(summary, at: 0)
```

**Wirkung:** User tippt versehentlich „WORKOUT BEENDEN" ohne einen Satz zu loggen → leerer Eintrag (0 Sätze, 0 kg) in History. Verfälscht Streak, Volumen-Sparkline, Wochenring, Stats. Tester sieht Geister-Workouts.

**Fix (5min):**
```swift
guard let workout = activeWorkout else { return }
guard workout.completedSets > 0 else {
  discardWorkout()  // existiert vermutlich schon
  return
}
```

---

### P0-4 · `discardActiveRun` lässt structured Workout zurück

**Datei:** `GainsStore.swift:1861`

```swift
func discardActiveRun() {
  guard activeRun != nil else { return }
  activeRun = nil
  lastProgressEvent = "Lauf verworfen — keine Änderung in der History."
}
// activeStructuredWorkout bleibt!
```

**Wirkung:** Wenn ein Lauf mit strukturiertem Workout (Intervalle/Phasen) abgebrochen wird, behält der Store den `activeStructuredWorkout`. Der nächste Lauf-Start lädt die alten Steps wieder ein. Du hast dafür in den letzten Commits („release: clear stop sheet state on run close") schon andere Symptome bekämpft, aber die Root Cause ist hier.

**Fix (1 Zeile):** `activeStructuredWorkout = nil` in `discardActiveRun()`.

---

### P0-5 · Race zwischen `saveAll()` und Onboarding-Abschluss

**Datei:** `OnboardingView.swift:812-813`

```swift
store.saveAll()       // async (vermutlich .global(qos: .utility))
hasCompletedOnboarding = true   // synchron @AppStorage
```

**Wirkung:** Tester killt App in dem Sekundenbruchteil zwischen den zwei Zeilen → AppStorage-Flag persistiert (UserDefaults.standard schreibt sehr schnell), aber `nutritionProfile`/`plannerSettings` noch nicht. Nächster Start: ContentView statt Onboarding, aber mit Default-Profil (175g Protein default, etc.). Tester denkt: „Hä, mein Profil ist verschwunden."

**Fix:**
- Entweder `saveAll()` mit Completion: `store.saveAll { hasCompletedOnboarding = true }`.
- Oder synchroner Save-Pfad fürs Onboarding-Finish (UserDefaults sync writes sind sub-millisekunden, kein Performance-Problem).

Ich empfehle Option 2 — sauberster Fix.

---

## P1 — Sichtbare Funktionsfehler (vor Tester-Einladung)

### P1-1 · Notifications-Permission wird im Onboarding sofort getriggert

**Datei:** `OnboardingView.swift:438`

```swift
NotificationsManager.shared.requestAuthorization { granted in ... }
```

Während Health/Location/Bluetooth nur **erklärt** werden (gemäß Best Practice), feuert die Notifications-Card direkt den System-Prompt. Die TestFlight-Briefing-Aussage „Permissions kommen erst beim ersten echten Use" stimmt für Notifications nicht.

**Fix:** Notifications auch nur erklären — der Trigger kommt dann beim ersten Workout-Reminder-Setup oder im Profil. Oder: Button-Label klar machen („Tippe um Erinnerungen zu aktivieren").

---

### P1-2 · `HomeView` hat 4 parallele `@State`-Sheet-Trigger ohne Mutual-Exclusion

**Datei:** `HomeView.swift` (mehrere `isShowingX = true`-Pfade)

`isShowingWorkoutChooser`, `isShowingWorkoutBuilder`, `isShowingWorkoutTracker`, `isShowingRunTracker` sind alle independent Booleans. Bei schnellem Doppel-Tap oder Tab-Wechsel kann theoretisch mehr als eins `true` sein → SwiftUI zeigt das oberste, aber State leakt. Das passt zu deinem Commit-Muster der letzten Wochen („clear stale arrange callbacks", „reset run tracker before template start").

**Fix:** Enum-basiertes Sheet-Routing:
```swift
enum HomeSheet: Identifiable { case chooser, builder, tracker, runTracker; var id: Self { self } }
@State private var activeSheet: HomeSheet?
.sheet(item: $activeSheet) { sheet in ... }
```

Aufwand: ~30min. Macht die Symptom-Patches der letzten Commits überflüssig, weil nur noch ein State zur Zeit aktiv sein kann.

---

### P1-3 · Pause-Timer im Strength-Trainer überlebt App-Backgrounding nicht sauber

**Datei:** `WorkoutTrackerView.swift` — `restTimerEndsAt`-State im View, kein Persistence.

**Was ist:** Pause-Timer ist ein `Date`-Endpunkt im View-State. Wenn iOS die App in den Hintergrund schickt und später aus dem Speicher wirft, verliert der Timer den State. App neu öffnen → Trainer ist auf Set 3 zurück, aber Pause-Anzeige ist weg. (Der Audit-Befund „Timer auf .common pausiert in Background" war falsch — `.common` ist genau richtig. Aber Memory-Eviction ist real.)

**Fix:** `restTimerEndsAt` in `GainsStore.activeWorkout` reinziehen, sodass es mit dem Workout persistiert wird. Beim Resume aus Background den Endpunkt einfach gegen `Date()` vergleichen.

---

### P1-4 · `RunTrackerView` Close-Button hat 3 verschiedene Verhalten

**Datei:** `RunTrackerView.swift:64-90`

In `.setup` und `.countdown` ruft Close direkt `discardActiveRun()`, in `.live` öffnet es `showsStopSheet`. Inkonsistent — wenn der User in `.countdown` versehentlich „×" tippt, ist der Lauf weg ohne Bestätigung.

**Fix:** Unified Cleanup-Pfad. Mindestens: in `.countdown` auch eine Bestätigung („Lauf verwerfen?"), weil die Vorbereitung (Ziel/Modus) sonst weg ist.

---

### P1-5 · Lauf < 30s kann nicht gespeichert werden, > 60s wird gerundet

**Datei:** `RunTrackerView.swift` (`canSaveRun`-Logik in StopRunSheet)

```swift
return run.distanceKm > 0 || run.durationMinutes >= 1
```

`durationMinutes` ist `Int`. 45 Sekunden = `0` → Save disabled. 65 Sekunden = `1` → Save enabled, aber als „1 min" gespeichert (statt 1:05).

**Fix:** Auf `elapsedSeconds` umstellen, mindestens für die Save-Bedingung. In der History eine `durationSeconds: Int` zusätzlich speichern (wäre auch besser für Pace-Berechnungen).

---

### P1-6 · Foto-KI ohne Fallback-Hinweis auf älteren iPhones

**Datei:** `AppleFoundationModelsClient.swift:37-51`

`isAvailable == false` für iOS < 26 oder iPhone 14/15 non-Pro. UI zeigt trotzdem den „Foto"-Button. Tap → spinner → Fehler („Apple Foundation Models nicht verfügbar"). Frustrierend.

**Fix:** In `FoodPhotoRecognitionView` und im Capture-Sheet conditional rendern. Oder klare Empty-State-Card: „KI-Foto erfordert iPhone 15 Pro / iOS 26 oder neuer — nutze Suche oder Barcode-Scan."

---

### P1-7 · GPS-Distanz akzeptiert nur 3–250m-Sprünge

**Datei:** `RunTrackerView.swift` (RunLocationTracker, ~Z. 1488)

```swift
if delta >= 3, delta <= 250 { trackedDistanceKm += ... }
```

3m-Untergrenze ist sinnvoll (GPS-Jitter), 250m-Obergrenze ist zu harsch — schnelle Bergab-Sprints oder kurze Tunnel-Recovers fallen raus. Außerdem: kein Plausibilitäts-Check über `location.speed`.

**Fix:** Statt fester Obergrenze: Geschwindigkeits-basierte Validierung. `delta / dt > maxRealisticSpeed (~10 m/s für Lauf, ~25 m/s für Rad)` → verwerfen. So fängst du echte GPS-Sprünge raus, ohne legitime schnelle Distanzen zu opfern.

---

### P1-8 · Onboarding kennt kein Bodyfat-% → Protein-Ziel zu hoch für übergewichtige Tester

**Datei:** `OnboardingView.swift:782-790`

`bodyFatPercent: nil` → Mifflin-St-Jeor mit Gesamtgewicht statt Lean Mass. User mit 80kg / 25% BF bekommt 160g Protein-Ziel (2.0 × 80) statt 120g (2.0 × 60 lean). Nicht falsch, aber im oberen Ende.

**Fix (optional für Beta):** Ein optionaler Slider „Ungefährer Körperfett-Anteil" mit „weiß ich nicht"-Skip. Nicht TestFlight-blockierend, aber wenn du Tester aus deinem Umfeld hast, die das selbst beurteilen können, wert.

---

## P2 — Polish (kann auch nach erstem Upload)

- **P2-1** · `WorkoutHubView` hat 7 `.sheet`-Modifier auf einer View — dasselbe Enum-Routing wie HomeView.
- **P2-2** · `NutritionTrackerView` hat 4 parallele `@State`-Sheet-Trigger — siehe oben.
- **P2-3** · `CoachView.swift` ist Dead Code laut Memory — gibt's noch versteckte Navigation dorthin? `grep` lief nicht durch in der Audit-Tiefe — verifizieren.
- **P2-4** · BMR-Berechnung im Onboarding ohne sichtbare Herleitung — Tester sieht „2865 kcal" ohne Begründung.
- **P2-5** · `WaterTracker` Rück-Button — kann Wasser-Wert auf negativ gehen? Schnell-Verify.
- **P2-6** · Wochenring zeigt „0/0" bei Fresh Install statt „Plan ausstehend".

---

## VERWORFEN (Audit-Befunde, die beim Verify nicht standhielten)

- ❌ „WorkoutTrackerView Timer auf `.common` RunLoop pausiert in Background" — `.common` ist exakt der richtige Mode. Falsch.
- ❌ „CardioModality fehlt auf RunTemplate, daher Crash" — kein Crash heute, weil der Aufrufer (`WeekdayDetailSheet`) gar nicht im Build ist (siehe P0-1).
- ❌ Diverse „VERIFY"-Findings zu CaptureSheet-State-Reset — das State-Verhalten der Capture-Form ist im jetzigen Code korrekt isoliert.

---

## Empfohlene Reihenfolge

1. **P0-1 entscheiden** (Files löschen oder fertigbauen) — ohne diese Entscheidung schwirrt halb-fertiger Code im Repo.
2. **P0-2, P0-3, P0-4, P0-5** in einem Schwung — alles kleine, isolierte Code-Änderungen, kein Refactoring.
3. **P1-2** (HomeView Enum-Sheet-Routing) — adressiert die Root Cause der letzten 15 „release: clear stale ..."-Commits.
4. **P1-1, P1-6** — UX-Patches, ~10min jeweils.
5. **P1-3, P1-5, P1-7** — Tracker-Robustheit. Ein Block.
6. **Pre-Flight Test:** App löschen, neu installieren, Onboarding durchgehen, Workout starten + abbrechen, Lauf starten + abbrechen, Mahlzeit loggen. Wenn das ohne Murren läuft → Archive + Upload.
