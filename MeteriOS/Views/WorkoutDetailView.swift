import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: ErgWorkout
    @State private var repeatDraft: WorkoutDraft?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HealthStyle.sectionSpacing) {

                HealthMetricHeader(
                    label: "TOTAL",
                    value: Formatters.meters(workout.totalMeters),
                    sublabel: Formatters.shortDate(workout.startDate)
                )

                Button("Repeat Workout", systemImage: "repeat") {
                    guard repeatDraft == nil else { return }
                    repeatDraft = WorkoutDraft(repeating: RecordedWorkout(workout))
                }
                .buttonStyle(.bordered)

                if !workout.pieces.isEmpty {
                    HealthSectionHeader(title: "Pieces")

                    HealthCard {
                        let pieces = RecordedWorkout.orderedPieces(workout)
                        VStack(spacing: 0) {
                            ForEach(pieces, id: \.persistentModelID) { p in
                                PieceRow(piece: p)
                                if p.persistentModelID != pieces.last?.persistentModelID {
                                    Divider().opacity(0.5)
                                }
                            }
                        }
                    }
                }

                if let extraMeters = RecordedWorkout.extraMeters(in: workout), extraMeters > 0 {
                    HealthSectionHeader(title: "Warmup / Cooldown")

                    HealthCard {
                        HStack {
                            Text("Extra meters")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Formatters.meters(extraMeters))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }
                }

                if !workout.notes.isEmpty {
                    HealthSectionHeader(title: "Notes")
                    HealthCard {
                        Text(workout.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Spacer(minLength: 8)
            }
            .padding(.horizontal, HealthStyle.pageHorizontalPadding)
            .padding(.bottom, 16)
        }
        .healthPage()
        .navigationTitle(workout.title.isEmpty ? "Rowing" : workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $repeatDraft) { draft in
            NavigationStack { AddWorkoutStructuredView(draft: draft) }
        }
    }
}

private struct PieceRow: View {
    let piece: ErgPiece

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(piece.reps) × \(piece.metersPerRep)m")
                    .font(.subheadline)

                HStack(spacing: 10) {
                    if let rest = piece.restSeconds {
                        Text("Rest \(TimeFormat.formatRest(rest))")
                    }
                    if let split = piece.avgSplitSecPer500 {
                        Text("\(TimeFormat.formatSplit(split))/500m")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(PieceDraft.workMeters(reps: piece.reps, meters: piece.metersPerRep).map { Formatters.meters($0) } ?? "—")
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
    }
}
