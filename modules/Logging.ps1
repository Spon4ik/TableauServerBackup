Set-StrictMode -Version 2.0

### =====================================================================
### Logging module
### =====================================================================

class BackupFatalException : System.Exception {
    [int]$ExitCode

    BackupFatalException([string]$Message, [int]$ExitCode) : base($Message) {
        $this.ExitCode = $ExitCode
    }
}

$script:BackupLogFile = $null

function Initialize-BackupLogging {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )

    $script:BackupLogFile = $LogFile

    $parent = Split-Path -Parent $LogFile

    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -Path $parent -ItemType Directory -Force | Out-Null
        }
    }

    if (-not (Test-Path -LiteralPath $LogFile -PathType Leaf)) {
        New-Item -Path $LogFile -ItemType File -Force | Out-Null
    }
}

function Write-Log {
    param(
        [AllowEmptyString()]
        [string]$Message
    )

    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $line = "[$ts] $Message"

    Write-Host $line

    if (-not [string]::IsNullOrWhiteSpace($script:BackupLogFile)) {
        try {
            Add-Content -LiteralPath $script:BackupLogFile -Value $line -Encoding UTF8
        }
        catch {
            Write-Host "[$ts] [WARNING] Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

function ConvertTo-CommandLineArgument {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Argument
    )

    if ($null -eq $Argument) {
        return '""'
    }

    $escaped = $Argument.Replace('"', '\"')

    if ($escaped -match '\s|["&|<>^]') {
        return '"' + $escaped + '"'
    }

    return $escaped
}

function Invoke-LoggedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [int[]]$SuccessExitCodes = @(0),

        [AllowEmptyString()]
        [string]$StepName = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($StepName)) {
        Write-Log "[STEP] $StepName"
    }

    $argText = ''

    if ($null -ne $Arguments -and @($Arguments).Count -gt 0) {
        $argText = ($Arguments | ForEach-Object {
            ConvertTo-CommandLineArgument -Argument ([string]$_)
        }) -join ' '
    }

    Write-Log "[CMD] `"$FilePath`" $argText"

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $argText
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    try {
        [void]$process.Start()

        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()

        $process.WaitForExit()

        $rc = [int]$process.ExitCode

        if (-not [string]::IsNullOrWhiteSpace($stdout)) {
            foreach ($line in ($stdout -split "`r?`n")) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Log $line
                }
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            foreach ($line in ($stderr -split "`r?`n")) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Log "[STDERR] $line"
                }
            }
        }

        Write-Log "[RC] $FilePath returned $rc."

        if ($SuccessExitCodes -notcontains $rc) {
            throw "Command failed. Exit code: $rc. Command: `"$FilePath`" $argText"
        }

        return $rc
    }
    finally {
        if ($null -ne $process) {
            $process.Dispose()
        }
    }
}

function Write-DiskSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Log "[STEP] Disk snapshot: $Title"

    try {
        $disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
            Select-Object `
                DeviceID,
                @{Name = 'SizeGB'; Expression = { [math]::Round($_.Size / 1GB, 2) } },
                @{Name = 'FreeGB'; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) } },
                @{Name = 'FreePct'; Expression = {
                    if ($_.Size -gt 0) {
                        [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
                    }
                    else {
                        0
                    }
                } }

        foreach ($disk in $disks) {
            Write-Log ("[INFO] Disk {0}: Free {1} GB / {2} GB ({3}%)" -f `
                $disk.DeviceID, $disk.FreeGB, $disk.SizeGB, $disk.FreePct)
        }
    }
    catch {
        Write-Log "[WARNING] Failed to collect disk snapshot."
        Write-Log "[WARNING] $($_.Exception.Message)"
    }
}

function Write-WindowsApplicationEvent {
    param(
        [Parameter(Mandatory = $true)]
        [int]$FinalRc,

        [AllowEmptyString()]
        [string]$FailureSummary = '',

        [AllowEmptyString()]
        [string]$LogFile = ''
    )

    Write-Log "[STEP] Writing Windows Application event..."

    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        $LogFile = $script:BackupLogFile
    }

    $eventType = 'INFORMATION'
    $eventId = 1000
    $statusText = 'SUCCESS'

    if ($FinalRc -ne 0) {
        $eventType = 'ERROR'
        $eventId = 1001
        $statusText = 'FAILED'
    }

    $message = @"
Tableau Server Backup $statusText
Computer: $env:COMPUTERNAME
Exit Code: $FinalRc
Log File: $LogFile
Failure Summary: $FailureSummary
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
"@

    if ($message.Length -gt 30000) {
        $message = $message.Substring(0, 30000)
    }

    try {
        $result = & eventcreate.exe `
            /L APPLICATION `
            /T $eventType `
            /ID $eventId `
            /SO TableauBackup `
            /D $message 2>&1

        if ($null -ne $result) {
            foreach ($line in @($result)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                    Write-Log ([string]$line)
                }
            }
        }

        $rc = $LASTEXITCODE
        Write-Log "[RC] eventcreate returned $rc."

        return $rc
    }
    catch {
        Write-Log "[WARNING] Failed to write Windows Application event."
        Write-Log "[WARNING] $($_.Exception.Message)"
        return 1
    }
}