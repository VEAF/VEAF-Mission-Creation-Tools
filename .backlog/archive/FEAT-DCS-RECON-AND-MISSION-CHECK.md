# FEAT-DCS-RECON-AND-MISSION-CHECK — reconnaissance photos and an in-game mission check, from a running DCS

Status: ✅ done · archived 2026-11-24

Two things the "Marteau du Golan" session (Syria, 2026-10-28) did by hand against a running DCS, through the `dcs-fiddle` hook, and that every objective mission needs again.
The prototype lives in that mission's `docs/build/recon/` (`fiddle.py`, `shoot.py`, `proj.py`, `process.py`, `menu.lua`, `zones*.lua`, `cap.lua`, `reroute.lua`); its logic is taken over, not its code.

| # | What | Ticket |
|---|---|---|
| 1 | `veaf-tools dcs recon-photos prepare`: a shooting copy of a built mission — clear sky, chosen time, every combat zone active at start, real group names | 01 |
| 2 | `veaf-tools dcs recon-photos shoot`: read the live units from the `server` state, put the F11 camera on each shot's engagement axis from the `export` state, grab the DCS window, write the raw shot and its metadata | 02 |
| 3 | `veaf-tools dcs recon-photos render`: the reconnaissance look (contrasted black and white, grain, vignette, banner, heading rose) and red felt-pen marks placed by perspective projection (80° horizontal field, measured) | 03 |
| 4 | `veaf-tools dcs mission-check`: the F10 tree VEAF built (empty labels), every combat zone and combat mission toggled and counted, every routed ground group seen moving within 60 s, one line per check and a verdict | 04 |
| 5 | Documentation, CHANGELOG | 05 |

Decided with the brief (2026-10-28):

- nothing is done to a DCS session the user did not launch; nothing on a server; no sound; each command says what it will do and what it expects of the user;
- unit tests for everything that does not need DCS: projection, camera vectors, rendering, menu tree parsing, request building and parsing;
- CLI only, filed under the `dcs` group next to `smoke-test`: like it, both need a DCS running on this machine, which an MCP client building a mission elsewhere does not have (CLAUDE.md §7, "a CLI command exists because a mission maker will type it");
- the JPEG + JSON pair is the input of the objective briefing (lot FEAT-OBJECTIVE-BRIEFING-QUALITY's follow-up).

One branch, one PR.

## Tickets, in full

## 01 — A shooting copy of a built mission

Status: ✅ done

`recon-photos prepare <mission.miz>` writes `<mission>_RECON.miz` beside it: clear sky (no cloud, fog, dust or precipitation, maximum visibility), the start time given (`--time HH:MM`, default 11:30), every combat zone activated at start, and `veaf.HideNamesFromSpawnedGroups = false` so the live groups carry their zone's name and can be matched to a shot.
The original is never touched.

Done when: the derived mission's weather, start time and `veaf-config.lua` are covered by tests on a fixture `.miz`.

### Result

`derive_recon_mission` and `recon-prepare`; tested on a fixture `.miz`. The in-game pass found the immediate activation loop spawning every zone two or three times: it now runs 5 s later, once per name, skipping active zones.

## 02 — Shoot: live units, camera on the engagement axis, window grab

Status: ✅ done

`recon-photos shoot --shots shots.yaml` against the shooting mission running in DCS, F11 free camera (spectator is enough).
Positions come from `coalition.getGroups` / `coalition.getStaticObjects` in the `server` state — VEAF's random draws only exist in game.
Each shot targets the centroid of the units whose group (or static) name starts with one of its prefixes, and the camera sits on the shot's heading, pitch and slant range, set with `LoSetCameraPosition` in the `export` state (x forward, y up, z right, p position), sent twice with a pause for the scenery to load.
The DCS client area is grabbed from the primary screen (`ImageGrab.grab()`; `all_screens=True` returns black for the DirectX window), retried while black, without the F11 info bar.
Metadata per shot: camera, heading, pitch, slant, target (DCS and lat/lon), mission time, units.

Done when: camera vectors, the camera request, the unit dump parsing and target selection are unit-tested.

### Result

`shoot_plan`, `camera_for`, `camera_lua`, `dcs_window_capture` and `recon-plan` / `recon-shoot`. In game: 12 shots in 44 s; the blackness test now leaves the F11 bar out (36 px, cut at 40) after four black shots slipped through.

## 03 — Render: the reconnaissance look and the felt-pen marks

Status: ✅ done

`recon-photos render` turns each raw shot into the final JPEG: contrasted black and white, grain, vignette, a banner (operation, target, heading, pitch, DMS, ground elevation, time), a heading rose, and red felt-pen marks — irregular open loops of varying stroke width, handwritten labels (Ink Free) — placed by perspective projection with an 80° horizontal field (measured: the six vehicles of an SA-11 fall within a few pixels of their projection).

Done when: the projection is unit-tested against a known geometry, and a render of a synthetic shot produces a JPEG of the expected size with red marks where the units project.

### Result

`recon_render` and `recon-render`, writing the sidecar `build_mission_briefing` reads (FEAT-OBJECTIVE-MISSION-V2) into `docs/recon/`. In game: the marks land on the SA-6 and SA-11 vehicles and the four Kiswah buildings.

## 04 — mission-check: menus, zones, missions, routes

Status: ✅ done

`veaf-tools dcs mission-check` on the test build the user launched:

- a. the F10 tree VEAF built (`veafRadio.radioMenu`), every empty label reported with its path;
- b. every combat zone and combat mission (CAP variants `<name>/<skill>/<scale>` included) activated and deactivated through the scripting state, units counted each time, every one left as it was found; operations are reported, not toggled (they cascade to their zones);
- c. every ground group with a route of more than one waypoint seen moving (speed > 0) within 60 s — the check that found the column frozen by an "On Road" route with no road;
- d. one line per check, a verdict at the end, exit code 1 on a failure.

Done when: the Lua builders and every parser are unit-tested, and the report's verdict follows the lines.

### Result

`dcs_mission_check` and `mission-check`, talking to the fiddle server inside the mission scripting environment (12080: the `server` state has no `veaf` modules). In game: PASS, 20 checks on Marteau du Golan; a provoked empty label fails with exit code 1.

## 05 — Documentation and CHANGELOG

Status: ✅ done

Both commands documented (FR + EN) where `smoke-test` is, with the exact steps a mission maker follows in DCS; CHANGELOG entry.

### Result

CLI reference (FR + EN), mission-maker guide, CHANGELOG, known limitations `camera-moves-only-from-the-export-state` and `operation-registers-its-zones-twice`.
