# Security And Git Hygiene

Do not commit real local configuration.

Tracked files may contain only public-safe examples such as `example.com` email addresses and placeholder paths. Real values belong in environment variables on the Tableau Server machine.

Before publishing or pushing:

```powershell
.\scripts\Test-GitHygiene.ps1
git status --short --ignored
```

Expected local-only examples:

- `config/MailSettings.local.json`
- backup files
- logs
- settings exports
- editor backup folders

