# FIX-SCRATCH-MISSION-PLAYABLE — a mission built from scratch cannot be flown

Status: 🔄 in-progress — ticket 02 (the guard) done 2026-08-14; 01 and 03 remain

Origin: David, 2026-08-14, thirty seconds after loading a mission prepared for the DCS verification
session — DCS opened **CHANGING COALITIONS** with every country unassigned. Found by starting the
game, which is exactly what a session is for.

## Three defects, one theme

A mission created from nothing — `prepare --theatre`, `scaffold_mission --theatre`, then populated
through the MCP — **is not playable**, and nothing says so.

### a. `coalitions` is never populated, and a comment claims otherwise

`blank_mission.py:80` ships `"coalitions": {"blue": {}, "red": {}, "neutrals": {}}`, and line 10
states the gap is covered:

> or the composites (`add_group` populates coalitions/countries on demand) — fills them in.

**No line of the MCP writes that table.** Grepped: the only matches are `enemy_coalitions`, a QRA
field with nothing to do with it. So the work was deferred to a place that never did it, which is the
same shape as `VMR-088` — and the comment is what made that deferral invisible.

`coalitions` maps **country ids to a side**; `coalition` holds the units. Populating the second
without the first gives a mission whose units live in a side that does not exist.

**There is no canonical distribution to copy.** Measured across this repository's missions: blue
carries between 5 and 30 countries, red between 3 and 12 — each author picked their own in the
editor. So the fix is not a default table; it is that **adding a group assigns that group's country
to its side**, which is precisely what the comment promises.

### b. Nothing can create a player slot

David, the same afternoon: a mission maker will need this for certain — and he is right, because the
assistant cannot produce a flyable mission at all today.

`add_group` handles ground groups. `set_unit_properties` **refuses** `Client`/`Player`, and that
refusal is correct and stays: writing an AI skill over a `Client` deletes a multiplayer slot and the
reverse creates one, which is the bug `FIX-TEMPLATE-SLOTS-VISIBLE` was opened for. What is missing is
an action that *creates* the slot.

`add_air_group` (`FEAT-MCP-MUTATION-ACTIONS` ticket 09) is blocked on parking data from a DCS session
— but **a slot in the air, or on the ground with a caller-supplied spot, needs none of it**. That half
is deliverable now.

### c. `validate` does not catch any of it

The mission built for that session **passed `validate` and built cleanly**, then DCS refused it. A
mission with units in a side owning no country is unflyable, and the one tool whose job is to say so
before the build said nothing. That is the defect that let a and b stay invisible.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | [Adding a group assigns its country to its side](tickets/01-populate-coalitions.md) | ⬜ |
| 02 | [`validate` refuses a mission nobody can fly](tickets/02-validate-playable.md) | ✅ |
| 03 | [An action that creates a player slot](tickets/03-player-slot.md) | ⬜ |

Order matters: 02 is the guard that proves 01, and it must fail on today's output before 01 lands.

## Definition of Done

- A mission created by `scaffold_mission` + `add_group` opens in DCS without the coalition dialog.
- `validate` reports a side holding units but no country, and reports a mission with no player slot.
- An assistant can produce a flyable mission end to end, without the editor.
- TDD throughout; full Python gate green; coverage ratchet respected.

## Ticket 02, done first on purpose

The guard was written before either fix and **failed on the session's own mission** — units in blue,
`coalitions.blue` empty — which is what proves it measures something. It reports zero errors on the
five real missions in `test/veaf-tools/`, so it is discriminating rather than merely strict.

One decision taken while writing it: the three quirk readers (`indexed`, `numeric_first`, `CATEGORIES`)
**moved from `veaf_mission_mcp.mission_table` to `veaf_libs.mission_table`**, re-exported so no import
changed. The validator needed the same dict-or-list quirk the MCP actions do, the dependency runs
MCP → veaf_libs, and a second copy would have received half the fixes.
