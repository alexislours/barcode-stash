import Foundation

extension DataMatrixEncoder {
    // MARK: - Symbol Info

    struct SymbolInfo {
        let rectangular: Bool
        let dataCapacity: Int
        let errorCodewords: Int
        let matrixWidth: Int
        let matrixHeight: Int
        let dataRegions: Int
        let rsBlockData: Int
        let rsBlockError: Int

        /// Whether this is the special 144x144 symbol
        let isSpecial144: Bool

        init(
            rectangular: Bool, dataCapacity: Int, errorCodewords: Int,
            matrixWidth: Int, matrixHeight: Int, dataRegions: Int,
            rsBlockData: Int? = nil, rsBlockError: Int? = nil,
            isSpecial144: Bool = false
        ) {
            self.rectangular = rectangular
            self.dataCapacity = dataCapacity
            self.errorCodewords = errorCodewords
            self.matrixWidth = matrixWidth
            self.matrixHeight = matrixHeight
            self.dataRegions = dataRegions
            self.rsBlockData = rsBlockData ?? dataCapacity
            self.rsBlockError = rsBlockError ?? errorCodewords
            self.isSpecial144 = isSpecial144
        }

        var horizontalDataRegions: Int {
            switch dataRegions {
            case 1: 1
            case 2: 2
            case 4: 2
            case 16: 4
            case 36: 6
            default: 1
            }
        }

        var verticalDataRegions: Int {
            switch dataRegions {
            case 1: 1
            case 2: 1
            case 4: 2
            case 16: 4
            case 36: 6
            default: 1
            }
        }

        var symbolDataWidth: Int {
            horizontalDataRegions * matrixWidth
        }

        var symbolDataHeight: Int {
            verticalDataRegions * matrixHeight
        }

        var symbolWidth: Int {
            symbolDataWidth + horizontalDataRegions * 2
        }

        var symbolHeight: Int {
            symbolDataHeight + verticalDataRegions * 2
        }

        var interleavedBlockCount: Int {
            if isSpecial144 { return 10 }
            return dataCapacity / rsBlockData
        }

        func dataLengthForBlock(_ index: Int) -> Int {
            if isSpecial144 { return index <= 8 ? 156 : 155 }
            return rsBlockData
        }

        func errorLengthForBlock(_: Int) -> Int {
            rsBlockError
        }

        static func lookup(dataCodewords: Int) -> SymbolInfo? {
            for symbol in symbols where dataCodewords <= symbol.dataCapacity {
                return symbol
            }
            return nil
        }

        static func lookup(
            symbolWidth: Int,
            symbolHeight: Int
        ) -> SymbolInfo? {
            symbols.first {
                $0.symbolWidth == symbolWidth
                    && $0.symbolHeight == symbolHeight
            }
        }

        // swiftlint:disable line_length
        /// ZXing's symbol table, capacity-sorted with rectangular interleaved
        static let symbols: [SymbolInfo] = [
            SymbolInfo(rectangular: false, dataCapacity: 3, errorCodewords: 5, matrixWidth: 8, matrixHeight: 8, dataRegions: 1),
            SymbolInfo(rectangular: false, dataCapacity: 5, errorCodewords: 7, matrixWidth: 10, matrixHeight: 10, dataRegions: 1),
            SymbolInfo(rectangular: true, dataCapacity: 5, errorCodewords: 7, matrixWidth: 16, matrixHeight: 6, dataRegions: 1),
            SymbolInfo(rectangular: false, dataCapacity: 8, errorCodewords: 10, matrixWidth: 12, matrixHeight: 12, dataRegions: 1),
            SymbolInfo(rectangular: true, dataCapacity: 10, errorCodewords: 11, matrixWidth: 14, matrixHeight: 6, dataRegions: 2),
            SymbolInfo(rectangular: false, dataCapacity: 12, errorCodewords: 12, matrixWidth: 14, matrixHeight: 14, dataRegions: 1),
            SymbolInfo(rectangular: true, dataCapacity: 16, errorCodewords: 14, matrixWidth: 24, matrixHeight: 10, dataRegions: 1),
            SymbolInfo(rectangular: false, dataCapacity: 18, errorCodewords: 14, matrixWidth: 16, matrixHeight: 16, dataRegions: 1),
            SymbolInfo(rectangular: false, dataCapacity: 22, errorCodewords: 18, matrixWidth: 18, matrixHeight: 18, dataRegions: 1),
            SymbolInfo(rectangular: true, dataCapacity: 22, errorCodewords: 18, matrixWidth: 16, matrixHeight: 10, dataRegions: 2),
            SymbolInfo(rectangular: false, dataCapacity: 30, errorCodewords: 20, matrixWidth: 20, matrixHeight: 20, dataRegions: 1),
            SymbolInfo(rectangular: true, dataCapacity: 32, errorCodewords: 24, matrixWidth: 16, matrixHeight: 14, dataRegions: 2),
            SymbolInfo(rectangular: false, dataCapacity: 36, errorCodewords: 24, matrixWidth: 22, matrixHeight: 22, dataRegions: 1),
            SymbolInfo(rectangular: false, dataCapacity: 44, errorCodewords: 28, matrixWidth: 24, matrixHeight: 24, dataRegions: 1),
            SymbolInfo(rectangular: true, dataCapacity: 49, errorCodewords: 28, matrixWidth: 22, matrixHeight: 14, dataRegions: 2),
            SymbolInfo(rectangular: false, dataCapacity: 62, errorCodewords: 36, matrixWidth: 14, matrixHeight: 14, dataRegions: 4),
            SymbolInfo(rectangular: false, dataCapacity: 86, errorCodewords: 42, matrixWidth: 16, matrixHeight: 16, dataRegions: 4),
            SymbolInfo(rectangular: false, dataCapacity: 114, errorCodewords: 48, matrixWidth: 18, matrixHeight: 18, dataRegions: 4),
            SymbolInfo(rectangular: false, dataCapacity: 144, errorCodewords: 56, matrixWidth: 20, matrixHeight: 20, dataRegions: 4),
            SymbolInfo(rectangular: false, dataCapacity: 174, errorCodewords: 68, matrixWidth: 22, matrixHeight: 22, dataRegions: 4),
            SymbolInfo(rectangular: false, dataCapacity: 204, errorCodewords: 84, matrixWidth: 24, matrixHeight: 24, dataRegions: 4, rsBlockData: 102, rsBlockError: 42),
            SymbolInfo(rectangular: false, dataCapacity: 280, errorCodewords: 112, matrixWidth: 14, matrixHeight: 14, dataRegions: 16, rsBlockData: 140, rsBlockError: 56),
            SymbolInfo(rectangular: false, dataCapacity: 368, errorCodewords: 144, matrixWidth: 16, matrixHeight: 16, dataRegions: 16, rsBlockData: 92, rsBlockError: 36),
            SymbolInfo(rectangular: false, dataCapacity: 456, errorCodewords: 192, matrixWidth: 18, matrixHeight: 18, dataRegions: 16, rsBlockData: 114, rsBlockError: 48),
            SymbolInfo(rectangular: false, dataCapacity: 576, errorCodewords: 224, matrixWidth: 20, matrixHeight: 20, dataRegions: 16, rsBlockData: 144, rsBlockError: 56),
            SymbolInfo(rectangular: false, dataCapacity: 696, errorCodewords: 272, matrixWidth: 22, matrixHeight: 22, dataRegions: 16, rsBlockData: 174, rsBlockError: 68),
            SymbolInfo(rectangular: false, dataCapacity: 816, errorCodewords: 336, matrixWidth: 24, matrixHeight: 24, dataRegions: 16, rsBlockData: 136, rsBlockError: 56),
            SymbolInfo(rectangular: false, dataCapacity: 1050, errorCodewords: 408, matrixWidth: 18, matrixHeight: 18, dataRegions: 36, rsBlockData: 175, rsBlockError: 68),
            SymbolInfo(rectangular: false, dataCapacity: 1304, errorCodewords: 496, matrixWidth: 20, matrixHeight: 20, dataRegions: 36, rsBlockData: 163, rsBlockError: 62),
            // Special 144x144 with 10 interleaved blocks
            SymbolInfo(rectangular: false, dataCapacity: 1558, errorCodewords: 620, matrixWidth: 22, matrixHeight: 22, dataRegions: 36, rsBlockData: -1, rsBlockError: 62, isSpecial144: true),
        ]
        // swiftlint:enable line_length
    }
}
