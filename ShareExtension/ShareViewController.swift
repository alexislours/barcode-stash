import ImageIO
import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    private var spinner: UIActivityIndicatorView!
    private var progressLabel: UILabel!
    private var overlayView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        overlayView = UIView()
        overlayView.backgroundColor = .systemBackground
        overlayView.layer.cornerRadius = 16
        overlayView.translatesAutoresizingMaskIntoConstraints = false

        spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        progressLabel = UILabel()
        progressLabel.font = .preferredFont(forTextStyle: .subheadline)
        progressLabel.textColor = .secondaryLabel
        progressLabel.textAlignment = .center
        progressLabel.translatesAutoresizingMaskIntoConstraints = false

        overlayView.addSubview(spinner)
        overlayView.addSubview(progressLabel)
        view.addSubview(overlayView)

        NSLayoutConstraint.activate([
            overlayView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlayView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlayView.widthAnchor.constraint(equalToConstant: 200),
            overlayView.heightAnchor.constraint(equalToConstant: 120),

            spinner.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 24),

            progressLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            progressLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 16),
            progressLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -16),
        ])

        overlayView.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            await handleSharedImages()
        }
    }

    private func handleSharedImages() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            extensionContext?.completeRequest(returningItems: [])
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }

        guard !providers.isEmpty else {
            extensionContext?.completeRequest(returningItems: [])
            return
        }

        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.alexislours.barcodes-app"
        ) else {
            extensionContext?.completeRequest(returningItems: [])
            return
        }

        let sharedDir = containerURL.appendingPathComponent("SharedImages", isDirectory: true)

        Task.detached { [self] in
            cleanupStaleFiles(in: sharedDir)
        }

        overlayView.isHidden = false
        if providers.count == 1 {
            progressLabel.text = String(
                localized: "Processing...",
                comment: "Share extension progress for single image"
            )
        }

        for (index, provider) in providers.enumerated() {
            if providers.count > 1 {
                updateProgress(current: index + 1, total: providers.count)
            }
            _ = await copyImage(from: provider, to: sharedDir)
        }

        overlayView.isHidden = true

        if let url = URL(string: "barcode-stash://scan-shared-images") {
            _ = openURL(url)
        }

        extensionContext?.completeRequest(returningItems: [])
    }

    private func updateProgress(current: Int, total: Int) {
        progressLabel.text = String(
            localized: "Processing \(current) of \(total)...",
            comment: "Share extension progress for multiple images"
        )
    }

    /// Copies an image from the provider to the shared directory via a temp file
    private nonisolated func copyImage(from provider: NSItemProvider, to directory: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(for: .image) { url, _, _ in
                guard let url,
                      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let uti = CGImageSourceGetType(source) as? String,
                      let type = UTType(uti)
                else {
                    continuation.resume(returning: false)
                    return
                }
                let ext = type.preferredFilenameExtension ?? "dat"
                let dest = directory.appendingPathComponent("\(UUID().uuidString).\(ext)")
                do {
                    try FileManager.default.copyItem(at: url, to: dest)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private nonisolated func cleanupStaleFiles(in directory: URL) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        let cutoff = Date.now.addingTimeInterval(-3600)
        for file in files {
            if let values = try? file.resourceValues(forKeys: [.creationDateKey]),
               let created = values.creationDate, created < cutoff {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    @discardableResult
    private func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url)
                return true
            }
            responder = current.next
        }
        return false
    }
}
