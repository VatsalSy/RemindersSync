import Foundation
import EventKit
import RemindersSyncCore

@main
struct ExportOtherRemindersCLI {
    // Lists to completely exclude from sync
    static func getExcludedLists(vaultPath: String) -> Set<String> {
        var excludedLists: Set<String> = [
            "Groceries",
            "Shopping",
            "Cooking-HouseHold",
            "obsidian"  // Always exclude obsidian list
        ]
        // Add vault name to excluded lists
        let vaultName = URL(fileURLWithPath: vaultPath).lastPathComponent
        excludedLists.insert(vaultName)
        return excludedLists
    }
    
    static func main() async {
        do {
            // Check if help is requested
            if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
                print("""
                Usage: ExportOtherReminders <path-to-obsidian-vault> [--cleanup]
                
                Options:
                  --cleanup    Remove all IDs from reminders in non-excluded lists
                  --help, -h   Show this help message
                
                Example: ExportOtherReminders ~/Documents/MyVault
                        ExportOtherReminders ~/Documents/MyVault --cleanup
                
                The tool will:
                - Scan vault for incomplete tasks
                - Export reminders to: <vault>/_AppleReminders.md
                """)
                exit(0)
            }
            
            // Get vault path from arguments
            guard CommandLine.arguments.count >= 2 else {
                print("Error: Vault path is required")
                print("Run with --help for usage information")
                exit(1)
            }
            
            let vaultPath = CommandLine.arguments[1]
            let eventStore = EKEventStore()
            try await requestRemindersAccess(eventStore: eventStore)
            
            // Check if cleanup mode is requested
            if CommandLine.arguments.contains("--cleanup") {
                try await cleanupReminders(eventStore: eventStore, vaultPath: vaultPath)
                return
            }
            
            // Regular sync process
            // 1. Scan Apple Reminders and save to JSON
            print("Scanning Apple Reminders...")
            let remindersDBPath = (vaultPath as NSString).appendingPathComponent("._RemindersDB.json")
            let remindersDB = try await scanAppleReminders(
                eventStore: eventStore,
                remindersDBPath: remindersDBPath,
                vaultPath: vaultPath
            )
            
            // 2. Scan _AppleReminders.md and save to JSON
            print("Scanning _AppleReminders.md...")
            let localDBPath = (vaultPath as NSString).appendingPathComponent("._LocalDB.json")
            let localDB = try scanLocalTasks(
                vaultPath: vaultPath,
                localDBPath: localDBPath
            )
            
            // 3. Compare and sync completion status
            print("Syncing completion status...")
            try await syncCompletionStatus(
                remindersDB: remindersDB,
                localDB: localDB,
                eventStore: eventStore,
                vaultPath: vaultPath,
                remindersDBPath: remindersDBPath,
                localDBPath: localDBPath
            )
            
            print("Sync completed successfully!")
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    static func normalizeId(_ id: String) -> String {
        // Remove any carets from the ID
        return id.replacingOccurrences(of: "^", with: "")
    }
    
    static func scanAppleReminders(
        eventStore: EKEventStore,
        remindersDBPath: String,
        vaultPath: String
    ) async throws -> [String: [String: Any]] {
        var remindersDB: [String: [String: Any]] = [:]
        let excludedLists = getExcludedLists(vaultPath: vaultPath)
        print("Excluded lists: \(excludedLists)")
        
        // Fetch all reminders
        let predicate = eventStore.predicateForReminders(in: nil)
        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersFetch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]))
                }
            }
        }
        
        for reminder in reminders {
            guard let title = reminder.title else { continue }
            
            // Skip if in excluded list
            if excludedLists.contains(reminder.calendar.title) {
                print("Skipping reminder '\(title)' because it's in excluded list '\(reminder.calendar.title)'")
                continue
            }
            
            // Extract or generate ID
            var id = ""
            var existingNotes = reminder.notes ?? ""
            
            // Check for existing IDs in notes
            if let notes = reminder.notes {
                // Try double caret first
                if let idRange = notes.range(of: "\\^\\^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", options: .regularExpression) {
                    id = String(notes[notes.index(after: notes.index(after: idRange.lowerBound))..<idRange.upperBound])
                }
                // Try single caret if double not found
                else if let idRange = notes.range(of: "\\^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", options: .regularExpression) {
                    id = String(notes[notes.index(after: idRange.lowerBound)..<idRange.upperBound])
                }
            }
            
            // Only generate and add new ID if no ID was found
            if id.isEmpty {
                id = UUID().uuidString
                // Add new ID to notes
                if existingNotes.isEmpty {
                    existingNotes = " ^" + id
                } else {
                    existingNotes += " ^" + id
                }
                reminder.notes = existingNotes
                try eventStore.save(reminder, commit: true)
            }
            
            // Normalize ID before storing
            let normalizedId = normalizeId(id)
            remindersDB[normalizedId] = [
                "title": title,
                "completed": reminder.isCompleted,
                "notes": reminder.notes ?? "",
                "parentList": reminder.calendar.title,
                "dueDate": reminder.dueDateComponents?.date?.description ?? ""
            ]
        }
        
        // Save database
        let data = try JSONSerialization.data(withJSONObject: remindersDB)
        try data.write(to: URL(fileURLWithPath: remindersDBPath))
        
        return remindersDB
    }
    
    static func scanLocalTasks(
        vaultPath: String,
        localDBPath: String
    ) throws -> [String: [String: Any]] {
        var localDB: [String: [String: Any]] = [:]
        let mdPath = (vaultPath as NSString).appendingPathComponent("_AppleReminders.md")
        
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: mdPath) {
            try "".write(to: URL(fileURLWithPath: mdPath), atomically: true, encoding: .utf8)
        }
        
        if let content = try? String(contentsOfFile: mdPath) {
            var currentSection = "Inbox"  // Default section
            let lines = content.components(separatedBy: .newlines)
            
            for line in lines {
                if line.hasPrefix("## ") {
                    currentSection = String(line.dropFirst(3))
                    continue
                }
                
                guard line.hasPrefix("- ") else { continue }
                
                let completed = line.hasPrefix("- [x]") || line.hasPrefix("- [X]")
                let textStart = completed ? line.index(line.startIndex, offsetBy: 6) : line.index(line.startIndex, offsetBy: 4)
                var text = String(line[textStart...]).trimmingCharacters(in: .whitespaces)
                
                // Extract ID if present - try both double and single caret
                var id = ""
                if let idRange = text.range(of: " \\^\\^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", options: .regularExpression) {
                    let idStart = text.index(idRange.lowerBound, offsetBy: 2)  // Skip space and double caret
                    let idEnd = text.index(idRange.upperBound, offsetBy: 0)
                    id = String(text[idStart..<idEnd])
                    text = String(text[..<idRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                else if let idRange = text.range(of: " \\^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", options: .regularExpression) {
                    let idStart = text.index(idRange.lowerBound, offsetBy: 1)  // Skip space and single caret
                    let idEnd = text.index(idRange.upperBound, offsetBy: 0)
                    id = String(text[idStart..<idEnd])
                    text = String(text[..<idRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                
                if id.isEmpty {
                    id = UUID().uuidString
                }
                
                // Normalize ID before storing
                let normalizedId = normalizeId(id)
                localDB[normalizedId] = [
                    "title": text,
                    "completed": completed,
                    "parentList": currentSection
                ]
            }
        }
        
        // Save database
        let data = try JSONSerialization.data(withJSONObject: localDB)
        try data.write(to: URL(fileURLWithPath: localDBPath))
        
        return localDB
    }
    
    static func syncCompletionStatus(
        remindersDB: [String: [String: Any]],
        localDB: [String: [String: Any]],
        eventStore: EKEventStore,
        vaultPath: String,
        remindersDBPath: String,
        localDBPath: String
    ) async throws {
        print("Starting completion sync...")
        var updatedRemindersDB = remindersDB
        var updatedLocalDB = localDB
        
        // First sync completion status for tasks with matching IDs
        let commonIds = Set(remindersDB.keys).intersection(localDB.keys)
        for id in commonIds {
            let reminderTask = remindersDB[id]!
            let localTask = localDB[id]!
            
            let reminderCompleted = reminderTask["completed"] as? Bool ?? false
            let localCompleted = localTask["completed"] as? Bool ?? false
            
            // If either is complete, mark both as complete
            if reminderCompleted || localCompleted {
                updatedRemindersDB[id]?["completed"] = true
                updatedLocalDB[id]?["completed"] = true
                
                // Update Apple Reminder if needed
                if !reminderCompleted {
                    if let reminder = try await findReminderById(id: id, eventStore: eventStore) {
                        reminder.isCompleted = true
                        try eventStore.save(reminder, commit: true)
                    }
                }
            }
        }
        
        // Save updated databases
        let remindersData = try JSONSerialization.data(withJSONObject: updatedRemindersDB)
        try remindersData.write(to: URL(fileURLWithPath: remindersDBPath))
        
        let localData = try JSONSerialization.data(withJSONObject: updatedLocalDB)
        try localData.write(to: URL(fileURLWithPath: localDBPath))
        
        // Create new markdown content with incomplete tasks
        try writeIncompleteTasks(remindersDB: updatedRemindersDB, localDB: updatedLocalDB, vaultPath: vaultPath)
    }
    
    static func findReminderById(id: String, eventStore: EKEventStore) async throws -> EKReminder? {
        let predicate = eventStore.predicateForReminders(in: nil)
        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersFetch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]))
                }
            }
        }
        // Try both double and single caret with normalized ID
        let normalizedId = normalizeId(id)
        return reminders.first { 
            let reminderNotes = $0.notes ?? ""
            return reminderNotes.contains("^^" + normalizedId) || reminderNotes.contains("^" + normalizedId)
        }
    }
    
    static func writeIncompleteTasks(
        remindersDB: [String: [String: Any]],
        localDB: [String: [String: Any]],
        vaultPath: String
    ) throws {
        let mdPath = (vaultPath as NSString).appendingPathComponent("_AppleReminders.md")
        var tasksByList: [String: [(title: String, id: String)]] = [:]
        var processedIds = Set<String>()  // Keep track of processed IDs
        
        // First, add incomplete tasks from Reminders
        for (id, task) in remindersDB {
            let completed = task["completed"] as? Bool ?? false
            if !completed {
                let title = task["title"] as? String ?? ""
                let parentList = task["parentList"] as? String ?? "Inbox"
                
                // Skip if we've already processed this ID
                if !processedIds.contains(id) {
                    tasksByList[parentList, default: []].append((title: title, id: id))
                    processedIds.insert(id)
                }
            }
        }
        
        // Then, add incomplete tasks from local DB that aren't in Reminders
        for (id, task) in localDB {
            // Skip if we've already processed this ID
            if !processedIds.contains(id) {
                let completed = task["completed"] as? Bool ?? false
                if !completed {
                    let title = task["title"] as? String ?? ""
                    let parentList = task["parentList"] as? String ?? "Inbox"
                    tasksByList[parentList, default: []].append((title: title, id: id))
                    processedIds.insert(id)
                }
            }
        }
        
        // Sort tasks within each list to maintain consistent order
        for (listName, tasks) in tasksByList {
            tasksByList[listName] = tasks.sorted { $0.title < $1.title }
        }
        
        // Write to file
        var content = ""
        let sortedLists = tasksByList.keys.sorted()
        
        for listName in sortedLists {
            if let tasks = tasksByList[listName], !tasks.isEmpty {
                content += "\n## \(listName)\n\n"
                for task in tasks {
                    // Remove any "]" from the beginning of titles
                    let cleanTitle = task.title.hasPrefix("]") ? 
                        String(task.title.dropFirst()).trimmingCharacters(in: .whitespaces) : 
                        task.title
                    content += "- [ ] \(cleanTitle) ^" + task.id + "\n"
                }
            }
        }
        
        // Remove leading newline if present
        if content.hasPrefix("\n") {
            content = String(content.dropFirst())
        }
        
        try content.write(to: URL(fileURLWithPath: mdPath), atomically: true, encoding: .utf8)
    }
    
    static func cleanupReminders(
        eventStore: EKEventStore,
        vaultPath: String
    ) async throws {
        print("Starting cleanup of reminder IDs...")
        let excludedLists = getExcludedLists(vaultPath: vaultPath)
        
        // Fetch all reminders
        let predicate = eventStore.predicateForReminders(in: nil)
        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersFetch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]))
                }
            }
        }
        
        var cleanedCount = 0
        for reminder in reminders {
            // Skip if in excluded list
            if excludedLists.contains(reminder.calendar.title) {
                continue
            }
            
            if var notes = reminder.notes {
                var wasModified = false
                
                // Remove old style ID: format
                if let idRange = notes.range(of: "ID: [A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}\n?", options: .regularExpression) {
                    notes.removeSubrange(idRange)
                    wasModified = true
                }
                
                // Remove double caret format
                if let idRange = notes.range(of: " \\^\\^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", options: .regularExpression) {
                    notes.removeSubrange(idRange)
                    wasModified = true
                }
                
                // Remove single caret format
                if let idRange = notes.range(of: " \\^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", options: .regularExpression) {
                    notes.removeSubrange(idRange)
                    wasModified = true
                }
                
                if wasModified {
                    // Trim any extra whitespace
                    notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                    reminder.notes = notes.isEmpty ? nil : notes
                    try eventStore.save(reminder, commit: true)
                    cleanedCount += 1
                    print("Cleaned ID from reminder: \(reminder.title ?? "")")
                }
            }
        }
        
        print("Cleanup completed. Removed IDs from \(cleanedCount) reminders.")
    }
}