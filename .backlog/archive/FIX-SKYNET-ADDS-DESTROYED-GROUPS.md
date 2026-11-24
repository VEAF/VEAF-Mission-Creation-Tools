# FIX-SKYNET-ADDS-DESTROYED-GROUPS — the IADS enrols groups DCS has already destroyed

Status: ✅ done — start-up half verified in game 2026-10-03 (R14); the deactivated-zone site that ticket 03 missed is fixed and verified in `FIX-IN-GAME-SESSION-2026-10-03` ticket 03 (#1055) · archived 2026-11-24

Origin: [#946](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/946), filed by the support
bot from Tripack's Discord report of 2026-09-08 on `Snowfox_20260908.miz` (Persian Gulf): *"au
lancement de la mission la console IADS indique 16 SAM dont le radar est détruit"*, where he expects
every SAM to be operational.

## What "radar destroyed" actually counts

`Raddest` on the in-game IADS status page is `samSiteRadarDestroyed` in Skynet's
`printSystemStatus` (`skynet-iads-compiled.lua:1512`), incremented for every site where
`hasWorkingRadar()` is false:

```
hasWorkingRadar()  →  radar:isRadarWorking()
                   →  isExist() and (getSensors() ~= nil or getAmmo() ~= nil)
```

It is **not** a radar that was shot down. And it cannot be a radar Skynet failed to recognise
either: `SkynetIADS:addSAMSite` refuses any group whose NATO name stays `UNKNOWN`, and the
match condition in `setupElements` requires at least one search radar. So a site counted in
`Raddest` at mission start is a site **whose radar unit no longer exists**.

## Root cause

Three facts, in this order:

1. **A combat zone destroys every group inside it when it initialises**, synchronously while the
   mission's config script loads — `veafCombatZone.lua:1408`, *"remove all units in the trigger
   zone (we want it CLEAN !)"*.
2. **`veafSkynet` builds its networks one second later** (`DelayForStartup = 1`) by walking
   `coalition.getGroups(coa)` in `initializeIADS`, **with no `isExist()` guard**.
3. **`coalition.getGroups` can hand back a group that has been destroyed.** This is not a
   hypothesis: the repository documents it, on the Skynet side, at the very place where the guard
   *does* exist (`skynet-iads-compiled.lua:238`, `forEachLiveGroup`). The VEAF loop does not guard.

So groups destroyed a fraction of a second earlier are enrolled as SAM sites whose units are gone.
`hasWorkingRadar()` is false for every one of them, and they land in `Raddest`. Tripack's log puts
the two events inside the same second: destructions at `16:52:01.677`
(`woCar can't load destroyed model … for '55G6 EWR'`, ×4), IADS initialised at `16:52:01.969`.

And **nothing ever removes them**: `veafSkynet.removeSkynetElement` exists but is only reachable
from the point-defence path (`veafSkynetIadsHelper.lua:533`), and `PointDefenceMode` is `None` by
default.

## Measured

The 6.19-era build Tripack ran was not attached (the bot cannot carry a mission binary), so the
measurement is on `Snowfox_20260903.miz` — the same mission five days earlier, which he had sent on
2026-09-05 for FIX-TRIPACK-FIELD-REPORTS. VEAF's eligibility rule and Skynet's `setupElements`
matching were replayed against it:

| | |
|---|---|
| red groups carrying a SAM unit Skynet knows | **67** |
| accepted as SAM sites (a NATO name was found) | **67** — none rejected |
| **standing inside a `CMBT_` combat zone** | **61** |
| outside every combat zone, hence alive at start | 6 |

61 of the 67 sites are destroyed at mission start and are candidate zombies; 16 of them still
listed by `coalition.getGroups` one second later is consistent with a listing one frame behind. The
exact count is not predictable from the file and this lot does not claim it — what the file settles
is that **every** SAM site in this mission is a combat-zone group, so the mechanism has 61 chances
to fire.

## What is and is not broken

`SkynetIADS:getUsableSAMSites` filters on `isDestroyed()`, so the live SAMs are unaffected — which
matches the outcome of FIX-TRIPACK-FIELD-REPORTS, where the SAMs worked once the scheduler floor
shipped. The damage is a status page that reports sixteen dead radars where nothing was shot, a
contact-evaluation cycle that walks corpses, and — the part that is not cosmetic — a **group name
held by a dead entry**: `addGroupToNetwork` refuses a group already in the network
(`sam.dcsName == dcsGroupName`), so a site respawned under its own name can never rejoin the IADS.

## Tickets

| # | Ticket | Scope |
|---|---|---|
| 01 | [the init skips groups DCS has destroyed](FIX-SKYNET-ADDS-DESTROYED-GROUPS.md) | the root cause |
| 02 | [`addGroupToNetwork` guards its own entry](FIX-SKYNET-ADDS-DESTROYED-GROUPS.md) | the other doors into the network |
| 03 | [vanished sites leave the network](FIX-SKYNET-ADDS-DESTROYED-GROUPS.md) | the mid-mission growth |
| 04 | [the destroyed-group mocks bite](FIX-SKYNET-ADDS-DESTROYED-GROUPS.md) | tests, incl. one that passes on broken code today |

All four are done. 138 tests in the suite, each production change verified to fail on its own when
reverted — the table is in ticket 04.

## What the pre-PR review caught in this lot's own code

Five passes were run (conformity to the repository's instructions, obvious bugs in the diff, history
of the modified lines, prior pull requests on these files, directives written in the code's comments).
The history and prior-PR passes returned nothing at or above the threshold; they did confirm two of
the diff's own claims against the sources, and recorded that this file's two most recent substantive
changes (#828, #876) were merged with **no** review at all, Sourcery's weekly budget being spent.

Seven defects were found and fixed. Three in the fix's first pass, each now covered by a test that
fails without the repair:

1. **The guard was one line too late for the case that was reported.** It sat at the top of
   `addGroupToNetwork`, but the start-up enrolment asks the handle for its name *before* calling that
   function. The Skynet layer records `getUnits` raising on a released object and nothing says
   `getName` is safer — and a raise there does not skip one group, it aborts the whole enrolment. The
   loop now tests the object itself, and `dcs_mocks` group doubles refuse `getName` once
   `isExist()` is false, so the ordering is what the test measures.
2. **The refusal log asked the corpse for its name.** `veaf.lp(dcsGroup.getName and dcsGroup:getName())`
   inside the branch that had just concluded DCS no longer holds the group: the message meant to
   report the refusal was the thing that raised. Now `veafSkynet.safeDcsName`, through `pcall`.
3. **The ledger only ever grew.** A unit name that was killed once stayed marked forever, so a *reused*
   name — a combat zone reactivated, spawning under the same unit names unless the zone renames them
   — would read as a kill and the site would be kept instead of swept, quietly reinstating the defect
   in a narrower case. `veafSkynet.onUnitBorn` clears the entry on `S_EVENT_BIRTH`.

And four more from the later passes:

4. **The sweep crippled *live* sites.** `removeSkynetElement` called `skynetElement:cleanUp()`, and
   Skynet's `cleanUp` walks `self.pointDefences` and cleans each one up too — but a point defence is a
   separate, living site, still listed and still commanded. Cleaning it up calls
   `world.removeEventHandler` on it, and `SkynetIADSAbstractElement:onEvent` is what makes an element
   react to the world: `S_EVENT_DEAD` (go dark when the power source or connection node is gone, tell
   the children) and `S_EVENT_SHOT` (`weaponFired`, which is all HARM detection has). Unregistered, the
   site is commanded while blind to both. Unreachable before this lot — the only caller was the
   point-defence path in `Dcs` mode, where the element removed *is* the point defence. Fixed by
   detaching first, through the `removePointDefencesFromSkynetElement` that already existed.
5. **The verification written into the session item was wrong.** It said to read the `SAM: n | … |
   Raddest: n` line in `dcs.log`; that line goes through `trigger.action.outText` and never reaches the
   log. What `debugRed` writes is `printSAMSiteStatus`, one `GROUP: <name>` line per site — which names
   the site instead of making anyone count, so the corrected check is strictly better. Chasing that
   also showed the refusal was logged at `debug` while the default level is `info`: invisible exactly
   where it is needed, on a defect whose whole story is that nothing said a word. Now `info`.
6. **Three of the new comments stated things that are not true**, which in this repository is a defect
   in itself — these comments are what the next reader trusts instead of re-deriving. The
   point-defence comment blamed a stale `harmScanID` making `isScanningForHARMs()` lie: that function
   has no callers at all and `scanForHarms` restarts unconditionally, so the mechanism was invented
   (the *fix* is still right, for the reason in 4). A mock comment said a test had "passed for a year"
   against the unguarded call: `git log -S` dates that test to 2026-08-10, twenty-nine days. And the
   EWR comment said the removal "used to stand here": it was born commented out in `3002aaad`
   (2023-11-02) and never ran.
7. **The new init suite leaked global state** — two real event callbacks and one real repeating
   scheduled task per test, plus `SkynetIADS` and `dcsUnits` overwritten without restoring. Under the
   reporting threshold, fixed anyway: it is the class of leak `CHORE-MOCK-RESET-LEAKS` exists for.

Left as known and written down rather than fixed: freeing a group name does not by itself bring back a
site that respawns **under the same name inside** the sweep interval, because enrolment happens on the
birth event and nothing retries it (see the open point in the lot's report); and `lostUnits` is
unbounded, because the obvious filter reads a field that stops resolving at the moment of death.

## The reproduction Tripack built

David asked him for the mission and got `Skynet-test_20260908.miz` (2026-09-08) — not the Snowfox
build, a **deliberate minimal reproduction**, which is better for the in-game check:

- Caucasus, one combat zone `TESTCZ` (3 km), holding one SAM group `TESTCZ - SA6`
- three red SAM groups outside every zone (S-300, Kub, 2S6) and one `1L13 EWR`, all alive at start
- `veafSkynet.initialize(true, true, …)` — `debugRed` is **on**, so `samSiteStatusEnvOutput` is set
  and the status page goes to `dcs.log`, not only to the screen
- the config declares the zone and then `veafCombatZone.ActivateZone("TESTCZ", true)`, which schedules
  the zone's activation at `t + 1` — the very second `DelayForStartup` fires the enrolment

So the run is readable from the log alone. **Which line, though, needed checking**: the aggregate
`SAM: n | … | Raddest: n` goes through `trigger.action.outText` and never reaches the log. What
`debugRed` writes there is `printSAMSiteStatus`, one `GROUP: <name> | TYPE: <nato>` line per site in
the network — which names the site instead of making anyone count, so it is the better check. On the
code as it shipped before this lot, `TESTCZ - SA6` is expected among those lines; with the fix it must
be absent, the three live sites still present, and one `ADD GROUP REFUSED [TESTCZ - SA6]` line should
say why. Written up as DCS-session item **R14**, with the three readings and what each concludes.

That last line is why the refusal is logged at `info` rather than `debug`: the default level is `info`
and no shipped mission raises it, so a debug line would be invisible at the exact moment it matters.
This defect became a bug report because nothing said a word about sixteen sites enrolled dead.

## What is left open

The 6.19 Snowfox build and the **full** status line (`SAM: N | On: … | Raddest: 16`) are still
Tripack's to send, and they would settle one question only: whether 16 is the stale-listing artefact
this lot fixes, or a coincidence — `Snowfox_20260903.miz` happens to hold exactly 16
`ZSU-23-4 Shilka` groups. Not blocking: the defect is in the code either way, the reproduction above
exercises the mechanism, and the fix does not wait for it.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

`Skynet-test` (#946) rebuilt from `develop`: `TESTCZ - SA6`, destroyed by its zone at start, was not
enrolled; the network listed the three outside sites and the zone's **respawned** SA-6, which
`FIX-SKYNET-CZ-RESPAWN-AND-RANGE` makes join on purpose. No `ADD GROUP REFUSED` line: the guard had
nothing to refuse, so it is not exercised by this run.

Ticket 03 did not hold: after a deactivate/reactivate cycle the old SA-6 stayed listed for more than
four minutes (five sweeps) although DCS no longer held it. Followed in `FIX-IN-GAME-SESSION-2026-10-03` ticket 03.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**the IADS enrols groups DCS has already destroyed**. [#946](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/946), Tripack 2026-09-08: *16 SAM dont le radar est détruit* at mission start, with nothing shot at. `Raddest` counts sites where `hasWorkingRadar()` is false, and a site Skynet accepted always has a search radar — so those sixteen radars **no longer exist**. A combat zone destroys every group inside it while the config script loads; `veafSkynet` walks `coalition.getGroups` one second later with no `isExist()` guard, and DCS still lists what it has just destroyed — a quirk the repository already documents on the Skynet side, at the very place the guard *does* exist. Tripack's log puts both inside the same second. Measured on `Snowfox_20260903.miz`: **all 67** red SAM sites are combat-zone groups, 61 of them inside the zone geometry, so the mechanism has 61 chances to fire. The live SAMs are unaffected (`getUsableSAMSites` filters on `isDestroyed`), which is why this reads as a false alarm and is not one: nothing removes the dead entries, they hold their group **name**, and `addGroupToNetwork` refuses a name it already lists — so a site respawned under its own name can never rejoin the IADS. The delicate half is ticket 03: a sweep must **not** remove the sites the player killed, and a kill is indistinguishable from a despawn on the object — only the absence of `S_EVENT_DEAD` tells them apart. Fix shipped, all four tickets done; waiting on the in-game check R14 against the reproduction Tripack built

## Tickets, in full

## 01 — the IADS never enrols a group DCS has already destroyed

Status: ✅ done
Type: fix

The root cause of [#946](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/946).

### The defect

[`initializeIADS`](../../src/scripts/veaf/veafSkynetIadsHelper.lua) enrols the map:

```lua
local dcsGroups = coalition.getGroups(coa)
for _, dcsGroup in pairs(dcsGroups) do
  ...
  veafSkynet.addGroupToNetwork(networkName, dcsGroup, forceEwr, pointDefense, alreadyAddedGroups, true)
```

`coalition.getGroups` can return a group DCS has destroyed. The repository already says so, in the
Skynet compatibility layer, right above the guard that exists **there**
([`skynet-iads-compiled.lua`](../../src/scripts/community/skynet-iads-compiled.lua)):

> `coalition.getGroups` can hand back a group that has been destroyed, and asking such a group for
> its units raises.

Nothing on the VEAF side guarded, and this loop runs one second after every combat zone has destroyed
the groups standing inside it. Whatever the listing is still carrying at that moment became a SAM
site whose units are gone, hence a site counted in `Raddest` for the rest of the mission.

### Where the guard went, and why not here

`veafSkynet.dcsObjectStillExists` was written for it — with the DCS quirk in its docstring rather than
a restatement of what `isExist` does — and the call sits at the top of
`veafSkynet.addGroupToNetwork`, **not** in this loop. That function is the single door every caller
goes through: the start-up enrolment, the deferred birth-event handler, the radio menu and the
`_skynet` markers. One guard there covers four callers; one guard here would have covered one and
left the dynamic path — the one most likely to be handed a corpse, since it fires on a delay — open.

`not dcsObject.isExist` is deliberate and phrased as `forEachLiveGroup` phrases it: a handle that
cannot answer the question must not take the whole enrolment down with it.

### Definition of done

- [x] `veafSkynet.dcsObjectStillExists` exists, its docstring carrying the **why** — the DCS quirk
      and the combat-zone ordering, not the mechanics of `isExist`
- [x] the start-up enrolment no longer enrols a group DCS has released, and no longer dies on one
- [x] a group that exists is still enrolled exactly as before — the control case
- [x] Lua tests per ticket 04, verified to fail with the guard removed (4 of them drop)
- [x] `stylua --check src/scripts/veaf/ test/lua/` clean

## 02 — `addGroupToNetwork` guards its own entry

Status: ✅ done
Type: fix

### Why the guard cannot live in the init alone

`initializeIADS` is one of four ways a group reaches a network. The others are the birth-event
handler (`_integrateDynamicSpawn`, on every spawn while `dynamic_spawn` is on), the radio menu, and
the `_skynet` marker commands. All four end in
[`addGroupToNetwork`](../../src/scripts/veaf/veafSkynetIadsHelper.lua:763), and the dynamic path
is the one most likely to be handed a corpse: it fires on a **deferred** schedule
(`DelayForDynamicIntegration`), so a group that was spawned and destroyed inside that second — a
combat zone activated and deactivated in quick succession, a `#spawndelay` element whose zone went
down — arrives already dead.

### A second, smaller defect on the same three lines

```lua
function veafSkynet.addGroupToNetwork(networkName, dcsGroup, ...)
  veaf.loggers.get(veafSkynet.Id):debug("ADD GROUP START [" .. dcsGroup:getName() .. "] ...")

  if not dcsGroup then
    veaf.loggers.get(veafSkynet.Id):error("No group to find to add to network")
    return false
  end
```

The `nil` guard sits **after** the dereference that would raise. It has never been able to fire.
Same function, same family of defect (a DCS handle trusted without being checked), so it is fixed
here rather than filed as a separate lot — but it is a guard being made reachable, not a change of
behaviour: a `nil` group still returns `false`, it just no longer raises on the way.

### The fix

At the top of the function, before anything dereferences the handle: refuse a `nil` group, and
refuse a group DCS no longer holds, through the ticket-01 helper. `debug`, not `error`, for the
vanished case — a spawn that died before its integration ran is ordinary mission life, not a fault.

### Definition of done

- [x] the `nil` check precedes every dereference and still returns `false`
- [x] a destroyed group returns `false` and adds nothing, from any caller
- [x] a live group behaves exactly as before — the three existing `TestVeafSkynetAddGroupToNetwork`
      cases stay green untouched
- [x] Lua tests per ticket 04

## 03 — a site whose group was despawned leaves the network

Status: ✅ done
Type: fix

### What tickets 01 and 02 do not fix

They stop a corpse being **enrolled**. They do nothing about a site enrolled alive whose group
vanishes later — which is what makes `Raddest` grow during a mission, every time a combat zone is
deactivated and takes its air defences with it.

`veafSkynet.removeSkynetElement` was written for exactly this and is reachable from nowhere: its only
caller is the point-defence path (`veafSkynetIadsHelper.lua:533`), under `PointDefenceMode`, which
is `None` by default. So the code to remove a site exists and has never run in a shipped mission.

### The distinction that makes this ticket delicate

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

### The fix

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

### The gain beyond the counter

`addGroupToNetwork` refuses a group already listed in the network (`sam.dcsName == dcsGroupName`).
A dead entry therefore **holds the name**, and a site respawned under its own name can never rejoin
the IADS. Combat zones happen to dodge this — `veaf.getNameForSpawnedGroup` gives the respawn a new
name — but `_spawn`, `veafAssets.respawn` and any mission-maker respawn under the editor name do not.
Freeing the name is the functional half of this ticket.

### Definition of done

- [x] `removeSkynetElement` no longer touches a DCS object that is gone
- [x] a despawned SAM site is removed from `iads.samSites` and from the network's `groups` table
- [x] a **destroyed** SAM site is kept, so the status page still counts it
- [x] a despawned early-warning radar is removed from `iads.earlyWarningRadars`
- [x] the sweep interval is a named constant at the top of the module, with the other delays
- [x] the sweep survives a network with no IADS, and a deactivated network
- [x] Lua tests per ticket 04

### What shipped

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

## 04 — tests, and one that passes on broken code today

Status: ✅ done
Type: test

### The test that does not bite

`TestSecrev2RemoveSkynetElement:test_a_destroyed_group_does_not_raise` asserts that
`removeSkynetElement` survives an element whose group is gone. It passes. It would pass on the real
defect too, because the mock's

```lua
enableEmission = function(_) end
```

answers happily whether the object exists or not, while DCS raises on a destroyed one — and
`removeSkynetElement` calls `getDCSRepresentation():enableEmission(true)` with no guard at all. The
test asserts the handler, not the wiring: the same shape as the four defects shipped green on
2026-08-25.

Making the mock refuse to answer once `isExist()` is false is the point of this ticket, not a detail
of it: it is what turns three existing tests into a real check and what will fail on ticket 03's
code before it is written.

### What to cover

Ticket 01 — the init:

- a red group registered with `isExist() == false` is **not** enrolled, though
  `coalition.getGroups` hands it back
- a live group next to it in the same listing **is** enrolled — a guard that skips everything looks
  identical to a guard that works, on an empty network

Ticket 02 — the entry:

- a destroyed group returns `false` from `addGroupToNetwork` whichever caller passes it
- a `nil` group returns `false` instead of raising, which is what the existing unreachable guard
  claimed to do
- the three existing `TestVeafSkynetAddGroupToNetwork` cases stay green with no edit — the control

Ticket 03 — the sweep:

- a SAM site whose group was despawned (no death event) leaves `iads.samSites`
- a SAM site whose unit was reported lost (`S_EVENT_DEAD`) **stays**, so the SEAD readout survives.
  This is the assertion that makes the ledger load-bearing: drop it and a sweep that removes
  everything looks correct
- the network's `groups` entry goes with the removed site, so the name is free again
- an early-warning radar takes the same two paths
- `removeSkynetElement` on a destroyed object does not raise, **against a mock that raises the way
  DCS does**

### Definition of done

- [x] `dcs_mocks` group and unit doubles refuse the calls DCS refuses on a destroyed object
- [x] every case above asserted, in `test/lua/test_veafSkynetIadsHelper.lua`
- [x] each new suite verified to **fail** with its production change reverted, one at a time — not
      only to pass with it
- [x] `poetry run test-lua` green, and the coverage floor raised if the measure moved

### Measured

138 tests in the suite, all green. Each production change verified to fail on its own when reverted,
one at a time:

| reverted | tests that drop |
|---|---|
| the `dcsObjectStillExists` guard in `addGroupToNetwork` | 4 |
| the `enableEmission` guard in `removeSkynetElement` | 7, **including `TestSecrev2RemoveSkynetElement.test_a_destroyed_group_does_not_raise`** — the test that passed on the defect until the mock was made to refuse |
| removing from `iads.earlyWarningRadars` | 1 |
| the `lostUnits` ledger (`_wasReportedLost` forced to `false`) | 2, both *"a destroyed site is kept"* |
| the idempotence of `_armVanishedSitesSweep` | 1 |

Lua coverage: 80.50 % against a floor of 80, so the gate stays within the ~2-point tolerance and was
not moved.
