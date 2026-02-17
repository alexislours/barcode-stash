import Foundation

// MARK: - Character Classification & Lookahead

extension DataMatrixEncoder {
    // MARK: - Character Classification

    static func isDigit(_ char: UInt8) -> Bool {
        char >= 0x30 && char <= 0x39
    }

    static func isExtendedASCII(_ char: UInt8) -> Bool {
        char >= 128
    }

    static func isNativeC40(_ char: UInt8) -> Bool {
        char == 0x20
            || (char >= 0x30 && char <= 0x39)
            || (char >= 0x41 && char <= 0x5A)
    }

    static func isNativeText(_ char: UInt8) -> Bool {
        char == 0x20
            || (char >= 0x30 && char <= 0x39)
            || (char >= 0x61 && char <= 0x7A)
    }

    static func isNativeX12(_ char: UInt8) -> Bool {
        isX12TermSep(char) || char == 0x20
            || (char >= 0x30 && char <= 0x39)
            || (char >= 0x41 && char <= 0x5A)
    }

    static func isX12TermSep(_ char: UInt8) -> Bool {
        char == 0x0D || char == 0x2A || char == 0x3E
    }

    static func isNativeEDIFACT(_ char: UInt8) -> Bool {
        char >= 0x20 && char <= 0x5E
    }

    // MARK: - Lookahead Test

    static func lookAheadTest(
        msg: [UInt8],
        startpos: Int,
        currentMode: EncodingMode
    ) -> EncodingMode {
        if startpos >= msg.count { return currentMode }

        var charCounts = initializeLookaheadCounts(
            currentMode: currentMode
        )

        var charsProcessed = 0
        while true {
            if (startpos + charsProcessed) == msg.count {
                return selectMinimumMode(charCounts: charCounts)
            }

            let char = msg[startpos + charsProcessed]
            charsProcessed += 1
            updateCharCosts(char: char, charCounts: &charCounts)

            if charsProcessed >= 4 {
                if let result = evaluateAfterProcessing(
                    charCounts: charCounts,
                    msg: msg,
                    startpos: startpos,
                    charsProcessed: charsProcessed
                ) {
                    return result
                }
            }
        }
    }

    // MARK: - Lookahead Helpers

    static func initializeLookaheadCounts(
        currentMode: EncodingMode
    ) -> [Float] {
        if currentMode == .ascii {
            return [0, 1, 1, 1, 1, 1.25]
        }
        var counts: [Float] = [1, 2, 2, 2, 2, 2.25]
        counts[currentMode.rawValue] = 0
        return counts
    }

    static func updateCharCosts(
        char: UInt8,
        charCounts: inout [Float]
    ) {
        // ASCII cost
        if isDigit(char) {
            charCounts[0] += 0.5
        } else if isExtendedASCII(char) {
            charCounts[0] = Float(Int(ceil(charCounts[0]))) + 2
        } else {
            charCounts[0] = Float(Int(ceil(charCounts[0]))) + 1
        }

        // C40 cost
        if isNativeC40(char) {
            charCounts[1] += 2.0 / 3.0
        } else if isExtendedASCII(char) {
            charCounts[1] += 8.0 / 3.0
        } else {
            charCounts[1] += 4.0 / 3.0
        }

        // Text cost
        if isNativeText(char) {
            charCounts[2] += 2.0 / 3.0
        } else if isExtendedASCII(char) {
            charCounts[2] += 8.0 / 3.0
        } else {
            charCounts[2] += 4.0 / 3.0
        }

        // X12 cost
        if isNativeX12(char) {
            charCounts[3] += 2.0 / 3.0
        } else if isExtendedASCII(char) {
            charCounts[3] += 13.0 / 3.0
        } else {
            charCounts[3] += 10.0 / 3.0
        }

        // EDIFACT cost
        if isNativeEDIFACT(char) {
            charCounts[4] += 3.0 / 4.0
        } else if isExtendedASCII(char) {
            charCounts[4] += 17.0 / 4.0
        } else {
            charCounts[4] += 13.0 / 4.0
        }

        // Base256 cost
        charCounts[5] += 1
    }

    static func selectMinimumMode(
        charCounts: [Float]
    ) -> EncodingMode {
        var intCounts = [Int](repeating: 0, count: 6)
        var mins = [Int8](repeating: 0, count: 6)
        findMinimums(
            charCounts, intCharCounts: &intCounts, mins: &mins
        )

        guard let minCount = intCounts.min() else { return .ascii }
        if intCounts[0] == minCount { return .ascii }

        let minModeCount = mins.reduce(0) { $0 + Int($1) }
        if minModeCount == 1, mins[5] > 0 { return .base256 }
        if minModeCount == 1, mins[4] > 0 { return .edifact }
        if minModeCount == 1, mins[2] > 0 { return .text }
        if minModeCount == 1, mins[3] > 0 { return .x12 }
        return .c40
    }

    static func evaluateAfterProcessing(
        charCounts: [Float],
        msg: [UInt8],
        startpos: Int,
        charsProcessed: Int
    ) -> EncodingMode? {
        var intCounts = [Int](repeating: 0, count: 6)
        var mins = [Int8](repeating: 0, count: 6)
        findMinimums(
            charCounts, intCharCounts: &intCounts, mins: &mins
        )
        let minCount = Int(mins.reduce(0) { $0 + Int($1) })

        if intCounts[0] < intCounts[5],
           intCounts[0] < intCounts[1],
           intCounts[0] < intCounts[2],
           intCounts[0] < intCounts[3],
           intCounts[0] < intCounts[4] {
            return .ascii
        }
        if intCounts[5] < intCounts[0]
            || (mins[1] + mins[2] + mins[3] + mins[4]) == 0 {
            return .base256
        }
        if minCount == 1, mins[4] > 0 { return .edifact }
        if minCount == 1, mins[2] > 0 { return .text }
        if minCount == 1, mins[3] > 0 { return .x12 }
        if intCounts[1] + 1 < intCounts[0],
           intCounts[1] + 1 < intCounts[5],
           intCounts[1] + 1 < intCounts[4],
           intCounts[1] + 1 < intCounts[2] {
            return evaluateC40vsX12(
                intCounts: intCounts,
                msg: msg,
                startpos: startpos,
                charsProcessed: charsProcessed
            )
        }
        return nil
    }

    static func evaluateC40vsX12(
        intCounts: [Int],
        msg: [UInt8],
        startpos: Int,
        charsProcessed: Int
    ) -> EncodingMode {
        if intCounts[1] < intCounts[3] { return .c40 }
        if intCounts[1] == intCounts[3] {
            var pos = startpos + charsProcessed + 1
            while pos < msg.count {
                let testChar = msg[pos]
                if isX12TermSep(testChar) { return .x12 }
                if !isNativeX12(testChar) { break }
                pos += 1
            }
        }
        return .c40
    }

    static func findMinimums(
        _ charCounts: [Float],
        intCharCounts: inout [Int],
        mins: inout [Int8]
    ) {
        var minVal = Int.max
        for idx in 0 ..< 6 {
            mins[idx] = 0
        }
        for idx in 0 ..< 6 {
            intCharCounts[idx] = Int(ceil(charCounts[idx]))
            if minVal > intCharCounts[idx] {
                minVal = intCharCounts[idx]
                for jdx in 0 ..< 6 {
                    mins[jdx] = 0
                }
            }
            if minVal == intCharCounts[idx] {
                mins[idx] += 1
            }
        }
    }
}
