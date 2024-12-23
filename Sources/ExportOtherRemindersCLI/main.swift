import Foundation
import EventKit
import RemindersSyncCore

@main
struct ExportOtherRemindersCLI {
    static func main() async {
        do {
            let options = CLIOptions.parse()
            let eventStore = EKEventStore()

            try await requestRemindersAccess(eventStore: eventStore)

            // Set up excluded lists
            let vaultName = URL(fileURLWithPath: options.vaultPath).lastPathComponent
            var excludedLists: Set<String> = [
                "Groceries",
                "Shopping",
                "Cooking-HouseHold"
            ]
            excludedLists.insert(vaultName)

            // Export reminders to markdown
            try await exportRemindersToMarkdown(
                excludeLists: excludedLists,
                eventStore: eventStore,
                outputPath: options.outputPath
            )
            
            print("Successfully exported other reminders to \(options.outputPath)")
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
} 