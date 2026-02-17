import SwiftUI

extension URL: @retroactive Identifiable {
    public var id: String {
        absoluteString
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
