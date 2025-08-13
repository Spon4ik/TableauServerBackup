# Tableau Server Backup (Windows Batch)

Automated, retention‑aware backup workflow for **Tableau Server** on Windows.

This script:
1. Moves any existing `.tsbak` files from Tableau’s default backup folder to a custom destination (non‑fatal)
2. Cleans up logs (best‑effort)
3. Exports **Tableau Server settings** to JSON (fatal on failure)
4. Creates a fresh `.tsbak` backup (fatal on failure)
5. Moves the new backup to a custom destination (fatal on failure)
6. Optionally sweeps leftover `.tsbak` files (non‑fatal)
7. Deletes backups and settings older than **5 days** in the destination (best‑effort)

> ⚠️ **Security & privacy**
>
> - **Do not commit** any backup (`*.tsbak`), settings export (`server_settings-*.json`), or log files to this repo.  
> - The provided `.gitignore` blocks them, but double‑check before pushing.  
> - Treat `tsm settings export` output as **confidential**.

---

## Requirements

- Windows Server 2016+ (tested on modern Windows Server)
- Tableau Server with `tsm` in `PATH`
- Local admin rights (script auto‑prompts for elevation)
- Two environment variables must be defined:
  - `TABLEAU_SERVER_DATA_DIR` – Tableau Server data directory (typically `C:\ProgramData\Tableau\Tableau Server\data`)
  - `TableauServerBackup` – **root** folder where you want backups, logs, and settings stored  
    The script will create subfolders: `backups`, `log`, `settings`.

---

## Install

1. Clone this repo or download the script.
2. Set environment variables (System Properties → Advanced → Environment Variables):
   - `TABLEAU_SERVER_DATA_DIR`  
   - `TableauServerBackup` (e.g. `D:\TableauBackup`)
3. Open **elevated** Command Prompt to test initial run.

---

## Usage

```bat
backup-tableau-server.bat
