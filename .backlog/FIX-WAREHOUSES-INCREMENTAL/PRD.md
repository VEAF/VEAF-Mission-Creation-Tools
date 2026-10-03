# FIX-WAREHOUSES-INCREMENTAL — assigning one airfield disabled all the others

Status: ✅ done — verified in game 2026-10-03 (R2)

Origin: David's answer to the open question left by `FIX-EMPTY-WAREHOUSES` — *"yes, dynamic slots
by default, on every airfield of the coalition; there is no rule for which airfield is blue or red:
the mission maker says so through the MCP, and for a test you pick one of each arbitrarily"*.

Instrumenting that answer surfaced a hole in the lot that had just shipped.

## The defect

`ensure_airports_populated` filled the airfield table **only when it was empty**. That rule breaks
the moment the documented workflow is used:

```
set_airbase_coalition("Deir ez-Zor", blue)   -> warehouses.airports = { 42: {...} }   (1 entry)
veaf-tools mission build                      -> table is not empty -> 0 added
```

The mission ships with **1 airfield out of 225**, and every other one is unusable — the exact defect
`FIX-EMPTY-WAREHOUSES` exists to prevent, reintroduced by using the MCP as intended. Measured, not
reasoned: the call above returns `0` on a table holding one entry.

The fix is to **complete** the table — add the missing airfields, never touch an existing entry
(it carries the mission maker's own ownership and stock).

## What already worked, and needed nothing

Dynamic slots are switched on by the existing `warehouses.yaml` step, whose default config declares
`blue:` and `red:` with **no airfield list** — which the injector reads as *"every airfield of that
coalition"*, sets `dynamicSpawn = true` and stocks the coalition's templates. So *"dynamic slots by
default on every airfield of the coalition"* needs no new code: it needs airfields that **have** a
coalition, which is what the MCP writes and what this lot stops the build from discarding.

Measured on a mission with Deir ez-Zor blue and Palmyra red:

| airfield | coalition | dynamicSpawn | catalogue |
|---|---|---|---|
| Deir ez-Zor | BLUE | true | 52 types |
| Palmyra | RED | true | 52 types |
| Nicosia (untouched) | NEUTRAL | false | 0 |

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Complete the airfield table instead of all-or-nothing](tickets/01-complete-not-all-or-nothing.md) | ✅ |
| 02 | [An entry that exists is not an entry that works](tickets/02-complete-partial-entries.md) | ✅ |
| 03 | [Offer a hot start on a dynamic-slot airfield](tickets/03-hot-start.md) | ✅ |
| 04 | [Document that the shipped templates are bare](tickets/04-document-template-loadouts.md) | ✅ |

## A build message that lied

The log said *"added to an empty table"* while the table held the two airfields the MCP had just
written. Reworded to *"added (the mission declared none)"* — a message stating a condition that is
not the one it fired on is exactly the kind of thing that sends the next investigation the wrong way.

## In-game check — 2026-10-03

From `FIX-IN-GAME-SESSION-2026-10-03`.

A blank Syria mission, Deir ez-Zor set blue and Palmyra red through `set_airbase_coalition`, built:
the game reports 225 airdromes (223 neutral, 1 red, 1 blue) and an untouched field, Nicosia, still
has its warehouse (four liquids). A dynamic-slot UH-1H was taken at Deir ez-Zor.

## Former index entry

The row this lot had in `.backlog/README.md` until the index was split into short summaries (CHORE-BACKLOG-INDEX-SPLIT, 2026-10-03), kept verbatim.

**assigning one airfield to a coalition disabled all the others.** `FIX-EMPTY-WAREHOUSES` filled the airfield table only when it was *empty*, and the documented workflow breaks that instantly: one `set_airbase_coalition` call leaves a single entry, the build then adds nothing, and the mission ships with **1 airfield out of 225** — the same defect, reintroduced by using the MCP as intended. Found while instrumenting David's arbitration (*dynamic slots by default on every airfield of the coalition; no rule decides who owns what — the mission maker says, or I pick one of each for a test*). The table is **completed** now, an existing entry never touched. That arbitration needed no other code: the `warehouses.yaml` step already reads "no airfield list" as "every airfield of that coalition" and switches `dynamicSpawn` on — measured at 52 aircraft types each on a blue Deir ez-Zor and a red Palmyra, neutrals inert. A build message claiming "added to an empty table" while the table held two entries was reworded on the way
