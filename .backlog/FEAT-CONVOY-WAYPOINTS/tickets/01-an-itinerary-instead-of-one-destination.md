# 01 — An itinerary instead of one destination

Status: ✅ done
Type: feat

## What exists

`_spawn convoy, dest X` stores one string in `options.destination`, and
`veaf.generateVehiclesRoute(spawnSpot, destination, …)` turns it into a 3- or 4-waypoint route:
departure, on-road entry, the destination, and a final off-road hop when `onroad` is set. The convoy
is then registered as `veafSpawn.spawnedConvoys[name] = { route = route, name = name }`.

## What this ticket does

Accept `dest` **more than once** and walk the points in the order written:

```
_spawn convoy, dest KOBULETI, dest BATUMI, dest POTI
```

`veaf.parseMarkerText` iterates keyphrases with `ipairs` — order is load-bearing there by design and
its comment says so — so accumulating in an `apply` is enough. One `dest` yields a one-point
itinerary, which is today's behaviour: **no existing marker changes meaning**.

The convoy record grows the state the later tickets need: the itinerary, which leg is current, and the
route parameters (`speed`, `onRoad`, `patrol`) so a leg can be regenerated rather than remembered.

## Definition of done

- [x] `dest` repeated accumulates in order; a single `dest` behaves exactly as before
- [x] A leg's route is generated from the convoy's current position, not from the original spawn point
- [x] Lua tests: one point, several points, a point name that does not resolve, and the ordering
- [x] `veafSpawn.spawnedConvoys` carries the itinerary and the current leg
