//
//  AutoDeleteFormat.swift
//  xNotes
//

import Foundation

/// Wording for the time left until an unlocked tab is deleted automatically,
/// shared by the sidebar tooltip and the context line.
enum AutoDeleteFormat {
    /// "in 3 days", "in 5 hours"; "any moment" once the deadline has passed.
    static func relative(_ deadline: Date, now: Date = Date()) -> String {
        guard deadline > now else { return "any moment" }
        return relativeFormatter.localizedString(for: deadline, relativeTo: now)
    }

    /// e.g. "24 Nov 2026 at 14:05"
    static func absolute(_ deadline: Date) -> String {
        absoluteFormatter.string(from: deadline)
    }

    /// Less than a day or a fifth of the auto-delete period left: worth a warning color.
    static func isSoon(_ deadline: Date, periodDays: Int, now: Date = Date()) -> Bool {
        let remaining = deadline.timeIntervalSince(now)
        let period = TimeInterval(periodDays * 24 * 60 * 60)
        return remaining < max(24 * 60 * 60, period * 0.2)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private static let absoluteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.doesRelativeDateFormatting = true
        return f
    }()
}
