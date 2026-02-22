import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// ECC200 Data Matrix encoder with multi-mode support, ported from ZXing.
/// Supports ASCII, C40, Text, X12, EDIFACT, and Base256 encoding modes
/// with cost-based lookahead for optimal mode selection.
enum DataMatrixEncoder {
    // MARK: - Public API

    /// Generates a pixel-perfect CIImage from a captured CIDataMatrixCodeDescriptor's
    /// payload and dimensions. The payload contains the original data codewords
    /// (after error-correction recovery), preserving the original encoder's mode choices.
    /// Pads and recomputes ECC (which is deterministic) to get the full codeword stream
    /// for module placement.
    nonisolated static func generateImage(
        fromPayload payload: Data,
        rowCount: Int,
        columnCount: Int,
        eccVersion: CIDataMatrixCodeDescriptor.ECCVersion
    ) -> CIImage? {
        guard eccVersion == .v200 else { return nil }
        guard let symbol = SymbolInfo.lookup(
            symbolWidth: columnCount,
            symbolHeight: rowCount
        ) else { return nil }

        var data = Array(payload)
        padToCapacity(&data, capacity: symbol.dataCapacity)
        let allCodewords = encodeECC200(data: data, symbolInfo: symbol)
        return renderCustomMatrix(symbolInfo: symbol, codewords: allCodewords)
    }

    /// Generates a CIImage for the given text as a Data Matrix barcode.
    /// Tries CIDataMatrixCodeDescriptor first for pixel-perfect rendering;
    /// falls back to a custom bitmap renderer if the descriptor isn't accepted.
    nonisolated static func generateImage(for text: String) -> CIImage? {
        guard !text.isEmpty else { return nil }
        guard let codewords = try? encodeHighLevel(text) else { return nil }
        guard let symbol = SymbolInfo.lookup(
            dataCodewords: codewords.count
        ) else { return nil }

        var padded = codewords
        padToCapacity(&padded, capacity: symbol.dataCapacity)
        let allCodewords = encodeECC200(data: padded, symbolInfo: symbol)

        // Try CIDataMatrixCodeDescriptor for pixel-perfect rendering
        if let descriptor = CIDataMatrixCodeDescriptor(
            payload: Data(padded),
            rowCount: symbol.symbolHeight,
            columnCount: symbol.symbolWidth,
            eccVersion: .v200
        ) {
            let filter = CIFilter.barcodeGenerator()
            filter.barcodeDescriptor = descriptor
            if let image = filter.outputImage {
                return image
            }
        }

        return renderCustomMatrix(symbolInfo: symbol, codewords: allCodewords)
    }

    // MARK: - Encoding Modes

    nonisolated enum EncodingMode: Int {
        case ascii = 0, c40, text, x12, edifact, base256
    }

    // MARK: - Latch Codes

    nonisolated static let latchToC40: UInt8 = 230
    nonisolated static let latchToBase256: UInt8 = 231
    nonisolated static let upperShift: UInt8 = 235
    nonisolated static let latchToX12: UInt8 = 238
    nonisolated static let latchToText: UInt8 = 239
    nonisolated static let latchToEdifact: UInt8 = 240
    nonisolated static let unlatch: UInt8 = 254
    nonisolated static let pad: UInt8 = 129

    // MARK: - Mode Encoder Dispatch

    nonisolated enum AnyModeEncoder {
        case ascii(ASCIIEncoder)
        case c40(C40Encoder)
        case text(TextEncoder)
        case x12(X12Encoder)
        case edifact(EdifactEncoder)
        case base256(Base256Encoder)

        func encode(_ ctx: EncoderContext) {
            switch self {
            case let .ascii(encoder): encoder.encode(ctx)
            case let .c40(encoder): encoder.encode(ctx)
            case let .text(encoder): encoder.encode(ctx)
            case let .x12(encoder): encoder.encode(ctx)
            case let .edifact(encoder): encoder.encode(ctx)
            case let .base256(encoder): encoder.encode(ctx)
            }
        }
    }

    // MARK: - Encoder Context

    final nonisolated class EncoderContext {
        let message: [UInt8]
        var codewords: [UInt8] = []
        var pos: Int = 0
        var newEncoding: Int = -1
        var skipAtEnd: Int = 0
        var symbolInfo: SymbolInfo?

        init(message: String) throws(EncodingError) {
            guard let data = message.data(using: .isoLatin1) else {
                throw EncodingError.invalidCharacter
            }
            self.message = Array(data)
        }

        var currentChar: UInt8 {
            message[pos]
        }

        func writeCodeword(_ codeword: UInt8) {
            codewords.append(codeword)
        }

        func writeCodewords(_ cws: [UInt8]) {
            codewords.append(contentsOf: cws)
        }

        var codewordCount: Int {
            codewords.count
        }

        func signalEncoderChange(_ mode: EncodingMode) {
            newEncoding = mode.rawValue
        }

        func resetEncoderSignal() {
            newEncoding = -1
        }

        var hasMoreCharacters: Bool {
            pos < totalMessageCharCount
        }

        var totalMessageCharCount: Int {
            message.count - skipAtEnd
        }

        var remainingCharacters: Int {
            totalMessageCharCount - pos
        }

        func updateSymbolInfo() {
            updateSymbolInfo(length: codewordCount)
        }

        func updateSymbolInfo(length len: Int) {
            if let current = symbolInfo, len <= current.dataCapacity {
                return
            }
            symbolInfo = SymbolInfo.lookup(dataCodewords: len)
        }

        func resetSymbolInfo() {
            symbolInfo = nil
        }
    }

    // MARK: - Encoding Error

    nonisolated enum EncodingError: Error {
        case invalidCharacter
        case capacityExceeded
    }

    // MARK: - Padding

    nonisolated static func padToCapacity(_ data: inout [UInt8], capacity: Int) {
        guard data.count < capacity else { return }
        data.append(pad)
        while data.count < capacity {
            let pos = data.count + 1
            var pseudo = 129 + (149 * pos) % 253 + 1
            if pseudo > 254 { pseudo -= 254 }
            data.append(UInt8(pseudo))
        }
    }

    // MARK: - High-Level Encoder

    nonisolated static func encodeHighLevel(_ text: String) throws(EncodingError) -> [UInt8] {
        let encoders: [AnyModeEncoder] = [
            .ascii(ASCIIEncoder()), .c40(C40Encoder()), .text(TextEncoder()),
            .x12(X12Encoder()), .edifact(EdifactEncoder()), .base256(Base256Encoder()),
        ]

        let ctx = try EncoderContext(message: text)
        var encodingMode = EncodingMode.ascii

        while ctx.hasMoreCharacters {
            encoders[encodingMode.rawValue].encode(ctx)
            if ctx.newEncoding >= 0 {
                encodingMode = EncodingMode(
                    rawValue: ctx.newEncoding
                ) ?? .ascii
                ctx.resetEncoderSignal()
            }
        }

        let len = ctx.codewordCount
        ctx.updateSymbolInfo()
        guard let symbolInfo = ctx.symbolInfo else {
            throw EncodingError.capacityExceeded
        }
        let capacity = symbolInfo.dataCapacity
        if len < capacity {
            if encodingMode != .ascii,
               encodingMode != .base256,
               encodingMode != .edifact {
                ctx.writeCodeword(unlatch)
            }
        }

        if ctx.codewords.count < capacity {
            ctx.writeCodeword(pad)
        }
        while ctx.codewords.count < capacity {
            let pos = ctx.codewords.count + 1
            var pseudo = 129 + (149 * pos) % 253 + 1
            if pseudo > 254 { pseudo -= 254 }
            ctx.writeCodeword(UInt8(pseudo))
        }

        return ctx.codewords
    }
}
