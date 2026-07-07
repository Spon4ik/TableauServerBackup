# Tableau Server Backup

Windows PowerShell 5.1 automation for Tableau Server backups through TSM.

The project is intentionally safe to clone and pull from Git. Git contains scripts, docs, and tests only. Real server paths, mail addresses, SMTP hosts, retention choices, and other local configuration are stored in environment variables on the Tableau Server machine, not in tracked files.

## First Setup

Run from an elevated PowerShell session on the Tableau Server machine:

```powershell
.\scripts\Setup-TableauServerBackup.ps1 -Interactive -Scope Machine
```

To change existing values later:

```powershell
.\scripts\Setup-TableauServerBackup.ps1 -Interactive -Scope Machine -Reconfigure
```

The setup script keeps existing values by default. It overwrites only when `-Reconfigure` or `-Force` is supplied.

## Required Configuration

Required:

- `TABLEAU_SERVER_DATA_DIR`: Tableau Server data root, usually the directory that contains `data\tabsvc`.
- `TABLEAU_BACKUP_ROOT`: destination root for `backups`, `log`, and `settings`.

Optional:

- `TABLEAU_BACKUP_MAIL_ENABLED`
- `TABLEAU_BACKUP_MAIL_SMTP_SERVER`
- `TABLEAU_BACKUP_MAIL_SMTP_PORT`
- `TABLEAU_BACKUP_MAIL_USE_SSL`
- `TABLEAU_BACKUP_MAIL_FROM`
- `TABLEAU_BACKUP_MAIL_TO`
- `TABLEAU_BACKUP_RETENTION_DAYS`
- `TABLEAU_BACKUP_MAINTENANCE_CLEANUP_ENABLED`
- `TABLEAU_BACKUP_HTTP_REQUESTS_CLEANUP_ENABLED`
- `TABLEAU_BACKUP_REINDEX_ENABLED`

## Running

Task Scheduler should run:

```text
Program/script: <project-folder>\TableauServerBackup.bat
Start in:       <project-folder>
```

Enable:

- Run whether user is logged on or not
- Run with highest privileges

Manual test modes:

```powershell
.\TableauServerBackup.bat -EmailOnlyTest
.\TableauServerBackup.bat -DryRun
```

This development PC does not need Tableau Server installed. Live TSM backup testing must happen on the Tableau Server machine.

## Git Hygiene

Before publishing:

```powershell
.\scripts\Test-GitHygiene.ps1
```

The scan blocks non-example emails and common secret keys in files that would be candidates for Git.

## Versioning

This project uses Semantic Versioning. Git release tags use `vMAJOR.MINOR.PATCH`, starting with `v0.1.0`.

## Roadmap

- Keep configuration outside Git.
- Add or update tests before changing behavior.
- Keep maintenance steps configurable.
- Improve scheduler installation automation after the core script is stable on the real Tableau host.
