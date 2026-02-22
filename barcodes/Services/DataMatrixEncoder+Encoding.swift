import Foundation

// MARK: - Mode Encoders & Shared Helpers

nonisolated extension DataMatrixEncoder {
    // MARK: - ASCII Encoder

    nonisolated struct ASCIIEncoder {
        func encode(_ ctx: EncoderContext) {
            let digitCount = consecutiveDigitCount(
                ctx.message, startpos: ctx.pos
            )
            if digitCount >= 2 {
                let digit1 = Int(ctx.message[ctx.pos]) - 48
                let digit2 = Int(ctx.message[ctx.pos + 1]) - 48
                ctx.writeCodeword(UInt8(digit1 * 10 + digit2 + 130))
                ctx.pos += 2
            } else {
                let char = ctx.currentChar
                let newMode = lookAheadTest(
                    msg: ctx.message,
                    startpos: ctx.pos,
                    currentMode: .ascii
                )
                if newMode != .ascii {
                    switch newMode {
                    case .base256:
                        ctx.writeCodeword(latchToBase256)
                        ctx.signalEncoderChange(.base256)
                    case .c40:
                        ctx.writeCodeword(latchToC40)
                        ctx.signalEncoderChange(.c40)
                    case .x12:
                        ctx.writeCodeword(latchToX12)
                        ctx.signalEncoderChange(.x12)
                    case .text:
                        ctx.writeCodeword(latchToText)
                        ctx.signalEncoderChange(.text)
                    case .edifact:
                        ctx.writeCodeword(latchToEdifact)
                        ctx.signalEncoderChange(.edifact)
                    default:
                        break
                    }
                } else if char >= 128 {
                    ctx.writeCodeword(upperShift)
                    ctx.writeCodeword(UInt8(Int(char) - 128 + 1))
                    ctx.pos += 1
                } else {
                    ctx.writeCodeword(char + 1)
                    ctx.pos += 1
                }
            }
        }
    }

    // MARK: - C40/Text Triplet Encoding

    static func encodeTripletChar(
        _ char: UInt8,
        buffer: inout [UInt8],
        isC40: Bool
    ) -> Int {
        // Native set (value 3 = space, 4-13 = digits, 14-39 = letters)
        if char == 0x20 { buffer.append(3); return 1 }
        if char >= 0x30, char <= 0x39 {
            buffer.append(UInt8(Int(char) - 48 + 4)); return 1
        }
        if isC40, char >= 0x41, char <= 0x5A {
            buffer.append(UInt8(Int(char) - 65 + 14)); return 1
        }
        if !isC40, char >= 0x61, char <= 0x7A {
            buffer.append(UInt8(Int(char) - 97 + 14)); return 1
        }
        return encodeShiftSet(char, buffer: &buffer, isC40: isC40)
    }

    static func encodeShiftSet(
        _ char: UInt8,
        buffer: inout [UInt8],
        isC40: Bool
    ) -> Int {
        if char <= 0x1F { // Shift 1
            buffer.append(0); buffer.append(char); return 2
        }
        if char >= 0x21, char <= 0x2F { // Shift 2: ! to /
            buffer.append(1)
            buffer.append(UInt8(Int(char) - 33))
            return 2
        }
        if char >= 0x3A, char <= 0x40 { // Shift 2: : to @
            buffer.append(1)
            buffer.append(UInt8(Int(char) - 58 + 15))
            return 2
        }
        if char >= 0x5B, char <= 0x5F { // Shift 2: [ to _
            buffer.append(1)
            buffer.append(UInt8(Int(char) - 91 + 22))
            return 2
        }
        if let count = encodeShift3(
            char, buffer: &buffer, isC40: isC40
        ) {
            return count
        }
        // Extended ASCII (>= 0x80): Shift 2 + Upper Shift + recursive
        if char >= 0x80 {
            buffer.append(1) // Shift 2
            buffer.append(30) // Upper Shift (0x1E)
            let len = encodeTripletChar(
                UInt8(Int(char) - 128),
                buffer: &buffer,
                isC40: isC40
            )
            return 2 + len
        }
        return 0
    }

    static func encodeShift3(
        _ char: UInt8,
        buffer: inout [UInt8],
        isC40: Bool
    ) -> Int? {
        if isC40 {
            if char >= 0x60, char <= 0x7F {
                buffer.append(2)
                buffer.append(UInt8(Int(char) - 96))
                return 2
            }
        } else {
            if char == 0x60 {
                buffer.append(2)
                buffer.append(UInt8(Int(char) - 96))
                return 2
            }
            if char >= 0x41, char <= 0x5A {
                buffer.append(2)
                buffer.append(UInt8(Int(char) - 65 + 1))
                return 2
            }
            if char >= 0x7B, char <= 0x7F {
                buffer.append(2)
                buffer.append(UInt8(Int(char) - 123 + 27))
                return 2
            }
        }
        return nil
    }

    static func encodeTripletToCodewords(
        _ buf: [UInt8],
        startpos: Int
    ) -> [UInt8] {
        let char1 = Int(buf[startpos])
        let char2 = Int(buf[startpos + 1])
        let char3 = Int(buf[startpos + 2])
        let value = 1600 * char1 + 40 * char2 + char3 + 1
        return [UInt8(value / 256), UInt8(value % 256)]
    }

    // MARK: - C40 Encoder

    nonisolated struct C40Encoder {
        func encode(_ ctx: EncoderContext) {
            var buffer: [UInt8] = []
            while ctx.hasMoreCharacters {
                let char = ctx.currentChar
                ctx.pos += 1

                let lastCharSize = encodeTripletChar(
                    char, buffer: &buffer, isC40: true
                )

                let unwritten = (buffer.count / 3) * 2
                let curCWCount = ctx.codewordCount + unwritten
                ctx.updateSymbolInfo(length: curCWCount)
                guard let symbolInfo = ctx.symbolInfo else { continue }
                let available = symbolInfo.dataCapacity - curCWCount

                if !ctx.hasMoreCharacters {
                    if (buffer.count % 3) == 2 {
                        if available < 2 || available > 2 {
                            backtrackOneChar(
                                ctx, buffer: &buffer,
                                lastCharSize: lastCharSize, isC40: true
                            )
                        }
                    }
                    var currentLastSize = lastCharSize
                    while (buffer.count % 3) == 1,
                          currentLastSize > 3 || available != 1 {
                        currentLastSize = backtrackOneChar(
                            ctx, buffer: &buffer,
                            lastCharSize: currentLastSize, isC40: true
                        )
                    }
                    break
                }

                if (buffer.count % 3) == 0 {
                    let newMode = lookAheadTest(
                        msg: ctx.message,
                        startpos: ctx.pos,
                        currentMode: .c40
                    )
                    if newMode != .c40 {
                        ctx.signalEncoderChange(.ascii)
                        break
                    }
                }
            }
            handleTripletEOD(ctx, buffer: &buffer, mode: .c40)
        }
    }

    // MARK: - Text Encoder

    nonisolated struct TextEncoder {
        func encode(_ ctx: EncoderContext) {
            var buffer: [UInt8] = []
            while ctx.hasMoreCharacters {
                let char = ctx.currentChar
                ctx.pos += 1

                let lastCharSize = encodeTripletChar(
                    char, buffer: &buffer, isC40: false
                )

                let unwritten = (buffer.count / 3) * 2
                let curCWCount = ctx.codewordCount + unwritten
                ctx.updateSymbolInfo(length: curCWCount)
                guard let symbolInfo = ctx.symbolInfo else { continue }
                let available = symbolInfo.dataCapacity - curCWCount

                if !ctx.hasMoreCharacters {
                    if (buffer.count % 3) == 2 {
                        if available < 2 || available > 2 {
                            backtrackOneChar(
                                ctx, buffer: &buffer,
                                lastCharSize: lastCharSize, isC40: false
                            )
                        }
                    }
                    var currentLastSize = lastCharSize
                    while (buffer.count % 3) == 1,
                          currentLastSize > 3 || available != 1 {
                        currentLastSize = backtrackOneChar(
                            ctx, buffer: &buffer,
                            lastCharSize: currentLastSize, isC40: false
                        )
                    }
                    break
                }

                if (buffer.count % 3) == 0 {
                    let newMode = lookAheadTest(
                        msg: ctx.message,
                        startpos: ctx.pos,
                        currentMode: .text
                    )
                    if newMode != .text {
                        ctx.signalEncoderChange(.ascii)
                        break
                    }
                }
            }
            handleTripletEOD(ctx, buffer: &buffer, mode: .text)
        }
    }

    // MARK: - Shared Triplet Helpers

    @discardableResult
    static func backtrackOneChar(
        _ ctx: EncoderContext,
        buffer: inout [UInt8],
        lastCharSize: Int,
        isC40: Bool
    ) -> Int {
        buffer.removeLast(lastCharSize)
        ctx.pos -= 1
        let char = ctx.currentChar
        var removed: [UInt8] = []
        let newSize = encodeTripletChar(
            char, buffer: &removed, isC40: isC40
        )
        ctx.resetSymbolInfo()
        return newSize
    }

    static func writeNextTriplet(
        _ ctx: EncoderContext,
        buffer: inout [UInt8]
    ) {
        let cws = encodeTripletToCodewords(buffer, startpos: 0)
        ctx.writeCodewords(cws)
        buffer.removeFirst(3)
    }

    static func handleTripletEOD(
        _ ctx: EncoderContext,
        buffer: inout [UInt8],
        mode _: EncodingMode
    ) {
        let unwritten = (buffer.count / 3) * 2
        let rest = buffer.count % 3

        let curCWCount = ctx.codewordCount + unwritten
        ctx.updateSymbolInfo(length: curCWCount)
        guard let symbolInfo = ctx.symbolInfo else { return }
        let available = symbolInfo.dataCapacity - curCWCount

        if rest == 2 {
            buffer.append(0) // Shift 1 padding
            while buffer.count >= 3 {
                writeNextTriplet(ctx, buffer: &buffer)
            }
            if ctx.hasMoreCharacters {
                ctx.writeCodeword(unlatch)
            }
        } else if available == 1, rest == 1 {
            while buffer.count >= 3 {
                writeNextTriplet(ctx, buffer: &buffer)
            }
            if ctx.hasMoreCharacters {
                ctx.writeCodeword(unlatch)
            }
            ctx.pos -= 1
        } else if rest == 0 {
            while buffer.count >= 3 {
                writeNextTriplet(ctx, buffer: &buffer)
            }
            if available > 0 || ctx.hasMoreCharacters {
                ctx.writeCodeword(unlatch)
            }
        }
        ctx.signalEncoderChange(.ascii)
    }

    // MARK: - Character Helpers

    static func consecutiveDigitCount(
        _ msg: [UInt8],
        startpos: Int
    ) -> Int {
        var count = 0
        var idx = startpos
        while idx < msg.count, isDigit(msg[idx]) {
            count += 1
            idx += 1
        }
        return count
    }
}
