# RemindersSync

A Swift-based tool to sync Obsidian tasks with Apple Reminders. Tasks are synced bidirectionally, meaning tasks marked as completed in either system will be reflected in the other.

## Features

- Bidirectional sync of tasks between Obsidian and Apple Reminders
- Maintains task completion status across both systems
- Exports non-synced reminders to a markdown file
- Preserves task IDs and mappings between systems
- Handles task due dates

## Available Commands

The package includes three command-line tools:

1. **RemindersSync**: Full two-way sync (recommended)
   - Syncs tasks from Obsidian to Reminders
   - Syncs completion status both ways
   - Exports other reminders to markdown
   ```bash
   swift run RemindersSync /path/to/vault
   ```

2. **ScanVaultCLI**: One-way sync from Obsidian to Reminders
   - Only syncs tasks from Obsidian to Reminders
   - Does not sync completion status
   - Does not export other reminders
   ```bash
   swift run ScanVaultCLI /path/to/vault
   ```

3. **ExportOtherRemindersCLI**: Export non-synced reminders
   - Exports reminders to `_AppleReminders.md`
   - Does not sync tasks
   ```bash
   swift run ExportOtherRemindersCLI /path/to/vault
   ```

## How it Works

The sync process works in three main steps:

1. **Task State Management**:
   - Scans Obsidian vault for tasks and saves their state to `._VaultTasks.json`
   - Fetches Apple Reminders and saves their state to `._Reminders.json`
   - Uses `._RemindersMapping.json` to maintain mappings between Obsidian tasks and Apple Reminders

2. **Completion Status Sync** (RemindersSync only):
   - Compares task completion status in both systems
   - If a task is marked as completed in either system, it's marked as completed in both
   - Uses unique IDs to ensure reliable task matching

3. **Other Reminders Export** (RemindersSync and ExportOtherRemindersCLI):
   - Exports reminders from non-synced lists to `_AppleReminders.md`
   - Excludes certain lists (e.g., "Groceries", "Shopping")

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
swift run ScanVaultCLI /path/to/vault            # One-way sync
swift run ExportOtherRemindersCLI /path/to/vault # Export only
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
sudo cp .build/release/ScanVaultCLI /usr/local/bin/obsidian-scan
sudo cp .build/release/ExportOtherRemindersCLI /usr/local/bin/obsidian-export
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

## State Files

The tool maintains several state files in your vault:

- `._VaultTasks.json`: Current state of all tasks in your Obsidian vault
- `._Reminders.json`: Current state of relevant reminders from Apple Reminders
- `._RemindersMapping.json`: Mappings between Obsidian task IDs and Apple Reminder IDs
- `_AppleReminders.md`: Exported non-synced reminders

These files help maintain sync state and ensure reliable task matching between systems.

## Excluded Lists

By default, the following reminder lists are excluded from syncing:
- Groceries
- Shopping
- Cooking-HouseHold
- Your vault name (to avoid circular syncs)

## Notes

- The tool requires permission to access Apple Reminders
- Task IDs are preserved across syncs using the mapping file
- Files starting with `._` in your vault are used for state management