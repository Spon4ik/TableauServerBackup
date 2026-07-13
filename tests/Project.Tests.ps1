$ProjectRoot = Split-Path -Parent $PSScriptRoot

Describe 'Email status body' {
    BeforeAll {
        . (Join-Path $ProjectRoot 'modules\Email.ps1')
    }

    It 'summarizes a successful backup without SMTP delivery caveats' {
        $body = New-BackupStatusEmailBody `
            -FinalRc 0 `
            -ComputerName 'TABLEAU01' `
            -BackupFile 'D:\backup\site.tsbak' `
            -LogFile 'D:\backup\log\backup_log_20260707.log'

        $body | Should Match 'Status\s+: SUCCESS'
        $body | Should Match 'Run Type\s+: Normal backup'
        $body | Should Match 'Run Summary:'
        $body | Should Match 'Backup workflow completed successfully\.'
        $body | Should Not Match 'Important:'
        $body | Should Not Match 'Send-MailMessage'
        $body | Should Not Match 'SMTP relay accepted'
        $body | Should Not Match 'Inbox delivery'
    }

    It 'includes failure status, exit code, and failure summary' {
        $body = New-BackupStatusEmailBody `
            -FinalRc 8 `
            -FailureSummary 'Expected backup file was not found.' `
            -ComputerName 'TABLEAU01'

        $body | Should Match 'Status\s+: FAILED'
        $body | Should Match 'Exit Code\s+: 8'
        $body | Should Match 'Expected backup file was not found\.'
    }

    It 'identifies dry-run messages' {
        $body = New-BackupStatusEmailBody `
            -FinalRc 0 `
            -DryRun $true `
            -ComputerName 'TABLEAU01'

        $body | Should Match 'Run Type\s+: Dry run'
    }

    It 'identifies email-only test messages' {
        $body = New-BackupStatusEmailBody `
            -FinalRc 0 `
            -EmailOnlyTest $true `
            -ComputerName 'TABLEAU01'

        $body | Should Match 'Run Type\s+: Email-only test'
        $body | Should Match 'Email-only test completed\. No Tableau operations were executed\.'
    }

    It 'adds actionable disk-space details from the run log to failed messages' {
        $logFile = Join-Path $TestDrive 'backup.log'
        Set-Content -LiteralPath $logFile -Encoding ASCII -Value @(
            '[2026-07-09 00:17:33.587] 50% - Insufficient disk space to generate backup on the following nodes: ''node1'''
            '[2026-07-09 00:17:33.608] One or more nodes in the cluster do not appear to have enough free disk space to allow generation of a backup.'
        )

        $body = New-BackupStatusEmailBody `
            -FinalRc 7 `
            -FailureSummary 'Backup creation command failed with exit code 1.' `
            -ComputerName 'TABLEAU01' `
            -LogFile $logFile

        $body | Should Match 'Failure Details:'
        $body | Should Match 'Insufficient disk space to generate backup'
        $body | Should Match 'node1'
    }
}

Describe 'Backup retention' {
    BeforeAll {
        . (Join-Path $ProjectRoot 'modules\Retention.ps1')

        function Write-Log {
            param([string]$Message)
        }
    }

    It 'keeps at least two tsbak files even when all backups are older than retention' {
        $backupPath = Join-Path $TestDrive 'backups'
        $settingsPath = Join-Path $TestDrive 'settings'
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        New-Item -Path $settingsPath -ItemType Directory -Force | Out-Null

        foreach ($name in @('backup-1.tsbak', 'backup-2.tsbak', 'backup-3.tsbak')) {
            $file = Join-Path $backupPath $name
            Set-Content -LiteralPath $file -Encoding ASCII -Value $name
            (Get-Item -LiteralPath $file).LastWriteTime = (Get-Date).AddDays(-10)
        }

        Invoke-BackupRetention -BackupPath $backupPath -SettingsPath $settingsPath -DaysToKeep 5 | Out-Null

        @(Get-ChildItem -LiteralPath $backupPath -Filter '*.tsbak' -File).Count | Should Be 2
        Test-Path -LiteralPath (Join-Path $backupPath 'backup-2.tsbak') | Should Be $true
        Test-Path -LiteralPath (Join-Path $backupPath 'backup-3.tsbak') | Should Be $true
    }

    It 'trims oldest backup files above the configured maximum count' {
        $backupPath = Join-Path $TestDrive 'backups'
        $settingsPath = Join-Path $TestDrive 'settings'
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        New-Item -Path $settingsPath -ItemType Directory -Force | Out-Null

        1..6 | ForEach-Object {
            $file = Join-Path $backupPath ("backup-$_.tsbak")
            Set-Content -LiteralPath $file -Encoding ASCII -Value "backup $_"
            (Get-Item -LiteralPath $file).LastWriteTime = (Get-Date).AddDays(-1 * (6 - $_))
        }

        Invoke-BackupRetention `
            -BackupPath $backupPath `
            -SettingsPath $settingsPath `
            -DaysToKeep 30 `
            -MinimumBackupFilesToKeep 2 `
            -MaxBackupFilesToKeep 5 | Out-Null

        @(Get-ChildItem -LiteralPath $backupPath -Filter '*.tsbak' -File).Count | Should Be 5
        Test-Path -LiteralPath (Join-Path $backupPath 'backup-1.tsbak') | Should Be $false
        Test-Path -LiteralPath (Join-Path $backupPath 'backup-6.tsbak') | Should Be $true
    }

    It 'keeps old settings files when settings retention is not configured' {
        $backupPath = Join-Path $TestDrive 'backups'
        $settingsPath = Join-Path $TestDrive 'settings'
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        New-Item -Path $settingsPath -ItemType Directory -Force | Out-Null

        $settingsFile = Join-Path $settingsPath 'server_settings-20260101_00-00-00.json'
        Set-Content -LiteralPath $settingsFile -Encoding ASCII -Value '{}'
        (Get-Item -LiteralPath $settingsFile).LastWriteTime = (Get-Date).AddDays(-180)

        Invoke-BackupRetention -BackupPath $backupPath -SettingsPath $settingsPath -DaysToKeep 5 | Out-Null

        Test-Path -LiteralPath $settingsFile | Should Be $true
    }

    It 'deletes old settings files when settings retention is configured' {
        $backupPath = Join-Path $TestDrive 'backups'
        $settingsPath = Join-Path $TestDrive 'settings'
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
        New-Item -Path $settingsPath -ItemType Directory -Force | Out-Null

        $settingsFile = Join-Path $settingsPath 'server_settings-20260101_00-00-00.json'
        Set-Content -LiteralPath $settingsFile -Encoding ASCII -Value '{}'
        (Get-Item -LiteralPath $settingsFile).LastWriteTime = (Get-Date).AddDays(-180)

        Invoke-BackupRetention -BackupPath $backupPath -SettingsPath $settingsPath -DaysToKeep 5 -SettingsDaysToKeep 30 | Out-Null

        Test-Path -LiteralPath $settingsFile | Should Be $false
    }
}

Describe 'Runtime configuration' {
    BeforeAll {
        . (Join-Path $ProjectRoot 'modules\Config.ps1')
    }

    BeforeEach {
        $env:TABLEAU_BACKUP_ROOT = Join-Path $TestDrive 'backup-root'
        $env:TABLEAU_SERVER_DATA_DIR = Join-Path $TestDrive 'tableau-data'
        $env:TABLEAU_BACKUP_MINIMUM_BACKUP_FILES_TO_KEEP = $null
        $env:TABLEAU_BACKUP_SETTINGS_RETENTION_DAYS = $null
    }

    It 'reads minimum backup files to keep from the environment' {
        $env:TABLEAU_BACKUP_MINIMUM_BACKUP_FILES_TO_KEEP = '4'

        $config = Get-BackupRuntimeConfig

        $config.MinimumBackupFilesToKeep | Should Be 4
    }

    It 'defaults minimum backup files to keep to two' {
        $config = Get-BackupRuntimeConfig

        $config.MinimumBackupFilesToKeep | Should Be 2
    }

    It 'reads settings retention days from the environment' {
        $env:TABLEAU_BACKUP_SETTINGS_RETENTION_DAYS = '90'

        $config = Get-BackupRuntimeConfig

        $config.SettingsRetentionDays | Should Be 90
    }

    It 'defaults settings retention days to zero so settings files are preserved' {
        $config = Get-BackupRuntimeConfig

        $config.SettingsRetentionDays | Should Be 0
    }
}

Describe 'Scheduled task management' {
    BeforeAll {
        . (Join-Path $ProjectRoot 'modules\Scheduler.ps1')
    }

    It 'reports a missing task without changing Task Scheduler' {
        Mock Get-ScheduledTask { throw 'The system cannot find the file specified.' }

        $summary = Get-TableauBackupScheduledTaskSummary -TaskName 'TableauServerBackup'

        $summary.Exists | Should Be $false
        $summary.State | Should Be 'NotFound'
    }

    It 'creates a daily batch task definition' {
        $batchPath = Join-Path $TestDrive 'TableauServerBackup.bat'
        Set-Content -LiteralPath $batchPath -Value '@echo off' -Encoding ASCII

        Mock New-ScheduledTaskAction {
            param($Execute, $WorkingDirectory)
            [pscustomobject]@{ Execute = $Execute; WorkingDirectory = $WorkingDirectory }
        }
        Mock New-ScheduledTaskTrigger {
            param($At, $DaysInterval)
            [pscustomobject]@{ At = $At; DaysInterval = $DaysInterval }
        }
        Mock New-ScheduledTaskSettingsSet { [pscustomobject]@{ StartWhenAvailable = $true; MultipleInstances = 'IgnoreNew' } }

        $definition = New-TableauBackupScheduledTaskDefinition `
            -BatchPath $batchPath `
            -WorkingDirectory $TestDrive `
            -DailyTime '03:15' `
            -DaysInterval 2

        $definition.Action.Execute | Should Be $batchPath
        ([string]$definition.Action.WorkingDirectory) | Should Be ([string]$TestDrive)
        $definition.Trigger.DaysInterval | Should Be 2
    }

    It 'previews task creation without prompting for a credential or changing Task Scheduler' {
        $result = Invoke-TableauBackupScheduledTaskAction `
            -Action CreateOrUpdate `
            -TaskName 'TableauServerBackup' `
            -WhatIfOnly $true

        $result.Planned | Should Be $true
        $result.Result | Should Be 'No scheduled-task changes were made.'
    }

    It 'registers a daily task with a supplied credential without emitting its password' {
        $batchPath = Join-Path $TestDrive 'TableauServerBackup.bat'
        Set-Content -LiteralPath $batchPath -Value '@echo off' -Encoding ASCII
        $credential = New-Object pscredential('CONTOSO\TableauBackup', (ConvertTo-SecureString 'test-password' -AsPlainText -Force))

        Mock New-ScheduledTaskAction { [pscustomobject]@{} }
        Mock New-ScheduledTaskTrigger { [pscustomobject]@{} }
        Mock New-ScheduledTaskSettingsSet { [pscustomobject]@{} }
        Mock Register-TableauBackupScheduledTask { }
        Mock Get-ScheduledTask {
            [pscustomobject]@{
                State = 'Ready'
                Actions = @()
                Triggers = @()
                Principal = [pscustomobject]@{ UserId = 'CONTOSO\TableauBackup' }
            }
        }

        $result = Invoke-TableauBackupScheduledTaskAction `
            -Action CreateOrUpdate `
            -TaskName 'TableauServerBackup' `
            -BatchPath $batchPath `
            -WorkingDirectory $TestDrive `
            -Credential $credential

        $result.UserId | Should Be 'CONTOSO\TableauBackup'
        ($result | Out-String) | Should Not Match 'test-password'
        Assert-MockCalled Register-TableauBackupScheduledTask -Times 1 -Exactly -ParameterFilter {
            $TaskName -eq 'TableauServerBackup' -and $Credential.UserName -eq 'CONTOSO\TableauBackup'
        }
    }

    It 'delegates enable, disable, and removal to Task Scheduler' {
        Mock Enable-ScheduledTask { }
        Mock Disable-ScheduledTask { }
        Mock Unregister-ScheduledTask { }

        Invoke-TableauBackupScheduledTaskAction -Action Enable -TaskName 'TableauServerBackup' | Out-Null
        Invoke-TableauBackupScheduledTaskAction -Action Disable -TaskName 'TableauServerBackup' | Out-Null
        Invoke-TableauBackupScheduledTaskAction -Action Remove -TaskName 'TableauServerBackup' | Out-Null

        Assert-MockCalled Enable-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskName -eq 'TableauServerBackup' }
        Assert-MockCalled Disable-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskName -eq 'TableauServerBackup' }
        Assert-MockCalled Unregister-ScheduledTask -Times 1 -Exactly -ParameterFilter { $TaskName -eq 'TableauServerBackup' }
    }
}

Describe 'Project hygiene' {
    It 'does not track runtime mail settings under the real runtime name' {
        Test-Path (Join-Path $ProjectRoot 'config\MailSettings.json') | Should Be $false
    }

    It 'does not track obsolete mail settings examples' {
        Test-Path (Join-Path $ProjectRoot 'config\MailSettings.example.json') | Should Be $false
    }

    It 'ignores local runtime configuration and backup artifacts' {
        $gitignore = Get-Content -LiteralPath (Join-Path $ProjectRoot '.gitignore') -Raw

        $gitignore | Should Match 'config/MailSettings\.json'
        $gitignore | Should Match 'config/\*\.local\.json'
        $gitignore | Should Match '\*\.tsbak'
        $gitignore | Should Match 'nppBackup/'
    }
}

Describe 'Logging commands' {
    BeforeAll {
        . (Join-Path $ProjectRoot 'modules\Logging.ps1')
    }

    It 'captures output when streaming command output is enabled' {
        $logFile = Join-Path $TestDrive 'stream.log'
        Initialize-BackupLogging -LogFile $logFile

        $rc = Invoke-LoggedCommand `
            -FilePath 'powershell.exe' `
            -Arguments @('-NoProfile', '-Command', 'Write-Output "stream-line-1"; Write-Output "stream-line-2"') `
            -StreamOutput

        $rc | Should Be 0
        $logText = Get-Content -LiteralPath $logFile -Raw
        $logText | Should Match 'stream-line-1'
        $logText | Should Match 'stream-line-2'
    }
}

Describe 'Setup script' {
    $setupScript = Join-Path $ProjectRoot 'scripts\Setup-TableauServerBackup.ps1'

    BeforeEach {
        $env:TABLEAU_SERVER_DATA_DIR = $null
        $env:TABLEAU_BACKUP_ROOT = $null
        $env:TABLEAU_BACKUP_MAIL_TO = $null
        $env:TABLEAU_BACKUP_MAIL_CC = $null
        $env:TABLEAU_BACKUP_MAIL_BCC = $null
        $env:TABLEAU_BACKUP_MAIL_SUBJECT_PREFIX = $null
        $env:TABLEAU_BACKUP_MAIL_DELIVERY_NOTIFICATION = $null
        $env:TABLEAU_BACKUP_MINIMUM_BACKUP_FILES_TO_KEEP = $null
        $env:TABLEAU_BACKUP_SETTINGS_RETENTION_DAYS = $null
        $env:TABLEAU_BACKUP_HTTP_REQUESTS_CLEANUP_ENABLED = $null
        $env:TABLEAU_BACKUP_HTTP_REQUESTS_RETENTION_DAYS = $null
        $env:TABLEAU_BACKUP_REINDEX_ENABLED = $null
    }

    It 'writes requested process environment values in non-interactive mode' {
        $tableauData = Join-Path $TestDrive 'tableau-data'
        $backupRoot = Join-Path $TestDrive 'backup-root'

        & $setupScript `
            -Scope Process `
            -TableauServerDataDir $tableauData `
            -BackupRoot $backupRoot `
            -MailTo 'admin@example.com' `
            -MailCc 'cc@example.com' `
            -MailBcc 'bcc@example.com' `
            -MailSubjectPrefix '[Tableau Backup Test]' `
            -MailDeliveryNotification 'OnSuccess,OnFailure' `
            -MinimumBackupFilesToKeep '4' `
            -SettingsRetentionDays '90' `
            -HttpRequestsCleanupEnabled 'true' `
            -HttpRequestsRetentionDays '730' `
            -ReindexEnabled 'true' `
            -Force | Out-Null

        $env:TABLEAU_SERVER_DATA_DIR | Should Be $tableauData
        $env:TABLEAU_BACKUP_ROOT | Should Be $backupRoot
        $env:TABLEAU_BACKUP_MAIL_TO | Should Be 'admin@example.com'
        $env:TABLEAU_BACKUP_MAIL_CC | Should Be 'cc@example.com'
        $env:TABLEAU_BACKUP_MAIL_BCC | Should Be 'bcc@example.com'
        $env:TABLEAU_BACKUP_MAIL_SUBJECT_PREFIX | Should Be '[Tableau Backup Test]'
        $env:TABLEAU_BACKUP_MAIL_DELIVERY_NOTIFICATION | Should Be 'OnSuccess,OnFailure'
        $env:TABLEAU_BACKUP_MINIMUM_BACKUP_FILES_TO_KEEP | Should Be '4'
        $env:TABLEAU_BACKUP_SETTINGS_RETENTION_DAYS | Should Be '90'
        $env:TABLEAU_BACKUP_HTTP_REQUESTS_CLEANUP_ENABLED | Should Be 'true'
        $env:TABLEAU_BACKUP_HTTP_REQUESTS_RETENTION_DAYS | Should Be '730'
        $env:TABLEAU_BACKUP_REINDEX_ENABLED | Should Be 'true'
    }

    It 'does not overwrite existing process environment values without Reconfigure or Force' {
        $existingRoot = Join-Path $TestDrive 'existing-root'
        $newRoot = Join-Path $TestDrive 'new-root'
        $env:TABLEAU_BACKUP_ROOT = $existingRoot

        & $setupScript `
            -Scope Process `
            -BackupRoot $newRoot | Out-Null

        $env:TABLEAU_BACKUP_ROOT | Should Be $existingRoot
    }

    It 'overwrites existing process environment values when Reconfigure is supplied' {
        $existingRoot = Join-Path $TestDrive 'existing-root'
        $newRoot = Join-Path $TestDrive 'new-root'
        $env:TABLEAU_BACKUP_ROOT = $existingRoot

        & $setupScript `
            -Scope Process `
            -BackupRoot $newRoot `
            -Reconfigure | Out-Null

        $env:TABLEAU_BACKUP_ROOT | Should Be $newRoot
    }
}

Describe 'Git hygiene check' {
    It 'fails when a scanned file contains a non-example email' {
        $temp = Join-Path $TestDrive 'leak.txt'
        Set-Content -LiteralPath $temp -Value ('owner' + '@' + 'private.invalid') -Encoding ASCII

        & (Join-Path $ProjectRoot 'scripts\Test-GitHygiene.ps1') -Path $temp -Quiet

        $LASTEXITCODE | Should Be 1
    }
}

Describe 'PowerShell source health' {
    It 'parses every active PowerShell file' {
        $parseErrors = @()

        foreach ($file in Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File | Where-Object { $_.Extension -ieq '.ps1' -and $_.FullName -notmatch '\\nppBackup\\' }) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)

            foreach ($error in $errors) {
                $parseErrors += "$($file.FullName):$($error.Extent.StartLineNumber): $($error.Message)"
            }
        }

        $parseErrors -join "`n" | Should Be ''
    }
}

Describe 'Simulation mode' {
    BeforeEach {
        $env:TABLEAU_SERVER_DATA_DIR = Join-Path $TestDrive 'tableau-data'
        $env:TABLEAU_BACKUP_ROOT = Join-Path $TestDrive 'backup-root'
        $env:TABLEAU_BACKUP_MAIL_ENABLED = 'false'

        New-Item -Path (Join-Path $env:TABLEAU_SERVER_DATA_DIR 'data\tabsvc\files\backups') -ItemType Directory -Force | Out-Null
    }

    It 'runs without TSM and creates backup, settings, and log output' {
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot 'TableauServerBackup.ps1') -Simulation

        $LASTEXITCODE | Should Be 0
        @(Get-ChildItem -LiteralPath (Join-Path $env:TABLEAU_BACKUP_ROOT 'backups') -Filter '*.tsbak' -File).Count | Should Be 1
        @(Get-ChildItem -LiteralPath (Join-Path $env:TABLEAU_BACKUP_ROOT 'settings') -Filter 'server_settings-*.json' -File).Count | Should Be 1
        @(Get-ChildItem -LiteralPath (Join-Path $env:TABLEAU_BACKUP_ROOT 'log') -Filter 'backup_log_*.log' -File).Count | Should Be 1
    }
}
