# RemindersSync

A Swift-based command-line tool that provides two-way synchronization between your Obsidian vault and Apple's Reminders app. It scans your vault for incomplete tasks and syncs them with Apple Reminders, while also maintaining a markdown export of your other reminders.

## Features

- **Vault to Reminders Sync**:
  - Scans your entire Obsidian vault for incomplete tasks (`- [ ]`)
  - Creates reminders with clickable links back to source files
  - Shows file names with link emoji (🔗) in reminder titles
  - Supports Obsidian-style due dates (📅 YYYY-MM-DD)
  - Uses proper Obsidian URI scheme for direct file opening
  - Prevents duplicate entries

- **Reminders to Vault Export**:
  - Exports all incomplete reminders to a markdown file
  - Organizes tasks by list
  - Preserves due dates and notes
  - Excludes specific lists (e.g., "Groceries", "Obsidian")

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- Xcode (for development)
- Access permissions to Apple Reminders

## Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd RemindersSync
```

2. Build the project using Swift Package Manager:
```bash
swift build
```

## Usage

Run the tool with your Obsidian vault path:
```bash
swift run SwiftRemindersCLI <path-to-obsidian-vault>
```

Example:
```bash
swift run SwiftRemindersCLI ~/Documents/MyVault
```

### Task Format

The tool recognizes:
- Incomplete tasks: `- [ ] Task description`
- Due dates: `- [ ] Task description 📅 2024-12-22`

### Output

1. **In Apple Reminders**:
   - Tasks appear as: "Task description 🔗 filename.md"
   - Each reminder includes:
     - Clickable Obsidian link in notes
     - Due date (if specified)
     - Source file reference

2. **In Obsidian**:
   - Creates `_AppleReminders.md` in your vault
   - Organizes tasks by reminder list
   - Includes due dates and notes

### Excluded Lists

The following reminder lists are excluded from export:
- Obsidian
- Groceries
- Shopping
- Cooking-HouseHold

## Configuration

By default, the tool:
- Scans all markdown files in your vault for tasks
- Syncs found tasks to a Reminders list named "Obsidian"
- Exports other reminders to `_AppleReminders.md` in your vault root

## Permissions

The app requires permission to access your Reminders. You'll be prompted for this permission when running the tool for the first time. To manage permissions:
1. Go to System Preferences
2. Navigate to Privacy & Security → Reminders
3. Ensure RemindersSync is allowed access

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Specify your license here]

## Support

For issues, questions, or contributions, please [create an issue](repository-issues-url).