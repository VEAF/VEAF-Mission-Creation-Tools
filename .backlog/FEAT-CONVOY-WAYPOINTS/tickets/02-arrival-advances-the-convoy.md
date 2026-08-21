# 02 — Arrival advances the convoy

Status: ✅ done
Type: feat

David's arbitration: **both** arrival and the radio advance a convoy. This ticket is the arrival half —
a convoy left alone walks its whole itinerary.

## The mechanism already exists, for patrols

`veaf.PatrolWatchdog` (`veaf.lua:1875`) reschedules itself every 30 s, compares the **lead vehicle's**
position against a point, and re-issues the route with `mist.goRoute` when it is within range. It is
specialised for patrols (it watches the *start* point, to loop) but the shape is exactly what an
arrival check needs, and it is proven in play.

## The two things the PRD said to measure rather than assume

**Does a stopped ground group resume its route?** Answered by reading the code, no session needed: the
question does not arise, because nothing here relies on DCS resuming anything. `_commandConvoy`'s
resume path already **re-issues** the route (`mist.goRoute(convoyName, …)`), and #290 — which the PRD
suspected of being the same root cause — was diagnosed as the **alarm state** (a group on RED never
moves) and fixed in `FIX-COMBATZONE-ALARM-BY-NATURE`. There is no evidence convoys lose routes.

**What is "arrival" when the lead vehicle is dead?** `Group:getUnits()` returns the *living* units, so
`getUnits()[1]` is simply the next surviving vehicle and the check keeps working with a new reference.
A convoy wiped out entirely leaves `Group.getByName` nil, which must stop the watchdog rather than
reschedule it forever.

## Definition of done

- [x] A convoy reaching a point starts the next leg unaided
- [x] The last point ends the itinerary: no further legs, no watchdog left running
- [x] A destroyed convoy stops its watchdog; a convoy that lost its lead vehicle keeps advancing
- [x] Lua tests over the advance decision, with time and positions injected rather than waited for
