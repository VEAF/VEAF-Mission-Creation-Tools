# 05 — validate_mission: a permanent group or a QRA inside a combat zone's circle

Status: ⬜ ready

Files: `veaf_libs/mission_validator.py`, `veaf_libs/locales/*.json`, tests.

## What happened

Report finding 10: VEAF captures a combat zone **by geometry** — whoever stands in its circle counts — so a permanent group or a QRA inside a zone's circle is taken for part of it.
On the Falklands OT, `tools/check_overlap.py` found the Port Stanley SA-15 (1 482 m from the OCA zone's centre, radius 1 500), a radar, a NASAMS, a beacon and the Port Stanley QRA parking; `validate_mission` said nothing.

## Done when

- First read the capture test in the runtime (`veafCombatZone.lua`): the warning must reproduce **its** geometry, not an approximation.
- `validate_mission` warns, per zone, for each unit of a group that is not the zone's own standing within its radius; the warning names the group, the zone and the distance.
- Tests: a SAM site inside a zone warns, one outside does not, a zone's own group does not, a QRA parking spot does.
