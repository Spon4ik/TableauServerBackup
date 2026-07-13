#requires -version 5.1

param(
    [string[]]$Path = @('.'),
    [switch]$Quiet
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-ScannableFiles {
    param(
        [string[]]$InputPath
    )

    foreach ($itemPath in $InputPath) {
        if (Test-Path -LiteralPath $itemPath -PathType Leaf) {
            Get-Item -LiteralPath $itemPath
            continue
        }

        Get-ChildItem -LiteralPath $itemPath -Recurse -File -ErrorAction Stop |
            Where-Object {
                $_.FullName -notmatch '\\\.git\\' -and
                $_.FullName -notmatch '\\bin\\' -and
                $_.FullName -notmatch '\\obj\\' -and
                $_.FullName -notmatch '\\publish\\' -and
                $_.FullName -notmatch '\\nppBackup\\' -and
                $_.Name -notmatch '\.local\.json$' -and
                $_.Name -notmatch '^MailSettings\.json$' -and
                $_.Name -notmatch '\.tsbak$' -and
                $_.Name -notmatch '\.bak$'
            }
    }
}

$patterns = @(
    [pscustomobject]@{ Name = 'NonExampleEmail'; Regex = '[A-Z0-9._%+-]+@(?!example\.com\b)[A-Z0-9.-]+\.[A-Z]{2,}' },
    [pscustomobject]@{ Name = 'PossibleSecret'; Regex = '(?i)(password|passwd|pwd|secret|token|apikey|api_key)\s*[:=]' }
)

$findings = @()

foreach ($file in Get-ScannableFiles -InputPath $Path) {
    foreach ($pattern in $patterns) {
        $matches = Select-String -LiteralPath $file.FullName -Pattern $pattern.Regex -AllMatches -ErrorAction SilentlyContinue
        foreach ($match in $matches) {
            $findings += [pscustomobject]@{
                Pattern = $pattern.Name
                File = $file.FullName
                Line = $match.LineNumber
                Text = $match.Line.Trim()
            }
        }
    }
}

if (@($findings).Count -gt 0) {
    if (-not $Quiet) {
        $findings | Format-Table -AutoSize -Wrap
    }
    exit 1
}

if (-not $Quiet) {
    Write-Host 'No Git hygiene findings.'
}

exit 0
