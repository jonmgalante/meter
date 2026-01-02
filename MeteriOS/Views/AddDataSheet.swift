import SwiftUI

struct AddDataSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    AddWorkoutStructuredView()
                } label: {
                    Label("Add Workout", systemImage: "square.and.pencil")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .healthPage()
            .navigationTitle("Add Data")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
