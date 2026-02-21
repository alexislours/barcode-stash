import SwiftData
import SwiftUI

@main
struct BarcodesApp: App {
    #if DEBUG
        private let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("--screenshots")
    #endif

    @UIApplicationDelegateAdaptor(QuickActionDelegate.self) var quickActionDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingSharedImageScan = false
    @State private var pendingQuickAction: QuickAction?
    @State private var modelContainer: ModelContainer?
    @State private var containerErrorMessage: String?

    init() {
        switch Self.makeModelContainer() {
        case let .success(container):
            _modelContainer = State(initialValue: container)
            _containerErrorMessage = State(initialValue: nil)
        case let .failure(error):
            _modelContainer = State(initialValue: nil)
            _containerErrorMessage = State(initialValue: error.localizedDescription)
        }
    }

    private static func makeModelContainer() -> Result<ModelContainer, any Error> {
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
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return .success(container)
        } catch {
            return .failure(error)
        }
    }

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

    private func consumeQuickAction() {
        if let action = quickActionDelegate.pendingAction {
            quickActionDelegate.pendingAction = nil
            pendingQuickAction = action
        }
    }

    private func retryContainerCreation() {
        switch Self.makeModelContainer() {
        case let .success(container):
            modelContainer = container
            containerErrorMessage = nil
        case let .failure(error):
            containerErrorMessage = error.localizedDescription
        }
    }

    private func resetAndRetry() {
        Self.deleteStoreFiles()
        retryContainerCreation()
    }

    private static func deleteStoreFiles() {
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }
        let basePath = appSupport.path + "/default.store"
        for suffix in ["", "-shm", "-wal"] {
            let path = basePath + suffix
            if fileManager.fileExists(atPath: path) {
                do {
                    try fileManager.removeItem(atPath: path)
                } catch {}
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                ContentView(
                    pendingSharedImageScan: $pendingSharedImageScan,
                    pendingQuickAction: pendingQuickAction,
                    consumeQuickAction: { pendingQuickAction = nil }
                )
                .onOpenURL { url in
                    guard url.scheme == "barcode-stash" else { return }
                    switch url.host() {
                    case "scan-shared-images":
                        pendingSharedImageScan = true
                    case "scan":
                        pendingQuickAction = .scan
                    case "generate":
                        pendingQuickAction = .generate
                    case "favorites":
                        pendingQuickAction = .favorites
                    default:
                        break
                    }
                }
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        consumeQuickAction()
                        if hasSharedImages() {
                            pendingSharedImageScan = true
                        }
                    }
                }
                #if DEBUG
                .task {
                        if isScreenshotMode {
                            MockDataSeeder.seed(into: modelContainer.mainContext)
                        }
                    }
                #endif
                    .modelContainer(modelContainer)
            } else {
                DatabaseErrorView(
                    errorMessage: containerErrorMessage,
                    onRetry: { retryContainerCreation() },
                    onReset: { resetAndRetry() }
                )
            }
        }
    }
}
