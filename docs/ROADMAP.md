# Roadmap

## Current

- Environment-variable setup and reconfiguration for backup, maintenance, retention, and email settings.
- Public-safe repository contents with Git hygiene checks that keep server-specific configuration out of source control.
- Tableau maintenance, settings export, backup creation, email notification, and local simulation workflows.
- Backup retention before creation and after a successful move, with a configurable minimum safety count.
- Independent settings-file retention, preserving exported settings by default.
- Live TSM backup output in the application log, with heartbeat messages during quiet long-running commands.
- Pester coverage for setup, configuration, retention, hygiene, parser health, and simulation output.
- Setup CLI support for every runtime setting plus scheduled-task inspection, preview, create/update, enable, disable, and removal.
- A self-contained local x64 WPF configuration app for Windows Server 2019+ with grouped settings editing and Windows scheduled-task management.

## Next

- Add an Authenticode code-signing release workflow for the published GUI executable: keep the certificate outside Git, timestamp each signature, publish a SHA-256 checksum, and fail release validation unless `Get-AuthenticodeSignature` reports a valid signature.
- Add mocked TSM command tests for command-line arguments and exit-code mapping.
- Add log rotation for very large daily logs.
- Add restore-drill documentation for operators.

## Later

- Add signed-script guidance for stricter Windows execution policies.
- Add richer notification options if email alone becomes insufficient.
