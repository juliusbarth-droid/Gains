import Foundation

// MARK: - Exercise Catalog
//
// Vollständiger Übungskatalog für Gains. Jede Übung enthält:
//  - Grunddaten: Name, Equipment, Default-Sätze/Reps/Gewicht
//  - Kategorie + Schwierigkeit (für Filter & Sortierung)
//  - Sekundärmuskeln (für das Detail-Sheet)
//  - Anleitung Schritt-für-Schritt
//  - Tipps für korrekte Ausführung
//  - Häufige Fehler
//  - Optional: Video-/GIF-URL (kann leer bleiben — UI fängt das ab)
//
// Erweiterung: Einfach weitere `ExerciseLibraryItem(...)` in die jeweilige
// Kategorie unten ergänzen.

extension ExerciseLibraryItem {

  /// Vollständiger Katalog — alphabetisch sortiert pro Kategorie,
  /// im UI weiter durchsuchbar.
  static let fullCatalog: [ExerciseLibraryItem] = {
    let all = chestExercises
      + backExercises
      + shoulderExercises
      + bicepsExercises
      + tricepsExercises
      + legExercises
      + gluteExercises
      + coreExercises
      + fullBodyExercises
      + cardioExercises
      + mobilityExercises
    return all.sorted {
      if $0.category.sortOrder != $1.category.sortOrder {
        return $0.category.sortOrder < $1.category.sortOrder
      }
      return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }()

  static func library(for category: ExerciseCategory) -> [ExerciseLibraryItem] {
    fullCatalog.filter { $0.category == category }
  }

  // MARK: Brust

  private static let chestExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Bankdrücken", primaryMuscle: "Brust", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 8, suggestedWeight: 60,
      category: .chest, secondaryMuscles: ["Vordere Schulter", "Trizeps"],
      instructions: [
        "Lege dich flach auf die Bank, Schulterblätter zusammen, leichtes Hohlkreuz.",
        "Greife die Stange schulterbreit, Daumen umschließen.",
        "Senke die Stange kontrolliert zur Brustmitte ab.",
        "Drücke explosiv nach oben, ohne die Ellbogen ganz durchzustrecken."
      ],
      tips: [
        "Schulterblätter aktiv nach hinten ziehen, das stabilisiert das Schultergelenk.",
        "Füße fest am Boden — Spannung kommt aus dem ganzen Körper."
      ],
      commonMistakes: [
        "Stange wird auf Halshöhe abgesenkt (Schulterstress).",
        "Hintern hebt von der Bank ab — Wirbelsäulenrisiko."
      ],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Schrägbankdrücken Langhantel", primaryMuscle: "Brust (oben)",
      equipment: "Langhantel", defaultSets: 4, defaultReps: 8, suggestedWeight: 50,
      category: .chest, secondaryMuscles: ["Vordere Schulter", "Trizeps"],
      instructions: [
        "Stelle die Bank auf 30–45° ein.",
        "Setze dich, drücke die Schulterblätter zusammen.",
        "Senke die Stange zur oberen Brust ab.",
        "Drücke gerade nach oben."
      ],
      tips: ["Winkel über 45° verlagert die Last zu stark auf die Schulter."],
      commonMistakes: ["Zu steile Bank macht aus Brust- ein Schulterdrücken."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Schrägbank Kurzhantel", primaryMuscle: "Brust (oben)",
      equipment: "Kurzhantel", defaultSets: 3, defaultReps: 10, suggestedWeight: 24,
      category: .chest, secondaryMuscles: ["Schulter vorne", "Trizeps"],
      instructions: [
        "Bank auf 30°, Hanteln über der Brust mit gestreckten Armen.",
        "Senke beide Hanteln gleichmäßig ab, leichter Bogen.",
        "Drücke wieder nach oben, Hanteln berühren sich nicht."
      ],
      tips: ["Mehr Bewegungsumfang als mit Langhantel — nutze ihn voll aus."],
      commonMistakes: ["Hanteln klappen nach außen, das stresst die Schulter."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Negativbankdrücken", primaryMuscle: "Brust (unten)",
      equipment: "Langhantel", defaultSets: 3, defaultReps: 8, suggestedWeight: 55,
      category: .chest, secondaryMuscles: ["Trizeps"],
      instructions: [
        "Bank in negativer Position einstellen, Füße fixieren.",
        "Stange zur unteren Brust absenken.",
        "Kraftvoll nach oben drücken."
      ],
      tips: ["Wegen schwierigerer Position immer mit Spotter trainieren."],
      commonMistakes: ["Zu schnelles Absenken ohne Kontrolle."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Kurzhantel Bankdrücken", primaryMuscle: "Brust", equipment: "Kurzhantel",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 26,
      category: .chest, secondaryMuscles: ["Schulter", "Trizeps"],
      instructions: [
        "Hanteln seitlich auf den Knien, dann zurücklehnen.",
        "Hanteln auf Brusthöhe positionieren.",
        "Drücke explosiv nach oben."
      ],
      tips: ["Kurzhanteln zwingen jede Seite zur Eigenarbeit — gut gegen Asymmetrien."],
      commonMistakes: ["Hanteln knallen oben aneinander statt kontrolliert zu stoppen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Maschinen-Brustdrücken", primaryMuscle: "Brust", equipment: "Maschine",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 50,
      category: .chest, secondaryMuscles: ["Trizeps"],
      instructions: [
        "Sitzhöhe so, dass die Griffe auf Brusthöhe liegen.",
        "Schulterblätter zurück, Brust raus.",
        "Drücke kontrolliert nach vorn, ohne Ellbogen zu blockieren."
      ],
      tips: ["Gut für Anfänger und Endsätze, weil Stabilisationsanteil entfällt."],
      commonMistakes: ["Sitzhöhe zu hoch — Übung wird Schulter-lastig."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Kabelzug Flys", primaryMuscle: "Brust", equipment: "Kabelzug",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 18,
      category: .chest, secondaryMuscles: ["Schulter vorne"],
      instructions: [
        "Kabel auf hoher oder mittlerer Position, ein Schritt nach vorn.",
        "Arme leicht gebeugt, Bewegung kommt aus der Brust.",
        "Hände vor dem Körper zusammenführen, kurz halten."
      ],
      tips: ["Brust 'umarmen' — kein gerades Drücken."],
      commonMistakes: ["Ellbogen werden zu stark gebeugt — wird zum Brustdrücken."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Kurzhantel Flys", primaryMuscle: "Brust", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 14,
      category: .chest, secondaryMuscles: ["Schulter vorne"],
      instructions: [
        "Flach auf der Bank, Hanteln über der Brust.",
        "Senke die Hanteln in einem Bogen seitlich ab.",
        "Führe sie über der Brust wieder zusammen."
      ],
      tips: ["Leichte Beuge im Ellbogen halten — sonst Reizung im Bizeps-Sehnenansatz."],
      commonMistakes: ["Zu schwere Hanteln, Bewegung wird zum Drücken."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Pec Deck (Butterfly)", primaryMuscle: "Brust", equipment: "Maschine",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 35,
      category: .chest, secondaryMuscles: [],
      instructions: [
        "Sitzhöhe so, dass Ellbogen auf Brusthöhe liegen.",
        "Drücke die Arme kontrolliert vor dem Körper zusammen.",
        "Halte 1 Sek. fest, dann langsam zurück."
      ],
      tips: ["Spitzenkontraktion oben kurz halten — Mind-Muscle-Connection."],
      commonMistakes: ["Hängen-lassen am Ende — keine kontrollierte Negative."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Liegestütze", primaryMuscle: "Brust", equipment: "Körpergewicht",
      defaultSets: 3, defaultReps: 15, suggestedWeight: 0,
      category: .chest, secondaryMuscles: ["Trizeps", "Schulter", "Core"],
      instructions: [
        "Hände schulterbreit, Körper bildet eine gerade Linie.",
        "Senke dich kontrolliert ab, bis die Brust fast den Boden berührt.",
        "Drücke kraftvoll nach oben."
      ],
      tips: ["Bauchspannung halten — Hüfte hängt nicht durch."],
      commonMistakes: ["Ellbogen flippen 90° nach außen statt 45°."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Diamant-Liegestütze", primaryMuscle: "Trizeps", equipment: "Körpergewicht",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 0,
      category: .chest, secondaryMuscles: ["Brust (innen)", "Schulter"],
      instructions: [
        "Hände bilden ein Diamant-Dreieck unter der Brust.",
        "Senke kontrolliert ab.",
        "Drücke explosiv hoch."
      ],
      tips: ["Etwa 30% schwerer als normale Liegestütze — Reps reduzieren."],
      commonMistakes: ["Schultern ziehen Richtung Ohren."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Decline Liegestütze", primaryMuscle: "Brust (oben)",
      equipment: "Körpergewicht", defaultSets: 3, defaultReps: 12, suggestedWeight: 0,
      category: .chest, secondaryMuscles: ["Schulter vorne"],
      instructions: [
        "Füße erhöht auf Bank/Box, Hände am Boden schulterbreit.",
        "Senke die Brust zum Boden.",
        "Drücke zurück nach oben."
      ],
      tips: ["Je höher die Erhöhung, desto stärker Schulteranteil."],
      commonMistakes: ["Hüfte hängt durch — Core-Spannung halten."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Brust-Dips", primaryMuscle: "Brust (unten)", equipment: "Körpergewicht",
      defaultSets: 3, defaultReps: 10, suggestedWeight: 0,
      category: .chest, secondaryMuscles: ["Trizeps", "Schulter"],
      instructions: [
        "An den Dip-Griffen aufstützen.",
        "Lehne den Oberkörper leicht nach vorn.",
        "Senke kontrolliert ab, bis Schulter knapp unter Ellbogen.",
        "Drücke wieder hoch."
      ],
      tips: ["Vorneigung ~30° aktiviert die Brust mehr als den Trizeps."],
      commonMistakes: ["Zu tiefes Absinken — Schulterkapsel-Risiko."],
      difficulty: .intermediate
    )
  ]

  // MARK: Rücken

  private static let backExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Klimmzüge", primaryMuscle: "Latissimus", equipment: "Körpergewicht",
      defaultSets: 4, defaultReps: 8, suggestedWeight: 0,
      category: .back, secondaryMuscles: ["Bizeps", "Hintere Schulter"],
      instructions: [
        "Greife die Stange schulterbreit im Obergriff.",
        "Hänge mit gestreckten Armen, Schulterblätter aktiv.",
        "Ziehe dich hoch, bis das Kinn über die Stange kommt.",
        "Senke kontrolliert ab."
      ],
      tips: ["Stelle dir vor, du ziehst die Ellbogen Richtung Hüfte."],
      commonMistakes: ["Schwung aus den Beinen — Übung wird zum Kippen."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Klimmzüge weit", primaryMuscle: "Latissimus (breit)",
      equipment: "Körpergewicht", defaultSets: 4, defaultReps: 6, suggestedWeight: 0,
      category: .back, secondaryMuscles: ["Hintere Schulter", "Bizeps"],
      instructions: [
        "Weiter Obergriff, ca. 1,5× Schulterbreite.",
        "Ziehe dich hoch, bis Brust nahe der Stange.",
        "Langsam absenken."
      ],
      tips: ["Aktiviert mehr den oberen Latissimus — Breite über alles."],
      commonMistakes: ["Zu weiter Griff überlastet die Schultern."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Klimmzüge eng (neutral)", primaryMuscle: "Latissimus",
      equipment: "Körpergewicht", defaultSets: 3, defaultReps: 10, suggestedWeight: 0,
      category: .back, secondaryMuscles: ["Bizeps"],
      instructions: [
        "Neutralgriff (Hände parallel) am Klimmzug-Griff.",
        "Ziehe dich hoch, Ellbogen nach hinten-unten.",
        "Kontrolliert ablassen."
      ],
      tips: ["Schonender für die Schulter als der weite Griff."],
      commonMistakes: ["Nur halber Bewegungsradius."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Chin-Ups (Untergriff)", primaryMuscle: "Latissimus", equipment: "Körpergewicht",
      defaultSets: 3, defaultReps: 10, suggestedWeight: 0,
      category: .back, secondaryMuscles: ["Bizeps"],
      instructions: [
        "Untergriff schulterbreit.",
        "Ziehe dich hoch, bis Kinn über der Stange.",
        "Langsam zurücklassen."
      ],
      tips: ["Mehr Bizeps-Anteil als beim Obergriff."],
      commonMistakes: ["Halsstrecken statt Hochziehen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Latzug breit", primaryMuscle: "Latissimus", equipment: "Maschine",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 55,
      category: .back, secondaryMuscles: ["Hintere Schulter", "Bizeps"],
      instructions: [
        "Weiter Obergriff, sitzend mit fixierten Knien.",
        "Lehne dich leicht zurück (~10°).",
        "Ziehe die Stange zur oberen Brust.",
        "Lasse kontrolliert nach oben."
      ],
      tips: ["Schulterblätter führen die Bewegung — nicht die Arme."],
      commonMistakes: ["Stange wird hinter den Kopf gezogen — Halsrisiko."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Latzug eng", primaryMuscle: "Latissimus", equipment: "Maschine",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 50,
      category: .back, secondaryMuscles: ["Bizeps"],
      instructions: [
        "Enger Neutral- oder Untergriff.",
        "Ziehe zur Brustmitte.",
        "Langsame Negative."
      ],
      tips: ["Mehr Spannung im unteren Latissimus."],
      commonMistakes: ["Schulter zieht sich zum Ohr."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Langhantelrudern", primaryMuscle: "Rücken", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 8, suggestedWeight: 60,
      category: .back, secondaryMuscles: ["Hintere Schulter", "Bizeps"],
      instructions: [
        "Hüftbreit stehen, Stange greifen, leichte Knie.",
        "Oberkörper ~45° nach vorn, Rücken gerade.",
        "Ziehe die Stange zum Bauchnabel.",
        "Kontrolliert ablassen."
      ],
      tips: ["Ellbogen nah am Körper, nicht ausstellen."],
      commonMistakes: ["Runder Rücken — Wirbelsäulenrisiko."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Pendlay Rudern", primaryMuscle: "Rücken (oben)", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 6, suggestedWeight: 60,
      category: .back, secondaryMuscles: ["Hintere Schulter"],
      instructions: [
        "Stange am Boden, Oberkörper parallel zum Boden.",
        "Reiße die Stange explosiv zum Bauch.",
        "Setze sie zwischen jedem Rep komplett ab."
      ],
      tips: ["Pause am Boden — nutze nur Muskel, keinen Schwung."],
      commonMistakes: ["Hüftschwung statt Rücken."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "T-Bar Rudern", primaryMuscle: "Rücken", equipment: "Maschine",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 50,
      category: .back, secondaryMuscles: ["Hintere Schulter", "Bizeps"],
      instructions: [
        "T-Bar zwischen den Beinen, Oberkörper geneigt.",
        "Ziehe die Griffe zur Brust.",
        "Langsam ablassen."
      ],
      tips: ["Brust raus, Schulterblätter zusammen."],
      commonMistakes: ["Mit dem ganzen Oberkörper rudern."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Rudern sitzend Kabel", primaryMuscle: "Rücken", equipment: "Kabelzug",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 55,
      category: .back, secondaryMuscles: ["Bizeps", "Hintere Schulter"],
      instructions: [
        "Sitzend, Füße auf der Plattform.",
        "Oberkörper aufrecht, leichte Vorneigung.",
        "Ziehe den Griff zum unteren Bauch.",
        "Langsam zurück."
      ],
      tips: ["Schulterblätter aktiv zusammenziehen am Endpunkt."],
      commonMistakes: ["Komplettes Vor- und Zurückwippen mit dem Rumpf."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Einarmiges Kurzhantelrudern", primaryMuscle: "Latissimus",
      equipment: "Kurzhantel", defaultSets: 3, defaultReps: 10, suggestedWeight: 22,
      category: .back, secondaryMuscles: ["Hintere Schulter", "Bizeps"],
      instructions: [
        "Ein Knie und eine Hand auf der Bank.",
        "Hantel hängt unter der Schulter.",
        "Ziehe die Hantel zur Hüfte.",
        "Kontrolliert ablassen."
      ],
      tips: ["Ellbogen führt — Hand folgt nur."],
      commonMistakes: ["Rotation des Oberkörpers für mehr Gewicht."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Kreuzheben", primaryMuscle: "Rücken/Beine", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 5, suggestedWeight: 100,
      category: .back, secondaryMuscles: ["Glutes", "Beinbizeps", "Trapez"],
      instructions: [
        "Stange über Mittelfuß, hüftbreite Stand.",
        "Schienbein berührt fast die Stange.",
        "Brust raus, Rücken neutral, Stange greifen.",
        "Drücke die Beine in den Boden, Stange gleitet eng am Körper hoch.",
        "Hüfte und Schulter erreichen gleichzeitig die Streckung."
      ],
      tips: ["Lat aktiv halten — wie 'Orangen unter der Achsel zerquetschen'."],
      commonMistakes: ["Runder unterer Rücken — sofortiger Stopp.", "Hüfte schießt zuerst hoch."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Rumänisches Kreuzheben", primaryMuscle: "Beinbizeps",
      equipment: "Langhantel", defaultSets: 4, defaultReps: 8, suggestedWeight: 80,
      category: .back, secondaryMuscles: ["Glutes", "Unterer Rücken"],
      instructions: [
        "Stange auf Hüfthöhe, leicht gebeugte Knie.",
        "Hüfte nach hinten schieben, Stange gleitet die Beine entlang.",
        "Stoppen, wenn Dehnung im Beinbizeps spürbar.",
        "Hüfte zurück nach vorn, aufrichten."
      ],
      tips: ["Knie bleiben fast gestreckt — Bewegung kommt aus der Hüfte."],
      commonMistakes: ["Tieferes Absenken durch Rundrücken statt Hüftbeuge."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Hyperextensions", primaryMuscle: "Unterer Rücken",
      equipment: "Maschine", defaultSets: 3, defaultReps: 12, suggestedWeight: 0,
      category: .back, secondaryMuscles: ["Glutes", "Beinbizeps"],
      instructions: [
        "Hüfte am Polster, Füße fixiert.",
        "Oberkörper nach unten beugen.",
        "Gerade Linie wieder herstellen — nicht überstrecken."
      ],
      tips: ["Mit Scheibe vor der Brust für mehr Widerstand."],
      commonMistakes: ["Überstrecken am oberen Punkt."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Pullover Kurzhantel", primaryMuscle: "Latissimus",
      equipment: "Kurzhantel", defaultSets: 3, defaultReps: 12, suggestedWeight: 18,
      category: .back, secondaryMuscles: ["Brust", "Trizeps"],
      instructions: [
        "Quer auf der Bank, Schultern aufgelegt.",
        "Hantel mit beiden Händen über der Brust.",
        "Senke die Hantel hinter den Kopf, Arme leicht gebeugt.",
        "Ziehe sie zurück über die Brust."
      ],
      tips: ["Spüre den Lat-Stretch unten — kein Trizeps-Drücken."],
      commonMistakes: ["Arme zu stark beugen, dann wird's Trizeps-Übung."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Face Pulls", primaryMuscle: "Hintere Schulter", equipment: "Kabelzug",
      defaultSets: 3, defaultReps: 15, suggestedWeight: 25,
      category: .back, secondaryMuscles: ["Trapez", "Rotatorenmanschette"],
      instructions: [
        "Seil auf Augenhöhe, Schritt nach hinten.",
        "Ziehe das Seil zum Gesicht, Hände trennen sich.",
        "Außenrotation der Schulter am Endpunkt.",
        "Langsam zurück."
      ],
      tips: ["Top-Übung für Schultergesundheit — mind. 2× pro Woche."],
      commonMistakes: ["Zu schweres Gewicht — Bewegung wird zum Rudern."],
      difficulty: .beginner
    )
  ]

  // MARK: Schulter

  private static let shoulderExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Schulterdrücken Langhantel", primaryMuscle: "Schulter",
      equipment: "Langhantel", defaultSets: 4, defaultReps: 8, suggestedWeight: 40,
      category: .shoulders, secondaryMuscles: ["Trizeps", "Oberer Trapez"],
      instructions: [
        "Stehend oder sitzend, Stange auf Schlüsselbein.",
        "Drücke die Stange gerade nach oben.",
        "Senke kontrolliert ab."
      ],
      tips: ["Core anspannen — sonst Hohlkreuz."],
      commonMistakes: ["Stange wird zu weit vor dem Körper geführt."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Schulterdrücken Kurzhantel", primaryMuscle: "Schulter",
      equipment: "Kurzhantel", defaultSets: 4, defaultReps: 10, suggestedWeight: 22,
      category: .shoulders, secondaryMuscles: ["Trizeps"],
      instructions: [
        "Sitzend, Lehne fast senkrecht.",
        "Hanteln auf Ohrhöhe, Ellbogen leicht vor dem Körper.",
        "Drücke nach oben, Hanteln berühren sich nicht.",
        "Langsam ablassen."
      ],
      tips: ["Kurzhanteln erlauben individuellen Bewegungsweg pro Schulter."],
      commonMistakes: ["Hanteln werden bis zum Anschlag gestreckt — Ellbogen-Stress."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Arnold Press", primaryMuscle: "Schulter", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 18,
      category: .shoulders, secondaryMuscles: ["Trizeps"],
      instructions: [
        "Hanteln vor der Brust, Handflächen zum Körper.",
        "Drehe die Hanteln nach außen während des Drückens.",
        "Oben Handflächen nach vorn.",
        "Umkehr beim Ablassen."
      ],
      tips: ["Trifft alle drei Schulterköpfe in einer Bewegung."],
      commonMistakes: ["Drehbewegung wird abgeschnitten."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Maschinen-Schulterdrücken", primaryMuscle: "Schulter",
      equipment: "Maschine", defaultSets: 3, defaultReps: 12, suggestedWeight: 35,
      category: .shoulders, secondaryMuscles: ["Trizeps"],
      instructions: [
        "Sitzhöhe so, dass Griffe auf Schulterhöhe.",
        "Drücke gerade nach oben.",
        "Kontrolliertes Ablassen."
      ],
      tips: ["Gut für Endsätze — weniger Stabilisation."],
      commonMistakes: ["Schulter zieht zum Ohr."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Seitheben Kurzhantel", primaryMuscle: "Seitliche Schulter",
      equipment: "Kurzhantel", defaultSets: 3, defaultReps: 15, suggestedWeight: 10,
      category: .shoulders, secondaryMuscles: ["Trapez"],
      instructions: [
        "Hanteln neben dem Körper, leichte Vorneigung.",
        "Hebe die Hanteln seitlich bis Schulterhöhe.",
        "Ellbogen führen — Daumen leicht nach unten.",
        "Langsam ablassen."
      ],
      tips: ["Bewegung kontrolliert — kein Schwung."],
      commonMistakes: ["Trapez übernimmt die Arbeit, Schulter zieht hoch."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Seitheben Kabel", primaryMuscle: "Seitliche Schulter",
      equipment: "Kabelzug", defaultSets: 3, defaultReps: 15, suggestedWeight: 10,
      category: .shoulders, secondaryMuscles: [],
      instructions: [
        "Kabel auf untere Position.",
        "Stehe seitlich zum Zug, Griff in der Außenhand.",
        "Hebe den Arm seitlich auf Schulterhöhe.",
        "Kontrolliert zurück."
      ],
      tips: ["Konstante Spannung — auch unten nicht hängen lassen."],
      commonMistakes: ["Zu nah am Zug, Bewegung wird unten kraftlos."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Frontheben Kurzhantel", primaryMuscle: "Vordere Schulter",
      equipment: "Kurzhantel", defaultSets: 3, defaultReps: 12, suggestedWeight: 12,
      category: .shoulders, secondaryMuscles: [],
      instructions: [
        "Hanteln vor dem Körper, neutrale oder Pronation.",
        "Hebe abwechselnd oder beidarmig auf Schulterhöhe.",
        "Kontrolliert ablassen."
      ],
      tips: ["Nicht über Schulterhöhe — sonst übernimmt Trapez."],
      commonMistakes: ["Lehnt zurück, Hohlkreuz."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Reverse Flys Kurzhantel", primaryMuscle: "Hintere Schulter",
      equipment: "Kurzhantel", defaultSets: 3, defaultReps: 15, suggestedWeight: 8,
      category: .shoulders, secondaryMuscles: ["Trapez"],
      instructions: [
        "Vorgebeugt 45°, Hanteln hängen vor dem Körper.",
        "Hebe die Hanteln seitlich, Ellbogen leicht gebeugt.",
        "Kurz halten am Endpunkt.",
        "Langsam ablassen."
      ],
      tips: ["Schulterblätter zusammen — daher kommt die Spannung."],
      commonMistakes: ["Mit dem Rumpf schwingen."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Reverse Flys Maschine", primaryMuscle: "Hintere Schulter",
      equipment: "Maschine", defaultSets: 3, defaultReps: 15, suggestedWeight: 25,
      category: .shoulders, secondaryMuscles: ["Trapez"],
      instructions: [
        "Sitzend mit Brust am Polster.",
        "Drücke die Griffe nach hinten-außen.",
        "Halte 1 Sek., dann zurück."
      ],
      tips: ["Häufig vernachlässigt — wichtig für Schulter-Balance."],
      commonMistakes: ["Mit dem Rücken statt der Schulter ziehen."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Upright Row", primaryMuscle: "Schulter", equipment: "Langhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 25,
      category: .shoulders, secondaryMuscles: ["Trapez", "Bizeps"],
      instructions: [
        "Stange im Obergriff, schulterbreit.",
        "Ziehe die Stange senkrecht zur Brust hoch.",
        "Ellbogen führen.",
        "Kontrolliert ablassen."
      ],
      tips: ["Nicht über Brusthöhe — Schulter-Impingement-Risiko."],
      commonMistakes: ["Zu enger Griff verschlechtert Schulterposition."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Shrugs Kurzhantel", primaryMuscle: "Trapez", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 15, suggestedWeight: 26,
      category: .shoulders, secondaryMuscles: [],
      instructions: [
        "Hanteln neben dem Körper.",
        "Ziehe die Schultern senkrecht nach oben.",
        "Kurz halten am Top.",
        "Langsam absenken."
      ],
      tips: ["Keine Kreisbewegung — schadet der Halswirbelsäule."],
      commonMistakes: ["Kopf wird mitgenommen."],
      difficulty: .beginner
    )
  ]

  // MARK: Bizeps

  private static let bicepsExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Langhantel Curls", primaryMuscle: "Bizeps", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 25,
      category: .biceps, secondaryMuscles: ["Unterarm"],
      instructions: [
        "Stange im Untergriff, schulterbreit.",
        "Ellbogen am Körper fixiert.",
        "Hebe die Stange zur Brust.",
        "Langsam ablassen."
      ],
      tips: ["Ellbogen wandern nicht nach vorn."],
      commonMistakes: ["Schwung aus den Knien."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Kurzhantel Curls", primaryMuscle: "Bizeps", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 14,
      category: .biceps, secondaryMuscles: ["Unterarm"],
      instructions: [
        "Hanteln neben dem Körper, Untergriff.",
        "Curle abwechselnd oder gleichzeitig.",
        "Drehe das Handgelenk leicht nach außen am Top."
      ],
      tips: ["Supination am Top für mehr Bizeps-Aktivierung."],
      commonMistakes: ["Schultern bewegen sich mit."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Hammer Curls", primaryMuscle: "Brachialis", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 16,
      category: .biceps, secondaryMuscles: ["Bizeps", "Unterarm"],
      instructions: [
        "Hanteln im Neutralgriff (Daumen oben).",
        "Curle hoch, Handposition bleibt neutral.",
        "Langsam ablassen."
      ],
      tips: ["Trifft den Brachialis — schiebt den Bizeps nach außen, mehr Volumen."],
      commonMistakes: ["Drehung der Hand am Top."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Konzentrationscurls", primaryMuscle: "Bizeps", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 12,
      category: .biceps, secondaryMuscles: [],
      instructions: [
        "Sitzend, Ellbogen am Innenschenkel abgestützt.",
        "Hantel hängt fast bis zum Boden.",
        "Curle kontrolliert hoch."
      ],
      tips: ["Maximale Spitzenkontraktion am Top."],
      commonMistakes: ["Schwung mit dem Oberkörper."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Predigerbank Curls", primaryMuscle: "Bizeps (unten)",
      equipment: "SZ-Stange", defaultSets: 3, defaultReps: 10, suggestedWeight: 20,
      category: .biceps, secondaryMuscles: [],
      instructions: [
        "Oberarme fest auf dem Polster.",
        "Curle die Stange nach oben.",
        "Senke kontrolliert — nicht voll strecken."
      ],
      tips: ["Voll strecken überdehnt die Sehne — kurz vor Streckung stoppen."],
      commonMistakes: ["Ellbogen abheben vom Polster."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Incline Curls", primaryMuscle: "Bizeps (lang)", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 12,
      category: .biceps, secondaryMuscles: [],
      instructions: [
        "Bank auf 45°, Hanteln hängen.",
        "Curle nach oben, Schultern bleiben hinten.",
        "Voller Stretch unten."
      ],
      tips: ["Trifft den langen Bizepskopf — Peak."],
      commonMistakes: ["Schultern rollen nach vorn — Cheating."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Kabel Curls", primaryMuscle: "Bizeps", equipment: "Kabelzug",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 22,
      category: .biceps, secondaryMuscles: ["Unterarm"],
      instructions: [
        "Stange am unteren Kabel.",
        "Curle hoch, Ellbogen fest.",
        "Konstante Spannung — auch unten nicht entlasten."
      ],
      tips: ["Top-Wahl für Endsätze und Drop Sets."],
      commonMistakes: ["Ellbogen wandern nach vorn."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Spider Curls", primaryMuscle: "Bizeps", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 12,
      category: .biceps, secondaryMuscles: [],
      instructions: [
        "Bauchlage auf der Schrägbank.",
        "Hanteln hängen senkrecht nach unten.",
        "Curle die Hanteln zur Schulter."
      ],
      tips: ["Strikte Form ohne Schwung möglich — sehr sauberer Stimulus."],
      commonMistakes: ["Drehen aus der Bauchlage."],
      difficulty: .intermediate
    )
  ]

  // MARK: Trizeps

  private static let tricepsExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Trizeps Pushdown (Seil)", primaryMuscle: "Trizeps",
      equipment: "Kabelzug", defaultSets: 3, defaultReps: 12, suggestedWeight: 28,
      category: .triceps, secondaryMuscles: [],
      instructions: [
        "Seil am oberen Kabel, Ellbogen am Körper.",
        "Drücke das Seil nach unten, ziehe die Enden auseinander.",
        "Halte am Ende kurz, dann langsam zurück."
      ],
      tips: ["Seil-Auseinanderziehen am Endpunkt aktiviert Trizeps stärker."],
      commonMistakes: ["Mit dem Oberkörper drücken."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Trizeps Pushdown (gerade)", primaryMuscle: "Trizeps",
      equipment: "Kabelzug", defaultSets: 3, defaultReps: 12, suggestedWeight: 32,
      category: .triceps, secondaryMuscles: [],
      instructions: [
        "Gerade Stange am oberen Kabel.",
        "Ellbogen fix am Körper.",
        "Drücke nach unten zur Streckung."
      ],
      tips: ["Mehr Last möglich als am Seil."],
      commonMistakes: ["Ellbogen wandern nach vorn."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Skull Crusher", primaryMuscle: "Trizeps",
      equipment: "SZ-Stange", defaultSets: 3, defaultReps: 10, suggestedWeight: 22,
      category: .triceps, secondaryMuscles: [],
      instructions: [
        "Flach auf der Bank, SZ-Stange über der Brust.",
        "Senke die Stange Richtung Stirn.",
        "Strecke die Arme wieder."
      ],
      tips: ["Bewegung nur aus den Ellbogen."],
      commonMistakes: ["Stange touchiert Stirn — Spotter empfohlen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "French Press", primaryMuscle: "Trizeps", equipment: "SZ-Stange",
      defaultSets: 3, defaultReps: 10, suggestedWeight: 25,
      category: .triceps, secondaryMuscles: [],
      instructions: [
        "Sitzend oder stehend, Stange über dem Kopf.",
        "Senke die Stange hinter den Kopf.",
        "Strecke wieder nach oben."
      ],
      tips: ["Trifft den langen Trizepskopf gut."],
      commonMistakes: ["Ellbogen flippen nach außen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Overhead Trizeps Kurzhantel", primaryMuscle: "Trizeps",
      equipment: "Kurzhantel", defaultSets: 3, defaultReps: 12, suggestedWeight: 16,
      category: .triceps, secondaryMuscles: [],
      instructions: [
        "Hantel mit beiden Händen über dem Kopf.",
        "Senke hinter den Kopf, Ellbogen zeigen nach vorn.",
        "Strecke wieder."
      ],
      tips: ["Voller Stretch im langen Trizepskopf."],
      commonMistakes: ["Ellbogen flippen — Schulterstress."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Trizeps Dips (Bank)", primaryMuscle: "Trizeps",
      equipment: "Körpergewicht", defaultSets: 3, defaultReps: 12, suggestedWeight: 0,
      category: .triceps, secondaryMuscles: ["Schulter vorne"],
      instructions: [
        "Hände auf der Bank, Beine vorne ausgestreckt.",
        "Senke die Hüfte ab, bis Ellbogen 90°.",
        "Drücke wieder hoch."
      ],
      tips: ["Gut als Aufwärm- oder Finisher-Übung."],
      commonMistakes: ["Schultern rollen nach vorn."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Trizeps Dips", primaryMuscle: "Trizeps", equipment: "Körpergewicht",
      defaultSets: 3, defaultReps: 10, suggestedWeight: 0,
      category: .triceps, secondaryMuscles: ["Brust", "Schulter"],
      instructions: [
        "An den Dip-Griffen, Oberkörper aufrecht.",
        "Senke ab, bis Ellbogen 90°.",
        "Drücke explosiv hoch."
      ],
      tips: ["Aufrechter Oberkörper = mehr Trizeps, vorgeneigt = mehr Brust."],
      commonMistakes: ["Zu tief absinken — Schulterstress."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Kickbacks", primaryMuscle: "Trizeps", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 8,
      category: .triceps, secondaryMuscles: [],
      instructions: [
        "Vorgebeugt, Oberarm parallel zum Körper.",
        "Strecke den Unterarm nach hinten.",
        "Halte oben kurz, dann zurück."
      ],
      tips: ["Geringes Gewicht reicht — Form über Last."],
      commonMistakes: ["Schwung aus dem Oberarm."],
      difficulty: .beginner
    )
  ]

  // MARK: Beine

  private static let legExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Kniebeugen", primaryMuscle: "Quadrizeps", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 6, suggestedWeight: 80,
      category: .legs, secondaryMuscles: ["Glutes", "Beinbizeps", "Core"],
      instructions: [
        "Stange auf dem oberen Trapez, schulterbreiter Stand.",
        "Hüfte nach hinten, Knie folgen den Zehen.",
        "Bis Hüfte unter Kniegelenk absenken.",
        "Kraftvoll nach oben drücken."
      ],
      tips: ["Brust hoch, Rücken neutral — keine Rundung im unteren Rücken."],
      commonMistakes: ["Knie kollabieren nach innen.", "Fersen heben vom Boden."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Frontkniebeugen", primaryMuscle: "Quadrizeps",
      equipment: "Langhantel", defaultSets: 4, defaultReps: 6, suggestedWeight: 60,
      category: .legs, secondaryMuscles: ["Core", "Glutes"],
      instructions: [
        "Stange auf dem vorderen Schultergürtel, Ellbogen hoch.",
        "Aufrechter Oberkörper.",
        "Tief absenken, Hüfte unter Knie.",
        "Aufrichten."
      ],
      tips: ["Trifft den Quad härter als Backsquats — gut für Beinaufbau."],
      commonMistakes: ["Ellbogen sinken ab, Stange rollt nach vorn."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Hack Squat", primaryMuscle: "Quadrizeps", equipment: "Maschine",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 80,
      category: .legs, secondaryMuscles: ["Glutes"],
      instructions: [
        "Schultern unter dem Polster, Füße schulterbreit.",
        "Senke kontrolliert ab.",
        "Drücke aus den Fersen wieder hoch."
      ],
      tips: ["Sicherer als freie Squats — gut für hohes Volumen."],
      commonMistakes: ["Knie kollabieren nach innen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Beinpresse 45°", primaryMuscle: "Quadrizeps", equipment: "Maschine",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 140,
      category: .legs, secondaryMuscles: ["Glutes", "Beinbizeps"],
      instructions: [
        "Setze dich, Füße schulterbreit auf der Plattform.",
        "Senke kontrolliert ab, Knie Richtung Brust.",
        "Drücke kraftvoll zurück, ohne Knie zu sperren."
      ],
      tips: ["Fußposition variiert die Belastung — höher = Glutes, tiefer = Quads."],
      commonMistakes: ["Hüfte hebt von der Polster ab."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Bulgarian Split Squat", primaryMuscle: "Quadrizeps",
      equipment: "Kurzhantel", defaultSets: 3, defaultReps: 10, suggestedWeight: 14,
      category: .legs, secondaryMuscles: ["Glutes", "Core"],
      instructions: [
        "Hinterer Fuß auf der Bank, vorderer ein Schritt nach vorn.",
        "Senke das hintere Knie kontrolliert ab.",
        "Drücke aus dem vorderen Bein wieder hoch."
      ],
      tips: ["Vorderes Bein trägt die Hauptarbeit — Schritt weit genug nach vorn."],
      commonMistakes: ["Vorderes Knie schiebt zu weit über die Zehen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Ausfallschritte", primaryMuscle: "Quadrizeps", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 12,
      category: .legs, secondaryMuscles: ["Glutes"],
      instructions: [
        "Hanteln seitlich, Schritt nach vorn.",
        "Beide Knie 90°, hinteres Knie über dem Boden.",
        "Zurück in Startposition."
      ],
      tips: ["Walking Lunges = mehr Glute-Aktivierung."],
      commonMistakes: ["Vorderes Knie schiebt vor die Zehe."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Beinstrecker", primaryMuscle: "Quadrizeps", equipment: "Maschine",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 55,
      category: .legs, secondaryMuscles: [],
      instructions: [
        "Sitzen, Polster über den Knöcheln.",
        "Strecke die Beine bis fast voll durch.",
        "Halte 1 Sek. am Top.",
        "Langsam ablassen."
      ],
      tips: ["Voll-Strecken vermeiden bei Knieproblemen."],
      commonMistakes: ["Schwung — Hüfte hebt vom Sitz."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Beinbeuger sitzend", primaryMuscle: "Beinbizeps", equipment: "Maschine",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 45,
      category: .legs, secondaryMuscles: ["Waden"],
      instructions: [
        "Sitzen, Polster über den Knöcheln.",
        "Beuge die Knie kontrolliert.",
        "Halte unten, dann langsam zurück."
      ],
      tips: ["Sitzende Variante streckt den Beinbizeps mehr."],
      commonMistakes: ["Tempo zu hoch."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Beinbeuger liegend", primaryMuscle: "Beinbizeps", equipment: "Maschine",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 40,
      category: .legs, secondaryMuscles: [],
      instructions: [
        "Auf dem Bauch, Polster über den Knöcheln.",
        "Ziehe die Fersen zum Po.",
        "Langsam ablassen."
      ],
      tips: ["Hüfte fest auf dem Polster."],
      commonMistakes: ["Hüfte hebt ab, Schwung."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Wadenheben stehend", primaryMuscle: "Waden", equipment: "Maschine",
      defaultSets: 4, defaultReps: 15, suggestedWeight: 60,
      category: .legs, secondaryMuscles: [],
      instructions: [
        "Vorderfuß auf der Plattform, Fersen frei.",
        "Drücke dich auf die Zehenspitzen.",
        "Langsam ablassen, voller Stretch unten."
      ],
      tips: ["Voller Bewegungsumfang — unten Stretch, oben kurz halten."],
      commonMistakes: ["Halber Bewegungsradius."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Wadenheben sitzend", primaryMuscle: "Schollenmuskel",
      equipment: "Maschine", defaultSets: 4, defaultReps: 15, suggestedWeight: 30,
      category: .legs, secondaryMuscles: [],
      instructions: [
        "Sitzen, Knie 90°, Polster auf Oberschenkel.",
        "Hebe die Fersen.",
        "Langsam ablassen."
      ],
      tips: ["Trifft den Schollenmuskel — gut für Volumen unter der Wade."],
      commonMistakes: ["Bouncing am unteren Punkt."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Step-Ups", primaryMuscle: "Quadrizeps", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 10, suggestedWeight: 12,
      category: .legs, secondaryMuscles: ["Glutes"],
      instructions: [
        "Hanteln seitlich, Box ca. Kniehöhe.",
        "Steige auf die Box, drücke aus dem oberen Bein.",
        "Kontrolliert herunter."
      ],
      tips: ["Hauptarbeit kommt aus dem oberen Bein — nicht vom hinteren abdrücken."],
      commonMistakes: ["Hinterer Fuß drückt mit hoch."],
      difficulty: .intermediate
    )
  ]

  // MARK: Glutes

  private static let gluteExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Hip Thrust", primaryMuscle: "Glutes", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 90,
      category: .glutes, secondaryMuscles: ["Beinbizeps", "Core"],
      instructions: [
        "Schultern an einer Bank, Stange auf der Hüfte.",
        "Drücke die Hüfte nach oben, bis Knie/Hüfte/Schulter eine Linie bilden.",
        "Halte oben 1 Sek.",
        "Senke kontrolliert."
      ],
      tips: ["Kinn zur Brust, Rippen nicht aufschlagen."],
      commonMistakes: ["Überstreckung der Lendenwirbelsäule."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Glute Bridge", primaryMuscle: "Glutes", equipment: "Körpergewicht",
      defaultSets: 3, defaultReps: 15, suggestedWeight: 0,
      category: .glutes, secondaryMuscles: ["Core"],
      instructions: [
        "Rückenlage, Knie gebeugt, Füße hüftbreit.",
        "Drücke die Hüfte nach oben.",
        "Halte kurz, dann ablassen."
      ],
      tips: ["Aktivierung vor schweren Sets."],
      commonMistakes: ["Hohlkreuz statt Glute-Anspannung."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Cable Kickback", primaryMuscle: "Glutes", equipment: "Kabelzug",
      defaultSets: 3, defaultReps: 15, suggestedWeight: 14,
      category: .glutes, secondaryMuscles: [],
      instructions: [
        "Fußschlaufe am unteren Kabel.",
        "Eine Hand am Gerät, Oberkörper leicht vorgeneigt.",
        "Strecke das Bein nach hinten, Glute aktiv.",
        "Langsam zurück."
      ],
      tips: ["Bewegung kommt aus der Hüfte — kein Hohlkreuz."],
      commonMistakes: ["Oberkörper kippt nach vorn für mehr Reichweite."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Sumo Squat", primaryMuscle: "Glutes", equipment: "Kurzhantel",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 22,
      category: .glutes, secondaryMuscles: ["Innenseite Oberschenkel", "Quadrizeps"],
      instructions: [
        "Weiter Stand, Zehen nach außen.",
        "Hantel zwischen den Beinen.",
        "Tief absenken, Knie über Zehen.",
        "Aufrichten."
      ],
      tips: ["Knie über Zehenspitzen, sonst Innenrotation."],
      commonMistakes: ["Knie kollabieren nach innen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Cable Pull-Through", primaryMuscle: "Glutes", equipment: "Kabelzug",
      defaultSets: 3, defaultReps: 12, suggestedWeight: 25,
      category: .glutes, secondaryMuscles: ["Beinbizeps"],
      instructions: [
        "Mit dem Rücken zum Kabel, Seil zwischen den Beinen.",
        "Hüfte nach hinten, Oberkörper neigt sich.",
        "Drücke die Hüfte nach vorn, ziehe das Seil zwischen den Beinen durch."
      ],
      tips: ["Hüftdominante Bewegung — kein Squat."],
      commonMistakes: ["Mit den Armen ziehen statt der Hüfte."],
      difficulty: .intermediate
    )
  ]

  // MARK: Core

  private static let coreExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Plank", primaryMuscle: "Core", equipment: "Körpergewicht",
      defaultSets: 3, defaultReps: 60, suggestedWeight: 0,
      category: .core, secondaryMuscles: ["Schulter", "Glutes"],
      instructions: [
        "Unterarme schulterbreit am Boden.",
        "Körper bildet eine gerade Linie.",
        "Bauch und Glutes anspannen.",
        "Position halten."
      ],
      tips: ["Rep-Zahl = Sekunden. Qualität vor Dauer — bei Hängen abbrechen."],
      commonMistakes: ["Hüfte hängt durch oder ragt nach oben."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Side Plank", primaryMuscle: "Schräge Bauchmuskeln",
      equipment: "Körpergewicht", defaultSets: 3, defaultReps: 30, suggestedWeight: 0,
      category: .core, secondaryMuscles: ["Schulter"],
      instructions: [
        "Seitenlage, ein Unterarm am Boden.",
        "Hebe die Hüfte, gerade Linie von Kopf bis Fuß.",
        "Halten, dann Seite wechseln."
      ],
      tips: ["Hüfte oben halten — kein Absinken."],
      commonMistakes: ["Schultern rotieren nach vorn."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Hängendes Beinheben", primaryMuscle: "Unterer Bauch",
      equipment: "Körpergewicht", defaultSets: 3, defaultReps: 12, suggestedWeight: 0,
      category: .core, secondaryMuscles: ["Hüftbeuger", "Unterarm"],
      instructions: [
        "An der Stange hängen, Schultern aktiv.",
        "Hebe die Beine kontrolliert auf 90°.",
        "Langsam ablassen."
      ],
      tips: ["Kein Schwung — Bauch macht die Arbeit."],
      commonMistakes: ["Schwung mit dem ganzen Körper."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Liegendes Beinheben", primaryMuscle: "Unterer Bauch",
      equipment: "Körpergewicht", defaultSets: 3, defaultReps: 15, suggestedWeight: 0,
      category: .core, secondaryMuscles: ["Hüftbeuger"],
      instructions: [
        "Rückenlage, Hände unter dem Po.",
        "Hebe die gestreckten Beine bis 90°.",
        "Senke kontrolliert ab, ohne den Boden zu berühren."
      ],
      tips: ["Lendenwirbelsäule am Boden — kein Hohlkreuz."],
      commonMistakes: ["Schwung mit den Beinen."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Crunches", primaryMuscle: "Bauch", equipment: "Körpergewicht",
      defaultSets: 3, defaultReps: 20, suggestedWeight: 0,
      category: .core, secondaryMuscles: [],
      instructions: [
        "Rückenlage, Knie 90°.",
        "Hebe Schultern und oberen Rücken an.",
        "Langsam zurück."
      ],
      tips: ["Bewegung kommt aus dem Bauch, nicht aus dem Nacken."],
      commonMistakes: ["Mit den Händen am Kopf ziehen."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Russian Twist", primaryMuscle: "Schräge Bauchmuskeln",
      equipment: "Kurzhantel", defaultSets: 3, defaultReps: 20, suggestedWeight: 8,
      category: .core, secondaryMuscles: [],
      instructions: [
        "Sitzend, Beine angehoben, Hantel vor der Brust.",
        "Drehe den Oberkörper abwechselnd zur Seite.",
        "Kontrolliertes Tempo."
      ],
      tips: ["Rotation kommt aus dem Rumpf, nicht aus den Armen."],
      commonMistakes: ["Hantel wandert um den Körper, ohne Rotation."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Ab Wheel Rollout", primaryMuscle: "Core",
      equipment: "Körpergewicht", defaultSets: 3, defaultReps: 10, suggestedWeight: 0,
      category: .core, secondaryMuscles: ["Schulter", "Latissimus"],
      instructions: [
        "Knien, Wheel vor den Knien.",
        "Rolle das Wheel nach vorn, bis fast voll gestreckt.",
        "Ziehe dich zurück."
      ],
      tips: ["Bauchspannung halten — kein Hohlkreuz."],
      commonMistakes: ["Hüfte hängt durch unten."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Cable Woodchop", primaryMuscle: "Schräge Bauchmuskeln",
      equipment: "Kabelzug", defaultSets: 3, defaultReps: 12, suggestedWeight: 18,
      category: .core, secondaryMuscles: ["Schulter"],
      instructions: [
        "Kabel auf hoher Position, seitlich stehen.",
        "Greife mit beiden Händen, ziehe diagonal über den Körper bis Hüfte.",
        "Kontrolliert zurück."
      ],
      tips: ["Rotation kommt aus dem Rumpf."],
      commonMistakes: ["Mit den Armen ziehen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Pallof Press", primaryMuscle: "Anti-Rotation",
      equipment: "Kabelzug", defaultSets: 3, defaultReps: 12, suggestedWeight: 12,
      category: .core, secondaryMuscles: [],
      instructions: [
        "Seitlich zum Kabel stehen, Griff auf Brusthöhe.",
        "Drücke den Griff gerade nach vorn vom Körper weg.",
        "Halte 2 Sek., dann zurück."
      ],
      tips: ["Anti-Rotations-Übung — Körper darf nicht verdrehen."],
      commonMistakes: ["Oberkörper rotiert mit."],
      difficulty: .intermediate
    )
  ]

  // MARK: Ganzkörper / Functional

  private static let fullBodyExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Burpees", primaryMuscle: "Ganzkörper", equipment: "Körpergewicht",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 0,
      category: .fullBody, secondaryMuscles: ["Brust", "Beine", "Core"],
      instructions: [
        "Aus dem Stand: Hände am Boden.",
        "Beine zurückspringen in Liegestütz.",
        "Ein Liegestütz, Beine zurück, Sprung in die Höhe.",
        "Wiederholen."
      ],
      tips: ["Tempo halten, aber Form vor Geschwindigkeit."],
      commonMistakes: ["Liegestütz wird übersprungen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Kettlebell Swing", primaryMuscle: "Glutes/Beinbizeps",
      equipment: "Kettlebell", defaultSets: 4, defaultReps: 15, suggestedWeight: 16,
      category: .fullBody, secondaryMuscles: ["Schulter", "Core"],
      instructions: [
        "Stand etwas weiter als hüftbreit, Kettlebell zwischen den Beinen.",
        "Hüfte nach hinten, Kettlebell schwingt zwischen die Beine.",
        "Hüfte explosiv strecken, KB schwingt auf Brusthöhe.",
        "Wiederholen — Bewegung aus der Hüfte, nicht den Armen."
      ],
      tips: ["Hüftexplosion treibt die Kettlebell — Arme sind nur Seile."],
      commonMistakes: ["Hocken statt Hüftbeugung."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Thruster", primaryMuscle: "Ganzkörper", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 10, suggestedWeight: 30,
      category: .fullBody, secondaryMuscles: ["Quadrizeps", "Schulter", "Trizeps"],
      instructions: [
        "Stange auf den vorderen Schultern.",
        "Front Squat tief absenken.",
        "Aus der Hocke explosiv hochdrücken — Stange direkt nach oben.",
        "Voll ausstrecken über dem Kopf."
      ],
      tips: ["Hüftexplosion treibt die Stange — Arme nur Lenken."],
      commonMistakes: ["Squat und Drücken werden getrennt — verliert Effizienz."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Power Clean", primaryMuscle: "Ganzkörper", equipment: "Langhantel",
      defaultSets: 4, defaultReps: 5, suggestedWeight: 50,
      category: .fullBody, secondaryMuscles: ["Beinbizeps", "Glutes", "Trapez"],
      instructions: [
        "Stand hüftbreit, Stange über Mittelfuß.",
        "Hüftbeugung, Stange greifen.",
        "Ziehe die Stange explosiv hoch, Hüftexplosion.",
        "Fange die Stange in der Front Rack Position auf."
      ],
      tips: ["Komplexe Übung — mit leichtem Gewicht und Coach lernen."],
      commonMistakes: ["Mit den Armen ziehen statt aus den Beinen."],
      difficulty: .advanced
    ),
    ExerciseLibraryItem(
      name: "Wall Ball", primaryMuscle: "Ganzkörper", equipment: "Medizinball",
      defaultSets: 4, defaultReps: 15, suggestedWeight: 9,
      category: .fullBody, secondaryMuscles: ["Quadrizeps", "Schulter"],
      instructions: [
        "Med-Ball vor der Brust, Front Squat.",
        "Aus der Hocke explosiv aufrichten und Ball gegen die Wand werfen.",
        "Fang ihn auf und gehe direkt in den nächsten Squat."
      ],
      tips: ["Ziel-Marke an der Wand setzen — sorgt für konstante Höhe."],
      commonMistakes: ["Nur mit den Armen werfen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Box Jump", primaryMuscle: "Beine", equipment: "Box",
      defaultSets: 4, defaultReps: 8, suggestedWeight: 0,
      category: .fullBody, secondaryMuscles: ["Glutes", "Core"],
      instructions: [
        "Stehe vor der Box, hüftbreit.",
        "Schwung mit den Armen, springe auf die Box.",
        "Komplette Streckung oben.",
        "Steige (nicht springe!) zurück."
      ],
      tips: ["Zurücksteigen schont die Achilles."],
      commonMistakes: ["Beine nicht voll strecken oben."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Turkish Get-Up", primaryMuscle: "Ganzkörper",
      equipment: "Kettlebell", defaultSets: 3, defaultReps: 5, suggestedWeight: 12,
      category: .fullBody, secondaryMuscles: ["Schulter", "Core"],
      instructions: [
        "Rückenlage, KB in einer Hand gestreckt nach oben.",
        "Aufstehen über mehrere Stufen, KB bleibt gestreckt oben.",
        "Stehen — KB immer gerade über der Schulter.",
        "Reverse-Sequenz zurück."
      ],
      tips: ["Komplette Übung pro Seite — Schulterstabilität-Booster."],
      commonMistakes: ["Arm nicht senkrecht über der Schulter."],
      difficulty: .advanced
    )
  ]

  // MARK: Cardio

  private static let cardioExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Laufband", primaryMuscle: "Cardio", equipment: "Maschine",
      defaultSets: 1, defaultReps: 20, suggestedWeight: 0,
      category: .cardio, secondaryMuscles: ["Beine", "Core"],
      instructions: [
        "Geschwindigkeit und Steigung passend zum Workout-Ziel wählen.",
        "Aufwärm-Phase 5 Minuten lockerer Lauf.",
        "Hauptintervall oder konstantes Tempo.",
        "Cool-Down 3–5 Minuten."
      ],
      tips: ["Steigung 1% simuliert Outdoor-Bedingungen."],
      commonMistakes: ["An den Griffen festhalten — verfälscht Belastung."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Crosstrainer", primaryMuscle: "Cardio", equipment: "Maschine",
      defaultSets: 1, defaultReps: 25, suggestedWeight: 0,
      category: .cardio, secondaryMuscles: ["Beine", "Arme"],
      instructions: [
        "Aufrechter Stand, Hände an den Griffen.",
        "Gleichmäßige Bewegung mit Armen und Beinen.",
        "Widerstand passend wählen."
      ],
      tips: ["Gelenkschonende Alternative zum Laufband."],
      commonMistakes: ["Nur die Beine bewegen — Arme passiv."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Rudergerät", primaryMuscle: "Cardio + Rücken", equipment: "Maschine",
      defaultSets: 1, defaultReps: 20, suggestedWeight: 0,
      category: .cardio, secondaryMuscles: ["Beine", "Latissimus", "Bizeps"],
      instructions: [
        "Setzen, Füße fixieren.",
        "Beine drücken zuerst, dann Oberkörper, dann Arme.",
        "Reverse: Arme zuerst, dann Oberkörper, dann Beine."
      ],
      tips: ["60% Beine, 20% Rücken, 20% Arme."],
      commonMistakes: ["Mit den Armen zuerst ziehen."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Assault Bike", primaryMuscle: "Cardio", equipment: "Maschine",
      defaultSets: 4, defaultReps: 1, suggestedWeight: 0,
      category: .cardio, secondaryMuscles: ["Beine", "Arme"],
      instructions: [
        "Aufrechter Sitz, Griffe in beiden Händen.",
        "Tritt + Drücke gleichzeitig.",
        "Intervall-Format: 30 Sek hart / 30 Sek locker."
      ],
      tips: ["Bringt Herzfrequenz schneller hoch als jedes andere Cardio-Gerät."],
      commonMistakes: ["Nur Beine, Arme hängen — verschenkt Effekt."],
      difficulty: .intermediate
    ),
    ExerciseLibraryItem(
      name: "Stepper", primaryMuscle: "Cardio + Beine", equipment: "Maschine",
      defaultSets: 1, defaultReps: 20, suggestedWeight: 0,
      category: .cardio, secondaryMuscles: ["Glutes", "Quadrizeps"],
      instructions: [
        "Aufrecht, leichte Vorneigung.",
        "Kontrollierte, gleichmäßige Schritte.",
        "Nicht auf den Griffen abstützen."
      ],
      tips: ["Glute-aktivierendes Cardio."],
      commonMistakes: ["Im Geländer hängen."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Seilspringen", primaryMuscle: "Cardio + Waden",
      equipment: "Seil", defaultSets: 4, defaultReps: 60, suggestedWeight: 0,
      category: .cardio, secondaryMuscles: ["Waden", "Schulter"],
      instructions: [
        "Stand hüftbreit, Seil hinter den Fersen.",
        "Schwinge das Seil und springe leicht auf die Vorderfüße.",
        "Sprung niedrig halten."
      ],
      tips: ["Rep = Sekunden. Niedriger Sprung schont die Knie."],
      commonMistakes: ["Zu hoch springen — Energie verschwendet."],
      difficulty: .beginner
    )
  ]

  // MARK: Mobility

  private static let mobilityExercises: [ExerciseLibraryItem] = [
    ExerciseLibraryItem(
      name: "Cat-Cow", primaryMuscle: "Wirbelsäule", equipment: "Körpergewicht",
      defaultSets: 2, defaultReps: 10, suggestedWeight: 0,
      category: .mobility, secondaryMuscles: ["Core"],
      instructions: [
        "Vierfüßlerstand, Hände unter den Schultern.",
        "Cat: Rücken rund, Kinn zur Brust.",
        "Cow: Rücken durchhängen, Blick nach oben.",
        "Wechsel im Atemrhythmus."
      ],
      tips: ["Aufwärm-Übung vor jedem Kraftworkout."],
      commonMistakes: ["Bewegung nur in einem Wirbelsäulenabschnitt."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "World's Greatest Stretch", primaryMuscle: "Hüfte/Brustwirbelsäule",
      equipment: "Körpergewicht", defaultSets: 2, defaultReps: 8, suggestedWeight: 0,
      category: .mobility, secondaryMuscles: [],
      instructions: [
        "Ausfallschritt nach vorn.",
        "Eine Hand am Boden, andere zur Decke rotieren.",
        "Wechsle die Hand am Boden, dann zurück.",
        "Seitenwechsel."
      ],
      tips: ["Kombiniert Hüftöffnung mit T-Spine-Rotation."],
      commonMistakes: ["Hüfte sinkt zur Seite ab."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Hip Flexor Stretch", primaryMuscle: "Hüftbeuger",
      equipment: "Körpergewicht", defaultSets: 2, defaultReps: 30, suggestedWeight: 0,
      category: .mobility, secondaryMuscles: [],
      instructions: [
        "Halber Kniestand, hinteres Knie am Boden.",
        "Hüfte nach vorn schieben.",
        "30 Sek halten."
      ],
      tips: ["Wichtig nach langen Sitzphasen."],
      commonMistakes: ["Hohlkreuz statt Hüftöffnung."],
      difficulty: .beginner
    ),
    ExerciseLibraryItem(
      name: "Wall Slides", primaryMuscle: "Schulter (Mobility)",
      equipment: "Körpergewicht", defaultSets: 2, defaultReps: 12, suggestedWeight: 0,
      category: .mobility, secondaryMuscles: [],
      instructions: [
        "Rücken an der Wand, Arme im 90°-Winkel.",
        "Schiebe die Arme entlang der Wand nach oben.",
        "Halte Kontakt — Schultern, Ellbogen, Handrücken an der Wand.",
        "Zurück in Startposition."
      ],
      tips: ["Aufwärmen vor Drücken-Übungen."],
      commonMistakes: ["Wandkontakt geht verloren."],
      difficulty: .beginner
    )
  ]
}
