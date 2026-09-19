# FEAT-SPOTTER-NETWORK — ground units see aircraft, and pass the word along

Status: ⏸ paused

> **Paused, not blocked on anyone here.** Its entry point into Skynet — the public wake-up added by
> `FEAT-LAST-LINE-OF-DEFENSE` in [`VEAF/Skynet-IADS`](https://github.com/VEAF/Skynet-IADS) — is not
> released yet, and there is nothing useful to start before it is. Nobody should pick this up.

Origin: David's idea, settled in principle with Flogas on 2026-09-19 alongside the last line of
defense. Deliberately **VEAF code, outside Skynet** — in `veafSkynetIadsHelper.lua` or in a module
of its own.

## The idea

Every DCS ground unit can notice a hostile aircraft nearby, at a distance that depends on what the
unit is — a JTAC sees further than a rifleman, who sees further than a tank — and slightly
randomised. Having seen it, the unit **passes the word** to whoever is within about 10 km, the range
of a field radio. Those in turn pass it on. Step by step, the alert spreads across the units that
are close enough to relay it.

Where it lands:

- **a unit that is a SAM site in a Skynet network** → Skynet wakes it as if an EWR had seen the
  aircraft, through the public entry point built by `FEAT-LAST-LINE-OF-DEFENSE` in the
  [Skynet repository](https://github.com/VEAF/Skynet-IADS). That entry point exists **for this
  feature**: without it, the helper would have to write into Skynet's internal state on every cycle;
- **any other unit, or a mission not using Skynet** → the unit is put on alert. Note the vocabulary:
  what wakes a DCS ground unit is the **alarm state** (`ALARM_STATE = RED`), not the rules of
  engagement; Skynet's `goLive` sets both. Confirm which is wanted when writing it.

It is a different animal from the last line of defense: that one is a single site hearing an
aircraft go over its own head, this one is a network of eyes and radios that carries information
across the map.

## What has to be designed before anything is written

**The cost is the whole problem.** Neighbour-to-neighbour propagation is quadratic: on a mission
carrying 500 ground units, one full pass is 250 000 distance measurements. Three guard-rails, to be
sized with numbers rather than assumed:

1. **Slow propagation.** One hop every N seconds rather than a pass per tick. It is cheaper *and*
   better in play: an alert that crawls across the map is worth more than one that teleports.
2. **Expiry.** An alert has a lifetime, or the whole map stays permanently awake after the first
   overflight of the mission.
3. **Spatial bucketing.** Units binned into cells so that nobody is ever compared against everybody.
   Positions change, so the bins have to be refreshed on a budget of their own.

Also to settle in design:

- the detection table per unit type, and how much randomness — drawn once per unit, as the last
  line of defense draws its radius once per site, or per attempt;
- whether a unit that is itself under Skynet control may act as a spotter, and whether a dark SAM
  site can see with its own eyes (it should — that is the point);
- how this interacts with the last line of defense, which already wakes a site on close proximity:
  the spotter network is the long-range half of the same idea, and the two must not fight over the
  same site;
- whether the alert carries the aircraft's position, or only "something is out there";
- what a player-visible effect would be, if any, so the feature is not invisible.

## Definition of done

- A design document with measured costs on a mission of realistic size, before implementation.
- Then: the feature, behind a setting, off or on by explicit decision at that point.
- Tests covering propagation, expiry, and the Skynet hand-off.
- Documentation in `doc/mission-maker/`, both languages.

## Dependency

Starts once `FEAT-LAST-LINE-OF-DEFENSE` has shipped in `VEAF/Skynet-IADS` **and** the new version is
vendored here by
[FIX-SKYNET-HELPER-AND-VENDORING](../FIX-SKYNET-HELPER-AND-VENDORING/tickets/03-vendor-the-new-skynet-version.md).
Both, in that order: the entry point has to exist in the artifact this repository ships before any
VEAF code can call it.
