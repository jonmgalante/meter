import SwiftUI
import SwiftData

@main
struct MeteriOSApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([ErgWorkout.self, ErgPiece.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(HealthStyle.accent)
        }
        .modelContainer(container)
    }
}
