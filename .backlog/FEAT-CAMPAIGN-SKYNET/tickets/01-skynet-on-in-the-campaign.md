# 01 — Skynet on in the campaign mission

Status: ⬜ ready
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
