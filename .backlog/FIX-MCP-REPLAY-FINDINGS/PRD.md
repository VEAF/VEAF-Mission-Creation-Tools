# FIX-MCP-REPLAY-FINDINGS — what the local-model replay of "Marteau du Golan" block 1 found

Status: ⬜ ready

Reported by the local-model test session on 2026-11-27, relayed with David's go: block 1 of "Marteau du Golan" replayed with Inkling local in Cherry Studio on develop `4ec65302`, compact profile. The mission was built — 120 MCP calls, 27 minutes, two harmless errors. Four points came out, measured in `E:\AI\mcp-calls.log` and `C:\VEAF-Missions\Marteau-du-Golan-3`.

1. Visibility "maximum" is written `visibility: 9000.0` in the built variant while the model says "80 km". **Known and by design**: `mission_settings.py` writes any visibility of 9 000 m or more as DCS's maximum, 80 km (a METAR's 9999). Not verified: that the built `.miz` holds 80 000. No ticket of its own; the check is part of ticket 03's measurement.
2. The guide's example (`C:\VEAF-Missions\test`, Caucasus, Beslan, 2024-06-10) was replayed as is. → ticket 01.
3. No action says which aircraft types an airfield offers; the model edited `src/warehouses.yaml` by hand with wrong keys (`F-16C`, `AV-8B` instead of `F-16C_50`, `AV8BNA`), got warnings at the first build and rebuilt, against the prompt's "one build at the end". → ticket 02.
4. `add_air_group` with `KC-135MPRS` was accepted, then the model deleted the group and recreated it as `KC135MPRS` (3 minutes). → ticket 03, a measurement first: `dcsUnits.yaml` holds the type `KC135MPRS` with the display name `KC-135MPRS`.

Three tickets, one PR. Ticket 02 is the useful one for a small local model: it removes the second build.
