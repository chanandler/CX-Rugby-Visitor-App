import SwiftUI
import SwiftData

@main
struct CX_Rugby_Visitor_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: VisitorRecord.self)
    }
}
