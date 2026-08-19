# FEAT-CONVOY-WAYPOINTS — a convoy follows an itinerary, and the player can hold it

Status: ⬜ ready

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

## Definition of done

- [ ] A convoy declares several points and walks them unaided
- [ ] A player can advance it, hold it to the next point, or stop it dead — three distinct entries
- [ ] `hold` and `stop` are visibly different on screen, not two words for one thing
- [ ] Route resumption **measured** in game, not assumed
- [ ] Documented, both languages
