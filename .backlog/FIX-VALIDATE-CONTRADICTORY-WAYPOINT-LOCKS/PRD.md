# FIX-VALIDATE-CONTRADICTORY-WAYPOINT-LOCKS — the validator passes a mission DCS refuses to save

Status: ⬜ ready

Found on 2026-08-22 the only way it could be found: David opened `verify-mission-a` in the DCS editor and
got a red box refusing to save it.

## What happened

```
SmokeZone-SmokeArmor:
All waypoints (2-2) have locked speed and surrounded by waypoints 1 and 2 with locked time!
```

Both waypoints of that route carried `ETA_locked = true` **and** `speed_locked = true`. A waypoint cannot
honour a fixed arrival time and a fixed speed at once when its neighbours also fix their times, so the
editor rejects the whole mission.

`poetry run veaf-tools mission validate .` had just reported **"✓ Validation réussie — aucun problème
détecté"** on that same file. The validator does not know these two flags exist: `ETA_locked` appears
nowhere in `mission_validator.py` or `mission_tools/`.

## Where the bad data came from — not the tooling

The second waypoint was added by hand on 2026-08-21 (commit `971652ad`, the lot that put `#alarm=2` on
unit #002), copied from the first with its locks included. The MCP is **not** the culprit and was checked:
`edit_route.py:_add` writes `"ETA_locked": False, "speed_locked": True`, which is correct.

An enumerated sweep of every route in both verification missions found **exactly one** offender, so this
is a one-off authoring slip — not a family of broken data. It is the *silence* that is the defect.

## Why this is worth a lot of its own

This is the same shape as [`FIX-WAYPOINTS-ETA-LOCKED`](../archive/FIX-WAYPOINTS-ETA-LOCKED.md), which
handled the **symmetric** case — a route with *no* locked-time waypoint, which DCS also refuses. That lot
taught the MCP to repair its own edits. Nothing teaches the **validator** to notice either case in data it
did not write.

A mission that fails to open in the editor is expensive out of proportion to the defect: it costs a
session. David lost the start of one to a single boolean, and the tool whose whole job is to say "this
mission is sound" said it was.

## Scope

| # | Ticket | Status |
|---|--------|--------|
| 01 | The validator reports contradictory waypoint locks, naming group and waypoint | ⬜ |
| 02 | It reports the symmetric case too — a route with no locked-time waypoint | ⬜ |

## Definition of done

- [ ] A route whose interior waypoint has `speed_locked` while its neighbours have `ETA_locked` is
      reported, with the group name and waypoint index, and the message says what to change
- [ ] A route with no `ETA_locked` at all is reported, matching what `FIX-WAYPOINTS-ETA-LOCKED` already
      repairs on the MCP side
- [ ] Both verification missions validate clean, and the fixed `SmokeZone-SmokeArmor` route is a
      regression test — it is real DCS-rejected data, which is worth more than a synthetic case
- [ ] The check runs on `mission validate`, so it is seen before a build rather than in the editor
