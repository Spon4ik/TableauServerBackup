#requires -version 5.1

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$tokens = $null
$parseErrors = @()

foreach ($file in Get-ChildItem -Recurse -File | Where-Object { $_.Extension -ieq '.ps1' -and $_.FullName -notmatch '\\nppBackup\\' }) {
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        foreach ($error in $errors) {
            $parseErrors += [pscustomobject]@{
                File = $file.FullName
                Line = $error.Extent.StartLineNumber
                Message = $error.Message
            }
        }
    }
}

if (@($parseErrors).Count -gt 0) {
    $parseErrors | Format-Table -AutoSize -Wrap
    exit 1
}

Invoke-Pester -Script (Join-Path $projectRoot 'tests') -EnableExit
