# RemindersSync

A Swift-based tool to sync Obsidian tasks with Apple Reminders. Tasks are synced bidirectionally between your Obsidian vault and a dedicated Apple Reminders list (with the same name as your vault).

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
   ```bash
   swift run RemindersSync /path/to/vault
   ```

2. **ScanVault**: One-way sync from Obsidian to Reminders
   - Only syncs tasks from Obsidian to Reminders
   - Does not sync completion status
   ```bash
   swift run ScanVault /path/to/vault
   ```

3. **ExportOtherReminders**: Two-way sync for other reminders
   - Maintains tasks in `_AppleReminders.md`
   - Syncs completion status both ways
   - Stores task IDs in both systems for reliable syncing
   - Creates missing tasks in Inbox list if found in `_AppleReminders.md`
   ```bash
   # Regular sync
   swift run ExportOtherReminders /path/to/vault

   # Clean up IDs (if needed)
   swift run ExportOtherReminders /path/to/vault --cleanup
   ```

### ExportOtherReminders Details

The `ExportOtherReminders` tool provides a robust sync between Apple Reminders and a markdown file:

#### Features
- Two-way completion status sync
- Preserves task organization by list
- Maintains unique IDs for reliable syncing
- Handles both new and existing tasks
- Cleans up duplicate entries

#### Excluded Lists
By default, the following lists are excluded from sync:
- Groceries
- Shopping
- Cooking-HouseHold
- obsidian
- Your vault name (to avoid conflicts with RemindersSync)

#### File Structure
- `_AppleReminders.md`: Main file containing all synced tasks
  - Organized by sections using `## List Name` headers
  - Each task includes a unique ID: `- [ ] Task text ^UUID`
  - Tasks without a section go to "Inbox"

#### State Files
- `._RemindersDB.json`: Current state of Apple Reminders
- `._LocalDB.json`: Current state of tasks from `_AppleReminders.md`

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

1. **Task Scanning**:
   - Scans Apple Reminders (excluding specified lists)
   - Scans `_AppleReminders.md`
   - Maintains unique IDs for each task

2. **Completion Sync**:
   - If a task is marked complete in either system, it's marked complete in both
   - Syncs status bidirectionally

3. **Task Organization**:
   - Tasks are organized by their list in Apple Reminders
   - Tasks from `_AppleReminders.md` maintain their section headers
   - New tasks without a list go to "Inbox"

4. **ID Management**:
   - Each task has a unique UUID
   - IDs are stored in Apple Reminders notes field
   - IDs are preserved in markdown using the `^UUID` format

#### Best Practices

1. Run `--cleanup` if you notice duplicate tasks
2. Let the tool manage the `_AppleReminders.md` file structure
3. Use list names in Apple Reminders to organize tasks
4. Don't manually edit task IDs

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