import SwiftUI

// MARK: - RunGoalPlanView
//
// UI-Bausteine für den Ziel-Trainingsplaner. Drei Komponenten:
//
//  • RunGoalPlannerSection   — Top-Block im PLÄNE-Tab (CTA wenn kein Plan,
//                              oder Hero-Karte + aktuelle Woche wenn aktiv).
//  • RunGoalPlanSetupSheet   — Eingabe-Sheet (Distanz, Pace, Datum,
//                              Wochenvolumen, Sessions/Woche).
//  • RunGoalPlanDetailSheet  — Detail-Sheet mit allen Wochen + Sessions.
//
// Sitzt in eigener Datei, weil das Feature unabhängig vom restlichen Run-Hub
// gewachsen ist. Keine eigene Tab-Navigation — der Block ersetzt nichts,
// sondern ergänzt den PLÄNE-Tab oben.

// MARK: - RunGoalPlannerSection

struct RunGoalPlannerSection: View {
  @EnvironmentObject private var store: GainsStore

  @State private var isShowingSetup = false
  @State private var isShowingDetail = false
  @State private var isConfirmingClear = false

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header

      if let plan = store.runGoalPlan {
        goalSummaryCard(plan)
        currentWeekCard(plan)
      } else {
        emptyStateCard
      }
    }
    .sheet(isPresented: $isShowingSetup) {
      RunGoalPlanSetupSheet(existing: store.runGoalPlan)
        .environmentObject(store)
    }
    .sheet(isPresented: $isShowingDetail) {
      if let plan = store.runGoalPlan {
        RunGoalPlanDetailSheet(plan: plan, onEdit: {
          isShowingDetail = false
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShowingSetup = true
          }
        })
        .environmentObject(store)
      }
    }
    .confirmationDialog(
      "Plan beenden?",
      isPresented: $isConfirmingClear,
      titleVisibility: .visible
    ) {
      Button("Plan löschen", role: .destructive) {
        store.clearRunGoalPlan()
      }
      Button("Abbrechen", role: .cancel) {}
    } message: {
      Text("Sessions und Fortschritt werden entfernt.")
    }
  }

  // MARK: Header

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      SlashLabel(
        parts: ["ZIEL", "TRAINING"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )
      Spacer()
      if store.runGoalPlan != nil {
        Menu {
          Button {
            isShowingDetail = true
          } label: {
            Label("Alle Wochen", systemImage: "calendar")
          }
          Button {
            isShowingSetup = true
          } label: {
            Label("Plan anpassen", systemImage: "slider.horizontal.3")
          }
          Button(role: .destructive) {
            isConfirmingClear = true
          } label: {
            Label("Plan löschen", systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
  }

  // MARK: Empty State (kein Plan aktiv)

  private var emptyStateCard: some View {
    Button {
      isShowingSetup = true
    } label: {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: "flag.checkered")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(GainsColor.lime)
          .frame(width: 44, height: 44)
          .background(GainsColor.lime.opacity(0.18))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        VStack(alignment: .leading, spacing: 6) {
          Text("Trainings-Ziel setzen")
            .font(GainsFont.title(17))
            .foregroundStyle(GainsColor.ink)
          Text("Distanz, Tempo und Datum festlegen — Gains baut dir den Wochenplan.")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(GainsColor.softInk.opacity(0.55))
      }
      .padding(16)
      .gainsInteractiveCardStyle(GainsColor.card, accent: GainsColor.lime)
    }
    .buttonStyle(.plain)
  }

  // MARK: Goal-Summary-Card (Ziel + Countdown + Fortschritt)

  private func goalSummaryCard(_ plan: RunGoalPlan) -> some View {
    let days = plan.daysUntilTarget()
    let dateLabel = plan.targetDate.formatted(date: .abbreviated, time: .omitted)

    return Button {
      isShowingDetail = true
    } label: {
      VStack(alignment: .leading, spacing: 14) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 4) {
            Text(plan.displayTitle)
              .font(GainsFont.title(20))
              .foregroundStyle(GainsColor.ink)
              .lineLimit(1)
            Text("Ziel \(dateLabel)")
              .font(GainsFont.eyebrow(10))
              .tracking(1.2)
              .foregroundStyle(GainsColor.softInk)
          }
          Spacer()
          countdownPill(days: days)
        }

        HStack(spacing: 0) {
          goalStatCell(
            label: "DISTANZ",
            value: distanceLabel(plan.targetDistanceKm),
            unit: "km"
          )
          goalStatDivider()
          goalStatCell(
            label: "PACE",
            value: paceValueLabel(plan.targetPaceSeconds),
            unit: "/km"
          )
          goalStatDivider()
          goalStatCell(
            label: "WOCHEN",
            value: "\(plan.totalWeeks)",
            unit: ""
          )
        }
        .padding(.vertical, 12)
        .background(GainsColor.surfaceDeep.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

        progressBar(plan)
      }
      .padding(16)
      .gainsInteractiveCardStyle(GainsColor.card, accent: GainsColor.lime)
    }
    .buttonStyle(.plain)
  }

  private func countdownPill(days: Int) -> some View {
    let label: String
    let tone: Color
    if days < 0 {
      label = "Ziel-Datum erreicht"
      tone = GainsColor.softInk
    } else if days == 0 {
      label = "Heute"
      tone = GainsColor.lime
    } else if days == 1 {
      label = "Morgen"
      tone = GainsColor.lime
    } else {
      label = "in \(days) Tagen"
      tone = days <= 21 ? GainsColor.lime : GainsColor.moss
    }
    return HStack(spacing: 5) {
      Image(systemName: "clock.fill")
        .font(.system(size: 9, weight: .bold))
      Text(label.uppercased())
        .font(GainsFont.eyebrow(9))
        .tracking(1.2)
    }
    .foregroundStyle(tone)
    .padding(.horizontal, 10)
    .frame(height: 24)
    .background(tone.opacity(0.16))
    .overlay(
      Capsule().strokeBorder(tone.opacity(0.4), lineWidth: 0.6)
    )
    .clipShape(Capsule())
  }

  private func goalStatCell(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.eyebrow(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(GainsFont.metricMono(16))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        if !unit.isEmpty {
          Text(unit)
            .font(GainsFont.body(10))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func goalStatDivider() -> some View {
    Rectangle()
      .fill(GainsColor.border.opacity(0.45))
      .frame(width: 0.6, height: 28)
  }

  private func progressBar(_ plan: RunGoalPlan) -> some View {
    let fraction = plan.completionFraction
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("FORTSCHRITT")
          .font(GainsFont.eyebrow(9))
          .tracking(1.4)
          .foregroundStyle(GainsColor.softInk)
        Spacer()
        Text("\(plan.completedCount) / \(plan.sessions.count) Sessions")
          .font(GainsFont.metricMono(12))
          .foregroundStyle(GainsColor.ink)
      }
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(GainsColor.border.opacity(0.4))
            .frame(height: 6)
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(GainsColor.lime)
            .frame(width: geo.size.width * fraction, height: 6)
        }
      }
      .frame(height: 6)
    }
  }

  // MARK: Aktuelle Woche

  private func currentWeekCard(_ plan: RunGoalPlan) -> some View {
    let weekIdx = plan.currentWeekIndex()
    let weekSessions = plan.sessions(inWeek: weekIdx)
    let phase = weekSessions.first?.phase ?? .base

    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text("DIESE WOCHE · \(phase.eyebrow)")
          .font(GainsFont.eyebrow(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.lime)
        Spacer()
        Text("Woche \(weekIdx + 1) / \(plan.totalWeeks)")
          .font(GainsFont.eyebrow(9))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }

      if weekSessions.isEmpty {
        Text("Keine Sessions in dieser Woche.")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
          .padding(.vertical, 6)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(weekSessions.enumerated()), id: \.element.id) { idx, session in
            sessionRow(session)
            if idx < weekSessions.count - 1 {
              Divider()
                .background(GainsColor.border.opacity(0.35))
                .padding(.horizontal, 12)
            }
          }
        }
      }
    }
    .padding(14)
    .gainsCardStyle()
  }

  // MARK: Session-Zeile

  @ViewBuilder
  private func sessionRow(_ session: PlannedRunSession) -> some View {
    let cal = Calendar.current
    let isToday = cal.isDateInToday(session.date)
    let isPast = !isToday && session.date < Date() && !session.isCompleted

    HStack(spacing: 12) {
      Button {
        store.togglePlanSessionCompletion(session.id)
      } label: {
        Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(session.isCompleted ? GainsColor.moss : GainsColor.lime)
      }
      .buttonStyle(.plain)
      .accessibilityLabel(session.isCompleted ? "Erledigt" : "Offen")

      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(session.kind.shortLabel)
            .font(GainsFont.eyebrow(9))
            .tracking(1.4)
            .foregroundStyle(kindColor(session.kind))
          Text("·")
            .foregroundStyle(GainsColor.softInk.opacity(0.5))
          Text(weekdayLabel(session.date))
            .font(GainsFont.eyebrow(9))
            .tracking(1.0)
            .foregroundStyle(isToday ? GainsColor.lime : GainsColor.softInk)
          if isPast {
            Text("· VERPASST")
              .font(GainsFont.eyebrow(9))
              .tracking(1.0)
              .foregroundStyle(GainsColor.softInk.opacity(0.7))
          }
        }
        Text(sessionTitle(session))
          .font(GainsFont.title(14))
          .foregroundStyle(session.isCompleted ? GainsColor.softInk : GainsColor.ink)
          .strikethrough(session.isCompleted, color: GainsColor.softInk)
          .lineLimit(1)
        if !session.notes.isEmpty {
          Text(session.notes)
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }
      }

      Spacer()

      Text(distanceLabel(session.distanceKm) + " km")
        .font(GainsFont.metricMono(13))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(1)
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 10)
  }

  private func sessionTitle(_ session: PlannedRunSession) -> String {
    "\(session.kind.title) · \(paceValueLabel(session.targetPaceSeconds)) /km"
  }

  private func kindColor(_ kind: PlannedSessionKind) -> Color {
    switch kind {
    case .longRun:     return GainsColor.lime
    case .tempoRun:    return GainsColor.zone4
    case .intervalRun: return GainsColor.zone5
    case .easyRun:     return GainsColor.moss
    case .recoveryRun: return GainsColor.zone1
    default:           return GainsColor.softInk
    }
  }

  private func weekdayLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "EEE d.M."
    return f.string(from: date).uppercased()
  }

  private func distanceLabel(_ km: Double) -> String {
    if km >= 10 { return String(format: "%.0f", km) }
    return String(format: "%.1f", km)
  }

  private func paceValueLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "—" }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }
}

// MARK: - Setup Sheet

struct RunGoalPlanSetupSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  /// Wenn gesetzt → Bearbeitungsmodus, der die bestehenden Werte vorbelegt.
  let existing: RunGoalPlan?

  @State private var title: String = ""
  @State private var distanceKm: Double = 21.0975
  @State private var paceMinutes: Int = 5
  @State private var paceSeconds: Int = 0
  // Stabilitäts-Fix: Defensiv ohne force-unwrap. Calendar.date(byAdding:)
  // kann theoretisch nil liefern — wir fallen dann auf 84 Tage in Sekunden zurück.
  @State private var targetDate: Date = Calendar.current.date(byAdding: .day, value: 84, to: Date())
    ?? Date().addingTimeInterval(84 * 86_400)
  @State private var weeklyBaseKm: Double = 20
  @State private var sessionsPerWeek: Int = 4

  private let presetDistances: [(label: String, km: Double)] = [
    ("5K", 5),
    ("10K", 10),
    ("Halbmarathon", 21.0975),
    ("Marathon", 42.195),
  ]

  private var paceTotalSeconds: Int { paceMinutes * 60 + paceSeconds }

  private var canSave: Bool {
    distanceKm > 0
      && paceTotalSeconds > 0
      && targetDate > Calendar.current.startOfDay(for: Date())
  }

  /// Geschätzte Wochenzahl, gerendert direkt im Sheet als Vorschau.
  private var estimatedWeeks: Int {
    let cal = Calendar.current
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: targetDate)).day ?? 0
    return max(4, min(24, days / 7))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          headerBlock

          distanceSection
          paceSection
          dateSection
          loadSection
          previewSection

          Color.clear.frame(height: 80)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
      }
      .background(GainsColor.background.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
        }
        ToolbarItem(placement: .principal) {
          Text(existing == nil ? "ZIEL SETZEN" : "PLAN ANPASSEN")
            .font(GainsFont.label(11))
            .tracking(2.0)
            .foregroundStyle(GainsColor.ink)
        }
      }
      .safeAreaInset(edge: .bottom) {
        saveButton
          .padding(.horizontal, 20)
          .padding(.vertical, 12)
          .background(GainsColor.background)
      }
      .onAppear(perform: prefill)
    }
  }

  private func prefill() {
    guard let plan = existing else { return }
    title = plan.title
    distanceKm = plan.targetDistanceKm
    paceMinutes = plan.targetPaceSeconds / 60
    paceSeconds = plan.targetPaceSeconds % 60
    targetDate = plan.targetDate
    weeklyBaseKm = plan.weeklyBaseKm
    sessionsPerWeek = plan.sessionsPerWeek
  }

  // MARK: Sections

  private var headerBlock: some View {
    VStack(alignment: .leading, spacing: 8) {
      SlashLabel(
        parts: ["ZIEL", "PLANER"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )
      Text("Distanz × Tempo × Datum")
        .font(GainsFont.title(24))
        .foregroundStyle(GainsColor.ink)
      Text("Aus deinem Ziel wird ein Wochenplan mit Long Run, Tempo und Easy-Einheiten gebaut.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var distanceSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["DISTANZ"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(presetDistances, id: \.label) { preset in
            Button {
              distanceKm = preset.km
              if title.isEmpty {
                title = preset.label
              }
            } label: {
              Text(preset.label)
                .font(GainsFont.label(11))
                .tracking(1.2)
                .foregroundStyle(distanceKm == preset.km ? GainsColor.onLime : GainsColor.softInk)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(distanceKm == preset.km ? GainsColor.lime : GainsColor.card)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }

      HStack(spacing: 12) {
        Image(systemName: "ruler")
          .foregroundStyle(GainsColor.softInk)
        TextField(
          "Distanz",
          value: $distanceKm,
          format: .number.precision(.fractionLength(0...2))
        )
        .keyboardType(.decimalPad)
        .font(GainsFont.metricMono(20))
        .foregroundStyle(GainsColor.ink)
        Text("km")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(.horizontal, 14)
      .frame(height: 50)
      .background(GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(GainsColor.border.opacity(0.5), lineWidth: 1)
      )
    }
    .padding(16)
    .gainsCardStyle()
  }

  private var paceSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["ZIEL", "PACE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      HStack(spacing: 14) {
        paceWheel(value: $paceMinutes, range: 3...8, unit: "min")
        Text(":")
          .font(GainsFont.metricMono(28))
          .foregroundStyle(GainsColor.softInk)
        paceWheel(value: $paceSeconds, range: 0...59, unit: "s", step: 5)
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text("/km")
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
          Text(estimatedFinishLabel())
            .font(GainsFont.eyebrow(10))
            .tracking(1.0)
            .foregroundStyle(GainsColor.moss)
            .lineLimit(1)
        }
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  private func paceWheel(value: Binding<Int>, range: ClosedRange<Int>, unit: String, step: Int = 1) -> some View {
    VStack(spacing: 6) {
      HStack(spacing: 8) {
        Button {
          let next = value.wrappedValue - step
          if next >= range.lowerBound { value.wrappedValue = next }
        } label: {
          Image(systemName: "minus")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 30, height: 30)
            .background(GainsColor.background.opacity(0.8))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)

        Text(String(format: "%02d", value.wrappedValue))
          .font(GainsFont.metricMono(28))
          .foregroundStyle(GainsColor.ink)
          .frame(minWidth: 56)

        Button {
          let next = value.wrappedValue + step
          if next <= range.upperBound { value.wrappedValue = next }
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(GainsColor.ink)
            .frame(width: 30, height: 30)
            .background(GainsColor.background.opacity(0.8))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }
      Text(unit)
        .font(GainsFont.eyebrow(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
    }
  }

  private func estimatedFinishLabel() -> String {
    guard paceTotalSeconds > 0, distanceKm > 0 else { return "" }
    let totalSeconds = Int(Double(paceTotalSeconds) * distanceKm)
    let h = totalSeconds / 3600
    let m = (totalSeconds % 3600) / 60
    if h > 0 { return String(format: "Ziel-Zeit %dh %02dm", h, m) }
    return String(format: "Ziel-Zeit %d Min", m)
  }

  private var dateSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["ZIEL", "DATUM"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      DatePicker(
        "Ziel-Datum",
        selection: $targetDate,
        in: Date()...,
        displayedComponents: .date
      )
      .datePickerStyle(.compact)
      .labelsHidden()
      .tint(GainsColor.lime)
      .frame(maxWidth: .infinity, alignment: .leading)

      HStack(spacing: 6) {
        Image(systemName: "calendar")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(GainsColor.softInk)
        Text("\(estimatedWeeks) Wochen Vorbereitung")
          .font(GainsFont.eyebrow(10))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  private var loadSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["AKTUELLE", "WOCHE"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Wochenvolumen")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.ink)
          Spacer()
          Text("\(Int(weeklyBaseKm)) km")
            .font(GainsFont.metricMono(15))
            .foregroundStyle(GainsColor.ink)
        }
        Slider(value: $weeklyBaseKm, in: 0...100, step: 5)
          .tint(GainsColor.lime)
        Text("Damit der Plan dort startet, wo du gerade stehst.")
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
      }

      Divider()
        .background(GainsColor.border.opacity(0.4))

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Sessions / Woche")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.ink)
          Spacer()
          Picker("Sessions", selection: $sessionsPerWeek) {
            Text("3").tag(3)
            Text("4").tag(4)
          }
          .pickerStyle(.segmented)
          .frame(width: 110)
        }
        Text(sessionsPerWeek == 4
          ? "Standard: Easy · Tempo · Easy · Long Run."
          : "Schlanker: Tempo · Easy · Long Run.")
          .font(GainsFont.body(11))
          .foregroundStyle(GainsColor.softInk)
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  private var previewSection: some View {
    let preview = RunGoalPlanGenerator.generateSessions(
      targetDistanceKm: max(distanceKm, 0.1),
      targetPaceSeconds: max(paceTotalSeconds, 1),
      targetDate: targetDate,
      weeklyBaseKm: weeklyBaseKm,
      sessionsPerWeek: sessionsPerWeek
    )
    let firstWeek = preview.filter { $0.weekIndex == 0 }
    return VStack(alignment: .leading, spacing: 10) {
      SlashLabel(
        parts: ["VORSCHAU", "WOCHE 1"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )
      if firstWeek.isEmpty {
        Text("Vorschau erscheint, sobald Distanz, Pace und Datum gesetzt sind.")
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(firstWeek.enumerated()), id: \.element.id) { idx, session in
            previewRow(session)
            if idx < firstWeek.count - 1 {
              Divider()
                .background(GainsColor.border.opacity(0.35))
                .padding(.horizontal, 8)
            }
          }
        }
      }
    }
    .padding(16)
    .gainsCardStyle()
  }

  private func previewRow(_ session: PlannedRunSession) -> some View {
    HStack(spacing: 10) {
      Text(session.kind.shortLabel)
        .font(GainsFont.eyebrow(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.lime)
        .frame(width: 70, alignment: .leading)
      Text(String(format: "%.1f km", session.distanceKm))
        .font(GainsFont.metricMono(13))
        .foregroundStyle(GainsColor.ink)
        .frame(width: 64, alignment: .leading)
      Text(RunGoalPlanGenerator.paceLabel(session.targetPaceSeconds))
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
      Spacer()
    }
    .padding(.vertical, 10)
  }

  // MARK: Save

  private var saveButton: some View {
    Button(action: save) {
      HStack(spacing: 10) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16, weight: .semibold))
        Text(existing == nil ? "Plan starten" : "Plan aktualisieren")
          .font(GainsFont.label(13))
          .tracking(1.4)
      }
      .foregroundStyle(canSave ? GainsColor.onLime : GainsColor.softInk)
      .frame(maxWidth: .infinity)
      .frame(height: 56)
      .background(canSave ? GainsColor.lime : GainsColor.card)
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      .shadow(
        color: canSave ? GainsColor.lime.opacity(0.35) : .clear,
        radius: 12, x: 0, y: 4
      )
    }
    .buttonStyle(.plain)
    .disabled(!canSave)
  }

  private func save() {
    guard canSave else { return }
    store.setRunGoalPlan(
      title: title,
      targetDistanceKm: distanceKm,
      targetPaceSeconds: paceTotalSeconds,
      targetDate: targetDate,
      weeklyBaseKm: weeklyBaseKm,
      sessionsPerWeek: sessionsPerWeek
    )
    dismiss()
  }
}

// MARK: - Detail Sheet (alle Wochen)

struct RunGoalPlanDetailSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: GainsStore

  let plan: RunGoalPlan
  let onEdit: () -> Void

  /// Liest den Plan aktiv aus dem Store, damit Toggle-Aktionen sofort
  /// neu rendern. Falls der Nutzer mittendrin den Plan löscht, fällt das
  /// Sheet auf die initial übergebene Snapshot-Variante zurück.
  private var livePlan: RunGoalPlan { store.runGoalPlan ?? plan }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          headerBlock
          summaryStats
          weeksSection
        }
        .padding(20)
      }
      .background(GainsColor.background.ignoresSafeArea())
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            onEdit()
          } label: {
            Image(systemName: "slider.horizontal.3")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(GainsColor.ink)
              .frame(width: 32, height: 32)
              .background(GainsColor.card)
              .clipShape(Circle())
          }
        }
      }
    }
  }

  private var headerBlock: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(livePlan.displayTitle)
        .font(GainsFont.title(28))
        .foregroundStyle(GainsColor.ink)
      Text("Ziel \(livePlan.targetDate.formatted(date: .long, time: .omitted))")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
  }

  private var summaryStats: some View {
    HStack(spacing: 0) {
      summaryCell(
        label: "DISTANZ",
        value: String(format: "%.1f", livePlan.targetDistanceKm),
        unit: "km"
      )
      Rectangle().fill(GainsColor.border.opacity(0.4)).frame(width: 1, height: 38)
      summaryCell(
        label: "PACE",
        value: RunGoalPlanGenerator.paceLabel(livePlan.targetPaceSeconds)
          .replacingOccurrences(of: " /km", with: ""),
        unit: "/km"
      )
      Rectangle().fill(GainsColor.border.opacity(0.4)).frame(width: 1, height: 38)
      summaryCell(label: "WOCHEN", value: "\(livePlan.totalWeeks)", unit: "")
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 12)
    .background(GainsColor.card)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func summaryCell(label: String, value: String, unit: String) -> some View {
    VStack(spacing: 4) {
      Text(label)
        .font(GainsFont.eyebrow(9))
        .tracking(1.4)
        .foregroundStyle(GainsColor.softInk)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(value)
          .font(GainsFont.metricMono(18))
          .foregroundStyle(GainsColor.ink)
        if !unit.isEmpty {
          Text(unit)
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var weeksSection: some View {
    let weekIdx = livePlan.currentWeekIndex()
    return VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["WOCHEN", "ÜBERSICHT"],
        primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk
      )

      ForEach(0..<livePlan.totalWeeks, id: \.self) { week in
        weekCard(weekIndex: week, isCurrent: week == weekIdx)
      }
    }
  }

  private func weekCard(weekIndex: Int, isCurrent: Bool) -> some View {
    let sessions = livePlan.sessions(inWeek: weekIndex)
    let phase = sessions.first?.phase ?? .base
    let totalKm = sessions.reduce(0) { $0 + $1.distanceKm }
    let done = sessions.filter(\.isCompleted).count

    return VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text("WOCHE \(weekIndex + 1) · \(phase.eyebrow)")
          .font(GainsFont.eyebrow(10))
          .tracking(1.4)
          .foregroundStyle(isCurrent ? GainsColor.lime : GainsColor.softInk)
        Spacer()
        Text("\(done)/\(sessions.count) · \(String(format: "%.0f", totalKm)) km")
          .font(GainsFont.eyebrow(9))
          .tracking(1.0)
          .foregroundStyle(GainsColor.softInk)
      }

      VStack(spacing: 0) {
        ForEach(Array(sessions.enumerated()), id: \.element.id) { idx, session in
          detailRow(session)
          if idx < sessions.count - 1 {
            Divider()
              .background(GainsColor.border.opacity(0.35))
              .padding(.horizontal, 6)
          }
        }
      }
    }
    .padding(14)
    .background(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(isCurrent ? GainsColor.lime.opacity(0.06) : GainsColor.card)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(
          isCurrent ? GainsColor.lime.opacity(0.4) : GainsColor.border.opacity(0.4),
          lineWidth: isCurrent ? 1 : 0.6
        )
    )
  }

  private func detailRow(_ session: PlannedRunSession) -> some View {
    HStack(spacing: 12) {
      Button {
        store.togglePlanSessionCompletion(session.id)
      } label: {
        Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(session.isCompleted ? GainsColor.moss : GainsColor.lime)
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 2) {
        Text(session.kind.title)
          .font(GainsFont.title(14))
          .foregroundStyle(session.isCompleted ? GainsColor.softInk : GainsColor.ink)
          .strikethrough(session.isCompleted, color: GainsColor.softInk)
        HStack(spacing: 6) {
          Text(weekdayMonthLabel(session.date))
            .font(GainsFont.eyebrow(9))
            .tracking(1.0)
            .foregroundStyle(GainsColor.softInk)
          Text("·")
            .foregroundStyle(GainsColor.softInk.opacity(0.4))
          Text(String(format: "%.1f km", session.distanceKm))
            .font(GainsFont.body(11))
            .foregroundStyle(GainsColor.softInk)
          if !session.notes.isEmpty {
            Text("·")
              .foregroundStyle(GainsColor.softInk.opacity(0.4))
            Text(session.notes)
              .font(GainsFont.body(11))
              .foregroundStyle(GainsColor.softInk)
              .lineLimit(1)
          }
        }
      }

      Spacer()

      Text(RunGoalPlanGenerator.paceLabel(session.targetPaceSeconds)
        .replacingOccurrences(of: " /km", with: ""))
        .font(GainsFont.metricMono(13))
        .foregroundStyle(GainsColor.ink)
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 10)
  }

  private func weekdayMonthLabel(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.dateFormat = "EEE d. MMM"
    return f.string(from: date).uppercased()
  }
}
