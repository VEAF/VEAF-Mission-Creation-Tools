# FIX-DYNSLOT-TEMPLATE-CATEGORY-002 — investigate the QRA airplane-intruder symptom

Status: 🧑 waiting-human
Type: fix
Files: `veafQraCore.lua`, `test/lua/`, DCS manual test (Tripack)

## What to build

Investigate the QRA symptom — link to 001 unconfirmed. Repro: dynamic-slot airplane +
a QRA with `react_on_helicopters: false`/absent → the QRA must activate. Test
before/after 001 to settle whether the category fix resolves it. If it persists, fix
QRA intruder detection so an airplane is recognised by real DCS unit type
(`unit:getCategory()`) regardless of the mist/section category (`unit.category` line
666, `group:getCategory()` line 774). Add a QRA test for the airplane-intruder case.

## Acceptance criteria

- [ ] Repro tested before/after 001 to settle whether the category fix resolves it
- [ ] If it persists, QRA recognises an airplane intruder by real DCS unit type
- [ ] QRA test added for the airplane-intruder case

## Blocked by

Waiting on in-game confirmation by Tripack after #515 (needs Tripack's source mission / a clean repro).
