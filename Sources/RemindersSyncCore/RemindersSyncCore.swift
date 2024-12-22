import Foundation
import EventKit
import CryptoKit

public struct ObsidianTask {
    public let id: String  // UUID for the task
    public let text: String
    public let dueDate: Date?
    public let filePath: String
    public let vaultPath: String
    public var isCompleted: Bool
    
    public init(id: String, text: String, dueDate: Date?, filePath: String, vaultPath: String, isCompleted: Bool) {
        self.id = id
        self.text = text
        self.dueDate = dueDate
        self.filePath = filePath
        self.vaultPath = vaultPath
        self.isCompleted = isCompleted
    }
    
    public var obsidianURL: URL? {
        let vaultName = URL(fileURLWithPath: vaultPath).lastPathComponent
        let cleanFilePath = filePath.hasPrefix("/") ? String(filePath.dropFirst()) : filePath
        
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vaultName),
            URLQueryItem(name: "file", value: cleanFilePath)
        ]
        
        return components.url
    }
}

public struct CLIOptions {
    public let vaultPath: String
    
    public var outputPath: String {
        return (vaultPath as NSString).appendingPathComponent("_AppleReminders.md")
    }
    
    public init(vaultPath: String) {
        self.vaultPath = vaultPath
    }
    
    public static func parse() -> CLIOptions {
        let args = CommandLine.arguments
        
        if args.count != 2 {
            print("Usage: \(args[0]) <path-to-obsidian-vault>")
            print("Example: \(args[0]) ~/Documents/MyVault")
            print("\nThe tool will:")
            print("- Scan vault for incomplete tasks")
            print("- Export reminders to: <vault>/_AppleReminders.md")
            exit(1)
        }
        
        return CLIOptions(vaultPath: (args[1] as NSString).expandingTildeInPath)
    }
}

// Copy all the other structs and functions from main.swift, making them public
// Include TaskMapping, TaskMappingStore, and all the helper functions

public struct TaskMapping: Codable {
    public let obsidianId: String
    public let reminderId: String
    public let filePath: String
    public let taskText: String
    
    public init(obsidianId: String, reminderId: String, filePath: String, taskText: String) {
        self.obsidianId = obsidianId
        self.reminderId = reminderId
        self.filePath = filePath
        self.taskText = taskText
    }
    
    public var signature: String {
        let input = "\(filePath)|\(taskText)"
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

public struct TaskMappingStore: Codable {
    public var mappings: [TaskMapping]
    
    public init(mappings: [TaskMapping]) {
        self.mappings = mappings
    }
    
    public func findMapping(filePath: String, taskText: String) -> TaskMapping? {
        let signature = TaskMapping(
            obsidianId: "", 
            reminderId: "", 
            filePath: filePath,
            taskText: taskText
        ).signature
        
        return mappings.first { $0.signature == signature }
    }
    
    public func findMapping(reminderId: String) -> TaskMapping? {
        return mappings.first { $0.reminderId == reminderId }
    }
}

// Add all the helper functions from main.swift here, making them public
public func loadTaskMappings(vaultPath: String) throws -> TaskMappingStore {
    // Copy implementation from main.swift
    let mappingFile = (vaultPath as NSString).appendingPathComponent("._RemindersMapping.json")
    if FileManager.default.fileExists(atPath: mappingFile) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: mappingFile))
            guard !data.isEmpty else {
                print("Warning: Mapping file exists but is empty. Creating new mapping store.")
                return TaskMappingStore(mappings: [])
            }
            
            do {
                return try JSONDecoder().decode(TaskMappingStore.self, from: data)
            } catch {
                print("Warning: Could not decode mapping file. Creating new mapping store. Error: \(error.localizedDescription)")
                let backupFile = mappingFile + ".backup"
                try? FileManager.default.copyItem(atPath: mappingFile, toPath: backupFile)
                return TaskMappingStore(mappings: [])
            }
        } catch {
            print("Warning: Could not read mapping file. Creating new mapping store. Error: \(error.localizedDescription)")
            return TaskMappingStore(mappings: [])
        }
    }
    return TaskMappingStore(mappings: [])
}

// Copy all other functions from main.swift, making them public
public func findIncompleteTasks(in vaultPath: String) throws -> [ObsidianTask] {
    var tasks: [ObsidianTask] = []
    var updatedFiles: [(URL, String)] = []
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(
        at: URL(fileURLWithPath: vaultPath),
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )
    
    let dateRegex = try NSRegularExpression(pattern: "📅 (\\d{4}-\\d{2}-\\d{2})")
    let taskRegex = try NSRegularExpression(pattern: "- \\[([ xX])\\] (.+?)(?:\\s*(?:\\^([A-Z0-9-]+)|<!-- id: ([A-Z0-9-]+) -->))?$", options: .anchorsMatchLines)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    let mappingStore = try loadTaskMappings(vaultPath: vaultPath)
    
    while let fileURL = enumerator?.nextObject() as? URL {
        guard fileURL.pathExtension == "md",
              fileURL.lastPathComponent != "_AppleReminders.md",
              !fileURL.lastPathComponent.hasPrefix("._") else {
            continue
        }
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        var updatedContent = ""
        var contentChanged = false
        let fileBaseName = fileURL.deletingPathExtension().lastPathComponent
        
        // Process the file line by line
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            var currentLine = line
            
            // Find all tasks in the current line
            let matches = taskRegex.matches(in: line, range: range)
            
            // If there are multiple tasks in one line, split them
            if matches.count > 1 {
                // Process each match and create separate lines
                for match in matches {
                    guard let statusRange = Range(match.range(at: 1), in: line),
                          let taskRange = Range(match.range(at: 2), in: line) else {
                        continue
                    }
                    
                    let status = String(line[statusRange])
                    let isCompleted = status == "x" || status == "X"
                    if isCompleted { continue }
                    
                    let taskLine = String(line[taskRange])
                    var taskId: String
                    
                    // Check for existing ID in either format
                    if let idRange = Range(match.range(at: 3), in: line) {
                        taskId = String(line[idRange])
                    } else if let idRange = Range(match.range(at: 4), in: line) {
                        taskId = String(line[idRange])
                    } else {
                        // Generate new ID if none exists
                        let cleanTaskText = taskLine.replacingOccurrences(of: " 📅 \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                                  .replacingOccurrences(of: " ⏳ \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                                  .replacingOccurrences(of: " \\^[A-Z0-9-]+", with: "", options: .regularExpression)
                                                  .replacingOccurrences(of: " <!-- id: [A-Z0-9-]+ -->", with: "", options: .regularExpression)
                                                  .trimmingCharacters(in: .whitespaces)
                        
                        if let existingMapping = mappingStore.findMapping(filePath: fileBaseName + ".md", taskText: cleanTaskText) {
                            taskId = existingMapping.obsidianId
                        } else {
                            taskId = UUID().uuidString
                        }
                    }
                    
                    // Create a new line for this task
                    let newTaskLine = "- [ ] \(taskLine) ^\(taskId)"
                    updatedContent += newTaskLine + "\n"
                    contentChanged = true
                    
                    // Add task to the list
                    if let taskRange = Range(match.range(at: 2), in: line) {
                        let taskText = String(line[taskRange])
                        var dueDate: Date? = nil
                        
                        if let dateMatch = dateRegex.firstMatch(in: taskText, range: NSRange(taskText.startIndex..., in: taskText)),
                           let dateRange = Range(dateMatch.range(at: 1), in: taskText) {
                            dueDate = dateFormatter.date(from: String(taskText[dateRange]))
                        }
                        
                        let cleanTaskText = taskText.replacingOccurrences(of: " 📅 \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                                  .replacingOccurrences(of: " ⏳ \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                                  .replacingOccurrences(of: " \\^[A-Z0-9-]+", with: "", options: .regularExpression)
                                                  .replacingOccurrences(of: " <!-- id: [A-Z0-9-]+ -->", with: "", options: .regularExpression)
                                                  .trimmingCharacters(in: .whitespaces)
                        
                        tasks.append(ObsidianTask(
                            id: taskId,
                            text: cleanTaskText,
                            dueDate: dueDate,
                            filePath: fileBaseName + ".md",
                            vaultPath: vaultPath,
                            isCompleted: false
                        ))
                    }
                }
            } else if let match = matches.first {
                // Single task in the line - process normally
                guard let statusRange = Range(match.range(at: 1), in: line),
                      let taskRange = Range(match.range(at: 2), in: line) else {
                    updatedContent += line + "\n"
                    continue
                }
                
                let status = String(line[statusRange])
                let isCompleted = status == "x" || status == "X"
                
                if isCompleted {
                    updatedContent += line + "\n"
                    continue
                }
                
                let taskLine = String(line[taskRange])
                var taskId: String
                
                // Check for existing ID in either format
                if let idRange = Range(match.range(at: 3), in: line) {
                    taskId = String(line[idRange])
                } else if let idRange = Range(match.range(at: 4), in: line) {
                    taskId = String(line[idRange])
                } else {
                    // Generate new ID if none exists
                    let cleanTaskText = taskLine.replacingOccurrences(of: " 📅 \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                              .replacingOccurrences(of: " ⏳ \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                              .replacingOccurrences(of: " \\^[A-Z0-9-]+", with: "", options: .regularExpression)
                                              .replacingOccurrences(of: " <!-- id: [A-Z0-9-]+ -->", with: "", options: .regularExpression)
                                              .trimmingCharacters(in: .whitespaces)
                    
                    if let existingMapping = mappingStore.findMapping(filePath: fileBaseName + ".md", taskText: cleanTaskText) {
                        taskId = existingMapping.obsidianId
                    } else {
                        taskId = UUID().uuidString
                    }
                    
                    currentLine = "- [ ] \(taskLine) ^\(taskId)"
                    contentChanged = true
                }
                
                // Add task to the list
                var dueDate: Date? = nil
                if let dateMatch = dateRegex.firstMatch(in: taskLine, range: NSRange(taskLine.startIndex..., in: taskLine)),
                   let dateRange = Range(dateMatch.range(at: 1), in: taskLine) {
                    dueDate = dateFormatter.date(from: String(taskLine[dateRange]))
                }
                
                let cleanTaskText = taskLine.replacingOccurrences(of: " 📅 \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                          .replacingOccurrences(of: " ⏳ \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                          .replacingOccurrences(of: " \\^[A-Z0-9-]+", with: "", options: .regularExpression)
                                          .replacingOccurrences(of: " <!-- id: [A-Z0-9-]+ -->", with: "", options: .regularExpression)
                                          .trimmingCharacters(in: .whitespaces)
                
                tasks.append(ObsidianTask(
                    id: taskId,
                    text: cleanTaskText,
                    dueDate: dueDate,
                    filePath: fileBaseName + ".md",
                    vaultPath: vaultPath,
                    isCompleted: false
                ))
                
                updatedContent += currentLine + "\n"
            } else {
                // No task in this line
                updatedContent += line + "\n"
            }
        }
        
        if contentChanged {
            // Remove extra newline at the end if present
            if updatedContent.hasSuffix("\n\n") {
                updatedContent.removeLast()
            }
            updatedFiles.append((fileURL, updatedContent))
        }
    }
    
    // Write all file updates after enumeration
    for (fileURL, updatedContent) in updatedFiles {
        try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    return tasks
}

public func findCompletedTasks(in vaultPath: String) throws -> [ObsidianTask] {
    var tasks: [ObsidianTask] = []
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(
        at: URL(fileURLWithPath: vaultPath),
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )
    
    let dateRegex = try NSRegularExpression(pattern: "📅 (\\d{4}-\\d{2}-\\d{2})")
    let taskRegex = try NSRegularExpression(pattern: "- \\[([xX])\\] (.+?)(?:\\s*(?:\\^([A-Z0-9-]+)|<!-- id: ([A-Z0-9-]+) -->))?$", options: .anchorsMatchLines)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    while let fileURL = enumerator?.nextObject() as? URL {
        guard fileURL.pathExtension == "md",
              fileURL.lastPathComponent != "_AppleReminders.md",
              !fileURL.lastPathComponent.hasPrefix("._") else {
            continue
        }
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let range = NSRange(content.startIndex..., in: content)
        
        taskRegex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match = match,
                  let taskRange = Range(match.range(at: 2), in: content) else {
                return
            }
            
            var taskId: String
            if let idRange = Range(match.range(at: 3), in: content) {
                taskId = String(content[idRange])
            } else if let idRange = Range(match.range(at: 4), in: content) {
                taskId = String(content[idRange])
            } else {
                return  // Skip tasks without IDs
            }
            
            let taskLine = String(content[taskRange])
            var dueDate: Date? = nil
            
            if let dateMatch = dateRegex.firstMatch(in: taskLine, range: NSRange(taskLine.startIndex..., in: taskLine)),
               let dateRange = Range(dateMatch.range(at: 1), in: taskLine) {
                dueDate = dateFormatter.date(from: String(taskLine[dateRange]))
            }
            
            let fileBaseName = fileURL.deletingPathExtension().lastPathComponent
            let cleanTaskText = taskLine.replacingOccurrences(of: " 📅 \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                      .replacingOccurrences(of: " ⏳ \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)
                                      .replacingOccurrences(of: " \\^[A-Z0-9-]+", with: "", options: .regularExpression)
                                      .replacingOccurrences(of: " <!-- id: [A-Z0-9-]+ -->", with: "", options: .regularExpression)
                                      .trimmingCharacters(in: .whitespaces)
            
            tasks.append(ObsidianTask(
                id: taskId,
                text: cleanTaskText,
                dueDate: dueDate,
                filePath: fileBaseName + ".md",
                vaultPath: vaultPath,
                isCompleted: true
            ))
        }
    }
    
    return tasks
}

// Continue copying all other functions, making them public
public func getOrCreateVaultCalendar(for vaultPath: String, eventStore: EKEventStore) throws -> EKCalendar {
    let vaultName = URL(fileURLWithPath: vaultPath).lastPathComponent
    if let calendar = eventStore.calendars(for: .reminder).first(where: { $0.title == vaultName }) {
        return calendar
    } else {
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = vaultName
        
        // Choose a source. Use the default if available; otherwise, pick the first local source.
        if let defaultSource = eventStore.defaultCalendarForNewReminders()?.source {
            newCalendar.source = defaultSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            newCalendar.source = localSource
        } else {
            throw NSError(domain: "RemindersSync",
                          code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "No valid Reminder source found"])
        }
        
        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }
}

public func syncTasksFromVault(tasks: [ObsidianTask], eventStore: EKEventStore) async throws {
    guard !tasks.isEmpty else { return }
    let targetCalendar = try getOrCreateVaultCalendar(for: tasks[0].vaultPath, eventStore: eventStore)
    
    var mappingStore = try loadTaskMappings(vaultPath: tasks.first?.vaultPath ?? "")
    
    let predicate = eventStore.predicateForReminders(in: [targetCalendar])
    let existingReminders = try await withCheckedThrowingContinuation { continuation in
        eventStore.fetchReminders(matching: predicate) { reminders in
            if let reminders = reminders {
                continuation.resume(returning: reminders)
            } else {
                continuation.resume(throwing: NSError(
                    domain: "RemindersSync",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]
                ))
            }
        }
    }
    
    mappingStore.mappings.removeAll { mapping in
        existingReminders.contains { reminder in
            reminder.calendarItemIdentifier == mapping.reminderId && reminder.isCompleted
        }
    }
    
    for task in tasks {
        var reminder: EKReminder?
        if let mapping = mappingStore.findMapping(filePath: task.filePath, taskText: task.text) {
            reminder = existingReminders.first { $0.calendarItemIdentifier == mapping.reminderId }
        }
        
        if reminder == nil {
            reminder = existingReminders.first { !$0.isCompleted && $0.title == "\(task.text) 🔗 \(task.filePath)" }
        }
        
        if reminder == nil {
            reminder = EKReminder(eventStore: eventStore)
            reminder?.calendar = targetCalendar
        }
        
        guard let reminder = reminder else { continue }
        
        reminder.title = task.text
        
        if let dueDate = task.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        }
        
        var notes = [String]()
        notes.append("obsidian://open?vault=\(task.vaultPath.components(separatedBy: "/").last ?? "")&file=\(task.filePath)")
        notes.append("ID: \(task.id)") // Add ID in a structured format
        reminder.notes = notes.joined(separator: "\n")
        
        try eventStore.save(reminder, commit: false)
        
        let newMapping = TaskMapping(
            obsidianId: task.id,
            reminderId: reminder.calendarItemIdentifier,
            filePath: task.filePath,
            taskText: task.text
        )
        
        if let existingIndex = mappingStore.mappings.firstIndex(where: { $0.signature == newMapping.signature }) {
            mappingStore.mappings[existingIndex] = newMapping
        } else {
            mappingStore.mappings.append(newMapping)
        }
    }
    
    try eventStore.commit()
    
    try saveTaskMappings(mappingStore, vaultPath: tasks.first?.vaultPath ?? "")
}

public func syncObsidianCompletedTasks(tasks: [ObsidianTask], eventStore: EKEventStore) async throws {
    guard !tasks.isEmpty else { return }
    let targetCalendar = try getOrCreateVaultCalendar(for: tasks[0].vaultPath, eventStore: eventStore)
    
    let mappingStore = try loadTaskMappings(vaultPath: tasks.first?.vaultPath ?? "")
    
    let predicate = eventStore.predicateForReminders(in: [targetCalendar])
    let reminders = try await withCheckedThrowingContinuation { continuation in
        eventStore.fetchReminders(matching: predicate) { reminders in
            if let reminders = reminders {
                continuation.resume(returning: reminders)
            } else {
                continuation.resume(throwing: NSError(
                    domain: "RemindersSync",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]
                ))
            }
        }
    }
    
    for task in tasks {
        print("Processing completed task: \(task.text)")  // Debug log
        if let mapping = mappingStore.findMapping(filePath: task.filePath, taskText: task.text) {
            print("Found mapping for task") // Debug log
            if let reminder = reminders.first(where: { $0.calendarItemIdentifier == mapping.reminderId }) {
                print("Found matching reminder") // Debug log
                if !reminder.isCompleted {
                    print("Marking reminder as completed") // Debug log
                    reminder.isCompleted = true
                    try eventStore.save(reminder, commit: true)
                }
            }
        }
    }
}

public func syncCompletedReminders(eventStore: EKEventStore, vaultPath: String) async throws {
    let targetCalendar = try getOrCreateVaultCalendar(for: vaultPath, eventStore: eventStore)
    
    let mappingStore = try loadTaskMappings(vaultPath: vaultPath)
    
    let predicate = eventStore.predicateForCompletedReminders(withCompletionDateStarting: nil, ending: nil, calendars: [targetCalendar])
    let completedReminders = try await withCheckedThrowingContinuation { continuation in
        eventStore.fetchReminders(matching: predicate) { reminders in
            if let reminders = reminders {
                continuation.resume(returning: reminders)
            } else {
                continuation.resume(throwing: NSError(
                    domain: "RemindersSync",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]
                ))
            }
        }
    }
    
    for reminder in completedReminders {
        if let mapping = mappingStore.findMapping(reminderId: reminder.calendarItemIdentifier) {
            let filePath = (vaultPath as NSString).appendingPathComponent(mapping.filePath)
            
            if FileManager.default.fileExists(atPath: filePath) {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                var lines = content.components(separatedBy: .newlines)
                
                for (index, line) in lines.enumerated() {
                    var currentLine = line
                    
                    // Check if this line contains our obsidianId (in either format)
                    if line.contains("^\(mapping.obsidianId)") || line.contains("<!-- id: \(mapping.obsidianId) -->") {
                        if line.contains("- [ ]") {
                            currentLine = line.replacingOccurrences(of: "- [ ]", with: "- [x]")
                        }
                    }
                    
                    lines[index] = currentLine
                }
                
                let updatedContent = lines.joined(separator: "\n")
                try updatedContent.write(to: URL(fileURLWithPath: filePath), atomically: true, encoding: .utf8)
            }
        }
    }
}

public func requestRemindersAccess(eventStore: EKEventStore) async throws {
    let authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    switch authorizationStatus {
    case .notDetermined:
        let granted = try await eventStore.requestAccess(to: .reminder)
        guard granted else {
            throw NSError(domain: "RemindersSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Access not granted"])
        }
    case .authorized:
        break
    default:
        throw NSError(domain: "RemindersSync", code: 1, userInfo: [NSLocalizedDescriptionKey: "Reminders access denied"])
    }
}

public func exportRemindersToMarkdown(excludeLists: Set<String>, eventStore: EKEventStore, outputPath: String) async throws {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let currentDate = dateFormatter.string(from: Date())
    
    var markdownContent = "---\ndate: \(currentDate)\n---\n\n"
    
    let calendars = eventStore.calendars(for: .reminder)
        .filter { !excludeLists.contains($0.title) }
        .sorted { $0.title < $1.title }
    
    for calendar in calendars {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersSync", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]))
                }
            }
        }
        
        let incompleteReminders = reminders.filter { !($0.isCompleted) }
        
        if !incompleteReminders.isEmpty {
            markdownContent += "\n### \(calendar.title)\n"
            
            let sortedReminders = incompleteReminders.sorted { r1, r2 in
                let date1 = Calendar.current.date(from: r1.dueDateComponents ?? DateComponents())
                let date2 = Calendar.current.date(from: r2.dueDateComponents ?? DateComponents())
                
                if let d1 = date1, let d2 = date2 {
                    return d1 < d2
                } else if date1 != nil {
                    return true
                } else if date2 != nil {
                    return false
                } else {
                    return (r1.title ?? "") < (r2.title ?? "")
                }
            }
            
            for reminder in sortedReminders {
                var taskLine = "- [ ] \(reminder.title ?? "Untitled")"
                
                if let notes = reminder.notes, !notes.isEmpty {
                    taskLine += " \(notes)"
                }
                
                if let dueDate = reminder.dueDateComponents {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    if let date = Calendar.current.date(from: dueDate) {
                        taskLine += " 📅 \(formatter.string(from: date))"
                    }
                }
                
                markdownContent += "\(taskLine)\n"
            }
        }
    }
    
    try markdownContent.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
}

public func cleanupTaskIds(in vaultPath: String) throws {
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(
        at: URL(fileURLWithPath: vaultPath),
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )
    
    var updatedFiles: [(URL, String)] = []
    
    // Match both formats: ^ID and <!-- id: ID -->
    let taskRegex = try NSRegularExpression(pattern: "- \\[([ xX])\\] (.+?)(?:\\s*(?:\\^([A-Z0-9-]+)|<!-- id: ([A-Z0-9-]+) -->))?$", options: .anchorsMatchLines)
    
    while let fileURL = enumerator?.nextObject() as? URL {
        guard fileURL.pathExtension == "md",
              fileURL.lastPathComponent != "_AppleReminders.md",
              !fileURL.lastPathComponent.hasPrefix("._") else {
            continue
        }
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        var updatedContent = ""
        var contentChanged = false
        
        // Process the file line by line
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            var currentLine = line
            
            if let match = taskRegex.firstMatch(in: line, range: range),
               let taskRange = Range(match.range(at: 2), in: line) {
                let taskText = String(line[taskRange])
                
                // Check if line has an ID (in either format)
                if line.contains("^") || line.contains("<!-- id:") {
                    // Remove both ID formats and clean up any extra spaces
                    currentLine = "- [ ] \(taskText)".trimmingCharacters(in: .whitespaces)
                    contentChanged = true
                }
            }
            
            updatedContent += currentLine + "\n"
        }
        
        if contentChanged {
            // Remove extra newline at the end if present
            if updatedContent.hasSuffix("\n\n") {
                updatedContent.removeLast()
            }
            updatedFiles.append((fileURL, updatedContent))
        }
    }
    
    // Write all file updates after processing
    for (fileURL, updatedContent) in updatedFiles {
        try updatedContent.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

public func saveTaskMappings(_ store: TaskMappingStore, vaultPath: String) throws {
    let mappingFile = (vaultPath as NSString).appendingPathComponent("._RemindersMapping.json")
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(store)
        try data.write(to: URL(fileURLWithPath: mappingFile), options: .atomic)
    } catch {
        print("Warning: Failed to save mapping file. Error: \(error.localizedDescription)")
        throw error
    }
} 