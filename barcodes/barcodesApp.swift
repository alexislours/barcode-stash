import SwiftData
import SwiftUI

@main
struct BarcodesApp: App {
    #if DEBUG
        private let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshots")
    #endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ScannedBarcode.self,
        ])
        let inMemory = ProcessInfo.processInfo.arguments.contains("--screenshots")

        let modelConfiguration = if inMemory {
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.com.alexislours.barcodes-app")
            )
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
            #if DEBUG
                .task {
                    if isScreenshotMode {
                        MockDataSeeder.seed(into: sharedModelContainer.mainContext)
                    }
                }
            #endif
        }
        .modelContainer(sharedModelContainer)
    }
}
