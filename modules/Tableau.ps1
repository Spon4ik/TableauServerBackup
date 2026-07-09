Set-StrictMode -Version 2.0

## =====================================================================
## Tableau module
##
## Depends on:
## - Write-Log
## - Invoke-LoggedCommand
## - BackupFatalException
##
## Provided by:
## - modules\Logging.ps1
## =====================================================================

function Get-TsmCommandPath {
    Write-Log "[STEP] Validating TSM command availability..."

    try {
        $cmd = Get-Command 'tsm' -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($cmd.Source)) {
            throw "Get-Command returned an empty source for tsm."
        }

        Write-Log "[OK] TSM found at: $($cmd.Source)"
        return $cmd.Source
    }
    catch {
        $msg = "tsm command was not found in PATH. Task Scheduler may be running with a different PATH than your interactive CMD session."
        Write-Log "[ERROR] $msg"
        throw [BackupFatalException]::new($msg, 4)
    }
}

function Get-TableauBackupRestorePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TsmPath
    )

    Write-Log "[STEP] Checking TSM basefilepath.backuprestore..."

    try {
        Write-Log "[CMD] `"$TsmPath`" configuration get -k basefilepath.backuprestore"

        $output = & $TsmPath configuration get -k basefilepath.backuprestore 2>&1
        $rc = $LASTEXITCODE

        foreach ($line in $output) {
            Write-Log ([string]$line)
        }

        Write-Log "[RC] configuration get returned $rc."

        if ($rc -ne 0) {
            Write-Log "[INFO] Could not read basefilepath.backuprestore. Continuing with computed Tableau backup path."
            return $null
        }

        $value = $output |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -First 1

        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Log "[INFO] basefilepath.backuprestore returned empty. Continuing with computed Tableau backup path."
            return $null
        }

        Write-Log "[INFO] TSM basefilepath.backuprestore returned: $value"
        return $value
    }
    catch {
        Write-Log "[INFO] Could not read basefilepath.backuprestore: $($_.Exception.Message)"
        return $null
    }
}

function Test-TableauServerStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TsmPath
    )

    Write-Log "[STEP] Checking Tableau Server status..."

    $rc = Invoke-LoggedCommand -FilePath $TsmPath -Arguments @('status', '-v')

    if ($rc -ne 0) {
        throw [BackupFatalException]::new('Tableau Server status check failed.', 5)
    }

    Write-Log "[OK] Tableau Server status command completed successfully."
}

function Invoke-TableauCleanupLogsTemp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TsmPath,

        [int]$LogRetentionDays = 7
    )

    Write-Log "[STEP] Cleanup old Tableau logs/temp files..."

    $rc = Invoke-LoggedCommand -FilePath $TsmPath -Arguments @(
        'maintenance',
        'cleanup',
        '-l',
        '-t',
        '--log-files-retention',
        ([string]$LogRetentionDays),
        '--request-timeout',
        '1800'
    )

    if ($rc -ne 0) {
        Write-Log "[WARN] Logs/temp cleanup returned non-zero, but cleanup is non-fatal. Continuing."
    }
    else {
        Write-Log "[OK] Logs/temp cleanup completed successfully."
    }

    return $rc
}

function Invoke-TableauHttpRequestsCleanup {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TsmPath,

        [int]$RetentionDays = 730
    )

    Write-Log "[STEP] Cleanup Tableau http_requests table retention..."

    $rc = Invoke-LoggedCommand -FilePath $TsmPath -Arguments @(
        'maintenance',
        'cleanup',
        '-q',
        '--http-requests-table-retention',
        ([string]$RetentionDays),
        '--request-timeout',
        '1800'
    )

    if ($rc -ne 0) {
        Write-Log "[WARN] http_requests cleanup returned non-zero, but this step is non-fatal. Continuing."
    }
    else {
        Write-Log "[OK] http_requests cleanup completed successfully."
    }

    return $rc
}

function Invoke-TableauReindexSearch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TsmPath
    )

    Write-Log "[STEP] Reindexing search..."

    $rc = Invoke-LoggedCommand -FilePath $TsmPath -Arguments @(
        'maintenance',
        'reindex-search'
    )

    if ($rc -ne 0) {
        Write-Log "[WARN] Reindex returned non-zero, but reindex is non-fatal. Continuing."
    }
    else {
        Write-Log "[OK] Reindex completed successfully."
    }

    return $rc
}

function Export-TableauSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TsmPath,

        [Parameter(Mandatory = $true)]
        [string]$SettingsFile
    )

    Write-Log "[STEP] Export Tableau Server settings..."

    $rc = Invoke-LoggedCommand -FilePath $TsmPath -Arguments @(
        'settings',
        'export',
        '-f',
        $SettingsFile
    )

    if ($rc -ne 0) {
        throw [BackupFatalException]::new('Settings export command failed.', 6)
    }

    if (-not (Test-Path -LiteralPath $SettingsFile -PathType Leaf)) {
        throw [BackupFatalException]::new("Settings export command returned success but file was not found: $SettingsFile", 6)
    }

    $size = (Get-Item -LiteralPath $SettingsFile).Length
    Write-Log "[INFO] Settings file size: $size bytes."

    if ($size -eq 0) {
        throw [BackupFatalException]::new("Settings file exists but is empty: $SettingsFile", 6)
    }

    Write-Log "[OK] Settings export completed and file was validated."
}

function Invoke-TableauBackupCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TsmPath,

        [Parameter(Mandatory = $true)]
        [string]$BackupBaseName
    )

    $rc = Invoke-LoggedCommand `
        -FilePath $TsmPath `
        -Arguments @('maintenance', 'backup', '--file', $BackupBaseName) `
        -StreamOutput `
        -HeartbeatSeconds 300 `
        -SuccessExitCodes @(0)

    Write-Log "[RC] backup command returned $rc."
    return $rc
}
