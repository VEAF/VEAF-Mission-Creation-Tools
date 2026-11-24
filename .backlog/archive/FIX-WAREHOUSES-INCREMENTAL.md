# FIX-WAREHOUSES-INCREMENTAL — assigning one airfield disabled all the others

Status: ✅ done — verified in game 2026-10-03 (R2) · archived 2026-11-24

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
| 01 | [Complete the airfield table instead of all-or-nothing](FIX-WAREHOUSES-INCREMENTAL.md) | ✅ |
| 02 | [An entry that exists is not an entry that works](FIX-WAREHOUSES-INCREMENTAL.md) | ✅ |
| 03 | [Offer a hot start on a dynamic-slot airfield](FIX-WAREHOUSES-INCREMENTAL.md) | ✅ |
| 04 | [Document that the shipped templates are bare](FIX-WAREHOUSES-INCREMENTAL.md) | ✅ |

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

## Tickets, in full

## 01 — Complete the airfield table instead of all-or-nothing

Status: ✅ done 2026-08-16 — 224 added beside 1 existing; needs one in-game confirmation
Type: fix
Files: `src/python/veaf-tools/mission_builder/warehouses_bootstrap.py`, both locale files,
`test/python/mission_builder/test_warehouses_bootstrap.py`

### The change

`ensure_airports_populated` iterates the theatre's airfields and adds the ones the table does not
already hold, instead of returning early on a non-empty table. An existing entry is skipped, never
merged into and never replaced: it carries the mission's own coalition and stock.

The return value keeps its meaning — how many entries were **added** — so the build message stays
truthful whether it fired on an empty table or a partial one.

### Why the old rule was wrong

It read as prudence ("do not touch a mission that declares its own airfields") but the two cases it
conflated are not alike:

- a mission that declares **all** its airfields — nothing to add, and the loop adds nothing;
- a mission that declares **one** — the all-or-nothing rule skipped the other 224.

The second is not exotic: it is what `set_airbase_coalition` produces, one call, the documented way
to own a base. A test now pins it with the exact shape that action leaves behind.

### Tests

Three added, one replaced: the missing airfields are added beside an existing one (224 + 1 = 225);
an existing entry keeps its identity (`is` the same object) and its settings; a complete table gains
nothing on a second pass. The former "an existing table is untouched" test is gone — it asserted the
defect.

### Verified beyond the tests

A mission built with Deir ez-Zor blue and Palmyra red: 223 airfields added to the 2 the MCP wrote,
and the warehouses step then switched dynamic slots on for both — `dynamicSpawn = true` with a
52-type catalogue each, while the neutral airfields stayed inert.

## 02 — An entry that exists is not an entry that works

Status: ✅ done 2026-08-16 — 5 keys became 20 at both ends; needs one in-game confirmation
Type: fix
Files: `src/python/veaf-tools/mission_builder/warehouses_bootstrap.py`,
`src/python/veaf-tools/veaf_mission_mcp/airbase.py`, their two test modules

### The measurement

Ticket 01 shipped, and the mission built with it still failed in game: parked slots unusable, and a
dynamic-slot catalogue showing **zero aircraft in every type**. The airfield entry the MCP had
written carried **5 keys**, against **20** on the ones the build wrote:

| | |
|---|---|
| Deir ez-Zor (MCP) | `aircrafts, coalition, dynamicSpawn, unlimitedFuel, unlimitedMunitions` |
| a neutral airfield (build) | the 20 keys the DCS Mission Editor writes |
| missing | `unlimitedAircrafts`, `size`, `speed`, `periodicity`, the three `OperatingLevel_*`, the four fuels, `suppliers`, `weapons`, `allowHotStart`, `dynamicCargo` |

Ticket 01 skipped it, because it existed. The rule was written as "never touch an existing entry",
and it silently read **"the entry exists"** as **"the entry is complete"** — the same shape of
mistake as the all-or-nothing rule it had just replaced, one level finer.

### The change, at both ends

- `ensure_airports_populated` **completes** a partial entry key by key. A key already present is
  never overwritten: it is the mission's own decision.
- `_airbase_entry` (the MCP) creates a **full** entry from `DEFAULT_AIRPORT` instead of `{}`, so an
  airfield is usable the moment it is assigned, without waiting for a build to repair it.

Either fix alone would have made the symptom go away; both are correct, and the build-side one also
covers entries written by something else.

### Tests

Four: a partial entry gains the keys it lacks; the values it already had survive; a new MCP entry
carries the full shape; an existing MCP entry keeps its identity and values.

### Verified beyond the tests

Rebuilt: Deir ez-Zor and Palmyra now carry 20 keys with nothing missing, `unlimitedAircrafts = true`
and a 52-type catalogue each; the neutral airfields keep theirs and stay inert.

## 03 — Offer a hot start on a dynamic-slot airfield

Status: ✅ done 2026-08-16 — needs one in-game confirmation
Type: fix
Files: `src/python/veaf-tools/warehouses_injector/warehouses_injector_worker.py`,
`src/defaults/mission-folder/src/warehouses.yaml`,
`test/python/warehouses_injector/test_warehouses_injector.py`

### The measurement

Reported in game on 2026-08-16, the run where everything else finally worked: *"seul défaut,
l'option spawn hot des slots dyn est désactivée"*.

`allowHotStart` is the field behind that option. The DCS Mission Editor writes it **false**, so
`DEFAULT_AIRPORT` copies false, and nothing ever set it back: `_apply_to_airport` handled
`dynamicSpawn`, fuel, munitions and stock, and did not know about it. Grepped: `allowHotStart`
appeared in exactly one place in the whole Python tree — the default entry.

### The change

An airfield the mission opens to dynamic slots offers a hot start: `_apply_to_airport` writes
`allowHotStart = True` beside `dynamicSpawn = True`. A dynamic slot the pilot can only take cold is
half the feature, and the mission has deliberately opened that airfield.

`hot_start: false` under a coalition's `defaults:` turns it back off — symmetric with the existing
`fuel:` and `weapons:` keys, so a mission wanting cold starts only can say so in one line. An
airfield of another coalition is never touched, which a test pins.

### Tests

Three: a configured airfield offers a hot start; `hot_start: false` turns it off; an airfield of a
coalition the config does not declare keeps whatever it had.

### Verified beyond the tests

Rebuilt: Deir ez-Zor (blue) and Palmyra (red) carry `allowHotStart = true` with their 52-type
catalogue; the neutral airfields keep `false` and stay inert.

## 04 — Document that the shipped dynamic-slot templates are bare

Status: ✅ done 2026-08-16
Type: docs
Files: `doc/mission-maker/GUIDE.md` + `.en.md`

### The measurement

Reported in game: *"les appareils qu'on me propose sont nus (pas de loadout, pas de skin VEAF)"*.

Counted in the built mission, per coalition:

| | |
|---|---|
| templates carrying a loadout | **9** — A-10C_2, F-14B, F-15C, F-15ESE, F-4E, Mirage-F1BE, … |
| templates with **no** loadout | **43** — UH-1H, CH-47F, FA-18C, F-16C, M-2000C, Mi-8MT, Ka-50, Su-25, the SA342s … |
| templates with a named livery | 45 of 52 |

The plumbing is sound, and a one-shot test proved it: an A-10C II taken from a dynamic slot comes
out **armed and painted**. All 52 catalogue entries carry a `linkDynTempl` pointing at their group,
and DCS applies it. A link to an empty template simply yields an empty aircraft.

So this is a **data** gap in `src/defaults/mission-folder/src/dynamic-slot-templates.yaml`, not a
defect in the build.

### David's arbitration

Option 3 of three: **document it**, rather than filling the 43 by hand (deciding an FA-18C's default
loadout for a VEAF mission is a mission-maker call, not a deduction) or regenerating the defaults
from a reference mission.

Both guides now say what a pilot will actually see, name the two families (9 equipped, 43 bare), and
give the one command that replaces the shipped templates with the mission maker's own:

```
veaf-tools.exe content extract-aircraft-groups my-mission.miz --kind dynamic-template
```

The option value was read off `--help` rather than guessed — it is `dynamic-template`, not
`dynamic`, and the first draft of the doc had it wrong.
