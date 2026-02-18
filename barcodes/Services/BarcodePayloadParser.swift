import Foundation

enum ParsedPayload {
    case url(URL)
    case phone(number: String)
    case email(recipient: String, subject: String?, body: String?)
    case sms(recipients: [String], body: String?)
    case wifi(ssid: String, password: String?, encryption: String?)
    case vCard(String)
    case calendarEvent(String)
    case geo(latitude: Double, longitude: Double, label: String?)

    var actionLabel: String {
        switch self {
        case .url: String(localized: "Open in Safari", comment: "Action label for URL payload")
        case .phone: String(localized: "Call Number", comment: "Action label for phone payload")
        case .email: String(localized: "Send Email", comment: "Action label for email payload")
        case .sms: String(localized: "Send Message", comment: "Action label for SMS payload")
        case .wifi: String(localized: "Join Wi-Fi", comment: "Action label for Wi-Fi payload")
        case .vCard: String(localized: "Add Contact", comment: "Action label for vCard payload")
        case .calendarEvent: String(localized: "Add to Calendar", comment: "Action label for calendar payload")
        case .geo: String(localized: "Open in Maps", comment: "Action label for geo payload")
        }
    }

    var systemImage: String {
        switch self {
        case .url: "safari"
        case .phone: "phone.fill"
        case .email: "envelope.fill"
        case .sms: "message.fill"
        case .wifi: "wifi"
        case .vCard: "person.crop.circle.badge.plus"
        case .calendarEvent: "calendar.badge.plus"
        case .geo: "map.fill"
        }
    }
}

enum BarcodePayloadParser {
    static func parse(rawValue: String, type _: BarcodeType) -> ParsedPayload? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if let wifi = parseWifi(trimmed) { return wifi }

        if trimmed.uppercased().hasPrefix("BEGIN:VCARD") {
            return .vCard(trimmed)
        }

        if trimmed.uppercased().hasPrefix("BEGIN:VEVENT") {
            return .calendarEvent(trimmed)
        }

        if let mailto = parseMailto(trimmed) { return mailto }

        if trimmed.lowercased().hasPrefix("tel:") {
            let number = String(trimmed.dropFirst(4))
            if !number.isEmpty { return .phone(number: number) }
        }

        if let sms = parseSms(trimmed) { return sms }

        if let geo = parseGeo(trimmed) { return geo }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https", url.host != nil {
            return .url(url)
        }

        return nil
    }

    // MARK: - Private Parsers

    private static func parseWifi(_ value: String) -> ParsedPayload? {
        // Format: WIFI:T:<encryption>;S:<ssid>;P:<password>;;
        // Special characters in values are escaped: \; \: \\ \"
        guard value.uppercased().hasPrefix("WIFI:") else { return nil }
        let content = String(value.dropFirst(5))
        var fields: [String: String] = [:]
        for part in splitWifiFields(content) where !part.isEmpty {
            if let colonIndex = part.firstIndex(of: ":") {
                let key = String(part[part.startIndex ..< colonIndex]).uppercased()
                let val = String(part[part.index(after: colonIndex)...])
                fields[key] = val
            }
        }
        guard let ssid = fields["S"], !ssid.isEmpty else { return nil }
        let password = fields["P"]?.isEmpty == true ? nil : fields["P"]
        return .wifi(ssid: ssid, password: password, encryption: fields["T"])
    }

    /// Splits a WIFI QR field string on unescaped semicolons, stripping escape backslashes.
    private static func splitWifiFields(_ content: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var escaped = false
        for char in content {
            if escaped {
                current.append(char)
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == ";" {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            fields.append(current)
        }
        return fields
    }

    private static func parseMailto(_ value: String) -> ParsedPayload? {
        guard value.lowercased().hasPrefix("mailto:") else { return nil }
        let rest = String(value.dropFirst(7))
        let parts = rest.components(separatedBy: "?")
        let recipient = parts[0]
        guard !recipient.isEmpty else { return nil }
        var subject: String?
        var body: String?
        if parts.count > 1 {
            let queryString = parts.dropFirst().joined(separator: "?")
            let params = URLComponents(string: "?\(queryString)")?.queryItems ?? []
            subject = params.first(where: { $0.name == "subject" })?.value
            body = params.first(where: { $0.name == "body" })?.value
        }
        return .email(recipient: recipient, subject: subject, body: body)
    }

    private static func parseSms(_ value: String) -> ParsedPayload? {
        let lower = value.lowercased()
        guard lower.hasPrefix("sms:") || lower.hasPrefix("smsto:") else { return nil }
        let prefix = lower.hasPrefix("smsto:") ? 6 : 4
        let rest = String(value.dropFirst(prefix))
        // Try query-string format first: sms:number?body=message
        let parts = rest.components(separatedBy: "?")
        let recipientPart = parts[0]
        var body: String?
        if parts.count > 1 {
            let queryString = parts.dropFirst().joined(separator: "?")
            let params = URLComponents(string: "?\(queryString)")?.queryItems ?? []
            body = params.first(where: { $0.name == "body" })?.value
        }
        // Fall back to colon-separated format: SMSTO:number:message
        var recipientString = recipientPart
        if body == nil, let colonIndex = recipientPart.firstIndex(of: ":") {
            recipientString = String(recipientPart[recipientPart.startIndex ..< colonIndex])
            let messageStart = recipientPart.index(after: colonIndex)
            if messageStart < recipientPart.endIndex {
                body = String(recipientPart[messageStart...])
            }
        }
        let recipients = recipientString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !recipients.isEmpty else { return nil }
        return .sms(recipients: recipients, body: body)
    }

    private static func parseGeo(_ value: String) -> ParsedPayload? {
        guard value.lowercased().hasPrefix("geo:") else { return nil }
        let rest = String(value.dropFirst(4))
        let parts = rest.components(separatedBy: "?")
        let coords = parts[0].components(separatedBy: ",")
        guard coords.count >= 2,
              let lat = Double(coords[0]),
              let lon = Double(coords[1]) else { return nil }
        var label: String?
        if parts.count > 1 {
            let params = URLComponents(string: "?\(parts[1])")?.queryItems ?? []
            label = params.first(where: { $0.name == "q" })?.value
        }
        return .geo(latitude: lat, longitude: lon, label: label)
    }
}
