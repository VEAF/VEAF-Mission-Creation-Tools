# FIX-ESCORT-RESPAWN-TASK — a respawned escort goes home; the fix already exists next door

Status: 🔄 in-progress — shipped 2026-08-20, verified in game 2026-08-28. The check found a defect **in the repair itself** (ticket 03, fixed); the escort still goes home, for a cause outside this lot — see [`FIX-ESCORT-RESPAWN-DISTANCE`](../FIX-ESCORT-RESPAWN-DISTANCE/PRD.md)

Origin: `CHORE-ISSUE-VERIFY-SESSION` check 9, run by David on 2026-08-18. Closes
[#107](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/107); the same session closes
[#101](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/101) as **not reproducible**.

## The two measurements, and why they explain each other

| Path | What David saw |
|---|---|
| `veafAssets.respawn` (F10 → Assets → Respawn Arco) | the escort holds for a while, then **leaves to land after ~10 minutes** |
| `veafMove` teleport (`_move tanker, name Arco, teleport`) | the escort **stays with the tanker for the 30 minutes he watched** |

The teleport path was the one reported as broken in #101. It is not: it works, and it works because
it does something the respawn path does not.

`veafMove.teleportEscort` recovers the escort task from the group data, **reassigns the escorted
group's id into it** (`veafMove.lua:648`) and pushes the mission back to the controller through
`veafMove.replaceMission` (`:655`). The comment at `:609` says exactly why — *"it seems DCS destroys
it after the escorted group respawns"*.

`veafAssets.respawn` calls `mist.respawnGroup(name, true)` on the asset, then `mist.respawnGroup` on
each `linked` group (`veafAssets.lua:165`), and **nothing else**. The escort comes back with an
Escort task pointing at a group id that no longer exists, flies out its route, and RTBs when the
route ends — which is what a ten-minute delay looks like.

So #107's own request is the fix: *"When a functionning way is found to move the tanker by teleporting
it #101, it should be ported to the veafAssets.respawn method / mist.respawnGroup method."* That way
exists and is measured to work.

## What shipped, 2026-08-20

Written on a workstation without DCS, which decides what could and could not be closed here.

| | |
|---|---|
| `veafMove.findEscortTask` | the lookup — group data, last waypoint, enabled `Escort` task — used by **both** paths |
| `veafMove.reestablishEscortTask` | the repair for a respawn: reassign the current `Group.getID()` and replace the mission. Nothing is moved |
| `veafAssets.respawn` | calls it, guarded on `veafMove` being present |
| `veafMove.teleportEscort` | now uses the shared lookup instead of its own copy |
| `veafMove.EscortGroupNameSuffix` | the convention, named once and documented |

Two things the work turned up that were not in the plan:

- **`unitGroup_escort` would have become a global.** It was assigned without `local`, relying on the
  block of locals this refactor removed. Caught by reading the diff, not by a tool.
- **`teleportEscort` needs two waypoints and the lookup needs none.** The teleport rewrites the last
  two, so it now says so and refuses a one-point route instead of indexing `points[0]`. That hole
  predates this lot.

Also fixed in passing, in the mocks: `Group.getID` had no static form (`Group.getID(grp)`), which is
the form the production code uses, and the controller mock had no `setTask` — so no test could see a
mission being pushed at all.

## The original plan

- `veafAssets.respawn` re-establishes the escort task after respawning a linked group: same recovery
  and same group-id reassignment as `teleportEscort`, applied to the newly respawned pair.
- The logic is **shared**, not copied. Two implementations of a DCS quirk this obscure will diverge,
  and the comment explaining it must live with the code, not in one of two places.
- The naming convention (`<group> escort`) that `teleportEscort` relies on is currently implicit.
  Either the respawn path uses the same convention, or the asset's `linked` list says which group is
  an escort — decide, and document it on the ASSETS page (both languages), because a mission maker
  cannot guess it today.

## Verification

Not by unit test alone: the defect is a DCS behaviour the mocks do not model. Rerun check 9 of
`verify-mission-c` — respawn Arco, watch the escort for **longer than ten minutes**, since the
failure is a delayed RTB and a short look would have called this fixed.

## Definition of done

- [x] Verified in game 2026-08-28. The repair chain runs end to end and writes the runtime group id
      into the Escort task (`1000031` → `18`, instrumented trace in ticket 03). Getting there required
      ticket 03: the lookup only searched the last waypoint and found nothing on any real route
- [ ] A respawned escort keeps escorting. **It still does not** — but the remaining cause is that
      `mist.respawnGroup` puts the tanker back at its mission start while its escorts fly on, ~80 km
      away and outside the task's own `engagementDistMax` of 60 km. Moved to
      [`FIX-ESCORT-RESPAWN-DISTANCE`](../FIX-ESCORT-RESPAWN-DISTANCE/PRD.md)
- [x] One shared implementation, used by both the teleport and the respawn path
- [x] The escort convention documented on the ASSETS page (fr + en), including what `linked` is not
- [ ] #107 closed citing the measurement; #101 closed as not reproducible, saying what was tried
      (teleport **and** move, escort observed for 30 minutes) — after the in-game check, so the
      closing comment can say it was verified rather than assumed

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [One shared escort-task recovery](tickets/01-shared-escort-recovery.md) | ✅ |
| 02 | [Document the escort convention on the ASSETS page](tickets/02-document-escort-convention.md) | ✅ |
| 03 | [Find the Escort task on any waypoint, not only the last](tickets/03-find-the-escort-task-on-any-waypoint.md) | ✅ |
