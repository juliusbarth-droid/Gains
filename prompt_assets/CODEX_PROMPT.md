# Codex Prompt — GAINS Home Screen

## Task
Baue den GAINS Home-Screen als React Native (Expo) Komponente mit NativeWind/Tailwind. Die Komponente ist der erste Screen, den Nutzer nach dem Login sehen. Sie zeigt Streak-Status, Wochen-Stats und das heute geplante Workout.

Referenzbild: `gains_home.png` (im Repo unter `/design/gains_home.png`)

## Design System

### Farben (Tailwind-Theme)
```
bg-base:    #E8E6E0   (Screen-Hintergrund)
bg-card:    #F4F2EC   (Karten)
ink:        #1A1A1A   (Schwarz, alle Headlines und dunkle Flächen)
ink-soft:   #666666   (Sekundär-Text auf hellem BG)
ink-mute:   #999999   (Mikro-Labels, Wochentags-Kürzel)
border:     #c9c6be   (Hairlines, gestrichelte Pausetage)
lime:       #D4E85C   (Akzent, alle aktiven States)
moss:       #4A5220   (Text auf Lime-Flächen)
```

### Typografie
- Primär-Font: Inter (via expo-font geladen), Fallback System-Sans
- Zwei Gewichte: 400 regular, 500 medium — nichts dazwischen, nichts drüber
- Display-Zahlen (die riesige "17", Stat-Zahlen): `letter-spacing: -0.08em`, `font-stretch: condensed` (für Inter nicht verfügbar → alternativ `Archivo Narrow` oder `Oswald` über expo-font laden)
- Body-Text: 14–16px, normal letter-spacing
- Mikro-Labels (Section-Titles, UPPERCASE): 10–11px, `letter-spacing: 0.3em`, `font-weight: 500`, uppercase

### Slash-System (Brand-Signature)
Slashes "/" in `lime` Farbe trennen Info-Einheiten in allen Labels:
- Datum-Header: `DI / 19 MRZ / WK 12`
- Section-Labels: `STATS / 7 TAGE`, `HEUTE / GEPLANT`, `WOCHE / LETZTE 7 TAGE`
- Workout-Meta: `5 ÜBUNGEN / 45 MIN / BRUST`
- Streak-Status: `STREAK / ACTIVE / PUSHING` (auf dunkler Hero-Card)
- Inline in Zahlen: "4/5" hat Lime-Slash zwischen den Ziffern

Wichtig: Slash ist 1px separates `<Text>` mit Lime-Farbe, nicht Teil des umgebenden Labels. Das sorgt für klare Color-Separation.

## Komponenten-Struktur

Baue als eine einzige Funktions-Komponente `HomeScreen` mit folgenden Sub-Sektionen (top-down):

1. **StatusBar**: iOS-Standard, `StatusBar` aus `expo-status-bar` mit style="dark"

2. **TopNav** (Zeile mit Icon links, Avatar rechts):
   - Links: 36×36 schwarzes rounded-square mit G-Monogramm (Platzhalter: weißer Kreis mit horizontalem Balken, wird später gegen finales Logo getauscht)
   - Rechts: 32×32 schwarzer Kreis mit Lime-Initial "J"

3. **DateHeader**: Slash-separierte Info-Zeile (siehe oben), 10px, uppercase, letter-spacing 0.3em

4. **Greeting**: "Let's go, Julius." — 24px, weight 500, dunkler ink

5. **StreakHeroCard**: Schwarze Karte (bg-ink), rounded-2xl, 196px Höhe, padding 20px:
   - Oben: Status-Zeile "STREAK / ACTIVE / PUSHING" (lime/grau/grau mit lime Slashes)
   - Links unten: Riesige Zahl "17" — 134px, font-weight 500, letter-spacing -0.08em, condensed, Farbe `bg-card` (cream-weiß)
   - Rechts mittig: Stack mit "tage in folge" (weiß, 11px) → Hairline-Divider → "BIS REKORD" (label) → "+ 6" in Lime, 28px condensed
   - Unten: Progress-Bar, 3px hoch, full-width mit Text "17" links und "23" rechts. Track `#2E2E2E`, Fill `lime`, Breite = 148/200

6. **StatsSection**:
   - Section-Label "STATS / 7 TAGE" mit Slash
   - Drei Karten nebeneinander (flex row, gap 9px):
     - Karte 1 (cream BG): Label "WOCHE" / Zahl "4/5" mit lime Slash / Sub "Sessions"
     - Karte 2 (cream BG): Label "VOLUMEN" / Zahl "12.4" + kleine "T" / Sub "Kilogramm"
     - Karte 3 (lime BG): Label "PRs" (in moss) / Zahl "+ 2" / Sub "Neue Rekorde" (in moss)
   - Alle Karten: 96px Höhe, rounded-xl, padding 14px

7. **TodayWorkoutSection**:
   - Section-Label "HEUTE / GEPLANT"
   - Cream-Karte, 92px hoch, full-width, rounded-xl:
     - Links: Titel "PUSH DAY" (20px, condensed) + Meta-Zeile mit Slashes "5 ÜBUNGEN / 45 MIN / BRUST"
     - Rechts: Schwarzer Pill-Button (96×46), "START →" in Lime

8. **WeekStripSection**:
   - Section-Label "WOCHE / LETZTE 7 TAGE"
   - 7 Tage nebeneinander (flex row, gap 10px), jeder Tag:
     - Oben: Wochentags-Kürzel in ink-mute (MI/DO/FR/...)
     - Unten: 38×42 rounded-lg Box mit Datum
     - Trainiert: bg-ink, Datum in cream
     - Pausetag: transparent mit dashed border, Datum in grau
     - Heute: bg-lime mit 2px ink-border, Datum in ink, kleiner ink-Dot drunter

9. **BottomNav**:
   - Hairline-Divider oben
   - 4 Items horizontal: HOME (aktiv), LOG, STATS, DU
   - Aktives Item: schwarzer rounded-Pill (50×32) mit Lime-Text
   - Inaktive Items: nur grauer Text, kein Background
   - Labels uppercase, 9px, letter-spacing 0.15em

## Technische Anforderungen

- **Nur Mock-Daten hardcoden** — keine Supabase-Anbindung in dieser Komponente. Werte als JS-Konstanten oben im File: `const streakDays = 17; const record = 23; const weekSessions = 4; ...`
- **Responsiveness**: Screen nutzt `SafeAreaView`, alle horizontalen Paddings = 20px (außer Phone-Frame)
- **Keine Abhängigkeiten außer**: `nativewind`, `expo-font`, `expo-status-bar`, `react-native-safe-area-context`
- **TypeScript strict**, keine `any`
- **Dateistruktur**: `app/(tabs)/index.tsx` für den Screen selbst. Kleine wiederverwendbare Komponenten wie `StatCard`, `DayCell`, `SlashLabel` in `components/home/` auslagern.
- **Tailwind-Config**: erweitere `tailwind.config.js` um das Farbsystem oben und die Custom-Utilities `font-display` (für die condensed Zahlen)

## Qualitätskriterien

- Die Komponente muss auf einem iPhone 14 Simulator exakt wie im Referenzbild aussehen
- Keine Gradients, keine Shadows (außer iOS-System-Shadow auf Karten, maximal 1px subtle)
- Alle Touch-Flächen mindestens 44×44 (iOS-Guideline) — auch wenn die visuellen Elemente kleiner wirken, muss der `TouchableOpacity`-Hit-Slop das kompensieren
- Keine externen Bild-Assets außer dem G-Icon (wird später geliefert, erstmal Platzhalter)

## Erwartetes Output

Erstelle:
1. `app/(tabs)/index.tsx` — der Home-Screen
2. `components/home/StreakHeroCard.tsx`
3. `components/home/StatCard.tsx`
4. `components/home/WorkoutCard.tsx`
5. `components/home/WeekStrip.tsx`
6. `components/home/SlashLabel.tsx` — reusable Slash-separated-Label
7. `tailwind.config.js` — erweitert um das Farbsystem

Keine weiteren Screens, keine Navigation, kein Routing — nur diese eine Komponente muss standalone laufen.

## Nicht machen

- KEINE Platzhalter-Grafiken wie "User uploaded" Logos — nur einfache geometrische Platzhalter
- KEINE Dark-Mode-Variante (kommt später)
- KEINE Animationen in dieser Iteration
- KEINE Zugriffe auf AsyncStorage, Fetch, oder externe APIs
- KEINE Kommentare im Code außer bei nicht-offensichtlichen Design-Entscheidungen
