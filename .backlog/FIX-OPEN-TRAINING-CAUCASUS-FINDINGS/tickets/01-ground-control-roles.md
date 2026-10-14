# 01 — Unattached roles and vehicle control set from mission.yaml

Status: ✅ done

Files: `veaf_libs/blank_mission.py`, the `mission:` section of the mission.yaml schema and its build step, the shipped `mission.yaml` template, the Open Training prompt (`.prompts/new-open-training-mission.fr.md`), `MISSION_YAML_REFERENCE` FR/EN, tests.

## What happened

`blank_mission.py:140` writes `groundControl` with 0 slots for `artillery_commander`, `forward_observer`, `instructor` and `observer`, on both sides, and `isPilotControlVehicles = False`.
No `mission.yaml` key reaches it, so a v6 mission has no game master slot unless someone edits `src/mission/mission` by hand.
The Caucasus OT v5 had 5 slots per role and per side and `isPilotControlVehicles = true`; the v6 Caucasus and GermanyCW missions were born without them, and the players noticed when they looked for the game master slot.

## Recommendation

A `mission.ground_control` block, applied at every build like `silence_atc_on_all_airbases`:

```yaml
mission:
  ground_control:
    game_master: 5          # instructor
    tactical_commander: 5   # artillery_commander
    jtac: 5                 # forward_observer
    observer: 5
    pilot_control_vehicles: true
```

A number applies to both sides; `{blue: 5, red: 0}` sets them apart.
Absent, the build leaves the mission's `groundControl` alone, so a mission that set it in the editor keeps it.
The Open Training prompt and template write the v5 values; `blank_mission.py` keeps its zeros for every other scaffold.
`passwords` stays out of reach: a role password in `mission.yaml` would be committed in clear.

## Done when

- The block above reaches `groundControl` in the built `.miz`, both forms (number, per side).
- Absent, a mission's own `groundControl` is unchanged by the build.
- The Open Training template and prompt carry the v5 values.
- Tests: both forms, the absent case, an unknown role refused by `validate`.

## Done

`mission_builder/ground_control.py`: `ground_control_errors` checks the block, `apply_ground_control` writes it; `MissionBuilderWorker.apply_ground_control` runs it at every build, right after the third-party mods are stripped, and an invalid block stops the build with every fault named. `validate` reports the same faults (check 12).
A role, a side or `pilot_control_vehicles` the block does not name keeps the mission's value, and `neutrals` is never set: the ticket asks for both sides, and no VEAF mission opens a neutral role.
"The Open Training template" is the prompt: there is no separate Open Training `mission.yaml`, and the shipped default keeps the block commented, so every other scaffold keeps its zeros.
