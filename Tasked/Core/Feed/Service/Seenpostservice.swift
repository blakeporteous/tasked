//
//  SeenPostsService.swift
//  Tasked
//
//  New (Story bar pass): tracks which of this week's friend posts the
//  signed-in user has already scrolled past in the Home feed — backs the
//  Instagram-style "story" row at the top of FeedView (StoryBarView).
//  Mirrors RecentSearchService's pattern: stored locally in UserDefaults,
//  keyed per uid, rather than in Firestore — "have I personally scrolled
//  past this" is a per-device convenience, not data anyone else needs to
//  read or that needs to sync.
//  Automatically resets whenever the calendar week changes, since the whole
//  point is tracking "seen" against THIS week's posts — last week's seen
//  state is meaningless once the feed re-scopes to a new week.
//

import Foundation

struct SeenPostsService {
    private static func idsKey(for uid: String) -> String {
        "seenPostIds_\(uid)"
    }

    private static func weekStartKey(for uid: String) -> String {
        "seenPostsWeekStart_\(uid)"
    }

    /// Post ids the signed-in user has scrolled past THIS week. Empty if
    /// nothing's ever been stored, or if what's stored is from a stale
    /// (previous) week — a new week means a new set of story posts, so old
    /// "seen" state no longer means anything.
    static func fetchSeenIds(for uid: String) -> Set<String> {
        let currentWeekStart = DateWeek.startOfWeek(containing: Date())
        let storedWeekStart = UserDefaults.standard.object(forKey: weekStartKey(for: uid)) as? Date

        guard storedWeekStart == currentWeekStart else {
            return []
        }
        let ids = UserDefaults.standard.stringArray(forKey: idsKey(for: uid)) ?? []
        return Set(ids)
    }

    /// Marks `postId` as seen for `uid`, stamping the current week alongside
    /// it so a future fetchSeenIds(for:) call knows whether to trust it or
    /// discard it as stale.
    static func markSeen(_ postId: String, for uid: String) {
        var ids = fetchSeenIds(for: uid)
        ids.insert(postId)
        UserDefaults.standard.set(Array(ids), forKey: idsKey(for: uid))
        UserDefaults.standard.set(DateWeek.startOfWeek(containing: Date()), forKey: weekStartKey(for: uid))
    }
}
