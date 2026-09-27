//
//  ReportService.swift
//  Tasked
//
//  New: backs post reporting. There's no in-app moderation UI yet — a report
//  just lands as a document in the "postReports" Firestore collection.
//  Client read access to that collection is fully locked down (see Firestore
//  rules), so for now reviewing reports means opening the Firebase console
//  and looking at the collection directly. A Cloud Function that emails/
//  Slack-notifies on new reports, or a small admin-only in-app screen, would
//  be the natural next step once report volume makes the console tedious.
//

import Foundation
import Firebase
import FirebaseFirestore

struct ReportService {

    private static let collection = Firestore.firestore().collection("postReports")

    /// Files (or re-files, if this user already reported this post) a report
    /// against `post`. No-ops if the current user is the post's own owner.
    static func report(post: Post, reason: ReportReason, currentUser: User) async throws {
        guard currentUser.id != post.ownerUid else { return }

        let id = "\(currentUser.id)_\(post.id)"
        let data: [String: Any] = [
            "id": id,
            "postId": post.id,
            "postOwnerUid": post.ownerUid,
            "reporterUid": currentUser.id,
            "reason": reason.rawValue,
            "status": "pending",
            "timestamp": Timestamp()
        ]
        try await collection.document(id).setData(data)
    }
}
