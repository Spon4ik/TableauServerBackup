#requires -version 5.1

param(
    [switch]$DryRun,
    [switch]$EmailOnlyTest,
    [switch]$Simulation
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

### =====================================================================
### Tableau Server Backup Orchestrator
###
### Test modes:
###   -EmailOnlyTest : send test email only, no Tableau operations.
###   -DryRun        : run flow but skip real backup, create tiny dummy .tsbak.
###
### Exit codes:
###   0    Success
###   1    Generic fatal failure
###   2    Required environment variable missing
###   3    Required folder creation failed
###   4    TSM command not found
###   5    Tableau Server health check failed
###   6    Settings export failed
###   7    Backup creation command failed
###   8    Backup validation failed
###   9    Backup move failed
###   740  Not running elevated
### =====================================================================

### ---------------------------------------------------------------------
### Script roots
### ---------------------------------------------------------------------

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModuleRoot = Join-Path $ScriptRoot 'modules'

### ---------------------------------------------------------------------
### Import modules
### ---------------------------------------------------------------------

. (Join-Path $ModuleRoot 'Logging.ps1')
. (Join-Path $ModuleRoot 'Config.ps1')
. (Join-Path $ModuleRoot 'Email.ps1')
. (Join-Path $ModuleRoot 'Tableau.ps1')
. (Join-Path $ModuleRoot 'FileMove.ps1')
. (Join-Path $ModuleRoot 'Retention.ps1')

### ---------------------------------------------------------------------
### Local helpers
### ---------------------------------------------------------------------

function Test-BackupEmpty {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $true
    }

    $Text = "$Value".Trim()

    if ($Text.Length -eq 0) {
        return $true
    }

    return $false
}

function Set-FinalFailure {
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $script:FinalRc = $ExitCode
    $script:FailureSummary = $Message
}

function Throw-BackupFatal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [int]$ExitCode
    )

    Set-FinalFailure -ExitCode $ExitCode -Message $Message

    throw $Message
}

function Invoke-NonFatalStep {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StepName,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    try {
        Write-Log "[STEP] $StepName"
        & $ScriptBlock
        Write-Log "[INFO] Completed non-fatal step: $StepName"
    }
    catch {
        Write-Log "[WARNING] Non-fatal step failed: $StepName"
        Write-Log "[WARNING] $($_.Exception.Message)"
    }
}

function Invoke-FunctionIfAvailable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FunctionName,

        [hashtable]$Parameters = @{},

        [switch]$Mandatory,

        [int]$FatalExitCode = 1
    )

    $Command = Get-Command -Name $FunctionName -CommandType Function -ErrorAction SilentlyContinue

    if ($null -eq $Command) {
        if ($Mandatory) {
            Throw-BackupFatal `
                -Message "Required function was not found: $FunctionName" `
                -ExitCode $FatalExitCode
        }

        Write-Log "[WARNING] Function not found, skipping: $FunctionName"
        return $null
    }

    $BoundParameters = @{}

    foreach ($Key in $Parameters.Keys) {
        if ($Command.Parameters.ContainsKey($Key)) {
            $BoundParameters[$Key] = $Parameters[$Key]
        }
    }

    return (& $FunctionName @BoundParameters)
}

function Move-BackupFileToCustomPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFile,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder
    )

    if (-not (Test-Path -LiteralPath $SourceFile -PathType Leaf)) {
        Throw-BackupFatal `
            -Message "Backup file to move was not found: $SourceFile" `
            -ExitCode 9
    }

    if (-not (Test-Path -LiteralPath $DestinationFolder -PathType Container)) {
        New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null
    }

    $DestinationFile = Join-Path $DestinationFolder (Split-Path -Leaf $SourceFile)

    Write-Log "[STEP] Moving backup file to custom backup folder..."
    Write-Log "[INFO] Source      : $SourceFile"
    Write-Log "[INFO] Destination : $DestinationFile"

    try {
        Move-Item `
            -LiteralPath $SourceFile `
            -Destination $DestinationFile `
            -Force `
            -ErrorAction Stop
    }
    catch {
        Throw-BackupFatal `
            -Message "Failed moving backup file from '$SourceFile' to '$DestinationFile'. $($_.Exception.Message)" `
            -ExitCode 9
    }

    if (-not (Test-Path -LiteralPath $DestinationFile -PathType Leaf)) {
        Throw-BackupFatal `
            -Message "Backup move finished but destination file was not found: $DestinationFile" `
            -ExitCode 9
    }

    $MovedItem = Get-Item -LiteralPath $DestinationFile -ErrorAction Stop

    if ($MovedItem.Length -le 0) {
        Throw-BackupFatal `
            -Message "Moved backup file exists but size is zero: $DestinationFile" `
            -ExitCode 9
    }

    Write-Log "[INFO] Backup moved successfully."
    Write-Log "[INFO] Moved backup file size bytes: $($MovedItem.Length)"

    return $DestinationFile
}

function New-DryRunBackupFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpectedBackupFile
    )

    Write-Log "[STEP] DRY RUN: creating dummy backup file..."

    $parent = Split-Path -Parent $ExpectedBackupFile

    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $content = @"
DRY RUN Tableau backup placeholder
Computer  : $env:COMPUTERNAME
Created   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')
File      : $ExpectedBackupFile
"@

    Set-Content -LiteralPath $ExpectedBackupFile -Value $content -Encoding ASCII -Force

    if (-not (Test-Path -LiteralPath $ExpectedBackupFile -PathType Leaf)) {
        throw "DRY RUN failed: dummy backup file was not created: $ExpectedBackupFile"
    }

    $item = Get-Item -LiteralPath $ExpectedBackupFile

    if ($item.Length -le 0) {
        throw "DRY RUN failed: dummy backup file is empty: $ExpectedBackupFile"
    }

    Write-Log "[INFO] DRY RUN dummy backup file created: $ExpectedBackupFile"
    Write-Log "[INFO] DRY RUN dummy backup size bytes: $($item.Length)"

    return $item.FullName
}

function Test-ExpectedBackupFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExpectedBackupFile
    )

    Write-Log "[STEP] Validating generated backup file..."
    Write-Log "[INFO] Expected backup file: $ExpectedBackupFile"

    if (-not (Test-Path -LiteralPath $ExpectedBackupFile -PathType Leaf)) {
        Throw-BackupFatal `
            -Message "Expected backup file was not found: $ExpectedBackupFile" `
            -ExitCode 8
    }

    $Item = Get-Item -LiteralPath $ExpectedBackupFile -ErrorAction Stop

    if ($Item.Length -le 0) {
        Throw-BackupFatal `
            -Message "Expected backup file exists but size is zero: $ExpectedBackupFile" `
            -ExitCode 8
    }

    Write-Log "[INFO] Backup file validation passed."
    Write-Log "[INFO] Backup file size bytes: $($Item.Length)"
}

### ---------------------------------------------------------------------
### Timestamp and date tokens
### ---------------------------------------------------------------------

$RunTimestamp = Get-Date -Format 'yyyyMMdd_HH-mm-ss'
$Today = $RunTimestamp.Substring(0, 8)

### ---------------------------------------------------------------------
### Runtime variables
### ---------------------------------------------------------------------

$FinalRc = 1
$FailureSummary = ''
$LogFile = $null
$BackupPath = $null
$SettingsPath = $null
$MovedBackupFile = ''
$TsmPath = $null

### ---------------------------------------------------------------------
### Validate admin/elevation before logging may be available
### ---------------------------------------------------------------------

if (-not $Simulation) {
    try {
        $principal = New-Object Security.Principal.WindowsPrincipal(
            [Security.Principal.WindowsIdentity]::GetCurrent()
        )

        $IsAdmin = $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )

        if (-not $IsAdmin) {
            Write-Host '[ERROR] Script is not running elevated as Administrator.'
            exit 740
        }
    }
    catch {
        Write-Host '[ERROR] Failed to validate administrator privileges.'
        Write-Host $_.Exception.Message
        exit 740
    }
}

### ---------------------------------------------------------------------
### Read paths from system environment variables
### ---------------------------------------------------------------------

$RuntimeConfig = Get-BackupRuntimeConfig

try {
    Assert-BackupRuntimeConfig -Config $RuntimeConfig
}
catch {
    Write-Host "[ERROR] $($_.Exception.Message)"
    exit 2
}

$DataDir = $RuntimeConfig.TableauServerDataDir
$CustomBackupRoot = $RuntimeConfig.BackupRoot

### ---------------------------------------------------------------------
### Validate environment variables before central logging
### ---------------------------------------------------------------------

if (Test-BackupEmpty $DataDir) {
    Write-Host '[ERROR] TABLEAU_SERVER_DATA_DIR is not set. Exiting...'
    exit 2
}

if (Test-BackupEmpty $CustomBackupRoot) {
    Write-Host '[ERROR] TABLEAU_BACKUP_ROOT is not set. Exiting...'
    exit 2
}

### ---------------------------------------------------------------------
### Build paths
### ---------------------------------------------------------------------

$DefaultBackupPath = Join-Path $DataDir 'data\tabsvc\files\backups'
$EffectiveBackupPath = $DefaultBackupPath

$BackupPath = Join-Path $CustomBackupRoot 'backups'
$LogPath = Join-Path $CustomBackupRoot 'log'
$SettingsPath = Join-Path $CustomBackupRoot 'settings'

$BackupBaseName = "$env:COMPUTERNAME`_backup-$RunTimestamp"
$ExpectedBackupFile = Join-Path $EffectiveBackupPath "$BackupBaseName.tsbak"

$LogFile = Join-Path $LogPath "backup_log_$Today.log"
$SettingsFile = Join-Path $SettingsPath "server_settings-$RunTimestamp.json"

### ---------------------------------------------------------------------
### Ensure required folders exist
### ---------------------------------------------------------------------

try {
    foreach ($folder in @($CustomBackupRoot, $BackupPath, $LogPath, $SettingsPath)) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }
}
catch {
    Write-Host '[ERROR] Failed to create required folder.'
    Write-Host $_.Exception.Message
    exit 3
}

### ---------------------------------------------------------------------
### Initialize logging
### ---------------------------------------------------------------------

Initialize-BackupLogging -LogFile $LogFile

try {
    Write-Log ''
    Write-Log '='
    Write-Log "= Tableau Server Backup Log - $(Get-Date)"
    Write-Log '='
    Write-Log "[INFO] Computer name: $env:COMPUTERNAME"
    Write-Log "[INFO] Running as: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Log "[INFO] Current directory: $(Get-Location)"
    Write-Log "[INFO] Script path: $($MyInvocation.MyCommand.Path)"
    Write-Log "[INFO] TABLEAU_SERVER_DATA_DIR: $DataDir"
    Write-Log "[INFO] TABLEAU_BACKUP_ROOT: $CustomBackupRoot"
    Write-Log "[INFO] Runtime config summary:"
    ConvertTo-MaskedConfigSummary -Config $RuntimeConfig | Format-List | Out-String |
        ForEach-Object {
            foreach ($line in ($_ -split "`r?`n")) {
                if (-not [string]::IsNullOrWhiteSpace($line)) {
                    Write-Log "[INFO] $line"
                }
            }
        }
    Write-Log "[INFO] Initial computed Tableau backup path: $DefaultBackupPath"
    Write-Log "[INFO] Custom backup path: $BackupPath"
    Write-Log "[INFO] Log file: $LogFile"
    Write-Log "[INFO] Settings file: $SettingsFile"
    Write-Log "[INFO] Backup base name passed to TSM: $BackupBaseName"
    Write-Log "[INFO] Initial expected physical backup file: $ExpectedBackupFile"

    if ($EmailOnlyTest) {
        Write-Log "[INFO] EMAIL ONLY TEST mode is enabled. No Tableau operations will be executed."
    }

    if ($DryRun) {
        Write-Log "[INFO] DRY RUN mode is enabled. Real Tableau backup creation will be skipped."
    }

    if ($Simulation) {
        Write-Log "[INFO] SIMULATION mode is enabled. TSM and administrator checks are skipped."
    }

    Write-Log ''

    ### -----------------------------------------------------------------
    ### Email-only test
    ### -----------------------------------------------------------------

    if ($EmailOnlyTest) {
        Send-BackupEmailOnlyTest `
            -ScriptRoot $ScriptRoot `
            -LogFile $LogFile

        $FinalRc = 0
        Write-Log "[FINAL] Email-only test finished with exit code 0."
        exit 0
    }

    ### -----------------------------------------------------------------
    ### Validate TSM path
    ### -----------------------------------------------------------------

    if ($Simulation) {
        $TsmPath = '(simulation)'
    }
    else {
        $TsmPath = Invoke-FunctionIfAvailable `
            -FunctionName 'Get-TsmCommandPath' `
            -Mandatory `
            -FatalExitCode 4
    }

    if (Test-BackupEmpty $TsmPath) {
        Throw-BackupFatal `
            -Message "TSM command path was not returned by Get-TsmCommandPath." `
            -ExitCode 4
    }

    Write-Log "[INFO] TSM path: $TsmPath"

    ### -----------------------------------------------------------------
    ### Detect Tableau backuprestore path, if module supports it
    ### -----------------------------------------------------------------

    $DetectedBackupPath = $null

    if (-not $Simulation) {
        $DetectedBackupPath = Invoke-FunctionIfAvailable `
            -FunctionName 'Get-TableauBackupRestorePath' `
            -Parameters @{
                TsmPath = $TsmPath
            }
    }

    if (-not (Test-BackupEmpty $DetectedBackupPath)) {
        $EffectiveBackupPath = "$DetectedBackupPath"
        $ExpectedBackupFile = Join-Path $EffectiveBackupPath "$BackupBaseName.tsbak"

        Write-Log "[INFO] Effective Tableau backup path updated from TSM config: $EffectiveBackupPath"
        Write-Log "[INFO] Expected physical backup file updated: $ExpectedBackupFile"
    }
    else {
        Write-Log "[INFO] Using default Tableau backup path: $EffectiveBackupPath"
    }

    ### -----------------------------------------------------------------
    ### Tableau health check - fatal
    ### -----------------------------------------------------------------

    if (-not $Simulation) {
        Invoke-FunctionIfAvailable `
            -FunctionName 'Test-TableauServerStatus' `
            -Parameters @{
                TsmPath = $TsmPath
            } `
            -Mandatory `
            -FatalExitCode 5 | Out-Null
    }

    ### -----------------------------------------------------------------
    ### Move existing old .tsbak files before creating a new backup - non-fatal
    ### -----------------------------------------------------------------

    Invoke-NonFatalStep -StepName "Move existing .tsbak files from Tableau backup folder" -ScriptBlock {
        if (Test-Path -LiteralPath $EffectiveBackupPath -PathType Container) {
            Get-ChildItem -LiteralPath $EffectiveBackupPath -Filter '*.tsbak' -File -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Move-BackupFileToCustomPath `
                        -SourceFile $_.FullName `
                        -DestinationFolder $BackupPath | Out-Null
                }
        }
        else {
            Write-Log "[INFO] Effective Tableau backup path does not exist yet: $EffectiveBackupPath"
        }
    }

    ### -----------------------------------------------------------------
    ### Retention - non-fatal, before backup creation to free space
    ### -----------------------------------------------------------------

    Invoke-NonFatalStep -StepName "Apply retention to backup folder before backup creation" -ScriptBlock {
        Invoke-FunctionIfAvailable `
            -FunctionName 'Invoke-BackupRetention' `
            -Parameters @{
                BackupPath = $BackupPath
                SettingsPath = $SettingsPath
                DaysToKeep = $RuntimeConfig.RetentionDays
                MinimumBackupFilesToKeep = $RuntimeConfig.MinimumBackupFilesToKeep
                SettingsDaysToKeep = $RuntimeConfig.SettingsRetentionDays
            } | Out-Null
    }

    ### -----------------------------------------------------------------
    ### Cleanup / maintenance - non-fatal
    ### -----------------------------------------------------------------

    if ($RuntimeConfig.MaintenanceCleanupEnabled -and -not $Simulation) {
        Invoke-NonFatalStep -StepName "Cleanup Tableau logs/temp files" -ScriptBlock {
            Invoke-FunctionIfAvailable `
                -FunctionName 'Invoke-TableauCleanupLogsTemp' `
                -Parameters @{
                    TsmPath = $TsmPath
                    LogRetentionDays = $RuntimeConfig.TableauLogRetentionDays
                } | Out-Null
        }
    }

    if ($RuntimeConfig.HttpRequestsCleanupEnabled -and -not $Simulation) {
        Invoke-NonFatalStep -StepName "Cleanup Tableau http_requests retention" -ScriptBlock {
            Invoke-FunctionIfAvailable `
                -FunctionName 'Invoke-TableauHttpRequestsCleanup' `
                -Parameters @{
                    TsmPath = $TsmPath
                    RetentionDays = $RuntimeConfig.HttpRequestsRetentionDays
                } | Out-Null
        }
    }

    if ($RuntimeConfig.ReindexEnabled -and -not $Simulation) {
        Invoke-NonFatalStep -StepName "Reindex Tableau search" -ScriptBlock {
            Invoke-FunctionIfAvailable `
                -FunctionName 'Invoke-TableauReindexSearch' `
                -Parameters @{
                    TsmPath = $TsmPath
                } | Out-Null
        }
    }

    ### -----------------------------------------------------------------
    ### Export settings - fatal
    ### -----------------------------------------------------------------

    Write-Log "[STEP] Export Tableau Server settings..."

    if ($Simulation) {
        Set-Content -LiteralPath $SettingsFile -Value '{"simulation":true}' -Encoding ASCII -Force
    }
    else {
        Invoke-FunctionIfAvailable `
            -FunctionName 'Export-TableauSettings' `
            -Parameters @{
                TsmPath      = $TsmPath
                SettingsFile = $SettingsFile
                OutputFile   = $SettingsFile
                OutputPath   = $SettingsFile
            } `
            -Mandatory `
            -FatalExitCode 6 | Out-Null
    }

    ### -----------------------------------------------------------------
    ### Create backup or dry-run dummy file - fatal
    ### -----------------------------------------------------------------

    if ($DryRun -or $Simulation) {
        New-DryRunBackupFile `
            -ExpectedBackupFile $ExpectedBackupFile | Out-Null
    }
    else {
        Write-Log "[STEP] Create Tableau backup..."

        $backupCommandRc = Invoke-FunctionIfAvailable `
            -FunctionName 'Invoke-TableauBackupCommand' `
            -Parameters @{
                TsmPath            = $TsmPath
                BackupBaseName     = $BackupBaseName
                ExpectedBackupFile = $ExpectedBackupFile
                BackupFile         = $ExpectedBackupFile
            } `
            -Mandatory `
            -FatalExitCode 7

        if ([int]$backupCommandRc -ne 0) {
            Throw-BackupFatal `
                -Message "Backup creation command failed with exit code $backupCommandRc." `
                -ExitCode 7
        }
    }

    ### -----------------------------------------------------------------
    ### Validate backup file - fatal
    ### -----------------------------------------------------------------

    Test-ExpectedBackupFile -ExpectedBackupFile $ExpectedBackupFile

    ### -----------------------------------------------------------------
    ### Move generated backup to custom path - fatal
    ### -----------------------------------------------------------------

    $MovedBackupFile = Move-BackupFileToCustomPath `
        -SourceFile $ExpectedBackupFile `
        -DestinationFolder $BackupPath

    ### -----------------------------------------------------------------
    ### Sweep leftovers - non-fatal
    ### -----------------------------------------------------------------

    Invoke-NonFatalStep -StepName "Sweep leftover .tsbak files from Tableau backup folder" -ScriptBlock {
        if (Test-Path -LiteralPath $EffectiveBackupPath -PathType Container) {
            Get-ChildItem -LiteralPath $EffectiveBackupPath -Filter '*.tsbak' -File -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Move-BackupFileToCustomPath `
                        -SourceFile $_.FullName `
                        -DestinationFolder $BackupPath | Out-Null
                }
        }
    }

    ### -----------------------------------------------------------------
    ### Retention - non-fatal, after backup creation to enforce final count
    ### -----------------------------------------------------------------

    Invoke-NonFatalStep -StepName "Apply retention to backup folder after backup creation" -ScriptBlock {
        Invoke-FunctionIfAvailable `
            -FunctionName 'Invoke-BackupRetention' `
            -Parameters @{
                BackupPath = $BackupPath
                SettingsPath = $SettingsPath
                DaysToKeep = $RuntimeConfig.RetentionDays
                MinimumBackupFilesToKeep = $RuntimeConfig.MinimumBackupFilesToKeep
                SettingsDaysToKeep = $RuntimeConfig.SettingsRetentionDays
                MaxBackupFilesToKeep = $RuntimeConfig.RetentionDays
            } | Out-Null
    }

    $FinalRc = 0
    $FailureSummary = ''

    Write-Log "[INFO] Tableau backup workflow finished successfully."
}
catch {
    if ($_.Exception -is [BackupFatalException]) {
        $FinalRc = $_.Exception.ExitCode
        $FailureSummary = $_.Exception.Message
    }
    elseif ($FinalRc -eq 0) {
        $FinalRc = 1
    }

    if (Test-BackupEmpty $FailureSummary) {
        $FailureSummary = $_.Exception.Message
    }

    Write-Log "[ERROR] Backup workflow failed."
    Write-Log "[ERROR] Exit code: $FinalRc"
    Write-Log "[ERROR] $FailureSummary"
}
finally {
    try {
        $WriteEventCommand = Get-Command -Name 'Write-WindowsApplicationEvent' -CommandType Function -ErrorAction SilentlyContinue

        if ($null -ne $WriteEventCommand) {
            $EventParams = @{
                FinalRc = $FinalRc
            }

            if ($WriteEventCommand.Parameters.ContainsKey('FailureSummary')) {
                $EventParams.FailureSummary = $FailureSummary
            }

            if ($WriteEventCommand.Parameters.ContainsKey('LogFile')) {
                $EventParams.LogFile = $LogFile
            }

            Write-WindowsApplicationEvent @EventParams
        }
        else {
            Write-Log "[WARNING] Function not found, skipping Windows Application event: Write-WindowsApplicationEvent"
        }
    }
    catch {
        Write-Log "[WARNING] Failed writing Windows Application event."
        Write-Log "[WARNING] $($_.Exception.Message)"
    }

    try {
        Send-BackupStatusEmail `
            -FinalRc $FinalRc `
            -ComputerName $env:COMPUTERNAME `
            -LogFile $LogFile `
            -BackupFile $MovedBackupFile `
            -ScriptRoot $ScriptRoot `
            -FailureSummary $FailureSummary `
            -DryRun:$DryRun
    }
    catch {
        Write-Log "[WARNING] Final email call failed unexpectedly."
        Write-Log "[WARNING] $($_.Exception.Message)"
    }

    if (-not (Test-BackupEmpty $LogFile)) {
        Write-Log ''
        Write-Log "[FINAL] Script finished with exit code $FinalRc."
    }

    exit $FinalRc
}
