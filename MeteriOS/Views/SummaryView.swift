import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    @Query(sort: \ErgWorkout.startDate, order: .reverse) private var workouts: [ErgWorkout]

    @State private var range: SummaryRange
    @State private var anchorDate: Date

    @State private var showingAddWorkoutSheet = false

    // Main chart selection + drill
    @State private var selectedBucketStart: Date? = nil
    @State private var drillRoute: DrillRoute?

    // Day view selection + navigation
    @State private var selectedWorkoutID: UUID? = nil
    @State private var navWorkout: ErgWorkout?

    init(initialRange: SummaryRange = .month, initialDate: Date = Date()) {
        _range = State(initialValue: initialRange)
        _anchorDate = State(initialValue: initialDate)
    }

    var body: some View {
        let stats = Aggregation.buildStats(workouts: workouts, range: range, anchorDate: anchorDate)
        let highlights = HighlightEngine.computeHighlights(workouts: workouts, anchorDate: anchorDate)

        let hasChartData = stats.buckets.contains(where: { $0.totalDistance > 0 })
        let header = headerDisplay(stats: stats)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: HealthStyle.sectionSpacing) {

                    Picker("", selection: $range) {
                        ForEach(SummaryRange.allCases) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 8)
                    .onChange(of: range) { _, _ in clearSelections() }

                    HealthMetricHeader(label: header.label, value: header.value, sublabel: header.sublabel)

                    PeriodNavigator(label: stats.subLabel, range: range, anchorDate: $anchorDate) {
                        clearSelections()
                    }

                    if range != .day {
                        if hasChartData {
                            HealthCard {
                                Chart {
                                    if let selectedBucketStart {
                                        RuleMark(x: .value("Selected", selectedBucketStart))
                                            .foregroundStyle(.secondary.opacity(0.25))
                                    }

                                    ForEach(stats.buckets) { b in
                                        let isSelected = (selectedBucketStart == b.startDate)

                                        BarMark(
                                            x: .value("Date", b.startDate),
                                            y: .value("Meters", b.totalDistance),
                                            width: .fixed(6)
                                        )
                                        .cornerRadius(3)
                                        .foregroundStyle(isSelected ? HealthStyle.accent : HealthStyle.accent.opacity(0.25))
                                        .shadow(
                                            color: isSelected ? HealthStyle.accent.opacity(0.35) : .clear,
                                            radius: isSelected ? 7 : 0,
                                            x: 0,
                                            y: 0
                                        )
                                    }
                                }
                                .chartXAxis { mainXAxis(for: range) }
                                .chartYAxis(.hidden)
                                .chartPlotStyle { $0.background(Color.clear) }
                                .frame(height: 220)
                                .chartOverlay { proxy in
                                    BucketInteractionOverlay(
                                        proxy: proxy,
                                        buckets: stats.buckets,
                                        range: range,
                                        selectedStart: $selectedBucketStart,
                                        onTapBucket: { bucket, tappedSame in
                                            if tappedSame { drill(from: bucket) }
                                        },
                                        tooltipTitle: { bucket in tooltipTitle(for: range, bucket: bucket) },
                                        tooltipValue: { bucket in Formatters.meters(bucket.totalDistance) },
                                        tooltipSubtitle: { bucket in bucket.workoutCount > 0 ? sessionsString(bucket.workoutCount) : nil }
                                    )
                                }
                            }
                        } else {
                            emptyChartCard(for: range)
                        }
                    }

                    if range == .day {
                        dayView(for: anchorDate)
                    }

                    HealthSectionHeader(title: "Highlights")
                    VStack(spacing: 10) {
                        ForEach(highlights) { h in
                            HighlightCardView(highlight: h)
                        }
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, HealthStyle.pageHorizontalPadding)
                .padding(.bottom, 16)
            }
            .healthPage()
            .navigationTitle("Rowing")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add Workout") { showingAddWorkoutSheet = true }
                }
            }
            .sheet(isPresented: $showingAddWorkoutSheet) {
                NavigationStack {
                    AddWorkoutStructuredView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showingAddWorkoutSheet = false }
                            }
                        }
                }
            }
            .navigationDestination(item: $drillRoute) { route in
                SummaryView(initialRange: route.range, initialDate: route.anchorDate)
            }
            .navigationDestination(item: $navWorkout) { w in
                WorkoutDetailView(workout: w)
            }
            .onChange(of: anchorDate) { _, _ in clearSelections() }
        }
    }

    // MARK: - Empty state card (for W/M/Y chart area)
    private func emptyChartCard(for range: SummaryRange) -> some View {
        HealthCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("No Data")
                    .font(.headline)

                Text(emptyStateSubtitle(for: range))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    showingAddWorkoutSheet = true
                } label: {
                    Text("Add Workout").fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .tint(HealthStyle.accent)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 220, alignment: .leading)
        }
    }

    private func emptyStateSubtitle(for range: SummaryRange) -> String {
        switch range {
        case .week:  return "Log a workout to see your weekly totals and averages."
        case .month: return "Log a workout to see your monthly totals and averages."
        case .year:  return "Log a workout to see your yearly totals and averages."
        case .day:   return "Log a workout to see details for this day."
        }
    }

    // MARK: - Header display (default vs selected)
    private func headerDisplay(stats: SummaryStats) -> (label: String, value: String, sublabel: String) {
        if range == .day,
           let selectedWorkoutID,
           let w = workoutForID(selectedWorkoutID) {
            return (
                label: "TOTAL",
                value: Formatters.meters(w.totalMeters),
                sublabel: Formatters.timeOnly(w.startDate)
            )
        }

        if let selectedBucketStart,
           let b = stats.buckets.first(where: { $0.startDate == selectedBucketStart }) {
            return (
                label: "TOTAL",
                value: Formatters.meters(b.totalDistance),
                sublabel: selectedBucketSublabel(range: range, bucketStart: b.startDate)
            )
        }

        return (stats.headlineLabel, stats.headlineValue, stats.subLabel)
    }

    private func selectedBucketSublabel(range: SummaryRange, bucketStart: Date) -> String {
        let df = DateFormatter()
        switch range {
        case .year: df.dateFormat = "LLLL yyyy"
        case .month, .week, .day: df.dateFormat = "EEE, MMM d"
        }
        return df.string(from: bucketStart)
    }

    private func workoutForID(_ id: UUID) -> ErgWorkout? {
        workouts.first(where: { $0.id == id })
    }

    // MARK: - Day view
    private func dayView(for date: Date) -> some View {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        let dayWorkouts = workouts
            .filter { $0.startDate >= start && $0.startDate < end }
            .sorted(by: { $0.startDate < $1.startDate })

        return Group {
            HealthSectionHeader(title: "Workouts")

            HealthCard {
                if dayWorkouts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("No Data").font(.headline)
                        Text("Log a workout to see details for this day.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            showingAddWorkoutSheet = true
                        } label: {
                            Text("Add Workout").fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .tint(HealthStyle.accent)
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 120, alignment: .leading)
                } else {
                    Chart {
                        if let selected = selectedWorkoutStartDate(from: dayWorkouts) {
                            RuleMark(x: .value("Selected", selected))
                                .foregroundStyle(.secondary.opacity(0.25))
                        }

                        ForEach(dayWorkouts) { w in
                            let isSelected = (selectedWorkoutID == w.id)

                            BarMark(
                                x: .value("Time", w.startDate),
                                y: .value("Meters", w.totalMeters),
                                width: .fixed(10)
                            )
                            .cornerRadius(3)
                            .foregroundStyle(isSelected ? HealthStyle.accent : HealthStyle.accent.opacity(0.25))
                            .shadow(
                                color: isSelected ? HealthStyle.accent.opacity(0.35) : .clear,
                                radius: isSelected ? 7 : 0,
                                x: 0,
                                y: 0
                            )
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .chartPlotStyle { $0.background(Color.clear) }
                    .frame(height: 120)
                    .chartOverlay { proxy in
                        DayWorkoutInteractionOverlay(
                            proxy: proxy,
                            workouts: dayWorkouts,
                            selectedWorkoutID: $selectedWorkoutID,
                            onOpenWorkout: { w in navWorkout = w }
                        )
                    }
                }
            }

            if !dayWorkouts.isEmpty {
                HealthCard {
                    VStack(spacing: 0) {
                        ForEach(dayWorkouts.reversed()) { w in
                            Button {
                                navWorkout = w
                            } label: {
                                DayWorkoutRow(workout: w, isSelected: selectedWorkoutID == w.id)
                            }
                            .buttonStyle(.plain)

                            if w.id != dayWorkouts.reversed().last?.id {
                                Divider().opacity(0.5)
                            }
                        }
                    }
                }
            }
        }
    }

    private func selectedWorkoutStartDate(from dayWorkouts: [ErgWorkout]) -> Date? {
        guard let selectedWorkoutID,
              let w = dayWorkouts.first(where: { $0.id == selectedWorkoutID }) else { return nil }
        return w.startDate
    }

    // MARK: - Drill
    private func drill(from bucket: SummaryBucket) {
        switch range {
        case .year:
            drillRoute = DrillRoute(range: .month, anchorDate: bucket.startDate)
        case .month, .week:
            drillRoute = DrillRoute(range: .day, anchorDate: bucket.startDate)
        case .day:
            break
        }
    }

    private func clearSelections() {
        selectedBucketStart = nil
        selectedWorkoutID = nil
    }

    // MARK: - Axis
    @AxisContentBuilder
    private func mainXAxis(for range: SummaryRange) -> some AxisContent {
        switch range {
        case .year:
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .month:
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisValueLabel(format: .dateTime.day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .week:
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .day:
            AxisMarks()
        }
    }

    // MARK: - Tooltip
    private func tooltipTitle(for range: SummaryRange, bucket: SummaryBucket) -> String {
        let df = DateFormatter()
        switch range {
        case .year:  df.dateFormat = "MMMM"
        case .month: df.dateFormat = "MMM d"
        case .week:  df.dateFormat = "EEE"
        case .day:   df.dateFormat = "MMM d"
        }
        return df.string(from: bucket.startDate)
    }

    private func sessionsString(_ n: Int) -> String {
        "\(n) " + (n == 1 ? "session" : "sessions")
    }
}

// MARK: - Day workout overlay (unchanged)
private struct DayWorkoutInteractionOverlay: View {
    let proxy: ChartProxy
    let workouts: [ErgWorkout]
    @Binding var selectedWorkoutID: UUID?
    let onOpenWorkout: (ErgWorkout) -> Void
    private let selectionThreshold: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            if let plotAnchor = proxy.plotFrame {
                let plotFrame = geo[plotAnchor]

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard plotFrame.contains(value.location) else {
                                        selectedWorkoutID = nil
                                        return
                                    }

                                    let xInPlot = value.location.x - plotFrame.origin.x
                                    guard let nearestResult = nearestWorkoutByX(xInPlot: xInPlot) else {
                                        selectedWorkoutID = nil
                                        return
                                    }

                                    let nearest = nearestResult.workout
                                    let dist = nearestResult.distance
                                    guard dist <= selectionThreshold else {
                                        selectedWorkoutID = nil
                                        return
                                    }

                                    let same = (selectedWorkoutID == nearest.id)
                                    if same { Haptics.lightImpact() } else { Haptics.selection() }

                                    selectedWorkoutID = nearest.id
                                    if same { onOpenWorkout(nearest) }
                                }
                        )

                    if let selectedWorkoutID,
                       let w = workouts.first(where: { $0.id == selectedWorkoutID }),
                       let xPos = proxy.position(forX: w.startDate) {

                        let pillWidth: CGFloat = 160
                        let globalX = plotFrame.minX + xPos
                        let clampedX = min(
                            max(globalX, plotFrame.minX + pillWidth / 2),
                            plotFrame.maxX - pillWidth / 2
                        )

                        HealthTooltipPill(
                            title: Formatters.timeOnly(w.startDate),
                            value: Formatters.meters(w.totalMeters),
                            subtitle: w.title.isEmpty ? nil : w.title
                        )
                        .frame(width: pillWidth)
                        .position(x: clampedX, y: plotFrame.minY + 14)
                    }
                }
            } else {
                Color.clear
            }
        }
    }

    private func nearestWorkoutByX(xInPlot: CGFloat) -> (workout: ErgWorkout, distance: CGFloat)? {
        var best: (ErgWorkout, CGFloat)?
        for w in workouts {
            guard let pos = proxy.position(forX: w.startDate) else { continue }
            let d = abs(pos - xInPlot)
            if best == nil || d < best!.1 {
                best = (w, d)
            }
        }
        return best
    }
}

private struct DayWorkoutRow: View {
    let workout: ErgWorkout
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title.isEmpty ? "Rowing" : workout.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text(Formatters.timeOnly(workout.startDate))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(Formatters.meters(workout.totalMeters))
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(isSelected ? HealthStyle.accent.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? HealthStyle.accent.opacity(0.28) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
