# 05 — `build_mission` wipes the briefing pictures

Status: ✅ done

The AI: "`build_mission` overwrites the .miz and wipes briefing pictures → always run `build_mission_briefing` last".
`build_mission_briefing` writes its pictures into the mission folder (`src/mission/l10n/DEFAULT/`, `mapResource`, `pictureFileName*`) and into the built `.miz` (FEAT-MCP-MISSION-BRIEFING), precisely so that a rebuild keeps them.

Measure: `build_mission_briefing`, then `build_mission`, then read the new `.miz` — are the pictures and their `pictureFileNameB/N` entries still there?
If they are gone, find which step of the build drops them (the folder's mission table, or a step that rewrites `mapResource`); if they stay, find what the AI saw instead and say it in the guide.

Done when: a rebuild keeps the briefing pictures, with a test that builds twice; or the measurement shows they were kept and the guide says so.

## Result

Measured, not reproduced. `build_mission_briefing` writes the pictures into the mission folder (`src/mission/l10n/DEFAULT/`, `mapResource`, `pictureFileName*`) **and** into the built `.miz`; the worker's tests check both. On Martinho's run (6.31.4, the worker is unchanged since 6.31.0): briefing, then `build_mission` again, and the final `.miz` holds the three `briefing-*.jpg` and a `mapResource` listing them beside the VEAF keys. The AI of the video (6.31.3, same worker) could have been misled by an unchanged `.miz` modification time, as Martinho's was; its folder is gone.
Fix: none in the build. `inspect_built_mission` now lists the pictures and whether the archive holds each (ticket 14), so the AI can check instead of guessing.
