# 01 — One shared escort-task recovery, used by both the teleport and the respawn path

Status: ✅ done 2026-08-20 — 14 Lua tests; the in-game confirmation is tracked on the PRD, not here
Type: fix
Files: `src/scripts/veaf/veafMove.lua`, `src/scripts/veaf/veafAssets.lua`,
`test/lua/dcs_mocks.lua`, `test/lua/test_veafMove.lua`, `test/lua/test_veafAssets.lua`

## Why the recovery has to move, not be copied

`veafMove.teleportEscort` already knows the DCS quirk: an `Escort` task carries a `groupId` that
stops resolving the moment the escorted group is recreated, and the only way back is to write the
**current** `Group.getID()` into the task and push the whole mission to the controller again. That
knowledge is currently welded into a 100-line function that also recomputes waypoints for a teleport
— which is why the respawn path never got it.

Split out the part that is not about moving anything:

- `veafMove.findEscortTask(escortGroupName)` — the lookup: group data, its route's **last** waypoint,
  and the `Escort` task inside it. Returns nil when any link of that chain is missing, which is the
  normal case for a group that has no escort.
- `veafMove.reestablishEscortTask(escortedGroupName, delay)` — the fix for a respawn: the escort has
  not moved, only the escorted group's id changed, so this reassigns the id and replaces the mission.
  Nothing else.

`teleportEscort` then calls the lookup instead of carrying its own copy, and keeps its waypoint
arithmetic, which is genuinely teleport-specific.

## The convention, decided

The escort of `<group>` is the group named **`<group> escort`**. That is what `teleportEscort`
already relies on, it is the convention that is measured to work, and the PRD's alternative — reading
the asset's `linked` list — cannot replace it: **the escort does not have to be respawned for its
task to break.** Respawning the escorted group alone invalidates the task of an escort that is still
flying, which is exactly the reported case (respawn Arco, its escort is untouched and still goes
home). So the recovery is keyed on the name, not on `linked`.

The suffix becomes a named constant, `veafMove.EscortGroupNameSuffix`, so the convention has one
place to be read and documented (ticket 02).

## The timing, and why it is delayed

`Group.getID` must be read **after** the respawn, or it returns the id that just died. The read
therefore happens inside the scheduled call, not before it — `mist.scheduleFunction` at
`timer.getTime() + delay`, defaulting to the same 1 s `replaceMission` already uses for a teleport.

## Tests

Lua, with `mist.scheduleFunction` made immediate so the scheduled work is observable:

- `findEscortTask` returns the task for a group whose last waypoint carries one;
- it returns nil for a group with no escort, no route, or a route whose last waypoint has no `Escort`
  task — three separate holes, each of which a mission maker will hit;
- `reestablishEscortTask` on a group with no escort does nothing and says so, rather than erroring;
- it writes the **current** group id into the task and calls `setTask` on the escort's controller;
- `veafAssets.respawn` calls it — the guard is worthless if the call site was missed.

The controller mock gains `setTask`, which it does not currently have.

## Done when

`poetry run test-lua` passes, `luacheck` and `stylua` are clean, and one implementation of the
`groupId` reassignment exists in the tree (grep for it).
