using TableauServerBackup.Gui.Models;

namespace TableauServerBackup.Gui.Services;

public sealed class EnvironmentSettingsService
{
    public IReadOnlyList<SettingEntry> CreateSettings() =>
    [
        new("TABLEAU_SERVER_DATA_DIR", "Tableau Server data directory", "The folder that contains data\\tabsvc."),
        new("TABLEAU_BACKUP_ROOT", "Backup root directory", "The root for backups, logs, and exported settings."),
        new("TABLEAU_BACKUP_RETENTION_DAYS", "Backup retention days", "Age limit and final maximum backup-file count."),
        new("TABLEAU_BACKUP_MINIMUM_BACKUP_FILES_TO_KEEP", "Minimum backup files", "Safety count retained even when backups are old."),
        new("TABLEAU_BACKUP_SETTINGS_RETENTION_DAYS", "Settings retention days", "Use 0 to keep exported settings indefinitely."),
        new("TABLEAU_BACKUP_MAINTENANCE_CLEANUP_ENABLED", "Maintenance cleanup", "Run Tableau maintenance cleanup before backup.", true),
        new("TABLEAU_BACKUP_TABLEAU_LOG_RETENTION_DAYS", "Tableau log retention days", "Age limit for Tableau logs."),
        new("TABLEAU_BACKUP_HTTP_REQUESTS_CLEANUP_ENABLED", "HTTP request cleanup", "Remove old HTTP request records.", true),
        new("TABLEAU_BACKUP_HTTP_REQUESTS_RETENTION_DAYS", "HTTP request retention days", "Age limit for HTTP request records."),
        new("TABLEAU_BACKUP_REINDEX_ENABLED", "Reindex search", "Run Tableau search reindexing.", true),
        new("TABLEAU_BACKUP_MAIL_ENABLED", "Enable email notifications", "Send status mail after the backup run.", true),
        new("TABLEAU_BACKUP_MAIL_SMTP_SERVER", "SMTP server", "Mail relay hostname or address."),
        new("TABLEAU_BACKUP_MAIL_SMTP_PORT", "SMTP port", "Usually 25, 465, or 587."),
        new("TABLEAU_BACKUP_MAIL_USE_SSL", "Use SMTP SSL", "Use SSL/TLS for SMTP.", true),
        new("TABLEAU_BACKUP_MAIL_FROM", "Mail from", "Sender address."),
        new("TABLEAU_BACKUP_MAIL_TO", "Mail to", "Comma- or semicolon-separated recipients."),
        new("TABLEAU_BACKUP_MAIL_CC", "Mail Cc", "Optional comma- or semicolon-separated recipients."),
        new("TABLEAU_BACKUP_MAIL_BCC", "Mail Bcc", "Optional comma- or semicolon-separated recipients."),
        new("TABLEAU_BACKUP_MAIL_SUBJECT_PREFIX", "Mail subject prefix", "Prefix used in status-message subjects."),
        new("TABLEAU_BACKUP_MAIL_DELIVERY_NOTIFICATION", "Delivery notification", "Optional SMTP delivery notification setting.")
    ];

    public void Load(IEnumerable<SettingEntry> settings, EnvironmentVariableTarget target)
    {
        foreach (var setting in settings)
        {
            setting.Value = Environment.GetEnvironmentVariable(setting.EnvironmentVariable, target) ?? string.Empty;
        }
    }

    public void Save(IEnumerable<SettingEntry> settings, EnvironmentVariableTarget target)
    {
        foreach (var setting in settings)
        {
            Environment.SetEnvironmentVariable(
                setting.EnvironmentVariable,
                string.IsNullOrWhiteSpace(setting.Value) ? null : setting.Value.Trim(),
                target);
        }
    }

    public static IReadOnlyList<string> Validate(IEnumerable<SettingEntry> settings)
    {
        var values = settings.ToDictionary(entry => entry.EnvironmentVariable, entry => entry.Value.Trim(), StringComparer.OrdinalIgnoreCase);
        var errors = new List<string>();

        foreach (var required in new[] { "TABLEAU_SERVER_DATA_DIR", "TABLEAU_BACKUP_ROOT" })
        {
            if (string.IsNullOrWhiteSpace(values[required]))
            {
                errors.Add($"{required} is required.");
            }
        }

        foreach (var number in new[]
                 {
                     "TABLEAU_BACKUP_RETENTION_DAYS",
                     "TABLEAU_BACKUP_MINIMUM_BACKUP_FILES_TO_KEEP",
                     "TABLEAU_BACKUP_SETTINGS_RETENTION_DAYS",
                     "TABLEAU_BACKUP_TABLEAU_LOG_RETENTION_DAYS",
                     "TABLEAU_BACKUP_HTTP_REQUESTS_RETENTION_DAYS"
                 })
        {
            if (!string.IsNullOrWhiteSpace(values[number]) && (!int.TryParse(values[number], out var parsed) || parsed < 0))
            {
                errors.Add($"{number} must be a whole number greater than or equal to zero.");
            }
        }

        if (!string.IsNullOrWhiteSpace(values["TABLEAU_BACKUP_MAIL_SMTP_PORT"])
            && (!int.TryParse(values["TABLEAU_BACKUP_MAIL_SMTP_PORT"], out var port) || port is < 1 or > 65535))
        {
            errors.Add("TABLEAU_BACKUP_MAIL_SMTP_PORT must be between 1 and 65535.");
        }

        return errors;
    }
}
