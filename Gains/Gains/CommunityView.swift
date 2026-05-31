import SwiftUI

// MARK: - Community-Hub (2026-05-30, Neuaufbau im Glass-Look)
//
// Der Community-Bereich wurde am 2026-05-01 aus der Tab-Bar genommen
// (5 → 4 Tabs) und zeigte seither nur eine Coming-Soon-Seite. Diese Datei
// ersetzt die alte 6-Surface-Legacy-View (Feed/Mine/Circles/Forum/Meetups/
// Settings im Lime-Fill-Look) komplett durch einen frisch gestalteten Hub
// in der aktuellen hellen Glass-Designsprache:
//
//   • Einstieg über Home (kein 5. Tab) — präsentiert als globaler
//     Fullscreen-Overlay via AppNavigationStore.showsCommunity.
//   • Drei fokussierte Sektionen: Feed · Forum · Treffs.
//   • Lokale Demo-Daten (store.seedCommunityDemoDataIfNeeded) machen den Hub
//     beim ersten Öffnen lebendig, ohne eigene Inhalte zu überschreiben.
//   • Glas/Outline statt Lime-Fill, Lime nur als Akzent — konsistent mit dem
//     Glass-Redesign vom 2026-05-29.

struct CommunityHubView: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  private enum Section: String, CaseIterable, Identifiable {
    case feed, forum, meetups
    var id: Self { self }
    var label: String {
      switch self {
      case .feed: return "Feed"
      case .forum: return "Forum"
      case .meetups: return "Treffs"
      }
    }
    var icon: String {
      switch self {
      case .feed: return "sparkles"
      case .forum: return "bubble.left.and.bubble.right.fill"
      case .meetups: return "calendar"
      }
    }
  }

  @State private var section: Section = .feed
  @State private var showingPrivacy = false
  @State private var showingForumComposer = false
  @State private var showingMeetupComposer = false

  var body: some View {
    ZStack {
      GainsAppBackground()

      VStack(spacing: GainsSpacing.m) {
        header
        sectionPicker

        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: GainsSpacing.xl) {
            switch section {
            case .feed: feedSection
            case .forum: forumSection
            case .meetups: meetupSection
            }
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.top, GainsSpacing.xs)
          .padding(.bottom, GainsSpacing.xl)
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .animation(GainsMotion.spring, value: section)
      }
      .padding(.top, GainsSpacing.s)
    }
    .onAppear { store.seedCommunityDemoDataIfNeeded() }
    .sheet(isPresented: $showingPrivacy) {
      CommunityPrivacySheet().environmentObject(store)
    }
    .sheet(isPresented: $showingForumComposer) {
      ForumComposerSheet().environmentObject(store)
    }
    .sheet(isPresented: $showingMeetupComposer) {
      MeetupComposerSheet().environmentObject(store)
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(alignment: .top, spacing: GainsSpacing.s) {
      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        SlashLabel(
          parts: ["COMMUNITY", "CREW"],
          primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        HStack(spacing: GainsSpacing.xs) {
          Text("Community")
            .font(GainsFont.title(28))
            .foregroundStyle(GainsColor.ink)
          GainsSignalDot(active: true, color: GainsColor.lime, size: 6)
        }
      }

      Spacer()

      iconButton(systemImage: "lock.shield.fill", accent: GainsColor.moss) {
        showingPrivacy = true
      }
      iconButton(systemImage: "xmark", accent: GainsColor.softInk) {
        dismiss()
      }
    }
    .padding(.horizontal, GainsSpacing.l)
  }

  private func iconButton(
    systemImage: String, accent: Color, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(accent)
        .frame(width: 40, height: 40)
        .background(.ultraThinMaterial, in: Circle())
        .overlay(
          Circle().strokeBorder(GainsColor.border.opacity(0.6), lineWidth: GainsBorder.hairline)
        )
    }
    .buttonStyle(.plain)
  }

  private var sectionPicker: some View {
    GainsSegmentedPicker(
      selection: $section,
      options: Section.allCases.map {
        GainsSegmentedPickerOption(id: $0, label: $0.label, icon: $0.icon)
      }
    )
    .padding(.horizontal, GainsSpacing.l)
  }

  // MARK: - Feed

  private var feedSection: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xl) {
      ChallengeHeroCard()
        .environmentObject(store)

      composerStrip

      if store.communityPosts.isEmpty {
        EmptyStateView(
          style: .prominent,
          title: "Noch nichts im Feed",
          message:
            "Sobald du ein Workout, einen Lauf oder ein Progress-Update teilst, taucht es hier zuerst auf.",
          icon: "sparkles"
        )
      } else {
        // Perf (2026-05-31): LazyVStack — Feed-Karten erst beim Scrollen bauen.
        LazyVStack(alignment: .leading, spacing: GainsSpacing.m) {
          SlashLabel(
            parts: ["FOR", "YOU"], primaryColor: GainsColor.lime,
            secondaryColor: GainsColor.softInk)
          ForEach(store.communityPosts) { post in
            CommunityPostCard(post: post)
              .environmentObject(store)
          }
        }
      }
    }
  }

  private var composerStrip: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      SlashLabel(
        parts: ["SCHNELL", "TEILEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: GainsSpacing.xsPlus) {
          ForEach(store.communityComposerActions) { action in
            Button {
              store.createCommunityPost(from: action)
              UISelectionFeedbackGenerator().selectionChanged()
            } label: {
              HStack(spacing: GainsSpacing.xs) {
                Image(systemName: action.systemImage)
                  .font(.system(size: 12, weight: .semibold))
                  .foregroundStyle(GainsColor.lime)
                Text(action.title)
                  .font(.system(size: 13, weight: .semibold))
                  .foregroundStyle(GainsColor.ink)
              }
              .padding(.horizontal, GainsSpacing.m)
              .frame(height: GainsControl.pillHeight)
              .gainsGlassCTA(corner: GainsRadius.small, accent: GainsColor.lime)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 2)
      }
    }
  }

  // MARK: - Forum

  private var forumSection: some View {
    ForumSurface(onCompose: { showingForumComposer = true })
      .environmentObject(store)
  }

  // MARK: - Meetups

  private var meetupSection: some View {
    MeetupSurface(onCompose: { showingMeetupComposer = true })
      .environmentObject(store)
  }
}

// MARK: - Challenge-Hero

private struct ChallengeHeroCard: View {
  @EnvironmentObject private var store: GainsStore

  private var model: CommunityViewModel { CommunityViewModel.mock }
  private var participants: Int {
    model.challengeParticipants + (store.joinedChallenge ? 1 : 0)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      SlashLabel(
        parts: ["LIVE", "CHALLENGE"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      Text(model.challengeTitle)
        .font(GainsFont.title(24))
        .foregroundStyle(GainsColor.ink)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: GainsSpacing.xs) {
        GainsSignalDot(active: true, color: GainsColor.lime, size: 6)
        Text("\(participants.formatted()) aktive Mitglieder")
          .gainsCaption(GainsColor.softInk)
      }

      FlowChips(items: model.challengeBenefits)

      Button {
        store.toggleChallengeJoined()
        UISelectionFeedbackGenerator().selectionChanged()
      } label: {
        HStack(spacing: GainsSpacing.xs) {
          Image(systemName: store.joinedChallenge ? "checkmark.circle.fill" : "flag.checkered")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text(store.joinedChallenge ? "Du bist dabei" : "Challenge beitreten")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(GainsColor.ink)
        }
        .frame(maxWidth: .infinity)
        .frame(height: GainsControl.ctaHeight)
        .gainsGlassCTA(accent: GainsColor.lime)
      }
      .buttonStyle(.plain)
    }
    .padding(GainsSpacing.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsHeroGlass(accent: GainsColor.lime)
  }
}

/// Einfacher umbrechender Chip-Fluss für die Benefit-Liste.
private struct FlowChips: View {
  let items: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xs) {
      ForEach(items, id: \.self) { item in
        HStack(spacing: GainsSpacing.xs) {
          Image(systemName: "checkmark")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(GainsColor.moss)
          Text(item)
            .gainsCaption(GainsColor.softInk)
        }
      }
    }
  }
}

// MARK: - Post-Card

private struct CommunityPostCard: View {
  @EnvironmentObject private var store: GainsStore
  let post: CommunityPost

  private var isOwn: Bool { post.handle == store.userHandle }
  private var liked: Bool { store.likedPostIDs.contains(post.id) }
  private var commented: Bool { store.commentedPostIDs.contains(post.id) }
  private var shared: Bool { store.sharedPostIDs.contains(post.id) }

  private var accent: Color {
    switch post.type {
    case .workout: return GainsColor.lime
    case .run: return GainsColor.accentCool
    case .progress: return GainsColor.moss
    case .all: return GainsColor.lime
    }
  }
  private var typeLabel: String {
    switch post.type {
    case .workout: return "Workout"
    case .run: return "Lauf"
    case .progress: return "Progress"
    case .all: return "Post"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      headerRow
      Text(post.title)
        .font(GainsFont.headline)
        .foregroundStyle(GainsColor.ink)
        .fixedSize(horizontal: false, vertical: true)
      Text(post.detail)
        .gainsBody(secondary: true)
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)

      if !post.highlightMetrics.isEmpty {
        HStack(spacing: GainsSpacing.xs) {
          ForEach(post.highlightMetrics) { metric in
            metricCell(metric)
          }
        }
      }

      actionRow
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private var headerRow: some View {
    HStack(spacing: GainsSpacing.s) {
      ZStack {
        Circle().fill(.ultraThinMaterial)
        Circle().strokeBorder(accent.opacity(0.4), lineWidth: GainsBorder.hairline)
        Text(initials(post.author))
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(accent)
      }
      .frame(width: 40, height: 40)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: GainsSpacing.xs) {
          Text(post.author)
            .font(GainsFont.headline)
            .foregroundStyle(GainsColor.ink)
          if isOwn {
            Text("DU")
              .font(.system(size: 9, weight: .heavy, design: .monospaced))
              .tracking(GainsTracking.eyebrowTight)
              .foregroundStyle(GainsColor.moss)
              .padding(.horizontal, GainsSpacing.xs)
              .frame(height: 18)
              .background(GainsColor.lime.opacity(0.16), in: Capsule())
          }
        }
        Text("\(post.handle) · \(post.timeAgo)")
          .gainsCaption(GainsColor.mutedInk)
          .lineLimit(1)
      }

      Spacer(minLength: GainsSpacing.xs)

      GainsGlassChip(typeLabel, accent: accent)
    }
  }

  private func metricCell(_ metric: CommunityMetric) -> some View {
    VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
      Text(metric.value)
        .gainsMetric(GainsColor.ink, size: .small)
      Text(metric.label)
        .gainsEyebrow(GainsColor.softInk, tracking: GainsTracking.eyebrowTight)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, GainsSpacing.xsPlus)
    .padding(.horizontal, GainsSpacing.s)
    .background(GainsColor.surfaceDeep.opacity(0.6))
    .overlay(
      RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
        .strokeBorder(GainsColor.border.opacity(0.55), lineWidth: GainsBorder.hairline)
    )
    .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
  }

  private var actionRow: some View {
    HStack(spacing: GainsSpacing.xs) {
      actionPill(
        count: post.reactions + (liked ? 1 : 0),
        icon: liked ? "heart.fill" : "heart",
        active: liked
      ) { store.toggleLike(postID: post.id) }

      actionPill(
        count: post.comments + (commented ? 1 : 0),
        icon: "bubble.right",
        active: commented
      ) { store.toggleComment(postID: post.id) }

      actionPill(
        count: post.shares + (shared ? 1 : 0),
        icon: "arrowshape.turn.up.right",
        active: shared
      ) { store.toggleShare(postID: post.id) }

      Spacer()
    }
  }

  private func actionPill(
    count: Int, icon: String, active: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: icon)
          .font(.system(size: 12, weight: .semibold))
        Text("\(count)")
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
      }
      .foregroundStyle(active ? GainsColor.moss : GainsColor.softInk)
      .padding(.horizontal, GainsSpacing.s)
      .frame(height: 34)
      .background(.ultraThinMaterial, in: Capsule())
      .overlay(
        Capsule().strokeBorder(
          (active ? GainsColor.lime.opacity(0.5) : GainsColor.border.opacity(0.55)),
          lineWidth: GainsBorder.hairline)
      )
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Forum

private struct ForumSurface: View {
  @EnvironmentObject private var store: GainsStore
  let onCompose: () -> Void

  @State private var selectedCategory: ForumCategory? = nil
  @State private var openThreadID: UUID? = nil

  private var visibleThreads: [ForumThread] {
    if let category = selectedCategory { return store.threads(in: category) }
    return store.forumThreads
  }

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.l) {
      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        SlashLabel(
          parts: ["FORUM", "AUSTAUSCH"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Text("Frag die Crew")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
        Text("Gym-Tipps, Ernährung, lokale Lauftreffs — frag nach oder teile, was funktioniert.")
          .gainsBody(secondary: true)
          .fixedSize(horizontal: false, vertical: true)
      }

      categoryFilter

      Button(action: onCompose) {
        HStack(spacing: GainsSpacing.xs) {
          Image(systemName: "plus.bubble.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text("Neuen Thread starten")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(GainsColor.ink)
          Spacer()
        }
        .padding(.horizontal, GainsSpacing.m)
        .frame(height: GainsControl.ctaHeight)
        .gainsGlassCTA(accent: GainsColor.lime)
      }
      .buttonStyle(.plain)

      if visibleThreads.isEmpty {
        EmptyStateView(
          style: .card(icon: "bubble.left.and.bubble.right"),
          title: "Hier ist es noch ruhig",
          message: "Stell die erste Frage in dieser Kategorie und gib der Crew den Anstoß."
        )
      } else {
        LazyVStack(spacing: GainsSpacing.s) {
          ForEach(visibleThreads) { thread in
            ForumThreadCard(
              thread: thread,
              isExpanded: openThreadID == thread.id,
              onToggle: {
                withAnimation(GainsMotion.spring) {
                  openThreadID = openThreadID == thread.id ? nil : thread.id
                }
              }
            )
            .environmentObject(store)
          }
        }
      }
    }
  }

  private var categoryFilter: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: GainsSpacing.xsPlus) {
        chip(label: "Alle", systemImage: "tray.full", isSelected: selectedCategory == nil) {
          selectedCategory = nil
        }
        ForEach(ForumCategory.allCases) { category in
          chip(
            label: category.title,
            systemImage: category.systemImage,
            isSelected: selectedCategory == category
          ) {
            selectedCategory = selectedCategory == category ? nil : category
          }
        }
      }
      .padding(.vertical, 2)
    }
  }

  private func chip(
    label: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: GainsSpacing.xs) {
        Image(systemName: systemImage)
          .font(.system(size: 11, weight: .semibold))
        Text(label)
          .font(.system(size: 13, weight: .semibold))
      }
      .foregroundStyle(isSelected ? GainsColor.onLime : GainsColor.softInk)
      .padding(.horizontal, GainsSpacing.m)
      .frame(height: GainsControl.chipHeight)
      .background {
        if isSelected {
          Capsule().fill(GainsColor.lime)
        } else {
          Capsule().fill(.ultraThinMaterial)
          Capsule().strokeBorder(GainsColor.border.opacity(0.55), lineWidth: GainsBorder.hairline)
        }
      }
      .clipShape(Capsule())
    }
    .buttonStyle(.plain)
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
      HStack(alignment: .top, spacing: GainsSpacing.s) {
        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(thread.category.title)
            .gainsEyebrow(GainsColor.moss, tracking: GainsTracking.eyebrowTight)
          Text(thread.title)
            .font(GainsFont.headline)
            .foregroundStyle(GainsColor.ink)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: GainsSpacing.xs)
        if let location = thread.location {
          HStack(spacing: GainsSpacing.xxs) {
            Image(systemName: "mappin")
              .font(.system(size: 10, weight: .semibold))
            Text(location)
              .font(.system(size: 11, weight: .medium))
          }
          .foregroundStyle(GainsColor.softInk)
          .padding(.horizontal, GainsSpacing.xsPlus)
          .frame(height: 24)
          .background(.ultraThinMaterial, in: Capsule())
        }
      }

      Text(thread.body)
        .gainsBody(secondary: true)
        .lineLimit(isExpanded ? nil : 3)
        .fixedSize(horizontal: false, vertical: true)

      HStack(spacing: GainsSpacing.m) {
        Label(thread.author, systemImage: "person.fill")
          .gainsCaption(GainsColor.mutedInk)
        Text(relativeTimestamp(for: thread.createdAt))
          .gainsCaption(GainsColor.mutedInk)

        Spacer()

        Button {
          store.toggleForumLike(threadID: thread.id)
        } label: {
          let isLiked = store.hasLikedThread(thread.id)
          Label("\(thread.likeCount)", systemImage: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isLiked ? GainsColor.moss : GainsColor.softInk)
        }
        .buttonStyle(.plain)

        Button(action: onToggle) {
          Label("\(thread.replies.count)", systemImage: "bubble.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(GainsColor.softInk)
        }
        .buttonStyle(.plain)
      }

      if isExpanded { expandedReplies }
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private var expandedReplies: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.s) {
      Divider().overlay(GainsColor.border.opacity(0.5))

      if thread.replies.isEmpty {
        Text("Noch keine Antworten – sei die Erste oder der Erste.")
          .gainsCaption(GainsColor.softInk)
      } else {
        ForEach(thread.replies) { reply in
          VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
            HStack(spacing: GainsSpacing.xs) {
              Text(reply.author)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GainsColor.ink)
              Text(relativeTimestamp(for: reply.createdAt))
                .gainsCaption(GainsColor.mutedInk)
            }
            Text(reply.body)
              .gainsBody()
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(GainsSpacing.s)
          .background(GainsColor.surfaceDeep.opacity(0.55))
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        }
      }

      HStack(spacing: GainsSpacing.xs) {
        TextField("Antwort schreiben…", text: $replyDraft, axis: .vertical)
          .lineLimit(1...4)
          .font(GainsFont.body(14))
          .padding(.horizontal, GainsSpacing.s)
          .padding(.vertical, GainsSpacing.xsPlus)
          .background(.ultraThinMaterial)
          .overlay(
            RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous)
              .strokeBorder(GainsColor.border.opacity(0.6), lineWidth: GainsBorder.hairline)
          )
          .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))

        Button {
          store.addReply(to: thread.id, body: replyDraft)
          replyDraft = ""
        } label: {
          Image(systemName: "paperplane.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
            .frame(width: 44, height: 44)
            .gainsGlassCTA(corner: GainsRadius.small, accent: GainsColor.lime)
        }
        .buttonStyle(.plain)
        .disabled(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
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
            .gainsCaption(GainsColor.softInk)
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
      .navigationBarTitleDisplayMode(.inline)
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
  let onCompose: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.l) {
      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        SlashLabel(
          parts: ["TREFFS", "ZUSAMMEN"], primaryColor: GainsColor.lime,
          secondaryColor: GainsColor.softInk)
        Text("Verabrede dich")
          .font(GainsFont.title(22))
          .foregroundStyle(GainsColor.ink)
        Text("Lauftreff, gemeinsame Gym-Session oder Radtour — plane einen Treff oder schließ dich an.")
          .gainsBody(secondary: true)
          .fixedSize(horizontal: false, vertical: true)
      }

      Button(action: onCompose) {
        HStack(spacing: GainsSpacing.xs) {
          Image(systemName: "calendar.badge.plus")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
          Text("Neuen Treff erstellen")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(GainsColor.ink)
          Spacer()
        }
        .padding(.horizontal, GainsSpacing.m)
        .frame(height: GainsControl.ctaHeight)
        .gainsGlassCTA(accent: GainsColor.lime)
      }
      .buttonStyle(.plain)

      if store.upcomingMeetups.isEmpty {
        EmptyStateView(
          style: .card(icon: "calendar"),
          title: "Noch keine Treffs",
          message: "Plane den ersten Lauftreff oder die nächste Gym-Session und lade die Crew ein."
        )
      } else {
        LazyVStack(spacing: GainsSpacing.s) {
          ForEach(store.upcomingMeetups) { meetup in
            MeetupCard(meetup: meetup)
              .environmentObject(store)
          }
        }
      }
    }
  }
}

private struct MeetupCard: View {
  @EnvironmentObject private var store: GainsStore
  let meetup: Meetup

  private var isJoined: Bool { meetup.participantHandles.contains(store.userHandle) }
  private var isFull: Bool { meetup.participantHandles.count >= meetup.maxParticipants }
  private var isHost: Bool { meetup.hostHandle == store.userHandle }

  var body: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      HStack(alignment: .top, spacing: GainsSpacing.s) {
        ZStack {
          Circle().fill(.ultraThinMaterial)
          Circle().strokeBorder(GainsColor.lime.opacity(0.4), lineWidth: GainsBorder.hairline)
          Image(systemName: meetup.sport.systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(GainsColor.lime)
        }
        .frame(width: 44, height: 44)

        VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
          Text(meetup.sport.title)
            .gainsEyebrow(GainsColor.moss, tracking: GainsTracking.eyebrowTight)
          Text(meetup.title)
            .font(GainsFont.headline)
            .foregroundStyle(GainsColor.ink)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: GainsSpacing.xs)

        Text("\(meetup.participantHandles.count)/\(meetup.maxParticipants)")
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .foregroundStyle(GainsColor.moss)
          .padding(.horizontal, GainsSpacing.xsPlus)
          .frame(height: 26)
          .background(GainsColor.lime.opacity(0.16), in: Capsule())
      }

      VStack(alignment: .leading, spacing: GainsSpacing.xs) {
        detailRow("mappin.and.ellipse", meetup.locationName)
        detailRow("clock", meetupTimeLabel(meetup.startsAt))
        if let pace = meetup.pace { detailRow("speedometer", pace) }
        detailRow("person.fill", "Host: \(meetup.hostName)")
      }

      if !meetup.notes.isEmpty {
        Text(meetup.notes)
          .gainsBody()
          .lineLimit(3)
          .fixedSize(horizontal: false, vertical: true)
      }

      Button {
        store.toggleMeetupParticipation(meetupID: meetup.id)
        UISelectionFeedbackGenerator().selectionChanged()
      } label: {
        Text(buttonLabel)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(isFull && !isJoined ? GainsColor.mutedInk : GainsColor.ink)
          .frame(maxWidth: .infinity)
          .frame(height: GainsControl.ctaHeight)
          .gainsGlassCTA(accent: GainsColor.lime, isEnabled: !(isFull && !isJoined))
      }
      .buttonStyle(.plain)
      .disabled((isFull && !isJoined) || isHost)
    }
    .padding(GainsSpacing.m)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private func detailRow(_ icon: String, _ text: String) -> some View {
    Label(text, systemImage: icon)
      .gainsCaption(GainsColor.softInk)
      .lineLimit(1)
  }

  private var buttonLabel: String {
    if isHost { return "Du bist Host" }
    if isJoined { return "Zusage zurückziehen" }
    if isFull { return "Voll besetzt" }
    return "Mitmachen"
  }
}

private struct MeetupComposerSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss
  @State private var sport: MeetupSport = .run
  @State private var title: String = ""
  @State private var locationName: String = ""
  @State private var startsAt: Date =
    Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
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
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Speichern") {
            store.createMeetup(
              sport: sport, title: title, locationName: locationName,
              startsAt: startsAt, pace: pace.isEmpty ? nil : pace,
              notes: notes, maxParticipants: maxParticipants)
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

// MARK: - Privacy / Auto-Sharing

private struct CommunityPrivacySheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ZStack {
        GainsAppBackground()
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: GainsSpacing.xl) {
            VStack(alignment: .leading, spacing: GainsSpacing.xs) {
              SlashLabel(
                parts: ["PRIVAT", "SPHÄRE"], primaryColor: GainsColor.lime,
                secondaryColor: GainsColor.softInk)
              Text("Was teilst du automatisch?")
                .font(GainsFont.title(22))
                .foregroundStyle(GainsColor.ink)
              Text("Du entscheidest, ob Workouts, Läufe oder neue Rekorde automatisch im Feed landen.")
                .gainsBody(secondary: true)
                .fixedSize(horizontal: false, vertical: true)
            }

            autoShareCard
            visibilityCard
          }
          .padding(.horizontal, GainsSpacing.l)
          .padding(.vertical, GainsSpacing.l)
        }
      }
      .navigationTitle("Privatsphäre")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") { dismiss() }
        }
      }
    }
  }

  private var autoShareCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      SlashLabel(
        parts: ["AUTO", "TEILEN"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      toggleRow(
        title: "Workouts automatisch teilen",
        subtitle: "Beendete Sessions landen direkt im Feed.",
        systemImage: "dumbbell.fill",
        isOn: Binding(
          get: { store.socialSharingSettings.autoShareWorkouts },
          set: { store.setAutoShareWorkouts($0) }))
      toggleRow(
        title: "Läufe automatisch teilen",
        subtitle: "Distanz, Pace und Herzfrequenz im Feed.",
        systemImage: "figure.run",
        isOn: Binding(
          get: { store.socialSharingSettings.autoShareRuns },
          set: { store.setAutoShareRuns($0) }))
      toggleRow(
        title: "Neue PRs feiern",
        subtitle: "Schlägst du einen Rekord, wird er als Progress-Post geteilt.",
        systemImage: "trophy.fill",
        isOn: Binding(
          get: { store.socialSharingSettings.autoSharePersonalRecords },
          set: { store.setAutoSharePersonalRecords($0) }))
      toggleRow(
        title: "Standort bei Läufen teilen",
        subtitle: "Wenn aktiv: Strecke / Stadt erscheint mit dem Lauf-Post.",
        systemImage: "mappin.and.ellipse",
        isOn: Binding(
          get: { store.socialSharingSettings.shareLocationWithRuns },
          set: { store.setShareLocationWithRuns($0) }))
    }
    .padding(GainsSpacing.l)
    .frame(maxWidth: .infinity, alignment: .leading)
    .gainsCardStyle()
  }

  private var visibilityCard: some View {
    VStack(alignment: .leading, spacing: GainsSpacing.m) {
      SlashLabel(
        parts: ["WER", "SIEHT"], primaryColor: GainsColor.lime,
        secondaryColor: GainsColor.softInk)

      VStack(spacing: GainsSpacing.xsPlus) {
        ForEach(SharingVisibility.allCases) { visibility in
          Button {
            store.setSharingVisibility(visibility)
          } label: {
            HStack(spacing: GainsSpacing.s) {
              Image(systemName: visibility.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                  store.socialSharingSettings.visibility == visibility
                    ? GainsColor.moss : GainsColor.softInk)
                .frame(width: 26)
              VStack(alignment: .leading, spacing: 2) {
                Text(visibility.title)
                  .font(GainsFont.headline)
                  .foregroundStyle(GainsColor.ink)
                Text(visibilityDescription(visibility))
                  .gainsCaption(GainsColor.softInk)
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
                ? GainsColor.lime.opacity(0.12) : GainsColor.surfaceDeep.opacity(0.5)
            )
            .overlay(
              RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
                .strokeBorder(
                  store.socialSharingSettings.visibility == visibility
                    ? GainsColor.lime.opacity(0.45) : GainsColor.border.opacity(0.5),
                  lineWidth: GainsBorder.hairline)
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
      ZStack {
        Circle().fill(.ultraThinMaterial)
        Circle().strokeBorder(GainsColor.lime.opacity(0.35), lineWidth: GainsBorder.hairline)
        Image(systemName: systemImage)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(GainsColor.moss)
      }
      .frame(width: 38, height: 38)

      VStack(alignment: .leading, spacing: GainsSpacing.xxs) {
        Text(title)
          .font(GainsFont.headline)
          .foregroundStyle(GainsColor.ink)
        Text(subtitle)
          .gainsCaption(GainsColor.softInk)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: GainsSpacing.xs)

      Toggle("", isOn: isOn)
        .labelsHidden()
        .tint(GainsColor.lime)
    }
  }
}

// MARK: - Helpers

private func initials(_ name: String) -> String {
  let parts = name.split(separator: " ")
  let chars = parts.prefix(2).compactMap { $0.first }
  let result = String(chars).uppercased()
  return result.isEmpty ? "?" : result
}

private let _relativeTimestampFormatter: RelativeDateTimeFormatter = {
  let f = RelativeDateTimeFormatter()
  f.locale = Locale(identifier: "de_DE")
  f.unitsStyle = .short
  return f
}()

private func relativeTimestamp(for date: Date) -> String {
  _relativeTimestampFormatter.localizedString(for: date, relativeTo: Date())
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
