# 05 — validate_mission: what a combat zone's circle does with the groups around it

Status: ✅ done — the report's premise did not hold for a combat zone; check 1 below built (David, 2026-10-13: « fais comme tu conseilles »)

Files: `veaf_libs/mission_validator.py`, `veaf_libs/locales/*.json`, tests.

## What happened

Report finding 10 says VEAF captures a combat zone **by geometry**, so a permanent group or a QRA inside a zone's circle would be destroyed then recreated: on the Falklands OT, `tools/check_overlap.py` found the Port Stanley SA-15 (1 482 m from the OCA zone's centre, radius 1 500), a radar, a NASAMS, a beacon and the Port Stanley QRA parking.

**Checked against the runtime (2026-10-13), that is not what a combat zone does.** `VeafCombatZone:findUnitsInCombatZone` takes the units of the trigger zone's circle (`veafGeo.getUnitsInCircularZone`: 2D distance to the centre ≤ radius, units and statics, any coalition) **and keeps only the groups whose name starts with the zone's name** (case ignored). The others are left where they stand — never removed, never recreated, never counted — and the log says so once (`N group(s) found inside the zone were ignored`). The module doc says it too (`doc/mission-maker/scripts/veafCombatZone.md`, « The prefix rule »). So the SA-15 and the QRA are untouched.
What does capture by pure geometry is the **campaign** zone (`VeafCampaignZone:groundHolders`: every active ground unit or grounded helicopter in the sphere, any side, with about 4 % slack), and only to decide who holds a neutral zone.

## What a validator could still say, each true in the runtime

1. A group **named for a zone but outside its circle**: the zone picks nothing up and nothing shows in game. The reverse of the prefix rule, and the one silent failure left.
2. Two zones whose names are prefixes of one another (`CZ-A` and `CZ-AB`) with circles that overlap: a group of `CZ-AB-…` in both circles belongs to both.
3. Campaign zones (`modules.CAMPAIGN`): a permanent ground group inside a neutral zone's circle counts as holding it.

None of the three is what the report asked, and the report's check (`check_overlap.py`) would warn on harmless layouts. Check 1 is built; 2 and 3 are not.

## Done

`find_combat_zone_groups_outside_their_circle` (`mission_builder/group_validation.py`), run by `validate_mission_content` and so by `validate` and the build: a **warning** per group whose name starts with a declared combat zone's name (operations excluded, case ignored) and none of whose units is within the zone's circle (2D, edge included; quad-point zones not measured). A group named for no zone is never reported.
It found one on the Falklands OT itself: `combatZone_PortStanley-Z14-1`, 1 078 m from the centre of its zone, outside the circle, hence picked up by nothing.
