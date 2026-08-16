# 01 — Complete the airfield table instead of all-or-nothing

Status: ✅ done 2026-08-16 — 224 added beside 1 existing; needs one in-game confirmation
Type: fix
Files: `src/python/veaf-tools/mission_builder/warehouses_bootstrap.py`, both locale files,
`test/python/mission_builder/test_warehouses_bootstrap.py`

## The change

`ensure_airports_populated` iterates the theatre's airfields and adds the ones the table does not
already hold, instead of returning early on a non-empty table. An existing entry is skipped, never
merged into and never replaced: it carries the mission's own coalition and stock.

The return value keeps its meaning — how many entries were **added** — so the build message stays
truthful whether it fired on an empty table or a partial one.

## Why the old rule was wrong

It read as prudence ("do not touch a mission that declares its own airfields") but the two cases it
conflated are not alike:

- a mission that declares **all** its airfields — nothing to add, and the loop adds nothing;
- a mission that declares **one** — the all-or-nothing rule skipped the other 224.

The second is not exotic: it is what `set_airbase_coalition` produces, one call, the documented way
to own a base. A test now pins it with the exact shape that action leaves behind.

## Tests

Three added, one replaced: the missing airfields are added beside an existing one (224 + 1 = 225);
an existing entry keeps its identity (`is` the same object) and its settings; a complete table gains
nothing on a second pass. The former "an existing table is untouched" test is gone — it asserted the
defect.

## Verified beyond the tests

A mission built with Deir ez-Zor blue and Palmyra red: 223 airfields added to the 2 the MCP wrote,
and the warehouses step then switched dynamic slots on for both — `dynamicSpawn = true` with a
52-type catalogue each, while the neutral airfields stayed inert.
