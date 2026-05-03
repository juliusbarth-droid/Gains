import Foundation

// MARK: - Forum & Meetups Extension
//
// 2026-05-03: Aus GainsStore.swift extrahiert (Quick-Win-Sweep „Optimiere
// die app"). Forum-Thread-Erstellung, Reply-Posting, Meetup-CRUD und
// Teilnahme-Toggles sitzen jetzt in einer eigenen Extension. Vorher waren
// sie inline in der 4393-Zeilen-Klasse zwischen Personal-Records und
// Social-Sharing-Settings vergraben.
//
// Die Funktionen greifen auf @Published-Properties (forumThreads, meetups,
// userName, joinedMeetupIDs) zu — alle internal-zugänglich, daher
// extension-tauglich. Keine privaten Helfer benötigt.

extension GainsStore {
  // MARK: - Forum

  func createForumThread(category: ForumCategory, title: String, body: String, location: String? = nil) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return }

    let thread = ForumThread(
      id: UUID(),
      category: category,
      title: trimmedTitle,
      body: trimmedBody,
      author: userName,
      handle: "@julius.gains",
      createdAt: Date(),
      location: location?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      replies: [],
      likeCount: 0
    )
    forumThreads.insert(thread, at: 0)
    saveAll()
  }

  func addReply(to threadID: UUID, body: String) {
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty,
          let index = forumThreads.firstIndex(where: { $0.id == threadID }) else { return }
    let reply = ForumReply(
      id: UUID(),
      author: userName,
      handle: "@julius.gains",
      body: trimmed,
      createdAt: Date()
    )
    forumThreads[index].replies.append(reply)
    saveAll()
  }

  func toggleForumLike(threadID: UUID) {
    guard let index = forumThreads.firstIndex(where: { $0.id == threadID }) else { return }
    forumThreads[index].likeCount += 1
    saveAll()
  }

  // MARK: - Meetups

  func createMeetup(
    sport: MeetupSport,
    title: String,
    locationName: String,
    startsAt: Date,
    pace: String?,
    notes: String,
    maxParticipants: Int
  ) {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty, !trimmedLocation.isEmpty else { return }

    let meetup = Meetup(
      id: UUID(),
      sport: sport,
      title: trimmedTitle,
      locationName: trimmedLocation,
      startsAt: startsAt,
      pace: pace?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
      hostHandle: "@julius.gains",
      hostName: userName,
      notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
      maxParticipants: max(2, maxParticipants),
      participantHandles: ["@julius.gains"]
    )
    meetups.insert(meetup, at: 0)
    joinedMeetupIDs.insert(meetup.id)
    saveAll()
  }

  func toggleMeetupParticipation(meetupID: UUID) {
    guard let index = meetups.firstIndex(where: { $0.id == meetupID }) else { return }
    let ownHandle = "@julius.gains"
    if meetups[index].participantHandles.contains(ownHandle) {
      meetups[index].participantHandles.removeAll { $0 == ownHandle }
      joinedMeetupIDs.remove(meetupID)
    } else if meetups[index].participantHandles.count < meetups[index].maxParticipants {
      meetups[index].participantHandles.append(ownHandle)
      joinedMeetupIDs.insert(meetupID)
    }
    saveAll()
  }

  var upcomingMeetups: [Meetup] {
    meetups
      .filter { $0.startsAt >= Date().addingTimeInterval(-3600) }
      .sorted { $0.startsAt < $1.startsAt }
  }

  func threads(in category: ForumCategory) -> [ForumThread] {
    forumThreads.filter { $0.category == category }
  }

}
