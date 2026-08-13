# 06 — The radio-specs generator writes engine types into its Aircraft column

Status: ⬜ ready
Type: fix
Files: `veaf_build/radio_specs_updater.py`, `test/python/veaf_build/`, then the regenerated
`doc/mission-maker/dcs-radio-specs.{md,en.md}`

## The defect

`doc/mission-maker/dcs-radio-specs.md` is a **reference table** whose "Appareil" column holds engine
types on **72 of its 88 rows**: `TurboFan` for the A-10C, C-101CC, F-15ESE and F-16C_50, `TurboJet`
for some thirty Mirage F1 variants, `Piston` for the FW-190D9 — and where it is not an engine type it
simply repeats the DCS id (`| **A6E** | \`A6E\` |`). Found by the 2026-08-13 documentation audit.

The page is **generated** (`radio_specs_updater.py:35` → `OUTPUT_MD`), so this is a generator bug and
hand-editing the page would be undone by the next `update-dcs-data --radio`. That also makes it the
right place to fix: one regex, 72 rows.

## Cause

```python
# radio_specs_updater.py:305-307
# 'type = "..."' holds the aircraft's DCS display name at the top level of the file.
match = re.search(r'^\s*type\s*=\s*"([^"]+)"', lua_content, re.MULTILINE)
```

The comment says *top level of the file*; the regex says `^\s*`, which with `re.MULTILINE` matches an
**indented** `type = …` just as happily — including the one inside the engine block. The first match
in a datamine aircraft file is therefore often the engine's type, not the aircraft's name.

## Fix

Anchor the search where the comment already says it belongs (column 0, no leading whitespace), or
prefer the `username` field outright and keep `type` as the fallback rather than the primary. Decide
by reading a real datamine aircraft file — the pinned revision is in the module — rather than from
this ticket.

## Careful

`dcs-radio-specs` is a **hybrid artefact**: `update-dcs-data --radio` overwrites a manual layer and
has been known to drop hand-maintained entries (`MiG-15bis` / `MiG-15bis_FC`, `dcs_rejects_on_load`)
and to replace the hand-written French page with a generated English one. Generate at the pin into a
temp dir, diff, and merge only what changed — the result must be the column contents and nothing else.

## TDD

- Failing first: feed `parse_display_name` a Lua fixture whose engine block carries
  `type = "TurboFan"` above the aircraft's own name field, and assert the aircraft name comes back.

## Acceptance criteria

- [ ] `parse_display_name` returns the aircraft name for the fixture and for the four named real
      types; test in place.
- [ ] The page regenerated (merge, do not blind-overwrite), both languages, 88 rows carrying aircraft
      names; `docs-check` green.
- [ ] Full Python gate green.
