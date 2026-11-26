import SwiftUI
import SwiftData

struct AddWorkoutStructuredView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutDraft
    @State private var writer = NewWorkoutWriter()
    @State private var saveError: String?

    init(draft: WorkoutDraft = WorkoutDraft()) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        Form {
            Section("Workout") {
                DatePicker("Date", selection: $draft.date, displayedComponents: [.date])
                TextField("Total meters (e.g. 6000)", text: $draft.totalText)
                    .keyboardType(.numberPad)
                if let work = draft.piecesTotal {
                    LabeledContent("Pieces total", value: Formatters.meters(work))
                    if let total = Int(draft.totalText), total > work {
                        LabeledContent("Extra", value: Formatters.meters(total - work))
                    }
                }
            }

            Section {
                ForEach($draft.pieces) { $piece in
                    PieceDraftRow(draft: $piece)
                }
                .onDelete { draft.pieces.remove(atOffsets: $0) }
                .onMove { draft.pieces.move(fromOffsets: $0, toOffset: $1) }
                Button {
                    draft.pieces.append(PieceDraft())
                } label: {
                    Label("Add piece", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("Pieces")
                    Spacer()
                    if draft.previous != nil && draft.pieces.count > 1 { EditButton() }
                }
            }

            Section("Notes (optional)") {
                TextField("Anything else…", text: $draft.notes, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityIdentifier("workout-notes")
            }
            if let previous = draft.previous {
                Section("Previous results · \(Formatters.shortDate(previous.date))") {
                    if !previous.title.isEmpty { Text(previous.title) }
                    LabeledContent("Session total", value: Formatters.meters(previous.total))
                    if !previous.groups.isEmpty, let extra = previous.extraMeters, extra > 0 {
                        LabeledContent("Extra meters", value: Formatters.meters(extra))
                    }
                    ForEach(previous.groups.indices, id: \.self) { index in
                        let group = previous.groups[index]
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(group.reps) × \(group.meters) m")
                            if let split = group.split {
                                Text("Average split \(TimeFormat.formatSplit(split)) /500 m")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .healthPage()
        .navigationTitle(draft.previous == nil ? "Add Workout" : "Repeat Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if draft.previous != nil {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    do {
                        if try writer.save(draft, in: context.container) { dismiss() }
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
                .disabled(draft.values == nil || writer.isSaving || writer.finished)
            }
        }
        .alert("Couldn’t save workout", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) { Button("OK") {} } message: { Text(saveError ?? "") }
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
