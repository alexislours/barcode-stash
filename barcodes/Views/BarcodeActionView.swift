import Contacts
import EventKit
import NetworkExtension
import SwiftUI

struct BarcodeActionView: View {
    let payload: ParsedPayload
    @State private var wifiStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailSection

            Button {
                performAction()
            } label: {
                Label(payload.actionLabel, systemImage: payload.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("payload-action-button")

            if let wifiStatus {
                Text(wifiStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
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

        case let .sms(recipient, _):
            Label(recipient, systemImage: "message")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .vCard:
            Label("Contact card detected", systemImage: "person.crop.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .calendarEvent:
            Label("Calendar event detected", systemImage: "calendar")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
        case let .sms(recipient, body):
            openSMS(recipient: recipient, body: body)
        case let .wifi(ssid, password, encryption):
            joinWifi(ssid: ssid, password: password, encryption: encryption)
        case let .vCard(raw):
            addContact(vCardString: raw)
        case let .calendarEvent(raw):
            addCalendarEvent(raw: raw)
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

    private func openSMS(recipient: String, body: String?) {
        var urlString = "sms:\(recipient)"
        if let body {
            let encoded = body.addingPercentEncoding(
                withAllowedCharacters: .urlQueryAllowed
            ) ?? body
            urlString += "&body=\(encoded)"
        }
        if let url = URL(string: urlString) {
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

    private func joinWifi(ssid: String, password: String?, encryption: String?) {
        let isWEP = encryption?.uppercased() == "WEP"
        let config = NEHotspotConfiguration(
            ssid: ssid, passphrase: password ?? "", isWEP: isWEP
        )
        Task {
            do {
                try await NEHotspotConfigurationManager.shared.apply(config)
                wifiStatus = String(
                    localized: "Connected to \(ssid)",
                    comment: "Wi-Fi connection success message showing network name"
                )
            } catch {
                wifiStatus = error.localizedDescription
            }
        }
    }

    private func addContact(vCardString: String) {
        guard let data = vCardString.data(using: .utf8),
              let contacts = try? CNContactVCardSerialization.contacts(with: data),
              let contact = contacts.first
        else {
            return
        }
        Task {
            let store = CNContactStore()
            guard try await store.requestAccess(for: .contacts) else { return }
            let saveRequest = CNSaveRequest()
            guard let mutableContact = contact.mutableCopy() as? CNMutableContact else { return }
            saveRequest.add(mutableContact, toContainerWithIdentifier: nil)
            try? store.execute(saveRequest)
        }
    }

    private func addCalendarEvent(raw: String) {
        Task {
            let store = EKEventStore()
            guard try await store.requestFullAccessToEvents() else { return }
            let event = EKEvent(eventStore: store)
            event.calendar = store.defaultCalendarForNewEvents

            let lines = raw.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("SUMMARY:") {
                    event.title = String(line.dropFirst(8))
                } else if line.hasPrefix("DTSTART:") {
                    event.startDate = parseICalDate(String(line.dropFirst(8)))
                } else if line.hasPrefix("DTEND:") {
                    event.endDate = parseICalDate(String(line.dropFirst(6)))
                } else if line.hasPrefix("LOCATION:") {
                    event.location = String(line.dropFirst(9))
                }
            }

            if event.title == nil { event.title = "Event" }
            if event.startDate == nil { event.startDate = Date() }
            if event.endDate == nil { event.endDate = (event.startDate ?? Date()).addingTimeInterval(3600) }

            try? store.save(event, span: .thisEvent)
        }
    }

    private func parseICalDate(_ string: String) -> Date? {
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
}
