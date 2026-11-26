import Foundation

enum TimeFormat {
    // Accept seconds or m:ss with an optional fractional second for a split.
    static func parseSplitSeconds(_ input: String) -> Double? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), let last = parts.last,
              last.wholeMatch(of: #/[0-9]+(?:\.[0-9]+)?/#) != nil,
              let seconds = Double(last), seconds.isFinite else { return nil }
        if parts.count == 1 { return seconds }
        guard seconds < 60, let minutes = nonnegativeInteger(parts[0]) else { return nil }
        return Double(minutes) * 60 + seconds
    }

    // Rest accepts whole seconds, m:ss, :ss and an optional trailing r.
    static func parseRestSeconds(_ input: String) -> Int? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.last?.lowercased() == "r" { text.removeLast() }
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), let last = parts.last,
              let seconds = nonnegativeInteger(last) else { return nil }
        if parts.count == 1 { return seconds }
        let minutes = parts[0].isEmpty ? 0 : nonnegativeInteger(parts[0])
        guard seconds < 60, let minutes, minutes <= (Int.max - seconds) / 60 else { return nil }
        return minutes * 60 + seconds
    }

    private static func nonnegativeInteger(_ text: Substring) -> Int? {
        guard text.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return Int(text)
    }

    static func formatSplit(_ seconds: Double?) -> String {
        guard let seconds else { return "" }
        guard seconds.isFinite else { return "Unavailable" }
        guard seconds >= 0, let tenths = Int(exactly: (seconds * 10).rounded()) else { return "\(seconds) s" }
        return "\(tenths / 600):" + String(format: "%02d.%d", tenths % 600 / 10, tenths % 10)
    }

    static func formatRest(_ seconds: Int?) -> String {
        guard let seconds else { return "" }
        guard seconds >= 0 else { return String(seconds) }
        return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}
