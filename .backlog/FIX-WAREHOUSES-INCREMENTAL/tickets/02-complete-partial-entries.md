# 02 — An entry that exists is not an entry that works

Status: ✅ done 2026-08-16 — 5 keys became 20 at both ends; needs one in-game confirmation
Type: fix
Files: `src/python/veaf-tools/mission_builder/warehouses_bootstrap.py`,
`src/python/veaf-tools/veaf_mission_mcp/airbase.py`, their two test modules

## The measurement

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

## The change, at both ends

- `ensure_airports_populated` **completes** a partial entry key by key. A key already present is
  never overwritten: it is the mission's own decision.
- `_airbase_entry` (the MCP) creates a **full** entry from `DEFAULT_AIRPORT` instead of `{}`, so an
  airfield is usable the moment it is assigned, without waiting for a build to repair it.

Either fix alone would have made the symptom go away; both are correct, and the build-side one also
covers entries written by something else.

## Tests

Four: a partial entry gains the keys it lacks; the values it already had survive; a new MCP entry
carries the full shape; an existing MCP entry keeps its identity and values.

## Verified beyond the tests

Rebuilt: Deir ez-Zor and Palmyra now carry 20 keys with nothing missing, `unlimitedAircrafts = true`
and a 52-type catalogue each; the neutral airfields keep theirs and stay inert.
