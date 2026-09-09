# 02 — a combat zone's spawn joins the IADS

Status: ✅ done

## The defect

A combat zone respawns its groups through `VeafGroupSpawn:respawn()` →
`veafDcsSpawner.addGroup()` → `coalition.addGroup`, and nothing in that chain mentions Skynet. The
birth-event handler that would otherwise catch the group is only armed when a network carries
`dynamicSpawn == true`, and that defaults to **false**.

Result: the sweep from #947 correctly removes a zone's air defences when the zone is switched off,
and nothing ever puts them back. Tripack's reactivated zone gave `3 SAM` where the mission started
with `4`, and his SA-6 sat outside the network for the rest of the run.

## Why this is not "just switch `dynamic_spawn` on"

FIX-SKYNET-DYNAMICSPAWN-SCOPE settled #151 by making `dynamic_spawn` a documented `mission.yaml`
field, and verified in game on 2026-08-22 that a combat-zone SAM joins the IADS **when the flag is
on**. That decision stands, and this ticket does not reopen it. What it repairs is an asymmetry the
flag does not govern:

`veafSkynet.loadAllAtInit` is `true` for both coalitions (`veafSkynetIadsHelper.lua:54`), so the
start-up enrolment takes **every** eligible group on the map — a combat zone's air defences included,
with `dynamic_spawn` off. That is what Tripack sees: `4 SAM` at mission start, his zone's SA-6 among
them. Cycle the zone and it is gone for good.

So the same site is in the network at second one and out of it at second sixty, under one
configuration. A mission maker cannot read that as an option; it reads as the IADS losing sites as
the mission runs. `dynamic_spawn` keeps its meaning — groups the Mission Editor or a third-party
script spawns — and a zone respawning content the author placed in it stops being a spawn nobody
asked for.

## What to build

- split the network-flag check out of `veafSkynet._integrateDynamicSpawn` so the same integration can
  be reached by a caller that is *not* the birth handler;
- `veafSkynet.integrateMissionSpawn(groupName)`: integrate a group a mission feature has just
  respawned into its coalition's default network, **without** requiring `dynamicSpawn`. The coalition
  is read from the group itself, not passed in, so the caller cannot get it wrong.
- call it from `VeafCombatZone:spawnElement`, for zone elements that are **not mobile** — the same
  criterion that already decides the alarm state (a battery that stays put wants RED and belongs in
  the IADS; a convoy wants AUTO and does not).

Why not simply arm the birth handler unconditionally: `dynamic_spawn` is a documented mission option
meaning "integrate groups spawned during the mission" — groups from the Mission Editor or a
third-party script. A group a combat zone respawns is neither: it is mission content the author placed
in a zone, and it was in the IADS at mission start. Requiring an opt-in to get it back would be a new
trap.

Double integration is not a risk: `addGroupToNetwork` refuses a group the network already lists.

## Done when

- a non-mobile zone element that respawns is integrated into its coalition's network with
  `dynamicSpawn == false`
- a mobile element (a convoy) is not
- the integration is skipped when the group is gone by the time it runs, and when the module is not
  initialised
- reverting the production change makes the new tests fail
