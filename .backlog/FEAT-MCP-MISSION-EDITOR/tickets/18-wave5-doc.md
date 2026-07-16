# FEAT-MCP-MISSION-EDITOR-018 — Wave-5 documentation

Status: ✅ done
Type: docs
Files: `doc/developer/mission-editing-mcp.md` (FR/EN), `doc/mission-maker/AI_ASSISTANT_CATALOG.md` (FR/EN), `CONTEXT.md`, `CHANGELOG.md`, `pyproject.toml`

## What to build

- Developer doc (FR/EN): document the oracle introspection actions (016) and the four-source
  knowledge model (generated DCS data / veafUnits+shortcuts / vendored artifacts / datamining
  provenance).
- Mission-maker catalogue (FR/EN): add the read-side "the AI knows DCS + VEAF" actions to the
  index + a themed section (living-doc rule).
- CONTEXT.md glossary entry if a new term is warranted (e.g. "domain oracle").
- CHANGELOG entry; PATCH version bump.

## Acceptance criteria

- [x] Both language docs describe the oracle actions and knowledge sources consistently.
- [x] Catalogue index + section updated; anchors resolve (done in 016, verified here).
- [x] CHANGELOG + version bump (6.9.5) landed; markdown-lint deferred to the CI docs job.

## Blocked by

FEAT-MCP-MISSION-EDITOR-016 / 017 (documents what they ship).
