import SwiftUI
import SwiftData

@main
struct CX_Rugby_Visitor_AppApp: App {
    private let sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: VisitorRecord.self,
                migrationPlan: VisitorMigrationPlan.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
