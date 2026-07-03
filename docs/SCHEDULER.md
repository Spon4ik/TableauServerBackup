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

Manual checks:

```powershell
.\TableauServerBackup.bat -EmailOnlyTest
.\TableauServerBackup.bat -DryRun
```

Use `-Simulation` only on development workstations without Tableau Server. It does not prove TSM connectivity.

