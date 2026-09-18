# FIX-SKYNET-DARK-SITE-WAKEUP — a SAM under IADS control cannot notice the aircraft overhead

Status: 🧑 waiting-human

> **DO NOT IMPLEMENT ANY OF THIS YET.** The lot is blocked on a conversation David is to have with
> **Flogas** and the historical IADS developers. Nothing here — not the wake-up, not the `actAsEW`
> reset, not the documentation that describes both — may be coded, branched or opened as a PR before
> that conversation has settled the four decisions listed below. This is not caution about the code:
> the behaviour under discussion is a deliberate VEAF trade-off from 2022 (see below), and changing
> it without its authors would be deciding in their place. An agent picking this lot up stops here
> and asks David where the conversation stands.

Origin: The Reaper, 2026-09-17, on a mission built with veaf-tools:

> *"J'ai configuré Skynet sur une mission avec les outils VEAF. J'ai un problème, quand il y a des
> EWR rouge à portée, les SAM ne s'allument pas même si on est à portée voire très proche. Quand il
> n'y a plus d'EWR rouge, les SAM deviennent autonomes et actifs."*

Same mission as the CTLD report of the same evening
(`VEAF_OpenTraining_Caucasus_v6_20260917_debug_skynet_1705.miz`), same `dcs.log`.

## The mechanism, read in the code

`skynet-iads-compiled.lua` is the VEAF fork (`3.4.0RP-VEAF`), so every line below is ours to change.

1. A SAM covered by one live EWR is pulled under network control: `setToCorrectAutonomousState` →
   `resetAutonomousState` → `goDark()`, which calls `enableEmission(false)`. **The site is now
   blind**: it cannot observe its own airspace.
2. The only path back to `goLive` is `SkynetIADS.evaluateContacts`: an EWR **that covers this site**
   must return a contact from `getDetectedTargets`, and that contact must pass the site's
   `isTargetInRange` (kill zone).
3. When step 2's first half fails, the second half is never evaluated. Proximity to the site is not
   an input anywhere in the cycle — the only sensor that could measure it is the one Skynet just
   switched off.
4. Lose every covering EWR and `goAutonomous()` hands the site back to the DCS AI, which lights up
   and engages. Hence the inversion the reporter describes: killing the EWRs makes the SAMs *more*
   dangerous.

Nothing in Skynet says "an aircraft is 5 NM out, light up regardless". That is the gap.

## Measured on the reporter's log (session of 19:12, 24 minutes of 5 s cycles)

| measure | value |
|---|---|
| SAM status lines `ACTIVE:false / AUTONOMOUS:false` | 7 933 |
| SAM status lines `ACTIVE:true / AUTONOMOUS:false` | **0** |
| SAM status lines `ACTIVE:true / AUTONOMOUS:true` | 30 |
| `GOING LIVE` after coverage was built | only the 2 autonomous, dynamically spawned sites |

Every network SAM went live once at startup — before coverage existed — then `GOING DARK`, then
never again. The only sites that ever fired up afterwards were the two that had no EWR parent.

**Stated honestly**: the closest contact to any network EWR in that log is 51.85 NM, so the
reporter's own "very close" pass is *not* in this log. The mechanism is proven from the code; his
specific pass is not reproduced here.

## Where the fix belongs — recommendation

In the **Skynet fork**, not in `veafSkynetIadsHelper.lua`. The deciding constraint is measurable:
`SkynetIADSSamSite:targetCycleUpdateEnd` sends dark every site whose `targetsInRange` is false at
the end of a cycle. A `goLive()` called from the outside by the VEAF helper is therefore undone
within 5 seconds unless the helper also writes `samSite.targetsInRange = true` — reaching into
Skynet's internal state on every cycle. Inside `evaluateContacts`, the same behaviour is a few
lines at the point that already owns the decision.

## This is a VEAF trade-off from 2022, not a Skynet defect

Until `a68dfd32` (2022-04-05, David Pierron, *"IADS: removed defaulting to EWR for SAM sites"*) the
helper set `actAsEW(**true**)` on SA-10, SA-6, Patriot and Hawk: the large systems watched
permanently and saw for themselves, which is exactly the behaviour the reporter expects. It was
removed on purpose, finished by `7ead5793` (2022-05-20), and the list was carried forward by Flogas
in `3002aaad` (2023) and `d4e1b66c` (2024).

Frame the conversation accordingly: the question is not why Skynet is broken, it is whether a
four-year-old trade-off still holds and what replaces it. Ticket 02 carries the record.

## Decisions to settle with the historical IADS devs, before any code

| # | Decision | Recommendation |
|---|---|---|
| 1 | Fork or helper | The fork — `targetCycleUpdateEnd` undoes any outside `goLive` within one cycle |
| 2 | Wake-up shape: short passive watch / whole kill zone / revert 2022 | Short passive watch, settable radius; explore hanging it on the point defences ([ticket 01](tickets/01-proximity-wakeup.md)) |
| 3 | Default on or off | On — off means nobody finds it and the same report returns in six months. It changes existing missions, say so in the PR |
| 4 | The five-NATO-name reset | Keep the list, honour an explicit watch request ([ticket 02](tickets/02-actasew-override-is-wiped.md)) |

A fifth, cheap: ask them whether they have already seen the blind A-50s of
[INVESTIGATE-SKYNET-AWACS-BLIND](../INVESTIGATE-SKYNET-AWACS-BLIND/PRD.md). One sentence from them
may close that lot.

## Tickets

| # | Ticket |
|---|---|
| 01 | [Wake a dark site when an aircraft enters its kill zone](tickets/01-proximity-wakeup.md) |
| 02 | [An explicit EW-watch request is wiped by the next group joining](tickets/02-actasew-override-is-wiped.md) |
| 03 | [Document what a network SAM does and does not see](tickets/03-document-the-dark-site-contract.md) |

## Definition of done

- A dark network site goes live when a hostile aircraft enters its kill zone, with no radar contact
  required, and stays live while the aircraft is there.
- The behaviour is switchable and its range is settable, because it is a deliberate departure from
  the IADS principle and not every mission wants it.
- Lua tests cover both directions: a site wakes on proximity, and a site does **not** wake for an
  aircraft outside its kill zone or of the wrong coalition.
- `doc/mission-maker/scripts/veafSkynetIadsHelper.md` and its `.en.md` twin say plainly that a
  network SAM is blind, and describe the new setting.
