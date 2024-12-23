import Foundation
import EventKit
import RemindersSyncCore

@main
struct RemindersSyncCLI {
    static func main() async {
        let options = CLIOptions.parse()
        let eventStore = EKEventStore()

        do {
            try await requestRemindersAccess(eventStore: eventStore)

            // 1. Handle completed tasks in both directions
            print("Syncing completed tasks...")
            try await syncCompletedReminders(eventStore: eventStore, vaultPath: options.vaultPath)

            // 2. Scan vault and sync tasks to Apple Reminders
            print("Scanning vault and syncing tasks...")
            let mappingPath = (options.vaultPath as NSString).appendingPathComponent("._RemindersMapping.json")
            if !FileManager.default.fileExists(atPath: mappingPath) {
                print("No mapping file found. Cleaning up existing task IDs...")
                try cleanupTaskIds(in: options.vaultPath)
            }
            
            let tasks = try findIncompleteTasks(in: options.vaultPath)
            try await syncTasksFromVault(tasks: tasks, eventStore: eventStore)

            print("Sync completed successfully!")
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
