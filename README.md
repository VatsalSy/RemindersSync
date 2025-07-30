# RemindersSync

[![License](https://img.shields.io/github/license/VatsalSy/RemindersSync)](https://github.com/VatsalSy/RemindersSync/blob/main/LICENSE)
[![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/VatsalSy/RemindersSync)](https://github.com/VatsalSy/RemindersSync/releases)
[![GitHub last commit](https://img.shields.io/github/last-commit/VatsalSy/RemindersSync)](https://github.com/VatsalSy/RemindersSync/commits/main)
[![macOS](https://img.shields.io/badge/platform-macOS-blue)](https://github.com/VatsalSy/RemindersSync#readme)

A Swift-based tool that provides bidirectional synchronization between Obsidian tasks and Apple Reminders. Tasks are synced between your Obsidian vault and a dedicated Apple Reminders list (with the same name as your vault).

If you encounter any problems or have suggestions, please open an issue on GitHub:<br>
[![GitHub issues](https://img.shields.io/github/issues/VatsalSy/RemindersSync)](https://github.com/VatsalSy/RemindersSync/issues/new/choose)

## Features

- **Bidirectional sync** between Obsidian tasks and Apple Reminders
  - Only syncs with the Apple Reminders list that matches your vault name
  - Does not affect tasks in other Reminders lists
  - Does not sync tasks found in `_AppleReminders.md`
- **Task filtering** - Tasks with the `#cl` tag are automatically excluded from syncing
- **Completion tracking** - Maintains task completion status across both systems
- **ID preservation** - Preserves task IDs and mappings between systems
- **Due date support** - Handles task due dates across platforms

## Available Commands

The package includes four command-line tools:

### 1. RemindersSync

**Full two-way sync** between vault tasks and vault-named list
- Syncs tasks between Obsidian and a dedicated Reminders list (named same as vault)
- Syncs completion status both ways
- Skips tasks with `#cl` tag
- Preserves task IDs and mappings between systems

```bash
swift run RemindersSync /path/to/vault
```

### 2. ScanVault

**One-way sync** from Obsidian to Reminders
- Only syncs tasks from Obsidian to Reminders
- Does not sync completion status back to Obsidian
- Skips tasks with `#cl` tag
- Creates tasks in the vault-named list in Apple Reminders

```bash
swift run ScanVault /path/to/vault
```

### 3. ExportOtherReminders

**Two-way sync** for non-vault reminders
- Syncs tasks between `_AppleReminders.md` and Apple Reminders (excluding vault list)
- Maintains two-way completion status sync
- Auto-creates tasks in Inbox for new entries without IDs
- Preserves list organization and due dates

```bash
# Regular sync
swift run ExportOtherReminders /path/to/vault

# Clean up IDs (if needed)
swift run ExportOtherReminders /path/to/vault --cleanup

# Get help with options
swift run ExportOtherReminders --help
```

### 4. ReSyncReminders

**Clean vault and prepare for fresh sync**
- Removes all task IDs (^ID and <!-- id: ID -->) from vault
- Removes all completed tasks (- [x] or - [X])
- Deletes the mapping file (._RemindersMapping.json)
- Prepares vault for a completely fresh sync

```bash
# Clean vault for fresh sync
swift run ReSyncReminders /path/to/vault

# After running, use RemindersSync to complete the fresh sync
swift run RemindersSync /path/to/vault
```

## Task Filtering

The tool automatically filters out tasks containing the `#cl` tag. This is useful for:
- Keeping checklist items (`#cl`) only in Obsidian
- Preventing cluttering your Reminders app with temporary checklist items

For example, these tasks will be skipped:
```markdown
- [ ] Research something #cl
- [ ] Document project with links #cl
- [ ] (Optional) Task with #cl tag
```

## ExportOtherReminders Details

The `ExportOtherReminders` tool provides a robust sync between Apple Reminders and a markdown file:

### Features
- Two-way completion status sync
- Preserves task organization by list
- Maintains unique IDs for reliable syncing
- Handles both new and existing tasks
- Cleans up duplicate entries
- Auto-creates tasks in Inbox for new entries without IDs

### Task Creation Behavior
- New tasks added to `_AppleReminders.md` without IDs:
  - Automatically created in Apple Reminders' Inbox
  - Removed from the markdown file after creation
  - Will reappear in markdown with proper ID after next sync
- New tasks with IDs:
  - Synced bidirectionally between systems
  - Maintain their list organization

### Excluded Lists
By default, the following lists are excluded from sync:
- Groceries
- Cooking-HouseHold
- obsidian
- Your vault name (to avoid conflicts with RemindersSync)
- Several others defined in the code

### File Structure
- `_AppleReminders.md`: Main file containing all synced tasks
  - Organized by sections using `## List Name` headers
  - Each task includes a unique ID: `- [ ] Task text ^UUID`
  - Tasks without a section go to "Inbox"
  - Supports due dates with YYYY-MM-DD format

### State Files
- `._TaskDB.json`: Current state of all tasks with their metadata
- `._ConsolidatedIds.json`: Mapping of task titles to their consolidated IDs

## State Files

The tools maintain several state files in your vault:

### RemindersSync Files:
- `._RemindersMapping.json`: Mappings between Obsidian task IDs and Apple Reminder IDs

### ExportOtherReminders Files:
- `._TaskDB.json`: Current state of all tasks with their metadata
- `._ConsolidatedIds.json`: Mapping of task titles to their consolidated IDs
- `_AppleReminders.md`: Tasks synced with Apple Reminders (outside vault-named list)

## Installation

There are two ways to install RemindersSync:

### Method 1: Quick Start (Development)

1. Clone this repository:
```bash
git clone https://github.com/VatsalSy/RemindersSync.git
cd RemindersSync
```

2. Run any of the commands directly with Swift:
```bash
swift run RemindersSync /path/to/vault            # Full two-way sync
swift run ScanVault /path/to/vault                # One-way sync
swift run ExportOtherReminders /path/to/vault     # Export other reminders
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
sudo cp .build/release/ReSyncReminders /usr/local/bin/obsidian-resync
```

3. Make them executable:
```bash
sudo chmod +x /usr/local/bin/obsidian-reminders
sudo chmod +x /usr/local/bin/obsidian-scan
sudo chmod +x /usr/local/bin/obsidian-export
sudo chmod +x /usr/local/bin/obsidian-resync
```

Now you can run any of the tools from anywhere:
```bash
obsidian-reminders /path/to/vault  # Full two-way sync
obsidian-scan /path/to/vault       # One-way sync
obsidian-export /path/to/vault     # Export only
obsidian-resync /path/to/vault     # Clean vault for fresh sync
```

### Optional: Create Aliases

Add these to your `~/.zshrc` or `~/.bashrc`:
```bash
alias sync-obsidian='obsidian-reminders "/Users/your-username/path/to/your/vault"'
alias scan-obsidian='obsidian-scan "/Users/your-username/path/to/your/vault"'
alias export-reminders='obsidian-export "/Users/your-username/path/to/your/vault"'
alias resync-obsidian='obsidian-resync "/Users/your-username/path/to/your/vault"'
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
resync-obsidian    # Clean vault for fresh sync
```

## Permissions Note

When running these tools for the first time, macOS will request permission to access your Reminders. If you're using a non-native terminal emulator (like VS Code's integrated terminal, iTerm2, etc.), you might encounter issues where the permission prompt never appears. If this happens, try running the command in the native macOS Terminal app instead.

## Troubleshooting

### Permission Issues
If you encounter permission issues:
1. Check System Settings → Privacy & Security → Reminders
2. Ensure RemindersSync has permission
3. Try removing and re-granting permission if needed

### Sync Problems
If the sync isn't working:
1. Check the console output for error messages
2. Verify the vault path is correct
3. Ensure your markdown files have the correct task format: `- [ ] Task text`

### Duplicate Tasks
If you're seeing duplicate tasks:
1. Run the cleanup command: `swift run ExportOtherReminders /path/to/vault --cleanup`
2. This consolidates task IDs and removes duplicates

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3) - see the [LICENSE](LICENSE) file for details.

The GPLv3 is a strong copyleft license that ensures the software remains free and open source. It grants you the freedom to:
- Use the software for any purpose
- Study how the program works and modify it
- Redistribute copies
- Distribute modified versions

Any modifications or derivative works must also be licensed under GPLv3.