# 01 — Wake a dark site when an aircraft enters its kill zone

Status: 🧑 waiting-human

> **Blocked: do not implement.** This ticket waits on David's conversation with **Flogas**
> and the historical IADS developers — see the [PRD](../PRD.md). No code, no branch, no PR
> before the decisions listed there are settled.

## Problem

A SAM under IADS control has its emission switched off, so it cannot detect anything itself. It is
woken only by an EWR that covers it *and* has the target on screen. An aircraft flying below the
EWRs' radar horizon — which is the normal way to attack a defended area — crosses the whole kill
zone without a single site reacting. The player reads this as "the SAMs are broken"; killing the
EWRs then makes them engage, which reads as the exact opposite of what should happen.

## What to build

In `SkynetIADS.evaluateContacts`, after the EWR pass and before `targetCycleUpdateEnd`, give every
usable, non-autonomous SAM site a chance to wake on proximity alone:

- enumerate hostile air units once per cycle (not per site), from the coalition opposite the IADS;
- for each site not already triggered this cycle, hand it the units it could reach through the
  existing `informOfContact` path, so the kill-zone test and the HARM rules stay the single
  authority on whether it lights up;
- the wake must survive `targetCycleUpdateEnd`, i.e. it must set `targetsInRange` the same way a
  radar-designated contact does.

Two settings, both on the IADS instance with a setter, both surfaced by `veafSkynet`: whether a
dark site may wake with no radar contact at all, and how far out that counts. **The second one is
not settled — see below.**

## The shape of the wake-up is a design decision, not an implementation detail

This ticket first said "the whole kill zone, on by default". That is wrong as written, and the
history says why: on a SA-10 it means lighting up at 75 km, which is the IADS switched off for
exactly the systems it exists to protect — which is what `a68dfd32` deliberately stopped doing
(see [ticket 02](02-actasew-override-is-wiped.md) for the 2022 record).

Three forms, to be settled with the historical IADS devs before any code:

| | What it does | What it costs |
|---|---|---|
| **A. Short passive watch** *(recommended)* | Each site gains a non-emitting sensor of fixed, settable radius (10–15 km) that wakes it with no radar involved | Models spotters and the regiment's field telephone, so it survives a purist's objection. Settles the reported case ("very close"). Leaves long-range systems quiet |
| **B. Wake on the whole kill zone** | The site lights up as soon as an intruder is inside its firing envelope | Matches what the player expects, and cancels the IADS for long-range systems |
| **C. Revert the 2022 decision** | Put `actAsEW(true)` back on the large systems | No new code. Large SAMs emit permanently, SEAD becomes trivial — precisely what was removed |

**A variant worth raising, because it is more elegant than A:** hang the passive watch on the
**point defences** rather than on every site. `initializePointDefences` already identifies them,
and a Shilka or a SA-19 is the short-range, optical sensor this is trying to model. They are dark
too today — `pointDefencesGoLive` is only reached from the `harmSilenceID` branch of `goDark`. Not
measured: whether point defences are present and close enough often enough to cover the reported
case on their own.

The on/off default is a second decision: **on** means every existing mission changes behaviour,
**off** means nobody finds it and the same report comes back in six months. Recommended: on, stated
plainly in the PR body.

## Cost to watch

The current cycle costs one `getDetectedTargets` per radar element. This adds one enumeration of
hostile air units per cycle, shared by every site. Do not put the enumeration inside the per-site
loop: on a mission with sixty batteries that is sixty sweeps every five seconds.

## Definition of done

- A site whose EWRs report nothing goes live when a hostile aircraft enters the agreed wake-up
  radius.
- It goes dark again once the aircraft leaves, on the normal cycle, with no special case.
- Tests, both directions: wakes on proximity; does **not** wake for an aircraft outside the radius,
  for a friendly aircraft, or when the setting is off.
- `poetry run test-lua` green.
