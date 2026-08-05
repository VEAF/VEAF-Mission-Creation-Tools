# Lot FEAT-COMBATZONE-RED-SIDE — a combat zone can be played from the red side

Status: ✅ done
Branch: feature/FEAT-COMBATZONE-RED-SIDE → PR #640 → merged into develop

## Problem Statement

A combat zone assumes the players are **blue** and the units to destroy are **red**. Two places
hard-code it:

- `VeafCombatZone:checkZoneCompletion` (the watchdog) completes the zone when `nbUnitsR == 0` —
  the red count alone.
- `VeafCombatZone:getInformation` (the F10 report) labels the blue tally *friends* and the red
  tally *enemies*.

So a zone whose enemies are blue cannot work: it holds no red unit, the watchdog sees zero reds
on its first pass (~1 min) and immediately completes and deactivates it. The documented
workaround is `completable: false`, which does not make the zone red-sided — it just switches
auto-completion off altogether, and the report still calls the blue enemies "friends".

That workaround is already written into the reference doc and the default `mission.yaml`
("required for a zone with no RED unit"), which is the shape of the gap: the limitation was
documented instead of fixed.

## Solution

One setting, `enemy_coalition` (default `RED` — every existing mission keeps its behaviour).

**Lua** (`veafCombatZone.lua`): `VeafCombatZone.enemyCoalition`, defaulting to red, with
`setEnemyCoalition` / `getEnemyCoalition` / `getFriendlyCoalition`. The setter accepts either a
DCS side number (`coalition.side.BLUE`) or a case-insensitive string (`"blue"`), since one
caller is hand-written Lua and the other is generated from YAML.

- the watchdog counts the **enemy** coalition instead of red;
- the report picks which tally is *friends* and which is *enemies* from the setting. The
  counting itself is untouched — it was already per-coalition and correct; only the labelling
  was wrong.

**Python** (`lua_config_generator.py`): `enemy_coalition: RED | BLUE` on a `combat_zones[]`
entry of type `zone`, emitted as `:setEnemyCoalition("blue")`. Omitted when red, so generated
configs do not churn. An unknown value is a validation error, not a silent fallback to red — a
typo would otherwise produce a zone that completes instantly.

## Testing Decisions

- Lua: default is red; a blue-sided zone completes when its blue units are gone and **not**
  while they are alive; the report swaps the friends/enemies labels; the setter accepts number
  and string forms.
- Python: `enemy_coalition: BLUE` emits the setter, `RED` and omission emit nothing, an invalid
  value is rejected.
- The existing red-side tests must stay green untouched — that is the regression guard for the
  default.

## Out of Scope

- Restricting a zone's F10 menu to one coalition: the menu is global today, for every zone, and
  that is a separate concern from who the enemy is.
- `popSmoke`'s red smoke colour (cosmetic, unrelated to coalitions).
- `VeafCombatOperation` (type `operation`): it chains zones and holds no units of its own, so it
  inherits each zone's own setting.

---

## 01 — `enemy_coalition` on a combat zone

Status: ✅ done

### Goal

Let a combat zone be played from the red side by making the enemy coalition a setting instead of
a hard-coded RED.

### Definition of Done

- [x] `VeafCombatZone.enemyCoalition` (default red) + `setEnemyCoalition` / `getEnemyCoalition` /
      `getFriendlyCoalition`, accepting a side number or a `"red"`/`"blue"` string
- [x] the watchdog completes on the **enemy** count, not the red count
- [x] the F10 report labels friends/enemies from the setting
- [x] `lua_config_generator` emits `:setEnemyCoalition(...)` for `enemy_coalition: BLUE`, nothing
      for RED/omitted, and rejects an unknown value
- [x] Lua tests (default, blue-sided completion, report labels, setter forms) + Python tests
- [x] `doc/mission-maker/scripts/veafCombatZone.md` + `.en.md` document the field and drop the
      "required for a zone with no RED unit" framing of `completable`
- [x] `src/defaults/mission-folder/mission.yaml` mentions the key (defaults lockstep)
- [x] `CHANGELOG.md` entry, PATCH version bumped in `pyproject.toml` + `plugin.json`
