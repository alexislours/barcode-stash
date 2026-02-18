import EventKit

// MARK: - vCard & iCal Parsing Helpers

extension BarcodeActionView {
    struct VCardSummary {
        var name: String?
        var phone: String?
        var email: String?
    }

    static func vCardValue(line: String, property: String) -> String? {
        guard line.hasPrefix(property) else { return nil }
        let after = line[line.index(line.startIndex, offsetBy: property.count)...]
        guard let first = after.first, first == ":" || first == ";" else { return nil }
        guard let colonIdx = line.firstIndex(of: ":") else { return nil }
        let value = String(line[line.index(after: colonIdx)...])
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    static func vCardSummary(_ raw: String) -> VCardSummary {
        var result = VCardSummary()
        for line in raw.components(separatedBy: .newlines) {
            if result.name == nil, let value = vCardValue(line: line, property: "FN") {
                result.name = value
            } else if result.phone == nil, let value = vCardValue(line: line, property: "TEL") {
                result.phone = value
            } else if result.email == nil, let value = vCardValue(line: line, property: "EMAIL") {
                result.email = value
            }
        }
        return result
    }

    struct CalendarEventSummary {
        var title: String?
        var dateString: String?
        var description: String?
    }

    /// Extracts the value from an iCal property line, handling parameter forms like `DTSTART;TZID=...:value`.
    static func iCalValue(line: String, property: String) -> String? {
        guard line.hasPrefix(property) else { return nil }
        let after = line[line.index(line.startIndex, offsetBy: property.count)...]
        guard let first = after.first, first == ":" || first == ";" else { return nil }
        guard let colonIdx = line.firstIndex(of: ":") else { return nil }
        let value = String(line[line.index(after: colonIdx)...])
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// Extracts the VEVENT block from a VCALENDAR wrapper, or returns the input as-is.
    static func extractVEventBlock(_ raw: String) -> String {
        let upper = raw.uppercased()
        guard upper.contains("BEGIN:VCALENDAR"),
              let startRange = upper.range(of: "BEGIN:VEVENT"),
              let endRange = upper.range(of: "END:VEVENT")
        else { return raw }
        let start = startRange.lowerBound
        let end = endRange.upperBound
        return String(raw[start ..< end])
    }

    static func parseICalDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // Try basic format: 20240101T120000Z
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let date = formatter.date(from: string) { return date }
        // Try without Z
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = .current
        if let date = formatter.date(from: string) { return date }
        // Try date only
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: string)
    }

    static func populateEvent(_ event: EKEvent, from raw: String) {
        let eventBlock = extractVEventBlock(raw)
        for line in eventBlock.components(separatedBy: .newlines) {
            if let value = iCalValue(line: line, property: "SUMMARY") {
                event.title = value
            } else if let value = iCalValue(line: line, property: "DTSTART") {
                event.startDate = parseICalDate(value)
            } else if let value = iCalValue(line: line, property: "DTEND") {
                event.endDate = parseICalDate(value)
            } else if let value = iCalValue(line: line, property: "LOCATION") {
                event.location = value
            } else if let value = iCalValue(line: line, property: "DESCRIPTION") {
                event.notes = value
            }
        }
        if event.title == nil { event.title = "Event" }
        if event.startDate == nil { event.startDate = Date() }
        if event.endDate == nil {
            event.endDate = (event.startDate ?? Date()).addingTimeInterval(3600)
        }
    }

    static func calendarEventSummary(_ raw: String) -> CalendarEventSummary {
        var result = CalendarEventSummary()
        let eventBlock = extractVEventBlock(raw)
        for line in eventBlock.components(separatedBy: .newlines) {
            if result.title == nil, let value = iCalValue(line: line, property: "SUMMARY") {
                result.title = value
            } else if result.dateString == nil, let value = iCalValue(line: line, property: "DTSTART") {
                if let date = parseICalDate(value) {
                    result.dateString = date.formatted(date: .abbreviated, time: .shortened)
                }
            } else if result.description == nil, let value = iCalValue(line: line, property: "DESCRIPTION") {
                result.description = value
            }
        }
        return result
    }
}
