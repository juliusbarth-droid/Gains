import SwiftUI

// MARK: - CustomPlanBuilderSheet
//
// Manueller Plan-Editor als Alternative zum 9-Schritte-Wizard. Pro Wochentag
// entscheidet der Nutzer selbst:
//   • Krafttraining → optional ein konkretes Workout aus der Bibliothek
//   • Lauf         → mit Lauf-Typ (Easy / Tempo / Intervalle / Long / Recovery)
//   • Frei         → Ruhetag
//
// Beim Speichern landet das Ganze über `applyManualPlan(...)` im Store. Die
// Engine respektiert die manuelle Map und überspringt ihre Auto-Verteilung,
// solange `isManualPlan == true`.

struct CustomPlanBuilderSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  /// Lokaler Eintrag pro Wochentag — `nil` heißt Frei.
  private struct DayDraft: Equatable {
    var kind: PlannedSessionKind
    var workoutPlanID: UUID?
  }

  @State private var drafts: [Weekday: DayDraft] = [:]
  @State private var showsClearConfirmation = false

  /// Onboarding möchte nach dem Speichern den Plan-Builder schließen UND
  /// das Onboarding selbst beenden. Der Callback erlaubt dem Caller, beim
  /// Speichern eine eigene Aktion (z.B. `finish()`) auszulösen.
  var onSaved: (() -> Void)? = nil

  // MARK: - Body

  var body: some View {
    NavigationStack {
      ZStack {
        GainsColor.background.ignoresSafeArea()

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: GainsSpacing.xl) {
            intro
            weeklyGrid
            summaryCard
            Color.clear.frame(height: 80) // Platz für Sticky-Bar
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.s)
        }

        VStack {
          Spacer()
          stickyActionBar
            .padding(.horizontal, GainsSpacing.l)
            .padding(.bottom, GainsSpacing.l)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("Eigener Wochenplan")
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.ink)
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(GainsColor.softInk)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button {
              applyMondayFridayPreset()
            } label: {
              Label("Mo–Fr Krafttraining", systemImage: "calendar")
            }
            Button {
              applyHybridPreset()
            } label: {
              Label("3× Kraft + 2× Lauf", systemImage: "arrow.triangle.branch")
            }
            Button {
              applyRunOnlyPreset()
            } label: {
              Label("4× Lauf-Woche", systemImage: "figure.run")
            }
            Divider()
            Button(role: .destructive) {
              showsClearConfirmation = true
            } label: {
              Label("Alles zurücksetzen", systemImage: "arrow.counterclockwise")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
              .foregroundStyle(GainsColor.softInk)
          }
        }
      }
      .onAppear { loadInitialDrafts() }
      .alert("Wochenplan zurücksetzen?", isPresented: $showsClearConfirmation) {
        Button("Abbrechen", role: .cancel) {}
        Button("Zurücksetzen", role: .destructive) {
          withAnimation(.spring(response: 0.3)) { drafts = [:] }
        }
      } message: {
        Text("Alle Einträge werden gelöscht. Du kannst danach wieder von vorn beginnen.")
      }
    }
    .presentationDetents([.large])
  }

  // MARK: - Intro

  private var intro: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      SlashLabel(
        parts: ["EIGENER", "WOCHENPLAN"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )
      Text("Du planst die Woche selbst")
        .font(GainsFont.title(24))
        .foregroundStyle(GainsColor.ink)
      Text("Tippe je Tag auf eine Option: Krafttraining (mit Workout), Lauf (mit Lauf-Typ) oder Frei. Speichern übernimmt den Plan und ersetzt die automatische Verteilung der Engine.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  // MARK: - Wochengrid

  private var weeklyGrid: some View {
    VStack(spacing: GainsSpacing.tight) {
      ForEach(Weekday.allCases) { day in
        weekdayCard(for: day)
      }
    }
  }

  @ViewBuilder
  private func weekdayCard(for day: Weekday) -> some View {
    let draft = drafts[day]
    let isToday = day == .today

    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      // Header: Wochentag + Heute-Marker + Quick-Toggle Frei
      HStack(spacing: GainsSpacing.tight) {
        Text(day.title.uppercased())
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(isToday ? GainsColor.lime : GainsColor.softInk)
        if isToday {
          Text("HEUTE")
            .font(GainsFont.label(8))
            .tracking(1.4)
            .foregroundStyle(GainsColor.moss)
            .padding(.horizontal, GainsSpacing.xs)
            .padding(.vertical, 2)
            .background(GainsColor.lime.opacity(0.18))
            .clipShape(Capsule())
        }
        Spacer()

        if draft != nil {
          Button {
            withAnimation(.spring(response: 0.25)) {
              drafts[day] = nil
            }
          } label: {
            HStack(spacing: GainsSpacing.xxs) {
              Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
              Text("Frei")
                .font(GainsFont.label(9))
                .tracking(1.0)
            }
            .foregroundStyle(GainsColor.softInk)
            .padding(.horizontal, GainsSpacing.tight)
            .frame(height: 28)
            .background(GainsColor.background.opacity(0.85))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }

      // Drei Mode-Buttons: Kraft / Lauf / Frei
      HStack(spacing: GainsSpacing.xsPlus) {
        modeButton(
          title: "Kraft",
          icon: "dumbbell.fill",
          isSelected: draft?.kind == .strength
        ) {
          withAnimation(.spring(response: 0.25)) {
            drafts[day] = DayDraft(kind: .strength, workoutPlanID: drafts[day]?.workoutPlanID)
          }
        }
        modeButton(
          title: "Lauf",
          icon: "figure.run",
          isSelected: draft?.kind.isRun == true
        ) {
          withAnimation(.spring(response: 0.25)) {
            // Beim ersten Wechsel zu Lauf: Default = Easy Run.
            // Stabilitäts-Hardening: kein Force-Unwrap mehr — explizit als
            // Optional-Pattern. Verhalten unverändert: wenn aktueller Eintrag
            // bereits ein Lauf-Kind ist, behalten wir ihn; sonst easyRun.
            let existing: PlannedSessionKind = {
              if let current = drafts[day]?.kind, current.isRun {
                return current
              }
              return .easyRun
            }()
            drafts[day] = DayDraft(kind: existing, workoutPlanID: nil)
          }
        }
        modeButton(
          title: "Frei",
          icon: "moon.zzz.fill",
          isSelected: draft == nil
        ) {
          withAnimation(.spring(response: 0.25)) {
            drafts[day] = nil
          }
        }
      }

      // Detail-Block je nach Auswahl
      if let draft {
        detailBlock(for: day, draft: draft)
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle(isToday ? GainsColor.lime.opacity(0.06) : GainsColor.card)
  }

  // MARK: - Mode-Button

  private func modeButton(
    title: String,
    icon: String,
    isSelected: Bool,
    onTap: @escaping () -> Void
  ) -> some View {
    Button(action: onTap) {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: icon)
          .font(.system(size: 12, weight: .bold))
        Text(title)
          .font(GainsFont.label(11))
          .tracking(1.2)
      }
      .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.ink)
      .frame(maxWidth: .infinity)
      .frame(height: 38)
      .background(isSelected ? GainsColor.lime : GainsColor.background.opacity(0.85))
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
          .stroke(
            isSelected ? Color.clear : GainsColor.border.opacity(0.55),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  // MARK: - Detail-Block

  @ViewBuilder
  private func detailBlock(for day: Weekday, draft: DayDraft) -> some View {
    if draft.kind == .strength {
      strengthDetail(for: day, currentPlanID: draft.workoutPlanID)
    } else if draft.kind.isRun {
      runDetail(for: day, currentKind: draft.kind)
    }
  }

  private func strengthDetail(for day: Weekday, currentPlanID: UUID?) -> some View {
    let plan = currentPlanID.flatMap { id in
      store.savedWorkoutPlans.first(where: { $0.id == id })
    }

    return Menu {
      Section("Workout zuweisen") {
        Button {
          drafts[day] = DayDraft(kind: .strength, workoutPlanID: nil)
        } label: {
          Label("Kein festes Workout", systemImage: "minus.circle")
        }
        Divider()
        ForEach(store.savedWorkoutPlans) { plan in
          Button {
            drafts[day] = DayDraft(kind: .strength, workoutPlanID: plan.id)
          } label: {
            Text("\(plan.title) · \(plan.split)")
          }
        }
      }
    } label: {
      HStack(spacing: GainsSpacing.tight) {
        Image(systemName: "dumbbell.fill")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 26, height: 26)
          .background(Circle().fill(GainsColor.lime.opacity(0.18)))

        VStack(alignment: .leading, spacing: 2) {
          Text(plan?.title ?? "Workout wählen")
            .font(GainsFont.label(13))
            .foregroundStyle(plan == nil ? GainsColor.softInk : GainsColor.ink)
          Text(plan.map { "\($0.exercises.count) Übungen · \($0.estimatedDurationMinutes) Min" } ?? "Optional · ohne Bindung")
            .font(GainsFont.label(10))
            .foregroundStyle(GainsColor.softInk)
        }
        Spacer()
        Image(systemName: "chevron.up.chevron.down")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(GainsSpacing.tight)
      .background(GainsColor.background.opacity(0.6))
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
    }
  }

  private func runDetail(for day: Weekday, currentKind: PlannedSessionKind) -> some View {
    let runKinds: [PlannedSessionKind] = [.easyRun, .tempoRun, .intervalRun, .longRun, .recoveryRun]

    return ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: GainsSpacing.xsPlus) {
        ForEach(runKinds, id: \.self) { kind in
          let isSelected = currentKind == kind
          Button {
            withAnimation(.spring(response: 0.25)) {
              drafts[day] = DayDraft(kind: kind, workoutPlanID: nil)
            }
          } label: {
            Text(kind.shortLabel)
              .font(GainsFont.label(10))
              .tracking(1.2)
              .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.ink)
              .padding(.horizontal, GainsSpacing.s)
              .frame(height: 32)
              .background(isSelected ? GainsColor.moss : GainsColor.background.opacity(0.85))
              .overlay(
                Capsule()
                  .stroke(
                    isSelected ? Color.clear : GainsColor.border.opacity(0.55),
                    lineWidth: 1
                  )
              )
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: - Summary

  private var summaryCard: some View {
    let strength = drafts.values.filter { $0.kind == .strength }.count
    let runs = drafts.values.filter { $0.kind.isRun }.count
    let total = strength + runs
    let rest = Weekday.allCases.count - total

    return VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["WOCHEN", "ÜBERSICHT"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      LazyVGrid(
        columns: [GridItem(.flexible(), spacing: GainsSpacing.tight), GridItem(.flexible(), spacing: GainsSpacing.tight)],
        spacing: GainsSpacing.tight
      ) {
        GainsMetricTile(
          label: "TRAINING",
          value: "\(total)",
          unit: total == 1 ? "Tag pro Woche" : "Tage pro Woche",
          style: .subdued
        )
        GainsMetricTile(
          label: "KRAFT",
          value: "\(strength)",
          unit: "Krafteinheiten",
          style: .subdued
        )
        GainsMetricTile(
          label: "LAUF",
          value: "\(runs)",
          unit: "Lauf-Sessions",
          style: .subdued
        )
        GainsMetricTile(
          label: "FREI",
          value: "\(rest)",
          unit: "Ruhetage",
          style: .subdued
        )
      }

      if total == 0 {
        HStack(alignment: .top, spacing: GainsSpacing.xsPlus) {
          Image(systemName: "info.circle.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
          Text("Wähle mindestens einen Trainingstag, sonst gibt es nichts zu speichern.")
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  // MARK: - Sticky Action Bar

  private var stickyActionBar: some View {
    Button {
      saveAndDismiss()
    } label: {
      HStack(spacing: GainsSpacing.xsPlus) {
        Image(systemName: "checkmark")
          .font(.system(size: 13, weight: .heavy))
        Text("Plan übernehmen")
          .font(GainsFont.label(13))
          .tracking(1.2)
      }
      .foregroundStyle(canSave ? GainsColor.onLime : GainsColor.ink.opacity(0.5))
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(canSave ? GainsColor.lime : GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(canSave ? Color.clear : GainsColor.border.opacity(0.5), lineWidth: 1)
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
    .disabled(!canSave)
  }

  private var canSave: Bool {
    !drafts.isEmpty
  }

  // MARK: - Initial-Loading
  //
  // Wenn der Nutzer den Sheet erneut öffnet und schon einen manuellen Plan
  // hat, übernehmen wir die existierende Map als Startpunkt — sonst
  // schlagen wir die aktuelle Wochenplanung als Vorlage vor (damit der
  // Nutzer nicht auf einer leeren Seite landet).

  private func loadInitialDrafts() {
    if store.plannerSettings.isManualPlan {
      var loaded: [Weekday: DayDraft] = [:]
      for (day, kind) in store.plannerSettings.manualSessionKinds {
        let planID = kind == .strength ? store.plannerSettings.dayAssignments[day] : nil
        loaded[day] = DayDraft(kind: kind, workoutPlanID: planID)
      }
      drafts = loaded
    } else {
      // Wizard-Plan als Startpunkt vorschlagen — der Nutzer kann ihn dann
      // einfach modifizieren statt komplett neu zu beginnen.
      var loaded: [Weekday: DayDraft] = [:]
      let kinds = store.plannedSessionKinds
      for (day, kind) in kinds {
        let planID = kind == .strength ? store.plannerSettings.dayAssignments[day] : nil
        loaded[day] = DayDraft(kind: kind, workoutPlanID: planID)
      }
      drafts = loaded
    }
  }

  // MARK: - Presets

  private func applyMondayFridayPreset() {
    var preset: [Weekday: DayDraft] = [:]
    preset[.monday]    = DayDraft(kind: .strength, workoutPlanID: nil)
    preset[.tuesday]   = DayDraft(kind: .strength, workoutPlanID: nil)
    preset[.wednesday] = DayDraft(kind: .strength, workoutPlanID: nil)
    preset[.thursday]  = DayDraft(kind: .strength, workoutPlanID: nil)
    preset[.friday]    = DayDraft(kind: .strength, workoutPlanID: nil)
    withAnimation(.spring(response: 0.3)) { drafts = preset }
  }

  private func applyHybridPreset() {
    var preset: [Weekday: DayDraft] = [:]
    preset[.monday]    = DayDraft(kind: .strength, workoutPlanID: nil)
    preset[.tuesday]   = DayDraft(kind: .easyRun, workoutPlanID: nil)
    preset[.wednesday] = DayDraft(kind: .strength, workoutPlanID: nil)
    preset[.friday]    = DayDraft(kind: .strength, workoutPlanID: nil)
    preset[.saturday]  = DayDraft(kind: .longRun, workoutPlanID: nil)
    withAnimation(.spring(response: 0.3)) { drafts = preset }
  }

  private func applyRunOnlyPreset() {
    var preset: [Weekday: DayDraft] = [:]
    preset[.monday]    = DayDraft(kind: .easyRun, workoutPlanID: nil)
    preset[.wednesday] = DayDraft(kind: .intervalRun, workoutPlanID: nil)
    preset[.friday]    = DayDraft(kind: .tempoRun, workoutPlanID: nil)
    preset[.sunday]    = DayDraft(kind: .longRun, workoutPlanID: nil)
    withAnimation(.spring(response: 0.3)) { drafts = preset }
  }

  // MARK: - Save

  private func saveAndDismiss() {
    var entries: [Weekday: PlannedSessionKind] = [:]
    var assignments: [Weekday: UUID] = [:]
    for (day, draft) in drafts {
      entries[day] = draft.kind
      if draft.kind == .strength, let id = draft.workoutPlanID {
        assignments[day] = id
      }
    }
    store.applyManualPlan(entries: entries, assignments: assignments)
    onSaved?()
    dismiss()
  }
}
