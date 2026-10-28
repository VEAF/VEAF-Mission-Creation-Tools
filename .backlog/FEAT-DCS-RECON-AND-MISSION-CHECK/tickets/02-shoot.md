# 02 — Shoot: live units, camera on the engagement axis, window grab

Status: 🔄 in progress

`recon-photos shoot --shots shots.yaml` against the shooting mission running in DCS, F11 free camera (spectator is enough).
Positions come from `coalition.getGroups` / `coalition.getStaticObjects` in the `server` state — VEAF's random draws only exist in game.
Each shot targets the centroid of the units whose group (or static) name starts with one of its prefixes, and the camera sits on the shot's heading, pitch and slant range, set with `LoSetCameraPosition` in the `export` state (x forward, y up, z right, p position), sent twice with a pause for the scenery to load.
The DCS client area is grabbed from the primary screen (`ImageGrab.grab()`; `all_screens=True` returns black for the DirectX window), retried while black, without the F11 info bar.
Metadata per shot: camera, heading, pitch, slant, target (DCS and lat/lon), mission time, units.

Done when: camera vectors, the camera request, the unit dump parsing and target selection are unit-tested.
