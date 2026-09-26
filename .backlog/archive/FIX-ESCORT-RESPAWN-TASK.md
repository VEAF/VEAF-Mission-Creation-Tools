# FIX-ESCORT-RESPAWN-TASK — a respawned escort goes home; the fix already exists next door

Status: ✅ done — shipped 2026-08-20, verified in game 2026-08-28, archived 2026-09-26. All three
tickets delivered. The check found a defect **in the repair itself** (ticket 03, fixed); the escort
still goes home, for a cause outside this lot — see
[`FIX-ESCORT-RESPAWN-DISTANCE`](../FIX-ESCORT-RESPAWN-DISTANCE/PRD.md), which also inherited the
closing of [#107](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/107): the issue's
symptom is that distance, not the task repair this lot shipped.

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
- [x] #101 closed as not reproducible, saying what was tried (teleport **and** move, escort observed
      for 30 minutes)
- [→] #107 **moved to `FIX-ESCORT-RESPAWN-DISTANCE`** on archiving, 2026-09-26. It stays open because
      its symptom — the respawned escort does not follow — is the 80 km this lot did not cause and
      does not fix; it closes on that lot's in-game check (item R5 of `DCS-SESSION-TODO.md`)

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | One shared escort-task recovery | ✅ |
| 02 | Document the escort convention on the ASSETS page | ✅ |
| 03 | Find the Escort task on any waypoint, not only the last | ✅ |

---

## Tickets, in full

Kept here because ticket 03 carries the instrumented trace that `FIX-ESCORT-RESPAWN-DISTANCE` and `FIX-TELEPORT-ESCORT-WAYPOINT` cite.

## 01 — One shared escort-task recovery, used by both the teleport and the respawn path

Status: ✅ done 2026-08-20 — 14 Lua tests; the in-game confirmation is tracked on the PRD, not here
Type: fix
Files: `src/scripts/veaf/veafMove.lua`, `src/scripts/veaf/veafAssets.lua`,
`test/lua/dcs_mocks.lua`, `test/lua/test_veafMove.lua`, `test/lua/test_veafAssets.lua`

### Why the recovery has to move, not be copied

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

### The convention, decided

The escort of `<group>` is the group named **`<group> escort`**. That is what `teleportEscort`
already relies on, it is the convention that is measured to work, and the PRD's alternative — reading
the asset's `linked` list — cannot replace it: **the escort does not have to be respawned for its
task to break.** Respawning the escorted group alone invalidates the task of an escort that is still
flying, which is exactly the reported case (respawn Arco, its escort is untouched and still goes
home). So the recovery is keyed on the name, not on `linked`.

The suffix becomes a named constant, `veafMove.EscortGroupNameSuffix`, so the convention has one
place to be read and documented (ticket 02).

### The timing, and why it is delayed

`Group.getID` must be read **after** the respawn, or it returns the id that just died. The read
therefore happens inside the scheduled call, not before it — `mist.scheduleFunction` at
`timer.getTime() + delay`, defaulting to the same 1 s `replaceMission` already uses for a teleport.

### Tests

Lua, with `mist.scheduleFunction` made immediate so the scheduled work is observable:

- `findEscortTask` returns the task for a group whose last waypoint carries one;
- it returns nil for a group with no escort, no route, or a route whose last waypoint has no `Escort`
  task — three separate holes, each of which a mission maker will hit;
- `reestablishEscortTask` on a group with no escort does nothing and says so, rather than erroring;
- it writes the **current** group id into the task and calls `setTask` on the escort's controller;
- `veafAssets.respawn` calls it — the guard is worthless if the call site was missed.

The controller mock gains `setTask`, which it does not currently have.

### Done when

`poetry run test-lua` passes, `luacheck` and `stylua` are clean, and one implementation of the
`groupId` reassignment exists in the tree (grep for it).

---

## 02 — Document the escort convention on the ASSETS page

Status: ✅ done 2026-08-20 — ASSETS page in both languages, plus the API reference entry for `veafAssets.respawn`
Type: docs
Files: `doc/mission-maker/scripts/veafAssets.md` + `.en.md`

### What is missing today

Nothing tells a mission maker that an asset's escort must be named `<asset> escort`. The convention
is implicit in `veafMove.teleportEscort`, and a mission maker cannot read Lua to find it. Today the
ASSETS page documents `linked` as *"name of a linked asset (e.g. a carrier linked to its escort)"*,
which reads as if `linked` were what makes an escort an escort. It is not.

### What to write

- The escort of an asset is the group named `<asset name> escort`, and that name is what lets the
  framework repair the escort's task when the asset is respawned or teleported.
- `linked` is a separate thing: it lists groups to **respawn along with** the asset. An escort may or
  may not be in it — the two mechanisms are independent, and saying so is the point of this ticket.
- One sentence on the symptom, because it is how a mission maker will arrive on this page: an escort
  that flies its route and lands after about ten minutes was an escort whose task DCS invalidated.

Both languages, and the anchor convention applies if the section is linked from elsewhere.

### Done when

`poetry run docs-check` passes and both pages say the same thing.

---

## 03 — Find the Escort task on any waypoint, not only the last

Status: ✅ done — 2026-08-28
Type: fix

Found by running the lot's own in-game check ([DCS-SESSION-TODO](../../DCS-SESSION-TODO.md)
item 10) on 2026-08-28. The repair ticket 01 shipped could not fire on the mission it was tested
against — nor on the repository's own demo mission.

### The defect

`veafMove.findEscortTask` read the task off the **last** waypoint of the escort's route and nowhere
else:

```lua
-- Last waypoint: where the escort task has to be set up in the editor.
local task2_escort = veaf.findInTable(points_escort[#points_escort], "task")
```

Nothing in DCS puts the `Escort` task on the last waypoint. A mission maker sets it wherever the
escort is meant to join, which is normally *before* the end of the route. Probed in game on the
three escorts of the demo mission this lot is verified against:

| Group | Waypoints | Escort task on |
|---|---:|---|
| `Arco escort` | 3 | **wp2** |
| `Arco-escort1` | 3 | **wp2** |
| `Petrolsky-escort` | 3 | **wp2** |

So every call reported `Arco escort exists but carries no Escort task ; nothing to repair` and
returned false. That line is in `dcs.log` for the 2026-08-28 run.

### Why the tests were green

`test_veafMove_escort.lua` built its fixture to the shape the code expected — the helper's own
docstring said *"with an Escort task on the last waypoint"*, and the test was called
`test_the_escort_task_is_found_on_the_last_waypoint`. The fixture asserted the implementation, not
the data DCS produces. Compare [[assert-the-applied-value-not-the-constant]].

### What was done

- `findEscortTask` walks the whole route, **last waypoint first**, so a mission that does put the
  task on the last waypoint resolves to exactly the same task as before.
- Four tests added, and each was **run against the old implementation first** to prove it fails
  there: task on an intermediate waypoint, task on the first waypoint, last waypoint still preferred
  when two waypoints carry one, and a disabled task late in the route not masking a valid earlier one.
  Three of the four were red before the change; the fourth is the non-regression.
- The ASSETS page said "set the `Escort` task on the **last waypoint**" in both languages. It now
  says **any waypoint**.

### Verified in game, 2026-08-28

The chain runs end to end. Instrumented on the live session, after a respawn of Arco:

```
1. reestablishEscortTask(Arco) called            -> true
2. actualReestablish(Arco -> Arco escort)  escortedGroupExists=true  runtimeId=18  taskIdBefore=1000031
3. replaceMission(group=Arco escort)  hasRoute=true  points=3   -> ok
2. -> taskIdAfter=18
```

The stale id `1000031` is replaced by the runtime id `18`, which is what ticket 01 set out to do.

**The escort still went home**, for a reason that is not this lot's — see
[`FIX-ESCORT-RESPAWN-DISTANCE`](../FIX-ESCORT-RESPAWN-DISTANCE/PRD.md).

### Definition of done

- [x] The Escort task is found wherever it sits on the route
- [x] Tests proven to fail against the previous implementation
- [x] `stylua --check` clean, Lua suite green (41 suites, 150 tests)
- [x] ASSETS page corrected, both languages, `docs-check` clean

---
