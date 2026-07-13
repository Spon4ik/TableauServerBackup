# Roadmap

## Current

- Environment-variable setup and reconfiguration for backup, maintenance, retention, and email settings.
- Public-safe repository contents with Git hygiene checks that keep server-specific configuration out of source control.
- Tableau maintenance, settings export, backup creation, email notification, and local simulation workflows.
- Backup retention before creation and after a successful move, with a configurable minimum safety count.
- Independent settings-file retention, preserving exported settings by default.
- Live TSM backup output in the application log, with heartbeat messages during quiet long-running commands.
- Pester coverage for setup, configuration, retention, hygiene, parser health, and simulation output.

## Next

- Extend the setup CLI with scheduled-task inspection, create/update, enable/disable, removal, and `WhatIf` preview support; keep every supported environment-backed setting available non-interactively.
- Add a self-contained x64 C# WPF configuration app for Windows Server 2019+ that manages the same User/Machine environment variables and scheduled-task settings through checkboxes, numeric fields, text fields, and path pickers. Keep it local-only, without a backend, Docker, paid subscription, or tracked local configuration; prompt for task credentials only when Windows requires them and never persist or log them.
- Add mocked TSM command tests for command-line arguments and exit-code mapping.
- Add log rotation for very large daily logs.
- Add restore-drill documentation for operators.

## Later

- Add signed-script guidance for stricter Windows execution policies.
- Add richer notification options if email alone becomes insufficient.
