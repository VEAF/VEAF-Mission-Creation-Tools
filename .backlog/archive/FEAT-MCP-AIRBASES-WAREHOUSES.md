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

---

## 01 — Lazy airbase-entry helper

Status: ⬜ ready

### Goal

A pure helper that, given a loaded mission and an airfield **name**, returns (creating it lazily if
absent) the `warehouses.airports[<id>]` entry to edit — resolving the name to a numeric airdrome id
via the folder's theatre.

### Details

- Resolve `name` → id with `veaf_libs.dcs_airdromes.airdrome_id_for_name(theatre, name)`, theatre
  taken from `DcsMission.theatre_content`.
- `warehouses.airports` keys are the airdrome ids (as strings in the exploded table); create a minimal
  entry when missing (lazy) so a blank mission (`airports = {}`) works.
- Raise a clear error for an unknown airfield name / missing theatre.

### Tests

- Known name → resolves to the expected id and returns the (new) entry.
- Existing entry is returned/edited in place, not duplicated.
- Unknown name → clear error.

---

## 02 — `set_airbase_coalition` MCP action

Status: ⬜ ready

### Goal

Expose an MCP action that assigns a DCS airfield to a coalition, durably, in the mission folder.

### Details

- `set_airbase_coalition(target, *, name, coalition)` where `coalition ∈ {blue, red, neutral}`.
- Loads the folder mission, uses the ticket-01 helper to get/create the airfield entry, sets
  `entry["coalition"] = coalition.upper()`, saves the folder (backup first, reusing
  `save_folder_mission`).
- Register in `actions.py` + `catalog.py` with a `coalition` enum, mirroring the existing action
  registration pattern (e.g. `add_trigger_zone`).
- Returns `{airbase, airdrome_id, coalition, durable: true}`.

### Tests

- Assigning blue writes `warehouses.airports[<id>].coalition == "BLUE"` and persists after reload.
- Neutral / red likewise.
- Catalog/describe exposes the action with the coalition enum.

---

## 03 — Auto Dynamic Spawn slots on assignment

Status: ⬜ ready

### Goal

Assigning a base to a coalition also enables its Dynamic Spawn slots and stocks its warehouse with
that coalition's dynamic templates — "by default, activate dyn slots + fill with dynamic spawnables".

### Details

- On `set_airbase_coalition`, also set `entry["dynamicSpawn"] = True` (recipe side).
- The actual warehouse **filling** (stock + `linkDynTempl`) happens at build via the existing
  `warehouses_injector`, which needs the injected templates' `groupId`s. So:
  - Ship an **effective** default `src/warehouses.yaml` (replace the fully-commented default): declare
    `blue:`/`red:` with `defaults` (unlimited fuel/munitions + dynamic-spawn) and **no** `airports:`
    list, so the injector applies to *every* airfield of that coalition — which, in lazy mode, is
    exactly the base(s) just assigned.
  - Add a worker mode to **auto-fill** a coalition's warehouse from all injected dynamic templates of
    that coalition when the config does not enumerate `aircrafts` (derive the type list from the
    `dynSpawnTemplate=true` groups already present). Keep explicit `aircrafts` overriding.
- Defaults lockstep: update `src/defaults/mission-folder/src/warehouses.yaml`.
- If `warehouses_injector_worker.py` is under the mypy `ignore_errors` list and is substantially
  edited, drop its entry and fix the types.

### Tests

- `set_airbase_coalition` sets `dynamicSpawn` on the entry.
- Worker auto-fill: a coalition with no explicit `aircrafts` stocks every injected template of that
  coalition (planes/helicopters under the right category) and links `linkDynTempl` to the right
  `groupId`.
- Explicit `aircrafts` still overrides auto-fill.

---

## 04 — Alias-first: skill directive + oracle categories

Status: ⬜ ready

### Goal

Make the assistant prefer a VEAF alias over hand-placed literal units whenever an alias covers the
need, and make aliases discoverable by category.

### Details

#### Skill (`plugin/skills/veaf-mission-authoring/SKILL.md`)

- Add a **general** alias-first principle (not limited to combat zones): when a `list_shortcuts`
  alias covers the need, prefer it — whether a `#command` (zone content) or `#veafInterpreter`
  (permanent asset) — over literal DCS units.
- Give the `#veafInterpreter` section the same preference wording (currently neutral).
- Fix the armor example so it leads with the alias, literal units only as the fallback.
- State the fallback criterion: literal units when no alias fits (precise type/placement needed).

#### Oracle (`src/python/veaf-tools/veaf_mission_mcp/oracle.py`)

- Add a structured `category` field to `list_shortcuts` command entries (SAM / AAA / infantry /
  armor / artillery / naval / transport / …), derived from the alias/description, so the assistant
  can enumerate "all SAM aliases" without substring guessing.

### Tests

- `list_shortcuts` commands carry a `category` for the known families (e.g. `-samLR` → SAM,
  `-aaa` → AAA, `-infantry` → infantry).
- Uncategorized aliases get a stable fallback (e.g. `other`), not a crash.
