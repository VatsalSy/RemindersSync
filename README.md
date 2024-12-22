# RemindersSync

A Swift-based command-line tool that provides two-way synchronization between your Obsidian vault and Apple's Reminders app. It consists of three separate CLIs for different sync operations, allowing flexible usage based on your needs.

## Features

- **Three Specialized CLIs**:
  - `ScanVault`: Syncs Obsidian tasks to Apple Reminders
  - `ExportOtherReminders`: Exports other reminders to markdown
  - `RemindersSync`: Complete two-way sync (combines both + handles completed tasks)

- **Vault-Specific Reminders Lists**:
  - Each Obsidian vault gets its own dedicated Reminders list
  - Lists are automatically created and named after your vault
  - Perfect for managing multiple vaults independently

- **Two-Way Task Completion Sync** (via RemindersSync):
  - Tasks completed in Apple Reminders are marked as completed (`- [x]`) in Obsidian files
  - Completed tasks in Obsidian are synced to Reminders to maintain consistency
  - Uses a robust task mapping system with SHA-256 signatures for reliable tracking
  - Maintains task completion state across both platforms

- **Task Mapping System**:
  - Uses a hidden `._RemindersMapping.json` file to maintain task relationships
  - Maps Obsidian tasks to Apple Reminders using unique identifiers
  - Employs SHA-256 signatures to prevent duplicate tasks
  - Automatically handles task ID cleanup and regeneration
  - Preserves task mappings across sync operations
  - Provides reliable two-way sync even if tasks are modified

- **Vault to Reminders Sync** (via ScanVault):
  - Scans your entire Obsidian vault for incomplete tasks (`- [ ]`)
  - Creates reminders with clickable links back to source files
  - Shows file names with link emoji (🔗) in reminder titles
  - Supports Obsidian-style due dates (📅 YYYY-MM-DD)
  - Uses proper Obsidian URI scheme for direct file opening
  - Prevents duplicate entries using cryptographic task signatures
  - Handles multiple tasks per line efficiently

- **Reminders to Vault Export** (via ExportOtherReminders):
  - Exports all incomplete reminders to a markdown file (`_AppleReminders.md`)
  - Organizes tasks by list
  - Preserves due dates and notes
  - Excludes specific lists (e.g., "Groceries", "Obsidian", "Shopping", "Cooking-HouseHold")

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

## System-wide Installation

To make all CLIs available system-wide:

1. Build a release version:
```bash
cd /path/to/RemindersSync
swift build -c release
```

2. Copy the executables to your local bin directory:
```bash
sudo mkdir -p /usr/local/bin
sudo cp .build/release/RemindersSync /usr/local/bin/obsidian-reminders
sudo cp .build/release/ScanVault /usr/local/bin/obsidian-scan
sudo cp .build/release/ExportOtherReminders /usr/local/bin/obsidian-export
```

3. Make them executable:
```bash
sudo chmod +x /usr/local/bin/obsidian-reminders
sudo chmod +x /usr/local/bin/obsidian-scan
sudo chmod +x /usr/local/bin/obsidian-export
```

Now you can run any of the tools from anywhere:
```bash
obsidian-reminders ~/path/to/vault  # Full two-way sync
obsidian-scan ~/path/to/vault       # Just sync Obsidian tasks to Reminders
obsidian-export ~/path/to/vault     # Just export other reminders to markdown
```

### Optional: Create Aliases

Add these to your `~/.zshrc` or `~/.bashrc`:
```bash
alias sync-obsidian='obsidian-reminders "/Users/your-username/path/to/your/vault"'
alias scan-obsidian='obsidian-scan "/Users/your-username/path/to/your/vault"'
alias export-reminders='obsidian-export "/Users/your-username/path/to/your/vault"'
```

Then you can simply run:
```bash
sync-obsidian       # Full two-way sync
scan-obsidian      # Just sync Obsidian tasks to Reminders
export-reminders   # Just export other reminders to markdown
```

Remember to run `source ~/.zshrc` (or `source ~/.bashrc`) after adding the aliases.

## Usage

You can use any of the three CLIs based on your needs:

```bash
# Full two-way sync (including completed tasks)
swift run RemindersSync <path-to-obsidian-vault>

# Just sync Obsidian tasks to Apple Reminders
swift run ScanVault <path-to-obsidian-vault>

# Just export other reminders to markdown
swift run ExportOtherReminders <path-to-obsidian-vault>
```

Example:
```bash
swift run RemindersSync ~/Documents/MyVault
```

### Task Format

The tool recognizes:
- Incomplete tasks: `- [ ] Task description`
- Complete tasks: `- [x] Task description`
- Due dates: `- [ ] Task description 📅 2024-12-22`

### Output

1. **In Apple Reminders** (via ScanVault or RemindersSync):
   - Tasks appear as: "Task description 🔗 filename.md"
   - Each reminder includes:
     - Clickable Obsidian link in notes
     - Due date (if specified)
     - Source file reference
   - Completing a task in Reminders will mark it as completed in Obsidian (RemindersSync only)

2. **In Obsidian** (via ExportOtherReminders or RemindersSync):
   - Tasks completed in Reminders are marked with `- [x]` (RemindersSync only)
   - Creates `_AppleReminders.md` in your vault
   - Organizes tasks by reminder list
   - Includes due dates and notes

### Excluded Lists

The following reminder lists are excluded from export:
- Your vault's list (automatically excluded)
- Groceries
- Shopping
- Cooking-HouseHold

## Configuration

By default, each CLI does the following:
- `ScanVault`: Scans vault for tasks and syncs them to Apple Reminders
- `ExportOtherReminders`: Exports other reminders to `_AppleReminders.md`
- `RemindersSync`: Runs both operations plus handles completed tasks sync

## Permissions

The app requires permission to access your Reminders. You'll be prompted for this permission when running any of the CLIs for the first time. To manage permissions:
1. Go to System Preferences
2. Navigate to Privacy & Security → Reminders
3. Ensure RemindersSync is allowed access

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Specify your license here]

## Support

For issues, questions, or contributions, please [create an issue](repository-issues-url).