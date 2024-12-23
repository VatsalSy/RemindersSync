// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RemindersSync",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "RemindersSync", targets: ["SwiftRemindersCLI"]),
        .executable(name: "ScanVault", targets: ["ScanVaultCLI"]),
        .executable(name: "ExportOtherReminders", targets: ["ExportOtherRemindersCLI"]),
        .library(name: "RemindersSyncCore", targets: ["RemindersSyncCore"])
    ],
    targets: [
        .target(
            name: "RemindersSyncCore",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        ),
        .executableTarget(
            name: "SwiftRemindersCLI",
            dependencies: ["RemindersSyncCore"],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        ),
        .executableTarget(
            name: "ScanVaultCLI",
            dependencies: ["RemindersSyncCore"],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        ),
        .executableTarget(
            name: "ExportOtherRemindersCLI",
            dependencies: ["RemindersSyncCore"],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        )
    ]
)
