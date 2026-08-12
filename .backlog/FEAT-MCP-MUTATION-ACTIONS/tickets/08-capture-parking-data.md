# 08 — Capture the parking-slot data an aircraft needs to stand on a ramp

Status: 🧑 waiting-human — the tooling ships (2026-08-12); capturing needs a DCS session, per theatre
Type: feat
Files: `veaf_libs/dcs_bridge_capture.py`, `veaf_tools/commands/capture_map.py`, locales, `test/python/`

Depends on: nothing. **Blocks** [09](09-add-air-group.md).

## Why this ticket exists at all

The triage filed `add_air_group` under [03](03-group-setters.md) and left one question open: whether it
should exist, *"decided when 03 is picked up, with the composite in front of you rather than from
memory"*. Doing that turned up a hard dependency nobody had costed.

**A parked aircraft carries two different numbers.** Read out of `test/veaf-tools/test.miz`:

| Group | `parking` | `parking_id` | First waypoint |
|---|---|---|---|
| `Mustang4 F-14A` | 28 | **24** | `TakeOffParking` / `From Parking Area`, `airdromeId: 12` |
| `Elvis5 F-14A` | 1 | 1 | `TakeOff` / `From Runway`, `helipadId: 58` |

They match the runtime's `Term_Index` and `Term_Index_0` — and the first row proves they are **not**
interchangeable. So "put a two-ship on the ramp at Incirlik" needs that airfield's real slot ids, and
guessing them puts aircraft on the grass, on a taxiway, or inside each other.

Nothing in this repository holds them. `veaf_build/dcs_data/airbase_dumps/<theatre>.json` — 15
theatres, captured by David with the kit from `FEAT-AIRDROMES-RUNTIME-SOURCE` — carries exactly
`{id, name, lat, lon, coalition}` per airbase and no parking at all. The API schema shipped here
declares `AirbaseParking` with four fields, which is **already known to be incomplete** given the pair
above, so the shape has to come from the runtime rather than from the schema.

David's call (2026-08-12): do `add_air_group` properly, **with** the parking data.

## What ships in this ticket (done)

The capture side, so the only thing left is running it:

- `capture_parking()` runs `Airbase:getParking(false)` over the existing dcs-bridge and returns
  `{airbase id: [slot, ...]}`. It dumps **every key** each slot carries, flattening a nested table one
  level (`vTerminalPos.x`), and keeps values as **strings** — the point is to record what the runtime
  returns, not to interpret it. A test pins that an unknown future field survives, precisely because
  the schema is known incomplete.
- `write_parking_dump()` writes `parking/<theatre>.json`, a **separate** file: a large theatre has
  hundreds of airfields with dozens of slots each, and inflating a dump that 15 theatres already use
  would be a migration for no reason.
- `veaf-tools capture-map --parking` does both captures in one run, airbases **first**, so a maker who
  loses the slower second call still has the useful half. Its own longer timeout, and FR + EN strings.

## What is left, and it needs DCS

Exactly what `FEAT-AIRDROMES-RUNTIME-SOURCE` did for airbases — the kit makes it a five-minute job per
map, and **starting DCS is David's**:

```bash
veaf-tools capture-map --parking --out-dir veaf_build/dcs_data
```

- [ ] 🧑 Run it on the theatres that matter first — Caucasus, Syria, PersianGulf — with a bridge
      mission loaded and `dcs-serve` up.
- [ ] Commit `veaf_build/dcs_data/parking/<theatre>.json` per captured theatre.
- [ ] **Then** read one real dump and record its actual shape here, before ticket 09 spends it. The
      table above is a mission-file measurement; the runtime's own field names are still assumed.

## Careful

- `getParking(false)` asks for **every** slot, not just the free ones (`true` filters to available).
  An empty bridge mission has everything free, so the distinction does not bite today — but a capture
  run inside a populated mission with `true` would silently record a subset.
- A theatre whose airfields report no slots is **data, not a failure**: a WWII map may genuinely have
  none, and the capture accepts an empty result rather than raising.
- Slot ids are terrain data, so they change when ED reworks a map. That argues for recording the DCS
  version alongside a capture — not done, and worth deciding in 09 rather than guessing here.

## Acceptance criteria

- [x] `capture-map --parking` implemented, tested, documented in both locales.
- [ ] 🧑 At least one theatre captured and committed.
- [ ] 🧑 The runtime shape of a slot recorded in this ticket, from a real capture.
