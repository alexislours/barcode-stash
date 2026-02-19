import SwiftData
import SwiftUI

@main
struct BarcodesApp: App {
    #if DEBUG
        private let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshots")
    #endif

    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingSharedImageScan = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ScannedBarcode.self,
        ])
        #if DEBUG
            let inMemory = ProcessInfo.processInfo.arguments.contains("--screenshots")
        #else
            let inMemory = false
        #endif

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

    private func hasSharedImages() -> Bool {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.alexislours.barcodes-app"
        ) else { return false }
        let sharedDir = containerURL.appendingPathComponent("SharedImages", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: sharedDir, includingPropertiesForKeys: nil
        ) else { return false }
        return !contents.isEmpty
    }

    var body: some Scene {
        WindowGroup {
            ContentView(pendingSharedImageScan: $pendingSharedImageScan)
                .onOpenURL { url in
                    if url.scheme == "barcode-stash", url.host() == "scan-shared-images" {
                        pendingSharedImageScan = true
                    }
                }
                .onChange(of: scenePhase) {
                    if scenePhase == .active, hasSharedImages() {
                        pendingSharedImageScan = true
                    }
                }
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
