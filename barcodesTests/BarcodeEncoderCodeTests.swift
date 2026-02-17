import Testing
@testable import barcodes

// MARK: - Code 39 Encoder

@Suite("Code 39 Encoder")
struct Code39EncoderTests {
    @Test func knownInputProducesResult() {
        #expect(BarcodeGenerator.encodeCode39("HELLO") != nil)
    }

    @Test func startAndStopMatch() {
        let modules = BarcodeGenerator.encodeCode39("A")!
        let starModules = BarcodeGenerator.expandCode39(
            BarcodeGenerator.code39Patterns["*"]!
        )
        // First modules are the start *
        #expect(Array(modules[0 ..< starModules.count]) == starModules)
        // Last modules are the stop *
        let endStart = modules.count - starModules.count
        #expect(Array(modules[endStart...]) == starModules)
    }

    @Test func invalidCharacterReturnsNil() {
        #expect(BarcodeGenerator.encodeCode39("TEST@VALUE") == nil)
    }

    @Test func emptyStringProducesStartStop() {
        let modules = BarcodeGenerator.encodeCode39("")!
        // Start * (15) + gap (1) + stop * (15) = 31
        #expect(modules.count == 31)
    }

    @Test func moduleCountIsCorrect() {
        // Each char = 15 modules + 1 gap; start = 15 + 1 gap; stop = 15 (no trailing gap)
        // Total for "HELLO" (5 chars): 15 + 1 + 5*(15+1) + 15 = 111
        #expect(BarcodeGenerator.encodeCode39("HELLO")?.count == 111)
    }

    @Test func lowercaseIsUppercased() {
        // Code 39 uppercases input
        let upper = BarcodeGenerator.encodeCode39("HELLO")
        let lower = BarcodeGenerator.encodeCode39("hello")
        #expect(upper == lower)
    }
}

// MARK: - Code 93 Encoder

@Suite("Code 93 Encoder")
struct Code93EncoderTests {
    @Test func knownInputProducesResult() {
        #expect(BarcodeGenerator.encodeCode93("HELLO") != nil)
    }

    @Test func startPatternPresent() {
        let modules = BarcodeGenerator.encodeCode93("A")!
        // Start pattern widths [1,1,1,1,4,1] = 9 modules
        let startExpected = BarcodeGenerator.expandCode93Widths([1, 1, 1, 1, 4, 1])
        #expect(Array(modules[0 ..< 9]) == startExpected)
    }

    @Test func terminationBarAtEnd() {
        let modules = BarcodeGenerator.encodeCode93("A")!
        #expect(modules.last == true)
    }

    @Test func invalidCharacterReturnsNil() {
        #expect(BarcodeGenerator.encodeCode93("test@") == nil)
    }

    @Test func moduleCountIncludesCheckDigits() {
        // "HELLO": start(9) + 5 data(45) + C(9) + K(9) + stop(9) + term(1) = 82
        #expect(BarcodeGenerator.encodeCode93("HELLO")?.count == 82)
    }

    @Test func lowercaseIsUppercased() {
        let upper = BarcodeGenerator.encodeCode93("HELLO")
        let lower = BarcodeGenerator.encodeCode93("hello")
        #expect(upper == lower)
    }

    @Test func emptyStringProducesStartStopAndCheckDigits() {
        let modules = BarcodeGenerator.encodeCode93("")!
        // start(9) + C(9) + K(9) + stop(9) + term(1) = 37
        #expect(modules.count == 37)
    }
}

// MARK: - ITF-14 Encoder

@Suite("ITF-14 Encoder")
struct ITF14EncoderTests {
    @Test func knownInputProducesResult() {
        #expect(BarcodeGenerator.encodeITF14("12345678901231") != nil)
    }

    @Test func startPattern() {
        let modules = BarcodeGenerator.encodeITF14("12345678901231")!
        #expect(Array(modules[0 ..< 4]) == [true, false, true, false])
    }

    @Test func endPattern() {
        let modules = BarcodeGenerator.encodeITF14("12345678901231")!
        let end = modules.count
        // End: wide bar (3), narrow space (1), narrow bar (1) = 5 modules
        #expect(Array(modules[(end - 5)...]) == [true, true, true, false, true])
    }

    @Test func nonFourteenDigitInputReturnsNil() {
        #expect(BarcodeGenerator.encodeITF14("123456") == nil)
    }

    @Test func nonDigitInputReturnsNil() {
        #expect(BarcodeGenerator.encodeITF14("1234567890123A") == nil)
    }

    @Test func correctTotalModuleCount() {
        // Start(4) + 7 pairs × 18 modules + end(5) = 135
        #expect(BarcodeGenerator.encodeITF14("12345678901231")?.count == 135)
    }

    @Test func allZerosEncodes() {
        let modules = BarcodeGenerator.encodeITF14("00000000000000")
        #expect(modules?.count == 135)
    }
}
