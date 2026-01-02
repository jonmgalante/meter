import Foundation
import SwiftData

@Model
final class ErgWorkout {
    var id: UUID
    var startDate: Date
    var dayKey: Date

    /// Optional label like "3x2k" or "10x250m :45r"
    var title: String

    /// Total meters rowed for the session (can include warmup/cooldown)
    var totalMeters: Int

    var notes: String

    /// Pieces are deleted if workout is deleted
    @Relationship(deleteRule: .cascade)
    var pieces: [ErgPiece]

    init(
        startDate: Date,
        title: String = "",
        totalMeters: Int,
        notes: String = "",
        pieces: [ErgPiece] = []
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.dayKey = Calendar.current.startOfDay(for: startDate)
        self.title = title
        self.totalMeters = totalMeters
        self.notes = notes
        self.pieces = pieces
    }

    /// Total meters represented by pieces
    var piecesMeters: Int {
        pieces.reduce(0) { $0 + $1.totalMeters }
    }

    /// Warmup/cooldown/extra meters beyond pieces
    var extraMeters: Int {
        max(0, totalMeters - piecesMeters)
    }
}

@Model
final class ErgPiece {
    var id: UUID
    var orderIndex: Int

    /// For intervals like 4x1k
    var reps: Int

    /// Meters per rep (e.g., 1000 for 1k)
    var metersPerRep: Int

    /// Rest between reps (seconds). nil if not intervals / unknown
    var restSeconds: Int?

    /// Average split seconds per 500m (Double allows tenths: 1:59.1)
    var avgSplitSecPer500: Double?

    init(
        orderIndex: Int,
        reps: Int = 1,
        metersPerRep: Int,
        restSeconds: Int? = nil,
        avgSplitSecPer500: Double? = nil
    ) {
        self.id = UUID()
        self.orderIndex = orderIndex
        self.reps = max(1, reps)
        self.metersPerRep = metersPerRep
        self.restSeconds = restSeconds
        self.avgSplitSecPer500 = avgSplitSecPer500
    }

    var totalMeters: Int { reps * metersPerRep }
}
