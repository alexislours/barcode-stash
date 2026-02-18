import Contacts
import ContactsUI
import EventKit
import EventKitUI
import MessageUI
import SwiftUI

struct BarcodeActionView: View {
    let payload: ParsedPayload
    @State private var showingMessageCompose = false

    private var hasAction: Bool {
        if case .wifi = payload { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailSection

            if hasAction {
                Button {
                    performAction()
                } label: {
                    Label(payload.actionLabel, systemImage: payload.systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("payload-action-button")
            }
        }
        .padding(12)
        .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .sheet(isPresented: $showingMessageCompose) {
            if case let .sms(recipients, body) = payload {
                MessageComposeView(recipients: recipients, body: body)
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var detailSection: some View {
        switch payload {
        case let .url(url):
            Label(url.host ?? url.absoluteString, systemImage: "link")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

        case let .wifi(ssid, password, encryption):
            VStack(alignment: .leading, spacing: 4) {
                Label(ssid, systemImage: "wifi")
                    .font(.subheadline.weight(.medium))
                if let password, !password.isEmpty {
                    HStack(spacing: 4) {
                        Text("Password:")
                            .foregroundStyle(.secondary)
                        Text(password)
                            .textSelection(.enabled)
                    }
                    .font(.caption)
                }
                if let encryption, !encryption.isEmpty, encryption.uppercased() != "NOPASS" {
                    Text("Security: \(encryption)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case let .phone(number):
            Label(number, systemImage: "phone")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case let .email(recipient, subject, _):
            VStack(alignment: .leading, spacing: 2) {
                Label(recipient, systemImage: "envelope")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let subject, !subject.isEmpty {
                    Text(subject)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

        case let .sms(recipients, _):
            Label(recipients.joined(separator: ", "), systemImage: "message")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case let .vCard(raw):
            let summary = Self.vCardSummary(raw)
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    summary.name ?? String(
                        localized: "Contact card detected",
                        comment: "Fallback label when vCard has no name"
                    ),
                    systemImage: "person.crop.circle"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let phone = summary.phone {
                    Label(phone, systemImage: "phone")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if let email = summary.email {
                    Label(email, systemImage: "envelope")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

        case let .calendarEvent(raw):
            let summary = Self.calendarEventSummary(raw)
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    summary.title ?? String(
                        localized: "Calendar event detected",
                        comment: "Fallback label when calendar event has no title"
                    ),
                    systemImage: "calendar"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let date = summary.dateString {
                    Label(date, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if let description = summary.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

        case let .geo(lat, lon, label):
            Label(label ?? String(format: "%.4f, %.4f", lat, lon), systemImage: "map")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func performAction() {
        switch payload {
        case let .url(url):
            UIApplication.shared.open(url)
        case let .phone(number):
            openPhone(number: number)
        case let .email(recipient, subject, body):
            openEmail(recipient: recipient, subject: subject, body: body)
        case .sms:
            if MFMessageComposeViewController.canSendText() {
                showingMessageCompose = true
            }
        case .wifi:
            break
        case let .vCard(raw):
            presentContactCard(vCardString: raw)
        case let .calendarEvent(raw):
            presentCalendarEvent(raw: raw)
        case let .geo(lat, lon, label):
            openMap(latitude: lat, longitude: lon, label: label)
        }
    }

    private func openPhone(number: String) {
        if let url = URL(string: "tel:\(number)") {
            UIApplication.shared.open(url)
        }
    }

    private func openEmail(recipient: String, subject: String?, body: String?) {
        var components = URLComponents(string: "mailto:\(recipient)")
        var items: [URLQueryItem] = []
        if let subject { items.append(URLQueryItem(name: "subject", value: subject)) }
        if let body { items.append(URLQueryItem(name: "body", value: body)) }
        if !items.isEmpty { components?.queryItems = items }
        if let url = components?.url {
            UIApplication.shared.open(url)
        }
    }

    private func openMap(latitude: Double, longitude: Double, label: String?) {
        let query = label ?? "\(latitude),\(longitude)"
        let encoded = query.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? query
        let urlString = "maps:?q=\(encoded)&ll=\(latitude),\(longitude)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func presentContactCard(vCardString: String) {
        guard let data = vCardString.data(using: .utf8),
              let contacts = try? CNContactVCardSerialization.contacts(with: data),
              let contact = contacts.first,
              let windowScene = UIApplication.shared.connectedScenes
              .compactMap({ $0 as? UIWindowScene }).first,
              let root = windowScene.keyWindow?.rootViewController
        else { return }
        let controller = CNContactViewController(forUnknownContact: contact)
        controller.contactStore = CNContactStore()
        controller.allowsEditing = true
        controller.allowsActions = true
        let nav = UINavigationController(rootViewController: controller)
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction { _ in nav.dismiss(animated: true) }
        )
        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(nav, animated: true)
    }

    private static func vCardValue(line: String, property: String) -> String? {
        guard line.hasPrefix(property) else { return nil }
        let after = line[line.index(line.startIndex, offsetBy: property.count)...]
        guard let first = after.first, first == ":" || first == ";" else { return nil }
        guard let colonIdx = line.firstIndex(of: ":") else { return nil }
        let value = String(line[line.index(after: colonIdx)...])
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private struct VCardSummary {
        var name: String?
        var phone: String?
        var email: String?
    }

    private static func vCardSummary(_ raw: String) -> VCardSummary {
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

    private func presentCalendarEvent(raw: String) {
        Task {
            let store = EKEventStore()
            guard try await store.requestFullAccessToEvents() else { return }
            let event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents
            Self.populateEvent(event, from: raw)

            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
                let root = windowScene.keyWindow?.rootViewController
            else { return }

            let editController = EKEventEditViewController()
            editController.eventStore = store
            editController.event = event
            let delegate = CalendarEditDelegate(controller: editController)
            editController.editViewDelegate = delegate
            objc_setAssociatedObject(
                editController, &CalendarEditDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN
            )

            var presenter = root
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(editController, animated: true)
        }
    }

    private static func populateEvent(_ event: EKEvent, from raw: String) {
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

    /// Extracts the value from an iCal property line, handling parameter forms like `DTSTART;TZID=...:value`.
    private static func iCalValue(line: String, property: String) -> String? {
        guard line.hasPrefix(property) else { return nil }
        let after = line[line.index(line.startIndex, offsetBy: property.count)...]
        guard let first = after.first, first == ":" || first == ";" else { return nil }
        guard let colonIdx = line.firstIndex(of: ":") else { return nil }
        let value = String(line[line.index(after: colonIdx)...])
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    /// Extracts the VEVENT block from a VCALENDAR wrapper, or returns the input as-is.
    private static func extractVEventBlock(_ raw: String) -> String {
        let upper = raw.uppercased()
        guard upper.contains("BEGIN:VCALENDAR"),
              let startRange = upper.range(of: "BEGIN:VEVENT"),
              let endRange = upper.range(of: "END:VEVENT")
        else { return raw }
        let start = startRange.lowerBound
        let end = endRange.upperBound
        return String(raw[start ..< end])
    }

    private static func parseICalDate(_ string: String) -> Date? {
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

    private struct CalendarEventSummary {
        var title: String?
        var dateString: String?
        var description: String?
    }

    private static func calendarEventSummary(_ raw: String) -> CalendarEventSummary {
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
