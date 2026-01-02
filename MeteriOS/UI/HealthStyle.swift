import SwiftUI
import UIKit

enum HealthStyle {
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)

    // Accent for “Rowing”
    static let accent = Color.orange

    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 14
    static let pageHorizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
}

struct HealthCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(HealthStyle.cardPadding)
            .background(HealthStyle.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: HealthStyle.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: HealthStyle.cardCornerRadius, style: .continuous)
                    .stroke(HealthStyle.separator.opacity(0.18), lineWidth: 1)
            )
    }
}

struct HealthSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.top, 4)
    }
}

/// Apple Health metric header + rolling number animation
struct HealthMetricHeader: View {
    let label: String
    let value: String
    let sublabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: label)

            Text(value)
                .font(.system(size: 44, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.22), value: value)

            Text(sublabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: sublabel)
        }
        .padding(.top, 6)
    }
}

struct HealthPageModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(HealthStyle.pageBackground)
    }
}

extension View {
    func healthPage() -> some View { modifier(HealthPageModifier()) }
}
