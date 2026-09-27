//
//  User.swift
//  Tasked
//
//  Updated (Streaks): added currentStreak + lastPostWeekStart.
//  Updated (Notification settings + push): added notificationPreferences
//  and fcmToken.
//  Updated (Single-lowercase-username pass): removed usernameLower entirely.
//  Updated (Drop fullname pass): removed fullname entirely.
//  Updated (Public/private pass): added isPublicAccount.
//  Updated (Block user pass): added blockedUids — uids this account has
//  blocked, same shape as friendUids. Postdates every existing account, so
//  init(from:) decodes it with a [] fallback like friendUids already gets.
//  Used by BlockService, UserService.searchUsers (filters blocked users out
//  of results), and FriendService.sendFriendRequest (blocks a request in
//  either direction between blocked parties).
//  Updated (Deactivate account pass): added isDeactivated — self-managed,
//  flipped on by AuthService.deactivateAccount() and cleared automatically
//  by AuthService.loadUserData()/reactivateAccount() the next time this
//  account successfully signs in. Postdates every existing account, so
//  init(from:) decodes it with a `false` fallback like isPublicAccount
//  already gets. Read by FriendsViewModel (filters a deactivated friend out
//  of the friends list) and, per its own file header, search/feed as well.
//  Updated (Location pass): added `locationLatitude`/`locationLongitude`,
//  alongside the existing `location` display string — set together
//  whenever EditProfileView's Location row resolves a pick from
//  LocationPickerView (the same city-search sheet UploadPostView uses).
//  Both postdate every existing account, so they decode with nil fallbacks
//  like the rest of this file's optional fields.
//

import Foundation
import Firebase
import FirebaseAuth

struct User: Identifiable, Hashable, Codable {
    let id: String
    
    /// Always lowercase — enforced client-side wherever this is written
    /// (sign-up, profile edits).
    var username: String
    
    var profileImageUrl: String?
    var bio: String?
    var location: String?
    var locationLatitude: Double?
    var locationLongitude: Double?
    
    var friendUids: [String] = []

    /// Uids this account has blocked. Self-managed — only the account
    /// itself ever writes to its own list (see BlockService). A block hides
    /// the blocked user's posts (via unfriending, since the feed is
    /// friends-scoped), removes them from search results in both
    /// directions, and prevents new friend requests either way.
    var blockedUids: [String] = []

    /// Whether new posts from this account default to public (visible to
    /// anyone signed in, eligible for a future public map view) or private
    /// (friends-only). Set once at sign-up; changing it later (not wired up
    /// yet — would live in Settings) would only affect posts uploaded after
    /// the change, not retroactively.
    var isPublicAccount: Bool = true

    /// Hides this account from search/feed/friends lists while true —
    /// nothing is deleted (see AuthService.deactivateAccount). Signing back
    /// in clears this automatically (AuthService.loadUserData), so there's
    /// no separate "Reactivate" screen.
    var isDeactivated: Bool = false

    var currentStreak: Int = 0
    var lastPostWeekStart: Timestamp?

    var notificationPreferences: NotificationPreferences = NotificationPreferences()
    var fcmToken: String?
    
    let email: String
    
    var friendsCount: Int { friendUids.count }

    /// The streak as it should be *displayed* right now. If the user hasn't
    /// posted this week or last week, the streak reads as 0 even though the
    /// stored `currentStreak` is only overwritten the next time they post.
    var displayStreak: Int {
        guard let lastPostWeekStart = lastPostWeekStart?.dateValue() else { return 0 }

        let currentWeekStart = DateWeek.startOfWeek(containing: Date())
        let previousWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart

        return (lastPostWeekStart == currentWeekStart || lastPostWeekStart == previousWeekStart) ? currentStreak : 0
    }
    
    var isCurrentUser: Bool {
        guard let currentUid = Auth.auth().currentUser?.uid else { return false }
        return currentUid == id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case profileImageUrl
        case bio
        case location
        case locationLatitude
        case locationLongitude
        case friendUids
        case blockedUids
        case isPublicAccount
        case isDeactivated
        case currentStreak
        case lastPostWeekStart
        case notificationPreferences
        case fcmToken
        case email
    }

    init(
        id: String,
        username: String,
        profileImageUrl: String? = nil,
        bio: String? = nil,
        location: String? = nil,
        locationLatitude: Double? = nil,
        locationLongitude: Double? = nil,
        friendUids: [String] = [],
        blockedUids: [String] = [],
        isPublicAccount: Bool = true,
        isDeactivated: Bool = false,
        currentStreak: Int = 0,
        lastPostWeekStart: Timestamp? = nil,
        notificationPreferences: NotificationPreferences = NotificationPreferences(),
        fcmToken: String? = nil,
        email: String
    ) {
        self.id = id
        self.username = username
        self.profileImageUrl = profileImageUrl
        self.bio = bio
        self.location = location
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.friendUids = friendUids
        self.blockedUids = blockedUids
        self.isPublicAccount = isPublicAccount
        self.isDeactivated = isDeactivated
        self.currentStreak = currentStreak
        self.lastPostWeekStart = lastPostWeekStart
        self.notificationPreferences = notificationPreferences
        self.fcmToken = fcmToken
        self.email = email
    }


    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)

        username = try container.decode(String.self, forKey: .username)

        profileImageUrl = try container.decodeIfPresent(
            String.self,
            forKey: .profileImageUrl
        )

        bio = try container.decodeIfPresent(
            String.self,
            forKey: .bio
        )

        location = try container.decodeIfPresent(
            String.self,
            forKey: .location
        )

        locationLatitude = try container.decodeIfPresent(
            Double.self,
            forKey: .locationLatitude
        )

        locationLongitude = try container.decodeIfPresent(
            Double.self,
            forKey: .locationLongitude
        )

        friendUids = try container.decodeIfPresent(
            [String].self,
            forKey: .friendUids
        ) ?? []

        // Postdates every account created before this pass — default to
        // an empty list rather than failing the decode when it's missing.
        blockedUids = try container.decodeIfPresent(
            [String].self,
            forKey: .blockedUids
        ) ?? []

        // Postdates every account created before this pass — default to
        // public rather than failing the decode when it's missing.
        isPublicAccount = try container.decodeIfPresent(
            Bool.self,
            forKey: .isPublicAccount
        ) ?? true

        // Also postdates every existing account — default to "not
        // deactivated" rather than failing the decode when it's missing.
        isDeactivated = try container.decodeIfPresent(
            Bool.self,
            forKey: .isDeactivated
        ) ?? false

        // Both postdate a lot of existing accounts — default instead of
        // failing the whole decode when they're missing.
        currentStreak = try container.decodeIfPresent(
            Int.self,
            forKey: .currentStreak
        ) ?? 0

        lastPostWeekStart = try container.decodeIfPresent(
            Timestamp.self,
            forKey: .lastPostWeekStart
        )

        // Also postdates existing accounts — every account gets the
        // all-enabled default until they change it themselves.
        notificationPreferences = try container.decodeIfPresent(
            NotificationPreferences.self,
            forKey: .notificationPreferences
        ) ?? NotificationPreferences()

        fcmToken = try container.decodeIfPresent(
            String.self,
            forKey: .fcmToken
        )

        email = try container.decode(
            String.self,
            forKey: .email
        )
    }
}

extension User {
    static var MOCK_USERS: [User] = [
        .init(id: NSUUID().uuidString, username: "mandolorian", profileImageUrl: nil, bio: "This is the way", friendUids: [], currentStreak: 4, lastPostWeekStart: Timestamp(date: DateWeek.startOfWeek(containing: Date())), email: "mando@gmail.com"),
        .init(id: NSUUID().uuidString, username: "ahsoka", profileImageUrl: nil, bio: "Snips", friendUids: [], email: "ashoka@gmail.com"),
        .init(id: NSUUID().uuidString, username: "anakin", profileImageUrl: nil, bio: "Skyguy", friendUids: [], email: "anakin@gmail.com"),
        .init(id: NSUUID().uuidString, username: "yoda", profileImageUrl: nil, bio: "Do or do not there is no try", friendUids: [], email: "yoda@gmail.com"),
    ]
}
