//
//  RelativeTime.swift
//  Tasked
//
//  New (Comment likes + replies pass): short, ROUNDED "time ago" formatting
//  — "5h", "1d", "2w" — factored out of AppNotification so Comment can show
//  the same style of timestamp without duplicating the bucket/rounding
//  logic. See AppNotification.timeAgo and Comment.timeAgo for the two call
//  sites.
//

import Foundation
import Firebase

enum RelativeTime {
    static func string(since timestamp: Timestamp) -> String {
        let seconds = max(0, Date().timeIntervalSince(timestamp.dateValue()))

        switch seconds {
        case ..<60:
            return "now"
        case ..<3600: // < 1 hour
            return "\(Int((seconds / 60).rounded()))m"
        case ..<86_400: // < 1 day
            return "\(Int((seconds / 3600).rounded()))h"
        case ..<604_800: // < 1 week
            return "\(Int((seconds / 86_400).rounded()))d"
        case ..<2_592_000: // < ~1 month
            return "\(Int((seconds / 604_800).rounded()))w"
        case ..<31_536_000: // < 1 year
            return "\(Int((seconds / 2_592_000).rounded()))mo"
        default:
            return "\(Int((seconds / 31_536_000).rounded()))y"
        }
    }
}
