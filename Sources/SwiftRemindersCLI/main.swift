// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import EventKit

struct ObsidianTask {
    let text: String
    let dueDate: Date?
    let filePath: String
    let vaultPath: String
    
    var obsidianURL: URL? {
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

struct CLIOptions {
    let vaultPath: String
    
    var outputPath: String {
        return (vaultPath as NSString).appendingPathComponent("_AppleReminders.md")
    }
    
    static func parse() -> CLIOptions {
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

func findIncompleteTasks(in vaultPath: String) throws -> [ObsidianTask] {
    var tasks: [ObsidianTask] = []
    let fileManager = FileManager.default
    let enumerator = fileManager.enumerator(
        at: URL(fileURLWithPath: vaultPath),
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    )
    
    let dateRegex = try NSRegularExpression(pattern: "📅 (\\d{4}-\\d{2}-\\d{2})")
    let taskRegex = try NSRegularExpression(pattern: "- \\[ \\] (.+)$", options: .anchorsMatchLines)
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    
    while let fileURL = enumerator?.nextObject() as? URL {
        guard fileURL.pathExtension == "md",
              fileURL.lastPathComponent != "_AppleReminders.md" else {
            continue
        }
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let range = NSRange(content.startIndex..., in: content)
        
        taskRegex.enumerateMatches(in: content, range: range) { match, _, _ in
            guard let match = match,
                  let taskRange = Range(match.range(at: 1), in: content) else {
                return
            }
            
            let taskLine = String(content[taskRange])
            var dueDate: Date? = nil
            
            if let dateMatch = dateRegex.firstMatch(in: taskLine, range: NSRange(taskLine.startIndex..., in: taskLine)),
               let dateRange = Range(dateMatch.range(at: 1), in: taskLine) {
                dueDate = dateFormatter.date(from: String(taskLine[dateRange]))
            }
            
            let fileRelativePath = fileURL.lastPathComponent
            tasks.append(ObsidianTask(
                text: "\(taskLine.replacingOccurrences(of: " 📅 \\d{4}-\\d{2}-\\d{2}", with: "", options: .regularExpression)) 🔗 \(fileRelativePath)",
                dueDate: dueDate,
                filePath: fileRelativePath,
                vaultPath: vaultPath
            ))
        }
    }
    
    return tasks
}

func syncTasksFromVault(tasks: [ObsidianTask], listName: String, eventStore: EKEventStore) async throws {
    guard let targetCalendar = eventStore.calendars(for: .reminder)
        .first(where: { $0.title == listName }) else {
        throw NSError(domain: "RemindersSync", code: 2, userInfo: [NSLocalizedDescriptionKey: "List \(listName) not found"])
    }
    
    let predicate = eventStore.predicateForReminders(in: [targetCalendar])
    let existingReminders = try await withCheckedThrowingContinuation { continuation in
        eventStore.fetchReminders(matching: predicate) { reminders in
            if let reminders = reminders {
                continuation.resume(returning: reminders)
            } else {
                continuation.resume(throwing: NSError(domain: "RemindersSync", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]))
            }
        }
    }
    
    let existingTitles = Set(existingReminders.map { $0.title ?? "" })
    
    for task in tasks {
        guard !existingTitles.contains(task.text) else {
            continue
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = targetCalendar
        reminder.title = task.text
        
        if let dueDate = task.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
        }
        
        if let url = task.obsidianURL {
            reminder.url = url
            reminder.notes = "Link to Obsidian: \(url.absoluteString)"
        }
        
        try eventStore.save(reminder, commit: false)
    }
    
    try eventStore.commit()
}

func requestRemindersAccess(eventStore: EKEventStore) async throws {
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

func exportRemindersToMarkdown(excludeLists: Set<String>, eventStore: EKEventStore, outputPath: String) async throws {
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

@main
struct RemindersSyncCLI {
    static func main() async {
        let options = CLIOptions.parse()
        let eventStore = EKEventStore()
        
        do {
            try await requestRemindersAccess(eventStore: eventStore)
            
            let tasks = try findIncompleteTasks(in: options.vaultPath)
            try await syncTasksFromVault(tasks: tasks, listName: "Obsidian", eventStore: eventStore)
            
            let excludedLists: Set<String> = [
                "Obsidian",
                "Groceries",
                "India trip shopping list",
                "Future shopping list",
                "Cooking-HouseHold"
            ]
            try await exportRemindersToMarkdown(excludeLists: excludedLists, eventStore: eventStore, outputPath: options.outputPath)
            
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
