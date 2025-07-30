import Foundation
import RemindersSyncCore

let args = CommandLine.arguments

if args.count != 2 {
    print("Usage: \(args[0]) <path-to-obsidian-vault>")
    print("Example: \(args[0]) ~/Documents/MyVault")
    print("\nThis tool will:")
    print("  - Remove all task IDs (^ID and <!-- id: ID -->)")
    print("  - Remove all completed tasks (- [x] or - [X])")
    print("  - Remove the mapping file (._RemindersMapping.json)")
    print("  - Prepare vault for fresh sync with Apple Reminders")
    exit(1)
}

let vaultPath = (args[1] as NSString).expandingTildeInPath
let fileManager = FileManager.default

// Regex patterns
let completedTaskPattern = #"^- \[[xX]\] .+$"#
let taskWithIdPattern = #"(- \[[ xX]\] .+?)(?:\s*(?:\^[A-Z0-9-]+|<!-- id: [A-Z0-9-]+ -->))$"#

let completedRegex = try! NSRegularExpression(pattern: completedTaskPattern, options: .anchorsMatchLines)
let idRegex = try! NSRegularExpression(pattern: taskWithIdPattern, options: .anchorsMatchLines)

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
            // Remove multiple consecutive blank lines
            while finalContent.contains("\n\n\n") {
                finalContent = finalContent.replacingOccurrences(of: "\n\n\n", with: "\n\n")
            }
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

// Also remove the mapping file to ensure fresh sync
let mappingFile = (vaultPath as NSString).appendingPathComponent("._RemindersMapping.json")
if fileManager.fileExists(atPath: mappingFile) {
    do {
        try fileManager.removeItem(atPath: mappingFile)
        print("✓ Removed mapping file")
    } catch {
        print("Warning: Could not remove mapping file: \(error)")
    }
}

print("\n✅ Vault prepared for resync!")
print("   Files processed: \(filesProcessed)")
print("   Completed tasks removed: \(completedTasksRemoved)")
print("   Task IDs removed: \(idsRemoved)")
print("\nYour vault is ready for a fresh sync with Apple Reminders.")
print("Run 'swift run RemindersSync \(vaultPath)' to complete the resync.")