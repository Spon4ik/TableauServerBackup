Set-StrictMode -Version 2.0

#### =====================================================================
#### Email module
####
#### Depends on:
#### - Write-Log
####
#### Reads:
#### Environment variables via modules\Config.ps1
####
#### Converts environment-backed runtime config into the mail object used by
#### validation and Send-MailMessage.
#### =====================================================================

function Test-IsEmpty {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return $true
    }

    if ($Value -is [string]) {
        return ([string]::IsNullOrWhiteSpace($Value))
    }

    if ($Value -is [System.Array]) {
        return (@($Value).Count -eq 0)
    }

    return $false
}

function ConvertTo-StringArray {
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    $items = @()

    if ($Value -is [System.Array]) {
        $items = @($Value)
    }
    else {
        $items = @(([string]$Value) -split '[;,]')
    }

    $result = @()

    foreach ($item in $items) {
        if ($null -ne $item) {
            $text = ([string]$item).Trim()
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $result += $text
            }
        }
    }

    return @($result)
}

function Get-MailSettings {
    param(
        [AllowEmptyString()]
        [string]$ScriptRoot = '',

        [AllowNull()]
        $RuntimeConfig = $null
    )

    if ($null -eq $RuntimeConfig) {
        if (Get-Command -Name 'Get-BackupRuntimeConfig' -CommandType Function -ErrorAction SilentlyContinue) {
            $RuntimeConfig = Get-BackupRuntimeConfig
        }
    }

    if ($null -ne $RuntimeConfig) {
        if (Get-Command -Name 'ConvertTo-MailSettingsFromEnvironment' -CommandType Function -ErrorAction SilentlyContinue) {
            return ConvertTo-MailSettingsFromEnvironment -Config $RuntimeConfig
        }
    }

    throw 'Mail settings are environment-based. Run scripts\Setup-TableauServerBackup.ps1 to configure notification settings.'
}

function Get-ConfigValue {
    param(
        [AllowNull()]
        $Config,

        [Parameter(Mandatory = $true)]
        [string[]]$Names,

        $DefaultValue = $null
    )

    if ($null -eq $Config) {
        return $DefaultValue
    }

    foreach ($name in $Names) {
        foreach ($prop in $Config.PSObject.Properties) {
            if ($prop.Name -ieq $name) {
                return $prop.Value
            }
        }
    }

    return $DefaultValue
}

function Get-SmtpConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        $EmailConfig,

        [Parameter(Mandatory = $true)]
        [string[]]$Names,

        $DefaultValue = $null
    )

    # Accept older flat key names for callers that pass a mail object directly.
    $flatValue = Get-ConfigValue -Config $EmailConfig -Names $Names -DefaultValue $null
    if ($null -ne $flatValue) {
        return $flatValue
    }

    # Current config shape: Smtp.Server / Smtp.Port / Smtp.UseSsl.
    $smtpObject = Get-ConfigValue -Config $EmailConfig -Names @('Smtp', 'SMTP', 'smtp') -DefaultValue $null
    if ($null -ne $smtpObject) {
        return Get-ConfigValue -Config $smtpObject -Names $Names -DefaultValue $DefaultValue
    }

    return $DefaultValue
}

function Get-ConfigPropertyNamesText {
    param(
        [AllowNull()]
        $Config
    )

    if ($null -eq $Config) {
        return '(config object is null)'
    }

    $names = @()

    foreach ($prop in $Config.PSObject.Properties) {
        $names += $prop.Name
    }

    if (@($names).Count -eq 0) {
        return '(no properties found)'
    }

    return ($names -join ', ')
}

function Test-MailSettings {
    param(
        [Parameter(Mandatory = $true)]
        $EmailConfig
    )

    $enabledRaw = Get-ConfigValue -Config $EmailConfig -Names @('Enabled', 'enabled') -DefaultValue $true
    $enabled = $true

    if ($enabledRaw -is [bool]) {
        $enabled = $enabledRaw
    }
    else {
        $enabled = (([string]$enabledRaw).Trim() -match '^(true|1|yes|y)$')
    }

    if (-not $enabled) {
        throw 'Mail settings validation failed: email is disabled.'
    }

    $smtpServer = Get-SmtpConfigValue -EmailConfig $EmailConfig -Names @(
        'Server', 'server',
        'Host', 'host',
        'SmtpServer', 'SMTPServer', 'smtpServer',
        'SmtpHost', 'SMTPHost', 'smtpHost',
        'SmtpRelay', 'SMTPRelay', 'smtpRelay',
        'Relay', 'relay'
    )

    $smtpPortRaw = Get-SmtpConfigValue -EmailConfig $EmailConfig -Names @(
        'Port', 'port',
        'SmtpPort', 'SMTPPort', 'smtpPort'
    ) -DefaultValue 25

    $from = Get-ConfigValue -Config $EmailConfig -Names @(
        'From', 'from',
        'MailFrom', 'mailFrom',
        'Sender', 'sender'
    )

    $toRaw = Get-ConfigValue -Config $EmailConfig -Names @(
        'To', 'to',
        'MailTo', 'mailTo',
        'Recipients', 'recipients'
    )

    $to = ConvertTo-StringArray -Value $toRaw

    if (Test-IsEmpty $smtpServer) {
        $knownKeys = Get-ConfigPropertyNamesText -Config $EmailConfig
        $smtpKeys = Get-ConfigPropertyNamesText -Config (Get-ConfigValue -Config $EmailConfig -Names @('Smtp', 'SMTP', 'smtp') -DefaultValue $null)
        throw "Mail settings validation failed: SMTP server is empty. Top-level keys: $knownKeys. Smtp keys: $smtpKeys"
    }

    if (Test-IsEmpty $from) {
        $knownKeys = Get-ConfigPropertyNamesText -Config $EmailConfig
        throw "Mail settings validation failed: Mail From is empty. Available mail setting keys: $knownKeys"
    }

    if (@($to).Count -eq 0) {
        $knownKeys = Get-ConfigPropertyNamesText -Config $EmailConfig
        throw "Mail settings validation failed: Mail To is empty. Available mail setting keys: $knownKeys"
    }

    try {
        $null = [int]$smtpPortRaw
    }
    catch {
        throw "Mail settings validation failed: SMTP port is not numeric: $smtpPortRaw"
    }

    return $true
}

function New-BackupStatusEmailBody {
    param(
        [Parameter(Mandatory = $true)]
        [int]$FinalRc,

        [AllowEmptyString()]
        [string]$FailureSummary = '',

        [AllowEmptyString()]
        [string]$LogFile = '',

        [AllowEmptyString()]
        [string]$BackupFile = '',

        [bool]$DryRun = $false,

        [bool]$EmailOnlyTest = $false,

        [AllowEmptyString()]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    $statusText = 'SUCCESS'
    if ($FinalRc -ne 0) {
        $statusText = 'FAILED'
    }

    $runTypeText = 'Normal backup'
    if ($EmailOnlyTest) {
        $runTypeText = 'Email-only test'
    }
    elseif ($DryRun) {
        $runTypeText = 'Dry run'
    }

    $backupFileText = $BackupFile
    if ([string]::IsNullOrWhiteSpace($backupFileText)) {
        $backupFileText = '(not available)'
    }

    $runSummaryText = $FailureSummary
    if ([string]::IsNullOrWhiteSpace($runSummaryText)) {
        if ($EmailOnlyTest) {
            $runSummaryText = 'Email-only test completed. No Tableau operations were executed.'
        }
        elseif ($FinalRc -eq 0) {
            $runSummaryText = 'Backup workflow completed successfully.'
        }
        else {
            $runSummaryText = 'Backup workflow failed, but failure details were not provided.'
        }
    }

    $lines = @(
        'Tableau Server Backup Status',
        '',
        "Computer        : $ComputerName",
        "Status          : $statusText",
        "Exit Code       : $FinalRc",
        "Run Type       : $runTypeText",
        "Backup File     : $backupFileText",
        "Log File        : $LogFile",
        "Timestamp       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
        '',
        'Run Summary:',
        $runSummaryText,
        '',
        'This message was generated automatically.'
    )

    return ($lines -join "`r`n")
}

function Send-BackupStatusEmail {
    param(
        [Parameter(Mandatory = $true)]
        [int]$FinalRc,

        [AllowEmptyString()]
        [string]$ScriptRoot = '',

        [AllowEmptyString()]
        [string]$FailureSummary = '',

        [AllowEmptyString()]
        [string]$LogFile = '',

        [AllowEmptyString()]
        [string]$BackupFile = '',

        [AllowEmptyString()]
        [string]$MovedBackupFile = '',

        [AllowEmptyString()]
        [string]$ExpectedBackupFile = '',

        [AllowEmptyString()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [switch]$DryRun,

        [switch]$EmailOnlyTest
    )

    Write-Log '[INFO] Preparing status email...'

    try {
        $emailConfig = Get-MailSettings -ScriptRoot $ScriptRoot

        $enabledRaw = Get-ConfigValue -Config $emailConfig -Names @('Enabled', 'enabled') -DefaultValue $false
        $enabled = $false
        if ($enabledRaw -is [bool]) {
            $enabled = $enabledRaw
        }
        else {
            $enabled = (([string]$enabledRaw).Trim() -match '^(true|1|yes|y)$')
        }

        if (-not $enabled) {
            Write-Log '[INFO] Email notifications are disabled. Skipping status email.'
            return $true
        }

        Test-MailSettings -EmailConfig $emailConfig | Out-Null

        $smtpServer = Get-SmtpConfigValue -EmailConfig $emailConfig -Names @(
            'Server', 'server',
            'Host', 'host',
            'SmtpServer', 'SMTPServer', 'smtpServer',
            'SmtpHost', 'SMTPHost', 'smtpHost',
            'SmtpRelay', 'SMTPRelay', 'smtpRelay',
            'Relay', 'relay'
        )

        $smtpPortRaw = Get-SmtpConfigValue -EmailConfig $emailConfig -Names @(
            'Port', 'port',
            'SmtpPort', 'SMTPPort', 'smtpPort'
        ) -DefaultValue 25

        $useSslRaw = Get-SmtpConfigValue -EmailConfig $emailConfig -Names @(
            'UseSsl', 'UseSSL', 'useSsl',
            'Ssl', 'SSL', 'ssl'
        ) -DefaultValue $false

        $from = Get-ConfigValue -Config $emailConfig -Names @(
            'From', 'from',
            'MailFrom', 'mailFrom',
            'Sender', 'sender'
        )

        $toRaw = Get-ConfigValue -Config $emailConfig -Names @(
            'To', 'to',
            'MailTo', 'mailTo',
            'Recipients', 'recipients'
        )

        $ccRaw = Get-ConfigValue -Config $emailConfig -Names @(
            'Cc', 'CC', 'cc'
        ) -DefaultValue @()

        $bccRaw = Get-ConfigValue -Config $emailConfig -Names @(
            'Bcc', 'BCC', 'bcc'
        ) -DefaultValue @()

        $deliveryNotificationOption = Get-ConfigValue -Config $emailConfig -Names @(
            'DeliveryNotificationOption', 'deliveryNotificationOption'
        ) -DefaultValue $null

        $to = ConvertTo-StringArray -Value $toRaw
        $cc = ConvertTo-StringArray -Value $ccRaw
        $bcc = ConvertTo-StringArray -Value $bccRaw

        $subjectPrefix = Get-ConfigValue -Config $emailConfig -Names @(
            'SubjectPrefix', 'subjectPrefix'
        ) -DefaultValue '[Tableau Backup]'

        try {
            $smtpPort = [int]$smtpPortRaw
        }
        catch {
            throw "SMTP port is not numeric: $smtpPortRaw"
        }

        $useSsl = $false
        if ($useSslRaw -is [bool]) {
            $useSsl = $useSslRaw
        }
        else {
            $useSslText = ([string]$useSslRaw).Trim()
            if ($useSslText -match '^(true|1|yes|y)$') {
                $useSsl = $true
            }
        }

        $statusText = 'SUCCESS'
        if ($FinalRc -ne 0) {
            $statusText = 'FAILED'
        }

        if ([string]::IsNullOrWhiteSpace($BackupFile)) {
            if (-not [string]::IsNullOrWhiteSpace($MovedBackupFile)) {
                $BackupFile = $MovedBackupFile
            }
            elseif (-not [string]::IsNullOrWhiteSpace($ExpectedBackupFile)) {
                $BackupFile = $ExpectedBackupFile
            }
        }

        $subject = "$subjectPrefix $statusText on $ComputerName - exit code $FinalRc"

        if ($EmailOnlyTest) {
            $subject = "$subjectPrefix EMAIL ONLY TEST on $ComputerName"
        }
        elseif ($DryRun) {
            $subject = "$subjectPrefix DRY RUN $statusText on $ComputerName - exit code $FinalRc"
        }

        $bodyParams = @{
            FinalRc        = $FinalRc
            FailureSummary = $FailureSummary
            LogFile        = $LogFile
            BackupFile     = $BackupFile
            DryRun         = [bool]$DryRun
            EmailOnlyTest  = [bool]$EmailOnlyTest
            ComputerName   = $ComputerName
        }

        $body = New-BackupStatusEmailBody @bodyParams

        Write-Log "[INFO] SMTP server : $smtpServer"
        Write-Log "[INFO] SMTP port   : $smtpPort"
        Write-Log "[INFO] SMTP UseSsl : $useSsl"
        Write-Log "[INFO] Mail From   : $from"
        Write-Log "[INFO] Mail To     : $($to -join '; ')"
        Write-Log "[INFO] Mail To count: $(@($to).Count)"

        if (@($cc).Count -gt 0) {
            Write-Log "[INFO] Mail Cc     : $($cc -join '; ')"
        }

        if (@($bcc).Count -gt 0) {
            Write-Log "[INFO] Mail Bcc count: $(@($bcc).Count)"
        }

        if ($null -ne $deliveryNotificationOption -and -not [string]::IsNullOrWhiteSpace([string]$deliveryNotificationOption)) {
            Write-Log "[INFO] DeliveryNotificationOption: $deliveryNotificationOption"
        }

        $mailParams = @{
            SmtpServer = $smtpServer
            Port       = $smtpPort
            From       = $from
            To         = @($to)
            Subject    = $subject
            Body       = $body
        }

        if ($useSsl) {
            $mailParams.UseSsl = $true
        }

        if (@($cc).Count -gt 0) {
            $mailParams.Cc = @($cc)
        }

        if (@($bcc).Count -gt 0) {
            $mailParams.Bcc = @($bcc)
        }

        if ($null -ne $deliveryNotificationOption -and -not [string]::IsNullOrWhiteSpace([string]$deliveryNotificationOption)) {
            $mailParams.DeliveryNotificationOption = $deliveryNotificationOption
        }

        Send-MailMessage @mailParams

        Write-Log '[INFO] Status email submitted successfully to SMTP relay.'
        Write-Log '[INFO] SMTP relay acceptance confirms message handoff only; final inbox delivery depends on downstream mail systems.'
        return $true
    }
    catch {
        Write-Log '[WARNING] Failed to send status email.'
        Write-Log "[WARNING] $($_.Exception.GetType().FullName): $($_.Exception.Message)"

        if ($null -ne $_.Exception.InnerException) {
            Write-Log "[WARNING] Inner exception: $($_.Exception.InnerException.GetType().FullName): $($_.Exception.InnerException.Message)"
        }

        return $false
    }
}

function Send-BackupEmailOnlyTest {
    param(
        [AllowEmptyString()]
        [string]$ScriptRoot = '',

        [AllowEmptyString()]
        [string]$LogFile = '',

        [AllowEmptyString()]
        [string]$ComputerName = $env:COMPUTERNAME
    )

    $params = @{
        FinalRc        = 0
        ScriptRoot     = $ScriptRoot
        FailureSummary = 'Email-only test mode. No Tableau operations were executed.'
        LogFile        = $LogFile
        BackupFile     = '(email-only test)'
        ComputerName   = $ComputerName
        EmailOnlyTest  = $true
    }

    return Send-BackupStatusEmail @params
}
