# Scheduler

Create a Windows Task Scheduler task that runs:

```text
Program/script: <project-folder>\TableauServerBackup.bat
Start in:       <project-folder>
```

Recommended settings:

- Run whether user is logged on or not.
- Run with highest privileges.
- Run as an account allowed to execute Tableau TSM commands.
- Store environment variables at Machine scope so the scheduled account can read them.

## CLI task management

The setup script can inspect and maintain the task without opening Task Scheduler:

```powershell
# Inspect the default TableauServerBackup task.
.\scripts\Setup-TableauServerBackup.ps1 -ScheduledTaskAction Inspect

# Preview a daily 02:00 task without changing Task Scheduler.
.\scripts\Setup-TableauServerBackup.ps1 -ScheduledTaskAction CreateOrUpdate -ScheduledTaskDailyTime 02:00 -WhatIfOnly

# Create or update the task. PowerShell securely prompts for the scheduled account.
.\scripts\Setup-TableauServerBackup.ps1 -ScheduledTaskAction CreateOrUpdate -ScheduledTaskDailyTime 02:00

# Maintain an existing task.
.\scripts\Setup-TableauServerBackup.ps1 -ScheduledTaskAction Disable
.\scripts\Setup-TableauServerBackup.ps1 -ScheduledTaskAction Enable
.\scripts\Setup-TableauServerBackup.ps1 -ScheduledTaskAction Remove
```

Use `-ScheduledTaskName` to manage a non-default task and `-ScheduledTaskDaysInterval` for a schedule other than every day. Create or update prompts for a Windows credential unless one is supplied through `-ScheduledTaskCredential`; the script never writes or logs the password. Windows Task Scheduler stores credentials only when Windows requires them to run the task while the user is not logged on.

Manual checks:

```powershell
.\TableauServerBackup.bat -EmailOnlyTest
.\TableauServerBackup.bat -DryRun
```

Use `-Simulation` only on development workstations without Tableau Server. It does not prove TSM connectivity.
