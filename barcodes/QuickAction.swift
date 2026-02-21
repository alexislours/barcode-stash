import UIKit

enum QuickAction: String {
    case scan = "com.alexislours.barcodes.scan"
    case generate = "com.alexislours.barcodes.generate"
    case favorites = "com.alexislours.barcodes.favorites"

    var urlHost: String {
        switch self {
        case .scan: "scan"
        case .generate: "generate"
        case .favorites: "favorites"
        }
    }
}

class QuickActionDelegate: NSObject, UIApplicationDelegate {
    var pendingAction: QuickAction?

    func application(
        _: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            pendingAction = QuickAction(rawValue: shortcutItem.type)
        }
        let config = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = QuickActionSceneDelegate.self
        return config
    }
}

class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem
    ) async -> Bool {
        guard let action = QuickAction(rawValue: shortcutItem.type),
              let url = URL(string: "barcode-stash://\(action.urlHost)")
        else { return false }
        await UIApplication.shared.open(url)
        return true
    }
}
