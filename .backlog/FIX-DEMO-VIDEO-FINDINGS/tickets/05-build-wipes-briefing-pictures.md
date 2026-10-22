# 05 — `build_mission` wipes the briefing pictures

Status: ⬜ ready

The AI: "`build_mission` overwrites the .miz and wipes briefing pictures → always run `build_mission_briefing` last".
`build_mission_briefing` writes its pictures into the mission folder (`src/mission/l10n/DEFAULT/`, `mapResource`, `pictureFileName*`) and into the built `.miz` (FEAT-MCP-MISSION-BRIEFING), precisely so that a rebuild keeps them.

Measure: `build_mission_briefing`, then `build_mission`, then read the new `.miz` — are the pictures and their `pictureFileNameB/N` entries still there?
If they are gone, find which step of the build drops them (the folder's mission table, or a step that rewrites `mapResource`); if they stay, find what the AI saw instead and say it in the guide.

Done when: a rebuild keeps the briefing pictures, with a test that builds twice; or the measurement shows they were kept and the guide says so.
