// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CaffeinateUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CaffeinateUI", targets: ["CaffeinateUI"]),
        .library(name: "CaffeinateKit", targets: ["CaffeinateKit"])
    ],
    targets: [
        // Pure logic: command building, session lifecycle, persistence.
        // No SwiftUI, so it can be unit tested without a UI host.
        .target(name: "CaffeinateKit"),

        // The SwiftUI application. Assembled into an .app bundle by scripts/build.sh.
        .executableTarget(
            name: "CaffeinateUI",
            dependencies: ["CaffeinateKit"]
        ),

        .testTarget(
            name: "CaffeinateKitTests",
            dependencies: ["CaffeinateKit"]
        )
    ]
)
