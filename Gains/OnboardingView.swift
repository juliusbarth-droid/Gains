import SwiftUI

// MARK: - OnboardingView
//
// Fünf-Schritt-Onboarding für die TestFlight-Beta.
// Wird von `GainsApp` als FullScreenCover gezeigt, wenn
// `gains_hasCompletedOnboarding` noch false ist.
//
// Schritte:
//   1. Welcome   — Wertversprechen, was die App macht
//   2. Profil    — Name, Geschlecht, Alter, Größe, Gewicht, Aktivität → NutritionProfile
//   3. Berechtigungen — erklärt Health/Location/Bluetooth/Push, ohne System-Prompts
//   4. Training  — Ziel + Sessions/Woche → WorkoutPlannerSettings
//   5. Summary   — Wochen-Vorschau, „Setup geschafft"-Moment, erstes CTA
//
// Permissions werden hier nur erklärt; die echten System-Prompts triggern
// erst, wenn der Nutzer das Feature konkret aufruft (Lauf-Tracking,
// HF-Sensor-Suche, etc.).
//
// Aha-Moment-Architektur (2026-05-01 Phase 1): Der Summary-Step zeigt dem
// User auf einen Blick die Woche, die die App für ihn aufgebaut hat —
// damit das Onboarding nicht mit „leeren Händen" endet, sondern mit
// einem konkreten Plan. Der Finish-Schritt setzt zusätzlich
// `gains_onboardingCompletedAt`, damit der HomeView in den ersten 24h
// einen personalisierten Day-One-Coach-Brief zeigt.

enum OnboardingStep: Int, CaseIterable, Identifiable {
  case welcome
  case profile
  case permissions
  case training
  case summary

  var id: Int { rawValue }
  var index: Int { rawValue }
  var total: Int { OnboardingStep.allCases.count }
}

// Wahl im Onboarding-Trainingsschritt: Engine erzeugt den Plan automatisch
// oder der Nutzer baut die Wochenstruktur selbst zusammen.
enum OnboardingPlanMode: String {
  case automatic
  case manual
}

struct OnboardingView: View {
  @EnvironmentObject private var store: GainsStore
  @AppStorage(GainsKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
  // Day-One-Window: HomeView nutzt diese Timestamp, um in den ersten 24h
  // einen personalisierten Welcome-Coach-Brief zu zeigen. Wird im finish()
  // gesetzt — als Double (timeIntervalSince1970), weil @AppStorage Date
  // nicht nativ unterstützt.
  @AppStorage(GainsKey.onboardingCompletedAt) private var onboardingCompletedAt: Double = 0
  @State private var currentStep: OnboardingStep = .welcome

  // Profil-Felder
  @State private var name: String = ""
  @State private var sex: BiologicalSex = .male
  @State private var age: Int = 28
  @State private var heightCm: Int = 178
  @State private var weightKg: Int = 76
  @State private var activityLevel: ActivityLevel = .moderate

  // Trainings-Felder
  @State private var goal: WorkoutPlanningGoal = .muscleGain
  @State private var nutritionGoal: NutritionGoal = .muscleGain
  @State private var sessionsPerWeek: Int = 4
  @State private var planMode: OnboardingPlanMode = .automatic
  @State private var showsCustomPlanBuilder = false

  // Permissions-Status
  @State private var notificationsState: NotificationsPermissionState = .idle

  enum NotificationsPermissionState {
    case idle
    case granted
    case denied
  }

  var body: some View {
    ZStack {
      GainsAppBackground()

      VStack(spacing: 0) {
        progressBar
          .padding(.horizontal, 24)
          .padding(.top, 12)

        ScrollView(showsIndicators: false) {
          stepContent
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }

        bottomBar
          .padding(.horizontal, 24)
          .padding(.bottom, 16)
      }
    }
    .interactiveDismissDisabled()
  }

  // MARK: - Progress Bar

  private var progressBar: some View {
    HStack(spacing: 6) {
      ForEach(OnboardingStep.allCases) { step in
        Capsule()
          .fill(step.index <= currentStep.index ? GainsColor.lime : GainsColor.border.opacity(0.4))
          .frame(height: 4)
      }
    }
  }

  // MARK: - Step Content

  @ViewBuilder
  private var stepContent: some View {
    switch currentStep {
    case .welcome:     welcomeStep
    case .profile:     profileStep
    case .permissions: permissionsStep
    case .training:    trainingStep
    case .summary:     summaryStep
    }
  }

  // MARK: - Step 1: Welcome

  private var welcomeStep: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 12) {
        Text("WILLKOMMEN")
          .gainsEyebrow(GainsColor.lime, size: 13, tracking: 1.6)

        Text("Hi.\nSchön, dass du da bist.")
          .font(GainsFont.display(40))
          .foregroundStyle(GainsColor.ink)
          .lineSpacing(-2)
          .fixedSize(horizontal: false, vertical: true)

        Text("Gains begleitet deine Trainings, Läufe, Ernährung und deinen Fortschritt — alles in einer App, ohne Quatsch.")
          .font(GainsFont.body(16))
          .foregroundStyle(GainsColor.softInk)
          .lineSpacing(2)
          .fixedSize(horizontal: false, vertical: true)
      }

      VStack(spacing: 12) {
        featureRow(icon: "dumbbell.fill", title: "Krafttraining tracken",
                   description: "Eigene Pläne, vorgefertigte Templates, über 90 Übungen mit Anleitung.")
        featureRow(icon: "figure.run", title: "Läufe per GPS",
                   description: "Distanz, Pace, Splits, Höhenmeter — verbunden mit deinem HF-Gurt.")
        featureRow(icon: "fork.knife", title: "Ernährung loggen",
                   description: "Kalorien und Makros via Barcode, Suche oder Foto-Erkennung.")
        featureRow(icon: "heart.text.square.fill", title: "Fortschritt sehen",
                   description: "Volumen, Pace, Gewicht, Recovery — verständlich aufbereitet.")
      }
    }
  }

  private func featureRow(icon: String, title: String, description: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 38, height: 38)
        .background(Circle().fill(GainsColor.lime.opacity(0.12)))

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        Text(description)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  // MARK: - Step 2: Profile

  private var profileStep: some View {
    VStack(alignment: .leading, spacing: 24) {
      stepHeader(
        eyebrow: "PROFIL",
        title: "Erzähl uns von dir.",
        subtitle: "Wir berechnen daraus deinen Grundumsatz, Kalorien- und Proteinziele. Bleibt alles auf deinem Gerät."
      )

      // Name
      VStack(alignment: .leading, spacing: 8) {
        Text("DEIN NAME")
          .gainsEyebrow(size: 12, tracking: 1.4)
        TextField("Wie sollen wir dich nennen?", text: $name)
          .font(GainsFont.body(17))
          .foregroundStyle(GainsColor.ink)
          .padding(.horizontal, 14)
          .padding(.vertical, 14)
          .background(GainsColor.card)
          .overlay(
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
          )
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          .submitLabel(.next)
      }

      // Sex
      VStack(alignment: .leading, spacing: 8) {
        Text("GESCHLECHT")
          .gainsEyebrow(size: 12, tracking: 1.4)
        HStack(spacing: 10) {
          ForEach(BiologicalSex.allCases, id: \.self) { option in
            sexChip(option)
          }
        }
      }

      // Age / Height / Weight
      VStack(alignment: .leading, spacing: 12) {
        Text("KÖRPERDATEN")
          .gainsEyebrow(size: 12, tracking: 1.4)

        HStack(spacing: 10) {
          numberStepper(title: "ALTER", unit: "Jahre", value: $age, range: 14...90, step: 1)
          numberStepper(title: "GRÖSSE", unit: "cm", value: $heightCm, range: 130...220, step: 1)
          numberStepper(title: "GEWICHT", unit: "kg", value: $weightKg, range: 35...200, step: 1)
        }
      }

      // Activity Level
      VStack(alignment: .leading, spacing: 8) {
        Text("AKTIVITÄT")
          .gainsEyebrow(size: 12, tracking: 1.4)
        VStack(spacing: 8) {
          ForEach(ActivityLevel.allCases, id: \.self) { level in
            activityRow(level)
          }
        }
      }
    }
  }

  private func sexChip(_ option: BiologicalSex) -> some View {
    let isSelected = sex == option
    return Button {
      sex = option
    } label: {
      HStack(spacing: 8) {
        Text(option.emoji)
          .font(.system(size: 16))
        Text(option.title)
          .font(GainsFont.label(13))
          .tracking(0.4)
      }
      .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.ink)
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(isSelected ? GainsColor.lime : GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(isSelected ? Color.clear : GainsColor.border.opacity(0.5), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func numberStepper(title: String, unit: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(GainsFont.label(9))
        .tracking(1.3)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text("\(value.wrappedValue)")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
        Text(unit)
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
      }
      Stepper("", value: value, in: range, step: step)
        .labelsHidden()
        .tint(GainsColor.lime)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private func activityRow(_ level: ActivityLevel) -> some View {
    let isSelected = activityLevel == level
    return Button {
      activityLevel = level
    } label: {
      HStack(spacing: 14) {
        Image(systemName: level.systemImage)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.lime)
          .frame(width: 36, height: 36)
          .background(Circle().fill(isSelected ? GainsColor.lime : GainsColor.lime.opacity(0.12)))

        VStack(alignment: .leading, spacing: 2) {
          Text(level.title)
            .font(GainsFont.title(15))
            .foregroundStyle(GainsColor.ink)
          Text(level.detail)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }

        Spacer()

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.lime : GainsColor.border)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(
            isSelected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.4),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Step 3: Permissions

  private var permissionsStep: some View {
    VStack(alignment: .leading, spacing: 22) {
      stepHeader(
        eyebrow: "BERECHTIGUNGEN",
        title: "Was Gains braucht.",
        subtitle: "Nichts wird im Hintergrund gesammelt. Du gibst jede Berechtigung erst frei, wenn du das jeweilige Feature nutzen willst."
      )

      VStack(spacing: 10) {
        permissionCard(
          icon: "heart.fill",
          title: "Apple Health",
          reason: "Liest Schritte, Schlaf, Ruhepuls und Aktivität, damit deine Statistiken nicht doppelt erfasst werden müssen."
        )
        permissionCard(
          icon: "location.fill",
          title: "Standort",
          reason: "Brauchen wir nur während eines Laufs — für GPS-Route, Distanz und Höhenmeter."
        )
        permissionCard(
          icon: "antenna.radiowaves.left.and.right",
          title: "Bluetooth",
          reason: "Verbindet HF-Sensoren wie Polar oder Wahoo, um deine Live-Herzfrequenz beim Training zu zeigen."
        )
        notificationsPermissionCard
      }
    }
  }

  // Eigene Karte für Mitteilungen — die einzige Permission, für die es im
  // späteren Flow keinen natürlichen Trigger-Moment gibt (Standort wird beim
  // Lauf-Start gefragt, BLE beim Sensor-Pairing, Health beim ersten Sync).
  // Hier kann der Nutzer die Permission direkt aus dem Onboarding heraus
  // erteilen, ohne nachher die Settings durchsuchen zu müssen.
  private var notificationsPermissionCard: some View {
    Button {
      requestNotificationsAuthorization()
    } label: {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: "bell.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 40, height: 40)
          .background(Circle().fill(GainsColor.lime.opacity(0.14)))

        VStack(alignment: .leading, spacing: 4) {
          Text("Mitteilungen")
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
          Text(notificationsCardReason)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        notificationsCardTrailing
      }
      .padding(14)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(notificationsState != .idle)
  }

  private var notificationsCardReason: String {
    switch notificationsState {
    case .idle:
      return "Dezent — nur Workout-Reminder und Streak-Save am Abend. Tippe zum Aktivieren."
    case .granted:
      return "Aktiviert. Du kannst die Reminder jederzeit im Profil wieder ausschalten."
    case .denied:
      return "Abgelehnt. Du kannst sie später in den iOS-Einstellungen freigeben."
    }
  }

  @ViewBuilder
  private var notificationsCardTrailing: some View {
    switch notificationsState {
    case .idle:
      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)
    case .granted:
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
    case .denied:
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.orange)
    }
  }

  private func requestNotificationsAuthorization() {
    NotificationsManager.shared.requestAuthorization { granted in
      notificationsState = granted ? .granted : .denied
      if granted {
        NotificationsManager.shared.refreshSchedule(for: store)
      }
    }
  }

  private func permissionCard(icon: String, title: String, reason: String) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 40, height: 40)
        .background(Circle().fill(GainsColor.lime.opacity(0.14)))

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        Text(reason)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  // MARK: - Step 4: Training

  private var trainingStep: some View {
    VStack(alignment: .leading, spacing: 22) {
      stepHeader(
        eyebrow: "TRAINING",
        title: "Was willst du erreichen?",
        subtitle: "Wir passen Volumen, Frequenz und Empfehlungen an dein Ziel an. Du kannst es jederzeit ändern."
      )

      VStack(alignment: .leading, spacing: 10) {
        Text("HAUPTZIEL")
          .gainsEyebrow(size: 12, tracking: 1.4)
        VStack(spacing: 8) {
          goalRow(.muscleGain, nutrition: .muscleGain,
                  description: "Kalorienüberschuss, Volumen-Fokus, schwere Compound-Lifts.")
          goalRow(.fatLoss, nutrition: .fatLoss,
                  description: "Defizit mit Protein-Fokus, Kraft erhalten, mehr Cardio-Anteil.")
          goalRow(.performance, nutrition: .maintain,
                  description: "Kraftrekorde, Pace und Wiederholungen — Gewicht halten.")
        }
      }

      VStack(alignment: .leading, spacing: 10) {
        Text("TRAININGS PRO WOCHE")
          .gainsEyebrow(size: 12, tracking: 1.4)

        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("\(sessionsPerWeek)")
            .font(GainsFont.display(48))
            .foregroundStyle(GainsColor.ink)
          Text("× pro Woche")
            .font(GainsFont.body(15))
            .foregroundStyle(GainsColor.softInk)
        }

        HStack(spacing: 8) {
          ForEach(2...6, id: \.self) { count in
            Button {
              sessionsPerWeek = count
            } label: {
              Text("\(count)")
                .font(GainsFont.title(16))
                .foregroundStyle(sessionsPerWeek == count ? GainsColor.onLime : GainsColor.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(sessionsPerWeek == count ? GainsColor.lime : GainsColor.card)
                .overlay(
                  RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
                    .stroke(sessionsPerWeek == count ? Color.clear : GainsColor.border.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
      }

      // Plan-Modus: Auto vs. Selbst erstellen.
      // Wir bieten dem Nutzer hier explizit die Wahl, damit niemand erst
      // im PLAN-Tab erfahren muss, dass es eine manuelle Variante gibt.
      VStack(alignment: .leading, spacing: 10) {
        Text("WIE WILLST DU DEINEN PLAN?")
          .gainsEyebrow(size: 12, tracking: 1.4)

        VStack(spacing: 8) {
          planModeRow(
            mode: .automatic,
            title: "Auto-Plan",
            description: "Wir verteilen Trainings, Pausen und ggf. Läufe optimal auf die Woche — basierend auf Ziel und Frequenz."
          )
          planModeRow(
            mode: .manual,
            title: "Selbst erstellen",
            description: "Du wählst pro Wochentag selbst: Krafttraining, Lauf-Typ oder Frei. Volle Kontrolle, ohne Wizard."
          )
        }

        if planMode == .manual {
          Button {
            showsCustomPlanBuilder = true
          } label: {
            HStack(spacing: 8) {
              Image(systemName: store.plannerSettings.isManualPlan ? "checkmark.circle.fill" : "slider.horizontal.3")
                .font(.system(size: 13, weight: .bold))
              Text(store.plannerSettings.isManualPlan
                   ? "Plan bearbeiten"
                   : "Plan jetzt selbst zusammenstellen")
                .font(GainsFont.label(12))
                .tracking(1.2)
              Spacer(minLength: 0)
              Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.7)
            }
            .foregroundStyle(GainsColor.onLime)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          }
          .buttonStyle(.plain)

          if store.plannerSettings.isManualPlan {
            HStack(spacing: 8) {
              Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(GainsColor.lime)
              Text("Eigener Plan gespeichert · \(store.plannerSettings.manualSessionKinds.count) Trainingstage")
                .font(GainsFont.label(11))
                .foregroundStyle(GainsColor.softInk)
            }
          } else {
            Text("Du kannst es auch später im PLAN-Tab nachholen.")
              .font(GainsFont.body(11))
              .foregroundStyle(GainsColor.softInk)
          }
        }
      }
    }
    .sheet(isPresented: $showsCustomPlanBuilder) {
      CustomPlanBuilderSheet()
        .environmentObject(store)
    }
  }

  // MARK: - Step 5: Summary
  //
  // Aha-Moment-Bühne: Der User sieht hier zum ersten Mal seinen Plan
  // als konkrete Wochen-Übersicht. Ziel: das Onboarding endet nicht
  // mit „und was jetzt?", sondern mit „aha, das ist mein Plan und so
  // sieht meine Woche aus".
  //
  // Layout:
  //   1) Hero — „[Name], Plan steht." in Display-Font, Akzent-Glow.
  //   2) Setup-Checklist — 4 abgehakte Punkte (Profil, Permissions, Plan,
  //      Ernährungsziele) als visueller Endowed-Progress.
  //   3) Wochen-Vorschau — 7 Mini-Karten Mo–So mit Plan-Inhalt aus
  //      `store.weeklyWorkoutSchedule`. Heutiger Tag highlighted.
  //   4) Was kommt zuerst — konkrete Empfehlung des heutigen Schritts
  //      (oder, wenn heute Rest, der nächste Trainingstag).

  private var summaryStep: some View {
    VStack(alignment: .leading, spacing: 22) {
      summaryHero
      summaryChecklist
      summaryWeekPreview
      summaryFirstStep
    }
  }

  private var summaryHero: some View {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let displayName = trimmedName.isEmpty ? "" : ", \(trimmedName)"

    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "sparkles")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        Text("SETUP GESCHAFFT")
          .gainsEyebrow(GainsColor.lime, size: 13, tracking: 1.6)
      }

      Text("Plan steht\(displayName).")
        .font(GainsFont.display(34))
        .foregroundStyle(GainsColor.ink)
        .lineSpacing(-2)
        .fixedSize(horizontal: false, vertical: true)

      Text("Wir haben deine Woche aufgebaut. Schau drüber — du kannst alles im Plan-Tab nochmal anpassen.")
        .font(GainsFont.body(15))
        .foregroundStyle(GainsColor.softInk)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var summaryChecklist: some View {
    VStack(spacing: 0) {
      summaryCheckRow(icon: "person.fill", title: "Profil komplett",
                      detail: profileSummaryDetail)
      summaryCheckRow(icon: "shield.lefthalf.filled", title: "Berechtigungen erklärt",
                      detail: "Du gibst sie frei, wenn du das Feature nutzt.")
      summaryCheckRow(icon: "target", title: "Ziel & Frequenz",
                      detail: trainingSummaryDetail)
      summaryCheckRow(icon: "fork.knife", title: "Ernährungsziele berechnet",
                      detail: nutritionSummaryDetail, isLast: true)
    }
    .padding(14)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.border.opacity(0.4), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  private func summaryCheckRow(icon: String, title: String, detail: String, isLast: Bool = false) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        ZStack {
          Circle()
            .fill(GainsColor.lime.opacity(0.14))
            .frame(width: 32, height: 32)
          Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(GainsColor.lime)
        }
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Image(systemName: icon)
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(GainsColor.softInk)
            Text(title)
              .font(GainsFont.title(14))
              .foregroundStyle(GainsColor.ink)
          }
          Text(detail)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(2)
        }
        Spacer(minLength: 0)
      }
      .padding(.vertical, 8)

      if !isLast {
        Divider()
          .overlay(GainsColor.border.opacity(0.25))
      }
    }
  }

  private var profileSummaryDetail: String {
    "\(age) Jahre · \(heightCm) cm · \(weightKg) kg · \(activityLevel.title)"
  }

  private var trainingSummaryDetail: String {
    let goalLabel = goal.title
    return "\(goalLabel) · \(sessionsPerWeek)× pro Woche"
  }

  private var nutritionSummaryDetail: String {
    let kcal = store.nutritionTargetCalories
    let protein = store.nutritionTargetProtein
    if kcal > 0 {
      return "Tagesziel ~\(kcal) kcal · \(protein) g Protein"
    }
    return "Werte werden im Profil berechnet."
  }

  private var summaryWeekPreview: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("DEINE WOCHE")
        .gainsEyebrow(size: 12, tracking: 1.4)

      VStack(spacing: 8) {
        ForEach(store.weeklyWorkoutSchedule, id: \.weekday) { day in
          summaryWeekRow(day)
        }
      }
    }
  }

  private func summaryWeekRow(_ day: WorkoutDayPlan) -> some View {
    let accent: Color = {
      switch day.status {
      case .planned:  return day.runTemplate != nil ? GainsColor.ember : GainsColor.lime
      case .rest:     return GainsColor.softInk
      case .flexible: return GainsColor.accentCool
      }
    }()
    let icon: String = {
      if let _ = day.runTemplate { return "figure.run" }
      switch day.status {
      case .planned:  return "dumbbell.fill"
      case .rest:     return "leaf.fill"
      case .flexible: return "infinity"
      }
    }()
    let titleText: String = {
      switch day.status {
      case .planned:  return day.workoutPlan?.title ?? day.title
      case .rest:     return "Recovery"
      case .flexible: return "Flexibel"
      }
    }()

    return HStack(spacing: 12) {
      VStack(spacing: 2) {
        Text(day.weekday.shortLabel.uppercased())
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(day.isToday ? GainsColor.lime : GainsColor.softInk)
        Image(systemName: day.isToday ? "circle.fill" : "circle")
          .font(.system(size: 5, weight: .bold))
          .foregroundStyle(day.isToday ? GainsColor.lime : GainsColor.border.opacity(0.5))
      }
      .frame(width: 36)

      ZStack {
        Circle()
          .fill(accent.opacity(0.14))
        Image(systemName: icon)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(accent)
      }
      .frame(width: 32, height: 32)

      VStack(alignment: .leading, spacing: 2) {
        Text(titleText)
          .font(GainsFont.title(14))
          .foregroundStyle(GainsColor.ink)
        Text(day.focus)
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(1)
      }

      Spacer(minLength: 0)

      if day.isToday {
        Text("HEUTE")
          .font(GainsFont.label(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.onLime)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Capsule().fill(GainsColor.lime))
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      day.isToday ? GainsColor.lime.opacity(0.06) : GainsColor.card
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(
          day.isToday ? GainsColor.lime.opacity(0.45) : GainsColor.border.opacity(0.3),
          lineWidth: day.isToday ? 0.8 : 0.6
        )
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private var summaryFirstStep: some View {
    let today = store.todayPlannedDay
    let (eyebrow, headline, sub): (String, String, String) = {
      switch today.status {
      case .planned:
        if let run = today.runTemplate {
          return (
            "ALS NÄCHSTES",
            "Heute: \(run.title)",
            String(format: "%.1f km · ~%d min. Sobald du fertig bist, kannst du direkt im Lauf-Tab starten.",
                   run.targetDistanceKm, run.targetDurationMinutes)
          )
        }
        let title = today.workoutPlan?.title ?? today.title
        let count = today.workoutPlan?.exercises.count ?? 0
        return (
          "ALS NÄCHSTES",
          "Heute: \(title)",
          count > 0
            ? "\(count) Übungen im Plan. Du findest das Workout sofort auf deinem Home-Screen."
            : "Dein Coach-Brief auf dem Home-Screen führt dich Schritt für Schritt."
        )
      case .rest:
        return (
          "ALS ERSTES",
          "Heute ist Recovery-Tag",
          "Perfekt zum Reinkommen — log deine erste Mahlzeit oder einen Spaziergang. Morgen geht's los."
        )
      case .flexible:
        return (
          "ALS ERSTES",
          "Heute ist flexibel",
          "Wähl spontan: kurzes Workout, Lauf oder Mobility. Der Home-Screen schlägt dir was vor."
        )
      }
    }()

    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "arrow.forward.circle.fill")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(GainsColor.lime)
        Text(eyebrow)
          .gainsEyebrow(GainsColor.lime, size: 12, tracking: 1.4)
      }
      Text(headline)
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)
        .fixedSize(horizontal: false, vertical: true)
      Text(sub)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      LinearGradient(
        colors: [GainsColor.lime.opacity(0.08), GainsColor.card],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.32), lineWidth: GainsBorder.accent)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }

  // Card-artige Auswahl-Reihe für den Plan-Modus.
  private func planModeRow(
    mode: OnboardingPlanMode,
    title: String,
    description: String
  ) -> some View {
    let isSelected = planMode == mode
    return Button {
      withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
        planMode = mode
      }
    } label: {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: mode == .automatic ? "wand.and.stars" : "slider.horizontal.3")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.lime)
          .frame(width: 40, height: 40)
          .background(Circle().fill(isSelected ? GainsColor.lime : GainsColor.lime.opacity(0.14)))

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
          Text(description)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.lime : GainsColor.border)
      }
      .padding(14)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(
            isSelected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.4),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private func goalRow(_ planning: WorkoutPlanningGoal, nutrition: NutritionGoal, description: String) -> some View {
    let isSelected = goal == planning
    return Button {
      goal = planning
      nutritionGoal = nutrition
    } label: {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: nutrition.systemImage)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.lime)
          .frame(width: 40, height: 40)
          .background(Circle().fill(isSelected ? GainsColor.lime : GainsColor.lime.opacity(0.14)))

        VStack(alignment: .leading, spacing: 4) {
          Text(planning.title)
            .font(GainsFont.title(16))
            .foregroundStyle(GainsColor.ink)
          Text(description)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(isSelected ? GainsColor.lime : GainsColor.border)
      }
      .padding(14)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(
            isSelected ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.4),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Header Helper

  private func stepHeader(eyebrow: String, title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(eyebrow)
        .gainsEyebrow(GainsColor.lime, size: 13, tracking: 1.6)
      Text(title)
        .font(GainsFont.display(32))
        .foregroundStyle(GainsColor.ink)
        .lineSpacing(-2)
        .fixedSize(horizontal: false, vertical: true)
      Text(subtitle)
        .font(GainsFont.body(15))
        .foregroundStyle(GainsColor.softInk)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Bottom Bar

  private var bottomBar: some View {
    HStack(spacing: 12) {
      if currentStep != .welcome {
        Button {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
              currentStep = prev
            }
          }
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 56, height: 56)
            .background(GainsColor.card)
            .overlay(
              RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
                .stroke(GainsColor.border.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        }
        .buttonStyle(.plain)
      }

      Button {
        advance()
      } label: {
        HStack(spacing: 8) {
          Text(currentStep == .summary ? "Los geht's" : "Weiter")
            .font(GainsFont.label(13))
            .tracking(1.4)
          Image(systemName: currentStep == .summary ? "sparkles" : "arrow.right")
            .font(.system(size: 13, weight: .heavy))
        }
        .foregroundStyle(canAdvance ? GainsColor.onLime : GainsColor.ink.opacity(0.5))
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(canAdvance ? GainsColor.lime : GainsColor.card)
        .overlay(
          RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
            .stroke(canAdvance ? Color.clear : GainsColor.border.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(!canAdvance)
    }
  }

  private var canAdvance: Bool {
    switch currentStep {
    case .welcome:     return true
    case .profile:     return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    case .permissions: return true
    case .training:    return true
    case .summary:     return true
    }
  }

  private func advance() {
    // H5-Fix (2026-05-01): Wenn der Nutzer „Selbst erstellen" gewählt,
    // aber den Builder nie gespeichert hat, fällt der Mode hier still auf
    // „Auto-Plan" zurück. Sonst landet der User mit planMode=.manual und
    // !isManualPlan in einem inkonsistenten Zustand: UI sagt manuell,
    // App rendert aber Auto-Plan.
    if currentStep == .training,
       planMode == .manual,
       !store.plannerSettings.isManualPlan {
      planMode = .automatic
    }

    // Phase 1 Aha-Moment (2026-05-01): Wenn der User von .training nach
    // .summary geht, müssen wir die Plan-Settings BEREITS partial committen,
    // damit der Summary-Step die echte Wochen-Vorschau aus
    // `store.weeklyWorkoutSchedule` rendern kann. Das volle saveAll()
    // läuft erst im finish() — hier nur In-Memory-Update.
    if currentStep == .training {
      var settings = store.plannerSettings
      settings.goal = goal
      if !settings.isManualPlan {
        settings.sessionsPerWeek = sessionsPerWeek
      }
      store.plannerSettings = settings
    }

    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
      if currentStep == .summary {
        finish()
      } else if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
        currentStep = next
      }
    }
  }

  private func finish() {
    // Profil speichern
    let profile = NutritionProfile(
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      bodyFatPercent: nil,
      activityLevel: activityLevel,
      goal: nutritionGoal,
      surplusKcal: nutritionGoal == .muscleGain ? 250 : (nutritionGoal == .fatLoss ? -400 : 0)
    )
    store.setNutritionProfile(profile)

    // Name speichern
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedName.isEmpty {
      store.userName = trimmedName
    }

    // Trainings-Settings übernehmen.
    // Wenn der Nutzer im Onboarding einen manuellen Plan gespeichert hat,
    // hat `applyManualPlan(...)` `sessionsPerWeek` schon auf die tatsächliche
    // Anzahl Trainingstage gesetzt und `isManualPlan = true` markiert. Wir
    // wollen das hier NICHT mit der Onboarding-Frequenz überschreiben.
    var settings = store.plannerSettings
    settings.goal = goal
    if !settings.isManualPlan {
      settings.sessionsPerWeek = sessionsPerWeek
    }
    store.plannerSettings = settings

    // 2026-05-01: P0-5-Fix. Vorher: `saveAll()` (async) + `hasCompletedOnboarding=true`
    // (sync). Wenn der Tester die App im Sekundenbruchteil zwischen den beiden
    // Zeilen killt, war die AppStorage-Flag persistiert aber Profil/Settings
    // nicht — App startete dann mit leerem Profil und Default-Werten.
    // Jetzt: Flag erst setzen, wenn Save garantiert durch ist.
    //
    // Phase 1 Aha-Moment (2026-05-01): Zusätzlich `onboardingCompletedAt`
    // setzen, damit HomeView in den ersten 24h einen Welcome-Coach-Brief
    // statt des generischen „Bereit?"-Defaults zeigen kann.
    store.saveAll {
      onboardingCompletedAt = Date().timeIntervalSince1970
      hasCompletedOnboarding = true
    }
  }
}
