# 01 — Reallocate colliding ids at injection

Status: ✅ done

## Problem

`AircraftGroupsInjectorWorker` writes the catalogue's `groupId` and `unitId` into the target mission
unchanged. The catalogues live in a low id band (145–544 and 47–152); a real mission occupies the
whole range up to ~3900. Measured: 6 duplicate `groupId` and 11 duplicate `unitId` on
`test-import.miz`, 4 and 9 on the Open Training Caucasus mission, and 4 `unitId` shared between the
two shipped catalogues on any mission that injects both.

A duplicate `groupId` on a template makes `linkDynTempl` ambiguous, and that aircraft type alone
stops being offered.

## Decision

Reallocate **only on collision** (option b, chosen by David on 2026-09-22), not systematically.

Reallocating every injected id would be simpler to reason about but would change all 128 template
ids on every build, so the `.miz` would differ wholesale from one build to the next, and in
`mode: replace` the ids would creep upward indefinitely.

The delicate part is `mode: replace`: the group being replaced must **not** count itself as taken,
or it reallocates itself on every build.

## Work

- Before the injection loop, index the ids the target mission already uses, and their maxima —
  across **every** group category, enumerated from `GROUP_CATEGORIES`. DCS shares one id space:
  scanning only `plane` and `helicopter` left 8 `groupId` and 5 `unitId` colliding with vehicles
  and statics, measured on two real missions.
- Per injected group: keep its id if free; otherwise allocate `max + 1` and bump the counter, so two
  injected groups cannot collide with each other either.
- Same for each `unitId`.
- In `mode: replace`, exclude the group being replaced from the taken set.
- Log how many ids were reallocated (detail level, not a warning: this is normal operation).

## Tests

The one that proves the bug is fixed is not about id uniqueness, it is about the link surviving:
after injection **and** `apply_warehouses`, every stocked type's `linkDynTempl` must designate
exactly one group, and that group must be a `dynSpawnTemplate` of the right type. It fails today.

Around it:

- ids are unique after injection, asserted on a mission whose own ids cover the catalogue's band;
- a catalogue id that is free stays unchanged (minimal diff);
- `mode: replace` run twice does not move the ids the second time;
- injecting `spawnables.yaml` then `dynamic-slot-templates.yaml` leaves no duplicate — the 4 shared
  `unitId` are the regression case.

Assert on the mission read back, not on the constant or the in-memory structure.
