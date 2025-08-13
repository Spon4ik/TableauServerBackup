@echo off


:: plan:
:: 1) Move any existing backups first (NON-FATAL)
:: 2) Cleanup logs - NON-FATAL
:: 3) Export Tableau Server settings (FATAL on failure)
:: 4) Create fresh backup (FATAL on failure)
:: 5) Move the just-created backup (FATAL on failure)
:: 6) Optional: sweep any other leftover .tsbak (NON-FATAL)
:: 7) Retention: Delete old backups and settings older than 5 days from destination (custom) folder (best-effort)

setlocal EnableExtensions

:: ===== Auto-elevate to Administrator via UAC =====
>nul 2>&1 net session
if %errorlevel% NEQ 0 (
    echo [INFO] Requesting administrative privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs -ArgumentList '%*'"
    exit /b
)


:: Optional: uncomment to enable command tracing for debugging
set TRACE=1
if defined TRACE echo [TRACE] Command echo enabled for debugging.

:: Set date and time in yyyyMMdd_HH-mm-ss format
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HH-mm-ss"') do set timestamp=%%I
set today=%timestamp:~0,8%
if "%timestamp%"=="" (echo [ERROR] Unable to determine timestamp & exit /b 1)

:: === Read paths from system environment variables ===
set "DataDir=%TABLEAU_SERVER_DATA_DIR%"
set "customBackupPath=%TableauServerBackup%"

:: === Validate variables and log ===
if "%DataDir%"=="" (
    echo [ERROR] TABLEAU_SERVER_DATA_DIR is not set. Exiting...
    exit /b 1
) else (
    echo [INFO] Tableau install dir: %DataDir%
)

if "%customBackupPath%"=="" (
    echo [ERROR] TableauServerBackup is not set. Exiting...
    exit /b 1
) else (
    echo [INFO] Custom backup path: %customBackupPath%
)

:: Build default backup path dynamically
set defaultBackupPath=%DataDir%\data\tabsvc\files\backups

:: Define other paths
set backupBaseName=%COMPUTERNAME%_backup-%timestamp%
set expectedBackup=%defaultBackupPath%\%backupBaseName%.tsbak
set tsbakPath=%customBackupPath%\backups
set logPath=%customBackupPath%\log
:: set logFile=%logPath%\backup_log_%timestamp%.log
set logFile=%logPath%\backup_log_%today%.log
:: set logFile=%logPath%\backup_log.log
set settingsPath=%customBackupPath%\settings
set settingsFile=%settingsPath%\server_settings-%timestamp%.json


:: Ensure all required directories exist
if not exist "%customBackupPath%" mkdir "%customBackupPath%"
if not exist "%tsbakPath%" mkdir "%tsbakPath%"
if not exist "%logPath%" mkdir "%logPath%"
if not exist "%settingsPath%" mkdir "%settingsPath%"


:: Start logging
echo === Tableau Server Backup Log - %date% %time% === > "%logFile%"
echo [INFO] Using default path: %defaultBackupPath% >> "%logFile%"
echo [INFO] Using custom path: %customBackupPath% >> "%logFile%"


:: 1) Move any existing backups first (NON-FATAL)
echo [STEP] Pre-clean: move any existing *.tsbak files from default to custom path first... >> "%logFile%"
call :MoveAllBackups >> "%logFile%" 2>&1


:: 2) Cleanup logs (best-effort)
echo [STEP] Cleanup old Tableau logs... >> "%logFile%"
call tsm maintenance cleanup -l --log-files-retention 7 --request-timeout 1800 >> "%logFile%" 2>&1


:: 3) Export Tableau Server settings (FATAL on failure)
echo [STEP] Export Tableau Server settings... >> "%logFile%"
call tsm settings export -f "%settingsFile%" >> "%logFile%" 2>&1
if not exist "%settingsFile%" (
    echo [ERROR] Settings export failed. Exiting... >> "%logFile%"
    exit /b 1
)


:: 4) Create fresh backup (FATAL on failure)
echo [STEP] Creating backup... >> "%logFile%"
call tsm maintenance backup --file "%backupBaseName%" >> "%logFile%" 2>&1
if not exist "%expectedBackup%" (
                    
    echo [ERROR] Backup file not created. Exiting... >> "%logFile%"
    exit /b 1
)


:: 5) Move the just-created backup (FATAL on failure)
echo [STEP] Moving newly created backup to custom path... >> "%logFile%"
call :MoveOne "%expectedBackup%" "%tsbakPath%" >> "%logFile%" 2>&1
if errorlevel 1 (
                    
    echo [ERROR] Post-backup move failed. Exiting... >> "%logFile%"
    exit /b 1
)

:: 6) Optional: sweep any other leftover .tsbak (NON-FATAL)
echo [STEP] [Optional] Sweep remaining .tsbak to custom path... >> "%logFile%"
call :MoveAllBackups >> "%logFile%" 2>&1

:: 7) Retention: Delete old backups and settings older than 5 days (best-effort)
echo [STEP] Deleting backup files older than 5 days... >> "%logFile%"
forfiles /p "%tsbakPath%" /m *.tsbak /d -5 /c "cmd /c del @path" >> "%logFile%" 2>&1

echo [STEP] Deleting settings files older than 5 days... >> "%logFile%"
forfiles /p "%settingsPath%" /m server_settings-*.json /d -5 /c "cmd /c del @path" >> "%logFile%" 2>&1

echo [DONE] Backup process completed. >> "%logFile%"
endlocal
exit /b

:MoveAllBackups
setlocal
if not exist "%defaultBackupPath%" (
    echo [INFO] Default backup path not found: "%defaultBackupPath%". Nothing to clean.
    endlocal & exit /b 0
)
if not exist "%defaultBackupPath%\*.tsbak" (
    echo [INFO] No .tsbak files found to move - pre/post sweep.
    endlocal & exit /b 0
)
attrib -R "%defaultBackupPath%\*.tsbak" 2>nul
move /Y "%defaultBackupPath%\*.tsbak" "%tsbakPath%" >nul 2>&1
endlocal & exit /b 0

:MoveOne
setlocal
set "src=%~1"
set "destDir=%~2"
if not exist "%src%" (
    echo [ERROR] Expected backup not found: "%src%"
    endlocal & exit /b 1
)
attrib -R "%src%" 2>nul
move /Y "%src%" "%destDir%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to move "%src%" to "%destDir%"
    endlocal & exit /b 1
)
endlocal & exit /b 0
