# Gains — Release Notes Beta 1 (Build 3)

**Datum:** 2026-05-14
**Version:** 1.0 (Build 3)
**Status:** Erste TestFlight-Welle

---

## Was in dieser Beta dabei ist

### Kerntraining
- **Workout-Tracker** mit Live-Pause-Timer, Auto-Scroll zur nächsten Übung, TimelineView-basierter Performance-Render, Undo-Snackbar nach versehentlichem Set-/Übung-Delete
- **Cardio-Tracker** für Lauf, Outdoor- und Indoor-Rad mit GPS-Routen, HF-Zonen, Tempo bzw. Pace, Speed-validierten Distanzwerten
- **Active-Workout-Recovery** — App-Kill mitten im Workout wird nach Cold-Start automatisch über einen Home-Banner angeboten
- **Quick-Resume** in der Wochenplan-Sheet — aktives Workout ist immer einen Tap entfernt

### Plan & Wochenstruktur
- **Editable Wochenkarten** im PLAN-Tab — Long-Press öffnet Aktions-Menü (Status, Workout, Tag-Tausch)
- **4-Wochen-Vorschau** Default-on, Tageszellen direkt tappbar
- **Manueller Plan-Builder** zusätzlich zum 9-Schritt-Wizard
- **Done-Status** automatisch aus Workout/Run-History abgeleitet, auch für Lauf-Tage

### Home (Coach-Brief-System)
- **Coach-Brief-Card** mit 12 Variants nach Priorität (PR-heute, Streak-at-risk, Workout-Window, Comeback, Rest-Day, Nutrition-Shortfall, …)
- **Pulse-Strip** mit Kontext-Tiles (Workout läuft / Run läuft / Post-Workout / Recovery / Abend / Default)
- **365-Tage-Aktivitäts-Grid** in Fortschritt (GitHub-Heatmap-Style)
- **Streak als emotionales Zentrum** — Breathing-Animation, Radial-Glow, At-Risk-Dot

### Ernährung
- **3-Tab-Layout** Tracker / Rezepte / KI-Fotoerkennung
- **KI-Fotoerkennung** mit 3-Stufen-Pipeline (Apple Foundation Models → Gemini → Apple Vision mit Saliency-Cropping)
- **Coach-Pulse** im Ernährungs-Tab mit 7 Variants
- **Day-Summary-Footer** mit Streak, Sparkline, Protein-Hit-Rate

### Connectivity
- **Tracker-Hub-Sheet** kombiniert BLE-HF-Sensoren + Apple Health/WHOOP/Garmin/Oura in einer Sheet
- **Apple Health** liest Schritte, Schlaf, HRV, Ruhepuls, VO2max, Aktivität
- **Suggestion-Cards** in Workout/Run blenden sich ein, wenn keine HF live ist

### Stabilität & Qualität (2026-05-14 Audit-Loop)
- **Sheet-Race-Hardening** — Sheet-zu-Sheet-Übergänge auf deterministisches `onDismiss`-Pattern umgestellt
- **Error-Banner-Manager** — globaler `GainsErrorPresenter` für HK-Permission-Denied, BLE-Disconnect etc.
- **Empty-States als Einladung** — alle Haupt-Empty-States bekommen klare nächste Handlung als CTA
- **Reorder-Mode** mit sichtbaren ↑/↓-Pfeilen statt verstecktem Long-Press
- **Timer-Lifecycle** — Coach-Ticker und Pulse-Timer laufen jetzt nur noch, wenn die View sichtbar ist

---

## Bekannte Einschränkungen

- **Community-Tab** ist vorerst ausgeblendet (Backend kommt in Phase 2)
- **CoachView** als eigene Surface ist nicht implementiert (Phase B)
- **Plan-Drag-zwischen-Tagen** noch nicht — Verschieben geht über Tag-Detail-Sheet
- **GainsStore-Modul-Split** als Refactor-Folge-PR
- **Inter-Font** nicht aktiv (iOS-System hat es nicht); App nutzt SF Pro mit Inter-approximierendem Tracking
- **Gradient-Reduktion** und **Floating Pill Tab-Bar** sind Post-Beta-Polish-Items

---

## Was bitte testen

1. **Onboarding** durchgehen (4 Schritte) — fühlt sich der Flow natürlich an?
2. **Workout starten → tracken → abschließen** — Pause-Timer, Auto-Scroll, Undo nach Set-Delete
3. **App-Kill während Workout** + Neustart — Recovery-Banner erscheint und Wiederherstellung funktioniert
4. **Lauf starten** — GPS-Pfad korrekt, Speed-Werte plausibel, ungewöhnliche GPS-Spikes werden verworfen
5. **KI-Fotoerkennung** — Mahlzeit fotografieren, Gramm-Werte plausibel?
6. **Coach-Brief auf Home** — wechselt der Brief plausibel je nach Tageszeit/Status?
7. **365-Tage-Grid** in Fortschritt — werden frühere Workouts/Läufe korrekt dargestellt?
8. **Sheet-Choreografie** — Plan-Tag öffnen → Workout starten — keine Sheet-stapelt-auf-Sheet-Probleme?

---

## Feedback-Kanal

TestFlight-In-App-Feedback (Screenshot + Beschreibung) ODER Mail an den Projekt-Owner.
Bug-Reports bitte mit:
- Build-Nummer (1.0/3)
- Reproduzier-Schritte
- iPhone-Modell + iOS-Version
- Screenshot/Screen-Recording wenn möglich
