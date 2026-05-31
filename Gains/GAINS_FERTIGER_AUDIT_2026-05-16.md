# Gains — Audit „App fertiger wirken lassen" (2026-05-16)

50 Befunde aus parallel laufenden Audits über Home/Profil/Onboarding/Community/Progress (15), Gym (11), Kardio (12) und Ernährung (12). Konsolidiert, dedupliziert und nach Impact priorisiert.

**Kern-Diagnose:** Die App ist visuell hochpoliert (Glows, Tokens, Animationen), aber an den **Übergängen** und **Bestätigungs-Momenten** fehlt Tactile Response. Save-Aktionen, Sheet-Wechsel und Empty-States laufen oft still — das lässt jeden einzelnen Tab „90 %" statt „99 %" wirken. Vier wiederkehrende Patterns dominieren das Bild:

1. **Sheet-Race-Pattern** in Home, Gym, WeekPlan, Nutrition — mehrere `.sheet(isPresented:)`-Modifier sequenziell.
2. **Haptik-Lücken** auf primären CTAs (Start, Save, Switch, Long-Press) — uneinheitlich pro Tab.
3. **Stille Saves** ohne Toast/Glow/Confirmation (Route, Segment, Nutrition-Log, Export, Plan-Save).
4. **Empty-States ohne CTA** — Text-only-Hint statt „Jetzt starten"-Button im selben Container.

---

## P0 — Schmerzhaft, schnell zu fixen (≤ 4 h gesamt) ✓ **ABGESCHLOSSEN 2026-05-16**

### P0-1 · CaptureSheet: Umlaut-Bug im Subtitle ✓
**`CaptureSheet.swift:54`** — `ueber` → `über`. **Erledigt.**

### P0-2 · München-Fallback in RunRoutesView ✓
**`RunRoutesView.swift:82-114, 132-139, 250-256`** — Empty-Heatmap rendert jetzt eine token-konforme Card statt einer München-Karte mit dunklem Overlay. Edge-Case-Fallbacks (NaN-Koordinaten) auf Greenwich/0,0 mit Welt-Span — keine fremde Stadt mehr. **Erledigt.**

### P0-3 · Route-Save ohne Toast/Haptik ✓
**`RunDetailSheet.swift:81-99`** — `GainsErrorPresenter.shared.presentSuccess(.routeSaved)` nach erfolgreichem Save. Success-Haptik (`UINotificationFeedbackGenerator.success`) + Lime-Top-Banner für 2,5 s. **Erledigt.**

### P0-4 · Segment-Save ohne Feedback ✓
**`RunSegmentsView.swift:679-692`** — `presentSuccess(.segmentSaved)` vor `dismiss()`. **Erledigt.**

### P0-5 · Nutrition Add-Food ohne Success-Feedback ✓
**`GainsStore.swift:165-175, 1551-1571, 1591-1595`** + **`NutritionTrackerView.swift:447-465, 1505-1554`** — Neu: `@Published var lastLoggedNutritionEntryID` im Store, gesetzt in `logRecipe` und `logNutritionEntry`. Die Row in `foodEntryRow` bekommt für 1,6 s einen Lime-Gradient + Border-Glow; `task(id:)` räumt die ID wieder auf. Plus `notificationOccurred(.success)` per `onChange(of:)`. **Erledigt.**

### P0-6 · Workout-Start ohne Übergangs-State ✓
**`HomeView.swift:219-241`** — Zentrale `onChange(of:)`-Hooks auf `isShowingWorkoutTracker` / `isShowingRunTracker` / `isShowingWorkoutChooser` / `isShowingWorkoutBuilder` feuern jeweils `UISelectionFeedbackGenerator().selectionChanged()` beim Öffnen. Deckt alle ~9 Aufrufstellen ab (Coach-Brief, Programm, Long-Press, Programm-Card etc.) ohne Touch-Site-Surgery. **Erledigt.**

### P0-7 · CommunityView nur Coming-Soon ohne Kontext ✓
**`CommunityView.swift:1448-1526, 1531-1554`** — Neue `releaseStrip`-Card oberhalb des Intros: „GEPLANTER LAUNCH · 08. August 2026" + dynamischer Wochen-Countdown (`weeksUntilLaunchLabel`, computed aus heute). Waitlist-Toggle bekommt Success-Toast (`presentSuccess`) beim Beitritt + Selection-Haptik beim Verlassen. Wirkt nicht mehr wie ein verlassener Stub — der User sieht ein konkretes Ziel. **Erledigt.**

---

## P1 — Hoher „Wirkt-unfertig"-Faktor (≤ 12 h gesamt)

### P1-8 · Sheet-Race-Hardening (übergreifend)
**Betroffen:** `HomeView.swift:177-207` (6 Sheets), `GymView.swift:90-119` (4 Sheets), `WeekPlanFullscreenView.swift:106-148` (4 Sheets), `WeekdayDetailSheet.swift` (mehrere), `NutritionTrackerView.swift:381-394`.

Pattern überall gleich: lineare `.sheet(isPresented:)`-Stacks, anfällig für Race-Conditions bei schnellem Tap-Cluster. → Konsistentes Migrieren auf `.sheet(item: $activeSheet)` mit `enum ActiveSheet: Identifiable, Hashable`. Pro View ca. 30-40 min. **Gesamt: 4 h.**

### P1-9 · Empty-State-CTAs konsistent machen
Aktuell überall reiner Text. Folgende Stellen brauchen jeweils einen „Jetzt …"-Button **im selben Container**:

- `CommunityView.swift:789-801` — Forum-Surface „Hier ist es noch ruhig" → CTA „Neuen Thread starten"
- `GymStatsTab.swift:49-56` — „Noch keine Trainingsdaten" → CTA „Erstes Workout starten"
- `GymWorkoutsTab.swift:821-837` — „Keine Treffer" → CTA „Neues Workout erstellen"
- `WeekdayDetailSheet.swift:565-577` — `emptyPlansHint` → CTA „Workout-Builder öffnen"
- `RunSegmentsView.swift:80-99` — disabled Button + opacity:0.4 → durch `EmptyStateView` mit erklärendem Text ersetzen
- `RecipesView.swift:637-645` — Empty-Filter zeigt aktive Filter-Pills nicht; → aktive Filter als Chip-Reihe **über** dem Empty-State rendern

**Gesamt: 3 h.**

### P1-10 · GPS-Locking-Spinner in RunTracker
**`RunTrackerView.swift:913-920`** — `modalityStatusRow` zeigt statischen Text „GPS WIRD VORBEREITET". Keine Animation. User denkt „hängt das?". → Pulsierender Kreis oder 3-Dot-Lade-Animation rechts neben dem Text. **Aufwand: 30 min.**

### P1-11 · Barcode-Lookup-Loading
**`BarcodeScannerView.swift:112-126, 574-580`** — `loading(String)`-State hat keinen sichtbaren Dim/Spinner, anders als Photo-Recognition (das hat `ScanningDotsView`). User könnte 2× scannen. → `ProgressView()` + Dim-Overlay im `loading`-State, analog zu Photo-View. Beim Detect: Camera-Frame kurz aufblitzen lassen. **Aufwand: 45 min.**

### P1-12 · Rest-Timer-Ende: visueller Toast zusätzlich zur Haptik
**`WorkoutTrackerView.swift:201-206`** — Pausen-Ende feuert `UINotificationFeedbackGenerator()` + Sound, aber kein visueller Hinweis. Wenn iPhone in der Tasche und Sound aus → User merkt's nicht. → Kurze `.transition(.opacity)` Lime-Toast-Card („Pause vorbei"), 1.5 s, dann fade. **Aufwand: 30 min.**

### P1-13 · Haptik auf primären CTAs (konsistent durchziehen)
Lücken in mehreren Bereichen:

- `WeekdayDetailSheet.swift:356-417` — Status-Switcher (Training/Flex/Ruhe) ändert sofort, ohne Haptik
- `GymTodayTab.swift:986` — `lastWorkoutBanner()` öffnet Stats-Sheet ohne Haptik
- `GymWorkoutsTab.swift:518-530` — Long-Press Quick-Menu öffnet ohne Haptik
- `RunWorkoutsView.swift:179-182` — „Workout starten" ohne Haptik
- `RecipesView.swift:873-886` — FeaturedRecipeCard Track-Button ohne Haptik
- `RecipesView.swift:1469-1508` — Stepper bei Min/Max ohne disabled-Haptik

Regel etablieren: jeder primäre Tap = `.selectionChanged()`; jede Erfolgs-Mutation = `.notificationOccurred(.success)`. **Gesamt: 1.5 h.**

### P1-14 · HomeView-Greeting bei leerem Namen
**`HomeView.swift` Greeting-Block** — `userName.isEmpty` → „Dein Name" als kalter Fallback. → Warmer Fallback („Hi! Magst du dich vorstellen?") mit Tap-Affordance, die Name-Editor öffnet (gibt's schon in ProfileView → wiederverwenden). **Aufwand: 30 min.**

### P1-15 · ProgressView Empty-Cards mit Fallback-Komponente
**`ProgressView.swift:1280, 1354, 1436`** — Wenn kein Workout/Lauf/Gewicht geloggt: nur graue Text-Zeile. Bricht visuell aus dem Card-Grid aus. → Wiederverwendbare `EmptyChartCard(icon:, hint:, cta:)`-Komponente mit Lime-CTA „Jetzt starten" → springt in entsprechenden Tab. **Aufwand: 1 h.**

---

## P2 — Polish/Detail (optional, ≤ 8 h gesamt)

### P2-16 · ProfileView Export silent fail
**`ProfileView.swift:691-736`** — JSON-Serialisierung-Fehler → leiser `return`. → `GainsErrorPresenter.present(.exportFailed)` Banner. **15 min.**

### P2-17 · Run-Step-Wechsel auch mit Haptik (nicht nur Audio)
**`RunTrackerView.swift:289-296`** — `audio.speak(...)` ist die einzige Step-Wechsel-Signalisierung. Bei `audioCuesEnabled = false` merkt User den Wechsel nicht. → Zusätzliches `.impactOccurred(.medium)` unabhängig vom Audio-Flag. **15 min.**

### P2-18 · Undo-Snackbar visueller Countdown
**`WorkoutTrackerView.swift:95-108, 182`** — 4 s Auto-Dismiss ohne sichtbaren Countdown. → 1 s vor Ende `.opacity`-Fade oder dünner Progress-Streifen. **20 min.**

### P2-19 · CustomPlanBuilder: Validierung leerer Plan
**`CustomPlanBuilderSheet.swift:35-109`** — Save-Button speichert auch komplett leeren Plan ohne Warnung. → `.disabled(drafts.allSatisfy { $0.kind == .rest })` + Toast-Hint bei Tap-Versuch. **20 min.**

### P2-20 · Recipe-Tag-Cards mit 0 Rezepten ausblenden
**`RecipesView.swift:214-232`** — Tag-Browser zeigt Cards auch wenn count = 0. → `if count > 0`-Wrapper, oder Placeholder-Zeile. **15 min.**

### P2-21 · Goal-Quick-Edit Undo-Pfad
**`NutritionTrackerView.swift:2823-2829`** — Slider-Änderung speichert sofort, kein Undo. → „Zurücksetzen"-Knopf im Sheet-Header + Haptik vor Apply. **30 min.**

### P2-22 · Onboarding Summary „Los geht's" Loading
**`OnboardingView.swift:1334-1382`** — `finish()` ohne Progress-Indikator. → Kurze `ProgressView()` + „App wird vorbereitet…" vor Dismiss (auch wenn synchron schnell, fühlt sich „echter" an). **20 min.**

### P2-23 · Onboarding Name-Validierung von Anfang an
**`OnboardingView.swift:1056`** — Leeres Feld neutral, erst nach Tippen Validierungs-Border. Inkonsistent zur späteren Strict-UI. → `nameValidationBorderColor`-Logik auch vor erstem Input anwenden. **10 min.**

### P2-24 · GymExerciseHistorySheet Fallback bei gelöschter History
**`GymExerciseHistorySheet.swift:33-39`** — EmptyStateView nur Standardtext. → Zusätzlicher Fallback-Hint („Geschichte ggf. mit Workout gelöscht — Datensicherung in Profil"). **15 min.**

### P2-25 · RunWorkoutsView: „—" Stapel in Detail-Sheet
**`RunWorkoutsView.swift:118-123, 238-242`** — Bei Custom-Workouts ohne vorberechnete Distanz: 3× „—" gestapelt. → Statt „—" → „Wird im Lauf gemessen". **15 min.**

### P2-26 · HomeView leere `EmptyView()`-Cases im Action-Grid
**`HomeView.swift:2129, 2304`** — Cases `.planner`, `.progress`, `.water` rendern `EmptyView()` im Context-Menu. → Tiles aus dem Grid entfernen ODER aktiven Hint zeigen. **30 min.**

### P2-27 · WorkoutTrackerEntry: Sheet-in-Sheet risikieren
**`WorkoutTrackerEntryView.swift:75-80`** — `ExerciseLibrary` als Sheet **in** einem Sheet. Auf iOS 16+ funktional, aber UX-anfällig. → Wenn möglich auf NavigationStack umstellen (mittel-aufwendig — eher Tracking-Aufgabe). **2 h.**

### P2-28 · Detail→Setup-Sheet-Wechsel im RunGoalPlan
**`RunGoalPlanView.swift:62-80`** — `pendingShowSetupAfterDetail`-Flagge ist ein bekannter State-Workaround. Fragil bei schnellem Wechsel. → Saubere Sheet-Sequenzierung via Enum (Teil von P1-8). **siehe P1-8.**

### P2-29 · Nutrition Day-One-Banner Kamera-Status
**`NutritionTrackerView.swift:542-660`** — Banner zeigt Foto-Pfad auch wenn `AVCaptureDevice.default(for: .video) == nil`. → Grayed-out + Tooltip. **20 min.**

### P2-30 · Wearable-Picker Context-Hint
**`WearablePickerSheet.swift:207-208`** — Bei leerem Scan: „Starte die Suche, um Geräte zu finden." → Erweitern um Kontext: „Sensor muss Bluetooth aktiv haben — Scan dauert ~10 s." + optional Autostart. **15 min.**

---

## Reihenfolge-Vorschlag

**Tag 1 (4 h):** P0-1 bis P0-7 → sofort sichtbarer „Beta-Wegfall"-Effekt.

**Tag 2-3 (8 h):** P1-8 (Sheet-Race-Sweep) + P1-9 (Empty-State-CTAs) + P1-13 (Haptik-Sweep) → strukturelle Verbesserung, Konsistenz über Tabs.

**Tag 4 (4 h):** P1-10/11/12/14/15 → Loading-States und Greeting-Polish.

**Tag 5 (optional, 6-8 h):** P2-Block, je nach verfügbarer Zeit. P2-27 (Sheet-in-Sheet) und P2-21 (Goal-Undo) sind die UX-relevantesten.

---

**Gesamt-Aufwand bis „99% fertig":** ~16-20 h Implementierungsarbeit, zzgl. Test/QA. Realistisch in 3-4 Arbeitstagen.

**Geschätzter Effekt:** Die App wechselt von „polierte Beta" zu „App-Store-Release-Niveau". Größter Hebel: P0 + P1-8 + P1-9 + P1-13 — das räumt die vier strukturellen Patterns auf, die in **jedem** Tab präsent sind.
