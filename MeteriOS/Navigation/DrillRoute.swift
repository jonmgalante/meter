import Foundation

struct DrillRoute: Identifiable, Hashable {
    let id: UUID
    let range: SummaryRange
    let anchorDate: Date

    init(range: SummaryRange, anchorDate: Date) {
        self.id = UUID()
        self.range = range
        self.anchorDate = anchorDate
    }
}
