# Goal

Provide a reliable Windows Task Scheduler job for Tableau Server backups.

The project should:

- Run Tableau maintenance, settings export, backup creation, retention, notification, and logging in one predictable workflow.
- Keep personal and server-specific configuration outside Git.
- Be safe to clone, pull, test locally, and publish without leaking real paths, mail addresses, SMTP hosts, or secrets.
- Support local validation on a workstation without Tableau Server through parser tests, hygiene checks, and simulation mode.

