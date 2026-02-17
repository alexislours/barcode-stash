import CoreImage
import Foundation

// MARK: - Module Placement & Rendering

extension DataMatrixEncoder {
    // MARK: - Module Placement (Utah Algorithm)

    struct ModulePlacer {
        let codewords: [UInt8]
        let numrows: Int
        let numcols: Int
        var bits: [Int8]

        init(codewords: [UInt8], numrows: Int, numcols: Int) {
            self.codewords = codewords
            self.numrows = numrows
            self.numcols = numcols
            bits = [Int8](repeating: -1, count: numrows * numcols)
        }

        mutating func setBit(col: Int, row: Int, value: Bool) {
            bits[row * numcols + col] = value ? 1 : 0
        }

        func hasBit(col: Int, row: Int) -> Bool {
            bits[row * numcols + col] >= 0
        }

        mutating func moduleAt(
            row: Int, col: Int, pos: Int, bit: Int
        ) {
            var rowCoord = row, colCoord = col
            if rowCoord < 0 {
                rowCoord += numrows
                colCoord += 4 - ((numrows + 4) % 8)
            }
            if colCoord < 0 {
                colCoord += numcols
                rowCoord += 4 - ((numcols + 4) % 8)
            }
            let value = pos < codewords.count
                ? Int(codewords[pos]) : 0
            setBit(
                col: colCoord,
                row: rowCoord,
                value: (value & (1 << (8 - bit))) != 0
            )
        }

        mutating func utah(row: Int, col: Int, pos: Int) {
            moduleAt(row: row - 2, col: col - 2, pos: pos, bit: 1)
            moduleAt(row: row - 2, col: col - 1, pos: pos, bit: 2)
            moduleAt(row: row - 1, col: col - 2, pos: pos, bit: 3)
            moduleAt(row: row - 1, col: col - 1, pos: pos, bit: 4)
            moduleAt(row: row - 1, col: col, pos: pos, bit: 5)
            moduleAt(row: row, col: col - 2, pos: pos, bit: 6)
            moduleAt(row: row, col: col - 1, pos: pos, bit: 7)
            moduleAt(row: row, col: col, pos: pos, bit: 8)
        }

        mutating func corner1(_ pos: Int) {
            moduleAt(row: numrows - 1, col: 0, pos: pos, bit: 1)
            moduleAt(row: numrows - 1, col: 1, pos: pos, bit: 2)
            moduleAt(row: numrows - 1, col: 2, pos: pos, bit: 3)
            moduleAt(row: 0, col: numcols - 2, pos: pos, bit: 4)
            moduleAt(row: 0, col: numcols - 1, pos: pos, bit: 5)
            moduleAt(row: 1, col: numcols - 1, pos: pos, bit: 6)
            moduleAt(row: 2, col: numcols - 1, pos: pos, bit: 7)
            moduleAt(row: 3, col: numcols - 1, pos: pos, bit: 8)
        }

        mutating func corner2(_ pos: Int) {
            moduleAt(row: numrows - 3, col: 0, pos: pos, bit: 1)
            moduleAt(row: numrows - 2, col: 0, pos: pos, bit: 2)
            moduleAt(row: numrows - 1, col: 0, pos: pos, bit: 3)
            moduleAt(row: 0, col: numcols - 4, pos: pos, bit: 4)
            moduleAt(row: 0, col: numcols - 3, pos: pos, bit: 5)
            moduleAt(row: 0, col: numcols - 2, pos: pos, bit: 6)
            moduleAt(row: 0, col: numcols - 1, pos: pos, bit: 7)
            moduleAt(row: 1, col: numcols - 1, pos: pos, bit: 8)
        }

        mutating func corner3(_ pos: Int) {
            moduleAt(row: numrows - 3, col: 0, pos: pos, bit: 1)
            moduleAt(row: numrows - 2, col: 0, pos: pos, bit: 2)
            moduleAt(row: numrows - 1, col: 0, pos: pos, bit: 3)
            moduleAt(row: 0, col: numcols - 2, pos: pos, bit: 4)
            moduleAt(row: 0, col: numcols - 1, pos: pos, bit: 5)
            moduleAt(row: 1, col: numcols - 1, pos: pos, bit: 6)
            moduleAt(row: 2, col: numcols - 1, pos: pos, bit: 7)
            moduleAt(row: 3, col: numcols - 1, pos: pos, bit: 8)
        }

        mutating func corner4(_ pos: Int) {
            moduleAt(row: numrows - 1, col: 0, pos: pos, bit: 1)
            let lastCol = numcols - 1
            moduleAt(row: numrows - 1, col: lastCol, pos: pos, bit: 2)
            moduleAt(row: 0, col: numcols - 3, pos: pos, bit: 3)
            moduleAt(row: 0, col: numcols - 2, pos: pos, bit: 4)
            moduleAt(row: 0, col: lastCol, pos: pos, bit: 5)
            moduleAt(row: 1, col: numcols - 3, pos: pos, bit: 6)
            moduleAt(row: 1, col: numcols - 2, pos: pos, bit: 7)
            moduleAt(row: 1, col: lastCol, pos: pos, bit: 8)
        }

        mutating func placeAll() {
            var pos = 0
            var row = 4
            var col = 0

            repeat {
                if row == numrows, col == 0 {
                    corner1(pos); pos += 1
                }
                if row == numrows - 2, col == 0,
                   (numcols % 4) != 0 {
                    corner2(pos); pos += 1
                }
                if row == numrows - 2, col == 0,
                   numcols % 8 == 4 {
                    corner3(pos); pos += 1
                }
                if row == numrows + 4, col == 2,
                   (numcols % 8) == 0 {
                    corner4(pos); pos += 1
                }

                // Sweep upper-right
                repeat {
                    if row < numrows, col >= 0,
                       !hasBit(col: col, row: row) {
                        utah(row: row, col: col, pos: pos)
                        pos += 1
                    }
                    row -= 2; col += 2
                } while row >= 0 && col < numcols
                row += 1; col += 3

                // Sweep lower-left
                repeat {
                    if row >= 0, col < numcols,
                       !hasBit(col: col, row: row) {
                        utah(row: row, col: col, pos: pos)
                        pos += 1
                    }
                    row += 2; col -= 2
                } while row < numrows && col >= 0
                row += 3; col += 1
            } while row < numrows || col < numcols

            // Fill fixed pattern in lower-right if untouched
            if !hasBit(col: numcols - 1, row: numrows - 1) {
                setBit(col: numcols - 1, row: numrows - 1, value: true)
                setBit(col: numcols - 2, row: numrows - 2, value: true)
            }
        }
    }

    static func placeModules(
        codewords: [UInt8],
        numrows: Int,
        numcols: Int
    ) -> [Int8] {
        var placer = ModulePlacer(
            codewords: codewords,
            numrows: numrows,
            numcols: numcols
        )
        placer.placeAll()
        return placer.bits
    }

    // MARK: - Custom Matrix Renderer

    static func renderCustomMatrix(
        symbolInfo: SymbolInfo,
        codewords: [UInt8]
    ) -> CIImage? {
        let nrow = symbolInfo.symbolDataHeight
        let ncol = symbolInfo.symbolDataWidth
        let bits = placeModules(
            codewords: codewords, numrows: nrow, numcols: ncol
        )

        let symRows = symbolInfo.symbolHeight
        let symCols = symbolInfo.symbolWidth

        var grid = [[Bool]](
            repeating: [Bool](repeating: false, count: symCols),
            count: symRows
        )

        addFinderPatterns(&grid, symbolInfo: symbolInfo)
        placeDataBits(
            &grid, bits: bits, symbolInfo: symbolInfo
        )
        return renderGridToImage(
            grid, symRows: symRows, symCols: symCols
        )
    }

    static func addFinderPatterns(
        _ grid: inout [[Bool]],
        symbolInfo: SymbolInfo
    ) {
        let matrixW = symbolInfo.matrixWidth
        let matrixH = symbolInfo.matrixHeight
        let hRegions = symbolInfo.horizontalDataRegions
        let vRegions = symbolInfo.verticalDataRegions
        let symCols = symbolInfo.symbolWidth
        let symRows = symbolInfo.symbolHeight

        // Horizontal: solid L-shape bottom, alternating clock track top
        for verticalRegion in 0 ..< vRegions {
            let altRow = verticalRegion * (matrixH + 2)
            let solidRow = altRow + matrixH + 1
            for col in 0 ..< symCols {
                grid[solidRow][col] = true
                if col % 2 == 0 { grid[altRow][col] = true }
            }
        }
        // Vertical finder patterns
        for horizontalRegion in 0 ..< hRegions {
            let solidCol = horizontalRegion * (matrixW + 2)
            let altCol = solidCol + matrixW + 1
            for row in 0 ..< symRows {
                grid[row][solidCol] = true
                if row % 2 == 1 { grid[row][altCol] = true }
            }
        }
    }

    static func placeDataBits(
        _ grid: inout [[Bool]],
        bits: [Int8],
        symbolInfo: SymbolInfo
    ) {
        let nrow = symbolInfo.symbolDataHeight
        let ncol = symbolInfo.symbolDataWidth
        let matrixW = symbolInfo.matrixWidth
        let matrixH = symbolInfo.matrixHeight

        for dataRow in 0 ..< nrow {
            for dataCol in 0 ..< ncol {
                let bitVal = bits[dataRow * ncol + dataCol]
                if bitVal == 1 {
                    let regionRow = dataRow / matrixH
                    let regionCol = dataCol / matrixW
                    let localRow = dataRow % matrixH
                    let localCol = dataCol % matrixW
                    let symRow = regionRow * (matrixH + 2)
                        + localRow + 1
                    let symCol = regionCol * (matrixW + 2)
                        + localCol + 1
                    grid[symRow][symCol] = true
                }
            }
        }
    }

    static func renderGridToImage(
        _ grid: [[Bool]],
        symRows: Int,
        symCols: Int
    ) -> CIImage? {
        let quietZone = 1
        let scale = 4
        let totalRows = symRows + 2 * quietZone
        let totalCols = symCols + 2 * quietZone
        let width = totalCols * scale
        let height = totalRows * scale
        var pixels = [UInt8](repeating: 255, count: width * height)

        for row in 0 ..< symRows {
            for col in 0 ..< symCols where grid[row][col] {
                let pixelRow = row + quietZone
                let pixelCol = col + quietZone
                for deltaY in 0 ..< scale {
                    for deltaX in 0 ..< scale {
                        let idx = (pixelRow * scale + deltaY)
                            * width + pixelCol * scale + deltaX
                        pixels[idx] = 0
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let provider = CGDataProvider(
            data: Data(pixels) as CFData
        ),
            let cgImage = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider, decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else { return nil }

        return CIImage(cgImage: cgImage)
    }
}
