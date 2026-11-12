import Foundation

func assertNear(_ actual: Double, _ expected: Double, _ label: String) {
    assert(abs(actual - expected) < 0.001, "\(label): \(actual) != \(expected)")
}

assert(SideHUDPlacement.fullWidth <= 90)
assert(SideHUDPlacement.collapsedWidth <= 28)
let height = 844.0
let hudHeight = 186.0
let lower = 100.0 + hudHeight / 2.0 - height / 2.0
let upper = height - 155.0 - hudHeight / 2.0 - height / 2.0
assertNear(SideHUDPlacement.clamp(-10000, viewportHeight: height, hudHeight: hudHeight), lower, "top boundary")
assertNear(SideHUDPlacement.clamp(10000, viewportHeight: height, hudHeight: hudHeight), upper, "bottom boundary")
assertNear(SideHUDPlacement.clamp(12, viewportHeight: height, hudHeight: hudHeight), 12, "drag within bounds")
assertNear(SideHUDPlacement.clamp(300, viewportHeight: 260, hudHeight: 190), 0, "small viewport")
assertNear(SideHUDPlacement.clamp(-20, viewportHeight: 0, hudHeight: 190), 0, "empty viewport")
print("SideHUDPlacement: 5 geometry scenarios passed.")
