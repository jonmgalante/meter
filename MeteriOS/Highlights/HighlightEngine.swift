import Foundation

struct Highlight: Identifiable {
    enum Kind {
        case monthToDate
        case yearToDate
        case rolling4Weeks
        case avgSessionLast8
        case best2kEver
    }

    let id = UUID()
    let kind: Kind

    let title: String
    let primaryValue: String
    let secondaryValue: String?
    let body: String

    let chart: MiniChart?
}

struct MiniChart {
    struct Point: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
    }

    let points: [Point]
    let average: Double
}

enum HighlightEngine {

    static func computeHighlights(
        workouts: [ErgWorkout],
        anchorDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [Highlight] {
        let sorted = workouts.sorted(by: { $0.startDate < $1.startDate })

        return [
            monthToDateHighlight(workouts: sorted, anchorDate: anchorDate, calendar: calendar),
            yearToDateHighlight(workouts: sorted, anchorDate: anchorDate, calendar: calendar),
            rolling4WeeksHighlight(workouts: sorted, anchorDate: anchorDate, calendar: calendar),
            avgSessionLast8Highlight(workouts: sorted),
            best2kEverHighlight(workouts: sorted)
        ].compactMap { $0 }
    }

    // 1) Month-to-date vs last month (same day-of-month window)
    private static func monthToDateHighlight(workouts: [ErgWorkout], anchorDate: Date, calendar: Calendar) -> Highlight? {
        let startThisMonth = calendar.dateInterval(of: .month, for: anchorDate)!.start
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: anchorDate))!

        let thisMonthWorkouts = inInterval(workouts, start: startThisMonth, end: endExclusive)
        let thisMeters = thisMonthWorkouts.reduce(0) { $0 + $1.totalMeters }
        let thisSessions = thisMonthWorkouts.count

        guard let startLastMonth = calendar.date(byAdding: .month, value: -1, to: startThisMonth) else { return nil }
        let lastMonthInterval = calendar.dateInterval(of: .month, for: startLastMonth)!

        let dayOfMonth = calendar.component(.day, from: anchorDate)
        let lastMonthEndCandidate = calendar.date(byAdding: .day, value: dayOfMonth, to: startLastMonth)!
        let lastMonthEndExclusive = min(lastMonthEndCandidate, lastMonthInterval.end)

        let lastMonthWorkouts = inInterval(workouts, start: startLastMonth, end: lastMonthEndExclusive)
        let lastMeters = lastMonthWorkouts.reduce(0) { $0 + $1.totalMeters }

        let compareText: String
        if lastMeters > 0 {
            compareText = "\(percentChange(current: thisMeters, prior: lastMeters)) vs last month"
        } else {
            compareText = "Not enough history to compare yet"
        }

        let points = dailyPoints(workouts: thisMonthWorkouts, start: startThisMonth, endExclusive: endExclusive, calendar: calendar)
        let avg = points.isEmpty ? 0 : Double(points.reduce(0) { $0 + $1.value }) / Double(points.count)

        return Highlight(
            kind: .monthToDate,
            title: "Month to Date",
            primaryValue: Formatters.meters(thisMeters),
            secondaryValue: sessionsString(thisSessions),
            body: compareText,
            chart: MiniChart(points: points, average: avg)
        )
    }

    // 2) Year-to-date vs last year (same day-of-year window)
    private static func yearToDateHighlight(workouts: [ErgWorkout], anchorDate: Date, calendar: Calendar) -> Highlight? {
        let startThisYear = calendar.dateInterval(of: .year, for: anchorDate)!.start
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: anchorDate))!

        let thisYearWorkouts = inInterval(workouts, start: startThisYear, end: endExclusive)
        let thisMeters = thisYearWorkouts.reduce(0) { $0 + $1.totalMeters }
        let thisSessions = thisYearWorkouts.count

        guard let startLastYear = calendar.date(byAdding: .year, value: -1, to: startThisYear) else { return nil }
        let daysIntoYear = calendar.dateComponents([.day], from: startThisYear, to: endExclusive).day ?? 0
        let lastYearEndExclusive = calendar.date(byAdding: .day, value: daysIntoYear, to: startLastYear)!

        let lastYearWorkouts = inInterval(workouts, start: startLastYear, end: lastYearEndExclusive)
        let lastMeters = lastYearWorkouts.reduce(0) { $0 + $1.totalMeters }

        let compareText: String
        if lastMeters > 0 {
            compareText = "\(percentChange(current: thisMeters, prior: lastMeters)) vs last year"
        } else {
            compareText = "Not enough history to compare yet"
        }

        return Highlight(
            kind: .yearToDate,
            title: "Year to Date",
            primaryValue: Formatters.meters(thisMeters),
            secondaryValue: sessionsString(thisSessions),
            body: compareText,
            chart: nil
        )
    }

    // 3) Rolling 4-week volume
    private static func rolling4WeeksHighlight(workouts: [ErgWorkout], anchorDate: Date, calendar: Calendar) -> Highlight? {
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: anchorDate))!
        let start = calendar.date(byAdding: .day, value: -28, to: endExclusive)!

        let w = inInterval(workouts, start: start, end: endExclusive)
        let meters = w.reduce(0) { $0 + $1.totalMeters }
        let sessions = w.count

        return Highlight(
            kind: .rolling4Weeks,
            title: "Last 4 Weeks",
            primaryValue: Formatters.meters(meters),
            secondaryValue: sessionsString(sessions),
            body: "Rolling 28-day total",
            chart: nil
        )
    }

    // 4) Avg meters per session (last 8 sessions)
    private static func avgSessionLast8Highlight(workouts: [ErgWorkout]) -> Highlight? {
        let last8 = Array(workouts.suffix(8))
        let total = last8.reduce(0) { $0 + $1.totalMeters }
        let avg = last8.isEmpty ? 0 : Double(total) / Double(last8.count)

        let df = DateFormatter()
        df.dateFormat = "M/d"
        let points = last8.map { MiniChart.Point(label: df.string(from: $0.startDate), value: $0.totalMeters) }

        return Highlight(
            kind: .avgSessionLast8,
            title: "Average Session",
            primaryValue: Formatters.meters(Int(avg.rounded())),
            secondaryValue: "Last \(last8.count) sessions",
            body: "Based on your most recent sessions",
            chart: MiniChart(points: points, average: avg)
        )
    }

    // 5) Best 2k ever (best split among 2k pieces)
    private static func best2kEverHighlight(workouts: [ErgWorkout]) -> Highlight? {
        var bestSplit: Double?
        var bestDate: Date?

        for w in workouts {
            for p in w.pieces {
                guard p.metersPerRep == 2000 else { continue }
                guard let split = p.avgSplitSecPer500 else { continue }
                if bestSplit == nil || split < bestSplit! {
                    bestSplit = split
                    bestDate = w.startDate
                }
            }
        }

        guard let bestSplit, let bestDate else {
            return Highlight(
                kind: .best2kEver,
                title: "Best 2k Ever",
                primaryValue: "—",
                secondaryValue: nil,
                body: "Log a 2k piece to set a PR",
                chart: nil
            )
        }

        let splitText = splitString(bestSplit)
        let time2k = timeString(bestSplit * 4.0)

        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none

        return Highlight(
            kind: .best2kEver,
            title: "Best 2k Ever",
            primaryValue: "\(splitText) /500m",
            secondaryValue: df.string(from: bestDate),
            body: "≈ \(time2k) for 2k",
            chart: nil
        )
    }

    // MARK: Helpers

    private static func inInterval(_ workouts: [ErgWorkout], start: Date, end: Date) -> [ErgWorkout] {
        workouts.filter { $0.startDate >= start && $0.startDate < end }
    }

    private static func dailyPoints(workouts: [ErgWorkout], start: Date, endExclusive: Date, calendar: Calendar) -> [MiniChart.Point] {
        let totals = Dictionary(grouping: workouts, by: { $0.dayKey })
            .mapValues { $0.reduce(0) { $0 + $1.totalMeters } }

        let df = DateFormatter()
        df.dateFormat = "d"

        var points: [MiniChart.Point] = []
        var cursor = calendar.startOfDay(for: start)
        while cursor < endExclusive {
            points.append(.init(label: df.string(from: cursor), value: totals[cursor] ?? 0))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return points
    }

    private static func percentChange(current: Int, prior: Int) -> String {
        guard prior > 0 else { return "—" }
        let delta = Double(current - prior) / Double(prior) * 100.0
        let rounded = Int(delta.rounded())
        return rounded >= 0 ? "+\(rounded)%" : "\(rounded)%"
    }

    private static func sessionsString(_ n: Int) -> String {
        "\(n) " + (n == 1 ? "session" : "sessions")
    }

    private static func splitString(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = seconds - Double(m * 60)
        return String(format: "%d:%04.1f", m, s)
    }

    private static func timeString(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = seconds - Double(m * 60)
        return String(format: "%d:%04.1f", m, s)
    }
}
