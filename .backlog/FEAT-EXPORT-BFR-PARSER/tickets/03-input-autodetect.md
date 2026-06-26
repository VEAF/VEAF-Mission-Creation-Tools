# FEAT-EXPORT-BFR-PARSER-003 — `export <input>` auto-detects `.miz` or folder

Status: ✅ done
Type: feat
Files: `veaf_tools/commands/export.py`, `mission_tools/`, `test/python/`

## What to build

`export` detects on the `input` argument:

- **`.miz`** (zip) → current `read_miz` path.
- **folder** (extracted mission tree / VEAF `src/mission/`) → read the loose files `mission`,
  `l10n/DEFAULT/dictionary`, `l10n/DEFAULT/mapResource` directly via `luadata` (no zip), into the
  same `DcsMission` shape. Replaces the idea of a separate `parse-lua` command.

Align folder discovery with the VEAF layout (`src/mission/mission`,
`src/mission/l10n/DEFAULT/{dictionary,mapResource}`).

## Acceptance criteria

- [ ] `.miz` input → unchanged behavior.
- [ ] Folder input → same JSON as the equivalent `.miz`.
- [ ] Clear error when neither a `.miz` nor a recognizable mission folder.
- [ ] TDD on both inputs; ruff + mypy clean.

## Blocked by

FEAT-EXPORT-BFR-PARSER-002.
