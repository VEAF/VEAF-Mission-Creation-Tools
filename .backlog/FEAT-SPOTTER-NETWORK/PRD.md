# FEAT-SPOTTER-NETWORK — ground units see aircraft, and pass the word along

Status: ⬜ ready (design first, no code before the design is costed)

Origin: David's idea, settled in principle with Flogas on 2026-09-19 alongside
[FIX-SKYNET-DARK-SITE-WAKEUP](../FIX-SKYNET-DARK-SITE-WAKEUP/PRD.md). Deliberately **VEAF code,
outside Skynet** — in `veafSkynetIadsHelper.lua` or in a module of its own.

## The idea

Every DCS ground unit can notice a hostile aircraft nearby, at a distance that depends on what the
unit is — a JTAC sees further than a rifleman, who sees further than a tank — and slightly
randomised. Having seen it, the unit **passes the word** to whoever is within about 10 km, the range
of a field radio. Those in turn pass it on. Step by step, the alert spreads across the units that
are close enough to relay it.

Where it lands:

- **a unit that is a SAM site in a Skynet network** → Skynet wakes it as if an EWR had seen the
  aircraft, through the public entry point built by
  [ticket 01](../FIX-SKYNET-DARK-SITE-WAKEUP/tickets/01-proximity-wakeup.md);
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

- the detection table per unit type, and how much randomness (drawn once per unit, as in ticket 01,
  or per attempt);
- whether a unit that is itself under Skynet control may act as a spotter, and whether a dark SAM
  site can see with its own eyes (it should — that is the point);
- whether the alert carries the aircraft's position, or only "something is out there";
- what a player-visible effect would be, if any, so the feature is not invisible.

## Definition of done

- A design document with measured costs on a mission of realistic size, before implementation.
- Then: the feature, behind a setting, off or on by explicit decision at that point.
- Tests covering propagation, expiry, and the Skynet hand-off.
- Documentation in `doc/mission-maker/`, both languages.

## Dependency

Starts after [ticket 01](../FIX-SKYNET-DARK-SITE-WAKEUP/tickets/01-proximity-wakeup.md) has shipped:
the public entry point it exposes is how this feature wakes a SAM site without reaching into
Skynet's internal state.
