# FIX-WAREHOUSES-LIST-FORM — every base neutral in a 6.14.2 build

Status: ✅ done — verified in game 2026-10-03 (R3), on a mission rebuilt from the current version

Reported by Tripack on 2026-08-17 with two builds of the same mission: `Snowfox_20260816.miz`
(6.14.0, correct) and `Snowfox_20260817.miz` (6.14.2, every base neutral).

## What the two files say

| | 6.14.0 | 6.14.2 |
|---|--------|--------|
| `warehouses` member | 261 KB | **141.7 KB** |
| its `airports` section | 6072 lines | **901 lines** |
| airfields | 29 | 30 |
| coalitions | 26 RED, 1 BLUE, 2 NEUTRAL | **30 NEUTRAL** |
| airfields carrying an aircraft stock | 3 | **0** |
| `allowHotStart` / `dynamicSpawn` set | 10 / 5 | none |

The `warehouses.warehouses` section (FARP and ship stock, 65 entries) is byte-identical in both —
nothing touches it, which is what pointed at `airports` specifically.

## Root cause

`warehouses_bootstrap.ensure_airports_populated`, three lines:

```python
airports = warehouses_content.get("airports")
if not isinstance(airports, dict):
    airports = {}                       # the mission's own table is discarded here
    warehouses_content["airports"] = airports
```

DCS keys `warehouses.airports` by **airdrome id**. A mission that declares every airfield of its
theatre therefore has the ids `1..N` — and `luadata` renders a contiguous integer-keyed Lua table
as a Python **list**. The guard, written to survive an absent or malformed table, catches the
**nominal case** instead: it replaces the mission's airfields with an empty dict, then repopulates
it with NEUTRAL defaults.

Reproduced by feeding Tripack's own 6.14.0 table to the shipped code:

```
BEFORE  type: list   count: 29   coalitions: {RED: 26, NEUTRAL: 2, BLUE: 1}   stock: 3
AFTER   type: dict   added: 30   coalitions: {NEUTRAL: 30}                    stock: 0
```

## Why no test and no in-game check caught it

Every test in `test_warehouses_bootstrap.py` builds `airports` as a **dict literal**, and both
in-game verifications (`FIX-EMPTY-WAREHOUSES`, `FIX-WAREHOUSES-INCREMENTAL`) started from a mission
built **from scratch**, where the table really is empty — or from one airfield written by
`set_airbase_coalition`, a dict the Python side had just built. All three exercised the two shapes
that happen to be dicts. The shape that breaks is the one only a real, complete mission has, and
nothing in the suite ever read a `.miz` at that point.

Scope note found while measuring: two other call sites index the same table and, on a real mission,
**raise** rather than degrade — `set_airbase_coalition` (`'list' object has no attribute 'get'`) and
the warehouses injector (`… no attribute 'items'`). They did not crash in 6.14.2 only because the
bootstrap ran first and had turned the list into a dict by emptying it. Fixing the bootstrap alone
would have surfaced two crashes.

## The fix

Normalise once, at load: `miz_tools.normalize_warehouses_airports` turns a list into a dict keyed
from **1** (Lua indexes from one; an off-by-one would move every airfield's ownership to its
neighbour), called from both `read_miz` and `read_mission_folder`. `ensure_airports_populated` and
`_airbase_entry` call it too, so a caller assembling a mission by hand cannot re-earn the bug.

Safe by construction, and measured rather than assumed: a dict keyed `1..N` and the list it came
from serialise **identically** under the build's settings (`always_provide_keyname=True`), both as
`[n] = {...}`. A mission nobody touched comes back out byte-identical.

Verified on Tripack's real file: 29 → 30 entries, **26 RED / 1 BLUE / 3 NEUTRAL**, all three
aircraft stocks intact, exactly **one** entry added — the airfield his mission had never declared.

## Blast radius

Only `v6.14.2` contains the guard (`git tag --contains` on the introducing commit). Any mission
**built** with 6.14.2 has neutral bases and must be rebuilt; the fix ships as 6.14.3.

Mission **sources** are safe: `write_mission_folder` is called only by the MCP, never by the build,
so no mission folder was rewritten with the emptied table. A rebuild is enough.

## Definition of done

- [x] The list form keeps its coalitions, its stock and its per-airfield settings
- [x] Completion still happens on a list-shaped table (the missing airfields are added)
- [x] A normalised table is written back unchanged
- [x] `set_airbase_coalition` no longer raises on a real mission
- [x] Tests build their fixture through a real Lua round-trip, not as a dict literal
- [ ] 6.14.3 released and Tripack's mission rebuilt with it

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

The airfields of a mission built from `develop` hold the coalition the mission declares, read by
`Airbase:getCoalition()` in game: Deir ez-Zor 2, Palmyra 1, Tiyas 0.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**every base neutral in a mission built with 6.14.2**, reported by Tripack with two builds of the same source. Measured on his files: the `warehouses` member fell **261 KB → 141.7 KB** and 29 airfields carrying 26 RED, 1 BLUE and three aircraft stocks came out as **30 NEUTRAL** with none. DCS keys that table by airdrome id, so a mission declaring every airfield of its theatre has the ids `1..N` — and `luadata` renders a contiguous integer-keyed table as a **list**. The guard `not isinstance(airports, dict)`, written for an absent or malformed table, caught **the nominal case** and replaced the mission's own airfields with an empty dict before filling it with neutral defaults. Reproduced by feeding his 6.14.0 table to the shipped code, fixed by normalising at load (keyed from **1** — Lua indexes from one, and an off-by-one would shift every airfield's ownership onto its neighbour), and verified on that same file: 29 → 30 entries, 26 RED / 1 BLUE intact, all three stocks kept, exactly **one** entry added. Safe because measured: a dict keyed `1..N` and the list it came from serialise **identically** under the build's settings, so an untouched mission is written back byte-for-byte. **Why nothing caught it**: every test built the table as a dict literal and both in-game checks started from a mission built *from scratch*, where it really is empty — the three shapes exercised were all dicts. Two more call sites indexed the same table and **raised** on a real mission (`set_airbase_coalition`, the injector); they only survived because the bootstrap emptied the list first, so fixing it alone would have surfaced two crashes. Sources are safe (`write_mission_folder` is MCP-only), a rebuild on 6.14.3 suffices
