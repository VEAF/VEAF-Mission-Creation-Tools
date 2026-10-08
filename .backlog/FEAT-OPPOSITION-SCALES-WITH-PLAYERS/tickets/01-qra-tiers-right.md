# 01 — The QRA's tiers: the biggest that fits, every group when asked, rearm while occupied

Status: ⬜ ready

The three defects of the PRD's table, in `veafQraCore.lua`, `veafReactiveZone.lua` and `lua_config_generator.py`:

- `chooseGroupsToDeploy` keeps the **biggest** tier lower than or equal to the enemies in the zone, whatever the order of the table (compare, do not rely on `pairs()`).
- A tier can deploy **every** group it names: in `mission.yaml`, a `groups_by_enemy_count` entry without `random_pick` deploys them all (`setGroupsToDeployByEnemyQuantity`); with `random_pick`, the draw is **without** replacement and never picks more than the list holds. Check who else calls `pickGroups` (combat zones, air waves) before changing it there — a draw with replacement may be wanted elsewhere; if so, give the QRA its own.
- A `mission.yaml` key to rearm with the zone occupied (`rearm_while_occupied: true` → `setNoNeedToLeaveZoneBeforeRearming()`).
- The migration note: a mission written with `random_pick` relying on the old behaviour changes; say it in the CHANGELOG.

## Done when

Lua tests enumerate the tier tables in every insertion order and every enemy count from 0 to 8 (biggest tier chosen each time); a tier without `random_pick` deploys all its groups; a pick of n from n gives n distinct groups. Python tests: the emitted chain for each form, and the new key. The *Kolkhida* workaround reads as no longer needed in the doc.
