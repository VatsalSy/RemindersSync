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
        .executable(name: "ReSyncReminders", targets: ["ReSyncRemindersCLI"]),
        .executable(name: "CleanUp", targets: ["CleanUpCLI"]),
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
        ),
        .executableTarget(
            name: "ReSyncRemindersCLI",
            dependencies: ["RemindersSyncCore"],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        ),
        .executableTarget(
            name: "CleanUpCLI",
            dependencies: ["RemindersSyncCore"],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        ),
        .testTarget(
            name: "RemindersSyncCoreTests",
            dependencies: ["RemindersSyncCore"]
        )
    ]
)
