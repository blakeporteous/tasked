//
//  WeeklyTask.swift
//  Tasked
//

import Foundation
import Firebase

struct WeeklyTask: Identifiable, Hashable, Codable {
    let id: String
    var title: String
    var description: String
    var startDate: Timestamp
    var endDate: Timestamp
    var isActive: Bool
}

extension WeeklyTask {
    static var MOCK_TASK = WeeklyTask(
        id: NSUUID().uuidString,
        title: "Play a round of golf",
        description: "Grab a friend and play a round this week.",
        startDate: Timestamp(),
        endDate: Timestamp(date: Date().addingTimeInterval(60 * 60 * 24 * 7)),
        isActive: true
    )
}
