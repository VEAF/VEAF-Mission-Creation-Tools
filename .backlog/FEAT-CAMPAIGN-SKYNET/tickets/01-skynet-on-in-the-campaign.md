# 01 — Skynet on in the campaign mission

Status: ✅ done
Type: feature

## To do

- First, a failing test (Python): `campaign next` writes `modules.SKYNET` enabled in the mission's `mission.yaml`, both networks loaded, `dynamic_spawn: false` (ticket 03 integrates explicitly), the other Skynet settings at their shipped defaults; a `campaign.yaml` that turns it off (`dynamic.skynet: false`, or the existing settings vocabulary — choose and say which) keeps it off.
- `next_mission.py`: set the module the way `SUPPORT` is set (`enable_support_module`, line 275), in the same lot of `campaign next` steps; the settings check (`dynamic_settings.py`) accepts the new key.
- Defaults lockstep (CLAUDE.md §9.7): the shipped campaign defaults and their comments.
- Docs: the campaign page (FR/EN) says the SAM sites run under Skynet and what a pilot sees (sites going dark under anti-radiation missiles, lighting up close); CHANGELOG entry.

## Done when

A campaign mission built by `campaign next` starts Skynet (`initializing Skynet` in the log), for both sides, unless the campaign turns it off; with tests.

## In-game check

On the Campagne server after the redeploy: `VEAF-SKYNET … initializing` in `dcs.log`, then the networks' sites listed as integrated (ticket 03).

## Done

- `campaign next` (persistent mode) writes `modules.SKYNET: { enabled: true, dynamic_spawn: false }` into the mission's `mission.yaml` (`enable_skynet_module`, `next_mission.py`), beside the `SUPPORT` module. `veafSkynet.initialize` always creates both networks, blue and red; the radio and debug flags stay at their shipped `false`, and the other Skynet settings (last line of defence, coverage sweep) are not written, so the helper's own defaults stand.
- **Choice: `dynamic.skynet.enabled: false`** turns it off — a block with `enabled`, like `warehouse`, `territory` and `bombers`, rather than a bare `dynamic.skynet: false`: the same vocabulary as its neighbours, and room for a campaign Skynet setting later without a second spelling. `dynamic_settings.py` checks it (`enabled` a boolean, no other key).
- Defaults: `src/defaults/campaign-folder-persistent/campaign.yaml` carries the block, commented. `src/defaults/mission-folder/mission.yaml` is untouched: `campaign next` writes the module; `convert-v5` and the generator are not changed, so §9.7 does not apply.
- Docs: `PERSISTENT_CAMPAIGN.md` / `.en.md`, section "Les SAM sous Skynet" / "SAM sites under Skynet" (`#skynet`), its row in the settings table and an item in "still to check in game"; CHANGELOG.
- Tests: `TestTheSkynetModule` (the block written; the generated Lua, through `_normalize_mission_yaml`, initializing Skynet with `DynamicSpawn = false`; the campaign turning it off), `campaign next` end to end, and the settings check.
