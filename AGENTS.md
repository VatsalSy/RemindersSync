# Repository Guidelines

## Project Structure & Module Organization
RemindersSync is a Swift Package managed by `Package.swift`. Core sync logic and shared models live in `Sources/RemindersSyncCore`, while each CLI tool sits in `Sources/<ToolName>CLI` (e.g., `Sources/SwiftRemindersCLI`). Automated scripts such as `install.sh` and `uninstall.sh` wrap release builds for system installs, and `TestVault/` supplies sample Markdown reminders for manual dry runs. Contributor tooling and historical agent specs reside outside this tree; keep edits to this repo focused on the Swift package.

## Build, Test, and Development Commands
Use `swift build` to compile all targets and surface compiler diagnostics. Run `swift run RemindersSync /path/to/vault` for the primary Obsidian↔︎Reminders sync; swap the target name to reach utilities like `ScanVault`, `ExportOtherReminders`, `ReSyncReminders`, or `CleanUp`. Execute `swift test` (optionally with `--parallel`) to exercise `RemindersSyncCoreTests`. Install release binaries with `sudo ./install.sh`; uninstall via `sudo ./uninstall.sh`. Favor `swift run ExportOtherReminders --help` to review cleanup and reset flags before destructive operations.

## Coding Style & Naming Conventions
Target Swift 5.9. Follow four-space indentation and the Swift API Design Guidelines: `UpperCamelCase` for types, `lowerCamelCase` for functions and properties. Keep CLI targets suffixed with `CLI`, and favor structs plus protocol-backed integrations for testability. Avoid hardcoded absolute paths; accept vault locations via arguments.

## Testing Guidelines
Unit coverage lives under `Tests/RemindersSyncCoreTests` with `test_<Scenario>_<Expectation>` naming. Add focused cases whenever sync logic changes, and prefer deterministic fixtures. For larger shifts, run `swift test --enable-code-coverage` and inspect results in Xcode. Validate integration flows against `TestVault/` before touching live data, and document any manual reproduction steps in PRs.

## Commit & Pull Request Guidelines
Write imperative commit subjects under ~50 characters (e.g., `Add resync shortcut`). Summaries should mention motivation plus relevant CLI output when behavior changes. Pull requests must describe affected tools, list validation commands (`swift run RemindersSync TestVault`), link issues, and flag permissions or migration steps. Confirm CI’s Agent Consistency Check passes before requesting review.

## Security & Configuration Tips
Never commit vault paths, Apple IDs, or credentials. Prefer environment variables and CLI flags for secrets. macOS prompts for Reminders access on first run—use the native Terminal so the dialog appears. Audit release binaries after running `install.sh`, and restrict distribution to trusted environments.
