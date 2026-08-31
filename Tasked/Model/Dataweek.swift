//
//  DateWeek.swift
//  Tasked
//
//  New (Feed week-scoping pass): pure date math for "the Monday-Sunday week
//  containing a given date," used to scope the feed to the current week
//  without hardcoding it and without depending on any Firestore document.
//
//  Uses the .yearForWeekOfYear/.weekOfYear round-trip technique rather than
//  manual weekday-offset arithmetic: with firstWeekday pinned to Monday,
//  asking Calendar for those two components and reconstructing a date from
//  them reliably lands on that week's Monday regardless of the device's
//  region settings (which might otherwise default to Sunday-first) — manual
//  "subtract N days" logic is the usual source of off-by-one bugs right at
//  the Sunday/Monday boundary, which this sidesteps entirely.
//
//  Deliberately uses Calendar.current (the device's local calendar/timezone)
//  per the existing app's convention of not forcing UTC anywhere else.
//

import Foundation

enum DateWeek {

    /// Monday 00:00 of the week containing `date`, in the given calendar/timezone.
    static func startOfWeek(containing date: Date = Date(), calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2 // Monday

        let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let monday = cal.date(from: components) else { return cal.startOfDay(for: date) }
        return cal.startOfDay(for: monday)
    }

    /// The instant the current week ends and the next begins — the following
    /// Monday 00:00. Used as an EXCLUSIVE upper bound in Firestore range
    /// queries, so Sunday 23:59:59.999 is included but the new week's first
    /// post is not.
    static func endOfWeek(containing date: Date = Date(), calendar: Calendar = .current) -> Date {
        var cal = calendar
        cal.firstWeekday = 2
        let start = startOfWeek(containing: date, calendar: cal)
        return cal.date(byAdding: .day, value: 7, to: start) ?? start
    }

    /// Convenience: (Monday 00:00, next Monday 00:00) for right now.
    static func currentWeekRange(calendar: Calendar = .current) -> (start: Date, end: Date) {
        let now = Date()
        return (startOfWeek(containing: now, calendar: calendar), endOfWeek(containing: now, calendar: calendar))
    }
}
