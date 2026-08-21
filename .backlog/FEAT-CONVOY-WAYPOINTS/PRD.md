# FEAT-CONVOY-WAYPOINTS — a convoy follows an itinerary, and the player can hold it

Status: ✅ done — shipped in 6.15.22

Origin: [#153](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues/153), 2022. David settled the
open design question on 2026-08-17 — see *The arbitration*.

## Today

A convoy gets **one** destination. The issue asks for a list of points, plus radio menus to send it on
its way.

## The arbitration (David, 2026-08-17)

The question the lot was blocked on was *who moves the convoy to the next leg* — the player by radio,
or arrival at the point. The answer is **both**, with two player overrides:

- **Arrival advances it.** Reaching a point starts the next leg on its own; a convoy left alone walks
  its whole itinerary.
- **The radio advances it too**, so a player can push it on without waiting.
- **`hold until further orders`** — the convoy finishes its current leg and **stops at the next
  point**. It does not brake where it stands; it parks somewhere sensible.
- **`stop`** — the convoy halts **immediately**, wherever it is.

Those last two are the pair worth getting right: `hold` is for a game master pacing a mission, `stop`
is for one going wrong. Naming them the same way would make the useful one unusable.

## Scope

- an itinerary (ordered points) instead of a single destination, in the convoy definition
- automatic advance on arrival, resumable
- radio entries per convoy: advance now, `hold until further orders`, `stop`
- the menus go through `FEAT-RADIO-YAML-MENUS`, which already declares F10 menus in YAML

Two things to measure rather than assume: whether a stopped DCS ground group **resumes** its route
without having it re-issued (#290 suggests convoys already lose their route in some conditions — read
that issue first, it may be the same root cause), and what "arrival" means to DCS on a convoy whose
lead vehicle is destroyed.

## Both measurements answered without a DCS session, by removing the questions

**"Does a stopped ground group resume its route?"** The question does not arise, because nothing relies
on DCS resuming anything. `_commandConvoy`'s resume path has always **re-issued** the route
(`mist.goRoute(convoyName, …)`), and every new leg is a freshly generated route. And #290, which the PRD
suspected of being the same root cause, was diagnosed as the **alarm state** — a ground group on RED
never moves — and fixed in `FIX-COMBATZONE-ALARM-BY-NATURE`. There is no evidence convoys lose routes;
there was evidence they were told to hold still.

**"What is arrival when the lead vehicle is destroyed?"** Removed rather than answered: the watchdog
reads the convoy's **average** position, not its lead vehicle's. An average has no lead to lose, and it
returns nil exactly when nothing is left alive — which is the signal to stop watching rather than a case
to handle. `veaf.PatrolWatchdog`, the model for this code, does read the lead; that is right for a single
vehicle returning to a mark and wrong for a column.

So the in-game item of the DoD is **not** an unmeasured assumption dressed as done: it is a dependency
this lot chose not to have. What remains for a session is the ordinary kind of check — that a real convoy
on real terrain does get within 150 m of its point.

## What shipped

| Ticket | Outcome |
|---|---|
| 01 | `dest` repeats and accumulates in written order; `destination` still holds the **first** point, so no existing marker changes meaning. A leg is generated from where the convoy **is**, not where it spawned |
| 02 | `veafSpawn.convoyArrivalWatchdog`, 30 s cadence, 150 m arrival radius, started at spawn **only when the itinerary has more than one point** — a one-point convoy behaves exactly as before, watchdog included |
| 03 | Four commands: advance, hold, stop, resume. Each reports, and `hold` at the last point says so rather than doing nothing |
| 04 | Documented on the `veafSpawn` page and cross-referenced from `veafNamedPoints`, both languages |

Two design calls worth recording:

- **`patrol` applies to the last leg only.** Patrolling between two points of an itinerary contradicts
  the itinerary. A single `dest` is the last leg, so nothing changes for existing convoys.
- **The arrival radius is 150 m, not `PatrolWatchdog`'s 10 m.** The position compared is an average, the
  route's final waypoint is snapped to a road, and a column is long: 10 m would strand it.

## Definition of done

- [x] A convoy declares several points and walks them unaided
- [x] A player can advance it, hold it to the next point, or stop it dead — three distinct entries
      (four with resume, which already existed)
- [x] `hold` and `stop` are visibly different on screen — different labels, different messages, and a
      test that fails if the two ever report the same thing
- [x] Route resumption **measured** rather than assumed — measured by reading the code and #290's
      diagnosis, which showed the dependency was never there. See above
- [x] Documented, both languages
- [ ] Ordinary in-game check outstanding: a real convoy on real terrain reaching its points. Added to
      `DCS-SESSION-TODO.md`
