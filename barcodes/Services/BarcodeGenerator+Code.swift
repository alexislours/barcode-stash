import CoreImage

// MARK: - Code 39, Code 93, ITF-14 Encoding

extension BarcodeGenerator {
    // MARK: - Code 39

    /// Each character: 9 elements (BSBSBSBSB), 0=narrow 1=wide
    static let code39Patterns: [Character: String] = [
        "0": "000110100", "1": "100100001", "2": "001100001", "3": "101100000",
        "4": "000110001", "5": "100110000", "6": "001110000", "7": "000100101",
        "8": "100100100", "9": "001100100", "A": "100001001", "B": "001001001",
        "C": "101001000", "D": "000011001", "E": "100011000", "F": "001011000",
        "G": "000001101", "H": "100001100", "I": "001001100", "J": "000011100",
        "K": "100000011", "L": "001000011", "M": "101000010", "N": "000010011",
        "O": "100010010", "P": "001010010", "Q": "000000111", "R": "100000110",
        "S": "001000110", "T": "000010110", "U": "110000001", "V": "011000001",
        "W": "111000000", "X": "010010001", "Y": "110010000", "Z": "011010000",
        "-": "010000101", ".": "110000100", " ": "011000100", "$": "010101000",
        "/": "010100010", "+": "010001010", "%": "000101010", "*": "010010100",
    ]

    static func expandCode39(_ pattern: String) -> [Bool] {
        var modules: [Bool] = []
        for (idx, char) in pattern.enumerated() {
            let isBar = idx % 2 == 0
            let width = char == "1" ? 3 : 1
            modules += Array(repeating: isBar, count: width)
        }
        return modules
    }

    static func encodeCode39(_ value: String) -> [Bool]? {
        guard let starPattern = code39Patterns["*"] else { return nil }
        var modules: [Bool] = []

        // Start character *
        modules += expandCode39(starPattern)
        modules.append(false) // inter-character gap

        for char in value.uppercased() {
            guard let pattern = code39Patterns[char] else { return nil }
            modules += expandCode39(pattern)
            modules.append(false) // inter-character gap
        }

        // Stop character *
        modules += expandCode39(starPattern)
        return modules
    }

    // MARK: - Code 93

    /// Each entry: (character, value, widths as [bar,space,bar,space,bar,space] summing to 9)
    static let code93Table: [(char: Character, widths: [Int])] = [
        ("0", [1, 3, 1, 1, 1, 2]), ("1", [1, 1, 1, 2, 1, 3]), ("2", [1, 1, 1, 3, 1, 2]),
        ("3", [1, 1, 1, 4, 1, 1]), ("4", [1, 2, 1, 1, 1, 3]), ("5", [1, 2, 1, 2, 1, 2]),
        ("6", [1, 2, 1, 3, 1, 1]), ("7", [1, 1, 1, 1, 1, 4]), ("8", [3, 1, 1, 1, 1, 2]),
        ("9", [2, 1, 1, 1, 1, 3]), ("A", [2, 1, 1, 2, 1, 2]), ("B", [2, 1, 1, 3, 1, 1]),
        ("C", [2, 2, 1, 1, 1, 2]), ("D", [2, 2, 1, 2, 1, 1]), ("E", [2, 3, 1, 1, 1, 1]),
        ("F", [1, 1, 2, 1, 1, 3]), ("G", [1, 1, 2, 2, 1, 2]), ("H", [1, 1, 2, 3, 1, 1]),
        ("I", [1, 2, 2, 1, 1, 2]), ("J", [1, 2, 2, 2, 1, 1]), ("K", [1, 3, 2, 1, 1, 1]),
        ("L", [1, 1, 1, 1, 2, 3]), ("M", [1, 1, 1, 2, 2, 2]), ("N", [1, 1, 1, 3, 2, 1]),
        ("O", [1, 2, 1, 1, 2, 2]), ("P", [1, 2, 1, 2, 2, 1]), ("Q", [1, 3, 1, 1, 2, 1]),
        ("R", [2, 1, 1, 1, 2, 2]), ("S", [2, 1, 1, 2, 2, 1]), ("T", [2, 2, 1, 1, 2, 1]),
        ("U", [1, 1, 2, 1, 2, 2]), ("V", [1, 1, 2, 2, 2, 1]), ("W", [1, 2, 2, 1, 2, 1]),
        ("X", [2, 1, 2, 1, 1, 2]), ("Y", [2, 1, 2, 2, 1, 1]), ("Z", [2, 2, 2, 1, 1, 1]),
        ("-", [1, 1, 1, 1, 3, 2]), (".", [3, 1, 1, 1, 2, 1]), (" ", [3, 1, 1, 2, 1, 1]),
        ("$", [3, 2, 1, 1, 1, 1]), ("/", [1, 1, 2, 1, 3, 1]), ("+", [1, 1, 3, 1, 2, 1]),
        ("%", [2, 1, 1, 1, 3, 1]),
        // Shift characters (values 43–46) for check digit encoding
        ("\u{F1}", [3, 1, 2, 1, 1, 1]), ("\u{F2}", [1, 1, 3, 1, 1, 2]),
        ("\u{F3}", [1, 2, 3, 1, 1, 1]), ("\u{F4}", [1, 3, 1, 2, 1, 1]),
    ]

    static func expandCode93Widths(_ widths: [Int]) -> [Bool] {
        var modules: [Bool] = []
        for (idx, width) in widths.enumerated() {
            let isBar = idx % 2 == 0
            modules += Array(repeating: isBar, count: width)
        }
        return modules
    }

    static func encodeCode93(_ value: String) -> [Bool]? {
        // Map characters to values
        var values: [Int] = []
        for char in value.uppercased() {
            guard let index = code93Table.firstIndex(where: { $0.char == char }), index < 43 else {
                return nil
            }
            values.append(index)
        }

        // Compute check digit C (weights 1–20, right to left)
        var sum = 0
        for (idx, value) in values.reversed().enumerated() {
            sum += ((idx % 20) + 1) * value
        }
        let checkDigitC = sum % 47

        // Compute check digit K (weights 1–15, right to left, including C)
        let valuesWithC = values + [checkDigitC]
        sum = 0
        for (idx, value) in valuesWithC.reversed().enumerated() {
            sum += ((idx % 15) + 1) * value
        }
        let checkDigitK = sum % 47

        // Build modules
        var modules: [Bool] = []

        // Start: widths 1,1,1,1,4,1
        modules += expandCode93Widths([1, 1, 1, 1, 4, 1])

        // Data + check digits
        for value in values + [checkDigitC, checkDigitK] {
            modules += expandCode93Widths(code93Table[value].widths)
        }

        // Stop: same as start
        modules += expandCode93Widths([1, 1, 1, 1, 4, 1])

        // Termination bar
        modules.append(true)

        return modules
    }

    // MARK: - ITF-14 (Interleaved 2 of 5)

    /// Each digit: 5 elements, N=narrow W=wide
    static let itfPatterns = [
        "NNWWN", "WNNNW", "NWNNW", "WWNNN", "NNWNW",
        "WNWNN", "NWWNN", "NNNWW", "WNNWN", "NWNWN",
    ]

    static func encodeITF14(_ value: String) -> [Bool]? {
        let digits = value.compactMap(\.wholeNumberValue)
        guard digits.count == 14, digits.count % 2 == 0 else { return nil }

        var modules: [Bool] = []

        // Start: narrow bar, narrow space, narrow bar, narrow space
        modules += [true, false, true, false]

        // Encode digit pairs
        for pairIdx in stride(from: 0, to: digits.count, by: 2) {
            let barPattern = itfPatterns[digits[pairIdx]]
            let spacePattern = itfPatterns[digits[pairIdx + 1]]

            for elementIdx in 0 ..< 5 {
                let bIdx = barPattern.index(barPattern.startIndex, offsetBy: elementIdx)
                let sIdx = spacePattern.index(spacePattern.startIndex, offsetBy: elementIdx)
                let barWidth = barPattern[bIdx] == "W" ? 3 : 1
                let spaceWidth = spacePattern[sIdx] == "W" ? 3 : 1
                modules += Array(repeating: true, count: barWidth)
                modules += Array(repeating: false, count: spaceWidth)
            }
        }

        // End: wide bar, narrow space, narrow bar
        modules += Array(repeating: true, count: 3)
        modules += [false, true]

        return modules
    }
}
