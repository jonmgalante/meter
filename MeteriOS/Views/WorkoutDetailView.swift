import SwiftUI

struct WorkoutDetailView: View {
    let workout: ErgWorkout

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HealthStyle.sectionSpacing) {

                HealthMetricHeader(
                    label: "TOTAL",
                    value: Formatters.meters(workout.totalMeters),
                    sublabel: Formatters.shortDate(workout.startDate)
                )

                if !workout.pieces.isEmpty {
                    HealthSectionHeader(title: "Pieces")

                    HealthCard {
                        let pieces = workout.pieces.sorted(by: { $0.orderIndex < $1.orderIndex })
                        VStack(spacing: 0) {
                            ForEach(pieces) { p in
                                PieceRow(piece: p)
                                if p.id != pieces.last?.id {
                                    Divider().opacity(0.5)
                                }
                            }
                        }
                    }
                }

                if workout.extraMeters > 0 {
                    HealthSectionHeader(title: "Warmup / Cooldown")

                    HealthCard {
                        HStack {
                            Text("Extra meters")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Formatters.meters(workout.extraMeters))
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

            Text(Formatters.meters(piece.totalMeters))
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
    }
}
