# FIX-WAREHOUSES-LIST-FORM — every base neutral in a 6.14.2 build

Status: 🔄 in-progress — fixed and tested; awaiting the 6.14.3 release and Tripack's rebuild.

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
