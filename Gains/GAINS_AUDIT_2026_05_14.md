# Gains – Senior-Dev-Audit (2026-05-14)

> Audit aus der Perspektive eines Senior-iOS-Entwicklers nach Design-Loops &
> Performance-Sweep. Ziel: Bestandsaufnahme, was in der App noch ruckelt,
> wackelt oder Risiken birgt — und ein priorisierter 10-Schritt-Plan zur
> Härtung.

---

## Was läuft gut

- **Design-System** ist solide: Tokens (`GainsColor`, `GainsSpacing`,
  `GainsRadius`, `GainsFont`) sind durchgezogen, neue Glass-Layer (A17/A18)
  konsistent.
- **TimelineView**-Optimierung im WorkoutTracker statt 1-s-Timer.
- **Coach-Brief** als zentrales Hero ersetzt die alte Symmetrie-Architektur
  und reduziert Entscheidungs-Lärm auf der Home.
- **0 `try!`, `fatalError`, `as!`** im Code → Fehlerpfade nicht crash-anfällig.

## Was problematisch ist

### 1. Gott-Klassen
- `GainsStore.swift` 4 752 LOC
- `HomeView.swift` 3 659 LOC
- `NutritionTrackerView.swift` 3 653 LOC
- `Models.swift` 4 217 LOC

Reviewing, Refactoring und Onboarding neuer Devs werden teuer. Bei dieser
Größe drohen Merge-Konflikte und versteckte Abhängigkeiten.

### 2. Schwache Accessibility-Abdeckung
31 `accessibilityLabel`, 6 `accessibilityHint`-artige Markierungen — bei
hunderten interaktiven Elementen ist das ~3 %. VoiceOver-User finden sich
nicht zurecht; iOS-Submission-Reviewer können das anmerken.

### 3. Timer ohne Lifecycle-Schutz
`coachTicker` (HomeView) und `pulseTimer` (NutritionTracker) laufen alle 60 s
auch im Hintergrund / off-screen. Verbraucht Akku und feuert Body-Refreshes,
die niemand sieht.

### 4. Sheet-Choreografie über `DispatchQueue.main.asyncAfter`
9 explizite `asyncAfter`-Calls für Sheet→Sheet-Transitions (HomeView,
WeekdayDetailSheet, WorkoutTracker). Race-anfällig. Es gibt schon
`pendingAfterChooser`/`pendingAfterArrange` als sauberes `onDismiss`-Pattern,
aber nicht überall.

### 5. Reorder-Funktion versteckt
Die neue „Übungen während Training neu sortieren"-Funktion liegt im
Long-Press-ContextMenu. Niemand wird das von alleine entdecken.

### 6. Keine Undo-Mechanik
Sets/Übungen lassen sich destruktiv löschen, ohne dass es einen
Rückgängig-Pfad gibt. Ein versehentlicher Set-Delete während des Workouts
kostet alle Werte des Satzes.

### 7. Keine zentrale Error-Surface
HealthKit-Permission denied, BLE-Disconnect, Camera-Permission denied,
GPS-Lost — jede Komponente kocht ihr eigenes Süppchen aus Alerts/inline-
Hints. Kein App-weiter „something went wrong"-Banner.

### 8. Kein Active-Workout-Recovery nach Cold-Start
Bei App-Kill mitten im Workout bleibt der Stand zwar dank
`activeRestTimerEndsAt`-Persist im Store für die Pause erhalten, das
`activeWorkout` selbst wird laut Persistence-Layer aber pro Session gehalten
— ohne dass eine explizite Recovery beim Launch greift.

### 9. Plan-Editing nur über Tag-Detail-Sheet
Workouts auf andere Wochentage zu verschieben geht aktuell nur via Sheet pro
Tag. Drag-zwischen-Tagen oder Bulk-Edit fehlt — der Plan fühlt sich rigid an.

### 10. Doppelter `GainsMotion`-Konflikt im Code-Pfad
(Schon im Loop behoben — als Beispiel für „eilig hinzugefügte" Tokens, die
ohne Suche zu doppelten Definitionen führen.)

---

## 10-Schritt-Plan (Priorität ↓)

| # | Maßnahme | Status | Warum |
|---|----------|--------|-------|
| 1 | **Reorder-Mode** – sichtbarer Toggle + ↑/↓-Pfeile pro Karte | ✅ implementiert | Reorder war via Long-Press unentdeckbar |
| 2 | **Undo-Toast (`GainsUndoSnackbar`)** – Set/Exercise-Delete | ✅ implementiert | Mistap-Schutz für destruktive Aktionen |
| 3 | **Timer-Lifecycle** – `coachTicker`/`pulseTimer` → `.task` | ✅ implementiert | 60-s-Wake-Up nur noch wenn View sichtbar |
| 4 | **Active-Workout-Recovery** | ⏳ Folge-PR | Crash-Recovery erfordert Persistenz-Refactor |
| 5 | **Quick-Resume-CTA in WeekPlanFullscreen** | ✅ implementiert | Aktives Workout ist überall ein Tap entfernt |
| 6 | **A11y-Combined-Label auf Exercise-Karten** | ✅ implementiert | VoiceOver-User können Karte als Ganzes hören |
| 7 | **Error-Banner-Manager (`GainsErrorPresenter`)** | ⏳ Folge-PR | App-weiter Refactor nötig |
| 8 | **Sheet-Race-Hardening**: alle `asyncAfter` → `onDismiss` | ⏳ Folge-PR | 9 Call-Sites über mehrere Dateien |
| 9 | **Plan-Drag-Zwischen-Tagen** | ⏳ Folge-PR | Eigenes UX-Feature |
| 10 | **Modul-Split `GainsStore`** in Extensions | ⏳ Folge-PR | 4 752 LOC Long-Term-Refactor |

**Schritte 1, 2, 3, 5, 6 wurden umgesetzt** (5/10).
**Schritte 4, 7, 8, 9, 10** sind im Audit-Backlog für Folgearbeiten dokumentiert
— jede einzelne erfordert mehr Tiefe als eine Session-Bandbreite vernünftig
hergibt, ohne Qualitätsverlust.

---

## Nachzug: Audit-Backlog teilweise abgearbeitet (2026-05-14, später)

Nach dem initialen Audit habe ich die Schritte 4 + 7 zusätzlich umgesetzt:

| # | Maßnahme | Status |
|---|----------|--------|
| 4 | Active-Workout-Recovery (`ActiveWorkoutPersister`) | ✅ Persistenz + Recovery-Banner auf Home |
| 7 | ErrorBanner-Manager (`GainsErrorPresenter`) | ✅ Service + Banner-UI + HK/BLE-Wiring |

`ActiveWorkoutPersister` schreibt debounced (350 ms) in UserDefaults; beim
Cold-Start liest `GainsStore.init()` einen `recoverableWorkout` und Home
zeigt einen „Fortsetzen / Verwerfen"-Banner. `GainsErrorPresenter` mountet
auf `ContentView` als globaler Overlay-Layer und reagiert auf HK-Auth-Fail
+ BLE-Disconnect via vordefinierte `GainsErrorMessage`-Konstanten.

---

## Brand-Re-Alignment auf Master Design Prompt (2026-05-14)

Nach dem Audit hat der User einen umfassenden Master Design Prompt für
gains. eingespeist (Signal Green, lowercase Wordmark, Inter-Typo,
„Addiction Architecture"). 12 Brand-Loops, davon 6 umgesetzt:

| # | Brand-Loop | Status |
|---|------------|--------|
| 1 | Color-Tokens: true black + 5-Stufen-Surface-Palette + neuer Text-Stack | ✅ |
| 2 | lowercase `gains.` Wordmark-Component (Period in Signal Green) | ✅ |
| 3 | Hero-Display-Typo (megaHero 120pt / hero 96pt / subHero 72pt, tracking −0.04em, tabular) | ✅ |
| 4 | Streak als emotionales Zentrum auf Home (breathing 0.5 Hz, radial glow, at-risk-dot) | ✅ |
| 5 | Completion-Ritual nach Workout (3-Sek-Cover, +1-Counter, ein Quiet-Pride-Stat, Success-Haptik) | ✅ |
| 11 | Variable-Reward-Insight-Card (5 Heuristiken, 7-Tage-No-Repeat-Cache) | ✅ |
| 6 | Floating Pill Tab-Bar (glasmorph) | ⏳ Folge-PR |
| 7 | GitHub-Style 365-Tage-Streak-Grid | ⏳ Folge-PR |
| 8 | Empty-States als Invitation (Audit aller Aufrufstellen) | ⏳ Folge-PR |
| 9 | Label-Härtung (uppercase 11pt, +0.08em tracking, sweep) | ⏳ Folge-PR |
| 10 | Gradient-Sweep (alle Linears raus, nur Streak-Radial-Glow bleibt) | ⏳ Folge-PR |
| 12 | Final Review + Markdown-Update | ✅ |

Signal-Green-Wert (`#C7EA45`) bleibt laut User-Direktive unverändert — der
Master-Prompt schlägt `#B8E035` vor, der bestehende Wert wurde aber explizit
gehalten.

Inter ist auf iOS nicht system-verfügbar — die App nutzt weiterhin SF Pro,
mit Tracking/Tabular-Tunings, die den Inter-Look approximieren. Wer wirklich
Inter will: Font-Files bundlen + Info.plist + UIFont-Registration in einem
separaten PR.

---

## Beta-1-Sweep (2026-05-14, später)

Vor dem TestFlight-Upload Build 3 nochmal durch:

| # | Maßnahme | Status |
|---|----------|--------|
| 8 | Sheet-Race-Hardening (asyncAfter → onDismiss) | ✅ WeekdayDetailSheet via `pendingPostDismiss`-Enum, RunGoalPlanView Detail→Setup-Wechsel auf onDismiss, ProfileView Focus-Trigger auf `.task`-Sleep, WorkoutTracker Scroll-Trigger auf Task |
| 7 (Brand) | 365-Tage-Aktivitätsgrid in Fortschritt | ✅ GitHub-Heatmap-Style, 7 Zeilen × ~53 Spalten, Intensität nach Workouts+Läufen/Tag, Legende, Total-Days-Anzeige |
| 8 (Brand) | Empty-States als Invitation | ✅ WorkoutTrackerEntry (2x), GymWorkoutsTab (Search+Empty-State CTAs), GymPlanTab (Wizard-CTA), WorkoutHubView (Quick-Start) |
| 9 (Brand) | Label-Härtung Token-Sweep | ✅ Alle exakt-passenden `.tracking(1.2/1.6/1.8)` auf `GainsTracking.eyebrowTight/eyebrow/eyebrowWide` — 18 Files, ~95 Sites |

Deferred zu Post-Beta-Polish (Risiko/Reward für Beta nicht gerechtfertigt):

- **10 (Brand) Gradient-Sweep** — 130+ Stellen, davon viele Hero-Glows die visuell tragen
- **6 (Brand) Floating Pill Tab-Bar** — aktuelle UITabBarAppearance mit ultraThinMaterial liefert bereits guten Liquid-Look
- **9 (Audit) Plan-Drag-zwischen-Tagen** — eigenes UX-Feature, Tag-Tausch-Menu deckt 80 %
- **10 (Audit) GainsStore-Modul-Split** — Long-Term-Refactor, nicht Beta-Blocker
- **Audit-Item: 1.4/1.5/2.0/2.4-Tracking-Sites** — gezielt off-token gesetzt, normalisieren würde Typografie verschlechtern

## Final-Verifikation (2026-05-14)

- 0 `try!`, `as!`, `fatalError`, `TODO`, `FIXME` im Code
- Sheet-Race-asyncAfter nur noch in 2 legitimen Sites (debounced Save in GainsStore, UI-Feedback-Timer in RecipesView mit Token-Cancel)
- WeekdayDetailSheet-API in beiden Parents (GymPlanTab + WeekPlanFullscreenView) konsistent migriert
- Build-Nummer von 2 → 3 für TestFlight Beta 1
