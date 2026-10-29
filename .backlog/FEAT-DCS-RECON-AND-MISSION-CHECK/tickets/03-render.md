# 03 — Render: the reconnaissance look and the felt-pen marks

Status: ✅ done

`recon-photos render` turns each raw shot into the final JPEG: contrasted black and white, grain, vignette, a banner (operation, target, heading, pitch, DMS, ground elevation, time), a heading rose, and red felt-pen marks — irregular open loops of varying stroke width, handwritten labels (Ink Free) — placed by perspective projection with an 80° horizontal field (measured: the six vehicles of an SA-11 fall within a few pixels of their projection).

Done when: the projection is unit-tested against a known geometry, and a render of a synthetic shot produces a JPEG of the expected size with red marks where the units project.

## Result

`recon_render` and `recon-render`, writing the sidecar `build_mission_briefing` reads (FEAT-OBJECTIVE-MISSION-V2) into `docs/recon/`. In game: the marks land on the SA-6 and SA-11 vehicles and the four Kiswah buildings.
