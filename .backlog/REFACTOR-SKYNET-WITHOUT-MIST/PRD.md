# REFACTOR-SKYNET-WITHOUT-MIST — cut Skynet's 42 calls to MiST, in a fork we own

Status: ✅ done — checked in game 2026-08-31, without a single takeoff

Origin: David, 2026-08-30, on `DROP-MIST` ticket 08 — *"skynet : pareil, c'est un fork du Regroupement,
on pourrait le forker aussi et faire une PR pour retirer Mist ?"*, then *"je parlais de forker le fork de
Flogas justement"*.

## Why this was the last blocker

After `REFACTOR-CSAR-WITHOUT-MIST` and `CHORE-DROP-HERCULES-SCRIPT`, Skynet was the only remaining
reason a VEAF mission had to inject MiST at all. It is what ticket 08 was waiting on.

| Script | Real calls | Status |
|---|---:|---|
| **`skynet-iads-compiled.lua`** | **42 across 31 lines** | **this lot** |
| `CSAR.lua` | 18 | done — `REFACTOR-CSAR-WITHOUT-MIST` |
| `Hercules_Cargo.lua` | 3 | removed entirely — `CHORE-DROP-HERCULES-SCRIPT` |
| `CTLD.lua` | 0 | already free of MiST in v2, on its own |

## The fork chain, and the measurement that changed the plan

`vendored.yaml` used to record that the Regroupement-Patrouille fork was *"the living branch"*, on the
strength of `ahead=4 behind=0` against walder/master. **That reading was wrong**: `ahead` measures
divergence, not activity, and those four commits all date from 2025. Measured 2026-08-30:

| Repository | Last commit | |
|---|---|---|
| `walder/Skynet-IADS` | December 2023 | dormant |
| `regroupement-patrouille/Skynet-IADS` (Flogas) | 2025-09-10 | dormant, 11 months |
| VEAF pull request #4 there | opened 2026-08-23 | 7 days, no comment, no review |

So VEAF forked the fork: `VEAF/Skynet-IADS`, transferred from `davidp57/Skynet-IADS` rather than
re-forked, which kept its six branches, its history and the open pull request — whose head moved from
`davidp57:` to `VEAF:` on its own.

Sending the work upstream stays worth doing **once it is checked in game**, to Flogas first. That is a
proposal, not a dependency.

## What replaced MiST, and why not the VEAF libraries

David's first instinct was *"en utilisant nos stubs VEAF"*. That made sense while the fork was
Flogas's. Once the fork became ours the trade-off inverted, and the lot took the other option:

- **(a) depend on VEAF** — about 40 lines. But Skynet would no longer start without VEAF, making our
  fork useless to anyone else and any upstream contribution impossible for good.
- **(b) a compatibility module inside Skynet** — 258 lines, no outside dependency. Chosen. The extra
  ~70 lines are arithmetic that will never change, and they buy not being locked in. It is also the
  repository's own idiom: it already has `skynet-iads-logger.lua`, `skynet-iads-supported-types.lua`.

`skynet-iads-utils.lua` reproduces the thirteen MiST functions from MiST 4.5.107. Ten are arithmetic.
Two needed care:

- **The scheduler** keeps MiST's guarantee that a repeating task which throws is logged and **keeps its
  place**. An IADS whose contact evaluation dies on one bad contact must not go deaf for the rest of
  the mission.
- **Listing units and groups** now asks DCS directly instead of reading a table MiST refreshed every
  two seconds. Skynet reads no field of those entries — it only takes the names and re-fetches with
  `Unit.getByName` / `Group.getByName`, filtering on `isActive`. So the visible behaviour is unchanged,
  and a group spawned at runtime is seen at once instead of up to two seconds later.

`mist.random` built a table of at least fifty candidates and drew from it ten times over; that changes
nothing about the distribution, so this calls `math.random`.

## Two defects found in the fork's build, fixed there

1. **The build produced an empty artefact under PowerShell 7.** `sc` was an alias of `Set-Content` in
   Windows PowerShell 5.1; PS7 removed it, so it resolves to `sc.exe` (Service Control) and the
   compiled file held nothing but its version banner.
2. **The build erases the README.** Its table-of-contents generator fails silently and writes back a
   README with 72 lines missing. Not fixed — reported in the pull request, since it is not ours.

## What the vendoring manifest had to say, and what it now says

The old `manual_steps` said to recompile and re-apply the `RP` label. It **did not say that the
artefact VEAF ships is run through stylua**, which the one in the fork is not. Following it literally
would have produced a 4000-line reformatting diff burying the real change — the same trap
`REFACTOR-CSAR-WITHOUT-MIST` had to fix on its own entry. Both the missing step and the new fork chain
are now recorded.

## What review caught

`coalition.getGroups` can hand back a group that has been **destroyed**. Asking such a group for its
units raises, and inside a `pairs` loop that error does not skip one group — it aborts the whole
listing. A single wreck on the map would have silently truncated `addEarlyWarningRadarsByPrefix` and
`addSAMSitesByPrefix`, with every site after it never joining the IADS and nothing in the log to say
so. MiST never met this because it answered from its own database, so the risk arrived *with* the
change that removed it.

Fixed in `VEAF/Skynet-IADS#2`: both listings go through one `forEachLiveGroup`, which skips a group
DCS no longer considers to exist, and `getUnits()` is guarded as well. Worth recording because it is
the failure mode this whole campaign keeps meeting — a replacement that is right on the happy path
and silent on the degraded one.

## Definition of done

- [x] No call to `mist.` remains in `skynet-iads-compiled.lua` — 42 replaced, 0 left, verified
      case-sensitively and excluding comments
- [x] The compatibility module carries no dependency on VEAF, so Skynet stays a drop-in script
- [x] The recompiled artefact matches the previous one **function for function**: 282 functions,
      140 table keys, 17 classes, no difference outside the intended change
- [x] All 20 sources and the artefact parse
- [x] `vendored.yaml` points at `VEAF/Skynet-IADS`, keeps both ancestors as `upstream-ref`, and its
      `manual_steps` names the stylua step; the 27 vendoring tests pass
- [x] The open pull request #4 (a live SAM site sent dark while its target is tracked) is merged into
      our `master`, so the artefact carries it
- [x] Checked in game 2026-08-31 — see below. The jammer was not exercised: it rides on the same
      scheduler as the rest, which was measured directly
- [x] `stylua --check` clean on the artefact


## Checked in game, 2026-08-31

David had no hardware to fly with, so nothing was flown. The mission was loaded and driven through
the DCS fiddle hook instead, which turned out to suit the subject better: both risky pieces are
behaviour over time, and time is easier to measure than to watch.

The mission is the fork's own Persian Gulf demo with two files changed: our artefact, and MiST
replaced by a table that raises on any access and names the symbol wanted. A missed call would
therefore appear in the log as `SKYNET TOUCHED MIST: mist.<symbol>` rather than as a nil-index crash
somewhere else.

| what | result |
|---|---|
| **The scheduler** | a repeating task ran **13 times in 26 s** at a 2 s interval, and a deferred one started exactly at its offset |
| **Cancellation** | `removeFunction` stopped a task dead; a second call answered `false` instead of cancelling something else |
| **HARM defence** | a site went dark and **came back** at its deadline: `finishHarmDefence` ran, cancelled its own task from inside its own callback, and cleared its state |
| **Discovery by prefix** | **13 SAM sites and 8 EW radars**, under their real names |
| **A site spawned mid-mission** | seen **immediately** (27 -> 28 groups), then added to the IADS (13 -> 14 sites) |
| **The MiST trap** | fired 31 times, **all 31 from `dcs-bridge.lua`** -- the observation tool, which probes `mist.majorVersion` in its `detectFrameworks()`. **None from Skynet.** |

Zero `error in scheduled function`, zero `attempt to` naming `SkynetIADSUtils`.

### Two false alarms, both mine

Worth writing down, because each looked exactly like a defect in the port:

1. **"The scheduler never runs."** A probe was installed over `SkynetIADS.evaluateContacts` and counted
   zero calls. It could not have counted any: `scheduleFunction` had captured the function reference
   at startup, so replacing the table entry afterwards changes nothing. Measured properly -- by giving
   the scheduler a task of its own -- it was exact.

2. **"A site stays dark forever."** The site really was still defending 157 s after a 126 s deadline,
   and its task really had vanished unexecuted. The cause was the *other* test: `addSAMSitesByPrefix`
   begins with `deativateSAMSites()`, which calls `cleanUp()` on every site, which calls
   `removeFunction(self.harmSilenceID)`. Running the prefix check while a HARM timer was armed
   cancelled it. Re-run in isolation, the site came back on time.

### One thing found upstream, not ours

`cleanUp()` cancels both HARM tasks but leaves `harmSilenceID` set. A site is then convinced it is
still evading a missile whose timer no longer exists, and `goDark` reads that field to decide whether
to bring point defences up. Present in the original, unchanged by the port -- worth mentioning when
the MiST work goes back to Flogas.

## What this unblocks

`DROP-MIST` ticket 08 — dropping the MiST injection entirely. No community script VEAF ships needs it
any more; what remains is the `veaf.mist.*` shim inside VEAF's own scripts.
