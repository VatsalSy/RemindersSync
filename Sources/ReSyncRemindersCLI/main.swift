import Foundation
import RemindersSyncCore

let args = CommandLine.arguments

if args.count != 2 {
    print("Usage: \(args[0]) <path-to-obsidian-vault>")
    print("Example: \(args[0]) ~/Documents/MyVault")
    print("\nThis tool will:")
    print("  - Remove all task IDs (^ID and <!-- id: ID -->)")
    print("  - Remove all completed tasks (- [x] or - [X])")
    print("  - Remove all state files (._RemindersMapping.json, ._TaskDB.json, ._ConsolidatedIds.json)")
    print("  - Prepare vault for fresh sync with Apple Reminders")
    exit(1)
}

let vaultPath = (args[1] as NSString).expandingTildeInPath
let fileManager = FileManager.default

// Regex patterns
let completedTaskPattern = #"^- \[[xX]\] .+$"#
let taskWithIdPattern = #"(- \[[ xX]\] .+?)(?:\s*(?:\^[A-Z0-9-]+|<!-- id: [A-Z0-9-]+ -->))$"#

let completedRegex: NSRegularExpression
let idRegex: NSRegularExpression

do {
    completedRegex = try NSRegularExpression(pattern: completedTaskPattern, options: .anchorsMatchLines)
    idRegex = try NSRegularExpression(pattern: taskWithIdPattern, options: .anchorsMatchLines)
} catch {
    print("Error creating regular expressions: \(error)")
    exit(1)
}

var filesProcessed = 0
var completedTasksRemoved = 0
var idsRemoved = 0

print("Preparing vault for fresh sync: \(vaultPath)")

let enumerator = fileManager.enumerator(
    at: URL(fileURLWithPath: vaultPath),
    includingPropertiesForKeys: [.isRegularFileKey],
    options: [.skipsHiddenFiles]
)

while let fileURL = enumerator?.nextObject() as? URL {
    // Skip non-markdown files and special files
    let vaultURL = URL(fileURLWithPath: vaultPath)
    let relativePath = fileURL.path.hasPrefix(vaultURL.path) 
        ? String(fileURL.path.dropFirst(vaultURL.path.count))
        : fileURL.path
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
        var modified = false
        var newLines: [String] = []
        
        for line in lines {
            var processedLine = line
            let lineRange = NSRange(line.startIndex..., in: line)
            
            // First check if it's a completed task
            if completedRegex.firstMatch(in: line, range: lineRange) != nil {
                // Skip completed tasks entirely
                completedTasksRemoved += 1
                modified = true
                continue
            }
            
            // For incomplete tasks, remove IDs
            if let match = idRegex.firstMatch(in: line, range: lineRange),
               let taskRange = Range(match.range(at: 1), in: line) {
                processedLine = String(line[taskRange])
                idsRemoved += 1
                modified = true
            }
            
            newLines.append(processedLine)
        }
        
        if modified {
            filesProcessed += 1
            // Join lines and clean up extra blank lines
            var finalContent = newLines.joined(separator: "\n")
            // Replace multiple consecutive newlines with double newlines
            finalContent = finalContent.replacingOccurrences(
                of: "\n{3,}",
                with: "\n\n",
                options: .regularExpression
            )
            // Ensure file ends with single newline
            if !finalContent.isEmpty && !finalContent.hasSuffix("\n") {
                finalContent += "\n"
            }
            try finalContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    } catch {
        print("Error processing \(fileURL.path): \(error)")
    }
}

// Remove all state files to ensure fresh sync
let stateFiles = [
    "._RemindersMapping.json",
    "._TaskDB.json", 
    "._ConsolidatedIds.json"
]

var removedFiles = 0
for stateFile in stateFiles {
    let filePath = (vaultPath as NSString).appendingPathComponent(stateFile)
    if fileManager.fileExists(atPath: filePath) {
        do {
            try fileManager.removeItem(atPath: filePath)
            removedFiles += 1
            print("✓ Removed \(stateFile)")
        } catch {
            print("Warning: Could not remove \(stateFile): \(error)")
        }
    }
}

if removedFiles > 0 {
    print("✓ Removed \(removedFiles) state file(s)")
}

print("\n✅ Vault prepared for resync!")
print("   Files processed: \(filesProcessed)")
print("   Completed tasks removed: \(completedTasksRemoved)")
print("   Task IDs removed: \(idsRemoved)")
print("\nYour vault is ready for a fresh sync with Apple Reminders.")
print("Run 'swift run RemindersSync \(vaultPath)' to complete the resync.")