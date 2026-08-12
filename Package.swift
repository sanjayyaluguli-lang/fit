// swift-tools-version: 5.9
import PackageDescription

// AutonomyKit is deliberately platform-free: no HealthKit, no SwiftUI, no network.
// Everything that touches Apple frameworks lives in App/, so the domain logic
// stays testable from the command line (including on Linux CI).
let package = Package(
    name: "AutonomyKit",
    platforms: [.iOS(.v17), .macOS(.v14), .watchOS(.v10)],
    products: [
        .library(name: "AutonomyKit", targets: ["AutonomyKit"])
    ],
    targets: [
        .target(name: "AutonomyKit"),
        .testTarget(name: "AutonomyKitTests", dependencies: ["AutonomyKit"])
    ]
)
