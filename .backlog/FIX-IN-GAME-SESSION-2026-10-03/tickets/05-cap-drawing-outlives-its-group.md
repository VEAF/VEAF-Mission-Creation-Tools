# 05 — a `-cap` zone drawing outlives its group

Status: 🚫 wontfix — a trace marker, not a drawing of the feature
Type: fix

## Measured

Ten `-cap` spawned on 2026-10-03 each drew its patrol zone on the F10 map, visible to the blue side.
Nine of them were then removed with `Group:destroy()`: their drawings stayed (David's capture, the
same day).

## Why it is not a defect

The circle is `veaf.Logger:marker(…, "CAP", "targetZone", …)` in the `cap` role, which draws only when
the logger's effective level is `trace` (`veaf.lua`, `getEffectiveLevel() >= 5`). The session ran
VEAF-SPAWN at `trace` (R18). At the default level nothing is drawn — so nothing outlives anything, and
no side sees a CAP's zone. Trace markers are never cleaned up, by design of the debug aid. David's call,
2026-10-03.
