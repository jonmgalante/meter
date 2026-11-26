import SwiftUI
import SwiftData

@main
struct MeteriOSApp: App {
    private let store: Result<ModelContainer, Error>

    init() {
        let schema = Schema([ErgWorkout.self, ErgPiece.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        store = Result {
            try ModelContainer(for: schema, configurations: [config])
        }
    }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                RootView()
                    .tint(HealthStyle.accent)
                    .modelContainer(container)
            case .failure(let error):
                ContentUnavailableView("Workout store could not open", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text("Your store has been retained.\n\(error.localizedDescription)"))
            }
        }
    }
}
