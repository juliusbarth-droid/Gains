# Gains – Verdrahtungs-Audit & Fix-Liste

_Stand 2026-05-03 · Fokus: Coach-Brief ↔ alle Module · Daten-Flow ↔ Visuelle Konsistenz ↔ Shared Context_

---

## Kurzbefund

Die App ist **visuell** sehr konsistent (Token-Adoption ~96 %, Hero-Komponenten stimmen ab) und funktional vollständig.
Die schwache Stelle ist **strukturell**:

1. **Coach-Brief ist eine 500-Zeilen-Computed-Property in `HomeView`**, kein zentraler Service. Updates passieren nur, wenn Home gerendert wird.
2. **Trainings-Energie ist von Nutrition entkoppelt** (kein kcal-Flow von Workout/Run in die Tagesbilanz, Streak ignoriert Nutrition-Tage komplett).
3. **Alle Nicht-Home-Module sind Inseln**: kein Streak-Badge, kein Coach-Hint, kein Tages-Plan-Bezug. Cardio ist die extremste Insel.

Die Fix-Liste unten ist nach **Wirkung × Aufwand** sortiert. P0 = sofort, hoher Hebel; P1 = nächste Welle; P2 = wenn Zeit ist.

---

## P0 — Wirkungsstärkste Fixes

### P0-1 · `DailyCoachStore` als zentralen Service einziehen
**Problem:** Coach-Logik (~500 Zeilen) lebt inline in `HomeView.swift:1664–2200` als Computed Property. Updates erst beim nächsten Home-Render → Latenz nach Workout-Ende, kein Trigger-Hook.
**Fix:** `DailyCoachStore: ObservableObject` mit `@Published var currentBrief: CoachBrief`. Reagiert auf Store-Änderungen via Combine (`store.$lastCompletedWorkout.sink`, `store.$nutritionEntries.sink`). Dann ist Coach in jedem Modul per `@EnvironmentObject` erreichbar.
**Aufwand:** ~1 Tag Refactor. Risiko mittel (große Computed-Property zerlegen).
**Hebel:** Macht alle weiteren Verdrahtungen erst möglich.

### P0-2 · Trainings-Kalorien in Nutrition-Tagesbilanz fließen lassen
**Problem:** `finishWorkout()` (`GainsStore.swift:2739`) und `finishRun()` (`GainsStore.swift:2312`) berechnen Anstrengung als Volume bzw. Distanz, schreiben aber **keine kcal-Schätzung**, die Nutrition lesen könnte. User trackt 2000 kcal Essen, läuft 10 km — Nutrition zeigt trotzdem 2000 kcal.
**Fix:**
- Helper `estimatedCaloriesBurned(workout:)` und `estimatedCaloriesBurned(run:)` in `GainsStore` einführen (Volume × Faktor / Distanz × Gewicht × MET).
- Computed `workoutCaloriesBurnedToday: Int` (sum über heute).
- Im `NutritionTrackerView`-Header eine "Aktiv verbrannt: −650 kcal"-Pill, die Tages-Defizit korrekt darstellt.
**Aufwand:** ~3 h.
**Hebel:** Energie-Balance wird endlich richtig — Kern-Fitness-Logik.

### P0-3 · Streak-Logik um Nutrition-Tage erweitern
**Problem:** `registerCompletedDay()` wird nur von `finishWorkout()` (Z. 2775) und `finishRun()` (Z. 2354) gerufen — **nicht von Nutrition-Logs**. User der täglich Mahlzeiten loggt aber 2 Tage nicht trainiert, sieht Streak-Bruch. Coach-Brief sagt "Eine Mahlzeit reicht" (Z. 1981), aber Streak wird davon nicht erhöht → Widerspruch.
**Fix:** Zwei separate Streaks:
- `trainingStreak` (bisheriges Verhalten)
- `trackingStreak` (Workout ODER Run ODER ≥1 Nutrition-Eintrag)

Coach-Brief und Pulse-Strip referenzieren `trackingStreak`, Profil zeigt beide (Trainings-Streak prominent, Tracking-Streak als zweite Pill).
**Aufwand:** ~2 h.
**Hebel:** Beendet Coach-Brief-Widerspruch; belohnt konsistente Nutzer-Aktivität.

### P0-4 · `TodayContextPill` als wiederverwendbare Komponente
**Problem:** Es gibt heute 0 wiederverwendete Cross-Modul-Komponenten. Jedes Modul wäre eine Insel auch wenn man Daten reinreicht.
**Fix:** Neue Komponente in `DesignSystem.swift`:
```swift
struct TodayContextPill: View {
    let streak: Int
    let plannedToday: String?   // "Push Day · 5 Sets"
    let coachHint: String?      // "Heute Refeed-Tag"
    let onTap: () -> Void       // springt zu Home/Coach
}
```
Nutzung: oben in `RunTrackerView`, `NutritionTrackerView`, `GymPlanTab` als 36-pt-Pill. Hairline-Border, GainsRadius.standard, gleicher Tap-Stil wie QuickStart-Tile.
**Aufwand:** ~2 h Komponente + 1 h Einbau in 3 Modulen.
**Hebel:** Macht aus 3 Inseln verbundene Räume; fühlt sich wie *eine* App an.

---

## P1 — Nächste Welle

### P1-5 · Coach-Brief soll `nutritionEntries` direkt lesen (nicht nur Post-Workout)
**Problem:** Coach kennt Nutrition nur im Fenster "letzte 90 min nach Workout" (`HomeView.swift:1900`). Wenn User mittags 800 kcal Frühstück loggt aber nicht trainiert, erfährt der Coach nichts.
**Fix:** Im neuen `DailyCoachStore` (P0-1) einen Branch "Nutrition-Gap heute": wenn `nutritionProteinToday < 50 % des Ziels && Tageszeit > 14:00 && kein activeWorkout` → Brief-Variante "PROTEIN HEUTE NIEDRIG · 80 g fehlen". CTA → Nutrition-Quick-Add.
**Aufwand:** ~1 h nach P0-1.

### P1-6 · Workout/Run/Nutrition-Module per Mini-Coach-Hint verbinden
**Problem:** `RunTrackerView` und `NutritionTrackerView` haben keinerlei Coach-Präsenz.
**Fix:** Über `TodayContextPill` (P0-4) hinaus: an Empty-States und Tracker-Headern eine kompakte 1-Liner-Coach-Zeile zeigen, gespeist aus `DailyCoachStore.currentBrief.title`. Beispiel im Run-Tracker-Setup: "Coach: 'Easy-Run heute, du läufst 4. Tag in Folge.'"
**Aufwand:** ~2 h.

### P1-7 · `proteinProgress` und `dayTotals.protein` deduplizieren
**Problem:** Zwei parallele Protein-Tracking-Pfade (`GainsStore.swift:133` Score 0–260 vs. `NutritionTrackerView.swift:141` Tagessumme). Können auseinanderlaufen, UI zeigt 170 g geloggt aber 200 g Progress.
**Fix:** `proteinProgress` als Computed Property aus `dayTotals.protein` ableiten — kein eigenes `@Published` mehr. Workouts incrementen nicht direkt, sondern setzen `recoveryProteinTarget` der die Anzeige relativiert.
**Aufwand:** ~2 h, Test-Bedarf moderat.

### P1-8 · Run-Modul schreibt `proteinProgress` & Recovery-Hinweis
**Problem:** `applyRunProgress()` (Z. 3747) befüllt nur Gewicht/Bauchumfang, nicht Recovery/Protein. Läufer sehen Coach-Briefe nur für Krafttraining.
**Fix:** Nach `finishRun()` Recovery-Hint im DailyCoachStore: "Lauf-Recovery: 25–35 g Protein in den nächsten 60 min." Brief-Variante "POST-RUN · NACHFÜLLEN" analog zur Post-Workout-Variante.
**Aufwand:** ~1 h.

### P1-9 · Day-One/Comeback-Logik gegen Profil-Reset härten
**Problem:** `isInDayOneWindow` (`HomeView.swift:2698`) hängt an `onboardingCompletedAt`. Bei `clearAllData` ohne Reset dieses Felds bleibt User in "Day 1" hängen.
**Fix:** `clearAllData()` resettet `onboardingCompletedAt = nil`, `isInDayOneWindow` zusätzlich an `onboardingCompletedAt != nil` koppeln.
**Aufwand:** 30 min.

---

## P2 — Wenn Zeit ist

### P2-10 · Hardcoded Tageszeit-Schwellen entkoppeln
`hour >= 15` für "WORKOUT-FENSTER", `hour < 11` für "GUTEN MORGEN" sind über `HomeView.swift:1666, 1998, 2050` verstreut. In `DailyCoachStore` als Konstanten/Profil-Slots ziehen, später durch User-Präferenz oder typische Aktivitätszeit ersetzen.
**Aufwand:** 1 h.

### P2-11 · ActionTiles und Coach-Brief-CTA-Kollision auflösen
`HomeView.swift:2609–2678` ActionTiles und Z. 1660–2200 Brief-CTA können widersprüchliche Aktionen empfehlen. ActionTiles aus `DailyCoachStore.currentBrief.secondaryActions` ableiten, statt zweiter Quelle.
**Aufwand:** 2 h.

### P2-12 · `lastProgressEvent` persistieren oder löschen
`GainsStore.swift:144` wird ~15× geschrieben, aber nicht in `saveAll()` (Z. 327–383). Entweder weg oder in Persistenz aufnehmen — als Toast-Quelle nach App-Neustart sehr wertvoll ("Gestern: PR Bankdrücken").
**Aufwand:** 30 min.

### P2-13 · 2 verbleibende visuelle Inkonsistenzen
- `NutritionTrackerView.swift:79` Tab-Bar-Border ist `1.0` statt `GainsBorder.hairline (0.6)`.
- `NutritionTrackerView.swift:1632` MealType-Selected-Border hardcoded `1`, sollte `GainsBorder.accent (0.8)` sein.
- `GymSharedComponents.swift:281–282` Badge-Padding (10) ist kein GainsSpacing-Token.

**Aufwand:** 30 min total.

### P2-14 · Profil zeigt Wochen-Fortschritts-Card
`ProfileView` zeigt heute statische Pulse-Strip. Eine Card "Diese Woche: 3/5 Workouts, 2/3 Läufe, 6/7 Tracking-Tage" (gespeist aus `DailyCoachStore`) macht das Profil zur Woche-Übersicht ohne dass es funktional kollidiert.
**Aufwand:** 1.5 h.

---

## Reihenfolge-Empfehlung

```
1. P0-1 DailyCoachStore           [Foundation, alles andere baut darauf auf]
2. P0-3 Streak (Tracking + Training)
3. P0-2 Trainings-Kalorien → Nutrition
4. P0-4 TodayContextPill + Einbau in 3 Modulen
5. P1-5 → P1-6 → P1-8           [Coach in alle Module ausrollen]
6. P1-7 → P1-9                   [Daten-Konsistenz härten]
7. P2-10 … P2-14                 [Polish]
```

P0 (1 + 2 + 3 + 4) zusammen ≈ 1.5 Tage Arbeit, danach fühlt sich die App messbar verbundener an.

---

## Was wir NICHT anfassen sollten

- **Visuelle Tokens / Card-Komponenten**: 96 % konsistent, mehr Refactor zerstört mehr als er bringt. Nur die 3 Mini-Inkonsistenzen aus P2-13.
- **Bestehende `GainsStore`-Persistenz**: funktioniert, einzige Ausnahme `lastProgressEvent` (P2-12).
- **`CoachView.swift`**: ist ohnehin deprecated, nicht aufpolieren — durch P0-1 obsolet.
