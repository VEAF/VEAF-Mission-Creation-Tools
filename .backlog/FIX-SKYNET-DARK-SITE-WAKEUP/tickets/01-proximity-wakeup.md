# 01 — Wake a dark site when an aircraft enters its kill zone

Status: ⬜ ready

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

Two settings, both on the IADS instance with a setter, both surfaced by `veafSkynet`:

| setting | default | meaning |
|---|---|---|
| proximity wake-up | **on** | whether a dark site may wake with no radar contact at all |
| proximity range percent | 100 | share of the site's kill zone that counts as "overhead" |

The default is on: the mission maker who wants a purist IADS switches it off, and everyone else
gets the behaviour they already expected. State that choice in the PR body — it changes existing
missions.

## Cost to watch

The current cycle costs one `getDetectedTargets` per radar element. This adds one enumeration of
hostile air units per cycle, shared by every site. Do not put the enumeration inside the per-site
loop: on a mission with sixty batteries that is sixty sweeps every five seconds.

## Definition of done

- A site whose EWRs report nothing goes live when a hostile aircraft enters its kill zone.
- It goes dark again once the aircraft leaves, on the normal cycle, with no special case.
- Tests, both directions: wakes on proximity; does **not** wake for an aircraft outside the kill
  zone, for a friendly aircraft, or when the setting is off.
- `poetry run test-lua` green.
