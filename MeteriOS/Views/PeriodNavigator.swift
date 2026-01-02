import SwiftUI

struct PeriodNavigator: View {
    let label: String
    let range: SummaryRange
    @Binding var anchorDate: Date
    let onChanged: () -> Void

    var body: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Button { shift(+1) } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
            .opacity(canGoForward ? 1 : 0.35)
        }
    }

    private var canGoForward: Bool {
        let cal = Calendar.current
        let todayStart = startOfPeriod(for: Date(), range: range, cal: cal)
        let anchorStart = startOfPeriod(for: anchorDate, range: range, cal: cal)
        return anchorStart < todayStart
    }

    private func shift(_ direction: Int) {
        let cal = Calendar.current
        var next = anchorDate

        switch range {
        case .day:
            next = cal.date(byAdding: .day, value: direction, to: next) ?? next
        case .week:
            next = cal.date(byAdding: .day, value: 7 * direction, to: next) ?? next
        case .month:
            next = cal.date(byAdding: .month, value: direction, to: next) ?? next
        case .year:
            next = cal.date(byAdding: .year, value: direction, to: next) ?? next
        }

        // Clamp forward navigation to current period
        let todayStart = startOfPeriod(for: Date(), range: range, cal: cal)
        let nextStart = startOfPeriod(for: next, range: range, cal: cal)
        if nextStart > todayStart { next = Date() }

        anchorDate = next
        onChanged()
    }

    private func startOfPeriod(for date: Date, range: SummaryRange, cal: Calendar) -> Date {
        switch range {
        case .day:
            return cal.startOfDay(for: date)
        case .week:
            return cal.dateInterval(of: .weekOfYear, for: date)!.start
        case .month:
            return cal.dateInterval(of: .month, for: date)!.start
        case .year:
            return cal.dateInterval(of: .year, for: date)!.start
        }
    }
}
