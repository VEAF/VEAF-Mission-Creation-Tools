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
start-up enrolment takes **every** eligible group standing on the map at `DelayForStartup` — one
second in. And `veafCombatZone.ActivateZone` schedules a zone's activation at `timer.getTime() + 1`
(`veafCombatZone.lua:2714`): **the same second**.

The pre-merge history pass challenged this, and was half right. The zone's `initialize` destroys the
editor groups inside the trigger zone synchronously, while the config script loads, so the group the
enrolment finds is never the editor one — it is the group the *activation* has just respawned, and
only if the activation ran first. It did, on Tripack's run: `TESTCZ [r] TESTCZ - SA6#10262` — a
respawn, as its name says — was enrolled at **09:58:02.591**, in the same millisecond as
`Creating IADS for RED`, and `dynamic_spawn` is absent from that mission's `veaf-config.lua`.

Which makes the case for this ticket stronger than first written: without it, whether a zone's
battery belongs to the IADS is decided by the order of two tasks scheduled for the same second. It
joined at mission start, left at the first sweep after a deactivation, and never came back. Requiring
`dynamic_spawn` would not fix that — it would only make the first second agree with the rest by
dropping the site from both. `dynamic_spawn` keeps its meaning (groups the Mission Editor or a
third-party script spawns); a zone announcing what it puts back is what makes the answer the same at
second one and at second six hundred.

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

## Known limit, left as it is

The gate is `not isMobile()` — a route with more than one waypoint. That is the criterion the alarm
state already uses, and it is SAM-shaped: an **early-warning radar** a zone spawns with a route would
not rejoin the network, although a moving radar still sees. Not fixed here, because the fix would be
a second, EWR-specific criterion for a case no mission in the repository exercises, and this lot has
no measurement of it. Recorded so the next reader does not take the omission for an oversight.

Found by the pre-merge review pass on prior pull requests, which also surfaced the exclusivity rule
#151 posed for the two integration paths (*"doing it here as well would integrate the same group
twice"*). That one **was** fixed: `integrateMissionSpawn` now leaves the work to a network whose
`dynamicSpawn` is on, instead of scheduling an integration that network would refuse.
