#requires -version 5.1

param(
    [ValidateSet('Process', 'User', 'Machine')]
    [string]$Scope = 'Machine',

    [switch]$Interactive,
    [switch]$Reconfigure,
    [switch]$Force,
    [switch]$WhatIfOnly,

    [AllowEmptyString()]
    [string]$TableauServerDataDir = '',

    [AllowEmptyString()]
    [string]$BackupRoot = '',

    [AllowEmptyString()]
    [string]$MailEnabled = '',

    [AllowEmptyString()]
    [string]$MailSmtpServer = '',

    [AllowEmptyString()]
    [string]$MailSmtpPort = '',

    [AllowEmptyString()]
    [string]$MailUseSsl = '',

    [AllowEmptyString()]
    [string]$MailFrom = '',

    [AllowEmptyString()]
    [string]$MailTo = '',

    [AllowEmptyString()]
    [string]$RetentionDays = ''
    ,

    [AllowEmptyString()]
    [string]$MaintenanceCleanupEnabled = '',

    [AllowEmptyString()]
    [string]$TableauLogRetentionDays = '',

    [AllowEmptyString()]
    [string]$HttpRequestsCleanupEnabled = '',

    [AllowEmptyString()]
    [string]$HttpRequestsRetentionDays = '',

    [AllowEmptyString()]
    [string]$ReindexEnabled = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-CurrentEnvironmentValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Scope
    )

    if ($Scope -eq 'Process') {
        return [Environment]::GetEnvironmentVariable($Name, 'Process')
    }

    return [Environment]::GetEnvironmentVariable($Name, $Scope)
}

function Set-EnvironmentValueSafely {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [string]$Scope,

        [bool]$AllowOverwrite,

        [bool]$WhatIfOnly
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject]@{
            Name = $Name
            Action = 'SkippedEmpty'
            Previous = Get-CurrentEnvironmentValue -Name $Name -Scope $Scope
            Value = ''
        }
    }

    $previous = Get-CurrentEnvironmentValue -Name $Name -Scope $Scope

    if (-not [string]::IsNullOrWhiteSpace($previous) -and -not $AllowOverwrite) {
        return [pscustomobject]@{
            Name = $Name
            Action = 'KeptExisting'
            Previous = $previous
            Value = $previous
        }
    }

    if (-not $WhatIfOnly) {
        [Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
        if ($Scope -ne 'Process') {
            [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
        }
    }

    return [pscustomobject]@{
        Name = $Name
        Action = if ([string]::IsNullOrWhiteSpace($previous)) { 'Created' } else { 'Updated' }
        Previous = $previous
        Value = $Value
    }
}

function Read-SetupValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt,

        [AllowEmptyString()]
        [string]$CurrentValue = ''
    )

    if ([string]::IsNullOrWhiteSpace($CurrentValue)) {
        return Read-Host $Prompt
    }

    $answer = Read-Host "$Prompt [$CurrentValue]"

    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $CurrentValue
    }

    return $answer
}

if ($Interactive) {
    $TableauServerDataDir = Read-SetupValue -Prompt 'TABLEAU_SERVER_DATA_DIR' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_SERVER_DATA_DIR' -Scope $Scope)
    $BackupRoot = Read-SetupValue -Prompt 'TABLEAU_BACKUP_ROOT' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_ROOT' -Scope $Scope)
    $MailEnabled = Read-SetupValue -Prompt 'Enable email notifications? true/false' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_MAIL_ENABLED' -Scope $Scope)
    $MailSmtpServer = Read-SetupValue -Prompt 'SMTP server' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_MAIL_SMTP_SERVER' -Scope $Scope)
    $MailSmtpPort = Read-SetupValue -Prompt 'SMTP port' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_MAIL_SMTP_PORT' -Scope $Scope)
    $MailUseSsl = Read-SetupValue -Prompt 'SMTP SSL true/false' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_MAIL_USE_SSL' -Scope $Scope)
    $MailFrom = Read-SetupValue -Prompt 'Mail From' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_MAIL_FROM' -Scope $Scope)
    $MailTo = Read-SetupValue -Prompt 'Mail To, comma or semicolon separated' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_MAIL_TO' -Scope $Scope)
    $RetentionDays = Read-SetupValue -Prompt 'Backup/settings retention days' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_RETENTION_DAYS' -Scope $Scope)
    $MaintenanceCleanupEnabled = Read-SetupValue -Prompt 'Maintenance cleanup enabled? true/false' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_MAINTENANCE_CLEANUP_ENABLED' -Scope $Scope)
    $TableauLogRetentionDays = Read-SetupValue -Prompt 'Tableau log retention days' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_TABLEAU_LOG_RETENTION_DAYS' -Scope $Scope)
    $HttpRequestsCleanupEnabled = Read-SetupValue -Prompt 'HTTP requests cleanup enabled? true/false' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_HTTP_REQUESTS_CLEANUP_ENABLED' -Scope $Scope)
    $HttpRequestsRetentionDays = Read-SetupValue -Prompt 'HTTP requests retention days' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_HTTP_REQUESTS_RETENTION_DAYS' -Scope $Scope)
    $ReindexEnabled = Read-SetupValue -Prompt 'Reindex search enabled? true/false' -CurrentValue (Get-CurrentEnvironmentValue -Name 'TABLEAU_BACKUP_REINDEX_ENABLED' -Scope $Scope)
}

$allowOverwrite = [bool]($Force -or $Reconfigure)

$results = @()
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_SERVER_DATA_DIR' -Value $TableauServerDataDir -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_ROOT' -Value $BackupRoot -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_MAIL_ENABLED' -Value $MailEnabled -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_MAIL_SMTP_SERVER' -Value $MailSmtpServer -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_MAIL_SMTP_PORT' -Value $MailSmtpPort -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_MAIL_USE_SSL' -Value $MailUseSsl -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_MAIL_FROM' -Value $MailFrom -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_MAIL_TO' -Value $MailTo -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_RETENTION_DAYS' -Value $RetentionDays -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_MAINTENANCE_CLEANUP_ENABLED' -Value $MaintenanceCleanupEnabled -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_TABLEAU_LOG_RETENTION_DAYS' -Value $TableauLogRetentionDays -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_HTTP_REQUESTS_CLEANUP_ENABLED' -Value $HttpRequestsCleanupEnabled -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_HTTP_REQUESTS_RETENTION_DAYS' -Value $HttpRequestsRetentionDays -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)
$results += Set-EnvironmentValueSafely -Name 'TABLEAU_BACKUP_REINDEX_ENABLED' -Value $ReindexEnabled -Scope $Scope -AllowOverwrite $allowOverwrite -WhatIfOnly ([bool]$WhatIfOnly)

$results | Format-Table -AutoSize

if (-not $WhatIfOnly) {
    Write-Host ''
    Write-Host 'Configuration saved. Open a new elevated PowerShell/Task Scheduler session if you used User or Machine scope.'
}
