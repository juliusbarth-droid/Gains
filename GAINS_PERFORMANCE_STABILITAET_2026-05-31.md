# Gains — Performance & Stabilität (Audit + Fixes)

**Datum:** 2026-05-31
**Scope:** `Gains/Gains/Gains/` (aktive Codebase, ~63k Zeilen Swift). Stale-Kopien unter `Gains app/`, `Gains konz.` und `.claude/worktrees/` ausgeschlossen.
**Build-Status:** Änderungen nicht in Xcode gebaut — bitte einmal kompilieren.

## Gesamtbild

Die Basis ist erstaunlich sauber und schon mehrfach optimiert: kein `try!`, kein `fatalError`, keine `as!`-Casts; alle `!` sind harmlose `UUID(uuidString:)`-Literale. `saveAll` läuft debounced (0,8 s) auf einem Utility-Thread mit Main-Thread-Snapshot, Caches werden über `didSet` invalidiert, der `RunLocationTracker` räumt GPS/Timer im `deinit` sauber auf, HealthKit-Callbacks schreiben `@Published` auf dem Main-Thread. Die echten Schwachstellen waren wenige und punktuell.

## Umgesetzte Fixes

### Stabilität / Akku

1. **BLE-Scan lief nach Schließen des Sheets unbegrenzt weiter** *(P1, Akku-Drain)*
   `WearablePickerSheet.swift` — `.onDisappear` ergänzt: ein laufender Scan wird beim Schließen gestoppt; eine bestehende Verbindung bleibt erhalten.

2. **Kein Scan-Timeout** *(P2, zweite Sicherung)*
   `BLEHeartRateManager.swift` — Scans stoppen sich nach 30 s selbst (Generation-Token, von `stopScanning()` entwertet). Fängt auch den Fall ab, dass das Sheet offen bleibt.

### Performance

3. **Übungs-Picker rendert ~105 Zeilen eager + O(n²)-Filter** *(P1)*
   `WorkoutHubView.swift` — `VStack`→`LazyVStack`; `filteredExercises.last?.id` einmal vor dem `ForEach` gebunden statt pro Zeile neu zu filtern.
   `HomeView.swift` — Picker ebenfalls auf `LazyVStack`.

4. **Avatar-JPEG wurde bei jedem Body-Pass neu dekodiert** *(P2)*
   `GainsStore.swift` — `userAvatarImage` cached das dekodierte `UIImage`; Invalidierung über `userAvatarData.didSet`. (HomeView-Greeting rendert ≥ alle 60 s.)

5. **Wachstumskritische Listen eager gerendert** *(P2)*
   `RecipesView.swift` (Rezeptliste + Suchergebnis) und `CommunityView.swift` (Feed, Forum-Threads, Treffs) auf `LazyVStack` — Karten samt `AsyncImage` erst beim Scrollen.

6. **`mergedHistory` materialisierte die ganze Historie für nur 5 Zeilen** *(P2)*
   `ProgressView.swift` — optionales `limit` stoppt den linearen Merge nach den n neuesten Einträgen; Verlaufs-Block ruft mit `limit: 5`.

## Bewusst nicht angefasst

- **`daySnapshot` (NutritionTrackerView):** Ist bereits ein dokumentierter Single-Pass. Ein Store-Cache brächte vor allem Stale-Data-Risiko bei Einträge-Edits; der reale Kostenunterschied (Integer-Vergleiche) ist vernachlässigbar. ROI niedrig.

## Empfohlene größere Schritte (separat, mit Test/Build)

- **`saveAll` feld-scopen** *(P1, skaliert mit Historie):* Jeder Save re-enkodiert alle ~25 Collections — inkl. `runHistory`/`savedRoutes` mit GPS-Koordinaten — auch wenn nur ein Nutrition-Eintrag geändert wurde. Aufteilen in `saveNutrition()` / `saveRunData()` o. ä. spart CPU/Akku, je größer die Historie wird. Berührt ~64 Call-Sites → eigener, getesteter Durchgang.
- **Live-Run-State in eigenes `ObservableObject`:** `GainsStore` ist ein God-Object, das von ~33 Views beobachtet wird. Der ~1-Hz-`activeRun`-Publish während eines Laufs re-evaluiert alle deren Bodies pro Sekunde. SwiftUIs Diffing fängt das heute ab; falls auf dem Run-Screen je Jank auftritt, ist das Auslagern der Live-Run-Daten der strukturelle Fix.
