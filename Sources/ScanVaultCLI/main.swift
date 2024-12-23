import Foundation
import EventKit
import RemindersSyncCore

@main
struct ScanVaultCLI {
    static func main() async {
        do {
            let options = CLIOptions.parse()
            let eventStore = EKEventStore()

            try await requestRemindersAccess(eventStore: eventStore)
            
            // First clean up any existing task IDs if mapping file doesn't exist
            let mappingPath = (options.vaultPath as NSString).appendingPathComponent("._RemindersMapping.json")
            if !FileManager.default.fileExists(atPath: mappingPath) {
                print("No mapping file found. Cleaning up existing task IDs...")
                try cleanupTaskIds(in: options.vaultPath)
            }
            
            // Find and sync incomplete tasks
            let tasks = try findIncompleteTasks(in: options.vaultPath)
            try await syncTasksFromVault(tasks: tasks, eventStore: eventStore)
            
            print("Successfully scanned vault and synced tasks to Apple Reminders")
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
} 