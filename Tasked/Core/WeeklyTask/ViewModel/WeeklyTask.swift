//
//  WeeklyTask.swift
//  Tasked
//

import Foundation
import Firebase
import FirebaseFirestore // Necessary for @DocumentID in modern Firebase versions

struct WeeklyTask: Identifiable, Hashable, Codable {
    // Corrected: Tells the decoder to populate this with the Firestore document name ("week1")
    @DocumentID var id: String?
    var title: String
    var description: String
    var startDate: Timestamp
    var endDate: Timestamp
    var isActive: Bool
}

extension WeeklyTask {
    static var MOCK_TASK = WeeklyTask(
        id: UUID().uuidString, // Works seamlessly with the optional @DocumentID property wrapper
        title: "Play a round of golf",
        description: "Grab a friend and play a round this week.",
        startDate: Timestamp(),
        endDate: Timestamp(date: Date().addingTimeInterval(60 * 60 * 24 * 7)),
        isActive: true
    )
}
