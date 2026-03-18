import PhotosUI
import SwiftUI

// MARK: - Image Scanning

extension HistoryView {
    func handlePendingSharedImageScan() {
        guard pendingSharedImageScan else { return }
        pendingSharedImageScan = false
        Task { await processSharedImages() }
    }

    func presentScanResults(_ results: [DetectedBarcode]) {
        if results.isEmpty {
            showNoBarcodeAlert = true
        } else {
            imageScanResults = results
            showImageScanResults = true
        }
    }

    func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        isImageScanning = true
        defer { isImageScanning = false }

        let allDetected = await withTaskGroup(
            of: [DetectedBarcode].self,
            returning: [DetectedBarcode].self
        ) { group in
            for item in items {
                group.addTask {
                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        return []
                    }
                    return (try? ImageBarcodeScanner.detectBarcodes(from: data)) ?? []
                }
            }

            var results: [DetectedBarcode] = []
            var seen = Set<String>()
            for await detected in group {
                for barcode in detected {
                    let key = "\(barcode.type.rawValue)|\(barcode.rawValue)"
                    if seen.insert(key).inserted {
                        results.append(barcode)
                    }
                }
            }
            return results
        }

        presentScanResults(allDetected)
    }

    // MARK: - Shared Image Scanning (Share Extension)

    func processSharedImages() async {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.alexislours.barcodes-app"
        ) else { return }

        let sharedDir = containerURL.appendingPathComponent("SharedImages", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sharedDir, includingPropertiesForKeys: nil
        ), !files.isEmpty else { return }

        isImageScanning = true
        defer { isImageScanning = false }

        let allDetected = await withTaskGroup(
            of: [DetectedBarcode].self,
            returning: [DetectedBarcode].self
        ) { group in
            for fileURL in files {
                group.addTask {
                    guard let data = try? Data(contentsOf: fileURL) else {
                        try? FileManager.default.removeItem(at: fileURL)
                        return []
                    }
                    let detected = (try? ImageBarcodeScanner.detectBarcodes(from: data)) ?? []
                    try? FileManager.default.removeItem(at: fileURL)
                    return detected
                }
            }

            var results: [DetectedBarcode] = []
            var seen = Set<String>()
            for await detected in group {
                for barcode in detected {
                    let key = "\(barcode.type.rawValue)|\(barcode.rawValue)"
                    if seen.insert(key).inserted {
                        results.append(barcode)
                    }
                }
            }
            return results
        }

        presentScanResults(allDetected)
    }
}
