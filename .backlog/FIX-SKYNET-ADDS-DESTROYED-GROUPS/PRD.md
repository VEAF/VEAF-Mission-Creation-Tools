# FIX-SKYNET-ADDS-DESTROYED-GROUPS — the IADS enrols groups DCS has already destroyed

Status: 🧑 waiting-human — **fix shipped**, awaiting one in-game observation

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
| 01 | [the init skips groups DCS has destroyed](tickets/01-init-skips-destroyed-groups.md) | the root cause |
| 02 | [`addGroupToNetwork` guards its own entry](tickets/02-add-group-guards-its-entry.md) | the other doors into the network |
| 03 | [vanished sites leave the network](tickets/03-vanished-sites-leave-the-network.md) | the mid-mission growth |
| 04 | [the destroyed-group mocks bite](tickets/04-mocks-that-bite.md) | tests, incl. one that passes on broken code today |

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
