//
//  WeeklyTaskService.swift
//  Tasked
//
//  Backs Features 3 & 4: reads the currently active weekly task from the
//  "weeklyTasks" Firestore collection.
//  Updated (Feed week-scoping pass): fetchCurrentTask() previously picked
//  isActive == true, order by startDate desc, limit 1 — i.e. "whichever
//  document happens to be newest," regardless of whether today's date
//  actually falls inside it. Since multiple weeks are now pre-populated in
//  advance (including future ones), that could return a week that hasn't
//  started yet, or rely on an isActive flag someone has to remember to flip
//  every Monday. Replaced with a date-based lookup: the most recently
//  STARTED week (startDate <= now) is the current one, as long as weeks are
//  entered as contiguous 7-day ranges — which the endDate check below
//  defends against if they aren't (e.g. a gap where next week's doc hasn't
//  been created yet).
//

import Foundation
import Firebase

struct WeeklyTaskService {

    private static let collection = Firestore.firestore().collection("weeklyTasks")

    /// Returns the task for the current calendar week, determined purely by
    /// date rather than an `isActive` flag or "newest document." This is a
    /// single-field range + order (both on startDate), so it needs no
    /// composite index — Firestore auto-indexes that.
    static func fetchCurrentTask() async throws -> WeeklyTask? {
        let snapshot = try await collection
            .whereField("startDate", isLessThanOrEqualTo: Timestamp(date: Date()))
            .order(by: "startDate", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let task = try snapshot.documents.first.flatMap({ try $0.data(as: WeeklyTask.self) }) else {
            return nil
        }

        // Defends against a gap in the pre-populated data (e.g. this week's
        // doc exists but next week's hasn't been created yet, so the query
        // above would otherwise keep returning an already-ended week).
        return task.endDate.dateValue() > Date() ? task : nil
    }

    /// Looks up a specific past task by id, used when a post needs to show
    /// context beyond the denormalized title/description stored on it directly.
    static func fetchTask(withId id: String) async throws -> WeeklyTask {
        let snapshot = try await collection.document(id).getDocument()
        return try snapshot.data(as: WeeklyTask.self)
    }
}
