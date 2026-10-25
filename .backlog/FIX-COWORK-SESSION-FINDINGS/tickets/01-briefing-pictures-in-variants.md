# 01 — Briefing pictures in every weather variant

Status: ✅ done

`build_mission_briefing` returned `"miz": "…\\VEAF_Caucasus_FireAtAdler_20261025.miz"`, the root archive of the build, while the players fly `missions\VEAF_Caucasus_FireAtAdler_dawn.miz`.
`find_built_mission` (`campaign_manager/mission_picture.py`) globs the folder's root and `build/` only; the weather variants of `versions.yaml` land in `missions/`.
The assistant rebuilt to carry the pictures over and had no tool to confirm they arrived.

Measure first: after `build_mission_briefing` then no rebuild, which archives hold the `MCP_Briefing_*` pictures; after a rebuild, whether the variants get them from `l10n/DEFAULT/` of the folder.

Done when: the pictures are in every `.miz` the build produced (root and each variant) right after `build_mission_briefing`, the result lists each archive written, and a test covers a folder with two variants.

## Result

Measured in the code: `find_built_mission` returns the build's own `.miz`, and nothing wrote the variants.
Fix: `built_archives` lists the build's own `.miz` then every `missions/*.miz`, and `_write_pictures` writes each, backed up; the result's `archives` lists them.
Tests: `test_every_weather_variant_gets_the_maps_too`, `test_the_kneeboard_and_the_archives_are_reported`.
