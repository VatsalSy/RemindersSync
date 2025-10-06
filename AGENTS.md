# Repository Guidelines

## Project Structure & Module Organization
RemindersSync is a Swift Package defined by `Package.swift`. Core sync logic lives in `Sources/RemindersSyncCore`, while CLI entrypoints reside in `Sources/<ToolName>CLI` (e.g., `Sources/SwiftRemindersCLI`). Tests for the core module are under `Tests/RemindersSyncCoreTests`. `install.sh` and `uninstall.sh` wrap release builds for system-wide installation, and `TestVault/` provides sample markdown data for manual verification.

## Build, Test, and Development Commands
- `swift build` compiles all targets and surfaces compiler diagnostics.
- `swift run RemindersSync /path/to/vault` performs the primary two-way Obsidian↔︎Reminders sync; swap the target name to exercise `ScanVault`, `ExportOtherReminders`, `ReSyncReminders`, or `CleanUp`.
- `swift run ExportOtherReminders --help` lists CLI flags, useful for discovering cleanup/reset options.
- `swift test` executes `RemindersSyncCoreTests`; pair with `--parallel` for faster local feedback.
- `sudo ./install.sh` installs release binaries into `/usr/local/bin`; rerun after dependency updates.

## Coding Style & Naming Conventions
Target Swift 5.9 and align with the Swift API Design Guidelines: four-space indentation, `UpperCamelCase` types, `lowerCamelCase` methods and properties. Prefer struct-based modeling in the core layer and isolate system integrations behind protocols for testability. Keep CLI targets suffixed with `CLI` to match existing module naming and expose user-facing commands through `swift run <ToolName>` or aliased binaries.

## Testing Guidelines
Extend the coverage-focused `Tests/RemindersSyncCoreTests` suite when adjusting sync logic; mirror behaviors with descriptive `test_<Scenario>_<Expectation>` methods. Use `swift test --enable-code-coverage` when validating substantial refactors, and review the generated report in Xcode. For integration changes, stage realistic markdown files in `TestVault/` and dry-run the relevant tool with `--cleanup` or `--help` before touching production data.

## Commit & Pull Request Guidelines
Write commits in the imperative mood (`Fix file path normalization`, `Add resync shortcut`) and keep subjects under ~50 characters; include a brief body explaining the motivation plus relevant CLI output when behavior changes. PRs should describe the impacted tools, list manual validation steps (`swift run RemindersSync TestVault`), link any tracked issues, and call out permissions considerations for reviewers. Request a CI run after major sync workflow adjustments to avoid regressions in release binaries.

## Security & Configuration Tips
Never hardcode vault paths, Apple IDs, or tokens; prefer arguments and environment variables consumed by the CLI wrappers. macOS will prompt for Reminders access on first run—advise contributors to use the native Terminal if third-party shells hide the dialog. Keep `install.sh` invocations scoped to trusted machines and audit resulting binaries before distribution.
