import Foundation
import SwiftData
import SwiftUI

@Model
final class BarcodeTag {
    var name: String = ""
    var colorName: String = ""
    var order: Int = 0

    var color: Color {
        TagPalette.color(for: colorName)
    }

    init(name: String, colorName: String, order: Int = 0) {
        self.name = name
        self.colorName = colorName
        self.order = order
    }
}

enum TagPalette {
    nonisolated static func color(for name: String) -> Color {
        let colorMap: [String: Color] = [
            "red": .red,
            "orange": .orange,
            "yellow": .yellow,
            "green": .green,
            "mint": .mint,
            "teal": .teal,
            "blue": .blue,
            "indigo": .indigo,
            "purple": .purple,
            "pink": .pink,
            "brown": .brown,
            "gray": .gray,
        ]
        return colorMap[name] ?? .gray
    }

    static let curated: [(name: String, label: String)] = [
        ("red", "Red"),
        ("orange", "Orange"),
        ("yellow", "Yellow"),
        ("green", "Green"),
        ("mint", "Mint"),
        ("teal", "Teal"),
        ("blue", "Blue"),
        ("indigo", "Indigo"),
        ("purple", "Purple"),
        ("pink", "Pink"),
        ("brown", "Brown"),
        ("gray", "Gray"),
    ]
}

extension [BarcodeTag] {
    func resolveColor(for tagName: String) -> Color? {
        first { $0.name == tagName }?.color
    }
}
