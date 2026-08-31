# FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING — a SAM site is switched off every other cycle

Status: 🧑 waiting-human — **fix shipped**, awaiting one in-game observation (no longer waiting on anyone else)

## Where it stands

**The fix is shipped.** Route 1 was taken, but the destination changed on the way: rather than waiting
for the Regroupement-Patrouille review, `VEAF/Skynet-IADS` became the reference fork (Flogas agreed
2026-08-31) and the fix was merged there — commit `3a94937`, carried into VEAF by
[#846](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pull/846).

Verified in the artefact VEAF actually embeds: the comment explaining the fix is present in
`src/scripts/community/skynet-iads-compiled.lua`, and the faulty `isActive() == false` filter is gone.

What this means for the plan below:

- **The upstream pull request is closed, unmerged.** It sat eight days without a comment, and nothing
  goes back upstream any more (David, 2026-08-31). `message-to-flogas.md` was deleted with it: it
  announced a pull request that no longer needs announcing.
- **Option 2 is moot.** The local replacement existed as a fallback for a stalling PR; there is no
  stalling PR, and the fix is in the artefact.
- **Nothing here waits on anyone else.** The one remaining box is an observation in game.

Observed in game on 2026-08-22 in `verify-mission-c`, on the SA-6 (`Kub 1S91 str` × 1 +
`Kub 2P25 ln` × 2):

> *"je me fais locker mais les lanceurs alternent entre une phase active (ils lèvent leurs missiles et
> tournent vers moi) et passive (ils se remettent en mode route, les missiles à plat droit devant) sans
> tirer (5 fois de suite)"*

## It is not DCS, and that was established rather than assumed

The session spent two days on a DCS-side theory: ground SAMs not engaging in 2.9.28. Two control tests
on a bare map with **no scripts at all** closed it:

| Control | Result |
|---|---|
| Three SA-15 (Tor 9A331), alarm red, ROE fire-at-will | locked and **fired** |
| A complete SA-6 — 2 × `1S91 str` + 4 × `2P25 ln` **in one group** — alarm red, ROE fire-at-will | **fired** |

The SA-6 is the multi-unit family, the one whose launchers depend on a separate tracking radar. It
engages normally without scripts. So a site that stands down mid-engagement *with* Skynet running is
being switched off by Skynet.

(The SA-6 control test failed on its first attempt — locked, launchers inert — because its six vehicles
were in six one-unit groups. In DCS a SAM site **is** a group: the group's controller hands a target
from the radar to a launcher. That failure mode is indistinguishable from "DCS is broken" unless you
look at the group structure, and it is worth asking Sharko how his three SAMs were placed.)

## The cause, traced in `skynet-iads-compiled.lua`

`SkynetIADS.evaluateContacts` runs on a timer and, per cycle:

1. `samSite:targetCycleUpdateStart()` sets `self.targetsInRange = false` — **unconditionally**, every
   cycle (`:3755`)
2. for each EW radar with contacts, the sites under its coverage are collected — but **only those that
   are not already active**:
   ```lua
   if samSiteUnterCoverage:isActive() == false then
     samSitesToTrigger[samSiteUnterCoverage:getDCSName()] = samSiteUnterCoverage
   end
   ```
   (`:1616`)
3. only those collected sites get `informOfContact`, and that is the **only** place in the whole file
   that sets `targetsInRange = true` (`:3779` — verified, one occurrence)
4. `samSite:targetCycleUpdateEnd()` calls `goDark()` when `targetsInRange == false`, the site is not
   acting as EW, is not autonomous, and its autonomous behaviour is `AUTONOMOUS_STATE_DCS_AI` — which
   is the **default** for a SAM site (`:3759`, default at `:2285`)

Put together, for a site under EW coverage:

| Cycle | State at start | Informed? | `targetsInRange` | End of cycle |
|---|---|---|---|---|
| N | inactive | yes — it is inactive | true | stays live |
| N+1 | **active** | **no — filtered out at `:1616`** | false | **goes dark** |
| N+2 | inactive | yes | true | goes live |

A site alternates live/dark on every evaluation. Note step 2's own consequence: a site that detects its
target *by itself* has its contacts merged into the IADS (`:1590`) but is **never** told about them, so
self-detection cannot keep it alive.

**Correction, from the same session.** An earlier draft of this PRD said the site "never keeps its radar
long enough to complete a launch". That is too strong and the mission disproved it: after the IADS combat
zone was activated, the SA-6 **shot the observer down**. So the effect is a *degraded, intermittent*
engagement — roughly half the time with the radar off — not an impossibility. Five wasted cycles followed
by a kill is exactly what a 5-seconds-on / 5-seconds-off site would produce against an aircraft that
stays in range. That matters for the fix's justification: this is a serious degradation of every Skynet
SAM, not a total failure, which is also why it could go unnoticed upstream.

## The observation that confirms or kills this

`contactUpdateInterval = 5` seconds (`:1303`), and `evaluateContacts` is scheduled at that interval
(`:1825`). So this explanation predicts the state changes are **~5 seconds apart**, regardless of what
the aircraft does.

**Measured 2026-08-22: "toutes les 10 secondes".** A full period — raise, retract, raise again — spans
**two** evaluation cycles, so 5 s live plus 5 s dark is exactly 10 s between two identical states. The
prediction holds, and it was made from the code before the measurement rather than fitted to it.

One residual ambiguity worth closing when convenient: 10 s is the period if it was measured between two
*raises*; if it was measured between a raise and the next retraction, the interval would be 10 s where
this analysis predicts 5, and the interval would then be `contactUpdateInterval` × 2 for some other
reason. Either way the mechanism is the same shape; only the constant would move.

## Reservation, stated rather than buried

A defect this central in a mature, widely used script is suspicious: it would mean every Skynet SAM
cycles every 5 seconds for everyone. Two things could soften it in practice — `goDark()` does not always
kill a radar that is actively tracking (our own code notes this), and `getUsableSAMSites` may not return
every site. But the launchers were seen physically retracting, so the effect is real here, and the code
path above has no other exit.

## Route, once confirmed

Skynet is `vendoring: compiled` from the Regroupement-Patrouille fork (`vendored.yaml`), so the file is
**not** ours to patch in place — a rebuild would erase it. Options, in order of preference:

1. **Upstream to the RP fork**, since that is where we take it from and this is a plain defect, not a
   VEAF policy
2. **Replace the two methods** from `veafSkynet` after load, the way `veaf.csar_initialize_replacement`
   handles CSAR — cheap, survives a recompile, and keeps VEAF missions working meanwhile
3. `setUpdateInterval` to something long enough that a launch completes between cycles — a mitigation,
   not a fix, and it degrades the IADS everywhere else

## What this also reopens

**Tripack's** report of silent SAMs inside combat zones on 6.15.2 was filed under "DCS is broken for
everyone". It never was, and this is a candidate explanation for it: same symptom, same mechanism, and it
predates every alarm-state change we have made since.

## Definition of done

- [x] The timing prediction checked in game — **10 s between identical states**, i.e. two 5 s
      evaluation cycles, as predicted from the code
- [x] If confirmed: fixed by route 1 or 2, never by editing the compiled file in place — route 1,
      merged in `VEAF/Skynet-IADS` and recompiled into the artefact, never edited in place
- [ ] A SAM site that has acquired a target keeps its radar long enough to launch
- [ ] Checked against Tripack's case, and his report closed or kept open on evidence
