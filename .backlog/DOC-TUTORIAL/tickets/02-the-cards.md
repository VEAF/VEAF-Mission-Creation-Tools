# 02 — The cards: one concept, one page

Status: ✅ done

Type: docs · Files: a `doc/mission-maker/concepts/` folder, both languages, `mkdocs.yml`

## What they are

One short page per concept — aim for twenty to forty lines — each answering "how do I write this
one thing?", with a minimal example that works and a link to the reference for the rest.

A reasonable first set, to adjust as you write: the mission folder, `mission.yaml` and its modules,
`custom_scripts` (and load staging), radio presets, dynamic slots and warehouses, combat zones,
spawnable groups, weather variants. Add or merge as the material dictates — the list is a starting
point, not a contract.

## Definition of done

- [x] Each card: what it is, the smallest example that works, one gotcha, a link to the reference
- [x] Every example verified against `src/defaults/mission-folder/` or a test — a wrong example is
      worse than no card
- [x] Both languages, all in the `nav`
- [x] Explicit English anchors on anything linked from another page
- [x] `poetry run docs-check` passes
