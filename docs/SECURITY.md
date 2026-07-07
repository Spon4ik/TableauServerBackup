# Security And Git Hygiene

Do not commit real local configuration.

Tracked files may contain only public-safe examples such as `example.com` email addresses and placeholder paths. Real values belong in environment variables on the Tableau Server machine.

Before publishing or pushing:

```powershell
.\scripts\Test-GitHygiene.ps1
git status --short --ignored
```

Expected local-only artifacts:

- local `config/*.local.json` files
- local `config/MailSettings.json`
- backup files
- logs
- settings exports
- editor backup folders
