# Configuration

Runtime configuration lives in environment variables, not tracked JSON files.

Use first-time setup:

```powershell
.\scripts\Setup-TableauServerBackup.ps1 -Interactive -Scope Machine
```

Use reconfiguration:

```powershell
.\scripts\Setup-TableauServerBackup.ps1 -Interactive -Scope Machine -Reconfigure
```

The setup script keeps existing values unless `-Reconfigure` or `-Force` is used.

## Required

- `TABLEAU_SERVER_DATA_DIR`: Tableau Server data directory.
- `TABLEAU_BACKUP_ROOT`: root folder where this project writes `backups`, `log`, and `settings`.

## Optional

- `TABLEAU_BACKUP_RETENTION_DAYS`
- `TABLEAU_BACKUP_MAIL_ENABLED`
- `TABLEAU_BACKUP_MAIL_SMTP_SERVER`
- `TABLEAU_BACKUP_MAIL_SMTP_PORT`
- `TABLEAU_BACKUP_MAIL_USE_SSL`
- `TABLEAU_BACKUP_MAIL_FROM`
- `TABLEAU_BACKUP_MAIL_TO`
- `TABLEAU_BACKUP_MAIL_CC`
- `TABLEAU_BACKUP_MAIL_BCC`
- `TABLEAU_BACKUP_MAIL_SUBJECT_PREFIX`
- `TABLEAU_BACKUP_MAIL_DELIVERY_NOTIFICATION`
- `TABLEAU_BACKUP_MAINTENANCE_CLEANUP_ENABLED`
- `TABLEAU_BACKUP_TABLEAU_LOG_RETENTION_DAYS`
- `TABLEAU_BACKUP_HTTP_REQUESTS_CLEANUP_ENABLED`
- `TABLEAU_BACKUP_HTTP_REQUESTS_RETENTION_DAYS`
- `TABLEAU_BACKUP_REINDEX_ENABLED`

`config/MailSettings.example.json` documents the old JSON shape for reference only. The real script reads mail settings from environment variables.

