# 03 — Report what the wiring actually achieved

Status: ✅ done

## Problem

Every defect in this lot was found by writing a throwaway script. The build prints
`Warehouses : 13 aéroports configurés, 832 liens de modèle` — a count of what it *wrote*, never a
check of whether it *works*. Two failure shapes pass through silently:

1. **A link that points at nothing.** `linkDynTempl: 3853` where no group carries that id. The
   Mission Editor renders it as `Group template: None` and the mission maker has no reason to read
   it as a defect. Measured: 69 such links survive a full build today, all in the ship/FARP section.

2. **Templates with nowhere to be offered from.** A mission built straight from
   `prepare --theatre Caucasus --template standard` injects **128 templates** and then prints
   `Warehouses : 0 aéroports configurés, 0 liens de modèle`. Every one of the 21 airfields is
   NEUTRAL, so no dynamic slot is playable. The build says nothing; the maker gets 128 groups in his
   mission and no way to use them.

Both are cheap to detect at the exact moment the pipeline already holds the data.

## Work

After the warehouses step, walk both warehouse sections and the mission's groups once:

- count `linkDynTempl` values that resolve to no group, or to a group that is not a
  `dynSpawnTemplate`, and **warn** with the count and the first few types;
- when templates were injected and the step configured zero airfields, **warn** saying why (no
  airbase belongs to a coalition) and what to do about it.

A warning, not an error: a mission may legitimately be built in an intermediate state.

## Tests

A check that cannot fail is not a check. Prove each one fires **and** stays quiet:

- a mission with a dead link → the warning fires, with the right count;
- the same mission after the fix of ticket 01/02 → silent;
- templates injected and no coalition airfield → the second warning fires;
- one coalition airfield → silent.
