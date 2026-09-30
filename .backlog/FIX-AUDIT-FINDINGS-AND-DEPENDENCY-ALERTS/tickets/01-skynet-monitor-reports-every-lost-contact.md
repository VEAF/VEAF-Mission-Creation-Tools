# 01 — the Skynet monitor reports every lost contact

Status: ✅ done — 2026-09-28

Source: `davidp57/security-audits#89`, checked against the code on 2026-09-28.

## The defect

`VeafSkynetMonitorTaskContacts:Execute` (`src/scripts/veaf/veafSkynetIadsMonitor.lua:482-488`)
walks `self.TrackedUnits` with `pairs` and removes from that same table inside the loop.
`TrackedUnits` is a sequence (`AddTrackedContact` uses `table.insert`), and `RemoveTrackedContact`
goes through the local `tableRemove`, which calls `table.remove(tab, i)` and shifts every later
element down one slot. The iterator resumes after the index it already returned, so each element
shifted onto a visited slot is skipped.

With `{A, B, C}` all lost in the same beat: A is removed, C is visited at index 2, the loop ends.
**B is never reported lost and stays in `TrackedUnits`**, so when it reappears the detection loop
(474-479) sees it as already tracked and reports nothing either. The contact is dead both ways for
the rest of the mission. Two aircraft of one flight leaving IADS cover together are enough.

## Also in the same two loops

`local err, errmsg = pcall(self.OnDetectedAction, …)` (478) and its twin (486) capture both values
and read neither. `err` is in fact the success flag, and a mission maker's action that raises is
swallowed without a log line. Log the failure at `error` with the message `pcall` returned.

## What to do

* Walk the sequence backwards (`for i = #self.TrackedUnits, 1, -1`), or iterate a copy. Backwards
  is the smaller change and keeps the removal where it is.
* Log a failed `OnDetectedAction` / `OnLostAction` with the contact name and the error message.

## Test

`test/lua/test_veafSkynetIadsMonitor.lua` never exercises `VeafSkynetMonitorTaskContacts:Execute`.
Add, with a stub IADS whose `getContacts()` the test controls:

* three tracked contacts, all gone in one call → `OnLostAction` called three times,
  `TrackedUnits` empty. **Fails before the fix** (two calls, one leftover).
* a lost contact that comes back → `OnDetectedAction` called again.
* an `OnLostAction` that raises → the loop still finishes and an error line is logged.
