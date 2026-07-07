# Changelog

This project uses Semantic Versioning with Git tags in the form `vMAJOR.MINOR.PATCH`.

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
