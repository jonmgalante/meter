import SwiftData
import XCTest
@testable import MeteriOS

@MainActor
final class RepeatWorkoutTests: XCTestCase {
    private func disposableURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Repeat-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
        addTeardownBlock { [weak self] in
            if self?.testRun?.totalFailureCount == 0 {
                try FileManager.default.removeItem(at: dir)
            } else {
                print("Retained test store and companions in \(dir.path)")
            }
        }
        return dir.appendingPathComponent("default.store")
    }

    private func withStore<T>(_ url: URL, writable: Bool = true, _ body: (ModelContainer) throws -> T) throws -> T {
        try autoreleasepool {
            let schema = Schema([ErgWorkout.self, ErgPiece.self])
            let config = ModelConfiguration(schema: schema, url: url, allowsSave: writable)
            let container = try ModelContainer(for: schema, configurations: [config])
            return try withExtendedLifetime(container) { try body(container) }
        }
    }

    private func transactions(_ context: ModelContext) throws -> [DefaultHistoryTransaction] {
        try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
    }

    private func manual() -> WorkoutDraft {
        var draft = WorkoutDraft()
        draft.totalText = "4000"
        draft.pieces = [PieceDraft(repsText: "4", metersText: "1k", restText: "2:30")]
        return draft
    }

    func testDetachedOrderedTemplateAndManualDefaults() throws {
        let url = try disposableURL()
        try withStore(url) { store in
            let ctx = store.mainContext
            let first = ErgPiece(orderIndex: -2, reps: 1, metersPerRep: 6000, avgSplitSecPer500: 124.125)
            let second = ErgPiece(orderIndex: 3, reps: 4, metersPerRep: 1000, restSeconds: 150, avgSplitSecPer500: 113.75)
            let third = ErgPiece(orderIndex: 9, reps: 10, metersPerRep: 250, restSeconds: 0)
            let old = ErgWorkout(startDate: Date(timeIntervalSinceReferenceDate: 12345678.375),
                                 title: "Old title", totalMeters: 13000, notes: "Old notes", pieces: [third, first, second])
            old.dayKey = Date(timeIntervalSinceReferenceDate: 12300000.125)
            ctx.insert(old)
            try ctx.save()
            let tokens = try transactions(ctx).map(\.token)
            let today = Date(timeIntervalSinceReferenceDate: 812345678.375)
            var draft = WorkoutDraft(repeating: RecordedWorkout(old), now: today)
            XCTAssertEqual(draft.date, today)
            XCTAssertEqual(draft.previous?.date, old.startDate)
            XCTAssertEqual(draft.previous?.total, 13000)
            XCTAssertEqual(draft.previous?.groups.compactMap(\.split), [124.125, 113.75])
            XCTAssertEqual(draft.pieces.map(\.restText), ["", "2:30", "0:00"])
            XCTAssertEqual(draft.pieces.map(\.splitText), ["", "", ""])
            XCTAssertEqual(draft.notes, "")
            XCTAssertEqual(draft.totalText, "12500")
            XCTAssertNotEqual(draft.id, old.id)
            XCTAssertTrue(Set(draft.pieces.map(\.id)).isDisjoint(with: old.pieces.map(\.id)))
            draft.pieces[1].repsText = "2"
            XCTAssertEqual(draft.totalText, "10500")
            draft.pieces.swapAt(0, 2)
            XCTAssertEqual(draft.values?.groups.map(\.meters), [250, 1000, 6000])
            draft.totalText = "11001"
            draft.pieces.removeLast()
            XCTAssertEqual(draft.totalText, "11001")
            draft.totalText = ""
            XCTAssertNil(draft.values)
            XCTAssertEqual(second.reps, 4)
            XCTAssertFalse(ctx.hasChanges)
            XCTAssertEqual(try transactions(ctx).map(\.token), tokens)

            let totalOnly = ErgWorkout(startDate: .distantPast, totalMeters: 8999)
            var blank = WorkoutDraft(repeating: RecordedWorkout(totalOnly))
            XCTAssertTrue(blank.pieces.isEmpty)
            XCTAssertEqual(blank.totalText, "")
            XCTAssertNil(blank.values)
            blank.totalText = "321"
            XCTAssertEqual(blank.values?.groups, [])
            var totalOnlyWithNewGroup = WorkoutDraft(repeating: RecordedWorkout(totalOnly))
            totalOnlyWithNewGroup.pieces.append(PieceDraft(metersText: "250"))
            XCTAssertNil(totalOnlyWithNewGroup.values)
            var fresh = WorkoutDraft()
            XCTAssertEqual(fresh.pieces.count, 1)
            XCTAssertEqual(fresh.pieces[0].repsText, "1")
            XCTAssertEqual(fresh.pieces[0].metersText, "2000")
            XCTAssertEqual(fresh.totalText, "")
            XCTAssertNil(fresh.values)
            fresh.pieces.removeAll()
            XCTAssertEqual(fresh.piecesTotal, 0)
            XCTAssertEqual(fresh.totalText, "")
        }
    }

    func testValidateEveryGroupBeforeWriting() throws {
        let url = try disposableURL()
        try withStore(url) { store in
            let writer = NewWorkoutWriter()
            for piece in [PieceDraft(repsText: "0", metersText: "1000"),
                          PieceDraft(repsText: "-1", metersText: "1000"),
                          PieceDraft(metersText: "nanK"), PieceDraft(metersText: "0.0001k"),
                          PieceDraft(repsText: "2", metersText: String(Int.max)),
                          PieceDraft(metersText: "250", restText: "bad:45"),
                          PieceDraft(metersText: "250", restText: "\(Int.max):30"),
                          PieceDraft(metersText: "250", splitText: "1:60"),
                          PieceDraft(metersText: "250", splitText: "NaN")] {
                var draft = manual()
                draft.pieces.append(piece)
                XCTAssertThrowsError(try writer.save(draft, in: store))
            }
            var overflow = manual()
            overflow.pieces.append(PieceDraft(metersText: String(Int.max)))
            XCTAssertNil(overflow.values)
            XCTAssertEqual(PieceDraft(metersText: "1.001k").totalMeters, 1001)
            XCTAssertEqual(TimeFormat.parseRestSeconds(":45r"), 45)
            XCTAssertEqual(TimeFormat.parseSplitSeconds("1:59.1"), 119.1)
            XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<ErgWorkout>()), 0)
            XCTAssertTrue(try transactions(store.mainContext).isEmpty)
        }
    }

    func testOneThrowingSaveAndDoubleTapLeaveMainContextAlone() throws {
        let url = try disposableURL()
        let draft = manual()
        try withStore(url) { store in
            let main = store.mainContext
            main.autosaveEnabled = false
            let pending = ErgWorkout(startDate: .now, totalMeters: 88)
            main.insert(pending)
            let writer = NewWorkoutWriter()
            var saves = 0
            XCTAssertTrue(try writer.save(draft, in: store) { isolated in
                XCTAssertFalse(isolated === main)
                XCTAssertFalse(isolated.autosaveEnabled)
                XCTAssertFalse(try writer.save(draft, in: store))
                saves += 1
                try isolated.save()
            })
            XCTAssertFalse(try writer.save(draft, in: store))
            XCTAssertEqual(saves, 1)
            XCTAssertTrue(main.hasChanges)
            XCTAssertTrue(pending.modelContext === main)
            main.rollback()
        }
        try withStore(url) { store in
            let w = try XCTUnwrap(store.mainContext.fetch(FetchDescriptor<ErgWorkout>()).first)
            XCTAssertTrue(try XCTUnwrap(draft.values).matches(w))
            XCTAssertEqual(try transactions(store.mainContext).map { $0.changes.count }, [2])
        }
    }

    func testReadOnlySaveFailureDiscardsOnlyIsolatedChangesAndAllowsRetry() throws {
        let url = try disposableURL()
        try withStore(url) { store in
            store.mainContext.insert(ErgWorkout(startDate: .distantPast, title: "Original", totalMeters: 7))
            try store.mainContext.save()
        }
        var draft = manual()
        let writer = NewWorkoutWriter()
        try withStore(url, writable: false) { store in
            XCTAssertThrowsError(try writer.save(draft, in: store))
            XCTAssertFalse(writer.finished)
            XCTAssertFalse(store.mainContext.hasChanges)
            XCTAssertEqual(try transactions(store.mainContext).count, 1)
        }
        try withStore(url) { store in
            XCTAssertEqual(try store.mainContext.fetch(FetchDescriptor<ErgWorkout>()).map(\.title), ["Original"])
            draft.notes = "Corrected after retry"
            XCTAssertTrue(try writer.save(draft, in: store))
        }
        try withStore(url) { store in
            let all = try store.mainContext.fetch(FetchDescriptor<ErgWorkout>())
            XCTAssertEqual(Set(all.map(\.notes)), ["", "Corrected after retry"])
            XCTAssertEqual(try transactions(store.mainContext).map { $0.changes.count }, [1, 2])
        }
    }

    func testUncertainCommitIsVerifiedBeforeRetryIncludingLaterEdits() throws {
        let url = try disposableURL()
        var draft = manual()
        let writer = NewWorkoutWriter()
        try withStore(url) { store in
            XCTAssertThrowsError(try writer.save(draft, in: store) { isolated in
                try isolated.save()
                throw CocoaError(.fileWriteUnknown)
            })
        }
        try withStore(url) { store in
            draft.notes = "Edit after first attempt"
            XCTAssertThrowsError(try writer.save(draft, in: store) { _ in XCTFail("Second commit") })
            draft.notes = ""
            XCTAssertTrue(try writer.save(draft, in: store) { _ in XCTFail("Second commit") })
            XCTAssertEqual(try transactions(store.mainContext).map { $0.changes.count }, [2])
        }
    }

    func testProposedIDCollisionNeverAdoptsOrChangesHistory() throws {
        let url = try disposableURL()
        let draft = manual()
        try withStore(url) { store in
            let old = ErgWorkout(startDate: .distantPast, title: "Existing", totalMeters: 9876)
            old.id = draft.id
            store.mainContext.insert(old)
            try store.mainContext.save()
            XCTAssertThrowsError(try NewWorkoutWriter().save(draft, in: store))
            var other = WorkoutDraft()
            other.totalText = "4000"
            other.pieces = draft.pieces
            let piece = ErgPiece(orderIndex: 14, metersPerRep: 29)
            piece.id = other.pieces[0].id
            store.mainContext.insert(piece)
            try store.mainContext.save()
            XCTAssertThrowsError(try NewWorkoutWriter().save(other, in: store))
            XCTAssertEqual(try store.mainContext.fetchCount(FetchDescriptor<ErgWorkout>()), 1)
            XCTAssertEqual(old.totalMeters, 9876)
            XCTAssertEqual(piece.orderIndex, 14)
            XCTAssertEqual(try transactions(store.mainContext).count, 2)
        }
    }
}
