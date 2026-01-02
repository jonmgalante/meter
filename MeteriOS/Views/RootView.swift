import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            SummaryView(initialRange: .month, initialDate: Date())
                .tabItem { Label("Summary", systemImage: "heart.text.square") }

            WorkoutsView()
                .tabItem { Label("Workouts", systemImage: "list.bullet") }
        }
    }
}
