//
//  WeeklyTaskService.swift
//  Tasked
//
//  Backs Features 3 & 4: reads the currently active weekly task from the
//  "weeklyTasks" Firestore collection.
//

import Foundation
import Firebase

struct WeeklyTaskService {

    private static let collection = Firestore.firestore().collection("weeklyTasks")

    /// Returns the task currently marked active, most-recently-started first.
    /// Requires a Firestore composite index on (isActive ==, startDate desc) — see project notes.
    static func fetchCurrentTask() async throws -> WeeklyTask? {
        let snapshot = try await collection
            .whereField("isActive", isEqualTo: true)
            .order(by: "startDate", descending: true)
            .limit(to: 1)
            .getDocuments()

        return try snapshot.documents.first.flatMap { try $0.data(as: WeeklyTask.self) }
    }

    /// Looks up a specific past task by id, used when a post needs to show
    /// context beyond the denormalized title/description stored on it directly.
    static func fetchTask(withId id: String) async throws -> WeeklyTask {
        let snapshot = try await collection.document(id).getDocument()
        return try snapshot.data(as: WeeklyTask.self)
    }
}
