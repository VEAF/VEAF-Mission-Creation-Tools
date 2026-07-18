# FEAT-MCP-MISSION-EDITOR-015 — Mission-maker action catalogue (user-facing doc)

Status: ✅ done
Type: docs
Files: `doc/mission-maker/AI_ASSISTANT_CATALOG.md`, `doc/mission-maker/AI_ASSISTANT_CATALOG.en.md`, `mkdocs.yml`, `doc/developer/mission-editing-mcp.md`, `CHANGELOG.md`

## What to build

A **user-facing** (not developer) catalogue of everything a Mission Maker can ask the AI to do
through the MCP, in plain language — distinct from the technical `developer/` doc.

- Grouped **by theme**, ordered by **estimated frequency of use**, with a **complete index** at
  the top and a frequency legend.
- Explains the two editing levels (source `mission.yaml` recipe vs built `.miz`) and the
  backup-before-write safety net, in user terms.
- Example phrases per action ("what you can say to the AI").
- FR base + EN mirror; added to the `mkdocs.yml` nav under *Mission Maker*.
- Cross-linked from the developer doc.

## Acceptance criteria

- [x] Every currently-shipped action (waves 1-4, 11 actions) appears in the index and a themed
      section, tagged with an estimated frequency.
- [x] FR + EN pages, in nav, custom anchors resolve (`attr_list` enabled).
- [x] Framed as a **living doc** — explicitly grows as the MCP gains capabilities.

## Note

Living document: any future lot that adds an MCP action MUST add it to this catalogue (index +
themed section + frequency estimate) as part of its Definition of Done.
