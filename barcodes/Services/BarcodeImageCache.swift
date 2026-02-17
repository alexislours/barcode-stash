import CryptoKit
import UIKit

final class BarcodeImageCache: Sendable {
    static let shared = BarcodeImageCache()

    private let cache: NSCache<NSString, UIImage>
    private let diskCacheURL: URL

    private init() {
        cache = NSCache()
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB

        let caches =
            (try? FileManager.default.url(
                for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            ))
            ?? FileManager.default.temporaryDirectory
        diskCacheURL = caches.appendingPathComponent("BarcodeImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    static func cacheKey(
        rawValue: String,
        type: String,
        descriptorArchive: Data?,
        width: Int,
        height: Int,
        generatorOptions: String? = nil
    ) -> NSString {
        let descriptorHash: String = if let data = descriptorArchive {
            SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        } else {
            "none"
        }
        var key = "\(rawValue)|\(type)|\(descriptorHash)|\(width)x\(height)"
        if let generatorOptions {
            key += "|\(generatorOptions)"
        }
        return key as NSString
    }

    func image(for key: NSString) -> UIImage? {
        cache.object(forKey: key)
    }

    func setImage(_ image: UIImage, for key: NSString) {
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        cache.setObject(image, forKey: key, cost: cost)
    }

    // MARK: - Disk Cache

    private nonisolated func diskURL(for key: NSString) -> URL {
        let hash = SHA256.hash(data: Data((key as String).utf8))
        let hex = hash.compactMap { String(format: "%02x", $0) }.joined()
        return diskCacheURL.appendingPathComponent(hex + ".png")
    }

    nonisolated func cachedImage(for key: NSString) async -> UIImage? {
        if let memoryHit = await image(for: key) {
            return memoryHit
        }

        let url = diskURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let diskImage = UIImage(data: data)
        else {
            return nil
        }

        await setImage(diskImage, for: key)
        return diskImage
    }

    nonisolated func storeImage(_ image: UIImage, for key: NSString) async {
        await setImage(image, for: key)

        let url = diskURL(for: key)
        if let pngData = image.pngData() {
            try? pngData.write(to: url, options: .atomic)
        }
    }

    func removeAll() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}
