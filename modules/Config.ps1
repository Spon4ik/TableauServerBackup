Set-StrictMode -Version 2.0

function Test-ConfigEmpty {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $true
    }

    return [string]::IsNullOrWhiteSpace([string]$Value)
}

function ConvertTo-ConfigBoolean {
    param(
        [AllowNull()]
        $Value,

        [bool]$DefaultValue = $false
    )

    if ($null -eq $Value) {
        return $DefaultValue
    }

    if ($Value -is [bool]) {
        return $Value
    }

    $text = ([string]$Value).Trim()

    if ($text -match '^(1|true|yes|y|on)$') {
        return $true
    }

    if ($text -match '^(0|false|no|n|off)$') {
        return $false
    }

    return $DefaultValue
}

function Get-ConfigInt {
    param(
        [AllowNull()]
        $Value,

        [int]$DefaultValue
    )

    if (Test-ConfigEmpty $Value) {
        return $DefaultValue
    }

    try {
        return [int]$Value
    }
    catch {
        return $DefaultValue
    }
}

function Get-BackupRuntimeConfig {
    $backupRoot = $env:TABLEAU_BACKUP_ROOT

    if (Test-ConfigEmpty $backupRoot) {
        $backupRoot = $env:TableauServerBackup
    }

    return [pscustomobject]@{
        TableauServerDataDir        = $env:TABLEAU_SERVER_DATA_DIR
        BackupRoot                  = $backupRoot
        MailEnabled                 = ConvertTo-ConfigBoolean -Value $env:TABLEAU_BACKUP_MAIL_ENABLED -DefaultValue $false
        MailSmtpServer              = $env:TABLEAU_BACKUP_MAIL_SMTP_SERVER
        MailSmtpPort                = Get-ConfigInt -Value $env:TABLEAU_BACKUP_MAIL_SMTP_PORT -DefaultValue 25
        MailUseSsl                  = ConvertTo-ConfigBoolean -Value $env:TABLEAU_BACKUP_MAIL_USE_SSL -DefaultValue $false
        MailFrom                    = $env:TABLEAU_BACKUP_MAIL_FROM
        MailTo                      = $env:TABLEAU_BACKUP_MAIL_TO
        MailCc                      = $env:TABLEAU_BACKUP_MAIL_CC
        MailBcc                     = $env:TABLEAU_BACKUP_MAIL_BCC
        MailSubjectPrefix           = if (Test-ConfigEmpty $env:TABLEAU_BACKUP_MAIL_SUBJECT_PREFIX) { '[Tableau Backup]' } else { $env:TABLEAU_BACKUP_MAIL_SUBJECT_PREFIX }
        MailDeliveryNotification    = $env:TABLEAU_BACKUP_MAIL_DELIVERY_NOTIFICATION
        RetentionDays               = Get-ConfigInt -Value $env:TABLEAU_BACKUP_RETENTION_DAYS -DefaultValue 5
        TableauLogRetentionDays     = Get-ConfigInt -Value $env:TABLEAU_BACKUP_TABLEAU_LOG_RETENTION_DAYS -DefaultValue 7
        MaintenanceCleanupEnabled   = ConvertTo-ConfigBoolean -Value $env:TABLEAU_BACKUP_MAINTENANCE_CLEANUP_ENABLED -DefaultValue $true
        HttpRequestsCleanupEnabled  = ConvertTo-ConfigBoolean -Value $env:TABLEAU_BACKUP_HTTP_REQUESTS_CLEANUP_ENABLED -DefaultValue $false
        HttpRequestsRetentionDays   = Get-ConfigInt -Value $env:TABLEAU_BACKUP_HTTP_REQUESTS_RETENTION_DAYS -DefaultValue 730
        ReindexEnabled              = ConvertTo-ConfigBoolean -Value $env:TABLEAU_BACKUP_REINDEX_ENABLED -DefaultValue $false
    }
}

function Assert-BackupRuntimeConfig {
    param(
        [Parameter(Mandatory = $true)]
        $Config
    )

    $missing = @()

    if (Test-ConfigEmpty $Config.TableauServerDataDir) {
        $missing += 'TABLEAU_SERVER_DATA_DIR'
    }

    if (Test-ConfigEmpty $Config.BackupRoot) {
        $missing += 'TABLEAU_BACKUP_ROOT'
    }

    if (@($missing).Count -gt 0) {
        throw "Required configuration is missing: $($missing -join ', '). Run scripts\Setup-TableauServerBackup.ps1."
    }
}

function ConvertTo-MailSettingsFromEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        $Config
    )

    [pscustomobject]@{
        Enabled = [bool]$Config.MailEnabled
        Smtp = [pscustomobject]@{
            Server = $Config.MailSmtpServer
            Port = [int]$Config.MailSmtpPort
            UseSsl = [bool]$Config.MailUseSsl
        }
        From = $Config.MailFrom
        To = $Config.MailTo
        Cc = $Config.MailCc
        Bcc = $Config.MailBcc
        SubjectPrefix = $Config.MailSubjectPrefix
        DeliveryNotificationOption = $Config.MailDeliveryNotification
    }
}

function ConvertTo-MaskedConfigSummary {
    param(
        [Parameter(Mandatory = $true)]
        $Config
    )

    $mailTargetCount = 0
    if (-not (Test-ConfigEmpty $Config.MailTo)) {
        $mailTargetCount = @(([string]$Config.MailTo) -split '[;,]' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
    }

    return [pscustomobject]@{
        TableauServerDataDir       = $Config.TableauServerDataDir
        BackupRoot                 = $Config.BackupRoot
        MailEnabled                = $Config.MailEnabled
        MailSmtpServerConfigured   = -not (Test-ConfigEmpty $Config.MailSmtpServer)
        MailFromConfigured         = -not (Test-ConfigEmpty $Config.MailFrom)
        MailToCount                = $mailTargetCount
        RetentionDays              = $Config.RetentionDays
        TableauLogRetentionDays    = $Config.TableauLogRetentionDays
        MaintenanceCleanupEnabled  = $Config.MaintenanceCleanupEnabled
        HttpRequestsCleanupEnabled = $Config.HttpRequestsCleanupEnabled
        HttpRequestsRetentionDays  = $Config.HttpRequestsRetentionDays
        ReindexEnabled             = $Config.ReindexEnabled
    }
}
