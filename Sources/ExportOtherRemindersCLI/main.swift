import Foundation
import EventKit
import RemindersSyncCore

@main
struct ExportOtherRemindersCLI {
    // Lists to completely exclude from sync
    static func getExcludedLists(vaultPath: String) -> Set<String> {
        var excludedLists: Set<String> = [
            "Groceries",
            "Cooking-HouseHold",
            "India-trip-shopping-list",
            "Future-shopping-list",
            "Books-to-listen-Anjali",
            "Anjali-internship-tasks",
            "GTasks",
            "Slack-ReadOnly",
            "obsidian"  // Always exclude obsidian list
        ]
        // Add vault name to excluded lists
        let vaultName = URL(fileURLWithPath: vaultPath).lastPathComponent
        excludedLists.insert(vaultName)
        return excludedLists
    }
    
    // Add new function to manage consolidated ID database
    static func loadConsolidatedIds(vaultPath: String) throws -> [String: String] {
        let consolidatedDBPath = (vaultPath as NSString).appendingPathComponent("._ConsolidatedIds.json")
        if FileManager.default.fileExists(atPath: consolidatedDBPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: consolidatedDBPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return json
        }
        return [:]
    }
    
    static func saveConsolidatedIds(_ ids: [String: String], vaultPath: String) throws {
        let consolidatedDBPath = (vaultPath as NSString).appendingPathComponent("._ConsolidatedIds.json")
        let data = try JSONSerialization.data(withJSONObject: ids)
        try data.write(to: URL(fileURLWithPath: consolidatedDBPath))
    }
    
    static func updateConsolidatedIds(
        remindersDB: [String: [String: Any]],
        localDB: [String: [String: Any]],
        vaultPath: String
    ) throws -> [String: String] {
        var consolidatedIds = try loadConsolidatedIds(vaultPath: vaultPath)
        
        // Helper function to get title from task
        func getTitle(from task: [String: Any]) -> String {
            return task["title"] as? String ?? ""
        }
        
        // First, process reminders DB
        for (id, task) in remindersDB {
            let title = getTitle(from: task)
            let normalizedId = normalizeId(id)
            
            if let existingId = consolidatedIds[title] {
                // If we have a different ID for this title, use the consolidated one
                if normalizedId != normalizeId(existingId) {
                    print("ID mismatch for '\(title)':")
                    print("  Reminders DB ID: \(id)")
                    print("  Consolidated ID: \(existingId)")
                }
            } else {
                consolidatedIds[title] = id
            }
        }
        
        // Then process local DB
        for (id, task) in localDB {
            let title = getTitle(from: task)
            let normalizedId = normalizeId(id)
            
            if let existingId = consolidatedIds[title] {
                // If we have a different ID for this title, use the consolidated one
                if normalizedId != normalizeId(existingId) {
                    print("ID mismatch for '\(title)':")
                    print("  Local DB ID: \(id)")
                    print("  Consolidated ID: \(existingId)")
                }
            } else {
                consolidatedIds[title] = id
            }
        }
        
        // Save the consolidated IDs
        try saveConsolidatedIds(consolidatedIds, vaultPath: vaultPath)
        
        return consolidatedIds
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
            
            // Print excluded lists
            let excludedLists = getExcludedLists(vaultPath: vaultPath)
            print("\nExcluded lists:", excludedLists)
            
            // Perform sync
            try await syncTasks(eventStore: eventStore, vaultPath: vaultPath)
            
            print("Sync completed successfully!")
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    static func normalizeId(_ id: String) -> String {
        // Remove any carets and spaces from the ID and convert to uppercase
        return id.replacingOccurrences(of: "^", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }
    
    static func formatIdForNotes(_ id: String) -> String {
        return "\nID: " + id
    }
    
    static func formatIdForMarkdown(_ id: String) -> String {
        return " ^" + id
    }
    
    static func extractIdFromNotes(_ text: String) -> String? {
        // Try ID: format first
        if let idRange = text.range(of: "ID:\\s*([A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12})", options: .regularExpression) {
            // Extract just the UUID part after "ID:"
            let idText = String(text[idRange])
            if let uuidRange = idText.range(of: "[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", options: .regularExpression) {
                return String(idText[uuidRange])
            }
        }
        
        // Then try caret format as fallback
        if let idRange = text.range(of: "\\^([A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12})", options: .regularExpression) {
            return String(text[text.index(after: idRange.lowerBound)..<idRange.upperBound])
        }
        
        return nil
    }
    
    static func removeIdFromNotes(_ text: String) -> String {
        // Remove ID: format
        var result = text.replacing(try! Regex("\\s*ID:\\s*[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}\\s*"), with: "")
        
        // Also remove any caret format IDs (for cleanup)
        result = result.replacing(try! Regex("\\s*\\^+[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}\\s*"), with: "")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Add new type to track task status
    struct TaskStatus {
        let isComplete: Bool
        let title: String
        let dueDate: String
        let parentList: String
        let notes: String
    }
    
    static func loadTaskDatabase(vaultPath: String) throws -> [String: TaskStatus] {
        let dbPath = (vaultPath as NSString).appendingPathComponent("._TaskDB.json")
        if FileManager.default.fileExists(atPath: dbPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: dbPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            return json.compactMapValues { dict in
                guard let title = dict["title"] as? String,
                      let isComplete = dict["completed"] as? Bool,
                      let parentList = dict["parentList"] as? String
                else { return nil }
                return TaskStatus(
                    isComplete: isComplete,
                    title: title,
                    dueDate: dict["dueDate"] as? String ?? "",
                    parentList: parentList,
                    notes: dict["notes"] as? String ?? ""
                )
            }
        }
        return [:]
    }
    
    static func saveTaskDatabase(_ tasks: [String: TaskStatus], vaultPath: String) throws {
        let dbPath = (vaultPath as NSString).appendingPathComponent("._TaskDB.json")
        let json = tasks.mapValues { status in
            return [
                "title": status.title,
                "completed": status.isComplete,
                "dueDate": status.dueDate,
                "parentList": status.parentList,
                "notes": status.notes
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: json)
        try data.write(to: URL(fileURLWithPath: dbPath))
    }
    
    static func scanMarkdownTasks(vaultPath: String) throws -> [String: TaskStatus] {
        var tasks: [String: TaskStatus] = [:]
        let mdPath = (vaultPath as NSString).appendingPathComponent("_AppleReminders.md")
        
        if !FileManager.default.fileExists(atPath: mdPath) {
            return tasks
        }
        
        let content = try String(contentsOfFile: mdPath)
        var currentSection = "Inbox"
        
        for line in content.components(separatedBy: .newlines) {
            if line.hasPrefix("## ") {
                currentSection = String(line.dropFirst(3))
                continue
            }
            
            guard line.hasPrefix("- ") else { continue }
            
            let isComplete = line.hasPrefix("- [x]") || line.hasPrefix("- [X]")
            let textStart = isComplete ? line.index(line.startIndex, offsetBy: 6) : line.index(line.startIndex, offsetBy: 4)
            var text = String(line[textStart...]).trimmingCharacters(in: .whitespaces)
            
            // Remove any leading "]" and trim whitespace
            if text.hasPrefix("]") {
                text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            
            // Skip tasks with #cl tag (Obsidian-only checklist items)
            if containsClTag(text) {
                continue
            }
            
            // Extract UUID if present
            if let id = extractIdFromNotes(text) {
                // Remove the ID from the text
                if let idRange = text.range(of: " \\^+[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", options: .regularExpression) {
                    text = String(text[..<idRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                
                // Extract due date if present
                var dueDate = ""
                if let dateRange = text.range(of: "📅 \\d{4}-\\d{2}-\\d{2}", options: .regularExpression) {
                    dueDate = String(text[dateRange].dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    text = String(text[..<dateRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                
                tasks[id] = TaskStatus(
                    isComplete: isComplete,
                    title: text,
                    dueDate: dueDate,
                    parentList: currentSection,
                    notes: ""
                )
            }
        }
        
        return tasks
    }
    
    static func scanAppleReminders(
        eventStore: EKEventStore,
        vaultPath: String
    ) async throws -> [String: TaskStatus] {
        var tasks: [String: TaskStatus] = [:]
        let excludedLists = getExcludedLists(vaultPath: vaultPath)
        
        // Fetch all reminders
        let predicate = eventStore.predicateForReminders(in: nil)
        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    let filteredReminders = reminders.filter { !excludedLists.contains($0.calendar.title) }
                    continuation.resume(returning: filteredReminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersFetch", code: -1))
                }
            }
        }
        
        // Process reminders
        for reminder in reminders {
            guard let title = reminder.title else { continue }
            
            if let notes = reminder.notes, let id = extractIdFromNotes(notes) {
                tasks[id] = TaskStatus(
                    isComplete: reminder.isCompleted,
                    title: title,
                    dueDate: reminder.dueDateComponents?.date?.description ?? "",
                    parentList: reminder.calendar.title,
                    notes: notes
                )
            }
        }
        
        return tasks
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
                
                // Remove any leading ']' and trim whitespace
                if text.hasPrefix("]") {
                    text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                
                // Extract due date if present
                var dueDate = ""
                if let dateRange = text.range(of: "📅 \\d{4}-\\d{2}-\\d{2}", options: .regularExpression) {
                    dueDate = String(text[dateRange].dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    text = String(text[..<dateRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                
                // Extract ID if present
                var id = ""
                if let existingId = extractIdFromNotes(text) {
                    id = existingId
                    // Remove the ID from the text
                    if let idRange = text.range(of: " \\^+[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", options: .regularExpression) {
                        text = String(text[..<idRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                    }
                } else {
                    id = UUID().uuidString
                }
                
                // Skip empty tasks
                if text.isEmpty {
                    continue
                }
                
                // Normalize ID before storing
                let normalizedId = normalizeId(id)
                
                // Only add to localDB if we haven't seen this ID before
                if localDB[normalizedId] == nil {
                    localDB[normalizedId] = [
                        "title": text,
                        "completed": completed,
                        "parentList": currentSection,
                        "dueDate": dueDate
                    ]
                }
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
        localDBPath: String,
        consolidatedIds: [String: String]
    ) async throws {
        print("Starting completion sync...")
        var updatedRemindersDB = remindersDB
        let updatedLocalDB = localDB
        let excludedLists = getExcludedLists(vaultPath: vaultPath)
        
        // Debug: Print IDs from both databases
        print("\nDEBUG: Database IDs")
        print("Local DB IDs:", Array(localDB.keys))
        print("Reminders DB IDs:", Array(remindersDB.keys))
        print("Number of local tasks:", localDB.count)
        print("Number of reminder tasks:", remindersDB.count)
        
        // First sync completion status for tasks with matching IDs
        let commonIds = Set(remindersDB.keys).intersection(localDB.keys)
        print("\nDEBUG: Common IDs count:", commonIds.count)
        
        // Debug: Print tasks that exist in local but not in reminders
        let onlyInLocal = Set(localDB.keys).subtracting(remindersDB.keys)
        print("\nDEBUG: Tasks only in local DB:")
        for id in onlyInLocal {
            if let task = localDB[id] {
                print("Title:", task["title"] as? String ?? "nil")
                print("ID:", id)
                print("Parent List:", task["parentList"] as? String ?? "nil")
                print("---")
            }
        }
        
        // First, fetch all existing reminders to check for duplicates
        let predicate = eventStore.predicateForReminders(in: nil)
        let existingReminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    // Filter out excluded lists before processing
                    let filteredReminders = reminders.filter { !excludedLists.contains($0.calendar.title) }
                    continuation.resume(returning: filteredReminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersFetch", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]))
                }
            }
        }
        
        // Debug: Print all reminders and their IDs
        print("\nDEBUG: All Apple Reminders:")
        for reminder in existingReminders {
            print("Title:", reminder.title ?? "nil")
            print("Notes:", reminder.notes ?? "nil")
            if let notes = reminder.notes, let id = extractIdFromNotes(notes) {
                print("Extracted ID:", id)
                print("Normalized ID:", normalizeId(id))
            } else {
                print("No ID found")
            }
            print("List:", reminder.calendar.title)
            print("---")
        }
        
        // Create map of existing IDs
        var existingIds = Set<String>()
        for reminder in existingReminders {
            if let notes = reminder.notes, let id = extractIdFromNotes(notes) {
                let normalizedId = normalizeId(id)
                existingIds.insert(normalizedId)
            }
        }
        
        // Create new reminders for tasks that only exist in _AppleReminders.md
        let newTaskIds = Set(localDB.keys).subtracting(remindersDB.keys)
        
        for id in newTaskIds {
            // Skip if this ID already exists in Apple Reminders
            let normalizedId = normalizeId(id)
            if existingIds.contains(normalizedId) {
                continue
            }
            
            guard let localTask = localDB[id] else { continue }
            let title = localTask["title"] as? String ?? ""
            let parentList = localTask["parentList"] as? String ?? "Inbox"
            
            // Skip if parent list is excluded
            if excludedLists.contains(parentList) {
                continue
            }
            
            // Check if we have a consolidated ID for this title
            let finalId: String
            if let consolidatedId = consolidatedIds[title] {
                finalId = consolidatedId
            } else {
                finalId = id
            }
            
            let completed = localTask["completed"] as? Bool ?? false
            let dueDate = localTask["dueDate"] as? String ?? ""
            
            // Create new reminder
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = title
            reminder.notes = formatIdForNotes(finalId)  // Use consistent ID formatting
            reminder.isCompleted = completed
            
            // Set due date if present
            if !dueDate.isEmpty {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: dueDate) {
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                    components.hour = 23
                    components.minute = 59
                    reminder.dueDateComponents = components
                }
            }
            
            // Find or create calendar for the parent list
            var targetCalendar: EKCalendar?
            for calendar in eventStore.calendars(for: .reminder) {
                if calendar.title == parentList {
                    targetCalendar = calendar
                    break
                }
            }
            
            // If list doesn't exist, create in default calendar
            reminder.calendar = targetCalendar ?? eventStore.defaultCalendarForNewReminders()
            
            // Save the reminder
            try eventStore.save(reminder, commit: true)
            print("Created new reminder: \(title) in list: \(reminder.calendar.title)")
            
            // Add to remindersDB
            updatedRemindersDB[finalId] = [
                "title": title,
                "completed": completed,
                "notes": reminder.notes ?? "",
                "parentList": reminder.calendar.title,
                "dueDate": dueDate
            ]
            
            // Add to existing IDs set
            existingIds.insert(normalizeId(finalId))
        }
        
        // Save updated databases
        let remindersData = try JSONSerialization.data(withJSONObject: updatedRemindersDB)
        try remindersData.write(to: URL(fileURLWithPath: remindersDBPath))
        
        let localData = try JSONSerialization.data(withJSONObject: updatedLocalDB)
        try localData.write(to: URL(fileURLWithPath: localDBPath))
        
        // Create new markdown content with incomplete tasks
        try writeIncompleteTasks(remindersDB: updatedRemindersDB, localDB: updatedLocalDB, vaultPath: vaultPath)
    }
    
    static func findReminderById(id: String, eventStore: EKEventStore, vaultPath: String) async throws -> EKReminder? {
        let predicate = eventStore.predicateForReminders(in: nil)
        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersFetch", code: -1))
                }
            }
        }
        
        return reminders.first { reminder in
            guard let notes = reminder.notes else { return false }
            return extractIdFromNotes(notes) == id
        }
    }
    
    static func writeIncompleteTasks(
        remindersDB: [String: [String: Any]],
        localDB: [String: [String: Any]],
        vaultPath: String
    ) throws {
        let mdPath = (vaultPath as NSString).appendingPathComponent("_AppleReminders.md")
        var tasksByList: [String: [(title: String, id: String, dueDate: String)]] = [:]
        var processedIds = Set<String>()  // Keep track of processed IDs
        
        // First, add incomplete tasks from Reminders
        for (id, task) in remindersDB {
            let completed = task["completed"] as? Bool ?? false
            if !completed {
                let title = task["title"] as? String ?? ""
                let parentList = task["parentList"] as? String ?? "Inbox"
                let dueDate = task["dueDate"] as? String ?? ""
                
                // Skip if we've already processed this ID
                if processedIds.contains(id) {
                    continue
                }
                
                tasksByList[parentList, default: []].append((title: title, id: id, dueDate: dueDate))
                processedIds.insert(id)
            }
        }
        
        // Then, add incomplete tasks from local DB that aren't in Reminders
        for (id, task) in localDB {
            // Skip if we've already processed this ID
            if processedIds.contains(id) {
                continue
            }
            
            let completed = task["completed"] as? Bool ?? false
            if !completed {
                let title = task["title"] as? String ?? ""
                let parentList = task["parentList"] as? String ?? "Inbox"
                let dueDate = task["dueDate"] as? String ?? ""
                
                tasksByList[parentList, default: []].append((title: title, id: id, dueDate: dueDate))
                processedIds.insert(id)
            }
        }
        
        // Sort tasks within each list to maintain consistent order
        for (listName, tasks) in tasksByList {
            tasksByList[listName] = tasks.sorted { $0.title < $1.title }
        }
        
        // Write to file
        var content = ""
        
        // First write Inbox if it exists
        if let inboxTasks = tasksByList["Inbox"], !inboxTasks.isEmpty {
            content += "## Inbox\n\n"
            for task in inboxTasks {
                let cleanTitle = task.title.hasPrefix("]") ? 
                    String(task.title.dropFirst()).trimmingCharacters(in: .whitespaces) : 
                    task.title
                
                // Format due date if present
                var taskLine = "- [ ] \(cleanTitle)"
                if !task.dueDate.isEmpty {
                    // Extract YYYY-MM-DD from the date string
                    if let dateRange = task.dueDate.range(of: "\\d{4}-\\d{2}-\\d{2}", options: .regularExpression) {
                        let formattedDate = String(task.dueDate[dateRange])
                        taskLine += " 📅 \(formattedDate)"
                    }
                }
                
                taskLine += formatIdForMarkdown(task.id) + "\n"  // Use consistent ID formatting
                content += taskLine
            }
            content += "\n"
        }
        
        // Then write other lists in alphabetical order
        let otherLists = tasksByList.keys
            .filter { $0 != "Inbox" }
            .sorted()
        
        for listName in otherLists {
            if let tasks = tasksByList[listName], !tasks.isEmpty {
                content += "## \(listName)\n\n"
                for task in tasks {
                    let cleanTitle = task.title.hasPrefix("]") ? 
                        String(task.title.dropFirst()).trimmingCharacters(in: .whitespaces) : 
                        task.title
                    
                    // Format due date if present
                    var taskLine = "- [ ] \(cleanTitle)"
                    if !task.dueDate.isEmpty {
                        // Extract YYYY-MM-DD from the date string
                        if let dateRange = task.dueDate.range(of: "\\d{4}-\\d{2}-\\d{2}", options: .regularExpression) {
                            let formattedDate = String(task.dueDate[dateRange])
                            taskLine += " 📅 \(formattedDate)"
                        }
                    }
                    
                    taskLine += formatIdForMarkdown(task.id) + "\n"  // Use consistent ID formatting
                    content += taskLine
                }
                content += "\n"
            }
        }
        
        // Remove trailing newlines
        content = content.trimmingCharacters(in: .newlines)
        
        try content.write(to: URL(fileURLWithPath: mdPath), atomically: true, encoding: .utf8)
    }
    
    static func cleanupReminders(eventStore: EKEventStore, vaultPath: String) async throws {
        print("\nStarting cleanup...")
        
        let excludedLists = getExcludedLists(vaultPath: vaultPath)
        print("\nExcluded lists:", excludedLists)
        
        var cleanedCount = 0
        
        // Fetch all reminders
        let predicate = eventStore.predicateForReminders(in: nil)
        let reminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersFetch", code: -1))
                }
            }
        }
        
        // Process reminders
        for reminder in reminders {
            // Skip reminders in excluded lists
            guard !excludedLists.contains(reminder.calendar.title) else { continue }
            
            // Check if reminder has an ID
            if let notes = reminder.notes, extractIdFromNotes(notes) != nil {
                // Remove the ID from notes
                reminder.notes = removeIdFromNotes(notes)
                try eventStore.save(reminder, commit: true)
                cleanedCount += 1
            }
        }
        
        print("\nCleanup completed. Removed IDs from \(cleanedCount) reminders.")
    }
    
    static func handleNewTasksWithoutID(
        eventStore: EKEventStore,
        vaultPath: String
    ) async throws {
        let mdPath = (vaultPath as NSString).appendingPathComponent("_AppleReminders.md")
        guard FileManager.default.fileExists(atPath: mdPath) else { return }
        
        // Load the file content
        let rawContent = try String(contentsOfFile: mdPath, encoding: .utf8)
        let lines = rawContent.components(separatedBy: .newlines)
        var newContent: [String] = []
        
        for line in lines {
            // Keep track of sections (just preserve them in output)
            if line.hasPrefix("## ") {
                newContent.append(line)
                continue
            }
            
            // Skip non-task lines
            guard line.hasPrefix("- [") else {
                newContent.append(line)
                continue
            }
            
            // Check if this line contains any known ID
            if let idInLine = extractIdFromNotes(line), !idInLine.isEmpty {
                // It has an ID, so keep it in the new content
                newContent.append(line)
                continue
            }
            
            // No ID found => treat this as a new task to add to Reminders
            let isComplete = line.hasPrefix("- [x]") || line.hasPrefix("- [X]")
            let textStart = isComplete ? line.index(line.startIndex, offsetBy: 6) : line.index(line.startIndex, offsetBy: 4)
            var cleanedLine = String(line[textStart...]).trimmingCharacters(in: .whitespaces)
            
            // Remove any leading "]" if present
            if cleanedLine.hasPrefix("]") {
                cleanedLine = String(cleanedLine.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
            
            // Skip tasks with #cl tag (Obsidian-only checklist items)
            if containsClTag(cleanedLine) {
                // Don't add this line back to the content since it's #cl only
                continue
            }
            
            // Extract due date if present
            var dueDateString = ""
            var titleOnly = cleanedLine
            if let dateRange = cleanedLine.range(of: "📅 \\d{4}-\\d{2}-\\d{2}", options: .regularExpression) {
                dueDateString = String(cleanedLine[dateRange].dropFirst(2)).trimmingCharacters(in: .whitespaces)
                titleOnly = String(cleanedLine[..<dateRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            
            // Create a new Apple Reminder in the Inbox
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = titleOnly
            reminder.isCompleted = isComplete
            
            // Set due date if any
            if !dueDateString.isEmpty {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                if let date = dateFormatter.date(from: dueDateString) {
                    var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                    components.hour = 23
                    components.minute = 59
                    reminder.dueDateComponents = components
                }
            }
            
            // Find or use default Inbox calendar
            var inboxCalendar: EKCalendar?
            for calendar in eventStore.calendars(for: .reminder) {
                if calendar.title == "Inbox" {
                    inboxCalendar = calendar
                    break
                }
            }
            reminder.calendar = inboxCalendar ?? eventStore.defaultCalendarForNewReminders()
            
            // Save the reminder
            try eventStore.save(reminder, commit: true)
            print("Created new reminder '\(titleOnly)' in Inbox")
            
            // Don't add this line back to the content since it's now in Reminders
        }
        
        // Write the updated content back to the file
        let updatedContent = newContent.joined(separator: "\n")
        try updatedContent.write(toFile: mdPath, atomically: true, encoding: .utf8)
    }
    
    static func syncTasks(
        eventStore: EKEventStore,
        vaultPath: String
    ) async throws {
        // First, process any new tasks without IDs
        try await handleNewTasksWithoutID(eventStore: eventStore, vaultPath: vaultPath)
        
        // Continue with existing sync logic...
        let mdPath = (vaultPath as NSString).appendingPathComponent("_AppleReminders.md")
        var taskDB = try loadTaskDatabase(vaultPath: vaultPath)
        let excludedLists = getExcludedLists(vaultPath: vaultPath)
        
        // Get tasks from both sources
        let mdTasks = try scanMarkdownTasks(vaultPath: vaultPath)
        let reminderTasks = try await scanAppleReminders(eventStore: eventStore, vaultPath: vaultPath)
        
        // Combine all known UUIDs
        var allIds = Set(mdTasks.keys).union(reminderTasks.keys)
        
        // First, handle tasks with UUIDs
        for id in allIds {
            let mdTask = mdTasks[id]
            let reminderTask = reminderTasks[id]
            
            // Skip if the task is in an excluded list
            if let task = mdTask ?? reminderTask {
                if excludedLists.contains(task.parentList) {
                    continue
                }
            }
            
            // If task exists in either place and is marked complete, mark it complete everywhere
            let isComplete = (mdTask?.isComplete ?? false) || (reminderTask?.isComplete ?? false)
            
            // Update or create reminder in Apple Reminders
            if let task = mdTask ?? reminderTask {
                if let reminder = try await findReminderById(id: id, eventStore: eventStore, vaultPath: vaultPath) {
                    // Update existing reminder
                    reminder.isCompleted = isComplete
                    try eventStore.save(reminder, commit: true)
                } else {
                    // Create new reminder
                    let reminder = EKReminder(eventStore: eventStore)
                    reminder.title = task.title
                    reminder.notes = formatIdForNotes(id)
                    reminder.isCompleted = isComplete
                    
                    // Set due date if present
                    if !task.dueDate.isEmpty {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        if let date = dateFormatter.date(from: task.dueDate) {
                            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                            components.hour = 23
                            components.minute = 59
                            reminder.dueDateComponents = components
                        }
                    }
                    
                    // Set list
                    var targetCalendar: EKCalendar?
                    for calendar in eventStore.calendars(for: .reminder) {
                        if calendar.title == task.parentList {
                            targetCalendar = calendar
                            break
                        }
                    }
                    reminder.calendar = targetCalendar ?? eventStore.defaultCalendarForNewReminders()
                    
                    try eventStore.save(reminder, commit: true)
                }
            }
            
            // Update task database
            taskDB[id] = TaskStatus(
                isComplete: isComplete,
                title: mdTask?.title ?? reminderTask?.title ?? "",
                dueDate: mdTask?.dueDate ?? reminderTask?.dueDate ?? "",
                parentList: mdTask?.parentList ?? reminderTask?.parentList ?? "Inbox",
                notes: mdTask?.notes ?? reminderTask?.notes ?? ""
            )
        }
        
        // Handle tasks without UUIDs in Apple Reminders
        let allReminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            eventStore.fetchReminders(matching: eventStore.predicateForReminders(in: nil)) { reminders in
                if let reminders = reminders {
                    // Filter out excluded lists
                    let filteredReminders = reminders.filter { !excludedLists.contains($0.calendar.title) }
                    continuation.resume(returning: filteredReminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersFetch", code: -1))
                }
            }
        }
        
        for reminder in allReminders {
            // Skip if in excluded list
            if excludedLists.contains(reminder.calendar.title) {
                continue
            }
            
            guard let title = reminder.title,
                  reminder.notes == nil || extractIdFromNotes(reminder.notes!) == nil else { continue }
            
            // Generate new UUID
            let id = UUID().uuidString
            
            // Add ID to reminder
            reminder.notes = (reminder.notes ?? "") + formatIdForNotes(id)
            try eventStore.save(reminder, commit: true)
            
            // Add to task database
            taskDB[id] = TaskStatus(
                isComplete: reminder.isCompleted,
                title: title,
                dueDate: reminder.dueDateComponents?.date?.description ?? "",
                parentList: reminder.calendar.title,
                notes: reminder.notes ?? ""
            )
            
            allIds.insert(id)
        }
        
        // Save task database
        try saveTaskDatabase(taskDB, vaultPath: vaultPath)
        
        // Write markdown file
        var content = ""
        var tasksByList: [String: [(title: String, id: String, dueDate: String, isComplete: Bool)]] = [:]
        
        // Group tasks by list (excluding excluded lists)
        for (id, task) in taskDB {
            if !task.isComplete && !excludedLists.contains(task.parentList) {  // Only include incomplete tasks from non-excluded lists
                tasksByList[task.parentList, default: []].append((
                    title: task.title,
                    id: id,
                    dueDate: task.dueDate,
                    isComplete: task.isComplete
                ))
            }
        }
        
        // Write Inbox first
        if let inboxTasks = tasksByList["Inbox"]?.sorted(by: { $0.title < $1.title }) {
            content += "## Inbox\n\n"
            for task in inboxTasks {
                // Remove any leading "]" from the title
                let cleanTitle = task.title.hasPrefix("]") ? 
                    String(task.title.dropFirst()).trimmingCharacters(in: .whitespaces) : 
                    task.title
                var line = "- [ ] \(cleanTitle)"
                if !task.dueDate.isEmpty {
                    if let dateRange = task.dueDate.range(of: "\\d{4}-\\d{2}-\\d{2}", options: .regularExpression) {
                        line += " 📅 \(task.dueDate[dateRange])"
                    }
                }
                line += formatIdForMarkdown(task.id) + "\n"
                content += line
            }
            content += "\n"
        }
        
        // Write other lists (excluding excluded lists)
        for list in tasksByList.keys.sorted().filter({ $0 != "Inbox" && !excludedLists.contains($0) }) {
            if let tasks = tasksByList[list]?.sorted(by: { $0.title < $1.title }), !tasks.isEmpty {
                content += "## \(list)\n\n"
                for task in tasks {
                    // Remove any leading "]" from the title
                    let cleanTitle = task.title.hasPrefix("]") ? 
                        String(task.title.dropFirst()).trimmingCharacters(in: .whitespaces) : 
                        task.title
                    var line = "- [ ] \(cleanTitle)"
                    if !task.dueDate.isEmpty {
                        if let dateRange = task.dueDate.range(of: "\\d{4}-\\d{2}-\\d{2}", options: .regularExpression) {
                            line += " 📅 \(task.dueDate[dateRange])"
                        }
                    }
                    line += formatIdForMarkdown(task.id) + "\n"
                    content += line
                }
                content += "\n"
            }
        }
        
        try content.write(to: URL(fileURLWithPath: mdPath), atomically: true, encoding: .utf8)
    }
}