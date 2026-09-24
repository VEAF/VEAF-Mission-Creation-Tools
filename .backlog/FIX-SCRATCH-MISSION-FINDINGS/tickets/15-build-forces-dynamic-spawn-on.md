# 15 — The build turns dynamic slots on at every airfield of a side, over `dynamic_spawn: false`

Status: ✅ done
Type: fix
Files: `src/python/veaf-tools/warehouses_injector/warehouses_injector_worker.py`, tests,
`doc/PIPELINE_REFERENCE*.md` (the `warehouses.yaml` section)

## Origin

GermanyCW-v6 rebuild of 2026-09-24 (MODERN, 6.24.0 for the build, MCP on develop). The red bases
were set with `set_airbase_coalition(..., dynamic_spawn=false)` — an enemy base that should offer no
slot, which is what that parameter was added for.

## Measured

With the default `src/warehouses.yaml` (no `airports:` list, as `src/defaults/mission-folder/src/warehouses.yaml`
ships it), the built `.miz` has **61 airfields configured and 3 111 template links**; the 49 red bases
set with `dynamic_spawn=false` come out with dynamic slots. With an explicit `airports:` list per side
(the workaround the mission carries): **12 airfields and 612 links**. Figures measured by the
GermanyCW-v6 session on its `.miz`.

## Cause

- `_apply_to_warehouse` writes `warehouse["dynamicSpawn"] = True` unconditionally
  (`warehouses_injector_worker.py:382`).
- Without an `airports:` list, the targets are **every** airport of the coalition
  (`warehouses_injector_worker.py:513-517`, "absent -> ALL airports of this coalition" in the module
  docstring, l. 13), whatever `dynamicSpawn` the source mission carries.
- `set_airbase_coalition` writes `dynamicSpawn = dynamic_spawn` (`veaf_mission_mcp/airbase.py:99`), so
  the MCP action and the build contradict each other, and the build wins without a word.

## What it is not

Not a problem for a mission that lists its airports: the explicit list is honoured. The defect is the
default path, the one `prepare` lays down.

## Done when

- A base whose source warehouse says `dynamicSpawn = false` stays without slots when no `airports:`
  list names it; an explicit `airports:` entry still turns it on (decide and document which one wins
  when both say something)
- Test: a mission with one blue base `dynamicSpawn = false` and one `true`, default config — only the
  second gets links
- GermanyCW-v6 rebuilt without its `airports:` lists: the red bases set `dynamic_spawn=false` carry no
  link

## Outcome

Decided with David (2026-09-24, option a): the record lives in `warehouses.yaml`, not in the
warehouses table, because `dynamicSpawn = false` is the editor's default there, not a choice — 12
local missions carry blue or red bases at `false` that were never meant to stay closed.

1. `set_airbase_coalition(dynamic_spawn=false)` writes the base under `<side>.exclude_airports` in
   `src/warehouses.yaml` (comments preserved), `true` removes it from every side; nothing is written
   when the file is absent (the step does not run) or the side is not declared in it (declaring it
   would open every one of its bases). The result says whether it was recorded.
2. The build reads `exclude_airports` (names or ids): an excluded base never gets slots, listed or
   not, with a warning when it is both listed and excluded; an unknown entry is reported.
3. Doc: `PIPELINE_REFERENCE` schema (FR/EN), the default `warehouses.yaml`, the MCP doc.

Left to the GermanyCW-v6 rebuild (PRD Definition of Done): drop the `airports:` lists and measure
the red bases stay at their 0 links.
