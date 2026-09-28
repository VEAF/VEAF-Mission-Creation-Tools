# FEAT-CONVOY-WAYPOINTS — a convoy follows an itinerary, and the player can hold it

Status: ✅ done — shipped in 6.15.22 · archived 2026-09-28

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

---

## Tickets, in full

## 01 — An itinerary instead of one destination

Status: ✅ done
Type: feat

### What exists

`_spawn convoy, dest X` stores one string in `options.destination`, and
`veaf.generateVehiclesRoute(spawnSpot, destination, …)` turns it into a 3- or 4-waypoint route:
departure, on-road entry, the destination, and a final off-road hop when `onroad` is set. The convoy
is then registered as `veafSpawn.spawnedConvoys[name] = { route = route, name = name }`.

### What this ticket does

Accept `dest` **more than once** and walk the points in the order written:

```
_spawn convoy, dest KOBULETI, dest BATUMI, dest POTI
```

`veaf.parseMarkerText` iterates keyphrases with `ipairs` — order is load-bearing there by design and
its comment says so — so accumulating in an `apply` is enough. One `dest` yields a one-point
itinerary, which is today's behaviour: **no existing marker changes meaning**.

The convoy record grows the state the later tickets need: the itinerary, which leg is current, and the
route parameters (`speed`, `onRoad`, `patrol`) so a leg can be regenerated rather than remembered.

### Definition of done

- [x] `dest` repeated accumulates in order; a single `dest` behaves exactly as before
- [x] A leg's route is generated from the convoy's current position, not from the original spawn point
- [x] Lua tests: one point, several points, a point name that does not resolve, and the ordering
- [x] `veafSpawn.spawnedConvoys` carries the itinerary and the current leg

---

## 02 — Arrival advances the convoy

Status: ✅ done
Type: feat

David's arbitration: **both** arrival and the radio advance a convoy. This ticket is the arrival half —
a convoy left alone walks its whole itinerary.

### The mechanism already exists, for patrols

`veaf.PatrolWatchdog` (`veaf.lua:1875`) reschedules itself every 30 s, compares the **lead vehicle's**
position against a point, and re-issues the route with `mist.goRoute` when it is within range. It is
specialised for patrols (it watches the *start* point, to loop) but the shape is exactly what an
arrival check needs, and it is proven in play.

### The two things the PRD said to measure rather than assume

**Does a stopped ground group resume its route?** Answered by reading the code, no session needed: the
question does not arise, because nothing here relies on DCS resuming anything. `_commandConvoy`'s
resume path already **re-issues** the route (`mist.goRoute(convoyName, …)`), and #290 — which the PRD
suspected of being the same root cause — was diagnosed as the **alarm state** (a group on RED never
moves) and fixed in `FIX-COMBATZONE-ALARM-BY-NATURE`. There is no evidence convoys lose routes.

**What is "arrival" when the lead vehicle is dead?** `Group:getUnits()` returns the *living* units, so
`getUnits()[1]` is simply the next surviving vehicle and the check keeps working with a new reference.
A convoy wiped out entirely leaves `Group.getByName` nil, which must stop the watchdog rather than
reschedule it forever.

### Definition of done

- [x] A convoy reaching a point starts the next leg unaided
- [x] The last point ends the itinerary: no further legs, no watchdog left running
- [x] A destroyed convoy stops its watchdog; a convoy that lost its lead vehicle keeps advancing
- [x] Lua tests over the advance decision, with time and positions injected rather than waited for

---

## 03 — Advance, hold and stop, as three visibly different things

Status: ✅ done
Type: feat

David's arbitration, and the part he was explicit about: `hold until further orders` **finishes the
current leg and parks at the next point**; `stop` **halts where it stands**. *"`hold` paces a mission,
`stop` rescues one going wrong; naming them alike would make the useful one unusable."*

### What exists

The F10 menu already offers two convoy commands (`veafSpawnCore.lua:947-949`):

| Menu | Function | Effect |
|---|---|---|
| `menu.spawn.convoy_stop` | `stopClosestConvoy` | pushes a `Hold` task — halts where it stands |
| `menu.spawn.convoy_move` | `moveClosestConvoy` | re-issues the route — resumes after a stop |

So `stop` and *resume* exist. What is missing is **advance now** and **hold at next point**, and the
wording that keeps `hold` and `stop` apart on screen.

### What this ticket does

- **advance now** — start the next leg without waiting for arrival
- **hold until further orders** — let the current leg finish, then stay put at that point
- keep **stop** (immediate) and **resume**, renamed so no two entries read alike
- every command reports what it did to the player, naming the point where relevant, so the two are
  distinguishable from the cockpit and not only in the code

### Definition of done

- [x] Four commands, each with its own message: advance, hold, stop, resume
- [x] `hold` at the last point of an itinerary says so rather than silently doing nothing
- [x] `stop` then `resume` still works, unchanged
- [x] i18n keys in both languages, menu labels included
- [x] Lua tests over each transition, including the ones that must be refused

---

## 04 — Document the itinerary and the two brakes

Status: ✅ done
Type: doc

The pair `hold` / `stop` is the whole point of the arbitration, so the doc has to make the difference
readable by someone who is *not* going to read the code.

### Definition of done

- [x] The `dest` syntax, repeated, with a worked example
- [x] A table contrasting advance / hold / stop / resume: what each does, and when to reach for it
- [x] Both languages, `poetry run docs-check` green
- [x] The marker-syntax reference page lists `dest` as repeatable

---
