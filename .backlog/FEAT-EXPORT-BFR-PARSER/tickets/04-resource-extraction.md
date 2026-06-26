# FEAT-EXPORT-BFR-PARSER-004 — resource extraction for `.miz` input

Status: ⬜ ready
Type: feat
Files: `veaf_tools/commands/export.py`, `mission_tools/`, `test/python/`

## What to build

For a `.miz` input, extract embedded resource files — `.lua` scripts and `l10n/DEFAULT/*`
(sounds/images) — to a sidecar output directory mirroring the archive layout, so the plugin can
run its `.lua` checks and resolve resources without unzipping itself.

## Acceptance criteria

- [ ] Embedded `.lua` and `l10n/DEFAULT/*` extracted preserving relative paths.
- [ ] Output location documented and predictable (next to the JSON, or a `--extract-dir`).
- [ ] Mission-folder input: no-op (files already loose).
- [ ] TDD on a small real `.miz`; ruff + mypy clean.

## Blocked by

FEAT-EXPORT-BFR-PARSER-003.
