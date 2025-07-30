import Foundation
import EventKit
import RemindersSyncCore

@main
struct CleanUpCLI {
    static func main() async {
        let args = CommandLine.arguments
        
        if args.count != 2 {
            print("Usage: \(args[0]) <path-to-obsidian-vault>")
            print("Example: \(args[0]) ~/Documents/MyVault")
            print("\nThis tool will:")
            print("  - First run RemindersSync to ensure systems are synchronized")
            print("  - Remove all completed tasks from Obsidian vault")
            print("  - Remove corresponding completed reminders from Apple Reminders")
            print("  - Update mapping file to reflect removed tasks")
            print("  - Preserve all incomplete tasks with their IDs")
            exit(1)
        }
        
        let vaultPath = (args[1] as NSString).expandingTildeInPath
        let eventStore = EKEventStore()
        
        do {
            // Request reminders access
            try await requestRemindersAccess(eventStore: eventStore)
            
            print("Step 1: Running RemindersSync to ensure systems are synchronized...")
            // First sync to ensure both systems are in sync
            try await syncCompletedReminders(eventStore: eventStore, vaultPath: vaultPath)
            let incompleteTasks = try findIncompleteTasks(in: vaultPath)
            try await syncTasksFromVault(tasks: incompleteTasks, eventStore: eventStore)
            print("✓ Systems synchronized")
            
            print("\nStep 2: Finding completed tasks...")
            // Find all completed tasks
            let completedTasks = try findCompletedTasks(in: vaultPath)
            print("Found \(completedTasks.count) completed tasks")
            
            if completedTasks.isEmpty {
                print("No completed tasks found. Nothing to clean up.")
                exit(0)
            }
            
            print("\nStep 3: Removing completed tasks from vault...")
            let removedFromVault = try removeCompletedTasksFromVault(vaultPath: vaultPath)
            print("✓ Removed \(removedFromVault) completed tasks from vault files")
            
            print("\nStep 4: Removing completed reminders...")
            let removedFromReminders = try await removeCompletedReminders(
                tasks: completedTasks,
                eventStore: eventStore,
                vaultPath: vaultPath
            )
            print("✓ Removed \(removedFromReminders) completed reminders from Apple Reminders")
            
            print("\n✅ Cleanup completed successfully!")
            print("   Removed \(removedFromVault) tasks from vault")
            print("   Removed \(removedFromReminders) reminders from Apple Reminders")
            print("   All incomplete tasks preserved with their IDs")
            
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    static func removeCompletedTasksFromVault(vaultPath: String) throws -> Int {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: vaultPath),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        let completedTaskPattern = #"^\s*- \[[xX]\] .+$"#
        let completedRegex = try NSRegularExpression(pattern: completedTaskPattern, options: .anchorsMatchLines)
        
        var totalRemoved = 0
        var filesProcessed = 0
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let relativePath = fileURL.path.replacingOccurrences(of: vaultPath, with: "")
            guard fileURL.pathExtension == "md",
                  !fileURL.lastPathComponent.hasPrefix("._"),
                  fileURL.lastPathComponent != "_AppleReminders.md",
                  !relativePath.contains("/Templates/"),
                  !relativePath.contains("/aiprompts/") else {
                continue
            }
            
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                var newLines: [String] = []
                var removed = 0
                
                for line in lines {
                    let lineRange = NSRange(line.startIndex..., in: line)
                    if completedRegex.firstMatch(in: line, range: lineRange) != nil {
                        removed += 1
                        continue // Skip completed tasks
                    }
                    newLines.append(line)
                }
                
                if removed > 0 {
                    filesProcessed += 1
                    totalRemoved += removed
                    
                    // Join lines and clean up extra blank lines
                    var finalContent = newLines.joined(separator: "\n")
                    // Replace multiple consecutive newlines with double newlines
                    finalContent = finalContent.replacingOccurrences(
                        of: "\n{3,}",
                        with: "\n\n",
                        options: .regularExpression
                    )
                    if !finalContent.isEmpty && !finalContent.hasSuffix("\n") {
                        finalContent += "\n"
                    }
                    
                    try finalContent.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            } catch {
                print("Warning: Could not process file \(fileURL.path): \(error)")
            }
        }
        
        if filesProcessed > 0 {
            print("Processed \(filesProcessed) files")
        }
        
        return totalRemoved
    }
    
    static func removeCompletedReminders(
        tasks: [ObsidianTask],
        eventStore: EKEventStore,
        vaultPath: String
    ) async throws -> Int {
        let targetCalendar = try getOrCreateVaultCalendar(for: vaultPath, eventStore: eventStore)
        var mappingStore = try loadTaskMappings(vaultPath: vaultPath)
        
        let predicate = eventStore.predicateForReminders(in: [targetCalendar])
        let reminders = try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "CleanUp",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]
                    ))
                }
            }
        }
        
        var removedCount = 0
        
        // Remove completed reminders
        for task in tasks {
            if let mapping = mappingStore.findMapping(obsidianId: task.id),
               let reminder = reminders.first(where: { $0.calendarItemIdentifier == mapping.reminderId }) {
                if reminder.isCompleted {
                    try eventStore.remove(reminder, commit: false)
                    removedCount += 1
                    
                    // Remove from mapping store
                    mappingStore.mappings.removeAll { $0.obsidianId == task.id }
                }
            }
        }
        
        // Also remove any completed reminders that might not have tasks anymore
        for reminder in reminders where reminder.isCompleted {
            if mappingStore.findMappingByReminderId(reminder.calendarItemIdentifier) != nil {
                // Check if this reminder's task was already removed
                if !mappingStore.mappings.contains(where: { $0.reminderId == reminder.calendarItemIdentifier }) {
                    continue // Already removed from mapping
                }
                
                try eventStore.remove(reminder, commit: false)
                removedCount += 1
                
                // Remove from mapping store
                mappingStore.mappings.removeAll { $0.reminderId == reminder.calendarItemIdentifier }
            }
        }
        
        if removedCount > 0 {
            try eventStore.commit()
            try saveTaskMappings(mappingStore, vaultPath: vaultPath)
        }
        
        return removedCount
    }
}