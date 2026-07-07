# Agent Instructions

These instructions apply to all future agent changes in this repository.

- Keep Git current: review `git status`, stage only intended files, and create a clear local commit after checks pass.
- Do not push to a remote unless the user explicitly asks for it.
- Bump `VERSION` for every code, docs, or behavior change using Semantic Versioning.
- Add a matching `CHANGELOG.md` entry for every version bump.
- Run `.\scripts\Invoke-ProjectChecks.ps1` and `.\scripts\Test-GitHygiene.ps1` when feasible before committing.
- If checks cannot be run, state the reason in the handoff.
