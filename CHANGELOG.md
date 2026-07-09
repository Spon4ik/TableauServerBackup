# Changelog

This project uses Semantic Versioning with Git tags in the form `vMAJOR.MINOR.PATCH`.

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
