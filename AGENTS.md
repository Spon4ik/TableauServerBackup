# Agent Instructions

These instructions apply to all future agent changes in this repository.

- Keep GitHub current: review `git status`, stage only intended files, create a clear local commit after checks pass, then push the branch to the configured remote.
- For every release version bump, create the matching Git tag in the form `vMAJOR.MINOR.PATCH` and push the tag to the configured remote.
- Bump `VERSION` for every code, docs, or behavior change using Semantic Versioning.
- Add a matching `CHANGELOG.md` entry for every version bump.
- Run `.\scripts\Invoke-ProjectChecks.ps1` and `.\scripts\Test-GitHygiene.ps1` when feasible before committing.
- If checks cannot be run, state the reason in the handoff.
