import SwiftUI
import Charts

struct BucketInteractionOverlay: View {
    let proxy: ChartProxy
    let buckets: [SummaryBucket]
    let range: SummaryRange

    @Binding var selectedStart: Date?
    let onTapBucket: (SummaryBucket, _ tappedSameAsSelected: Bool) -> Void
    let tooltipTitle: (SummaryBucket) -> String
    let tooltipValue: (SummaryBucket) -> String
    let tooltipSubtitle: (SummaryBucket) -> String?

    // How close a tap must be to a bar’s center to count as a selection
    private let selectionThreshold: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let plotFrame = geo[proxy.plotFrame]

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                // Tap outside plot clears selection (Apple Health behavior)
                                guard plotFrame.contains(value.location) else {
                                    selectedStart = nil
                                    return
                                }

                                let xInPlot = value.location.x - plotFrame.origin.x

                                // Find nearest bar center by X distance
                                guard let nearestResult = nearestBucketByX(xInPlot: xInPlot) else {
                                    selectedStart = nil
                                    return
                                }

                                let nearest = nearestResult.bucket
                                let dist = nearestResult.distance

                                // Tap “blank space” -> clear selection
                                guard dist <= selectionThreshold else {
                                    selectedStart = nil
                                    return
                                }

                                let same = (selectedStart == nearest.startDate)
                                if same { Haptics.lightImpact() } else { Haptics.selection() }

                                selectedStart = nearest.startDate
                                onTapBucket(nearest, same)
                            }
                    )

                if let selectedStart,
                   let selectedBucket = buckets.first(where: { $0.startDate == selectedStart }),
                   let xPos = proxy.position(forX: selectedStart) {

                    let pillWidth: CGFloat = 150
                    let globalX = plotFrame.minX + xPos
                    let clampedX = min(
                        max(globalX, plotFrame.minX + pillWidth / 2),
                        plotFrame.maxX - pillWidth / 2
                    )

                    HealthTooltipPill(
                        title: tooltipTitle(selectedBucket),
                        value: tooltipValue(selectedBucket),
                        subtitle: tooltipSubtitle(selectedBucket)
                    )
                    .frame(width: pillWidth)
                    .position(x: clampedX, y: plotFrame.minY + 14)
                    .animation(.easeInOut(duration: 0.12), value: selectedStart)
                }
            }
        }
    }

    private func nearestBucketByX(xInPlot: CGFloat) -> (bucket: SummaryBucket, distance: CGFloat)? {
        var best: (SummaryBucket, CGFloat)?
        for b in buckets {
            guard let pos = proxy.position(forX: b.startDate) else { continue } // plot coords
            let d = abs(pos - xInPlot)
            if best == nil || d < best!.1 {
                best = (b, d)
            }
        }
        return best
    }
}
