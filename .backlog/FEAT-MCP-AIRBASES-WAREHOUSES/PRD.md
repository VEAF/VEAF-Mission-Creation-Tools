# Lot FEAT-MCP-AIRBASES-WAREHOUSES — airbase coalition, dynamic slots, alias-first

Status: ✅ done (PR #603 merged → `feature/mcp-mission-editor`)

Branch: `feat/mcp-airbases-warehouses` → PR → `feature/mcp-mission-editor`

## Context

Three gaps surfaced driving a real Syria mission through the MCP (David):

1. **The generator hand-places literal units where a VEAF alias exists.** Asked for a long-range
   SAM, it placed a literal Patriot instead of a `#veafInterpreter["-samLR"]` carrier. The skill
   only states an alias preference for *combat-zone* content ([SKILL.md:70](../../plugin/skills/veaf-mission-authoring/SKILL.md)); it is not
   generalized to permanent assets, and the armor example presents "literal units **or** alias" as
   equals. The oracle `list_shortcuts` has no structured category, so discovering "all the SAM
   aliases" is substring guesswork.

2. **A base stays neutral even when the user assigns it a coalition.** "Mezzeh is blue" placed a
   blue Patriot but the airfield stayed neutral. Root cause: an airfield's coalition lives in
   `warehouses.airports[<id>].coalition` (`"BLUE"`/`"RED"`/`"NEUTRAL"`), **not** in
   `mission.coalition` — and the synthetic blank mission ships `warehouses.airports = {}` empty
   ([blank_mission.py:198](../../src/python/veaf-tools/veaf_libs/blank_mission.py)), because DCS (via the Mission Editor) is what normally fills
   that table. So there is no airfield entry to colour.

3. **Dynamic Spawn slots are skipped.** The build logs `no warehouse airports; skipping Dynamic-Slot
   wiring` — same empty-`airports` root cause, plus the default `warehouses.yaml` ships fully
   commented. The Dynamic-Slot injector is already wired into the pipeline
   ([warehouses_injector_worker.py:224](../../src/python/veaf-tools/warehouses_injector/warehouses_injector_worker.py)); it just has no airport to target.

Points 2 and 3 share the empty-`airports` root cause. Airfield ids already exist
([dcs_airdromes.py](../../src/python/veaf-tools/veaf_libs/dcs_airdromes.py) + `data/airdromes.yaml`) but **without** coalition (scenario-specific).

## Design decisions (validated with David)

- **Airfield entries: lazy.** Create `warehouses.airports[<id>]` only for a base the user explicitly
  assigns; other airfields keep the DCS default. No full-theatre population, no per-theatre default
  coalition data to maintain.
- **Dynamic slots: automatic on assignment.** Assigning a base to a coalition also turns on its
  Dynamic Spawn slots and stocks its warehouse with the coalition's dynamic templates — matching
  "by default, activate dyn slots and fill the warehouses with the dynamic spawnables".
- **Alias-first: skill + oracle.** Generalize the preference directive in the skill, and add a
  structured `category` to `list_shortcuts` so the assistant can enumerate/prefer aliases.

## Tickets

- `01-airbase-entry-helper` — lazy resolve/create a `warehouses.airports[<id>]` entry for a named
  airfield (name→id via `dcs_airdromes` + the folder's theatre).
- `02-set-airbase-coalition-action` — MCP action `set_airbase_coalition(target, name, coalition)`
  writing `.coalition` durably into the folder's `warehouses` table (lazy entry).
- `03-auto-dynamic-slots` — on assignment, turn on `dynamicSpawn` and wire warehouse filling; ship an
  effective default `warehouses.yaml` + a worker mode that auto-fills a coalition's airfields from the
  injected dynamic templates.
- `04-alias-first-skill-oracle` — generalized alias-first directive in the skill + structured
  `category` on `list_shortcuts` commands.

## Definition of Done

- Each new function/action delivered with unit tests (TDD); `poetry run pytest` green; coverage gate
  respected (bump if actual drifts >2 pts above the floor).
- `ruff`/`ruff format`/`mypy` clean. If a substantially-edited worker is still under the mypy
  `ignore_errors` list, drop its entry and fix the surfaced types.
- Docs updated (mission-maker catalog + skill); `CHANGELOG.md` entry; PATCH bump; defaults lockstep
  if `warehouses.yaml` default changes.
- One PR → `feature/mcp-mission-editor`.
