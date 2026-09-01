# 01 — Only aircraft are CAP targets

Status: ✅ done

Type: fix · Files: `src/scripts/veaf/veafSpawnAircraft.lua`, `test/lua/test_veafSpawn.lua`,
`test/lua/dcs_mocks.lua`

## What was wrong

`startCapWatchdog` decided what to engage from the **group** a detected object belongs to:

```lua
targetGroupCategory == Group.Category.AIRPLANE or targetGroupCategory == Group.Category.HELICOPTER
```

An ejected pilot keeps his aircraft's group, so the group category still says AIRPLANE, and
`target:inAir()` is true under a canopy. Neither test can tell a fighter from a man on a parachute.

Two other things were wrong on the same lines, and both were reachable in the same session:

- the object was **dereferenced four times before being filtered** (`getID`, `getGroup`,
  `getName`, `getCategory`). `getDetectedTargets` returns *objects*, not aircraft, and on 2026-09-01
  one of them raised *"Static doesn't exist"* — twice. The watchdog re-arms itself from its own tail,
  so the raise did not cost a tick, it stopped that CAP's watchdog for the rest of the mission;
- the priority ladder ended in an `else` branch — *"Target has unknown attributes"* — which gave
  anything unrecognised a priority and a place in the list rather than refusing it.

## What was done

One named predicate, `veafSpawn.isCapEngageableTarget(target, capCoalition)`, called **before** anything
is read off the object, and called again by the engage loop so that a target that has gone is dropped.

It refuses, in this order: an object whose `Object.Category` is not `UNIT`; one that is not active or
not airborne; one whose coalition is unknown or friendly; one whose group is not an aircraft group; and
finally one **whose own descriptor does not carry the `Air` attribute**. Every accessor goes through a
guarded call, so an object that raises is refused rather than propagated.

### Why the `Air` attribute, and why nothing that reads a name

Enumerated from the shipped DCS unit database rather than picked: of its **883 entries, all 170
aircraft carry `Air`, and not one vehicle, ship, static or infantry entry does**. The test sweeps the
whole table, so the day ED ships an aircraft without it, the suite says so.

A name match would have been worse than useless. A mission maker names his units in his own language —
and DCS's *own* default unit name for an aircraft is `Pilot #001`, which is exactly what the
2026-09-01 log was full of (see the PRD's second recorded correction). An ED attribute is the same
string in every mission, whatever language it is written in.

## Definition of done

- [x] An object that is not an aircraft is never listed, whatever its group says
- [x] The enumeration is over the whole shipped unit database, not over chosen cases
- [x] An object that raises costs neither its neighbour on the radar nor the watchdog
- [x] Tests red before the change, green after
