// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RemindersSync",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SwiftRemindersCLI", targets: ["SwiftRemindersCLI"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SwiftRemindersCLI",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        )
    ]
)
