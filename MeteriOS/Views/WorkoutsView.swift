import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ErgWorkout.startDate, order: .reverse) private var workouts: [ErgWorkout]

    @State private var showingAddSheet = false

    private var grouped: [(Date, [ErgWorkout])] {
        let dict = Dictionary(grouping: workouts) { $0.dayKey }
        return dict
            .map { ($0.key, $0.value.sorted(by: { $0.startDate > $1.startDate })) }
            .sorted(by: { $0.0 > $1.0 })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.0) { day, items in
                    Section(Formatters.shortDate(day)) {
                        ForEach(items) { w in
                            NavigationLink {
                                WorkoutDetailView(workout: w)
                            } label: {
                                WorkoutListRow(workout: w)
                            }
                        }
                        .onDelete { idxSet in
                            for idx in idxSet {
                                context.delete(items[idx])
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .healthPage()
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddDataSheet()
            }
        }
    }
}

private struct WorkoutListRow: View {
    let workout: ErgWorkout

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title.isEmpty ? "Rowing" : workout.title)
                    .font(.subheadline)

                if workout.pieces.count > 0 {
                    Text("\(workout.pieces.count) piece" + (workout.pieces.count == 1 ? "" : "s"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(Formatters.meters(workout.totalMeters))
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
