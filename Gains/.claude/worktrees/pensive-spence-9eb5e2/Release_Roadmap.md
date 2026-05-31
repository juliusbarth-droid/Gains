# Gains — Release-Roadmap

**Ziel:** TestFlight-Beta für Freunde, die sich nicht mehr wie ein Prototyp anfühlt — mit Pfad Richtung App-Store.
**Stand heute:** 2026‑04‑27, Version 1.0 / Build 1, iOS 17+, alle Permissions im Info.plist gesetzt, Code-Signing vorhanden, keine Tests, keine Telemetrie, Persistence über UserDefaults.

---

## 1. Was sich heute wie Prototyp anfühlt

Aus dem Code-Audit, gekoppelt an deine Pain Points:

**Mock-Content im Live-Build sichtbar.** Diese Stellen zeigen aktuell Fake-Daten, die ein Beta-Tester sofort als „Demo" erkennt:
- `GainsStore.swift:43–44` — `workoutHistory` und `runHistory` starten mit `mockHistory`. Frische Installs zeigen sofort fremde Workouts.
- `GainsStore.swift:57` — `communityPosts` = `CommunityViewModel.mock.posts` (komplett fiktive Profile).
- `GainsStore.swift:62–63` — `forumThreads` und `meetups` = `mockThreads` / `mockMeetups`.
- `GainsStore.swift:78` — `recordDays` aus `HomeViewModel.mock`.
- `GainsStore.swift:1501` — Coach-Text referenziert `CoachViewModel.mock.checkIns.count`.
- `ContentView.swift:45` — `CommunityView(viewModel: CommunityViewModel.mock)` direkt am Tab.

**Onboarding fehlt komplett.** Kein `Onboarding`/`Welcome`/`hasCompletedOnboarding`-Flag im ganzen Repo. Beim ersten Start landet der Nutzer direkt im Home-Tab, Permissions werden ad-hoc geöffnet wenn der Nutzer auf einen Button drückt — nicht erklärt, nicht im Kontext.

**Empty States teilweise da, aber unsystematisch.** Nutzungsstellen finden sich in HomeView, GymView, WorkoutHubView, ProgressView, RecipesView, NutritionTrackerView, CommunityView — kein gemeinsamer `EmptyStateView`-Baustein, jeder Screen löst es anders.

**Lesbarkeit / Formatierung.** `DesignSystem.swift` hat WCAG-Kommentare und Mindestgrößen für Body/Title, aber:
- `GainsFont.eyebrow` setzt nur `.semibold` ohne Tracking — wenn `SlashLabel` Uppercase mit 1.5–2pt Tracking benutzt, zerfällt es bei kleinen Größen trotzdem.
- Body ist 16pt — Apple HIG empfiehlt 17pt als Default. Auf Light-Mode mit `softInk #3A3A3A` auf `card #F7F4EE` ist der Kontrast knapp.
- `GainsColor.lime` als Tint plus Lime-CTAs auf Lime-Hintergründen führt zu mehrfacher Lime-Schichtung in Coach/Home-Hero.

**Kleine, aber sichtbare Polish-Lücken.**
- Sheet-Übergänge mit `DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)` (HomeView.swift:41–47, 57, 67) — funktioniert, fühlt sich aber wackelig an.
- Tab-Bar-Background `GainsColor.card.opacity(0.94)` mit `.toolbarBackground(.visible)` — bei Scroll-unter-Tabbar entsteht Banding.
- Userdefaults-Persistence: 30+ einzelne Keys (`PersistenceKey`-Enum) als JSON-Blobs. Schemamigration ist nur teilweise gelöst (`WorkoutPlannerSettings` fängt es ab, andere Modelle nicht). Ein neues Feld in `CompletedWorkoutSummary` würde alle Historien beim nächsten Start verwerfen.

---

## 2. TestFlight-Beta vs. „vollständiges Backend" — ehrliche Auflösung

Du hast TestFlight-Beta angekreuzt **und** vollständiges Backend (Auth + Community + Coach). Das passt zeitlich nicht zusammen: ein eigenes Backend ist mehrere Wochen Arbeit (Auth, Server, Datenmodell, Privacy, Push), eine TestFlight-Beta für Freunde lebt davon, dass du sie in 1–2 Wochen rausschicken kannst.

**Mein Vorschlag:** Zwei Phasen, klar getrennt.

**Phase A — Beta-Ready (1–2 Wochen).** Solo-App fühlt sich fertig an. Community wird *nicht* als Mock gezeigt, sondern als „Coming Soon"-Surface mit Waitlist-Eintrag — ehrlich, statt Fake-Posts. So riecht nichts mehr nach Prototyp, und du kannst echte Freunde einladen.

**Phase B — Backend & Community Live (3–6 Wochen, parallel oder danach).** Auth, Sync, echte Community. Während die Beta läuft.

So bleibt die Beta nicht auf das Backend warten, und das Backend muss nicht gegen Beta-Feedback arbeiten, das es noch gar nicht gibt.

---

## 3. Phase A — Beta-Ready (P0)

Das ist die eigentliche „weniger Prototyp"-Arbeit. In Reihenfolge:

### A1. Mock-Daten aus dem Erstkontakt entfernen
- `GainsStore.swift`: `workoutHistory` und `runHistory` starten als `[]`. `mockHistory` nur noch in DEBUG-Builds als „Demo-Daten laden"-Button im Profil.
- `recordDays`, `bodyFatChange`, `weightTrend` ohne Mock-Default — nil-tolerant rendern.
- Community-Tab in Phase A: alle Surfaces (`feed`, `mine`, `circles`, `forum`, `meetups`) durch eine einzige „Community kommt bald"-Karte ersetzen, mit Toggle „Benachrichtige mich". Beta-Tester verstehen das, eine Mock-Bar voller Fake-Profile macht den ganzen Eindruck kaputt.
- Coach-Texte (`GainsStore.swift:1501`) auf reale Daten umstellen oder neutral formulieren („Du hast heute X von Y Check-ins erledigt", aus echten `completedCoachCheckInIDs`).

### A2. Onboarding-Flow (3–4 Screens)
1. **Willkommen + Wertversprechen** (was Gains macht, in 1 Satz pro Tab).
2. **Profil** — Name, Geschlecht, Alter, Größe, Gewicht (füllt `nutritionProfile` direkt).
3. **Berechtigungen erklärt** — Health, Standort (für Lauf), Bluetooth (für HF-Sensor), Mitteilungen. Pro Permission: kurze Begründung *vor* dem System-Prompt, dann Trigger.
4. **Trainingsziel & Wochenfrequenz** (füllt `WorkoutPlannerSettings`).

State: `@AppStorage("gains_hasCompletedOnboarding")` Bool. `GainsApp` zeigt den Flow modal über `ContentView`, wenn false.

### A3. Einheitlicher `EmptyStateView`-Baustein
Eine SwiftUI-View mit Icon + Titel + Subtitle + optionalem CTA. Ersetzt die Ad-hoc-Lösungen in den 8 Files. Beispiel: leere Workout-Historie → „Noch kein Training geloggt — Tippe auf den Plus-Button, um zu starten" + Lime-Button.

### A4. Lesbarkeit & Typo-Pass
- Body-Default von 16 → 17pt (Apple HIG). `softInk` im Light-Mode auf `#2E2E2E` ziehen für deutlich besseren Kontrast.
- `GainsFont.eyebrow` mit explizitem `.tracking(1.2)` und Mindestgröße 13pt.
- Lime-Schichtung im Hero: Hero behält Dark-Surface (`ctaSurface`), Lime nur als Akzent (Border, kleine Chips, einzelner CTA pro Card — nicht mehrere).
- Pro Screen *einen* Pass: Spacing-Stack auf 4er-Raster (8/12/16/24/32), keine Zwischenwerte wie 22.

### A5. Persistence-Migration absichern
- `PersistenceVersion`-Key in UserDefaults einführen (Int).
- Beim App-Start: aktuelle Version lesen, auf Migrations-Bedarf prüfen, sonst alte Keys defensiv decodieren (`decodeIfPresent` überall, nicht nur in `WorkoutPlannerSettings`).
- Optional, aber stark empfohlen für Beta: Wechsel auf SwiftData *jetzt*, bevor echte Nutzer-Historien entstehen, die du nicht migrieren willst. UserDefaults-JSON skaliert nicht über die Beta hinaus.

### A6. Sheet-Choreografie aufräumen
Die `asyncAfter(0.2)`-Pattern in `HomeView` durch `onDismiss`-Callbacks ersetzen — sauber, deterministisch, kein Flackern.

### A7. Crash-Safety & Telemetrie (leichtgewichtig)
- `MetricKit` einbinden — Crash-Reports und Hänger landen lokal und du bekommst sie aus TestFlight.
- Optional: Sentry oder TelemetryDeck für Beta-Insights (anonym, opt-in im Onboarding).

### A8. App-Icon, Screenshots, App-Store-Connect-Eintrag (TestFlight)
- `AppIconSource.svg` ist da — final exportiert in alle Größen (Icon-Set).
- TestFlight braucht: App-Beschreibung, Beta-App-Beschreibung, Test-Information, Feedback-Email.
- Privacy-Manifest (`PrivacyInfo.xcprivacy`) — seit 2024 Pflicht für viele Frameworks, mindestens für UserDefaults-Tracking-Domain auflisten.

---

## 4. Phase B — Backend & Community Live (P1)

Wenn Phase A draußen ist und Feedback reinkommt:

### B1. Auth + User-Profil
- **Sign in with Apple** als einziger Auth-Provider für v1.0 — review-freundlich, kein Passwort-Stress.
- Backend-Optionen: **Supabase** (Postgres + Row-Level-Security + Auth + Realtime + Storage, PaaS, schnell) oder **CloudKit** (Apple-eigen, kostenlos bis Quota, aber Community schwierig). Empfehlung: Supabase, weil Community + Realtime out-of-the-box.

### B2. Datenmodell auf Server
Tabellen: `profiles`, `workouts`, `runs`, `nutrition_entries`, `community_posts`, `forum_threads`, `meetups`. Lokales SwiftData als Cache, Sync via Supabase Realtime + manueller Pull bei App-Start.

### B3. Community echt machen
- Feed: Posts der Personen, denen du folgst. Default-Sortierung nach Zeit.
- Forum: einfache Threads mit Reactions.
- Meetups: Standort-basiert, optional.
- Moderation: Report-Button + Block-User von Tag 1 (App-Review-relevant).

### B4. Coach-Backend
- `studyBasedCoachingEnabled`-Feature wird live: serverseitige Heuristik aus Health-Daten + Trainingsfrequenz → tägliche Empfehlung.
- v1.0 reicht ein Regelwerk; LLM später.

### B5. Push-Notifications
- APNs-Setup, Token-Registry, kategorisierte Notifications (Workout-Reminder, Community-Reply, Coach-Tipp).

### B6. Privacy Policy + Terms
- Pflicht für App Store. Hosted (z.B. GitHub Pages reicht). DSGVO-Hinweis, Datenexport, Kontolöschung im Profil-Tab.

---

## 5. Phase C — Polish bis App-Store-v1.0 (P2)

- Echte XCTest-Suite für `GainsStore`-Methoden (kein UI-Test-Theater, aber die Berechnungen für Streak, Volume, Macros sollen verifiziert sein).
- iPad-Support oder explizit `UIRequiresFullScreen` mit iPhone-only.
- Localization-Pass (heute: deutsch hardcoded; mindestens englisch für App Store).
- Accessibility: Dynamic Type bis XXL, VoiceOver-Labels für Icon-Buttons, kein Reliance auf Farbe alleine (Lime-only-States).
- Onboarding-Telemetrie auswerten — wo brechen Nutzer ab?

---

## 6. Konkreter Vorschlag für die nächsten 2 Wochen

| Woche | Fokus | Deliverable |
|---|---|---|
| 1 | A1, A2, A3 | Mock raus, Onboarding live, EmptyStateView überall |
| 2 | A4, A5, A6, A7, A8 | Typo-Pass, Persistence-Migration, Sheets aufgeräumt, MetricKit, TestFlight-Build hochgeladen |

Phase B kannst du parallel ab Woche 2 starten (Supabase aufsetzen, Schema definieren) — Code-Integration kommt erst nach Beta-Feedback.

---

## 7. Was ich konkret als nächstes empfehle

Sag mir, mit welchem Punkt du anfangen willst — ich würde **A1 (Mocks raus) + A3 (EmptyStateView)** als erstes machen. Beides zusammen ändert schon den Gesamteindruck der App spürbar, ohne dass etwas Neues gebaut werden muss, und es entkoppelt dich vom Phase-B-Backend-Pfad.
