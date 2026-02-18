import Contacts
import ContactsUI
import EventKit
import EventKitUI
import MessageUI
import SwiftUI

struct BarcodeActionView: View {
    let payload: ParsedPayload
    @State private var showingMessageCompose = false
    @State private var showCopiedConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: tinted rounded-square icon + title/subtitle
            HStack(spacing: 14) {
                Image(systemName: payload.systemImage)
                    .font(.title3)
                    .foregroundStyle(payload.tintColor)
                    .frame(width: 40, height: 40)
                    .background(payload.tintColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.title)
                        .font(.headline)
                    subtitleText
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            // Extra detail rows for complex payloads
            extraDetailSection

            // Action button(s)
            actionButtons
        }
        .padding(16)
        .background(.fill.quinary, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .sheet(isPresented: $showingMessageCompose) {
            if case let .sms(recipients, body) = payload {
                MessageComposeView(recipients: recipients, body: body)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Header Subtitle

    @ViewBuilder
    private var subtitleText: some View {
        switch payload {
        case let .url(url):
            Text(url.host ?? url.absoluteString)
        case let .phone(number):
            Text(number)
        case let .email(recipient, _, _):
            Text(recipient)
        case let .sms(recipients, _):
            Text(recipients.joined(separator: ", "))
        case let .wifi(ssid, _, _):
            Text(ssid)
        case let .vCard(raw):
            let summary = Self.vCardSummary(raw)
            Text(
                summary.name ?? String(
                    localized: "Contact card detected",
                    comment: "Fallback label when vCard has no name"
                )
            )
        case let .calendarEvent(raw):
            let summary = Self.calendarEventSummary(raw)
            Text(
                summary.title ?? String(
                    localized: "Calendar event detected",
                    comment: "Fallback label when calendar event has no title"
                )
            )
        case let .geo(lat, lon, label):
            Text(label ?? String(format: "%.4f, %.4f", lat, lon))
        }
    }

    // MARK: - Extra Detail Rows (complex payloads only)

    @ViewBuilder
    private var extraDetailSection: some View {
        switch payload {
        case let .vCard(raw):
            let summary = Self.vCardSummary(raw)
            if summary.phone != nil || summary.email != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let phone = summary.phone {
                        Label(phone, systemImage: "phone")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let email = summary.email {
                        Label(email, systemImage: "envelope")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        case let .calendarEvent(raw):
            let summary = Self.calendarEventSummary(raw)
            if summary.dateString != nil || summary.description != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if let date = summary.dateString {
                        Label(date, systemImage: "clock")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let description = summary.description {
                        Label(description, systemImage: "doc.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }

        case let .wifi(_, password, encryption):
            let hasPassword = password.map { !$0.isEmpty } ?? false
            let hasEncryption = encryption.map { !$0.isEmpty && $0.uppercased() != "NOPASS" } ?? false
            if hasPassword || hasEncryption {
                VStack(alignment: .leading, spacing: 6) {
                    if let password, !password.isEmpty {
                        Label {
                            Text(password)
                                .textSelection(.enabled)
                        } icon: {
                            Image(systemName: "key")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    if let encryption, !encryption.isEmpty, encryption.uppercased() != "NOPASS" {
                        Label(encryption, systemImage: "lock.shield")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

        case let .email(_, subject, _):
            if let subject, !subject.isEmpty {
                Label(subject, systemImage: "text.alignleft")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

        case let .sms(_, body):
            if let body, !body.isEmpty {
                Label(body, systemImage: "text.bubble")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

        case let .geo(lat, lon, _):
            Label(String(format: "%.4f, %.4f", lat, lon), systemImage: "location")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        default:
            EmptyView()
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch payload {
        case let .wifi(_, password, _):
            if let password, !password.isEmpty {
                Button {
                    UIPasteboard.general.string = password
                    showCopiedConfirmation = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showCopiedConfirmation = false
                    }
                } label: {
                    Label(
                        showCopiedConfirmation
                            ? String(localized: "Copied!", comment: "WiFi password copied confirmation")
                            : String(localized: "Copy Password", comment: "Action to copy WiFi password"),
                        systemImage: showCopiedConfirmation ? "checkmark" : "doc.on.doc"
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(payload.tintColor)
                .accessibilityIdentifier("payload-action-button")
            }

        default:
            Button {
                performAction()
            } label: {
                Label(payload.actionLabel, systemImage: payload.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(payload.tintColor)
            .accessibilityIdentifier("payload-action-button")
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
}
