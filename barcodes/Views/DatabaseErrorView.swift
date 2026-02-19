import SwiftUI

struct DatabaseErrorView: View {
    let errorMessage: String?
    let onRetry: () -> Void
    let onReset: () -> Void

    @State private var showResetConfirmation = false

    var body: some View {
        ContentUnavailableView {
            Label("Database Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(
                """
                The app database could not be loaded. \
                This can happen after an update or if the database was corrupted.
                """
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        } actions: {
            VStack(spacing: 12) {
                Button("Retry", action: onRetry)
                Button("Reset Database", role: .destructive) {
                    showResetConfirmation = true
                }
            }
        }
        .confirmationDialog(
            "Reset Database?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Data & Reset", role: .destructive, action: onReset)
        } message: {
            Text(
                "This will delete all locally stored barcodes. Data synced to iCloud may be recoverable after reset."
            )
        }
    }
}
