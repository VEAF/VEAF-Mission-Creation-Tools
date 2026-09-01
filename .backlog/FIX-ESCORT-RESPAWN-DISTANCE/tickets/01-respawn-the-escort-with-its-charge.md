# 01 — Respawn the escort with its charge

Status: ✅ done — 8 Lua tests, each verified red before the fix and red again under a deliberate
sabotage; the in-game confirmation is tracked on the PRD, not here
Type: fix
Files: `src/scripts/veaf/veafMove.lua`, `src/scripts/veaf/veafAssets.lua`,
`test/lua/test_veafMove_escort.lua`, `test/lua/test_veafAssets.lua`,
`doc/mission-maker/scripts/veafAssets.md`, `doc/mission-maker/scripts/veafAssets.en.md`,
`DCS-SESSION-TODO.md` (item R5 — the in-game check, with both outcomes stated)

Implements option **(a)** as decided by David on 2026-08-28 (see the PRD). The decision is not
reopened here.

## What was written

`veafMove.respawnEscort(escorted_groupName)` — one thing: put `<group> escort` back where the Mission
Editor drew it. It sits next to `reestablishEscortTask` because the naming convention it reads
(`veafMove.EscortGroupNameSuffix`) already lives there, and because `veafAssets` already guards the
whole escort branch on `veafMove` being loaded at all.

`veafAssets.respawn` then runs **asset → escort → repair**, inside the existing `if veafMove then`
guard. The order is not cosmetic:

- the asset first, because the repair reads `Group.getID` of the freshly created asset;
- the escort before the repair, because `reestablishEscortTask`'s own guard is
  `Group.getByName(<group> escort)` — a repair asked for before the escort is back finds nothing and
  returns false.

Nothing is positioned by hand, so `docs/agents/dcs-coordinates.md` has no bearing on the change: a
respawn with no `:at()` puts the group back at its editor position, and that is the whole point —
the escort lands back exactly where its charge has just been put back.

## The one judgement call: what "has an escort" means

The guard is the escort's **mission record** (`veaf.getGroupRecord`), not a live group. The PRD says
"if such a group exists", which is ambiguous between *defined in the mission* and *currently flying*.
The mission record was chosen because:

- it is the precondition of the action itself — `VeafGroupSpawn:respawn()` reads the editor
  definition, so this guard tests exactly what the respawn needs;
- an escort that was shot down is precisely the case a respawn is for. `Group.getByName` answers nil
  for it, so the live-group guard would leave the asset back on station with no escort at all;
- it costs no extra code.

Covered by `test_an_escort_that_is_no_longer_flying_is_still_put_back`.

## Considered and deliberately not written

**Skipping the escort when `linked` already names it.** A mission maker who lists the escort in
`linked` — documented as unnecessary, not forbidden — gets it submitted to `coalition.addGroup`
twice in one call. Not guarded: a respawn keeps the group's name and its editor position, so the
second submission recreates the same group at the same place, which is what the first did. Adding a
de-duplication would be untestable in game from here and is code with no measured defect behind it.

## Tests, and the proof they can fail

`test/lua/test_veafMove_escort.lua`, `TestVeafMoveRespawnEscort` (5) — the escort reaches DCS; the
escorted group does not (this function does one thing); the escort comes back **with its route**, so
the Escort task the repair fixes is there; a group with no escort respawns nothing; a shot-down
escort is still put back.

`test/lua/test_veafAssets.lua`, `TestVeafAssetsRespawnBringsBackTheEscort` (3) — the **wiring**,
which is where this can silently do nothing: both groups reach DCS **in the order asset, escort**;
the repair is still asked for, and is asked for *after* both are back (asserted by capturing
`#dcs_mocks.groupsAdded` at the moment the repair is called); an asset with no escort respawns only
itself.

Red before the fix:

- `TestVeafMoveRespawnEscort` — 5 errors, *"attempt to call field 'respawnEscort' (a nil value)"*.
- `TestVeafAssetsRespawnBringsBackTheEscort` — 2 failures: `{"Arco"}` where `{"Arco", "Arco escort"}`
  was expected, and the repair running with 1 group back instead of 2.

Red again under three deliberate sabotages of the finished code, each applied and reverted on its
own:

| Sabotage | What went red |
|---|---|
| Swap the two calls in `veafAssets.respawn` so the repair runs before the escort respawn | `test_the_task_repair_runs_after_both_are_back` — expected 2, actual 1 |
| Delete the `VeafGroupSpawn` chain in `respawnEscort`, keeping `return true` | 4 of the 5 `TestVeafMoveRespawnEscort` tests; the "no escort" one correctly stayed green |
| Swap the guard to `Group.getByName` instead of `veaf.getGroupRecord` | `test_an_escort_that_is_no_longer_flying_is_still_put_back` — expected true, actual false |

The whole Lua suite is green after each revert: 45 suites, `test_veafMove_escort` 25 tests,
`test_veafAssets` 32.

## Documentation

`doc/mission-maker/scripts/veafAssets.md` and `.en.md`, new section *What a respawn does to an
escort* (`{#respawn-and-escorts}`): a respawn brings the escort back **and** repairs the task, why
both halves are needed with the measured 78/82 km against the 60 km `engagementDistMax`, and the cost
stated rather than glossed — the escort that comes back is a fresh one. The `linked` warning is
reworded rather than deleted: the two mechanisms now have the same effect on the escort at respawn
time, and the page has to say so, but only the naming convention repairs the task.
