//
//  RecentSearchService.swift
//  Tasked
//
//  New: backs the "Recent" list on SearchView's idle state — the row of
//  previously-searched people shown before you type anything, matching
//  Instagram's search screen. Stored locally in UserDefaults rather than
//  Firestore since this is a per-device convenience, not data that needs to
//  sync or be readable by anyone else. Keyed per signed-in uid so switching
//  accounts on the same device doesn't mix histories.
//

import Foundation

struct RecentSearchService {
    private static let maxEntries = 10

    private static func key(for uid: String) -> String {
        "recentSearches_\(uid)"
    }

    /// Ordered most-recent-first list of previously-searched user ids.
    static func fetch(for uid: String) -> [String] {
        UserDefaults.standard.stringArray(forKey: key(for: uid)) ?? []
    }

    /// Moves `searchedUid` to the front, de-duping any earlier occurrence,
    /// and trims to maxEntries.
    static func record(_ searchedUid: String, for uid: String) {
        var ids = fetch(for: uid)
        ids.removeAll { $0 == searchedUid }
        ids.insert(searchedUid, at: 0)
        if ids.count > maxEntries {
            ids = Array(ids.prefix(maxEntries))
        }
        UserDefaults.standard.set(ids, forKey: key(for: uid))
    }

    static func remove(_ searchedUid: String, for uid: String) {
        var ids = fetch(for: uid)
        ids.removeAll { $0 == searchedUid }
        UserDefaults.standard.set(ids, forKey: key(for: uid))
    }

    static func clear(for uid: String) {
        UserDefaults.standard.removeObject(forKey: key(for: uid))
    }
}
