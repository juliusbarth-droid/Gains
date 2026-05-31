---
title: Gains Design-Optimierung
author: claude
date: 2026-05-31
tag: design
---

# Gains — Design-Optimierung (2026-05-31)

Breiter Design-Audit über die ganze App gegen das eigene Design-System
(`DesignSystem.swift`). Befund vorweg: Die App ist nach ~50 Polish-Loops sehr
konsistent. Echter Drift ist selten — die meisten „Funde" eines naiven Scans
sind in Wahrheit bewusste, dokumentierte Entscheidungen. Darum unten klar
getrennt: **umgesetzt**, **bewusst nicht angefasst** (mit Beweis) und
**deine Entscheidung**.

---

## ✅ Umgesetzt (3 saubere Wins, alle low-risk)

**1. Makro-Farbsystem vervollständigt — Fett ist jetzt ein Token**
Das war der einzige echte systemische Drift. Protein und Kohlenhydrate liefen
schon über Tokens (`lime` / `accentCool`), Fett hing als rohes
`Color(hex: "FF8A4A")` an **12 Stellen** in 4 Dateien.

- Neuer Token `GainsColor.macroFat` (`DesignSystem.swift:84`), bewusst eigenständig
  vom `ember`-Coral — `ember` kodiert „über Budget / Warnung", Fett ist eine
  neutrale Makro-Farbe. Hätte ich Fett auf `ember` gemappt, wären Fett-Werte
  optisch mit Warn-Zuständen verschmolzen.
- Alle 12 Vorkommen migriert (NutritionTracker 8, FoodPhoto 2, Recipes 1,
  Barcode 1). **Kein visueller Unterschied** — identischer Hex, nur kein
  hartcodierter String mehr. Falls die Makro-Palette je angepasst wird, jetzt
  eine Stelle statt zwölf.

**2. Letzte rohe SwiftUI-Systemfarbe entfernt**
`OnboardingView.swift:626` — das „Benachrichtigung verweigert"-Icon nutzte
`.foregroundStyle(.orange)`. Es war die *einzige* rohe System-Farbe der App
(alles andere läuft über `GainsColor`). → `GainsColor.ember` (das adaptive
Warn-Coral, passt auch hell/dunkel).

**3. Aktiver Sort-Chip — Kontrast & Konsistenz**
`RecipesView.swift:365` — der ausgewählte Sortier-Chip nutzte `moss`-Text auf
`lime`-Fläche (schwacher Kontrast). Alle anderen „Text-auf-Lime"-Stellen
(`GainsSegmentedPicker`, sämtliche NEU-Badges) nutzen `onLime` (fast-schwarz).
→ auf `onLime` vereinheitlicht. Klarer lesbar, konsistent mit dem System.

---

## 🛑 Bewusst NICHT angefasst (verifizierte Fehlalarme)

Drei Sub-Audits haben diese als „P0-Bugs" gemeldet. Beim Nachprüfen war jeder
eine bewusste, dokumentierte Design-Entscheidung — Ändern wäre eine Regression:

- **`gainsHeroShadow()` „undefiniert"** → existiert (`DesignSystem.swift:2107`).
  Wäre es wirklich undefiniert, würde die App nicht bauen.
- **`.blendMode(.screen)` auf hellen Flächen „blowout"** → ist die *gewollte*
  Light-Mode-sichere Variante von `.plusLighter` (44 bewusste Stellen, inkl.
  des Design-Systems selbst; vgl. Kommentar `HomeView.swift:1901`). Korrektes
  Muster, kein Bug.
- **Solid-Lime-Fill bei ausgewählten Pills / Badges „verletzt Lime-nur-Akzent"**
  → ist das **kanonische** Selected-State-Muster: `GainsSegmentedPicker`
  (`DesignSystem.swift:2759`) füllt das aktive Segment voll mit Lime + `onLime`-
  Text. Die „Lime nur Akzent"-Regel gilt für große Flächen, Glows und CTAs —
  nicht für kleine Selected/Badge-Fills. NEU-Badges und Filter-Pills bleiben.

---

## 🤔 Deine Entscheidung (optional, rein strukturell)

Es gibt drei kategoriale Hex-Paletten, die *bewusst* außerhalb der 2–3
Brand-Tokens leben. Sie sind nicht „falsch" — nur nicht tokenisiert. Bündeln
wäre Aufräumen ohne jede visuelle Änderung. Meine Empfehlung: **lassen**, außer
du planst ein Theming/Figma-Refactor — dann lohnt das Enum.

- **Muskelgruppen-Farben** — `WorkoutHubView.swift:2480–2488` (9 Hex-Werte für
  Brust/Rücken/Beine/…). Kandidat für ein `MuscleGroupColor`-Enum.
- **Wearable-Brand-Farben** — `WearablePickerSheet.swift` (Garmin/Wahoo/Whoop).
  Das sind echte Marken-Farben, absichtlich spezifisch. Eher als
  `BrandColor`-Enum dokumentieren als „korrigieren".
- **Rezept-Tag/Ziel-Farben** — `RecipesView.swift` (Mealprep/Airfryer/Budget,
  ab-/zunehmen). Kleine kategoriale Palette, an 2 Stellen dupliziert → falls
  angefasst, in *ein* `RecipeTagColor`-Enum ziehen (DRY).

**Zur `.plusLighter`-Lage allgemein:** 110 View-Stellen. Die allermeisten sitzen
korrekt auf dunklen Onyx-/CTA-Flächen (additives Blending gehört da hin). Ein
pauschaler „purge" wäre riskant und würde fein abgestimmte Glows kaputtmachen.
Falls dir konkret eine helle Fläche auffällt, die ausgewaschen wirkt: nenn mir
den Screen, dann schau ich die *eine* Stelle gezielt an.

---

## Geänderte Dateien

```
DesignSystem.swift          + GainsColor.macroFat Token
NutritionTrackerView.swift  8× → macroFat
FoodPhotoRecognitionView.swift  2× → macroFat
RecipesView.swift           1× → macroFat, Sort-Chip moss → onLime
BarcodeScannerView.swift    1× → macroFat
OnboardingView.swift        .orange → ember
```

Braces in allen Dateien balanciert. Bauen wie immer bei dir in Xcode.
