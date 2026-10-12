# 01 — Measure the object, then guard by what it can answer

Status: ⬜ ready

- `veafSanctuary.lua` (around line 605): `weapon:getTarget()` can return an object with no `isExist` method; the guard `not target:isExist()` then raises in the scheduler.
- First **measure** what that object is: log its `getCategory()` and `getName()` once, on a shot at a building, a unit, a static and a weapon, in a test mission or through the bridge. The scenery hypothesis is not proved.
- Then guard by what the object can answer, and decide what the sanctuary does with a target it cannot ask about (a scenery target protects no human: it should return quietly).
- Lua test where the mocked target has no `isExist`; the existing test for a target destroyed since stays green.
