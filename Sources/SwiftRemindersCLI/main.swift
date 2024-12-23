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

            // 3. Export other reminders to markdown
            print("Exporting other reminders...")
            let vaultName = URL(fileURLWithPath: options.vaultPath).lastPathComponent
            var excludedLists: Set<String> = [
                "Groceries",
                "Shopping",
                "Cooking-HouseHold"
            ]
            excludedLists.insert(vaultName)

            try await exportRemindersToMarkdown(
                excludeLists: excludedLists,
                eventStore: eventStore,
                outputPath: options.outputPath
            )
            
            print("Sync completed successfully!")
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
