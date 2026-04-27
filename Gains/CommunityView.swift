import SwiftUI

private enum CommunitySurface: String, CaseIterable, Identifiable {
  case feed
  case mine
  case circles
  case forum
  case meetups
  case settings

  var id: Self { self }

  var title: String {
    switch self {
    case .feed: return "For You"
    case .mine: return "Meine Posts"
    case .circles: return "Kontakte"
    case .forum: return "Forum"
    case .meetups: return "Treffs"
    case .settings: return "Privatsphäre"
    }
  }

  var systemImage: String {
    switch self {
    case .feed: return "sparkles"
    case .mine: return "person.crop.square"
    case .circles: return "person.2.fill"
    case .forum: return "bubble.left.and.bubble.right.fill"
    case .meetups: return "calendar.badge.plus"
    case .settings: return "lock.shield.fill"
    }
  }
}

struct CommunityView: View {
  @EnvironmentObject private var store: GainsStore
  let viewModel: CommunityViewModel
  @State private var selectedFeedType: CommunityPostType = .all
  @State private var selectedSurface: CommunitySurface = .feed
  private let ownHandle = "@julius.gains"

  // A1b: Community ist bewusst noch nicht live. Backend, Auth und Moderation
  // kommen in Phase B. Statt Mock-Profile zu zeigen, präsentieren wir hier
  // eine ehrliche Coming-Soon-Surface.
  @AppStorage("gains_communityWaitlist") private var isOnWaitlist = false

  var body: some View {
    CommunityComingSoonView(isOnWaitlist: $isOnWaitlist)
  }

  // MARK: - Legacy (Phase B reaktivieren)
  //
  // Die Surface- und Feed-Logik unten bleibt erhalten für die Reaktivierung,
  // sobald das Backend in Phase B steht. Aktuell nicht aufgerufen.
  @ViewBuilder
  private var legacyBody: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 22) {
        screenHeader(
          eyebrow: "CREW / CONNECTION",
          title: "Fortschritt im Feed",
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
            HStack(spacing: 6) {
              Image(systemName: surface.systemImage)
                .font(.system(size: 11, weight: .semibold))
              Text(surface.title)
                .font(GainsFont.label(10))
                .tracking(1.5)
            }
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
      VStack(alignment: .leading, spacing: 18) {
        featuredFeedHeader
        challengeCard
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
        composerSection
        filterSection
        feedSection(
          emptyTitle: "Du hast noch keine eigenen Posts",
          emptyDescription:
            "Teile dein letztes Workout, deinen letzten Lauf oder ein Progress-Update."
        )
      }
    case .circles:
      VStack(alignment: .leading, spacing: 22) {
        contactsSection
        challengeCard
      }
    case .forum:
      ForumSurface()
    case .meetups:
      MeetupSurface()
    case .settings:
      SocialSettingsSurface()
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
    .background(GainsColor.ctaSurface)
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
  }

  private var featuredFeedHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      SlashLabel(
        parts: ["FEED", "FIRST"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: 10) {
        Text(store.communityHighlightHeadline)
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        Text("Beiträge stehen hier im Mittelpunkt. Filter und Kontakte bleiben erhalten, treten aber hinter dem Feed zurück.")
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)
      }
      .padding(18)
      .gainsCardStyle()
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
              .background(GainsColor.ctaSurface)
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
          .background(isEnabled ? GainsColor.ctaSurface : GainsColor.card)
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
        .fill(GainsColor.ctaSurface)
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
      return [GainsColor.lime, GainsColor.ctaSurface]
    case .workout:
      return [Color(hex: "C1D65A"), GainsColor.ctaSurface]
    case .run:
      return [Color(hex: "7AB6A7"), GainsColor.ctaSurface]
    case .progress:
      return [Color(hex: "DDA869"), GainsColor.ctaSurface]
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

// MARK: - Forum

private struct ForumSurface: View {
  @EnvironmentObject private var store: GainsStore
  @State private var selectedCategory: ForumCategory? = nil
  @State private var showingComposer = false
  @State private var openThreadID: UUID? = nil

  private var visibleThreads: [ForumThread] {
    if let category = selectedCategory {
      return store.threads(in: category)
    }
    return store.forumThreads
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 10) {
        SlashLabel(
          parts: ["FORUM", "AUSTAUSCH"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Text("Themen, Tipps, lokale Sportangebote")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
        Text("Frage Empfehlungen für Gyms, teile Ernährungs-Tricks oder finde lokale Lauftreffs.")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      categoryFilter

      Button {
        showingComposer = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "plus.bubble.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text("Neuen Thread starten")
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(GainsColor.lime)
          Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(GainsColor.ctaSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)

      if visibleThreads.isEmpty {
        emptyState
      } else {
        VStack(spacing: 12) {
          ForEach(visibleThreads) { thread in
            ForumThreadCard(
              thread: thread,
              isExpanded: openThreadID == thread.id,
              onToggle: {
                openThreadID = openThreadID == thread.id ? nil : thread.id
              }
            )
          }
        }
      }
    }
    .sheet(isPresented: $showingComposer) {
      ForumComposerSheet()
        .environmentObject(store)
    }
  }

  private var categoryFilter: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 10) {
        categoryChip(label: "Alle", systemImage: "tray.full", isSelected: selectedCategory == nil) {
          selectedCategory = nil
        }
        ForEach(ForumCategory.allCases) { category in
          categoryChip(
            label: category.title,
            systemImage: category.systemImage,
            isSelected: selectedCategory == category
          ) {
            selectedCategory = category
          }
        }
      }
      .padding(.vertical, 2)
    }
  }

  private func categoryChip(
    label: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: systemImage)
          .font(.system(size: 11, weight: .semibold))
        Text(label)
          .font(GainsFont.label(10))
          .tracking(1.4)
      }
      .foregroundStyle(isSelected ? GainsColor.ink : GainsColor.softInk)
      .padding(.horizontal, 14)
      .frame(height: 36)
      .background(isSelected ? GainsColor.lime : GainsColor.card)
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Hier ist es noch ruhig")
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)
      Text("Stell die erste Frage in dieser Kategorie und gib der Community den Anstoß.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }
}

private struct ForumThreadCard: View {
  @EnvironmentObject private var store: GainsStore
  let thread: ForumThread
  let isExpanded: Bool
  let onToggle: () -> Void
  @State private var replyDraft: String = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(thread.category.title.uppercased())
            .font(GainsFont.label(9))
            .tracking(1.7)
            .foregroundStyle(GainsColor.moss)
          Text(thread.title)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
        }
        Spacer()
        if let location = thread.location {
          HStack(spacing: 4) {
            Image(systemName: "mappin")
              .font(.system(size: 10, weight: .semibold))
            Text(location)
              .font(GainsFont.label(9))
              .tracking(1.2)
          }
          .foregroundStyle(GainsColor.softInk)
          .padding(.horizontal, 8)
          .frame(height: 22)
          .background(GainsColor.background.opacity(0.85))
          .clipShape(Capsule())
        }
      }

      Text(thread.body)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(isExpanded ? nil : 3)

      HStack(spacing: 12) {
        Label(thread.author, systemImage: "person.fill")
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)

        Text(relativeTimestamp(for: thread.createdAt))
          .font(GainsFont.label(10))
          .tracking(1.2)
          .foregroundStyle(GainsColor.softInk)

        Spacer()

        Button {
          store.toggleForumLike(threadID: thread.id)
        } label: {
          Label("\(thread.likeCount)", systemImage: "hand.thumbsup.fill")
            .font(GainsFont.label(10))
            .tracking(1.2)
            .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)

        Button(action: onToggle) {
          Label("\(thread.replies.count)", systemImage: "bubble.right")
            .font(GainsFont.label(10))
            .tracking(1.2)
            .foregroundStyle(GainsColor.moss)
        }
        .buttonStyle(.plain)
      }

      if isExpanded {
        VStack(alignment: .leading, spacing: 10) {
          if thread.replies.isEmpty {
            Text("Noch keine Antworten – sei die Erste oder der Erste.")
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.softInk)
          } else {
            ForEach(thread.replies) { reply in
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Text(reply.author)
                    .font(GainsFont.label(10))
                    .tracking(1.2)
                    .foregroundStyle(GainsColor.ink)
                  Text(relativeTimestamp(for: reply.createdAt))
                    .font(GainsFont.label(9))
                    .tracking(1)
                    .foregroundStyle(GainsColor.softInk)
                }
                Text(reply.body)
                  .font(GainsFont.body(13))
                  .foregroundStyle(GainsColor.ink)
              }
              .padding(12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(GainsColor.background.opacity(0.7))
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
          }

          HStack(spacing: 10) {
            TextField("Antwort schreiben…", text: $replyDraft, axis: .vertical)
              .lineLimit(1...4)
              .font(GainsFont.body(13))
              .padding(.horizontal, 12)
              .padding(.vertical, 10)
              .background(GainsColor.background.opacity(0.9))
              .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
              store.addReply(to: thread.id, body: replyDraft)
              replyDraft = ""
            } label: {
              Image(systemName: "paperplane.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GainsColor.lime)
                .frame(width: 44, height: 44)
                .background(GainsColor.ctaSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }
}

private struct ForumComposerSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss
  @State private var category: ForumCategory = .general
  @State private var title: String = ""
  @State private var bodyText: String = ""
  @State private var location: String = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Kategorie") {
          Picker("Kategorie", selection: $category) {
            ForEach(ForumCategory.allCases) { item in
              Label(item.title, systemImage: item.systemImage).tag(item)
            }
          }
          .pickerStyle(.menu)
          Text(category.subtitle)
            .font(GainsFont.body(12))
            .foregroundStyle(GainsColor.softInk)
        }
        Section("Thema") {
          TextField("Titel", text: $title)
          TextField("Beschreibung", text: $bodyText, axis: .vertical)
            .lineLimit(4...10)
        }
        Section("Ort (optional)") {
          TextField("z. B. Berlin Mitte", text: $location)
        }
      }
      .navigationTitle("Thread starten")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Posten") {
            store.createForumThread(
              category: category, title: title, body: bodyText,
              location: location.isEmpty ? nil : location)
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}

// MARK: - Meetups

private struct MeetupSurface: View {
  @EnvironmentObject private var store: GainsStore
  @State private var showingComposer = false

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 10) {
        SlashLabel(
          parts: ["TREFFS", "ZUSAMMEN"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Text("Verabrede dich mit der Community")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
        Text(
          "Lauftreff, gemeinsame Gym-Session oder Radtour – plane oder schließ dich an."
        )
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
      }

      Button {
        showingComposer = true
      } label: {
        HStack(spacing: 10) {
          Image(systemName: "calendar.badge.plus")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text("Neuen Treff erstellen")
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(GainsColor.lime)
          Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(GainsColor.ctaSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .buttonStyle(.plain)

      if store.upcomingMeetups.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Noch keine Treffs in der Pipeline")
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)
          Text("Plane den ersten Lauftreff oder die nächste Gym-Session und lade Kontakte ein.")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gainsCardStyle()
      } else {
        VStack(spacing: 12) {
          ForEach(store.upcomingMeetups) { meetup in
            MeetupCard(meetup: meetup)
          }
        }
      }
    }
    .sheet(isPresented: $showingComposer) {
      MeetupComposerSheet()
        .environmentObject(store)
    }
  }
}

private struct MeetupCard: View {
  @EnvironmentObject private var store: GainsStore
  let meetup: Meetup

  private var isJoined: Bool {
    meetup.participantHandles.contains("@julius.gains")
  }

  private var isFull: Bool {
    meetup.participantHandles.count >= meetup.maxParticipants
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top, spacing: 12) {
        Circle()
          .fill(GainsColor.lime.opacity(0.32))
          .frame(width: 44, height: 44)
          .overlay {
            Image(systemName: meetup.sport.systemImage)
              .foregroundStyle(GainsColor.moss)
          }

        VStack(alignment: .leading, spacing: 4) {
          Text(meetup.sport.title.uppercased())
            .font(GainsFont.label(9))
            .tracking(1.7)
            .foregroundStyle(GainsColor.moss)
          Text(meetup.title)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)
            .lineLimit(2)
        }

        Spacer()

        Text("\(meetup.participantHandles.count)/\(meetup.maxParticipants)")
          .font(GainsFont.label(10))
          .tracking(1.4)
          .foregroundStyle(GainsColor.moss)
          .padding(.horizontal, 10)
          .frame(height: 26)
          .background(GainsColor.lime.opacity(0.32))
          .clipShape(Capsule())
      }

      VStack(alignment: .leading, spacing: 6) {
        Label(meetup.locationName, systemImage: "mappin.and.ellipse")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        Label(meetupTimeLabel(meetup.startsAt), systemImage: "clock")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
        if let pace = meetup.pace {
          Label(pace, systemImage: "speedometer")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }
        Label("Host: \(meetup.hostName)", systemImage: "person.fill")
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
      }

      if !meetup.notes.isEmpty {
        Text(meetup.notes)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(3)
      }

      Button {
        store.toggleMeetupParticipation(meetupID: meetup.id)
      } label: {
        Text(buttonLabel)
          .font(GainsFont.label(11))
          .tracking(1.4)
          .foregroundStyle(buttonForeground)
          .frame(maxWidth: .infinity)
          .frame(height: 44)
          .background(buttonBackground)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(isFull && !isJoined)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private var buttonLabel: String {
    if isJoined { return "Zusage zurückziehen" }
    if isFull { return "Voll besetzt" }
    return "Mitmachen"
  }

  private var buttonForeground: Color {
    if isJoined { return GainsColor.ink }
    if isFull { return GainsColor.softInk }
    return GainsColor.lime
  }

  private var buttonBackground: Color {
    if isJoined { return GainsColor.lime }
    if isFull { return GainsColor.card }
    return GainsColor.ctaSurface
  }
}

private struct MeetupComposerSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss
  @State private var sport: MeetupSport = .run
  @State private var title: String = ""
  @State private var locationName: String = ""
  @State private var startsAt: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
  @State private var pace: String = ""
  @State private var notes: String = ""
  @State private var maxParticipants: Int = 6

  var body: some View {
    NavigationStack {
      Form {
        Section("Sportart") {
          Picker("Sportart", selection: $sport) {
            ForEach(MeetupSport.allCases) { item in
              Label(item.title, systemImage: item.systemImage).tag(item)
            }
          }
          .pickerStyle(.menu)
        }
        Section("Treff") {
          TextField("Titel", text: $title)
          TextField("Treffpunkt / Ort", text: $locationName)
          DatePicker("Start", selection: $startsAt, in: Date()...)
        }
        Section("Details") {
          TextField("Pace / Tempo (optional)", text: $pace)
          TextField("Notizen", text: $notes, axis: .vertical)
            .lineLimit(3...8)
          Stepper("Max. Teilnehmer: \(maxParticipants)", value: $maxParticipants, in: 2...30)
        }
      }
      .navigationTitle("Treff erstellen")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Speichern") {
            store.createMeetup(
              sport: sport,
              title: title,
              locationName: locationName,
              startsAt: startsAt,
              pace: pace.isEmpty ? nil : pace,
              notes: notes,
              maxParticipants: maxParticipants
            )
            dismiss()
          }
          .disabled(
            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}

// MARK: - Privacy / Sharing Settings

private struct SocialSettingsSurface: View {
  @EnvironmentObject private var store: GainsStore

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 10) {
        SlashLabel(
          parts: ["PRIVAT", "SPHÄRE"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Text("Was teilst du automatisch?")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
        Text(
          "Du entscheidest, ob Workouts, Läufe oder neue Personal Records automatisch in deinem Feed landen."
        )
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
      }

      VStack(alignment: .leading, spacing: 14) {
        SlashLabel(
          parts: ["AUTO", "TEILEN"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        toggleRow(
          title: "Workouts automatisch teilen",
          subtitle: "Beendete Sessions landen direkt im Community-Feed.",
          systemImage: "dumbbell.fill",
          isOn: Binding(
            get: { store.socialSharingSettings.autoShareWorkouts },
            set: { store.setAutoShareWorkouts($0) }
          )
        )

        toggleRow(
          title: "Läufe automatisch teilen",
          subtitle: "Strava-Style: Distanz, Pace und Herzfrequenz im Feed.",
          systemImage: "figure.run",
          isOn: Binding(
            get: { store.socialSharingSettings.autoShareRuns },
            set: { store.setAutoShareRuns($0) }
          )
        )

        toggleRow(
          title: "Neue PRs feiern",
          subtitle: "Schlägst du einen Personal Record, wird er als Progress-Post geteilt.",
          systemImage: "trophy.fill",
          isOn: Binding(
            get: { store.socialSharingSettings.autoSharePersonalRecords },
            set: { store.setAutoSharePersonalRecords($0) }
          )
        )

        toggleRow(
          title: "Standort bei Läufen teilen",
          subtitle: "Wenn aktiv: Strecke / Stadt erscheint mit dem Lauf-Post.",
          systemImage: "mappin.and.ellipse",
          isOn: Binding(
            get: { store.socialSharingSettings.shareLocationWithRuns },
            set: { store.setShareLocationWithRuns($0) }
          )
        )
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .gainsCardStyle()

      VStack(alignment: .leading, spacing: 14) {
        SlashLabel(
          parts: ["WER", "SIEHT"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        VStack(spacing: 10) {
          ForEach(SharingVisibility.allCases) { visibility in
            Button {
              store.setSharingVisibility(visibility)
            } label: {
              HStack(spacing: 12) {
                Image(systemName: visibility.systemImage)
                  .foregroundStyle(
                    store.socialSharingSettings.visibility == visibility
                      ? GainsColor.moss : GainsColor.softInk)
                VStack(alignment: .leading, spacing: 2) {
                  Text(visibility.title)
                    .font(GainsFont.title(16))
                    .foregroundStyle(GainsColor.ink)
                  Text(visibilityDescription(visibility))
                    .font(GainsFont.body(12))
                    .foregroundStyle(GainsColor.softInk)
                }
                Spacer()
                if store.socialSharingSettings.visibility == visibility {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(GainsColor.lime)
                }
              }
              .padding(14)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                store.socialSharingSettings.visibility == visibility
                  ? GainsColor.lime.opacity(0.18) : GainsColor.background.opacity(0.7)
              )
              .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .gainsCardStyle()
    }
  }

  private func visibilityDescription(_ visibility: SharingVisibility) -> String {
    switch visibility {
    case .onlyMe: return "Posts bleiben nur in deinem persönlichen Verlauf."
    case .friends: return "Nur Kontakte aus deinem Adressbuch sehen deine Posts."
    case .publicFeed: return "Posts landen in der globalen For-You-Page."
    }
  }

  private func toggleRow(
    title: String, subtitle: String, systemImage: String, isOn: Binding<Bool>
  ) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Circle()
        .fill(GainsColor.lime.opacity(0.32))
        .frame(width: 38, height: 38)
        .overlay {
          Image(systemName: systemImage)
            .foregroundStyle(GainsColor.moss)
        }

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        Text(subtitle)
          .font(GainsFont.body(12))
          .foregroundStyle(GainsColor.softInk)
      }

      Spacer()

      Toggle("", isOn: isOn)
        .labelsHidden()
        .tint(GainsColor.lime)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GainsColor.background.opacity(0.7))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

// MARK: - Helpers

private func relativeTimestamp(for date: Date) -> String {
  let formatter = RelativeDateTimeFormatter()
  formatter.locale = Locale(identifier: "de_DE")
  formatter.unitsStyle = .short
  return formatter.localizedString(for: date, relativeTo: Date())
}

private func meetupTimeLabel(_ date: Date) -> String {
  let formatter = DateFormatter()
  formatter.locale = Locale(identifier: "de_DE")
  formatter.dateFormat = "EE, d. MMM · HH:mm"
  return formatter.string(from: date) + " Uhr"
}

// MARK: - Coming Soon (Phase A)

struct CommunityComingSoonView: View {
  @Binding var isOnWaitlist: Bool

  private struct UpcomingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
  }

  private let features: [UpcomingFeature] = [
    UpcomingFeature(
      icon: "sparkles",
      title: "For-You-Feed",
      description: "Workouts, Läufe und Progress-Updates der Leute, denen du folgst — chronologisch, ohne Algorithmus-Tricks."
    ),
    UpcomingFeature(
      icon: "bubble.left.and.bubble.right.fill",
      title: "Forum & Threads",
      description: "Fragen zu Training, Ernährung und Recovery — moderiert, mit Reaktionen und Antworten."
    ),
    UpcomingFeature(
      icon: "calendar.badge.plus",
      title: "Meetups & Treffs",
      description: "Lokale Lauf- und Gym-Treffs mit Leuten in deiner Nähe."
    ),
    UpcomingFeature(
      icon: "person.2.wave.2.fill",
      title: "Kontakte",
      description: "Trainings-Buddies aus deinen Kontakten finden — komplett opt-in, ohne unaufgeforderte Profilsuche."
    )
  ]

  var body: some View {
    GainsScreen {
      VStack(alignment: .leading, spacing: 24) {
        screenHeader(
          eyebrow: "CREW / IN ARBEIT",
          title: "Community kommt bald."
        )
        intro
        waitlistCard
        featuresSection
        privacyNote
      }
    }
  }

  private var intro: some View {
    Text("Wir bauen den Community-Bereich Schritt für Schritt mit echtem Backend, sauberer Moderation und Datenschutz von Tag eins. Bis dahin zeigen wir hier nichts Erfundenes — versprochen.")
      .font(GainsFont.body(14))
      .foregroundStyle(GainsColor.softInk)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var waitlistCard: some View {
    Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
        isOnWaitlist.toggle()
      }
    } label: {
      HStack(alignment: .top, spacing: 14) {
        Image(systemName: isOnWaitlist ? "checkmark.circle.fill" : "bell.badge")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(isOnWaitlist ? GainsColor.lime : GainsColor.lime)
          .frame(width: 44, height: 44)
          .background(Circle().fill(GainsColor.lime.opacity(0.16)))

        VStack(alignment: .leading, spacing: 4) {
          Text(isOnWaitlist ? "Du bist auf der Warteliste" : "Sag mir Bescheid, wenn's losgeht")
            .font(GainsFont.title(17))
            .foregroundStyle(GainsColor.ink)
            .multilineTextAlignment(.leading)
          Text(isOnWaitlist
               ? "Sobald die Community live geht, bekommst du eine Benachrichtigung."
               : "Tippe hier, dann benachrichtigen wir dich beim Launch.")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
            .multilineTextAlignment(.leading)
        }

        Spacer()
      }
      .padding(16)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(
            isOnWaitlist ? GainsColor.lime.opacity(0.6) : GainsColor.border.opacity(0.5),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var featuresSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("WAS KOMMT")
        .font(GainsFont.label(10))
        .tracking(2.0)
        .foregroundStyle(GainsColor.softInk)

      VStack(spacing: 10) {
        ForEach(features) { feature in
          featureRow(feature)
        }
      }
    }
  }

  private func featureRow(_ feature: UpcomingFeature) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: feature.icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 40, height: 40)
        .background(Circle().fill(GainsColor.lime.opacity(0.12)))

      VStack(alignment: .leading, spacing: 4) {
        Text(feature.title)
          .font(GainsFont.title(16))
          .foregroundStyle(GainsColor.ink)
        Text(feature.description)
          .font(GainsFont.body(13))
          .foregroundStyle(GainsColor.softInk)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private var privacyNote: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: "lock.shield.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(GainsColor.moss)
        .padding(.top, 2)
      Text("Wenn die Community live geht, ist alles opt-in. Du teilst nur, was du explizit teilen willst — und kannst jeden Beitrag pseudonym posten.")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.mutedInk)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 4)
  }
}
