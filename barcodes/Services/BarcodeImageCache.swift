import CryptoKit
import UIKit

final class BarcodeImageCache: Sendable {
    static let shared = BarcodeImageCache()

    private nonisolated(unsafe) let cache: NSCache<NSString, UIImage>
    private let diskCacheURL: URL
    private let diskCacheSizeLimit: Int

    private init(diskCacheSizeLimit: Int = 100 * 1024 * 1024) {
        cache = NSCache()
        cache.countLimit = 200
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        self.diskCacheSizeLimit = diskCacheSizeLimit

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

    nonisolated func image(for key: NSString) -> UIImage? {
        cache.object(forKey: key)
    }

    nonisolated func setImage(_ image: UIImage, for key: NSString) {
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
        if let memoryHit = image(for: key) {
            return memoryHit
        }

        let url = diskURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let diskImage = UIImage(data: data)
        else {
            return nil
        }

        setImage(diskImage, for: key)
        return diskImage
    }

    nonisolated func storeImage(_ image: UIImage, for key: NSString) async {
        setImage(image, for: key)

        let url = diskURL(for: key)
        if let pngData = image.pngData() {
            try? pngData.write(to: url, options: .atomic)
        }

        evictDiskCacheIfNeeded()
    }

    // MARK: - Disk Cache Eviction

    private struct CachedFileInfo {
        let url: URL
        let size: Int
        let modified: Date
    }

    private nonisolated func evictDiskCacheIfNeeded() {
        let fileManager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]

        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: Array(resourceKeys)
        ) else { return }

        var totalSize = 0
        var fileInfos: [CachedFileInfo] = []

        for file in files {
            guard let values = try? file.resourceValues(forKeys: resourceKeys),
                  let size = values.fileSize,
                  let modified = values.contentModificationDate
            else { continue }
            totalSize += size
            fileInfos.append(CachedFileInfo(url: file, size: size, modified: modified))
        }

        guard totalSize > diskCacheSizeLimit else { return }

        // Sort oldest first for LRU eviction
        fileInfos.sort { $0.modified < $1.modified }

        for info in fileInfos {
            try? fileManager.removeItem(at: info.url)
            totalSize -= info.size
            if totalSize <= diskCacheSizeLimit {
                break
            }
        }
    }

    func removeAll() {
        cache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}
