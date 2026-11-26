import Foundation
import SwiftData

// Compile with the accepted build's model and module name, then run on a new simulator.
@main
struct MakePriorStore {
    @MainActor static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        guard !FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileWriteFileExists) }
        let schema = Schema([ErgWorkout.self, ErgPiece.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let writer = container.mainContext
        func uuid(_ n: Int) -> UUID { UUID(uuidString: String(format: "71000000-0000-0000-0000-%012d", n))! }
        func piece(_ n: Int, _ order: Int, _ reps: Int, _ meters: Int, _ rest: Int?, _ split: Double?) -> ErgPiece {
            let p = ErgPiece(orderIndex: order, reps: reps, metersPerRep: meters, restSeconds: rest, avgSplitSecPer500: split)
            p.id = uuid(n)
            p.reps = reps
            return p
        }
        func session(_ n: Int, _ daysAgo: Int, _ title: String, _ total: Int, _ groups: [ErgPiece]) {
            let calendar = Calendar.current
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: .now))!
            let w = ErgWorkout(startDate: day.addingTimeInterval(43200.375), title: title, totalMeters: total,
                               notes: "Old log, \"\(title)\"\n雪", pieces: groups)
            w.dayKey = day.addingTimeInterval(0.125)
            w.id = uuid(n)
            writer.insert(w)
        }
        session(1, 1, "Four thousands", 4875, [piece(11, 7, 4, 1000, 150, 113.712345678)])
        session(2, 2, "Six thousand", 6200, [piece(21, 9, 1, 6000, nil, 126.75)])
        session(3, 3, "Ten short", 2800, [piece(31, 1, 10, 250, 45, 98.5)])
        session(4, 4, "Mixed set", 3800, [piece(43, 20, 3, 250, 45, 99.75), piece(41, -3, 1, 1000, nil, 110.25),
                                        piece(42, 8, 2, 750, 0, 125.5)])
        session(5, 5, "Meters only", 8123, [])
        writer.insert(piece(90, -1, -2, 17, nil, nil))
        try writer.save()
        withExtendedLifetime(container) {}
    }
}
