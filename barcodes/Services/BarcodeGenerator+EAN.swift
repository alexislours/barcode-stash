import CoreImage

// MARK: - EAN / UPC Encoding

nonisolated extension BarcodeGenerator {
    // MARK: - EAN / UPC Encoding Tables

    /// L-code (odd parity), G-code (even parity), R-code - 7 modules each
    static let eanL = [
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011",
    ]
    static let eanG = [
        "0100111", "0110011", "0011011", "0100001", "0011101",
        "0111001", "0000101", "0010001", "0001001", "0010111",
    ]
    static let eanR = [
        "1110010", "1100110", "1101100", "1000010", "1011100",
        "1001110", "1010000", "1000100", "1001000", "1110100",
    ]

    /// First digit of EAN-13 determines L/G parity for left group
    static let ean13Parity = [
        "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
        "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL",
    ]

    /// UPC-E parity based on check digit (number system 0)
    /// O = odd (L-code), E = even (G-code)
    static let upceParityNS0 = [
        "EEEOOO", "EEOEOO", "EEOOEO", "EEOOOE", "EOEEOO",
        "EOOEEO", "EOOOEE", "EOEOEO", "EOEOOE", "EOOEOE",
    ]

    static func patternToModules(_ pattern: String) -> [Bool] {
        pattern.map { $0 == "1" }
    }

    // MARK: - EAN-13

    static func encodeEAN13(_ value: String) -> [Bool]? {
        let digits = value.compactMap(\.wholeNumberValue)
        guard digits.count == 13 else { return nil }

        var modules: [Bool] = []
        modules += [true, false, true] // start guard

        let parity = ean13Parity[digits[0]]
        for idx in 0 ..< 6 {
            let digit = digits[idx + 1]
            let parityChar = parity[parity.index(parity.startIndex, offsetBy: idx)]
            modules += patternToModules(parityChar == "L" ? eanL[digit] : eanG[digit])
        }

        modules += [false, true, false, true, false] // center guard

        for idx in 0 ..< 6 {
            modules += patternToModules(eanR[digits[idx + 7]])
        }

        modules += [true, false, true] // end guard
        return modules
    }

    // MARK: - EAN-8

    static func encodeEAN8(_ value: String) -> [Bool]? {
        let digits = value.compactMap(\.wholeNumberValue)
        guard digits.count == 8 else { return nil }

        var modules: [Bool] = []
        modules += [true, false, true]
        for idx in 0 ..< 4 {
            modules += patternToModules(eanL[digits[idx]])
        }
        modules += [false, true, false, true, false]
        for idx in 4 ..< 8 {
            modules += patternToModules(eanR[digits[idx]])
        }
        modules += [true, false, true]
        return modules
    }

    // MARK: - UPC-E

    static func encodeUPCE(_ value: String) -> [Bool]? {
        let digits = value.compactMap(\.wholeNumberValue)
        guard digits.count == 8 else { return nil }

        let numberSystem = digits[0]
        let checkDigit = digits[7]

        let basePattern = upceParityNS0[checkDigit]
        // Number system 1 inverts parity
        let parity: String = if numberSystem == 1 {
            String(basePattern.map { $0 == "O" ? Character("E") : Character("O") })
        } else {
            basePattern
        }

        var modules: [Bool] = []
        modules += [true, false, true] // start guard

        for idx in 0 ..< 6 {
            let digit = digits[idx + 1]
            let parityChar = parity[parity.index(parity.startIndex, offsetBy: idx)]
            modules += patternToModules(parityChar == "O" ? eanL[digit] : eanG[digit])
        }

        modules += [false, true, false, true, false, true] // UPC-E end guard (6 modules)
        return modules
    }
}
