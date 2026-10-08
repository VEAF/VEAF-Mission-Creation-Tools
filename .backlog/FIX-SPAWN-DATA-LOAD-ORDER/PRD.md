# FIX-SPAWN-DATA-LOAD-ORDER — campaign garrisons drawn from an empty groups database: no air defence

Status: ⬜ ready

## Problem

David, 2026-10-08, *Kolkhida* mission 1 rebuilt with the fix of `FIX-BUNDLE-LOCAL-LIMIT` (#1102): "c'est mieux mais y'a encore des erreurs dans le log".

```text
VEAF-CASMISSION|E|generateAirDefenseGroup|…: veafCasMission.generateAirDefenseGroup cannot find group [generateAirDefenseGroup-RED-3]
VEAF-CASMISSION|E|generateLongRangeAirDefenseGroup|…: veafCasMission.generateLongRangeAirDefenseGroup cannot find group [sa10]
  … in function 'composeGarrison' / 'drawGarrison' / 'initialize' (veafCampaign)
  [string "l10n/DEFAULT/veaf-config.lua"]:188
```

`veafUnits.UnitsDatabase` / `GroupsDatabase` ship empty in the bundle and are filled by `veaf-spawn-data.lua` (ADR 0005), which `spawn_data_injector_worker.inject_spawn_data` loads from a trigger of its own **appended at the end** of the trigger list — after `veaf-config.lua`. Its docstring states why that was safe: "the spawn database is consumed at runtime …, never during script load".

That stopped being true with the campaign: `veafCampaign.initialize()` (`veafCampaign.lua`, `zone:drawGarrison(reserve)`) draws the garrisons while `veaf-config.lua` runs, so `veafUnits.findGroup` searches an empty database.

Measured in that `dcs.log`: every garrison came out **without its air defence** — Senaki 24 units where the `airfield` size class averages 51 with ≈ 20 for the long-range SAM, so no SA-10 at Senaki; Batumi without its Patriot. Armour and infantry are drawn (they do not go through `findGroup`). The defect dates from the garrison drawing (FEAT-MULTI-MISSION-CAMPAIGN); it went unseen because the bundle itself did not load until #1102.

Trigger order in a built `.miz` (Kolkhida mission 1): 3 `VEAF scripts loading - dynamic`, 4 `VEAF scripts loading - static`, 5/6 `Mission scripts loading - dynamic/static` (`veaf-config.lua`, `mission-script.lua`), …, 8 `VEAF spawn-data loading`.

## Decided with David, 2026-10-08

**Load the database with the framework** (option a), rather than defer the garrison drawing in `veafCampaign` (option b): the premise "never read during script load" is what is wrong, and the next module reading the database at initialization would fall into it again.

## What the lot does

- `inject_spawn_data` adds the `a_do_script_file` of the spawn data as the **last action of both framework load triggers** (comments `VEAF scripts loading - static` and `- dynamic`), in `trigrules[i].actions` and in the compiled `trig.actions[i]` string — right after the bundle defines `veafUnits`, before the mission scripts. No trigger of its own any more, so no renumbering.
- Once only: a second injection does not load it twice.
- `trigrules[i].actions` may be a dict (`{1: …}`, as parsed) or a list (as the builder emits): both handled.
- A mission with no framework trigger keeps today's trailing trigger, with a warning (i18n, `en.json` / `fr.json`).
- The two trigger comments get one source shared by `mission_builder_worker._build_veaf_trigger_specs`, which writes them, and the injector, which looks for them (`mission_tools/mission_constants.py`).
- The injector's module docstring says why.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-load-with-the-framework.md) | The spawn data loads with the framework, and a campaign mission draws its garrisons with their air defence | ⬜ |

## Related

- `FIX-BUNDLE-LOCAL-LIMIT` (#1102): the bundle loads again; this defect was behind it.
- [`FEAT-MULTI-MISSION-CAMPAIGN`](../FEAT-MULTI-MISSION-CAMPAIGN/PRD.md): introduced the garrison drawing at initialization.
- ADR 0005: the spawn data externalized from `veafUnits.lua`.
