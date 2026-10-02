# 11 — The mission-folder .gitignore covers the MCP backups and the presets report

Status: ⬜ ready

Files: `src/defaults/mission-folder/.gitignore`.

## What happened

Every MCP write backs up into `<mission>/.veaf-backups/`, and every build writes `presets-validation-report.md`
at the root; the shipped `.gitignore` covers neither, so both show up as new files in the mission's repository.

## Done when

- Both are in the shipped `.gitignore`.
