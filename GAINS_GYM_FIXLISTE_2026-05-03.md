# Gym-Hub UX/Friction Fixliste — 2026-05-03

Audit-Scope: `GymView` + 4 Sub-Tabs (HEUTE / PLÄNE / PLAN / DATEN) + `WeekdayDetailSheet`.
Achse: UX/Friction (kein Performance-/Visual-Sweep).
Keine Code-Änderungen — diese Liste dient als Vorlage für einen späteren Welle-4-Patch.

Legende: **P0** = funktional/kognitiv blockierend · **P1** = spürbare Friction · **P2** = Polish/Konsistenz/DRY.

---

## P0 — funktional & kognitiv blockierend

### G-P0-1 Tab-Naming-Verwirrung „PLÄNE" vs „PLAN"
- **Wo**: `GymView.swift:9-14`, GymTab-Enum.
- **Symptom**: `case workouts = "PLÄNE"` rendert die **Workout-Bibliothek**, `case plan = "PLAN"` die **Wochenplanung**. Plural/Singular sind im Tab-Picker auf 11pt-Eyebrow-Höhe nicht unterscheidbar. Beim Erstkontakt rät der User, erfahrene Nutzer tappen falsch.
- **Fix**: Umbenennen. Vorschlag: `workouts = "BIBLIOTHEK"` (oder „VORLAGEN"), `plan = "WOCHE"` (oder „PLANER"). Day-One-Tour-Eintrag und sekundäre Action-Buttons müssen nachgezogen werden (`GymTodayTab.swift:99-104`, `:265-269`).

### G-P0-2 Wartender `false→true`-Toggle in der Workout-Row blockiert Re-Present
- **Wo**: `GymWorkoutsTab.swift:466-467`.
  ```swift
  isShowingWorkoutTracker = false
  isShowingWorkoutTracker = true
  ```
- **Symptom**: Das Pattern ist exakt jenes, das `GymTodayTab.swift:333-336` (G1/G2-Fix) als wirkungslos dokumentiert hat — SwiftUI batcht synchrone Bindings im selben Tick → kein View-Diff → kein Re-Present. Wenn der Tracker bereits offen war, wird er also **nicht** mit dem neuen Plan neu geladen; tappt der User auf einen anderen Plan, sieht er die alte Session.
- **Fix**: Zeile 466 streichen. Außerdem die `if store.activeWorkout == nil`-Guard auf Zeile 463 explizit machen — heute drückt man auf einen Plan, ein anderer ist live, und es passiert silent **nichts**. Entweder Sheet öffnen mit Hinweis „Andere Session läuft" oder Button disablen mit Tooltip.

### G-P0-3 STATS-Label-Inkonsistenz „DATEN" vs „Stats" vs „Statistik"
- **Wo**: `GymView.swift:13` (`stats = "DATEN"`), `GymTodayTab.swift:103` (Day-One-Tour: „Stats"), `:273` (Action-Button: „Stats"), `:662-666` (Wochen-Pulse-Chevron: „Statistik").
- **Symptom**: Drei Bezeichnungen für denselben Ziel-Tab. Der User kann den CTA nicht mit dem Tab-Label assoziieren.
- **Fix**: Eine Schreibweise wählen (Empfehlung: „STATS" — kurz, identisch zu Memory-Hint vom 2026-05-01) und alle vier Stellen ausrichten.

---

## P1 — spürbare Friction

### G-P1-1 Hero-Metric „STREAK" am Ruhetag dupliziert „WOCHE"
- **Wo**: `GymTodayTab.swift:233-238`, `heroMetricsList` Rest-Branch.
- **Symptom**: Beide Werte zeigen `weeklySessionsCompleted` — derselbe Zähler in zwei Slots, einmal als Bruch, einmal als Solo. Der Nutzer liest „3/4 Sessions … Streak 3" und denkt „Streak == diese Woche?".
- **Fix**: Echte Streak-Quelle aus dem Store ziehen (z. B. „längste Folgewoche mit ≥ 1 Workout") oder Slot ersetzen durch „LETZTES PR" oder „PROTEIN HEUTE" (wenn der Rest-Tag bewusst kein Training ist, ist Recovery-Ernährung der relevantere Hint).

### G-P1-2 Day-One-Window 24h schneidet Übernacht-Onboarder ab
- **Wo**: `GymTodayTab.swift:31-39`, `isInGymDayOneWindow`.
- **Symptom**: User onboardet 22 Uhr, öffnet morgens 9 Uhr → Tour ist weg, obwohl noch kein Workout absolviert. Andere Welle-2-Module (Nutrition-Welcome) zeigen Day-One bis zur ersten Aktion.
- **Fix**: 24h-Fenster entfernen. Bedingung: `workoutHistory.isEmpty && lastCompletedWorkout == nil`. Onboarding-Marker reicht als Untergrenze.

### G-P1-3 lastWorkoutBanner-Tap landet generisch im STATS-Tab
- **Wo**: `GymTodayTab.swift:706-758`, `lastWorkoutBanner`.
- **Symptom**: Banner zeigt Titel, Sätze, Volumen, %. Tap führt nur in den STATS-Tab — der User muss das Workout dort erneut suchen, um Detail zu sehen.
- **Fix**: Tap öffnet den Verlaufseintrag direkt (z. B. `GymExerciseHistorySheet` oder dedicated `WorkoutSummarySheet`). STATS-Tab als Fallback nur, wenn keine Detail-View existiert.

### G-P1-4 4-Wochen-Vorschau default eingeklappt — ihr wertvollster Inhalt
- **Wo**: `GymPlanTab.swift:25` (`showsFourWeekPreview = false`).
- **Symptom**: Die Vorschau ist die einzige Stelle, an der man Trainings-Frequenz und Lauf-Verteilung über mehrere Wochen sieht. Memory-Hint vom 2026-04-28 nennt sie als „die eigentliche Steuerzentrale". Versteckt hinter „Anzeigen"-Toggle wird sie selten geklickt.
- **Fix**: Default expanded, **wenn** der Plan ≥ 1 Trainingstag und ≥ 1 zugewiesenes Workout hat. Bei leerem Plan eingeklappt lassen (sonst leere Punktraster-Wand).

### G-P1-5 Doppelte „WOCHEN-KM"-Tile bei Cardio-Plan
- **Wo**: `GymPlanTab.swift:559-563` (`evidenceSection`) und `:736-744` (`runningSummary`).
- **Symptom**: Bei `trainingFocus == .cardio` rendert evidenceSection eine `WOCHEN-KM`-Tile UND runningSummary darunter eine weitere mit identischem Wert + Label. Nutzer sieht zweimal „60 km · Wochenziel".
- **Fix**: evidenceSection im Cardio-Modus den ersten Slot tauschen (z. B. „LANGER LAUF" / „LONG RUN"), oder runningSummary verstecken wenn evidence den Cardio-Block bereits zeigt. Saubere Lösung: eine Section entfernen, die andere füllt beide Modi konsistent.

### G-P1-6 Workout-Zuweisungs-Picker skaliert nicht
- **Wo**: `GymPlanTab.swift:476-480`, `assignmentRow` Menu.
- **Symptom**: `ForEach(store.savedWorkoutPlans) { plan in Button(plan.title) { ... } }` flacht alle Pläne (custom + 18 starter-templates) zu einer ungetrennten Liste. Auf einem iPhone 12 mini scrollt der Native-Picker mit 25+ Items unbenutzbar.
- **Fix**: Sections im Menu (`Section("Eigene")` / `Section("Vorlagen")`), nur die `customWorkoutPlans` plus Top-3-Templates inline, Rest hinter „Mehr Vorlagen → Sheet".

### G-P1-7 Compact-Wochenpuls hat Trend-Text aber keinen visuellen Trend
- **Wo**: `GymTodayTab.swift:616-675`, `compactWeeklyPulse`.
- **Symptom**: Der Block ist „kompakt" gemacht (Memory-Hint), aber das Visual ist nur `GymWeekStrip` (7 Punkte für diese Woche) + Text-Trend. Eine 6-Wochen-Sparkline ist im Trend (`weeklyVolumeTrend`-Daten existieren bereits) — würde auf 18px Höhe sitzen und mehr Signal-pro-Pixel liefern als der Trend-String.
- **Fix**: 6-Wochen-Mini-Sparkline rechts vom Volumen-Wert, Text-Delta darunter oder als Tooltip. Daten bereits da; Renderer existiert in `GainsCharts`.

### G-P1-8 timeRange-Filter wirkt nicht auf STÄRKE-FORTSCHRITT
- **Wo**: `GymStatsTab.swift:391-451`, `strengthProgressSection` greift `store.exerciseStrengthProgress` (vor-aggregiert), nicht die zeitraum-gefilterte Historie.
- **Symptom**: User wählt „WOCHE" → erwartet, dass alle Sektionen sich neu fokussieren. Stärke-Fortschritt bleibt aber lifetime. Inkonsistent zu PRs/History/Summary, die filtern.
- **Fix**: Entweder den Filter auch durchreichen (Store-Helper `exerciseStrengthProgress(in:)`), oder den `timeRangeFilter` auf den Sektionen markieren („alle Zeit") wo er nicht greift, damit der Nutzer nicht überrascht wird.

### G-P1-9 GymView-Header ignoriert Lauf-Tag
- **Wo**: `GymView.swift:108-125`, `gymHeaderTitle`.
- **Symptom**: Wenn der heutige Tag ein `runTemplate` hat, fällt der Title trotzdem auf `workoutPlan?.title.uppercased()` zurück — der User sieht oben „PUSH" obwohl der Plan-Tag „TEMPO 8 KM" ist. Hero-Title in TodayTab handhabt es korrekt (`heroTitle:286-289`); der Top-Header nicht.
- **Fix**: In `gymHeaderTitle` zuerst auf `runTemplate` prüfen (analog `heroTitle`), bevor `workoutPlan` kommt.

---

## P2 — Polish, Konsistenz, DRY

### G-P2-1 `weeklyVolumeTrend` zweimal identisch implementiert
- **Wo**: `GymTodayTab.swift:677-687` und `GymStatsTab.swift:552-562`.
- **Fix**: In den Store als computed property hochziehen (analog `dayTotals`-Single-Pass, Memory 2026-05-03), beide Tabs lesen die Quelle.

### G-P2-2 `isMatchingToday` (id-basiert) vs. `lastPerformedDate` (title-basiert)
- **Wo**: `GymWorkoutsTab.swift:375` und `:364-368`.
- **Symptom**: Wenn ein Plan dupliziert oder neu angelegt wird (Titel gleich, neue UUID), divergieren die Badges — „HEUTE" verschwindet, „Zuletzt: gestern" bleibt korrekt (oder umgekehrt).
- **Fix**: Einen Match-Schlüssel wählen. Empfehlung: WorkoutHistory speichert `planID` zusätzlich zu `title`; beide Lookups dann via id.

### G-P2-3 `currentWorkoutPreview`-Fallback ohne Hint
- **Wo**: `GymTodayTab.swift:178-198`, `todayHeroCard`. `plan = day.workoutPlan ?? store.todayPlannedWorkout ?? store.currentWorkoutPreview`.
- **Symptom**: Wenn weder Tag-Plan noch heutiger Plan, zeigt der Hero stillschweigend irgendeinen `savedWorkoutPlans.first` — der User denkt „das ist mein Plan" obwohl es nur die erste Vorlage ist.
- **Fix**: Eyebrow auf „VORSCHLAG" setzen, wenn nur `currentWorkoutPreview` greift; alternativ Badge `tone: .flex`.

### G-P2-4 `plan.split` als Hero-Metrik bei Rest/Flex irreführend
- **Wo**: `GymTodayTab.swift:240-245`.
- **Symptom**: Rest-/Flex-Tag → 3. Spalte zeigt `plan.split` (Push/Pull/Legs …), obwohl heute nicht trainiert wird. Wirkt wie eine Empfehlung.
- **Fix**: Bei Rest 3. Slot „PROTEIN" oder „SCHLAF-EMPF.", bei Flex „NÄCHSTES" (nächster geplanter Trainingstag).

### G-P2-5 plannerLegend-Hinweis „Tippen für Optionen" redundant
- **Wo**: `GymPlanTab.swift:300-303`.
- **Symptom**: Karten sind sichtbar tap-affordant (Lime-Border auf today, Card-Surface, Icon im Kreis). Hint ist Lärm; auf 4-Inch-Devices bricht die Legende um.
- **Fix**: Hint streichen. Wenn nötig, einmalig als Day-One-Tooltip statt permanent.

### G-P2-6 STATS-EmptyState zu früh
- **Wo**: `GymStatsTab.swift:46-52`.
- **Symptom**: Sobald `workoutHistory.isEmpty && exerciseStrengthProgress.isEmpty`, wird **alles** ausgeblendet — auch `muscleDistributionSection`, das aus dem Wochenplan (nicht der Historie) lebt. Tag-1-User mit Plan, ohne Training, sieht eine leere Wand statt „so wird deine Woche aussehen".
- **Fix**: Empty-Card am oberen Rand zeigen, `muscleDistributionSection` und `volumeTrendSection` (mit Skeleton) trotzdem rendern.

### G-P2-7 Workout-Suche durchsucht Übungen nicht
- **Wo**: `GymWorkoutsTab.swift:328-336`, `apply(searchText:)`.
- **Symptom**: Match nur auf `title`, `split`, `focus`. „Bench Press" findet kein Workout, das zwar Bench enthält, aber im Titel „Push A" heißt.
- **Fix**: Übungs-Namen mit-durchsuchen (`plan.exercises.contains { $0.name.localizedCaseInsensitiveContains(query) }`). Treffer-Begründung optional als kleines Sub-Label („gefunden: Bench Press").

### G-P2-8 4-Wochen-Vorschau: Past-Days nur via opacity 0.55
- **Wo**: `GymPlanTab.swift:710`.
- **Symptom**: Vergangene, unvollständige Tage werden nur abgedimmt — auf hellen iPad-Backgrounds verschwimmt der Unterschied zu „heute, noch offen".
- **Fix**: Past-Days mit explizitem Diagonal-Stroke oder grau-out-mit-Strikethrough kennzeichnen, nicht nur Opacity.

### G-P2-9 Long-Press-Quickaction auf Wochenkarten fehlt
- **Wo**: `GymPlanTab.swift:194-199`, `weekdayCard`.
- **Symptom**: Memory-Hint vom 2026-05-02 (Welle 2) nennt „Long-Press Power-Shortcuts auf Action-Tiles" als bestehendes Pattern. Wochenkarten haben nur Tap → Sheet. Long-Press-Status-Switcher (Training/Flex/Rest) wäre für Power-User schneller als das volle Sheet.
- **Fix**: `.contextMenu` mit drei Status-Buttons direkt auf der Karte, parallel zum Sheet-Pfad.

### G-P2-10 Muskel-Verteilung im Cardio-Plan halb-leer
- **Wo**: `GymStatsTab.swift:212-247`, `muscleDistributionSection`.
- **Symptom**: Bei `trainingFocus == .cardio` zeigt die Section nur die wenigen Kraft-Anteile, das Cardio-Volumen fehlt komplett. Der Block heißt „MUSKEL-VERTEILUNG" — bei reinem Lauf-Plan also leer.
- **Fix**: Im Cardio-Modus die Section ausblenden ODER durch eine Lauf-Verteilung (Easy/Tempo/Long/Recovery in km) ersetzen.

### G-P2-11 `currentWeekRangeLabel` rechnet bei jedem Re-Render
- **Wo**: `GymPlanTab.swift:322-334`.
- **Symptom**: Computed property nutzt `Date()` direkt im Body — pro View-Update neuer Calendar-Roundtrip. Wenig dramatisch, aber inkonsistent zum Memory-Hint vom 2026-05-03 (DateFormatter-Caches).
- **Fix**: `@State private var weekRange: String = ""` + `onAppear` einmal befüllen; bei `scenePhase == .active`-Wechsel refreshen.

### G-P2-12 4-Tab-Hub für ein Sub-Modul ist viel
- **Wo**: `GymView.swift:9-14`.
- **Beobachtung** (kein konkreter Bug): HEUTE/PLÄNE/PLAN/DATEN. Nutrition läuft mit 2 Tabs, Lauf-Hub mit ähnlicher Tiefe ohne dedizierten PLAN-Tab. Wenn PLAN-Tab nur Wochen-Zuweisung + 4-Wochen-Vorschau bleibt, könnte er als Sheet vom HEUTE-Tab aus erreichbar sein → 3-Tab-Layout (HEUTE/BIBLIOTHEK/STATS).
- **Empfehlung**: In Welle-4-Sweep prüfen, ob PLAN als Tab gerechtfertigt ist oder zu „Plan bearbeiten"-CTA aus der Hero-Card und „Wochenkarten"-Section im HEUTE-Tab schrumpfen kann.

---

## Anhang — auf einen Blick

| ID | Bereich | Datei | Aufwand |
|---|---|---|---|
| G-P0-1 | Tab-Naming | GymView | S |
| G-P0-2 | Tracker-Race | GymWorkoutsTab | S |
| G-P0-3 | Stats-Label | 4 Stellen | S |
| G-P1-1 | Hero-Streak | GymTodayTab | S |
| G-P1-2 | Day-One 24h | GymTodayTab | S |
| G-P1-3 | LastBanner-Drilldown | GymTodayTab | M |
| G-P1-4 | 4W-Default | GymPlanTab | S |
| G-P1-5 | km-Duplikat | GymPlanTab | S |
| G-P1-6 | Picker-Skalierung | GymPlanTab | M |
| G-P1-7 | Sparkline | GymTodayTab | M |
| G-P1-8 | TimeRange-Reichweite | GymStatsTab | M |
| G-P1-9 | Header-Run | GymView | S |
| G-P2-1 | DRY volumeTrend | Store | S |
| G-P2-2 | id vs title | GymWorkoutsTab | M |
| G-P2-3 | Vorschlag-Hint | GymTodayTab | S |
| G-P2-4 | Rest-Slot | GymTodayTab | S |
| G-P2-5 | Legend-Hint | GymPlanTab | S |
| G-P2-6 | Empty zu früh | GymStatsTab | M |
| G-P2-7 | Übungs-Suche | GymWorkoutsTab | M |
| G-P2-8 | Past-Day-Stil | GymPlanTab | S |
| G-P2-9 | Long-Press | GymPlanTab | S |
| G-P2-10 | Cardio-Verteilung | GymStatsTab | M |
| G-P2-11 | Cache Range-Label | GymPlanTab | S |
| G-P2-12 | 4-Tab-Layout | GymView | L (strategisch) |

S ≈ ≤30 min · M ≈ 30–90 min · L ≈ ≥2h oder strategischer Re-Cut.

Empfohlene Welle-4-Reihenfolge: P0-2 → P0-1 → P0-3 → P1-1/-2/-4/-9 (alle S) → P2-1/-3/-4/-5 → Rest nach Verfügbarkeit.
