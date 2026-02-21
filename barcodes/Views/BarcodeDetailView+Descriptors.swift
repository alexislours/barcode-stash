import CoreImage
import Foundation

// MARK: - Descriptor Data Rows

extension BarcodeDetailView {
    struct DescriptorRow {
        let label: String
        let value: String
    }

    func descriptorRows() -> [DescriptorRow]? {
        guard let data = barcode.descriptorArchive else { return nil }

        let descriptor: CIBarcodeDescriptor? = if #available(iOS 17, *) {
            try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [
                CIQRCodeDescriptor.self,
                CIAztecCodeDescriptor.self,
                CIPDF417CodeDescriptor.self,
                CIDataMatrixCodeDescriptor.self,
            ], from: data) as? CIBarcodeDescriptor
        } else {
            nil
        }

        guard let descriptor else { return nil }

        let rows = descriptorTypeRows(for: descriptor)
        return rows.isEmpty ? nil : rows
    }

    func generatorOptionsRows() -> [DescriptorRow]? {
        guard barcode.isGenerated, barcode.descriptorArchive == nil else { return nil }

        var rows: [DescriptorRow] = []

        if let level = barcode.correctionLevel {
            let displayValue: String = switch barcode.type {
            case .qr:
                QRCorrectionLevel(rawValue: level)?.label ?? level
            case .aztec:
                "\(level)%"
            default:
                level
            }
            rows.append(DescriptorRow(
                label: String(localized: "Error Correction", comment: "Descriptor: error correction level label"),
                value: displayValue
            ))
        }

        if barcode.isCompactStyle {
            rows.append(DescriptorRow(
                label: String(localized: "Compact", comment: "Descriptor: compact mode label"),
                value: String(localized: "Yes", comment: "Descriptor: boolean true value")
            ))
        }

        if let mode = barcode.compactionMode {
            let displayValue = PDF417CompactionMode(rawValue: mode)?.label ?? mode
            rows.append(DescriptorRow(
                label: String(localized: "Compaction Mode", comment: "Descriptor: compaction mode label"),
                value: displayValue
            ))
        }

        if let cols = barcode.columnCount, cols > 0 {
            rows.append(DescriptorRow(
                label: String(localized: "Column Count", comment: "Descriptor: column count label"),
                value: "\(cols)"
            ))
        }

        return rows.isEmpty ? nil : rows
    }

    func descriptorTypeRows(for descriptor: CIBarcodeDescriptor) -> [DescriptorRow] {
        let yesValue = String(localized: "Yes", comment: "Descriptor: boolean true value")
        let noValue = String(localized: "No", comment: "Descriptor: boolean false value")

        if let qrCode = descriptor as? CIQRCodeDescriptor {
            return qrCodeRows(qrCode)
        } else if let aztec = descriptor as? CIAztecCodeDescriptor {
            return aztecRows(aztec, yes: yesValue, no: noValue)
        } else if let pdf = descriptor as? CIPDF417CodeDescriptor {
            return pdf417Rows(pdf, yes: yesValue, no: noValue)
        } else if let dataMatrix = descriptor as? CIDataMatrixCodeDescriptor {
            return dataMatrixRows(dataMatrix)
        }
        return []
    }

    func payloadSizeRow(_ byteCount: Int) -> DescriptorRow {
        DescriptorRow(
            label: String(
                localized: "Payload Size",
                comment: "Descriptor: payload data size label"
            ),
            value: String(
                localized: "\(byteCount) bytes",
                comment: "Descriptor: size in bytes"
            )
        )
    }

    func qrCodeRows(_ qrCode: CIQRCodeDescriptor) -> [DescriptorRow] {
        let eccLevel = switch qrCode.errorCorrectionLevel {
        case .levelL: "L (7%)"
        case .levelM: "M (15%)"
        case .levelQ: "Q (25%)"
        case .levelH: "H (30%)"
        @unknown default: String(
                localized: "Unknown",
                comment: "Descriptor: unknown value"
            )
        }
        return [
            DescriptorRow(
                label: String(
                    localized: "Symbol Version",
                    comment: "Descriptor: QR symbol version label"
                ),
                value: "\(qrCode.symbolVersion)"
            ),
            DescriptorRow(
                label: String(
                    localized: "Mask Pattern",
                    comment: "Descriptor: QR mask pattern label"
                ),
                value: "\(qrCode.maskPattern)"
            ),
            DescriptorRow(
                label: String(
                    localized: "Error Correction",
                    comment: "Descriptor: error correction level label"
                ),
                value: eccLevel
            ),
            payloadSizeRow(qrCode.errorCorrectedPayload.count),
        ]
    }

    func aztecRows(
        _ aztec: CIAztecCodeDescriptor,
        yes yesValue: String,
        no noValue: String
    ) -> [DescriptorRow] {
        [
            DescriptorRow(
                label: String(
                    localized: "Compact",
                    comment: "Descriptor: compact mode label"
                ),
                value: aztec.isCompact ? yesValue : noValue
            ),
            DescriptorRow(
                label: String(
                    localized: "Layer Count",
                    comment: "Descriptor: Aztec layer count label"
                ),
                value: "\(aztec.layerCount)"
            ),
            DescriptorRow(
                label: String(
                    localized: "Data Codewords",
                    comment: "Descriptor: data codeword count label"
                ),
                value: "\(aztec.dataCodewordCount)"
            ),
            payloadSizeRow(aztec.errorCorrectedPayload.count),
        ]
    }

    func pdf417Rows(
        _ pdf: CIPDF417CodeDescriptor,
        yes yesValue: String,
        no noValue: String
    ) -> [DescriptorRow] {
        [
            DescriptorRow(
                label: String(
                    localized: "Compact",
                    comment: "Descriptor: compact mode label"
                ),
                value: pdf.isCompact ? yesValue : noValue
            ),
            DescriptorRow(
                label: String(
                    localized: "Row Count",
                    comment: "Descriptor: row count label"
                ),
                value: "\(pdf.rowCount)"
            ),
            DescriptorRow(
                label: String(
                    localized: "Column Count",
                    comment: "Descriptor: column count label"
                ),
                value: "\(pdf.columnCount)"
            ),
            payloadSizeRow(pdf.errorCorrectedPayload.count),
        ]
    }

    func dataMatrixRows(
        _ dataMatrix: CIDataMatrixCodeDescriptor
    ) -> [DescriptorRow] {
        let eccVersion = switch dataMatrix.eccVersion {
        case .v000: "000"
        case .v050: "050"
        case .v080: "080"
        case .v100: "100"
        case .v140: "140"
        case .v200: "200"
        @unknown default: String(
                localized: "Unknown",
                comment: "Descriptor: unknown value"
            )
        }
        return [
            DescriptorRow(
                label: String(
                    localized: "Row Count",
                    comment: "Descriptor: row count label"
                ),
                value: "\(dataMatrix.rowCount)"
            ),
            DescriptorRow(
                label: String(
                    localized: "Column Count",
                    comment: "Descriptor: column count label"
                ),
                value: "\(dataMatrix.columnCount)"
            ),
            DescriptorRow(
                label: String(
                    localized: "ECC Version",
                    comment: "Descriptor: ECC version label"
                ),
                value: eccVersion
            ),
            payloadSizeRow(dataMatrix.errorCorrectedPayload.count),
        ]
    }
}
