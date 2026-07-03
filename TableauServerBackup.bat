@echo off
setlocal EnableExtensions
rem =====================================================================
rem Tiny Task Scheduler entrypoint for Tableau Server backup.
rem
rem Recommended Task Scheduler settings:
rem   Program/script:
rem      <project-folder>\TableauServerBackup.bat
rem
rem   Start in:
rem      <project-folder>
rem
rem   Also enable:
rem      Run whether user is logged on or not
rem      Run with highest privileges
rem
rem Optional manual test modes:
rem   <project-folder>\TableauServerBackup.bat -EmailOnlyTest
rem   <project-folder>\TableauServerBackup.bat -DryRun
rem =====================================================================

set "SCRIPT_DIR=%~dp0"
set "PS1=%SCRIPT_DIR%TableauServerBackup.ps1"

if not exist "%PS1%" (
    echo [ERROR] PowerShell orchestrator was not found:
    echo [ERROR] "%PS1%"
    exit /b 1
)

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" ^
  -NoProfile ^
  -ExecutionPolicy Bypass ^
  -File "%PS1%" %*

exit /b %ERRORLEVEL%
