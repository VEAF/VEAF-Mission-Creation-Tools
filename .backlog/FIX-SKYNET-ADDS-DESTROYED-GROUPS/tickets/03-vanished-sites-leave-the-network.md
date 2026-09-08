# 03 — a site whose group was despawned leaves the network

Status: ✅ done
Type: fix

## What tickets 01 and 02 do not fix

They stop a corpse being **enrolled**. They do nothing about a site enrolled alive whose group
vanishes later — which is what makes `Raddest` grow during a mission, every time a combat zone is
deactivated and takes its air defences with it.

`veafSkynet.removeSkynetElement` was written for exactly this and is reachable from nowhere: its only
caller is the point-defence path (`veafSkynetIadsHelper.lua:533`), under `PointDefenceMode`, which
is `None` by default. So the code to remove a site exists and has never run in a shipped mission.

## The distinction that makes this ticket delicate

A sweep that removed every site whose group is gone would be wrong. **Skynet is meant to keep the
sites the player destroyed**: `Raddest` for SAM sites and `Destroyed:` for early-warning radars are
the SEAD readout — the mission maker watching an IADS come apart wants to see `EW: 6 | Destroyed: 4`,
not `EW: 2 | Destroyed: 0`. Removing a kill from the network deletes that information.

And the two cases are indistinguishable from the object: a group shot to pieces and a group
`destroy()`-ed both answer `isExist() == false`, and both make `SkynetIADSSamSite:isDestroyed()`
true.

What tells them apart is the **event**. DCS raises `S_EVENT_DEAD` / `S_EVENT_UNIT_LOST` for a unit
that was killed and **nothing at all** for a unit that was despawned by script. So:

> a site whose DCS object is gone **and** none of whose units was ever reported lost was despawned,
> not destroyed.

## The fix

- a ledger of unit names reported lost, filled by one `veafEventHandler.addCallback` on
  `S_EVENT_DEAD` and `S_EVENT_UNIT_LOST` — keyed on **unit name** through
  `veafEventHandler.unitNameFromEvent`, not on group name: `completeUnitFromName` resolves the group
  through `Unit.getByName`, which is exactly what has stopped answering by the time a death is
  reported
- a periodic sweep, one per network, removing SAM sites and early-warning radars whose object is
  gone and whose units are absent from the ledger
- `removeSkynetElement` calls `getDCSRepresentation():enableEmission(true)` unguarded, two lines
  below a comment stating that the function is called precisely when the representation is gone.
  That raises in DCS on a destroyed object. It has to be guarded before anything calls this function
  for real — see ticket 04, whose existing test passes on this defect because its mock never raises

Sweeping the early-warning radars means using `iads.earlyWarningRadars`, not
`iads:getEarlyWarningRadars()`: the getter returns a delegator **copy**, which is why the EWR line
inside `removeSkynetElement` was left commented out with a trace reading *"not removed here"*.

## The gain beyond the counter

`addGroupToNetwork` refuses a group already listed in the network (`sam.dcsName == dcsGroupName`).
A dead entry therefore **holds the name**, and a site respawned under its own name can never rejoin
the IADS. Combat zones happen to dodge this — `veaf.getNameForSpawnedGroup` gives the respawn a new
name — but `_spawn`, `veafAssets.respawn` and any mission-maker respawn under the editor name do not.
Freeing the name is the functional half of this ticket.

## Definition of done

- [x] `removeSkynetElement` no longer touches a DCS object that is gone
- [x] a despawned SAM site is removed from `iads.samSites` and from the network's `groups` table
- [x] a **destroyed** SAM site is kept, so the status page still counts it
- [x] a despawned early-warning radar is removed from `iads.earlyWarningRadars`
- [x] the sweep interval is a named constant at the top of the module, with the other delays
- [x] the sweep survives a network with no IADS, and a deactivated network
- [x] Lua tests per ticket 04

## What shipped

- `veafSkynet.lostUnits`, filled by one `veafEventHandler` callback on `S_EVENT_DEAD` and
  `S_EVENT_UNIT_LOST`, keyed on unit name through `unitNameFromEvent` so both event shapes count
- `veafSkynet.removeVanishedSites(networkName)` and `veafSkynet.sweepVanishedSites()`, the latter
  scheduled every `SecondsBetweenVanishedSitesSweeps` seconds (60) from `_initialize`
- `_armVanishedSitesSweep` is idempotent: a reinitialisation must not stack a second callback nor a
  second schedule, which would record every loss twice and sweep twice (the shape of #824)
- `removeSkynetElement` no longer hands emission back to an object DCS has released, and now removes
  from `iads.earlyWarningRadars` — the field, not the delegator **copy** the getter returns, which is
  what the commented-out line and its *"not removed here"* trace were recording
- `getStringSkynetElement` goes through the same helper, so describing an element whose representation
  is `nil` says so instead of raising. That line is what `removeSkynetElement` logs, on elements
  chosen precisely for having lost their object
