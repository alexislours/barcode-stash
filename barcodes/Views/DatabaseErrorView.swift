import SwiftUI

struct DatabaseErrorView: View {
    let errorMessage: String?
    let onRetry: () -> Void
    let onReset: () -> Void

    @State private var showResetConfirmation = false

    var body: some View {
        ContentUnavailableView {
            Label(
                String(localized: "Database Error", comment: "Database error: title shown when SwiftData fails to load"),
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(
                String(localized: """
                The app database could not be loaded. \
                This can happen after an update or if the database was corrupted.
                """, comment: "Database error: explanation of why the database failed")
            )
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        } actions: {
            VStack(spacing: 12) {
                Button(
                    String(localized: "Retry", comment: "Database error: retry loading the database"),
                    action: onRetry
                )
                Button(
                    String(localized: "Reset Database", comment: "Database error: destructive button to recreate database"),
                    role: .destructive
                ) {
                    showResetConfirmation = true
                }
            }
        }
        .confirmationDialog(
            String(localized: "Reset Database?", comment: "Database error: confirmation dialog title"),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(
                String(localized: "Delete All Data & Reset", comment: "Database error: confirm destructive reset button"),
                role: .destructive,
                action: onReset
            )
        } message: {
            Text(
                String(
                    localized: "This will delete all locally stored barcodes. Data synced to iCloud may be recoverable after reset.",
                    comment: "Database error: confirmation dialog explaining consequences of reset"
                )
            )
        }
    }
}

#Preview("With error message") {
    DatabaseErrorView(
        errorMessage: "The model configuration is incompatible with the existing store.",
        onRetry: {},
        onReset: {}
    )
}

#Preview("Without error message") {
    DatabaseErrorView(
        errorMessage: nil,
        onRetry: {},
        onReset: {}
    )
}
