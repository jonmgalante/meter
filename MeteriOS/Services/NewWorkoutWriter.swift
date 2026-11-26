import Foundation
import Observation
import SwiftData

struct NewWorkout {
    struct Group: Equatable {
        let id: UUID
        let reps: Int
        let meters: Int
        let rest: Int?
        let split: Double?
    }

    let id: UUID
    let day: Date
    let total: Int
    let notes: String
    let groups: [Group]

    func matches(_ workout: ErgWorkout) -> Bool {
        guard workout.id == id, workout.startDate == day, workout.dayKey == day, workout.title.isEmpty,
              workout.totalMeters == total, workout.notes.utf8.elementsEqual(notes.utf8),
              workout.pieces.count == groups.count else { return false }
        let ordered = workout.pieces.sorted { $0.orderIndex < $1.orderIndex }
        return groups.indices.allSatisfy { i in
            let group = groups[i], stored = ordered[i]
            return stored.id == group.id && stored.orderIndex == i && stored.reps == group.reps &&
                stored.metersPerRep == group.meters && stored.restSeconds == group.rest &&
                stored.avgSplitSecPer500?.bitPattern == group.split?.bitPattern
        }
    }
}

/// One writer per presentation, shared by all three ways of opening the form.
@MainActor @Observable
final class NewWorkoutWriter {
    enum Failure: LocalizedError {
        case invalid, collision, earlierSave

        var errorDescription: String? {
            switch self {
            case .invalid: "Enter a session total and check each group's reps, distance, rest and split."
            case .collision: "A record already uses a proposed identifier. Close and reopen the form to start a new workout."
            case .earlierSave: "The earlier save is already in Workouts. Later edits are still in this form. Close it to keep the saved workout."
            }
        }
    }

    private(set) var isSaving = false
    private(set) var finished = false
    private var attempted: NewWorkout?

    // Only detached values outlive save(). Releasing the form needs no executor hop.
    nonisolated deinit {}

    @discardableResult
    func save(_ draft: WorkoutDraft, in container: ModelContainer,
              commit: (ModelContext) throws -> Void = { try $0.save() }) throws -> Bool {
        guard !isSaving, !finished else { return false }
        isSaving = true
        defer { isSaving = false }
        guard let values = draft.values else { throw Failure.invalid }
        let context = ModelContext(container)
        context.autosaveEnabled = false

        // A failed save can have an uncertain outcome. Read the proposed ID in this
        // fresh context before constructing any models, even when the draft changed.
        let id = values.id
        var lookup = FetchDescriptor<ErgWorkout>(predicate: #Predicate { $0.id == id })
        lookup.fetchLimit = 2
        let existing = try context.fetch(lookup)
        if let found = existing.first {
            guard existing.count == 1, let attempted, attempted.matches(found) else { throw Failure.collision }
            guard values.matches(found) else { throw Failure.earlierSave }
            finished = true
            return true
        }

        let ids = values.groups.map(\.id)
        if !ids.isEmpty {
            var pieces = FetchDescriptor<ErgPiece>(predicate: #Predicate { ids.contains($0.id) })
            pieces.fetchLimit = 1
            guard Set(ids).count == ids.count, try context.fetch(pieces).isEmpty else { throw Failure.collision }
        }
        let groups = values.groups.enumerated().map { index, group in
            let piece = ErgPiece(orderIndex: index, reps: group.reps, metersPerRep: group.meters,
                                 restSeconds: group.rest, avgSplitSecPer500: group.split)
            piece.id = group.id
            return piece
        }
        let workout = ErgWorkout(startDate: values.day, totalMeters: values.total, notes: values.notes, pieces: groups)
        workout.id = id
        context.insert(workout)
        attempted = values
        do {
            try commit(context)
        } catch {
            context.rollback()
            throw error
        }
        finished = true
        return true
    }
}
