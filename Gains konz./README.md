# gains. — design reference

Beispiel-Dateien für das visuelle System der gains. App.
Diese Dateien dienen Codex als Referenz, wie die App aussehen soll.

## Dateien

### `tokens.css`
Alle Design-Variablen, Typografie-Klassen und Basis-Komponenten.
In jeden Screen mit `<link rel="stylesheet" href="tokens.css">` einbinden.

### `design-system.html`
Style-Guide-Seite. Zeigt alle Farben, Typografie-Größen, Komponenten und die Wortmarke.
Dient als Referenz, wenn neue UI-Elemente gebaut werden.

### `home-screen.html`
Der Home-Screen als fertige Mobile-Referenz.
Zeigt: Header, Streak-Card, Stat-Grid, Today-Card, Tab-Bar.

### `workout-screen.html`
Der Workout-Screen als zweiter Reference-Point.
Zeigt: Navigation, Timer-Card, Exercise-Liste mit States (done, active, pending), Bottom-CTA.

## Usage mit Codex

Pack alle 4 Dateien in dein Repo (z.B. unter `/design-reference/`) und sag Codex:

> "Nutze die Dateien in `/design-reference/` als visuelle Referenz für alle UI-Arbeiten. `tokens.css` enthält alle Design-Variablen, die anderen HTML-Dateien zeigen die fertigen Screens. Halte dich an diese Tokens und Patterns."

## Kern-Regeln

- **Dark first.** Ink (#0A0A0A) ist die Grundfläche.
- **Eine Akzentfarbe.** Signal Green (#B8E035) ist der einzige Akzent.
- **Wortmarke immer lowercase.** `gains.` mit grünem Punkt.
- **Font ist Inter.** Nur Gewichte 400 und 600, Labels in 500.
- **Slashes und Punkte in Grün.** Als Marken-Signatur.
- **Labels in UPPERCASE mit Letter-Spacing.** Body-Text in sentence case.
