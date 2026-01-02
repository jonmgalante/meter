import Foundation

enum Formatters {
    static func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    static func monthYear(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "LLLL yyyy"
        return df.string(from: date)
    }

    static func year(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy"
        return df.string(from: date)
    }

    static func timeOnly(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        df.dateStyle = .none
        return df.string(from: date)
    }

    static func meters(_ meters: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        let s = nf.string(from: NSNumber(value: meters)) ?? "\(meters)"
        return "\(s)m"
    }
}
