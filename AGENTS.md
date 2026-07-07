# Agent Instructions

These instructions apply to all future agent changes in this repository.

- Keep GitHub current: review `git status`, stage only intended files, create a clear local commit after checks pass, then push the branch to the configured remote.
- For every release version bump, create the matching Git tag in the form `vMAJOR.MINOR.PATCH`, push the tag to the configured remote, create the GitHub Release for that tag, and verify the release URL exists.
- Use the matching `CHANGELOG.md` entry as the GitHub Release notes unless the user provides different release notes.
- Do not report a release as complete until the branch, tag, and GitHub Release are all present on GitHub.
- Bump `VERSION` for every code, docs, or behavior change using Semantic Versioning.
- Add a matching `CHANGELOG.md` entry for every version bump.
- Run `.\scripts\Invoke-ProjectChecks.ps1` and `.\scripts\Test-GitHygiene.ps1` when feasible before committing.
- If checks cannot be run, state the reason in the handoff.
