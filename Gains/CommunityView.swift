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
  @AppStorage(GainsKey.communityWaitlist) private var isOnWaitlist = false

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
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
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
      HStack(spacing: GainsSpacing.tight) {
        ForEach(CommunitySurface.allCases) { surface in
          Button {
            selectedSurface = surface
          } label: {
            HStack(spacing: GainsSpacing.xs) {
              Image(systemName: surface.systemImage)
                .font(.system(size: 11, weight: .semibold))
              Text(surface.title)
                .font(GainsFont.label(10))
                .tracking(1.5)
            }
            .foregroundStyle(selectedSurface == surface ? GainsColor.ink : GainsColor.softInk)
            .padding(.horizontal, GainsSpacing.m)
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
      VStack(alignment: .leading, spacing: GainsSpacing.l) {
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
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
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
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
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
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["LETZTE", "AKTIVITÄTEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(spacing: GainsSpacing.tight) {
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
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      SlashLabel(
        parts: ["LIVE", "CHALLENGE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.onCtaSurface.opacity(0.75))

      Text(viewModel.challengeTitle)
        .font(GainsFont.title(28))
        .foregroundStyle(GainsColor.onCtaSurface)

      Text("\(store.challengeParticipantsCount) aktive Mitglieder")
        .font(GainsFont.body())
        .foregroundStyle(GainsColor.onCtaSurface.opacity(0.8))

      HStack(spacing: GainsSpacing.xsPlus) {
        ForEach(viewModel.challengeBenefits, id: \.self) { benefit in
          Text(benefit)
            .font(GainsFont.label(9))
            .tracking(1.4)
            .foregroundStyle(GainsColor.onCtaSurface.opacity(0.82))
            .padding(.horizontal, GainsSpacing.tight)
            .frame(height: 26)
            .background(GainsColor.onCtaSurface.opacity(0.08))
            .clipShape(Capsule())
        }
      }

      Button {
        store.toggleChallengeJoined()
      } label: {
        Text(store.joinedChallenge ? "Challenge verlassen" : "Challenge beitreten")
          .font(GainsFont.label(12))
          .tracking(1.5)
          .foregroundStyle(store.joinedChallenge ? GainsColor.onLime : GainsColor.lime)
          .frame(maxWidth: .infinity)
          .frame(height: 48)
          .background(store.joinedChallenge ? GainsColor.lime : GainsColor.onCtaSurface.opacity(0.14))
          .overlay {
            RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
              .stroke(
                store.joinedChallenge ? GainsColor.lime : GainsColor.onCtaSurface.opacity(0.28),
                lineWidth: 1)
          }
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(GainsSpacing.l)
    .background(GainsColor.ctaSurface)
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous))
  }

  private var featuredFeedHeader: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["FEED", "FIRST"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: GainsSpacing.tight) {
        Text(store.communityHighlightHeadline)
          .font(GainsFont.title(24))
          .foregroundStyle(GainsColor.ink)
          .lineLimit(2)

        Text("Beiträge stehen hier im Mittelpunkt. Filter und Kontakte bleiben erhalten, treten aber hinter dem Feed zurück.")
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
          .lineLimit(3)
      }
      .padding(GainsSpacing.l)
      .gainsCardStyle()
    }
  }

  private var contactsSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["KONTAKTE", "COMMUNITY"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(alignment: .leading, spacing: GainsSpacing.m) {
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
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          }
          .buttonStyle(.plain)
        } else if store.hasContactsAccess && !store.communityContacts.isEmpty {
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GainsSpacing.tight) {
              ForEach(store.communityContacts) { contact in
                communityContactCard(contact)
              }
            }
            .padding(.vertical, 2)
          }
        }
      }
      .padding(GainsSpacing.l)
      .gainsCardStyle()
    }
  }

  private var composerSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["SCHNELL", "POSTEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.tight) {
          ForEach(store.communityComposerActions) { action in
            Button {
              store.createCommunityPost(from: action)
              selectedFeedType = .all
            } label: {
              Label(action.title, systemImage: action.systemImage)
                .font(GainsFont.label(10))
                .tracking(1.5)
                .foregroundStyle(GainsColor.ink)
                .padding(.horizontal, GainsSpacing.m)
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
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["FEED", "FILTER"], primaryColor: GainsColor.lime, secondaryColor: GainsColor.softInk
      )

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.tight) {
          ForEach(CommunityPostType.allCases, id: \.self) { type in
            Button {
              selectedFeedType = type
            } label: {
              Text(type.title)
                .font(GainsFont.label(10))
                .tracking(1.5)
                .foregroundStyle(selectedFeedType == type ? GainsColor.ink : GainsColor.softInk)
                .padding(.horizontal, GainsSpacing.m)
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
      VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
        Text(emptyTitle)
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)

        Text(emptyDescription)
          .font(GainsFont.body())
          .foregroundStyle(GainsColor.softInk)
      }
      .padding(GainsSpacing.l)
      .gainsCardStyle()
    } else {
      VStack(alignment: .leading, spacing: GainsSpacing.m) {
        ForEach(filteredPosts) { post in
          CommunityFeedCard(post: post)
            .environmentObject(store)
        }
      }
    }
  }

  private func communitySummaryCard(title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
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
    .padding(GainsSpacing.m)
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
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .top, spacing: GainsSpacing.s) {
        Circle()
          .fill(GainsColor.lime.opacity(0.32))
          .frame(width: 42, height: 42)
          .overlay {
            Image(systemName: systemImage)
              .foregroundStyle(GainsColor.moss)
          }

        VStack(alignment: .leading, spacing: GainsSpacing.xs) {
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
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(!isEnabled)
    }
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  private func activityBadge(_ text: String) -> some View {
    Text(text)
      .font(GainsFont.label(9))
      .tracking(1.8)
      .foregroundStyle(GainsColor.moss)
      .padding(.horizontal, GainsSpacing.tight)
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
    VStack(alignment: .leading, spacing: GainsSpacing.tight) {
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
    .padding(GainsSpacing.m)
    .gainsCardStyle(GainsColor.lime.opacity(0.18))
  }
}

private struct CommunityFeedCard: View {
  @EnvironmentObject private var store: GainsStore
  let post: CommunityPost

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack {
        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(post.author)
            .font(GainsFont.title(18))
            .foregroundStyle(GainsColor.ink)

          HStack(spacing: GainsSpacing.xsPlus) {
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

      HStack(spacing: GainsSpacing.tight) {
        ForEach(post.highlightMetrics) { metric in
          VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
            Text(metric.value)
              .font(GainsFont.title(16))
              .foregroundStyle(GainsColor.ink)

            Text(metric.label)
              .font(GainsFont.label(9))
              .tracking(1.7)
              .foregroundStyle(GainsColor.softInk)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(GainsSpacing.s)
          .background(GainsColor.background.opacity(0.8))
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
        }
      }

      HStack(spacing: GainsSpacing.tight) {
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
    .padding(GainsSpacing.m)
    .gainsCardStyle()
  }

  private var postArtwork: some View {
    ZStack(alignment: .bottomLeading) {
      RoundedRectangle(cornerRadius: GainsRadius.hero, style: .continuous)
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
            .foregroundStyle(GainsColor.onCtaSurface)
        }

      Text("\(post.type.title)-Post")
        .font(GainsFont.label(9))
        .tracking(1.8)
        .foregroundStyle(GainsColor.onCtaSurface.opacity(0.8))
        .padding(GainsSpacing.m)
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
      .padding(.horizontal, GainsSpacing.tight)
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
      .padding(.horizontal, GainsSpacing.s)
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
    VStack(alignment: .leading, spacing: GainsSpacing.l) {
      VStack(alignment: .leading, spacing: GainsSpacing.tight) {
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
        HStack(spacing: GainsSpacing.tight) {
          Image(systemName: "plus.bubble.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text("Neuen Thread starten")
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(GainsColor.lime)
          Spacer()
        }
        .padding(.horizontal, GainsSpacing.m)
        .frame(height: 48)
        .background(GainsColor.ctaSurface)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      }
      .buttonStyle(.plain)

      if visibleThreads.isEmpty {
        emptyState
      } else {
        VStack(spacing: GainsSpacing.s) {
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
      HStack(spacing: GainsSpacing.tight) {
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
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: systemImage)
          .font(.system(size: 11, weight: .semibold))
        Text(label)
          .font(GainsFont.label(10))
          .tracking(1.4)
      }
      .foregroundStyle(isSelected ? GainsColor.ink : GainsColor.softInk)
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: 36)
      .background(isSelected ? GainsColor.lime : GainsColor.card)
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
      Text("Hier ist es noch ruhig")
        .font(GainsFont.title(20))
        .foregroundStyle(GainsColor.ink)
      Text("Stell die erste Frage in dieser Kategorie und gib der Community den Anstoß.")
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
    }
    .padding(GainsSpacing.l)
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
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
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
          HStack(spacing: GainsSpacing.xxs) {
            Image(systemName: "mappin")
              .font(.system(size: 10, weight: .semibold))
            Text(location)
              .font(GainsFont.label(9))
              .tracking(1.2)
          }
          .foregroundStyle(GainsColor.softInk)
          .padding(.horizontal, GainsSpacing.xsPlus)
          .frame(height: 22)
          .background(GainsColor.background.opacity(0.85))
          .clipShape(Capsule())
        }
      }

      Text(thread.body)
        .font(GainsFont.body(13))
        .foregroundStyle(GainsColor.softInk)
        .lineLimit(isExpanded ? nil : 3)

      HStack(spacing: GainsSpacing.s) {
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
          let isLiked = store.hasLikedThread(thread.id)
          Label("\(thread.likeCount)", systemImage: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
            .font(GainsFont.label(10))
            .tracking(1.2)
            .foregroundStyle(isLiked ? GainsColor.lime : GainsColor.moss)
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
        VStack(alignment: .leading, spacing: GainsSpacing.tight) {
          if thread.replies.isEmpty {
            Text("Noch keine Antworten – sei die Erste oder der Erste.")
              .font(GainsFont.body(12))
              .foregroundStyle(GainsColor.softInk)
          } else {
            ForEach(thread.replies) { reply in
              VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
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
              .padding(GainsSpacing.s)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(GainsColor.background.opacity(0.7))
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
            }
          }

          HStack(spacing: GainsSpacing.tight) {
            TextField("Antwort schreiben…", text: $replyDraft, axis: .vertical)
              .lineLimit(1...4)
              .font(GainsFont.body(13))
              .padding(.horizontal, GainsSpacing.s)
              .padding(.vertical, GainsSpacing.tight)
              .background(GainsColor.background.opacity(0.9))
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

            Button {
              store.addReply(to: thread.id, body: replyDraft)
              replyDraft = ""
            } label: {
              Image(systemName: "paperplane.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(GainsColor.lime)
                .frame(width: 44, height: 44)
                .background(GainsColor.ctaSurface)
                .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
    }
    .padding(GainsSpacing.m)
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
    VStack(alignment: .leading, spacing: GainsSpacing.l) {
      VStack(alignment: .leading, spacing: GainsSpacing.tight) {
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
        HStack(spacing: GainsSpacing.tight) {
          Image(systemName: "calendar.badge.plus")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text("Neuen Treff erstellen")
            .font(GainsFont.label(11))
            .tracking(1.4)
            .foregroundStyle(GainsColor.lime)
          Spacer()
        }
        .padding(.horizontal, GainsSpacing.m)
        .frame(height: 48)
        .background(GainsColor.ctaSurface)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      }
      .buttonStyle(.plain)

      if store.upcomingMeetups.isEmpty {
        VStack(alignment: .leading, spacing: GainsSpacing.xsPlus) {
          Text("Noch keine Treffs in der Pipeline")
            .font(GainsFont.title(20))
            .foregroundStyle(GainsColor.ink)
          Text("Plane den ersten Lauftreff oder die nächste Gym-Session und lade Kontakte ein.")
            .font(GainsFont.body(13))
            .foregroundStyle(GainsColor.softInk)
        }
        .padding(GainsSpacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .gainsCardStyle()
      } else {
        VStack(spacing: GainsSpacing.s) {
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
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .top, spacing: GainsSpacing.s) {
        Circle()
          .fill(GainsColor.lime.opacity(0.32))
          .frame(width: 44, height: 44)
          .overlay {
            Image(systemName: meetup.sport.systemImage)
              .foregroundStyle(GainsColor.moss)
          }

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
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
          .padding(.horizontal, GainsSpacing.tight)
          .frame(height: 26)
          .background(GainsColor.lime.opacity(0.32))
          .clipShape(Capsule())
      }

      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
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
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(isFull && !isJoined)
    }
    .padding(GainsSpacing.m)
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
    VStack(alignment: .leading, spacing: GainsSpacing.l) {
      VStack(alignment: .leading, spacing: GainsSpacing.tight) {
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

      VStack(alignment: .leading, spacing: GainsSpacing.m) {
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
      .padding(GainsSpacing.l)
      .frame(maxWidth: .infinity, alignment: .leading)
      .gainsCardStyle()

      VStack(alignment: .leading, spacing: GainsSpacing.m) {
        SlashLabel(
          parts: ["WER", "SIEHT"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)

        VStack(spacing: GainsSpacing.tight) {
          ForEach(SharingVisibility.allCases) { visibility in
            Button {
              store.setSharingVisibility(visibility)
            } label: {
              HStack(spacing: GainsSpacing.s) {
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
              .padding(GainsSpacing.m)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(
                store.socialSharingSettings.visibility == visibility
                  ? GainsColor.lime.opacity(0.18) : GainsColor.background.opacity(0.7)
              )
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(GainsSpacing.l)
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
    HStack(alignment: .top, spacing: GainsSpacing.m) {
      Circle()
        .fill(GainsColor.lime.opacity(0.32))
        .frame(width: 38, height: 38)
        .overlay {
          Image(systemName: systemImage)
            .foregroundStyle(GainsColor.moss)
        }

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
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
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(GainsColor.background.opacity(0.7))
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
  }
}

// MARK: - Helpers

private func relativeTimestamp(for date: Date) -> String {
  let formatter = RelativeDateTimeFormatter()
  formatter.locale = Locale(identifier: "de_DE")
  formatter.unitsStyle = .short
  return formatter.localizedString(for: date, relativeTo: Date())
}

private let _meetupTimeFormatter: DateFormatter = {
  let f = DateFormatter()
  f.locale = Locale(identifier: "de_DE")
  f.dateFormat = "EE, d. MMM · HH:mm"
  return f
}()

private func meetupTimeLabel(_ date: Date) -> String {
  _meetupTimeFormatter.string(from: date) + " Uhr"
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
      VStack(alignment: .leading, spacing: GainsSpacing.xl) {
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
      HStack(alignment: .top, spacing: GainsSpacing.m) {
        Image(systemName: isOnWaitlist ? "checkmark.circle.fill" : "bell.badge")
          .font(.system(size: 22, weight: .semibold))
          .foregroundStyle(isOnWaitlist ? GainsColor.lime : GainsColor.lime)
          .frame(width: 44, height: 44)
          .background(Circle().fill(GainsColor.lime.opacity(0.16)))

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
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
      .padding(GainsSpacing.m)
      .background(GainsColor.card)
      .overlay(
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(
            isOnWaitlist ? GainsColor.lime.opacity(0.6) : GainsColor.border.opacity(0.5),
            lineWidth: 1
          )
      )
      .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
    }
    .buttonStyle(.plain)
  }

  private var featuresSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      Text("WAS KOMMT")
        .font(GainsFont.label(10))
        .tracking(2.0)
        .foregroundStyle(GainsColor.softInk)

      VStack(spacing: GainsSpacing.tight) {
        ForEach(features) { feature in
          featureRow(feature)
        }
      }
    }
  }

  private func featureRow(_ feature: UpcomingFeature) -> some View {
    HStack(alignment: .top, spacing: GainsSpacing.m) {
      Image(systemName: feature.icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(GainsColor.lime)
        .frame(width: 40, height: 40)
        .background(Circle().fill(GainsColor.lime.opacity(0.12)))

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
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
    .padding(GainsSpacing.m)
    .background(GainsColor.card)
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .stroke(GainsColor.border.opacity(0.35), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private var privacyNote: some View {
    HStack(alignment: .top, spacing: GainsSpacing.tight) {
      Image(systemName: "lock.shield.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(GainsColor.moss)
        .padding(.top, 2)
      Text("Wenn die Community live geht, ist alles opt-in. Du teilst nur, was du explizit teilen willst — und kannst jeden Beitrag pseudonym posten.")
        .font(GainsFont.body(12))
        .foregroundStyle(GainsColor.mutedInk)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, GainsSpacing.xxs)
  }
}
