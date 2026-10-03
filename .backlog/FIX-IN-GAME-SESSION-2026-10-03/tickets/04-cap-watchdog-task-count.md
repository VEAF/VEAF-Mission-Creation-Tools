# 04 — the CAP watchdog keeps adding tasks

Status: ⬜ ready — needs reading before a fix
Type: fix

## Measured

A `-cap` MiG-29S pair, watchdog traced on 2026-10-03: `numberOfTasksAddedByWatchdog` read 38, 43, 49
on three consecutive passes ten seconds apart, while the CAP kept engaging the same targets. Nothing
seen removes a task the watchdog pushed.

## Also seen

The same passes kept as targets aircraft **105 km** from the CAP zone's centre (Arco and its escorts).
The `-cap` zones drawn on the F10 map that day were of the same order of radius. Whether that radius
is intended is part of this reading.

## To find out

Whether the count is a counter that never resets (cosmetic) or tasks really accumulating on the
controller (a growing task list on every engaging CAP for the whole mission).
