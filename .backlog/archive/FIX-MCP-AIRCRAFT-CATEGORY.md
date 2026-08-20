# FIX-MCP-AIRCRAFT-CATEGORY — every helicopter slot the MCP created was unflyable

Status: ✅ done — 2026-08-16

Origin: David opened a generated test mission in the Mission Editor on 2026-08-16 and sent a
screenshot: **AIRPLANE GROUP**, `TYPE: UH-1H` in red. The mission was one I had built to verify
`FIX-CTLD-NEVER-INITIALIZED`, and I had "verified" its slots by finding the string `UH-1H` in the
`.miz` — it was there, in the wrong place.

## The measurement

A DCS mission files aircraft under two different keys, `plane` and `helicopter`, and they are not
interchangeable. Both MCP actions that create aircraft hard-coded the wrong one:

| File | Line | |
|------|------|---|
| `veaf_mission_mcp/add_air_group.py` | `category="plane"` | a ramp flight |
| `veaf_mission_mcp/player_slot.py` | `category="plane"` | a player slot |

So **every** helicopter either action ever produced was broken: the editor shows the type in red and
the slot cannot be flown. Nothing in the mission file marks it — the category is structural, not a
validated field — which is why it survived a full test suite. The existing tests looked the group up
*by name under `plane`* and found it, which is exactly what a wrongly-filed helicopter does.

## The fix

`air_category_for_type()` in `mission_tools/group_insertion.py` resolves the category from the type,
reading the generated `dcsUnits.yaml` through a new `veaf_libs/dcs_units_data.py` — the same
database `list_unit_types` serves, so there is no second list to keep in step.

An unknown type falls back to `plane` **and returns a warning naming it**, surfaced in the action's
result. Third-party mods are legitimately absent from the database (`Hercules` is), so refusing
would break a legitimate call; guessing silently would rebuild the defect. Both actions now also
report the `category` they chose.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | Resolve the category from the aircraft type | ✅ |

## What this says about the tests

Nine tests were added, but the interesting number is the one that was already there: the suite was
green while the feature was broken for a whole category of aircraft, because **no assertion looked
at the category at all**. The new tests assert the group is under `helicopter` *and absent from*
`plane` — a one-sided assertion would have passed before the fix too.

## What the ticket changed

**01 — Resolve the aircraft category from the type.** New `veaf_libs/dcs_units_data.py`, plus
`mission_tools/group_insertion.py`, `veaf_mission_mcp/add_air_group.py`,
`veaf_mission_mcp/player_slot.py` and their three test modules.

`air_category_for_type_verbose(unit_type) -> (category, warning)` sits beside `GROUP_CATEGORIES`,
where the category vocabulary already lives; a thin `air_category_for_type()` serves callers that
surface the warning elsewhere. Both actions call it instead of passing a literal, and both return the
resolved `category` so a caller can see what was decided. Nine tests.
