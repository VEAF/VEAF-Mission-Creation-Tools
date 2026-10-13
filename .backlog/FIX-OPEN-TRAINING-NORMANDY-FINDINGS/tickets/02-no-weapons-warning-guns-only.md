# 02 — « no weapons » warning on a gun-armed fighter, and `loadout_from` refuses a gun-only template

Status: ✅ done
Type: fix
Files: `veaf_mission_mcp/add_air_group.py` (l. 294), `veaf_mission_mcp/aircraft_payload.py` (l. 162-172), tests

## What happens

1. `add_air_group` warns « group 'X' has task 'CAP' and no weapons: it will not fight without a loadout » for every WW2 fighter given no pylons. A P-51D, a Spitfire, a Bf 109 or a Fw 190 fights with its guns: the written unit carries `payload.gun = 100` and `pylons = {}` (checked in `src/mission/mission` of the Normandy Open Training). `create_qra` and `create_cap_mission` repeat the warning per group — 20 QRA groups and 5 CAP templates, 25 warnings the maker learns to ignore, which hides a real one (a Ju-88A4 with no bombs).
2. `loadout_from` raises « the group 'P-51D Template' carries no pylons » for a template whose empty pylons are legitimate (guns only).

## What ships

- The no-weapons test also counts the gun: a unit whose `payload.gun` is positive is armed. State the rule in the action's description.
- `loadout_from` a group with no pylons but a `gun` copies « no pylons » (and the gun and fuel it carries) instead of refusing; it still refuses a group that does not exist.

## Done when

`add_air_group` for a P-51D `task: CAP` with no payload returns no warning; the same for a Ju-88A4 `task: Ground Attack` with no pylons still warns. `loadout_from: "P-51D Template"` succeeds.

## Done

The rule the ticket proposed (« `payload.gun` positive means armed ») is wrong: `build_aircraft_payload` writes `gun: 100` for **every** aircraft, so it would also have silenced the warning for an F-15C given no missiles (FIX-OPEN-TRAINING-SYRIA-FINDINGS ticket 01, which a test holds). The rule is by type: a WW2 gun fighter (`GUN_FIGHTERS` in `add_air_group.py`: P-51D, P-47D, Spitfire, Bf 109, Fw 190, Mosquito, I-16, La-7, F4U-1D) with the gun is armed; a Ju-88A4 or B-17G with no bombs, and a modern jet with no missiles, still warn. `loadout_from` a group with aircraft but no pylons copies « no pylons »; a group found nowhere, or with no aircraft, is still refused.
