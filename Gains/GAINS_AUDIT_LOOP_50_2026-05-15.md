# Gains 50er Audit-Fix-Loop — 2026-05-15

Systematischer Sweep durch alle Submenus. 50 Loops mit konkretem Fix oder Bestätigung "OK".

## Zusammenfassung

22 substanzielle Fixes / Cleanups (Bugs, Inkonsistenzen, Dead-Code, UX).
Rest waren OK-Verifikationen oder Architektur-bedingt-fine.

---

## Loop 1 — Repo-Hygiene: `DesignSystem.swift.bak`
- Verwaiste Backup-Datei aus dem Source-Tree entfernt (deletion permission granted).
- Datei war nicht im Xcode-Projekt referenziert, aber polluted das Repo.

## Loop 2 — WeekPlanFullscreen Progress-Ring: `done > total`-Bug
- `weekDoneSessions` konnte `weekTotalSessions` übersteigen (spontane Workouts an `flexible`-Tagen).
- Ring zeigte „4/3" und Trim überlief 1.0.
- Fix: `done` + `progress` gegen `total` gekappt, plus „—"-Fallback wenn `total == 0`. A11y-Label ergänzt.

## Loop 3 — Duplikat-Eyebrow "DIESE WOCHE"
- Hero-Header UND weekStripSection hatten beide den Eyebrow „DIESE WOCHE".
- Fix: weekStripSection → „TAGE & TRAINING" (beschreibender, eindeutig).

## Loop 4 — Activer-Run-Resume-Banner fehlte
- Workout hatte einen „LÄUFT JETZT"-Banner im Fullscreen-Plan, aktiver Run nicht.
- Fix: `activeRunResumeBanner` analog implementiert, Bike-Icon je nach `modality`.

## Loop 5 — GymView ContentView allgemein
- Aufbau geprüft, sauber. Keine Änderung.

## Loop 6 — Sheet-Race-Hardening WorkoutTrackerView
- Bestehender Code mit `.task(id:)`-Pattern für Pause-Timer + Undo-Snackbar — sauber.
- Keine Änderung.

## Loop 7 — CoachView (DEPRECATED)
- Als "Phase B Referenz" dokumentiert, kein Live-Code-Pfad. Belassen.

## Loop 8 — FoodPhotoRecognition `ScanningDotsView`-Timer
- `Timer.scheduledTimer` + manuelles `invalidate()` ersetzt durch `.task`-Pattern.
- View-Lifetime ist jetzt einzige Quelle der Wahrheit, kein Race bei Sheet-Toggles.

## Loop 9 — RecipesView: `DispatchQueue.main.asyncAfter` → Task
- Quick-Track-Feedback-Token-Reset auf `Task { @MainActor in … sleep … }` umgestellt.
- Konsistent mit dem Rest der App (Sheet-Race-Hardening 2026-05-14).

## Loop 10 — Dead-Code-Audit
- Keine `print()` außer dem ENC-Fehler-Log in `GainsPersistence`. OK.

## Loop 11 — Day-One-Window-Inkonsistenz Cardio-Hub
- `WorkoutHubView.isInRunDayOneWindow` hatte noch die 24h-Schranke.
- GymTodayTab hatte sie schon entfernt (P1-2, 2026-05-03) — Begründung gilt analog für Cardio.
- Fix: 24h-Cap raus, Tour läuft bis erster Lauf in `runHistory`.

## Loop 12 — Day-One-Window-Inkonsistenz Ernährung
- `NutritionTrackerView.isInNutritionDayOneWindow` hatte ebenfalls noch die 24h-Schranke.
- Fix: 24h-Cap raus, Banner läuft bis erste `nutritionEntries`.
- Drei Day-One-Banner sind jetzt konsistent.

## Loop 13 — HomeView `isInDayOneWindow` bewusst unverändert
- Verifiziert: Home hat zusätzlich einen Re-Engagement-Brief, der bei `!isInDayOneWindow && noSessions` greift.
- Das 24h-Cap ist hier load-bearing — würde man es entfernen, würde der Re-Engagement-Brief nie feuern.

## Loop 14 — Toter Binding `showsPlanWizard` in GymTodayTab
- Binding war deklariert + von GymView weitergereicht, aber niemals gelesen.
- Fix: Binding aus GymTodayTab entfernt, Aufruf in GymView angepasst.

## Loop 15 — GymView State-Check
- Übrige States werden genutzt (showsPlanWizard / showsCustomPlanBuilder → GymPlanTab). OK.

## Loop 16 — WeekdayDetailSheet `navigation` als ungenutzter EnvironmentObject
- `@EnvironmentObject navigation: AppNavigationStore` deklariert, aber nie verwendet.
- GymPlanTab reichte navigation NICHT an die Sheet weiter — latenter Crash-Pfad bei künftiger Nutzung.
- Fix: Deklaration entfernt. Sheet kommuniziert ausschließlich über `pendingPostDismiss`.

## Loop 17 — GymStatsTab Quick-Audit
- TimeRange-Filter und filteredHistory-Logik sauber. Empty-State korrekt. Keine Änderung.

## Loop 18 — WorkoutTrackerEntryView Dead-Code: `browsingExercise`
- `@State` + zugehöriges `sheet(item:)` für `browsingExercise` — niemals zugewiesen.
- Fix: State + orphaned Sheet entfernt. Library bleibt über `showsExerciseLibrary` erreichbar.

## Loop 19 — GymPlanWizardSheet
- 9-Step-Wizard, sauber. Keine Änderung.

## Loop 20 — RunTracker Confirmation-Dialog-Labels irreführend
- „Abbrechen" war `.destructive` (= Setup verwerfen), „Weiter" war `.cancel`.
- Im Dialog-Kontext bedeutet „Abbrechen" für die meisten User „Dialog schließen".
- Fix: Labels umbenannt → „Setup verwerfen" / „Zurück". Titel auf „verwerfen?" geändert.

## Loop 21 — Tab-Label-Inkonsistenz „DATEN" vs „STATS"
- Cardio-Hub nutzte noch „DATEN" als Tab-Label, Gym längst auf „STATS" vereinheitlicht.
- Fix: `RunHubTab.stats.label` → „STATS", konsistent mit Day-One-Tour, Coach-Actions, Pulse-Chevrons.

## Loop 22 — RunRoutesView Audit
- Sauber. Heatmap Empty-State zentriert auf München als Fallback — vertretbar.

## Loop 23 — RunWorkoutsView Audit
- Sauber. Keine Änderung.

## Loop 24 — RunSegmentsView Audit
- „Neu"-Button-Sichtbarkeit korrekt logisch verzweigt (Empty-Card hat eigenen CTA). OK.

## Loop 25 — RunGoalPlan Setup `21.0975`-Default
- Halbmarathon-Distanz als Default ist Konvention. Edit-Mode prefillt via `onAppear`. OK.

## Loop 26 — NutritionTrackerView Tab-Switch
- ZStack-Architektur dokumentiert (verhindert State-Loss). OK.

## Loop 27 — Date-Navigation `userPickedDate`-Logik
- Korrekt: Forward zu „heute" cleart `userPickedDate`, Backward setzt es. Scene-Phase respektiert es. OK.

## Loop 28 — RecipesView Filter
- Bindings sauber, Filter-Sheet konsistent. OK.

## Loop 29 — BarcodeScannerView
- DispatchQueue.main.async für Callback ist Standard-Pattern. OK.

## Loop 30 — FoodPhotoRecognition `pickerItem` nicht zurückgesetzt
- Nach Foto-Verarbeitung blieb `pickerItem` gesetzt → derselbe Pick triggert kein zweites `onChange`.
- Fix: `pickerItem = nil` nach Verarbeitung in `MainActor.run`, guard auf nicht-nil eingangs.

## Loop 31 — CaptureSheet quick check
- States konsistent, `hasSelectedMealPhoto` via onChange-Sync. OK.

## Loop 32 — ProfileView avatar picker
- `avatarPickerItem = nil` wird in `loadAvatar` korrekt reset (Z. 1013/1018). OK.

## Loop 33 — ProfileView Diagnostics Share Sheet
- `DiagnosticsShareItem` als Identifiable-Wrapper sauber. OK.

## Loop 34 — ProgressView Hero-Variants
- Komplexes Multi-Hero-System, ProgressHero-Enum sauber dokumentiert. OK.

## Loop 35 — OnboardingView Save-Flow
- Persistenz-Race-Fix (`store.saveAll { flag = true }`) korrekt. OK.

## Loop 36 — CompletionRitualView Auto-Dismiss
- `dismissRitual()` cleart Store-State → fullScreenCover dismisst automatisch. OK.
- `@Environment(\.dismiss)` ungenutzt, aber harmlos.

## Loop 37 — ContentView Global Sheets
- WeekPlan-FullScreenCover, Completion-Ritual, Capture-Sheet alle korrekt auf Root montiert. OK.

## Loop 38 — GainsStore Workout-Start Race-Conditions
- `startWorkout`/`startRun` mit Guards (`activeRun == nil`/`activeWorkout == nil`). OK.

## Loop 39 — HealthKitManager Singleton
- Etablierter Pattern. OK.

## Loop 40 — BLE Heart-Rate Manager
- Etablierter Pattern. OK.

## Loop 41 — DesignSystem Tokens
- Radius/Spacing/Border-Tokens sauber dokumentiert. OK.

## Loop 42 — GainsSheet Detents
- Helper konsistent. OK.

## Loop 43 — GainsErrorPresenter
- Severity-System + Banner-Layer sauber. OK.

## Loop 44 — Background/AppBackground
- Etabliert. OK.

## Loop 45 — GainsCharts
- Etabliert. OK.

## Loop 46 — ActiveWorkoutPersister
- Etabliert (Bug-Vermeidung im Pause-Timer dokumentiert). OK.

## Loop 47 — CustomPlanBuilderSheet
- States sauber. OK.

## Loop 48 — GymPlanWizardSheet Init-Pattern
- @State via `_property = State(initialValue:)` korrekt für Init-Settings. OK.

## Loop 49 — GymExerciseHistorySheet
- Reine Read-Only-Drill-Down, keine Side-Effects. OK.

## Loop 50 — Klammer-Sanity-Check
- Per `grep -o`-Count alle modifizierten Files balanced (Brace-Match = 100%).
- NutritionTrackerView hat 6 More Close-Parens — pre-existing, von String-Literalen / Kommentaren mit Klammern. Nicht Folge meiner Edits.

---

## Modifizierte Dateien

```
Gains/DesignSystem.swift.bak                  (gelöscht)
Gains/WeekPlanFullscreenView.swift            (Loop 2, 3, 4)
Gains/FoodPhotoRecognitionView.swift          (Loop 8, 30)
Gains/RecipesView.swift                       (Loop 9)
Gains/WorkoutHubView.swift                    (Loop 11, 21)
Gains/NutritionTrackerView.swift              (Loop 12)
Gains/GymTodayTab.swift                       (Loop 14)
Gains/GymView.swift                           (Loop 14)
Gains/WeekdayDetailSheet.swift                (Loop 16)
Gains/WorkoutTrackerEntryView.swift           (Loop 18)
Gains/RunTrackerView.swift                    (Loop 20)
```
