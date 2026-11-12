import Foundation

/// Bounds for the floating edge HUD. Pure logic so the placement can be
/// regression-tested without UIKit / SwiftUI.
enum SideHUDPlacement {
    static let fullWidth: Double = 86
    static let collapsedWidth: Double = 26

    static func clamp(_ proposed: Double,
                      viewportHeight: Double,
                      hudHeight: Double,
                      topReserved: Double = 100,
                      bottomReserved: Double = 155) -> Double {
        guard viewportHeight > 0, hudHeight > 0 else { return 0 }
        let center = viewportHeight / 2
        let lower = topReserved + hudHeight / 2 - center
        let upper = viewportHeight - bottomReserved - hudHeight / 2 - center
        guard lower <= upper else { return 0 }
        return max(lower, min(proposed, upper))
    }
}
