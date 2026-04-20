import SwiftUI

private enum CommunitySurface: String, CaseIterable, Identifiable {
  case feed
  case mine
  case circles

  var id: Self { self }

  var title: String {
    switch self {
    case .feed: return "For You"
    case .mine: return "Meine Posts"
    case .circles: return "Kontakte"
    }
  }
}

struct CommunityView: View {
  @EnvironmentObject private var store: GainsStore
  let viewModel: CommunityViewModel
  @State private var selectedFeedType: CommunityPostType = .all
  @State private var selectedSurface: CommunitySurface = .feed
  private let ownHandle = "@julius.gains"

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        screenHeader(
          eyebrow: "COMMUNITY / SOCIAL",
          title: "Fortschritt, den man teilt",
          subtitle: viewModel.headline
        )

        surfacePicker
        visibleContent
      }
    }
    .onAppear {
      store.refreshContactsAuthorizationStatus()
      if store.hasContactsAccess && store.communityContacts.isEmpty {
        store.loadCommunityContacts()
      }
    }
  }

  private var ownPosts: [CommunityPost] {
    store.communityPosts.filter { $0.handle == ownHandle }
  }

  private var forYouPosts: [CommunityPost] {
    store.communityPosts.filter { $0.handle != ownHandle }
  }

  private var filteredPosts: [CommunityPost] {
    let sourcePosts = selectedSurface == .mine ? ownPosts : forYouPosts
    guard selectedFeedType != .all else { return sourcePosts }
    return sourcePosts.filter { $0.type == selectedFeedType }
  }

  private var surfacePicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        ForEach(CommunitySurface.allCases) { surface in
          Button {
            selectedSurface = surface
          } label: {
            Text(surface.title)
              .font(GainsFont.label(10))
              .tracking(1.5)
              .foregroundStyle(selectedSurface == surface ? GainsColor.ink : GainsColor.softInk)
              .padding(.horizontal, 16)
              .frame(height: 38)
              .background(selectedSurface == surface ? GainsColor.lime : GainsColor.card)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.vertical, 2)
    }
  }

  @ViewBuilder
  private var visibleContent: some View {
    switch selectedSurface {
    case .feed:
      VStack(alignment: .leading, spacing: 22) {
        forYouIntroSection
        filterSection
        feedSection(
          emptyTitle: "Noch nichts in deiner For You Page",
          emptyDescription:
            "Sobald neue Workouts, Läufe oder Progress-Updates reinkommen, siehst du sie hier zuerst."
        )
      }
    case .mine:
      VStack(alignment: .leading, spacing: 22) {
        recentActivitySection
        filterSection
        feedSection(
          emptyTitle: "Du hast noch keine eigenen Posts",
          emptyDescription:
            "Teile dein letztes Workout, deinen letzten Lauf oder ein Progress-Update."
        )
        composerSection
      }
    case .circles:
      VStack(alignment: .leading, spacing: 22) {
        contactsSection
        challengeCard
      }
    }
  }

  private var recentActivitySection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["LETZTE", "AKTIVITÄTEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(spacing: 10) {
        recentActivityCard(
          title: store.lastCompletedWorkout?.title ?? "Noch kein Workout geteilt",
          subtitle: store.lastCompletedWorkout.map {
            "\($0.completedSets)/\($0.totalSets) Sätze · \(Int($0.volume)) kg Volumen"
          } ?? "Dein nächstes Workout landet hier.",
          badge: "WORKOUT",
          systemImage: "dumbbell.fill",
          actionTitle: "Workout teilen",
          isEnabled: store.lastCompletedWorkout != nil,
          action: store.shareLatestWorkout
        )

        recentActivityCard(
          title: store.latestCompletedRun?.title ?? "Noch kein Lauf geteilt",
          subtitle: store.latestCompletedRun.map {
            "\(String(format: "%.1f", $0.distanceKm)) km · \(paceLabel($0.averagePaceSeconds)) · \($0.averageHeartRate) bpm"
          } ?? "Dein nächster Lauf landet hier.",
          badge: "RUN",
          systemImage: "figure.run",
          actionTitle: "Lauf teilen",
          isEnabled: store.latestCompletedRun != nil,
          action: store.shareLatestRun
        )
      }
    }
  }

  private var challengeCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      SlashLabel(
        parts: ["LIVE", "CHALLENGE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.card.opacity(0.75))

      Text(viewModel.challengeTitle)
        .font(GainsFont.title(28))
        .foregroundStyle(GainsColor.card)

      Text("\(store.challengeParticipantsCount) aktive Mitglieder")
        .font(GainsFont.body())
        .foregroundStyle(GainsColor.card.opacity(0.8))

      HStack(spacing: 8) {
        ForEach(viewModel.challengeBenefits, id: \.self) { benefit in
          Text(benefit)
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(GainsColor.card.opacity(0.82))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(GainsColor.card.opacity(0.08))
            .clipShape(Capsule())
        }
      }

      Button {
        store.toggleChallengeJoined()
      } label: {
        Text(store.joinedChallenge ? "Challenge verlassen" : "Challenge beitreten")
          .font(GainsFont.label(12))
          .tracking(1.5)
          .foregroundStyle(store.joinedChallenge ? GainsColor.ink : GainsColor.lime)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(store.joinedChallenge ? GainsColor.lime : GainsColor.card.opacity(0.14))
          .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
              .stroke(
                store.joinedChallenge ? GainsColor.lime : GainsColor.card.opacity(0.28),
                lineWidth: 1)
          }
          .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(20)
    .background(GainsColor.ink)
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
  }

  private var forYouIntroSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["FOR", "YOU"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      LazyVGrid(
        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10
      ) {
        communitySummaryCard(title: "Feed", value: "\(forYouPosts.count)")
        communitySummaryCard(
          title: "Workouts", value: "\(forYouPosts.filter { $0.type == .workout }.count)")
        communitySummaryCard(
          title: "Läufe", value: "\(forYouPosts.filter { $0.type == .run }.count)")
        communitySummaryCard(
          title: "Progress", value: "\(forYouPosts.filter { $0.type == .progress }.count)")
      }
    }
  }

  private var contactsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["KONTAKTE", "COMMUNITY"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 14) {
        Text(store.contactsStatusTitle)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        if store.canRequestContactsAccess {
          Button {
            store.requestContactsAccess()
          } label: {
            Text("Kontakte freigeben")
              .font(GainsFont.label(11))
              .tracking(1.4)
              .foregroundStyle(GainsColor.lime)
              .frame(maxWidth: .infinity)
              .frame(height: 44)
              .background(GainsColor.ink)
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          }
          .buttonStyle(.plain)
        } else if store.hasContactsAccess && !store.communityContacts.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
              ForEach(store.communityContacts) { contact in
                communityContactCard(contact)
              }
            }
            .padding(.vertical, 2)
          }
        }
      }
      .padding(18)
      .gainsCardStyle()
    }
  }

  private var composerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["SCHNELL", "POSTEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(store.communityComposerActions) { action in
            Button {
              store.createCommunityPost(from: action)
              selectedFeedType = .all
            } label: {
              Label(action.title, systemImage: action.systemImage)
                .font(GainsFont.label(10))
                .tracking(1.5)
                .foregroundStyle(GainsColor.ink)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(GainsColor.elevated)
                .overlay {
                  Capsule()
                    .stroke(GainsColor.lime.opacity(0.45), lineWidth: 1)
                }
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
  }

  private var filterSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["FEED", "FILTER"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 10) {
          ForEach(CommunityPostType.allCases, id: \.self) { type in
            Button {
              selectedFeedType = type
            } label: {
              Text(type.title)
                .font(GainsFont.label(10))
                .tracking(1.5)
                .foregroundStyle(selectedFeedType == type ? GainsColor.ink : GainsColor.softInk)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(selectedFeedType == type ? GainsColor.lime : GainsColor.card)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 2)
      }
    }
  }

  @ViewBuilder
  private func feedSection(emptyTitle: String, emptyDescription: String) -> some View {
    if filteredPosts.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text(emptyTitle)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)

        Text(emptyDescription)
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(18)
      .gainsCardStyle()
    } else {
      VStack(alignment: .leading, spacing: 14) {
        ForEach(filteredPosts) { post in
          CommunityFeedCard(post: post)
            .environmentObject(store)
        }
      }
    }
  }

  private func communitySummaryCard(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title.uppercased())
        .font(GainsFont.label(9))
        .tracking(2)
        .foregroundStyle(GainsColor.softInk)

      Text(value)
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .frame(minHeight: 92, alignment: .leading)
    .padding(14)
    .gainsCardStyle()
  }

  private func recentActivityCard(
    title: String,
    subtitle: String,
    badge: String,
    systemImage: String,
    actionTitle: String,
    isEnabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Circle()
          .fill(GainsColor.lime.opacity(0.32))
          .frame(width: 42, height: 42)
          .overlay {
            Image(systemName: systemImage)
              .foregroundStyle(GainsColor.moss)
          }

        VStack(alignment: .leading, spacing: 6) {
          Text(title)
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)

          Text(subtitle)
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
            .lineLimit(1)
        }

        Spacer()

        activityBadge(badge)
      }

      Button(action: action) {
        Text(actionTitle)
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(isEnabled ? GainsColor.lime : GainsColor.softInk)
          .frame(maxWidth: .infinity)
          .frame(height: 42)
          .background(isEnabled ? GainsColor.ink : GainsColor.card)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(!isEnabled)
    }
    .padding(16)
    .gainsCardStyle()
  }

  private func activityBadge(_ text: String) -> some View {
    Text(text)
      .font(GainsFont.label(9))
      .tracking(1.8)
      .foregroundStyle(GainsColor.moss)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(GainsColor.lime.opacity(0.4))
      .clipShape(Capsule())
  }

  private func paceLabel(_ seconds: Int) -> String {
    guard seconds > 0 else { return "--:-- /km" }
    let minutes = seconds / 60
    let remainingSeconds = seconds % 60
    return String(format: "%d:%02d /km", minutes, remainingSeconds)
  }

  private func communityContactCard(_ contact: CommunityContact) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Circle()
        .fill(GainsColor.ink)
        .frame(width: 44, height: 44)
        .overlay {
          Text(contact.initials)
            .font(GainsFont.label(12))
            .foregroundStyle(GainsColor.lime)
        }

      Text(contact.displayName)
        .font(GainsFont.title(16))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)

      Text(contact.subtitle)
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(1)
    }
    .frame(width: 150, alignment: .leading)
    .padding(14)
    .gainsCardStyle(GainsColor.lime.opacity(0.18))
  }
}

private struct CommunityFeedCard: View {
  @EnvironmentObject private var store: GainsStore
  let post: CommunityPost

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(post.author)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)

          HStack(spacing: 8) {
            Text(post.handle.uppercased())
              .font(GainsFont.label(9))
              .tracking(1.8)
              .foregroundStyle(GainsColor.softInk)

            Text(post.timeAgo.uppercased())
              .font(GainsFont.label(9))
              .tracking(1.8)
              .foregroundStyle(GainsColor.softInk)
          }
        }

        Spacer()

        feedBadge(post.type.title.uppercased())
      }

      postArtwork

      Text(post.title)
        .font(GainsFont.title(22))
        .foregroundStyle(GainsColor.ink)
        .lineLimit(2)

      Text(post.detail)
        .font(GainsFont.body(14))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(2)

      HStack(spacing: 10) {
        ForEach(post.highlightMetrics) { metric in
          VStack(alignment: .leading, spacing: 4) {
            Text(metric.value)
              .font(GainsFont.title(16))
              .foregroundStyle(GainsColor.ink)

            Text(metric.label)
              .font(GainsFont.label(9))
              .tracking(1.7)
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .background(GainsColor.background.opacity(0.8))
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
      }

      HStack(spacing: 10) {
        Button {
          store.toggleLike(postID: post.id)
        } label: {
          feedAction(
            title: "\(post.reactions + (store.likedPostIDs.contains(post.id) ? 1 : 0))",
            systemImage: store.likedPostIDs.contains(post.id) ? "heart.fill" : "heart",
            isActive: store.likedPostIDs.contains(post.id)
          )
        }
        .buttonStyle(.plain)

        Button {
          store.toggleComment(postID: post.id)
        } label: {
          feedAction(
            title: "\(post.comments + (store.commentedPostIDs.contains(post.id) ? 1 : 0))",
            systemImage: "bubble.right",
            isActive: store.commentedPostIDs.contains(post.id)
          )
        }
        .buttonStyle(.plain)

        Button {
          store.toggleShare(postID: post.id)
        } label: {
          feedAction(
            title: "\(post.shares + (store.sharedPostIDs.contains(post.id) ? 1 : 0))",
            systemImage: "arrowshape.turn.up.right",
            isActive: store.sharedPostIDs.contains(post.id)
          )
        }
        .buttonStyle(.plain)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .gainsCardStyle()
  }

  private var postArtwork: some View {
    ZStack(alignment: .bottomLeading) {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(
          LinearGradient(
            colors: artworkColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(height: 220)
        .overlay(alignment: .topTrailing) {
          Circle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 110, height: 110)
            .offset(x: -18, y: 18)
        }
        .overlay {
          Image(systemName: post.placeholderSymbol)
            .font(.system(size: 72, weight: .medium))
            .foregroundStyle(GainsColor.card)
        }

      Text("\(post.type.title)-Post")
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.card.opacity(0.8))
        .padding(16)
    }
  }

  private var artworkColors: [Color] {
    switch post.type {
    case .all:
      return [GainsColor.lime, GainsColor.ink]
    case .workout:
      return [Color(hex: "C1D65A"), GainsColor.ink]
    case .run:
      return [Color(hex: "7AB6A7"), GainsColor.ink]
    case .progress:
      return [Color(hex: "DDA869"), GainsColor.ink]
    }
  }

  private func feedBadge(_ text: String) -> some View {
    Text(text)
      .font(GainsFont.label(9))
      .tracking(1.8)
      .foregroundStyle(GainsColor.moss)
      .padding(.horizontal, 10)
      .frame(height: 24)
      .background(GainsColor.lime.opacity(0.4))
      .clipShape(Capsule())
  }

  private func feedAction(title: String, systemImage: String, isActive: Bool) -> some View {
    Label(title, systemImage: systemImage)
      .font(GainsFont.label(10))
      .tracking(1.4)
      .foregroundStyle(isActive ? GainsColor.moss : GainsColor.softInk)
      .frame(height: 36)
      .padding(.horizontal, 12)
      .background(isActive ? GainsColor.lime.opacity(0.45) : GainsColor.background.opacity(0.85))
      .clipShape(Capsule())
  }
}
