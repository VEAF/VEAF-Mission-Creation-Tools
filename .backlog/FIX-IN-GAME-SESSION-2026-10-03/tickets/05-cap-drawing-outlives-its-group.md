# 05 — a `-cap` zone drawing outlives its group

Status: ⬜ ready
Type: fix

## Measured

Ten `-cap` spawned on 2026-10-03 each drew its patrol zone on the F10 map, visible to the blue side.
Nine of them were then removed with `Group:destroy()`: their drawings stayed (David's capture, the
same day).

## To decide

Whether removal by script should take the drawing with it (a watchdog that sees its group gone), or
whether only the VEAF removal verbs are expected to — and whether the opposing side should see a
CAP's zone at all.
