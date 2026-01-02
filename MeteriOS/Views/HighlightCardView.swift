import SwiftUI
import Charts

struct HighlightCardView: View {
    let highlight: Highlight

    var body: some View {
        HealthCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(highlight.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(highlight.primaryValue)
                            .font(.title2)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.2), value: highlight.primaryValue)

                        if let secondary = highlight.secondaryValue {
                            Text(secondary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if let chart = highlight.chart, !chart.points.isEmpty {
                        MiniBarChartView(chart: chart)
                            .frame(width: 150, height: 58)
                    }
                }

                Text(highlight.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MiniBarChartView: View {
    let chart: MiniChart

    var body: some View {
        Chart {
            ForEach(chart.points) { p in
                BarMark(
                    x: .value("X", p.label),
                    y: .value("Meters", p.value),
                    width: .fixed(4)
                )
                .cornerRadius(2)
                .foregroundStyle(HealthStyle.accent.opacity(0.95))
            }

            RuleMark(y: .value("Avg", chart.average))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { $0.background(Color.clear) }
    }
}
