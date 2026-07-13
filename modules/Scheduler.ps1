#requires -version 5.1

Set-StrictMode -Version 2.0

function Get-TableauBackupScheduledTask {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )

    try {
        return Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Message -match '(?i)not found|cannot find|does not exist') {
            return $null
        }

        throw
    }
}

function Get-TableauBackupScheduledTaskSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )

    $task = Get-TableauBackupScheduledTask -TaskName $TaskName

    if ($null -eq $task) {
        return [pscustomobject]@{
            Action   = 'Inspect'
            TaskName = $TaskName
            Exists   = $false
            State    = 'NotFound'
            Actions  = @()
            Triggers = @()
            UserId   = ''
        }
    }

    return [pscustomobject]@{
        Action   = 'Inspect'
        TaskName = $TaskName
        Exists   = $true
        State    = [string]$task.State
        Actions  = @($task.Actions | ForEach-Object { "{0} {1}" -f $_.Execute, $_.Arguments })
        Triggers = @($task.Triggers | ForEach-Object { [string]$_.StartBoundary })
        UserId   = [string]$task.Principal.UserId
    }
}

function New-TableauBackupScheduledTaskDefinition {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BatchPath,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^([01]?\d|2[0-3]):[0-5]\d$')]
        [string]$DailyTime,

        [ValidateRange(1, 31)]
        [int]$DaysInterval = 1
    )

    if (-not (Test-Path -LiteralPath $BatchPath -PathType Leaf)) {
        throw "Scheduled-task batch file was not found: $BatchPath"
    }

    if (-not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
        throw "Scheduled-task working directory was not found: $WorkingDirectory"
    }

    $timeParts = $DailyTime -split ':'
    $startAt = Get-Date -Hour ([int]$timeParts[0]) -Minute ([int]$timeParts[1]) -Second 0

    return [pscustomobject]@{
        Action = New-ScheduledTaskAction -Execute $BatchPath -WorkingDirectory $WorkingDirectory
        Trigger = New-ScheduledTaskTrigger -Daily -At $startAt -DaysInterval $DaysInterval
        Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew
    }
}

function Register-TableauBackupScheduledTask {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskName,

        [Parameter(Mandatory = $true)]
        $Definition,

        [Parameter(Mandatory = $true)]
        [pscredential]$Credential
    )

    $credentialText = $Credential.GetNetworkCredential().Password
    try {
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $Definition.Action `
            -Trigger $Definition.Trigger `
            -Settings $Definition.Settings `
            -Description 'Runs Tableau Server Backup through the repository batch entry point.' `
            -User $Credential.UserName `
            -Password $credentialText `
            -RunLevel Highest `
            -Force | Out-Null
    }
    finally {
        $credentialText = $null
    }
}

function Invoke-TableauBackupScheduledTaskAction {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Inspect', 'CreateOrUpdate', 'Enable', 'Disable', 'Remove')]
        [string]$Action,

        [Parameter(Mandatory = $true)]
        [string]$TaskName,

        [string]$BatchPath = '',

        [string]$WorkingDirectory = '',

        [ValidatePattern('^([01]?\d|2[0-3]):[0-5]\d$')]
        [string]$DailyTime = '02:00',

        [ValidateRange(1, 31)]
        [int]$DaysInterval = 1,

        [string]$RunAsUser = '',

        [pscredential]$Credential,

        [bool]$WhatIfOnly = $false
    )

    if ($Action -eq 'Inspect') {
        return Get-TableauBackupScheduledTaskSummary -TaskName $TaskName
    }

    if ($WhatIfOnly) {
        return [pscustomobject]@{
            Action   = $Action
            TaskName = $TaskName
            Planned  = $true
            Result   = 'No scheduled-task changes were made.'
        }
    }

    switch ($Action) {
        'CreateOrUpdate' {
            $definition = New-TableauBackupScheduledTaskDefinition `
                -BatchPath $BatchPath `
                -WorkingDirectory $WorkingDirectory `
                -DailyTime $DailyTime `
                -DaysInterval $DaysInterval

            if ($null -eq $Credential) {
                $credentialPrompt = 'Enter the Windows account that Task Scheduler should use. The script never saves or logs the password; Windows Task Scheduler stores it securely only when required for unattended execution.'
                $Credential = Get-Credential -UserName $RunAsUser -Message $credentialPrompt
            }

            if ($null -eq $Credential) {
                throw 'A Windows credential is required to create or update the scheduled task.'
            }

            Register-TableauBackupScheduledTask `
                -TaskName $TaskName `
                -Definition $definition `
                -Credential $Credential

            return Get-TableauBackupScheduledTaskSummary -TaskName $TaskName
        }
        'Enable' {
            Enable-ScheduledTask -TaskName $TaskName -ErrorAction Stop | Out-Null
        }
        'Disable' {
            Disable-ScheduledTask -TaskName $TaskName -ErrorAction Stop | Out-Null
        }
        'Remove' {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        }
    }

    return [pscustomobject]@{
        Action   = $Action
        TaskName = $TaskName
        Planned  = $false
        Result   = 'Completed'
    }
}
