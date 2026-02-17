import SwiftUI
import UIKit

/// Wraps `withAnimation`, passing `nil` (no animation) when Reduce Motion is enabled.
func withAccessibleAnimation<Result>(
    _ animation: Animation? = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(UIAccessibility.isReduceMotionEnabled ? nil : animation) {
        try body()
    }
}
