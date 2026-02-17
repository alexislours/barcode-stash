import Testing
@testable import barcodes

// MARK: - High-Level Encoder

@Suite("High-Level Encoder")
struct HighLevelEncoderTests {
    @Test func asciiDigitPairsEncodeCorrectly() throws {
        // Digit pairs: 12→1*10+2+130=142, 34→164, 56→186
        let codewords = try DataMatrixEncoder.encodeHighLevel("123456")
        #expect(codewords[0] == 142)
        #expect(codewords[1] == 164)
        #expect(codewords[2] == 186)
    }

    @Test func simpleASCIITextEncodes() throws {
        // 'A' (0x41=65) encodes as 65+1=66
        let codewords = try DataMatrixEncoder.encodeHighLevel("A")
        #expect(codewords[0] == 66)
    }

    @Test func outputFitsWithinSymbolCapacity() throws {
        let codewords = try DataMatrixEncoder.encodeHighLevel("Hello, World!")
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(dataCodewords: codewords.count)
        #expect(symbol != nil)
        #expect(codewords.count <= symbol!.dataCapacity)
    }

    @Test func nonLatin1ThrowsInvalidCharacter() {
        #expect(throws: DataMatrixEncoder.EncodingError.self) {
            _ = try DataMatrixEncoder.encodeHighLevel("\u{1F4BB}")
        }
    }

    @Test func singleDigitEncodesAsASCII() throws {
        // Single digit can't pair, encodes as char+1: '5'(0x35=53) → 54
        let codewords = try DataMatrixEncoder.encodeHighLevel("5")
        #expect(codewords[0] == 54)
    }

    @Test func encodingIsDeterministic() throws {
        let first = try DataMatrixEncoder.encodeHighLevel("Test123")
        let second = try DataMatrixEncoder.encodeHighLevel("Test123")
        #expect(first == second)
    }
}

// MARK: - Padding

@Suite("Padding")
struct PaddingTests {
    @Test func padsToCapacity() {
        var data: [UInt8] = [10, 20]
        DataMatrixEncoder.padToCapacity(&data, capacity: 5)
        #expect(data.count == 5)
    }

    @Test func firstPadByteIs129() {
        var data: [UInt8] = [10, 20]
        DataMatrixEncoder.padToCapacity(&data, capacity: 5)
        #expect(data[2] == 129)
    }

    @Test func subsequentPadBytesFollowFormula() {
        var data: [UInt8] = [10, 20]
        DataMatrixEncoder.padToCapacity(&data, capacity: 5)
        // Position 4 (count 3 + 1): pseudo = 129 + (149*4)%253 + 1 = 220
        #expect(data[3] == 220)
        // Position 5 (count 4 + 1): pseudo = 129 + (149*5)%253 + 1 = 369 → 369-254 = 115
        #expect(data[4] == 115)
    }

    @Test func alreadyAtCapacityIsUnchanged() {
        var data: [UInt8] = [10, 20, 30]
        let original = data
        DataMatrixEncoder.padToCapacity(&data, capacity: 3)
        #expect(data == original)
    }

    @Test func overCapacityIsUnchanged() {
        var data: [UInt8] = [10, 20, 30, 40]
        let original = data
        DataMatrixEncoder.padToCapacity(&data, capacity: 3)
        #expect(data == original)
    }
}

// MARK: - Symbol Info

@Suite("Symbol Info")
struct SymbolInfoTests {
    @Test func lookupReturnsSmallestFittingSymbol() {
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(dataCodewords: 3)!
        #expect(symbol.dataCapacity == 3)
    }

    @Test func lookupDataCodewords3Returns10x10() {
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(dataCodewords: 3)!
        #expect(symbol.symbolWidth == 10)
        #expect(symbol.symbolHeight == 10)
    }

    @Test func lookupDataCodewords4ReturnsNextSymbol() {
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(dataCodewords: 4)!
        #expect(symbol.dataCapacity == 5)
        #expect(symbol.symbolWidth == 12)
        #expect(symbol.symbolHeight == 12)
    }

    @Test func lookupExceedingMaxReturnsNil() {
        #expect(DataMatrixEncoder.SymbolInfo.lookup(dataCodewords: 9999) == nil)
    }

    @Test func lookupByDimensionsFindsMatch() {
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(
            symbolWidth: 10,
            symbolHeight: 10
        )!
        #expect(symbol.dataCapacity == 3)
    }

    @Test func lookupByDimensionsReturnsNilForInvalid() {
        #expect(DataMatrixEncoder.SymbolInfo.lookup(
            symbolWidth: 7,
            symbolHeight: 7
        ) == nil)
    }

    @Test func symbolWidthAndHeightComputedCorrectly() {
        // First symbol: matrixWidth=8, matrixHeight=8, dataRegions=1
        // horizontalDataRegions=1, verticalDataRegions=1
        // symbolWidth = 8*1 + 1*2 = 10, symbolHeight = 8*1 + 1*2 = 10
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(dataCodewords: 1)!
        #expect(symbol.symbolDataWidth == 8)
        #expect(symbol.symbolDataHeight == 8)
        #expect(symbol.symbolWidth == 10)
        #expect(symbol.symbolHeight == 10)
    }

    @Test func special144InterleavedBlockCount() {
        // 144×144 symbol has 10 interleaved blocks
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(
            symbolWidth: 144,
            symbolHeight: 144
        )!
        #expect(symbol.interleavedBlockCount == 10)
        #expect(symbol.isSpecial144)
    }

    @Test func rectangularSymbolDimensions() {
        // 18×8 rectangular: matrixWidth=16, matrixHeight=6, dataRegions=1
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(
            symbolWidth: 18,
            symbolHeight: 8
        )!
        #expect(symbol.rectangular)
        #expect(symbol.dataCapacity == 5)
    }
}

// MARK: - ECC

@Suite("ECC")
struct ECCTests {
    @Test func createECCBlockReturnsCorrectLength() {
        let ecc = DataMatrixEncoder.createECCBlock(
            codewords: [142, 164, 186],
            numECWords: 5
        )
        #expect(ecc.count == 5)
    }

    @Test func createECCBlockUnsupportedReturnsEmpty() {
        // 3 is not in factorSets
        let ecc = DataMatrixEncoder.createECCBlock(
            codewords: [1, 2, 3],
            numECWords: 3
        )
        #expect(ecc.isEmpty)
    }

    @Test func createECCBlockIsDeterministic() {
        let ecc1 = DataMatrixEncoder.createECCBlock(
            codewords: [142, 164, 186],
            numECWords: 5
        )
        let ecc2 = DataMatrixEncoder.createECCBlock(
            codewords: [142, 164, 186],
            numECWords: 5
        )
        #expect(ecc1 == ecc2)
    }

    @Test func encodeECC200SingleBlockOutputLength() {
        // First symbol: dataCapacity=3, errorCodewords=5
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(dataCodewords: 3)!
        let data: [UInt8] = [142, 164, 186]
        let result = DataMatrixEncoder.encodeECC200(
            data: data,
            symbolInfo: symbol
        )
        #expect(result.count == symbol.dataCapacity + symbol.errorCodewords)
    }

    @Test func encodeECC200SingleBlockPreservesData() {
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(dataCodewords: 3)!
        let data: [UInt8] = [142, 164, 186]
        let result = DataMatrixEncoder.encodeECC200(
            data: data,
            symbolInfo: symbol
        )
        // Data prefix should be preserved
        #expect(Array(result[0 ..< 3]) == data)
    }

    @Test func encodeECC200MultiBlockOutputLength() {
        // Symbol with rsBlockData < dataCapacity (multi-block)
        let symbol = DataMatrixEncoder.SymbolInfo.lookup(dataCodewords: 200)!
        var data = [UInt8](repeating: 129, count: symbol.dataCapacity)
        DataMatrixEncoder.padToCapacity(&data, capacity: symbol.dataCapacity)
        let result = DataMatrixEncoder.encodeECC200(
            data: data,
            symbolInfo: symbol
        )
        #expect(result.count == symbol.dataCapacity + symbol.errorCodewords)
    }

    @Test("All supported factor set sizes produce non-empty ECC",
          arguments: [5, 7, 10, 11, 12, 14, 18, 20, 24, 28, 36, 42, 48, 56, 62, 68])
    func allFactorSetsWork(numECWords: Int) {
        let data: [UInt8] = [1, 2, 3]
        let ecc = DataMatrixEncoder.createECCBlock(
            codewords: data,
            numECWords: numECWords
        )
        #expect(ecc.count == numECWords)
    }
}
