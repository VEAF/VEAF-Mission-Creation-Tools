# 01 — Measure the object, then guard by what it can answer

Status: 🧑 waiting-human

- `veafSanctuary.lua` (around line 605): `weapon:getTarget()` can return an object with no `isExist` method; the guard `not target:isExist()` then raises in the scheduler.
- First **measure** what that object is: log its `getCategory()` and `getName()` once, on a shot at a building, a unit, a static and a weapon, in a test mission or through the bridge. The scenery hypothesis is not proved.
- Then guard by what the object can answer, and decide what the sanctuary does with a target it cannot ask about (a scenery target protects no human: it should return quietly).
- Lua test where the mocked target has no `isExist`; the existing test for a target destroyed since stays green.

## Done, 2026-10-14

- **Not measured.** DCS was not running on the workstation, and the scripting API schema documents `isExist` on every `Object`, `SceneryObject` included — so it cannot say which object came without it. The scenery hypothesis stays a hypothesis.
- Guarded by capability: a target whose `isExist` is not a function is ignored (no player to protect), before `isExist()` is called. A target destroyed since is still ignored the same way as before.
- That object is logged once per mission at `info`: `weapon target with no isExist method: Object.getCategory=…, Object.getName=…, type=…`, each call under `pcall`. The next server log of a mission built with the fix says what it is, without a session.
- The other `getTarget()` caller, `veafMissileGuardian.lua`, never calls `isExist` on the target, only `getName` and, for a protected unit, `getPoint`: not the same defect, left as is.
- `test_a_target_with_no_isExist_method_is_ignored_and_logged_once` reproduced the log line before the fix (`attempt to call method 'isExist' (a nil value)`); the destroyed-target test stays green.
- Recorded in `known-limitations.yaml` (`weapon-gettarget-object-with-no-isexist`, `kind: dcs`); the measurement to make is R48 in `DCS-SESSION-TODO.md`.

**Left (🧑)**: read the category from the next server log, or run R48 — and if it is a unit or a static, the guard must ask through `Object.getName` instead of returning.
