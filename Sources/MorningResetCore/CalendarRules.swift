import Foundation

public enum CalendarRules {
    /// Stored date labels never change with travel. Gregorian arithmetic avoids 24-hour assumptions.
    public static func localCalendar(timeZone: TimeZone = .current) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = Calendar.current.firstWeekday
        return calendar
    }

    public static func dateKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    public static func date(from key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    public static func night(on day: Date, time: LockTime, calendar: Calendar) -> Date {
        // Spring gap moves forward; autumn repeated hour uses its first occurrence.
        calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day,
                      matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)!
    }

    public static func latestNight(in state: ResetState, at now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        return [yesterday, today].map { day in
            let key = dateKey(day, calendar: calendar)
            let time = state.tonightOverride?.dateKey == key ? state.tonightOverride!.time : state.lockTime
            return night(on: day, time: time, calendar: calendar)
        }.filter { $0 <= now }.max()!
    }

    public static func nextNight(in state: ResetState, at now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        for offset in 0...2 {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let key = dateKey(day, calendar: calendar)
            let time = state.tonightOverride?.dateKey == key ? state.tonightOverride!.time : state.lockTime
            let candidate = night(on: day, time: time, calendar: calendar)
            if candidate > now { return candidate }
        }
        return calendar.date(byAdding: .day, value: 1, to: now)!
    }
}

public struct StreakSummary: Equatable {
    public var current: Int
    public var best: Int
    public var thisWeek: Int

    public static func calculate(history: [HistoryEntry], now: Date, calendar: Calendar) -> Self {
        let keys = Set(history.filter(\.protectedSuccess).map(\.localDate))
        let dates = keys.compactMap { CalendarRules.date(from: $0, calendar: calendar) }.sorted()
        var best = 0, run = 0
        var prior: Date?
        for date in dates {
            let adjacent = prior.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) }
            run = adjacent.map { calendar.isDate($0, inSameDayAs: date) } == true ? run + 1 : 1
            best = max(best, run)
            prior = date
        }
        let today = calendar.startOfDay(for: now)
        var cursor = today
        if !keys.contains(CalendarRules.dateKey(today, calendar: calendar)) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var current = 0
        while keys.contains(CalendarRules.dateKey(cursor, calendar: calendar)) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekCount = dates.filter { date in
            guard let week else { return false }
            return date >= week.start && date < week.end
                && CalendarRules.dateKey(date, calendar: calendar) <= CalendarRules.dateKey(now, calendar: calendar)
        }.count
        return Self(current: current, best: best, thisWeek: weekCount)
    }
}
