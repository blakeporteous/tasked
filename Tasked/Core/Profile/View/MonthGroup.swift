//
//  MonthGroup.swift
//  Tasked
//
//  New (Monthly report pass): groups a user's posts by calendar month so
//  the profile grid can show one "report card" per month instead of a flat
//  photo grid — see PostGridView.
//

import Foundation

struct MonthGroup: Identifiable, Hashable {
    let year: Int
    let month: Int // 1...12
    /// This month's posts, newest first.
    let posts: [Post]

    var id: String { "\(year)-\(month)" }

    var monthName: String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let date = Calendar.current.date(from: components) ?? Date()

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).uppercased()
    }

    /// Cover photo shown behind the month name — the most recent post's image.
    var coverImageUrl: String {
        posts.first?.imageUrl ?? ""
    }
}
