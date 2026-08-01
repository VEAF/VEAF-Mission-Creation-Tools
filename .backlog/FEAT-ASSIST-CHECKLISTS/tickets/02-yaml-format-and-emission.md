# 02 — checklist YAML: schema, loader, Lua emission

**Status:** ✅ done — 2026-08-01.

Python side. Reads checklist YAML, validates it, and emits the Lua table the engine consumes. DCS has no
YAML reader: the YAML is design-time only.

## Where files are found

Two sources, later overriding earlier by `id`:

1. **VMCT catalogue** — shipped with the tool, versioned with it. This is where the F-16C checklist of
   ticket 06 lives.
2. **`checklists/` in the mission folder** — what the mission maker adds or overrides.

Sidecar files, not blocks of `mission.yaml`, per the call in
[ADR 0016](../../../docs/adr/0016-ctld2-sidecar-configuration.md). One file per checklist.

## Schema

Validate with a pydantic model (the project already depends on pydantic) and **fail the build with a
readable message** on a bad checklist — a mission maker's typo must not surface as a Lua error in game.

| Field | Required | Notes |
|---|---|---|
| `id` | yes | unique; the override key |
| `title` | yes | i18n key or literal |
| `aircraft` | yes | list of DCS type names; validate against the unit catalogue and **reject unknown types** |
| `menu` | yes | menu slot under `Assistance` |
| `steps[].label` | yes | i18n key or literal |
| `steps[].element` | no | cockpit element to box |
| `steps[].argument` | no | animation argument → automatic check |
| `steps[].equals` + `tolerance` | with `argument` | window is `[equals-tolerance, equals+tolerance]` |
| `steps[].range` | alternative | `[min, max]`, mutually exclusive with `equals` |
| `steps[].confirm` | no | pilot confirms; implied when there is no `argument` and no `check` |
| `steps[].check` | no | `{type: <name>, …}` — named check, the bomb-run extension point |
| `steps[].device` / `command` | no | carried, unused for now (future demonstration mode) |

Rules to enforce: a step needs **exactly one** validation mode (`argument`, `check`, or confirm); a step
with neither `element` nor a validation mode is meaningless and must be rejected; `tolerance` without
`equals` is an error; an empty `steps` list is an error.

## Emission

Emit into the generated Lua config the way other modules receive their data — one
`veafAssist.registerChecklist({...})` call per checklist, wired through
[lua_config_generator.py](../../../src/python/veaf-tools/veaf_libs/lua_config_generator.py) which is the
authoritative YAML-to-Lua path. Emit **only the checklists the mission activates**; that is what keeps
ticket 03's image generation proportional to actual use.

Reuse the existing Lua-scalar and string-emission helpers rather than formatting by hand — label text can
contain quotes and accents.

## Tests

`test/python/…/test_checklist_format.py`: valid file round-trips to the expected Lua; each rejection rule
above produces a clear error; mission-folder file overrides catalogue file of the same `id`; unknown
aircraft type is rejected; a mission activating nothing emits nothing.

## Definition of done

- Loader + model + emission, `ruff`, `ruff format --check` and `mypy` clean.
- Tests green, `--cov-fail-under` bumped per the ratchet policy in `CLAUDE.md` §3.
- If this changes what the config generator emits, `src/defaults/mission-folder/mission.yaml` updated in
  the same lot (`CLAUDE.md` §9.7).

## What was built

[`veaf_libs/checklists.py`](../../../src/python/veaf-tools/veaf_libs/checklists.py) — the pydantic models
(`Checklist`, `ChecklistStep`), `parse_checklist()` and `load_checklists()`. Emission lives in
[`lua_config_generator.py`](../../../src/python/veaf-tools/veaf_libs/lua_config_generator.py)
(`emit_checklists_lua`, plus the `checklists=` parameter of `generate_config_lua`), which is where the Lua
string helpers already are. Tests:
[`test_checklist_format.py`](../../../test/python/veaf_libs/test_checklist_format.py), 34 cases.

Three calls taken while building it:

- **The window is resolved at design time.** `equals` + `tolerance` becomes `min` / `max` in the emitted
  table, so the engine's comparison is a plain `min <= value <= max` and no arithmetic ships to Lua.
- **`tolerance` defaults to 0.05** when a step gives `equals` without one — the value every example in the
  PRD uses. Narrow enough to reject the neighbouring position of a three-position switch.
- **Every step emits a uniform `check = {type = …}` table**, `confirm` and `argument` included. The engine
  dispatches on `check.type` through its registry with no special case, which is what makes the bomb-run
  lot purely additive.

**Left to ticket 05:** *which* checklists a mission activates. `generate_config_lua` takes the list it is
given and emits nothing for an empty one, so the loader and the emitter are complete; the `mission.yaml`
key that selects ids is part of the wiring ticket, and inventing it here would have pre-empted it.
