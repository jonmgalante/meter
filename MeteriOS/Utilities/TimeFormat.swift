import Foundation

enum TimeFormat {
    // Parses "m:ss", "m:ss.t", or "ss" → seconds (Double)
    static func parseSplitSeconds(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }

        if t.contains(":") {
            let parts = t.split(separator: ":", omittingEmptySubsequences: true)
            guard parts.count == 2 else { return nil }
            guard let m = Double(parts[0]) else { return nil }
            guard let sec = Double(parts[1]) else { return nil }
            return m * 60.0 + sec
        } else {
            return Double(t)
        }
    }

    // Parses rest like "2:30", ":45", "45", "2:30r" → seconds (Int)
    static func parseRestSeconds(_ s: String) -> Int? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if t.hasSuffix("r") || t.hasSuffix("R") { t.removeLast() }

        if t.contains(":") {
            let parts = t.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let left = String(parts[0])
            let right = String(parts[1])
            let m = Int(left) ?? 0
            let sec = Int(right) ?? 0
            return m * 60 + sec
        } else {
            return Int(t)
        }
    }

    static func formatSplit(_ seconds: Double?) -> String {
        guard let seconds else { return "" }
        let m = Int(seconds) / 60
        let s = seconds - Double(m * 60)
        return String(format: "%d:%04.1f", m, s)
    }

    static func formatRest(_ seconds: Int?) -> String {
        guard let seconds else { return "" }
        let m = seconds / 60
        let s = seconds % 60
        return "\(m):" + String(format: "%02d", s)
    }
}
