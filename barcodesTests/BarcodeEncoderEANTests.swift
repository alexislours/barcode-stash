import Testing
@testable import barcodes

// MARK: - Pattern to Modules

@Suite("Pattern to Modules")
struct PatternToModulesTests {
    @Test func convertsPatternToBoolArray() {
        #expect(BarcodeGenerator.patternToModules("101") == [true, false, true])
    }

    @Test func emptyStringReturnsEmpty() {
        #expect(BarcodeGenerator.patternToModules("").isEmpty)
    }

    @Test func allZeros() {
        #expect(BarcodeGenerator.patternToModules("000") == [false, false, false])
    }

    @Test func allOnes() {
        #expect(BarcodeGenerator.patternToModules("111") == [true, true, true])
    }
}

// MARK: - EAN-13 Encoder

@Suite("EAN-13 Encoder")
struct EAN13EncoderTests {
    // EAN-13: 3 (start) + 42 (6×7 left) + 5 (center) + 42 (6×7 right) + 3 (end) = 95
    @Test func producesCorrectModuleCount() {
        #expect(BarcodeGenerator.encodeEAN13("4006381333931")?.count == 95)
    }

    @Test func startGuard() {
        let modules = BarcodeGenerator.encodeEAN13("4006381333931")!
        #expect(Array(modules[0 ..< 3]) == [true, false, true])
    }

    @Test func centerGuard() {
        let modules = BarcodeGenerator.encodeEAN13("4006381333931")!
        #expect(Array(modules[45 ..< 50]) == [false, true, false, true, false])
    }

    @Test func endGuard() {
        let modules = BarcodeGenerator.encodeEAN13("4006381333931")!
        #expect(Array(modules[92 ..< 95]) == [true, false, true])
    }

    @Test func wrongDigitCountReturnsNil() {
        #expect(BarcodeGenerator.encodeEAN13("123456") == nil)
    }

    @Test func nonDigitInputReturnsNil() {
        #expect(BarcodeGenerator.encodeEAN13("400638133393A") == nil)
    }

    @Test func firstDigitZeroEncodesCorrectly() {
        let modules = BarcodeGenerator.encodeEAN13("0000000000000")
        #expect(modules?.count == 95)
    }

    @Test func differentFirstDigitsProduceDifferentParity() {
        let modules0 = BarcodeGenerator.encodeEAN13("0000000000000")!
        let modules4 = BarcodeGenerator.encodeEAN13("4006381333931")!
        // Left halves differ due to different first-digit parity patterns
        #expect(Array(modules0[3 ..< 45]) != Array(modules4[3 ..< 45]))
    }
}

// MARK: - EAN-8 Encoder

@Suite("EAN-8 Encoder")
struct EAN8EncoderTests {
    // EAN-8: 3 (start) + 28 (4×7 left) + 5 (center) + 28 (4×7 right) + 3 (end) = 67
    @Test func producesCorrectModuleCount() {
        #expect(BarcodeGenerator.encodeEAN8("96385074")?.count == 67)
    }

    @Test func startGuard() {
        let modules = BarcodeGenerator.encodeEAN8("96385074")!
        #expect(Array(modules[0 ..< 3]) == [true, false, true])
    }

    @Test func centerGuard() {
        let modules = BarcodeGenerator.encodeEAN8("96385074")!
        // Center at position 3 + 28 = 31
        #expect(Array(modules[31 ..< 36]) == [false, true, false, true, false])
    }

    @Test func endGuard() {
        let modules = BarcodeGenerator.encodeEAN8("96385074")!
        #expect(Array(modules[64 ..< 67]) == [true, false, true])
    }

    @Test func wrongDigitCountReturnsNil() {
        #expect(BarcodeGenerator.encodeEAN8("1234") == nil)
    }

    @Test func nonDigitInputReturnsNil() {
        #expect(BarcodeGenerator.encodeEAN8("9638507A") == nil)
    }
}

// MARK: - UPC-E Encoder

@Suite("UPC-E Encoder")
struct UPCEEncoderTests {
    // UPC-E: 3 (start) + 42 (6×7 data) + 6 (end guard) = 51
    @Test func producesCorrectModuleCount() {
        #expect(BarcodeGenerator.encodeUPCE("04252614")?.count == 51)
    }

    @Test func startGuard() {
        let modules = BarcodeGenerator.encodeUPCE("04252614")!
        #expect(Array(modules[0 ..< 3]) == [true, false, true])
    }

    @Test func endGuard() {
        let modules = BarcodeGenerator.encodeUPCE("04252614")!
        // UPC-E end guard is 6 modules: [false, true, false, true, false, true]
        #expect(Array(modules[45 ..< 51]) == [false, true, false, true, false, true])
    }

    @Test func numberSystemZeroAndOneProduceDifferentParity() {
        // Same inner digits, different number system
        let ns0 = BarcodeGenerator.encodeUPCE("04252614")!
        let ns1 = BarcodeGenerator.encodeUPCE("14252614")!
        // Data sections differ due to inverted parity
        #expect(Array(ns0[3 ..< 45]) != Array(ns1[3 ..< 45]))
    }

    @Test func wrongDigitCountReturnsNil() {
        #expect(BarcodeGenerator.encodeUPCE("12345") == nil)
    }

    @Test func nonDigitInputReturnsNil() {
        #expect(BarcodeGenerator.encodeUPCE("0425261A") == nil)
    }
}
