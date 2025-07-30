# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

```bash
# Run the main bidirectional sync tool
swift run RemindersSync /path/to/vault

# Run one-way vault scan (Obsidian → Reminders only)
swift run ScanVault /path/to/vault

# Run the export tool for non-vault reminders
swift run ExportOtherReminders /path/to/vault
swift run ExportOtherReminders /path/to/vault --cleanup  # Clean duplicate IDs

# Clean vault for fresh sync (removes IDs and completed tasks)
swift run ReSyncReminders /path/to/vault

# Remove only completed tasks (preserves incomplete tasks with IDs)
swift run CleanUp /path/to/vault

# Build release version
swift build -c release

# No test targets defined yet
```

## Architecture Overview

RemindersSync is a Swift Package Manager project with five CLI executables sharing a common core library:

1. **RemindersSyncCore** - Shared library containing all synchronization logic
   - `ObsidianTask` struct for task representation
   - `TaskMapping` and `TaskMappingStore` for ID management
   - Task parsing/scanning functions using regex
   - EventKit integration for Apple Reminders

2. **RemindersSync** - Main bidirectional sync between vault tasks and vault-named Reminders list
   - Syncs completion status both ways
   - Excludes tasks with `#cl` tag
   - Creates `._RemindersMapping.json` for ID tracking

3. **ScanVault** - One-way sync from Obsidian to Reminders
   - No completion status sync back
   - Uses same task filtering as main tool

4. **ExportOtherReminders** - Manages non-vault reminders in `_AppleReminders.md`
   - Two-way sync with all Reminders lists except vault list
   - Auto-creates new tasks in Inbox
   - Creates `._TaskDB.json` and `._ConsolidatedIds.json`

5. **ReSyncReminders** - Clean vault for fresh sync
   - Removes all task IDs (^ID and <!-- id: ID -->)
   - Removes all completed tasks
   - Deletes all state files (._RemindersMapping.json, ._TaskDB.json, ._ConsolidatedIds.json)

6. **CleanUp** - Remove completed tasks only
   - Runs RemindersSync first to synchronize systems
   - Removes completed tasks from vault and Apple Reminders
   - Preserves incomplete tasks with their IDs
   - Updates mapping file appropriately

## Key Implementation Details

- **Task Format Regex**: Supports multiple formats including `- [ ] Task`, `- [ ] Task ^ID`, `- [ ] Task <!-- id: ID -->`
- **ID Management**: Uses UUIDs to maintain stable mappings between Obsidian and Reminders
- **Permissions**: Requires EventKit authorization - handle permission prompts appropriately
- **State Files**: All state files use `.` prefix to hide them from Obsidian's file explorer
- **Error Handling**: Comprehensive try-catch blocks with descriptive error messages
- **Task Filtering**: Tasks containing `#cl` tag are automatically excluded from all sync operations

## Development Notes

- Platform requirement: macOS 13+ (Ventura)
- Swift version: 5.9+
- No external dependencies - uses only Apple frameworks
- All file paths must be absolute when passed to CLI tools
- Batch operations used for performance (save mappings after all changes)