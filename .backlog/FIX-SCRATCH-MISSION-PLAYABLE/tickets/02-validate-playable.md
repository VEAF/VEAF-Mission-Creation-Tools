# 02 — `validate` refuses a mission nobody can fly

Status: ✅ done 2026-08-14 — both checks in place; proven on the session's own broken mission and silent on the five real missions in the repository
Type: fix
Files: `src/python/veaf-tools/veaf_libs/mission_validator.py`, tests

## Why this comes first

The mission built for the 2026-08-14 session **passed `validate` and built cleanly**, and DCS then
refused to load it without a manual coalition assignment. The missing guard is why defects a and b of
this lot stayed invisible. Write it first and watch it fail on today's output — that failure is the
proof the guard measures something.

## The two checks

1. **A side holds units but its coalition owns no country** → **error**. That is the state DCS shows as
   CHANGING COALITIONS, and it is unambiguous: units exist in a side that does not.
2. **No unit anywhere has skill `Client` or `Player`** → **warning**, not an error. A mission with no
   player slot is legitimate — a server-side scenario, a template library — so this must not refuse the
   build. But it is the other half of what made a mission unflyable, and worth saying once.

Word both so the fix is obvious from the message: name the side, and say that a slot is what a pilot
needs to enter the mission at all.

## TDD

- Failing first: a mission with units in blue and `coalitions.blue` empty is reported as an error.
- A mission whose country is assigned passes.
- The player-slot check warns rather than errors — proven by a mission with no slot still validating.

## Acceptance criteria

- [ ] Both checks in place with tests; the first an error, the second a warning.
- [ ] `validate` stays clean on the repository's own fixtures, which are real missions.
- [ ] Full Python gate green.
