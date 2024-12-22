// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import EventKit

struct TaskItem: Decodable {
    let text: String
    let due: String?
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

func loadTasks(from path: String) throws -> [TaskItem] {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode([TaskItem].self, from: data)
}

func syncTasks(_ tasks: [TaskItem], listName: String, eventStore: EKEventStore) async throws {
    guard let targetCalendar = eventStore.calendars(for: .reminder)
        .first(where: { $0.title == listName }) else {
        throw NSError(domain: "RemindersSync", code: 2, userInfo: [NSLocalizedDescriptionKey: "List \(listName) not found"])
    }

    let predicate = eventStore.predicateForReminders(in: [targetCalendar])
    let existingReminders = try await eventStore.reminders(matching: predicate)
    let existingTitles = Set(existingReminders.map { $0.title ?? "" })

    for task in tasks {
        guard !existingTitles.contains(task.text) else { continue }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = targetCalendar
        reminder.title = task.text

        if let dueString = task.due, !dueString.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let dueDate = formatter.date(from: dueString) {
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            }
        }

        try eventStore.save(reminder, commit: false)
    }

    try eventStore.commit()
}

@main
struct RemindersSyncCLI {
    static func main() async {
        let eventStore = EKEventStore()
        
        do {
            try await requestRemindersAccess(eventStore: eventStore)
            
            // Default to current directory for tasks.json
            let tasksPath = FileManager.default.currentDirectoryPath + "/testTasks.json"
            
            let tasks = try loadTasks(from: tasksPath)
            print("Loaded \(tasks.count) tasks from \(tasksPath)")
            
            try await syncTasks(tasks, listName: "Reminders", eventStore: eventStore)
            print("Sync complete!")
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
