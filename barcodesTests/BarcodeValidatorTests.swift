import Testing
import UIKit
@testable import barcodes

// MARK: - Empty Input

@Suite("Empty Input")
struct EmptyInputTests {
    @Test("All types reject empty input", arguments: BarcodeType.allCases)
    func rejectsEmpty(type: BarcodeType) {
        let result = BarcodeValidator.validate("", for: type)
        #expect(!result.isValid)
        #expect(result.message.contains("Enter"))
    }
}

// MARK: - Free-Form Types

@Suite("Free-Form Types")
struct FreeFormTests {
    @Test("Accept any non-empty input",
          arguments: [BarcodeType.qr, .code128, .pdf417, .aztec, .dataMatrix])
    func acceptsAnyInput(type: BarcodeType) {
        let result = BarcodeValidator.validate("Hello, World! 🌍", for: type)
        #expect(result.isValid)
        #expect(result.message.contains("Valid"))
    }
}

// MARK: - EAN-13

@Suite("EAN-13")
struct EAN13Tests {
    @Test func validCode() {
        let result = BarcodeValidator.validate("4006381333931", for: .ean13)
        #expect(result.isValid)
        #expect(result.message.contains("Valid"))
    }

    @Test func wrongDigitCount() {
        let result = BarcodeValidator.validate("123456", for: .ean13)
        #expect(!result.isValid)
        #expect(result.message.contains("13"))
    }

    @Test func nonDigitCharacters() {
        let result = BarcodeValidator.validate("400638133393A", for: .ean13)
        #expect(!result.isValid)
        #expect(result.message.contains("13"))
    }

    @Test func invalidCheckDigit() {
        let result = BarcodeValidator.validate("4006381333932", for: .ean13)
        #expect(!result.isValid)
        #expect(result.message.contains("1"))
    }
}

// MARK: - EAN-8

@Suite("EAN-8")
struct EAN8Tests {
    @Test func validCode() {
        let result = BarcodeValidator.validate("96385074", for: .ean8)
        #expect(result.isValid)
        #expect(result.message.contains("Valid"))
    }

    @Test func wrongDigitCount() {
        let result = BarcodeValidator.validate("1234", for: .ean8)
        #expect(!result.isValid)
        #expect(result.message.contains("8"))
    }

    @Test func nonDigitCharacters() {
        let result = BarcodeValidator.validate("9638507A", for: .ean8)
        #expect(!result.isValid)
        #expect(result.message.contains("8"))
    }

    @Test func invalidCheckDigit() {
        let result = BarcodeValidator.validate("96385075", for: .ean8)
        #expect(!result.isValid)
        #expect(result.message.contains("4"))
    }
}

// MARK: - UPC-E

@Suite("UPC-E")
struct UPCETests {
    @Test func validCode() {
        let result = BarcodeValidator.validate("04252614", for: .upce)
        #expect(result.isValid)
        #expect(result.message.contains("Valid"))
    }

    @Test func wrongDigitCount() {
        let result = BarcodeValidator.validate("12345", for: .upce)
        #expect(!result.isValid)
        #expect(result.message.contains("8"))
    }

    @Test func nonDigitCharacters() {
        let result = BarcodeValidator.validate("0425261A", for: .upce)
        #expect(!result.isValid)
        #expect(result.message.contains("8"))
    }

    @Test func acceptsAnyCheckDigit() {
        // UPC-E validation does not verify the check digit
        #expect(BarcodeValidator.validate("04252610", for: .upce).isValid)
    }
}

// MARK: - Code 39/93

@Suite("Code 39/93")
struct Code39_93Tests {
    @Test("Valid alphanumeric input", arguments: [BarcodeType.code39, .code93])
    func validInput(type: BarcodeType) {
        let result = BarcodeValidator.validate("HELLO-123 $/+%.", for: type)
        #expect(result.isValid)
        #expect(result.message.contains("Valid"))
    }

    @Test("Rejects lowercase input", arguments: [BarcodeType.code39, .code93])
    func lowercaseInput(type: BarcodeType) {
        #expect(!BarcodeValidator.validate("hello", for: type).isValid)
    }

    @Test("Rejects invalid characters", arguments: [BarcodeType.code39, .code93])
    func invalidCharacters(type: BarcodeType) {
        let result = BarcodeValidator.validate("TEST@VALUE", for: type)
        #expect(!result.isValid)
        #expect(result.message.contains("A-Z"))
    }
}

// MARK: - ITF-14

@Suite("ITF-14")
struct ITF14Tests {
    @Test func validCode() {
        let result = BarcodeValidator.validate("12345678901231", for: .itf14)
        #expect(result.isValid)
        #expect(result.message.contains("Valid"))
    }

    @Test func wrongDigitCount() {
        let result = BarcodeValidator.validate("123456", for: .itf14)
        #expect(!result.isValid)
        #expect(result.message.contains("14"))
    }

    @Test func nonDigitCharacters() {
        let result = BarcodeValidator.validate("1234567890123A", for: .itf14)
        #expect(!result.isValid)
        #expect(result.message.contains("14"))
    }

    @Test func invalidCheckDigit() {
        let result = BarcodeValidator.validate("12345678901230", for: .itf14)
        #expect(!result.isValid)
        #expect(result.message.contains("1"))
    }
}

// MARK: - Check Digit Algorithm

@Suite("Check Digit Algorithm")
struct CheckDigitTests {
    @Test("Reports expected check digit in error",
          arguments: zip(
              ["4006381333932", "96385075"],
              ["1", "4"]
          ))
    func reportsExpectedDigit(input: String, expected: String) {
        let type: BarcodeType = input.count == 13 ? .ean13 : .ean8
        let result = BarcodeValidator.validate(input, for: type)
        #expect(!result.isValid)
        #expect(result.message.contains(expected))
    }

    @Test func checkDigitZero() {
        // EAN-13 where computed check digit is 0: (10 - 0) % 10 = 0
        #expect(BarcodeValidator.validate("0000000000000", for: .ean13).isValid)
        // EAN-8 where computed check digit is 0
        #expect(BarcodeValidator.validate("00000000", for: .ean8).isValid)
        // ITF-14 where computed check digit is 0
        #expect(BarcodeValidator.validate("00000000000000", for: .itf14).isValid)
    }

    @Test func checkDigitNine() {
        // EAN-13: first 12 digits sum to remainder 1 → check = 9
        #expect(BarcodeValidator.validate("1000000000009", for: .ean13).isValid)
        // EAN-8: first 7 digits sum to remainder 1 → check = 9
        #expect(BarcodeValidator.validate("01000009", for: .ean8).isValid)
        // ITF-14: first 13 digits sum to remainder 1 → check = 9
        #expect(BarcodeValidator.validate("01000000000009", for: .itf14).isValid)
    }
}

// MARK: - Hints

@Suite("Hints")
struct HintTests {
    @Test("All types return non-empty hint", arguments: BarcodeType.allCases)
    func nonEmptyHint(type: BarcodeType) {
        #expect(!BarcodeValidator.hint(for: type).isEmpty)
    }
}

// MARK: - Keyboard Types

@Suite("Keyboard Types")
struct KeyboardTypeTests {
    @Test("Numeric types use numberPad",
          arguments: [BarcodeType.ean13, .ean8, .upce, .itf14])
    func numericTypes(type: BarcodeType) {
        #expect(BarcodeValidator.keyboardType(for: type) == .numberPad)
    }

    @Test("Alpha types use asciiCapable",
          arguments: [BarcodeType.code39, .code93])
    func alphaTypes(type: BarcodeType) {
        #expect(BarcodeValidator.keyboardType(for: type) == .asciiCapable)
    }

    @Test("Free-form types use default keyboard",
          arguments: [BarcodeType.qr, .code128, .pdf417, .aztec, .dataMatrix])
    func freeFormTypes(type: BarcodeType) {
        #expect(BarcodeValidator.keyboardType(for: type) == .default)
    }
}
