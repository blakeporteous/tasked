//
//  Report.swift
//  Tasked
//
//  New: backs post reporting. Reports live in their own top-level
//  "postReports" collection (not a subcollection of posts) so a post can be
//  deleted without losing the report trail against whoever posted it.
//

import Foundation
import Firebase

enum ReportReason: String, CaseIterable, Identifiable, Codable {
    case spam
    case inappropriate
    case harassment
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spam: return "Spam"
        case .inappropriate: return "Inappropriate Content"
        case .harassment: return "Harassment or Bullying"
        case .other: return "Other"
        }
    }
}

struct PostReport: Identifiable, Codable, Hashable {
    /// "{reporterUid}_{postId}" — same one-doc-per-pair pattern as
    /// FriendRequest, so a user can only have one open report against a
    /// given post; reporting the same post again just overwrites the reason
    /// and timestamp rather than creating a duplicate row.
    let id: String
    let postId: String
    let postOwnerUid: String
    let reporterUid: String
    var reason: String
    var status: String // "pending" — anything else is set by staff, never the client
    let timestamp: Timestamp
}
