Set-StrictMode -Version 2.0

## =====================================================================
## File move module
## =====================================================================

function Get-CanonicalFolderPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    return $item.FullName.TrimEnd('\')
}

function Move-OneBackupFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFile,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder,

        [switch]$Fatal
    )

    Write-Log "[INFO] Move-OneBackupFile source: $SourceFile"
    Write-Log "[INFO] Move-OneBackupFile destination folder: $DestinationFolder"

    try {
        if (-not (Test-Path -LiteralPath $SourceFile -PathType Leaf)) {
            $msg = "Source backup file not found: $SourceFile"
            Write-Log "[ERROR] $msg"

            if ($Fatal) {
                throw [BackupFatalException]::new($msg, 9)
            }

            return 1
        }

        if (-not (Test-Path -LiteralPath $DestinationFolder -PathType Container)) {
            Write-Log "[INFO] Destination folder does not exist. Creating: $DestinationFolder"
            New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $DestinationFolder -PathType Container)) {
            $msg = "Failed to create destination folder: $DestinationFolder"
            Write-Log "[ERROR] $msg"

            if ($Fatal) {
                throw [BackupFatalException]::new($msg, 9)
            }

            return 1
        }

        $sourceItem = Get-Item -LiteralPath $SourceFile -ErrorAction Stop
        $sourceSize = [int64]$sourceItem.Length

        Write-Log "[INFO] Source backup size before move: $sourceSize bytes."

        if ($sourceSize -eq 0) {
            $msg = "Source backup file exists but is empty: $SourceFile"
            Write-Log "[ERROR] $msg"

            if ($Fatal) {
                throw [BackupFatalException]::new($msg, 9)
            }

            return 1
        }

        $destinationFile = Join-Path $DestinationFolder $sourceItem.Name

        if (Test-Path -LiteralPath $destinationFile -PathType Leaf) {
            $msg = "Destination backup file already exists. Refusing to overwrite: $destinationFile"
            Write-Log "[ERROR] $msg"

            if ($Fatal) {
                throw [BackupFatalException]::new($msg, 9)
            }

            return 1
        }

        Write-Log "[CMD] attrib -R `"$SourceFile`""
        & attrib -R $SourceFile 2>$null
        Write-Log "[RC] attrib returned $LASTEXITCODE."

        Write-Log "[CMD] Move-Item -LiteralPath `"$SourceFile`" -Destination `"$destinationFile`""
        Move-Item -LiteralPath $SourceFile -Destination $destinationFile -Force -ErrorAction Stop

        if (-not (Test-Path -LiteralPath $destinationFile -PathType Leaf)) {
            $msg = "Move completed but destination backup file was not found: $destinationFile"
            Write-Log "[ERROR] $msg"

            if ($Fatal) {
                throw [BackupFatalException]::new($msg, 9)
            }

            return 1
        }

        $destinationItem = Get-Item -LiteralPath $destinationFile -ErrorAction Stop
        $destinationSize = [int64]$destinationItem.Length

        Write-Log "[INFO] Destination backup size after move: $destinationSize bytes."

        if ($destinationSize -ne $sourceSize) {
            $msg = "Moved backup size does not match source size. Source=$sourceSize; Destination=$destinationSize"
            Write-Log "[ERROR] $msg"

            if ($Fatal) {
                throw [BackupFatalException]::new($msg, 9)
            }

            return 1
        }

        if (Test-Path -LiteralPath $SourceFile -PathType Leaf) {
            $msg = "Source backup still exists after move: $SourceFile"
            Write-Log "[ERROR] $msg"

            if ($Fatal) {
                throw [BackupFatalException]::new($msg, 9)
            }

            return 1
        }

        Write-Log "[OK] Backup moved and validated successfully: $destinationFile"
        return 0
    }
    catch [BackupFatalException] {
        throw
    }
    catch {
        $msg = "Move-OneBackupFile failed: $($_.Exception.Message)"
        Write-Log "[ERROR] $msg"

        if ($Fatal) {
            throw [BackupFatalException]::new($msg, 9)
        }

        return 1
    }
}

function Move-AllTableauBackups {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFolder
    )

    Write-Log "[INFO] Checking Tableau backup path: $SourceFolder"

    try {
        if (-not (Test-Path -LiteralPath $SourceFolder -PathType Container)) {
            Write-Log "[WARN] Tableau backup path not found: $SourceFolder"
            return 1
        }

        if (-not (Test-Path -LiteralPath $DestinationFolder -PathType Container)) {
            Write-Log "[INFO] Custom backup path not found. Creating: $DestinationFolder"
            New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null
        }

        if (-not (Test-Path -LiteralPath $DestinationFolder -PathType Container)) {
            Write-Log "[WARN] Failed to create custom backup path: $DestinationFolder"
            return 1
        }

        $srcCan = Get-CanonicalFolderPath -Path $SourceFolder
        $dstCan = Get-CanonicalFolderPath -Path $DestinationFolder

        Write-Log "[INFO] Move-AllTableauBackups source canonical: $srcCan"
        Write-Log "[INFO] Move-AllTableauBackups destination canonical: $dstCan"

        if ($srcCan -ieq $dstCan) {
            Write-Log "[WARN] Tableau backup path and custom backup path are the same folder."
            Write-Log "[WARN] Skipping Move-AllTableauBackups to avoid moving files into themselves."
            return 0
        }

        $files = Get-ChildItem -LiteralPath $SourceFolder -Filter '*.tsbak' -File -ErrorAction SilentlyContinue

        if ($null -eq $files -or $files.Count -eq 0) {
            Write-Log "[INFO] No .tsbak files found to move."
            return 0
        }

        Write-Log "[INFO] .tsbak files found in Tableau backup path: $($files.Count)"

        $moveAllRc = 0

        foreach ($file in $files) {
            Write-Log ''
            Write-Log "[INFO] Move-AllTableauBackups processing: $($file.FullName)"

            $targetFile = Join-Path $DestinationFolder $file.Name
            $sourceFileToMove = $file.FullName

            if (Test-Path -LiteralPath $targetFile -PathType Leaf) {
                $newName = '{0}_moved_{1}{2}' -f $file.BaseName, (Get-Date -Format 'yyyyMMdd_HH-mm-ss'), $file.Extension
                $renamedSource = Join-Path $SourceFolder $newName

                Write-Log "[WARN] Destination file already exists."
                Write-Log "[WARN] Incoming file will be renamed before move to avoid overwrite."
                Write-Log "[INFO] New source name before move: $renamedSource"

                Rename-Item -LiteralPath $file.FullName -NewName $newName -ErrorAction Stop
                $sourceFileToMove = $renamedSource
            }

            $oneRc = Move-OneBackupFile -SourceFile $sourceFileToMove -DestinationFolder $DestinationFolder
            Write-Log "[RC] Move-OneBackupFile returned $oneRc."

            if ($oneRc -ne 0) {
                Write-Log "[WARN] Failed to move file: $sourceFileToMove"
                $moveAllRc = $oneRc
            }
        }

        if ($moveAllRc -ne 0) {
            Write-Log "[WARN] Move-AllTableauBackups completed with one or more failures."
            return $moveAllRc
        }

        Write-Log "[OK] Move-AllTableauBackups completed."
        return 0
    }
    catch {
        Write-Log "[WARN] Move-AllTableauBackups failed: $($_.Exception.Message)"
        return 1
    }
}