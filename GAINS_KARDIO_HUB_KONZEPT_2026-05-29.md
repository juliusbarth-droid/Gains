# Gains — Kardio-Hub Umbau (Letzte Läufe à la Strava)

**Datum:** 2026-05-29 · **Autor:** Claude · **Status:** Umgesetzt (Build in Xcode prüfen — hier kein Compiler)

---

## Ausgangslage (korrigiert)

Der Kardio-Tab ist `WorkoutHubView` (Tab `AppTab.run`). `PreRunSetupView` ist nur der **Tracker-Sheet**, der von hier startet — nicht der Hub. Der Hub hatte bereits Hero-Kachel (`GainsHeroCard`), Modus-Toggle im Header, PR-Strips, Streak-Badge **und einen Run-Feed mit `runActivityCard`** — aber: der Feed steckte hinter dem Sub-Tab **„FEED"** (von 5: Feed/Routen/Segmente/Pläne/Stats), und den Karten fehlte die **Mini-Map**.

Zu Strava fehlten also genau zwei Dinge: Läufe nicht direkt unter der Kachel, und kein Kartenbild. Daher **Umbau statt Neubau**.

---

## Was umgesetzt wurde

**Struktur (Variante A — FEED-Tab raus):**
Header → Hero-Kachel → Live-Banner (falls aktiv) → **`belowHeroContent`** (Heute geplant → PR-Strips → Letzte Läufe → Wochen-Trend → Vorschläge) → schlanker Picker (Routen/Segmente/Pläne/Stats) → Tab-Inhalt.

`RunHubTab.feed` entfernt, `selectedTab`-Default → `.routes`, `feedTab` + `runFeedSection` entfernt (Logik in `recentRunsSection` + `allRunsSheet` aufgegangen).

**Letzte Läufe (`recentRunsSection`)** — direkt unter der Kachel, modus-gefiltert (`recentSessionsForModality`: Lauf zeigt nur `.run`, Rad alle Cycling → löst den „Distanz nur getrennt"-Punkt), die neuesten 3 als `runActivityCard`. „Alle · N" öffnet `allRunsSheet` mit der kompletten Liste. Empty-State mit Quick-Start.

**Mini-Map auf der Karte (`runActivityMap`)** — Map + `MapPolyline` + Start/End-Punkte, Lauf = Lime, Rad = `accentCool`. Indoor/ohne GPS → Fallback-Panel mit Modus-Glyphe. Pattern 1:1 aus `RunRoutesView.routeCard`; `gainsCardStyle()` clippt die oberen Ecken automatisch. Region via `runRegion(_:)` (Greenwich-Fallback).

**Heute geplant (`todayPlannedRow`)** — liest `store.weeklyWorkoutSchedule` nach `isToday` + `sessionKind.isRun` + nicht abgeschlossen. Template aus `plan.runTemplate ?? RunTemplate.template(for:)`. „Starten" → `store.startRun(from:)` (Ziel vorbefüllt) → Tracker.

**Wochen-Trend (`weeklyTrendSection`)** — 8-Wochen-Sparkline, modus-gefiltert, laufende Woche hervorgehoben, Ø-Label. Erst ab 2 Wochen mit Daten sichtbar.

---

## Geänderte Dateien

| Datei | Änderung |
|---|---|
| `GainsStore.swift` | `WeeklyDistanceBucket`-Struct + `weeklyDistanceTrend(modality:weeks:)` (Single-Pass über `runHistory`, modus-gefiltert). |
| `WorkoutHubView.swift` | `import MapKit`/`CoreLocation`; `RunHubTab.feed` raus; Body via `belowHeroContent` gebündelt (10-Kinder-Limit); neue Sektionen `todayPlannedCardio/todayPlannedRow`, `recentSessionsForModality/recentRunsSection`, `weeklyTrendSection`, `allRunsSheet`, `runActivityMap/runRegion`; `runActivityCard` mit Map-Kopf; `feedTab`/`runFeedSection` entfernt; `showsAllRuns`/`pendingDetailRun`-State. |

Keine Model-Migration nötig.

---

## Bewusste Design-Entscheidungen

- **FEED-Tab raus** (statt behalten): Läufe oben + Feed-Tab wäre Doppelung. Routen/Segmente/Pläne/Stats bleiben als Picker.
- **Sheet-über-Sheet:** „Alle" → Detail läuft über `pendingDetailRun` im `onDismiss` (vermeidet den Tab-Sheet-Race, der im Mai schon mal Thema war).
- **3 Karten** im Hub-Vorschau, Rest in „Alle". `runActivityCard` mit Map + Splits + „Erneut laufen"-Footer ist hoch — 3 reicht above-the-fold.

---

## Nachträge (2026-05-29, gleiche Session)

- **Läufe umbenennen + löschen** — im `RunDetailSheet` über ein ⋯-Menü (Toolbar): „Umbenennen" (Alert + TextField) und „Löschen" (Confirm-Dialog → `dismiss`). `CompletedRunSummary.title` ist jetzt `var`; neue Store-Methoden `renameRun(_:to:)` / `deleteRun(_:)`. Titel aktualisiert live im offenen Sheet via `displayTitle`-State.
- **Statzeile der Lauf-Karte (Clean-Glass)** — das dunkle `surfaceDeep`+Gradient-Inset-Panel mit Doppel-Hairline ist raus (war der alte „Cockpit"-Look). Neu: Werte direkt auf der Glas-Karte, **Wert oben / Label drunter, links ausgerichtet** (Strava-Hierarchie), eine feine Top-Hairline, keine Spalten-Trenner. `runStatDivider` entfernt. Folgt der Design-Richtung vom 2026-05-29 (heller/luftiger Clean-Glass, wenig Chrome).

## Noch offen / verschoben

- **Rekorde-Strip** und **„Gegen dich selbst" (Routen-Vergleich)** — bewusst auf später (v2).
- **PR-Badge auf der Karte** (z. B. „PR PACE") aus dem Mockup noch nicht drin — leicht nachrüstbar via `run.averagePaceSeconds == store.bestRunPaceSeconds`.
- **Build-Check in Xcode** steht aus (hier kein iOS-Compiler). Geprüft: ViewBuilder-Kinder ≤ 10, keine `.feed`-Restreferenzen außerhalb von `CommunityView` (anderes Enum), Map-API identisch zu `RunRoutesView`.
