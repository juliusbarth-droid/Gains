import SwiftUI

// MARK: - GymPlanWizardSheet
//
// Aus dem alten GymView.swift extrahierter Wizard (9 Schritte). Polish vs.
// der vorherigen Version:
//   • `summaryMetricTile` ersetzt durch shared `GainsMetricTile.subdued`.
//   • Profil-Chips nutzen jetzt `GainsColor.elevated` konsistent.
//   • Navigation Buttons mit klarem Step-Counter im Header.

struct GymPlanWizardSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  // ── Wizard Navigation ─────────────────────────────────────────
  @State private var step        = 0
  @State private var goingForward = true

  // ── Wizard Inputs (pre-filled from current settings) ──────────
  @State private var trainingFocus:      WorkoutTrainingFocus
  @State private var goal:               WorkoutPlanningGoal
  @State private var experience:         TrainingExperience
  @State private var equipment:          GymEquipment
  @State private var sessionsPerWeek:    Int
  @State private var sessionLength:      Int
  @State private var recovery:           RecoveryCapacity
  @State private var prioritizedMuscles: Set<MuscleGroup>
  @State private var limitations:        Set<WorkoutLimitation>
  @State private var runningGoal:        RunningGoal

  // ── Step Config ────────────────────────────────────────────────
  private var includesRunStep: Bool { trainingFocus != .strength }
  private var totalSteps: Int      { includesRunStep ? 9 : 8 }
  private var isSummaryStep: Bool  { step == totalSteps }

  init(settings: WorkoutPlannerSettings) {
    _trainingFocus      = State(initialValue: settings.trainingFocus)
    _goal               = State(initialValue: settings.goal)
    _experience         = State(initialValue: settings.experience)
    _equipment          = State(initialValue: settings.equipment)
    _sessionsPerWeek    = State(initialValue: settings.sessionsPerWeek)
    _sessionLength      = State(initialValue: settings.preferredSessionLength)
    _recovery           = State(initialValue: settings.recoveryCapacity)
    _prioritizedMuscles = State(initialValue: settings.prioritizedMuscles)
    _limitations        = State(initialValue: settings.limitations)
    _runningGoal        = State(initialValue: settings.runningGoal)
  }

  // ── Body ───────────────────────────────────────────────────────
  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        VStack(spacing: 0) {
          progressBar
            .padding(.horizontal, GainsSpacing.xl)
            .padding(.top, GainsSpacing.s)
            .padding(.bottom, GainsSpacing.xsPlus)

          Text("Schritt \(min(step + 1, totalSteps + 1)) von \(totalSteps + 1)")
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.mutedInk)
            .padding(.bottom, GainsSpacing.l)

          ZStack {
            Group {
              switch step {
              case 0: focusStep
              case 1: goalStep
              case 2: experienceStep
              case 3: equipmentStep
              case 4: frequencyStep
              case 5: recoveryStep
              case 6: priorityStep
              case 7: limitationsStep
              case 8 where includesRunStep: runningStep
              default: summaryStep
              }
            }
            .transition(
              .asymmetric(
                insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
                removal:   .move(edge: goingForward ? .leading  : .trailing).combined(with: .opacity)
              )
            )
            .id(step)
          }
          .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
          .frame(maxWidth: .infinity, maxHeight: .infinity)

          navigationButtons
            .padding(.horizontal, GainsSpacing.xl)
            .padding(.top, GainsSpacing.m)
            .padding(.bottom, GainsSpacing.xl)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(stepTitle)
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .presentationDetents([.large])
  }

  // MARK: - Progress Bar

  private var progressBar: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(GainsColor.border.opacity(0.4)).frame(height: 4)
        Capsule()
          .fill(GainsColor.lime)
          .frame(width: geo.size.width * (Double(step + 1) / Double(totalSteps + 1)), height: 4)
          .animation(.spring(response: 0.4, dampingFraction: 0.8), value: step)
      }
    }
    .frame(height: 4)
  }

  private var stepTitle: String {
    switch step {
    case 0: return "Trainingsfokus"
    case 1: return "Ziel"
    case 2: return "Erfahrung"
    case 3: return "Equipment"
    case 4: return "Frequenz & Dauer"
    case 5: return "Erholung"
    case 6: return "Muskelprioritäten"
    case 7: return "Einschränkungen"
    case 8 where includesRunStep: return "Laufziel"
    default: return "Dein optimaler Plan"
    }
  }

  // MARK: - Step 0: Trainingsfokus

  private var focusStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Was ist dein Trainingsfokus?",
        subtitle: "Die Engine wählt Split, Volumen und Intensität passend zu deinem Schwerpunkt."
      )
      VStack(spacing: GainsSpacing.s) {
        ForEach(WorkoutTrainingFocus.allCases, id: \.self) { f in
          wizardChoiceRow(
            icon: focusIcon(f),
            title: f.title,
            subtitle: f.detail,
            isSelected: trainingFocus == f
          ) { withAnimation(.spring(response: 0.3)) { trainingFocus = f } }
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      Spacer()
    }
  }

  // MARK: - Step 1: Ziel

  private var goalStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Was ist dein Trainingsziel?",
        subtitle: "Bestimmt Wiederholungsbereich, RIR-Steuerung und Übungsauswahl."
      )
      VStack(spacing: GainsSpacing.s) {
        ForEach(WorkoutPlanningGoal.allCases, id: \.self) { g in
          wizardChoiceRow(
            icon: goalIcon(g),
            title: g.title,
            subtitle: goalDetail(g),
            isSelected: goal == g
          ) { withAnimation(.spring(response: 0.3)) { goal = g } }
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      Spacer()
    }
  }

  // MARK: - Step 2: Erfahrung

  private var experienceStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Wie ist dein Trainingsalter?",
        subtitle: "Beeinflusst Split-Komplexität, Volumen und Intensitätssteuerung."
      )
      VStack(spacing: GainsSpacing.s) {
        ForEach(TrainingExperience.allCases, id: \.self) { exp in
          wizardChoiceRow(
            icon: experienceIcon(exp),
            title: exp.title,
            subtitle: exp.detail,
            isSelected: experience == exp
          ) { withAnimation(.spring(response: 0.3)) { experience = exp } }
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      Spacer()
    }
  }

  // MARK: - Step 3: Equipment

  private var equipmentStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Was steht dir zur Verfügung?",
        subtitle: "Limitiert den Übungspool und die empfohlenen Splits."
      )
      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: GainsSpacing.s), GridItem(.flexible(), spacing: GainsSpacing.s)],
        spacing: GainsSpacing.s
      ) {
        ForEach(GymEquipment.allCases, id: \.self) { equip in
          wizardGridCard(
            title: equip.title,
            subtitle: equip.detail,
            icon: equipmentIcon(equip),
            isSelected: equipment == equip
          ) { withAnimation(.spring(response: 0.3)) { equipment = equip } }
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      Spacer()
    }
  }

  // MARK: - Step 4: Frequenz + Sessiondauer

  private var frequencyStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Wie oft und wie lange trainierst du?",
        subtitle: "Tage werden automatisch optimal auf die Woche verteilt – du musst nichts zuweisen."
      )

      VStack(spacing: GainsSpacing.m) {
        Text("TRAININGSTAGE PRO WOCHE")
          .font(GainsFont.label(9))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, GainsSpacing.xl)

        Text("\(sessionsPerWeek)")
          .font(.system(size: 64, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.lime)
          .contentTransition(.numericText())
          .animation(.spring(response: 0.3), value: sessionsPerWeek)

        HStack(spacing: GainsSpacing.s) {
          ForEach(2...6, id: \.self) { n in
            Button {
              withAnimation(.spring(response: 0.3)) { sessionsPerWeek = n }
            } label: {
              Text("\(n)")
                .font(GainsFont.label(15))
                .foregroundStyle(sessionsPerWeek == n ? GainsColor.onLime : GainsColor.ink)
                .frame(width: 48, height: 48)
                .background(sessionsPerWeek == n ? GainsColor.lime : GainsColor.card)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
          }
        }
      }

      VStack(spacing: GainsSpacing.m) {
        Text("DAUER PRO EINHEIT")
          .font(GainsFont.label(9))
          .tracking(1.6)
          .foregroundStyle(GainsColor.softInk)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, GainsSpacing.xl)

        HStack(spacing: GainsSpacing.xsPlus) {
          ForEach([30, 45, 60, 75, 90], id: \.self) { min in
            Button {
              withAnimation(.spring(response: 0.3)) { sessionLength = min }
            } label: {
              VStack(spacing: GainsSpacing.xxs) {
                Text("\(min)")
                  .font(GainsFont.title(20))
                  .foregroundStyle(sessionLength == min ? GainsColor.onLime : GainsColor.ink)
                Text("min")
                  .font(GainsFont.label(9))
                  .tracking(1.0)
                  .foregroundStyle(sessionLength == min ? GainsColor.onLime.opacity(0.8) : GainsColor.softInk)
              }
              .frame(maxWidth: .infinity)
              .frame(height: 62)
              .background(sessionLength == min ? GainsColor.lime : GainsColor.card)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, GainsSpacing.xl)
      }

      Spacer()
    }
  }

  // MARK: - Step 5: Recovery

  private var recoveryStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Wie erholst du dich aktuell?",
        subtitle: "Fließt als Volumen-Modifier ein. Ehrlichkeit schützt vor Übertraining."
      )
      VStack(spacing: GainsSpacing.s) {
        ForEach(RecoveryCapacity.allCases, id: \.self) { cap in
          wizardChoiceRow(
            icon: recoveryIcon(cap),
            title: cap.title,
            subtitle: cap.detail,
            isSelected: recovery == cap
          ) { withAnimation(.spring(response: 0.3)) { recovery = cap } }
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      Spacer()
    }
  }

  // MARK: - Step 6: Muskel-Priorität

  private var priorityStep: some View {
    VStack(spacing: GainsSpacing.l) {
      wizardHeader(
        title: "Welche Muskeln sollen mehr bekommen?",
        subtitle: "Optional · 0–2 Schwerpunkte · Priorisierte Muskeln erhalten +30 % Sätze pro Woche."
      )

      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: GainsSpacing.tight),
          GridItem(.flexible(), spacing: GainsSpacing.tight),
          GridItem(.flexible(), spacing: GainsSpacing.tight)
        ],
        spacing: GainsSpacing.tight
      ) {
        ForEach(MuscleGroup.allCases) { muscle in
          let selected = prioritizedMuscles.contains(muscle)
          Button {
            withAnimation(.spring(response: 0.25)) {
              if selected { prioritizedMuscles.remove(muscle) }
              else         { prioritizedMuscles.insert(muscle) }
            }
          } label: {
            VStack(spacing: GainsSpacing.xs) {
              Text(muscleIcon(muscle))
                .font(.system(size: 28))
              Text(muscle.title)
                .font(GainsFont.label(11))
                .tracking(1.0)
                .foregroundStyle(selected ? GainsColor.onLime : GainsColor.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(selected ? GainsColor.lime : GainsColor.card)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, GainsSpacing.xl)

      Text("Überspringen möglich – tippe auf \"Weiter\"")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.mutedInk)

      Spacer()
    }
  }

  // MARK: - Step 7: Einschränkungen

  private var limitationsStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Hast du Einschränkungen?",
        subtitle: "Problematische Übungen werden automatisch durch gelenkschonende Alternativen ersetzt."
      )

      VStack(spacing: GainsSpacing.tight) {
        ForEach(WorkoutLimitation.allCases) { limit in
          let selected = limitations.contains(limit)
          Button {
            withAnimation(.spring(response: 0.25)) {
              if selected { limitations.remove(limit) }
              else         { limitations.insert(limit) }
            }
          } label: {
            HStack(spacing: GainsSpacing.m) {
              Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(selected ? GainsColor.lime : GainsColor.softInk)
              VStack(alignment: .leading, spacing: 3) {
                Text(limit.title)
                  .font(GainsFont.label(15))
                  .foregroundStyle(GainsColor.ink)
                Text(limit.hint)
                  .font(GainsFont.label(11))
                  .foregroundStyle(GainsColor.softInk)
                  .lineLimit(2)
              }
              Spacer()
            }
            .padding(GainsSpacing.m)
            .background(selected ? GainsColor.lime.opacity(0.06) : GainsColor.card)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
                .stroke(
                  selected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.5),
                  lineWidth: 1.2
                )
            )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, GainsSpacing.xl)

      Text("Überspringen möglich – tippe auf \"Weiter\"")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.mutedInk)

      Spacer()
    }
  }

  // MARK: - Step 8 (conditional): Laufziel

  private var runningStep: some View {
    VStack(spacing: GainsSpacing.xl) {
      wizardHeader(
        title: "Was ist dein Laufziel?",
        subtitle: "Bestimmt empfohlene Wochenkilometer und die Intensitätsverteilung im Plan."
      )
      VStack(spacing: GainsSpacing.s) {
        ForEach(RunningGoal.allCases, id: \.self) { rg in
          wizardChoiceRow(
            icon: runningGoalIcon(rg),
            title: rg.title,
            subtitle: runningGoalDetail(rg),
            isSelected: runningGoal == rg
          ) { withAnimation(.spring(response: 0.3)) { runningGoal = rg } }
        }
      }
      .padding(.horizontal, GainsSpacing.xl)
      Spacer()
    }
  }

  // MARK: - Summary Step

  private var summaryStep: some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: GainsSpacing.m) {
        wizardHeader(
          title: "Dein optimaler Plan",
          subtitle: "Die Engine hat deinen Plan auf Basis aktueller Sportwissenschaft berechnet."
        )

        VStack(spacing: GainsSpacing.m) {
          summaryRow(icon: "rectangle.split.3x1",   label: "Split",         value: autoSplitName)
          Divider().background(GainsColor.border)
          summaryRow(icon: "calendar",              label: "Trainingstage", value: "\(sessionsPerWeek)× pro Woche")
          Divider().background(GainsColor.border)
          summaryRow(icon: "clock",                 label: "Session-Dauer", value: "\(sessionLength) Min")
          Divider().background(GainsColor.border)
          summaryRow(icon: "target",                label: "Fokus",         value: "\(trainingFocus.title) · \(goal.title)")
        }
        .padding(GainsSpacing.l)
        .gainsCardStyle(GainsColor.card)
        .padding(.horizontal, GainsSpacing.xl)

        weeklyOverviewCard

        VStack(alignment: .leading, spacing: 0) {
          Text("WISSENSCHAFTLICHE PARAMETER")
            .font(GainsFont.label(9))
            .tracking(1.6)
            .foregroundStyle(GainsColor.softInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, GainsSpacing.l)
            .padding(.top, GainsSpacing.m)
            .padding(.bottom, GainsSpacing.s)

          LazyVGrid(
            columns: [GridItem(.flexible(), spacing: GainsSpacing.tight), GridItem(.flexible(), spacing: GainsSpacing.tight)],
            spacing: GainsSpacing.tight
          ) {
            GainsMetricTile(
              label: "VOLUMEN",
              value: "\(autoSetsRange.lowerBound)–\(autoSetsRange.upperBound)",
              unit: "Sätze / Muskel × Wo.",
              style: .subdued
            )
            GainsMetricTile(
              label: "FREQUENZ",
              value: "\(autoFrequency)×",
              unit: "pro Muskelgruppe",
              style: .subdued
            )
            GainsMetricTile(
              label: "REPS / RIR",
              value: "\(autoRepRange.lowerBound)–\(autoRepRange.upperBound)",
              unit: "RIR \(autoRIRRange.lowerBound)–\(autoRIRRange.upperBound)",
              style: .subdued
            )
            GainsMetricTile(
              label: "PAUSEN",
              value: "\(autoRestCompound)s",
              unit: "Compound · \(autoRestIsolation)s Isolation",
              style: .subdued
            )
          }
          .padding(.horizontal, GainsSpacing.m)
          .padding(.bottom, GainsSpacing.m)
        }
        .gainsCardStyle(GainsColor.card)
        .padding(.horizontal, GainsSpacing.xl)

        if includesRunStep {
          VStack(spacing: GainsSpacing.s) {
            summaryRow(icon: "figure.run",  label: "Laufziel",    value: runningGoal.title)
            Divider().background(GainsColor.border)
            summaryRow(icon: "road.lanes",  label: "Empfohlen",   value: "\(runningGoal.defaultWeeklyKilometers) km / Woche")
          }
          .padding(GainsSpacing.l)
          .gainsCardStyle(GainsColor.card)
          .padding(.horizontal, GainsSpacing.xl)
        }

        VStack(spacing: GainsSpacing.xsPlus) {
          profileChip("\(experience.title) · \(equipment.title)")
          profileChip(recovery.title + " Recovery")
          if !prioritizedMuscles.isEmpty {
            profileChip("Priorität: \(prioritizedMuscles.map(\.title).sorted().joined(separator: ", "))")
          }
          if !limitations.isEmpty {
            profileChip("Einschr.: \(limitations.map(\.title).sorted().joined(separator: ", "))")
          }
        }
        .padding(.horizontal, GainsSpacing.xl)

        Text("Quellen: Schoenfeld 2017, Helms 2018, Grgic 2018 · Wochentage werden automatisch verteilt")
          .font(.system(size: 10))
          .foregroundStyle(GainsColor.mutedInk)
          .multilineTextAlignment(.center)
          .padding(.horizontal, GainsSpacing.xl)

        Spacer(minLength: 8)
      }
    }
  }

  // MARK: - Auto-Berechnungen

  private var autoSplitName: String {
    let light = equipment == .bodyweight || equipment == .dumbbellsOnly
    switch sessionsPerWeek {
    case ...1: return "Ganzkörper"
    case 2:    return light ? "Ganzkörper × 2"     : "Upper / Lower"
    case 3:
      if experience == .beginner || light { return "Ganzkörper × 3" }
      return "Push / Pull / Legs"
    case 4: return light ? "Ganzkörper × 4" : "Upper / Lower × 2"
    case 5:
      if experience == .advanced && !light { return "PPL + Upper / Lower" }
      return "Upper / Lower + Ganzkörper"
    case 6: return "Push / Pull / Legs × 2"
    default: return "High-Frequency"
    }
  }

  private var autoSetsRange: ClosedRange<Int> {
    let base: ClosedRange<Int>
    switch experience {
    case .beginner:     base = 8...12
    case .intermediate: base = 12...18
    case .advanced:     base = 16...22
    }
    let m = recovery.volumeMultiplier
    let lo = max(6,       Int(round(Double(base.lowerBound) * m)))
    let hi = max(lo + 2,  Int(round(Double(base.upperBound) * m)))
    return lo...hi
  }

  private var autoFrequency: Int { experience == .advanced ? 3 : 2 }

  private var autoRepRange: ClosedRange<Int> {
    switch goal {
    case .muscleGain:  return experience == .beginner ? 8...12 : 6...12
    case .fatLoss:     return 8...15
    case .performance: return experience == .beginner ? 5...8  : 3...6
    }
  }

  private var autoRIRRange: ClosedRange<Int> {
    switch goal {
    case .muscleGain:  return experience == .advanced ? 0...2 : 1...3
    case .fatLoss:     return 1...2
    case .performance: return 0...2
    }
  }

  private var autoRestCompound: Int {
    switch goal {
    case .muscleGain:  return 150
    case .fatLoss:     return 90
    case .performance: return 240
    }
  }

  private var autoRestIsolation: Int {
    switch goal {
    case .muscleGain:  return 90
    case .fatLoss:     return 60
    case .performance: return 120
    }
  }

  // MARK: - Navigation Buttons

  private var navigationButtons: some View {
    HStack(spacing: GainsSpacing.s) {
      if step > 0 {
        Button {
          goingForward = false
          withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step -= 1 }
        } label: {
          HStack(spacing: GainsSpacing.xs) {
            Image(systemName: "chevron.left")
            Text("Zurück")
          }
          .font(GainsFont.label(15))
          .foregroundStyle(GainsColor.softInk)
          .frame(height: 54)
          .frame(maxWidth: .infinity)
          .background(GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        }
        .buttonStyle(.plain)
      }

      Button {
        if isSummaryStep {
          applySettings()
          dismiss()
        } else {
          goingForward = true
          withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step += 1 }
        }
      } label: {
        HStack(spacing: GainsSpacing.xs) {
          Text(isSummaryStep ? "Plan übernehmen" : "Weiter")
          Image(systemName: isSummaryStep ? "checkmark" : "chevron.right")
        }
        .font(GainsFont.label(15))
        .foregroundStyle(GainsColor.onLime)
        .frame(height: 54)
        .frame(maxWidth: .infinity)
        .background(GainsColor.lime)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Apply Settings

  private func applySettings() {
    store.applyWizardSettings(
      focus:              trainingFocus,
      goal:               goal,
      experience:         experience,
      equipment:          equipment,
      sessionsPerWeek:    sessionsPerWeek,
      sessionLength:      sessionLength,
      recovery:           recovery,
      prioritizedMuscles: prioritizedMuscles,
      limitations:        limitations,
      runningGoal:        runningGoal
    )
  }

  // MARK: - Reusable View Helpers

  private func wizardHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text(title)
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
      Text(subtitle)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, GainsSpacing.xl)
  }

  private func wizardChoiceRow(
    icon: String,
    title: String,
    subtitle: String,
    isSelected: Bool,
    onTap: @escaping () -> Void
  ) -> some View {
    Button(action: onTap) {
      HStack(spacing: GainsSpacing.m) {
        Text(icon)
          .font(.system(size: 22))
          .frame(width: 44, height: 44)
          .background(isSelected ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
          Text(subtitle)
            .font(GainsFont.label(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(GainsColor.lime)
        }
      }
      .padding(GainsSpacing.m)
      .background(isSelected ? GainsColor.lime.opacity(0.06) : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(
            isSelected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.5),
            lineWidth: 1.2
          )
      )
    }
    .buttonStyle(.plain)
  }

  private func wizardGridCard(
    title: String,
    subtitle: String,
    icon: String,
    isSelected: Bool,
    onTap: @escaping () -> Void
  ) -> some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
        Text(icon)
          .font(.system(size: 28))
        Text(title)
          .font(GainsFont.title(15))
          .foregroundStyle(GainsColor.ink)
        Text(subtitle)
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)
      }
      .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
      .padding(GainsSpacing.m)
      .background(isSelected ? GainsColor.lime.opacity(0.18) : GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(isSelected ? GainsColor.lime.opacity(0.55) : Color.clear, lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var weeklyOverviewCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Text("WOCHE IM ÜBERBLICK")
        .font(GainsFont.label(9))
        .tracking(1.6)
        .foregroundStyle(GainsColor.softInk)

      LazyVGrid(
        columns: [
          GridItem(.flexible(), spacing: GainsSpacing.xsPlus),
          GridItem(.flexible(), spacing: GainsSpacing.xsPlus)
        ],
        spacing: GainsSpacing.xsPlus
      ) {
        overviewStatChip(title: "TRAINING", value: "\(previewScheduledDays.count)")
        overviewStatChip(title: "FREI", value: "\(max(7 - previewScheduledDays.count, 0))")
        if previewRunDaysCount > 0 {
          overviewStatChip(title: "RUN", value: "\(previewRunDaysCount)")
        }
        if previewStrengthDaysCount > 0 {
          overviewStatChip(title: "KRAFT", value: "\(previewStrengthDaysCount)")
        }
      }

      VStack(spacing: GainsSpacing.xsPlus) {
        ForEach(Weekday.allCases) { day in
          weeklyOverviewRow(day)
        }
      }
    }
    .padding(GainsSpacing.l)
    .gainsCardStyle(GainsColor.card)
    .padding(.horizontal, GainsSpacing.xl)
  }

  private func overviewStatChip(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(GainsFont.label(8))
        .tracking(1.2)
        .foregroundStyle(GainsColor.softInk)
      Text(value)
        .font(GainsFont.title(14))
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, GainsSpacing.s)
    .padding(.vertical, GainsSpacing.xsPlus)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private var previewRunDaysCount: Int {
    previewSessionKinds.values.filter(\.isRun).count
  }

  private var previewStrengthDaysCount: Int {
    previewSessionKinds.values.filter { !$0.isRun }.count
  }

  private func weeklyOverviewRow(_ day: Weekday) -> some View {
    let kind = previewSessionKinds[day]
    let isPlanned = kind != nil

    return HStack(spacing: GainsSpacing.s) {
      Text(day.shortLabel)
        .font(GainsFont.label(10))
        .tracking(1.4)
        .foregroundStyle(isPlanned ? GainsColor.ink : GainsColor.softInk)
        .frame(width: 28, alignment: .leading)

      ZStack {
        Circle()
          .fill(previewAccent(for: kind).opacity(isPlanned ? 0.18 : 0.10))
          .frame(width: 24, height: 24)

        Image(systemName: previewIcon(for: kind))
          .font(.system(size: 10, weight: .bold))
          .foregroundStyle(isPlanned ? previewAccent(for: kind) : GainsColor.softInk)
      }

      VStack(alignment: .leading, spacing: 1) {
        Text(previewTitle(for: kind))
          .font(GainsFont.body(13))
          .foregroundStyle(isPlanned ? GainsColor.ink : GainsColor.softInk)
        if isPlanned {
          Text(previewMeta(for: kind))
            .font(GainsFont.label(9))
            .tracking(1.0)
            .foregroundStyle(GainsColor.softInk)
        }
      }

      Spacer()
    }
    .padding(.horizontal, GainsSpacing.s)
    .padding(.vertical, GainsSpacing.xsPlus)
    .background(GainsColor.elevated)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private var previewScheduledDays: [Weekday] {
    switch sessionsPerWeek {
    case ...0:
      return []
    case 1:
      return [.wednesday]
    case 2:
      return [.tuesday, .friday]
    case 3:
      return [.monday, .wednesday, .friday]
    case 4:
      return [.monday, .tuesday, .thursday, .saturday]
    case 5:
      return [.monday, .tuesday, .thursday, .friday, .sunday]
    case 6:
      return [.monday, .tuesday, .wednesday, .friday, .saturday, .sunday]
    default:
      return Weekday.allCases
    }
  }

  private var previewSessionKinds: [Weekday: PlannedSessionKind] {
    let days = previewScheduledDays
    guard !days.isEmpty else { return [:] }

    var result: [Weekday: PlannedSessionKind] = [:]

    switch trainingFocus {
    case .strength:
      for day in days { result[day] = .strength }
    case .cardio:
      let kinds = previewRunSessionKinds(for: days.count)
      for (index, day) in days.enumerated() {
        result[day] = index < kinds.count ? kinds[index] : .easyRun
      }
    case .hybrid:
      let strengthCount: Int = {
        switch days.count {
        case ...1: return 1
        case 2: return 1
        case 3: return 2
        case 4: return 2
        case 5: return 3
        case 6: return 4
        default: return max(days.count - 2, 0)
        }
      }()
      let runKinds = previewRunSessionKinds(for: max(days.count - strengthCount, 0))
      for (index, day) in days.enumerated() {
        if index < strengthCount {
          result[day] = .strength
        } else {
          let runIndex = index - strengthCount
          result[day] = runIndex < runKinds.count ? runKinds[runIndex] : .easyRun
        }
      }
    }

    return result
  }

  private func previewRunSessionKinds(for count: Int) -> [PlannedSessionKind] {
    switch count {
    case ...0:
      return []
    case 1:
      return [.longRun]
    case 2:
      return [.easyRun, .longRun]
    case 3:
      return [.easyRun, .tempoRun, .longRun]
    case 4:
      return [.easyRun, .tempoRun, .intervalRun, .longRun]
    default:
      return [.easyRun, .tempoRun, .recoveryRun, .intervalRun, .longRun]
    }
  }

  private func previewTitle(for kind: PlannedSessionKind?) -> String {
    guard let kind else { return "Frei / Puffer" }
    switch kind {
    case .strength:
      return "Krafttraining"
    default:
      return kind.title
    }
  }

  private func previewMeta(for kind: PlannedSessionKind?) -> String {
    guard let kind else { return "" }
    switch kind {
    case .strength:
      return autoSplitName
    default:
      return "ca. \(sessionLength) Min"
    }
  }

  private func previewAccent(for kind: PlannedSessionKind?) -> Color {
    guard let kind else { return GainsColor.softInk.opacity(0.35) }
    return kind.isRun ? GainsColor.moss : GainsColor.lime
  }

  private func previewIcon(for kind: PlannedSessionKind?) -> String {
    guard let kind else { return "moon.zzz.fill" }
    switch kind {
    case .strength:
      return "dumbbell.fill"
    case .easyRun, .tempoRun, .intervalRun, .longRun, .recoveryRun:
      return "figure.run"
    case .mobility:
      return "figure.cooldown"
    }
  }

  private func summaryRow(icon: String, label: String, value: String) -> some View {
    HStack {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.moss)
        .frame(width: 22)
      Text(label)
        .font(GainsFont.label(13))
        .foregroundStyle(GainsColor.softInk)
      Spacer()
      Text(value)
        .font(.system(size: 14, weight: .semibold, design: .rounded))
        .foregroundStyle(GainsColor.ink)
    }
  }

  private func profileChip(_ text: String) -> some View {
    Text(text)
      .font(GainsFont.label(12))
      .foregroundStyle(GainsColor.softInk)
      .padding(.horizontal, GainsSpacing.m)
      .padding(.vertical, GainsSpacing.xsPlus)
      .background(GainsColor.elevated)
      .clipShape(Capsule())
  }

  // MARK: - Icon Helpers

  private func focusIcon(_ f: WorkoutTrainingFocus) -> String {
    switch f {
    case .strength: return "🏋️"
    case .cardio:   return "🏃"
    case .hybrid:   return "⚡️"
    }
  }

  private func goalIcon(_ g: WorkoutPlanningGoal) -> String {
    switch g {
    case .muscleGain:  return "💪"
    case .fatLoss:     return "🔥"
    case .performance: return "🎯"
    }
  }

  private func goalDetail(_ g: WorkoutPlanningGoal) -> String {
    switch g {
    case .muscleGain:  return "Muskelaufbau · Hypertrophie-Reps, moderates Volumen."
    case .fatLoss:     return "Fettabbau · Höhere Reps, kürzere Pausen, mehr Ausdauer."
    case .performance: return "Kraft & Leistung · Niedrige Reps, lange Pausen, maximale Last."
    }
  }

  private func experienceIcon(_ exp: TrainingExperience) -> String {
    switch exp {
    case .beginner:     return "🌱"
    case .intermediate: return "💫"
    case .advanced:     return "🔱"
    }
  }

  private func equipmentIcon(_ equip: GymEquipment) -> String {
    switch equip {
    case .fullGym:        return "🏟️"
    case .homeGymBarbell: return "🏠"
    case .dumbbellsOnly:  return "🏋️"
    case .bodyweight:     return "🤸"
    }
  }

  private func recoveryIcon(_ cap: RecoveryCapacity) -> String {
    switch cap {
    case .low:    return "😴"
    case .medium: return "😊"
    case .high:   return "⚡️"
    }
  }

  private func muscleIcon(_ muscle: MuscleGroup) -> String {
    switch muscle {
    case .chest:     return "🫁"
    case .back:      return "🔙"
    case .shoulders: return "🎽"
    case .arms:      return "💪"
    case .legs:      return "🦵"
    case .core:      return "🎯"
    }
  }

  private func runningGoalIcon(_ rg: RunningGoal) -> String {
    switch rg {
    case .general:      return "🏃"
    case .fiveK:        return "5️⃣"
    case .tenK:         return "🔟"
    case .halfMarathon: return "🥈"
    case .marathon:     return "🏅"
    }
  }

  private func runningGoalDetail(_ rg: RunningGoal) -> String {
    "\(rg.title) · ~\(rg.defaultWeeklyKilometers) km/Woche empfohlen"
  }
}
