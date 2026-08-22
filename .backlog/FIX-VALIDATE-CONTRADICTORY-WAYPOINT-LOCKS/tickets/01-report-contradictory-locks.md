# 01 — Report contradictory waypoint locks

Status: ⬜ ready

## What

`mission validate` must report a route whose waypoint fixes its **speed** while the waypoints around it
fix their **arrival time**. DCS refuses to save such a mission and names the route, not the flag, so the
message must do better than the editor's.

## The real case to reproduce

`verify-mission-a`, group `SmokeZone-SmokeArmor`, before the 2026-08-22 repair: two waypoints, both with
`ETA_locked = true` and `speed_locked = true`. The editor answered:

```
All waypoints (2-2) have locked speed and surrounded by waypoints 1 and 2 with locked time!
```

Use that data as the fixture — it is real DCS-rejected data, worth more than a synthetic route.

## Done when

- [ ] The check names the **group** and the **waypoint index**, and says which flag to clear
- [ ] It runs as part of `mission validate`, before a build rather than in the editor
- [ ] A route with one locked-time waypoint and locked speeds elsewhere stays **clean** — that is the
      normal shape, and every other route in both verification missions has it. A check that flags the
      normal case is worse than no check
