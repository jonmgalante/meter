import Foundation

enum SummaryRange: String, CaseIterable, Identifiable {
    case day = "D"
    case week = "W"
    case month = "M"
    case year = "Y"

    var id: String { rawValue }
}

struct SummaryBucket: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date

    var totalDistance: Int = 0
    var workoutCount: Int = 0
}

struct SummaryStats {
    let headlineLabel: String
    let headlineValue: String
    let subLabel: String
    let buckets: [SummaryBucket]
}

enum Aggregation {
    static func buildStats(
        workouts: [ErgWorkout],
        range: SummaryRange,
        anchorDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SummaryStats {

        switch range {

        case .day:
            let dayStart = calendar.startOfDay(for: anchorDate)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let dayWorkouts = workouts.filter { $0.startDate >= dayStart && $0.startDate < dayEnd }
            let total = dayWorkouts.reduce(0) { $0 + $1.totalMeters }

            return SummaryStats(
                headlineLabel: "TOTAL",
                headlineValue: Formatters.meters(total),
                subLabel: Formatters.shortDate(dayStart),
                buckets: []
            )

        case .week:
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: anchorDate)!
            let buckets = makeDayBuckets(from: weekInterval.start, days: 7, calendar: calendar)
            let filled = fillBuckets(buckets: buckets, workouts: workouts)

            let avg = averagePerBucket(filled)
            let endLabelDate = calendar.date(byAdding: .day, value: 6, to: weekInterval.start)!

            return SummaryStats(
                headlineLabel: "DAILY AVERAGE",
                headlineValue: Formatters.meters(avg),
                subLabel: "\(Formatters.shortDate(weekInterval.start)) – \(Formatters.shortDate(endLabelDate))",
                buckets: filled
            )

        case .month:
            let monthInterval = calendar.dateInterval(of: .month, for: anchorDate)!
            let days = calendar.range(of: .day, in: .month, for: anchorDate)?.count ?? 30

            let buckets = makeDayBuckets(from: monthInterval.start, days: days, calendar: calendar)
            let filled = fillBuckets(buckets: buckets, workouts: workouts)

            let avg = averagePerBucket(filled)

            return SummaryStats(
                headlineLabel: "DAILY AVERAGE",
                headlineValue: Formatters.meters(avg),
                subLabel: Formatters.monthYear(anchorDate),
                buckets: filled
            )

        case .year:
            let yearInterval = calendar.dateInterval(of: .year, for: anchorDate)!
            let buckets = makeMonthBuckets(forYearStart: yearInterval.start, calendar: calendar)
            let filled = fillBuckets(buckets: buckets, workouts: workouts)

            let avg = averagePerDayInYear(
                filled,
                yearStart: yearInterval.start,
                yearEnd: yearInterval.end,
                calendar: calendar
            )

            return SummaryStats(
                headlineLabel: "DAILY AVERAGE",
                headlineValue: Formatters.meters(avg),
                subLabel: Formatters.year(anchorDate),
                buckets: filled
            )
        }
    }

    // MARK: Bucket builders

    private static func makeDayBuckets(from start: Date, days: Int, calendar: Calendar) -> [SummaryBucket] {
        (0..<days).map { offset in
            let s = calendar.date(byAdding: .day, value: offset, to: start)!
            let e = calendar.date(byAdding: .day, value: 1, to: s)!
            return SummaryBucket(startDate: s, endDate: e)
        }
    }

    private static func makeMonthBuckets(forYearStart yearStart: Date, calendar: Calendar) -> [SummaryBucket] {
        (0..<12).map { m in
            let monthStart = calendar.date(byAdding: .month, value: m, to: yearStart)!
            let interval = calendar.dateInterval(of: .month, for: monthStart)!
            return SummaryBucket(startDate: interval.start, endDate: interval.end)
        }
    }

    // MARK: Filling

    private static func fillBuckets(buckets: [SummaryBucket], workouts: [ErgWorkout]) -> [SummaryBucket] {
        var out = buckets
        for i in out.indices {
            let b = out[i]
            let inBucket = workouts.filter { $0.startDate >= b.startDate && $0.startDate < b.endDate }
            out[i].workoutCount = inBucket.count
            out[i].totalDistance = inBucket.reduce(0) { $0 + $1.totalMeters }
        }
        return out
    }

    // MARK: Averages

    private static func averagePerBucket(_ buckets: [SummaryBucket]) -> Int {
        guard !buckets.isEmpty else { return 0 }
        let total = buckets.reduce(0) { $0 + $1.totalDistance }
        return Int(Double(total) / Double(buckets.count))
    }

    private static func averagePerDayInYear(_ buckets: [SummaryBucket], yearStart: Date, yearEnd: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: yearStart, to: yearEnd).day ?? 365
        guard days > 0 else { return 0 }
        let total = buckets.reduce(0) { $0 + $1.totalDistance }
        return Int(Double(total) / Double(days))
    }
}
