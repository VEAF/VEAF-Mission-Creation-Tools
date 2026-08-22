# FIX-SKYNET-SITE-GOES-DARK-BEFORE-FIRING — a SAM site locks, raises, then stands down without firing

Status: ⬜ ready — needs one 5-minute control test before any code is written

Observed in game on 2026-08-22, in `verify-mission-c`, on the SA-6 (`Kub 2P25 ln` × 4 +
`Kub 1S91 str` × 2):

> *"je me fais locker mais les lanceurs alternent entre une phase active (ils lèvent leurs missiles et
> tournent vers moi) et passive (ils se remettent en mode route, les missiles à plat droit devant) sans
> tirer (5 fois de suite)"*

## Why this is almost certainly ours, not the DCS bug

The session had been chasing a DCS-side theory: ground SAMs not engaging in 2.9.28. Three SA-15 on a
bare map with no scripts locked and fired, which narrowed it to "maybe multi-unit sites are affected".
This observation **rules that reading out**, and it is worth stating plainly because it was the working
hypothesis an hour earlier:

A site that acquires, slews its launchers and elevates its missiles is not a site DCS is preventing from
working. It is a site that is being **switched off** between acquisition and launch. Five clean cycles is
a control loop, not a broken engagement.

Skynet drives exactly that loop. `SkynetIADSAbstractRadarElement:goLive()` / `goDark()`
(`skynet-iads-compiled.lua:2794` / `:2820`) are called from `setActAsEW`, `resetAutonomousState`,
`goAutonomous`, `goDarkIfOutOfAmmo`, and from the HARM defence — which stands a site down on a
*probability* per type (`harm_detection_chance`, 30–90 across the database). Any of those firing
mid-engagement produces what was seen.

`veafSkynet.deactivateNetwork` also calls `goDark`/`goAutonomous`, but only on an explicit network
deactivation, so it is not the loop.

## The control test, before touching anything

A **complete SA-6** on a bare map, no scripts at all, alarm red, ROE fire-at-will — the same shape as
the SA-15 test that cleared DCS's name. Five minutes.

| Result | Meaning |
|---|---|
| **It fires** | Skynet is standing the site down mid-engagement. Ours to fix, and the HARM defence is the first suspect |
| **Same cycle** | DCS after all, and specific to sites whose tracking radar is a separate vehicle — which would also explain Tripack's report of silent zone SAMs |

Do not skip this. The session already lost a check to a criterion written from an untested assumption
about DCS behaviour, and this PRD is one assumption away from the same mistake.

## If it is Skynet

Order of suspicion, cheapest first:

- **HARM defence.** It is probabilistic and per-type, so it produces intermittent stand-downs that look
  exactly like this. Check whether it triggers with no anti-radiation weapon anywhere in the mission
- **Engagement-zone hysteresis** — a target near the boundary makes the site cycle live/dark. Would show
  as cycles correlated with range rather than with time
- **Autonomous state churn** — losing and regaining the link to the command centre or EWR calls
  `resetAutonomousState`, which goes dark unconditionally

## Definition of done

- [ ] The control test run and its result recorded here
- [ ] If ours: the stand-down reason identified from Skynet's own state, not guessed
- [ ] A SAM site that has acquired a target is not switched off before it can launch
- [ ] Recorded whether this is what Tripack saw (silent zone SAMs on 6.15.2), which is still unexplained
