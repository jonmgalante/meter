import Foundation
import SwiftData

/// Previous results are display-only values. No managed object leaves the detail screen.
struct RecordedWorkout {
    struct Group {
        let reps: Int
        let meters: Int
        let rest: Int?
        let split: Double?
    }

    let date: Date
    let title: String
    let total: Int
    let groups: [Group]
    let extraMeters: Int?

    init(_ workout: ErgWorkout) {
        date = workout.startDate
        title = workout.title
        total = workout.totalMeters
        extraMeters = Self.extraMeters(in: workout)
        groups = Self.orderedPieces(workout).map {
            Group(reps: $0.reps, meters: $0.metersPerRep, rest: $0.restSeconds, split: $0.avgSplitSecPer500)
        }
    }

    static func orderedPieces(_ workout: ErgWorkout) -> [ErgPiece] {
        workout.pieces.sorted {
            if $0.orderIndex != $1.orderIndex { return $0.orderIndex < $1.orderIndex }
            if $0.id != $1.id { return $0.id < $1.id }
            return $0.persistentModelID < $1.persistentModelID
        }
    }

    static func extraMeters(in workout: ErgWorkout) -> Int? {
        var remaining = workout.totalMeters
        for group in workout.pieces {
            guard let meters = PieceDraft.workMeters(reps: group.reps, meters: group.metersPerRep),
                  remaining >= meters else { return nil }
            remaining -= meters
        }
        return remaining
    }
}

struct WorkoutDraft: Identifiable {
    let id = UUID()
    let previous: RecordedWorkout?
    var date: Date
    var notes = ""
    var pieces: [PieceDraft]
    private var enteredTotal: String?

    init(repeating previous: RecordedWorkout? = nil, now: Date = .now) {
        self.previous = previous
        date = now
        if let previous {
            pieces = previous.groups.map {
                PieceDraft(repsText: String($0.reps), metersText: String($0.meters),
                           restText: TimeFormat.formatRest($0.rest))
            }
        } else {
            pieces = [PieceDraft(metersText: "2000")]
        }
    }

    var piecesTotal: Int? {
        guard !pieces.isEmpty else { return previous == nil ? 0 : nil }
        var sum = 0
        for piece in pieces {
            guard let work = piece.totalMeters else { return nil }
            let (next, overflow) = sum.addingReportingOverflow(work)
            guard !overflow else { return nil }
            sum = next
        }
        return sum
    }

    var totalText: String {
        get {
            if let enteredTotal { return enteredTotal }
            guard let previous, !previous.groups.isEmpty, let piecesTotal else { return "" }
            return String(piecesTotal)
        }
        set { enteredTotal = newValue }
    }

    var values: NewWorkout? {
        guard let total = Int(totalText.trimmingCharacters(in: .whitespacesAndNewlines)), total >= 0,
              pieces.isEmpty || piecesTotal != nil else { return nil }
        var groups: [NewWorkout.Group] = []
        for piece in pieces {
            guard let group = piece.values else { return nil }
            groups.append(group)
        }
        return NewWorkout(id: id, day: Calendar.current.startOfDay(for: date), total: total, notes: notes, groups: groups)
    }
}

struct PieceDraft: Identifiable {
    let id = UUID()
    var repsText = "1"
    var metersText = ""
    var restText = ""
    var splitText = ""

    private var meters: Int? {
        let text = metersText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard text.hasSuffix("k") else { return Int(text) }
        let parts = text.dropLast().split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count),
              parts.contains(where: { !$0.isEmpty }),
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
        let fraction = parts.count == 2 ? parts[1] : ""
        guard fraction.dropFirst(3).allSatisfy({ $0 == "0" }) else { return nil }
        let digits = String(fraction.prefix(3))
        return Int(String(parts[0]) + digits + String(repeating: "0", count: 3 - digits.count))
    }

    static func workMeters(reps: Int, meters: Int) -> Int? {
        guard reps > 0, meters > 0 else { return nil }
        let (work, overflow) = reps.multipliedReportingOverflow(by: meters)
        return overflow ? nil : work
    }

    var totalMeters: Int? {
        guard let reps = Int(repsText), let meters else { return nil }
        return Self.workMeters(reps: reps, meters: meters)
    }

    var values: NewWorkout.Group? {
        guard let reps = Int(repsText), let meters, Self.workMeters(reps: reps, meters: meters) != nil else { return nil }
        let rest = TimeFormat.parseRestSeconds(restText)
        let split = TimeFormat.parseSplitSeconds(splitText)
        guard rest != nil || restText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              split != nil || splitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return NewWorkout.Group(id: id, reps: reps, meters: meters, rest: rest, split: split)
    }
}
