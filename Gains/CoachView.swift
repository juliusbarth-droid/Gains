import SwiftUI

// MARK: - CoachView (DEPRECATED, Phase B)
//
// Diese View ist aktuell **nicht** in der App-Navigation eingebunden.
// In der laufenden Version werden Coach-Inhalte (Headline, Recommendations)
// inline auf dem Home-Screen und im PLAN-Tab gerendert. Diese eigenständige
// CoachView bleibt als Referenz für ein späteres dediziertes Coach-Surface
// (Phase B) erhalten — sie nicht löschen, aber auch nicht versuchen, sie
// per Quicklink zu erreichen, das endete in der Vergangenheit damit, dass
// Buttons mit dem Label "Coach" in Wahrheit ins Gym gesprungen sind.

struct CoachView: View {
  @EnvironmentObject private var store: GainsStore
  let viewModel: CoachViewModel

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
        screenHeader(
          eyebrow: "COACH / TAGESPLAN",
          title: "Dein AI Coach",
          subtitle:
            "\(viewModel.coachName) priorisiert heute Training, Recovery und Ernährung mit echtem Kontext."
        )

        coachFocusCard
        scoreSection
        routineTargetsSection
        checkInSection
        recommendationSection
      }
    }
  }

  private var coachFocusCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      SlashLabel(
        parts: ["HEUTE", "FOKUS"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      Text(viewModel.focus)
        .font(GainsFont.title(28))
        .foregroundStyle(GainsColor.ink)

      Text("Nicht generisch, sondern aus deinen Routinen, Fortschritten und Biomarkern abgeleitet.")
        .font(GainsFont.body())
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(GainsSpacing.l)
    .background(GainsColor.ctaSurface)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
    .overlay(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
        .stroke(GainsColor.lime.opacity(0.22), lineWidth: 1)
    }
    .foregroundStyle(GainsColor.onCtaSurface)
  }

  private var scoreSection: some View {
    HStack(spacing: GainsSpacing.s) {
      CoachMetricCard(
        title: "Ernährung", value: "\(viewModel.nutritionAdherence)%", subtitle: "Plan erfüllt")
      CoachMetricCard(
        title: "Recovery", value: "\(viewModel.recoveryScore)", subtitle: "Readiness Score")
    }
  }

  private var routineTargetsSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["ZIELE", "HEUTE"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      HStack(spacing: GainsSpacing.s) {
        CoachMetricCard(
          title: "Schritte", value: "\(viewModel.stepGoal / 1000)k", subtitle: "Tagesziel")
        CoachMetricCard(
          title: "Water", value: String(format: "%.1fL", viewModel.hydrationGoalLiters),
          subtitle: "Hydration")
        CoachMetricCard(
          title: "Schlaf", value: String(format: "%.1fh", viewModel.sleepTargetHours),
          subtitle: "Recovery")
      }
    }
  }

  private var checkInSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["CHECK-IN", "KONSISTENZ"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ForEach(viewModel.checkIns) { item in
        Button {
          store.toggleCoachCheckIn(item.id)
        } label: {
          HStack(spacing: GainsSpacing.s) {
            Image(
              systemName: store.completedCoachCheckInIDs.contains(item.id)
                ? "checkmark.circle.fill" : "circle"
            )
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(
              store.completedCoachCheckInIDs.contains(item.id) ? GainsColor.moss : GainsColor.border
            )

            VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
              Text(item.title)
                .font(GainsFont.title(18))
                .foregroundStyle(GainsColor.ink)

              Text(item.detail)
                .font(GainsFont.body(14))
                .foregroundStyle(GainsColor.softInk)
            }

            Spacer()
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(GainsSpacing.m)
          .background(
            store.completedCoachCheckInIDs.contains(item.id)
              ? GainsColor.lime.opacity(0.45) : GainsColor.card
          )
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var recommendationSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["AKTIONEN", "PRIORITÄT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ForEach(viewModel.recommendations, id: \.self) { recommendation in
        HStack(alignment: .top, spacing: GainsSpacing.tight) {
          Circle()
            .fill(GainsColor.lime)
            .frame(width: 10, height: 10)
            .padding(.top, GainsSpacing.xs)

          Text(recommendation)
            .font(GainsFont.body())
            .foregroundStyle(GainsColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(GainsSpacing.m)
        .gainsCardStyle()
      }
    }
  }
}

private struct CoachMetricCard: View {
  let title: String
  let value: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
      Text(title.uppercased())
        .font(GainsFont.label(10))
        .tracking(2.5)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.display(34))
        .foregroundStyle(GainsColor.ink)

      Text(subtitle)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
    .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
    .padding(GainsSpacing.l)
    .gainsCardStyle()
  }
}
