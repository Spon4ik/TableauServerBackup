# Windows Configuration App

`TableauServerBackup.Gui` is a local x64 WPF app for Windows Server 2019 or later. It manages the same environment variables and Windows scheduled task as the PowerShell CLI; it has no backend, Docker dependency, subscription, or local configuration file.

## Use

Build and publish the self-contained app from the repository root:

```powershell
dotnet publish .\TableauServerBackup.Gui\TableauServerBackup.Gui.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o .\TableauServerBackup.Gui\publish
```

Launch `TableauServerBackup.Gui.exe` from that output folder. Keep the output inside the repository so the app can locate `TableauServerBackup.bat`; the app uses that existing batch entry point for the scheduled task.

## Configuration

- Choose **Machine** scope to configure the account used by Task Scheduler; run the app as administrator to write Machine-scoped values.
- Choose **User** scope for a non-admin preview or per-user configuration.
- Empty text values remove the corresponding environment variable from the selected scope. No values are written to a local app file.
- Required fields and numeric ranges are validated before save.

## Scheduled Task

The **Scheduled task** tab can inspect, preview, create or update, enable, disable, and remove `TableauServerBackup` (or a custom name). The task runs `TableauServerBackup.bat` from the repository root with highest privileges.

For create or update, enter the account allowed to run Tableau TSM and its password. The GUI clears the password after each action and never writes or logs it. Windows Task Scheduler retains a credential only when Windows requires one for unattended execution.

The primary path is keyboard-accessible: tabs move between sections, standard controls expose labels to screen readers, and the status bar announces success and errors.
