$ProjectRoot = Split-Path -Parent $PSScriptRoot

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

Describe 'Setup script' {
    $setupScript = Join-Path $ProjectRoot 'scripts\Setup-TableauServerBackup.ps1'

    BeforeEach {
        $env:TABLEAU_SERVER_DATA_DIR = $null
        $env:TABLEAU_BACKUP_ROOT = $null
        $env:TABLEAU_BACKUP_MAIL_TO = $null
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
            -HttpRequestsCleanupEnabled 'true' `
            -HttpRequestsRetentionDays '730' `
            -ReindexEnabled 'true' `
            -Force | Out-Null

        $env:TABLEAU_SERVER_DATA_DIR | Should Be $tableauData
        $env:TABLEAU_BACKUP_ROOT | Should Be $backupRoot
        $env:TABLEAU_BACKUP_MAIL_TO | Should Be 'admin@example.com'
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
