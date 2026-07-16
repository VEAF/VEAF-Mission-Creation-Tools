# FEAT-BLANK-MISSION-THEATRE-002 — `prepare --theatre` + `--list-theatres`

Status: ⬜ ready
Type: feat
Files: `src/python/veaf-tools/veaf_tools/commands/prepare.py`, `veaf_libs/locales/{en,fr}.json`, `test/python/`

## What to build

Extend `prepare` so it can lay down a theatre blank:

- `--theatre <name>` — after copying the defaults, generate the theatre blank (ticket 001) into the
  folder's `src/mission/`. If `src/mission/` is already populated, follow the same
  ask/`--force`/`NEVER_OVERWRITE` policy the default-file copy uses.
- `--list-theatres` — print the supported set (from the constants table), mirroring
  `--list-templates`.
- Unknown theatre → clear localized error naming the supported set (before copying anything).
- No `--theatre` → today's behaviour unchanged (empty `src/mission/`, the next-steps hint still
  tells the maker to supply their own `.miz`).

## Acceptance criteria

- [ ] `prepare --theatre caucasus` on an empty folder produces a buildable `src/mission/`.
- [ ] `--list-theatres` lists the supported set.
- [ ] Unknown theatre → localized error, nothing written.
- [ ] `--theatre` composes with `--template` (both applied).
- [ ] FR + EN locale keys; TDD on the CLI path; ruff + mypy clean.

## Blocked by

FEAT-BLANK-MISSION-THEATRE-001.
