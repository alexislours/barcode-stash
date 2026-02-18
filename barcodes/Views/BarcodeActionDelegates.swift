import EventKit
import EventKitUI
import MessageUI
import SwiftUI

struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: MFMessageComposeViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss)
    }

    nonisolated class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let dismiss: DismissAction

        init(dismiss: DismissAction) {
            self.dismiss = dismiss
        }

        func messageComposeViewController(
            _: MFMessageComposeViewController,
            didFinishWith _: MessageComposeResult
        ) {
            Task { @MainActor in
                dismiss()
            }
        }
    }
}

nonisolated class CalendarEditDelegate: NSObject, EKEventEditViewDelegate {
    nonisolated(unsafe) static var key: UInt8 = 0
    private let controller: EKEventEditViewController

    init(controller: EKEventEditViewController) {
        self.controller = controller
    }

    func eventEditViewController(
        _: EKEventEditViewController,
        didCompleteWith _: EKEventEditViewAction
    ) {
        Task { @MainActor in
            controller.dismiss(animated: true)
        }
    }
}
