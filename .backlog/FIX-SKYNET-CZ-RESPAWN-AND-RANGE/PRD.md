# FIX-SKYNET-CZ-RESPAWN-AND-RANGE — a combat zone's air defences, after the first second

Status: 🧑 waiting-human — **the three fixes are in**, awaiting the reading of Tripack's next log

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
| 01 | [a radar with no range is asked again](tickets/01-radar-range-is-not-final.md) | A, plus the instrumentation that will name the DCS cause |
| 02 | [a combat zone's spawn joins the IADS](tickets/02-combat-zone-spawn-joins-the-iads.md) | B |
| 03 | [a removal rebuilds the coverage](tickets/03-removal-rebuilds-the-coverage.md) | C |

## Where it stands

All three tickets are done. 170 tests in the Skynet suite and 301 in the combat-zone suite, and each
of the six production changes was reverted on its own and verified to turn the suite red — the table
is in the lot's report. What the code cannot settle is why DCS answers `nil`, which is written up as
a DCS-session item.

## Definition of done

- the three tickets, each with tests that fail when the production change is reverted
- one `info` line per site whose radars report no range, carrying the counts behind the verdict, so
  the next log Tripack sends says which of the DCS-side explanations is the real one
- `CHANGELOG.md` under `[Unreleased]`
