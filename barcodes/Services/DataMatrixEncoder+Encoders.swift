import Foundation

// MARK: - X12, EDIFACT & Base256 Mode Encoders

extension DataMatrixEncoder {
    // MARK: - X12 Encoder

    struct X12Encoder {
        func encode(_ ctx: EncoderContext) {
            var buffer: [UInt8] = []
            while ctx.hasMoreCharacters {
                let char = ctx.currentChar
                ctx.pos += 1
                encodeX12Char(char, buffer: &buffer)

                if (buffer.count % 3) == 0 {
                    writeNextTriplet(ctx, buffer: &buffer)
                    let newMode = lookAheadTest(
                        msg: ctx.message,
                        startpos: ctx.pos,
                        currentMode: .x12
                    )
                    if newMode != .x12 {
                        ctx.signalEncoderChange(.ascii)
                        break
                    }
                }
            }
            handleX12EOD(ctx, buffer: &buffer)
        }

        private func encodeX12Char(
            _ char: UInt8,
            buffer: inout [UInt8]
        ) {
            if char == 0x0D { buffer.append(0) } else if char == 0x2A { buffer.append(1) } else if char == 0x3E {
                buffer.append(2)
            } else if char == 0x20 { buffer.append(3) } else if char >= 0x30, char <= 0x39 {
                buffer.append(UInt8(Int(char) - 48 + 4))
            } else if char >= 0x41, char <= 0x5A {
                buffer.append(UInt8(Int(char) - 65 + 14))
            }
        }

        private func handleX12EOD(
            _ ctx: EncoderContext,
            buffer: inout [UInt8]
        ) {
            ctx.updateSymbolInfo()
            guard let symbolInfo = ctx.symbolInfo else { return }
            let available = symbolInfo.dataCapacity - ctx.codewordCount
            let count = buffer.count
            ctx.pos -= count
            if ctx.remainingCharacters > 1
                || available > 1
                || ctx.remainingCharacters != available {
                ctx.writeCodeword(DataMatrixEncoder.unlatch)
            }
            if ctx.newEncoding < 0 {
                ctx.signalEncoderChange(.ascii)
            }
        }
    }

    // MARK: - EDIFACT Encoder

    struct EdifactEncoder {
        func encode(_ ctx: EncoderContext) {
            var buffer: [UInt8] = []
            while ctx.hasMoreCharacters {
                let char = ctx.currentChar
                encodeEdifactChar(char, buffer: &buffer)
                ctx.pos += 1

                if buffer.count >= 4 {
                    ctx.writeCodewords(
                        encodeEdifactToCodewords(&buffer)
                    )
                    let newMode = lookAheadTest(
                        msg: ctx.message,
                        startpos: ctx.pos,
                        currentMode: .edifact
                    )
                    if newMode != .edifact {
                        ctx.signalEncoderChange(.ascii)
                        break
                    }
                }
            }
            buffer.append(31) // Unlatch
            handleEdifactEOD(ctx, buffer: &buffer)
        }

        private func encodeEdifactChar(
            _ char: UInt8,
            buffer: inout [UInt8]
        ) {
            if char >= 0x20, char <= 0x3F {
                buffer.append(char)
            } else if char >= 0x40, char <= 0x5E {
                buffer.append(UInt8(Int(char) - 64))
            }
        }

        private func encodeEdifactToCodewords(
            _ buffer: inout [UInt8]
        ) -> [UInt8] {
            let char1 = buffer.count >= 1 ? Int(buffer[0]) : 0
            let char2 = buffer.count >= 2 ? Int(buffer[1]) : 0
            let char3 = buffer.count >= 3 ? Int(buffer[2]) : 0
            let char4 = buffer.count >= 4 ? Int(buffer[3]) : 0
            let value = (char1 << 18) + (char2 << 12)
                + (char3 << 6) + char4
            var result: [UInt8] = [UInt8((value >> 16) & 0xFF)]
            if buffer.count >= 2 {
                result.append(UInt8((value >> 8) & 0xFF))
            }
            if buffer.count >= 3 {
                result.append(UInt8(value & 0xFF))
            }
            let consumed = min(4, buffer.count)
            buffer.removeFirst(consumed)
            return result
        }

        private func handleEdifactEOD(
            _ ctx: EncoderContext,
            buffer: inout [UInt8]
        ) {
            let count = buffer.count
            if count == 0 {
                ctx.signalEncoderChange(.ascii)
                return
            }
            if count == 1 {
                ctx.updateSymbolInfo()
                guard let symbolInfo = ctx.symbolInfo else { return }
                var available = symbolInfo.dataCapacity
                    - ctx.codewordCount
                let remaining = ctx.remainingCharacters
                if remaining > available {
                    ctx.updateSymbolInfo(
                        length: ctx.codewordCount + 1
                    )
                    guard let updated = ctx.symbolInfo else { return }
                    available = updated.dataCapacity - ctx.codewordCount
                }
                if remaining <= available, available <= 2 {
                    ctx.signalEncoderChange(.ascii)
                    return
                }
            }

            let restChars = count - 1
            let encoded = encodeEdifactToCodewords(&buffer)
            let endOfSymbol = !ctx.hasMoreCharacters
            var restInAscii = endOfSymbol && restChars <= 2

            if restChars <= 2 {
                ctx.updateSymbolInfo(
                    length: ctx.codewordCount + restChars
                )
                guard let symbolInfo = ctx.symbolInfo else { return }
                let available = symbolInfo.dataCapacity
                    - ctx.codewordCount
                if available >= 3 {
                    restInAscii = false
                    ctx.updateSymbolInfo(
                        length: ctx.codewordCount + encoded.count
                    )
                }
            }

            if restInAscii {
                ctx.resetSymbolInfo()
                ctx.pos -= restChars
            } else {
                ctx.writeCodewords(encoded)
            }
            ctx.signalEncoderChange(.ascii)
        }
    }

    // MARK: - Base256 Encoder

    struct Base256Encoder {
        func encode(_ ctx: EncoderContext) {
            var buffer: [UInt8] = [0] // length placeholder
            while ctx.hasMoreCharacters {
                buffer.append(ctx.currentChar)
                ctx.pos += 1
                let newMode = lookAheadTest(
                    msg: ctx.message,
                    startpos: ctx.pos,
                    currentMode: .base256
                )
                if newMode != .base256 {
                    ctx.signalEncoderChange(.ascii)
                    break
                }
            }
            let dataCount = buffer.count - 1
            let lengthFieldSize = dataCount > 249 ? 2 : 1
            let currentSize = ctx.codewordCount
                + dataCount + lengthFieldSize
            ctx.updateSymbolInfo(length: currentSize)
            guard let symbolInfo = ctx.symbolInfo else { return }
            let mustPad = symbolInfo.dataCapacity - currentSize > 0
            if ctx.hasMoreCharacters || mustPad {
                if dataCount <= 249 {
                    buffer[0] = UInt8(dataCount)
                } else {
                    buffer[0] = UInt8(dataCount / 250 + 249)
                    buffer.insert(UInt8(dataCount % 250), at: 1)
                }
            }
            for idx in 0 ..< buffer.count {
                ctx.writeCodeword(
                    randomize255State(
                        buffer[idx],
                        codewordPosition: ctx.codewordCount + 1
                    )
                )
            }
        }

        private func randomize255State(
            _ char: UInt8,
            codewordPosition: Int
        ) -> UInt8 {
            let pseudo = ((149 * codewordPosition) % 255) + 1
            let temp = Int(char) + pseudo
            return temp <= 255 ? UInt8(temp) : UInt8(temp - 256)
        }
    }
}
