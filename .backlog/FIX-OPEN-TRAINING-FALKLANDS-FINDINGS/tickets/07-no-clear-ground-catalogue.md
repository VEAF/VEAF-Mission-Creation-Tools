# 07 — Ground placement on a theatre with no clear-ground catalogue

Status: ⬜ ready

Files: `veaf_libs/data/known-limitations.yaml`, `veaf_mission_mcp/surface.py`, tests.

## What happened

Report finding 12: on Falklands, a `Disposition` probe of the grid positions found 15 vehicles out of 176 at fault — 5 in the water (two beacons, two false units of the Ushuaia naval base, a 4x4) and 10 « blocked » — and `tools/fix_scenery.py` moved them from 25 m to 1 425 m.
No clear-ground catalogue covers the map, and the ground sweep sees neither fresh water nor trees.
It is the case of `marianas-placement-checks-nothing`, one theatre more.

## Done when

- A known-limitation entry for Falklands (`kind: tool`) with the 15/176 measure and the workaround (`clear-ground-sweep Falklands --zones-from <mission>`, then `clear-ground-check`); `docs/agents/dcs-runtime-traps.md` regenerated.
- The « surface not checked » warning names `clear-ground-sweep` too, not only `terrain-sweep`.
- Decide with David whether a catalogue around the 27 Falklands airfields is worth shipping.
