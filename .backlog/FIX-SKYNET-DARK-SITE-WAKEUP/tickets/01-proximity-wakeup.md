# 01 — Last line of defense: a dark site wakes on close proximity

Status: ⬜ ready

## Decision

Settled with Flogas and the historical IADS devs, 2026-09-19: **option A, the short passive watch.**

A site held dark by the network keeps a short, *virtual* detection radius — Skynet's own, no DCS
radar involved. A hostile aircraft inside that radius makes it go live, whether or not any EWR ever
saw the aircraft. Radius 10–15 km, randomised.

This is a deliberate departure from the IADS principle, made because the principle has an angle
blind spot: coverage says an EWR is *near the battery*, never that the EWR is *feeding* it, so a
battery stays dark while an aircraft crosses it at low level. Options B (wake on the whole kill
zone) and C (revert the 2022 `actAsEW` defaults) were considered and rejected — B cancels the IADS
for long-range systems, C makes SEAD trivial.

## Problem this closes

A SAM under IADS control has its emission switched off, so it cannot detect anything itself. It is
woken only by an EWR that covers it *and* has the target on screen. An aircraft flying below the
EWRs' radar horizon — the normal way to attack a defended area — crosses the whole kill zone without
a single site reacting. Reported by The Reaper on 2026-09-17; measured on his log as 7 933 SAM status
lines dark under network control and zero ever lit over 24 minutes.

## What to build

In `SkynetIADS.evaluateContacts`, after the EWR pass and before `targetCycleUpdateEnd`, every usable
SAM site that no EWR has already triggered this cycle gets a proximity check.

**The radius is drawn once, per site, when the site is built** — not per cycle. Drawn per cycle, an
aircraft loitering near the mean value makes the site blink every 5 s. Drawn once, the pilot still
cannot learn the exact distance, and the site behaves consistently.

**The proximity wake-up ignores the kill-zone test.** `informOfContact` requires the target to be
inside the site's firing envelope; with a 10–15 km radius a Shilka (useful range ~2.5 km) would
*never* wake by that path, and short-range pieces are precisely the last line of defense this
exists for. A site lights up because it hears the aircraft go over, not because it can hit it.
Accepted consequence: a short-range piece may go live with nothing it can engage — which is what a
real crew going to alert does.

**Expose the wake-up as a public entry point of the fork**, used by this feature itself — something
like `iads:reportContact(dcsUnit, site)`. A Skynet contact builds from any DCS unit
(`SkynetIADSContact:create({ object = unit }, source)`), so this is cheap. It exists because the
spotter network ([FEAT-SPOTTER-NETWORK](../../FEAT-SPOTTER-NETWORK/PRD.md)) has to wake a site "as
if an EWR had seen the aircraft" from **outside** Skynet, and the alternative is the helper writing
into Skynet's internal state on every cycle.

Two settings on the IADS instance, with setters, surfaced by `veafSkynet`: whether the last line of
defense is active at all, and the radius bounds. Default **on** — off means nobody finds it and the
same report returns in six months. It changes existing missions; say so in the PR body.

## Cost to watch

Enumerate hostile air units **once per cycle**, shared by every site — never inside the per-site
loop. On a mission carrying sixty batteries that would be sixty sweeps every five seconds.

## Definition of done

- A site whose EWRs report nothing goes live when a hostile aircraft enters its drawn radius, and
  goes dark again once it leaves, on the normal cycle, with no special case.
- The radius is stable for a given site across the mission.
- The public entry point exists and this feature is its first caller.
- Tests, both directions: wakes on proximity; does **not** wake for an aircraft outside the radius,
  for a friendly aircraft, or when the setting is off. Plus: the drawn radius does not change
  between two cycles.
- `poetry run test-lua` green.
