# FIX-SKYNET-CZ-RESPAWN-AND-RANGE — a combat zone's air defences, after the first second

Status: ✅ done — the root cause was found on the fourth round and **verified in game 2026-09-09** · archived 2026-09-28

Origin: the second and third rounds of [#946](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/946).
FIX-SKYNET-ADDS-DESTROYED-GROUPS shipped the corpse guard and the sweep; Tripack ran the resulting
test build twice and reported that **nothing had changed** for the SAM standing inside his combat
zone. His `dcs.log` of 2026-09-09 (attachment `32002594`) says why, and it is not the same defect.

## What his run measured

| step | SAM | Raddest |
|---|---|---|
| mission start | 4 | 1 |
| combat zone deactivated | 3 | 0 |
| combat zone **reactivated** | **3** | **0** |
| `-destroy` on the three sites outside the zone | 0 | 0 |
| a SA-6 added with a marker | 1 | 0 |

Plus, in his words: *"Le SA-6 de la CZ n'est pas inclus dans IADS et il est pleinement opérationnel,
il tire sur le F/A-18"*.

Three separate defects, none of them the one #947 fixed.

## A — the radar range is read once, and never questioned

Both of his symptoms come out of the same field. `Raddest` counts
`hasWorkingRadar() == false`; `SAM SITES IN COVERED AREA` counts the sites inside
`maximumRange`. And `maximumRange` is filled by `SkynetIADSSAMSearchRadar:setupRangeData`, called
exactly once, from `buildSingleUnit`, at the instant the element is built
(`skynet-iads-compiled.lua:3013`). It reads `getSensors()`. When that answers `nil`, the range stays
**0 for the rest of the mission**.

Four readings from his log pin the state down:

| reading | what it proves |
|---|---|
| the site is in the network as `TYPE: SA-6` | the 1S91 was in `getUnits()` at setup — otherwise `natoName` stays `UNKNOWN` and `addSAMSite` rejects the group |
| it is listed as a **child** of the three other sites | its radar handle answers `isExist() == true` (`isInRadarDetectionRangeOf` requires it on both sides) |
| `HAS AMMO: true` | its launchers answer |
| `SAM SITES IN COVERED AREA: 0`, while the other SA-6 — same type, same range — sees it | its `maximumRange` is zero |

One combination satisfies all four: **the radar handle exists and `getSensors()` returned nil**.
A 1S91 carries no ammunition, so the `getAmmo()` fallback on line 3963 does not save it either.

Why DCS answers nil on that handle is **not measurable from this machine** — and does not need to
be, to fix this. The exploitable fault is ours: a single unverified reading decides a site's range
for the whole mission. Four hypotheses were eliminated on the way, and are written down in ticket 01
so nobody re-runs them.

## B — a site respawned by a combat zone never rejoins the network

Traced end to end. `VeafCombatZone:activate()` → `spawnElement()` →
`VeafGroupSpawn:respawn()` → `veafDcsSpawner.addGroup()` → `coalition.addGroup`. **No link in that
chain knows Skynet exists** — `grep -n skynet veafCombatZone.lua veafDcsSpawner.lua` returns
nothing.

The only remaining catch-all is the birth-event handler, and it is only armed when a network carries
`dynamicSpawn == true`, whose default is **false** (`veafSkynet.DynamicSpawn`, and the generator only
writes the variable when `dynamic_spawn` is stated in the mission's yaml).

His log proves the flag was off, without needing the mission file: the SA-6 he added with a marker
went live **2 ms** after its birth (`New Object Spawned` 10:03:08.924 → `GOING LIVE` .926), while the
birth handler waits `DelayForDynamicIntegration = 1` second. That ajout came through
`veafSpawnCore`'s explicit path, which is taken *only* `if not integratesDynamicSpawns(networkName)`.

So a zone's air defences leave the network when the zone is switched off — the sweep #947 added does
that correctly — and never come back. On a mission that cycles its zones, the IADS drains as the
mission goes on. That is worse than the lying counter the lot started from.

## C — the coverage graph is never rebuilt after a removal

At 10:03:13, with three sites destroyed by command and the zone's site swept, the EW radar still
announces `SAM SITES IN COVERED AREA: 5` and names four elements that are **no longer in the
network**. Nothing calls `buildRadarCoverage` after a removal, so `informChildrenOfStateChange` keeps
commanding elements that have been cleaned up. A regression introduced by #947.

## Tickets

| # | Ticket | Scope |
|---|---|---|
| 01 | [a radar with no range is asked again](FIX-SKYNET-CZ-RESPAWN-AND-RANGE.md) | A, plus the instrumentation that will name the DCS cause |
| 02 | [a combat zone's spawn joins the IADS](FIX-SKYNET-CZ-RESPAWN-AND-RANGE.md) | B |
| 03 | [a removal rebuilds the coverage](FIX-SKYNET-CZ-RESPAWN-AND-RANGE.md) | C |
| 04 | [the radar must be the first unit](FIX-SKYNET-CZ-RESPAWN-AND-RANGE.md) | the root cause, found in game |

## Where it stands

All four tickets are done, and the DCS-side question the first three left open is **answered**: DCS
gives a SAM group no sensors at all when its first unit is not its radar, and `buildSnapshot` was
shuffling that order with `pairs`. See [ticket 04](FIX-SKYNET-CZ-RESPAWN-AND-RANGE.md) for
the fourteen probes that settled it in the running mission, in both directions.

That answer retires ticket 01's re-read — it rested on the explanation the measurement replaced, and
`Unit.getByName` hands back the same handle anyway — so the scaffolding was removed and its tests with
it. The diagnostic line naming each radar unit is kept, as a canary for any other cause.

**Verified in game 2026-09-09** on `Skynet-test_20260908-fix946f`: no `RADAR RANGE` line at all, the
zone's SA-6 active and tracking the F/A-18 at 7 NM, and it fired.

## What the pre-merge review caught in this lot's own code

Five passes (conformity to the repository's instructions, obvious bugs in the diff, history of the
modified lines, prior pull requests on these files, directives written in the code's comments).
Sourcery could not review: the weekly 250 000-character budget was spent, as it was for #947.

Two findings at or above the reporting threshold, both fixed:

1. **The coverage rebuild woke a network somebody had switched off.** `SkynetIADS:buildRadarCoverage`
   ends by calling `informChildrenOfStateChange()` on every SAM site — the vendored comment says it
   is *"to make sure autonomous sites go live"* — and a parentless site whose autonomous behaviour is
   the default `AUTONOMOUS_STATE_DCS_AI` then goes live: radar on, alarm state red.
   `deactivateNetwork` deliberately leaves `samSites` populated and only marks the network, and
   `sweepVanishedSites` walks **every** network, so the periodic sweep would have relit a deactivated
   one — around the refusal `delayedActivate` exists to enforce (#261), and with those elements'
   world event handlers already unregistered by `cleanUp()`. Two passes found it independently.
   `rebuildRadarCoverage` now refuses a deactivated network.
2. **The written justification for not requiring `dynamic_spawn` was wrong** — and it was the whole
   argument, so an inaccurate comment here is a defect in itself. It said the start-up enrolment takes
   an active zone's batteries because `loadAllAtInit` is true. The history pass objected that a zone's
   `initialize` destroys the editor groups synchronously, before that enrolment ever runs. It is right
   about the mechanism and wrong about the conclusion, and Tripack's log settles it: what was enrolled
   at 09:58:02.591 is `TESTCZ [r] TESTCZ - SA6#10262` — a **respawn**, as the name says — because
   `ActivateZone` schedules the activation at `timer.getTime() + 1` and `DelayForStartup` is `1`. The
   real story is worse than the one first written: membership was decided by which of two tasks
   scheduled for the same second ran first. Corrected in the code comment, in the ticket and in both
   documentation pages.

Three below the threshold, fixed anyway:

- the lot index row was written in French, which the repository's own instructions forbid for
  technical documentation;
- the two new settings (`DelayForRangeRecheck`, `MaxRangeRechecks`) were announced in the changelog
  and documented nowhere, while the preceding lot documented its own knob on that same page;
- `RADAR RANGE ZERO` promised a re-read even when none was coming (no live radar left, or
  `MaxRangeRechecks = 0`) — misleading in the one log this lot exists to make readable. It now names
  which of the three cases applies. Two more new comments overstated what the code does (the
  idempotence of `setupRangeData`, and "the same criterion that chose the alarm state", which only
  holds when no `#alarm=` tag was stated) and were corrected.

One finding was checked and **dismissed with its evidence**: that a zone's `#command` air defences
would be left orphaned. The SAM shortcuts carry `skynet true` (`veafShortcuts.lua:837`), so they take
`veafSpawnCore`'s explicit integration path at spawn time. And one gap is recorded rather than fixed,
in ticket 02: a combat-zone **early-warning radar** given a route would not rejoin the network, since
the gate is `isMobile()`. No mission in the repository exercises it and this lot has no measurement
of it.

## Definition of done

- the three tickets, each with tests that fail when the production change is reverted
- one `info` line per site whose radars report no range, carrying the counts behind the verdict, so
  the next log Tripack sends says which of the DCS-side explanations is the real one
- `CHANGELOG.md` under `[Unreleased]`

---

## Tickets, in full

## 01 — a radar that reports no range is asked again

Status: ✅ done

### The defect

`SkynetIADSSAMSearchRadar:setupRangeData` is called once per radar, from `buildSingleUnit`, while the
element is being built (`skynet-iads-compiled.lua:3013`). It reads `getSensors()` and writes
`maximumRange`. If the answer is `nil`, `maximumRange` keeps its constructor value — `0` — and no
code path ever reads the sensors again.

A site in that state:

- detects nothing (`isInRadarDetectionRangeOf` compares against `maximumRange`), so it never goes
  live, even when a player flies over it;
- is counted under `Raddest` on every status page, because `isRadarWorking()` also goes through
  `getSensors()`, and a search radar carrying no ammunition gets nothing from the `getAmmo()`
  fallback either.

That is both of Tripack's symptoms out of one unread field.

### Hypotheses eliminated — do not re-run these

1. **"the radar unit was not born yet"** — no. `addSAMSite` rejects a group whose `natoName` stays
   `UNKNOWN`, and the match in `setupElements` requires at least one search radar. The site is in the
   network as `TYPE: SA-6`, so the 1S91 was there.
2. **"DCS had not finished initialising the unit"** — no. The marker-spawned SA-6 was enrolled 2 ms
   after its birth event and its radar works (`Raddest: 0`).
3. **"a corpse was enrolled, #947 did not hold"** — no. The guard is at both levels
   (`veafSkynetIadsHelper.lua:1263` and `:1009`) and no `ADD GROUP REFUSED` line appears in the log.
4. **"the zone leaves its SAMs on alarm state green, radar down"** — no.
   `veafCombatZone.DefaultAlarmStateStatic` is `ALARM_STATE_RED`.

What remains — why DCS answers `nil` on a live handle — cannot be measured without the game, which
is why this ticket both repairs and instruments.

### What to build

- `veafSkynet.measureRadarRange(element)` → widest range reported, number of radars, number of them
  DCS still holds. One place that knows how to ask, used by the check and by the tests.
- `veafSkynet.checkRadarRange(networkName, element)`, called for every element joining a network:
  logs at **`info`** when the range is zero while the element holds a live radar — with the counts,
  so the line is a diagnosis and not a complaint — and schedules a re-read.
- `veafSkynet.recheckRadarRange(...)`: calls `setupRangeData()` again on each radar, up to
  `veafSkynet.MaxRangeRechecks` times, `veafSkynet.DelayForRangeRecheck` seconds apart, and rebuilds
  the coverage as soon as one radar answers with a range.

`info` rather than `debug`, for the reason ticket 02 of the previous lot recorded: the default level
is `info` and no shipped mission raises it, so a `debug` line is invisible exactly where it is needed.
Silent on the normal case — one line per *faulty* site, not per site.

### Done when

- a site whose radars report zero is re-read, and its range is picked up when the second reading
  answers
- a site whose radars report a range is never re-read, and logs nothing at `info`
- the re-read stops after `MaxRangeRechecks`, and never runs on an element DCS no longer holds
- reverting the production change makes the new tests fail

---

## 02 — a combat zone's spawn joins the IADS

Status: ✅ done

### The defect

A combat zone respawns its groups through `VeafGroupSpawn:respawn()` →
`veafDcsSpawner.addGroup()` → `coalition.addGroup`, and nothing in that chain mentions Skynet. The
birth-event handler that would otherwise catch the group is only armed when a network carries
`dynamicSpawn == true`, and that defaults to **false**.

Result: the sweep from #947 correctly removes a zone's air defences when the zone is switched off,
and nothing ever puts them back. Tripack's reactivated zone gave `3 SAM` where the mission started
with `4`, and his SA-6 sat outside the network for the rest of the run.

### Why this is not "just switch `dynamic_spawn` on"

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

### What to build

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

### Done when

- a non-mobile zone element that respawns is integrated into its coalition's network with
  `dynamicSpawn == false`
- a mobile element (a convoy) is not
- the integration is skipped when the group is gone by the time it runs, and when the module is not
  initialised
- reverting the production change makes the new tests fail

### Known limit, left as it is

The gate is `not isMobile()` — a route with more than one waypoint. That is the criterion the alarm
state already uses, and it is SAM-shaped: an **early-warning radar** a zone spawns with a route would
not rejoin the network, although a moving radar still sees. Not fixed here, because the fix would be
a second, EWR-specific criterion for a case no mission in the repository exercises, and this lot has
no measurement of it. Recorded so the next reader does not take the omission for an oversight.

Found by the pre-merge review pass on prior pull requests, which also surfaced the exclusivity rule
#151 posed for the two integration paths (*"doing it here as well would integrate the same group
twice"*). That one **was** fixed: `integrateMissionSpawn` now leaves the work to a network whose
`dynamicSpawn` is on, instead of scheduling an integration that network would refuse.

---

## 03 — a removal rebuilds the coverage

Status: ✅ done

### The defect

The parent/child radar graph is built once, by `SkynetIADS:buildRadarCoverage`, when the network
activates. `veafSkynet.removeSkynetElement` takes an element out of `iads.samSites` and
`iads.earlyWarningRadars` — and leaves it listed as a **child** of every element that could see it.

Measured on Tripack's log, 10:03:13: three sites destroyed by command, one swept, and the EW radar
still announces `SAM SITES IN COVERED AREA: 5`, naming four elements that are no longer in the
network. `informChildrenOfStateChange` keeps commanding elements that have been cleaned up.

Introduced by #947: before the sweep existed, the only caller of `removeSkynetElement` was the
point-defence path, which does not run by default.

### What to build

- `veafSkynet.rebuildRadarCoverage(networkName)`: `iads:buildRadarCoverage()` through `pcall`, since
  it is called right after corpses have been dropped;
- call it from `removeVanishedSites` when the sweep actually removed something — once per sweep, not
  once per element.

### Done when

- a sweep that removes an element rebuilds the coverage
- a sweep that removes nothing does not
- a network with no IADS does not raise
- reverting the production change makes the new tests fail

---

## 04 — the radar must be the first unit, and `pairs` was losing that

Status: ✅ done — **verified in game 2026-09-09**
Type: fix

This ticket answers the question tickets 01–03 left open and wrote up as a DCS-session item: *why
does DCS report no sensor data for a radar unit it still holds?*

### The answer

**It is not about the radar. DCS gives a SAM group no sensors at all — on every unit — when the
group's first unit is not its radar.**

And VEAF was shuffling that order itself. `veafMissionDb.buildSnapshot` walked a group's units with

```lua
for _, unitData in pairs(groupData.units or {}) do
```

`pairs` has no defined order, so every mission record carried its units in hash order. A respawn
hands that order straight to `coalition.addGroup`. On Tripack's SA-6 the radar landed third of five.

### Measured, in game, against DCS itself

Through the bridge injected into the test mission, on 2026-09-09. Fourteen probe groups, each created
and destroyed in the running mission:

| probe | first unit | units with sensors |
|---|---|---|
| the record exactly as VEAF submits it | `Kub 2P25 ln` | **0 / 5** |
| the *same five units*, radar moved back to first | `Kub 1S91 str` | **5 / 5** |
| a hand-written pair, radar first | `Kub 1S91 str` | 2 / 2 |
| the *same pair*, launcher first | `Kub 2P25 ln` | **0 / 2** |

The check falls both ways: reordering repairs it, and inverting breaks a group that worked. Eleven
further probes cleared, one at a time, `coldAtStart`, `playerCanDrive`, `unitId`, `groupId`,
`missionData`, `route`, `task`, the coordinates, the unit count and `coalition.addGroup` itself.

The editor group standing outside the zone (`Sol_g-2`), same five unit types, reported 5/5 throughout
— it is never respawned, so nothing shuffled it. That is why the defect looked machine-specific and
was not.

### What it explains, all of it

- `getSensors()` nil → `SkynetIADSSAMSearchRadar:setupRangeData` finds no range → `maximumRange`
  stays 0 → `isTargetInRange` is always false → the site never goes live and never fires
- the same nil → `isRadarWorking()` false → the site is counted under `Raddest` on the status page

One word, both of #946's symptoms. It also retires ticket 01's re-read, which was built on the
explanation this measurement replaced: `Unit.getByName` hands back the very same handle, so
re-resolving it was a no-op (`rehandled=0` in the log of the run that measured it). The diagnostic
line naming each radar unit is kept as a canary for any other cause.

Beyond Skynet: everything that anchors on "unit 1" of a respawned group — the spawn offset of
FIX-TRIPACK-FIELD-REPORTS ticket 04 among them — was anchoring on whichever unit the hash order put
there.

### Verified in game

2026-09-09, `Skynet-test_20260908-fix946f`, launched from the mission list. No `RADAR RANGE` line at
all; the zone's SA-6 reported `ACTIVE: true`, `HAS AMMO: true`, `DETECTED TARGETS: 1` on the F/A-18 at
7.03 NM, its units stationary and carrying three missiles each; it held the lock and fired once the
aircraft came back inside its envelope.

### Definition of done

- [x] `ipairs`, with a comment carrying the measurement rather than the mechanics
- [x] tests that fail when the change is reverted — two of the three do so deterministically, through
      a non-array key that `pairs` visits and `ipairs` does not; asserting order alone would be flaky
      because Lua often walks a short array in order by luck
- [x] the re-read scaffolding of ticket 01 removed, its tests with it
- [x] verified in game

---
