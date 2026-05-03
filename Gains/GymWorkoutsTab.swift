import SwiftUI

// MARK: - GymWorkoutsTab
//
// Aufgewerteter WORKOUTS-Tab. Neuerungen vs. der vorherigen Version:
//   • Sortier-Menü (Zuletzt / A–Z / Dauer / Übungen) zusätzlich zum
//     Quelle-Filter — schnellerer Zugriff bei wachsender Bibliothek.
//   • "Zuletzt: vor X Tagen"-Indikator je Workout, basierend auf der
//     Workout-Historie. Macht sichtbar, was tatsächlich gerade Teil deiner
//     Routine ist (vs. Karteileichen).
//   • "Tag zuweisen"-Quick-Action im Kontext-Menü jeder Reihe — ohne Umweg
//     über den PLAN-Tab kann man ein Workout direkt einem Wochentag zuordnen.
//   • Suche, Filter, Bearbeiten/Duplizieren/Löschen unverändert.

struct GymWorkoutsTab: View {
  @EnvironmentObject private var store: GainsStore

  @Binding var isShowingWorkoutBuilder: Bool
  @Binding var isShowingWorkoutTracker: Bool
  @Binding var workoutToEdit: WorkoutPlan?

  @State private var searchText: String = ""
  @State private var selectedFilter: SourceFilter = .all
  @State private var sortOption: SortOption = .lastPerformed
  @State private var planToDelete: WorkoutPlan? = nil
  @State private var showsFullLibrary = false

  // 2026-05-03 (P0-2): Wenn eine andere Session läuft, war der Play-Button
  // bisher `.disabled(isBlocked)` — der User tappte und nichts passierte.
  // Statt silent-no-op zeigen wir jetzt einen Confirm-Dialog: aktuelle
  // Session beenden und neuen Plan starten? Das macht den Block transparent.
  @State private var blockedPlanAttempt: WorkoutPlan? = nil

  private enum SourceFilter: String, CaseIterable, Identifiable {
    case all     = "ALLE"
    case custom  = "EIGENE"
    case template = "VORLAGEN"
    var id: Self { self }
  }

  private enum SortOption: String, CaseIterable, Identifiable {
    case lastPerformed = "Zuletzt"
    case alphabetical  = "A–Z"
    case duration      = "Dauer"
    case exerciseCount = "Übungen"
    var id: Self { self }

    var icon: String {
      switch self {
      case .lastPerformed: return "clock.arrow.circlepath"
      case .alphabetical:  return "textformat"
      case .duration:      return "timer"
      case .exerciseCount: return "list.bullet"
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      header
      searchBar
      filterRow

      let custom = filteredCustom()
      let templates = filteredTemplates()

      libraryStatsLine(custom: custom, templates: templates)

      if custom.isEmpty && templates.isEmpty {
        emptyResult
      }

      if !custom.isEmpty {
        VStack(alignment: .leading, spacing: GainsSpacing.tight) {
          Text("EIGENE WORKOUTS")
            .font(GainsFont.label(9))
            .tracking(2.0)
            .foregroundStyle(GainsColor.softInk)
          ForEach(custom) { plan in
            workoutRow(plan)
          }
        }
      }

      if !templates.isEmpty && selectedFilter != .custom {
        VStack(alignment: .leading, spacing: GainsSpacing.tight) {
          Text("VORLAGEN")
            .font(GainsFont.label(9))
            .tracking(2.0)
            .foregroundStyle(GainsColor.softInk)
            .padding(.top, custom.isEmpty ? 0 : 6)

          let visible = showsFullLibrary ? templates : Array(templates.prefix(3))
          ForEach(visible) { plan in
            workoutRow(plan)
          }

          if templates.count > 3 {
            Button {
              withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                showsFullLibrary.toggle()
              }
            } label: {
              HStack(spacing: GainsSpacing.xs) {
                Text(showsFullLibrary
                  ? "Weniger anzeigen"
                  : "\(templates.count - 3) weitere Vorlagen")
                  .font(GainsFont.label(10))
                  .tracking(1.2)
                Image(systemName: showsFullLibrary ? "chevron.up" : "chevron.down")
                  .font(.system(size: 10, weight: .semibold))
              }
              .foregroundStyle(GainsColor.softInk)
              .frame(maxWidth: .infinity)
              .frame(height: 42)
              .background(GainsColor.background.opacity(0.8))
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .alert(
      Text(deleteAlertTitle),
      isPresented: Binding(
        get: { planToDelete != nil },
        set: { if !$0 { planToDelete = nil } }
      )
    ) {
      Button("Abbrechen", role: .cancel) { planToDelete = nil }
      Button("Löschen", role: .destructive) {
        if let plan = planToDelete {
          store.deleteWorkout(plan)
        }
        planToDelete = nil
      }
    } message: {
      Text("Eigene Workouts werden inklusive Tageszuweisungen entfernt.")
    }
    // P0-2: Block-Confirm. Aktuell laufender Plan wird beendet, der neue
    // sofort gestartet — sonst kann der User über die Bibliothek nicht
    // wechseln, ohne erst den Tracker zu öffnen.
    .alert(
      Text("Andere Session läuft"),
      isPresented: Binding(
        get: { blockedPlanAttempt != nil },
        set: { if !$0 { blockedPlanAttempt = nil } }
      )
    ) {
      Button("Abbrechen", role: .cancel) { blockedPlanAttempt = nil }
      Button("Beenden & wechseln", role: .destructive) {
        if let plan = blockedPlanAttempt {
          store.discardWorkout()
          store.startWorkout(from: plan)
          isShowingWorkoutTracker = true
        }
        blockedPlanAttempt = nil
      }
    } message: {
      if let plan = blockedPlanAttempt, let active = store.activeWorkout {
        Text("„\(active.title)" läuft gerade. Diese Session beenden und „\(plan.title)" starten?")
      } else {
        Text("Eine andere Session läuft gerade.")
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      SlashLabel(
        parts: ["MEINE", "WORKOUTS"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )
      Spacer()

      // Sortier-Menü direkt neben dem "NEU"-Button — vermeidet, dass
      // Filter und Sortierung vermischt werden. Picker rendert automatisch
      // ein Häkchen vor der gewählten Option.
      Menu {
        Picker("Sortieren", selection: $sortOption) {
          ForEach(SortOption.allCases) { option in
            Label(option.rawValue, systemImage: option.icon)
              .tag(option)
          }
        }
      } label: {
        HStack(spacing: GainsSpacing.xxs) {
          Image(systemName: "arrow.up.arrow.down")
            .font(.system(size: 10, weight: .bold))
          Text(sortOption.rawValue.uppercased())
            .font(GainsFont.eyebrow(10))
            .tracking(1.2)
        }
        .foregroundStyle(GainsColor.ink)
        .padding(.horizontal, GainsSpacing.s)
        .frame(height: 32)
        .background(GainsColor.card)
        .overlay(
          Capsule().strokeBorder(GainsColor.border.opacity(0.6), lineWidth: 1)
        )
        .clipShape(Capsule())
      }

      Button {
        isShowingWorkoutBuilder = true
      } label: {
        HStack(spacing: GainsSpacing.xxs) {
          Image(systemName: "plus")
            .font(.system(size: 11, weight: .bold))
          Text("NEU")
            .font(GainsFont.label(10))
            .tracking(1.8)
        }
        .foregroundStyle(GainsColor.onLime)
        .padding(.horizontal, GainsSpacing.s)
        .frame(height: 32)
        .background(GainsColor.lime)
        .clipShape(Capsule())
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Suchfeld

  private var searchBar: some View {
    HStack(spacing: GainsSpacing.tight) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)
      TextField("Workout, Split oder Fokus suchen", text: $searchText)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.ink)
        .submitLabel(.search)
      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 14))
            .foregroundStyle(GainsColor.softInk.opacity(0.7))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, GainsSpacing.m)
    .frame(height: 44)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.6), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  // MARK: - Library-Stats Zeile
  //
  // Eine schmale Info-Zeile zwischen Filter und Liste. Zeigt im Default
  // die Bibliotheks-Kennzahlen, bei aktiver Suche die Treffer-Anzahl —
  // gibt schnellen Überblick ohne separate Stats-Karte.

  @ViewBuilder
  private func libraryStatsLine(
    custom: [WorkoutPlan],
    templates: [WorkoutPlan]
  ) -> some View {
    let isSearching = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let totalCustom = store.customWorkoutPlans.count
    let totalTemplates = store.templateWorkoutPlans.count
    let totalMatches = custom.count + templates.count

    HStack(spacing: GainsSpacing.xs) {
      Image(systemName: isSearching ? "magnifyingglass" : "books.vertical.fill")
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(GainsColor.softInk)

      if isSearching {
        Text("\(totalMatches) \(totalMatches == 1 ? "Treffer" : "Treffer")")
          .font(GainsFont.label(10))
          .tracking(1.0)
          .foregroundStyle(GainsColor.ink)
        Text("·")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.softInk)
        Text("\(custom.count) eigen · \(templates.count) Vorlagen")
          .font(GainsFont.label(9))
          .tracking(0.8)
          .foregroundStyle(GainsColor.softInk)
      } else {
        Text("\(totalCustom) \(totalCustom == 1 ? "eigenes" : "eigene") · \(totalTemplates) Vorlagen")
          .font(GainsFont.label(10))
          .tracking(1.0)
          .foregroundStyle(GainsColor.ink)
        Text("·")
          .font(GainsFont.label(10))
          .foregroundStyle(GainsColor.softInk)
        Text("Sortiert nach \(sortOption.rawValue)")
          .font(GainsFont.label(9))
          .tracking(0.8)
          .foregroundStyle(GainsColor.softInk)
      }
      Spacer(minLength: 0)
    }
  }

  // MARK: - Filter
  //
  // A9: Pill-Stil identisch zu `GymStatsTab.timeRangeFilter` — `card` als
  // inaktiv-Surface mit Hairline-Border, lime-fill ohne Border als aktiv.
  // Vorher war der inaktiv-Background ein dunklerer `background.opacity(0.85)`,
  // der visuell gegen den Card-Stack der Liste darunter „verschwommen" hat.

  private var filterRow: some View {
    HStack(spacing: GainsSpacing.xsPlus) {
      ForEach(SourceFilter.allCases) { filter in
        Button {
          withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            selectedFilter = filter
          }
        } label: {
          Text(filter.rawValue)
            .font(GainsFont.eyebrow(10))
            .tracking(1.4)
            .foregroundStyle(selectedFilter == filter ? GainsColor.onLime : GainsColor.softInk)
            .padding(.horizontal, GainsSpacing.m)
            .frame(height: 32)
            .background(selectedFilter == filter ? GainsColor.lime : GainsColor.card)
            .overlay(
              Capsule().strokeBorder(
                selectedFilter == filter ? Color.clear : GainsColor.border.opacity(0.6),
                lineWidth: 1
              )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
      }
      Spacer()
    }
  }

  // MARK: - Filter- & Sortier-Logik

  private func filteredCustom() -> [WorkoutPlan] {
    guard selectedFilter != .template else { return [] }
    let filtered = apply(searchText: searchText, to: store.customWorkoutPlans)
    return sorted(filtered)
  }

  private func filteredTemplates() -> [WorkoutPlan] {
    guard selectedFilter != .custom else { return [] }
    let filtered = apply(searchText: searchText, to: store.templateWorkoutPlans)
    return sorted(filtered)
  }

  private func apply(searchText: String, to plans: [WorkoutPlan]) -> [WorkoutPlan] {
    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return plans }
    return plans.filter { plan in
      plan.title.localizedCaseInsensitiveContains(trimmed)
        || plan.split.localizedCaseInsensitiveContains(trimmed)
        || plan.focus.localizedCaseInsensitiveContains(trimmed)
    }
  }

  private func sorted(_ plans: [WorkoutPlan]) -> [WorkoutPlan] {
    switch sortOption {
    case .lastPerformed:
      // Pläne mit Verlauf zuerst (nach Datum absteigend), Pläne ohne Verlauf
      // alphabetisch dahinter — sonst springt die Reihenfolge unerwartet.
      return plans.sorted { lhs, rhs in
        let lhsDate = lastPerformedDate(for: lhs)
        let rhsDate = lastPerformedDate(for: rhs)
        switch (lhsDate, rhsDate) {
        case let (l?, r?): return l > r
        case (_?, nil):    return true
        case (nil, _?):    return false
        case (nil, nil):   return lhs.title.localizedCompare(rhs.title) == .orderedAscending
        }
      }
    case .alphabetical:
      return plans.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    case .duration:
      return plans.sorted { $0.estimatedDurationMinutes < $1.estimatedDurationMinutes }
    case .exerciseCount:
      return plans.sorted { $0.exercises.count > $1.exercises.count }
    }
  }

  /// Datum der letzten absolvierten Session, gematched über den Plan-Titel.
  /// Workout-Historie speichert keine Plan-IDs, deshalb der Titel-Vergleich.
  private func lastPerformedDate(for plan: WorkoutPlan) -> Date? {
    store.workoutHistory
      .first(where: { $0.title == plan.title })?
      .finishedAt
  }

  // MARK: - Workout-Row

  private func workoutRow(_ plan: WorkoutPlan) -> some View {
    let isActive = store.activeWorkout?.title == plan.title
    let isBlocked = store.activeWorkout != nil && !isActive
    let isMatchingToday = store.todayPlannedWorkout?.id == plan.id
    let lastDate = lastPerformedDate(for: plan)

    return HStack(spacing: GainsSpacing.s) {
      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        HStack(spacing: GainsSpacing.xsPlus) {
          GymWorkoutSourceBadge(source: plan.source)
          Text(plan.split.uppercased())
            .font(GainsFont.label(9))
            .tracking(1.5)
            .foregroundStyle(GainsColor.softInk)
          if isMatchingToday {
            Text("HEUTE")
              .font(GainsFont.label(8))
              .tracking(1.4)
              .foregroundStyle(GainsColor.moss)
              .padding(.horizontal, GainsSpacing.xs)
              .padding(.vertical, 2)
              .background(GainsColor.lime.opacity(0.18))
              .clipShape(Capsule())
          }
        }
        Text(plan.title)
          .font(GainsFont.title(18))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
        Text("\(plan.exercises.count) Übungen · \(plan.estimatedDurationMinutes) Min · \(plan.focus)")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(1)

        if let lastDate {
          HStack(spacing: GainsSpacing.xxs) {
            Image(systemName: "clock.arrow.circlepath")
              .font(.system(size: 10, weight: .semibold))
            Text("Zuletzt: \(relativeLastLabel(lastDate))")
              .font(GainsFont.label(9))
              .tracking(0.8)
          }
          .foregroundStyle(GainsColor.moss)
        }
      }

      Spacer(minLength: 0)

      Menu {
        // Tag zuweisen — neue Quick-Action.
        Menu {
          ForEach(Weekday.allCases) { day in
            Button {
              store.assignWorkout(plan, to: day)
            } label: {
              Label(day.title, systemImage: day == .today ? "star.fill" : "calendar")
            }
          }
        } label: {
          Label("Tag zuweisen", systemImage: "calendar.badge.plus")
        }

        if plan.source == .custom {
          Button {
            workoutToEdit = plan
          } label: {
            Label("Bearbeiten", systemImage: "pencil")
          }
        }
        Button {
          store.duplicateWorkout(plan)
        } label: {
          Label("Duplizieren", systemImage: "doc.on.doc")
        }
        if plan.source == .custom {
          Divider()
          Button(role: .destructive) {
            planToDelete = plan
          } label: {
            Label("Löschen", systemImage: "trash")
          }
        }
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(GainsColor.softInk)
          .frame(width: 32, height: 32)
          .contentShape(Rectangle())
      }

      Button {
        // P0-2: drei Pfade.
        //   isActive  → Tracker einfach (wieder) öffnen.
        //   isBlocked → andere Session läuft → Confirm-Alert statt no-op.
        //   sonst     → frisch starten.
        if isActive {
          isShowingWorkoutTracker = true
        } else if isBlocked {
          UINotificationFeedbackGenerator().notificationOccurred(.warning)
          blockedPlanAttempt = plan
        } else {
          store.startWorkout(from: plan)
          isShowingWorkoutTracker = true
        }
      } label: {
        Image(systemName: isActive ? "play.fill" : "arrow.right")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(isBlocked ? GainsColor.softInk : GainsColor.onLime)
          .frame(width: 38, height: 38)
          .background(isBlocked ? GainsColor.background : GainsColor.lime)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      // .disabled(isBlocked) bewusst raus: ein Tap darf jetzt einen Dialog
      // öffnen statt schweigend ins Leere zu laufen.
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
    // Long-Press öffnet identisches Menü — gleiche Aktionen wie der ⋯-Button,
    // funktioniert aber auch wenn der Tap-Bereich klein ist.
    .contextMenu {
      Menu {
        ForEach(Weekday.allCases) { day in
          Button {
            store.assignWorkout(plan, to: day)
          } label: {
            Label(day.title, systemImage: day == .today ? "star.fill" : "calendar")
          }
        }
      } label: {
        Label("Tag zuweisen", systemImage: "calendar.badge.plus")
      }

      if plan.source == .custom {
        Button {
          workoutToEdit = plan
        } label: {
          Label("Bearbeiten", systemImage: "pencil")
        }
      }
      Button {
        store.duplicateWorkout(plan)
      } label: {
        Label("Duplizieren", systemImage: "doc.on.doc")
      }
      if plan.source == .custom {
        Button(role: .destructive) {
          planToDelete = plan
        } label: {
          Label("Löschen", systemImage: "trash")
        }
      }
    }
  }

  // MARK: - Last-Performed Label

  private func relativeLastLabel(_ date: Date) -> String {
    let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    switch days {
    case ..<0:  return "geplant"
    case 0:     return "heute"
    case 1:     return "gestern"
    case 2..<7: return "vor \(days) Tagen"
    case 7..<14: return "vor 1 Woche"
    case 14..<30: return "vor \(days / 7) Wochen"
    case 30..<60: return "vor 1 Monat"
    default:    return "vor \(days / 30) Monaten"
    }
  }

  // MARK: - Empty State

  private var emptyResult: some View {
    EmptyStateView(
      style: .inline,
      title: searchText.isEmpty ? "Bibliothek leer" : "Keine Treffer",
      message: emptyResultMessage,
      icon: searchText.isEmpty ? "tray" : "magnifyingglass"
    )
  }

  private var emptyResultMessage: String {
    if searchText.isEmpty {
      return "Erstelle dein erstes eigenes Workout oder nutze eine Vorlage als Startpunkt."
    }
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return "Für „\(query)" + "\" haben wir nichts gefunden. Probier einen anderen Begriff oder lege ein neues Workout an."
  }

  private var deleteAlertTitle: String {
    if let title = planToDelete?.title {
      return "„\(title)" + "\" löschen?"
    }
    return "Workout löschen?"
  }
}
