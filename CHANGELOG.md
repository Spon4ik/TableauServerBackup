# Changelog

This project uses Semantic Versioning with Git tags in the form `vMAJOR.MINOR.PATCH`.

## v0.4.3 - 2026-07-13

Windows Server compatibility fix release.

- Retargeted the self-contained WPF GUI to .NET 8 LTS after .NET 10 crashed before its first window opened on Windows Server 2019 (build 17763).
- Updated GUI build requirements so an existing .NET 8 SDK can publish the executable.

## v0.4.2 - 2026-07-13

GUI build-instructions release.

- Clarified the required .NET 10 SDK and correct self-contained publish commands from both supported working directories.

## v0.4.1 - 2026-07-13

Code-signing roadmap release.

- Added an Authenticode signing and verification milestone for published GUI releases.

## v0.4.0 - 2026-07-13

Local Windows configuration app release.

- Added a self-contained x64 WPF app for viewing and editing every environment-backed backup setting with grouped text fields and checkboxes.
- Added secure local Windows Task Scheduler inspection, preview, create/update, enable, disable, and removal from the app.
- Added GUI build verification to project checks and documented publishing, accessibility, scope, and credential behavior.

## v0.3.0 - 2026-07-13

Scheduled-task management release.

- Added setup CLI actions to inspect, preview, create/update, enable, disable, and remove the Tableau Server Backup scheduled task.
- Added daily schedule configuration and secure credential prompting for unattended task registration; the script never writes or logs the supplied password.
- Exposed all supported mail environment variables through interactive and non-interactive setup.
- Added scheduler management documentation and Pester coverage for task definitions and no-side-effect previews.

## v0.2.10 - 2026-07-13

Local Windows GUI roadmap release.

- Added the staged CLI scheduler-management and self-contained WPF configuration-app direction to the roadmap.
- Defined the GUI as a local-only Windows Server administration tool that keeps the CLI authoritative and avoids backend, Docker, paid subscriptions, and tracked local configuration.

## v0.2.9 - 2026-07-12

Roadmap consolidation release.

- Removed the stale duplicate roadmap from the README.
- Made `docs/ROADMAP.md` the sole roadmap source and linked to it from the README.

## v0.2.8 - 2026-07-12

Roadmap refresh release.

- Updated the current-capabilities roadmap through the work shipped in v0.2.7.
- Clarified the scope of configuration, retention, logging, simulation, and automated test coverage.

## v0.2.7 - 2026-07-09

Backup progress and final retention release.

- Apply a second retention pass after a successful backup is moved so the final backup folder count matches the configured retention value.
- Stream Tableau backup command output into the app log while the backup command is still running.
- Add a periodic heartbeat log line when a long-running command produces no output for five minutes.
- Clarified setup and documentation wording for backup retention versus settings retention.

## v0.2.6 - 2026-07-09

Settings retention release.

- Preserve exported Tableau settings files by default instead of deleting them with backup retention.
- Added `TABLEAU_BACKUP_SETTINGS_RETENTION_DAYS` to optionally delete very old settings files when set to a positive number.
- Added interactive and non-interactive setup support for settings retention days.

## v0.2.5 - 2026-07-09

Configurable retention safety release.

- Added `TABLEAU_BACKUP_MINIMUM_BACKUP_FILES_TO_KEEP` as the environment-backed setting for the minimum retained `.tsbak` safety count.
- Added interactive and non-interactive setup support for configuring the minimum backup file count.
- Logged the configured minimum backup file count in the runtime config summary.

## v0.2.4 - 2026-07-09

Retention safety and notification detail release.

- Apply backup retention before creating a new Tableau backup so old files can free space first.
- Preserve at least two `.tsbak` files during retention to avoid deleting every fallback backup after repeated failures.
- Include actionable disk-space failure lines from the run log in failed status emails.

## v0.2.3 - 2026-07-07

Release process guidance release.

- Clarified that keeping GitHub current requires a pushed branch, pushed release tag, and GitHub Release object.
- Required GitHub Release notes to come from the matching changelog entry unless overridden by the user.
- Required release completion verification against the GitHub Release URL.

## v0.2.2 - 2026-07-07

Notification content release.

- Removed SMTP relay delivery caveats from composed status emails.
- Kept SMTP handoff caveats in log and interactive console output after successful submission.
- Improved status email wording for normal, dry-run, failure, and email-only-test runs.
- Added repo-local agent guidance for version bumps, checks, and local commits.

## v0.2.1 - 2026-07-07

Cleanup release.

- Removed the obsolete `config/MailSettings.example.json` file.
- Updated documentation and tests to reflect environment-only mail configuration.
- Removed stale `MailSettings.json` wording from mail validation messages.

## v0.2.0 - 2026-07-06

Backward-compatible configuration release.

- Added interactive setup prompts for maintenance cleanup, Tableau log retention, HTTP requests cleanup, HTTP requests retention, and search reindexing.
- Added non-interactive setup parameters for the same maintenance options.
- Added HTTP requests and Tableau log retention values to the masked runtime config summary.
- Added test coverage for the new setup environment variables.

## v0.1.0 - 2026-07-03

Initial public-safe release.

- Added environment-variable based setup and reconfiguration.
- Kept real runtime configuration outside Git.
- Added Tableau backup orchestration, maintenance, retention, notification, and logging scripts.
- Added local simulation mode for machines without Tableau Server.
- Added project checks, Pester tests, and Git hygiene scanning.
- Added setup, scheduler, troubleshooting, security, goal, and roadmap documentation.
