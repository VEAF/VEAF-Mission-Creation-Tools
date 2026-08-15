# 08 — Capture the parking-slot data an aircraft needs to stand on a ramp

Status: 🔄 in-progress — tooling shipped 2026-08-12; Caucasus captured and analysed 2026-08-15;
Syria and PersianGulf still want a DCS session
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

- [x] 🧑 **Caucasus captured 2026-08-15** by David. Syria and PersianGulf remain — the bridge missions
      for both are ready in `tmp\bridge-maps\collect\` (Syria built the same day).
- [x] Committed as `veaf_build/dcs_data/airbase_dumps/parking/Caucasus.json`, beside the airbase dump
      rather than in a sibling `parking/` folder, so the two files that share a key sit together.
- [x] **Shape recorded below, and it contradicts the table above**: `Term_Index_0` is `-1` on every
      slot, so `parking_id` does not come from this capture.

## The runtime shape, from a real capture — Caucasus, 2026-08-15

Captured by David with a bridge mission loaded, committed as
`veaf_build/dcs_data/airbase_dumps/parking/Caucasus.json`. **21 airfields, 942 slots**, between 7 and
94 per field. The file is `{theatre, parking_by_airbase}`, keyed by **airbase id as a string** — the
same ids as the airbase dump beside it (21 of 21 match), so a mission's `airdromeId` indexes straight
into it. Every value is a **string**, including the numbers.

A slot carries exactly eight keys:

```json
{"TO_AC": "false", "Term_Index": "43", "Term_Index_0": "-1", "Term_Type": "104",
 "fDistToRW": "1476.5401611328", "vTerminalPos.x": "-318191.53125",
 "vTerminalPos.y": "18.01001739502", "vTerminalPos.z": "635663.3125"}
```

### `parking_id` is **not** `Term_Index_0` — the assumption above is wrong

`Term_Index_0` is **`-1` on all 942 slots**. So is `TO_AC` (`"false"` throughout). Yet the A-10 that
flies at Kobuleti declares `parking: "43"` **and** `parking_id: "16"`, and David's own declares
`6` / `"01"` — a zero-padded string, which reads like the sign painted on the ramp rather than an
index. **Ticket 09 must not derive `parking_id` from this capture**; where it comes from is an open
question, and guessing it is what puts an aircraft on the grass.

`Term_Index` is the half that is confirmed: slot `43` exists at Kobuleti (airbase 24), which is the
one the working A-10 sits on.

### The coordinate mapping, confirmed by superposition

The same slot's position matches the flying A-10's group **exactly**:

| | runtime slot | mission group |
|---|---|---|
| `vTerminalPos.x` | `-318191.53125` | `x` = `-318191.53125` |
| `vTerminalPos.z` | `635663.3125` | `y` = `635663.3125` |
| `vTerminalPos.y` | `18.01001739502` | `alt` = `18` |

So **mission `y` is runtime `z`**, and runtime `y` is the altitude — exactly the trap
`docs/agents/dcs-coordinates.md` warns about, here confirmed on real data rather than argued.

`Term_Type` takes 5 values across the theatre: `104` (510 slots), `68` (340), `72` (46), `16` (42),
`40` (4). What they mean is not captured and ticket 09 should not assume — filtering a slot by type
without knowing which type accepts an A-10 is the next silent failure in line.

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
