import Testing
@testable import barcodes

// MARK: - Character Classification

@Suite("isDigit")
struct IsDigitTests {
    @Test("Digits 0-9 return true", arguments: UInt8(0x30) ... UInt8(0x39))
    func digitsAreTrue(char: UInt8) {
        #expect(DataMatrixEncoder.isDigit(char))
    }

    @Test("Non-digits return false", arguments: [UInt8(0x00), 0x20, 0x2F, 0x3A, 0x41, 0x7F, 0xFF])
    func nonDigitsAreFalse(char: UInt8) {
        #expect(!DataMatrixEncoder.isDigit(char))
    }
}

@Suite("isExtendedASCII")
struct IsExtendedASCIITests {
    @Test("128+ return true", arguments: [UInt8(128), 200, 255])
    func extendedIsTrue(char: UInt8) {
        #expect(DataMatrixEncoder.isExtendedASCII(char))
    }

    @Test("0-127 return false", arguments: [UInt8(0), 32, 65, 97, 127])
    func standardIsFalse(char: UInt8) {
        #expect(!DataMatrixEncoder.isExtendedASCII(char))
    }
}

@Suite("isNativeC40")
struct IsNativeC40Tests {
    @Test("Space, digits, uppercase return true",
          arguments: [UInt8(0x20), 0x30, 0x39, 0x41, 0x5A])
    func nativeC40IsTrue(char: UInt8) {
        #expect(DataMatrixEncoder.isNativeC40(char))
    }

    @Test("Lowercase, control chars return false",
          arguments: [UInt8(0x00), 0x1F, 0x61, 0x7A, 0x21])
    func nonNativeC40IsFalse(char: UInt8) {
        #expect(!DataMatrixEncoder.isNativeC40(char))
    }
}

@Suite("isNativeText")
struct IsNativeTextTests {
    @Test("Space, digits, lowercase return true",
          arguments: [UInt8(0x20), 0x30, 0x39, 0x61, 0x7A])
    func nativeTextIsTrue(char: UInt8) {
        #expect(DataMatrixEncoder.isNativeText(char))
    }

    @Test("Uppercase return false",
          arguments: [UInt8(0x41), 0x5A])
    func uppercaseIsFalse(char: UInt8) {
        #expect(!DataMatrixEncoder.isNativeText(char))
    }
}

@Suite("isNativeX12")
struct IsNativeX12Tests {
    @Test("C40 chars plus CR/*/> return true",
          arguments: [UInt8(0x0D), 0x2A, 0x3E, 0x20, 0x30, 0x41, 0x5A])
    func nativeX12IsTrue(char: UInt8) {
        #expect(DataMatrixEncoder.isNativeX12(char))
    }

    @Test("Lowercase return false", arguments: [UInt8(0x61), 0x7A])
    func lowercaseIsFalse(char: UInt8) {
        #expect(!DataMatrixEncoder.isNativeX12(char))
    }
}

@Suite("isNativeEDIFACT")
struct IsNativeEDIFACTTests {
    @Test("0x20-0x5E return true", arguments: [UInt8(0x20), 0x40, 0x5E])
    func nativeEdifactIsTrue(char: UInt8) {
        #expect(DataMatrixEncoder.isNativeEDIFACT(char))
    }

    @Test("Outside range return false", arguments: [UInt8(0x1F), 0x5F, 0x00, 0xFF])
    func outsideRangeIsFalse(char: UInt8) {
        #expect(!DataMatrixEncoder.isNativeEDIFACT(char))
    }
}

// MARK: - Lookahead

@Suite("Lookahead")
struct LookaheadTests {
    @Test func allDigitInputReturnsASCII() {
        let msg = Array("123456".utf8)
        let mode = DataMatrixEncoder.lookAheadTest(
            msg: msg, startpos: 0, currentMode: .ascii
        )
        #expect(mode == .ascii)
    }

    @Test func allUppercaseReturnsC40() {
        let msg = Array("ABCDEFGHIJ".utf8)
        let mode = DataMatrixEncoder.lookAheadTest(
            msg: msg, startpos: 0, currentMode: .ascii
        )
        #expect(mode == .c40)
    }

    @Test func allLowercaseReturnsText() {
        let msg = Array("abcdefghij".utf8)
        let mode = DataMatrixEncoder.lookAheadTest(
            msg: msg, startpos: 0, currentMode: .ascii
        )
        #expect(mode == .text)
    }

    @Test func emptyInputReturnsCurrentMode() {
        let msg: [UInt8] = []
        let mode = DataMatrixEncoder.lookAheadTest(
            msg: msg, startpos: 0, currentMode: .c40
        )
        #expect(mode == .c40)
    }

    @Test func pastEndReturnsCurrentMode() {
        let msg = Array("AB".utf8)
        let mode = DataMatrixEncoder.lookAheadTest(
            msg: msg, startpos: 5, currentMode: .text
        )
        #expect(mode == .text)
    }

    @Test func mixedInputReturnsReasonableMode() {
        let msg = Array("Hello123World".utf8)
        let mode = DataMatrixEncoder.lookAheadTest(
            msg: msg, startpos: 0, currentMode: .ascii
        )
        // Should pick a mode (not crash); exact mode depends on cost analysis
        let validModes: [DataMatrixEncoder.EncodingMode] = [
            .ascii, .c40, .text, .x12, .edifact, .base256,
        ]
        #expect(validModes.contains(mode))
    }
}
