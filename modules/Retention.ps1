Set-StrictMode -Version 2.0

## =====================================================================
## Retention module
## =====================================================================

function Invoke-BackupRetention {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupPath,

        [Parameter(Mandatory = $true)]
        [string]$SettingsPath,

        [int]$DaysToKeep = 5,

        [int]$MinimumBackupFilesToKeep = 2
    )

    $cutoff = (Get-Date).AddDays(-1 * $DaysToKeep)

    Write-Log "[STEP] Deleting backup files older than $DaysToKeep days from custom backup path..."
    Write-Log "[INFO] Backup retention path: $BackupPath"
    Write-Log "[INFO] Backup retention cutoff: $cutoff"
    Write-Log "[INFO] Minimum backup files to keep: $MinimumBackupFilesToKeep"

    try {
        if (Test-Path -LiteralPath $BackupPath -PathType Container) {
            $allBackupFiles = @(Get-ChildItem -LiteralPath $BackupPath -Filter '*.tsbak' -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending)

            $protectedBackupPaths = @{}
            foreach ($file in @($allBackupFiles | Select-Object -First $MinimumBackupFilesToKeep)) {
                $protectedBackupPaths[$file.FullName] = $true
            }

            $backupFiles = @($allBackupFiles |
                Where-Object {
                    $_.LastWriteTime -lt $cutoff -and -not $protectedBackupPaths.ContainsKey($_.FullName)
                })

            if (@($backupFiles).Count -eq 0) {
                Write-Log "[INFO] No old backup files matched retention."
            }
            else {
                foreach ($file in $backupFiles) {
                    Write-Log "[INFO] Deleting old backup file: $($file.FullName)"
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                }

                Write-Log "[OK] Backup retention completed."
            }

            if (@($allBackupFiles).Count -gt 0 -and @($backupFiles).Count -eq 0) {
                Write-Log "[INFO] Backup retention preserved existing files to keep the minimum safety count."
            }
        }
        else {
            Write-Log "[WARN] Backup retention path does not exist: $BackupPath"
        }
    }
    catch {
        Write-Log "[WARN] Backup retention failed: $($_.Exception.Message)"
    }

    Write-Log ''
    Write-Log "[STEP] Deleting settings files older than $DaysToKeep days from settings path..."
    Write-Log "[INFO] Settings retention path: $SettingsPath"
    Write-Log "[INFO] Settings retention cutoff: $cutoff"

    try {
        if (Test-Path -LiteralPath $SettingsPath -PathType Container) {
            $settingsFiles = Get-ChildItem -LiteralPath $SettingsPath -Filter 'server_settings-*.json' -File -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoff }

            if ($null -eq $settingsFiles -or $settingsFiles.Count -eq 0) {
                Write-Log "[INFO] No old settings files matched retention."
            }
            else {
                foreach ($file in $settingsFiles) {
                    Write-Log "[INFO] Deleting old settings file: $($file.FullName)"
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                }

                Write-Log "[OK] Settings retention completed."
            }
        }
        else {
            Write-Log "[WARN] Settings retention path does not exist: $SettingsPath"
        }
    }
    catch {
        Write-Log "[WARN] Settings retention failed: $($_.Exception.Message)"
    }

    return 0
}
