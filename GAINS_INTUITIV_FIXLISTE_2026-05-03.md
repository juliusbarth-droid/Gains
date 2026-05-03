# Gains Intuitivitäts-Sweep — 2026-05-03

Audit über fünf Bereiche (Home/Onboarding, Gym/Workout, Kardio, Ernährung, Profil/Coach). 82 Friction-Punkte, davon 6× P0, 38× P1, 38× P2.

---

## P0 — Blocker / Verwirrend

### A. Sheet-Race auf HomeView
**HomeView.swift:99-120** — 7 separate `.sheet()`-Modifier. SwiftUI garantiert kein exklusives Verhalten; gleichzeitiges Setzen zweier Booleans (z. B. via `runCoachAction` + Tile-Tap in derselben Run-Loop) kann Sheets stapeln.
**Fix:** Single-State-Enum `HomeSheet { case none, workout, run, progress, planner, profile, capture }` + `.sheet(item:)`.

### B. Coach-Brief-Lock fehlt bei Workout-Start
**HomeView.swift:1768-1873 / ~2774** — Coach-Brief evaluiert sich neu auf jeden `coachClock`-Tick. Während User „Start Workout" tippt, kann Brief von „Workout-Window" → „Day-One" → „Workout läuft" flackern (activeWorkout wird verzögert publiziert).
**Fix:** `runCoachAction` setzt einen `pendingActionLock`-Status (z. B. `.startingWorkout`/`.startingRun`), der `currentCoachBrief` priorisiert kurzschließt, bis `store.activeWorkout`/`activeRunSession` populated ist.

### C. Workout-Start-Flow zu viele Stufen
**GymTodayTab.swift:331-370 (`handlePrimaryAction`)** — Verzweigung Rest/Plan/Flex erzeugt 3-4 Taps bis Tracker. Zudem keine 1-Tap-Wiederholung der letzten Session an Trainingstagen.
**Fix:** Single Entry „Trainieren" → kompaktes Bottom-Sheet mit drei Pillen (Heutiger Plan / Letzte wiederholen / Frei). Standard-CTA startet sofort.

### D. End-Run-Confirm fehlt
**RunTrackerView.swift:349 (`stopTracking`)** — Stop-Button beendet sofort ohne Confirm. In der Hosentasche/durchnässt → Datenverlust.
**Fix:** Press-and-Hold (0.6 s) ODER Confirmation-Sheet mit „Pausieren · Speichern · Verwerfen" (analog Workout).

### E. Ziel-Editor Quick-Path fehlt
**NutritionTrackerView.swift:500-545** — Ziel ändern nur via 9-Step-Wizard. User mit „1900 statt 2000 kcal"-Wunsch wird aus dem Profil neu berechnet.
**Fix:** Quick-Edit-Sheet (Slider Kcal + Protein + Anwenden) zusätzlich zum Wizard. Wizard nur bei Profil-Recalc.

### F. Onboarding-Modify ohne Reset unmöglich
**ProfileView.swift:680 (DEBUG only)** — Plan/Ziel ändern verlangt entweder Plan-Tab-Edit (nicht alles) ODER Reset (alles weg). Kein „Onboarding-Replay" außerhalb DEBUG.
**Fix:** Profil → „Daten neu erfassen" Button (Sheet öffnet OnboardingView komplett wiederholbar mit Vorbelegung).

---

## P1 — Reibung

### Home / Onboarding
1. **Coach-Primary-CTA-Affordance** (HomeView:412-450) — Outline statt Solid, schwacher Kontrast → solid Akzent + onAccent-Text + minimaler Border.
2. **Permissions-Step Skip unklar** (OnboardingView:351-387) — Hinweis-Caption „Tippe einzeln oder ‚Weiter' für später".
3. **Summary mit leeren Targets** (OnboardingView:724-740) — `nutritionTarget*` synchron in `finish()` berechnen vor Render.
4. **Plan-Builder-Dismiss-State** (OnboardingView:567-613) — `.sheet(item:)` + Reset im onDismiss.
5. **Spotlight ↔ Plan-Row-Hierarchie** (HomeView:555-630) — visuelle Differenzierung (Plan-Row klein, Spotlight Hero) oder Plan-Row weglassen.
6. **Coach-Action vs. Tab-Wechsel-Affordance** (HomeView:2774-2805) — Symbolik unterscheiden: Sheet `↗` vs. Tab-Switch `→` ODER nur Sheets aus Coach-Brief.
7. **Stepper Größe/Gewicht** (OnboardingView:236-239, 280-306) — TextField + Stepper-Kombination; Plausibilitätsbereich (130-220 cm, 30-200 kg).
8. **Day-One-Brief Flash** (HomeView:1768-1873) — siehe P0 B.

### Gym / Workout
9. **Set-Status visualisieren** (WorkoutTrackerView) — `✓ done / ◯ pending / ✗ skipped` als Symbol auf Set-Row + ContextMenu.
10. **End-Workout-Alert-Reorder** (WorkoutTrackerView:174-186) — destructive-Button untenrichts mit größerem Tap-Abstand zu „Speichern".
11. **Pause-Auto-Default aus Plan** (GymPlanTab:651) — Plan-Pausen (90 s/60 s) übernehmen den Timer-Default.
12. **Skip-Confirm-Wording** (WorkoutTrackerView:188-204) — „X ausstehende Sätze als nicht-absolviert markieren?" statt „als erledigt".
13. **Pause +/- vs. Skip-Trennung** (WorkoutTrackerView:351-384) — +/- visuell oben (neutral), Skip eigene Zeile unten (red, kleiner).
14. **Plan/Today/Workouts/Stats-Mental-Model** (GymView) — Eyebrow auf jeder Tab erklärt Funktion in einem Satz („HEUTE · Live-Fokus", „PLAN · Wochen-Struktur", „WORKOUTS · Library", „STATS · Verlauf").

### Kardio
15. **Pre-Run-Setup verkürzen** (WorkoutHubView:423-450) — primärer Quick-Start-CTA im Hub-Header („Start · Outdoor · 5 km Easy"), Long-Press → Anpassen.
16. **Live-Tracker-Lesbarkeit** (RunTrackerView:600-700) — Pace/Distanz auf 44 pt, HF + Zeit darüber, Lap-Button Mindest-56 pt.
17. **Templates Rad fehlen** (RunWorkoutsView:8-40 + GainsStore+RunFeatures:359-394) — 3 Bike-Builtins: Steady 30 min / Tabata 8×20-10 / Sweet Spot 3×8.
18. **Routes „Jetzt laufen"-CTA** (RunRoutesView:40-50) — Route-Detail bekommt primären CTA der RunTracker mit `presetRoute:` startet.
19. **Stats Lauf vs. Rad trennen** (RunDetailSheet:635-672) — `personalBests()` filtert auch nach `modality`.

### Ernährung
20. **Quick-Add-Discoverability** (NutritionTrackerView:296-299, 1438-1500) — sichtbare Pille „⚡ Schnell-Eintrag" neben Recents-Strip + Ersttag-Tooltip.
21. **Foto-Erkennung Edit-Affordance** (FoodPhotoRecognitionView:720-733, 791-821) — Edit-Pencil größer + farbig + Caption „Vor Loggen prüfen".
22. **Gramm-Edit-Menü** (NutritionTrackerView:950-985) — `⋯`-Menu bekommt „Gramm ändern…" → kleines Slider-Sheet (statt Löschen+Neu).
23. **Coach-Pulse Actionability** (NutritionTrackerView:1003-1155) — Pulse nur wenn actionable (nicht generic „TAG LÄUFT"), Inline-CTA-Pille statt Info.
24. **Barcode No-Result Manuell-Fallback** (BarcodeScannerView:214-256) — Notfound-Card bekommt Button „Manuell suchen…" → öffnet FoodSearchSheet.
25. **Ring-Mittelpunkt: gegessen/Ziel** (NutritionTrackerView:587-639, 669) — Center-Label „1200 / 2000" + verbleibend als Caption.
26. **Datum-Navigation +1 Tag** (NutritionTrackerView:319-373) — Chevron-rechts erlaubt bis +7 Tage (Meal-Prep-Vorschau).

### Profil / Coach
27. **HealthKit-Connect-Status** (ProfileView:412-484) — Tracker-Card differenziert „nicht verfügbar / nicht verbunden / verbunden".
28. **Notifications-Toggle-Wirkung** (ProfileView:495-501) — bei Toggle auf YES: Permission-Request + Settings-Deeplink, bei NO: Cancel pending notifications.
29. **Re-Engagement Welcome-Back** (HomeView:~2151) — Coach-Brief-Variante `.welcomeBack(daysAway:)` zwischen `comebackDay` und Default einfügen.
30. **Daten-Export** (ProfileView, neu) — Optionen-Card: „Daten als JSON exportieren" → ShareSheet.

---

## P2 — Nice-to-have / Polish

31. Pulse-Tile-Spacing 8→12 pt für Tap-Toleranz (HomeView:485)
32. Validation-Border auf Name-Feld (OnboardingView:202-217)
33. Summary-Wochen-Vorschau kompakt (OnboardingView:742-835)
34. accessibilityLabels auf Custom-Buttons (OnboardingView, HomeView)
35. Drag-to-Reorder im Workout-Tracker (WorkoutTrackerView)
36. Letzten-Set-Inline-Pille im Tracker („L: 5×80kg, RIR 2")
37. Volumen-MEV/MAV/MRV-Tooltip (GymStatsTab + GymSharedComponents:199-209)
38. Inline-Search im Workout-Builder (WorkoutTrackerEntryView:250-255)
39. Day-One-Gym-Guide persistenter Re-Open (GymTodayTab:31-39)
40. Superset-Gruppierung visuell (WorkoutTrackerView)
41. Indoor-Bike Stepper Exponential (RunTrackerView, Models:1820-1828) 0.1→0.5→1 km
42. Goal-Plan Rad-Distanzen (RunGoalPlanView/Models)
43. HF-Suggestion bei keinem Sensor (RunTrackerView:144,260)
44. Empty-State-Hero im Hub (RunRoutesView, RunSegmentsView)
45. Granulare Audio/Haptik-Toggles (GainsStore+RunFeatures:419)
46. Auto-Match-Toast Segments (GainsStore+RunFeatures:200-215)
47. Live-Tempo-Anpassung Bike (RunTrackerView:700-800)
48. Recents-Strip Limit + Filter (NutritionTrackerView:1157-1312)
49. Sparkline-Höhe + Target-Linie (NutritionTrackerView:1314-1435)
50. ⋯-Menu-Hint Long-Press (NutritionTrackerView:916-938)
51. Wasser-Tracker im Nutrition-Tab (FoodModels:467, HomeView:2633-2727)
52. Empty-State CTA Day 2 (NutritionTrackerView:384-453)
53. Profile-Hero-Tooltip „Antippen zum Bearbeiten" (ProfileView:160-188)
54. Settings-Toggle-Subtitle „Status: AKTIV/INAKTIV" (ProfileView:493-530)
55. Plan-Card-Profil reduzieren auf Summary+Tab-Link (ProfileView:301-376)
56. CoachView Dead Code rauswerfen / WIP-Marker
57. CommunityView Legacy-Body in eigene Datei oder löschen
58. Reset-UI in Production-Build (ProfileView:659-717)
59. Theme-Akzent-Picker (DesignSystem) — *deferred, Brand-Identity*
60. Hilfe/FAQ-Footer im Profil

---

## Empfohlene Umsetzungsreihenfolge

1. **P0 A-F** (sofort) — Sheet-Race, Coach-Lock, Workout-Start-Flow, End-Run-Confirm, Ziel-Quick-Edit, Onboarding-Modify
2. **P1 hoch-impact**: 9, 11, 13, 15-17, 20-23, 25, 27-29
3. **P1 Polish**: 1, 6, 10, 12, 18, 19, 24, 26, 30
4. **P2-Sweep**: in Themen-Bündeln (Tap-Targets, A11y, Empty-States)

