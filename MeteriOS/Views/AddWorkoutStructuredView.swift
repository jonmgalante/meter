import SwiftUI
import SwiftData

struct AddWorkoutStructuredView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Date only (no time)
    @State private var date: Date = Date()

    @State private var totalMetersText: String = ""
    @State private var notes: String = ""

    @State private var pieces: [PieceDraft] = [
        PieceDraft(orderIndex: 0, repsText: "1", metersText: "2000", restText: "", splitText: "")
    ]

    var body: some View {
        Form {
            Section("Workout") {
                DatePicker("Date", selection: $date, displayedComponents: [.date])

                TextField("Total meters (e.g. 6000)", text: $totalMetersText)
                    .keyboardType(.numberPad)

                if let piecesTotal = piecesTotalMeters {
                    HStack {
                        Text("Pieces total")
                        Spacer()
                        Text(Formatters.meters(piecesTotal))
                            .foregroundStyle(.secondary)
                    }

                    if let total = Int(totalMetersText), total > piecesTotal {
                        HStack {
                            Text("Extra (WU/CD)")
                            Spacer()
                            Text(Formatters.meters(total - piecesTotal))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Pieces") {
                ForEach($pieces) { $p in
                    PieceDraftRow(draft: $p)
                }
                .onDelete { idxSet in
                    pieces.remove(atOffsets: idxSet)
                    reindex()
                }

                Button {
                    let next = (pieces.last?.orderIndex ?? 0) + 1
                    pieces.append(PieceDraft(orderIndex: next, repsText: "1", metersText: "", restText: "", splitText: ""))
                } label: {
                    Label("Add piece", systemImage: "plus")
                }
            }

            Section("Notes (optional)") {
                TextField("Anything else…", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .healthPage()
        .navigationTitle("Add Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
    }

    private var piecesTotalMeters: Int? {
        let totals = pieces.compactMap { $0.totalMeters }
        guard totals.count == pieces.count else { return nil }
        return totals.reduce(0, +)
    }

    private var canSave: Bool {
        Int(totalMetersText) != nil && pieces.allSatisfy { $0.isValid }
    }

    private func reindex() {
        for i in pieces.indices {
            pieces[i].orderIndex = i
        }
    }

    private func save() {
        guard let totalMeters = Int(totalMetersText) else { return }

        let pieceModels: [ErgPiece] = pieces.compactMap { d in
            guard let reps = Int(d.repsText), let meters = d.metersMeters else { return nil }
            let rest = TimeFormat.parseRestSeconds(d.restText)
            let split = TimeFormat.parseSplitSeconds(d.splitText)
            return ErgPiece(
                orderIndex: d.orderIndex,
                reps: reps,
                metersPerRep: meters,
                restSeconds: rest,
                avgSplitSecPer500: split
            )
        }
        .sorted(by: { $0.orderIndex < $1.orderIndex })

        let workout = ErgWorkout(
            startDate: Calendar.current.startOfDay(for: date),
            title: "",
            totalMeters: totalMeters,
            notes: notes,
            pieces: pieceModels
        )

        context.insert(workout)
        dismiss()
    }
}

struct PieceDraft: Identifiable {
    let id = UUID()
    var orderIndex: Int

    var repsText: String
    var metersText: String
    var restText: String
    var splitText: String

    var isValid: Bool {
        Int(repsText) != nil && metersMeters != nil
    }

    var metersMeters: Int? {
        let t = metersText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.hasSuffix("k") {
            let num = t.dropLast()
            if let v = Double(num) { return Int(v * 1000.0) }
            return nil
        }
        return Int(t)
    }

    var totalMeters: Int? {
        guard let reps = Int(repsText), let m = metersMeters else { return nil }
        return max(1, reps) * m
    }
}

struct PieceDraftRow: View {
    @Binding var draft: PieceDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField("reps", text: $draft.repsText)
                    .keyboardType(.numberPad)
                    .frame(width: 52)

                Text("×")
                    .foregroundStyle(.secondary)

                TextField("meters (e.g. 1k)", text: $draft.metersText)

                Spacer()

                if let total = draft.totalMeters {
                    Text(Formatters.meters(total))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 10) {
                TextField("rest (e.g. 2:30r)", text: $draft.restText)
                TextField("avg split (e.g. 1:59.1)", text: $draft.splitText)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
