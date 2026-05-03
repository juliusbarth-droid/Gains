# Kardio-Hub — Fix-Liste (Audit 2026-05-03)

Audit-Scope: `WorkoutHubView.swift` (1100 LOC) + Datenfluss zu `GainsStore` (Stats/PRs/Pace-Zonen). Drei Achsen: **Datenkorrektheit (Lauf vs. Rad)**, **Informations-Hierarchie/Redundanz**, **Edge-Cases/UX-Glättung**.

Legende: **P0** = sachlich falsche Daten oder kaputter Klick-Pfad · **P1** = Hierarchie/Doppelung/Verwirrung · **P2** = Polish/Wording/Layout.

---

## P0 — Daten-Korrektheit

### P0-1 — Hero-Metriken & Stats mischen Lauf + Rad in einen Topf
**Symptom:** `weeklyRunDistanceKm`, `weeklyRunCount`, `averageRunPaceSeconds`, `weeklyRunsByDay`, `yearlyRunDistanceKm/Count/Elevation/Duration`, `paceZones`, `distancePRs` filtern alle ausschliesslich nach Datum, **nicht nach Modalität**. `runHistory` enthält seit dem 2026-05-03-Patch auch `bikeOutdoor`/`bikeIndoor`-Sessions.
**Auswirkung:**
- „Ø PACE" mischt 5:00/km Lauf mit 25 km/h Rad (≈ 2:24/km Pace-Äquivalent) → der Mittelwert ist sinnlos.
- „BESTZEITEN 5K/10K/HM/Marathon" wird durch Bike-Sessions verfälscht (eine 5-km-Radtour schlägt die schnellste 5K-Laufzeit).
- Pace-Zonen Easy/Moderat/Tempo/Hart sind run-only Konzepte — Bike-Sessions in „Hart" einzusortieren ist semantisch falsch.
- „WOCHE / DISTANZ" addiert Lauf-km + Rad-km, obwohl der Hub als Cardio-Hub auch Rad-km zeigen soll, sie sind aber im STATS-Tab unter „run" gebrandet.
**Fix:**
- Drei neue Computed-Vars: `recentRunOnlyHistory`, `recentBikeHistory`, oder allgemeiner `recentHistory(matching: CardioModality?)`.
- `paceZones`, `distancePRs` (Run-Strecken) explizit nur auf `modality == .run` filtern.
- Wochen-Chart und YTD-Tiles separat in `running...` (Pace) und `cycling...` (Speed/Distanz) aufteilen oder als Combined-Total mit Mode-Breakdown rendern.
**Datei:** `GainsStore.swift:599-805`, `WorkoutHubView.swift:233-238 + 790-947`.

### P0-2 — Quick-Start-Chips sind Ghost-Tap, sobald ein Run aktiv ist
**Symptom:** `cardioQuickStartChips` (Zeile 253-281) wird ausgeblendet, **wenn `store.activeRun == nil` falsch ist** — gut. **Aber:** `startQuickCardio(_:)` (Zeile 1076-1082) prüft `if store.activeRun == nil` und ignoriert den Modus, wenn schon ein Run läuft. Da der Chip-Strip ohnehin verborgen ist, ist die Verzweigung dead code, aber sie ist zusätzlich irreführend kommentiert („eine laufende Session wird hier nicht überschrieben").
**Auswirkung:** Geringe — kein Bug im Live-Betrieb, aber wenn der `activeRun == nil`-Guard im View je vergessen wird, würde der Chip zwar Tracker öffnen aber **stillschweigend die gewählte Modalität verwerfen**, ohne Hinweis.
**Fix:** Funktion sollte bei aktivem Run entweder (a) Toast/Hinweis zeigen oder (b) auf `setRunModality` fallen (wenn Modality zwischen Run und Bike Outdoor wechselbar bleibt), statt nur Tracker zu öffnen.
**Datei:** `WorkoutHubView.swift:1076-1082`.

### P0-3 — Doppel-Trigger `isShowingRunTracker = false; = true`
**Symptom:** Mehrfach im File (Zeilen 369-371, 499-500, 671-672, 1068-1069, 1080-1081). Der Pattern setzt eine `@State`-Bool zweimal in derselben Frame, um eine schon präsentierte Sheet zu schliessen und neu zu öffnen.
**Auswirkung:** SwiftUI verschluckt die zweite Animation, wenn die erste noch nicht abgeschlossen ist (Sheet-Race) — beim ersten Tap auf „Tracker & Karte öffnen" während eines anderen Sheets in Transit kann das Sheet wegspringen.
**Fix:** Ein einzelnes `isShowingRunTracker = true` reicht in 4 von 5 Stellen (Sheet ist nicht offen). In der einen Stelle (`startRunLike` mit Detail-Sheet noch offen) den Pattern via `pendingAfterSelectedRun`/`pendingAfterPresentedWorkout` führen — der Mechanismus existiert schon.
**Datei:** `WorkoutHubView.swift:369-371, 499-500, 671-672, 1068-1069, 1080-1081`.

---

## P1 — Hierarchie & Redundanz

### P1-1 — Drei Eyebrows mit ähnlicher Botschaft + doppeltes „Lauf starten"
**Symptom:** Hub-Header rendert via `screenHeader(eyebrow: "RUN / CARDIO", title: "Lauf starten", subtitle: "Routen, Segmente, …")`. Direkt darunter `runHeroCard` mit `eyebrow: ["LAUFEN", "RUN"]`, `title: store.runningHeadline`, `primaryCtaTitle: "Lauf starten"`.
**Auswirkung:** Gleiches Wort dreimal („RUN/CARDIO" → „LAUFEN/RUN" → „Lauf starten" Title + CTA). Der Header-Title konkurriert mit dem CTA-Title. Wenn der Hero `Live: 1.4 km · 5:38/km` zeigt, sagt der Header daneben weiter „Lauf starten" — widerspricht.
**Fix:**
- Hub-Header: Title aus dem Header **streichen**, nur Eyebrow + (optionaler) Subtitle behalten — der Hero ist die Bühne, nicht der Header.
- Eyebrow: einheitlich „CARDIO / TRAINING" o. ä., damit Lauf+Rad gemeint sind.
- Hero-Eyebrow: kontextspezifisch — `["LAUF", "LIVE"]` bei aktivem Run, `["RAD", "LIVE"]` bei Bike, `["CARDIO", "QUICK START"]` ohne aktive Session.
**Datei:** `WorkoutHubView.swift:136-142, 221-239`.

### P1-2 — Hero-CTA + Quick-Start-Chips sind redundant
**Symptom:** Hero-CTA „Lauf starten" startet via `startOrResumeRun()` immer mit Modalität `.run`. Direkt darunter drei Chips „Lauf / Rad / Rad Indoor", die dasselbe können — aber explizit mit Modus.
**Auswirkung:** Erst-Nutzer scrollt nicht weiter; tippt Hero, bekommt Lauf, kann nicht erkennen, dass Rad im Hero geht. Der Chip-Strip rettet das nur, wenn der Nutzer ihn entdeckt.
**Fix-Optionen:**
- (A) Hero-CTA generisch „Cardio starten" + Modus-Picker daneben (Segmented), Hero startet Quick-Run mit gewähltem Modus.
- (B) Hero behält Run-Default + Chip-Strip wird visuell aufgewertet (Eyebrow „MODUS WÄHLEN") und immer gerendert (auch bei aktivem Run als „WECHSELN").
- Empfehlung: (A) — eine Bühne, eine Aktion.
**Datei:** `WorkoutHubView.swift:221-281, 1064-1082`.

### P1-3 — „Bestzeiten" stehen zweimal in der View
**Symptom:** Quick-PR-Strip (Zeile 1003-1036) als horizontaler Chip-Strip oben + `distancePRsSection` als 2-Spalten-Grid im STATS-Tab (Zeile 952-994). Beide ziehen `store.distancePRs`.
**Auswirkung:** Der STATS-Tab zeigt für den User, der das Quick-PR-Strip schon gesehen hat, nichts neues.
**Fix:** STATS-Tab um eine **Detail-Karte pro PR** erweitern (mit Datum, Route, Kontext) statt dieselbe Tabelle. Quick-Strip oben behält Preview-Charakter.
**Datei:** `WorkoutHubView.swift:952-994 + 1003-1036`.

### P1-4 — „VORSCHLÄGE / ROUTEN" + Sub-Tab „ROUTEN"
**Symptom:** `runningTemplatesSection` heisst im UI „VORSCHLÄGE / ROUTEN" (Templates wie Easy 5K, Tempo 8K, …) und sitzt im FEED-Tab. Im Tab-Picker gibt es einen separaten „ROUTEN"-Tab, der gespeicherte GPS-Routen verwaltet.
**Auswirkung:** Wortgleich, semantisch verschieden — Verwirrung.
**Fix:** Eyebrow umbenennen: `["VORSCHLÄGE", "PLÄNE"]` oder `["EMPFEHLUNGEN", "WORKOUTS"]`.
**Datei:** `WorkoutHubView.swift:482-494`.

### P1-5 — Day-One-Banner-Copy ist veraltet
**Symptom:** Zeile 166: „Im Tracker kannst du auf Rad umschalten." Seit dem 2026-05-03-Patch sind Rad/Indoor-Modi direkt im Hub als Chips wählbar (vor dem Tracker).
**Fix:** Copy: „Tippe oben auf einen Modus — Lauf, Rad oder Heimtrainer — und Gains tracked Pace, Distanz und Splits automatisch."
**Datei:** `WorkoutHubView.swift:161-167`.

### P1-6 — `runningHeadline` ist Bike-blind
**Symptom:** `GainsStore.runningHeadline` (Zeile 1180-1192):
- Live-Variante: „Live: 1.4 km · 5:38/km" — bei Bike-Session zeigt es Pace statt km/h.
- Latest-Variante: „Letzter Lauf: …" — auch wenn der letzte Eintrag eine Radfahrt war.
- Empty: „Starte deinen ersten Lauf in Gains" — falsch im Cardio-Hub.
**Fix:** Modality-aware Strings:
- Live (Run): „Live: %.1f km · {pace} /km"
- Live (Bike): „Live: %.1f km · {speed} km/h"
- Latest (Run): „Letzter Lauf: …"
- Latest (Bike Out): „Letzte Tour: …"
- Latest (Bike Indoor): „Zuletzt am Heimtrainer: …"
- Empty: „Starte deine erste Cardio-Session"
**Datei:** `GainsStore.swift:1180-1192`.

### P1-7 — Templates sind 100 % run-only
**Symptom:** `RunTemplate.stravaInspiredTemplates` enthält fünf Lauf-Templates (Easy 5K, Tempo 8K, Long Run 12K, Recovery, VO₂max-Intervalle). Keine Rad-Vorlage.
**Auswirkung:** Wer im Hub als Bike-Nutzer landet, sieht im Feed-Tab nur Lauf-Vorschläge.
**Fix:**
- 3 Bike-Templates: Endurance-Tour 30 km / Sweet-Spot 60 min / Recovery Spin 20 min.
- Im Hub: Templates nach gewählter Default-Modalität gefiltert oder mit Modality-Badge gerendert.
**Datei:** `Models.swift:2137-2189`, `WorkoutHubView.swift:482-546`.

---

## P2 — Polish

### P2-1 — Chip-Strip overflow auf kleinen Devices
**Symptom:** Drei Chips à `.frame(maxWidth: .infinity)` mit Texten „Lauf"/„Rad"/„Rad Indoor". Auf iPhone SE mit langem System-Font kann „Rad Indoor" abgeschnitten werden.
**Fix:** `minimumScaleFactor(0.85)` + `lineLimit(1)` an den Text-View. Optional: Icon-only-Variante < 360 pt Breite via SizeClass.
**Datei:** `WorkoutHubView.swift:262-265`.

### P2-2 — Empty-State im Feed: nur „Lauf"-Sprache
**Symptom:** Zeile 568-571: „Noch keine Aktivitäten — Starte deinen ersten Lauf — Gains baut deinen Feed automatisch auf."
**Fix:** „Starte deine erste Cardio-Session — Lauf, Rad oder Indoor."
**Datei:** `WorkoutHubView.swift:565-572`.

### P2-3 — Streak-Badge zählt alle Run+Bike-Tage
**Symptom:** `runStreak` (GainsStore Zeile 735-751) zählt Tage mit ≥1 Eintrag in `runHistory` — also Streak ist ein Cardio-Streak, das Badge im Hero heisst aber implizit „Lauf-Streak".
**Fix-Option:** Klarstellen — Badge-Tooltip „Cardio-Streak" oder Modality-Badge dazu. Streak-Logik selbst ist OK (Cardio insgesamt sinnvoll), nur Wording.
**Datei:** `WorkoutHubView.swift:294-311`, `GainsStore.swift:735-751`.

### P2-4 — Tab-Bar mit 5 Pillen + minScale 0.85
**Symptom:** Auf iPhone Mini bei „SEGMENTE" + „WORKOUTS" + „STATS" rutscht der Text in 0.85× → unscharfe Wirkung gegen die saubere SF-Mono-Typo des Rests.
**Fix-Option (klein):** „SEGMENTE" → „SEGS" auf Devices < 380pt, oder ScrollView-Fallback. „PLÄNE" / „WORKOUTS" sind bereits gleich-bedeutend — zumindest Eyebrow `WORKOUTS` ist schon da.
**Datei:** `WorkoutHubView.swift:36-46, 397-403`.

### P2-5 — Wochen-Distanz-Chart hat hartcodierte Höhe ohne Skalen-Label
**Symptom:** Zeile 833 `.frame(height: 72)` — kein y-Achsen-Tick, nur Bar-Topwert. Bei langer Strecke (z. B. 30 km) ist 72pt arg klein.
**Fix-Option:** Höhe erhöhen auf 96pt + Y-Achsen-Tick „max %.1f km" in den Header der Card mit aufnehmen.
**Datei:** `WorkoutHubView.swift:803-846`.

### P2-6 — `FEED`-Tab versteckt zwei Sektionen ohne sichtbare Trennung
**Symptom:** „VORSCHLÄGE/ROUTEN" + „AKTIVITÄTEN/FEED" sitzen beide im FEED-Tab. Trennung nur durch 18pt Spacing.
**Fix-Option:** Hairline-Divider oder `SectionHeader` mit Underline; visuell Hierarchie betonen.
**Datei:** `WorkoutHubView.swift:462-468`.

### P2-7 — `runActivityCard` Footer „Erneut laufen" ignoriert Bike-Session
**Symptom:** Zeile 677 hardcoded „Erneut laufen" — auch bei Bike-Session.
**Fix:** Modality-aware: „Erneut laufen" / „Erneut fahren" / „Wieder am Heimtrainer".
**Datei:** `WorkoutHubView.swift:670-687`.

### P2-8 — `latestRunAchievement` & `runPersonalBests` sind Run-only-zentriert
**Symptom:** Beide Strings sprechen nur von Lauf, keine Bike-Pendants. Werden zwar nicht direkt im Hub gerendert (nur indirekt im CoachView/Profil), aber mit Bike-Sessions im History-Pool zeigen sie falsche Werte.
**Fix:** Filter nach `.run` ODER Bike-Pendants ergänzen.
**Datei:** `GainsStore.swift:660-716`.

---

## Implementierungs-Reihenfolge

1. **P0-1** zuerst — neue Filter im Store. Ohne diesen Fix führen alle Hero-Metriken in die Irre und P1-6/P2-8 brauchen die Filter ohnehin.
2. **P0-3 + P0-2** — Sheet-Race + Ghost-Tap (kleine, lokale Patches).
3. **P1-1 + P1-2 + P1-5 + P1-6** — Hero/Header/Day-One-Banner-Wording in einem Rutsch (Modality-aware-Pass).
4. **P1-3 + P1-4** — Eyebrow-Renaming + STATS-Tab-PR-Detail.
5. **P1-7** — Bike-Templates ergänzen.
6. **P2-1 / P2-2 / P2-7 / P2-8** — Polish + Bike-Wording. P2-3/P2-4/P2-5/P2-6 als optionale Folge.

Nicht in dieser Liste, aber direkt danach sinnvoll: STATS-Tab als zwei Sub-Sub-Tabs (Lauf / Rad) oder als Modality-Picker oben in der Stats-Card — sonst bleibt der Daten-Bereich auch nach P0-1 visuell run-zentriert.
