# Troubleshooting

## Local Workstation

This repository can be tested on a machine without Tableau Server:

```powershell
.\scripts\Invoke-ProjectChecks.ps1
.\scripts\Test-GitHygiene.ps1
```

Use simulation mode to verify local path creation and final logging:

```powershell
.\TableauServerBackup.ps1 -Simulation
```

## Tableau Server Machine

If the scheduler fails:

- Check the daily log under `TABLEAU_BACKUP_ROOT\log`.
- Confirm `TABLEAU_SERVER_DATA_DIR` and `TABLEAU_BACKUP_ROOT` are visible to the scheduled account.
- Confirm the task runs elevated.
- Confirm `tsm` is available in the scheduled account environment.
- Check the Windows Application event source `TableauBackup`.

Exit codes are documented at the top of `TableauServerBackup.ps1`.

