# RemindersSync

[![License](https://img.shields.io/github/license/VatsalSy/RemindersSync)](https://github.com/VatsalSy/RemindersSync/blob/main/LICENSE)
[![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/VatsalSy/RemindersSync)](https://github.com/VatsalSy/RemindersSync/releases)
[![GitHub last commit](https://img.shields.io/github/last-commit/VatsalSy/RemindersSync)](https://github.com/VatsalSy/RemindersSync/commits/main)
[![macOS](https://img.shields.io/badge/platform-macOS-blue)](https://github.com/VatsalSy/RemindersSync#readme)

A Swift-based tool to sync Obsidian tasks with Apple Reminders. Tasks are synced bidirectionally between your Obsidian vault and a dedicated Apple Reminders list (with the same name as your vault).

If you encounter any problems or have suggestions, please open an issue on GitHub:<br>
[![GitHub issues](https://img.shields.io/github/issues/VatsalSy/RemindersSync)](https://github.com/VatsalSy/RemindersSync/issues/new/choose)

## Features

- Bidirectional sync of tasks between Obsidian and Apple Reminders
  - Only syncs with the Apple Reminders list that matches your vault name
  - Does not affect tasks in other Reminders lists
  - Does not sync tasks found in `_AppleReminders.md`
- Maintains task completion status across both systems
- Preserves task IDs and mappings between systems
- Handles task due dates

## Available Commands

The package includes three command-line tools:

1. **RemindersSync**: Full two-way sync between vault tasks and vault-named list
   - Syncs tasks between Obsidian and a dedicated Reminders list (named same as vault)
   - Syncs completion status both ways
   - Only affects tasks in your vault, not those in `_AppleReminders.md`
   - Preserves task IDs and mappings between systems
   ```bash
   swift run RemindersSync /path/to/vault
   ```

2. **ScanVault**: One-way sync from Obsidian to Reminders
   - Only syncs tasks from Obsidian to Reminders
   - Does not sync completion status back to Obsidian
   - Creates tasks in the vault-named list in Apple Reminders
   ```bash
   swift run ScanVault /path/to/vault
   ```

3. **ExportOtherReminders**: Two-way sync for non-vault reminders
   - Syncs tasks between `_AppleReminders.md` and Apple Reminders (excluding vault list)
   - Maintains two-way completion status sync
   - Auto-creates tasks in Inbox for new entries without IDs
   - Preserves list organization and due dates
   - Handles task consolidation and ID management
   ```bash
   # Regular sync
   swift run ExportOtherReminders /path/to/vault

   # Clean up IDs (if needed)
   swift run ExportOtherReminders /path/to/vault --cleanup

   # Get help with options
   swift run ExportOtherReminders --help
   ```

### ExportOtherReminders Details

The `ExportOtherReminders` tool provides a robust sync between Apple Reminders and a markdown file:

#### Features
- Two-way completion status sync
- Preserves task organization by list
- Maintains unique IDs for reliable syncing
- Handles both new and existing tasks
- Cleans up duplicate entries
- Auto-creates tasks in Inbox for new entries without IDs

#### Task Creation Behavior
- New tasks added to `_AppleReminders.md` without IDs:
  - Automatically created in Apple Reminders' Inbox
  - Removed from the markdown file after creation
  - Will reappear in markdown with proper ID after next sync
- New tasks with IDs:
  - Synced bidirectionally between systems
  - Maintain their list organization

#### Excluded Lists
By default, the following lists are excluded from sync:
- Groceries
- Cooking-HouseHold
- obsidian
- Your vault name (to avoid conflicts with RemindersSync)

#### File Structure
- `_AppleReminders.md`: Main file containing all synced tasks
  - Organized by sections using `## List Name` headers
  - Each task includes a unique ID: `- [ ] Task text ^UUID`
  - Tasks without a section go to "Inbox"
  - Supports due dates with YYYY-MM-DD format

#### State Files
- `._TaskDB.json`: Current state of all tasks with their metadata
- `._ConsolidatedIds.json`: Mapping of task titles to their consolidated IDs

#### Usage Examples

1. Regular sync:
```bash
swift run ExportOtherReminders /path/to/vault
```

2. Clean up IDs (if you have duplicates):
```bash
swift run ExportOtherReminders /path/to/vault --cleanup
```

3. Get help:
```bash
swift run ExportOtherReminders --help
```

#### How It Works

1. **Initial Processing**:
   - Scans `_AppleReminders.md` for tasks without IDs
   - Creates these tasks in Apple Reminders' Inbox
   - Removes them from the markdown file

2. **Main Sync**:
   - Scans all remaining tasks in both systems
   - Syncs completion status bidirectionally
   - Maintains list organization
   - Preserves due dates

3. **Task Organization**:
   - Tasks are organized by their list in Apple Reminders
   - Tasks from `_AppleReminders.md` maintain their section headers
   - New tasks without a list go to "Inbox"

4. **ID Management**:
   - Each task has a unique UUID
   - IDs are stored in Apple Reminders notes field
   - IDs are preserved in markdown using the `^UUID` format
   - Consolidated IDs prevent duplicates

#### Best Practices

1. Run `--cleanup` if you notice duplicate tasks
2. Let the tool manage the `_AppleReminders.md` file structure
3. Use list names in Apple Reminders to organize tasks
4. Don't manually edit task IDs
5. For new tasks in markdown, just add them without IDs - they'll be properly processed

## State Files

The tools maintain several state files in your vault:

### RemindersSync Files:
- `._VaultTasks.json`: Current state of all tasks in your Obsidian vault
- `._Reminders.json`: Current state of reminders from your vault's list in Apple Reminders
- `._RemindersMapping.json`: Mappings between Obsidian task IDs and Apple Reminder IDs

### ExportOtherReminders Files:
- `._RemindersDB.json`: State of all Apple Reminders with their IDs
- `._LocalDB.json`: State of tasks from `_AppleReminders.md`
- `_AppleReminders.md`: Tasks synced with Apple Reminders (outside vault-named list)

## Permissions Note

When running these tools for the first time, macOS will request permission to access your Reminders. If you're using a non-native terminal emulator (like VS Code's integrated terminal, iTerm2, etc.), you might encounter issues where the permission prompt never appears. If this happens, try running the command in the native macOS Terminal app instead.

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3) - see the [LICENSE](LICENSE) file for details.

The GPLv3 is a strong copyleft license that ensures the software remains free and open source. It grants you the freedom to:
- Use the software for any purpose
- Study how the program works and modify it
- Redistribute copies
- Distribute modified versions

Any modifications or derivative works must also be licensed under GPLv3.

## Notes

- Both tools require permission to access Apple Reminders
- Task IDs are preserved across syncs using the mapping files
- Files starting with `._` in your vault are used for state management
- RemindersSync only interacts with the Apple Reminders list that matches your vault name
- ExportOtherReminders handles all other reminders through `_AppleReminders.md`

## Installation

There are two ways to install RemindersSync:

### Method 1: Quick Start (Development)

1. Clone this repository:
```bash
git clone https://github.com/vatsalag09/RemindersSync.git
cd RemindersSync
```

2. Run any of the commands directly with Swift:
```bash
swift run RemindersSync /path/to/vault            # Full two-way sync
swift run ScanVault /path/to/vault            # One-way sync
swift run ExportOtherReminders /path/to/vault # Export only
```

### Method 2: System Installation

For easier access, you can install the tools system-wide:

1. Build a release version:
```bash
cd /path/to/RemindersSync
swift build -c release
```

2. Copy the executables to your local bin:
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
obsidian-reminders /path/to/vault  # Full two-way sync
obsidian-scan /path/to/vault       # One-way sync
obsidian-export /path/to/vault     # Export only
```

### Optional: Create Aliases

Add these to your `~/.zshrc` or `~/.bashrc`:
```bash
alias sync-obsidian='obsidian-reminders "/Users/your-username/path/to/your/vault"'
alias scan-obsidian='obsidian-scan "/Users/your-username/path/to/your/vault"'
alias export-reminders='obsidian-export "/Users/your-username/path/to/your/vault"'
```

Then run:
```bash
source ~/.zshrc  # or source ~/.bashrc for bash users
```

Now you can simply type:
```bash
sync-obsidian      # Full two-way sync
scan-obsidian      # One-way sync
export-reminders   # Export only
```

### Permissions

On first run, you'll need to grant RemindersSync permission to access your Reminders:

1. macOS will prompt you to allow access
2. Click "OK" to grant permission
3. If you miss the prompt, go to:
   - System Settings → Privacy & Security → Reminders
   - Enable RemindersSync

### Verifying Installation

To verify everything is working:

1. Create a test task in your vault:
```markdown
- [ ] Test task
```

2. Run the sync:
```bash
obsidian-reminders /path/to/vault
```

3. Check Apple Reminders - you should see:
   - A new list with your vault's name
   - The test task with a link back to your vault

### Troubleshooting

If you encounter permission issues:
1. Check System Settings → Privacy & Security → Reminders
2. Ensure RemindersSync has permission
3. Try removing and re-granting permission if needed

If the sync isn't working:
1. Check the console output for error messages
2. Verify the vault path is correct
3. Ensure your markdown files have the correct task format: `- [ ] Task text`