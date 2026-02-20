import UIKit

enum BarcodeValidator {
    struct ValidationResult {
        let isValid: Bool
        let message: String
    }

    static func validate(_ input: String, for type: BarcodeType) -> ValidationResult {
        guard !input.isEmpty else {
            return ValidationResult(
                isValid: false,
                message: String(localized: "Enter a value", comment: "Validation: empty input")
            )
        }

        switch type {
        case .qr, .code128, .pdf417, .aztec, .dataMatrix:
            return validResult()
        case .ean13:
            return validateEAN13(input)
        case .ean8:
            return validateEAN8(input)
        case .upce:
            return validateUPCE(input)
        case .code39, .code93:
            return validateCode39Or93(input)
        case .itf14:
            return validateITF14(input)
        }
    }

    private static func validateEAN13(_ input: String) -> ValidationResult {
        let digits = input.filter(\.isNumber)
        guard digits.count == 13, digits == input else {
            return ValidationResult(
                isValid: false,
                message: String(
                    localized: "Must be exactly 13 digits",
                    comment: "Validation: EAN-13 digit count"
                )
            )
        }
        return checkDigitResult(digits: digits)
    }

    private static func validateEAN8(_ input: String) -> ValidationResult {
        let digits = input.filter(\.isNumber)
        guard digits.count == 8, digits == input else {
            return ValidationResult(
                isValid: false,
                message: String(
                    localized: "Must be exactly 8 digits",
                    comment: "Validation: EAN-8 digit count"
                )
            )
        }
        return checkDigitResult(digits: digits)
    }

    private static func validateUPCE(_ input: String) -> ValidationResult {
        let digits = input.filter(\.isNumber)
        guard digits.count == 8, digits == input else {
            return ValidationResult(
                isValid: false,
                message: String(
                    localized: "Must be exactly 8 digits",
                    comment: "Validation: UPC-E digit count"
                )
            )
        }
        let upcA = expandUPCEtoUPCA(digits)
        return checkDigitResult(digits: upcA)
    }

    private static func expandUPCEtoUPCA(_ digits: String) -> String {
        let nums = digits.compactMap(\.wholeNumberValue)
        let expanded: [Int] = switch nums[6] {
        case 0, 1, 2:
            [nums[0], nums[1], nums[2], nums[6], 0, 0, 0, 0, nums[3], nums[4], nums[5], nums[7]]
        case 3:
            [nums[0], nums[1], nums[2], nums[3], 0, 0, 0, 0, 0, nums[4], nums[5], nums[7]]
        case 4:
            [nums[0], nums[1], nums[2], nums[3], nums[4], 0, 0, 0, 0, 0, nums[5], nums[7]]
        default:
            [nums[0], nums[1], nums[2], nums[3], nums[4], nums[5], 0, 0, 0, 0, nums[6], nums[7]]
        }
        return expanded.map(String.init).joined()
    }

    private static func validateCode39Or93(_ input: String) -> ValidationResult {
        let allowed = CharacterSet.uppercaseLetters.union(.decimalDigits).union(CharacterSet(charactersIn: " -.$/+%"))
        guard input.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return ValidationResult(
                isValid: false,
                message: String(
                    localized: "Only A-Z, 0-9, space, -.$/+%",
                    comment: "Validation: allowed characters for Code 39/93"
                )
            )
        }
        return validResult()
    }

    private static func validateITF14(_ input: String) -> ValidationResult {
        let digits = input.filter(\.isNumber)
        guard digits.count == 14, digits == input else {
            return ValidationResult(
                isValid: false,
                message: String(
                    localized: "Must be exactly 14 digits",
                    comment: "Validation: ITF-14 digit count"
                )
            )
        }
        return checkDigitResult(digits: digits)
    }

    private static func validResult() -> ValidationResult {
        ValidationResult(
            isValid: true,
            message: String(localized: "Valid", comment: "Validation: input is valid")
        )
    }

    static func hint(for type: BarcodeType) -> String {
        hintMap[type] ?? ""
    }

    private static let hintMap: [BarcodeType: String] = [
        .qr: String(localized: "Any text, URL, or data", comment: "Hint for QR code input"),
        .ean13: String(localized: "13-digit product code", comment: "Hint for EAN-13 input"),
        .ean8: String(localized: "8-digit product code", comment: "Hint for EAN-8 input"),
        .upce: String(localized: "8-digit UPC code", comment: "Hint for UPC-E input"),
        .code128: String(localized: "Any text or numbers", comment: "Hint for Code 128 input"),
        .code39: String(localized: "A-Z, 0-9, space, -.$/+%", comment: "Hint for Code 39 input"),
        .code93: String(localized: "A-Z, 0-9, space, -.$/+%", comment: "Hint for Code 93 input"),
        .pdf417: String(localized: "Any text or data", comment: "Hint for PDF417 input"),
        .aztec: String(localized: "Any text or data", comment: "Hint for Aztec input"),
        .dataMatrix: String(localized: "Any text or data", comment: "Hint for DataMatrix input"),
        .itf14: String(localized: "14-digit shipping code", comment: "Hint for ITF-14 input"),
    ]

    static func keyboardType(for type: BarcodeType) -> UIKeyboardType {
        switch type {
        case .ean13, .ean8, .upce, .itf14:
            .numberPad
        case .code39, .code93:
            .asciiCapable
        case .qr, .code128, .pdf417, .aztec, .dataMatrix:
            .default
        }
    }

    // MARK: - Check Digit Validation

    private static func checkDigitResult(digits: String) -> ValidationResult {
        let nums = digits.compactMap(\.wholeNumberValue)
        let count = nums.count
        var sum = 0
        for (index, digit) in nums.dropLast().enumerated() {
            // GS1 Mod-10: weights alternate 3,1 from the right; parity depends on digit count
            sum += ((count + index) % 2 == 0) ? digit * 3 : digit
        }
        let check = (10 - (sum % 10)) % 10
        if check == nums[count - 1] {
            return validResult()
        }
        return ValidationResult(
            isValid: false,
            message: String(
                localized: "Invalid check digit (expected \(check))",
                comment: "Validation: check digit mismatch"
            )
        )
    }
}
