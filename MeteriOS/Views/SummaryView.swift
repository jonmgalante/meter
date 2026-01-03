import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    @Query(sort: \ErgWorkout.startDate, order: .reverse) private var workouts: [ErgWorkout]

    @State private var range: SummaryRange
    @State private var anchorDate: Date

    @State private var showingAddWorkoutSheet = false

    // Main chart selection + drill
    @State private var selectedBucketIndex: Int? = nil
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

        let bucketCount = stats.buckets.count
        let hasChartData = bucketCount >= 2 && stats.buckets.contains(where: { $0.totalDistance > 0 })
        let header = headerDisplay(stats: stats)

        // X indices (categorical-ish numeric axis) so bars center under labels
        let xValues: [Double] = (0..<bucketCount).map { Double($0) }
        let xDomain: ClosedRange<Double>? = bucketCount >= 2 ? (-0.5...(Double(bucketCount) - 0.5)) : nil

        // Y axis spec (nice ticks like 1k/5k/10k)
        let maxY = stats.buckets.map(\.totalDistance).max() ?? 0
        let yAxis = makeYAxis(maxValue: maxY, range: range)
        let yTop = yAxis.top
        let yTicks = yAxis.ticks

        // Bar width by range (closer to Apple Health)
        let barWidth: CGFloat = {
            switch range {
            case .week:  return 18
            case .month: return 8
            case .year:  return 12
            case .day:   return 10
            }
        }()

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
                    .onChange(of: range) { _, _ in
                        clearSelections()
                    }

                    HealthMetricHeader(label: header.label, value: header.value, sublabel: header.sublabel)

                    PeriodNavigator(label: stats.subLabel, range: range, anchorDate: $anchorDate) {
                        clearSelections()
                    }

                    if range != .day {
                        if hasChartData {
                            HealthCard {
                                let count = stats.buckets.count
                                let xValues: [Double] = (0..<count).map { Double($0) }
                                
                                // Give extra space on both ends so bars look centered under labels,
                                // and so the rightmost bar doesn’t collide with the trailing y-axis.
                                let paddedDomain = (-0.8...(Double(count) - 0.2))
                                
                                // For year labels: show fewer labels so they don’t truncate, but ALWAYS include Dec (index 11).
                                let yearLabelIdx: [Double] = [0, 2, 4, 6, 8, 10, 11]
                                    .filter { $0 < count }
                                    .map { Double($0) }
                                
                                Chart {
                                    if let selectedBucketIndex {
                                        RuleMark(x: .value("Selected", Double(selectedBucketIndex)))
                                            .foregroundStyle(.secondary.opacity(0.25))
                                    }
                                    
                                    ForEach(Array(stats.buckets.enumerated()), id: \.element.id) { (idx, b) in
                                        let isSelected = (selectedBucketIndex == idx)
                                        
                                        BarMark(
                                            x: .value("Index", Double(idx)),
                                            y: .value("Meters", b.totalDistance),
                                            width: .fixed(barWidth)
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
                                .chartXScale(domain: paddedDomain)              // ✅ fixes centering + right-edge collision
                                .chartYScale(domain: 0...yTop)
                                
                                .chartXAxis {
                                    switch range {
                                    case .week:
                                        // ✅ Force all 7 labels (including Saturday)
                                        AxisMarks(values: xValues) { value in
                                            AxisValueLabel {
                                                if let x = value.as(Double.self) {
                                                    let i = max(0, min(count - 1, Int(x.rounded())))
                                                    Text(stats.buckets[i].startDate, format: .dateTime.weekday(.narrow))
                                                }
                                            }
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        }
                                        
                                    case .month:
                                        // Show about weekly ticks for readability
                                        let step = 7
                                        let values = stride(from: 0, to: count, by: step).map { Double($0) }
                                        AxisMarks(values: values) { value in
                                            AxisValueLabel {
                                                if let x = value.as(Double.self) {
                                                    let i = max(0, min(count - 1, Int(x.rounded())))
                                                    let day = Calendar.current.component(.day, from: stats.buckets[i].startDate)
                                                    Text("\(day)")
                                                }
                                            }
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        }
                                        
                                    case .year:
                                        // ✅ Avoid truncation AND guarantee December appears
                                        AxisMarks(values: yearLabelIdx) { value in
                                            AxisValueLabel {
                                                if let x = value.as(Double.self) {
                                                    let i = max(0, min(count - 1, Int(x.rounded())))
                                                    Text(stats.buckets[i].startDate, format: .dateTime.month(.abbreviated))
                                                }
                                            }
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        }
                                        
                                    case .day:
                                        AxisMarks()
                                    }
                                }
                                
                                .chartYAxis {
                                    AxisMarks(position: .trailing, values: yTicks) { value in
                                        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                                        AxisTick().foregroundStyle(.secondary.opacity(0.25))
                                        AxisValueLabel {
                                            if let v = value.as(Int.self) {
                                                Text(formatYAxisTick(v))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                
                                .chartPlotStyle { plot in
                                    // A tiny extra nudge so y labels don’t feel on top of the bars.
                                    plot.padding(.trailing, 6)
                                }
                                .frame(height: 220)
                                
                                .chartOverlay { proxy in
                                    BucketIndexInteractionOverlay(
                                        proxy: proxy,
                                        buckets: stats.buckets,
                                        range: range,
                                        selectedIndex: $selectedBucketIndex,
                                        onTapBucket: { bucket, tappedSame in
                                            if tappedSame { drill(from: bucket) }
                                        },
                                        tooltipTitle: { bucket in tooltipTitle(for: range, bucket: bucket) },
                                        tooltipValue: { bucket in Formatters.meters(bucket.totalDistance) },
                                        tooltipSubtitle: { bucket in bucket.workoutCount > 0 ? sessionsString(bucket.workoutCount) : nil }
                                    )
                                }
                    
                                // extra breathing room so right-side labels don’t feel on top of bars
                                .chartPlotStyle { plot in
                                    plot
                                        .background(Color.clear)
                                        .padding(.trailing, 8)
                                }
                                .frame(height: 220)
                                .chartOverlay { proxy in
                                    BucketIndexInteractionOverlay(
                                        proxy: proxy,
                                        buckets: stats.buckets,
                                        range: range,
                                        selectedIndex: $selectedBucketIndex,
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
            .navigationTitle("Meters")
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

        if let selectedBucketIndex,
           selectedBucketIndex >= 0,
           selectedBucketIndex < stats.buckets.count {
            let b = stats.buckets[selectedBucketIndex]
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

        // Y axis for day chart
        let dayMaxY = dayWorkouts.map(\.totalMeters).max() ?? 0
        let dayAxis = makeYAxis(maxValue: dayMaxY, range: .day)
        let dayTop = dayAxis.top
        let dayTicks = dayAxis.ticks

        // Safe x domain for day chart
        let dayXDomain: ClosedRange<Date> = {
            if dayWorkouts.count >= 2 {
                let minD = dayWorkouts.first!.startDate
                let maxD = dayWorkouts.last!.startDate
                return (minD < maxD) ? (minD...maxD) : (minD...minD.addingTimeInterval(1))
            } else if let only = dayWorkouts.first?.startDate {
                return only.addingTimeInterval(-3600)...only.addingTimeInterval(3600)
            } else {
                let now = Date()
                return now.addingTimeInterval(-3600)...now.addingTimeInterval(3600)
            }
        }()

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
                    .chartXScale(domain: dayXDomain)
                    .chartXAxis(.hidden)
                    .chartYScale(domain: 0...dayTop)
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: dayTicks) { value in
                            AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                            AxisTick().foregroundStyle(.secondary.opacity(0.25))
                            AxisValueLabel {
                                if let v = value.as(Int.self) {
                                    Text(formatYAxisTick(v))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
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
        selectedBucketIndex = nil
        selectedWorkoutID = nil
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

    // MARK: - Y Axis helpers (nice ticks + k/M formatting)
    private struct YAxisSpec {
        let top: Int
        let ticks: [Int]
    }

    private func makeYAxis(maxValue: Int, range: SummaryRange) -> YAxisSpec {
        guard maxValue > 0 else {
            return YAxisSpec(top: 1000, ticks: [0, 500, 1000])
        }

        let desiredTickCount: Int = (range == .year) ? 5 : 4
        let rawStep = Double(maxValue) / Double(max(1, desiredTickCount - 1))
        let step = niceStep(rawStep)

        let top = Int(ceil(Double(maxValue) / step) * step)
        let intStep = max(1, Int(step.rounded()))
        let ticks = stride(from: 0, through: top, by: intStep).map { $0 }

        return YAxisSpec(top: top, ticks: ticks)
    }

    private func niceStep(_ x: Double) -> Double {
        guard x > 0 else { return 1 }

        let exp = floor(log10(x))
        let f = x / pow(10, exp)

        let nf: Double
        if f <= 1 { nf = 1 }
        else if f <= 2 { nf = 2 }
        else if f <= 5 { nf = 5 }
        else { nf = 10 }

        return nf * pow(10, exp)
    }

    private func formatYAxisTick(_ meters: Int) -> String {
        if meters == 0 { return "0" }

        if meters >= 1_000_000 {
            let v = Double(meters) / 1_000_000.0
            return v >= 10 || v.rounded() == v ? "\(Int(v.rounded()))M" : String(format: "%.1fM", v)
        }

        if meters >= 1_000 {
            let v = Double(meters) / 1_000.0
            return v >= 10 || v.rounded() == v ? "\(Int(v.rounded()))k" : String(format: "%.1fk", v)
        }

        return "\(meters)"
    }

    // MARK: - Overlay to handle taps on index-based x-axis
    private struct BucketIndexInteractionOverlay: View {
        let proxy: ChartProxy
        let buckets: [SummaryBucket]
        let range: SummaryRange

        @Binding var selectedIndex: Int?
        let onTapBucket: (SummaryBucket, _ tappedSameAsSelected: Bool) -> Void
        let tooltipTitle: (SummaryBucket) -> String
        let tooltipValue: (SummaryBucket) -> String
        let tooltipSubtitle: (SummaryBucket) -> String?

        private let selectionThreshold: CGFloat = 18

        var body: some View {
            GeometryReader { geo in
                if let plotAnchor = proxy.plotFrame {
                    let plotFrame = geo[plotAnchor]
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .overlay(alignment: .topLeading) {
                            if let selectedIndex,
                               selectedIndex >= 0,
                               selectedIndex < buckets.count,
                               let xPos = proxy.position(forX: Double(selectedIndex)) {

                                let bucket = buckets[selectedIndex]
                                let pillWidth: CGFloat = 150
                                let globalX = plotFrame.minX + xPos
                                let clampedX = min(
                                    max(globalX, plotFrame.minX + pillWidth / 2),
                                    plotFrame.maxX - pillWidth / 2
                                )

                                HealthTooltipPill(
                                    title: tooltipTitle(bucket),
                                    value: tooltipValue(bucket),
                                    subtitle: tooltipSubtitle(bucket)
                                )
                                .frame(width: pillWidth)
                                .position(x: clampedX, y: plotFrame.minY + 14)
                            }
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    guard plotFrame.contains(value.location) else {
                                        selectedIndex = nil
                                        return
                                    }

                                    let xInPlot = value.location.x - plotFrame.origin.x
                                    guard let raw: Double = proxy.value(atX: xInPlot) else {
                                        selectedIndex = nil
                                        return
                                    }

                                    let i = Int(raw.rounded())
                                    guard i >= 0, i < buckets.count else {
                                        selectedIndex = nil
                                        return
                                    }

                                    // Blank-space clear if tap is far from bar center
                                    if let center = proxy.position(forX: Double(i)) {
                                        let dist = abs(center - xInPlot)
                                        guard dist <= selectionThreshold else {
                                            selectedIndex = nil
                                            return
                                        }
                                    }

                                    let same = (selectedIndex == i)
                                    if same { Haptics.lightImpact() } else { Haptics.selection() }

                                    selectedIndex = i
                                    onTapBucket(buckets[i], same)
                                }
                        )
                } else {
                    Color.clear
                }
            }
        }
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
                                guard let tappedDate: Date = proxy.value(atX: xInPlot) else {
                                    selectedWorkoutID = nil
                                    return
                                }

                                guard let nearest = nearestWorkout(to: tappedDate) else { return }
                                let same = (selectedWorkoutID == nearest.id)

                                if same { Haptics.lightImpact() } else { Haptics.selection() }
                                selectedWorkoutID = nearest.id
                                if same { onOpenWorkout(nearest) }
                            }
                    )
            } else {
                Color.clear
            }
        }
    }

    private func nearestWorkout(to date: Date) -> ErgWorkout? {
        workouts.min(by: {
            abs($0.startDate.timeIntervalSince(date)) < abs($1.startDate.timeIntervalSince(date))
        })
    }
}

private struct DayWorkoutRow: View {
    let workout: ErgWorkout
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title.isEmpty ? "Workout" : workout.title)
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

private extension View {
    @ViewBuilder
    func applyIf<T>(_ condition: Bool, transform: (Self) -> T) -> some View where T: View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
