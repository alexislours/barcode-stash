import Foundation
import Testing
@testable import barcodes

// All tests use .qr since `parse` ignores the type parameter.
private let type = BarcodeType.qr

// MARK: - URL

@Suite("URL Parsing")
struct URLParsingTests {
    @Test("Parses HTTPS URLs", arguments: [
        "https://example.com",
        "https://example.com/path?q=1",
        "https://sub.domain.co.uk/page",
    ])
    func parsesHTTPS(input: String) {
        guard case .url(let url) = BarcodePayloadParser.parse(rawValue: input, type: type) else {
            Issue.record("Expected .url, got something else")
            return
        }
        #expect(url.absoluteString == input)
    }

    @Test func parsesHTTP() {
        guard case .url(let url) = BarcodePayloadParser.parse(rawValue: "http://example.com", type: type) else {
            Issue.record("Expected .url")
            return
        }
        #expect(url.absoluteString == "http://example.com")
    }

    @Test("Rejects non-HTTP schemes", arguments: [
        "ftp://example.com",
        "file:///tmp/test",
        "custom://app",
    ])
    func rejectsNonHTTP(input: String) {
        #expect(BarcodePayloadParser.parse(rawValue: input, type: type) == nil)
    }

    @Test func rejectsPlainText() {
        #expect(BarcodePayloadParser.parse(rawValue: "just some text", type: type) == nil)
    }

    @Test func rejectsURLWithoutHost() {
        #expect(BarcodePayloadParser.parse(rawValue: "https://", type: type) == nil)
    }
}

// MARK: - Phone

@Suite("Phone Parsing")
struct PhoneParsingTests {
    @Test func parsesPhoneNumber() {
        guard case .phone(let number) = BarcodePayloadParser.parse(rawValue: "tel:+15551234567", type: type) else {
            Issue.record("Expected .phone")
            return
        }
        #expect(number == "+15551234567")
    }

    @Test func caseInsensitivePrefix() {
        guard case .phone = BarcodePayloadParser.parse(rawValue: "TEL:12345", type: type) else {
            Issue.record("Expected .phone")
            return
        }
    }

    @Test func rejectsEmptyNumber() {
        #expect(BarcodePayloadParser.parse(rawValue: "tel:", type: type) == nil)
    }

    @Test func preservesFormattingInNumber() {
        guard case .phone(let number) =
            BarcodePayloadParser.parse(rawValue: "tel:+1 (555) 123-4567", type: type)
        else {
            Issue.record("Expected .phone")
            return
        }
        #expect(number == "+1 (555) 123-4567")
    }
}

// MARK: - Email (mailto)

@Suite("Email Parsing")
struct EmailParsingTests {
    @Test func parsesSimpleMailto() {
        guard case .email(let recipient, let subject, let body) =
            BarcodePayloadParser.parse(rawValue: "mailto:user@example.com", type: type)
        else {
            Issue.record("Expected .email")
            return
        }
        #expect(recipient == "user@example.com")
        #expect(subject == nil)
        #expect(body == nil)
    }

    @Test func parsesMailtoWithSubjectAndBody() {
        let input = "mailto:user@example.com?subject=Hello&body=World"
        guard case .email(let recipient, let subject, let body) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .email")
            return
        }
        #expect(recipient == "user@example.com")
        #expect(subject == "Hello")
        #expect(body == "World")
    }

    @Test func caseInsensitivePrefix() {
        guard case .email = BarcodePayloadParser.parse(rawValue: "MAILTO:a@b.com", type: type) else {
            Issue.record("Expected .email")
            return
        }
    }

    @Test func rejectsEmptyRecipient() {
        #expect(BarcodePayloadParser.parse(rawValue: "mailto:", type: type) == nil)
    }

    @Test func parsesURLEncodedSubject() {
        let input = "mailto:user@example.com?subject=Hello%20World"
        guard case .email(_, let subject, _) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .email")
            return
        }
        #expect(subject == "Hello World")
    }

    @Test func handlesQuestionMarkInSubject() {
        let input = "mailto:user@example.com?subject=Really?&body=Yes"
        guard case .email(let recipient, let subject, let body) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .email")
            return
        }
        #expect(recipient == "user@example.com")
        #expect(subject == "Really?")
        #expect(body == "Yes")
    }
}

// MARK: - SMS

@Suite("SMS Parsing")
struct SMSParsingTests {
    @Test func parsesSms() {
        guard case .sms(let recipients, let body) =
            BarcodePayloadParser.parse(rawValue: "sms:+15551234567", type: type)
        else {
            Issue.record("Expected .sms")
            return
        }
        #expect(recipients == ["+15551234567"])
        #expect(body == nil)
    }

    @Test func parsesSmsWithBody() {
        let input = "sms:+15551234567?body=Hello"
        guard case .sms(let recipients, let body) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .sms")
            return
        }
        #expect(recipients == ["+15551234567"])
        #expect(body == "Hello")
    }

    @Test func parsesSmsto() {
        guard case .sms(let recipients, _) =
            BarcodePayloadParser.parse(rawValue: "smsto:+15551234567", type: type)
        else {
            Issue.record("Expected .sms")
            return
        }
        #expect(recipients == ["+15551234567"])
    }

    @Test func parsesMultipleRecipients() {
        let input = "sms:+15551234567,+15559876543?body=Hey"
        guard case .sms(let recipients, let body) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .sms")
            return
        }
        #expect(recipients == ["+15551234567", "+15559876543"])
        #expect(body == "Hey")
    }

    @Test func caseInsensitivePrefix() {
        guard case .sms = BarcodePayloadParser.parse(rawValue: "SMS:12345", type: type) else {
            Issue.record("Expected .sms")
            return
        }
    }

    @Test func rejectsEmptyRecipient() {
        #expect(BarcodePayloadParser.parse(rawValue: "sms:", type: type) == nil)
        #expect(BarcodePayloadParser.parse(rawValue: "smsto:", type: type) == nil)
    }

    @Test func parsesURLEncodedBody() {
        let input = "sms:+15551234567?body=Hello%20World"
        guard case .sms(_, let body) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .sms")
            return
        }
        #expect(body == "Hello World")
    }

    @Test func handlesQuestionMarkInBody() {
        let input = "sms:+15551234567?body=Are you there?"
        guard case .sms(let recipients, let body) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .sms")
            return
        }
        #expect(recipients == ["+15551234567"])
        #expect(body == "Are you there?")
    }
}

// MARK: - Wi-Fi

@Suite("Wi-Fi Parsing")
struct WiFiParsingTests {
    @Test func parsesFullWifi() {
        let input = "WIFI:T:WPA;S:MyNetwork;P:password123;;"
        guard case .wifi(let ssid, let password, let encryption) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .wifi")
            return
        }
        #expect(ssid == "MyNetwork")
        #expect(password == "password123")
        #expect(encryption == "WPA")
    }

    @Test func parsesWifiWithoutPassword() {
        let input = "WIFI:S:OpenNetwork;T:nopass;;"
        guard case .wifi(let ssid, let password, _) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .wifi")
            return
        }
        #expect(ssid == "OpenNetwork")
        #expect(password == nil)
    }

    @Test func caseInsensitivePrefix() {
        guard case .wifi = BarcodePayloadParser.parse(rawValue: "wifi:S:Net;;", type: type) else {
            Issue.record("Expected .wifi")
            return
        }
    }

    @Test func rejectsEmptySSID() {
        #expect(BarcodePayloadParser.parse(rawValue: "WIFI:S:;P:pass;;", type: type) == nil)
    }

    @Test func rejectsMissingSSID() {
        #expect(BarcodePayloadParser.parse(rawValue: "WIFI:T:WPA;P:pass;;", type: type) == nil)
    }

    @Test func treatsEmptyPasswordAsNil() {
        guard case .wifi(_, let password, _) =
            BarcodePayloadParser.parse(rawValue: "WIFI:S:MyNet;P:;;", type: type)
        else {
            Issue.record("Expected .wifi")
            return
        }
        #expect(password == nil)
    }

    @Test func handlesEscapedSemicolonInPassword() {
        let input = "WIFI:T:WPA;S:MyNet;P:pass\\;word;;"
        guard case .wifi(let ssid, let password, let encryption) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .wifi")
            return
        }
        #expect(ssid == "MyNet")
        #expect(password == "pass;word")
        #expect(encryption == "WPA")
    }

    @Test func handlesEscapedColonInPassword() {
        let input = "WIFI:T:WPA;S:MyNet;P:pass\\:word;;"
        guard case .wifi(_, let password, _) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .wifi")
            return
        }
        #expect(password == "pass:word")
    }

    @Test func handlesEscapedBackslashInPassword() {
        let input = "WIFI:T:WPA;S:MyNet;P:pass\\\\word;;"
        guard case .wifi(_, let password, _) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .wifi")
            return
        }
        #expect(password == "pass\\word")
    }
}

// MARK: - vCard

@Suite("vCard Parsing")
struct VCardParsingTests {
    @Test func parsesVCard() {
        let input = "BEGIN:VCARD\nVERSION:3.0\nFN:John Doe\nEND:VCARD"
        guard case .vCard(let raw) = BarcodePayloadParser.parse(rawValue: input, type: type) else {
            Issue.record("Expected .vCard")
            return
        }
        #expect(raw == input)
    }

    @Test func caseInsensitivePrefix() {
        let input = "begin:vcard\nVERSION:3.0\nEND:VCARD"
        guard case .vCard = BarcodePayloadParser.parse(rawValue: input, type: type) else {
            Issue.record("Expected .vCard")
            return
        }
    }

    @Test func parsesIncompleteVCard() {
        let input = "BEGIN:VCARD\nVERSION:3.0\nFN:John Doe"
        guard case .vCard(let raw) = BarcodePayloadParser.parse(rawValue: input, type: type) else {
            Issue.record("Expected .vCard")
            return
        }
        #expect(raw == input)
    }
}

// MARK: - Calendar Event

@Suite("Calendar Event Parsing")
struct CalendarEventParsingTests {
    @Test func parsesVEvent() {
        let input = "BEGIN:VEVENT\nSUMMARY:Meeting\nEND:VEVENT"
        guard case .calendarEvent(let raw) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .calendarEvent")
            return
        }
        #expect(raw == input)
    }

    @Test func caseInsensitivePrefix() {
        let input = "begin:vevent\nSUMMARY:Test\nEND:VEVENT"
        guard case .calendarEvent = BarcodePayloadParser.parse(rawValue: input, type: type) else {
            Issue.record("Expected .calendarEvent")
            return
        }
    }

    @Test func parsesIncompleteVEvent() {
        let input = "BEGIN:VEVENT\nSUMMARY:Meeting"
        guard case .calendarEvent(let raw) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .calendarEvent")
            return
        }
        #expect(raw == input)
    }
}

// MARK: - Geo

@Suite("Geo Parsing")
struct GeoParsingTests {
    @Test func parsesCoordinates() {
        guard case .geo(let lat, let lon, let label) =
            BarcodePayloadParser.parse(rawValue: "geo:48.8566,2.3522", type: type)
        else {
            Issue.record("Expected .geo")
            return
        }
        #expect(lat == 48.8566)
        #expect(lon == 2.3522)
        #expect(label == nil)
    }

    @Test func parsesCoordinatesWithLabel() {
        let input = "geo:48.8566,2.3522?q=Eiffel%20Tower"
        guard case .geo(let lat, let lon, let label) =
            BarcodePayloadParser.parse(rawValue: input, type: type)
        else {
            Issue.record("Expected .geo")
            return
        }
        #expect(lat == 48.8566)
        #expect(lon == 2.3522)
        #expect(label == "Eiffel Tower")
    }

    @Test func parsesNegativeCoordinates() {
        guard case .geo(let lat, let lon, _) =
            BarcodePayloadParser.parse(rawValue: "geo:-33.8688,151.2093", type: type)
        else {
            Issue.record("Expected .geo")
            return
        }
        #expect(lat == -33.8688)
        #expect(lon == 151.2093)
    }

    @Test func rejectsInvalidCoordinates() {
        #expect(BarcodePayloadParser.parse(rawValue: "geo:abc,def", type: type) == nil)
    }

    @Test func rejectsSingleCoordinate() {
        #expect(BarcodePayloadParser.parse(rawValue: "geo:48.8566", type: type) == nil)
    }

    @Test func parsesCoordinatesWithAltitude() {
        guard case .geo(let lat, let lon, _) =
            BarcodePayloadParser.parse(rawValue: "geo:48.8566,2.3522,100", type: type)
        else {
            Issue.record("Expected .geo")
            return
        }
        #expect(lat == 48.8566)
        #expect(lon == 2.3522)
    }
}

// MARK: - Whitespace Handling

@Suite("Whitespace Handling")
struct WhitespaceTests {
    @Test func trimsLeadingAndTrailingWhitespace() {
        guard case .url = BarcodePayloadParser.parse(rawValue: "  https://example.com  ", type: type) else {
            Issue.record("Expected .url after trimming")
            return
        }
    }

    @Test func trimsNewlines() {
        guard case .phone = BarcodePayloadParser.parse(rawValue: "\ntel:12345\n", type: type) else {
            Issue.record("Expected .phone after trimming")
            return
        }
    }
}

// MARK: - Priority / Ambiguity

@Suite("Parse Priority")
struct ParsePriorityTests {
    @Test("Wi-Fi takes priority over URL")
    func wifiBeforeURL() {
        // Ensure WIFI: prefix is matched before falling through to URL
        guard case .wifi = BarcodePayloadParser.parse(rawValue: "WIFI:S:Test;;", type: type) else {
            Issue.record("Expected .wifi, not .url")
            return
        }
    }

    @Test("mailto takes priority over URL")
    func mailtoBeforeURL() {
        guard case .email = BarcodePayloadParser.parse(rawValue: "mailto:a@b.com", type: type) else {
            Issue.record("Expected .email")
            return
        }
    }

    @Test func returnsNilForUnrecognized() {
        #expect(BarcodePayloadParser.parse(rawValue: "random string 123", type: type) == nil)
        #expect(BarcodePayloadParser.parse(rawValue: "", type: type) == nil)
    }
}

// MARK: - Action Labels & Icons

@Suite("Payload Metadata")
struct PayloadMetadataTests {
    @Test("Every case has a non-empty action label and icon")
    func allCasesHaveMetadata() {
        let payloads: [ParsedPayload] = [
            .url(URL(string: "https://example.com")!),
            .phone(number: "123"),
            .email(recipient: "a@b.com", subject: nil, body: nil),
            .sms(recipients: ["123"], body: nil),
            .wifi(ssid: "Net", password: nil, encryption: nil),
            .vCard("BEGIN:VCARD\nEND:VCARD"),
            .calendarEvent("BEGIN:VEVENT\nEND:VEVENT"),
            .geo(latitude: 0, longitude: 0, label: nil),
        ]
        for payload in payloads {
            #expect(!payload.actionLabel.isEmpty)
            #expect(!payload.systemImage.isEmpty)
        }
    }
}
