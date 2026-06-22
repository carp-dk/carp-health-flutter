// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "health",
    platforms: [
        .iOS("14.0")
    ],
    products: [
        .library(name: "health", targets: ["health"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "health",
            dependencies: [],
            // HealthKit is linked explicitly. Under CocoaPods it was linked
            // implicitly through `import HealthKit`; SPM needs it declared.
            linkerSettings: [
                .linkedFramework("HealthKit")
            ]
        )
    ]
)
